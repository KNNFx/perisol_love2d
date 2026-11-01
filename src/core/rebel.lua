-- Phiến Quân (U-03). Luật: docs/Decisions.md D-009, sửa theo GDD 1.6 ở D-020. Thuần Lua, không gọi love.*.
--
-- state.rebel = { q, r, pending = nil
--                         | { stage = "move", points = n, roller = pid, visited = { ["q,r"] = true } }
--                         | { stage = "loss", owner = pid, roller = pid, amount = n, options = { resKey... },
--                             move = { points, roller, visited } } }
-- Người đổ 7 điều khiển từng bước (không undo). Dừng khi hết điểm hoặc không còn ô kề đủ điểm.
-- Ô Nhà Chính là ô chặn: Phiến Quân không vào, không dừng (GDD 1.6 §6.2).
-- Cướp phá khi bước lên (kể cả đi ngang) công trình / Khu Trực Thuộc của người khác: chủ mất ceil(1/2) loại tài nguyên
-- nhiều nhất (hòa -> chủ chọn), người điều khiển nhận toàn bộ số đó; mỗi công trình chỉ bị cướp 1 lần mỗi vòng.
-- Dừng trên ô chưa có chủ có Tài Nguyên Cơ Bản: người điều khiển nhận từ ngân hàng ceil(1/2) mỗi loại.

local C         = require("src.config.constants")
local Hex       = require("src.core.hex")
local Dice      = require("src.core.dice")
local State     = require("src.core.state")
local Structures = require("src.core.structures")
local Roads     = require("src.core.roads")
local Aura      = require("src.core.aura")
local Movement  = require("src.data.movement")
local Resources = require("src.data.resources")
local Rounds    = require("src.core.rounds")
local SpecialsData = require("src.data.specials")

local Rebel = {}

-- Chi phí Phiến Quân vào ô địa hình `terrainId` ở vòng hiện tại (khóa Núi quy đổi theo số vòng của ván).
local function rebelCost(state, terrainId)
    return Movement.stepCost("rebel", terrainId, state.round, Rounds.scale(state, C.REBEL_MOUNTAIN_LOCK_ROUNDS))
end
Rebel.stepCost = rebelCost

-- ─── Phong tỏa ──────────────────────────────────────────────────────────────

