-- Phiến Quân (U-03). Luật: docs/Decisions.md D-009. Thuần Lua, không gọi love.*.
--
-- state.rebel = { q, r, pending = nil
--                         | { stage = "move", points = n, roller = pid }
--                         | { stage = "loss", owner = pid, roller = pid, amount = n, options = { resKey... } } }
-- Người đổ 7 điều khiển từng bước (không undo). Dừng khi hết điểm hoặc không còn ô kề đủ điểm.
-- Dừng trên công trình (kể cả HQ) của người khác: chủ mất ceil(1/2) loại tài nguyên nhiều nhất
-- (hòa -> chủ chọn), người đổ nhận ceil(1/2) số đó.

local C         = require("src.config.constants")
local Hex       = require("src.core.hex")
local Dice      = require("src.core.dice")
local State     = require("src.core.state")
local Structures = require("src.core.structures")
local Roads     = require("src.core.roads")
local Movement  = require("src.data.movement")
local Resources = require("src.data.resources")

local Rebel = {}

-- ─── Phong tỏa ──────────────────────────────────────────────────────────────

-- Vùng phong tỏa: ô Phiến Quân đứng + 6 ô kề (REBEL_BLOCKADE_TILES = 7), chỉ gồm ô trong bản đồ.
function Rebel.blockade(state)
    local out = {}
    local rb = state.rebel
    if not rb or Rebel.isSuppressed(state) then return out end
    for _, h in ipairs(Hex.range(rb, 1)) do
        local t = state.map:get(h.q, h.r)
        if t then out[#out + 1] = t end
    end
    return out
end

-- Trấn Áp thành công hủy phong tỏa trong cả vòng đó (Data §5).
function Rebel.isSuppressed(state)
    local rb = state.rebel
    return rb ~= nil and rb.suppressedRound == state.round
end

-- true nếu ô `tile` đang bị Phiến Quân phong tỏa.
function Rebel.isBlockaded(state, tile)
    local rb = state.rebel
    return rb ~= nil and not Rebel.isSuppressed(state) and Hex.distance(rb, tile) <= 1
end

-- ─── Cấm dừng cạnh đơn vị Trú Đóng (A-04) ───────────────────────────────────

-- Phiến Quân không được dừng trên ô đơn vị Trú Đóng đứng hoặc ô kề nó.
function Rebel.forbiddenStop(state, tile)
    for _, u in pairs(state.units) do
        if u.garrison and Hex.distance(u, tile) <= 1 then return true end
    end
    return false
end

local function anyGarrison(state)
    for _, u in pairs(state.units) do
        if u.garrison then return true end
    end
    return false
end

-- ─── Xuất hiện ──────────────────────────────────────────────────────────────

local function distanceToHQs(state, tile)
    local best = math.huge
    for _, p in ipairs(state.players) do
        if p.hq then best = math.min(best, Hex.distance(p.hq, tile)) end
    end
    return best
end

-- Đặt Phiến Quân sau khi mọi HQ đã được đặt: ô Đồng Bằng / Lãnh Nguyên / Sa Mạc cách mọi HQ >= 2.
-- Không có thì lấy ô đi được bất kỳ cách HQ >= 2 (rồi >= 1). Trả ô đã chọn.
function Rebel.spawn(state)
    local spawnTerrain = {}
    for _, id in ipairs(C.REBEL_SPAWN_TERRAINS) do spawnTerrain[id] = true end

    local function candidates(preferred, minDist)
        local out = {}
        for _, t in ipairs(state.map.list) do
            local walkable = Movement.stepCost("rebel", t.terrain, 1) < math.huge
            if walkable and (not preferred or spawnTerrain[t.terrain])
                and distanceToHQs(state, t) >= minDist then
                out[#out + 1] = t
            end
        end
        return out
    end

    local list = candidates(true, C.REBEL_SPAWN_MIN_HQ_DIST)
    if #list == 0 then list = candidates(false, C.REBEL_SPAWN_MIN_HQ_DIST) end
    if #list == 0 then list = candidates(false, 1) end
    assert(#list > 0, "không có ô nào cho Phiến Quân")
    local t = state.rng:pick(list)
    state.rebel = { q = t.q, r = t.r }
    return t
end

-- ─── Di chuyển ──────────────────────────────────────────────────────────────

function Rebel.stage(state)
    local rb = state.rebel
    return rb and rb.pending and rb.pending.stage or nil
end

-- Các bước thô từ `here` với `points` điểm, bỏ ô đã qua (`visited`). Trả list { tile, cost }.
local function rawSteps(state, here, points, visited)
    local out = {}
    for _, n in ipairs(state.map:neighbors(here)) do
        local cost = Movement.stepCost("rebel", n.terrain, state.round)
        if not visited[State.key(n)] and cost <= points then out[#out + 1] = { tile = n, cost = cost } end
    end
    return out
end

-- Từ `here` với `points` điểm còn lại có đường đi nào kết thúc ở ô không bị cấm dừng không?
-- Phiến Quân bắt buộc đi tiếp khi còn bước, nên chỉ xét các điểm dừng bắt buộc.
local function canEndAllowed(state, here, points, visited)
    local steps = rawSteps(state, here, points, visited)
    if #steps == 0 then return not Rebel.forbiddenStop(state, here) end
    for _, s in ipairs(steps) do
        local k = State.key(s.tile)
        visited[k] = true
        local left = points - s.cost
        local ok
        if left <= 0 then ok = not Rebel.forbiddenStop(state, s.tile)
        else ok = canEndAllowed(state, s.tile, left, visited) end
        visited[k] = nil
        if ok then return true end
    end
    return false
end

-- Các ô kề Phiến Quân có thể bước vào với số điểm còn lại (không đi lại ô đã qua trong lần này).
-- Nếu có đơn vị Trú Đóng: loại các bước mà mọi đường đi tiếp đều buộc dừng ở ô bị cấm; nếu loại hết thì
-- vẫn cho đi để Phiến Quân không kẹt (D-015).
function Rebel.legalSteps(state)
    local out = {}
    local rb = state.rebel
    if not rb or Rebel.stage(state) ~= "move" then return out end
    local here = state.map:get(rb.q, rb.r)
    local points = rb.pending.points
    local visited = {}
    for k in pairs(rb.pending.visited or {}) do visited[k] = true end   -- GDD §6.2: không đi lại ô cũ
    local steps = rawSteps(state, here, points, visited)
    for _, s in ipairs(steps) do out[#out + 1] = s.tile end
    if #out == 0 or not anyGarrison(state) then return out end

    local filtered = {}
    for _, s in ipairs(steps) do
        local k = State.key(s.tile)
        visited[k] = true
        local left = points - s.cost
        local ok
        if left <= 0 then ok = not Rebel.forbiddenStop(state, s.tile)
        else ok = canEndAllowed(state, s.tile, left, visited) end
        visited[k] = nil
        if ok then filtered[#filtered + 1] = s.tile end
    end
    return #filtered > 0 and filtered or out
end

-- Đẩy Phiến Quân `dir` (1..6) tối đa `steps` ô, dừng trước ô ra ngoài bản đồ hoặc đang cấm đi (Núi trong
-- thời gian khóa). Trả danh sách ô đã đi qua (có thể rỗng); chưa đổi state.
function Rebel.pushPath(state, dir, steps)
    local out, pos = {}, state.rebel
    for _ = 1, steps do
        local d = Hex.DIRECTIONS[dir]
        local n = state.map:get(pos.q + d.q, pos.r + d.r)
        if not n or Movement.stepCost("rebel", n.terrain, state.round) == math.huge then break end
        out[#out + 1] = n
        pos = n
    end
    return out
end

-- Bắt đầu di chuyển: đổ 1d6 làm điểm. Trả points, events (có thể đã dừng ngay nếu không đi được).
function Rebel.startMove(state, roller)
    assert(state.rebel, "chưa có Phiến Quân")
    local points = Dice.rollOne(state.rng)
    state.rebel.pending = { stage = "move", points = points, roller = roller,
                            visited = { [State.key(state.rebel)] = true } }
    local events = { { kind = "rebel_roll", roller = roller, points = points } }
    if #Rebel.legalSteps(state) == 0 then
        for _, e in ipairs(Rebel.stop(state)) do events[#events + 1] = e end
    end
    return points, events
end

-- Bước vào ô (q, r). Trả events. Tự dừng khi hết điểm / không còn bước.
function Rebel.step(state, q, r)
    local rb = state.rebel
    assert(rb and Rebel.stage(state) == "move", "Phiến Quân không đang di chuyển")
    local target
    for _, t in ipairs(Rebel.legalSteps(state)) do
        if t.q == q and t.r == r then target = t end
    end
    assert(target, "bước đi không hợp lệ")

    local cost = Movement.stepCost("rebel", target.terrain, state.round)
    local from = { q = rb.q, r = rb.r }
    rb.pending.points = rb.pending.points - cost
    rb.q, rb.r = target.q, target.r
    rb.pending.visited = rb.pending.visited or {}
    rb.pending.visited[State.key(target)] = true
    local events = { { kind = "rebel_step", from = from, to = { q = target.q, r = target.r },
                       left = rb.pending.points } }
    if rb.pending.points <= 0 or #Rebel.legalSteps(state) == 0 then
        for _, e in ipairs(Rebel.stop(state)) do events[#events + 1] = e end
    elseif Roads.damagePass(state, target) then   -- đi qua (không dừng): Đường Đất bị xóa, Lát Đá miễn nhiễm
        events[#events + 1] = { kind = "road_damaged", q = target.q, r = target.r, lost = true }
    end
    return events
end

-- ─── Dừng và hiệu ứng ───────────────────────────────────────────────────────

-- Chủ của công trình / HQ tại tile, hoặc nil.
local function ownerAt(state, tile)
    local b = Structures.at(state, tile)
    if b then return b.owner end
    for pid, p in ipairs(state.players) do
        if p.hq and p.hq.q == tile.q and p.hq.r == tile.r then return pid end
        for _, s in ipairs(p.subs or {}) do
            if s.q == tile.q and s.r == tile.r then return pid end
        end
    end
    return nil
end

local function applyLoss(state, owner, roller, resKey, amount)
    local victim = state.players[owner]
    local lost = math.min(amount, victim.res[resKey])
    local gained = math.ceil(lost / 2)
    victim.res[resKey] = victim.res[resKey] - lost
    local taker = state.players[roller]
    taker.res[resKey] = taker.res[resKey] + gained
    return lost, gained
end

-- Phiến Quân dừng. Trả events. Có thể để lại pending.stage = "loss" nếu chủ phải chọn loại.
function Rebel.stop(state)
    local rb = state.rebel
    local roller = rb.pending and rb.pending.roller
    local tile = state.map:get(rb.q, rb.r)
    rb.pending = nil
    local events = { { kind = "rebel_stop", q = rb.q, r = rb.r, roller = roller } }

    -- dừng trên đường: Đất mất, Lát Đá tụt về Đất (Data §6.2)
    local hadStone = Roads.isStone(state, tile)
    if Roads.damageStop(state, tile) then
        events[#events + 1] = { kind = "road_damaged", q = rb.q, r = rb.r, lost = not hadStone }
    end

    -- đơn vị đứng trên ô bị tiêu hủy ngay, không kiểm tra (Data §5 "PQ đè lên đơn vị")
    local doomed = {}
    for uid, u in pairs(state.units) do
        if u.q == rb.q and u.r == rb.r then doomed[#doomed + 1] = uid end
    end
    table.sort(doomed)
    for _, uid in ipairs(doomed) do
        local u = state.units[uid]
        events[#events + 1] = { kind = "unit_destroyed", uid = uid, unit = u.type, pid = u.owner,
                                q = u.q, r = u.r, reason = "rebel" }
        state.units[uid] = nil
    end

    local owner = ownerAt(state, tile)
    if not owner or owner == roller then return events end

    local victim = state.players[owner]
    local max, options = 0, {}
    for _, r in ipairs(Resources.core) do
        local have = victim.res[r.key]
        if have > max then max, options = have, { r.key }
        elseif have == max and have > 0 then options[#options + 1] = r.key end
    end
    if max <= 0 then return events end

    local amount = math.ceil(max / 2)
    if #options == 1 then
        local lost, gained = applyLoss(state, owner, roller, options[1], amount)
        events[#events + 1] = { kind = "rebel_loss", victim = owner, roller = roller,
                                res = options[1], lost = lost, gained = gained }
    else
        rb.pending = { stage = "loss", owner = owner, roller = roller, amount = amount, options = options }
        events[#events + 1] = { kind = "rebel_choose", victim = owner, roller = roller,
                                amount = amount, options = options }
    end
    return events
end

-- Chủ chọn loại tài nguyên bị mất khi hòa. Trả events.
function Rebel.resolveLoss(state, resKey)
    local rb = state.rebel
    assert(rb and Rebel.stage(state) == "loss", "không có lựa chọn nào đang chờ")
    local p = rb.pending
    local valid = false
    for _, k in ipairs(p.options) do if k == resKey then valid = true end end
    assert(valid, "loại tài nguyên không nằm trong lựa chọn")
    rb.pending = nil
    local lost, gained = applyLoss(state, p.owner, p.roller, resKey, p.amount)
    return { { kind = "rebel_loss", victim = p.owner, roller = p.roller, res = resKey,
               lost = lost, gained = gained } }
end

return Rebel
