-- Lãnh thổ & Chi Phối. Luật: docs/Decisions.md D-006 (cơ bản) và D-013 (theo GDD PDF). Thuần Lua.
--
-- Ba tầng: Vùng ảnh hưởng (bán kính theo cấp HQ/Sub quanh mỗi "mốc") -> Tranh chấp (có phiếu, chưa ai
-- đủ) -> Thực hữu (xây được). Lúc đầu chỉ ô HQ là thực hữu; 6 ô quanh HQ là vùng ảnh hưởng.
-- Phiếu nằm ở state.votes[key][pid]; chủ nằm ở state.owner[key].

local C         = require("src.config.constants")
local Hex       = require("src.core.hex")
local State     = require("src.core.state")
local Rebel     = require("src.core.rebel")
local Structures = require("src.core.structures")
local Roads     = require("src.core.roads")
local Aura      = require("src.core.aura")
local Terrains  = require("src.data.terrains")
local Strategic = require("src.data.strategic")

local T = {}

local key = State.key

-- TN-06 Vàng Sa Khoáng: giảm ngưỡng Chi Phối 1 (D-006).
local TN_THRESHOLD_BONUS = Strategic.ALLUVIAL_GOLD

-- ─── Mốc (HQ / Sub) và vùng ảnh hưởng ───────────────────────────────────────

function T.ownerOf(state, tile) return state.owner[key(tile)] end

-- Phiếu hiệu lực của `pid` trên `tile`: phiếu đã đặt, nhân hệ số aura Bảo Tàng S-03 (làm tròn lên) trên cụm.
function T.votesOn(state, tile, pid)
    local v = state.votes[key(tile)]
    local n = v and v[pid] or 0
    if n > 0 then n = math.ceil(n * Aura.voteMultiplier(state, pid, tile)) end
    return n
end

