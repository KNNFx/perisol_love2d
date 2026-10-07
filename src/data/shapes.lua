-- Hình dạng công trình nhiều ô (D-014, đề xuất của dự án). Mỗi hình là danh sách offset axial {q, r},
-- ô (0,0) là ô gốc của hình; xoay 60° bằng Hex.rotate. Tên hình khớp trường `shape` trong
-- src/data/buildings.lua. Hex không có hình thang 6 ô đối xứng, nên trapezoid/cluster là đề xuất.

local Hex = require("src.core.hex")

local S = {}

S.cells = {
    single    = { { 0, 0 } },
    pair      = { { 0, 0 }, { 1, 0 } },
    triangle  = { { 0, 0 }, { 1, 0 }, { 0, 1 } },
    line3     = { { 0, 0 }, { 1, 0 }, { 2, 0 } },
    L         = { { 0, 0 }, { 1, 0 }, { 1, 1 } },
    rect      = { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } },                          -- hình bình hành
    trapezoid = { { 0, 0 }, { 1, 0 }, { 2, 0 }, { 3, 0 }, { 0, 1 }, { 1, 1 } },      -- hàng 4 trên hàng 2
    cluster   = { { 0, 0 }, { 1, 0 }, { 1, -1 }, { 0, -1 }, { -1, 0 }, { -1, 1 } },  -- ô giữa + 5 ô kề
}

-- Các ô của hình `name` đặt với ô gốc tại (q, r) và xoay `rot` × 60°: danh sách { q, r }, cùng thứ tự với `cells`.
function S.footprint(name, q, r, rot)
    local cells = S.cells[name]
    assert(cells, "hình không tồn tại: " .. tostring(name))
    local out = {}
    for i, c in ipairs(cells) do
        local h = Hex.rotate({ q = c[1], r = c[2] }, rot or 0)
        out[i] = { q = q + h.q, r = r + h.r }
    end
    return out
end

return S
