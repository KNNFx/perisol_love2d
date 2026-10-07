-- Luật chơi M1: máy trạng thái ván + lệnh (command). Thuần Lua, không gọi love.*.
-- Mọi thay đổi trạng thái đi qua Game.check / Game.apply (D-011), nên UI, mô phỏng test, AI (P6)
-- và multiplayer (P7) dùng chung một API.
--
--   Game.new{seed, players}   -> state (phase "setup_hq")
--   Game.actor(state)         -> pid phải ra lệnh (nil khi ván kết thúc)
--   Game.check(state, cmd)    -> ok, lý do (tiếng Việt, cho tooltip)
--   Game.apply(state, cmd)    -> events (cho log/UI); lệnh sai thì báo lỗi
--   Game.legal(state)         -> danh sách lệnh hợp lệ của Game.actor (cho sim/AI/nút)
--
-- Pha: setup_hq -> [roll -> (rebel_move -> rebel_loss?) -> action] x lượt x 20 vòng -> over
-- Lệnh: placeHQ{start} · roll · rebelStep{q,r} · chooseLoss{res} · trade{give,get} · placeVote{q,r} ·
--       buyTile{q,r} · upgradeHQ · foundSub{q,r} · build{id,q,r} · upgrade{uid,q,r,rot} · demolish{uid} ·
--       respond{choice} (phase prompt) · endTurn

local C           = require("src.config.constants")
local Dice        = require("src.core.dice")
local Mapgen      = require("src.core.mapgen")
local Production  = require("src.core.production")
local Rebel       = require("src.core.rebel")
local Scoring     = require("src.core.scoring")
local Serialize   = require("src.core.serialize")
local State       = require("src.core.state")
local Structures  = require("src.core.structures")
local Construction = require("src.core.construction")
local Passives    = require("src.core.passives")   -- đăng ký bước upkeep thu nhập thụ động (sau bước dỡ)
local Upkeep      = require("src.core.upkeep")
local Territory   = require("src.core.territory")
local Buildings   = require("src.data.buildings")
local Terrains    = require("src.data.terrains")
local Resources   = require("src.data.resources")

local Game = {}
local key = State.key

local CORE = {}
for _, r in ipairs(Resources.core) do CORE[r.key] = true end

-- ─── Tiện ích ───────────────────────────────────────────────────────────────

local function canAfford(res, cost)
    for k, n in pairs(cost) do
        if (res[k] or 0) < n then return false end
    end
    return true
end

local function pay(res, cost)
    for k, n in pairs(cost) do res[k] = res[k] - n end
end

