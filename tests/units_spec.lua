local C          = require("src.config.constants")
local Game       = require("src.core.game")
local Hex        = require("src.core.hex")
local Rebel      = require("src.core.rebel")
local Rng        = require("src.core.rng")
local Sim        = require("src.core.sim")
local State      = require("src.core.state")
local Territory  = require("src.core.territory")
local Units      = require("src.core.units")
local Upkeep     = require("src.core.upkeep")
local arena      = require("tests.arena")

local key = State.key

local function farRebel(s) s.rebel = { q = -99, r = -99 } end

-- Ô cách `t` đúng `dq, dr` theo toạ độ axial.
local function off(s, t, dq, dr) return s.map:get(t.q + dq, t.r + dr) end

-- Chọn seed cho state.rng sao cho viên d6 đầu tiên thỏa `want(roll)`.
local function rigRoll(s, want)
    for i = 1, 500 do
        local tag = "rig" .. i
        if want(Rng.new(tag):int(1, 6)) then s.rng = Rng.new(tag) return end
    end
    error("không tìm được seed")
end

describe("units: mua và sinh", function()
    it("mua Viễn Chinh ở Nhà Chính: trừ 3 TN + 3 V + 3 KT, không có điểm di chuyển ngay khi sinh", function()
        local s, pid = arena()
        farRebel(s)
        local hq = s.players[pid].hq
        local before = {}
        for k, v in pairs(s.players[pid].res) do before[k] = v end
        local ev = Game.apply(s, { type = "buyUnit", unit = "expedition", q = hq.q, r = hq.r })
        expect.eq(ev[1].kind, "unit_buy")
        for k, n in pairs(C.EXPEDITION_COST) do expect.eq(s.players[pid].res[k], before[k] - n) end
        local u = s.units[ev[1].uid]
        expect.eq(u.owner, pid); expect.eq(u.q, hq.q); expect.eq(u.mp, 0)
        expect.falsy(Game.check(s, { type = "moveUnit", uid = u.uid, q = hq.q + 1, r = hq.r }))
        expect.truthy(Sim.invariants(s))
    end)

    it("từ chối: không phải Nhà Chính/Sub của mình, quota 3, thiếu tiền, bị phong tỏa", function()
        local s, pid, c = arena()
        farRebel(s)
        local hq = s.players[pid].hq
        local ok, why = Game.check(s, { type = "buyUnit", unit = "expedition", q = c.q, r = c.r })
        expect.falsy(ok); expect.eq(why, "Viễn Chinh chỉ sinh ở Nhà Chính, Khu Trực Thuộc hoặc Pháo Đài của bạn")
        for _ = 1, C.MAX_EXPEDITION_PER_PLAYER do
            Game.apply(s, { type = "buyUnit", unit = "expedition", q = hq.q, r = hq.r })
        end
        ok, why = Game.check(s, { type = "buyUnit", unit = "expedition", q = hq.q, r = hq.r })
        expect.falsy(ok); expect.truthy(why:find("giới hạn", 1, true))

        local s2, pid2 = arena()
        local hq2 = s2.players[pid2].hq
        s2.players[pid2].res.faith = 2
        ok, why = Game.check(s2, { type = "buyUnit", unit = "expedition", q = hq2.q, r = hq2.r })
        expect.falsy(ok); expect.eq(why, "Không đủ tài nguyên mua Viễn Chinh")
        s2.players[pid2].res.faith = 99
        s2.rebel = { q = hq2.q, r = hq2.r }
        ok, why = Game.check(s2, { type = "buyUnit", unit = "expedition", q = hq2.q, r = hq2.r })
        expect.falsy(ok); expect.eq(why, "Ô đang bị Phiến Quân phong tỏa")
    end)

    it("legal() có buyUnit khi đủ tiền, và các lệnh của đơn vị đều qua check", function()
        local s, pid = arena()
        farRebel(s)
        local hq = s.players[pid].hq
        Game.apply(s, { type = "buyUnit", unit = "expedition", q = hq.q, r = hq.r })
        local u = Units.ownedBy(s, pid)[1]
        u.mp = 4
        local kinds = {}
        for _, cmd in ipairs(Game.legal(s)) do
            kinds[cmd.type] = (kinds[cmd.type] or 0) + 1
            expect.truthy(Game.check(s, cmd), cmd.type)
        end
        expect.truthy(kinds.buyUnit); expect.truthy(kinds.moveUnit); expect.truthy(kinds.garrison); expect.truthy(kinds.disband)
    end)
end)

