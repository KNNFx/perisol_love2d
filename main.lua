-- Perisol — bootstrap. Logic game nằm trong src/, test trong tests/.

local testMode = false
for _, a in pairs(arg or {}) do
    if a == "--test" then testMode = true end
end

if testMode then
    function love.load()
        local code = require("tests.runner").run()
        love.event.quit(code)
    end
    return
end

local manager = require("src.scenes.manager")

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest") -- pixel art
    love.graphics.setBackgroundColor(0.10, 0.12, 0.15)
    manager.switch(require("src.scenes.sandbox"))
end

function love.update(dt) manager.call("update", dt) end
function love.draw() manager.draw() end
function love.keypressed(key, scancode, isrepeat) manager.call("keypressed", key, scancode, isrepeat) end
function love.mousepressed(x, y, button) manager.call("mousepressed", x, y, button) end
function love.mousereleased(x, y, button) manager.call("mousereleased", x, y, button) end
function love.mousemoved(x, y, dx, dy) manager.call("mousemoved", x, y, dx, dy) end
function love.wheelmoved(dx, dy) manager.call("wheelmoved", dx, dy) end
function love.resize(w, h) manager.call("resize", w, h) end
