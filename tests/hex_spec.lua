local Hex = require("src.core.hex")

describe("hex", function()
    it("6 hướng đều cách tâm đúng 1", function()
        local o = Hex.new(0, 0)
        for i = 1, 6 do
            expect.eq(Hex.distance(o, Hex.neighbor(o, i)), 1)
        end
    end)

    it("distance đối xứng và đúng giá trị mẫu", function()
        local a, b = Hex.new(2, -3), Hex.new(-1, 4)
        expect.eq(Hex.distance(a, b), Hex.distance(b, a))
        expect.eq(Hex.distance(Hex.new(0, 0), Hex.new(3, -3)), 3)
        expect.eq(Hex.distance(Hex.new(0, 0), Hex.new(2, 1)), 3)
    end)

    it("ring có 6r ô, tất cả cách tâm đúng r", function()
        local c = Hex.new(3, -2)
        for r = 1, 5 do
            local ring = Hex.ring(c, r)
            expect.eq(#ring, 6 * r, "ring " .. r)
            for _, h in ipairs(ring) do expect.eq(Hex.distance(c, h), r) end
        end
        expect.eq(#Hex.ring(c, 0), 1)
    end)

    it("range(2)=19 ô, range(3)=37 ô, không trùng", function()
        expect.eq(#Hex.range(Hex.new(0, 0), 1), 7)
        expect.eq(#Hex.range(Hex.new(0, 0), 2), 19)
        expect.eq(#Hex.range(Hex.new(5, 5), 3), 37)
        local seen = {}
        for _, h in ipairs(Hex.range(Hex.new(0, 0), 3)) do
            local k = Hex.key(h)
            expect.falsy(seen[k], "trùng " .. k)
            seen[k] = true
        end
    end)

    it("line dài distance+1, bước liền kề, đúng hai đầu", function()
        local a, b = Hex.new(-2, 1), Hex.new(4, -3)
        local line = Hex.line(a, b)
        expect.eq(#line, Hex.distance(a, b) + 1)
        expect.truthy(Hex.equals(line[1], a))
        expect.truthy(Hex.equals(line[#line], b))
        for i = 2, #line do expect.eq(Hex.distance(line[i - 1], line[i]), 1) end
        expect.eq(#Hex.line(a, a), 1)
    end)

    it("offset <-> axial khứ hồi (kể cả hàng âm)", function()
        for row = -5, 10 do
            for col = -5, 10 do
                local h = Hex.fromOffset(col, row)
                local c, r = Hex.toOffset(h)
                expect.eq(c, col)
                expect.eq(r, row)
            end
        end
    end)

    it("hàng lẻ lệch phải nửa ô (odd-r)", function()
        local layout = { w = 32, stepY = 24 }
        local x0 = Hex.toPixel(Hex.fromOffset(0, 0), layout)
        local x1 = Hex.toPixel(Hex.fromOffset(0, 1), layout)
        local x2 = Hex.toPixel(Hex.fromOffset(0, 2), layout)
        expect.near(x1 - x0, 16)
        expect.near(x2 - x0, 0)
    end)

    it("fromPixel(toPixel(h)) = h trên lưới 20x20", function()
        local layout = { w = 32, stepY = 24, ox = 100, oy = 50 }
        for row = 0, 19 do
            for col = 0, 19 do
                local h = Hex.fromOffset(col, row)
                local x, y = Hex.toPixel(h, layout)
                local back = Hex.fromPixel(x, y, layout)
                expect.truthy(Hex.equals(h, back), "col " .. col .. " row " .. row)
            end
        end
    end)

    it("điểm sát cạnh/đỉnh vẫn rơi đúng ô", function()
        local layout = { w = 32, stepY = 24 }
        local h = Hex.new(0, 0)
        local x, y = Hex.toPixel(h, layout)
        -- gần mép ngang (nửa bề rộng 16), gần đỉnh nhọn (nửa chiều cao 16)
        expect.truthy(Hex.equals(Hex.fromPixel(x + 15, y, layout), h))
        expect.truthy(Hex.equals(Hex.fromPixel(x - 15, y, layout), h))
        expect.truthy(Hex.equals(Hex.fromPixel(x, y + 11, layout), h))
        expect.truthy(Hex.equals(Hex.fromPixel(x, y - 11, layout), h))
        -- vượt mép sang ô bên cạnh
        expect.truthy(Hex.equals(Hex.fromPixel(x + 17, y, layout), Hex.new(1, 0)))
    end)

    it("round chọn ô gần nhất", function()
        expect.truthy(Hex.equals(Hex.round(0.4, 0.1), Hex.new(0, 0)))
        expect.truthy(Hex.equals(Hex.round(0.9, -0.1), Hex.new(1, 0)))
        expect.truthy(Hex.equals(Hex.round(-0.2, 1.1), Hex.new(0, 1)))
    end)
end)
