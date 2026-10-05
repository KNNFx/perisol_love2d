-- Widget immediate-mode tối giản. Mỗi frame scene gọi ui:begin(), vẽ widget (đồng thời đăng ký vùng
-- bấm), rồi ui:finish() để vẽ tooltip. mousepressed tra vùng bấm của frame vừa vẽ.
-- Bố cục: scene tự tính hình chữ nhật theo mép màn hình (neo), widget chỉ nhận (x, y, w, h).

local Theme = require("src.ui.theme")

local UI = {}
UI.__index = UI

function UI.new()
    return setmetatable({ hits = {}, tip = nil, mx = 0, my = 0, focusId = nil }, UI)
end

function UI:begin()
    self.hits = {}
    self.tip = nil
    self.mx, self.my = love.mouse.getPosition()
end

local function inside(r, x, y)
    return x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h
end

-- Popup modal: bỏ mọi vùng bấm đã đăng ký trước đó (chúng nằm "dưới" popup).
function UI:blockBelow()
    self.hits = {}
    self.tip = nil
end

function UI:hovered(x, y, w, h)
    return inside({ x = x, y = y, w = w, h = h }, self.mx, self.my)
end

function UI:panel(x, y, w, h, opts)
    opts = opts or {}
    Theme.setColor(opts.color or Theme.color.panel)
    love.graphics.rectangle("fill", x, y, w, h, Theme.px(4), Theme.px(4))
    if opts.border ~= false then
        Theme.setColor(opts.borderColor or Theme.color.panelLine)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, Theme.px(4), Theme.px(4))
    end
end

-- opts: font (đối tượng Font), color, align ("left"|"center"|"right"), width (để căn)
function UI:label(text, x, y, opts)
    opts = opts or {}
    love.graphics.setFont(opts.font or Theme.font(12))
    Theme.setColor(opts.color or Theme.color.text)
    if opts.width then
        love.graphics.printf(text, x, y, opts.width, opts.align or "left")
    else
        love.graphics.print(text, x, y)
    end
end

-- Nút bấm. opts: enabled (mặc định true), tip (tooltip), color, textColor, onClick, font, focused
-- Trả true nếu đang hover.
function UI:button(id, x, y, w, h, text, opts)
    opts = opts or {}
    local enabled = opts.enabled ~= false
    local hot = enabled and inside({ x = x, y = y, w = w, h = h }, self.mx, self.my)
    local base = opts.color or Theme.color.button
    local fill = not enabled and Theme.color.buttonOff or (hot and Theme.color.buttonHot or base)
    Theme.setColor(fill)
    love.graphics.rectangle("fill", x, y, w, h, Theme.px(4), Theme.px(4))

    local focused = opts.focused or self.focusId == id
    Theme.setColor(focused and Theme.color.accent or Theme.color.panelLine)
    love.graphics.setLineWidth(focused and 2 or 1)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, Theme.px(4), Theme.px(4))
    love.graphics.setLineWidth(1)

    local font = opts.font or Theme.font(12, true)
    love.graphics.setFont(font)
    Theme.setColor(opts.textColor or (enabled and Theme.color.text or Theme.color.dim))
    love.graphics.printf(text, x, y + (h - font:getHeight()) / 2, w, "center")

    self.hits[#self.hits + 1] = { id = id, x = x, y = y, w = w, h = h, enabled = enabled,
                                  onClick = opts.onClick, tip = opts.tip }
    if opts.tip and inside({ x = x, y = y, w = w, h = h }, self.mx, self.my) then self.tip = opts.tip end
    return hot
end

-- Xử lý click chuột trái. Trả true nếu một nút (hoặc popup) đã nhận click.
function UI:mousepressed(x, y, button)
    if button ~= 1 then return false end
    for i = #self.hits, 1, -1 do
        local h = self.hits[i]
        if inside(h, x, y) then
            if h.enabled and h.onClick then h.onClick() end
            return true
        end
    end
    return false
end

-- true nếu điểm (x, y) nằm trên bất kỳ widget nào (để map không nhận click xuyên qua).
function UI:isOver(x, y)
    for i = #self.hits, 1, -1 do
        if inside(self.hits[i], x, y) then return true end
    end
    return false
end

-- Kích hoạt nút theo id (dùng khi điều khiển bằng phím).
function UI:activate(id)
    for _, h in ipairs(self.hits) do
        if h.id == id and h.enabled and h.onClick then h.onClick() return true end
    end
    return false
end

-- Vẽ tooltip cuối frame, kẹp trong màn hình.
function UI:finish()
    if not self.tip then return end
    local font = Theme.font(11)
    love.graphics.setFont(font)
    local pad = Theme.px(6)
    local maxW = Theme.px(260)
    local _, lines = font:getWrap(self.tip, maxW)
    local w = 0
    for _, l in ipairs(lines) do w = math.max(w, font:getWidth(l)) end
    w = w + pad * 2
    local h = #lines * font:getHeight() + pad * 2
    local sw, sh = love.graphics.getDimensions()
    local x = math.max(2, math.min(sw - w - 2, self.mx + Theme.px(14)))
    local y = math.max(2, math.min(sh - h - 2, self.my + Theme.px(14)))
    Theme.setColor({ 0.05, 0.06, 0.08, 0.95 })
    love.graphics.rectangle("fill", x, y, w, h, 3, 3)
    Theme.setColor(Theme.color.panelLine)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, 3, 3)
    Theme.setColor(Theme.color.text)
    love.graphics.printf(self.tip, x + pad, y + pad, maxW, "left")
end

return UI
