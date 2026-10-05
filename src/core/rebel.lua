-- Phiến Quân (U-03). Luật: docs/Decisions.md D-009. Thuần Lua, không gọi love.*.

local Hex = require("src.core.hex")

local Rebel = {}

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

return Rebel