-- Xếp hạng thứ tự lượt bằng xúc xắc; hòa thì những người hòa đổ lại.
local function rankByRolls(rng, pids)
    if #pids <= 1 then return pids end
    local groups = {}
    for _, pid in ipairs(pids) do
        local v = Dice.rollOne(rng)
        groups[v] = groups[v] or {}
        table.insert(groups[v], pid)
    end
    local out = {}
    for v = 6, 1, -1 do
        if groups[v] then
            for _, pid in ipairs(rankByRolls(rng, groups[v])) do out[#out + 1] = pid end
        end
    end
    return out
end

local function isEventRound(round)
    for _, r in ipairs(C.EVENT_ROUNDS) do
        if r == round then return true end
    end
    return false
end

-- ─── Khởi tạo ───────────────────────────────────────────────────────────────

function Game.new(opts)
    local players = opts.players
    local map = Mapgen.generate({ seed = opts.seed, players = players })
    local state = State.new(map, players, opts.seed)
    state.setupIdx, state.takenStarts, state.history = 1, {}, {}
    for pid = 1, players do
        for k, v in pairs(C.STARTING_RESOURCES) do state.players[pid].res[k] = v end
    end
    local pids = {}
    for pid = 1, players do pids[pid] = pid end
    state.order = rankByRolls(state.rng, pids)
    state.log[1] = { kind = "setup", order = state.order, round = 0 }
    return state
end

function Game.actor(state)
    local ph = state.phase
    if ph == "setup_hq" then return state.order[state.setupIdx] end
    if ph == "roll" or ph == "action" then return state.order[state.turn] end
    if ph == "rebel_move" then return state.rebel.pending.roller end
    if ph == "rebel_loss" then return state.rebel.pending.owner end
    if ph == "prompt" then return state.prompt.pid end
    return nil
end

-- ─── Chuyển pha sau Phiến Quân / Giải Quyết ─────────────────────────────────

-- Khâu Giải Quyết (GDD §5.3): Phiến Quân (đã xong) -> Sự Kiện Tổng -> Sắc Lệnh -> kỹ năng nhân vật.
-- M1 chỉ ghi nhận mốc sự kiện (stub); Sắc Lệnh / kỹ năng ở M2 / M3.
local function resolution(state, events)
    if state.turn == 1 and isEventRound(state.round) then
        events[#events + 1] = { kind = "global_event", stub = true }
    end
    state.phase = "action"
end

local function settleRebel(state, events)
    local stage = Rebel.stage(state)
    if stage == "move" then state.phase = "rebel_move"
    elseif stage == "loss" then state.phase = "rebel_loss"
    else resolution(state, events) end
end

-- ─── Điều kiện xây ──────────────────────────────────────────────────────────

-- Chi phí xây thực tế của công trình `id` cấp 1 trên `tile` (hiệu ứng địa hình giảm chi phí).
local function buildCost(state, pid, id, tile)
    return Construction.cost(state, id, 1, tile)
end

local function buildCheck(state, pid, id, tile)
    local def = Buildings.level(id, 1)
    if not def then return false, "Công trình không tồn tại" end
    if not tile then return false, "Không có ô này" end
    if state.owner[key(tile)] ~= pid then return false, "Chỉ xây được trên lãnh thổ thực hữu của bạn" end
    if Structures.at(state, tile) or Territory.isAnchorTile(state, tile) then return false, "Ô đã có công trình" end
    if Rebel.isBlockaded(state, tile) then return false, "Ô đang bị Phiến Quân phong tỏa" end
    if not Buildings.allowedOn(id, 1, tile.terrain) then return false, "Địa hình này không xây được công trình này" end
    if not canAfford(state.players[pid].res, buildCost(state, pid, id, tile)) then return false, "Không đủ tài nguyên" end
    return true
end

Game.buildCost = buildCost
Game.buildCheck = buildCheck

-- ─── Bảng lệnh ──────────────────────────────────────────────────────────────

local H = {}

H.placeHQ = {
    phase = "setup_hq",
    check = function(state, cmd)
        local st = state.map.starts[cmd.start or 0]
        if not st then return false, "Vùng khởi đầu không tồn tại" end
        if state.takenStarts[cmd.start] then return false, "Vùng khởi đầu đã có người chọn" end
        return true
    end,
    apply = function(state, cmd, pid, events)
        local st = state.map.starts[cmd.start]
        state.takenStarts[cmd.start] = pid
        local hqTile = state.map:get(st.q, st.r)
        Territory.placeHQ(state, pid, hqTile)
        events[#events + 1] = { kind = "place_hq", pid = pid, q = st.q, r = st.r }
        -- thưởng khởi đầu từ 6 ô quanh HQ (GDD §11.1 bước 8, D-013)
        local gains = {}
        for _, n in ipairs(state.map:neighbors(hqTile)) do
            local res = C.START_BONUS_BY_TERRAIN[n.terrain]
            if res then
                state.players[pid].res[res] = state.players[pid].res[res] + C.START_BONUS_PER_TILE
                gains[res] = (gains[res] or 0) + C.START_BONUS_PER_TILE
            end
        end
        events[#events + 1] = { kind = "start_bonus", pid = pid, gains = gains }
        state.setupIdx = state.setupIdx + 1
        if state.setupIdx > state.playerCount then
            local t = Rebel.spawn(state)
            events[#events + 1] = { kind = "rebel_spawn", q = t.q, r = t.r }
            state.phase, state.round, state.turn = "roll", 1, 1
        end
    end,
}

H.roll = {
    phase = "roll",
    check = function() return true end,
    apply = function(state, cmd, pid, events)
        for _, e in ipairs(Upkeep.startTurn(state, pid)) do events[#events + 1] = e end
        local dice = Dice.roll(state.rng)
        state.dice = dice
        events[#events + 1] = { kind = "roll", pid = pid, dice = dice }
        if Dice.isSeven(dice) then
            events[#events + 1] = { kind = "seven", pid = pid }
            local _, ev = Rebel.startMove(state, pid)
            for _, e in ipairs(ev) do events[#events + 1] = e end
            settleRebel(state, events)
        else
            for _, e in ipairs(Production.run(state, dice, pid)) do events[#events + 1] = e end
            resolution(state, events)
        end
    end,
}

H.rebelStep = {
    phase = "rebel_move",
    check = function(state, cmd)
        for _, t in ipairs(Rebel.legalSteps(state)) do
            if t.q == cmd.q and t.r == cmd.r then return true end
        end
        return false, "Phiến Quân không đi tới được ô này"
    end,
    apply = function(state, cmd, pid, events)
        for _, e in ipairs(Rebel.step(state, cmd.q, cmd.r)) do events[#events + 1] = e end
        settleRebel(state, events)
    end,
}

H.chooseLoss = {
    phase = "rebel_loss",
    check = function(state, cmd)
        for _, k in ipairs(state.rebel.pending.options) do
            if k == cmd.res then return true end
        end
        return false, "Loại tài nguyên không nằm trong lựa chọn"
    end,
    apply = function(state, cmd, pid, events)
        for _, e in ipairs(Rebel.resolveLoss(state, cmd.res)) do events[#events + 1] = e end
        settleRebel(state, events)
    end,
}

H.trade = {
    phase = "action",
    check = function(state, cmd, pid)
        if not CORE[cmd.give] or not CORE[cmd.get] then return false, "Tài nguyên không hợp lệ" end
        if cmd.give == cmd.get then return false, "Phải đổi sang loại khác" end
        if state.players[pid].res[cmd.give] < C.BANK_TRADE_RATE then
            return false, "Cần " .. C.BANK_TRADE_RATE .. " tài nguyên cùng loại để đổi"
        end
        return true
    end,
    apply = function(state, cmd, pid, events)
        local res = state.players[pid].res
        res[cmd.give] = res[cmd.give] - C.BANK_TRADE_RATE
        res[cmd.get] = res[cmd.get] + 1
        events[#events + 1] = { kind = "trade", pid = pid, give = cmd.give, get = cmd.get, rate = C.BANK_TRADE_RATE }
    end,
}

H.buyTile = {
    phase = "action",
    check = function(state, cmd, pid)
        local tile = state.map:get(cmd.q, cmd.r)
        local ok, why = Territory.canBuyTile(state, pid, tile)
        if not ok then return false, why end
        if not canAfford(state.players[pid].res, Territory.buyTileCost(state, pid, tile)) then
            return false, "Không đủ tài nguyên mua ô"
        end
        return true
    end,
    apply = function(state, cmd, pid, events)
        local tile = state.map:get(cmd.q, cmd.r)
        pay(state.players[pid].res, Territory.buyTileCost(state, pid, tile))
        Territory.buyTile(state, pid, tile)
        events[#events + 1] = { kind = "buy_tile", pid = pid, q = tile.q, r = tile.r }
        events[#events + 1] = { kind = "claim", pid = pid, q = tile.q, r = tile.r }
    end,
}

H.upgradeHQ = {
    phase = "action",
    check = function(state, cmd, pid)
        local ok, why = Territory.canUpgradeHQ(state, pid)
        if not ok then return false, why end
        local level = state.players[pid].hqLevel + 1
        if not canAfford(state.players[pid].res, C.HQ_UPGRADE_COST[level]) then
            return false, "Không đủ tài nguyên nâng cấp"
        end
        return true
    end,
    apply = function(state, cmd, pid, events)
        local p = state.players[pid]
        pay(p.res, C.HQ_UPGRADE_COST[p.hqLevel + 1])
        Territory.upgradeHQ(state, pid)
        events[#events + 1] = { kind = "upgrade_hq", pid = pid, level = p.hqLevel, q = p.hq.q, r = p.hq.r }
    end,
}

H.foundSub = {
    phase = "action",
    check = function(state, cmd, pid)
        local tile = state.map:get(cmd.q, cmd.r)
        local ok, why = Territory.canFoundSub(state, pid, tile)
        if not ok then return false, why end
        if not canAfford(state.players[pid].res, C.SUB_COST) then
            return false, "Không đủ tài nguyên lập Khu Trực Thuộc"
        end
        return true
    end,
    apply = function(state, cmd, pid, events)
        local tile = state.map:get(cmd.q, cmd.r)
        pay(state.players[pid].res, C.SUB_COST)
        Territory.addSub(state, pid, tile)
        events[#events + 1] = { kind = "found_sub", pid = pid, q = tile.q, r = tile.r }
    end,
}

H.placeVote = {
    phase = "action",
    check = function(state, cmd, pid)
        return Territory.canVote(state, pid, state.map:get(cmd.q, cmd.r))
    end,
    apply = function(state, cmd, pid, events)
        local tile = state.map:get(cmd.q, cmd.r)
        local before, after = Territory.addVote(state, pid, tile)
        events[#events + 1] = { kind = "vote", pid = pid, q = tile.q, r = tile.r,
                                status = Territory.statusOf(state, tile) }
        if after and after ~= before then
            events[#events + 1] = { kind = "claim", pid = after, from = before, q = tile.q, r = tile.r }
        end
    end,
}

H.build = {
    phase = "action",
    check = function(state, cmd, pid)
        return buildCheck(state, pid, cmd.id, state.map:get(cmd.q, cmd.r))
    end,
    apply = function(state, cmd, pid, events)
        local tile = state.map:get(cmd.q, cmd.r)
        pay(state.players[pid].res, buildCost(state, pid, cmd.id, tile))
        Structures.place(state, { id = cmd.id, level = 1, owner = pid }, { tile })
        events[#events + 1] = { kind = "build", pid = pid, id = cmd.id, level = 1, q = cmd.q, r = cmd.r }
    end,
}

-- Chi phí nâng `b` lên cấp kế, tính theo ô neo (nil nếu đã tối đa).
local function upgradeCost(state, b)
    if not Buildings.level(b.id, b.level + 1) then return nil end
    return Construction.cost(state, b.id, b.level + 1, Structures.tilesOf(state, b)[1])
end

local function upgradeCheck(state, pid, cmd)
    local b = state.buildings[cmd.uid]
    local ok, why = Construction.checkFootprint(state, pid, b, cmd.q, cmd.r, cmd.rot or 0)
    if not ok then return false, why end
    if not canAfford(state.players[pid].res, upgradeCost(state, b)) then return false, "Không đủ tài nguyên" end
    return true
end

Game.upgradeCost = upgradeCost
Game.upgradeCheck = upgradeCheck

H.upgrade = {
    phase = "action",
    check = function(state, cmd, pid) return upgradeCheck(state, pid, cmd) end,
    apply = function(state, cmd, pid, events)
        local b = state.buildings[cmd.uid]
        pay(state.players[pid].res, upgradeCost(state, b))
        local a = Construction.upgrade(state, cmd.uid, cmd.q, cmd.r, cmd.rot or 0)
        events[#events + 1] = { kind = "upgrade", pid = pid, id = b.id, level = b.level, q = a.q, r = a.r, uid = b.uid }
    end,
}

H.demolish = {
    phase = "action",
    check = function(state, cmd, pid)
        return Construction.checkDemolish(state, pid, state.buildings[cmd.uid])
    end,
    apply = function(state, cmd, pid, events)
        local b = state.buildings[cmd.uid]
        Construction.demolish(state, cmd.uid)
        local a = Structures.tilesOf(state, b)[1]
        events[#events + 1] = { kind = "demolish_start", pid = pid, id = b.id, q = a.q, r = a.r, uid = b.uid }
    end,
}

-- Lời nhắc xen lượt (trả lời đề xuất trao đổi, phản ứng của Đặc Biệt, Sắc Lệnh Phản Ứng ở M2...).
-- state.prompt = { kind, pid, options = { choice... }, resume = "action", ... dữ liệu riêng của kind }
-- Mỗi kind đăng ký vào Game.prompts: { check(state, prompt, choice) -> ok, lý do,
--                                      apply(state, prompt, choice, events) }.
Game.prompts = {}

-- Mở lời nhắc: phase chuyển sang "prompt" cho người trả lời. `resume` là phase quay về sau khi trả lời.
function Game.openPrompt(state, prompt)
    assert(Game.prompts[prompt.kind], "kind lời nhắc chưa đăng ký: " .. tostring(prompt.kind))
    prompt.resume = prompt.resume or state.phase
    state.prompt = prompt
    state.phase = "prompt"
end

H.respond = {
    phase = "prompt",
    check = function(state, cmd)
        local p = state.prompt
        local ok = false
        for _, c in ipairs(p.options) do
            if c == cmd.choice then ok = true end
        end
        if not ok then return false, "Lựa chọn không hợp lệ" end
        return Game.prompts[p.kind].check(state, p, cmd.choice)
    end,
    apply = function(state, cmd, pid, events)
        local p = state.prompt
        state.prompt = nil
        state.phase = p.resume
        Game.prompts[p.kind].apply(state, p, cmd.choice, events)
    end,
}

H.endTurn = {
    phase = "action",
    check = function() return true end,
    apply = function(state, cmd, pid, events)
        events[#events + 1] = { kind = "end_turn", pid = pid }
        state.turn = state.turn + 1
        if state.turn > state.playerCount then
            state.turn = 1
            state.round = state.round + 1
        end
        if state.round > C.ROUNDS_PER_GAME then
            state.phase = "over"
            events[#events + 1] = { kind = "game_over" }
        else
            state.phase = "roll"
        end
    end,
}

-- ─── API ────────────────────────────────────────────────────────────────────

function Game.check(state, cmd)
    local h = H[cmd.type]
    if not h then return false, "Lệnh không tồn tại" end
    if state.phase == "over" then return false, "Ván đã kết thúc" end
    if h.phase ~= state.phase then return false, "Chưa thể làm điều này lúc này" end
    local actor = Game.actor(state)
    if cmd.pid and cmd.pid ~= actor then return false, "Chưa tới lượt của bạn" end
    return h.check(state, cmd, actor)
end

function Game.apply(state, cmd)
    local ok, reason = Game.check(state, cmd)
    if not ok then error("lệnh không hợp lệ (" .. tostring(cmd.type) .. "): " .. tostring(reason), 2) end
    local pid = Game.actor(state)

    local rec = { pid = pid }
    for k, v in pairs(cmd) do rec[k] = v end
    state.history[#state.history + 1] = rec

    local events = {}
    local round, turn = state.round, state.turn
    H[cmd.type].apply(state, cmd, pid, events)
    for _, e in ipairs(events) do
        e.round, e.turn = round, turn
        state.log[#state.log + 1] = e
    end
    return events
end

function Game.legal(state)
    local actor = Game.actor(state)
    local out = {}
    if not actor then return out end
    local ph = state.phase

    if ph == "setup_hq" then
        for i in ipairs(state.map.starts) do
            if not state.takenStarts[i] then out[#out + 1] = { type = "placeHQ", pid = actor, start = i } end
        end
    elseif ph == "roll" then
        out[1] = { type = "roll", pid = actor }
    elseif ph == "rebel_move" then
        for _, t in ipairs(Rebel.legalSteps(state)) do
            out[#out + 1] = { type = "rebelStep", pid = actor, q = t.q, r = t.r }
        end
    elseif ph == "rebel_loss" then
        for _, k in ipairs(state.rebel.pending.options) do
            out[#out + 1] = { type = "chooseLoss", pid = actor, res = k }
        end
    elseif ph == "prompt" then
        for _, c in ipairs(state.prompt.options) do
            out[#out + 1] = { type = "respond", pid = actor, choice = c }
        end
    elseif ph == "action" then
        local p = state.players[actor]
        for _, give in ipairs(Resources.core) do
            if p.res[give.key] >= C.BANK_TRADE_RATE then
                for _, get in ipairs(Resources.core) do
                    if get.key ~= give.key then
                        out[#out + 1] = { type = "trade", pid = actor, give = give.key, get = get.key }
                    end
                end
            end
        end
        for _, t in ipairs(Territory.buyTargets(state, actor)) do
            if canAfford(p.res, Territory.buyTileCost(state, actor, t)) then
                out[#out + 1] = { type = "buyTile", pid = actor, q = t.q, r = t.r }
            end
        end
        if Territory.canUpgradeHQ(state, actor) and canAfford(p.res, C.HQ_UPGRADE_COST[p.hqLevel + 1]) then
            out[#out + 1] = { type = "upgradeHQ", pid = actor }
        end
        if canAfford(p.res, C.SUB_COST) then
            for _, t in ipairs(Territory.ownedTiles(state, actor)) do
                if Territory.canFoundSub(state, actor, t) then
                    out[#out + 1] = { type = "foundSub", pid = actor, q = t.q, r = t.r }
                end
            end
        end
        for _, t in ipairs(Territory.voteTargets(state, actor)) do
            out[#out + 1] = { type = "placeVote", pid = actor, q = t.q, r = t.r }
        end
        for _, b in ipairs(Buildings.list) do
            do
                for _, t in ipairs(Territory.ownedTiles(state, actor)) do
                    if buildCheck(state, actor, b.id, t) then
                        out[#out + 1] = { type = "build", pid = actor, id = b.id, q = t.q, r = t.r }
                    end
                end
            end
        end
        for _, b in ipairs(Structures.list(state)) do
            if b.owner == actor and not b.demolishing then
                local cost = upgradeCost(state, b)
                if cost and canAfford(p.res, cost) then
                    for _, o in ipairs(Construction.upgradeOptions(state, b.uid)) do
                        out[#out + 1] = { type = "upgrade", pid = actor, uid = b.uid, q = o.q, r = o.r, rot = o.rot }
                    end
                end
                out[#out + 1] = { type = "demolish", pid = actor, uid = b.uid }
            end
        end
        out[#out + 1] = { type = "endTurn", pid = actor }
    end
    return out
end

-- ─── Điểm, lưu / nạp, phát lại ──────────────────────────────────────────────

Game.score   = Scoring.score
Game.ranking = Scoring.ranking

local PHASES = { setup_hq = true, roll = true, rebel_move = true, rebel_loss = true, prompt = true,
                 action = true, over = true }

-- Migration: MIGRATIONS[v] đưa dữ liệu version v lên v+1 (chưa cần ở version 1).
local MIGRATIONS = {
    -- v1 -> v2 (D-013): thêm cấp HQ/Sub. Save cũ có 6 ô nhà đã là thực hữu nên vẫn hợp lệ.
    [1] = function(data)
        for _, p in ipairs(data.state.players or {}) do
            p.hqLevel = p.hqLevel or 1
            for _, sub in ipairs(p.subs or {}) do sub.level = sub.level or 1 end
        end
        data.version = 2
        return data
    end,
    -- v2 -> v3 (D-014): công trình theo uid + occupied, vật liệu, carry, units/roads/lostStrategic.
    [2] = function(data)
        local s = data.state
        local old, keys = s.buildings or {}, {}
        for k in pairs(old) do keys[#keys + 1] = k end
        table.sort(keys)
        s.buildings, s.occupied, s.nextUid = {}, {}, 1
        for _, k in ipairs(keys) do
            local b, uid = old[k], s.nextUid
            s.nextUid = uid + 1
            s.buildings[uid] = { uid = uid, id = b.id, level = b.level, owner = b.owner,
                                 tiles = { k }, anchor = k, rot = 0 }
            s.occupied[k] = uid
        end
        s.lostStrategic, s.units, s.roads = s.lostStrategic or {}, s.units or {}, s.roads or {}
        for _, p in ipairs(s.players or {}) do
            for _, r in ipairs(Resources.materials) do p.res[r.key] = p.res[r.key] or 0 end
            p.carry = p.carry or {}
        end
        data.version = 3
        return data
    end,
}

-- Chuỗi save: dữ liệu thuần có `version`, KHÔNG gồm bản đồ (sinh lại từ seed + số người).
function Game.save(state)
    return Serialize.dump({ version = C.SAVE_VERSION, state = State.snapshot(state) })
end

-- Nạp từ chuỗi. Trả state hoặc nil, lỗi. Kiểm tra hợp lệ trước khi dùng.
function Game.load(str)
    local data, err = Serialize.load(str)
    if not data then return nil, "không đọc được file save: " .. tostring(err) end
    if type(data) ~= "table" or type(data.version) ~= "number" then return nil, "file save thiếu version" end
    if data.version > C.SAVE_VERSION then return nil, "file save từ phiên bản mới hơn" end
    while data.version < C.SAVE_VERSION do
        local migrate = MIGRATIONS[data.version]
        if not migrate then return nil, "không có migration từ version " .. data.version end
        data = migrate(data)
    end

    local s = data.state
    if type(s) ~= "table" or type(s.players) ~= "table" or not PHASES[s.phase] then
        return nil, "dữ liệu save không hợp lệ"
    end
    local n = s.playerCount
    if type(n) ~= "number" or n < 1 or n > 4 or #s.players ~= n or type(s.rng) ~= "table" then
        return nil, "dữ liệu save không hợp lệ (người chơi)"
    end
    for _, t in ipairs({ "owner", "votes", "buildings", "occupied", "lostStrategic", "units", "roads",
                         "log", "history", "order" }) do
        if type(s[t]) ~= "table" then return nil, "dữ liệu save thiếu " .. t end
    end

    local ok, map = pcall(Mapgen.generate, { seed = s.seed, players = n })
    if not ok then return nil, "không dựng lại được bản đồ: " .. tostring(map) end
    s.map = map
    return State.restoreRng(s)
end

-- Chơi lại từ đầu bằng danh sách lệnh (state.history). Trả state.
function Game.replay(seed, players, history)
    local state = Game.new({ seed = seed, players = players })
    for _, cmd in ipairs(history) do Game.apply(state, cmd) end
    return state
end

return Game
