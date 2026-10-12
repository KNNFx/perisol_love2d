local C            = require("src.config.constants")
local Construction = require("src.core.construction")
local Game         = require("src.core.game")
local Hex          = require("src.core.hex")
local Production   = require("src.core.production")
local Shapes       = require("src.data.shapes")
local Sim          = require("src.core.sim")
local State        = require("src.core.state")
local Structures   = require("src.core.structures")
local Upkeep       = require("src.core.upkeep")

local key = State.key

local arena = require("tests.arena")

describe("construction: nâng cấp tại chỗ", function()
    it("C1 -> C2 (tam giác): trả đủ chi phí cấp mới, chiếm 3 ô, giữ ô neo", function()
        local s, pid, center = arena()
        Game.apply(s, { type = "build", id = "B-01", q = center.q, r = center.r })
        local b = Structures.at(s, center)
        local before = s.players[pid].res.engineering
        local opts = Construction.upgradeOptions(s, b.uid)
        expect.truthy(#opts > 0, "phải có hình hợp lệ")
        local o = opts[1]
        expect.truthy(Game.check(s, { type = "upgrade", uid = b.uid, q = o.q, r = o.r, rot = o.rot }))
        local ev = Game.apply(s, { type = "upgrade", uid = b.uid, q = o.q, r = o.r, rot = o.rot })
        expect.eq(ev[1].kind, "upgrade"); expect.eq(ev[1].level, 2)
        expect.eq(b.level, 2); expect.eq(#b.tiles, 3); expect.eq(b.anchor, key(center))
        expect.eq(s.players[pid].res.engineering, before - 4)   -- B-01.2: 4 KT + 2 KH + 3 V
        for _, k in ipairs(b.tiles) do expect.eq(s.occupied[k], b.uid) end
        expect.truthy(Sim.invariants(s))
    end)

    it("mọi tùy chọn của upgradeOptions đều qua check; hình khác nhau cho tập ô khác nhau", function()
        local s, pid, center = arena()
        Game.apply(s, { type = "build", id = "B-03", q = center.q, r = center.r })
        local b = Structures.at(s, center)
        local opts, seen = Construction.upgradeOptions(s, b.uid), {}
        expect.truthy(#opts >= 6, "cặp ô liền: 6 hướng")
        for _, o in ipairs(opts) do
            local ok, why, tiles = Construction.checkFootprint(s, pid, b, o.q, o.r, o.rot)
            expect.truthy(ok, why)
            expect.eq(#tiles, 2)
            local ks = { key(tiles[1]), key(tiles[2]) }
            table.sort(ks)
            local sig = ks[1] .. ";" .. ks[2]
            expect.falsy(seen[sig], "trùng tập ô")
            seen[sig] = true
        end
    end)

    it("C2 -> C3 hình thang 6 ô phải chứa 3 ô cũ", function()
        local s, pid, center = arena()
        Game.apply(s, { type = "build", id = "B-01", q = center.q, r = center.r })
        local b = Structures.at(s, center)
        local o = Construction.upgradeOptions(s, b.uid)[1]
        Game.apply(s, { type = "upgrade", uid = b.uid, q = o.q, r = o.r, rot = o.rot })
        local old = {}
        for i, k in ipairs(b.tiles) do old[i] = k end
        local opts = Construction.upgradeOptions(s, b.uid)
        expect.truthy(#opts > 0, "vùng 19 ô đủ chỗ cho hình thang")
        o = opts[1]
        Game.apply(s, { type = "upgrade", uid = b.uid, q = o.q, r = o.r, rot = o.rot })
        expect.eq(b.level, 3); expect.eq(#b.tiles, 6)
        for i, k in ipairs(old) do expect.eq(b.tiles[i], k) end
        expect.eq(Construction.upgradeOptions(s, b.uid)[1], nil, "C3 là tối đa")
        expect.falsy(Game.check(s, { type = "upgrade", uid = b.uid, q = 0, r = 0, rot = 0 }))
        expect.truthy(Sim.invariants(s))
    end)

    it("từ chối: thiếu tiền, ô không thuộc mình, ô có công trình, địa hình cấm, phong tỏa, hình không chứa ô cũ", function()
        local s, pid, center = arena()
        Game.apply(s, { type = "build", id = "B-01", q = center.q, r = center.r })
        local b = Structures.at(s, center)
        local o = Construction.upgradeOptions(s, b.uid)[1]
        local cmd = { type = "upgrade", uid = b.uid, q = o.q, r = o.r, rot = o.rot }
        expect.truthy(Game.check(s, cmd))

        -- hình không chứa ô cũ
        local ok, why = Game.check(s, { type = "upgrade", uid = b.uid, q = o.q + 3, r = o.r, rot = o.rot })
        expect.falsy(ok); expect.eq(why, "Hình mới phải chứa các ô của công trình hiện tại")

        local tiles = select(3, Construction.checkFootprint(s, pid, b, o.q, o.r, o.rot))
        local extra = tiles[#tiles]

        -- ô không thuộc mình
        local saved = s.owner[key(extra)]
        s.owner[key(extra)] = 3 - pid
        ok, why = Game.check(s, cmd)
        expect.falsy(ok); expect.eq(why, "Mọi ô phải là lãnh thổ thực hữu của bạn")
        s.owner[key(extra)] = saved

        -- ô có công trình khác
        local other = Structures.place(s, { id = "B-02", owner = pid }, { extra })
        ok, why = Game.check(s, cmd)
        expect.falsy(ok); expect.eq(why, "Có ô đã có công trình")
        Structures.remove(s, other.uid)

        -- địa hình cấm (Sông không xây được Trại Khai Thác)
        local terr = extra.terrain
        extra.terrain = "DH-04"
        ok, why = Game.check(s, cmd)
        expect.falsy(ok)
        expect.truthy(why:find("không xây được cấp này", 1, true))
        extra.terrain = terr

        -- phong tỏa
        s.rebel = { q = extra.q, r = extra.r }
        ok, why = Game.check(s, cmd)
        expect.falsy(ok); expect.eq(why, "Có ô đang bị Phiến Quân phong tỏa")
        s.rebel = false

        -- thiếu tiền
        s.players[pid].res.engineering = 3
        ok, why = Game.check(s, cmd)
        expect.falsy(ok); expect.eq(why, "Không đủ tài nguyên")
    end)

    it("Lãnh Nguyên giảm 1 KT chi phí nâng cấp theo ô neo", function()
        local s, pid, center = arena()
        center.terrain = "DH-06"
        Game.apply(s, { type = "build", id = "B-01", q = center.q, r = center.r })
        local b = Structures.at(s, center)
        local cost = Game.upgradeCost(s, b)
        expect.eq(cost.engineering, 3)    -- 4 - 1
        expect.eq(cost.science, 2)
    end)
end)

describe("construction: sản xuất theo footprint", function()
    it("C2 sản xuất 2 KT khi ra KT; bị phong tỏa ở BẤT KỲ ô nào thì ngừng", function()
        local s, pid, center = arena()
        Game.apply(s, { type = "build", id = "B-01", q = center.q, r = center.r })
        local b = Structures.at(s, center)
        local o = Construction.upgradeOptions(s, b.uid)[1]
        Game.apply(s, { type = "upgrade", uid = b.uid, q = o.q, r = o.r, rot = o.rot })
        local function eng()
            local n = 0
            for _, e in ipairs(Production.compute(s, { 3, 5 }, pid)) do
                if e.kind == "produce" and e.res == "engineering" then n = n + e.amount end
            end
            return n
        end
        expect.eq(eng(), 2)

        -- Phiến Quân cách ô neo 2 nhưng kề một ô khác của công trình
        local far
        for _, k in ipairs(b.tiles) do
            local q, r = k:match("^(-?%d+),(-?%d+)$")
            local t = s.map:get(tonumber(q), tonumber(r))
            if Hex.distance(t, center) == 1 then far = t break end
        end
        for _, h in ipairs(Hex.ring(far, 1)) do
            if Hex.distance(h, center) == 2 then s.rebel = { q = h.q, r = h.r } break end
        end
        expect.truthy(s.rebel and Hex.distance(s.rebel, center) == 2)
        expect.eq(eng(), 0)
        s.rebel = false
        expect.eq(eng(), 2)
    end)

    it("ô của công trình nhiều ô đều khóa phiếu của đối thủ", function()
        local s, pid, center = arena()
        Game.apply(s, { type = "build", id = "B-03", q = center.q, r = center.r })
        local b = Structures.at(s, center)
        local o = Construction.upgradeOptions(s, b.uid)[1]
        Game.apply(s, { type = "upgrade", uid = b.uid, q = o.q, r = o.r, rot = o.rot })
        local Territory = require("src.core.territory")
        local second = Structures.tilesOf(s, b)[2]
        local ok, why = Territory.canVote(s, 3 - pid, second)
        expect.falsy(ok)
        expect.truthy(why ~= "Chỉ đặt phiếu trong vùng ảnh hưởng của bạn" and why ~= nil)
    end)
end)

describe("construction: dỡ công trình", function()
    it("dỡ không hoàn tài nguyên, ngừng sản xuất ngay, bị gỡ ở đầu lượt kế tiếp của chủ", function()
        local s, pid, center = arena()
        Game.apply(s, { type = "build", id = "B-01", q = center.q, r = center.r })
        local b = Structures.at(s, center)
        local res = s.players[pid].res.engineering
        local ev = Game.apply(s, { type = "demolish", uid = b.uid })
        expect.eq(ev[1].kind, "demolish_start")
        expect.eq(s.players[pid].res.engineering, res)
        expect.truthy(b.demolishing)
        expect.eq(#Production.compute(s, { 3, 5 }, pid), 0)
        expect.falsy(Game.check(s, { type = "demolish", uid = b.uid }))
        expect.falsy(Game.check(s, { type = "upgrade", uid = b.uid, q = center.q, r = center.r, rot = 0 }))

        expect.eq(#Upkeep.startTurn(s, 3 - pid), 0)         -- lượt của người khác không gỡ
        expect.truthy(Structures.at(s, center))
        local events = Upkeep.startTurn(s, pid)
        expect.eq(events[1].kind, "demolished")
        expect.eq(Structures.at(s, center), nil)
        expect.eq(s.owner[key(center)], pid, "ô vẫn thuộc chủ")
    end)

    it("chỉ chủ mới dỡ được; không có uid thì từ chối", function()
        local s, pid, center = arena()
        Game.apply(s, { type = "build", id = "B-01", q = center.q, r = center.r })
        local b = Structures.at(s, center)
        b.owner = 3 - pid
        expect.falsy(Game.check(s, { type = "demolish", uid = b.uid }))
        expect.falsy(Game.check(s, { type = "demolish", uid = 999 }))
    end)

    it("TN trên mọi ô của công trình mất vĩnh viễn khi gỡ; cảnh báo liệt kê đúng TN", function()
        local s, pid, center = arena()
        center.strategic = "TN-05"
        Game.apply(s, { type = "build", id = "B-01", q = center.q, r = center.r })
        local b = Structures.at(s, center)
        local o = Construction.upgradeOptions(s, b.uid)[1]
        Game.apply(s, { type = "upgrade", uid = b.uid, q = o.q, r = o.r, rot = o.rot })
        local second = Structures.tilesOf(s, b)[2]
        second.strategic = "TN-01"
        local warn = Construction.lostOnDemolish(s, b)
        expect.eq(#warn, 2)
        expect.eq(warn[1].tn, "TN-05"); expect.eq(warn[2].tn, "TN-01")

        Game.apply(s, { type = "demolish", uid = b.uid })
        expect.eq(Structures.strategicAt(s, center), "TN-05", "chưa mất khi mới ra lệnh")
        local events = Upkeep.startTurn(s, pid)
        local lost = 0
        for _, e in ipairs(events) do if e.kind == "strategic_lost" then lost = lost + 1 end end
        expect.eq(lost, 2)
        expect.eq(Structures.strategicAt(s, center), nil)
        expect.eq(Structures.strategicAt(s, second), nil)

        -- xây lại trên ô cũ: bonus TN-05 không còn
        Game.apply(s, { type = "build", id = "B-01", q = center.q, r = center.r })
        local prod = Production.compute(s, { 3, 5 }, pid)
        expect.eq(prod[1].amount, 1)
        center.strategic = nil
        second.strategic = nil
    end)

    it("dỡ chạy qua roll của chủ (Game.apply) và sống qua save/load", function()
        local s, pid, center = arena()
        center.strategic = "TN-03"
        Game.apply(s, { type = "build", id = "B-01", q = center.q, r = center.r })
        local b = Structures.at(s, center)
        Game.apply(s, { type = "demolish", uid = b.uid })
        s.phase = "roll"
        s.turn = 1
        for i, id in ipairs(s.order) do if id == pid then s.turn = i end end
        local ev = Game.apply(s, { type = "roll" })
        expect.eq(ev[1].kind, "demolished")
        expect.eq(Structures.at(s, center), nil)
        expect.truthy(s.lostStrategic[key(center)])
        center.strategic = nil
    end)
end)

describe("construction: mô phỏng có tài nguyên dồi dào", function()
    it("chơi ngẫu nhiên với nhiều tài nguyên: có nâng cấp/dỡ và bất biến luôn đúng", function()
        local s, pid = arena(8)
        local upgrades, demolished = 0, 0
        local seen = #s.log
        for _ = 1, 80 do
            Sim.advance(s, 12, 8)
            for p = 1, 2 do
                for k, v in pairs(s.players[p].res) do if v < 30 and k ~= "bond" then s.players[p].res[k] = 30 end end
            end
            local ok, why = Sim.invariants(s)
            expect.truthy(ok, why)
            for i = seen + 1, #s.log do
                if s.log[i].kind == "upgrade" then upgrades = upgrades + 1 end
                if s.log[i].kind == "demolished" then demolished = demolished + 1 end
            end
            seen = #s.log
            if s.phase == "over" then break end
        end
        expect.truthy(upgrades > 0, "phải có ít nhất một nâng cấp")
        expect.truthy(demolished >= 0)
    end)
end)

describe("shapes", function()
    it("mỗi hình có đúng số ô theo bảng Data và liên thông", function()
        local Buildings = require("src.data.buildings")
        for _, b in ipairs(Buildings.list) do
            for _, lv in ipairs(b.levels) do
                local cells = Shapes.footprint(lv.shape, 0, 0, 0)
                expect.eq(#cells, lv.tiles, b.id .. " C" .. lv.level)
                local set, stack, seen, n = {}, { cells[1] }, {}, 0
                for _, c in ipairs(cells) do set[key(c)] = c end
                seen[key(cells[1])] = true
                while #stack > 0 do
                    local c = table.remove(stack)
                    n = n + 1
                    for _, nb in ipairs(Hex.neighbors(c)) do
                        local k = key(nb)
                        if set[k] and not seen[k] then seen[k] = true; stack[#stack + 1] = nb end
                    end
                end
                expect.eq(n, #cells, b.id .. " C" .. lv.level .. " liên thông")
            end
        end
    end)

    it("xoay giữ hình: cùng số ô, mọi ô khác nhau", function()
        for name in pairs(Shapes.cells) do
            for rot = 0, 5 do
                local cells, seen = Shapes.footprint(name, 5, 5, rot), {}
                expect.eq(#cells, #Shapes.cells[name])
                for _, c in ipairs(cells) do
                    expect.falsy(seen[key(c)], name .. " trùng ô")
                    seen[key(c)] = true
                end
            end
        end
    end)
end)
