-- RNG tất định (Park–Miller / MINSTD). Thuần Lua, không phụ thuộc love.math.
-- s_{n+1} = s_n * 48271 mod (2^31 - 1). Tích < 2^47 nên chính xác trên double.

local Rng = {}
Rng.__index = Rng

local MOD, MUL = 2147483647, 48271

local function hashString(str)
    local h = 5381
    for i = 1, #str do h = (h * 33 + str:byte(i)) % MOD end
    return h
end

-- Trộn seed để các seed liền kề không cho dãy tương quan.
local function scramble(seed)
    local s = (seed % (MOD - 1)) + 1
    for _ = 1, 8 do s = (s * MUL) % MOD end
    return s
end

function Rng.new(seed)
    seed = seed or 1
    local base = seed
    local n = type(seed) == "string" and hashString(seed) or math.floor(seed)
    return setmetatable({ base = tostring(base), state = scramble(n) }, Rng)
end

-- Số thực trong [0, 1).
function Rng:next()
    self.state = (self.state * MUL) % MOD
    return (self.state - 1) / (MOD - 1)
end

-- Số nguyên trong [a, b] (bao gồm hai đầu). int(n) = int(1, n).
function Rng:int(a, b)
    if not b then a, b = 1, a end
    return a + math.floor(self:next() * (b - a + 1))
end

function Rng:chance(p) return self:next() < p end

function Rng:pick(list) return list[self:int(1, #list)] end

-- Chọn theo trọng số; weightFn(item) -> số >= 0.
function Rng:weighted(list, weightFn)
    local total = 0
    for _, item in ipairs(list) do total = total + weightFn(item) end
    if total <= 0 then return nil end
    local roll = self:next() * total
    for _, item in ipairs(list) do
        roll = roll - weightFn(item)
        if roll < 0 then return item end
    end
    return list[#list]
end

-- Fisher–Yates tại chỗ; trả lại chính `t`.
function Rng:shuffle(t)
    for i = #t, 2, -1 do
        local j = self:int(1, i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

-- RNG con độc lập, chỉ phụ thuộc seed gốc + tag (không phụ thuộc số lần đã gọi next).
function Rng:fork(tag)
    return Rng.new(self.base .. ":" .. tostring(tag))
end

return Rng
