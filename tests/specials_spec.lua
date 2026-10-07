local C            = require("src.config.constants")
local Aura         = require("src.core.aura")
local Game         = require("src.core.game")
local Hex          = require("src.core.hex")
local Production   = require("src.core.production")
local Rebel        = require("src.core.rebel")
local Rng          = require("src.core.rng")
local Scoring      = require("src.core.scoring")
local Sim          = require("src.core.sim")
local Specials     = require("src.core.specials")
local State        = require("src.core.state")
local Structures   = require("src.core.structures")
local Territory    = require("src.core.territory")
local Units        = require("src.core.units")
local Upkeep       = require("src.core.upkeep")
local Dice         = require("src.core.dice")
local Passives     = require("src.core.passives")
local Data         = require("src.data.specials")
local Shapes       = require("src.data.shapes")
local strip        = require("tests.strip")

local key = State.key

local function at(s, c, dq, dr) return s.map:get(c.q + dq, c.r + dr) end

local function put(s, pid, c, id, level, offsets)
    local tiles = {}
    for i, o in ipairs(offsets) do tiles[i] = at(s, c, o[1], o[2]) end
    return Structures.place(s, { id = id, level = level, owner = pid }, tiles)
end

-- Cấu hình chung: Nhà Chính C3, nhiều vật liệu.
local function setup(seed)
    local s, pid, c = strip(seed)
    s.players[pid].hqLevel = 3
    local res = s.players[pid].res
    for _, m in ipairs({ "alloy", "paper", "steel", "silk" }) do res[m] = 30 end
    return s, pid, c, res
end

-- Công trình nền để đủ điều kiện từng Đặc Biệt.
local TRAP = { { 0, 0 }, { 1, 0 }, { 2, 0 }, { 3, 0 }, { 0, 1 }, { 1, 1 } }
local TRI  = function(dq, dr) return { { dq, dr }, { dq + 1, dr }, { dq, dr + 1 } } end
local LOW  = { { 0, 1 }, { 1, 1 }, { 2, 1 }, { 3, 1 }, { 0, 2 }, { 1, 2 } }   -- Viện NC C3 ở hàng dưới, chừa hàng trên cho hex7

