-- Ngăn xếp scene (theo skill love2d-core): màn trên cùng nhận input/update,
-- mọi màn được vẽ từ dưới lên để overlay (pause, popup) nằm đè lên màn bên dưới.
-- Scene là bảng với các hàm tùy chọn: enter, leave, update(dt), draw, keypressed, ...

local M = { screens = {} }

function M.current()
    return M.screens[#M.screens]
end

-- Thêm màn lên đỉnh (vd. mở pause đè lên game).
function M.push(scene, ...)
    M.screens[#M.screens + 1] = scene
    if scene.enter then scene:enter(...) end
end

-- Bỏ màn trên đỉnh và trả về nó.
function M.pop()
    local scene = table.remove(M.screens)
    if scene and scene.leave then scene:leave() end
    return scene
end

-- Thay màn trên đỉnh (vd. menu -> game).
function M.switch(scene, ...)
    if #M.screens > 0 then M.pop() end
    M.push(scene, ...)
end

-- Chuyển callback LÖVE tới màn trên cùng nếu nó có hàm đó.
function M.call(name, ...)
    local scene = M.current()
    if scene and scene[name] then return scene[name](scene, ...) end
end

function M.draw()
    for _, scene in ipairs(M.screens) do
        if scene.draw then scene:draw() end
    end
end

return M
