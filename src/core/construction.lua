-- Nâng cấp tại chỗ và dỡ công trình (D-014). Thuần Lua, không gọi love.*.
--
--   Construction.cost(state, id, level, anchorTile)       -> chi phí xây/nâng tới `level` (đã giảm theo địa hình)
--   Construction.checkFootprint(state, pid, b, q, r, rot) -> ok, lý do, tiles   (chưa tính tiền)
--   Construction.upgradeOptions(state, uid)               -> { { q, r, rot }, ... } mọi hình hợp lệ (chưa tính tiền)
--   Construction.upgrade(state, uid, q, r, rot)           -> áp dụng (đã qua check)
--   Construction.checkDemolish / demolish                 -> dỡ: gỡ vào đầu lượt kế tiếp của chủ
--   Construction.lostOnDemolish(state, b)                 -> TN sẽ mất nếu dỡ (cho cảnh báo UI)
--
-- Hình mới: đặt hình `shape` của cấp mới với ô gốc tại (q, r), xoay rot × 60°. Hình mới phải chứa mọi ô cũ.

local Hex        = require("src.core.hex")
local Rebel      = require("src.core.rebel")
local Roads      = require("src.core.roads")
local Structures = require("src.core.structures")
local Territory  = require("src.core.territory")
local Upkeep     = require("src.core.upkeep")
local Buildings  = require("src.data.buildings")
local Shapes     = require("src.data.shapes")
local Strategic  = require("src.data.strategic")
local Terrains   = require("src.data.terrains")

local K = {}

-- ─── Chi phí ────────────────────────────────────────────────────────────────

-- Chi phí công trình `id` cấp `level` với ô neo `anchorTile` (hiệu ứng địa hình giảm chi phí, ví dụ Lãnh Nguyên).
function K.cost(state, id, level, anchorTile)
    local def = Buildings.level(id, level)
    local cost = {}
    for k, n in pairs(def.cost) do cost[k] = n end
    local fx = anchorTile and Terrains.byId[anchorTile.terrain].effects
    if fx and fx.buildDiscount then
        for k, n in pairs(fx.buildDiscount) do
            if cost[k] then cost[k] = math.max(0, cost[k] - n) end
        end
    end
    -- TN-08 Đất Màu Mỡ: công trình C1 trên ô này giảm 1 KT chi phí xây
    if level == 1 and anchorTile and cost.engineering
        and Structures.strategicAt(state, anchorTile) == Strategic.FERTILE then
        cost.engineering = math.max(0, cost.engineering - 1)
    end
    return cost
end

-- ─── Khu Chợ cần đường (Data B-05.1/.2: "cần đường nếu không liền HQ") ──────

-- Footprint Khu Chợ C1/C2 phải liền Nhà Chính, hoặc nối đường tới Nhà Chính, hoặc có ô TN-03 Cá (D-014).
-- Chỉ kiểm lúc xây/nâng; mất đường sau đó không tắt chợ. Trả ok, lý do.
function K.marketReach(state, pid, tiles)
    local hq = state.players[pid].hq
    local hqTile = hq and state.map:get(hq.q, hq.r)
    if not hqTile then return false, "Chưa đặt Nhà Chính" end
    for _, t in ipairs(tiles) do
        if Hex.distance(t, hqTile) <= 1 then return true end
        if Structures.strategicAt(state, t) == "TN-03" then return true end
    end
    if Roads.route(state, tiles, { hqTile }) then return true end
    return false, "Khu Chợ phải liền Nhà Chính hoặc nối đường tới Nhà Chính (trừ ô có Cá)"
end

-- ─── Nâng cấp ───────────────────────────────────────────────────────────────

