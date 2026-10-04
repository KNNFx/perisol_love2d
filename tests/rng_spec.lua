local Rng = require("src.core.rng")

describe("rng", function()
    it("cùng seed cho cùng dãy", function()
        local a, b = Rng.new(12345), Rng.new(12345)
        for _ = 1, 100 do expect.eq(a:next(), b:next()) end
    end)

    it("seed chuỗi và seed số đều tất định", function()
        local a, b = Rng.new("abc"), Rng.new("abc")
        for _ = 1, 20 do expect.eq(a:int(1, 100), b:int(1, 100)) end
    end)

    it("seed khác cho dãy khác (kể cả seed liền kề)", function()
        local a, b = Rng.new(1), Rng.new(2)
        local diff = 0
        for _ = 1, 20 do if a:next() ~= b:next() then diff = diff + 1 end end
        expect.truthy(diff >= 19)
    end)

    it("next trong [0,1), int trong biên và có phủ đủ giá trị", function()
        local r = Rng.new(7)
        local seen = {}
        for _ = 1, 2000 do
            local f = r:next()
            expect.truthy(f >= 0 and f < 1)
            local n = r:int(3, 8)
            expect.truthy(n >= 3 and n <= 8)
            seen[n] = true
        end
        for v = 3, 8 do expect.truthy(seen[v], "thiếu " .. v) end
    end)

    it("phân bố thô đều", function()
        local r = Rng.new(99)
        local buckets = { 0, 0, 0, 0 }
        for _ = 1, 4000 do
            local i = r:int(1, 4)
            buckets[i] = buckets[i] + 1
        end
        for i = 1, 4 do expect.truthy(buckets[i] > 800 and buckets[i] < 1200, "bucket " .. i) end
    end)

    it("shuffle giữ nguyên phần tử và tất định", function()
        local function make() local t = {} for i = 1, 10 do t[i] = i end return t end
        local a = Rng.new(5):shuffle(make())
        local b = Rng.new(5):shuffle(make())
        local sum = 0
        for i = 1, 10 do expect.eq(a[i], b[i]); sum = sum + a[i] end
        expect.eq(sum, 55)
    end)

    it("fork độc lập với số lần đã gọi next", function()
        local a, b = Rng.new(42), Rng.new(42)
        for _ = 1, 50 do a:next() end
        expect.eq(a:fork("x"):next(), b:fork("x"):next())
        expect.truthy(a:fork("x"):next() ~= a:fork("y"):next())
    end)

    it("weighted tôn trọng trọng số 0", function()
        local r = Rng.new(3)
        for _ = 1, 100 do
            local v = r:weighted({ "a", "b" }, function(x) return x == "a" and 0 or 1 end)
            expect.eq(v, "b")
        end
    end)
end)
