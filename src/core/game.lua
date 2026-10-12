-- Luật chơi: máy trạng thái ván + lệnh (command). Thuần Lua, không gọi love.*.
-- Mọi thay đổi trạng thái đi qua Game.check / Game.apply (D-011), nên UI, mô phỏng test, AI
-- và multiplayer dùng chung một API.
--
--   Game.new{seed, players}        -> state (phase "setup_hq")
--   Game.actor(state)              -> pid phải ra lệnh (nil khi ván kết thúc)
--   Game.check(state, cmd)         -> ok, lý do (tiếng Việt, cho tooltip)
--   Game.apply(state, cmd)         -> events (cho log/UI); lệnh sai thì báo lỗi
--   Game.legal(state)              -> danh sách lệnh hợp lệ của Game.actor (cho sim/AI/nút)
--   Game.price(state, pid, kind, a, b) -> giá duy nhất của mọi thứ mua/nâng (lệnh, UI, legal đều dùng)
--
-- Pha: setup_hq -> [roll -> (rebel_move -> rebel_loss?) -> action] x lượt x 20 vòng -> over.
--   Đầu lượt chạy Upkeep (src/core/upkeep.lua) trước khi đổ xúc xắc.
--   Pha prompt: hỏi người khác giữa lượt (Game.openPrompt, trả lời bằng respond, registry Game.prompts).
-- Lệnh (H[type] = { phase, check, apply }): placeHQ · roll · rebelStep · chooseLoss · trade · buyTile ·
--   upgradeHQ · upgradeSub · buildSpecial · upgradeSpecial · fortressStrike · buildDerived · redeemBond ·
--   foundSub · buyUnit · moveUnit · upgradeRoad · proposeTrade · suppress · garrison · disband · placeVote ·
--   build · upgrade · demolish · respond · endTurn
-- Tài nguyên đi qua Wallet (pay / gain), không ghi thẳng vào bảng res.

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
local Units        = require("src.core.units")
local Roads        = require("src.core.roads")
local Trade        = require("src.core.trade")
local Derived      = require("src.core.derived")
local Aura         = require("src.core.aura")
local Specials     = require("src.core.specials")
local DerivedData  = require("src.data.derived")
local SpecialsData = require("src.data.specials")
local Passives    = require("src.core.passives")
local Upkeep      = require("src.core.upkeep")
local Territory   = require("src.core.territory")
local Hex         = require("src.core.hex")
local Buildings   = require("src.data.buildings")
local Terrains    = require("src.data.terrains")
local Resources   = require("src.data.resources")
local Wallet      = require("src.core.wallet")
local Invariants  = require("src.core.invariants")

local Game = {}
-- Registry lời nhắc của pha prompt: Game.prompts[kind] = { check, apply } (xem Game.openPrompt).
Game.prompts = {}
local key = State.key

local CORE = {}
for _, r in ipairs(Resources.core) do CORE[r.key] = true end

-- ─── Tiện ích ───────────────────────────────────────────────────────────────

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
    for pid = 1, players do
        for k, v in pairs(C.STARTING_RESOURCES) do state.players[pid].res[k] = v end   -- wallet:ok khởi tạo ván
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

-- Giá thực tế của mọi lần mua: nơi DUY NHẤT core và UI lấy giá (check, apply, legal, nút bấm). Trả bảng chi phí,
-- nil nếu không có giá (đã tối đa...). Hiệu ứng làm đổi giá (địa hình, TN, sau này Tech/nhân vật/Sắc Lệnh) cắm ở đây.
--   "build" (id, tile) · "upgrade" (b) · "buyTile" (tile) · "hq" · "sub" (cấp mới) · "foundSub" · "unit" (loại)
--   "road" · "special" (id) · "specialUp" (b) · "derived" (id)
function Game.price(state, pid, kind, a, b)
    if kind == "build" then return Construction.cost(state, a, 1, b)
    elseif kind == "upgrade" then return Game.upgradeCost(state, a)
    elseif kind == "buyTile" then return Territory.buyTileCost(state, pid, a)
    elseif kind == "hq" then return C.HQ_UPGRADE_COST[state.players[pid].hqLevel + 1]
    elseif kind == "sub" then return C.SUB_UPGRADE_COST[a]
    elseif kind == "foundSub" then return C.SUB_COST
    elseif kind == "unit" then return C.UNIT_COST[a]
    elseif kind == "road" then return C.ROAD_UPGRADE_COST
    elseif kind == "special" then return Specials.def(a).levels[1].cost
    elseif kind == "specialUp" then return Specials.upgradeCost(a)
    elseif kind == "derived" then return Derived.def(a).cost
    end
    error("Game.price: loại giá không có: " .. tostring(kind))
