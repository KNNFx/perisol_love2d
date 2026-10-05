-- Các lớp vẽ của ván chơi M1 (lãnh thổ, công trình, Phiến Quân, highlight) đặt lên trên bản đồ của
-- src/render/map_renderer.lua. Tất cả vẽ trong không gian thế giới (đã qua camera:attach()).
-- Chữ trên bản đồ dùng font mặc định, chỉ ASCII (KT, KH, PQ, số).

local Hex         = require("src.core.hex")
local MapRenderer = require("src.render.map_renderer")
local Buildings   = require("src.data.buildings")

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

    for _, tile in ipairs(state.map.list) do
        local b = state.buildings[key(tile)]
        if b then
            local cx, cy = tileCenter(tile)
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
        end
    end

    for pid, p in ipairs(state.players) do
        local anchors = {}
        if p.hq then anchors[#anchors + 1] = { at = p.hq, scale = 1 } end
        for _, sub in ipairs(p.subs or {}) do anchors[#anchors + 1] = { at = sub, scale = 0.7 } end
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
        end
    end
    love.graphics.setColor(1, 1, 1)
end

-- Phiến Quân + vùng phong tỏa. opts = { zoom, time }
function L.drawRebel(state, opts)
    local rb = state.rebel
    if not rb then return end
    local zoom, time = opts.zoom or 1, opts.time or 0
    local pulse = 0.5 + 0.5 * math.sin(time * 4)

    for _, h in ipairs(Hex.range(rb, 1)) do
        local t = state.map:get(h.q, h.r)
        if t then
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
