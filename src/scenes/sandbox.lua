-- Sandbox M0: sinh và xem bản đồ.
-- Phím: R = seed mới · 1-4 = số người chơi · F1 = debug · Z = vùng khởi đầu · Esc = thoát
-- Chuột: kéo phải/giữa = di chuyển · con lăn = zoom · WASD/mũi tên = di chuyển
-- Tham số dòng lệnh: --seed N  --players N

local C           = require("src.config.constants")
local Mapgen      = require("src.core.mapgen")
local Camera      = require("src.render.camera")
local Tileset     = require("src.render.tileset")
local MapRenderer = require("src.render.map_renderer")
local Terrains    = require("src.data.terrains")
local Strategic   = require("src.data.strategic")

local Sandbox = {}

local function cliOption(name)
    local args = arg or {}
    for i, a in pairs(args) do
        if a == name then return args[i + 1] end
    end
    return nil   -- phải trả nil tường minh: tonumber() không đối số sẽ báo lỗi
end

function Sandbox:enter()
    self.tileset = Tileset.load()
    self.camera = Camera.new()
    self.debug = true
    self.showZones = true
    self.hover = nil
    self.font = love.graphics.newFont(13)

    self.players = tonumber(cliOption("--players")) or 4
    self.nextSeed = tonumber(cliOption("--seed"))
    self:regenerate()
end

function Sandbox:regenerate()
    local seed = self.nextSeed or love.math.random(1, 999999999)
    self.nextSeed = nil
    self.map = Mapgen.generate({ seed = seed, players = self.players })
    local w, h = MapRenderer.worldSize(self.map)
    self.camera:setWorld(w, h)
    self.camera:fit(love.graphics.getWidth())
    self.hover = nil
end

function Sandbox:update(dt)
    self.camera:update(dt)
    local mx, my = love.mouse.getPosition()
    local wx, wy = self.camera:screenToWorld(mx, my)
    self.hover = MapRenderer.tileAt(self.map, wx, wy)
end

function Sandbox:draw()
    self.camera:attach()
    MapRenderer.draw(self.map, {
        tileset = self.tileset, hover = self.hover, zoom = self.camera.zoom, showZones = self.showZones,
    })
    self.camera:detach()
    self:drawOverlay()

    -- Dev: `--shot ten.png` chụp màn hình vào thư mục save (%APPDATA%/LOVE/perisol) rồi thoát.
    self.frames = (self.frames or 0) + 1
    local shot = cliOption("--shot")
    if shot and self.frames == 3 then
        love.graphics.captureScreenshot(function(img)
            img:encode("png", shot)
            love.event.quit()
        end)
    end
end

function Sandbox:drawOverlay()
    love.graphics.setFont(self.font)
    local lines = {
        "Perisol - M0 Sandbox   FPS " .. love.timer.getFPS(),
        string.format("seed %s  attempt %d  players %d  map %dx%d  zoom %.1fx",
            tostring(self.map.seed), self.map.attempt, self.map.players, self.map.cols, self.map.rows, self.camera.zoom),
        "R new seed | 1-4 players | Z zones | F1 debug | wheel zoom | RMB drag / WASD pan",
    }

    if self.debug then
        local counts = self.map:countByTerrain()
        local parts = {}
        for _, id in ipairs(self.map.terrains) do
            parts[#parts + 1] = string.format("%s %s x%d", id, Terrains.byId[id].en, counts[id] or 0)
        end
        lines[#lines + 1] = "terrains: " .. table.concat(parts, ", ")

        local t = self.hover
        if t then
            local def = Terrains.byId[t.terrain]
            local tn = t.strategic and Strategic.byId[t.strategic]
            lines[#lines + 1] = string.format("tile q=%d r=%d  col=%d row=%d  %s %s%s%s",
                t.q, t.r, t.col, t.row, t.terrain, def.en,
                tn and ("  | " .. tn.id .. " " .. tn.en) or "",
                t.zone and ("  | zone P" .. t.zone) or "")
        else
            lines[#lines + 1] = "tile: -"
        end
    end

    local h = #lines * 17 + 8
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), h)
    love.graphics.setColor(1, 1, 1)
    for i, line in ipairs(lines) do
        love.graphics.print(line, 8, 4 + (i - 1) * 17)
    end
end

function Sandbox:keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "r" then
        self:regenerate()
    elseif key == "f1" then
        self.debug = not self.debug
    elseif key == "z" then
        self.showZones = not self.showZones
    elseif key >= "1" and key <= "4" and #key == 1 then
        self.players = tonumber(key)
        self:regenerate()
    end
end

function Sandbox:mousemoved(x, y, dx, dy)
    if love.mouse.isDown(2) or love.mouse.isDown(3) then
        self.camera:pan(-dx, -dy)
    end
end

function Sandbox:wheelmoved(dx, dy)
    if dy ~= 0 then
        local mx, my = love.mouse.getPosition()
        self.camera:zoomAt(dy > 0 and 1 or -1, mx, my)
    end
end

function Sandbox:resize(w, h)
    self.camera:clamp()
end

return Sandbox
