-- Công trình Đặc Biệt S-01..S-05 (D-019). Thuần Lua, không gọi love.*.
--
-- Là công trình thường trong state.buildings (id "S-0x", level 1..3 = cấp xây + hai nâng cấp "+1", "+2").
-- Footprint theo hình trong src/data/shapes.lua, mọi ô phải là ô thực hữu của chủ. Mỗi người chơi chỉ có một
-- công trình mỗi loại. Aura xem src/core/aura.lua; module này chứa điều kiện xây/nâng cấp và các khả năng chủ động.

local C          = require("src.config.constants")
local Aura       = require("src.core.aura")
local Derived    = require("src.core.derived")
local Hex        = require("src.core.hex")
local Rebel      = require("src.core.rebel")
local Rng        = require("src.core.rng")
local Dice       = require("src.core.dice")
local State      = require("src.core.state")
local Structures = require("src.core.structures")
local Territory  = require("src.core.territory")
local Movement   = require("src.data.movement")
local Shapes     = require("src.data.shapes")
local Data       = require("src.data.specials")
local Terrains   = require("src.data.terrains")

local S = {}

local key = State.key

S.MIN_HQ_LEVEL = 3   -- HQ C3 cho phép xây Công Trình Đặc Biệt (Data §9.1)

function S.def(id) return Data.byId[id] end

-- Công trình Đặc Biệt `id` của `pid` (không chờ dỡ) hoặc nil. Mỗi người chỉ có một mỗi loại.
function S.owned(state, pid, id)
    return Aura.each(state, id, pid)[1]
end

-- Hoạt động = không chờ dỡ và không ô nào bị Phiến Quân phong tỏa.
function S.isActive(state, b)
    if b.demolishing then return false end
    for _, t in ipairs(Structures.tilesOf(state, b)) do
        if Rebel.isBlockaded(state, t) then return false end
    end
    return true
end

-- ─── Xây ────────────────────────────────────────────────────────────────────

local BLOCKED_TERRAIN = { ["DH-10"] = true, ["DH-11"] = true }   -- Khu Dân Cư / Danh Thắng: chỉ Chi Phối

-- Có công trình Cơ Bản đủ cấp trong bán kính quanh `centre` không?
local function hasPrereq(state, pid, centre, req)
    for _, b in ipairs(Structures.list(state)) do
        if b.owner == pid and b.id == req.id and b.level >= req.level and not b.demolishing then
            if Hex.distance(Aura.centre(state, b), centre) <= req.radius then return true end
        end
    end
    return false
end

-- Kiểm tra xây `id` với hình đặt tại (q, r) xoay `rot` (chưa tính tiền). Trả ok, lý do, tiles (tile đầu = trung tâm).
function S.checkBuild(state, pid, id, q, r, rot)
    local def = Data.byId[id]
    if not def then return false, "Công trình Đặc Biệt không tồn tại" end
    local p = state.players[pid]
    if (p.hqLevel or 1) < S.MIN_HQ_LEVEL then return false, "Cần Nhà Chính cấp " .. S.MIN_HQ_LEVEL .. " để xây Công Trình Đặc Biệt" end
    if S.owned(state, pid, id) then return false, "Bạn đã có " .. def.name end

    local tiles = {}
    for i, c in ipairs(Shapes.footprint(def.shape, q, r, rot or 0)) do
        local t = state.map:get(c.q, c.r)
        if not t then return false, "Hình vượt ra ngoài bản đồ" end
        tiles[i] = t
    end
    local centre = tiles[1]
    if not def.terrains[centre.terrain] then
        return false, "Địa hình " .. Terrains.byId[centre.terrain].name .. " không xây được " .. def.name
    end
    if def.graniteOnMountain and (centre.terrain == "DH-03" or centre.terrain == "DH-12")
        and Structures.strategicAt(state, centre) ~= "TN-01" then
        return false, "Xây trên Núi cần ô có Đá Granite"
    end
    for _, t in ipairs(tiles) do
        if state.owner[key(t)] ~= pid then return false, "Mọi ô phải là lãnh thổ thực hữu của bạn" end
        if Structures.at(state, t) or Territory.isAnchorTile(state, t) then return false, "Có ô đã có công trình" end
        if Rebel.isBlockaded(state, t) then return false, "Có ô đang bị Phiến Quân phong tỏa" end
        if BLOCKED_TERRAIN[t.terrain] then return false, "Không xây trên Khu Dân Cư / Danh Thắng" end
        if def.sameTerrain and t.terrain ~= centre.terrain then return false, "Mọi ô phải cùng một loại địa hình" end
        if not def.sameTerrain and not def.terrains[t.terrain] and not Terrains.byId[t.terrain].canBuild then
            return false, "Có ô địa hình không xây được"
        end
    end
    for _, req in ipairs(def.prereq) do
        if not hasPrereq(state, pid, centre, req) then
            local Buildings = require("src.data.buildings")
            return false, string.format("Cần %s cấp %d trong bán kính %d ô", Buildings.byId[req.id].name, req.level, req.radius)
        end
    end
    if def.needsDerived then
        local ok = false
        for _, inst in ipairs(Derived.list(state, pid)) do
            if inst.id == def.needsDerived and Derived.isActive(state, inst) then ok = true end
        end
        if not ok then return false, "Cần " .. require("src.data.derived").byId[def.needsDerived].name .. " đang hoạt động" end
    end
    return true, nil, tiles
