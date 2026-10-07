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
local Dice       = require("src.core.dice")
local Hex        = require("src.core.hex")
local Rebel      = require("src.core.rebel")
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
    if tile and Structures.strategicAt(state, tile) == "TN-04" and u.type ~= "trade" then
        if Territory.distanceToAnchor(state, u.owner, tile) <= C.TN04_HOME_RADIUS then mp = mp + C.TN04_BONUS_MOVE end
    end
    return mp
end

-- Chi phí để đơn vị `u` đi vào `tile`. TN-11 Gió Mạnh giảm TN11_STEP_REFUND (tối thiểu 0).
function U.stepCost(state, u, tile)
    local c = Movement.stepCost(U.TYPES[u.type].move, tile.terrain, state.round)
    if c == INF then return INF end
    if Structures.strategicAt(state, tile) == "TN-11" and u.type ~= "trade" then
        c = math.max(0, c - C.TN11_STEP_REFUND)
    end
    return c
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
            for _, n in ipairs(state.map:neighbors(node.tile)) do
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
function U.pathTo(state, u, q, r)
    local reach = U.reachable(state, u)
    local node = reach[q .. "," .. r]
    if not node or (u.q == q and u.r == r) then return nil end
    local path, k = {}, q .. "," .. r
    while k and reach[k].prev do
        table.insert(path, 1, reach[k].tile)
        k = reach[k].prev
    end
    return path, node.cost
end

function U.checkMove(state, pid, u, q, r)
    if not u then return false, "Không có đơn vị này" end
    if u.owner ~= pid then return false, "Không phải đơn vị của bạn" end
    if u.acted then return false, "Đơn vị đã dùng hành động trong lượt này" end
    if u.mp <= 0 then return false, "Hết điểm di chuyển" end
    if u.q == q and u.r == r then return false, "Đơn vị đang đứng ở ô này" end
    local _, cost = U.pathTo(state, u, q, r)
    if not cost then return false, "Không đi tới được ô này với điểm di chuyển còn lại" end
    return true
end

-- Áp dụng (đã qua check). Trả cost.
function U.move(state, u, q, r)
    local _, cost = U.pathTo(state, u, q, r)
    u.mp = u.mp - cost
    u.q, u.r = q, r
    return cost
end

-- ─── Mua / giải thể ─────────────────────────────────────────────────────────

-- `tile` là ô HQ hoặc Sub của `pid` (nơi sinh Viễn Chinh).
local function isOwnAnchor(state, pid, tile)
    for _, a in ipairs(Territory.anchors(state, pid)) do
        if a.q == tile.q and a.r == tile.r then return true end
    end
    return false
end

function U.checkBuy(state, pid, unitType, tile)
    if unitType ~= "expedition" then return false, "Loại đơn vị này chưa mua được" end
    if not tile then return false, "Không có ô này" end
    if not isOwnAnchor(state, pid, tile) then return false, "Viễn Chinh chỉ sinh ở Nhà Chính hoặc Khu Trực Thuộc của bạn" end
    if Rebel.isBlockaded(state, tile) then return false, "Ô đang bị Phiến Quân phong tỏa" end
    local quota = U.TYPES[unitType].quota
    if U.quotaCount(state, pid, quota) >= U.quotaMax(quota) then
        return false, "Đã đạt giới hạn " .. U.quotaMax(quota) .. " Viễn Chinh"
    end
    return true
end

-- Sinh đơn vị mới. Viễn Chinh không hành động ngay khi sinh (Data §2): mp = 0.
function U.spawn(state, pid, unitType, tile)
    local uid = state.nextUnitUid or 1
    state.nextUnitUid = uid + 1
    local u = { uid = uid, type = unitType, owner = pid, q = tile.q, r = tile.r, mp = 0, acted = false,
                garrison = false, recentGarrison = false }
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
        state.players[pid].res.faith = state.players[pid].res.faith - C.SUPPRESS_GUARANTEE_FAITH
    else
        roll = Dice.rollOne(state.rng)
        success = roll >= threshold
    end
    u.acted, u.mp = true, 0
    local events = {}
    if success then
        local path = Rebel.pushPath(state, dir, C.SUPPRESS_PUSH_TILES)
        local from = { q = state.rebel.q, r = state.rebel.r }
        local to = path[#path]
        state.rebel.q, state.rebel.r = to.q, to.r
        state.rebel.suppressedRound = state.round
        state.players[pid].res.faith = state.players[pid].res.faith + C.SUPPRESS_REWARD_FAITH
        events[#events + 1] = { kind = "suppress", pid = pid, uid = u.uid, ok = true, roll = roll, threshold = threshold,
                                paid = pay or false, from = from, to = { q = to.q, r = to.r }, q = to.q, r = to.r }
    else
        events[#events + 1] = { kind = "suppress", pid = pid, uid = u.uid, ok = false, roll = roll, threshold = threshold,
                                paid = false, q = u.q, r = u.r }
        events[#events + 1] = { kind = "unit_destroyed", uid = u.uid, unit = u.type, pid = pid, q = u.q, r = u.r,
                                reason = "suppress" }
        state.units[u.uid] = nil
    end
    return events
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
    local mine = U.ownedBy(state, pid)
    local due = math.max(0, #mine - 1) * C.EXPEDITION_UPKEEP_GOLD
    local res = state.players[pid].res
    while due > res.gold and #mine > 1 do
        local u = table.remove(mine)
        events[#events + 1] = { kind = "unit_destroyed", uid = u.uid, unit = u.type, pid = pid, q = u.q, r = u.r,
                                reason = "upkeep" }
        state.units[u.uid] = nil
        due = math.max(0, #mine - 1) * C.EXPEDITION_UPKEEP_GOLD
    end
    if due > 0 then
        res.gold = res.gold - due
        events[#events + 1] = { kind = "unit_upkeep", pid = pid, gold = due, count = #mine }
    end
    for _, u in ipairs(mine) do
        u.recentGarrison, u.garrison = u.garrison, false
        u.mp, u.acted = U.baseMove(state, u), false
    end
end

Upkeep.register(U.startTurn)

return U
