-- D-021: thứ tự việc đầu lượt khai tường minh một chỗ (src/core/upkeep.lua):
-- hoàn tất dỡ -> thu nhập thụ động -> upkeep đơn vị. Thu nhập của lượt trả được upkeep của chính lượt đó.

local Units  = require("src.core.units")
local Upkeep = require("src.core.upkeep")
local arena  = require("tests.arena")

local ORDER = "demolish,passives,units"

describe("upkeep: thứ tự đầu lượt (D-021)", function()
    it("tên các bước theo đúng thứ tự D-021", function()
        expect.eq(table.concat(Upkeep.names(), ","), ORDER)
    end)

    it("thứ tự không phụ thuộc thứ tự require các module core", function()
        local saved = {}
        for name, mod in pairs(package.loaded) do
            if type(name) == "string" and name:find("^src%.core%.") then saved[name] = mod end
        end
        for name in pairs(saved) do package.loaded[name] = nil end
        local ok, err = pcall(function()
            -- đảo ngược thứ tự cũ: units, passives, construction trước, upkeep sau cùng
            require("src.core.units")
            require("src.core.passives")
            require("src.core.construction")
            local U = require("src.core.upkeep")
            expect.eq(table.concat(U.names(), ","), ORDER)
        end)
        for name in pairs(package.loaded) do
            if type(name) == "string" and name:find("^src%.core%.") then package.loaded[name] = nil end
        end
        for name, mod in pairs(saved) do package.loaded[name] = mod end
        assert(ok, err)
    end)

    it("thu nhập thụ động đầu lượt bù upkeep đơn vị: đơn vị không bị mất", function()
        local s, pid, c = arena()
        s.rebel = { q = -99, r = -99 }
        for i = 0, 2 do Units.spawn(s, pid, "expedition", s.map:get(c.q + i - 1, c.r)) end
        local p = s.players[pid]
        p.res.gold, p.carry.gold = 0, 2          -- thiếu Vàng trả upkeep (2), thụ động đầu lượt bù đủ
        local ev = Upkeep.startTurn(s, pid)
        expect.eq(#Units.ownedBy(s, pid), 3)
        for _, e in ipairs(ev) do expect.truthy(e.kind ~= "unit_destroyed") end
        expect.eq(p.res.gold, 0)
    end)
end)
