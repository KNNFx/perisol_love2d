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
local Movement  = require("src.data.movement")
local Resources = require("src.data.resources")

local Rebel = {}

-- ─── Phong tỏa ──────────────────────────────────────────────────────────────

-- Vùng phong tỏa: ô Phiến Quân đứng + 6 ô kề (REBEL_BLOCKADE_TILES = 7), chỉ gồm ô trong bản đồ.
function Rebel.blockade(state)
    local out = {}
    local rb = state.rebel
    if not rb then return out end
    for _, h in ipairs(Hex.range(rb, 1)) do
        local t = state.map:get(h.q, h.r)
        if t then out[#out + 1] = t end
    end
    return out
end

-- true nếu ô `tile` đang bị Phiến Quân phong tỏa.
function Rebel.isBlockaded(state, tile)
    local rb = state.rebel
    return rb ~= nil and Hex.distance(rb, tile) <= 1
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

-- Các ô kề Phiến Quân có thể bước vào với số điểm còn lại (không đi lại ô đã qua trong lần này).
function Rebel.legalSteps(state)
    local out = {}
    local rb = state.rebel
    if not rb or Rebel.stage(state) ~= "move" then return out end
    local here = state.map:get(rb.q, rb.r)
    local points = rb.pending.points
    for _, n in ipairs(state.map:neighbors(here)) do
        local seen = rb.pending.visited and rb.pending.visited[State.key(n)]   -- GDD §6.2: không đi lại ô cũ
        if not seen and Movement.stepCost("rebel", n.terrain, state.round) <= points then out[#out + 1] = n end
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
    end
    return events
end

-- ─── Dừng và hiệu ứng ───────────────────────────────────────────────────────

-- Chủ của công trình / HQ tại tile, hoặc nil.
local function ownerAt(state, tile)
    local b = state.buildings[State.key(tile)]
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
