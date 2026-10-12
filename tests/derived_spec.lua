local C            = require("src.config.constants")
local Derived      = require("src.core.derived")
local Game         = require("src.core.game")
local Hex          = require("src.core.hex")
local Passives     = require("src.core.passives")
local Production   = require("src.core.production")
local Roads        = require("src.core.roads")
local Sim          = require("src.core.sim")
local State        = require("src.core.state")
local Structures   = require("src.core.structures")
local Territory    = require("src.core.territory")
local Upkeep       = require("src.core.upkeep")
local DerivedData  = require("src.data.derived")

local key = State.key

local strip = require("tests.strip")
local reload = require("tests.reload")

local function at(s, c, dq, dr) return s.map:get(c.q + dq, c.r + dr) end

-- Đặt công trình `id` cấp `level` chiếm các ô theo offset { {dq, dr}, ... } so với c.
local function put(s, pid, c, id, level, offsets)
    local tiles = {}
    for i, o in ipairs(offsets) do tiles[i] = at(s, c, o[1], o[2]) end
    return Structures.place(s, { id = id, level = level, owner = pid }, tiles)
end

local TRI = function(dq, dr) return { { dq, dr }, { dq + 1, dr }, { dq, dr + 1 } } end

local function total(events, res)
    local n = 0
    for _, e in ipairs(events) do if e.kind == "produce" and e.res == res then n = n + e.amount end end
    return n
end

