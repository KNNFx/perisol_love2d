local Rng       = require("src.core.rng")
local Dice      = require("src.core.dice")
local Modifiers = require("src.core.modifiers")
local Serialize = require("src.core.serialize")

describe("dice", function()
    it("đổ ra 1..6, tổng 7 xảy ra khoảng 1/6", function()
        local rng, sevens, n = Rng.new(99), 0, 6000
        for _ = 1, n do
            local d = Dice.roll(rng)
            expect.eq(#d, 2)
            for i = 1, 2 do expect.truthy(d[i] >= 1 and d[i] <= 6) end
            if Dice.isSeven(d) then sevens = sevens + 1 end
        end
        expect.truthy(math.abs(sevens / n - 1 / 6) < 0.025, "tỉ lệ ra 7 = " .. sevens / n)
    end)

    it("count / hexCount / isSeven đúng", function()
        expect.eq(Dice.count({ 3, 3 }, 3), 2)
        expect.eq(Dice.count({ 3, 5 }, 3), 1)
        expect.eq(Dice.count({ 3, 5 }, 1), 0)
        expect.eq(Dice.hexCount({ 6, 6 }), 2)
        expect.eq(Dice.hexCount({ 6, 1 }), 1)
        expect.truthy(Dice.isSeven({ 1, 6 }))
        expect.truthy(Dice.isSeven({ 2, 5 }))
        expect.truthy(Dice.isSeven({ 4, 3 }))
        expect.falsy(Dice.isSeven({ 6, 6 }))
        expect.falsy(Dice.isSeven({ 3, 3 }))
    end)
end)

describe("modifiers", function()
    it("áp dụng theo đúng thứ tự stage, bất kể thứ tự register", function()
        local m, order = Modifiers.new(), {}
        local function rec(name) return function(v) order[#order + 1] = name; return v end end
        m:register("road", rec("road"))
        m:register("strategic", rec("strategic"))
        m:register("base", rec("base"))
        m:register("tech", rec("tech"))
        m:register("aura", rec("aura"))
        m:register("character", rec("character"))
        m:apply(1, {})
        expect.eq(table.concat(order, ">"), "base>character>tech>aura>strategic>road")
    end)

    it("chỉ làm tròn xuống ở bước cuối", function()
        local m = Modifiers.new()
        m:register("base", function(v) return v * 1.5 end)        -- 3 -> 4.5
        m:register("tech", function(v) return v + 0.4 end)        -- 4.9 (không floor giữa chừng)
        m:register("strategic", function(v) return v * 2 end)     -- 9.8
        expect.eq(m:apply(3, {}), 9)
    end)

    it("modifier nhận ctx và không dính nhau giữa các registry", function()
        local a, b = Modifiers.new(), Modifiers.new()
        a:register("strategic", function(v, ctx) return v + ctx.bonus end)
        expect.eq(a:apply(2, { bonus = 3 }), 5)
        expect.eq(b:apply(2, { bonus = 3 }), 2)
    end)

    it("stage không hợp lệ báo lỗi", function()
        expect.error(function() Modifiers.new():register("nope", function() end) end)
    end)
end)

describe("serialize", function()
    it("khứ hồi giữ nguyên dữ liệu", function()
        local data = {
            version = 1, name = 'a "quoted"\nline', flag = true, off = false,
            nums = { 1, 2.5, -3, 0.1 + 0.2 },
            nested = { ["1,2"] = { owner = 2, votes = { [1] = 3, [2] = 1 } } },
        }
        local back = assert(Serialize.load(Serialize.dump(data)))
        expect.deepEq(back, data)
    end)

    it("khóa được sắp xếp nên chuỗi ổn định", function()
        local a = { z = 1, a = 2, m = { y = 1, b = 2 } }
        local b = { m = { b = 2, y = 1 }, a = 2, z = 1 }
        expect.eq(Serialize.dump(a), Serialize.dump(b))
    end)

    it("từ chối hàm, bảng vòng, số không hữu hạn", function()
        expect.error(function() Serialize.dump({ f = print }) end)
        local loop = {}; loop.self = loop
        expect.error(function() Serialize.dump(loop) end)
        expect.error(function() Serialize.dump({ x = math.huge }) end)
    end)

    it("load không chạy được mã độc / hàm toàn cục", function()
        local data, err = Serialize.load("return os.execute('echo hi')")
        expect.eq(data, nil)
        expect.truthy(err)
        expect.eq(Serialize.load("{{{"), nil)
    end)
end)
