-- Ánh xạ phím -> action có tên (skill input-systems): code gameplay/UI chỉ hỏi action, không đọc phím thô.
-- Đổi bảng `bindings` (hoặc nạp từ file cấu hình sau này) để rebind mà không đụng logic.
-- Camera pan (WASD / mũi tên) nằm trong src/render/camera.lua, đọc trạng thái giữ phím liên tục.

local Actions = {}

Actions.bindings = {
    confirm      = { "return", "kpenter", "space" },
    cancel       = { "escape" },
    roll         = { "space", "r" },
    endTurn      = { "e" },
    quicksave    = { "f5" },
    quickload    = { "f9" },
    toggleDebug  = { "f1" },
    toggleZones  = { "z" },
    menuUp       = { "up", "w" },
    menuDown     = { "down", "s" },
    menuLeft     = { "left", "a" },
    menuRight    = { "right", "d" },
    nextTarget   = { "tab" },
}

-- true nếu `key` đang gán cho `action`.
function Actions.matches(action, key)
    local list = Actions.bindings[action]
    if not list then return false end
    for _, k in ipairs(list) do
        if k == key then return true end
    end
    return false
end

-- Tên phím hiển thị cho gợi ý (phím đầu tiên của action).
function Actions.label(action)
    local list = Actions.bindings[action]
    local k = list and list[1] or "?"
    return (k:gsub("^%l", string.upper))
end

return Actions
