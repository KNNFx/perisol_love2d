-- Camera 2D: (x, y) là điểm thế giới nằm giữa màn hình, zoom theo các bậc cố định.

local C = require("src.config.constants")

local Camera = {}
Camera.__index = Camera

function Camera.new()
    return setmetatable({ x = 0, y = 0, zoomIndex = 1, zoom = C.ZOOM_LEVELS[1], worldW = 0, worldH = 0 }, Camera)
end

function Camera:setWorld(w, h)
    self.worldW, self.worldH = w, h
    self:clamp()
end

function Camera:clamp()
    self.x = math.max(0, math.min(self.worldW, self.x))
    self.y = math.max(0, math.min(self.worldH, self.y))
end

-- Chọn bậc zoom lớn nhất mà toàn bản đồ còn vừa chiều ngang màn hình, rồi căn giữa.
function Camera:fit(viewW)
    self.zoomIndex = 1
    for i, z in ipairs(C.ZOOM_LEVELS) do
        if self.worldW * z <= viewW then self.zoomIndex = i end
    end
    self.zoom = C.ZOOM_LEVELS[self.zoomIndex]
    self.x, self.y = self.worldW / 2, self.worldH / 2
end

function Camera:attach()
    local w, h = love.graphics.getDimensions()
    love.graphics.push()
    love.graphics.translate(math.floor(w / 2), math.floor(h / 2))
    love.graphics.scale(self.zoom)
    love.graphics.translate(-self.x, -self.y)
end

function Camera:detach()
    love.graphics.pop()
end

function Camera:screenToWorld(sx, sy)
    local w, h = love.graphics.getDimensions()
    return (sx - math.floor(w / 2)) / self.zoom + self.x, (sy - math.floor(h / 2)) / self.zoom + self.y
end

-- Kéo bản đồ theo pixel màn hình.
function Camera:pan(dxScreen, dyScreen)
    self.x = self.x + dxScreen / self.zoom
    self.y = self.y + dyScreen / self.zoom
    self:clamp()
end

-- Zoom tới/lui một bậc, giữ nguyên điểm thế giới dưới con trỏ.
function Camera:zoomAt(steps, sx, sy)
    local newIndex = math.max(1, math.min(#C.ZOOM_LEVELS, self.zoomIndex + steps))
    if newIndex == self.zoomIndex then return end
    local wx, wy = self:screenToWorld(sx, sy)
    self.zoomIndex = newIndex
    self.zoom = C.ZOOM_LEVELS[newIndex]
    local w, h = love.graphics.getDimensions()
    self.x = wx - (sx - math.floor(w / 2)) / self.zoom
    self.y = wy - (sy - math.floor(h / 2)) / self.zoom
    self:clamp()
end

function Camera:update(dt)
    local dx, dy = 0, 0
    local kb = love.keyboard
    if kb.isDown("a", "left") then dx = dx - 1 end
    if kb.isDown("d", "right") then dx = dx + 1 end
    if kb.isDown("w", "up") then dy = dy - 1 end
    if kb.isDown("s", "down") then dy = dy + 1 end
    if dx ~= 0 or dy ~= 0 then
        self:pan(dx * C.CAMERA_PAN_SPEED * dt, dy * C.CAMERA_PAN_SPEED * dt)
    end
end

return Camera