end

-- Trạng thái cho UI: có xây được `id` ở đâu đó không, hoặc lý do chưa được (không tính tài nguyên). Trả ok, lý do.
function S.status(state, pid, id)
    local def = Data.byId[id]
    if (state.players[pid].hqLevel or 1) < S.MIN_HQ_LEVEL then return false, "Cần Nhà Chính cấp " .. S.MIN_HQ_LEVEL end
    if S.owned(state, pid, id) then return false, "Đã có" end
    local Buildings = require("src.data.buildings")
    for _, req in ipairs(def.prereq) do
        local have = false
        for _, b in ipairs(Structures.list(state)) do
            if b.owner == pid and b.id == req.id and b.level >= req.level and not b.demolishing then have = true end
        end
        if not have then return false, string.format("Cần %s cấp %d", Buildings.byId[req.id].name, req.level) end
    end
    if def.needsDerived then
        local ok = false
        for _, inst in ipairs(Derived.list(state, pid)) do
            if inst.id == def.needsDerived and Derived.isActive(state, inst) then ok = true end
        end
        if not ok then return false, "Cần " .. require("src.data.derived").byId[def.needsDerived].name end
    end
    if #S.placements(state, pid, id) == 0 then return false, "Không có chỗ đặt hợp lệ (ô thực hữu liền nhau, đúng địa hình, gần công trình tiên quyết)" end
    return true
end

