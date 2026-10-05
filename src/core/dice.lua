-- Xúc xắc: hai viên d6, mặt 1..5 là tài nguyên (src/data/resources.lua), mặt 6 là Hex.
-- Thuần Lua; mọi ngẫu nhiên đi qua Rng truyền vào.

local C         = require("src.config.constants")
local Resources = require("src.data.resources")

local Dice = {}

-- Đổ hai viên. Trả { a, b }.
function Dice.roll(rng)
    return { rng:int(1, 6), rng:int(1, 6) }
end

-- Đổ một viên (Phiến Quân di chuyển, xếp thứ tự lượt).
function Dice.rollOne(rng)
    return rng:int(1, 6)
end

-- Tổng 7 tính theo số trên mặt (D-008).
function Dice.isSeven(d)
    return d[1] + d[2] == C.SEVEN
end

-- Số viên ra đúng mặt `face`.
function Dice.count(d, face)
    local n = 0
    for i = 1, #d do
        if d[i] == face then n = n + 1 end
    end
    return n
end

function Dice.hexCount(d)
    return Dice.count(d, Resources.HEX_FACE)
end

return Dice