-- Vùng phong tỏa: ô Phiến Quân đứng + 6 ô kề (REBEL_BLOCKADE_TILES = 7), chỉ gồm ô trong bản đồ.
function Rebel.blockade(state)
    local out = {}
    local rb = state.rebel
    if not rb or Rebel.isSuppressed(state) then return out end
    for _, h in ipairs(Hex.range(rb, 1)) do
        local t = state.map:get(h.q, h.r)
        if t and not Rebel.isImmuneCentre(state, t) then out[#out + 1] = t end
    end
    return out
end

-- `pid` đang bị quấy phá: có ít nhất 1 ô thực hữu hoặc công trình nằm trong vùng phong tỏa (GDD 1.6 §6.2).
function Rebel.harassed(state, pid)
    for _, t in ipairs(Rebel.blockade(state)) do
        if state.owner[State.key(t)] == pid then return true end
        local b = Structures.at(state, t)
        if b and b.owner == pid then return true end
    end
    return false
end

-- Phiến Quân bị đẩy từ `from` ra `to` (Trấn Áp, Thiên Đàn): nếu `from` nằm trong aura Pháo Đài mà `to` thì không, người kích
-- hoạt Phiến Quân lần cuối mất FORTRESS_TOLL Vàng (GDD 1.6 §8.3). Trả event hoặc nil.
function Rebel.fortressToll(state, from, to)
    local pid = state.rebel and state.rebel.lastRoller
    if not pid then return nil end
    for _, b in ipairs(Aura.each(state, "S-02")) do
        if Aura.covers(state, b, from) and not Aura.covers(state, b, to) then
            local res = state.players[pid].res
            local pay = math.min(SpecialsData.FORTRESS_TOLL, res.gold)
            res.gold = res.gold - pay
            return { kind = "fortress_toll", pid = pid, gold = pay, owner = b.owner }
        end
    end
    return nil
end

-- Trấn Áp thành công hủy phong tỏa trong cả vòng đó (Data §5).
function Rebel.isSuppressed(state)
    local rb = state.rebel
    return rb ~= nil and rb.suppressedRound == state.round
end

-- Ô tâm của Khu Trực Thuộc C3 (Đô Thị Vệ Tinh) miễn nhiễm phong tỏa (Data §9.1).
function Rebel.isImmuneCentre(state, tile)
    for _, p in ipairs(state.players) do
        for _, s in ipairs(p.subs or {}) do
            if (s.level or 1) >= 3 and s.q == tile.q and s.r == tile.r then return true end
        end
    end
    return false
end

-- true nếu ô `tile` đang bị Phiến Quân phong tỏa.
function Rebel.isBlockaded(state, tile)
    local rb = state.rebel
    return rb ~= nil and not Rebel.isSuppressed(state) and Hex.distance(rb, tile) <= 1
        and not Rebel.isImmuneCentre(state, tile)
end

-- Ô Nhà Chính của bất kỳ người chơi nào: ô chặn đối với Phiến Quân.
function Rebel.isHQTile(state, tile)
    for _, p in ipairs(state.players) do
        if p.hq and p.hq.q == tile.q and p.hq.r == tile.r then return true end
    end
    return false
end

-- ─── Cấm dừng cạnh đơn vị Trú Đóng (A-04) ───────────────────────────────────

-- Phiến Quân không được dừng trên ô đơn vị Trú Đóng đứng hoặc ô kề nó.
function Rebel.forbiddenStop(state, tile)
    for _, u in pairs(state.units) do
        if u.garrison and Hex.distance(u, tile) <= 1 then return true end
    end
    return Aura.fortressAt(state, tile) ~= nil     -- aura Pháo Đài S-02: Phiến Quân không được dừng
end

local function anyGarrison(state)
    for _, u in pairs(state.units) do
        if u.garrison then return true end
    end
    for _, b in pairs(state.buildings) do
        if b.id == "S-02" and not b.demolishing then return true end   -- Pháo Đài cũng cấm dừng
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

-- Đặt Phiến Quân sau khi mọi HQ đã được đặt (GDD 1.6 §11.1 bước 4): ở ô trung tâm bản đồ; nếu cách HQ nào dưới
-- REBEL_SPAWN_MIN_HQ_DIST bước (hoặc không đi được) thì dời tới ô hợp lệ gần nhất. Không dùng RNG. Trả ô đã chọn.
function Rebel.spawn(state)
    local map = state.map
    local mid = Hex.fromOffset(math.floor((map.cols - 1) / 2), math.floor((map.rows - 1) / 2))
    local function valid(t, minDist)
        return Movement.stepCost("rebel", t.terrain, 1) < math.huge and not Rebel.isHQTile(state, t)
            and distanceToHQs(state, t) >= minDist
    end
    local best
    for _, minDist in ipairs({ C.REBEL_SPAWN_MIN_HQ_DIST, 1 }) do
        local bestD
        for _, t in ipairs(map.list) do
            if valid(t, minDist) then
                local d = Hex.distance(mid, t)
                if not bestD or d < bestD then best, bestD = t, d end   -- hòa: ô đứng trước trong thứ tự hàng
            end
        end
        if best then break end
    end
    assert(best, "không có ô nào cho Phiến Quân")
    state.rebel = { q = best.q, r = best.r }
    return best
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
        local cost = rebelCost(state, n.terrain)
        if not visited[State.key(n)] and cost <= points and not Rebel.isHQTile(state, n) then
            out[#out + 1] = { tile = n, cost = cost }
        end
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
        if not n or rebelCost(state, n.terrain) == math.huge or Rebel.isHQTile(state, n) then break end
        out[#out + 1] = n
        pos = n
    end
    return out
end

-- Bắt đầu di chuyển: đổ 1d6 làm điểm. Trả points, events (có thể đã dừng ngay nếu không đi được).
function Rebel.startMove(state, roller)
    assert(state.rebel, "chưa có Phiến Quân")
    local points = Dice.rollOne(state.rng)
    state.rebel.lastRoller = roller   -- "người kích hoạt PQ" (S-02: mất Vàng khi PQ bị đẩy ra khỏi aura)
    state.rebel.pending = { stage = "move", points = points, roller = roller,
                            visited = { [State.key(state.rebel)] = true } }
    local events = { { kind = "rebel_roll", roller = roller, points = points } }
    if #Rebel.legalSteps(state) == 0 then
        for _, e in ipairs(Rebel.stop(state)) do events[#events + 1] = e end
    end
    return points, events
end

-- Sau khi Phiến Quân bước xong một bước (và xử lý cướp phá): dừng nếu hết điểm / không còn bước, nếu không thì xử lý
-- đường bị đi qua. Trả events.
local function afterStep(state, target)
    local rb = state.rebel
    local events = {}
    if rb.pending.points <= 0 or #Rebel.legalSteps(state) == 0 then
        for _, e in ipairs(Rebel.stop(state)) do events[#events + 1] = e end
    elseif Roads.damagePass(state, target) then   -- đi qua (không dừng): Đường Đất bị xóa, Lát Đá miễn nhiễm
        events[#events + 1] = { kind = "road_damaged", q = target.q, r = target.r, lost = true }
    end
    return events
end

-- Bước vào ô (q, r). Trả events. Tự dừng khi hết điểm / không còn bước. Bước lên công trình của người khác là cướp phá;
-- nếu chủ phải chọn loại tài nguyên (hòa) thì dừng ở stage "loss" và tiếp tục sau khi chọn (Rebel.resolveLoss).
function Rebel.step(state, q, r)
    local rb = state.rebel
    assert(rb and Rebel.stage(state) == "move", "Phiến Quân không đang di chuyển")
    local target
    for _, t in ipairs(Rebel.legalSteps(state)) do
        if t.q == q and t.r == r then target = t end
    end
    assert(target, "bước đi không hợp lệ")

    local cost = rebelCost(state, target.terrain)
    local from = { q = rb.q, r = rb.r }
    rb.pending.points = rb.pending.points - cost
    rb.q, rb.r = target.q, target.r
    rb.pending.visited = rb.pending.visited or {}
    rb.pending.visited[State.key(target)] = true
    local events = { { kind = "rebel_step", from = from, to = { q = target.q, r = target.r },
                       left = rb.pending.points } }
    local pe, waiting = Rebel.plunder(state, target)
    for _, e in ipairs(pe) do events[#events + 1] = e end
    if waiting then return events end
    for _, e in ipairs(afterStep(state, target)) do events[#events + 1] = e end
    return events
end

-- ─── Cướp phá và dừng ───────────────────────────────────────────────────────

-- Chủ và khóa "đã bị cướp" của thứ đang chiếm `tile` (công trình hoặc Khu Trực Thuộc), hoặc nil.
local function plunderTarget(state, tile)
    local b = Structures.at(state, tile)
    if b then return b.owner, "b" .. b.uid end
    for pid, p in ipairs(state.players) do
        for _, s in ipairs(p.subs or {}) do
            if s.q == tile.q and s.r == tile.r then return pid, "s" .. State.key(tile) end
        end
    end
    return nil
end

local function applyLoss(state, owner, roller, resKey, amount)
    local victim = state.players[owner]
    local lost = math.min(amount, victim.res[resKey])
    victim.res[resKey] = victim.res[resKey] - lost
    local taker = state.players[roller]
    taker.res[resKey] = taker.res[resKey] + lost   -- người điều khiển nhận toàn bộ (GDD 1.6 §6.2)
    return lost, lost
end

-- Phiến Quân vừa bước lên `tile`: cướp công trình / Khu Trực Thuộc của người khác nếu chưa bị cướp trong vòng này.
-- Trả events, waiting (true nếu chủ phải chọn loại tài nguyên: pending.stage = "loss").
function Rebel.plunder(state, tile)
    local rb = state.rebel
    local roller = rb.pending and rb.pending.roller
    local owner, pk = plunderTarget(state, tile)
    if not owner or owner == roller then return {}, false end
    state.plundered = state.plundered or {}
    if state.plundered[pk] == state.round then return {}, false end

    local victim = state.players[owner]
    local max, options = 0, {}
    for _, r in ipairs(Resources.core) do
        local have = victim.res[r.key]
        if have > max then max, options = have, { r.key }
        elseif have == max and have > 0 then options[#options + 1] = r.key end
    end
    state.plundered[pk] = state.round
    if max <= 0 then return {}, false end

    local amount = math.ceil(max / 2)
    if #options == 1 then
        local lost, gained = applyLoss(state, owner, roller, options[1], amount)
        return { { kind = "rebel_loss", victim = owner, roller = roller, res = options[1], lost = lost, gained = gained,
                   q = tile.q, r = tile.r } }, false
    end
    local mv = rb.pending
    rb.pending = { stage = "loss", owner = owner, roller = roller, amount = amount, options = options,
                   q = tile.q, r = tile.r, move = { points = mv.points, roller = mv.roller, visited = mv.visited } }
    return { { kind = "rebel_choose", victim = owner, roller = roller, amount = amount, options = options,
               q = tile.q, r = tile.r } }, true
end

-- Phiến Quân dừng. Trả events.
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

    -- ô chưa có chủ có Tài Nguyên Cơ Bản: người điều khiển nhận từ ngân hàng ceil(1/2) mỗi loại (GDD 1.6 §6.2)
    if roller and not state.owner[State.key(tile)] and tile.base then
        local gains = {}
        for _, r in ipairs(Resources.core) do
            local n = tile.base[r.key]
            if n then
                local g = math.ceil(n / 2)
                state.players[roller].res[r.key] = state.players[roller].res[r.key] + g
                gains[r.key] = g
            end
        end
        if next(gains) then events[#events + 1] = { kind = "rebel_bank", roller = roller, gains = gains, q = rb.q, r = rb.r } end
    end
    return events
end

-- Chủ chọn loại tài nguyên bị mất khi hòa. Trả events; sau đó Phiến Quân tiếp tục đi (hoặc dừng nếu hết bước).
function Rebel.resolveLoss(state, resKey)
    local rb = state.rebel
    assert(rb and Rebel.stage(state) == "loss", "không có lựa chọn nào đang chờ")
    local p = rb.pending
    local valid = false
    for _, k in ipairs(p.options) do if k == resKey then valid = true end end
    assert(valid, "loại tài nguyên không nằm trong lựa chọn")
    local lost, gained = applyLoss(state, p.owner, p.roller, resKey, p.amount)
    local events = { { kind = "rebel_loss", victim = p.owner, roller = p.roller, res = resKey, lost = lost,
                       gained = gained, q = p.q, r = p.r } }
    rb.pending = { stage = "move", points = p.move.points, roller = p.move.roller, visited = p.move.visited }
    for _, e in ipairs(afterStep(state, state.map:get(rb.q, rb.r))) do events[#events + 1] = e end
    return events
end

return Rebel