-- Mọi cách đặt hợp lệ của `id` cho `pid`: { { q, r, rot, tiles } } (hình đối xứng chỉ liệt kê một lần), tất định.
function S.placements(state, pid, id)
    local def = Data.byId[id]
    local out, seen = {}, {}
    if not def or (state.players[pid].hqLevel or 1) < S.MIN_HQ_LEVEL or S.owned(state, pid, id) then return out end
    local rots = (def.shape == "hex7") and 1 or 6
    for _, origin in ipairs(Territory.ownedTiles(state, pid)) do
        for rot = 0, rots - 1 do
            local ok, _, tiles = S.checkBuild(state, pid, id, origin.q, origin.r, rot)
            if ok then
                local keys = {}
                for i, t in ipairs(tiles) do keys[i] = key(t) end
                table.sort(keys)
                local sig = table.concat(keys, ";")
                if not seen[sig] then
                    seen[sig] = true
                    out[#out + 1] = { q = origin.q, r = origin.r, rot = rot, tiles = tiles }
                end
            end
        end
    end
    return out
end

-- Áp dụng xây (đã qua check và thanh toán). Trả công trình.
function S.build(state, pid, id, q, r, rot)
    local ok, why, tiles = S.checkBuild(state, pid, id, q, r, rot)
    assert(ok, why)
    return Structures.place(state, { id = id, level = 1, owner = pid, rot = rot or 0 }, tiles)
end

-- ─── Nâng cấp +1 / +2 ───────────────────────────────────────────────────────

function S.checkUpgrade(state, pid, b)
    if not b or not Data.byId[b.id] then return false, "Không phải công trình Đặc Biệt" end
    if b.owner ~= pid then return false, "Không phải công trình của bạn" end
    if b.demolishing then return false, "Công trình đang chờ dỡ" end
    if b.level >= Data.MAX_LEVEL then return false, "Đã ở cấp tối đa" end
    return true
end

function S.upgradeCost(b)
    local def = Data.byId[b.id]
    return def.levels[b.level + 1] and def.levels[b.level + 1].cost
end

function S.upgrade(state, b) b.level = b.level + 1 end

-- ─── Tháp Thiên Văn S-01: xem trước xúc xắc ─────────────────────────────────

-- Các viên xúc xắc kế tiếp `pid` được xem trước (1 viên, hoặc 2 từ "+2"), hoặc nil. Không đổi RNG.
function S.peekDice(state, pid)
    local b = S.owned(state, pid, "S-01")
    if not b or not S.isActive(state, b) then return nil end
    local n = Aura.levelDef(b).peek or 0
    if n < 1 then return nil end
    local d = Dice.roll(state.rng:copy())
    local out = {}
    for i = 1, n do out[i] = d[i] end
    return out
end

-- ─── Pháo Đài S-02 "Pháo" (+2) ──────────────────────────────────────────────

-- Công trình Cơ Bản cấp 1 của đối thủ trong bán kính STRIKE_RADIUS quanh Pháo Đài `b`.
function S.strikeTargets(state, pid, b)
    local out = {}
    local centre = Aura.centre(state, b)
    for _, t in ipairs(Structures.list(state)) do
        if t.owner ~= pid and t.level == 1 and t.id:sub(1, 2) == "B-" and not t.demolishing
            and Hex.distance(centre, Aura.centre(state, t)) <= Data.STRIKE_RADIUS then
            out[#out + 1] = t
        end
    end
    return out
end

function S.checkStrike(state, pid, uid, targetUid)
    local b = state.buildings[uid]
    if not b or b.id ~= "S-02" or b.owner ~= pid then return false, "Cần Pháo Đài Chiến Lược của bạn" end
    if not Aura.levelDef(b).strike then return false, "Pháo Đài cần nâng cấp +2 để dùng \"Pháo\"" end
    if not S.isActive(state, b) then return false, "Pháo Đài đang không hoạt động" end
    local p = state.players[pid]
    if p.strikeRound and state.round - p.strikeRound < Data.STRIKE_COOLDOWN then
        return false, string.format("\"Pháo\" hồi sau %d vòng nữa", Data.STRIKE_COOLDOWN - (state.round - p.strikeRound))
    end
    for _, t in ipairs(S.strikeTargets(state, pid, b)) do
        if t.uid == targetUid then return true end
    end
    return false, "Mục tiêu phải là công trình cấp 1 của đối thủ trong bán kính " .. Data.STRIKE_RADIUS
end

-- Phá hủy công trình mục tiêu ngay; TN trên ô của nó mất vĩnh viễn như khi dỡ (D-014). Trả events.
function S.strike(state, pid, uid, targetUid)
    local target = state.buildings[targetUid]
    local tiles = Structures.tilesOf(state, target)
    local events = { { kind = "fortress_strike", pid = pid, target = target.owner, id = target.id,
                       q = tiles[1].q, r = tiles[1].r } }
    for _, t in ipairs(tiles) do
        local tn = Structures.strategicAt(state, t)
        if tn then
            state.lostStrategic[key(t)] = true
            events[#events + 1] = { kind = "strategic_lost", pid = target.owner, tn = tn, q = t.q, r = t.r }
        end
    end
    Structures.remove(state, targetUid)
    state.players[pid].strikeRound = state.round
    return events
end

-- ─── Đài Phát Thanh S-04 "Phát Sóng" (+2) ───────────────────────────────────

-- `pid` được dùng "Phát Sóng" ở lần đổ này không? Trả ok, lý do.
function S.checkBroadcast(state, pid)
    local b = S.owned(state, pid, "S-04")
    if not b or not Aura.levelDef(b).broadcast then return false, "Cần Đài Phát Thanh Long Mạch nâng cấp +2" end
    if not S.isActive(state, b) then return false, "Đài Phát Thanh đang không hoạt động" end
    local p = state.players[pid]
    if p.broadcastRound and state.round - p.broadcastRound < Data.BROADCAST_COOLDOWN then
        return false, string.format("Phát Sóng hồi sau %d vòng nữa", Data.BROADCAST_COOLDOWN - (state.round - p.broadcastRound))
    end
    return true
end

-- ─── Thiên Đình S-05 ────────────────────────────────────────────────────────

-- Số lần hủy tổng 7 còn lại của `pid`.
function S.cancel7Left(state, pid)
    local b = S.owned(state, pid, "S-05")
    if not b or b.demolishing then return 0 end   -- Phiến Quân kề không vô hiệu hóa việc hủy 7
    return math.max(0, (Aura.levelDef(b).cancel7 or 0) - (state.players[pid].cancel7Used or 0))
end

-- Người chơi có thể hủy tổng 7 (theo thứ tự pid), đưa roller lên đầu nếu roller có.
function S.cancel7Holders(state, roller)
    local out = {}
    for pid = 1, state.playerCount do
        if S.cancel7Left(state, pid) > 0 then out[#out + 1] = pid end
    end
    table.sort(out, function(a, b)
        if a == roller then return b ~= roller end
        if b == roller then return false end
        return a < b
    end)
    return out
end

-- Các chủ Thiên Đình có aura phủ ô Phiến Quân vừa dừng và đủ TN để đẩy. Trả { { pid, uid } }.
function S.pushHolders(state)
    local out = {}
    local rb = state.rebel
    if not rb then return out end
    for _, b in ipairs(Aura.each(state, "S-05")) do
        local lv = Aura.levelDef(b)
        if not b.demolishing and Aura.covers(state, b, rb) and state.players[b.owner].res.faith >= lv.pushPay then
            if #S.pushCandidates(state, b) > 0 then out[#out + 1] = { pid = b.owner, uid = b.uid } end
        end
    end
    return out
end

-- Ô ngoài aura trong 2 bước quanh Phiến Quân mà Phiến Quân đứng được (Núi khóa không tính), theo thứ tự (r, q).
function S.pushCandidates(state, b)
    local out = {}
    local rb = state.rebel
    for _, h in ipairs(Hex.range(rb, 2)) do
        local t = state.map:get(h.q, h.r)
        if t and not Aura.covers(state, b, t) and Movement.stepCost("rebel", t.terrain, state.round) < math.huge then
            out[#out + 1] = t
        end
    end
    table.sort(out, function(x, y) if x.r ~= y.r then return x.r < y.r end return x.q < y.q end)
    return out
end

-- ─── Bảo Tàng S-03: điểm cuối ván ───────────────────────────────────────────

-- +1 điểm mỗi Khu Dân Cư mà `pid` chi phối (hơn hẳn số ô trong cụm) có ô trong bán kính 3 quanh Bảo Tàng.
function S.museumBonus(state, pid)
    local b = S.owned(state, pid, "S-03")
    if not b or b.demolishing then return 0 end
    local centre = Aura.centre(state, b)
    local n = 0
    for _, cluster in ipairs(state.map.settlements or {}) do
        local controller = Territory.clusterController(state, cluster)
        if controller == pid then
            for _, t in ipairs(cluster.tiles) do
                if Hex.distance(centre, t) <= Data.SCORE_SETTLEMENT_RADIUS then n = n + 1 break end
            end
        end
    end
    return n
end

return S
