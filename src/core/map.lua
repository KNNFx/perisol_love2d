-- Mô hình bản đồ: lưới chữ nhật cols×rows (offset odd-r), mỗi ô có tọa độ axial.
-- Thuần Lua, không gọi love.*

local Hex = require("src.core.hex")

local Map = {}
Map.__index = Map

-- Tile = { q, r, col, row, terrain (DH-xx), strategic (TN-xx|nil), zone (số người chơi|nil),
--          settlement (id cụm|nil), landmark (id|nil) }
function Map.new(cols, rows)
    local self = setmetatable({ cols = cols, rows = rows, tiles = {}, list = {}, starts = {} }, Map)
    for row = 0, rows - 1 do
        for col = 0, cols - 1 do
            local h = Hex.fromOffset(col, row)
            local tile = { q = h.q, r = h.r, col = col, row = row }
            self.tiles[Hex.key(h)] = tile
            self.list[#self.list + 1] = tile   -- thứ tự hàng trước -> vẽ từ trên xuống
        end
    end
    return self
end

function Map:get(q, r)
    return self.tiles[q .. "," .. r]
end

function Map:getHex(h) return self:get(h.q, h.r) end

function Map:inBounds(q, r) return self:get(q, r) ~= nil end

-- Các ô kề nằm trong bản đồ.
function Map:neighbors(tile)
    local out = {}
    for i = 1, 6 do
        local d = Hex.DIRECTIONS[i]
        local n = self:get(tile.q + d.q, tile.r + d.r)
        if n then out[#out + 1] = n end
    end
    return out
end

-- Các ô trong bán kính `radius` (kể cả tâm) nằm trong bản đồ.
function Map:range(tile, radius)
    local out = {}
    for _, h in ipairs(Hex.range(tile, radius)) do
        local t = self:get(h.q, h.r)
        if t then out[#out + 1] = t end
    end
    return out
end

-- Duyệt theo thứ tự hàng (trên xuống, trái sang phải).
function Map:each()
    local i = 0
    return function()
        i = i + 1
        return self.list[i]
    end
end

function Map:countByTerrain()
    local counts = {}
    for _, t in ipairs(self.list) do
        if t.terrain then counts[t.terrain] = (counts[t.terrain] or 0) + 1 end
    end
    return counts
end

return Map
