-- D-021: thứ tự việc đầu lượt khai tường minh một chỗ (src/core/upkeep.lua):
-- hoàn tất dỡ -> thu nhập thụ động -> upkeep đơn vị. Thu nhập của lượt trả được upkeep của chính lượt đó.

local Units  = require("src.core.units")
local Upkeep = require("src.core.upkeep")
local arena  = require("tests.arena")

describe("D-021: thứ tự việc đầu lượt", function()
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
