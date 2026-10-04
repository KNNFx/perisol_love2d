-- Quản lý scene: scene hiện tại nhận các callback của LÖVE qua manager.call(tên, ...).

local M = { current = nil }

function M.switch(scene, ...)
    if M.current and M.current.leave then M.current:leave() end
    M.current = scene
    if scene.enter then scene:enter(...) end
end

function M.call(name, ...)
    local scene = M.current
    if scene and scene[name] then return scene[name](scene, ...) end
end

return M
