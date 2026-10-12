-- Đơn vị di động: Viễn Chinh U-01 (M1.5 phase D), sau này Hiệp Sĩ U-01K và Giao Thương U-02. D-015.
-- Thuần Lua, không gọi love.*.
--
--   state.units[uid] = { uid, type = "expedition" | "knight" | "trade", owner, q, r,
--                        mp = điểm di chuyển còn lại, acted = đã dùng hành động của lượt,
--                        garrison = đang Trú Đóng, recentGarrison = lượt trước đã Trú Đóng }
--
-- Module này chứa luật kiểm tra / áp dụng; Game.check/apply gọi vào đây (thanh toán nằm ở game.lua).
-- Đơn vị đi xuyên nhau, không chiếm ô, không chặn xây dựng (Data nguyên tắc 1).

local C          = require("src.config.constants")
local Wallet = require("src.core.wallet")
local Dice       = require("src.core.dice")
local Hex        = require("src.core.hex")
local Aura       = require("src.core.aura")
local Rebel      = require("src.core.rebel")
local Roads      = require("src.core.roads")
local State      = require("src.core.state")
local Structures = require("src.core.structures")
local Territory  = require("src.core.territory")
local Upkeep     = require("src.core.upkeep")
local Movement   = require("src.data.movement")
local Strategic  = require("src.data.strategic")

local U = {}

local key = State.key
local INF = math.huge

-- Loại đơn vị -> khóa bảng chi phí di chuyển, bước cơ bản, quota dùng chung.
U.TYPES = {
    expedition = { move = "expedition", base = "EXPEDITION_BASE_MOVE", quota = "expedition", name = "Viễn Chinh" },
    knight     = { move = "knight",     base = "KNIGHT_BASE_MOVE",     quota = "expedition", name = "Hiệp Sĩ" },
    trade      = { move = "trade",      base = "TRADE_BASE_MOVE",      quota = "trade",      name = "Giao Thương" },
}

local MOUNTAIN = { ["DH-03"] = true, ["DH-12"] = true }
local HILLS    = "DH-09"

-- ─── Truy vấn ───────────────────────────────────────────────────────────────

function U.tileOf(state, u) return state.map:get(u.q, u.r) end

