-- Toán hex: tọa độ axial {q, r}, lưới pointy-top, offset kiểu odd-r.
-- Thuần Lua, không gọi love.*  (tham khảo: Red Blob Games "Hexagonal Grids").
--
-- Pixel: lưới sprite 32×32, bước ngang `w`, bước dọc `stepY` (hex bị nén theo chiều dọc),
-- nên toPixel/fromPixel làm việc trên không gian tuyến tính đã chia theo (w, stepY).

local Hex = {}

Hex.DIRECTIONS = {
    { q = 1, r = 0 }, { q = 1, r = -1 }, { q = 0, r = -1 },
    { q = -1, r = 0 }, { q = -1, r = 1 }, { q = 0, r = 1 },
}

function Hex.new(q, r) return { q = q, r = r } end
function Hex.key(h) return h.q .. "," .. h.r end
function Hex.equals(a, b) return a.q == b.q and a.r == b.r end
function Hex.add(a, b) return { q = a.q + b.q, r = a.r + b.r } end
function Hex.sub(a, b) return { q = a.q - b.q, r = a.r - b.r } end
function Hex.scale(a, k) return { q = a.q * k, r = a.r * k } end

function Hex.neighbor(h, dir)
    local d = Hex.DIRECTIONS[dir]
    return { q = h.q + d.q, r = h.r + d.r }
end

function Hex.neighbors(h)
    local out = {}
    for i = 1, 6 do out[i] = Hex.neighbor(h, i) end
    return out
end

function Hex.distance(a, b)
    local dq, dr = a.q - b.q, a.r - b.r
    return (math.abs(dq) + math.abs(dr) + math.abs(dq + dr)) / 2
end

-- Các ô cách `center` đúng `radius` bước (6*radius ô; radius 0 -> chính nó).
function Hex.ring(center, radius)
    if radius == 0 then return { { q = center.q, r = center.r } } end
    local out = {}
    -- bắt đầu ở góc hướng 5 (-1,+1) rồi đi vòng quanh
    local h = { q = center.q + Hex.DIRECTIONS[5].q * radius, r = center.r + Hex.DIRECTIONS[5].r * radius }
    for side = 1, 6 do
        for _ = 1, radius do
            out[#out + 1] = h
            h = Hex.neighbor(h, side)
        end
    end
    return out
end

-- Mọi ô cách `center` tối đa `radius` bước (3r(r+1)+1 ô).
function Hex.range(center, radius)
    local out = {}
    for dq = -radius, radius do
        for dr = math.max(-radius, -dq - radius), math.min(radius, -dq + radius) do
            out[#out + 1] = { q = center.q + dq, r = center.r + dr }
        end
    end
    return out
end

-- Làm tròn tọa độ axial thực về ô hex gần nhất (cube round).
function Hex.round(fq, fr)
    local fs = -fq - fr
    local q, r, s = math.floor(fq + 0.5), math.floor(fr + 0.5), math.floor(fs + 0.5)
    local dq, dr, ds = math.abs(q - fq), math.abs(r - fr), math.abs(s - fs)
    if dq > dr and dq > ds then
        q = -r - s
    elseif dr > ds then
        r = -q - s
    end
    return { q = q, r = r }
end

-- Đường thẳng từ a đến b gồm distance+1 ô.
function Hex.line(a, b)
    local n = Hex.distance(a, b)
    local out = {}
    if n == 0 then return { { q = a.q, r = a.r } } end
    -- epsilon tránh rơi đúng vào cạnh giữa hai ô
    local aq, ar = a.q + 1e-6, a.r + 2e-6
    local bq, br = b.q + 1e-6, b.r + 2e-6
    for i = 0, n do
        local t = i / n
        out[#out + 1] = Hex.round(aq + (bq - aq) * t, ar + (br - ar) * t)
    end
    return out
end

-- ─── Offset odd-r (hàng lẻ lệch phải) ──────────────────────────────────────
function Hex.toOffset(h)
    return h.q + (h.r - (h.r % 2)) / 2, h.r   -- col, row
end

function Hex.fromOffset(col, row)
    return { q = col - (row - (row % 2)) / 2, r = row }
end

-- ─── Pixel (tâm ô) ─────────────────────────────────────────────────────────
-- layout = { w = 32, stepY = 24, ox = 0, oy = 0 }
function Hex.toPixel(h, layout)
    return layout.w * (h.q + h.r / 2) + (layout.ox or 0),
           layout.stepY * h.r + (layout.oy or 0)
end

function Hex.fromPixel(x, y, layout)
    x, y = x - (layout.ox or 0), y - (layout.oy or 0)
    local fr = y / layout.stepY
    local fq = x / layout.w - fr / 2
    return Hex.round(fq, fr)
end

return Hex
