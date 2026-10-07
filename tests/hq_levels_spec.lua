local C            = require("src.config.constants")
local Game         = require("src.core.game")
local Hex          = require("src.core.hex")
local Production   = require("src.core.production")
local Rebel        = require("src.core.rebel")
local Roads        = require("src.core.roads")
local Rng          = require("src.core.rng")
local Sim          = require("src.core.sim")
local State        = require("src.core.state")
local Structures   = require("src.core.structures")
local Territory    = require("src.core.territory")
local Units        = require("src.core.units")
local Upkeep       = require("src.core.upkeep")
local arena        = require("tests.arena")

local key = State.key

local function farRebel(s) s.rebel = { q = -99, r = -99 } end
local function off(s, t, dq, dr) return s.map:get(t.q + dq, t.r + dr) end
local function hqTile(s, pid) return s.map:get(s.players[pid].hq.q, s.players[pid].hq.r) end

-- Cho người chơi `pid` một Khu Chợ liền Nhà Chính (ô kề HQ thuộc mình).
local function marketNextToHQ(s, pid, level)
    local near = s.map:neighbors(hqTile(s, pid))[1]
    s.owner[key(near)] = pid
    s.votes[key(near)] = { [pid] = 9 }
    near.terrain = "DH-01"
    return Structures.place(s, { id = "B-05", level = level or 1, owner = pid }, { near }), near
end

