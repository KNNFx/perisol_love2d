-- Giao diện chung: font tiếng Việt, màu, hệ số scale theo kích thước cửa sổ (skill game-ui-ux).
-- Thiết kế cho cửa sổ tối thiểu 1024x576 (scale 1); cửa sổ lớn hơn thì phóng UI theo bậc 0.25.

local MapRenderer = require("src.render.map_renderer")

local Theme = {}

Theme.REF_W, Theme.REF_H = 1024, 576
Theme.scale = 1

local FONT_REGULAR = "assets/fonts/BeVietnamPro-Regular.ttf"
local FONT_BOLD    = "assets/fonts/BeVietnamPro-Bold.ttf"

local cache = {}

-- Gọi khi khởi động và mỗi lần đổi kích thước cửa sổ.
function Theme.update(w, h)
    local s = math.min(w / Theme.REF_W, h / Theme.REF_H)
    s = math.max(1, math.min(2.5, math.floor(s * 4 + 0.5) / 4))
    if s ~= Theme.scale then
        Theme.scale = s
        cache = {}
    end
end

-- Làm tròn kích thước theo scale (pixel nguyên).
function Theme.px(n) return math.floor(n * Theme.scale + 0.5) end

-- Font cỡ `size` (theo hệ quy chiếu 1024x576), `bold` tùy chọn.
function Theme.font(size, bold)
    local px = Theme.px(size)
    local k = (bold and "b" or "r") .. px
    if not cache[k] then
        local path = bold and FONT_BOLD or FONT_REGULAR
        local ok, f = pcall(love.graphics.newFont, path, px)
        cache[k] = ok and f or love.graphics.newFont(px)   -- thiếu file font -> font mặc định
    end
    return cache[k]
end

Theme.color = {
    bg        = { 0.10, 0.12, 0.15 },
    panel     = { 0.13, 0.16, 0.20, 0.92 },
    panelLine = { 0.30, 0.36, 0.44 },
    text      = { 0.92, 0.94, 0.96 },
    dim       = { 0.60, 0.66, 0.72 },
    accent    = { 0.96, 0.78, 0.18 },
    good      = { 0.35, 0.80, 0.45 },
    bad       = { 0.92, 0.32, 0.30 },
    warn      = { 0.98, 0.65, 0.20 },
    button    = { 0.20, 0.25, 0.32 },
    buttonHot = { 0.28, 0.35, 0.45 },
    buttonOff = { 0.16, 0.18, 0.21 },
}

Theme.resource = {
    science     = { 0.38, 0.68, 1.00 },
    culture     = { 0.78, 0.50, 0.96 },
    engineering = { 0.96, 0.62, 0.28 },
    faith       = { 0.96, 0.96, 0.74 },
    gold        = { 0.98, 0.82, 0.25 },
}

Theme.player = MapRenderer.PLAYER_COLORS

function Theme.playerName(pid) return "P" .. pid end

-- Đặt màu từ bảng {r,g,b[,a]} với alpha tùy chọn.
function Theme.setColor(c, a)
    love.graphics.setColor(c[1], c[2], c[3], a or c[4] or 1)
end

return Theme
