-- Aura của công trình Đặc Biệt (D-019). Thuần Lua, không gọi love.*. Chỉ phụ thuộc dữ liệu + Structures nên
-- Rebel, Units, Territory và Production đều dùng được mà không vòng phụ thuộc.
--
-- Công trình Đặc Biệt đang chờ dỡ không còn aura. Ô trung tâm = ô neo `b.anchor`.

local Hex        = require("src.core.hex")
local Structures = require("src.core.structures")
local Specials   = require("src.data.specials")

local A = {}

function A.isSpecial(b) return b ~= nil and Specials.byId[b.id] ~= nil end

function A.levelDef(b) return Specials.byId[b.id].levels[b.level] end

-- Ô trung tâm của công trình.
function A.centre(state, b)
    return state.map:get(Hex.unkey(b.anchor))
end

-- Bán kính aura hiện tại.
function A.radius(b) return A.levelDef(b).aura end

-- Công trình Đặc Biệt `id` của người `pid` (nil = mọi người), không chờ dỡ, theo thứ tự uid.
function A.each(state, id, pid)
    local out = {}
    for _, b in ipairs(Structures.list(state)) do
        if b.id == id and not b.demolishing and (not pid or b.owner == pid) then out[#out + 1] = b end
    end
    return out
end

-- `tile` nằm trong aura của `b` (kể cả ô trung tâm).
function A.covers(state, b, tile)
    return Hex.distance(A.centre(state, b), tile) <= A.radius(b)
end

-- Pháo Đài S-02 (của bất kỳ ai, hoặc chỉ `exceptOwner` bị loại) có aura phủ `tile`? Trả công trình đầu tiên.
function A.fortressAt(state, tile, exceptOwner)
    for _, b in ipairs(A.each(state, "S-02")) do
        if b.owner ~= exceptOwner and A.covers(state, b, tile) then return b end
    end
    return nil
end

-- Hệ số phiếu Chi Phối của `pid` trên `tile` (Bảo Tàng S-03: ×1.5 trên Khu Dân Cư / Danh Thắng trong aura).
function A.voteMultiplier(state, pid, tile)
    if not (tile.settlement or tile.landmark) then return 1 end
    for _, b in ipairs(A.each(state, "S-03", pid)) do
        if A.covers(state, b, tile) then return A.levelDef(b).voteMul end
    end
    return 1
end

return A