describe("HQ C3-C5: điều kiện, chi phí, hiệu ứng", function()
    it("C3 cần một Khu Chợ liền hoặc nối đường tới Nhà Chính, và 2 Hợp Kim", function()
        local s, pid = arena()
        farRebel(s)
        local p = s.players[pid]
        p.hqLevel = 2
        local ok, why = Territory.canUpgradeHQ(s, pid)
        expect.falsy(ok); expect.eq(why, "Cần một Khu Chợ liền hoặc nối đường tới Nhà Chính")
        marketNextToHQ(s, pid)
        expect.truthy(Territory.canUpgradeHQ(s, pid))
        p.res.alloy = 1
        expect.falsy(Game.check(s, { type = "upgradeHQ" }))
        p.res.alloy = 5
        local before = {}
        for k, v in pairs(p.res) do before[k] = v end
        local ev = Game.apply(s, { type = "upgradeHQ" })
        expect.eq(ev[1].kind, "upgrade_hq"); expect.eq(ev[1].level, 3); expect.eq(p.hqLevel, 3)
        for k, n in pairs(C.HQ_UPGRADE_COST[3]) do expect.eq(p.res[k], before[k] - n, k) end
    end)

    it("Khu Chợ ở xa chỉ tính khi có đường nối tới Nhà Chính; Khu Chợ chờ dỡ không tính", function()
        local s, pid, c = arena()
        farRebel(s)
        local p = s.players[pid]
        p.hqLevel = 2
        local m = Structures.place(s, { id = "B-05", level = 1, owner = pid }, { c })
        expect.falsy(Territory.canUpgradeHQ(s, pid))
        for _, h in ipairs(Hex.line(hqTile(s, pid), c)) do
            local t = s.map:get(h.q, h.r)
            if t and not (t.q == p.hq.q and t.r == p.hq.r) and not (t.q == c.q and t.r == c.r) then Roads.build(s, t) end
        end
        expect.truthy(Territory.canUpgradeHQ(s, pid))
        m.demolishing = true
        expect.falsy(Territory.canUpgradeHQ(s, pid))
    end)

    it("C4 từ vòng 11; C5 cần Khu Chợ C3; tối đa C5; bán kính ảnh hưởng không tăng sau C2", function()
        local s, pid = arena()
        farRebel(s)
        local p = s.players[pid]
        p.hqLevel = 3
        s.round = C.HQ_C4_MIN_ROUND - 1
        local ok, why = Territory.canUpgradeHQ(s, pid)
        expect.falsy(ok); expect.eq(why, "Chỉ nâng lên C4 từ vòng " .. C.HQ_C4_MIN_ROUND)
        s.round = C.HQ_C4_MIN_ROUND
        expect.truthy(Territory.canUpgradeHQ(s, pid))
        p.hqLevel = 4
        ok, why = Territory.canUpgradeHQ(s, pid)
        expect.falsy(ok); expect.eq(why, "Cần sở hữu một Khu Chợ cấp 3")
        local m = marketNextToHQ(s, pid, 2)
        expect.falsy(Territory.canUpgradeHQ(s, pid))
        m.level = 3
        expect.truthy(Territory.canUpgradeHQ(s, pid))
        p.hqLevel = 5
        ok, why = Territory.canUpgradeHQ(s, pid)
        expect.falsy(ok); expect.eq(why, "Nhà Chính đã ở cấp tối đa")
        local anchors = Territory.anchors(s, pid)
        expect.eq(anchors[1].radius, 2)
    end)

    it("HQ C4: mọi Viễn Chinh thành Hiệp Sĩ ngay lúc nâng cấp, giữ điểm di chuyển; Giao Thương không đổi", function()
        local s, pid, c = arena()
        farRebel(s)
        local p = s.players[pid]
        p.hqLevel = 3
        s.round = C.HQ_C4_MIN_ROUND
        local a = Units.spawn(s, pid, "expedition", c)
        a.mp = 3
        local t = Units.spawn(s, pid, "trade", c)
        local enemy = Units.spawn(s, 3 - pid, "expedition", c)
        p.res.steel, p.res.engineering, p.res.gold = 9, 20, 20
        local ev = Game.apply(s, { type = "upgradeHQ" })
        local transforms = 0
        for _, e in ipairs(ev) do if e.kind == "unit_transform" then transforms = transforms + 1 end end
        expect.eq(transforms, 1)
        expect.eq(a.type, "knight"); expect.eq(a.mp, 3)
        expect.eq(t.type, "trade"); expect.eq(enemy.type, "expedition")
        expect.eq(Units.baseMove(s, a), C.KNIGHT_BASE_MOVE)
        expect.eq(Units.quotaCount(s, pid, "expedition"), 1, "Hiệp Sĩ dùng chung quota")
        expect.truthy(Sim.invariants(s))
    end)

    it("Viễn Chinh mua sau HQ C4 cũng thành Hiệp Sĩ ở đầu lượt kế tiếp", function()
        local s, pid = arena()
        farRebel(s)
        s.players[pid].hqLevel = 4
        local hq = s.players[pid].hq
        local ev = Game.apply(s, { type = "buyUnit", unit = "expedition", q = hq.q, r = hq.r })
        local u = s.units[ev[1].uid]
        expect.eq(u.type, "expedition")
        local up = Upkeep.startTurn(s, pid)
        expect.eq(u.type, "knight")
        expect.eq(up[1].kind, "unit_transform")
        expect.eq(u.mp, C.KNIGHT_BASE_MOVE)
    end)

    it("Hiệp Sĩ leo được Núi (tốn 2), Viễn Chinh thì không; ngưỡng Trấn Áp 3", function()
        local s, pid, c = arena()
        farRebel(s)
        local mountain = off(s, c, 1, 0)
        mountain.terrain = "DH-03"
        local e = Units.spawn(s, pid, "expedition", c)
        local k = Units.spawn(s, pid, "knight", c)
        expect.eq(Units.stepCost(s, e, mountain), math.huge)
        expect.eq(Units.stepCost(s, k, mountain), 2)
        s.rebel = { q = c.q, r = c.r + 1 }
        expect.eq(Units.suppressThreshold(s, e), C.SUPPRESS_THRESHOLD_EXPEDITION)
        expect.eq(Units.suppressThreshold(s, k), C.SUPPRESS_THRESHOLD_KNIGHT)
        mountain.terrain = "DH-01"
    end)

    it("Hiệp Sĩ thua Trấn Áp thì rút về HQ (1 lần mỗi 5 vòng), lần sau mới mất", function()
        local s, pid, c = arena()
        local p = s.players[pid]
        local function rig(want)
            for i = 1, 500 do
                if want(Rng.new("k" .. i):int(1, 6)) then s.rng = Rng.new("k" .. i) return end
            end
        end
        local k = Units.spawn(s, pid, "knight", c)
        s.rebel = { q = c.q + 1, r = c.r }
        rig(function(r) return r < C.SUPPRESS_THRESHOLD_KNIGHT end)
        local ev = Game.apply(s, { type = "suppress", uid = k.uid, dir = 1, pay = false })
        expect.falsy(ev[1].ok)
        expect.eq(ev[2].kind, "unit_retreat")
        expect.truthy(s.units[k.uid], "Hiệp Sĩ còn sống")
        expect.eq(k.q, p.hq.q); expect.eq(k.r, p.hq.r)
        expect.eq(p.knightRetreatRound, s.round)

        -- lượt sau cùng vòng: hết lần rút, thua là mất
        k.q, k.r, k.acted = c.q, c.r, false
        s.rebel = { q = c.q + 1, r = c.r }
        rig(function(r) return r < C.SUPPRESS_THRESHOLD_KNIGHT end)
        ev = Game.apply(s, { type = "suppress", uid = k.uid, dir = 1, pay = false })
        expect.eq(ev[2].kind, "unit_destroyed")
        expect.eq(s.units[k.uid], nil)

        -- sau 5 vòng được rút lại
        local k2 = Units.spawn(s, pid, "knight", c)
        s.round = s.round + C.KNIGHT_RETREAT_COOLDOWN
        s.rebel = { q = c.q + 1, r = c.r }
        rig(function(r) return r < C.SUPPRESS_THRESHOLD_KNIGHT end)
        ev = Game.apply(s, { type = "suppress", uid = k2.uid, dir = 1, pay = false })
        expect.eq(ev[2].kind, "unit_retreat")
    end)

    it("HQ C5: +1 sản lượng mỗi viên cho công trình trong bán kính 2 quanh Nhà Chính, không xa hơn", function()
        local s, pid = arena()
        farRebel(s)
        local p = s.players[pid]
        local hq = hqTile(s, pid)
        local near, mid, far            -- cách HQ 1, 2, 3 theo một hướng còn nằm trong bản đồ
        for _, d in ipairs(Hex.DIRECTIONS) do
            near, mid, far = off(s, hq, d.q, d.r), off(s, hq, 2 * d.q, 2 * d.r), off(s, hq, 3 * d.q, 3 * d.r)
            if near and mid and far then break end
        end
        expect.truthy(near and mid and far)
        for _, t in ipairs({ near, mid, far }) do
            t.terrain, t.settlement, t.landmark, t.strategic = "DH-01", nil, nil, nil
            s.owner[key(t)] = pid
            Structures.place(s, { id = "B-01", level = 1, owner = pid }, { t })
        end
        local function eng(level)
            p.hqLevel = level
            local per = {}
            for _, e in ipairs(Production.compute(s, { 3, 5 }, pid)) do
                if e.kind == "produce" and e.res == "engineering" then per[e.key] = e.amount end
            end
            return per
        end
        local base = eng(4)
        expect.eq(base[key(near)], 1); expect.eq(base[key(mid)], 1); expect.eq(base[key(far)], 1)
        local boosted = eng(5)
        expect.eq(boosted[key(near)], 2); expect.eq(boosted[key(mid)], 2); expect.eq(boosted[key(far)], 1)
    end)

    it("aura HQ C5 chỉ cho chủ Nhà Chính, không cho công trình của đối thủ trong bán kính", function()
        local s, pid = arena()
        farRebel(s)
        local hq = hqTile(s, pid)
        local t = off(s, hq, 1, 0)
        t.terrain, t.settlement, t.landmark, t.strategic = "DH-01", nil, nil, nil
        s.players[pid].hqLevel = 5
        Structures.place(s, { id = "B-01", level = 1, owner = 3 - pid }, { t })
        local n = 0
        for _, e in ipairs(Production.compute(s, { 3, 5 }, pid)) do
            if e.kind == "produce" and e.res == "engineering" then n = n + e.amount end
        end
        expect.eq(n, 1)
    end)
end)

