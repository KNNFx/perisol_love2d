-- Lãnh thổ & Chi Phối. Luật: docs/Decisions.md D-006. Thuần Lua, không gọi love.*.
--
-- Ba tầng: vùng ảnh hưởng (bán kính 1 quanh HQ) -> Tranh chấp (có phiếu, chưa ai đủ) -> Thực hữu.
-- Phiếu nằm ở state.votes[key][pid]; chủ nằm ở state.owner[key].

local C     = require("src.config.constants")
local Hex   = require("src.core.hex")
local State = require("src.core.state")
local Rebel = require("src.core.rebel")

local T = {}

local key = State.key

-- TN-06 Vàng Sa Khoáng: giảm ngưỡng Chi Phối 1 (D-006).
local TN_THRESHOLD_BONUS = "TN-06"

-- ─── Truy vấn cơ bản ────────────────────────────────────────────────────────

function T.ownerOf(state, tile) return state.owner[key(tile)] end

function T.votesOn(state, tile, pid)
    local v = state.votes[key(tile)]
    return v and v[pid] or 0
end

-- HQ + Sub của người chơi (tâm vùng ảnh hưởng).
function T.anchors(state, pid)
    local p = state.players[pid]
    local out = {}
    if p.hq then out[#out + 1] = p.hq end
    for _, s in ipairs(p.subs or {}) do out[#out + 1] = s end
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

-- Người chơi mà `tile` thuộc vùng nhà (HQ + 6 ô kề), hoặc nil.
function T.homeOf(state, tile)
    for pid in ipairs(state.players) do
        if T.distanceToAnchor(state, pid, tile) <= C.INFLUENCE_RADIUS then return pid end
    end
    return nil
end

-- ─── Ngưỡng và trạng thái ───────────────────────────────────────────────────

-- Số phiếu `pid` cần để sở hữu `tile` (theo khoảng cách tới HQ/Sub của chính họ).
function T.threshold(state, pid, tile)
    local d = T.distanceToAnchor(state, pid, tile)
    local idx = math.max(1, math.min(d, #C.CHI_PHOI_THRESHOLD))
    local need = C.CHI_PHOI_THRESHOLD[idx]
    if tile.strategic == TN_THRESHOLD_BONUS then need = need - 1 end
    return math.max(1, need)
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

-- Tính lại chủ của ô sau khi phiếu đổi. Trả chủ mới (có thể là nil).
-- Chiếm được khi: phiếu >= ngưỡng riêng VÀ nhiều phiếu hơn hẳn mọi người khác. Hòa -> chủ cũ giữ.
function T.recalc(state, tile)
    local k = key(tile)
    local v = state.votes[k] or {}
    local leader, best, tie = nil, 0, false
    for pid, n in pairs(v) do
        if n > best then leader, best, tie = pid, n, false
        elseif n == best and n > 0 then tie = true end
    end
    if leader and not tie and best >= T.threshold(state, leader, tile) then
        state.owner[k] = leader
    end
    return state.owner[k]
end

-- ─── Nhà (HQ) ───────────────────────────────────────────────────────────────

-- Đặt HQ cho `pid` tại `tile`; HQ + 6 ô kề thành lãnh thổ thực hữu ngay (D-006).
function T.placeHQ(state, pid, tile)
    local p = state.players[pid]
    p.hq = { q = tile.q, r = tile.r }
    for _, t in ipairs(state.map:range(tile, C.INFLUENCE_RADIUS)) do
        state.owner[key(t)] = pid
    end
end

-- ─── Đặt phiếu ──────────────────────────────────────────────────────────────

-- Có thể đặt 1 phiếu của `pid` lên `tile` không? Trả ok, lý do (tiếng Việt, cho tooltip).
function T.canVote(state, pid, tile)
    local p = state.players[pid]
    if not tile then return false, "Không có ô này" end
    if not p.hq then return false, "Chưa đặt Nhà Chính" end
    if p.votes < 1 then return false, "Không còn phiếu Chi Phối" end
    if Rebel.isBlockaded(state, tile) then return false, "Ô đang bị Phiến Quân phong tỏa" end

    local home = T.homeOf(state, tile)
    if home and home ~= pid then return false, "Ô thuộc vùng nhà của đối thủ" end
    local b = state.buildings[key(tile)]
    if b and b.owner ~= pid then return false, "Ô có công trình của đối thủ" end

    local owner = state.owner[key(tile)]
    if owner == pid and not T.isDisputed(state, tile) then return false, "Ô đã thuộc về bạn" end

    -- trong vùng ảnh hưởng, đã có phiếu của mình, hoặc kề lãnh thổ của mình
    local reachable = T.distanceToAnchor(state, pid, tile) <= C.INFLUENCE_RADIUS
        or T.votesOn(state, tile, pid) > 0
    if not reachable then
        for _, n in ipairs(state.map:neighbors(tile)) do
            if state.owner[key(n)] == pid then reachable = true break end
        end
    end
    if not reachable then return false, "Ô phải kề lãnh thổ của bạn" end
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
    local after = T.recalc(state, tile)
    return before, after
end

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

T.TN_THRESHOLD_BONUS = TN_THRESHOLD_BONUS

return T
