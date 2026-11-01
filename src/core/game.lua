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
-- Lệnh: placeHQ{start} · roll{hold?} · rebelStep{q,r} · chooseLoss{res} · trade{give,get} · placeVote{q,r} ·
--       buyTile{q,r} · upgradeHQ · foundSub{q,r} · build{id,q,r} · upgrade{uid,q,r,rot} · demolish{uid} ·
--       expelRebel · respond{choice} (phase prompt) · endTurn

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
local Units        = require("src.core.units")      -- bước upkeep đơn vị đăng ký ở đây
local Roads        = require("src.core.roads")
local Trade        = require("src.core.trade")
local Derived      = require("src.core.derived")
local Aura         = require("src.core.aura")
local Specials     = require("src.core.specials")
local DerivedData  = require("src.data.derived")
local SpecialsData = require("src.data.specials")
local Passives    = require("src.core.passives")   -- đăng ký bước upkeep thu nhập thụ động (sau bước dỡ)
local Upkeep      = require("src.core.upkeep")
local Territory   = require("src.core.territory")
local Rounds      = require("src.core.rounds")
local Hex         = require("src.core.hex")
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

local function isEventRound(state, round)
    return Rounds.isEventRound(state, round)
end

-- ─── Khởi tạo ───────────────────────────────────────────────────────────────

