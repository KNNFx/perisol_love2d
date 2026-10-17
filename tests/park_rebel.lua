-- Giữ Phiến Quân tồn tại trên một ô thật, xa các ô đang dùng trong thế cờ.
-- Thay sentinel (-99,-99): fixture dùng để kiểm invariant hoặc save phải hợp lệ như state thật.
local Hex = require("src.core.hex")
local State = require("src.core.state")

return function(state)
    local avoid = {}
    for _, tile in ipairs(state.map.list) do
        if state.owner[State.key(tile)] then avoid[#avoid + 1] = tile end
    end
    for _, unit in pairs(state.units) do avoid[#avoid + 1] = unit end
    local best, distance
    for _, tile in ipairs(state.map.list) do
        local nearest = math.huge
        for _, other in ipairs(avoid) do nearest = math.min(nearest, Hex.distance(tile, other)) end
        if not distance or nearest > distance then best, distance = tile, nearest end
    end
    assert(best and distance > 1, "không có ô đỗ Phiến Quân ngoài vùng test")
    state.rebel = { q = best.q, r = best.r }
end