-- Kiểm tra hình mới mà không tính tiền. Trả ok, lý do, tiles (ô cũ đứng trước, rồi ô mới).
function K.checkFootprint(state, pid, b, q, r, rot)
    if not b then return false, "Không có công trình này" end
    if b.owner ~= pid then return false, "Không phải công trình của bạn" end
    if b.demolishing then return false, "Công trình đang chờ dỡ" end
    local newDef = Buildings.level(b.id, b.level + 1)
    if not newDef then return false, "Đã ở cấp tối đa" end

    local cells = Shapes.footprint(newDef.shape, q, r, rot)
    local newTiles, inNew = {}, {}
    for i, c in ipairs(cells) do
        local t = state.map:get(c.q, c.r)
        if not t then return false, "Hình vượt ra ngoài bản đồ" end
        newTiles[i] = t
        inNew[c.q .. "," .. c.r] = t
    end
    for _, k in ipairs(b.tiles) do
        if not inNew[k] then return false, "Hình mới phải chứa các ô của công trình hiện tại" end
    end

    local inOld = {}
    for _, k in ipairs(b.tiles) do inOld[k] = true end
    for _, t in ipairs(newTiles) do
        local k = t.q .. "," .. t.r
        if state.owner[k] ~= pid then return false, "Mọi ô phải là lãnh thổ thực hữu của bạn" end
        if not inOld[k] then
            if Structures.at(state, t) or Territory.isAnchorTile(state, t) then return false, "Có ô đã có công trình" end
        end
        if Rebel.isBlockaded(state, t) then return false, "Có ô đang bị Phiến Quân phong tỏa" end
        if not Buildings.allowedOn(b.id, b.level + 1, t.terrain) then
            return false, "Địa hình " .. Terrains.byId[t.terrain].name .. " không xây được cấp này"
        end
    end

    local ordered = Structures.tilesOf(state, b)
    for _, t in ipairs(newTiles) do
        if not inOld[t.q .. "," .. t.r] then ordered[#ordered + 1] = t end
    end
    if b.id == "B-05" and b.level + 1 <= 2 then
        local okM, whyM = K.marketReach(state, pid, ordered)
        if not okM then return false, whyM end
    end
    return true, nil, ordered
end

-- Mọi hình hợp lệ để nâng `uid` lên cấp kế (không tính tiền). Mỗi phần tử { q, r, rot } là ô gốc + xoay;
-- các hình cho cùng tập ô chỉ liệt kê một lần. Thứ tự tất định.
function K.upgradeOptions(state, uid)
    local b = state.buildings[uid]
    local out = {}
    if not b or b.demolishing then return out end
    local newDef = Buildings.level(b.id, b.level + 1)
    if not newDef then return out end

    local cells, seen = Shapes.cells[newDef.shape], {}
    local oldTiles = Structures.tilesOf(state, b)
    for rot = 0, 5 do
        for _, c in ipairs(cells) do
            local rc = Hex.rotate({ q = c[1], r = c[2] }, rot)
            for _, a in ipairs(oldTiles) do
                local q, r = a.q - rc.q, a.r - rc.r
                local ok, _, tiles = K.checkFootprint(state, b.owner, b, q, r, rot)
                if ok then
                    local keys = {}
                    for i, t in ipairs(tiles) do keys[i] = t.q .. "," .. t.r end
                    table.sort(keys)
                    local sig = table.concat(keys, ";")
                    if not seen[sig] then
                        seen[sig] = true
                        out[#out + 1] = { q = q, r = r, rot = rot }
                    end
                end
            end
        end
    end
    return out
end

-- Áp dụng nâng cấp (đã qua check, kể cả tiền). Trả tile neo.
function K.upgrade(state, uid, q, r, rot)
    local b = state.buildings[uid]
    local ok, why, tiles = K.checkFootprint(state, b and b.owner, b, q, r, rot)
    assert(ok, why)
    Structures.upgrade(state, uid, tiles, b.level + 1, rot)
    return tiles[1]
end

-- ─── Dỡ ─────────────────────────────────────────────────────────────────────

function K.checkDemolish(state, pid, b)
    if not b then return false, "Không có công trình này" end
    if b.owner ~= pid then return false, "Không phải công trình của bạn" end
    if b.demolishing then return false, "Công trình đã được lệnh dỡ" end
    return true
end

-- Danh sách { q, r, tn } các TN sẽ mất vĩnh viễn nếu dỡ `b` (chỉ TN chưa mất).
function K.lostOnDemolish(state, b)
    local out = {}
    for _, t in ipairs(Structures.tilesOf(state, b)) do
        local tn = Structures.strategicAt(state, t)
        if tn then out[#out + 1] = { q = t.q, r = t.r, tn = tn, name = Strategic.byId[tn].name } end
    end
    return out
end

-- Ra lệnh dỡ: công trình ngừng sản xuất ngay, bị gỡ ở đầu lượt kế tiếp của chủ.
function K.demolish(state, uid)
    state.buildings[uid].demolishing = true
end

-- Bước upkeep: gỡ công trình đang chờ dỡ của `pid`; TN trên các ô của nó mất vĩnh viễn (D-014).
function K.completeDemolitions(state, pid, events)
    for _, b in ipairs(Structures.list(state)) do
        if b.owner == pid and b.demolishing then
            local tiles = Structures.tilesOf(state, b)
            local a = tiles[1]
            events[#events + 1] = { kind = "demolished", pid = pid, id = b.id, level = b.level, q = a.q, r = a.r }
            for _, t in ipairs(tiles) do
                local tn = Structures.strategicAt(state, t)
                if tn then
                    state.lostStrategic[t.q .. "," .. t.r] = true
                    events[#events + 1] = { kind = "strategic_lost", pid = pid, tn = tn, q = t.q, r = t.r }
                end
            end
            Structures.remove(state, b.uid)
        end
    end
end

Upkeep.register(K.completeDemolitions)

return K
