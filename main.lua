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
local Cli = require("src.cli")

-- Khi chụp màn hình tự động (--shot) mà gặp lỗi: in lỗi ra console rồi thoát thay vì treo ở màn hình lỗi.
if Cli.flag("--shot") then
    function love.errorhandler(msg)
        print("LỖI: " .. tostring(msg) .. "\n" .. debug.traceback("", 2))
        io.stdout:flush()
        return 1
    end
end

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest") -- pixel art
    love.graphics.setBackgroundColor(0.10, 0.12, 0.15)
    require("src.ui.theme").update(love.graphics.getDimensions())

    -- Mặc định mở menu. Tham số dev: --sandbox (bản đồ M0), --newgame (vào thẳng ván, dùng --seed/--players), --results (xem màn hình điểm),
    -- --play N (tự chơi N lệnh ngẫu nhiên trước khi hiện, để chụp màn hình).
    if Cli.flag("--sandbox") then
        manager.switch(require("src.scenes.sandbox"))
    elseif Cli.flag("--results") then
        -- dev: chơi hết một ván ngẫu nhiên rồi mở thẳng màn hình điểm
        local Game = require("src.core.game")
        local state = Game.new({ seed = tonumber(Cli.option("--seed")) or 7, players = tonumber(Cli.option("--players")) or 3 })
        require("src.core.sim").advance(state, 1000000)
        manager.switch(require("src.scenes.results"), state)
    elseif Cli.flag("--newgame") then
        manager.switch(require("src.scenes.game"), {
            seed = tonumber(Cli.option("--seed")), players = tonumber(Cli.option("--players")),
        })
    else
        manager.switch(require("src.scenes.menu"))
    end
end

local frames = 0
-- Dev: `--drive N` tự bấm giao diện ván chơi qua N lượt (src/dev/drive.lua), rồi chụp nếu có --shot.
local drive = tonumber(Cli.option("--drive")) and { maxTurns = tonumber(Cli.option("--drive")) } or nil

local function captureAndQuit(name)
    love.graphics.captureScreenshot(function(img)
        img:encode("png", name)
        love.event.quit()
    end)
end

function love.update(dt)
    manager.call("update", dt)
    if drive then
        local scene = manager.current()
        if scene and scene.state and scene.ui then
            if scene.state.phase == "over" and not drive.overAt then
                drive.overAt, drive.done = love.timer.getTime(), true
                print(string.format("DRIVE: ván kết thúc sau %d lượt, không lỗi", drive.turns or 0))
                io.stdout:flush()
            end
            if drive.overAt and love.timer.getTime() - drive.overAt > 2 then
                print("DRIVE: scene hiện tại sau khi kết thúc = " .. (scene.ranking and "results" or "game"))
                io.stdout:flush()
                love.event.quit()
            end
            require("src.dev.drive").update(scene, drive, dt)
            drive.lastLog = drive.lastLog or 0
            if love.timer.getTime() - drive.lastLog > 3 then
                drive.lastLog = love.timer.getTime()
                local st = scene.state
                print(string.format("  [drive] vòng %d lượt %d pha %s mode %s popup %s lệnh %d", st.round, st.turn, st.phase,
                    tostring(scene.mode and scene.mode.kind), tostring(scene.popup), #st.history))
                io.stdout:flush()
            end
            if drive.done and not drive.reported and not drive.overAt then
                drive.reported = true
                local st = scene.state
                print(string.format("DRIVE: %d lượt, vòng %d, pha %s, lệnh %d, công trình %d", drive.turns or 0, st.round,
                    st.phase, #st.history, (function() local n = 0 for _ in pairs(st.buildings) do n = n + 1 end return n end)()))
                io.stdout:flush()
                drive.onDone = nil
                local shot = Cli.option("--shot")
                if shot then drive.shotAt = frames + 3 else love.event.quit() end
            end
        end
    end
end

function love.draw()
    manager.draw()
    -- Dev: `--shot ten.png` chụp màn hình vào thư mục save (%APPDATA%/LOVE/perisol) rồi thoát.
    frames = frames + 1
    local shot = Cli.option("--shot")
    if shot and not drive and frames == 4 then captureAndQuit(shot) end
    if shot and drive and drive.shotAt and frames >= drive.shotAt then
        drive.shotAt = nil
        captureAndQuit(shot)
    end
end
function love.keypressed(key, scancode, isrepeat) manager.call("keypressed", key, scancode, isrepeat) end
function love.textinput(text) manager.call("textinput", text) end
function love.mousepressed(x, y, button) manager.call("mousepressed", x, y, button) end
function love.mousereleased(x, y, button) manager.call("mousereleased", x, y, button) end
function love.mousemoved(x, y, dx, dy) manager.call("mousemoved", x, y, dx, dy) end
function love.wheelmoved(dx, dy) manager.call("wheelmoved", dx, dy) end
function love.resize(w, h) manager.call("resize", w, h) end
