-- Việc đầu lượt của người chơi (trước khi đổ xúc xắc). "Mỗi vòng" = mỗi lượt của chính người chơi (D-014).
-- Thuần Lua, không gọi love.*.
--
-- Thứ tự chạy khai tường minh ở danh sách bên dưới, không phụ thuộc thứ tự require (D-021):
--   1. demolish   hoàn tất dỡ công trình (TN trên ô mất vĩnh viễn)
--   2. passives   thu nhập thụ động, kèm dọn và đếm nhịp Phái Sinh
--   3. units      reset điểm di chuyển, trả Vàng duy trì đơn vị (thu nhập ở bước 2 trả được upkeep của chính lượt này)
-- Mỗi bước: fn(state, pid, events). M2 (thẻ Nội Tại) thêm bước bằng Upkeep.register, chạy sau ba bước trên.

local Construction = require("src.core.construction")
local Passives     = require("src.core.passives")
local Units        = require("src.core.units")

local Upkeep = {}

Upkeep.steps = {
    { name = "demolish", fn = Construction.completeDemolitions },
    { name = "passives", fn = Passives.step },
    { name = "units",    fn = Units.startTurn },
}

-- Thêm một bước vào cuối danh sách.
function Upkeep.register(fn, name)
    assert(type(fn) == "function", "bước upkeep phải là hàm")
    Upkeep.steps[#Upkeep.steps + 1] = { name = name or "extra", fn = fn }
end

-- Chạy mọi bước cho `pid`. Trả events.
function Upkeep.startTurn(state, pid)
    local events = {}
    for _, st in ipairs(Upkeep.steps) do st.fn(state, pid, events) end
    return events
end

return Upkeep
