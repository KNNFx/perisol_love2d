-- Cắt sprite từ Image/HexaTiles_Test_V001.png (448×360). Sprite hex 32×32, đặt trên lưới 32px.
-- Mỗi mục: { x, y, overhang } — (x, y) là góc trên-trái ô 32×32, overhang = số pixel cây/nhà
-- nhô lên trên ô (chỉ dùng khi phía trên ô đó trống trong sheet, tránh lẫn sprite khác).
-- Chưa có sprite: Sông riêng, Đầm Lầy, Danh Thắng -> map_renderer vẽ đa giác màu thay thế.

local C = require("src.config.constants")

local Tileset = {}

local SPRITES = {
    plains     = { { 128, 128, 0 }, { 192, 128, 0 } },
    forest     = { { 96, 32, 4 }, { 160, 32, 4 }, { 32, 64, 4 }, { 128, 64, 4 },
                   { 64, 96, 4 }, { 160, 96, 4 }, { 224, 32, 4 }, { 256, 32, 4 } },
    tundra     = { { 192, 64, 4 } },
    desert     = { { 256, 96, 0 }, { 320, 96, 0 } },
    coast      = { { 128, 192, 0 } },
    water      = { { 160, 192, 0 }, { 192, 192, 0 }, { 160, 224, 0 } },
    hills      = { { 224, 160, 4 } },
    mountain   = { { 256, 160, 0 }, { 288, 160, 0 } },
    snow       = { { 320, 192, 4 }, { 352, 192, 4 } },
    settlement = { { 224, 224, 4 }, { 256, 224, 4 } },
}

Tileset.IMAGE_PATH = "Image/HexaTiles_Test_V001.png"

function Tileset.load()
    local self = setmetatable({}, { __index = Tileset })
    self.image = love.graphics.newImage(Tileset.IMAGE_PATH)
    self.image:setFilter("nearest", "nearest")
    local iw, ih = self.image:getDimensions()
    self.quads = {}
    for key, list in pairs(SPRITES) do
        self.quads[key] = {}
        for i, s in ipairs(list) do
            local x, y, oh = s[1], s[2], s[3]
            self.quads[key][i] = {
                quad = love.graphics.newQuad(x, y - oh, C.TILE_W, C.TILE_H + oh, iw, ih),
                overhang = oh,
            }
        end
    end
    return self
end

function Tileset:has(key) return key ~= nil and self.quads[key] ~= nil end

-- Chọn biến thể tất định theo tọa độ ô để map không nhấp nháy khi vẽ lại.
function Tileset:variant(key, q, r)
    local list = self.quads[key]
    return list[(q * 7919 + r * 104729) % #list + 1]
end

-- Vẽ sprite với tâm ô tại (cx, cy) trong tọa độ thế giới.
function Tileset:draw(key, q, r, cx, cy)
    local v = self:variant(key, q, r)
    love.graphics.draw(self.image, v.quad, cx - C.TILE_W / 2, cy - C.TILE_H / 2 - v.overhang)
end

return Tileset
