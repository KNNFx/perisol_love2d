-- Perisol — bootstrap. Logic game nằm trong src/, test trong tests/.

local testMode, simCount = false, nil
for i, a in pairs(arg or {}) do
    if a == "--test" then testMode = true end
    if a == "--sim" then simCount = tonumber(arg[i + 1]) or 100 end
end

-- Mô phỏng headless: `lovec.exe . --sim 100` chơi 100 ván ngẫu nhiên (2-4 người) và in thống kê.
if simCount then
    function love.load()
        local Sim = require("src.core.sim")
        local sum = Sim.batch(simCount, 1, function(i, seed, players, state, ranking)
            print(string.format("ván %3d seed %-4d %d người  thắng P%d (%d điểm, %d ô)", i, seed, players,
                ranking[1].pid, ranking[1].total, ranking[1].tileCount))
        end)
        local g = sum.games
        print(string.format("\n%d ván, không lỗi. Trung bình/ván: %.1f lần ra 7, %.1f công trình, %.1f lần chiếm ô, %.0f lệnh",
            g, sum.sevens / g, sum.builds / g, sum.claims / g, sum.commands / g))
        print(string.format("Điểm trung bình/người: %.1f · ô thực hữu trung bình/người: %.1f · ô của người thắng: %.1f",
            sum.score / sum.players, sum.tiles / sum.players, sum.winnerTiles / g))
        io.stdout:flush()
        love.event.quit(0)
    end
    return
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