end

-- `pid` đủ tiền trả giá Game.price(...) chưa? (cho nút UI và check).
function Game.afford(state, pid, kind, a, b)
    local cost = Game.price(state, pid, kind, a, b)
    return cost ~= nil and Wallet.canAfford(state.players[pid].res, cost)
end

-- Nút "Xây" (chưa chọn ô): sáng nếu có ô thực hữu nào mà giá thực trên ô đó trả nổi (giá đổi theo địa hình / TN).
function Game.affordBuild(state, pid, id)
    for _, t in ipairs(Territory.ownedTiles(state, pid)) do
        if Game.afford(state, pid, "build", id, t) then return true end
    end
    return false
end

local function buildCost(state, pid, id, tile) return Game.price(state, pid, "build", id, tile) end

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
    if not Game.afford(state, pid, "build", id, tile) then return false, "Không đủ tài nguyên" end
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
                Wallet.gain(state.players[pid].res, res, C.START_BONUS_PER_TILE)
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
    check = function(state, cmd, pid)
        if cmd.broadcast then return Specials.checkBroadcast(state, pid) end   -- S-04 +2 "Phát Sóng"
        return true
    end,
    apply = function(state, cmd, pid, events)
        for _, e in ipairs(Upkeep.startTurn(state, pid)) do events[#events + 1] = e end
        local dice = Dice.roll(state.rng)
        if cmd.broadcast then   -- cả hai viên thành mặt cao hơn của viên đã đổ
            local m = math.max(dice[1], dice[2])
            dice = { m, m }
            state.players[pid].broadcastRound = state.round
            events[#events + 1] = { kind = "broadcast", pid = pid, face = m }
        end
        state.dice = dice
        events[#events + 1] = { kind = "roll", pid = pid, dice = dice }
        if Dice.isSeven(dice) then
            events[#events + 1] = { kind = "seven", pid = pid }
            local holders = Specials.cancel7Holders(state, pid)
            if #holders > 0 then
                openCancel7Prompt(state, pid, holders)
            else
                runRebel(state, pid, events)
            end
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
        local rate = Trade.bankRate(state, pid)
        if state.players[pid].res[cmd.give] < rate then
            return false, "Cần " .. rate .. " tài nguyên cùng loại để đổi"
        end
        return true
    end,
    apply = function(state, cmd, pid, events)
        local res = state.players[pid].res
        local rate = Trade.bankRate(state, pid)
        Wallet.pay(res, { [cmd.give] = rate })
        Wallet.gain(res, cmd.get, 1)
        events[#events + 1] = { kind = "trade", pid = pid, give = cmd.give, get = cmd.get, rate = rate }
    end,
}

H.buyTile = {
    phase = "action",
    check = function(state, cmd, pid)
        local tile = state.map:get(cmd.q, cmd.r)
        local ok, why = Territory.canBuyTile(state, pid, tile)
        if not ok then return false, why end
        if not Game.afford(state, pid, "buyTile", tile) then
            return false, "Không đủ tài nguyên mua ô"
        end
        return true
    end,
    apply = function(state, cmd, pid, events)
        local tile = state.map:get(cmd.q, cmd.r)
        Wallet.pay(state.players[pid].res, Game.price(state, pid, "buyTile", tile))
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
        if not Game.afford(state, pid, "hq") then
            return false, "Không đủ tài nguyên nâng cấp"
        end
        return true
    end,
    apply = function(state, cmd, pid, events)
        local p = state.players[pid]
        Wallet.pay(p.res, Game.price(state, pid, "hq"))
        Territory.upgradeHQ(state, pid)
        events[#events + 1] = { kind = "upgrade_hq", pid = pid, level = p.hqLevel, q = p.hq.q, r = p.hq.r }
        if p.hqLevel >= C.HQ_KNIGHT_LEVEL then Units.transformArmy(state, pid, events) end   -- HQ C4: Viễn Chinh thành Hiệp Sĩ
    end,
}

H.upgradeSub = {
    phase = "action",
    check = function(state, cmd, pid)
        local tile = state.map:get(cmd.q or 0, cmd.r or 0)
        local ok, why = Territory.canUpgradeSub(state, pid, tile)
        if not ok then return false, why end
        local level = Territory.subAt(state, pid, tile).level + 1
        if not Game.afford(state, pid, "sub", level) then
            return false, "Không đủ tài nguyên nâng cấp"
        end
        return true
    end,
    apply = function(state, cmd, pid, events)
        local tile = state.map:get(cmd.q, cmd.r)
        local sub = Territory.subAt(state, pid, tile)
        Wallet.pay(state.players[pid].res, Game.price(state, pid, "sub", sub.level + 1))
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
        if not Game.afford(state, pid, "special", cmd.id) then return false, "Không đủ tài nguyên" end
        return true
    end,
    apply = function(state, cmd, pid, events)
        Wallet.pay(state.players[pid].res, Game.price(state, pid, "special", cmd.id))
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
        if not Game.afford(state, pid, "specialUp", b) then return false, "Không đủ tài nguyên" end
        return true
    end,
    apply = function(state, cmd, pid, events)
        local b = state.buildings[cmd.uid]
        Wallet.pay(state.players[pid].res, Game.price(state, pid, "specialUp", b))
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
Game.prompts.cancel7 = {
    check = function() return true end,
    apply = function(state, p, choice, events)
        if choice == "cancel" then
            state.players[p.pid].cancel7Used = state.players[p.pid].cancel7Used + 1
            Wallet.gain(state.players[p.roller].res, "faith", C.SEVEN_CANCEL_FAITH)
            events[#events + 1] = { kind = "seven_cancelled", pid = p.pid, roller = p.roller }
            resolution(state, events)
        elseif #p.rest > 0 then
            openCancel7Prompt(state, p.roller, p.rest)
        else
            runRebel(state, p.roller, events)
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
        local q, r = Hex.unkey(target)
        Wallet.pay(state.players[p.pid].res, { faith = p.cost })
        local from = Rebel.moveTo(state, q, r)
        events[#events + 1] = { kind = "rebel_pushed", pid = p.pid, from = from, q = q, r = r, cost = p.cost }
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
        if not Game.afford(state, pid, "derived", cmd.id) then return false, "Không đủ tài nguyên" end
        return true
    end,
    apply = function(state, cmd, pid, events)
        local def = Derived.def(cmd.id)
        Wallet.pay(state.players[pid].res, Game.price(state, pid, "derived", cmd.id))
        local tile = cmd.q and state.map:get(cmd.q, cmd.r) or nil
        local inst = Derived.build(state, pid, cmd.id, { a = cmd.a, b = cmd.b, tile = tile })
        local at = Structures.tilesOf(state, state.buildings[inst.a])[1]
        events[#events + 1] = { kind = "derived_built", pid = pid, id = cmd.id, did = inst.did, q = at.q, r = at.r }
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
        Wallet.pay(res, { bond = cmd.n })
        Wallet.gain(res, "gold", cmd.n * C.BOND_REDEEM_GOLD)
        events[#events + 1] = { kind = "bond_redeemed", pid = pid, n = cmd.n, gold = cmd.n * C.BOND_REDEEM_GOLD }
    end,
}

-- Lập Khu Trực Thuộc bằng đơn vị đứng trên ô thực hữu hợp lệ; đơn vị bị tiêu thụ (A-02, D-014).
H.foundSub = {
    phase = "action",
    check = function(state, cmd, pid)
        local ok, why = Units.checkFoundSub(state, pid, state.units[cmd.uid])
        if not ok then return false, why end
        if not Game.afford(state, pid, "foundSub") then
            return false, "Không đủ tài nguyên lập Khu Trực Thuộc"
        end
        return true
    end,
    apply = function(state, cmd, pid, events)
        local u = state.units[cmd.uid]
        local tile = Units.tileOf(state, u)
        Wallet.pay(state.players[pid].res, Game.price(state, pid, "foundSub"))
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
        if not Game.afford(state, pid, "unit", cmd.unit) then
            return false, "Không đủ tài nguyên mua " .. Units.TYPES[cmd.unit].name
        end
        return true
    end,
    apply = function(state, cmd, pid, events)
        Wallet.pay(state.players[pid].res, Game.price(state, pid, "unit", cmd.unit))
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
    if road.level >= C.ROAD_STONE_LEVEL then return false, "Đường đã là Lát Đá" end
    if state.owner[key(tile)] ~= pid and not Territory.inInfluence(state, pid, tile) then
        return false, "Chỉ nâng đường trong lãnh thổ hoặc vùng ảnh hưởng của bạn"
    end
    if not Game.afford(state, pid, "road") then return false, "Không đủ tài nguyên nâng đường" end
    return true
end

Game.roadUpgradeCheck = roadUpgradeCheck

H.upgradeRoad = {
    phase = "action",
    check = function(state, cmd, pid) return roadUpgradeCheck(state, pid, state.map:get(cmd.q or 0, cmd.r or 0)) end,
    apply = function(state, cmd, pid, events)
        Wallet.pay(state.players[pid].res, Game.price(state, pid, "road"))
        Roads.upgrade(state, state.map:get(cmd.q, cmd.r))
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
        Wallet.gain(state.players[pid].res, "gold", refund)
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
        Wallet.pay(state.players[pid].res, Game.price(state, pid, "build", cmd.id, tile))
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
    if not Game.afford(state, pid, "upgrade", b) then return false, "Không đủ tài nguyên" end
    return true
end

Game.upgradeCost = upgradeCost
Game.upgradeCheck = upgradeCheck

H.upgrade = {
    phase = "action",
    check = function(state, cmd, pid) return upgradeCheck(state, pid, cmd) end,
    apply = function(state, cmd, pid, events)
        local b = state.buildings[cmd.uid]
        Wallet.pay(state.players[pid].res, Game.price(state, pid, "upgrade", b))
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
        state.prompt = false
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
    if type(cmd) ~= "table" then return false, "Lệnh phải là một bảng" end
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
        if Specials.checkBroadcast(state, actor) then out[2] = { type = "roll", pid = actor, broadcast = true } end
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
            if Game.afford(state, actor, "buyTile", t) then
                out[#out + 1] = { type = "buyTile", pid = actor, q = t.q, r = t.r }
            end
        end
        if Territory.canUpgradeHQ(state, actor) and Game.afford(state, actor, "hq") then
            out[#out + 1] = { type = "upgradeHQ", pid = actor }
        end
        for _, sub in ipairs(p.subs) do
            local tile = state.map:get(sub.q, sub.r)
            if Territory.canUpgradeSub(state, actor, tile) and Game.afford(state, actor, "sub", sub.level + 1) then
                out[#out + 1] = { type = "upgradeSub", pid = actor, q = sub.q, r = sub.r }
            end
        end
        for _, u in ipairs(Units.ownedBy(state, actor)) do
            if Game.afford(state, actor, "foundSub") and Units.checkFoundSub(state, actor, u) then
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
        if Game.afford(state, actor, "unit", "expedition") then
            for _, a in ipairs(Territory.anchors(state, actor)) do
                if Units.checkBuy(state, actor, "expedition", state.map:get(a.q, a.r)) then
                    out[#out + 1] = { type = "buyUnit", pid = actor, unit = "expedition", q = a.q, r = a.r }
                end
            end
        end
        if Game.afford(state, actor, "unit", "trade") then
            local spawns = { state.map:get(p.hq.q, p.hq.r) }
            for _, m in ipairs(Trade.markets(state, actor)) do spawns[#spawns + 1] = Structures.tilesOf(state, m)[1] end
            for _, t in ipairs(spawns) do
                if Units.checkBuy(state, actor, "trade", t) then
                    out[#out + 1] = { type = "buyUnit", pid = actor, unit = "trade", q = t.q, r = t.r }
                end
            end
        end
        if Game.afford(state, actor, "road") then
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
                    if def.host[1] == b.id and b.level >= def.host[2] and Game.afford(state, actor, "derived", def.id) then
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
            if Game.afford(state, actor, "special", def.id) then
                for _, pl in ipairs(Specials.placements(state, actor, def.id)) do
                    out[#out + 1] = { type = "buildSpecial", pid = actor, id = def.id, q = pl.q, r = pl.r, rot = pl.rot }
                end
            end
        end
        for _, b in ipairs(Structures.list(state)) do
            if b.owner == actor and Aura.isSpecial(b) then
                if Specials.checkUpgrade(state, actor, b) and Game.afford(state, actor, "specialUp", b) then
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
        for _, b in ipairs(Structures.list(state)) do
            if b.owner == actor and not b.demolishing then
                if Game.afford(state, actor, "upgrade", b) then
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

-- Migration: MIGRATIONS[v] đưa dữ liệu version v lên v+1. Mỗi lần đổi hình dạng state = tăng C.SAVE_VERSION + thêm một bước ở đây
-- (và khai trường mới trong State.new). Chỉ migration mới được vá trường thiếu; Game.load không vá gì ngoài việc chạy chuỗi này.
-- Save fixture của từng version nằm ở tests/fixtures/saves (tests/save_spec.lua).
local MIGRATIONS = {
    -- v1 -> v2 (D-013): thêm cấp HQ/Sub. Save cũ có 6 ô nhà đã là thực hữu nên vẫn hợp lệ; nhưng v2 đòi mọi ô thực hữu ngoài ô
    -- HQ/Sub phải có phiếu >= ngưỡng (Sim.invariants), còn 6 ô nhà của v1 chưa từng có phiếu. Ô nhà kề HQ (ngưỡng 1) nên điền 1
    -- phiếu cho chủ ô; chỉ điền cho ô thực hữu chưa có phiếu nào của chủ, nên ô đã mua bằng phiếu giữ nguyên.
    [1] = function(data)
        local st = data.state
        local hqKey = {}
        for pid, p in ipairs(st.players or {}) do
            if p.hq then hqKey[Hex.key(p.hq)] = true end
        end
        for k, pid in pairs(st.owner or {}) do
            if not hqKey[k] then
                st.votes[k] = st.votes[k] or {}
                if (st.votes[k][pid] or 0) == 0 then st.votes[k][pid] = 1 end
            end
        end
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
        s.lostStrategic, s.units, s.roads = s.lostStrategic or {}, s.units or {}, s.roads or {}   -- units:ok roads:ok migration
        for _, p in ipairs(s.players or {}) do
            for _, r in ipairs(Resources.materials) do p.res[r.key] = p.res[r.key] or 0 end   -- wallet:ok migration
            p.carry = p.carry or {}
        end
        data.version = 3
        return data
    end,
    -- v3 -> v4 (M2b-1): State.new khai đủ trường. "v3" từng có nhiều hình dạng (save v3 sớm thiếu derived / nextDerivedUid /
    -- nextUnitUid; các cờ theo người chơi và rebel / dice / prompt sinh lười, nil trong file). Mọi thứ thiếu được điền giá trị trống
    -- đúng như State.new: false cho "chưa có", 0 cho bộ đếm. Không đổi luật: cờ false và nil cùng nghĩa "chưa từng".
    [3] = function(data)
        local s = data.state
        s.derived, s.nextDerivedUid, s.nextUnitUid = s.derived or {}, s.nextDerivedUid or 1, s.nextUnitUid or 1   -- units:ok migration
        for _, k in ipairs({ "rebel", "dice", "prompt" }) do
            if s[k] == nil then s[k] = false end
        end
        for _, p in ipairs(s.players or {}) do
            if p.hq == nil then p.hq = false end
            for _, k in ipairs({ "strikeRound", "broadcastRound", "knightRetreatRound" }) do
                if p[k] == nil then p[k] = false end
            end
            if p.cancel7Used == nil then p.cancel7Used = 0 end
        end
        data.version = 4
        return data
    end,
}

-- Chuỗi save: dữ liệu thuần có `version`, KHÔNG gồm bản đồ (sinh lại từ seed + số người).
function Game.save(state)
    return Serialize.dump({ version = C.SAVE_VERSION, state = State.snapshot(state) })
end

-- Nạp từ chuỗi. Trả state, hoặc nil, lý do (dữ liệu hỏng không bao giờ ném lỗi hay trả state méo): đọc, chạy chuỗi
-- migration lên C.SAVE_VERSION, kiểm tra hình dạng, dựng lại bản đồ từ (seed, players), rồi kiểm tra bất biến.
function Game.load(str)
    local data, err = Serialize.load(str)
    if not data then return nil, "không đọc được file save: " .. tostring(err) end
    if type(data) ~= "table" or type(data.version) ~= "number" then return nil, "file save thiếu version" end
    if data.version > C.SAVE_VERSION then return nil, "file save từ phiên bản mới hơn" end
    if type(data.state) ~= "table" then return nil, "file save thiếu state" end
    while data.version < C.SAVE_VERSION do
        local migrate = MIGRATIONS[data.version]
        if not migrate then return nil, "không có migration từ version " .. data.version end
        local ok, res = pcall(migrate, data)
        if not ok then return nil, "migration từ version " .. data.version .. " lỗi: " .. tostring(res) end
        data = res
    end

    local s = data.state
    local good, why = Invariants.shape(s)
    if not good then return nil, "dữ liệu save không hợp lệ: " .. tostring(why) end
    local ok, map = pcall(Mapgen.generate, { seed = s.seed, players = s.playerCount })
    if not ok then return nil, "không dựng lại được bản đồ: " .. tostring(map) end
    s.map = map
    State.restoreRng(s)
    local checked, valid, msg = pcall(Invariants.check, s)
    if not checked then return nil, "dữ liệu save không hợp lệ: " .. tostring(valid) end
    if not valid then return nil, "dữ liệu save vi phạm bất biến: " .. tostring(msg) end
    return s
end

-- Chơi lại từ đầu bằng danh sách lệnh (state.history). Trả state.
function Game.replay(seed, players, history)
    local state = Game.new({ seed = seed, players = players })
    for _, cmd in ipairs(history) do Game.apply(state, cmd) end
    return state
end

return Game
