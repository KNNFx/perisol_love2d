-- Menu chính: chọn số người chơi và seed, bắt đầu ván mới, tiếp tục bản lưu nhanh, mở sandbox M0.
-- Điều khiển được bằng chuột lẫn bàn phím: lên/xuống đổi mục, trái/phải đổi số người, Enter kích hoạt.

local Cli     = require("src.cli")
local Save    = require("src.save")
local Actions = require("src.input.actions")
local Theme   = require("src.ui.theme")
local UI      = require("src.ui.widgets")
local manager = require("src.scenes.manager")

local Menu = {}

local ITEMS = { "players", "seed", "start", "continue", "sandbox", "quit" }

function Menu:enter()
    self.ui = UI.new()
    self.players = math.max(1, math.min(4, tonumber(Cli.option("--players")) or 2))
    self.seedText = Cli.option("--seed") and tostring(Cli.option("--seed")) or ""
    self.focus = 3
    self.message = nil
end

function Menu:startGame()
    local seed = tonumber(self.seedText)
    manager.switch(require("src.scenes.game"), { seed = seed or love.math.random(1, 999999), players = self.players })
end

function Menu:continueGame()
    local state, err = Save.read("quick")
    if not state then self.message = "Không nạp được: " .. tostring(err) return end
    manager.switch(require("src.scenes.game"), { state = state })
end

function Menu:activate(id)
    if id == "start" then self:startGame()
    elseif id == "continue" then if Save.exists("quick") then self:continueGame() end
    elseif id == "sandbox" then manager.switch(require("src.scenes.sandbox"))
    elseif id == "quit" then love.event.quit() end
end

function Menu:draw()
    local W, H = love.graphics.getDimensions()
    Theme.update(W, H)
    local ui = self.ui
    ui:begin()
    ui.focusId = ITEMS[self.focus]

    local w, h = Theme.px(380), Theme.px(400)
    local x, y = (W - w) / 2, (H - h) / 2
    ui:panel(x, y, w, h)
    ui:label("PERISOL", x, y + Theme.px(14), { font = Theme.font(34, true), width = w, align = "center", color = Theme.color.accent })
    ui:label("Long Mạch · lãnh thổ lục giác", x, y + Theme.px(60), { font = Theme.font(12), width = w, align = "center", color = Theme.color.dim })

    local bx, bw = x + Theme.px(30), w - Theme.px(60)
    local by = y + Theme.px(96)
    local bh, gap = Theme.px(34), Theme.px(8)

    -- số người chơi
    ui:label("Số người chơi", bx, by, { font = Theme.font(11), color = Theme.color.dim })
    by = by + Theme.px(16)
    local pw = (bw - 3 * Theme.px(6)) / 4
    for n = 1, 4 do
        ui:button("players" .. n, bx + (n - 1) * (pw + Theme.px(6)), by, pw, bh, tostring(n), {
            focused = self.players == n and ITEMS[self.focus] == "players" or self.players == n,
            color = self.players == n and { 0.28, 0.42, 0.30 } or nil, font = Theme.font(14, true),
            onClick = function() self.players = n; self.focus = 1 end,
        })
    end
    by = by + bh + gap

    -- seed
    ui:label("Seed (để trống = ngẫu nhiên)", bx, by, { font = Theme.font(11), color = Theme.color.dim })
    by = by + Theme.px(16)
    ui:button("seed", bx, by, bw, bh, self.seedText == "" and "ngẫu nhiên" or self.seedText, {
        font = Theme.font(13), onClick = function() self.focus = 2 end,
        color = ITEMS[self.focus] == "seed" and { 0.16, 0.20, 0.27 } or nil,
    })
    by = by + bh + gap + Theme.px(6)

    local hasSave = Save.exists("quick")
    ui:button("start", bx, by, bw, bh + Theme.px(4), "Bắt đầu ván mới", {
        color = { 0.25, 0.45, 0.30 }, font = Theme.font(14, true), onClick = function() self:activate("start") end,
    })
    by = by + bh + Theme.px(4) + gap
    ui:button("continue", bx, by, bw, bh, "Tiếp tục (bản lưu nhanh)", {
        enabled = hasSave, font = Theme.font(12, true), tip = hasSave and nil or "Chưa có bản lưu nhanh. Nhấn F5 trong ván để lưu.",
        onClick = function() self:activate("continue") end,
    })
    by = by + bh + gap
    ui:button("sandbox", bx, by, bw, bh, "Sandbox bản đồ (M0)", {
        font = Theme.font(12, true), onClick = function() self:activate("sandbox") end,
    })
    by = by + bh + gap
    ui:button("quit", bx, by, bw, bh, "Thoát", { font = Theme.font(12, true), onClick = function() self:activate("quit") end })

    if self.message then
        ui:label(self.message, x, y + h - Theme.px(22), { font = Theme.font(10), width = w, align = "center", color = Theme.color.bad })
    end
    ui:label("Lên/Xuống: chọn mục  ·  Trái/Phải: đổi số người  ·  Enter: xác nhận", 0, H - Theme.px(22),
        { font = Theme.font(10), width = W, align = "center", color = Theme.color.dim })
    ui:finish()
end

function Menu:keypressed(key)
    local id = ITEMS[self.focus]
    if Actions.matches("menuUp", key) and key ~= "w" then
        self.focus = (self.focus - 2) % #ITEMS + 1
    elseif Actions.matches("menuDown", key) and key ~= "s" then
        self.focus = self.focus % #ITEMS + 1
    elseif id == "players" and Actions.matches("menuLeft", key) and key ~= "a" then
        self.players = math.max(1, self.players - 1)
    elseif id == "players" and Actions.matches("menuRight", key) and key ~= "d" then
        self.players = math.min(4, self.players + 1)
    elseif id == "seed" and key == "backspace" then
        self.seedText = self.seedText:sub(1, -2)
    elseif Actions.matches("confirm", key) and key ~= "space" then
        if id == "players" or id == "seed" then self.focus = 3 else self:activate(id) end
    elseif key == "escape" then
        love.event.quit()
    end
end

function Menu:textinput(text)
    if ITEMS[self.focus] == "seed" and text:match("^%d$") and #self.seedText < 9 then
        self.seedText = self.seedText .. text
    end
end

function Menu:mousepressed(x, y, button)
    self.ui:mousepressed(x, y, button)
end

return Menu