-- Đơn vị theo thứ tự uid (duyệt tất định).
function U.list(state)
    local out = {}
    for _, u in pairs(state.units) do out[#out + 1] = u end
    table.sort(out, function(a, b) return a.uid < b.uid end)
    return out
end

function U.ownedBy(state, pid)
    local out = {}
    for _, u in ipairs(U.list(state)) do
        if u.owner == pid then out[#out + 1] = u end
    end
    return out
end

function U.at(state, tile)
    local out = {}
    for _, u in ipairs(U.list(state)) do
        if u.q == tile.q and u.r == tile.r then out[#out + 1] = u end
    end
    return out
end

-- Số đơn vị của `pid` tính vào quota `quota` ("expedition" | "trade").
function U.quotaCount(state, pid, quota)
    local n = 0
    for _, u in pairs(state.units) do
        if u.owner == pid and U.TYPES[u.type].quota == quota then n = n + 1 end
    end
    return n
end

local QUOTA_MAX = { expedition = "MAX_EXPEDITION_PER_PLAYER", trade = "MAX_TRADE_PER_PLAYER" }

function U.quotaMax(quota) return C[QUOTA_MAX[quota]] end

-- ─── Di chuyển ──────────────────────────────────────────────────────────────

-- Điểm di chuyển đầu lượt: bước cơ bản; TN-04 Ngựa +2 nếu đơn vị đứng trên ô Ngựa và có HQ/Sub của chủ
-- trong bán kính TN04_HOME_RADIUS (D-015).
function U.baseMove(state, u)
    local mp = C[U.TYPES[u.type].base]
    local tile = U.tileOf(state, u)
    if tile then
        local tn = Structures.strategicAt(state, tile)
        if tn == "TN-04" and u.type ~= "trade" then
            if Territory.distanceToAnchor(state, u.owner, tile) <= C.TN04_HOME_RADIUS then mp = mp + C.TN04_BONUS_MOVE end
        elseif tn == Strategic.HARBOR and u.type == "trade" then
            mp = mp + C.TN10_BONUS_MOVE
        end
        if Roads.isStone(state, tile) then mp = mp + C.STONE_ROAD_START_BONUS end
    end
    return mp
end

-- Chi phí để đơn vị `u` đi vào `tile`. Có đường: giảm ROAD_STEP_REDUCTION (tối thiểu 1). TN-11 Gió Mạnh giảm
-- thêm TN11_STEP_REFUND (tối thiểu 0, không áp cho Giao Thương).
function U.stepCost(state, u, tile)
    local c = Movement.stepCost(U.TYPES[u.type].move, tile.terrain, state.round)
    if c == INF then return INF end
    if Roads.has(state, tile) then c = math.max(1, c - C.ROAD_STEP_REDUCTION) end
    if Structures.strategicAt(state, tile) == "TN-11" and u.type ~= "trade" then
        c = math.max(0, c - C.TN11_STEP_REFUND)
    end
    -- aura Pháo Đài S-02 của đối thủ: đơn vị quân sự vào ô trong aura tốn thêm `speed` điểm (D-019)
    if u.type ~= "trade" then
        local f = Aura.fortressAt(state, tile, u.owner)
        if f then c = c + Aura.levelDef(f).speed end
    end
    return c
end

-- Ô nằm trong aura "chặn đứng" (Pháo Đài +1 trở lên) của đối thủ: vào rồi là hết điểm di chuyển.
local function stallsUnit(state, u, tile)
    if u.type == "trade" then return false end
    local f = Aura.fortressAt(state, tile, u.owner)
    return f ~= nil and Aura.levelDef(f).stall == true
end

-- Dijkstra trong ngân sách `u.mp`. Trả { [key] = { tile, cost, prev = key|nil } } gồm cả ô đang đứng (cost 0).
function U.reachable(state, u)
    local start = U.tileOf(state, u)
    local best = { [key(start)] = { tile = start, cost = 0 } }
    local open, closed = { key(start) }, {}
    while #open > 0 do
        local bi = 1
        for i = 2, #open do
            if best[open[i]].cost < best[open[bi]].cost then bi = i end
        end
        local k = table.remove(open, bi)
        if not closed[k] then
            closed[k] = true
            local node = best[k]
            local stalled = node.prev ~= nil and stallsUnit(state, u, node.tile)   -- vào aura chặn đứng thì không đi tiếp
            for _, n in ipairs(stalled and {} or state.map:neighbors(node.tile)) do
                local step = U.stepCost(state, u, n)
                local total = node.cost + step
                local nk = key(n)
                if step < INF and total <= u.mp and not closed[nk] and (not best[nk] or total < best[nk].cost) then
                    best[nk] = { tile = n, cost = total, prev = k }
                    open[#open + 1] = nk
                end
            end
        end
    end
    return best
end

-- Đường đi (danh sách tile, không gồm ô xuất phát) tới (q, r) và tổng chi phí, hoặc nil.
function U.pathTo(state, u, q, r, reach)
    reach = reach or U.reachable(state, u)
    local node = reach[q .. "," .. r]
    if not node or (u.q == q and u.r == r) then return nil end
    local path, k = {}, q .. "," .. r
    while k and reach[k].prev do
        table.insert(path, 1, reach[k].tile)
        k = reach[k].prev
    end
    return path, node.cost
end

-- Các ô đơn vị Giao Thương sẽ xây Đường Đất khi đi theo `path` và tổng Vàng phải trả (D-016).
-- Mỗi ô đi vào mà chưa có đường và địa hình cho phép thì tạo đường, tốn ROAD_COST_PER_TILE (TN-10: miễn phí).
function U.roadPlan(state, u, path)
    local tiles, gold = {}, 0
    if u.type ~= "trade" then return tiles, gold end
    for _, t in ipairs(path) do
        if not Roads.has(state, t) and Roads.canBuildOn(t) then
            tiles[#tiles + 1] = t
            if Structures.strategicAt(state, t) ~= Strategic.HARBOR then gold = gold + C.ROAD_COST_PER_TILE end
        end
    end
    return tiles, gold
end

-- `reach` (tùy chọn) là kết quả U.reachable đã tính sẵn, để liệt kê nhiều đích mà không chạy lại Dijkstra.
function U.checkMove(state, pid, u, q, r, reach)
    if not u then return false, "Không có đơn vị này" end
    if u.owner ~= pid then return false, "Không phải đơn vị của bạn" end
    if u.acted then return false, "Đơn vị đã dùng hành động trong lượt này" end
    if u.mp <= 0 then return false, "Hết điểm di chuyển" end
    if u.q == q and u.r == r then return false, "Đơn vị đang đứng ở ô này" end
    local path, cost = U.pathTo(state, u, q, r, reach)
    if not cost then return false, "Không đi tới được ô này với điểm di chuyển còn lại" end
    local _, gold = U.roadPlan(state, u, path)
    if gold > state.players[pid].res.gold then
        return false, string.format("Không đủ Vàng xây đường (cần %d V)", gold)
    end
    return true
end

-- Áp dụng (đã qua check). Trả cost, danh sách tile đã xây đường, Vàng đã trả.
function U.move(state, u, q, r)
    local path, cost = U.pathTo(state, u, q, r)
    local built, gold = U.roadPlan(state, u, path)
    for _, t in ipairs(built) do Roads.build(state, t) end
    assert(Wallet.pay(state.players[u.owner].res, { gold = gold }), "U.move: thiếu Vàng xây đường")
    u.mp = u.mp - cost
    u.q, u.r = q, r
    for _, t in ipairs(path) do
        if stallsUnit(state, u, t) then u.mp = 0 break end    -- aura Pháo Đài +1: bị chặn đứng
    end
    return cost, built, gold
end

-- ─── Mua / giải thể ─────────────────────────────────────────────────────────

-- `tile` là ô HQ hoặc Sub của `pid` (nơi sinh Viễn Chinh).
local function isOwnAnchor(state, pid, tile)
    for _, a in ipairs(Territory.anchors(state, pid)) do
        if a.q == tile.q and a.r == tile.r then return true end
    end
    return false
end

-- Ô thuộc footprint Pháo Đài S-02 của `pid` (nơi sinh Viễn Chinh, Data §2).
local function isOwnFortress(state, pid, tile)
    local b = Structures.at(state, tile)
    return b ~= nil and b.id == "S-02" and b.owner == pid and not b.demolishing
end

-- Số Khu Chợ (B-05, không chờ dỡ) của `pid`.
local function hasMarket(state, pid)
    for _, b in pairs(state.buildings) do
        if b.owner == pid and b.id == "B-05" and not b.demolishing then return true end
    end
    return false
end

-- Giao Thương sinh ở ô thuộc Khu Chợ của mình; chưa có chợ nào thì sinh ở Nhà Chính (Data §2).
local function isTradeSpawn(state, pid, tile)
    local b = Structures.at(state, tile)
    if b and b.owner == pid and b.id == "B-05" and not b.demolishing then return true end
    return not hasMarket(state, pid) and isOwnAnchor(state, pid, tile) and tile.q == state.players[pid].hq.q
        and tile.r == state.players[pid].hq.r
end

function U.checkBuy(state, pid, unitType, tile)
    local def = U.TYPES[unitType]
    if unitType ~= "expedition" and unitType ~= "trade" then return false, "Loại đơn vị này chưa mua được" end
    if not tile then return false, "Không có ô này" end
    if unitType == "expedition" then
        if not isOwnAnchor(state, pid, tile) and not isOwnFortress(state, pid, tile) then
            return false, "Viễn Chinh chỉ sinh ở Nhà Chính, Khu Trực Thuộc hoặc Pháo Đài của bạn"
        end
    elseif not isTradeSpawn(state, pid, tile) then
        return false, "Giao Thương sinh ở Khu Chợ của bạn (chưa có chợ thì ở Nhà Chính)"
    end
    if Rebel.isBlockaded(state, tile) then return false, "Ô đang bị Phiến Quân phong tỏa" end
    if U.quotaCount(state, pid, def.quota) >= U.quotaMax(def.quota) then
        return false, "Đã đạt giới hạn " .. U.quotaMax(def.quota) .. " " .. def.name
    end
    return true
end

-- Sinh đơn vị mới. Viễn Chinh không hành động ngay khi sinh (Data §2): mp = 0. Giao Thương đi ngay với đủ bước.
function U.spawn(state, pid, unitType, tile)
    local uid = state.nextUnitUid or 1
    state.nextUnitUid = uid + 1
    local u = { uid = uid, type = unitType, owner = pid, q = tile.q, r = tile.r, mp = 0, acted = false,
                garrison = false, recentGarrison = false }
    if unitType == "trade" then u.mp = U.baseMove(state, u) end
    if isOwnFortress(state, pid, tile) then u.spawnBonus = 2 end   -- xuất phát từ Pháo Đài: +2 bước lượt đầu
    state.units[uid] = u
    return u
end

function U.remove(state, uid) state.units[uid] = nil end

function U.checkDisband(state, pid, u)
    if not u then return false, "Không có đơn vị này" end
    if u.owner ~= pid then return false, "Không phải đơn vị của bạn" end
    return true
end

-- ─── Lập Khu Trực Thuộc (A-02) ──────────────────────────────────────────────

-- Kiểm tra điều kiện của ô (không tính tiền). Trả ok, lý do.
function U.checkFoundSub(state, pid, u)
    if not u then return false, "Không có đơn vị này" end
    if u.owner ~= pid then return false, "Không phải đơn vị của bạn" end
    if u.type ~= "expedition" and u.type ~= "knight" then return false, "Chỉ Viễn Chinh hoặc Hiệp Sĩ lập được Khu Trực Thuộc" end
    if u.acted then return false, "Đơn vị đã dùng hành động trong lượt này" end
    return Territory.canFoundSub(state, pid, U.tileOf(state, u))
end

-- ─── Trấn Áp (A-03) ─────────────────────────────────────────────────────────

-- Ngưỡng đổ 1d6 cần đạt (Data §5): cơ bản 4 (Hiệp Sĩ 3); −1 đứng Đồi Cỏ/Núi; −1 vừa Trú Đóng lượt trước;
-- +1 nếu Phiến Quân đứng trên Núi/Núi Tuyết; sàn SUPPRESS_THRESHOLD_FLOOR, trần 6.
function U.suppressThreshold(state, u)
    local t = u.type == "knight" and C.SUPPRESS_THRESHOLD_KNIGHT or C.SUPPRESS_THRESHOLD_EXPEDITION
    local tile = U.tileOf(state, u)
    if tile.terrain == HILLS or MOUNTAIN[tile.terrain] then t = t - 1 end
    if u.recentGarrison then t = t - 1 end
    local rt = state.map:get(state.rebel.q, state.rebel.r)
    if MOUNTAIN[rt.terrain] then t = t + 1 end
    return math.max(C.SUPPRESS_THRESHOLD_FLOOR, math.min(6, t))
end

-- Xác suất thắng khi đổ (số mặt đạt ngưỡng / 6).
function U.suppressChance(state, u)
    return (7 - U.suppressThreshold(state, u)) / 6
end

-- Kiểm tra Trấn Áp theo hướng `dir` (1..6), `pay` = trả TN để chắc thắng. Trả ok, lý do.
function U.checkSuppress(state, pid, u, dir, pay)
    if not u then return false, "Không có đơn vị này" end
    if u.owner ~= pid then return false, "Không phải đơn vị của bạn" end
    if u.type ~= "expedition" and u.type ~= "knight" then return false, "Chỉ Viễn Chinh hoặc Hiệp Sĩ trấn áp được" end
    if u.acted then return false, "Đơn vị đã dùng hành động trong lượt này" end
    if not state.rebel then return false, "Không có Phiến Quân" end
    if Hex.distance(u, state.rebel) ~= 1 then return false, "Đơn vị phải đứng kề Phiến Quân" end
    if not Hex.DIRECTIONS[dir or 0] then return false, "Hướng đẩy không hợp lệ" end
    if #Rebel.pushPath(state, dir, C.SUPPRESS_PUSH_TILES) == 0 then
        return false, "Không đẩy Phiến Quân theo hướng này được (ngoài bản đồ hoặc vào Núi đang khóa)"
    end
    if pay and state.players[pid].res.faith < C.SUPPRESS_GUARANTEE_FAITH then
        return false, "Không đủ Tín Ngưỡng để chắc thắng"
    end
    return true
end

-- Thực hiện Trấn Áp (đã qua check). Trả events. `pay` trả TN để chắc thắng, bỏ qua xúc xắc.
function U.suppress(state, u, dir, pay)
    local pid = u.owner
    local threshold = U.suppressThreshold(state, u)
    local roll
    local success = pay
    if pay then
        assert(Wallet.pay(state.players[pid].res, { faith = C.SUPPRESS_GUARANTEE_FAITH }), "U.suppress: thiếu Tín Ngưỡng")
    else
        roll = Dice.rollOne(state.rng)
        success = roll >= threshold
    end
    u.acted, u.mp = true, 0
    local events = {}
    local owner = state.players[pid]
    local canRetreat = u.type == "knight" and owner.hq
        and (owner.knightRetreatRound == nil or state.round - owner.knightRetreatRound >= C.KNIGHT_RETREAT_COOLDOWN)
    if success then
        local path = Rebel.pushPath(state, dir, C.SUPPRESS_PUSH_TILES)
        local from = { q = state.rebel.q, r = state.rebel.r }
        local to = path[#path]
        state.rebel.q, state.rebel.r = to.q, to.r
        state.rebel.suppressedRound = state.round
        Wallet.gain(state.players[pid].res, "faith", C.SUPPRESS_REWARD_FAITH)
        events[#events + 1] = { kind = "suppress", pid = pid, uid = u.uid, ok = true, roll = roll, threshold = threshold,
                                paid = pay or false, from = from, to = { q = to.q, r = to.r }, q = to.q, r = to.r }
    else
        events[#events + 1] = { kind = "suppress", pid = pid, uid = u.uid, ok = false, roll = roll, threshold = threshold,
                                paid = false, q = u.q, r = u.r }
        if canRetreat then   -- Hiệp Sĩ rút về HQ thay vì mất, tối đa 1 lần mỗi KNIGHT_RETREAT_COOLDOWN vòng (Data §5)
            owner.knightRetreatRound = state.round
            events[#events + 1] = { kind = "unit_retreat", pid = pid, uid = u.uid, unit = u.type,
                                    from = { q = u.q, r = u.r }, q = owner.hq.q, r = owner.hq.r }
            u.q, u.r = owner.hq.q, owner.hq.r
        else
            events[#events + 1] = { kind = "unit_destroyed", uid = u.uid, unit = u.type, pid = pid, q = u.q, r = u.r,
                                    reason = "suppress" }
            state.units[u.uid] = nil
        end
    end
    return events
end

-- HQ C4+: mọi Viễn Chinh của `pid` tự nâng thành Hiệp Sĩ, giữ nguyên điểm di chuyển và trạng thái (Data §2).
function U.transformArmy(state, pid, events)
    local hq = state.players[pid]
    if (hq.hqLevel or 1) < 4 then return end
    for _, u in ipairs(U.ownedBy(state, pid)) do
        if u.type == "expedition" then
            u.type = "knight"
            events[#events + 1] = { kind = "unit_transform", pid = pid, uid = u.uid, from = "expedition", to = "knight",
                                    q = u.q, r = u.r }
        end
    end
end

-- ─── Trú Đóng (A-04) ────────────────────────────────────────────────────────

function U.checkGarrison(state, pid, u)
    if not u then return false, "Không có đơn vị này" end
    if u.owner ~= pid then return false, "Không phải đơn vị của bạn" end
    if u.type ~= "expedition" and u.type ~= "knight" then return false, "Chỉ Viễn Chinh hoặc Hiệp Sĩ trú đóng được" end
    if u.acted then return false, "Đơn vị đã dùng hành động trong lượt này" end
    if state.rebel and Hex.distance(u, state.rebel) <= 1 then return false, "Không thể trú đóng khi Phiến Quân ở kề" end
    return true
end

function U.garrison(state, u)
    u.garrison, u.acted, u.mp = true, true, 0
end

-- ─── Upkeep đầu lượt ────────────────────────────────────────────────────────

-- Reset điểm di chuyển và hành động; Trú Đóng hết hiệu lực (ghi nhớ cho ngưỡng Trấn Áp); trả Vàng duy trì
-- từ đơn vị thứ 2 trở đi, thiếu Vàng thì hủy đơn vị mới nhất (D-015).
function U.startTurn(state, pid, events)
    U.transformArmy(state, pid, events)
    -- upkeep chỉ tính đơn vị quân sự (quota "expedition"); Giao Thương chưa có upkeep (D-015)
    local army = {}
    for _, u in ipairs(U.ownedBy(state, pid)) do
        if U.TYPES[u.type].quota == "expedition" then army[#army + 1] = u end
    end
    local due = math.max(0, #army - 1) * C.EXPEDITION_UPKEEP_GOLD
    local res = state.players[pid].res
    while due > res.gold and #army > 1 do
        local u = table.remove(army)
        events[#events + 1] = { kind = "unit_destroyed", uid = u.uid, unit = u.type, pid = pid, q = u.q, r = u.r,
                                reason = "upkeep" }
        state.units[u.uid] = nil
        due = math.max(0, #army - 1) * C.EXPEDITION_UPKEEP_GOLD
    end
    if due > 0 then
        Wallet.pay(res, { gold = due })
        events[#events + 1] = { kind = "unit_upkeep", pid = pid, gold = due, count = #army }
    end
    for _, u in ipairs(U.ownedBy(state, pid)) do
        u.recentGarrison, u.garrison = u.garrison, false
        u.mp, u.acted = U.baseMove(state, u), false
        if u.spawnBonus then u.mp, u.spawnBonus = u.mp + u.spawnBonus, nil end
    end
end

Upkeep.register(U.startTurn)

return U
