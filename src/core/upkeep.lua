-- Việc đầu lượt của người chơi (trước khi đổ xúc xắc): hoàn tất dỡ công trình, thu nhập thụ động,
-- upkeep đơn vị, reset điểm di chuyển. "Mỗi vòng" = mỗi lượt của chính người chơi (D-014).
-- Thuần Lua, không gọi love.*.
--
-- Các bước đăng ký vào Upkeep.steps (fn(state, pid, events)); chạy theo thứ tự đăng ký.
-- Phase A để trống; phase B..H thêm bước vào đây.

local Upkeep = {}

Upkeep.steps = {}

function Upkeep.register(fn)
    assert(type(fn) == "function", "bước upkeep phải là hàm")
    Upkeep.steps[#Upkeep.steps + 1] = fn
end

-- Chạy mọi bước cho `pid`. Trả events.
function Upkeep.startTurn(state, pid)
    local events = {}
    for _, fn in ipairs(Upkeep.steps) do fn(state, pid, events) end
    return events
end

return Upkeep
