-- Vẽ bản đồ hex (pointy-top). Thế giới: ô (0,0) có góc trên-trái ở (0,0).

local C         = require("src.config.constants")
local Hex       = require("src.core.hex")
local Terrains  = require("src.data.terrains")
local Strategic = require("src.data.strategic")

local R = {}

R.LAYOUT = { w = C.TILE_W, stepY = C.TILE_STEP_Y, ox = C.TILE_W / 2, oy = C.TILE_H / 2 }

-- Màu người chơi theo nhân vật (GDD §4.2): Vàng, Xanh dương, Xanh lá, Đỏ.
R.PLAYER_COLORS = {
    { 0.96, 0.78, 0.18 }, { 0.25, 0.55, 0.95 }, { 0.30, 0.80, 0.35 }, { 0.92, 0.28, 0.25 },
}

local RARITY_COLOR = {
    common = { 1, 1, 1 }, uncommon = { 0.4, 0.9, 1 }, rare = { 1, 0.65, 0.2 }, very_rare = { 1, 0.3, 0.9 },
}

-- Kích thước thế giới (px) của bản đồ cols×rows.
function R.worldSize(map)
    return map.cols * C.TILE_W + C.TILE_W / 2, (map.rows - 1) * C.TILE_STEP_Y + C.TILE_H
end

function R.tileCenter(tile)
    return Hex.toPixel(tile, R.LAYOUT)
end

-- Ô nằm dưới điểm thế giới (wx, wy), hoặc nil nếu ngoài bản đồ.
function R.tileAt(map, wx, wy)
    local h = Hex.fromPixel(wx, wy, R.LAYOUT)
    return map:get(h.q, h.r)
end

-- 6 đỉnh hex pointy-top quanh tâm (cx, cy), phẳng thành {x1,y1,x2,y2,...}.
local function hexPolygon(cx, cy)
    local hw, hh, qh = C.TILE_W / 2, C.TILE_H / 2, C.TILE_H / 4
    return {
        cx, cy - hh,   cx + hw, cy - qh,   cx + hw, cy + qh,
        cx, cy + hh,   cx - hw, cy + qh,   cx - hw, cy - qh,
    }
end

R.hexPolygon = hexPolygon   -- dùng chung với src/render/game_layers.lua

local function drawFallback(def, cx, cy)
    local poly = hexPolygon(cx, cy)
    local c = def.color
    love.graphics.setColor(c[1], c[2], c[3])
    love.graphics.polygon("fill", poly)
    love.graphics.setColor(c[1] * 0.55, c[2] * 0.55, c[3] * 0.55)
    love.graphics.setLineWidth(1)
    love.graphics.polygon("line", poly)
end

-- Lượt 1: địa hình, vẽ theo hàng từ trên xuống để hàng dưới đè phần nhô lên.
-- opts = { tileset }
function R.drawTerrain(map, opts)
    local tileset = opts.tileset
    for _, tile in ipairs(map.list) do
        local def = Terrains.byId[tile.terrain]
        local cx, cy = R.tileCenter(tile)
        love.graphics.setColor(1, 1, 1)
        if tileset and tileset:has(def.sprite) then
            tileset:draw(def.sprite, tile.q, tile.r, cx, cy)
        else
            drawFallback(def, cx, cy)
        end
    end
end

-- Lượt 2: lớp phủ của bản đồ (vùng khởi đầu, Danh Thắng, tài nguyên chiến lược).
-- opts = { zoom, showZones }
function R.drawMarkers(map, opts)
    local zoom = opts.zoom or 1
    for _, tile in ipairs(map.list) do
        local cx, cy = R.tileCenter(tile)

        if opts.showZones and tile.zone then
            local pc = R.PLAYER_COLORS[tile.zone]
            love.graphics.setColor(pc[1], pc[2], pc[3], 0.28)
            love.graphics.polygon("fill", hexPolygon(cx, cy))
        end
        if opts.showZones and tile.isStart then
            local pc = R.PLAYER_COLORS[tile.isStart]
            love.graphics.setColor(pc[1], pc[2], pc[3])
            love.graphics.setLineWidth(2 / zoom)
            love.graphics.circle("line", cx, cy, 7)
            love.graphics.setLineWidth(1)
        end

        if tile.landmark then
            love.graphics.setColor(1, 1, 1, 0.95)
            love.graphics.polygon("fill", cx, cy - 5, cx + 4, cy, cx, cy + 5, cx - 4, cy)
            love.graphics.setColor(0.3, 0.1, 0.4)
            love.graphics.polygon("line", cx, cy - 5, cx + 4, cy, cx, cy + 5, cx - 4, cy)
        end

        if tile.strategic then
            local tn = Strategic.byId[tile.strategic]
            local col = RARITY_COLOR[tn.rarity]
            local sx, sy = cx + 8, cy + 7
            love.graphics.setColor(0, 0, 0, 0.7)
            love.graphics.circle("fill", sx, sy, 4.5)
            love.graphics.setColor(col[1], col[2], col[3])
            love.graphics.circle("fill", sx, sy, 3.2)
            if zoom >= 2 then
                love.graphics.setColor(0, 0, 0)
                love.graphics.print(tn.letter, sx - 2.5, sy - 5, 0, 0.45, 0.45)
            end
        end
    end
end

function R.drawHover(tile, zoom, color)
    local cx, cy = R.tileCenter(tile)
    local c = color or { 1, 1, 1 }
    love.graphics.setColor(c[1], c[2], c[3], 0.22)
    love.graphics.polygon("fill", hexPolygon(cx, cy))
    love.graphics.setColor(c[1], c[2], c[3])
    love.graphics.setLineWidth(2 / zoom)
    love.graphics.polygon("line", hexPolygon(cx, cy))
    love.graphics.setLineWidth(1)
end

-- opts = { tileset, hover = tile|nil, zoom = số, showZones = bool }
function R.draw(map, opts)
    R.drawTerrain(map, opts)
    R.drawMarkers(map, opts)
    if opts.hover then R.drawHover(opts.hover, opts.zoom or 1) end
    love.graphics.setColor(1, 1, 1)
end

return R
