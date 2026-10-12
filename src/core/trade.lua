-- Trao đổi giữa người chơi qua Khu Chợ nối đường (GDD §5.4, D-014, D-016). Thuần Lua, không gọi love.*.
--
--   Trade.route(state, a, b)  -> { fee, length, fromUid, toUid } tuyến rẻ nhất nối Khu Chợ của a và b, hoặc nil
--   Trade.check(state, from, to, give, get) -> ok, lý do, route
--   Trade.bankRate(state, pid)               -> tỉ lệ đổi ngân hàng (4:1, hoặc 1:1 nhờ TN-06 + Khu Chợ C2+)
-- Luật: chỉ người đang lượt đề xuất; mỗi bên đưa >= 1 tài nguyên cốt lõi, KHÔNG loại nào xuất hiện ở cả hai phía
-- (không cho không, không đổi cùng loại); phí = số ô đường × TRADE_FEE_PER_TILE do người đề xuất trả
-- (toàn tuyến Lát Đá: nhân STONE_FEE_FACTOR làm tròn lên; tuyến đi qua TN-10: miễn phí). Khu Chợ C3 trong bán
-- kính MARKET_C3_RADIUS coi như đã nối, phí = số ô trống giữa hai chợ.

local C          = require("src.config.constants")
local Wallet = require("src.core.wallet")
local Hex        = require("src.core.hex")
local Rebel      = require("src.core.rebel")
local Roads      = require("src.core.roads")
local Structures = require("src.core.structures")
local Resources  = require("src.data.resources")

local T = {}

local CORE = {}
for _, r in ipairs(Resources.core) do CORE[r.key] = true end

-- Khu Chợ (B-05) của `pid`: không chờ dỡ. Theo thứ tự uid.
function T.markets(state, pid)
    local out = {}
    for _, b in ipairs(Structures.list(state)) do
        if b.owner == pid and b.id == "B-05" and not b.demolishing then out[#out + 1] = b end
    end
    return out
end

local function blocked(state, tiles)
    for _, t in ipairs(tiles) do
        if Rebel.isBlockaded(state, t) then return true end
    end
    return false
end

local function minDistance(a, b)
    local best = math.huge
    for _, x in ipairs(a) do
        for _, y in ipairs(b) do best = math.min(best, Hex.distance(x, y)) end
    end
    return best
end

-- Phí cho tuyến có `length` ô đường (D-016).
function T.fee(length, stone, harbor)
    if harbor or length == 0 then return 0 end
    local fee = length * C.TRADE_FEE_PER_TILE
    if stone then fee = math.ceil(fee * C.STONE_FEE_FACTOR) end
    return fee
end

-- Tuyến rẻ nhất giữa mọi cặp Khu Chợ (không bị phong tỏa) của hai người. Trả { fee, length, fromUid, toUid } hoặc nil.
function T.route(state, a, b)
    local best
    for _, ma in ipairs(T.markets(state, a)) do
        local ta = Structures.tilesOf(state, ma)
        if not blocked(state, ta) then
            for _, mb in ipairs(T.markets(state, b)) do
                local tb = Structures.tilesOf(state, mb)
                if not blocked(state, tb) then
                    local cand
                    local r = Roads.route(state, ta, tb)
                    if r then cand = { fee = T.fee(r.length, r.stone, r.harbor), length = r.length } end
                    if (ma.level >= 3 or mb.level >= 3) and minDistance(ta, tb) <= C.MARKET_C3_RADIUS then
                        local gap = math.max(0, minDistance(ta, tb) - 1)
                        if not cand or gap * C.TRADE_FEE_PER_TILE < cand.fee then
                            cand = { fee = gap * C.TRADE_FEE_PER_TILE, length = gap }
                        end
                    end
                    if cand and (not best or cand.fee < best.fee or (cand.fee == best.fee and cand.length < best.length)) then
                        best = { fee = cand.fee, length = cand.length, fromUid = ma.uid, toUid = mb.uid }
                    end
                end
            end
        end
    end
    return best
end

-- Tổng số lượng của bảng tài nguyên {res = n}.
local function total(t)
    local n = 0
    for _, v in pairs(t) do n = n + v end
    return n
end

-- Kiểm tra đề xuất `from` -> `to`: give = { [res] = n } người đề xuất đưa, get = { [res] = n } người đề xuất nhận.
-- Dùng cả lúc đề xuất lẫn lúc người nhận chấp nhận. Trả ok, lý do, route.
function T.check(state, from, to, give, get)
    if from == to or not state.players[to] then return false, "Chọn một người chơi khác" end
    if type(give) ~= "table" or type(get) ~= "table" or total(give) < 1 or total(get) < 1 then
        return false, "Mỗi bên phải đưa ít nhất 1 tài nguyên (không cho không)"
    end
    for res, n in pairs(give) do
        if not CORE[res] or n < 0 or n ~= math.floor(n) then return false, "Tài nguyên không hợp lệ" end
        if get[res] and get[res] > 0 and n > 0 then return false, "Không đổi cùng loại tài nguyên" end
    end
    for res, n in pairs(get) do
        if not CORE[res] or n < 0 or n ~= math.floor(n) then return false, "Tài nguyên không hợp lệ" end
    end
    local f, t = state.players[from].res, state.players[to].res
    for res, n in pairs(give) do
        if (f[res] or 0) < n then return false, "Bạn không đủ tài nguyên để đưa" end
    end
    for res, n in pairs(get) do
        if (t[res] or 0) < n then return false, "Đối phương không đủ tài nguyên" end
    end
    if #T.markets(state, from) == 0 then return false, "Bạn cần có Khu Chợ" end
    if #T.markets(state, to) == 0 then return false, "Đối phương chưa có Khu Chợ" end
    local route = T.route(state, from, to)
    if not route then return false, "Hai Khu Chợ chưa được nối bằng đường (hoặc đang bị phong tỏa)" end
    if (f.gold or 0) - (give.gold or 0) < route.fee then
        return false, string.format("Không đủ Vàng trả phí đường (%d V)", route.fee)
    end
    return true, nil, route
end

-- Thực hiện (đã qua check): đổi tài nguyên, trừ phí của người đề xuất. Trả route.
function T.execute(state, from, to, give, get)
    local ok, why, route = T.check(state, from, to, give, get)
    assert(ok, why)
    local f, t = state.players[from].res, state.players[to].res
    assert(Wallet.pay(f, give) and Wallet.pay(t, get), "T.execute: thiếu tài nguyên sau check")
    for res, n in pairs(give) do Wallet.gain(t, res, n) end
    for res, n in pairs(get) do Wallet.gain(f, res, n) end
    assert(Wallet.pay(f, { gold = route.fee }), "T.execute: không đủ Vàng trả phí đường")
    return route
end

-- Tỉ lệ đổi ngân hàng: TN-06 Vàng Sa Khoáng + Khu Chợ C2+ của mình trên ô đó -> 1:1 (Data, bonus công trình).
function T.bankRate(state, pid)
    for _, m in ipairs(T.markets(state, pid)) do
        if m.level >= 2 then
            for _, tile in ipairs(Structures.tilesOf(state, m)) do
                if Structures.strategicAt(state, tile) == "TN-06" then return C.TN06_MARKET_RATE end
            end
        end
    end
    return C.BANK_TRADE_RATE
end

return T