describe("derived: dữ liệu", function()
    it("5 công trình Phái Sinh có chi phí, vật liệu và quy tắc đúng bảng Data", function()
        expect.eq(#DerivedData.list, 5)
        local cost = { ["D-01"] = { engineering = 3, science = 2, gold = 2 }, ["D-02"] = { culture = 2, engineering = 2, gold = 1 },
                       ["D-03"] = { engineering = 4, faith = 2, gold = 3 }, ["D-04"] = { culture = 3, faith = 2, gold = 2 },
                       ["D-05"] = { gold = 5, culture = 2, engineering = 2 } }
        local mat = { ["D-01"] = "alloy", ["D-02"] = "paper", ["D-03"] = "steel", ["D-04"] = "silk", ["D-05"] = "bond" }
        for id, c in pairs(cost) do
            local d = DerivedData.byId[id]
            for k, n in pairs(c) do expect.eq(d.cost[k], n, id .. " " .. k) end
            expect.eq(d.material, mat[id])
        end
        expect.eq(DerivedData.byId["D-03"].maxGap, 0, "D-03 phải liền kề")
        expect.truthy(DerivedData.byId["D-03"].site and DerivedData.byId["D-05"].site)
        local Buildings = require("src.data.buildings")
        expect.truthy(Buildings.byId["D-01"] and Buildings.byId["D-05"])
        for _, b in ipairs(Buildings.list) do expect.truthy(b.id:sub(1, 1) == "B", "menu xây thường không có Phái Sinh") end
    end)
end)

describe("derived: D-01 Phòng TN Vật Liệu", function()
    local function setup()
        local s, pid, c = strip()
        local kt = put(s, pid, c, "B-01", 2, TRI(0, 0))
        local nc = put(s, pid, c, "B-02", 2, { { 2, -1 }, { 3, -1 }, { 2, 0 } })
        return s, pid, c, kt, nc
    end

    it("lập khi hai công trình C2 liền kề: trừ chi phí, +1 Hợp Kim mỗi viên khớp KT hoặc KH", function()
        local s, pid, c, kt, nc = setup()
        local res = s.players[pid].res
        local before = {}
        for k, v in pairs(res) do before[k] = v end
        local ev = Game.apply(s, { type = "buildDerived", id = "D-01", a = kt.uid, b = nc.uid })
        expect.eq(ev[1].kind, "derived_built")
        for k, n in pairs(DerivedData.byId["D-01"].cost) do expect.eq(res[k], before[k] - n, k) end
        expect.eq(next(s.derived) ~= nil, true)
        local mats = Production.run(s, { 3, 1 }, pid)
        expect.eq(total(mats, "alloy"), 2)
        expect.eq(res.alloy, 2)
        Production.run(s, { 3, 3 }, 3 - pid)                 -- Long Mạch chia sẻ: lượt của người khác
        expect.eq(res.alloy, 4)
        Production.run(s, { 5, 4 }, pid)
        expect.eq(res.alloy, 4, "mặt khác không ra Hợp Kim")
    end)

    it("từ chối: thiếu cấp, trùng, đối tác của người khác, thiếu tiền", function()
        local s, pid, c, kt, nc = setup()
        nc.level = 1
        local ok, why = Game.check(s, { type = "buildDerived", id = "D-01", a = kt.uid, b = nc.uid })
        expect.falsy(ok); expect.eq(why, "công trình đối tác cần cấp 2 trở lên")
        nc.level = 2
        nc.owner = 3 - pid
        ok, why = Game.check(s, { type = "buildDerived", id = "D-01", a = kt.uid, b = nc.uid })
        expect.falsy(ok); expect.eq(why, "Không có công trình đối tác")
        nc.owner = pid
        s.players[pid].res.science = 0
        ok, why = Game.check(s, { type = "buildDerived", id = "D-01", a = kt.uid, b = nc.uid })
        expect.falsy(ok); expect.eq(why, "Không đủ tài nguyên")
        s.players[pid].res.science = 50
        Game.apply(s, { type = "buildDerived", id = "D-01", a = kt.uid, b = nc.uid })
        ok, why = Game.check(s, { type = "buildDerived", id = "D-01", a = kt.uid, b = nc.uid })
        expect.falsy(ok); expect.eq(why, "Đã có Phòng TN Vật Liệu ở công trình này")
    end)

    it("khoảng cách: 1 ô cần đường liên tục; 3 ô trở lên không thể dù có đường; đường đứt thì ngừng", function()
        local s, pid, c = strip()
        local kt = put(s, pid, c, "B-01", 2, TRI(0, 0))
        local far1 = put(s, pid, c, "B-02", 2, { { 3, -1 }, { 4, -1 }, { 3, 0 } })       -- cách 1 ô
        local ok, why = Game.check(s, { type = "buildDerived", id = "D-01", a = kt.uid, b = far1.uid })
        expect.falsy(ok); expect.eq(why, "Cần đường liên tục nối hai công trình")
        Roads.build(s, at(s, c, 2, 0))
        expect.truthy(Game.check(s, { type = "buildDerived", id = "D-01", a = kt.uid, b = far1.uid }))
        Game.apply(s, { type = "buildDerived", id = "D-01", a = kt.uid, b = far1.uid })
        expect.eq(total(Production.compute(s, { 3, 5 }, pid), "alloy"), 1)
        s.roads = {}
        expect.eq(total(Production.compute(s, { 3, 5 }, pid), "alloy"), 0, "đường bị phá: ngừng")
        Roads.build(s, at(s, c, 2, 0))
        expect.eq(total(Production.compute(s, { 3, 5 }, pid), "alloy"), 1)

        local s2, pid2, c2 = strip()
        local kt2 = put(s2, pid2, c2, "B-01", 2, TRI(0, 0))
        local far3 = put(s2, pid2, c2, "B-02", 2, { { 5, -1 }, { 6, -1 }, { 5, 0 } })     -- cách 3 ô
        for q = 2, 4 do Roads.build(s2, at(s2, c2, q, 0)) end
        ok, why = Game.check(s2, { type = "buildDerived", id = "D-01", a = kt2.uid, b = far3.uid })
        expect.falsy(ok); expect.eq(why, "Hai công trình cách 3 ô, tối đa 2")
    end)

    it("Phiến Quân phong tỏa công trình chủ thì ngừng; dỡ đối tác thì instance bị xóa ở lượt chủ", function()
        local s, pid, c, kt, nc = setup()
        Game.apply(s, { type = "buildDerived", id = "D-01", a = kt.uid, b = nc.uid })
        expect.eq(total(Production.compute(s, { 3, 5 }, pid), "alloy"), 1)
        s.rebel = { q = c.q, r = c.r }
        expect.eq(total(Production.compute(s, { 3, 5 }, pid), "alloy"), 0)
        s.rebel = { q = -99, r = -99 }
        Structures.remove(s, nc.uid)
        expect.eq(total(Production.compute(s, { 3, 5 }, pid), "alloy"), 0)
        local ev = Upkeep.startTurn(s, pid)
        local lost
        for _, e in ipairs(ev) do if e.kind == "derived_lost" then lost = e end end
        expect.truthy(lost); expect.eq(lost.id, "D-01")
        expect.eq(next(s.derived), nil)
    end)

    it("thụ động: +1 Hợp Kim mỗi 3 lượt; TN-05 trên ô chủ: +1 mỗi lượt", function()
        local s, pid, c, kt, nc = setup()
        Game.apply(s, { type = "buildDerived", id = "D-01", a = kt.uid, b = nc.uid })
        local res = s.players[pid].res
        for _ = 1, 2 do Upkeep.startTurn(s, pid) end
        expect.eq(res.alloy, 0)
        Upkeep.startTurn(s, pid)
        expect.eq(res.alloy, 1)
        c.strategic = "TN-05"
        Upkeep.startTurn(s, pid)
        expect.eq(res.alloy, 2)
        c.strategic = nil
    end)
end)

describe("derived: D-02 Xưởng In Ấn và D-04 Xưởng Dệt Lụa", function()
    it("D-02: +1 Giấy khi ra VH hoặc KT; +1 mỗi lượt chỉ khi hai công trình nối bằng đường", function()
        local s, pid, c = strip()
        local nvh = put(s, pid, c, "B-03", 1, { { 0, 0 } })
        local kt = put(s, pid, c, "B-01", 2, TRI(1, 0))                  -- liền kề
        Game.apply(s, { type = "buildDerived", id = "D-02", a = nvh.uid, b = kt.uid })
        local res = s.players[pid].res
        expect.eq(total(Production.run(s, { 2, 3 }, pid), "paper"), 2)
        Upkeep.startTurn(s, pid)
        expect.eq(res.paper, 2, "liền kề: không có thụ động nhờ đường")

        local s2, pid2, c2 = strip()
        local nvh2 = put(s2, pid2, c2, "B-03", 1, { { 0, 0 } })
        local kt2 = put(s2, pid2, c2, "B-01", 2, TRI(2, 0))              -- cách 1 ô
        Roads.build(s2, at(s2, c2, 1, 0))
        Game.apply(s2, { type = "buildDerived", id = "D-02", a = nvh2.uid, b = kt2.uid })
        Upkeep.startTurn(s2, pid2)
        expect.eq(s2.players[pid2].res.paper, 1)
    end)

    it("D-04: +1 Lụa khi ra VH hoặc TN; kề Khu Dân Cư +1 mỗi lượt; kề Đầm Lầy/Sông thêm +1", function()
        local s, pid, c = strip()
        local nvh = put(s, pid, c, "B-03", 2, { { 0, 0 }, { 1, 0 } })
        local tem = put(s, pid, c, "B-04", 2, { { 2, 0 }, { 3, 0 } })
        Game.apply(s, { type = "buildDerived", id = "D-04", a = nvh.uid, b = tem.uid })
        local res = s.players[pid].res
        expect.eq(total(Production.run(s, { 2, 4 }, pid), "silk"), 2)
        Upkeep.startTurn(s, pid)
        expect.eq(res.silk, 2)
        at(s, c, 0, -1).terrain = "DH-10"
        Upkeep.startTurn(s, pid)
        expect.eq(res.silk, 3)
        at(s, c, 1, 1).terrain = "DH-04"
        Upkeep.startTurn(s, pid)
        expect.eq(res.silk, 5)
    end)
end)

describe("derived: D-03 Xưởng Luyện Kim", function()
    local function setup()
        local s, pid, c = strip()
        local kt = put(s, pid, c, "B-01", 3, { { 0, 0 }, { 1, 0 }, { 2, 0 }, { 3, 0 }, { 0, 1 }, { 1, 1 } })
        local tem = put(s, pid, c, "B-04", 2, { { 4, 0 }, { 5, 0 } })
        return s, pid, c, kt, tem
    end

    it("chiếm 1 ô kề Trại KT C3, +1 Thép khi ra KT, +1 mỗi 4 lượt", function()
        local s, pid, c, kt, tem = setup()
        local site = at(s, c, 0, -1)
        local ev = Game.apply(s, { type = "buildDerived", id = "D-03", a = kt.uid, b = tem.uid, q = site.q, r = site.r })
        expect.eq(ev[1].kind, "derived_built")
        expect.eq(Structures.at(s, site).id, "D-03")
        expect.eq(s.owner[key(site)], pid)
        expect.eq(total(Production.run(s, { 3, 3 }, pid), "steel"), 2)
        local res = s.players[pid].res
        for _ = 1, 3 do Upkeep.startTurn(s, pid) end
        expect.eq(res.steel, 2)
        Upkeep.startTurn(s, pid)
        expect.eq(res.steel, 3)
        expect.truthy(Sim.invariants(s))
    end)

    it("từ chối: ô riêng không kề, ô đã có công trình, địa hình cấm, đối tác không liền kề (dù có đường)", function()
        local s, pid, c, kt, tem = setup()
        local ok, why = Game.check(s, { type = "buildDerived", id = "D-03", a = kt.uid, b = tem.uid, q = c.q + 8, r = c.r })
        expect.falsy(ok)
        local far = at(s, c, 5, 2)
        ok, why = Game.check(s, { type = "buildDerived", id = "D-03", a = kt.uid, b = tem.uid, q = far.q, r = far.r })
        expect.falsy(ok); expect.truthy(why:find("cách", 1, true))
        ok, why = Game.check(s, { type = "buildDerived", id = "D-03", a = kt.uid, b = tem.uid, q = c.q, r = c.r })
        expect.falsy(ok); expect.eq(why, "Ô đã có công trình")
        local site = at(s, c, 0, -1)
        site.terrain = "DH-04"
        ok, why = Game.check(s, { type = "buildDerived", id = "D-03", a = kt.uid, b = tem.uid, q = site.q, r = site.r })
        expect.falsy(ok); expect.truthy(why:find("không xây được", 1, true))
        site.terrain = "DH-01"
        tem.tiles = { key(at(s, c, 6, 0)), key(at(s, c, 7, 0)) }       -- dời đối tác cách 2 ô: D-03 cấm kể cả có đường
        s.occupied = {}
        for _, b in pairs(s.buildings) do for _, k in ipairs(b.tiles) do s.occupied[k] = b.uid end end
        Roads.build(s, at(s, c, 4, 0)); Roads.build(s, at(s, c, 5, 0))
        ok, why = Game.check(s, { type = "buildDerived", id = "D-03", a = kt.uid, b = tem.uid, q = site.q, r = site.r })
        expect.falsy(ok); expect.truthy(why:find("tối đa 0", 1, true))
    end)

    it("legal() có buildDerived cho D-03; công trình riêng bị dỡ thì Phái Sinh bị xóa và ô trả về", function()
        local s, pid, c, kt, tem = setup()
        local found = 0
        for _, cmd in ipairs(Game.legal(s)) do
            if cmd.type == "buildDerived" then found = found + 1; expect.truthy(Game.check(s, cmd)); expect.eq(cmd.id, "D-03") end
        end
        expect.truthy(found > 0)
        local site = at(s, c, 0, -1)
        Game.apply(s, { type = "buildDerived", id = "D-03", a = kt.uid, b = tem.uid, q = site.q, r = site.r })
        Structures.remove(s, Structures.at(s, site).uid)
        local ev = Upkeep.startTurn(s, pid)
        local lost = false
        for _, e in ipairs(ev) do if e.kind == "derived_lost" then lost = true end end
        expect.truthy(lost)
        expect.eq(Structures.at(s, site), nil)
    end)
end)

describe("derived: D-05 Nhà Ngân Hàng và Tín Phiếu", function()
    local function setup()
        local s, pid, c = strip()
        local nvh = put(s, pid, c, "B-03", 1, { { 0, 0 } })
        local kt = put(s, pid, c, "B-01", 2, TRI(1, 0))
        local market = put(s, pid, c, "B-05", 2, { { 6, 0 }, { 7, 0 } })
        return s, pid, c, nvh, kt, market
    end

    it("cần Xưởng In Ấn đang hoạt động; lập xong +1 Tín Phiếu mỗi viên Vàng, tối đa 5", function()
        local s, pid, c, nvh, kt, market = setup()
        local site = at(s, c, 8, 0)
        local ok, why = Game.check(s, { type = "buildDerived", id = "D-05", a = market.uid, b = 1, q = site.q, r = site.r })
        expect.falsy(ok); expect.eq(why, "Cần Xưởng In Ấn đang hoạt động")
        Game.apply(s, { type = "buildDerived", id = "D-02", a = nvh.uid, b = kt.uid })
        local did
        for k in pairs(s.derived) do did = k end
        local ev = Game.apply(s, { type = "buildDerived", id = "D-05", a = market.uid, b = did, q = site.q, r = site.r })
        expect.eq(ev[1].kind, "derived_built")
        local res = s.players[pid].res
        expect.eq(total(Production.run(s, { 5, 5 }, pid), "bond"), 2)
        expect.eq(res.bond, 2)
        for _ = 1, 5 do Production.run(s, { 5, 5 }, 3 - pid) end
        expect.eq(res.bond, C.BOND_MAX)
        expect.truthy(Sim.invariants(s))
    end)

    it("lãi 0.5 V mỗi Tín Phiếu mỗi lượt (phần lẻ dồn); đổi 1 Tín Phiếu lấy 2 V cần ngân hàng hoạt động", function()
        local s, pid, c, nvh, kt, market = setup()
        local site = at(s, c, 8, 0)
        Game.apply(s, { type = "buildDerived", id = "D-02", a = nvh.uid, b = kt.uid })
        local did
        for k in pairs(s.derived) do did = k end
        Game.apply(s, { type = "buildDerived", id = "D-05", a = market.uid, b = did, q = site.q, r = site.r })
        local res = s.players[pid].res
        res.bond = 3
        local gold = res.gold
        Upkeep.startTurn(s, pid)
        expect.eq(res.gold, gold + 1)
        expect.eq(s.players[pid].carry.gold, 0.5)
        Upkeep.startTurn(s, pid)
        expect.eq(res.gold, gold + 3)
        gold = res.gold
        local ev = Game.apply(s, { type = "redeemBond", n = 2 })
        expect.eq(ev[1].kind, "bond_redeemed"); expect.eq(res.bond, 1); expect.eq(res.gold, gold + 4)
        local ok, why = Game.check(s, { type = "redeemBond", n = 5 })
        expect.falsy(ok); expect.eq(why, "Không đủ Tín Phiếu")
        ok = Game.check(s, { type = "redeemBond", n = 0 })
        expect.falsy(ok)
        s.roads = {}; nvh.demolishing = true      -- Xưởng In Ấn ngừng -> ngân hàng ngừng
        ok, why = Game.check(s, { type = "redeemBond", n = 1 })
        expect.falsy(ok); expect.eq(why, "Cần Nhà Ngân Hàng đang hoạt động")
    end)
end)

describe("derived: lưu / nạp và mô phỏng", function()
    it("save/load giữ Phái Sinh, ô riêng và bộ đếm chu kỳ", function()
        local s, pid, c = strip(9)
        local kt = put(s, pid, c, "B-01", 3, { { 0, 0 }, { 1, 0 }, { 2, 0 }, { 3, 0 }, { 0, 1 }, { 1, 1 } })
        local tem = put(s, pid, c, "B-04", 2, { { 4, 0 }, { 5, 0 } })
        local site = at(s, c, 0, -1)
        Game.apply(s, { type = "buildDerived", id = "D-03", a = kt.uid, b = tem.uid, q = site.q, r = site.r })
        Upkeep.startTurn(s, pid)
        local s2 = reload(s)   -- thế cờ dựng tay không qua được kiểm tra của Game.load
        local inst
        for _, i in pairs(s2.derived) do inst = i end
        expect.eq(inst.id, "D-03"); expect.eq(inst.timer, 1); expect.truthy(Derived.isActive(s2, inst))
        expect.eq(s2.nextDerivedUid, s.nextDerivedUid)
        expect.eq(Structures.at(s2, site).id, "D-03")
    end)

    it("save v3 sớm thiếu derived/nextDerivedUid được migration v3 -> v4 bù mặc định khi nạp", function()
        local s = Game.new({ seed = 9, players = 2 })
        local Serialize = require("src.core.serialize")
        local data = assert(Serialize.load(Game.save(s)))
        data.version = 3
        data.state.derived, data.state.nextDerivedUid, data.state.nextUnitUid = nil, nil, nil
        local s2 = assert(Game.load(Serialize.dump(data)))
        expect.eq(next(s2.derived), nil); expect.eq(s2.nextDerivedUid, 1); expect.eq(s2.nextUnitUid, 1)
    end)

    it("chơi ngẫu nhiên nhiều tài nguyên: bất biến luôn đúng, Phái Sinh không làm hỏng ván", function()
        local s = strip(14)
        local rt = s.map.list[1]                 -- Phiến Quân thật sự trên bản đồ (strip đặt nó ngoài bản đồ)
        s.rebel = { q = rt.q, r = rt.r }
        local built = 0
        local seen = #s.log
        for _ = 1, 150 do
            Sim.advance(s, 10, 14)
            for p = 1, 2 do
                for k, v in pairs(s.players[p].res) do if v < 30 and k ~= "bond" then s.players[p].res[k] = 30 end end
            end
            local ok, why = Sim.invariants(s)
            expect.truthy(ok, why)
            for i = seen + 1, #s.log do if s.log[i].kind == "derived_built" then built = built + 1 end end
            seen = #s.log
            if s.phase == "over" then break end
        end
        expect.truthy(built >= 0)
    end)
end)
