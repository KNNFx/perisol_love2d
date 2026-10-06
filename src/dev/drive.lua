-- Driver dev: tự "bấm" giao diện ván chơi qua chính API của scene (nút theo id, phím, click ô) để kiểm tra
-- luồng UI end-to-end mà không cần người ngồi bấm. Chỉ dùng khi dev: `--newgame --drive N` (N = số lượt).
-- Không thuộc luật chơi và không được test tự động gọi.

local Rebel     = require("src.core.rebel")
local Territory = require("src.core.territory")
local Game      = require("src.core.game")
local Buildings = require("src.data.buildings")
local MapRenderer = require("src.render.map_renderer")

local Drive = {}

local function canAfford(res, cost)
    for k, n in pairs(cost) do if (res[k] or 0) < n then return false end end
    return true
end

local function clickTile(scene, tile)
    local x, y = MapRenderer.tileCenter(tile)
    scene.camera.x, scene.camera.y = x, y     -- đưa ô vào giữa màn hình để không bị panel che
    scene.camera:clamp()
    local W, H = love.graphics.getDimensions()
    local px, py = scene.camera:position()
    local sx = math.floor(W / 2) + (x - px) * scene.camera.zoom
    local sy = math.floor(H / 2) + (y - py) * scene.camera.zoom
    scene:mousepressed(sx, sy, 1)
end

-- Gọi mỗi frame. opts = { turns = N, onDone = fn }.
function Drive.update(scene, drv, dt)
    if drv.done then return end
    drv.wait = (drv.wait or 0) - dt
    if drv.wait > 0 or scene.rollAnim or scene.tween:busy() then return end
    drv.wait = 0.05

    local st = scene.state
    drv.turns = drv.turns or 0
    if st.phase == "over" then drv.done = true return end
    if drv.turns >= drv.maxTurns then drv.done = true if drv.onDone then drv.onDone() end return end

    local actor = Game.actor(st)
    local p = actor and st.players[actor]

    if st.phase == "setup_hq" then
        for i, s in ipairs(st.map.starts) do
            if not st.takenStarts[i] then clickTile(scene, st.map:get(s.q, s.r)) return end
        end
    elseif st.phase == "roll" then
        drv.actions = 0
        -- kiểm tra F5/F9: lưu ở lượt 2, nạp lại ở lượt 5 và so sánh lịch sử lệnh
        if drv.turns == 2 and not drv.saved then
            scene:keypressed("f5")
            drv.saved, drv.savedLen = true, #st.history
            print("DRIVE: F5 lưu nhanh tại lệnh " .. drv.savedLen)
        elseif drv.turns == 5 and drv.saved and not drv.loaded then
            scene:keypressed("f9")
            drv.loaded = true
            local n = #scene.state.history
            print(string.format("DRIVE: F9 nạp -> %d lệnh (mong đợi %d) %s", n, drv.savedLen,
                n == drv.savedLen and "OK" or "SAI"))
            io.stdout:flush()
            return
        end
        scene:keypressed("space")
    elseif st.phase == "rebel_move" then
        local t = Rebel.legalSteps(st)[1]
        clickTile(scene, t)
    elseif st.phase == "rebel_loss" then
        scene.ui:activate("loss" .. st.rebel.pending.options[1])
    elseif st.phase == "action" then
        drv.actions = (drv.actions or 0) + 1
        if scene.mode then
            local items = scene:computeTargets()
            if #items > 0 and drv.actions <= 12 then clickTile(scene, items[1].tile) else scene:keypressed("escape") end
        elseif drv.actions > 8 then
            drv.turns = drv.turns + 1
            scene:keypressed("e")
        else
            for _, b in ipairs(Buildings.list) do
                for _, t in ipairs(Territory.ownedTiles(st, actor)) do
                    if Game.buildCheck(st, actor, b.id, t) then
                        scene.ui:activate("build" .. b.id)
                        return
                    end
                end
            end
            local buyable = false
            for _, t in ipairs(Territory.buyTargets(st, actor)) do
                if canAfford(p.res, Territory.buyTileCost(st, actor, t)) then buyable = true break end
            end
            if Game.check(st, { type = "upgradeHQ" }) then
                scene.ui:activate("upgradehq")
            elseif p.votes > 0 and #Territory.voteTargets(st, actor) > 0 then
                scene.ui:activate("vote")
            elseif buyable then
                scene.ui:activate("buytile")
            elseif canAfford(p.res, require("src.config.constants").SUB_COST) and drv.actions % 3 == 0 then
                scene.ui:activate("foundsub")
            else
                drv.turns = drv.turns + 1
                scene:keypressed("e")
            end
        end
    end
end

return Drive
