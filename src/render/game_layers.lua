-- Các lớp vẽ của ván chơi M1 (lãnh thổ, công trình, Phiến Quân, highlight) đặt lên trên bản đồ của
-- src/render/map_renderer.lua. Tất cả vẽ trong không gian thế giới (đã qua camera:attach()).
-- Chữ trên bản đồ dùng font mặc định, chỉ ASCII (KT, KH, PQ, số).

local Hex         = require("src.core.hex")
local MapRenderer = require("src.render.map_renderer")
local Buildings   = require("src.data.buildings")
local Structures  = require("src.core.structures")

local L = {}

local hexPolygon = MapRenderer.hexPolygon
local tileCenter = MapRenderer.tileCenter
local PLAYER     = MapRenderer.PLAYER_COLORS

-- Cạnh của hex theo hướng Hex.DIRECTIONS (E, NE, NW, W, SW, SE) -> cặp đỉnh trong hexPolygon
-- (đỉnh 1 = trên cùng, rồi theo chiều kim đồng hồ).
local EDGE = { { 2, 3 }, { 1, 2 }, { 6, 1 }, { 5, 6 }, { 4, 5 }, { 3, 4 } }

local RES_COLOR = {
    science = { 0.38, 0.68, 1.00 }, culture = { 0.78, 0.50, 0.96 }, engineering = { 0.96, 0.62, 0.28 },
    faith = { 0.96, 0.96, 0.74 }, gold = { 0.98, 0.82, 0.25 },
}

local function key(tile) return tile.q .. "," .. tile.r end

-- Chữ nhỏ canh giữa tại (cx, cy).
local function worldText(text, cx, cy, scale)
    local font = love.graphics.getFont()
    local w = font:getWidth(text) * scale
    love.graphics.print(text, cx - w / 2, cy - font:getHeight() * scale / 2, 0, scale, scale)
end