describe("units: di chuyển", function()
    it("Đồng Bằng tốn 1/ô; Rừng tốn 2; Núi cấm; không vượt 4 điểm", function()
        local s, pid, c = arena()
        farRebel(s)
        off(s, c, 1, 0).terrain = "DH-02"
        off(s, c, -1, 0).terrain = "DH-03"
        local u = Units.spawn(s, pid, "expedition", c)
        u.mp = 4
        local reach = Units.reachable(s, u)
        expect.eq(reach[key(off(s, c, 0, 1))].cost, 1)
        expect.eq(reach[key(off(s, c, 1, 0))].cost, 2)
        expect.eq(reach[key(off(s, c, -1, 0))], nil, "Núi cấm")
        expect.eq(reach[key(off(s, c, 0, -1))].cost, 1)
        for k, node in pairs(reach) do expect.truthy(node.cost <= 4, k) end
        expect.falsy(reach[key(off(s, c, 5, 0))] and true)
        off(s, c, 1, 0).terrain, off(s, c, -1, 0).terrain = "DH-01", "DH-01"
    end)

    it("moveUnit trừ đúng chi phí đường rẻ nhất, có thể đi nhiều lần tới hết điểm", function()
        local s, pid, c = arena()
        farRebel(s)
        local u = Units.spawn(s, pid, "expedition", c)
        u.mp = 4
        local d2 = off(s, c, 2, 0)
        local path, cost = Units.pathTo(s, u, d2.q, d2.r)
        expect.eq(cost, 2); expect.eq(#path, 2)
        local ev = Game.apply(s, { type = "moveUnit", uid = u.uid, q = d2.q, r = d2.r })
        expect.eq(ev[1].kind, "unit_move"); expect.eq(ev[1].cost, 2); expect.eq(u.mp, 2)
        expect.eq(u.q, d2.q)
        off(s, c, 3, 0).terrain, off(s, c, 4, 0).terrain = "DH-01", "DH-01"
        local d3 = off(s, c, 4, 0)
        Game.apply(s, { type = "moveUnit", uid = u.uid, q = d3.q, r = d3.r })
        expect.eq(u.mp, 0)
        local ok, why = Game.check(s, { type = "moveUnit", uid = u.uid, q = c.q, r = c.r })
        expect.falsy(ok); expect.eq(why, "Hết điểm di chuyển")
    end)

    it("đi xuyên đơn vị khác, không chiếm ô; chỉ điều khiển đơn vị của mình", function()
        local s, pid, c = arena()
        farRebel(s)
        local mine = Units.spawn(s, pid, "expedition", c)
        mine.mp = 4
        Units.spawn(s, 3 - pid, "expedition", off(s, c, 1, 0))
        Units.spawn(s, 3 - pid, "expedition", off(s, c, 2, 0))
        expect.truthy(Game.check(s, { type = "moveUnit", uid = mine.uid, q = c.q + 2, r = c.r }))
        local theirs = Units.ownedBy(s, 3 - pid)[1]
        theirs.mp = 4
        local ok, why = Game.check(s, { type = "moveUnit", uid = theirs.uid, q = c.q + 1, r = c.r + 1 })
        expect.falsy(ok); expect.eq(why, "Không phải đơn vị của bạn")
        expect.eq(#Units.at(s, off(s, c, 2, 0)), 1)
    end)

    it("TN-11 Gió Mạnh giảm 1 điểm khi vào ô; TN-04 Ngựa +2 điểm đầu lượt gần Nhà Chính", function()
        local s, pid, c = arena()
        farRebel(s)
        local u = Units.spawn(s, pid, "expedition", c)
        u.mp = 4
        local t = off(s, c, 1, 0)
        t.strategic = "TN-11"
        expect.eq(Units.stepCost(s, u, t), 0)
        t.strategic = nil
        expect.eq(Units.stepCost(s, u, t), 1)

        local hq = s.map:get(s.players[pid].hq.q, s.players[pid].hq.r)
        local near = s.map:neighbors(hq)[1]
        near.strategic = "TN-04"
        local h = Units.spawn(s, pid, "expedition", near)
        expect.eq(Units.baseMove(s, h), C.EXPEDITION_BASE_MOVE + C.TN04_BONUS_MOVE)
        local far = Units.spawn(s, pid, "expedition", c)
        c.strategic = "TN-04"
        expect.eq(Units.baseMove(s, far), C.EXPEDITION_BASE_MOVE)     -- HQ ở quá xa
        near.strategic, c.strategic = nil, nil
    end)
end)

describe("units: upkeep đầu lượt", function()
    it("reset điểm di chuyển; Vàng duy trì từ đơn vị thứ 2; thiếu Vàng thì hủy đơn vị mới nhất", function()
        local s, pid, c = arena()
        farRebel(s)
        local a = Units.spawn(s, pid, "expedition", c)
        local b = Units.spawn(s, pid, "expedition", off(s, c, 1, 0))
        local d = Units.spawn(s, pid, "expedition", off(s, c, 0, 1))
        a.acted, a.mp = true, 0
        s.players[pid].res.gold = 10
        local ev = Upkeep.startTurn(s, pid)
        local up
        for _, e in ipairs(ev) do if e.kind == "unit_upkeep" then up = e end end
        expect.eq(up.gold, 2 * C.EXPEDITION_UPKEEP_GOLD)
        expect.eq(s.players[pid].res.gold, 8)
        expect.eq(a.mp, C.EXPEDITION_BASE_MOVE); expect.falsy(a.acted)

        s.players[pid].res.gold = 1
        ev = Upkeep.startTurn(s, pid)
        local destroyed = {}
        for _, e in ipairs(ev) do if e.kind == "unit_destroyed" then destroyed[#destroyed + 1] = e end end
        expect.eq(#destroyed, 1)
        expect.eq(destroyed[1].uid, d.uid); expect.eq(destroyed[1].reason, "upkeep")
        expect.eq(s.units[d.uid], nil); expect.truthy(s.units[b.uid])
        expect.eq(s.players[pid].res.gold, 0)
        local lone = Units.ownedBy(s, pid)
        expect.eq(#lone, 2)
        s.players[pid].res.gold = 0
        Upkeep.startTurn(s, pid)   -- 1 V cho đơn vị thứ 2: hết Vàng nên bị hủy
        expect.eq(#Units.ownedBy(s, pid), 1)
    end)

    it("người khác không bị trừ/reset khi tới lượt mình", function()
        local s, pid, c = arena()
        farRebel(s)
        local u = Units.spawn(s, 3 - pid, "expedition", c)
        u.mp = 1
        Upkeep.startTurn(s, pid)
        expect.eq(u.mp, 1)
    end)
end)

describe("units: Lập Sub, Trấn Áp, Trú Đóng, Giải Thể", function()
    it("foundSub từ chối khi ô không hợp lệ hoặc thiếu tiền; hợp lệ thì tiêu thụ đơn vị", function()
        local s, pid, c = arena()
        farRebel(s)
        local u = Units.spawn(s, pid, "expedition", c)
        local ok, why = Game.check(s, { type = "foundSub", uid = u.uid })
        -- vùng arena toàn Đồng Bằng thuộc mình, xa HQ: hợp lệ (trừ khi gần cụm hoặc HQ)
        if ok then
            s.players[pid].res.faith = 0
            ok, why = Game.check(s, { type = "foundSub", uid = u.uid })
            expect.falsy(ok); expect.eq(why, "Không đủ tài nguyên lập Khu Trực Thuộc")
            s.players[pid].res.faith = 99
            Game.apply(s, { type = "foundSub", uid = u.uid })
            expect.eq(s.units[u.uid], nil)
            expect.eq(#s.players[pid].subs, 1)
        end
        local u2 = Units.spawn(s, pid, "expedition", s.map:get(s.players[pid].hq.q, s.players[pid].hq.r))
        ok = Game.check(s, { type = "foundSub", uid = u2.uid })
        expect.falsy(ok, "không lập Sub trên Nhà Chính")
        u2.acted = true
        ok, why = Game.check(s, { type = "foundSub", uid = u.uid + 100 })
        expect.falsy(ok)
    end)

    it("ngưỡng Trấn Áp: 4; Đồi Cỏ −1; vừa Trú Đóng −1; PQ trên Núi +1; sàn 2", function()
        local s, pid, c = arena()
        local u = Units.spawn(s, pid, "expedition", c)
        s.rebel = { q = c.q + 1, r = c.r }
        expect.eq(Units.suppressThreshold(s, u), 4)
        expect.eq(Units.suppressChance(s, u), 0.5)
        c.terrain = "DH-09"
        expect.eq(Units.suppressThreshold(s, u), 3)
        u.recentGarrison = true
        expect.eq(Units.suppressThreshold(s, u), 2)
        off(s, c, 1, 0).terrain = "DH-03"
        expect.eq(Units.suppressThreshold(s, u), 3)
        c.terrain = "DH-01"; off(s, c, 1, 0).terrain = "DH-01"
        u.recentGarrison = false
        off(s, c, 1, 0).terrain = "DH-12"
        expect.eq(Units.suppressThreshold(s, u), 5)
        off(s, c, 1, 0).terrain = "DH-01"
    end)

    it("Trấn Áp trả TN: chắc thắng, đẩy PQ 2 ô, +1 TN, hủy phong tỏa cả vòng", function()
        local s, pid, c = arena()
        local u = Units.spawn(s, pid, "expedition", c)
        s.rebel = { q = c.q + 1, r = c.r }        -- kề đơn vị theo hướng 1 (+1, 0)
        s.players[pid].res.faith = 10
        expect.truthy(Rebel.isBlockaded(s, c))
        local ev = Game.apply(s, { type = "suppress", uid = u.uid, dir = 1, pay = true })
        expect.eq(ev[1].kind, "suppress"); expect.truthy(ev[1].ok); expect.truthy(ev[1].paid)
        expect.eq(s.rebel.q, c.q + 3); expect.eq(s.rebel.r, c.r)
        expect.eq(s.players[pid].res.faith, 10 - C.SUPPRESS_GUARANTEE_FAITH + C.SUPPRESS_REWARD_FAITH)
        expect.truthy(u.acted); expect.truthy(s.units[u.uid], "đơn vị không di chuyển theo")
        s.rebel.q, s.rebel.r = c.q + 1, c.r        -- kể cả khi PQ quay lại gần: vẫn bị hủy phong tỏa trong vòng này
        expect.falsy(Rebel.isBlockaded(s, c))
        expect.eq(#Rebel.blockade(s), 0)
        s.round = s.round + 1
        expect.truthy(Rebel.isBlockaded(s, c))
        expect.falsy(Game.check(s, { type = "suppress", uid = u.uid, dir = 1, pay = true }), "đã hành động")
    end)

    it("Trấn Áp bằng xúc xắc: đạt ngưỡng thì thắng, không thì mất đơn vị và PQ đứng yên", function()
        local s, pid, c = arena()
        local u = Units.spawn(s, pid, "expedition", c)
        s.rebel = { q = c.q + 1, r = c.r }
        rigRoll(s, function(r) return r >= 4 end)
        local ev = Game.apply(s, { type = "suppress", uid = u.uid, dir = 1, pay = false })
        expect.truthy(ev[1].ok); expect.truthy(ev[1].roll >= 4); expect.eq(s.rebel.q, c.q + 3)

        local s2, pid2, c2 = arena()
        local u2 = Units.spawn(s2, pid2, "expedition", c2)
        s2.rebel = { q = c2.q + 1, r = c2.r }
        s2.players[pid2].res.faith = 5
        rigRoll(s2, function(r) return r < 4 end)
        ev = Game.apply(s2, { type = "suppress", uid = u2.uid, dir = 1, pay = false })
        expect.falsy(ev[1].ok)
        expect.eq(ev[2].kind, "unit_destroyed"); expect.eq(ev[2].reason, "suppress")
        expect.eq(s2.units[u2.uid], nil)
        expect.eq(s2.rebel.q, c2.q + 1)
        expect.eq(s2.players[pid2].res.faith, 5)
        expect.falsy(Rebel.isSuppressed(s2))
    end)

    it("Trấn Áp từ chối: không kề PQ, hướng không đi được, thiếu TN để chắc thắng", function()
        local s, pid, c = arena()
        local u = Units.spawn(s, pid, "expedition", c)
        farRebel(s)
        local ok, why = Game.check(s, { type = "suppress", uid = u.uid, dir = 1, pay = false })
        expect.falsy(ok); expect.eq(why, "Đơn vị phải đứng kề Phiến Quân")
        s.rebel = { q = c.q + 1, r = c.r }
        s.players[pid].res.faith = 1
        ok, why = Game.check(s, { type = "suppress", uid = u.uid, dir = 1, pay = true })
        expect.falsy(ok); expect.eq(why, "Không đủ Tín Ngưỡng để chắc thắng")
        off(s, c, 2, 0).terrain = "DH-03"      -- Núi đang khóa chặn ngay ô đầu tiên
        ok, why = Game.check(s, { type = "suppress", uid = u.uid, dir = 1, pay = false })
        expect.falsy(ok); expect.truthy(why:find("Không đẩy", 1, true))
        off(s, c, 3, 0).terrain = "DH-01"
        off(s, c, 2, 0).terrain = "DH-01"
        off(s, c, 3, 0).terrain = "DH-03"      -- chỉ đẩy được 1 ô: vẫn hợp lệ
        expect.truthy(Game.check(s, { type = "suppress", uid = u.uid, dir = 1, pay = false }))
        s.players[pid].res.faith = 5
        local ev = Game.apply(s, { type = "suppress", uid = u.uid, dir = 1, pay = true })
        expect.eq(ev[1].q, c.q + 2)
        off(s, c, 3, 0).terrain = "DH-01"
    end)

    it("Trú Đóng: không làm được khi PQ kề; chặn PQ dừng ở ô kề; hết hiệu lực nhưng hạ ngưỡng lượt sau", function()
        local s, pid, c = arena()
        local u = Units.spawn(s, pid, "expedition", c)
        s.rebel = { q = c.q + 1, r = c.r }
        local ok, why = Game.check(s, { type = "garrison", uid = u.uid })
        expect.falsy(ok); expect.eq(why, "Không thể trú đóng khi Phiến Quân ở kề")
        farRebel(s)
        Game.apply(s, { type = "garrison", uid = u.uid })
        expect.truthy(u.garrison); expect.truthy(u.acted)
        expect.truthy(Rebel.forbiddenStop(s, c))
        expect.truthy(Rebel.forbiddenStop(s, off(s, c, 1, 0)))
        expect.falsy(Rebel.forbiddenStop(s, off(s, c, 2, 0)))
        Upkeep.startTurn(s, pid)
        expect.falsy(u.garrison); expect.truthy(u.recentGarrison)
        s.rebel = { q = c.q + 1, r = c.r }
        expect.eq(Units.suppressThreshold(s, u), 3)
        Upkeep.startTurn(s, pid)
        expect.falsy(u.recentGarrison)
    end)

    it("PQ không bị buộc dừng cạnh đơn vị Trú Đóng khi còn đường khác; hết đường thì vẫn đi", function()
        local s, pid, c = arena()
        local u = Units.spawn(s, pid, "expedition", off(s, c, 2, 0))
        u.garrison = true
        s.rebel = { q = c.q, r = c.r, pending = { stage = "move", points = 1, roller = pid, visited = { [key(c)] = true } } }
        local n1 = off(s, c, 1, 0)
        expect.truthy(Rebel.forbiddenStop(s, n1))
        local steps = Rebel.legalSteps(s)
        expect.eq(#steps, 5)
        for _, t in ipairs(steps) do expect.falsy(t == n1) end
        expect.falsy(Game.check(s, { type = "rebelStep", q = n1.q, r = n1.r }) and s.phase == "rebel_move")

        -- đơn vị Trú Đóng ngay tại ô PQ: mọi ô kề đều cấm -> không loại ô nào (tránh kẹt)
        u.q, u.r = c.q, c.r
        expect.eq(#Rebel.legalSteps(s), 6)
    end)

    it("PQ dừng trên ô có đơn vị thì đơn vị bị tiêu hủy (mọi chủ)", function()
        local s, pid, c = arena()
        local a = Units.spawn(s, pid, "expedition", c)
        local b = Units.spawn(s, 3 - pid, "expedition", c)
        local keep = Units.spawn(s, pid, "expedition", off(s, c, 1, 0))
        s.rebel = { q = c.q, r = c.r, pending = { stage = "move", points = 1, roller = pid } }
        local ev = Rebel.stop(s)
        local gone = 0
        for _, e in ipairs(ev) do if e.kind == "unit_destroyed" then gone = gone + 1; expect.eq(e.reason, "rebel") end end
        expect.eq(gone, 2)
        expect.eq(s.units[a.uid], nil); expect.eq(s.units[b.uid], nil); expect.truthy(s.units[keep.uid])
    end)

    it("Giải Thể hoàn 1 V; không giải thể được đơn vị của người khác", function()
        local s, pid, c = arena()
        farRebel(s)
        local u = Units.spawn(s, pid, "expedition", c)
        local other = Units.spawn(s, 3 - pid, "expedition", c)
        expect.falsy(Game.check(s, { type = "disband", uid = other.uid }))
        local gold = s.players[pid].res.gold
        local ev = Game.apply(s, { type = "disband", uid = u.uid })
        expect.eq(ev[1].refund, 1)
        expect.eq(s.players[pid].res.gold, gold + 1)
        expect.eq(s.units[u.uid], nil)
    end)
end)

describe("units: lưu / nạp và mô phỏng", function()
    it("save/load giữ đơn vị, trạng thái Trú Đóng, suppressedRound và bộ đếm uid", function()
        local s, pid, c = arena(11)
        local u = Units.spawn(s, pid, "expedition", c)
        u.mp, u.garrison, u.recentGarrison = 3, true, true
        s.rebel.suppressedRound = s.round
        local s2 = assert(Game.load(Game.save(s)))
        local u2 = s2.units[u.uid]
        expect.eq(u2.q, c.q); expect.eq(u2.mp, 3); expect.truthy(u2.garrison); expect.truthy(u2.recentGarrison)
        expect.eq(s2.nextUnitUid, s.nextUnitUid)
        expect.eq(s2.rebel.suppressedRound, s.round)
        local n = Units.spawn(s2, pid, "expedition", c)
        expect.truthy(n.uid ~= u.uid)
    end)

    it("chơi ngẫu nhiên có nhiều tài nguyên: đơn vị mua/di chuyển/trấn áp, bất biến luôn đúng", function()
        local s, pid = arena(12)
        local bought, moves, suppress, subs = 0, 0, 0, 0
        local seen = #s.log
        for _ = 1, 120 do
            Sim.advance(s, 10, 12)
            for p = 1, 2 do
                for k, v in pairs(s.players[p].res) do if v < 30 and k ~= "bond" then s.players[p].res[k] = 30 end end
            end
            local ok, why = Sim.invariants(s)
            expect.truthy(ok, why)
            for i = seen + 1, #s.log do
                local k = s.log[i].kind
                if k == "unit_buy" then bought = bought + 1
                elseif k == "unit_move" then moves = moves + 1
                elseif k == "suppress" then suppress = suppress + 1
                elseif k == "found_sub" then subs = subs + 1 end
            end
            seen = #s.log
            if s.phase == "over" then break end
        end
        expect.truthy(bought > 0 and moves > 0, "phải có mua và di chuyển")
    end)
end)