-- HQ + Sub của người chơi, mỗi mốc kèm bán kính vùng ảnh hưởng: { q, r, radius, kind }.
function T.anchors(state, pid)
    local p = state.players[pid]
    local out = {}
    if p.hq then
        local lv = math.min(p.hqLevel, #C.INFLUENCE_RADIUS_HQ)
        out[#out + 1] = { q = p.hq.q, r = p.hq.r, radius = C.INFLUENCE_RADIUS_HQ[lv], kind = "hq" }
    end
    for _, s in ipairs(p.subs) do
        local lv = math.min(s.level or 1, #C.INFLUENCE_RADIUS_SUB)
        out[#out + 1] = { q = s.q, r = s.r, radius = C.INFLUENCE_RADIUS_SUB[lv], kind = "sub" }
    end
    return out
end

-- Khoảng cách tới HQ/Sub gần nhất của `pid` (math.huge nếu chưa có HQ).
function T.distanceToAnchor(state, pid, tile)
    local best = math.huge
    for _, a in ipairs(T.anchors(state, pid)) do
        best = math.min(best, Hex.distance(a, tile))
    end
    return best
end

-- `tile` nằm trong vùng ảnh hưởng của `pid` (kể cả chính ô mốc).
function T.inInfluence(state, pid, tile)
    for _, a in ipairs(T.anchors(state, pid)) do
        if Hex.distance(a, tile) <= a.radius then return true end
    end
    return false
end

-- `tile` là ô đặt HQ/Sub của bất kỳ người chơi nào.
function T.isAnchorTile(state, tile)
    for pid in ipairs(state.players) do
        for _, a in ipairs(T.anchors(state, pid)) do
            if a.q == tile.q and a.r == tile.r then return true end
        end
    end
    return false
end

-- ─── Cụm Khu Dân Cư / Danh Thắng ────────────────────────────────────────────

-- Cụm chứa `tile` (bảng { tiles, size, ... } của mapgen) hoặc nil.
function T.clusterOf(state, tile)
    if tile.settlement then return state.map.settlements[tile.settlement] end
    if tile.landmark then return state.map.landmarks[tile.landmark] end
    return nil
end

-- Người sở hữu nhiều ô nhất trong cụm (hơn hẳn mọi người khác), hoặc nil. Trả thêm số ô của họ.
function T.clusterController(state, cluster)
    local counts = {}
    for _, t in ipairs(cluster.tiles) do
        local o = state.owner[key(t)]
        if o then counts[o] = (counts[o] or 0) + 1 end
    end
    local leader, best, tie = nil, 0, false
    for pid, n in pairs(counts) do
        if n > best then leader, best, tie = pid, n, false
        elseif n == best then tie = true end
    end
    if tie then return nil, best end
    return leader, best
end

-- ─── Ngưỡng và trạng thái ───────────────────────────────────────────────────

-- Ngưỡng theo khoảng cách; `tn` là TN đang tính trên ô (nil = không có).
local function thresholdWith(state, pid, tile, tn)
    if tile.settlement or tile.landmark then return C.CLUSTER_TILE_VOTES end
    local d = T.distanceToAnchor(state, pid, tile)
    local idx = math.max(1, math.min(d, #C.CHI_PHOI_THRESHOLD))
    local need = C.CHI_PHOI_THRESHOLD[idx]
    if tn == TN_THRESHOLD_BONUS then need = need - 1 end
    return math.max(1, need)
end

-- Số phiếu `pid` cần để sở hữu `tile`.
-- Ô trong cụm: luôn CLUSTER_TILE_VOTES. Ô thường: 1/2/3 theo khoảng cách tới mốc (TN-06 −1).
function T.threshold(state, pid, tile)
    return thresholdWith(state, pid, tile, Structures.strategicAt(state, tile))
end

-- Ngưỡng như lúc TN-06 còn: ô chiếm nhờ TN-06 rồi mất TN (D-020) vẫn thuộc chủ với số phiếu đó.
-- Chỉ TN-06 được tính; ô mất TN khác thì bằng T.threshold.
function T.thresholdAtClaim(state, pid, tile)
    return thresholdWith(state, pid, tile, tile.strategic == TN_THRESHOLD_BONUS and tile.strategic or
        Structures.strategicAt(state, tile))
end

-- "owned" | "contested" | "none".  Contested = chưa có chủ nhưng đã có phiếu.
function T.statusOf(state, tile)
    if state.owner[key(tile)] then return "owned" end
    local v = state.votes[key(tile)]
    if v then
        for _, n in pairs(v) do
            if n > 0 then return "contested" end
        end
    end
    return "none"
end

-- Ô có chủ nhưng đối thủ cũng đang có phiếu trên đó.
function T.isDisputed(state, tile)
    local owner = state.owner[key(tile)]
    local v = state.votes[key(tile)]
    if not owner or not v then return false end
    for pid, n in pairs(v) do
        if pid ~= owner and n > 0 then return true end
    end
    return false
end

-- Số phiếu `pid` cần để cướp `tile` đang thuộc `owner`.
function T.retakeNeed(state, pid, tile, owner)
    local theirs = T.votesOn(state, tile, owner)
    if tile.settlement or tile.landmark then
        return math.max(T.threshold(state, pid, tile), theirs + C.CLUSTER_RETAKE_STEP)
    end
    return math.max(C.RETAKE_MULTIPLIER * T.threshold(state, pid, tile), theirs + 1)
end

-- Xét lại chủ của ô sau khi `voter` vừa đặt phiếu. Trả chủ mới (có thể nil).
--   Ô chưa có chủ: ai đạt ngưỡng trước được ô.
--   Ô của người khác: cần phiếu ≥ 2 × ngưỡng của mình và hơn phiếu của chủ
--   (ô trong cụm: hơn phiếu của chủ 1). Hòa thì chủ cũ giữ.
function T.recalc(state, tile, voter)
    local k = key(tile)
    local owner = state.owner[k]
    if owner == voter then return owner end
    local mine = T.votesOn(state, tile, voter)
    if not owner then
        if mine >= T.threshold(state, voter, tile) then state.owner[k] = voter end
    elseif mine >= T.retakeNeed(state, voter, tile, owner) then
        state.owner[k] = voter
    end
    return state.owner[k]
end

-- ─── Nhà (HQ), nâng cấp và Khu Trực Thuộc ───────────────────────────────────

-- Đặt HQ cho `pid` tại `tile`. Chỉ ô HQ là thực hữu; 6 ô quanh là vùng ảnh hưởng (D-013).
function T.placeHQ(state, pid, tile)
    local p = state.players[pid]
    p.hq = { q = tile.q, r = tile.r }
    p.hqLevel = 1
    state.owner[key(tile)] = pid
end

-- Khu Chợ (B-05, không chờ dỡ) của `pid` thỏa `test(building)`.
local function marketWhere(state, pid, test)
    for _, b in ipairs(Structures.marketsOf(state, pid)) do
        if test(b) then return true end
    end
    return false
end

-- Có Khu Chợ liền Nhà Chính hoặc nối đường tới Nhà Chính (điều kiện HQ C3, Data §9.1).
function T.hasLinkedMarket(state, pid)
    local hq = state.players[pid].hq
    local hqTile = hq and state.map:get(hq.q, hq.r)
    if not hqTile then return false end
    return marketWhere(state, pid, function(b)
        return Roads.route(state, Structures.tilesOf(state, b), { hqTile }) ~= nil
    end)
end

-- Điều kiện nâng Nhà Chính lên cấp kế (chưa tính tiền). Trả ok, lý do.
--   C3: có Khu Chợ nối với Nhà Chính. C4: từ vòng HQ_C4_MIN_ROUND. C5: có Khu Chợ C3.
function T.canUpgradeHQ(state, pid)
    local p = state.players[pid]
    if not p.hq then return false, "Chưa đặt Nhà Chính" end
    local level = p.hqLevel + 1
    if level > C.HQ_MAX_LEVEL then return false, "Nhà Chính đã ở cấp tối đa" end
    if level == 3 and not T.hasLinkedMarket(state, pid) then
        return false, "Cần một Khu Chợ liền hoặc nối đường tới Nhà Chính"
    elseif level == 4 and state.round < C.HQ_C4_MIN_ROUND then
        return false, "Chỉ nâng lên C4 từ vòng " .. C.HQ_C4_MIN_ROUND
    elseif level == 5 and not marketWhere(state, pid, function(b) return b.level >= C.MARKET_C3_LEVEL end) then
        return false, "Cần sở hữu một Khu Chợ cấp 3"
    end
    return true
end

function T.upgradeHQ(state, pid)
    local p = state.players[pid]
    p.hqLevel = p.hqLevel + 1
end

-- Khu Trực Thuộc của `pid` tại `tile` (bảng trong p.subs) hoặc nil.
function T.subAt(state, pid, tile)
    for _, s in ipairs(state.players[pid].subs) do
        if s.q == tile.q and s.r == tile.r then return s end
    end
    return nil
end

-- Điều kiện nâng Khu Trực Thuộc tại `tile` lên cấp kế (chưa tính tiền). C3: từ vòng SUB_C3_MIN_ROUND.
function T.canUpgradeSub(state, pid, tile)
    if not tile then return false, "Không có ô này" end
    local sub = T.subAt(state, pid, tile)
    if not sub then return false, "Không có Khu Trực Thuộc của bạn ở ô này" end
    local level = (sub.level or 1) + 1
    if level > C.SUB_MAX_LEVEL then return false, "Khu Trực Thuộc đã ở cấp tối đa" end
    if level == C.SUB_C3_LEVEL and state.round < C.SUB_C3_MIN_ROUND then
        return false, "Chỉ nâng lên C3 từ vòng " .. C.SUB_C3_MIN_ROUND
    end
    return true
end

function T.upgradeSub(state, pid, tile)
    local sub = T.subAt(state, pid, tile)
    sub.level = (sub.level or 1) + 1
    return sub.level
end

-- Ô tâm của Khu Trực Thuộc C3 (Đô Thị Vệ Tinh) miễn nhiễm phong tỏa (Data §9.1); logic ở Rebel.
T.isImmuneCentre = Rebel.isImmuneCentre

-- Có thể lập Khu Trực Thuộc của `pid` tại `tile` không (không tính tiền)? Trả ok, lý do.
function T.canFoundSub(state, pid, tile)
    if not tile then return false, "Không có ô này" end
    if state.owner[key(tile)] ~= pid then return false, "Phải lập Khu Trực Thuộc trên lãnh thổ thực hữu của bạn" end
    if Structures.at(state, tile) or T.isAnchorTile(state, tile) then return false, "Ô đã có công trình" end
    if Rebel.isBlockaded(state, tile) then return false, "Ô đang bị Phiến Quân phong tỏa" end
    if not Terrains.byId[tile.terrain].canSub then return false, "Không đặt Khu Trực Thuộc trên địa hình này" end
    if #state.map:neighbors(tile) < 6 then return false, "Cần đủ 6 ô xung quanh" end
    for other in ipairs(state.players) do
        local need = other == pid and C.SUB_MIN_DIST_OWN or C.SUB_MIN_DIST_RIVAL
        for _, a in ipairs(T.anchors(state, other)) do
            if Hex.distance(a, tile) < need then
                return false, other == pid and "Phải cách Nhà Chính/Khu Trực Thuộc của bạn ít nhất 2 ô"
                    or "Phải cách Nhà Chính/Khu Trực Thuộc của đối thủ ít nhất 3 ô"
            end
        end
    end
    for _, n in ipairs(state.map:range(tile, 1)) do
        if n.settlement or n.landmark then return false, "Vùng ảnh hưởng không được trùng Khu Dân Cư / Danh Thắng" end
    end
    return true
end

function T.addSub(state, pid, tile)
    local p = state.players[pid]
    p.subs[#p.subs + 1] = { q = tile.q, r = tile.r, level = 1 }
end

-- ─── Đặt phiếu ──────────────────────────────────────────────────────────────

-- Có thể đặt 1 phiếu của `pid` lên `tile` không? Trả ok, lý do (tiếng Việt, cho tooltip).
function T.canVote(state, pid, tile)
    local p = state.players[pid]
    if not tile then return false, "Không có ô này" end
    if not p.hq then return false, "Chưa đặt Nhà Chính" end
    if p.votes < 1 then return false, "Không còn phiếu Chi Phối" end
    if Rebel.isBlockaded(state, tile) then return false, "Ô đang bị Phiến Quân phong tỏa" end
    if not T.inInfluence(state, pid, tile) then return false, "Chỉ đặt phiếu trong vùng ảnh hưởng của bạn" end
    if T.isAnchorTile(state, tile) then return false, "Không đặt phiếu lên ô Nhà Chính / Khu Trực Thuộc" end
    local b = Structures.at(state, tile)
    if b and b.owner ~= pid then return false, "Ô có công trình của đối thủ" end
    local owner = state.owner[key(tile)]
    if owner == pid and not T.isDisputed(state, tile) then return false, "Ô đã thuộc về bạn" end
    return true
end

-- Đặt phiếu (đã qua canVote). Trả chủ cũ, chủ mới.
function T.addVote(state, pid, tile)
    local ok, reason = T.canVote(state, pid, tile)
    assert(ok, reason)
    local k = key(tile)
    local before = state.owner[k]
    state.players[pid].votes = state.players[pid].votes - 1
    state.votes[k] = state.votes[k] or {}
    state.votes[k][pid] = (state.votes[k][pid] or 0) + 1
    local after = T.recalc(state, tile, pid)
    return before, after
end

-- ─── Mua ô ──────────────────────────────────────────────────────────────────

-- Giá mua `tile` (bảng tài nguyên): BASE × GROWTH^(khoảng cách − 1).
function T.buyTileCost(state, pid, tile)
    local d = math.max(1, T.distanceToAnchor(state, pid, tile))
    local mult = C.BUY_TILE_GROWTH ^ (d - 1)
    local cost = {}
    for k, n in pairs(C.BUY_TILE_BASE) do cost[k] = n * mult end
    return cost
end

-- Mua được ô chưa có chủ trong vùng ảnh hưởng? (Chưa tính tiền.) Trả ok, lý do.
function T.canBuyTile(state, pid, tile)
    if not tile then return false, "Không có ô này" end
    if not state.players[pid].hq then return false, "Chưa đặt Nhà Chính" end
    if Rebel.isBlockaded(state, tile) then return false, "Ô đang bị Phiến Quân phong tỏa" end
    if not T.inInfluence(state, pid, tile) then return false, "Chỉ mua ô trong vùng ảnh hưởng của bạn" end
    if T.isAnchorTile(state, tile) then return false, "Không mua ô Nhà Chính / Khu Trực Thuộc" end
    if state.owner[key(tile)] then return false, "Ô đã có chủ" end
    return true
end

-- Gán ô cho người mua. Phiếu của họ trên ô được nâng lên ít nhất bằng ngưỡng để luật cướp tính đúng.
function T.buyTile(state, pid, tile)
    local k = key(tile)
    state.owner[k] = pid
    state.votes[k] = state.votes[k] or {}
    state.votes[k][pid] = math.max(state.votes[k][pid] or 0, T.threshold(state, pid, tile))
end

-- ─── Truy vấn danh sách ─────────────────────────────────────────────────────

-- Danh sách ô thực hữu của `pid` (thứ tự hàng để vẽ/duyệt ổn định).
function T.ownedTiles(state, pid)
    local out = {}
    for _, t in ipairs(state.map.list) do
        if state.owner[key(t)] == pid then out[#out + 1] = t end
    end
    return out
end

-- Các ô `pid` có thể đặt phiếu (dùng cho Game.legal và ghost UI).
function T.voteTargets(state, pid)
    local out = {}
    if state.players[pid].votes < 1 then return out end
    for _, t in ipairs(state.map.list) do
        if T.canVote(state, pid, t) then out[#out + 1] = t end
    end
    return out
end

-- Các ô `pid` có thể mua (chưa tính tiền).
function T.buyTargets(state, pid)
    local out = {}
    for _, t in ipairs(state.map.list) do
        if T.canBuyTile(state, pid, t) then out[#out + 1] = t end
    end
    return out
end

T.TN_THRESHOLD_BONUS = TN_THRESHOLD_BONUS

return T
