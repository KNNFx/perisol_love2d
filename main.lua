-- Perisol — bootstrap tối thiểu (M0 Sandbox). Scene manager sẽ được thêm sau.

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest") -- pixel art
    love.graphics.setBackgroundColor(0.10, 0.12, 0.15)
end

function love.update(dt)
end

function love.draw()
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Perisol — M0 Sandbox", 16, 16)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 16, 36)
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
end
