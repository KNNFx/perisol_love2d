-- Màn hình điểm cuối ván: bảng xếp hạng chi tiết (GDD §11.2) đè lên bản đồ cuối cùng.
-- Mở bằng manager.switch(scene, state).

local Scoring     = require("src.core.scoring")
local Tileset     = require("src.render.tileset")
local Camera      = require("src.render.camera")
local MapRenderer = require("src.render.map_renderer")
local Layers      = require("src.render.game_layers")
local Theme       = require("src.ui.theme")
local UI          = require("src.ui.widgets")
local Tween       = require("src.ui.tween")
local manager     = require("src.scenes.manager")

local Results = {}

local COLUMNS = {
    { key = "tileCount", title = "Ô" },
    { key = "tiles", title = "Điểm ô" },
    { key = "landmarks", title = "Danh Thắng" },
    { key = "buildings", title = "CT C2+" },
    { key = "leftover", title = "TN dư" },
    { key = "resources", title = "Điểm TN" },
    { key = "total", title = "TỔNG" },
}

function Results:enter(state)
    self.state = state
    self.ranking = Scoring.ranking(state)
    self.ui = UI.new()
    self.tween = Tween.new()
    self.tileset = Tileset.load()
    self.camera = Camera.new()
    local w, h = MapRenderer.worldSize(state.map)
    self.camera:setWorld(w, h)
    self.camera:fit(love.graphics.getWidth())
    self.reveal = { a = 0 }
    self.tween:to(self.reveal, "a", 1, 0.6, "outCubic")
end

function Results:update(dt)
    self.tween:update(dt)
end

function Results:newGame()
    manager.switch(require("src.scenes.game"), { seed = love.math.random(1, 999999), players = self.state.playerCount })
end

function Results:draw()
    local W, H = love.graphics.getDimensions()
    Theme.update(W, H)
    local state, ui = self.state, self.ui

    self.camera:attach()
    MapRenderer.drawTerrain(state.map, { tileset = self.tileset })
    Layers.drawTerritory(state, { zoom = self.camera.zoom })
    Layers.drawBuildings(state, { zoom = self.camera.zoom })
    self.camera:detach()
    love.graphics.setColor(0, 0, 0, 0.7 * self.reveal.a)
    love.graphics.rectangle("fill", 0, 0, W, H)

    ui:begin()
    local nRows = #self.ranking
    local rowH = Theme.px(30)
    local w = math.min(W - Theme.px(20), Theme.px(760))
    local h = Theme.px(150) + nRows * rowH
    local x, y = (W - w) / 2, (H - h) / 2 - Theme.px(10) * (1 - self.reveal.a)

    ui:panel(x, y, w, h)
    local winners = {}
    for _, s in ipairs(self.ranking) do if s.rank == 1 then winners[#winners + 1] = "P" .. s.pid end end
    ui:label("Ván đấu kết thúc", x, y + Theme.px(10), { font = Theme.font(20, true), width = w, align = "center", color = Theme.color.accent })
    ui:label((#winners > 1 and "Đồng hạng nhất: " or "Người thắng: ") .. table.concat(winners, ", "),
        x, y + Theme.px(40), { font = Theme.font(14, true), width = w, align = "center" })

    -- bảng
    local ty = y + Theme.px(72)
    local nameW = Theme.px(110)
    local colW = (w - nameW - Theme.px(24)) / #COLUMNS
    local fh = Theme.font(10, true)
    ui:label("Hạng · Người chơi", x + Theme.px(12), ty, { font = fh, color = Theme.color.dim })
    for i, col in ipairs(COLUMNS) do
        ui:label(col.title, x + Theme.px(12) + nameW + (i - 1) * colW, ty,
            { font = fh, color = Theme.color.dim, width = colW, align = "center" })
    end
    local f = Theme.font(13, true)
    for r, s in ipairs(self.ranking) do
        local ry = ty + Theme.px(18) + (r - 1) * rowH
        if r % 2 == 1 then
            love.graphics.setColor(1, 1, 1, 0.05)
            love.graphics.rectangle("fill", x + Theme.px(6), ry, w - Theme.px(12), rowH - 2)
        end
        local pc = Theme.player[s.pid]
        love.graphics.setColor(pc[1], pc[2], pc[3])
        love.graphics.rectangle("fill", x + Theme.px(8), ry + 2, Theme.px(4), rowH - 6)
        ui:label(string.format("#%d  P%d", s.rank, s.pid), x + Theme.px(18), ry + Theme.px(5), { font = f })
        for i, col in ipairs(COLUMNS) do
            ui:label(tostring(s[col.key]), x + Theme.px(12) + nameW + (i - 1) * colW, ry + Theme.px(5), {
                font = col.key == "total" and Theme.font(15, true) or f, width = colW, align = "center",
                color = col.key == "total" and Theme.color.accent or Theme.color.text,
            })
        end
    end

    local by = y + h - Theme.px(42)
    local bw = Theme.px(180)
    ui:button("again", x + w / 2 - bw - Theme.px(6), by, bw, Theme.px(32), "Ván mới", {
        color = { 0.25, 0.45, 0.30 }, font = Theme.font(13, true), onClick = function() self:newGame() end,
    })
    ui:button("menu", x + w / 2 + Theme.px(6), by, bw, Theme.px(32), "Về menu", {
        font = Theme.font(13, true), onClick = function() manager.switch(require("src.scenes.menu")) end,
    })
    ui:finish()
end

function Results:keypressed(key)
    if key == "return" or key == "kpenter" then self:newGame()
    elseif key == "escape" then manager.switch(require("src.scenes.menu")) end
end

function Results:mousepressed(x, y, button)
    self.ui:mousepressed(x, y, button)
end

return Results
