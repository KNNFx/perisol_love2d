-- Ví tài nguyên: nơi DUY NHẤT trong src/core được cộng/trừ `player.res` (xem target `layer` trong Makefile).
-- Thuần Lua, không gọi love.*.
--
--   Wallet.canAfford(res, cost)  -> đủ trả bảng chi phí `cost` ({ gold = 3, ... })? Giá rỗng luôn đủ.
--   Wallet.pay(res, cost)        -> trừ cả bảng; không đủ thì không đổi gì và trả false (không bao giờ để số âm)
--   Wallet.gain(res, key, n)     -> cộng n; Tín Phiếu bị kẹp ở C.BOND_MAX
--   Wallet.take(res, key, n)     -> trừ tối đa n (không quá số đang có); trả số thực trừ (cướp, trừ không thể thiếu)
-- API nội bộ: key phải thuộc Resources, số lượng/số dư phải là số nguyên hữu hạn >= 0.
-- Vi phạm contract ném lỗi TRƯỚC khi ghi; thiếu tiền hợp lệ trả false. Ví có thể thiếu key (coi như 0).

local C = require("src.config.constants")
local Resources = require("src.data.resources")

local W = {}

local function amount(n)
    return type(n) == "number" and n >= 0 and n < math.huge and n == math.floor(n)
end

local function balance(res, key)
    assert(type(res) == "table", "Wallet: ví phải là bảng")
    assert(type(key) == "string" and Resources.byKey[key], "Wallet: tài nguyên không hợp lệ")
    local v = res[key]
    if v == nil then return 0 end
    assert(amount(v), "Wallet: số dư phải là số nguyên hữu hạn không âm")
    if key == "bond" then assert(v <= C.BOND_MAX, "Wallet: Tín Phiếu vượt trần") end
    return v
end

function W.canAfford(res, cost)
    assert(type(res) == "table" and type(cost) == "table", "Wallet: ví và chi phí phải là bảng")
    local enough = true
    for k, n in pairs(cost) do
        assert(amount(n), "Wallet: chi phí phải là số nguyên hữu hạn không âm")
        if balance(res, k) < n then enough = false end
    end
    return enough
end

function W.pay(res, cost)
    if not W.canAfford(res, cost) then return false end
    for k, n in pairs(cost) do
        if n ~= 0 then res[k] = res[k] - n end
    end
    return true
end

function W.gain(res, key, n)
    assert(amount(n), "Wallet: lượng nhận phải là số nguyên hữu hạn không âm")
    local v = balance(res, key) + n
    assert(v < math.huge, "Wallet: số dư vượt giới hạn số")
    if key == "bond" then v = math.min(v, C.BOND_MAX) end   -- tối đa 5 Tín Phiếu
    res[key] = v
end

function W.take(res, key, n)
    assert(amount(n), "Wallet: lượng mất phải là số nguyên hữu hạn không âm")
    local have = balance(res, key)
    local lost = math.min(n, have)
    res[key] = have - lost
    return lost
end

return W