describe("specials: dữ liệu", function()
    it("5 Đặc Biệt, 3 cấp mỗi loại (xây + hai nâng cấp), chi phí theo Data", function()
        expect.eq(#Data.list, 5)
        local base = { ["S-01"] = { alloy = 3, science = 5, paper = 2 }, ["S-02"] = { steel = 3, engineering = 6, gold = 5 },
                       ["S-03"] = { silk = 2, paper = 3, culture = 6, gold = 4 },
                       ["S-04"] = { alloy = 2, paper = 2, science = 4, engineering = 4 },
                       ["S-05"] = { faith = 8, silk = 2, steel = 1, gold = 4 } }
        for id, cost in pairs(base) do
            local d = Data.byId[id]
            expect.eq(#d.levels, 3)
            for k, n in pairs(cost) do expect.eq(d.levels[1].cost[k], n, id .. " " .. k) end
        end
        expect.eq(Data.byId["S-02"].levels[2].cost.steel, 2)
        expect.eq(#Shapes.cells.hex7, 7); expect.eq(#Shapes.cells.fort4, 4)
        local Buildings = require("src.data.buildings")
        for _, d in ipairs(Data.list) do
            expect.truthy(Buildings.byId[d.id], d.id)
            expect.eq(Buildings.level(d.id, 3).tiles, #Shapes.cells[d.shape])
        end
    end)

    it("hình hex7 là ô giữa + 6 ô kề; fort4 là ô giữa + 3 ô kề xen kẽ", function()
        for _, name in ipairs({ "hex7", "fort4" }) do
            local cells = Shapes.footprint(name, 0, 0, 0)
            for i = 2, #cells do expect.eq(Hex.distance(cells[1], cells[i]), 1, name) end
        end
        local f = Shapes.footprint("fort4", 0, 0, 0)
        for i = 2, 4 do for j = i + 1, 4 do expect.eq(Hex.distance(f[i], f[j]), 2, "ba ô kề không liền nhau") end end
    end)
end)

describe("specials: điều kiện xây", function()
    it("cần Nhà Chính C3, đủ tài nguyên, công trình tiên quyết trong bán kính", function()
        local s, pid, c, res = setup()
        s.players[pid].hqLevel = 2
        local ok, why = Specials.checkBuild(s, pid, "S-01", c.q + 3, c.r - 1, 0)
        expect.falsy(ok); expect.eq(why, "Cần Nhà Chính cấp 3 để xây Công Trình Đặc Biệt")
        s.players[pid].hqLevel = 3
        ok, why = Specials.checkBuild(s, pid, "S-01", c.q + 3, c.r - 1, 0)
        expect.falsy(ok); expect.truthy(why:find("Viện Nghiên Cứu cấp 3", 1, true))
        put(s, pid, c, "B-02", 3, LOW)
        expect.truthy(Specials.checkBuild(s, pid, "S-01", c.q + 3, c.r - 1, 0))
        res.alloy = 1
        ok, why = Game.check(s, { type = "buildSpecial", id = "S-01", q = c.q + 3, r = c.r - 1, rot = 0 })
        expect.falsy(ok); expect.eq(why, "Không đủ tài nguyên")
        res.alloy = 30
        local before = {}
        for k, v in pairs(res) do before[k] = v end
        local ev = Game.apply(s, { type = "buildSpecial", id = "S-01", q = c.q + 3, r = c.r - 1, rot = 0 })
        expect.eq(ev[1].kind, "special_built")
        for k, n in pairs(Data.byId["S-01"].levels[1].cost) do expect.eq(res[k], before[k] - n, k) end
        local b = Structures.at(s, at(s, c, 3, -1))
        expect.eq(b.id, "S-01"); expect.eq(#b.tiles, 7); expect.eq(b.level, 1)
        expect.truthy(Sim.invariants(s))
        ok, why = Specials.checkBuild(s, pid, "S-01", c.q + 7, c.r - 1, 0)
        expect.falsy(ok); expect.eq(why, "Bạn đã có Tháp Thiên Văn")
    end)

    it("từ chối: ô không thuộc mình, đã có công trình, địa hình trung tâm sai, hình vượt bản đồ", function()
        local s, pid, c = setup()
        put(s, pid, c, "B-02", 3, TRAP)
        local ok, why = Specials.checkBuild(s, pid, "S-01", c.q + 1, c.r, 0)
        expect.falsy(ok); expect.eq(why, "Có ô đã có công trình")
        local ctr = at(s, c, 4, -1)
        s.owner[key(at(s, c, 5, -1))] = 3 - pid
        ok, why = Specials.checkBuild(s, pid, "S-01", ctr.q, ctr.r, 0)
        expect.falsy(ok); expect.eq(why, "Mọi ô phải là lãnh thổ thực hữu của bạn")
        s.owner[key(at(s, c, 5, -1))] = pid
        ctr.terrain = "DH-04"
        ok, why = Specials.checkBuild(s, pid, "S-01", ctr.q, ctr.r, 0)
        expect.falsy(ok); expect.truthy(why:find("không xây được", 1, true))
        ctr.terrain = "DH-01"
        ok, why = Specials.checkBuild(s, pid, "S-01", -5, -5, 0)
        expect.falsy(ok); expect.eq(why, "Hình vượt ra ngoài bản đồ")
    end)

    it("S-02: cần Trại KT C2 trong bán kính 2; xây trên Núi cần Đá Granite", function()
        local s, pid, c = setup()
        local ok, why = Specials.checkBuild(s, pid, "S-02", c.q + 4, c.r, 0)
        expect.falsy(ok); expect.truthy(why:find("Trại Khai Thác cấp 2", 1, true))
        put(s, pid, c, "B-01", 2, TRI(0, 0))
        ok = Specials.checkBuild(s, pid, "S-02", c.q + 2, c.r, 0)
        expect.truthy(ok)
        local m = at(s, c, 2, 0)
        for _, o in ipairs({ { 2, 0 }, { 3, 0 }, { 2, -1 }, { 1, 1 } }) do at(s, c, o[1], o[2]).terrain = "DH-03" end
        ok, why = Specials.checkBuild(s, pid, "S-02", m.q, m.r, 0)
        expect.falsy(ok); expect.eq(why, "Xây trên Núi cần ô có Đá Granite")
        m.strategic = "TN-01"
        ok, why = Specials.checkBuild(s, pid, "S-02", m.q, m.r, 0)
        expect.truthy(ok, why)
        m.strategic = nil
    end)

    it("S-03 cần Nhà VH C3 và Xưởng In Ấn hoạt động; S-04 cần Viện NC C2 + Trại KT C2; S-05 cần Đền Thờ C3 và ô cùng địa hình", function()
        local s, pid, c = setup()
        put(s, pid, c, "B-03", 3, { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } })
        local ok, why = Specials.checkBuild(s, pid, "S-03", c.q - 1, c.r - 1, 0)
        expect.falsy(ok); expect.eq(why, "Cần Xưởng In Ấn đang hoạt động")
        local kt = put(s, pid, c, "B-01", 2, TRI(2, 1))
        Game.apply(s, { type = "buildDerived", id = "D-02", a = Structures.at(s, c).uid, b = kt.uid })
        ok, why = Specials.checkBuild(s, pid, "S-03", c.q - 1, c.r - 1, 0)
        expect.truthy(ok, why)

        ok, why = Specials.checkBuild(s, pid, "S-04", c.q + 6, c.r - 1, 0)
        expect.falsy(ok); expect.truthy(why:find("Viện Nghiên Cứu cấp 2", 1, true))

        local s2, pid2, c2 = setup()
        ok, why = Specials.checkBuild(s2, pid2, "S-05", c2.q + 4, c2.r, 0)
        expect.falsy(ok)
        put(s2, pid2, c2, "B-04", 3, { { 3, -1 }, { 2, -1 }, { 1, -1 } })    -- neo (3,-1) cách tâm Thiên Đình 2 ô
        ok, why = Specials.checkBuild(s2, pid2, "S-05", c2.q + 4, c2.r, 0)
        expect.falsy(ok); expect.truthy(why:find("không xây được", 1, true) or why:find("cùng", 1, true))
        for _, o in ipairs({ { 4, 0 }, { 5, 0 }, { 4, 1 } }) do at(s2, c2, o[1], o[2]).terrain = "DH-02" end
        ok, why = Specials.checkBuild(s2, pid2, "S-05", c2.q + 4, c2.r, 0)
        expect.truthy(ok, why)
        at(s2, c2, 5, 0).terrain = "DH-03"
        ok, why = Specials.checkBuild(s2, pid2, "S-05", c2.q + 4, c2.r, 0)
        expect.falsy(ok); expect.eq(why, "Mọi ô phải cùng một loại địa hình")
    end)

    it("legal() có buildSpecial khi đủ điều kiện, mọi lệnh qua check; placements không trùng", function()
        local s, pid, c = setup()
        put(s, pid, c, "B-02", 3, LOW)
        local n = 0
        for _, cmd in ipairs(Game.legal(s)) do
            if cmd.type == "buildSpecial" then n = n + 1; expect.truthy(Game.check(s, cmd)); expect.eq(cmd.id, "S-01") end
        end
        expect.truthy(n > 0)
        local seen = {}
        for _, pl in ipairs(Specials.placements(s, pid, "S-01")) do
            local keys = {}
            for i, t in ipairs(pl.tiles) do keys[i] = key(t) end
            table.sort(keys)
            local sig = table.concat(keys, ";")
            expect.falsy(seen[sig]); seen[sig] = true
        end
    end)
end)

describe("specials: nâng cấp +1 / +2", function()
    it("trả đúng chi phí từng cấp, tối đa +2, không đổi footprint", function()
        local s, pid, c, res = setup()
        put(s, pid, c, "B-02", 3, LOW)
        Game.apply(s, { type = "buildSpecial", id = "S-01", q = c.q + 3, r = c.r - 1, rot = 0 })
        local b = Structures.at(s, at(s, c, 3, -1))
        expect.eq(Aura.radius(b), 2)
        local before = {}
        for k, v in pairs(res) do before[k] = v end
        local ev = Game.apply(s, { type = "upgradeSpecial", uid = b.uid })
        expect.eq(ev[1].kind, "special_upgrade"); expect.eq(b.level, 2); expect.eq(Aura.radius(b), 3)
        for k, n in pairs(Data.byId["S-01"].levels[2].cost) do expect.eq(res[k], before[k] - n, k) end
        Game.apply(s, { type = "upgradeSpecial", uid = b.uid })
        expect.eq(b.level, 3); expect.eq(#b.tiles, 7)
        local ok, why = Game.check(s, { type = "upgradeSpecial", uid = b.uid })
        expect.falsy(ok); expect.eq(why, "Đã ở cấp tối đa")
        expect.eq(#require("src.core.construction").upgradeOptions(s, b.uid), 0, "không nâng bằng hình mới")
        expect.truthy(Sim.invariants(s))
    end)

    it("từ chối: thiếu tài nguyên, công trình người khác, không phải Đặc Biệt", function()
        local s, pid, c, res = setup()
        local kt = put(s, pid, c, "B-01", 2, TRI(0, 0))
        local ok, why = Game.check(s, { type = "upgradeSpecial", uid = kt.uid })
        expect.falsy(ok); expect.eq(why, "Không phải công trình Đặc Biệt")
        put(s, pid, c, "B-02", 3, { { 0, 2 }, { 1, 2 }, { 2, 2 }, { 3, 2 } })
        local sp = put(s, pid, c, "S-02", 1, { { 4, -1 }, { 5, -1 }, { 4, -2 }, { 3, 0 } })
        res.steel = 0
        ok, why = Game.check(s, { type = "upgradeSpecial", uid = sp.uid })
        expect.falsy(ok); expect.eq(why, "Không đủ tài nguyên")
        sp.owner = 3 - pid
        ok, why = Game.check(s, { type = "upgradeSpecial", uid = sp.uid })
        expect.falsy(ok); expect.eq(why, "Không phải công trình của bạn")
    end)
end)

describe("specials: S-01 Tháp Thiên Văn", function()
    it("aura +1 KH mỗi viên KH cho Viện NC của chủ trong bán kính; không cho ô ngoài aura hay của người khác", function()
        local s, pid, c = setup()
        local tower = put(s, pid, c, "S-01", 1, { { 3, -1 }, { 4, -1 }, { 4, -2 }, { 3, -2 }, { 2, -1 }, { 2, 0 }, { 3, 0 } })
        local near = put(s, pid, c, "B-02", 1, { { 5, -2 } })       -- cách tâm 2
        local far = put(s, pid, c, "B-02", 1, { { 8, 0 } })         -- ngoài aura
        local rival = put(s, pid, c, "B-02", 1, { { 5, -1 } })      -- cách tâm 2
        rival.owner = 3 - pid
        local function sci()
            local per = {}
            for _, e in ipairs(Production.compute(s, { 1, 5 }, pid)) do
                if e.kind == "produce" and e.res == "science" then per[e.key] = e.amount end
            end
            return per
        end
        local per = sci()
        expect.eq(per[near.anchor], 2); expect.eq(per[far.anchor], 1); expect.eq(per[rival.anchor], 1)
        tower.level = 2                                                  -- bán kính 3: phủ tới ô cách 3
        local third = put(s, pid, c, "B-02", 1, { { 6, -1 } })          -- cách tâm 3
        expect.eq(sci()[third.anchor], 2)
        tower.demolishing = true
        expect.eq(sci()[near.anchor], 1, "chờ dỡ thì mất aura")
    end)

    it("xem trước xúc xắc kế tiếp (1 viên, +2 thì 2 viên) mà không đổi RNG; khớp lần đổ thật", function()
        local s, pid, c = setup()
        local tower = put(s, pid, c, "S-01", 1, { { 3, -1 }, { 4, -1 }, { 4, -2 }, { 3, -2 }, { 2, -1 }, { 2, 0 }, { 3, 0 } })
        s.phase = "roll"
        for i, id in ipairs(s.order) do if id == pid then s.turn = i end end
        local p1 = Specials.peekDice(s, pid)
        expect.eq(#p1, 1)
        expect.eq(Specials.peekDice(s, pid)[1], p1[1], "xem hai lần cho cùng kết quả")
        expect.eq(Specials.peekDice(s, 3 - pid), nil, "người khác không có tháp")
        tower.level = 3
        local p2 = Specials.peekDice(s, pid)
        expect.eq(#p2, 2); expect.eq(p2[1], p1[1])
        local ev = Game.apply(s, { type = "roll" })
        local roll
        for _, e in ipairs(ev) do if e.kind == "roll" then roll = e end end
        expect.eq(roll.dice[1], p2[1]); expect.eq(roll.dice[2], p2[2])
    end)
end)

describe("specials: S-02 Pháo Đài", function()
    local FORT = { { 4, -1 }, { 5, -1 }, { 4, -2 }, { 3, 0 } }

    it("aura: Phiến Quân không được dừng trong bán kính, trừ khi mọi đường đều bị cấm", function()
        local s, pid, c = setup()
        local fort = put(s, pid, c, "S-02", 1, FORT)
        local centre = Aura.centre(s, fort)
        expect.truthy(Rebel.forbiddenStop(s, centre))
        expect.truthy(Rebel.forbiddenStop(s, at(s, c, 6, -1)))
        expect.falsy(Rebel.forbiddenStop(s, at(s, c, 8, 2)))
        fort.demolishing = true
        expect.falsy(Rebel.forbiddenStop(s, centre))
        fort.demolishing = false
        -- PQ ở gần aura: bước vào ô trong aura mà phải dừng ngay (hết điểm) thì bị loại khỏi các bước hợp lệ
        local edge = at(s, c, 7, -1)            -- cách tâm (4,-1): 3 > 2: ngoài aura; ô kề (6,-1) nằm trong aura
        s.rebel = { q = edge.q, r = edge.r, pending = { stage = "move", points = 1, roller = pid, visited = { [key(edge)] = true } } }
        local steps = Rebel.legalSteps(s)
        for _, t in ipairs(steps) do expect.falsy(Rebel.forbiddenStop(s, t)) end
        expect.truthy(#steps > 0 and #steps < 6)
    end)

    it("đơn vị Viễn Chinh đối thủ vào aura tốn thêm 2 điểm; +1 thì bị chặn đứng; chủ và Giao Thương không bị", function()
        local s, pid, c = setup()
        local fort = put(s, pid, c, "S-02", 1, FORT)
        local enemy = Units.spawn(s, 3 - pid, "expedition", at(s, c, 9, 0))
        enemy.mp = 6
        local inside = at(s, c, 6, -1)            -- trong aura R2 của (4,-1)
        expect.eq(Units.stepCost(s, enemy, inside), 1 + 2)
        local mine = Units.spawn(s, pid, "expedition", at(s, c, 9, 0))
        expect.eq(Units.stepCost(s, mine, inside), 1)
        local trade = Units.spawn(s, 3 - pid, "trade", at(s, c, 9, 0))
        expect.eq(Units.stepCost(s, trade, inside), 1)
        fort.level = 2                            -- +1: chặn đứng
        s.phase = "action"
        for i, id in ipairs(s.order) do if id == 3 - pid then s.turn = i end end
        enemy.mp = 8
        s.players[3 - pid].res.gold = 20
        inside = at(s, c, 7, -1)                  -- +1 mở aura bán kính 3: ô này giờ nằm trong aura
        local reach = Units.reachable(s, enemy)
        local node = reach[key(inside)]
        expect.truthy(node, "vẫn vào được")
        for k, n in pairs(reach) do
            if n.prev == key(inside) then expect.truthy(false, "không được đi tiếp từ ô chặn đứng: " .. k) end
        end
        Units.move(s, enemy, inside.q, inside.r)
        expect.eq(enemy.mp, 0)
    end)

    it("Viễn Chinh sinh ở Pháo Đài: được +2 bước ở lượt đầu; +1 KT thụ động mỗi vòng", function()
        local s, pid, c = setup()
        local fort = put(s, pid, c, "S-02", 1, FORT)
        local tile = Structures.tilesOf(s, fort)[2]
        local ev = Game.apply(s, { type = "buyUnit", unit = "expedition", q = tile.q, r = tile.r })
        local u = s.units[ev[1].uid]
        expect.eq(u.spawnBonus, 2)
        Upkeep.startTurn(s, pid)
        expect.eq(u.mp, C.EXPEDITION_BASE_MOVE + 2)
        expect.eq(u.spawnBonus, nil)
        Upkeep.startTurn(s, pid)
        expect.eq(u.mp, C.EXPEDITION_BASE_MOVE, "chỉ lượt đầu")
        local kt = s.players[pid].res.engineering
        Upkeep.startTurn(s, pid)
        expect.eq(s.players[pid].res.engineering, kt + 1)
    end)

    it("+2 \"Pháo\": phá công trình cấp 1 của đối thủ trong bán kính 3, hồi 5 vòng, TN trên ô mất", function()
        local s, pid, c = setup()
        local fort = put(s, pid, c, "S-02", 3, FORT)
        local victim = put(s, pid, c, "B-01", 1, { { 6, 0 } })
        victim.owner = 3 - pid
        local safe = put(s, pid, c, "B-01", 2, { { 6, -1 } })
        safe.owner = 3 - pid
        local far = put(s, pid, c, "B-01", 1, { { 0, 2 } })
        far.owner = 3 - pid
        at(s, c, 6, 0).strategic = "TN-05"
        local ok, why = Game.check(s, { type = "fortressStrike", uid = fort.uid, target = safe.uid })
        expect.falsy(ok); expect.truthy(why:find("cấp 1", 1, true))
        ok = Game.check(s, { type = "fortressStrike", uid = fort.uid, target = far.uid })
        expect.falsy(ok)
        local targets = Specials.strikeTargets(s, pid, fort)
        expect.eq(#targets, 1); expect.eq(targets[1].uid, victim.uid)
        local ev = Game.apply(s, { type = "fortressStrike", uid = fort.uid, target = victim.uid })
        expect.eq(ev[1].kind, "fortress_strike"); expect.eq(ev[2].kind, "strategic_lost")
        expect.eq(Structures.at(s, at(s, c, 6, 0)), nil)
        expect.truthy(s.lostStrategic[key(at(s, c, 6, 0))])
        local other = put(s, pid, c, "B-01", 1, { { 5, 0 } })
        other.owner = 3 - pid
        ok, why = Game.check(s, { type = "fortressStrike", uid = fort.uid, target = other.uid })
        expect.falsy(ok); expect.truthy(why:find("hồi", 1, true))
        s.round = s.round + Data.STRIKE_COOLDOWN
        expect.truthy(Game.check(s, { type = "fortressStrike", uid = fort.uid, target = other.uid }))
        fort.level = 2
        ok, why = Game.check(s, { type = "fortressStrike", uid = fort.uid, target = other.uid })
        expect.falsy(ok); expect.truthy(why:find("+2", 1, true))
        at(s, c, 6, 0).strategic = nil
    end)
end)

describe("specials: S-03 Bảo Tàng, S-04 Đài Phát Thanh", function()
    it("S-03: phiếu ×1.5 (làm tròn lên) trên Khu Dân Cư/Danh Thắng trong aura; ô thường và ngoài aura không", function()
        local s, pid, c = setup()
        local museum = put(s, pid, c, "S-03", 1, TRI(3, 0))
        local inside, outside, plain = at(s, c, 4, -1), at(s, c, 9, 1), at(s, c, 3, -1)
        inside.settlement, outside.settlement = 1, 1
        s.votes[key(inside)], s.votes[key(outside)], s.votes[key(plain)] = { [pid] = 3 }, { [pid] = 3 }, { [pid] = 3 }
        expect.eq(Territory.votesOn(s, inside, pid), 5)
        expect.eq(Territory.votesOn(s, outside, pid), 3)
        expect.eq(Territory.votesOn(s, plain, pid), 3)
        expect.eq(Territory.votesOn(s, inside, 3 - pid), 0)
        s.votes[key(inside)] = { [pid] = 2 }
        expect.eq(Territory.votesOn(s, inside, pid), 3)
        museum.level = 2
        expect.eq(Aura.radius(museum), 3)
        inside.settlement, outside.settlement = nil, nil
    end)

    it("S-03: +2 VH mỗi vòng; +1 điểm cuối ván cho mỗi Khu Dân Cư chi phối trong bán kính 3; tính như công trình C2+", function()
        local s, pid, c = setup()
        put(s, pid, c, "S-03", 1, TRI(3, 0))
        s.rebel = { q = -99, r = -99 }
        local before = s.players[pid].res.culture
        Upkeep.startTurn(s, pid)
        expect.eq(s.players[pid].res.culture, before + 2)
        local a, b = at(s, c, 5, 0), at(s, c, 9, 2)
        s.map.settlements = { { tiles = { a } }, { tiles = { b } } }
        local base = Scoring.score(s)[pid]
        expect.eq(base.museum, 1, "chỉ cụm trong bán kính 3 và do mình chi phối")
        expect.eq(base.buildings, C.SCORE_BUILDING_C2, "Đặc Biệt tính như C2+")
        expect.eq(base.total, base.tiles + base.landmarks + base.buildings + base.resources + base.museum)
        s.owner[key(a)] = 3 - pid
        expect.eq(Scoring.score(s)[pid].museum, 0)
        s.map.settlements = nil
    end)

    it("S-04: khi chủ đài đổ, công trình (kể cả của đối thủ) trong bán kính 3 sản xuất +1 mỗi viên; người khác đổ thì không", function()
        local s, pid, c = setup()
        put(s, pid, c, "S-04", 1, { { 3, -1 }, { 4, -1 }, { 4, -2 }, { 3, -2 }, { 2, -1 }, { 2, 0 }, { 3, 0 } })
        local mine = put(s, pid, c, "B-01", 1, { { 5, 0 } })
        local rival = put(s, pid, c, "B-01", 1, { { 5, -1 } })      -- cách tâm 2
        rival.owner = 3 - pid
        local far = put(s, pid, c, "B-01", 1, { { 9, 2 } })
        local function eng(roller)
            local per = {}
            for _, e in ipairs(Production.compute(s, { 3, 5 }, roller)) do
                if e.kind == "produce" and e.res == "engineering" then per[e.key] = e.amount end
            end
            return per
        end
        local own = eng(pid)
        expect.eq(own[mine.anchor], 2); expect.eq(own[rival.anchor], 2); expect.eq(own[far.anchor], 1)
        local theirs = eng(3 - pid)
        expect.eq(theirs[mine.anchor], 1); expect.eq(theirs[rival.anchor], 1)
    end)

    it("S-04 +2 Phát Sóng: cả hai viên thành mặt cao hơn, hồi 3 vòng, cần nâng cấp +2", function()
        local s, pid, c = setup()
        local tower = put(s, pid, c, "S-04", 1, { { 3, -1 }, { 4, -1 }, { 4, -2 }, { 3, -2 }, { 2, -1 }, { 2, 0 }, { 3, 0 } })
        s.phase = "roll"
        for i, id in ipairs(s.order) do if id == pid then s.turn = i end end
        local ok, why = Game.check(s, { type = "roll", broadcast = true })
        expect.falsy(ok); expect.eq(why, "Cần Đài Phát Thanh Long Mạch nâng cấp +2")
        tower.level = 3
        local legal = Game.legal(s)
        expect.eq(#legal, 2); expect.truthy(legal[2].broadcast)
        local ev = Game.apply(s, { type = "roll", broadcast = true })
        local roll, bc
        for _, e in ipairs(ev) do
            if e.kind == "roll" then roll = e end
            if e.kind == "broadcast" then bc = e end
        end
        expect.truthy(bc)
        expect.eq(roll.dice[1], roll.dice[2]); expect.eq(roll.dice[1], bc.face)
        expect.eq(s.players[pid].broadcastRound, s.round)
        s.phase = "roll"
        ok, why = Game.check(s, { type = "roll", broadcast = true })
        expect.falsy(ok); expect.truthy(why:find("hồi", 1, true))
        s.round = s.round + Data.BROADCAST_COOLDOWN
        expect.truthy(Game.check(s, { type = "roll", broadcast = true }))
    end)
end)

describe("specials: S-05 Thiên Đình", function()
    local function temple(s, pid, c, level)
        for _, o in ipairs({ { 4, 0 }, { 5, 0 }, { 4, 1 } }) do at(s, c, o[1], o[2]).terrain = "DH-02" end
        return put(s, pid, c, "S-05", level or 1, TRI(4, 0))
    end

    -- Tìm seed sao cho lần đổ kế tiếp ra tổng 7.
    local function rigSeven(s)
        for i = 1, 3000 do
            local tag = "seven" .. i
            local d = Dice.roll(Rng.new(tag))
            if d[1] + d[2] == 7 then s.rng = Rng.new(tag) return end
        end
        error("không tìm được seed ra 7")
    end

    local function toRoll(s, pid)
        s.phase = "roll"
        for i, id in ipairs(s.order) do if id == pid then s.turn = i end end
    end

    it("hủy tổng 7: chủ Thiên Đình được hỏi; hủy thì người đổ +1 TN, Phiến Quân không đi; mỗi ván 1 lần (+1: 2 lần)", function()
        local s, pid, c = setup()
        local owner = pid
        local tem = temple(s, pid, c)
        local roller = 3 - pid
        toRoll(s, roller)
        rigSeven(s)
        s.rebel = { q = -99, r = -99 }
        local faith = s.players[roller].res.faith
        local ev = Game.apply(s, { type = "roll" })
        expect.eq(s.phase, "prompt"); expect.eq(Game.actor(s), owner); expect.eq(s.prompt.kind, "cancel7")
        local ok = Game.check(s, { type = "respond", choice = "cancel" })
        expect.truthy(ok)
        ev = Game.apply(s, { type = "respond", choice = "cancel" })
        expect.eq(ev[1].kind, "seven_cancelled")
        expect.eq(s.phase, "action"); expect.eq(Game.actor(s), roller)
        expect.eq(s.players[roller].res.faith, faith + 1)
        expect.eq(s.players[owner].cancel7Used, 1)
        expect.eq(Specials.cancel7Left(s, owner), 0)

        -- hết lượt hủy: tổng 7 tiếp theo chạy Phiến Quân bình thường
        toRoll(s, roller)
        s.rebel = { q = c.q + 8, r = c.r + 1 }
        rigSeven(s)
        Game.apply(s, { type = "roll" })
        expect.truthy(s.phase == "rebel_move" or s.phase == "prompt" or s.phase == "action")
        expect.falsy(s.prompt and s.prompt.kind == "cancel7")

        tem.level = 2
        expect.eq(Specials.cancel7Left(s, owner), 1, "+1: 2 lần mỗi ván")
    end)

    it("từ chối hủy 7: Phiến Quân hành động như thường", function()
        local s, pid, c = setup()
        temple(s, pid, c)
        toRoll(s, 3 - pid)
        rigSeven(s)
        s.rebel = { q = c.q + 8, r = c.r + 2 }
        Game.apply(s, { type = "roll" })
        expect.eq(s.phase, "prompt")
        Game.apply(s, { type = "respond", choice = "allow" })
        expect.truthy(s.phase == "rebel_move" or s.phase == "action")
        expect.eq(s.players[pid].cancel7Used, nil)
    end)

    it("PQ dừng trong aura: chủ trả 2 TN để đẩy ra ngoài (ngẫu nhiên ở cấp xây, tự chọn ở +1); từ chối thì thôi", function()
        local s, pid, c = setup()
        local tem = temple(s, pid, c)
        local roller = pid                      -- người đổ 7 cũng là người đang lượt
        s.players[pid].res.faith = 10
        local inside = at(s, c, 6, 0)
        local from = at(s, c, 7, 0)
        s.phase = "rebel_move"
        s.rebel = { q = from.q, r = from.r, pending = { stage = "move", points = 1, roller = roller, visited = { [key(from)] = true } } }
        local ev = Game.apply(s, { type = "rebelStep", q = inside.q, r = inside.r })
        expect.eq(s.phase, "prompt"); expect.eq(s.prompt.kind, "pushrebel"); expect.eq(Game.actor(s), pid)
        expect.eq(#s.prompt.options, 2)
        local faith = s.players[pid].res.faith
        ev = Game.apply(s, { type = "respond", choice = "push" })
        expect.eq(ev[1].kind, "rebel_pushed")
        expect.eq(s.players[pid].res.faith, faith - 2)
        expect.falsy(Aura.covers(s, tem, s.rebel), "PQ đã ra ngoài aura")
        expect.eq(s.phase, "action"); expect.eq(Game.actor(s), roller)

        -- cấp +1: tự chọn ô
        tem.level = 2
        s.phase = "rebel_move"
        s.rebel = { q = from.q, r = from.r, pending = { stage = "move", points = 1, roller = roller, visited = { [key(from)] = true } } }
        Game.apply(s, { type = "rebelStep", q = inside.q, r = inside.r })
        expect.eq(s.prompt.options[1], "decline"); expect.truthy(#s.prompt.options > 2)
        local pick = s.prompt.options[2]
        Game.apply(s, { type = "respond", choice = pick })
        expect.eq(key(s.rebel), pick)

        -- từ chối: Phiến Quân ở yên trong aura
        s.phase = "rebel_move"
        s.rebel = { q = from.q, r = from.r, pending = { stage = "move", points = 1, roller = roller, visited = { [key(from)] = true } } }
        Game.apply(s, { type = "rebelStep", q = inside.q, r = inside.r })
        faith = s.players[pid].res.faith
        Game.apply(s, { type = "respond", choice = "decline" })
        expect.eq(s.players[pid].res.faith, faith)
        expect.eq(key(s.rebel), key(inside))
        expect.eq(s.phase, "action")
    end)

    it("không có lời nhắc khi chủ không đủ TN; +2 TN thụ động mỗi vòng", function()
        local s, pid, c = setup()
        temple(s, pid, c)
        s.players[pid].res.faith = 1
        local inside, from = at(s, c, 6, 0), at(s, c, 7, 0)
        s.phase = "rebel_move"
        s.rebel = { q = from.q, r = from.r, pending = { stage = "move", points = 1, roller = 3 - pid, visited = { [key(from)] = true } } }
        Game.apply(s, { type = "rebelStep", q = inside.q, r = inside.r })
        expect.eq(s.phase, "action")
        s.rebel = { q = -99, r = -99 }
        local faith = s.players[pid].res.faith
        Upkeep.startTurn(s, pid)
        expect.eq(s.players[pid].res.faith, faith + 2)
    end)

    it("save/load giữ Đặc Biệt, số lần hủy 7 đã dùng, lời nhắc đang mở", function()
        local s, pid, c = setup()
        temple(s, pid, c)
        s.players[pid].cancel7Used = 1
        local s2 = assert(Game.load(Game.save(s)))
        expect.eq(Structures.at(s2, at(s2, c, 4, 0)).id, "S-05")
        expect.eq(s2.players[pid].cancel7Used, 1)
        expect.eq(Aura.radius(Structures.at(s2, at(s2, c, 4, 0))), 2)
    end)
end)

describe("specials: mô phỏng", function()
    it("chơi ngẫu nhiên nhiều tài nguyên (Nhà Chính C3, đủ vật liệu): bất biến luôn đúng", function()
        local s, pid = setup(14)
        local rt = s.map.list[1]
        s.rebel = { q = rt.q, r = rt.r }
        for p = 1, 2 do s.players[p].hqLevel = 3 end
        for _ = 1, 150 do
            Sim.advance(s, 10, 14)
            for p = 1, 2 do
                for k, v in pairs(s.players[p].res) do if v < 30 and k ~= "bond" then s.players[p].res[k] = 30 end end
            end
            local ok, why = Sim.invariants(s)
            expect.truthy(ok, why)
            if s.phase == "over" then break end
        end
    end)
end)
