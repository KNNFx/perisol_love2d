-- Ví tài nguyên: nơi DUY NHẤT trong src/core được cộng/trừ `player.res` (xem target `layer` trong Makefile).
-- Thuần Lua, không gọi love.*.
--
--   Wallet.canAfford(res, cost)  -> đủ trả bảng chi phí `cost` ({ gold = 3, ... })? Giá rỗng luôn đủ.
--   Wallet.pay(res, cost)        -> trừ cả bảng; không đủ thì không đổi gì và trả false (không bao giờ để số âm)
--   Wallet.gain(res, key, n)     -> cộng n; Tín Phiếu bị kẹp ở C.BOND_MAX
--   Wallet.take(res, key, n)     -> trừ tối đa n (không quá số đang có); trả số thực trừ (cướp, trừ không thể thiếu)

local C = require("src.config.constants")

local W = {}

function W.canAfford(res, cost)
    for k, n in pairs(cost) do
        if (res[k] or 0) < n then return false end
    end
    return true
end

function W.pay(res, cost)
    if not W.canAfford(res, cost) then return false end
    for k, n in pairs(cost) do
        if n ~= 0 then res[k] = res[k] - n end
    end
    return true
end

function W.gain(res, key, n)
    local v = (res[key] or 0) + n
    if key == "bond" then v = math.min(v, C.BOND_MAX) end   -- tối đa 5 Tín Phiếu
    res[key] = v
end

function W.take(res, key, n)
    local lost = math.min(n, res[key] or 0)
    res[key] = (res[key] or 0) - lost
    return lost
end

return W
