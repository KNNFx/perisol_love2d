-- Pipeline modifier. Thứ tự áp dụng (Data §7):
--   Gốc -> Nhân vật -> Công Nghệ -> Công trình (aura) -> TNCL -> Hạ tầng (đường), làm tròn xuống ở cuối.
-- Mỗi hệ thống (nhân vật M3, thẻ công nghệ M2, aura M1.5...) chỉ cần register vào đúng stage.
--
-- Một modifier là hàm fn(value, ctx) -> value mới. Nó KHÔNG làm tròn; chỉ bước cuối mới floor.

local Modifiers = {}
Modifiers.__index = Modifiers

Modifiers.STAGES = { "base", "character", "tech", "aura", "strategic", "road" }

local STAGE_SET = {}
for _, s in ipairs(Modifiers.STAGES) do STAGE_SET[s] = true end

-- Tạo registry rỗng (mỗi test / mỗi hệ thống có thể có registry riêng).
function Modifiers.new()
    local self = setmetatable({ byStage = {} }, Modifiers)
    for _, s in ipairs(Modifiers.STAGES) do self.byStage[s] = {} end
    return self
end

function Modifiers:register(stage, fn)
    assert(STAGE_SET[stage], "stage không hợp lệ: " .. tostring(stage))
    assert(type(fn) == "function", "modifier phải là hàm")
    local list = self.byStage[stage]
    list[#list + 1] = fn
end

-- Áp dụng mọi modifier theo thứ tự stage rồi floor. `base` là giá trị gốc (số >= 0).
function Modifiers:apply(base, ctx)
    local value = base
    for _, stage in ipairs(Modifiers.STAGES) do
        for _, fn in ipairs(self.byStage[stage]) do
            value = fn(value, ctx)
        end
    end
    return math.floor(value)
end

return Modifiers