describe("Khu Trực Thuộc C2-C3", function()
    local function withSub(round)
        local s, pid, c = arena()
        farRebel(s)
        local p = s.players[pid]
        p.subs[#p.subs + 1] = { q = c.q, r = c.r, level = 1 }
        s.round = round or 1
        for k in pairs(p.res) do p.res[k] = (k == "bond") and 0 or 20 end
        return s, pid, c, p
    end

    it("C2: 4 KT + 3 V, mở bán kính 2", function()
        local s, pid, c, p = withSub()
        expect.eq(Territory.anchors(s, pid)[2].radius, 1)
        local before = {}
        for k, v in pairs(p.res) do before[k] = v end
        local ev = Game.apply(s, { type = "upgradeSub", q = c.q, r = c.r })
        expect.eq(ev[1].kind, "upgrade_sub"); expect.eq(ev[1].level, 2)
        for k, n in pairs(C.SUB_UPGRADE_COST[2]) do expect.eq(p.res[k], before[k] - n) end
        expect.eq(Territory.subAt(s, pid, c).level, 2)
        expect.eq(Territory.anchors(s, pid)[2].radius, 2)
        expect.truthy(Territory.inInfluence(s, pid, off(s, c, 2, 0)))
    end)

    it("C3 từ vòng 16, cần 2 Thép; tối đa C3; không nâng Sub của người khác hay ô không có Sub", function()
        local s, pid, c, p = withSub(10)
        Game.apply(s, { type = "upgradeSub", q = c.q, r = c.r })
        local ok, why = Game.check(s, { type = "upgradeSub", q = c.q, r = c.r })
        expect.falsy(ok); expect.eq(why, "Chỉ nâng lên C3 từ vòng " .. C.SUB_C3_MIN_ROUND)
        s.round = C.SUB_C3_MIN_ROUND
        p.res.steel = 1
        ok, why = Game.check(s, { type = "upgradeSub", q = c.q, r = c.r })
        expect.falsy(ok); expect.eq(why, "Không đủ tài nguyên nâng cấp")
        p.res.steel = 5
        Game.apply(s, { type = "upgradeSub", q = c.q, r = c.r })
        expect.eq(Territory.subAt(s, pid, c).level, 3)
        ok, why = Game.check(s, { type = "upgradeSub", q = c.q, r = c.r })
        expect.falsy(ok); expect.eq(why, "Khu Trực Thuộc đã ở cấp tối đa")
        ok, why = Game.check(s, { type = "upgradeSub", q = c.q + 1, r = c.r })
        expect.falsy(ok); expect.eq(why, "Không có Khu Trực Thuộc của bạn ở ô này")
        local other = 3 - pid
        s.players[other].subs[1] = { q = c.q + 2, r = c.r, level = 1 }
        ok = Game.check(s, { type = "upgradeSub", q = c.q + 2, r = c.r })
        expect.falsy(ok)
    end)

    it("legal() liệt kê upgradeSub khi đủ điều kiện; Sub C3: ô tâm miễn phong tỏa, ô kề vẫn bị", function()
        local s, pid, c, p = withSub(C.SUB_C3_MIN_ROUND)
        local found = false
        for _, cmd in ipairs(Game.legal(s)) do
            if cmd.type == "upgradeSub" then found = true; expect.truthy(Game.check(s, cmd)) end
        end
        expect.truthy(found)
        s.rebel = { q = c.q, r = c.r }
        expect.truthy(Rebel.isBlockaded(s, c))
        p.subs[1].level = 3
        expect.falsy(Rebel.isBlockaded(s, c))
        expect.truthy(Rebel.isBlockaded(s, off(s, c, 1, 0)))
        expect.eq(#Rebel.blockade(s), 6)
        -- công trình đặt ngay ô tâm Sub không có (ô tâm là Sub), nhưng ô kề vẫn mất sản xuất
        s.rebel = nil
        farRebel(s)
    end)

    it("chơi ngẫu nhiên nhiều tài nguyên (cả vật liệu): nâng HQ/Sub, bất biến luôn đúng", function()
        local s = arena(15)
        local ups = 0
        local seen = #s.log
        for _ = 1, 150 do
            Sim.advance(s, 10, 15)
            for p = 1, 2 do
                for k, v in pairs(s.players[p].res) do if v < 30 and k ~= "bond" then s.players[p].res[k] = 30 end end
            end
            local ok, why = Sim.invariants(s)
            expect.truthy(ok, why)
            for i = seen + 1, #s.log do
                local k = s.log[i].kind
                if k == "upgrade_hq" or k == "upgrade_sub" then ups = ups + 1 end
            end
            seen = #s.log
            if s.phase == "over" then break end
        end
        expect.truthy(ups > 0, "phải có nâng cấp HQ hoặc Sub")
    end)
end)
