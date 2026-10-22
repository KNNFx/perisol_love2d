-- Phiến Quân (U-03). Luật: GDD v1.3 §6.2, §6.3, docs/Decisions.md D-009. Thuần Lua, không gọi love.*.
--
-- state.rebel = { q, r, controller = pid | false, plundered = { [targetId] = round },
--                 pending = nil
--                         | { stage = "move", points = n, roller = pid, visited = { [key] = true } }
--                         | { stage = "loss", owner = pid, roller = pid, amount = n, options = { resKey... },
--                             q = q, r = r, points = n | nil, visited = table | nil } }
-- Người đổ 7 (hoặc dùng Lệnh Đuổi Phiến Quân) điều khiển từng bước (không undo).
-- Ô Nhà Chính (HQ) là ô chặn: Phiến Quân không được bước vào, dừng hoặc bị đẩy vào ô HQ.
-- Mỗi khi bước vào công trình của người khác (kể cả đi xuyên qua): chủ mất ceil(1/2) loại tài nguyên nhiều nhất
-- (hòa -> chủ chọn), người điều khiển nhận toàn bộ số đó; mỗi công trình tối đa 1 lần mỗi vòng.

local C         = require("src.config.constants")
local Wallet = require("src.core.wallet")
local Hex       = require("src.core.hex")
local Dice      = require("src.core.dice")
local State     = require("src.core.state")
local Structures = require("src.core.structures")
local Roads     = require("src.core.roads")
local Aura      = require("src.core.aura")
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
        if t and not Rebel.isImmuneCentre(state, t) then out[#out + 1] = t end
    end
    return out
end

-- Trấn Áp thành công hủy phong tỏa trong cả vòng đó (Data §5).
function Rebel.isSuppressed(state)
    local rb = state.rebel
    return rb and rb.suppressedRound == state.round
end

-- Ô tâm của Khu Trực Thuộc C3 (Đô Thị Vệ Tinh) miễn nhiễm phong tỏa (Data §9.1).
function Rebel.isImmuneCentre(state, tile)
    for _, p in ipairs(state.players) do
        for _, s in ipairs(p.subs) do
            if (s.level or 1) >= 3 and s.q == tile.q and s.r == tile.r then return true end
        end
    end
    return false
end

-- true nếu ô `tile` đang bị Phiến Quân phong tỏa.
function Rebel.isBlockaded(state, tile)
    local rb = state.rebel
    return rb and not Rebel.isSuppressed(state) and Hex.distance(rb, tile) <= 1
        and not Rebel.isImmuneCentre(state, tile)
end

-- true nếu `tile` là ô Nhà Chính (HQ) của bất kỳ người chơi nào (GDD v1.3 §6.2: ô chặn đối với Phiến Quân).
function Rebel.isHQ(state, tile)
    if not tile then return false end
    for _, p in ipairs(state.players) do
        if p.hq and p.hq.q == tile.q and p.hq.r == tile.r then return true end
    end
    return false
end

-- ─── Đếm lượt Bị Quấy Phá & Lệnh Đuổi Phiến Quân (GDD v1.3 §6.2, §6.3) ──────

-- true nếu người chơi `pid` có ít nhất 1 ô thực hữu hoặc công trình nằm trong vùng phong tỏa của Phiến Quân.
function Rebel.isHarassing(state, pid)
    for _, t in ipairs(Rebel.blockade(state)) do
        if state.owner[State.key(t)] == pid then return true end
        local b = Structures.at(state, t)
        if b and b.owner == pid then return true end
    end
    return false
end

-- Reset bộ đếm bị quấy phá về 0 cho mọi người chơi không còn bị Phiến Quân phong tỏa.
function Rebel.refreshHarass(state)
    for pid = 1, state.playerCount do
        local p = state.players[pid]
        if p and (p.harassTurns or 0) > 0 and not Rebel.isHarassing(state, pid) then
            p.harassTurns = 0
        end
    end
end

-- Cập nhật bộ đếm bị quấy phá ở đầu pha Sản Xuất của `pid` (GDD v1.3 §6.2).
function Rebel.onTurnStart(state, pid)
    local p = state.players[pid]
    if not p then return end
    if Rebel.isHarassing(state, pid) then
        p.harassTurns = (p.harassTurns or 0) + 1
    else
        p.harassTurns = 0
    end
end

-- Kiểm tra quyền dùng Lệnh Đuổi Phiến Quân (bị quấy phá > 3 lượt liên tiếp, tức từ lượt thứ 4).
function Rebel.checkExpel(state, pid)
    if not state.rebel then return false, "Không có Phiến Quân" end
    local p = state.players[pid]
    if not p or (p.harassTurns or 0) <= C.REBEL_HARASS_TURNS then
        return false, string.format("Chỉ dùng được khi bị Phiến Quân quấy phá quá %d lượt liên tiếp", C.REBEL_HARASS_TURNS)
    end
    return true
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

-- Đặt Phiến Quân sau khi mọi HQ đã được đặt: ô Đồng Bằng / Lãnh Nguyên / Sa Mạc cách mọi HQ >= 2.
-- Không có thì lấy ô đi được bất kỳ cách HQ >= 2 (rồi >= 1). Trả ô đã chọn.
function Rebel.spawn(state)
    local spawnTerrain = {}
    for _, id in ipairs(C.REBEL_SPAWN_TERRAINS) do spawnTerrain[id] = true end

    local function candidates(preferred, minDist)
        local out = {}
        for _, t in ipairs(state.map.list) do
            local walkable = Movement.stepCost("rebel", t.terrain, 1) < math.huge
            if walkable and not Rebel.isHQ(state, t) and (not preferred or spawnTerrain[t.terrain])
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

-- Nơi DUY NHẤT ghi vị trí Phiến Quân (bước đi, đẩy của Thiên Đình, Trấn Áp, sau này thẻ dời Phiến Quân).
-- Không phát event: mỗi nơi gọi có event riêng (rebel_step, rebel_pushed, suppress). Trả vị trí cũ { q, r }.
function Rebel.moveTo(state, q, r)
    local rb = state.rebel
    local from = { q = rb.q, r = rb.r }
    rb.q, rb.r = q, r
    Rebel.refreshHarass(state)
    return from
end

function Rebel.stage(state)
    local rb = state.rebel
    return rb and rb.pending and rb.pending.stage or nil
end

-- Các bước thô từ `here` với `points` điểm, bỏ ô đã qua (`visited`) và ô HQ. Trả list { tile, cost }.
local function rawSteps(state, here, points, visited)
    local out = {}
    for _, n in ipairs(state.map:neighbors(here)) do
        local cost = Movement.stepCost("rebel", n.terrain, state.round)
        if not visited[State.key(n)] and not Rebel.isHQ(state, n) and cost <= points then
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

-- Đẩy Phiến Quân `dir` (1..6) tối đa `steps` ô, dừng trước ô ra ngoài bản đồ, ô HQ hoặc đang cấm đi (Núi trong
-- thời gian khóa). Trả danh sách ô đã đi qua (có thể rỗng); chưa đổi state.
function Rebel.pushPath(state, dir, steps)
    local out, pos = {}, state.rebel
    for _ = 1, steps do
        local d = Hex.DIRECTIONS[dir]
        local n = state.map:get(pos.q + d.q, pos.r + d.r)
        if not n or Rebel.isHQ(state, n) or Movement.stepCost("rebel", n.terrain, state.round) == math.huge then break end
        out[#out + 1] = n
        pos = n
    end
    return out
end

-- ─── Cướp phá và Dừng (GDD v1.3 §6.2) ───────────────────────────────────────

-- Chủ và mã định danh công trình / Sub tại `tile` (không tính ô HQ vì HQ bị chặn, không tính Sub C3 miễn nhiễm).
local function plunderTarget(state, tile)
    local b = Structures.at(state, tile)
    if b then return b.owner, "b:" .. b.uid end
    if Rebel.isImmuneCentre(state, tile) then return nil, nil end
    for pid, p in ipairs(state.players) do
        for _, s in ipairs(p.subs) do
            if s.q == tile.q and s.r == tile.r then return pid, "sub:" .. State.key(tile) end
        end
    end
    return nil, nil
end

-- Chuyển toàn bộ lượng tài nguyên bị mất của `owner` sang `roller` (GDD v1.3 §6.2: người điều khiển nhận toàn bộ số mất).
local function applyLoss(state, owner, roller, resKey, amount)
    local victim = state.players[owner]
    local lost = Wallet.take(victim.res, resKey, amount)
    local gained = lost
    Wallet.gain(state.players[roller].res, resKey, gained)
    return lost, gained
end

-- Kiểm tra và kích hoạt cướp phá tại `tile` (tối đa 1 lần / công trình / vòng).
-- `keepMove = true` khi Phiến Quân đang đi ngang qua và vẫn còn bước đi tiếp sau khi chủ chọn tài nguyên bị mất.
local function plunderAt(state, tile, roller, events, keepMove)
    if not roller then return end
    local owner, targetId = plunderTarget(state, tile)
    if not owner or owner == roller then return end
    local rb = state.rebel
    if rb.plundered and rb.plundered[targetId] == state.round then return end
    rb.plundered = rb.plundered or {}
    rb.plundered[targetId] = state.round

    local victim = state.players[owner]
    local max, options = 0, {}
    for _, r in ipairs(Resources.core) do
        local have = victim.res[r.key]
        if have > max then max, options = have, { r.key }
        elseif have == max and have > 0 then options[#options + 1] = r.key end
    end
    if max <= 0 then return end

    local amount = math.ceil(max / 2)
    if #options == 1 then
        local lost, gained = applyLoss(state, owner, roller, options[1], amount)
        events[#events + 1] = { kind = "rebel_loss", victim = owner, roller = roller,
                                res = options[1], lost = lost, gained = gained,
                                q = tile.q, r = tile.r }
    else
        local movePend = keepMove and rb.pending or nil
        rb.pending = { stage = "loss", owner = owner, roller = roller, amount = amount, options = options,
                       q = tile.q, r = tile.r,
                       points = movePend and movePend.points or nil,
                       visited = movePend and movePend.visited or nil }
        events[#events + 1] = { kind = "rebel_choose", victim = owner, roller = roller,
                                amount = amount, options = options,
                                q = tile.q, r = tile.r }
    end
end

-- Bắt đầu di chuyển: đổ 1d6 làm điểm. Trả points, events (có thể đã dừng ngay nếu không đi được).
function Rebel.startMove(state, roller)
    assert(state.rebel, "chưa có Phiến Quân")
    local points = Dice.rollOne(state.rng)
    state.rebel.controller = roller
    state.rebel.pending = { stage = "move", points = points, roller = roller,
                            visited = { [State.key(state.rebel)] = true } }
    local events = { { kind = "rebel_roll", roller = roller, points = points } }
    if #Rebel.legalSteps(state) == 0 then
        for _, e in ipairs(Rebel.stop(state)) do events[#events + 1] = e end
    end
    return points, events
end

-- Bước vào ô (q, r). Trả events. Cướp phá ngay khi bước lên công trình đối thủ; tự dừng khi hết điểm / không còn bước.
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
    local roller = rb.pending.roller
    rb.pending.points = rb.pending.points - cost
    Rebel.moveTo(state, target.q, target.r)
    rb.pending.visited = rb.pending.visited or {}
    rb.pending.visited[State.key(target)] = true
    local events = { { kind = "rebel_step", from = from, to = { q = target.q, r = target.r },
                       left = rb.pending.points } }
    if rb.pending.points <= 0 or #Rebel.legalSteps(state) == 0 then
        for _, e in ipairs(Rebel.stop(state)) do events[#events + 1] = e end
    else
        if Roads.damagePass(state, target) then   -- đi qua (không dừng): Đường Đất bị xóa, Lát Đá miễn nhiễm
            events[#events + 1] = { kind = "road_damaged", q = target.q, r = target.r, lost = true }
        end
        plunderAt(state, target, roller, events, true)
    end
    return events
end

-- Phiến Quân dừng. Trả events. Có thể để lại pending.stage = "loss" nếu chủ phải chọn loại.
function Rebel.stop(state)
    local Units = require("src.core.units")   -- nạp muộn: units.lua đã require rebel.lua (tránh vòng); chỉ để gọi Units.remove
    local rb = state.rebel
    local roller = rb.pending and rb.pending.roller or rb.controller
    local tile = state.map:get(rb.q, rb.r)
    rb.pending = nil
    Rebel.refreshHarass(state)
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
        Units.remove(state, uid)
    end

    plunderAt(state, tile, roller, events, false)
    return events
end

-- Chủ chọn loại tài nguyên bị mất khi hòa. Trả events (tiếp tục di chuyển nếu Phiến Quân còn điểm khi đi ngang qua).
function Rebel.resolveLoss(state, resKey)
    local rb = state.rebel
    assert(rb and Rebel.stage(state) == "loss", "không có lựa chọn nào đang chờ")
    local p = rb.pending
    local valid = false
    for _, k in ipairs(p.options) do if k == resKey then valid = true end end
    assert(valid, "loại tài nguyên không nằm trong lựa chọn")
    local lost, gained = applyLoss(state, p.owner, p.roller, resKey, p.amount)
    local events = { { kind = "rebel_loss", victim = p.owner, roller = p.roller, res = resKey,
                       lost = lost, gained = gained, q = p.q or rb.q, r = p.r or rb.r } }
    if p.points and p.points > 0 then
        rb.pending = { stage = "move", points = p.points, roller = p.roller, visited = p.visited }
        if #Rebel.legalSteps(state) == 0 then
            for _, e in ipairs(Rebel.stop(state)) do events[#events + 1] = e end
        end
    else
        rb.pending = nil
    end
    return events
end

return Rebel