-- opts = { seed, players, rounds? }. rounds mặc định 10 x số người chơi (GDD 1.6 §11.3), phải là bội của ROUND_STEP.
function Game.new(opts)
    local players = opts.players
    local rounds = opts.rounds or Rounds.defaultFor(players)
    assert(Rounds.valid(rounds), "số vòng phải là bội của " .. C.ROUND_STEP .. ": " .. tostring(rounds))
    local map = Mapgen.generate({ seed = opts.seed, players = players })
    local state = State.new(map, players, opts.seed)
    state.rounds = rounds
    state.setupIdx, state.takenStarts, state.history = 1, {}, {}
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
    if state.expelMode then   -- Lệnh Đuổi Phiến Quân dùng giữa Khâu Hành Động: không lặp Khâu Giải Quyết (GDD 1.6 §6.2)
        state.expelMode = nil
    elseif state.turn == 1 and isEventRound(state, state.round) then
        events[#events + 1] = { kind = "global_event", stub = true }
    end
    state.phase = "action"
end

-- Thiên Đình S-05 (D-019): Phiến Quân vừa dừng trong aura của chủ Thiên Đình có đủ TN thì chủ được hỏi có trả TN để đẩy
-- Phiến Quân ra ngoài aura không. `holders` = { { pid, uid } }; hỏi lần lượt từng người, người từ chối thì tới người kế.
local function openPushPrompt(state, holders, events)
    local h = holders[1]
    local b = state.buildings[h.uid]
    local lv = Aura.levelDef(b)
    local cands = Specials.pushCandidates(state, b)
    local rest = {}
    for i = 2, #holders do rest[#rest + 1] = holders[i] end
    local prompt = { kind = "pushrebel", pid = h.pid, uid = h.uid, rest = rest, resume = "action", cost = lv.pushPay }
    if lv.pushChoose then          -- "+1": tự chọn ô; không thì ngẫu nhiên
        prompt.options = { "decline" }
        for _, t in ipairs(cands) do prompt.options[#prompt.options + 1] = key(t) end
    else
        prompt.options = { "push", "decline" }
        prompt.target = key(state.rng:pick(cands))
    end
    Game.openPrompt(state, prompt)
end

local function afterRebelStop(state, events)
    local holders = Specials.pushHolders(state)
    if #holders > 0 then openPushPrompt(state, holders, events) else resolution(state, events) end
end

local function settleRebel(state, events)
    local stage = Rebel.stage(state)
    if stage == "move" then state.phase = "rebel_move"
    elseif stage == "loss" then state.phase = "rebel_loss"
    else afterRebelStop(state, events) end
end

-- Phiến Quân hành động sau tổng 7: người đổ điều khiển.
local function runRebel(state, pid, events)
    local _, ev = Rebel.startMove(state, pid)
    for _, e in ipairs(ev) do events[#events + 1] = e end
    settleRebel(state, events)
end

-- Thiên Đình S-05: hủy tổng 7. `holders` = danh sách pid còn lượt hủy; hỏi lần lượt.
local function openCancel7Prompt(state, roller, holders)
    local rest = {}
    for i = 2, #holders do rest[#rest + 1] = holders[i] end
    Game.openPrompt(state, { kind = "cancel7", pid = holders[1], roller = roller, rest = rest, resume = "action",
                             options = { "cancel", "allow" } })
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
    if id == "B-05" then
        local okM, whyM = Construction.marketReach(state, pid, { tile })
        if not okM then return false, whyM end
    end
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
        -- tài nguyên khởi đầu = toàn bộ Tài Nguyên Cơ Bản của 6 ô quanh HQ, nhận 1 lần (GDD 1.6 §11.1 bước 8, D-020 #4)
        local gains = {}
        for _, n in ipairs(state.map:neighbors(hqTile)) do
            for res, amount in pairs(n.base or {}) do
                state.players[pid].res[res] = state.players[pid].res[res] + amount
                gains[res] = (gains[res] or 0) + amount
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

-- Sau khi xúc xắc đã chốt (kể cả sau đổ lại của Đài Khí Tượng): tổng 7 thì hủy/chạy Phiến Quân; không thì hỏi chủ ô Địa Linh
-- (mỗi viên Hex một lựa chọn) rồi sản xuất.
local finishRoll

local function produceAndResolve(state, pid, extras, events)
    for _, e in ipairs(Production.run(state, state.dice, pid, extras)) do events[#events + 1] = e end
    resolution(state, events)
end

-- Hỏi lần lượt các lựa chọn Địa Linh còn lại `choices[idx..]`; `extras` gom các lựa chọn đã có.
local function openLeyPrompt(state, pid, choices, idx, extras)
    local c = choices[idx]
    local options = { "skip" }
    for _, res in ipairs(c.options) do options[#options + 1] = res end
    Game.openPrompt(state, { kind = "ley", pid = c.pid, roller = pid, options = options, q = c.q, r = c.r,
                             choices = choices, idx = idx, extras = extras, resume = "action" })
end

finishRoll = function(state, pid, events)
    local dice = state.dice
    if Dice.isSeven(dice) then
        events[#events + 1] = { kind = "seven", pid = pid }
        local holders = Specials.cancel7Holders(state, pid)
        if #holders > 0 then openCancel7Prompt(state, pid, holders) else runRebel(state, pid, events) end
        return
    end
    local choices = Production.leyChoices(state, dice)
    if #choices > 0 then
        openLeyPrompt(state, pid, choices, 1, {})
    else
        produceAndResolve(state, pid, nil, events)
    end
end

H.roll = {
    phase = "roll",
    check = function(state, cmd, pid)
        if cmd.hold then
            if cmd.hold ~= 1 and cmd.hold ~= 2 then return false, "Chọn giữ viên 1 hoặc 2" end
            return Specials.checkHold(state, pid)   -- S-01 +2: giữ 1 viên, đổ lại viên còn lại
        end
        return true
    end,
    apply = function(state, cmd, pid, events)
        -- đầu Khâu Sản Xuất: đếm số lượt liên tiếp bị Phiến Quân quấy phá; hơn 3 lượt thì có Lệnh Đuổi (GDD 1.6 §6.2)
        local me = state.players[pid]
        if Rebel.harassed(state, pid) then me.harass = (me.harass or 0) + 1 else me.harass = 0 end
        if me.harass > C.REBEL_HARASS_BEFORE_EXPEL and not me.expelReady then
            me.expelReady = true
            events[#events + 1] = { kind = "expel_ready", pid = pid }
        elseif me.harass == 0 then
            me.expelReady = nil
        end
        for _, e in ipairs(Upkeep.startTurn(state, pid)) do events[#events + 1] = e end
        local dice = Dice.roll(state.rng)
        if cmd.hold then   -- Tháp S-01 +2: giữ viên `hold`, đổ lại viên còn lại (viên xem trước vẫn là 2 lần rút đầu)
            local other = cmd.hold == 1 and 2 or 1
            local old = dice[other]
            dice[other] = Dice.rollOne(state.rng)
            events[#events + 1] = { kind = "dice_hold", pid = pid, kept = cmd.hold, die = other, from = old, to = dice[other] }
        end
        state.dice = dice
        events[#events + 1] = { kind = "roll", pid = pid, dice = dice }
        local opts = Specials.rerollOptions(state, pid, dice)   -- Đài Khí Tượng S-04: đổ lại 1 viên / chọn mặt
        if opts then
            Game.openPrompt(state, { kind = "reroll", pid = pid, roller = pid, options = opts, resume = "action" })
        else
            finishRoll(state, pid, events)
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

-- Lệnh Đuổi Phiến Quân (GDD 1.6 §6.2): người bị quấy phá hơn 3 lượt liên tiếp đổ 1d6 điều khiển Phiến Quân như vừa ra 7,
-- không mất sản xuất của lượt. Dùng xong thì bộ đếm về 0.
H.expelRebel = {
    phase = "action",
    check = function(state, cmd, pid)
        local p = state.players[pid]
        if not p.expelReady then return false, "Chưa có Lệnh Đuổi Phiến Quân (cần bị quấy phá hơn " .. C.REBEL_HARASS_BEFORE_EXPEL .. " lượt liên tiếp)" end
        if not state.rebel then return false, "Không có Phiến Quân trên bản đồ" end
        return true
    end,
    apply = function(state, cmd, pid, events)
        local p = state.players[pid]
        p.harass, p.expelReady = 0, nil
        events[#events + 1] = { kind = "expel", pid = pid }
        state.expelMode = true
        runRebel(state, pid, events)
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
        local rate = Trade.bankRate(state, pid)
        if state.players[pid].res[cmd.give] < rate then
            return false, "Cần " .. rate .. " tài nguyên cùng loại để đổi"
        end
        return true
    end,
    apply = function(state, cmd, pid, events)
        local res = state.players[pid].res
        local rate = Trade.bankRate(state, pid)
        res[cmd.give] = res[cmd.give] - rate
        res[cmd.get] = res[cmd.get] + 1
        events[#events + 1] = { kind = "trade", pid = pid, give = cmd.give, get = cmd.get, rate = rate }
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
        if p.hqLevel >= 4 then Units.transformArmy(state, pid, events) end   -- HQ C4: Viễn Chinh thành Hiệp Sĩ
    end,
}

H.upgradeSub = {
    phase = "action",
    check = function(state, cmd, pid)
        local tile = state.map:get(cmd.q or 0, cmd.r or 0)
        local ok, why = Territory.canUpgradeSub(state, pid, tile)
        if not ok then return false, why end
        local level = Territory.subAt(state, pid, tile).level + 1
        if not canAfford(state.players[pid].res, C.SUB_UPGRADE_COST[level]) then
            return false, "Không đủ tài nguyên nâng cấp"
        end
        return true
    end,
    apply = function(state, cmd, pid, events)
        local tile = state.map:get(cmd.q, cmd.r)
        local sub = Territory.subAt(state, pid, tile)
        pay(state.players[pid].res, C.SUB_UPGRADE_COST[sub.level + 1])
        local level = Territory.upgradeSub(state, pid, tile)
        events[#events + 1] = { kind = "upgrade_sub", pid = pid, level = level, q = tile.q, r = tile.r }
    end,
}

-- ─── Công trình Đặc Biệt (D-019) ────────────────────────────────────────────

H.buildSpecial = {
    phase = "action",
    check = function(state, cmd, pid)
        local ok, why = Specials.checkBuild(state, pid, cmd.id, cmd.q, cmd.r, cmd.rot)
        if not ok then return false, why end
        if not canAfford(state.players[pid].res, Specials.def(cmd.id).levels[1].cost) then return false, "Không đủ tài nguyên" end
        return true
    end,
    apply = function(state, cmd, pid, events)
        pay(state.players[pid].res, Specials.def(cmd.id).levels[1].cost)
        local b = Specials.build(state, pid, cmd.id, cmd.q, cmd.r, cmd.rot)
        events[#events + 1] = { kind = "special_built", pid = pid, id = cmd.id, uid = b.uid, q = cmd.q, r = cmd.r }
    end,
}

H.upgradeSpecial = {
    phase = "action",
    check = function(state, cmd, pid)
        local b = state.buildings[cmd.uid]
        local ok, why = Specials.checkUpgrade(state, pid, b)
        if not ok then return false, why end
        if not canAfford(state.players[pid].res, Specials.upgradeCost(b)) then return false, "Không đủ tài nguyên" end
        return true
    end,
    apply = function(state, cmd, pid, events)
        local b = state.buildings[cmd.uid]
        pay(state.players[pid].res, Specials.upgradeCost(b))
        Specials.upgrade(state, b)
        local a = Structures.tilesOf(state, b)[1]
        events[#events + 1] = { kind = "special_upgrade", pid = pid, id = b.id, level = b.level, uid = b.uid, q = a.q, r = a.r }
    end,
}

H.fortressStrike = {
    phase = "action",
    check = function(state, cmd, pid) return Specials.checkStrike(state, pid, cmd.uid, cmd.target) end,
    apply = function(state, cmd, pid, events)
        for _, e in ipairs(Specials.strike(state, pid, cmd.uid, cmd.target)) do events[#events + 1] = e end
    end,
}

-- Hủy tổng 7 (S-05): hỏi lần lượt các chủ Thiên Đình còn lượt hủy. Hủy: người đổ nhận 1 TN, Phiến Quân không đi.
Game.prompts = Game.prompts or {}
Game.prompts.cancel7 = {
    check = function() return true end,
    apply = function(state, p, choice, events)
        if choice == "cancel" then
            state.players[p.pid].cancel7Used = (state.players[p.pid].cancel7Used or 0) + 1
            state.players[p.roller].res.faith = state.players[p.roller].res.faith + 1
            events[#events + 1] = { kind = "seven_cancelled", pid = p.pid, roller = p.roller }
            resolution(state, events)
        elseif #p.rest > 0 then
            openCancel7Prompt(state, p.roller, p.rest)
        else
            runRebel(state, p.roller, events)
        end
    end,
}

-- Đài Khí Tượng S-04 (GDD 1.6 §8.3): sau khi đổ, chủ được đổ lại 1 viên hoặc (+2) chọn mặt cho 1 viên; "keep" = giữ nguyên.
Game.prompts.reroll = {
    check = function() return true end,
    apply = function(state, p, choice, events)
        if choice ~= "keep" then
            for _, e in ipairs(Specials.applyReroll(state, p.pid, state.dice, choice)) do events[#events + 1] = e end
            events[#events + 1] = { kind = "roll", pid = p.roller, dice = state.dice, changed = true }
        end
        finishRoll(state, p.roller, events)
    end,
}

-- Địa Linh TN-12 (GDD 1.6 §3.4): mỗi viên Hex được chủ ô đổi thành một mặt tài nguyên mà ô (hoặc công trình trên ô) sản xuất.
Game.prompts.ley = {
    check = function() return true end,
    apply = function(state, p, choice, events)
        local extras = p.extras
        if choice ~= "skip" then
            extras[#extras + 1] = { q = p.q, r = p.r, res = choice }
            events[#events + 1] = { kind = "ley_choice", pid = p.pid, q = p.q, r = p.r, res = choice }
        end
        if p.idx < #p.choices then
            openLeyPrompt(state, p.roller, p.choices, p.idx + 1, extras)
        else
            produceAndResolve(state, p.roller, extras, events)
        end
    end,
}

-- Đẩy Phiến Quân (S-05): "push" = ô đã định sẵn ngẫu nhiên; hoặc tên ô "q,r" do chủ chọn (+1). Trả TN, dời Phiến Quân.
Game.prompts.pushrebel = {
    check = function(state, p, choice)
        if choice == "decline" then return true end
        local b = state.buildings[p.uid]
        if not b then return false, "Thiên Đình không còn" end
        if state.players[p.pid].res.faith < p.cost then return false, "Không đủ Tín Ngưỡng" end
        return true
    end,
    apply = function(state, p, choice, events)
        if choice == "decline" then
            if #p.rest > 0 then openPushPrompt(state, p.rest, events) else resolution(state, events) end
            return
        end
        local target = choice == "push" and p.target or choice
        local q, r = target:match("^(-?%d+),(-?%d+)$")
        local from = { q = state.rebel.q, r = state.rebel.r }
        state.players[p.pid].res.faith = state.players[p.pid].res.faith - p.cost
        local toll = Rebel.fortressToll(state, from, { q = tonumber(q), r = tonumber(r) })
        state.rebel.q, state.rebel.r = tonumber(q), tonumber(r)
        events[#events + 1] = { kind = "rebel_pushed", pid = p.pid, from = from, q = tonumber(q), r = tonumber(r), cost = p.cost }
        if toll then events[#events + 1] = toll end
        resolution(state, events)
    end,
}

-- Lập công trình Phái Sinh (D-018): a = uid công trình chủ, b = uid đối tác (D-05: did của Xưởng In Ấn),
-- q,r = ô riêng cho D-03 / D-05.
H.buildDerived = {
    phase = "action",
    check = function(state, cmd, pid)
        local def = Derived.def(cmd.id)
        if not def then return false, "Công trình Phái Sinh không tồn tại" end
        local tile = cmd.q and state.map:get(cmd.q, cmd.r) or nil
        local ok, why = Derived.checkBuild(state, pid, cmd.id, { a = cmd.a, b = cmd.b, tile = tile })
        if not ok then return false, why end
        if not canAfford(state.players[pid].res, def.cost) then return false, "Không đủ tài nguyên" end
        return true
    end,
    apply = function(state, cmd, pid, events)
        local def = Derived.def(cmd.id)
        pay(state.players[pid].res, def.cost)
        local tile = cmd.q and state.map:get(cmd.q, cmd.r) or nil
        local inst = Derived.build(state, pid, cmd.id, { a = cmd.a, b = cmd.b, tile = tile })
        local at = Structures.tilesOf(state, state.buildings[inst.a])[1]
        events[#events + 1] = { kind = "derived_built", pid = pid, id = cmd.id, did = inst.did, q = at.q, r = at.r }
    end,
}

-- Chuyển Vàng thành Tín Phiếu 1:1 (D-05 đang hoạt động): mỗi viên Vàng ra cho tối đa 2 Vàng (hạn mức dồn lại tới lượt của chủ),
-- tối đa BOND_MAX Tín Phiếu cùng lúc (GDD 1.6 §8.2).
H.convertBond = {
    phase = "action",
    check = function(state, cmd, pid)
        local p = state.players[pid]
        if type(cmd.n) ~= "number" or cmd.n < 1 or cmd.n ~= math.floor(cmd.n) then return false, "Số Vàng không hợp lệ" end
        if not Derived.hasBank(state, pid) then return false, "Cần Nhà Ngân Hàng đang hoạt động" end
        if (p.bondAllow or 0) < cmd.n then return false, "Chỉ chuyển được " .. (p.bondAllow or 0) .. " Vàng (cần ra mặt Vàng)" end
        if p.res.gold < cmd.n then return false, "Không đủ Vàng" end
        if p.res.bond + cmd.n > C.BOND_MAX then return false, "Tối đa " .. C.BOND_MAX .. " Tín Phiếu" end
        return true
    end,
    apply = function(state, cmd, pid, events)
        local p = state.players[pid]
        p.res.gold, p.res.bond, p.bondAllow = p.res.gold - cmd.n, p.res.bond + cmd.n, p.bondAllow - cmd.n
        events[#events + 1] = { kind = "bond_converted", pid = pid, n = cmd.n }
    end,
}

-- Đổi Tín Phiếu lấy Vàng (D-05 đang hoạt động).
H.redeemBond = {
    phase = "action",
    check = function(state, cmd, pid)
        if type(cmd.n) ~= "number" or cmd.n < 1 or cmd.n ~= math.floor(cmd.n) then return false, "Số Tín Phiếu không hợp lệ" end
        if state.players[pid].res.bond < cmd.n then return false, "Không đủ Tín Phiếu" end
        if not Derived.hasBank(state, pid) then return false, "Cần Nhà Ngân Hàng đang hoạt động" end
        return true
    end,
    apply = function(state, cmd, pid, events)
        local res = state.players[pid].res
        res.bond = res.bond - cmd.n
        res.gold = res.gold + cmd.n * C.BOND_REDEEM_GOLD
        events[#events + 1] = { kind = "bond_redeemed", pid = pid, n = cmd.n, gold = cmd.n * C.BOND_REDEEM_GOLD }
    end,
}

-- Lập Khu Trực Thuộc bằng đơn vị đứng trên ô thực hữu hợp lệ; đơn vị bị tiêu thụ (A-02, D-014).
H.foundSub = {
    phase = "action",
    check = function(state, cmd, pid)
        local ok, why = Units.checkFoundSub(state, pid, state.units[cmd.uid])
        if not ok then return false, why end
        if not canAfford(state.players[pid].res, C.SUB_COST) then
            return false, "Không đủ tài nguyên lập Khu Trực Thuộc"
        end
        return true
    end,
    apply = function(state, cmd, pid, events)
        local u = state.units[cmd.uid]
        local tile = Units.tileOf(state, u)
        pay(state.players[pid].res, C.SUB_COST)
        Units.remove(state, u.uid)
        Territory.addSub(state, pid, tile)
        events[#events + 1] = { kind = "found_sub", pid = pid, q = tile.q, r = tile.r, uid = u.uid }
    end,
}

H.buyUnit = {
    phase = "action",
    check = function(state, cmd, pid)
        local ok, why = Units.checkBuy(state, pid, cmd.unit, state.map:get(cmd.q or 0, cmd.r or 0))
        if not ok then return false, why end
        if not canAfford(state.players[pid].res, C.UNIT_COST[cmd.unit]) then
            return false, "Không đủ tài nguyên mua " .. Units.TYPES[cmd.unit].name
        end
        return true
    end,
    apply = function(state, cmd, pid, events)
        pay(state.players[pid].res, C.UNIT_COST[cmd.unit])
        local u = Units.spawn(state, pid, cmd.unit, state.map:get(cmd.q, cmd.r))
        events[#events + 1] = { kind = "unit_buy", pid = pid, uid = u.uid, unit = u.type, q = u.q, r = u.r }
    end,
}

H.moveUnit = {
    phase = "action",
    check = function(state, cmd, pid) return Units.checkMove(state, pid, state.units[cmd.uid], cmd.q, cmd.r) end,
    apply = function(state, cmd, pid, events)
        local u = state.units[cmd.uid]
        local from = { q = u.q, r = u.r }
        local cost, built, gold = Units.move(state, u, cmd.q, cmd.r)
        events[#events + 1] = { kind = "unit_move", pid = pid, uid = u.uid, unit = u.type, from = from,
                                q = u.q, r = u.r, cost = cost, left = u.mp, roads = #built, gold = gold }
    end,
}

-- Nâng Đường Đất lên Lát Đá: ô nằm trong lãnh thổ hoặc vùng ảnh hưởng của mình (D-016).
local function roadUpgradeCheck(state, pid, tile)
    if not tile then return false, "Không có ô này" end
    local road = Roads.get(state, tile)
    if not road then return false, "Ô này chưa có đường" end
    if road.level >= 2 then return false, "Đường đã là Lát Đá" end
    if state.owner[key(tile)] ~= pid and not Territory.inInfluence(state, pid, tile) then
        return false, "Chỉ nâng đường trong lãnh thổ hoặc vùng ảnh hưởng của bạn"
    end
    if not canAfford(state.players[pid].res, C.ROAD_UPGRADE_COST) then return false, "Không đủ tài nguyên nâng đường" end
    return true
end

Game.roadUpgradeCheck = roadUpgradeCheck

H.upgradeRoad = {
    phase = "action",
    check = function(state, cmd, pid) return roadUpgradeCheck(state, pid, state.map:get(cmd.q or 0, cmd.r or 0)) end,
    apply = function(state, cmd, pid, events)
        pay(state.players[pid].res, C.ROAD_UPGRADE_COST)
        state.roads[cmd.q .. "," .. cmd.r].level = 2
        events[#events + 1] = { kind = "road_upgrade", pid = pid, q = cmd.q, r = cmd.r }
    end,
}

-- Đề xuất trao đổi với người chơi khác (GDD §5.4): mở lời nhắc cho người nhận, người đề xuất chờ.
H.proposeTrade = {
    phase = "action",
    check = function(state, cmd, pid)
        local ok, why = Trade.check(state, pid, cmd.to, cmd.give, cmd.get)
        return ok, why
    end,
    apply = function(state, cmd, pid, events)
        local _, _, route = Trade.check(state, pid, cmd.to, cmd.give, cmd.get)
        events[#events + 1] = { kind = "trade_proposed", pid = pid, to = cmd.to, give = cmd.give, get = cmd.get, fee = route.fee }
        Game.openPrompt(state, { kind = "trade", pid = cmd.to, from = pid, give = cmd.give, get = cmd.get,
                                 fee = route.fee, options = { "accept", "decline" }, resume = "action" })
    end,
}

Game.prompts = Game.prompts or {}
Game.prompts.trade = {
    check = function(state, p, choice)
        if choice == "accept" then
            local ok, why = Trade.check(state, p.from, p.pid, p.give, p.get)
            if not ok then return false, why end
        end
        return true
    end,
    apply = function(state, p, choice, events)
        if choice == "accept" then
            local route = Trade.execute(state, p.from, p.pid, p.give, p.get)
            events[#events + 1] = { kind = "trade_accepted", pid = p.from, to = p.pid, give = p.give, get = p.get, fee = route.fee }
        else
            events[#events + 1] = { kind = "trade_declined", pid = p.from, to = p.pid }
        end
    end,
}

H.suppress = {
    phase = "action",
    check = function(state, cmd, pid)
        return Units.checkSuppress(state, pid, state.units[cmd.uid], cmd.dir, cmd.pay)
    end,
    apply = function(state, cmd, pid, events)
        for _, e in ipairs(Units.suppress(state, state.units[cmd.uid], cmd.dir, cmd.pay)) do events[#events + 1] = e end
    end,
}

H.garrison = {
    phase = "action",
    check = function(state, cmd, pid) return Units.checkGarrison(state, pid, state.units[cmd.uid]) end,
    apply = function(state, cmd, pid, events)
        local u = state.units[cmd.uid]
        Units.garrison(state, u)
        events[#events + 1] = { kind = "unit_garrison", pid = pid, uid = u.uid, q = u.q, r = u.r }
    end,
}

H.disband = {
    phase = "action",
    check = function(state, cmd, pid) return Units.checkDisband(state, pid, state.units[cmd.uid]) end,
    apply = function(state, cmd, pid, events)
        local u = state.units[cmd.uid]
        local refund = C.UNIT_DISBAND_REFUND[u.type] or 0
        state.players[pid].res.gold = state.players[pid].res.gold + refund
        Units.remove(state, u.uid)
        events[#events + 1] = { kind = "unit_disband", pid = pid, uid = u.uid, unit = u.type, q = u.q, r = u.r, refund = refund }
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
    if Aura.isSpecial(b) or b.id:sub(1, 2) == "D-" then return nil end   -- Đặc Biệt: lệnh upgradeSpecial; Phái Sinh: không nâng
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
Game.prompts = Game.prompts or {}

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
        if state.round > Rounds.total(state) then
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
        if Specials.checkHold(state, actor) then
            out[2] = { type = "roll", pid = actor, hold = 1 }
            out[3] = { type = "roll", pid = actor, hold = 2 }
        end
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
        local bankRate = Trade.bankRate(state, actor)
        for _, give in ipairs(Resources.core) do
            if p.res[give.key] >= bankRate then
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
        for _, sub in ipairs(p.subs) do
            local tile = state.map:get(sub.q, sub.r)
            if Territory.canUpgradeSub(state, actor, tile) and canAfford(p.res, C.SUB_UPGRADE_COST[sub.level + 1]) then
                out[#out + 1] = { type = "upgradeSub", pid = actor, q = sub.q, r = sub.r }
            end
        end
        for _, u in ipairs(Units.ownedBy(state, actor)) do
            if canAfford(p.res, C.SUB_COST) and Units.checkFoundSub(state, actor, u) then
                out[#out + 1] = { type = "foundSub", pid = actor, uid = u.uid }
            end
            if u.mp > 0 and not u.acted then
                local reach, dests = Units.reachable(state, u), {}
                for _, node in pairs(reach) do
                    if node.prev then dests[#dests + 1] = node.tile end   -- bỏ ô đang đứng
                end
                table.sort(dests, function(a, b) if a.r ~= b.r then return a.r < b.r end return a.q < b.q end)
                for _, t in ipairs(dests) do
                    if Units.checkMove(state, actor, u, t.q, t.r, reach) then   -- Giao Thương cần đủ Vàng xây đường
                        out[#out + 1] = { type = "moveUnit", pid = actor, uid = u.uid, q = t.q, r = t.r }
                    end
                end
            end
            if state.rebel and Hex.distance(u, state.rebel) == 1 and not u.acted then
                for dir = 1, 6 do
                    if Units.checkSuppress(state, actor, u, dir, false) then
                        out[#out + 1] = { type = "suppress", pid = actor, uid = u.uid, dir = dir, pay = false }
                        if Units.checkSuppress(state, actor, u, dir, true) then
                            out[#out + 1] = { type = "suppress", pid = actor, uid = u.uid, dir = dir, pay = true }
                        end
                    end
                end
            end
            if Units.checkGarrison(state, actor, u) then out[#out + 1] = { type = "garrison", pid = actor, uid = u.uid } end
            out[#out + 1] = { type = "disband", pid = actor, uid = u.uid }
        end
        if canAfford(p.res, C.EXPEDITION_COST) then
            for _, a in ipairs(Territory.anchors(state, actor)) do
                if Units.checkBuy(state, actor, "expedition", state.map:get(a.q, a.r)) then
                    out[#out + 1] = { type = "buyUnit", pid = actor, unit = "expedition", q = a.q, r = a.r }
                end
            end
        end
        if canAfford(p.res, C.UNIT_COST.trade) then
            local spawns = { state.map:get(p.hq.q, p.hq.r) }
            for _, m in ipairs(Trade.markets(state, actor)) do spawns[#spawns + 1] = Structures.tilesOf(state, m)[1] end
            for _, t in ipairs(spawns) do
                if Units.checkBuy(state, actor, "trade", t) then
                    out[#out + 1] = { type = "buyUnit", pid = actor, unit = "trade", q = t.q, r = t.r }
                end
            end
        end
        if canAfford(p.res, C.ROAD_UPGRADE_COST) then
            for _, t in ipairs(Roads.list(state)) do
                if roadUpgradeCheck(state, actor, t) then out[#out + 1] = { type = "upgradeRoad", pid = actor, q = t.q, r = t.r } end
            end
        end
        -- đề xuất trao đổi: chỉ liệt kê mẫu 1 đổi 1 (Game.check chấp nhận mọi số lượng hợp lệ)
        if #Trade.markets(state, actor) > 0 then
            for other = 1, state.playerCount do
                if other ~= actor and Trade.route(state, actor, other) then
                    for _, g in ipairs(Resources.core) do
                        for _, r in ipairs(Resources.core) do
                            if g.key ~= r.key and p.res[g.key] >= 1 and state.players[other].res[r.key] >= 1 then
                                local cmd = { type = "proposeTrade", pid = actor, to = other, give = { [g.key] = 1 }, get = { [r.key] = 1 } }
                                if Trade.check(state, actor, other, cmd.give, cmd.get) then out[#out + 1] = cmd end
                            end
                        end
                    end
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
        -- Phái Sinh: mỗi công trình chủ đủ cấp x loại x đối tác x (ô riêng)
        for _, b in ipairs(Structures.list(state)) do
            if b.owner == actor and not b.demolishing then
                for _, def in ipairs(DerivedData.list) do
                    if def.host[1] == b.id and b.level >= def.host[2] and canAfford(p.res, def.cost) then
                        local partners = Derived.partnerCandidates(state, actor, def.id, b.uid)
                        local sites = def.site and Derived.siteCandidates(state, actor, def.id, b.uid) or { false }
                        for _, other in ipairs(def.dep and partners or (def.partner and partners or { false })) do
                            for _, t in ipairs(sites) do
                                local cmd = { type = "buildDerived", pid = actor, id = def.id, a = b.uid, b = other or nil,
                                              q = t and t.q or nil, r = t and t.r or nil }
                                if Game.check(state, cmd) then out[#out + 1] = cmd end
                            end
                        end
                    end
                end
            end
        end
        -- Đặc Biệt: xây mới (đủ tài nguyên + HQ C3), nâng cấp +1/+2, "Pháo"
        for _, def in ipairs(SpecialsData.list) do
            if canAfford(p.res, def.levels[1].cost) then
                for _, pl in ipairs(Specials.placements(state, actor, def.id)) do
                    out[#out + 1] = { type = "buildSpecial", pid = actor, id = def.id, q = pl.q, r = pl.r, rot = pl.rot }
                end
            end
        end
        for _, b in ipairs(Structures.list(state)) do
            if b.owner == actor and Aura.isSpecial(b) then
                if Specials.checkUpgrade(state, actor, b) and canAfford(p.res, Specials.upgradeCost(b)) then
                    out[#out + 1] = { type = "upgradeSpecial", pid = actor, uid = b.uid }
                end
                if b.id == "S-02" and Aura.levelDef(b).strike then
                    for _, t in ipairs(Specials.strikeTargets(state, actor, b)) do
                        if Specials.checkStrike(state, actor, b.uid, t.uid) then
                            out[#out + 1] = { type = "fortressStrike", pid = actor, uid = b.uid, target = t.uid }
                        end
                    end
                end
            end
        end
        if p.res.bond >= 1 and Derived.hasBank(state, actor) then
            out[#out + 1] = { type = "redeemBond", pid = actor, n = p.res.bond }
        end
        if (p.bondAllow or 0) >= 1 and Derived.hasBank(state, actor) then
            local n = math.min(p.bondAllow, p.res.gold, C.BOND_MAX - p.res.bond)
            if n >= 1 then out[#out + 1] = { type = "convertBond", pid = actor, n = n } end
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
        if p.expelReady and state.rebel then out[#out + 1] = { type = "expelRebel", pid = actor } end
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
    -- v3 -> v4 (D-020, GDD 1.6): số vòng của ván (save cũ luôn là ván 20 vòng), bảng Phiến Quân đã cướp.
    -- Hiệp Sĩ còn sót được đổi về Viễn Chinh ở đầu lượt kế tiếp (Units.transformArmy khi KNIGHTS_ENABLED tắt).
    [3] = function(data)
        local s = data.state
        s.rounds = s.rounds or C.ROUNDS_REFERENCE
        s.plundered = s.plundered or {}
        for _, p in ipairs(s.players or {}) do p.harass = p.harass or 0 end
        data.version = 4
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
    -- trường thêm sau khi v3 ra đời (save v3 cũ của các phase trước): bù mặc định
    s.derived = s.derived or {}
    s.nextDerivedUid = s.nextDerivedUid or 1
    s.nextUnitUid = s.nextUnitUid or 1
    s.plundered = s.plundered or {}
    s.rounds = s.rounds or C.ROUNDS_REFERENCE
    return State.restoreRng(s)
end

-- Chơi lại từ đầu bằng danh sách lệnh (state.history). `rounds` nil = mặc định theo số người. Trả state.
function Game.replay(seed, players, history, rounds)
    local state = Game.new({ seed = seed, players = players, rounds = rounds })
    for _, cmd in ipairs(history) do Game.apply(state, cmd) end
    return state
end

return Game
