-- Chế độ test: `lovec.exe . --test` -> không mở cửa sổ/âm thanh.
local function hasFlag(flag)
    for _, a in pairs(arg or {}) do
        if a == flag then return true end
    end
    return false
end

function love.conf(t)
    t.identity = "perisol"          -- thư mục save trong %APPDATA%/LOVE/perisol
    t.version = "11.5"
    t.console = true                -- console Windows để xem print() khi dev (tắt khi đóng gói)

    t.window.title = "Perisol"
    t.window.width = 1280
    t.window.height = 720
    t.window.resizable = true
    t.window.minwidth = 1024
    t.window.minheight = 576
    t.window.vsync = 1

    t.modules.joystick = false      -- không dùng tay cầm
    t.modules.physics = false       -- board game, không cần Box2D

    if hasFlag("--test") then
        t.window = false
        t.console = false
        t.modules.audio = false
        t.modules.sound = false
    end
end