-- Gạch chéo trong một hex (ô Tranh chấp).
local function hatch(cx, cy, color, zoom)
    love.graphics.stencil(function() love.graphics.polygon("fill", hexPolygon(cx, cy)) end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
    love.graphics.setColor(color[1], color[2], color[3], 0.8)
    love.graphics.setLineWidth(1 / zoom)
    for off = -16, 16, 5 do
        love.graphics.line(cx + off - 8, cy + 10, cx + off + 8, cy - 10)
    end
    love.graphics.setLineWidth(1)
    love.graphics.setStencilTest()
end

-- Vùng ảnh hưởng chưa sở hữu quanh HQ/Sub: tô nhạt màu phe (GDD §7.1: bỏ phiếu/mua ô được, chưa xây được).
function L.drawInfluence(state, opts)
    local Territory = require("src.core.territory")
    for pid in ipairs(state.players) do
        local pc = PLAYER[pid]
        for _, a in ipairs(Territory.anchors(state, pid)) do
            for _, h in ipairs(Hex.range(a, a.radius)) do
                local t = state.map:get(h.q, h.r)
                if t and state.owner[key(t)] ~= pid then
                    local cx, cy = tileCenter(t)
                    love.graphics.setColor(pc[1], pc[2], pc[3], 0.10)
                    love.graphics.polygon("fill", hexPolygon(cx, cy))
                    love.graphics.setColor(pc[1], pc[2], pc[3], 0.35)
                    love.graphics.setLineWidth(1 / (opts.zoom or 1))
                    love.graphics.polygon("line", hexPolygon(cx, cy))
                    love.graphics.setLineWidth(1)
                end
            end
        end
    end
    love.graphics.setColor(1, 1, 1)
end

-- Lãnh thổ: tô màu chủ, viền ở cạnh giáp ô khác chủ, gạch chéo ô Tranh chấp kèm phiếu/ngưỡng.
-- opts = { zoom, thresholdFn = function(tile, pid) -> số phiếu cần }
function L.drawTerritory(state, opts)
    local zoom = opts.zoom or 1
    local map = state.map

    for _, tile in ipairs(map.list) do
        local owner = state.owner[key(tile)]
        if owner then
            local cx, cy = tileCenter(tile)
            local pc = PLAYER[owner]
            love.graphics.setColor(pc[1], pc[2], pc[3], 0.24)
            love.graphics.polygon("fill", hexPolygon(cx, cy))
        end
    end

    for _, tile in ipairs(map.list) do
        local k = key(tile)
        local owner = state.owner[k]
        local cx, cy = tileCenter(tile)

        if owner then
            local pc = PLAYER[owner]
            local poly = hexPolygon(cx, cy)
            love.graphics.setColor(pc[1], pc[2], pc[3], 0.95)
            love.graphics.setLineWidth(2 / zoom)
            for d = 1, 6 do
                local dir = Hex.DIRECTIONS[d]
                local n = map:get(tile.q + dir.q, tile.r + dir.r)
                if n and state.owner[key(n)] ~= owner then
                    local a, b = EDGE[d][1], EDGE[d][2]
                    love.graphics.line(poly[2 * a - 1], poly[2 * a], poly[2 * b - 1], poly[2 * b])
                end
            end
            love.graphics.setLineWidth(1)
        end

        local v = state.votes[k]
        if v then
            local leader, best, rival = nil, 0, false
            for pid, n in pairs(v) do
                if n > best then leader, best = pid, n end
                if pid ~= owner and n > 0 then rival = true end
            end
            if leader and (not owner or rival) then
                hatch(cx, cy, PLAYER[leader], zoom)
                local need = opts.thresholdFn and opts.thresholdFn(tile, leader)
                love.graphics.setColor(0, 0, 0, 0.75)
                love.graphics.circle("fill", cx, cy, 5.5)
                love.graphics.setColor(1, 1, 1)
                worldText(need and (best .. "/" .. need) or tostring(best), cx, cy, 0.4)
            end
        end
    end
    love.graphics.setColor(1, 1, 1)
end

-- Công trình, Nhà Chính, Khu Trực Thuộc.
function L.drawBuildings(state, opts)
    local zoom = opts.zoom or 1

    for _, b in ipairs(Structures.list(state)) do
        do
            local tiles = Structures.tilesOf(state, b)
            local pcol = PLAYER[b.owner]
            -- footprint nhiều ô: tô nhạt + viền màu chủ quanh từng ô
            if #tiles > 1 then
                for _, t in ipairs(tiles) do
                    local tx, ty = tileCenter(t)
                    love.graphics.setColor(pcol[1], pcol[2], pcol[3], 0.22)
                    love.graphics.polygon("fill", hexPolygon(tx, ty))
                    love.graphics.setColor(pcol[1], pcol[2], pcol[3], 0.9)
                    love.graphics.setLineWidth(1.5 / zoom)
                    love.graphics.polygon("line", hexPolygon(tx, ty))
                    love.graphics.setLineWidth(1)
                    if t ~= tiles[1] then
                        love.graphics.setColor(pcol[1], pcol[2], pcol[3], 0.9)
                        love.graphics.circle("fill", tx, ty, 2.2)
                    end
                end
            end
            local cx, cy = tileCenter(tiles[1])
            local def = Buildings.byId[b.id]
            local rc, pc = RES_COLOR[def.main], PLAYER[b.owner]
            love.graphics.setColor(0, 0, 0, 0.45)
            love.graphics.circle("fill", cx, cy + 1, 7.5)
            love.graphics.setColor(rc[1], rc[2], rc[3])
            love.graphics.circle("fill", cx, cy, 6.5)
            love.graphics.setColor(pc[1], pc[2], pc[3])
            love.graphics.setLineWidth(2 / zoom)
            love.graphics.circle("line", cx, cy, 6.5)
            love.graphics.setLineWidth(1)
            love.graphics.setColor(0.08, 0.08, 0.1)
            worldText(def.icon, cx, cy, 0.42)
            if b.level > 1 then
                love.graphics.setColor(1, 1, 1)
                worldText(tostring(b.level), cx + 6, cy - 6, 0.4)
            end
            if b.demolishing then   -- chờ dỡ: gạch chéo đỏ trên mọi ô
                love.graphics.setColor(0.95, 0.25, 0.2, 0.9)
                love.graphics.setLineWidth(2 / zoom)
                for _, t in ipairs(tiles) do
                    local tx, ty = tileCenter(t)
                    love.graphics.line(tx - 6, ty - 6, tx + 6, ty + 6)
                    love.graphics.line(tx - 6, ty + 6, tx + 6, ty - 6)
                end
                love.graphics.setLineWidth(1)
            end
        end
    end

    for pid, p in ipairs(state.players) do
        local anchors = {}
        if p.hq then anchors[#anchors + 1] = { at = p.hq, scale = 1, level = p.hqLevel } end
        for _, sub in ipairs(p.subs or {}) do anchors[#anchors + 1] = { at = sub, scale = 0.7, level = sub.level } end
        for _, item in ipairs(anchors) do
            local cx, cy = tileCenter(item.at)
            local pc, s = PLAYER[pid], item.scale
            love.graphics.setColor(0, 0, 0, 0.45)
            love.graphics.ellipse("fill", cx, cy + 6 * s, 8 * s, 3 * s)
            love.graphics.setColor(pc[1], pc[2], pc[3])
            love.graphics.rectangle("fill", cx - 5 * s, cy - 2 * s, 10 * s, 7 * s)
            love.graphics.polygon("fill", cx - 7 * s, cy - 2 * s, cx, cy - 9 * s, cx + 7 * s, cy - 2 * s)
            love.graphics.setColor(1, 1, 1)
            love.graphics.setLineWidth(1.5 / zoom)
            love.graphics.rectangle("line", cx - 5 * s, cy - 2 * s, 10 * s, 7 * s)
            love.graphics.polygon("line", cx - 7 * s, cy - 2 * s, cx, cy - 9 * s, cx + 7 * s, cy - 2 * s)
            love.graphics.setLineWidth(1)
            if item.level and item.level > 1 then
                love.graphics.setColor(0.08, 0.08, 0.1)
                worldText(tostring(item.level), cx, cy + 2 * s, 0.45)
            end
        end
    end
    love.graphics.setColor(1, 1, 1)
end

-- Đường: nét nối tâm các ô có đường kề nhau (nâu = Đường Đất, xám sáng đậm hơn = Lát Đá) và chấm ở mỗi ô.
function L.drawRoads(state, opts)
    local zoom = opts.zoom or 1
    local function colorOf(road)
        if road.level >= 2 then return 0.82, 0.82, 0.86, 3.2 end
        return 0.62, 0.45, 0.27, 2.2
    end
    for _, t in ipairs(state.map.list) do
        local road = state.roads[key(t)]
        if road then
            local cx, cy = tileCenter(t)
            local r, g, b, w = colorOf(road)
            for _, nb in ipairs(state.map:neighbors(t)) do
                local nr = state.roads[key(nb)]
                if nr and key(nb) > key(t) then
                    local nx, ny = tileCenter(nb)
                    love.graphics.setColor(0, 0, 0, 0.4)
                    love.graphics.setLineWidth((w + 1.2) / zoom)
                    love.graphics.line(cx, cy, nx, ny)
                    local r2, g2, b2, w2 = colorOf(nr)
                    love.graphics.setColor((r + r2) / 2, (g + g2) / 2, (b + b2) / 2)
                    love.graphics.setLineWidth(math.min(w, w2) / zoom)
                    love.graphics.line(cx, cy, nx, ny)
                end
            end
            love.graphics.setColor(0, 0, 0, 0.45)
            love.graphics.circle("fill", cx, cy, w * 0.9 + 0.8)
            love.graphics.setColor(r, g, b)
            love.graphics.circle("fill", cx, cy, w * 0.9)
        end
    end
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1)
end

local UNIT_LETTER = { expedition = "VC", knight = "HS", trade = "GT" }

-- Đơn vị: huy hiệu tròn màu phe, chữ viết tắt, điểm di chuyển còn lại; vòng vàng = đang chọn,
-- khiên nhỏ = Trú Đóng, mờ = đã hành động. Nhiều đơn vị cùng ô thì xếp lệch nhau. opts = { zoom, selected = uid }
function L.drawUnits(state, opts)
    local zoom = opts.zoom or 1
    local count = {}
    local units = {}
    for _, u in pairs(state.units) do units[#units + 1] = u end
    table.sort(units, function(a, b) return a.uid < b.uid end)
    for _, u in ipairs(units) do
        local tile = state.map:get(u.q, u.r)
        local cx, cy = tileCenter(tile)
        local k = u.q .. "," .. u.r
        local idx = count[k] or 0
        count[k] = idx + 1
        cx, cy = cx - 7 + idx * 5, cy + 7 - idx * 2
        local pc = PLAYER[u.owner]
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.circle("fill", cx, cy + 1, 5.6)
        local a = u.acted and 0.55 or 1
        love.graphics.setColor(pc[1], pc[2], pc[3], a)
        love.graphics.circle("fill", cx, cy, 4.8)
        love.graphics.setColor(1, 1, 1, a)
        love.graphics.setLineWidth(1 / zoom)
        love.graphics.circle("line", cx, cy, 4.8)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(0.05, 0.06, 0.1, a)
        worldText(UNIT_LETTER[u.type] or "?", cx, cy, 0.33)
        if u.mp > 0 then
            love.graphics.setColor(1, 1, 1, 0.95)
            worldText(tostring(u.mp), cx + 5, cy - 5, 0.4)
        end
        if u.garrison then
            love.graphics.setColor(0.9, 0.9, 0.35)
            love.graphics.setLineWidth(1.5 / zoom)
            love.graphics.arc("line", "open", cx, cy, 6.8, math.pi * 0.15, math.pi * 0.85)
            love.graphics.setLineWidth(1)
        end
        if opts.selected == u.uid then
            love.graphics.setColor(1, 0.9, 0.3)
            love.graphics.setLineWidth(2 / zoom)
            love.graphics.circle("line", cx, cy, 7.4)
            love.graphics.setLineWidth(1)
        end
    end
    love.graphics.setColor(1, 1, 1)
end

-- Đường đi xem trước: nối tâm các ô, chữ chi phí ở ô cuối. path = list tile (không gồm ô xuất phát).
function L.drawPath(from, path, cost, zoom)
    if #path == 0 then return end
    love.graphics.setColor(1, 0.9, 0.3, 0.95)
    love.graphics.setLineWidth(2 / zoom)
    local px, py = tileCenter(from)
    for _, t in ipairs(path) do
        local cx, cy = tileCenter(t)
        love.graphics.line(px, py, cx, cy)
        px, py = cx, cy
    end
    love.graphics.setLineWidth(1)
    love.graphics.circle("fill", px, py, 2.5)
    local text = tostring(cost)
    local tw = love.graphics.getFont():getWidth(text) * 0.5 + 6
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", px + 3, py - 12, tw, 9, 2, 2)
    love.graphics.setColor(1, 1, 1)
    worldText(text, px + 3 + tw / 2, py - 7.5, 0.5)
end

-- Phiến Quân + vùng phong tỏa. opts = { zoom, time }
function L.drawRebel(state, opts)
    local rb = state.rebel
    if not rb then return end
    local zoom, time = opts.zoom or 1, opts.time or 0
    local pulse = 0.5 + 0.5 * math.sin(time * 4)

    for _, t in ipairs(require("src.core.rebel").blockade(state)) do   -- rỗng khi Trấn Áp đã hủy phong tỏa
        do
            local cx, cy = tileCenter(t)
            love.graphics.setColor(0.45, 0.02, 0.05, 0.22 + 0.12 * pulse)
            love.graphics.polygon("fill", hexPolygon(cx, cy))
            love.graphics.setColor(0.95, 0.25, 0.2, 0.8)
            love.graphics.setLineWidth(1 / zoom)
            love.graphics.polygon("line", hexPolygon(cx, cy))
            love.graphics.setLineWidth(1)
        end
    end

    local cx, cy = tileCenter(rb)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.ellipse("fill", cx, cy + 7, 8, 3)
    love.graphics.setColor(0.32, 0.03, 0.06)
    love.graphics.circle("fill", cx, cy - 1, 8)
    love.graphics.setColor(1, 0.3, 0.25)
    love.graphics.setLineWidth(2 / zoom)
    love.graphics.circle("line", cx, cy - 1, 8)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1)
    worldText("PQ", cx, cy - 1, 0.5)
end

-- Tô sáng danh sách ô. items = { { tile, color = {r,g,b}, alpha, outline = bool } }
function L.drawHighlights(items, zoom)
    for _, it in ipairs(items) do
        local cx, cy = tileCenter(it.tile)
        local c = it.color
        love.graphics.setColor(c[1], c[2], c[3], it.alpha or 0.28)
        love.graphics.polygon("fill", hexPolygon(cx, cy))
        if it.outline ~= false then
            love.graphics.setColor(c[1], c[2], c[3], 0.95)
            love.graphics.setLineWidth(1.5 / zoom)
            love.graphics.polygon("line", hexPolygon(cx, cy))
            love.graphics.setLineWidth(1)
        end
    end
    love.graphics.setColor(1, 1, 1)
end

-- Vùng khởi đầu chưa ai chọn (pha setup): tô vùng bán kính 2, vòng tròn và số thứ tự.
function L.drawStartPicks(state, zoom, hoverStart)
    for i, st in ipairs(state.map.starts) do
        if not state.takenStarts[i] then
            local tile = state.map:get(st.q, st.r)
            local cx, cy = tileCenter(tile)
            local pc = PLAYER[i]
            love.graphics.setColor(pc[1], pc[2], pc[3], hoverStart == i and 0.55 or 0.3)
            for _, t in ipairs(state.map:range(tile, 2)) do
                local tx, ty = tileCenter(t)
                love.graphics.polygon("fill", hexPolygon(tx, ty))
            end
            love.graphics.setColor(0, 0, 0, 0.75)
            love.graphics.circle("fill", cx, cy, 8)
            love.graphics.setColor(pc[1], pc[2], pc[3])
            love.graphics.setLineWidth(2 / zoom)
            love.graphics.circle("line", cx, cy, 8)
            love.graphics.setLineWidth(1)
            love.graphics.setColor(1, 1, 1)
            worldText(tostring(i), cx, cy, 0.6)
        end
    end
    love.graphics.setColor(1, 1, 1)
end

-- Vòng sóng lan ra khi chiếm ô / xây. pulses = { { tile, t, d } } (t chạy 0..d)
function L.drawPulses(pulses, zoom)
    for _, p in ipairs(pulses) do
        local cx, cy = tileCenter(p.tile)
        local k = p.t / p.d
        love.graphics.setColor(1, 1, 1, (1 - k) * 0.9)
        love.graphics.setLineWidth(2 / zoom)
        love.graphics.circle("line", cx, cy, 6 + 16 * k)
        love.graphics.setLineWidth(1)
    end
    love.graphics.setColor(1, 1, 1)
end

return L
