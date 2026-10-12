local C            = require("src.config.constants")
local Construction = require("src.core.construction")
local Game         = require("src.core.game")
local Hex          = require("src.core.hex")
local Passives     = require("src.core.passives")
local Rebel        = require("src.core.rebel")
local Roads        = require("src.core.roads")
local Sim          = require("src.core.sim")
local State        = require("src.core.state")
local Structures   = require("src.core.structures")
local Trade        = require("src.core.trade")
local Units        = require("src.core.units")
local Upkeep       = require("src.core.upkeep")
local arena        = require("tests.arena")
local reload       = require("tests.reload")

local key = State.key

local function farRebel(s) s.rebel = { q = -99, r = -99 } end
local function off(s, t, dq, dr) return s.map:get(t.q + dq, t.r + dr) end

-- Hai Khu Chợ C1: của `pid` ở c, của đối thủ ở c + (dq, dr). Trả ô của đối thủ.
local function twoMarkets(s, pid, c, dq, dr)
    local other = 3 - pid
    local oc = off(s, c, dq, dr)
    s.owner[key(oc)] = other
    s.votes[key(oc)] = { [other] = 9 }
    Structures.place(s, { id = "B-05", level = 1, owner = pid }, { c })
    Structures.place(s, { id = "B-05", level = 1, owner = other }, { oc })
    return oc, other
end

describe("roads: Đơn vị Giao Thương và đường", function()
    it("mua Giao Thương: 5 V, quota 2, chưa có chợ thì sinh ở Nhà Chính và đi ngay với 5 bước", function()
        local s, pid = arena()
        farRebel(s)
        local hq = s.players[pid].hq
        local gold = s.players[pid].res.gold
        local ev = Game.apply(s, { type = "buyUnit", unit = "trade", q = hq.q, r = hq.r })
        local u = s.units[ev[1].uid]
        expect.eq(u.type, "trade"); expect.eq(u.mp, C.TRADE_BASE_MOVE)
        expect.eq(s.players[pid].res.gold, gold - 5)
        Game.apply(s, { type = "buyUnit", unit = "trade", q = hq.q, r = hq.r })
        local ok, why = Game.check(s, { type = "buyUnit", unit = "trade", q = hq.q, r = hq.r })
        expect.falsy(ok); expect.truthy(why:find("giới hạn", 1, true))
        expect.eq(Units.quotaCount(s, pid, "trade"), 2)
        expect.eq(Units.quotaCount(s, pid, "expedition"), 0, "quota riêng với Viễn Chinh")
    end)

    it("đã có Khu Chợ thì Giao Thương sinh ở chợ, không phải Nhà Chính", function()
        local s, pid, c = arena()
        farRebel(s)
        local hq = s.players[pid].hq
        Structures.place(s, { id = "B-05", level = 1, owner = pid }, { c })
        local ok, why = Game.check(s, { type = "buyUnit", unit = "trade", q = hq.q, r = hq.r })
        expect.falsy(ok); expect.eq(why, "Giao Thương sinh ở Khu Chợ của bạn (chưa có chợ thì ở Nhà Chính)")
        expect.truthy(Game.check(s, { type = "buyUnit", unit = "trade", q = c.q, r = c.r }))
    end)

    it("đi tới đâu tự xây Đường Đất tới đó (1 V/ô); ô không cho đường thì không xây", function()
        local s, pid, c = arena()
        farRebel(s)
        local u = Units.spawn(s, pid, "trade", c)
        off(s, c, 1, 0).terrain = "DH-07"            -- Sa Mạc: đi được nhưng không xây đường
        local gold = s.players[pid].res.gold
        local dest = off(s, c, 0, 2)                 -- hai bước thẳng, đều Đồng Bằng
        local ev = Game.apply(s, { type = "moveUnit", uid = u.uid, q = dest.q, r = dest.r })
        expect.eq(ev[1].roads, 2); expect.eq(ev[1].gold, 2)
        expect.eq(s.players[pid].res.gold, gold - 2)
        expect.truthy(Roads.has(s, off(s, c, 0, 1))); expect.truthy(Roads.has(s, dest))
        expect.falsy(Roads.has(s, c), "ô xuất phát không tạo đường")
        expect.eq(Roads.get(s, dest).level, 1)
        off(s, c, 1, 0).terrain = "DH-01"
        local u2 = Units.spawn(s, pid, "trade", c)
        local desert = off(s, c, 1, 0)
        desert.terrain = "DH-07"
        Game.apply(s, { type = "moveUnit", uid = u2.uid, q = desert.q, r = desert.r })
        expect.falsy(Roads.has(s, desert))
        desert.terrain = "DH-01"
    end)

    it("thiếu Vàng thì không đi được; TN-10 Cảng miễn phí đường; Viễn Chinh không xây đường", function()
        local s, pid, c = arena()
        farRebel(s)
        local u = Units.spawn(s, pid, "trade", c)
        s.players[pid].res.gold = 1
        local d2 = off(s, c, 2, 0)
        local ok, why = Game.check(s, { type = "moveUnit", uid = u.uid, q = d2.q, r = d2.r })
        expect.falsy(ok); expect.eq(why, "Không đủ Vàng xây đường (cần 2 V)")
        off(s, c, 1, 0).strategic = "TN-10"
        expect.truthy(Game.check(s, { type = "moveUnit", uid = u.uid, q = d2.q, r = d2.r }))
        Game.apply(s, { type = "moveUnit", uid = u.uid, q = d2.q, r = d2.r })
        expect.eq(s.players[pid].res.gold, 0)               -- chỉ trả 1 V cho ô thường
        expect.truthy(Roads.has(s, off(s, c, 1, 0)))
        off(s, c, 1, 0).strategic = nil

        local e = Units.spawn(s, pid, "expedition", c)
        e.mp = 4
        s.players[pid].res.gold = 9
        Game.apply(s, { type = "moveUnit", uid = e.uid, q = c.q, r = c.r + 2 })
        expect.eq(s.players[pid].res.gold, 9)
        expect.falsy(Roads.has(s, off(s, c, 0, 2)))
    end)

    it("đường giảm 1 điểm vào ô (tối thiểu 1): Rừng có đường tốn 1; Lát Đá +1 bước đầu lượt", function()
        local s, pid, c = arena()
        farRebel(s)
        local forest = off(s, c, 1, 0)
        forest.terrain = "DH-02"
        local u = Units.spawn(s, pid, "expedition", c)
        expect.eq(Units.stepCost(s, u, forest), 2)
        Roads.build(s, forest)
        expect.eq(Units.stepCost(s, u, forest), 1)
        expect.eq(Units.stepCost(s, u, off(s, c, 0, 1)), 1)
        local plains = off(s, c, 0, 1)
        Roads.build(s, plains)
        expect.eq(Units.stepCost(s, u, plains), 1, "tối thiểu 1")
        u.q, u.r = plains.q, plains.r
        expect.eq(Units.baseMove(s, u), C.EXPEDITION_BASE_MOVE)
        s.roads[key(plains)].level = 2
        expect.eq(Units.baseMove(s, u), C.EXPEDITION_BASE_MOVE + C.STONE_ROAD_START_BONUS)
        forest.terrain = "DH-01"
    end)

    it("TN-10 +3 bước đầu lượt cho Giao Thương đứng trên ô Cảng", function()
        local s, pid, c = arena()
        c.strategic = "TN-10"
        local u = Units.spawn(s, pid, "trade", c)
        expect.eq(Units.baseMove(s, u), C.TRADE_BASE_MOVE + C.TN10_BONUS_MOVE)
        c.strategic = nil
    end)
end)

describe("roads: nâng Lát Đá và Phiến Quân", function()
    it("upgradeRoad: trả 1 KT + 1 V; chỉ trong lãnh thổ/vùng ảnh hưởng; không nâng hai lần", function()
        local s, pid, c = arena()
        farRebel(s)
        Roads.build(s, c)
        local res = s.players[pid].res
        local kt, v = res.engineering, res.gold
        local ev = Game.apply(s, { type = "upgradeRoad", q = c.q, r = c.r })
        expect.eq(ev[1].kind, "road_upgrade")
        expect.eq(res.engineering, kt - 1); expect.eq(res.gold, v - 1)
        expect.eq(Roads.get(s, c).level, 2)
        local ok, why = Game.check(s, { type = "upgradeRoad", q = c.q, r = c.r })
        expect.falsy(ok); expect.eq(why, "Đường đã là Lát Đá")
        local far = s.map.list[1]
        Roads.build(s, far)
        ok, why = Game.check(s, { type = "upgradeRoad", q = far.q, r = far.r })
        expect.falsy(ok); expect.eq(why, "Chỉ nâng đường trong lãnh thổ hoặc vùng ảnh hưởng của bạn")
        ok, why = Game.check(s, { type = "upgradeRoad", q = c.q + 1, r = c.r })
        expect.falsy(ok); expect.eq(why, "Ô này chưa có đường")
        res.engineering = 0
        Roads.build(s, off(s, c, 1, 0))
        ok, why = Game.check(s, { type = "upgradeRoad", q = c.q + 1, r = c.r })
        expect.falsy(ok); expect.eq(why, "Không đủ tài nguyên nâng đường")
    end)

    it("PQ đi qua: Đường Đất mất, Lát Đá còn; PQ dừng: Lát Đá tụt về Đất, Đường Đất mất", function()
        local s, pid, c = arena()
        local a, b, d = off(s, c, 0, 1), off(s, c, 1, 0), off(s, c, 2, 0)
        Roads.build(s, a); Roads.build(s, b); Roads.build(s, d)
        s.roads[key(b)].level = 2
        s.rebel = { q = c.q, r = c.r, pending = { stage = "move", points = 3, roller = pid, visited = { [key(c)] = true } } }
        local ev = Rebel.step(s, a.q, a.r)          -- đi qua Đường Đất
        expect.falsy(Roads.has(s, a))
        expect.eq(ev[2].kind, "road_damaged"); expect.truthy(ev[2].lost)
        -- đi qua Lát Đá: miễn nhiễm
        s.rebel = { q = c.q, r = c.r, pending = { stage = "move", points = 3, roller = pid, visited = { [key(c)] = true } } }
        Rebel.step(s, b.q, b.r)
        expect.eq(Roads.get(s, b).level, 2)
        -- dừng trên Lát Đá: tụt về Đất
        s.rebel = { q = b.q, r = b.r, pending = { stage = "move", points = 1, roller = pid, visited = { [key(b)] = true } } }
        Rebel.step(s, d.q, d.r)                    -- đi vào d (Đường Đất) và dừng vì hết điểm
        expect.falsy(Roads.has(s, d), "dừng trên Đường Đất: mất")
        s.rebel = { q = b.q, r = b.r, pending = { stage = "move", points = 1, roller = pid } }
        local rb = Rebel.stop(s)
        expect.eq(Roads.get(s, b).level, 1)
        expect.eq(rb[2].kind, "road_damaged"); expect.falsy(rb[2].lost)
    end)
end)

describe("roads: tuyến nối và Khu Chợ", function()
    it("Roads.route: kề nhau dài 0; qua chuỗi đường dài đúng số ô; cờ Lát Đá/Cảng; không đường thì nil", function()
        local s, pid, c = arena()
        local A, B = { c }, { off(s, c, 3, 0) }
        expect.eq(Roads.route(s, A, B), nil)
        expect.eq(Roads.route(s, A, { off(s, c, 1, 0) }).length, 0)
        Roads.build(s, off(s, c, 1, 0)); Roads.build(s, off(s, c, 2, 0))
        local r = Roads.route(s, A, B)
        expect.eq(r.length, 2); expect.falsy(r.stone); expect.falsy(r.harbor)
        s.roads[key(off(s, c, 1, 0))].level, s.roads[key(off(s, c, 2, 0))].level = 2, 2
        expect.truthy(Roads.route(s, A, B).stone)
        off(s, c, 2, 0).strategic = "TN-10"
        expect.truthy(Roads.route(s, A, B).harbor)
        s.lostStrategic[key(off(s, c, 2, 0))] = true
        expect.falsy(Roads.route(s, A, B).harbor)
        off(s, c, 2, 0).strategic = nil
    end)

    it("Khu Chợ C1 phải liền Nhà Chính, nối đường tới Nhà Chính, hoặc có ô Cá (TN-03)", function()
        local s, pid, c = arena()
        farRebel(s)
        local hq = s.map:get(s.players[pid].hq.q, s.players[pid].hq.r)
        local ok, why = Game.buildCheck(s, pid, "B-05", c)
        expect.falsy(ok); expect.eq(why, "Khu Chợ phải liền Nhà Chính hoặc nối đường tới Nhà Chính (trừ ô có Cá)")
        c.strategic = "TN-03"
        expect.truthy(Game.buildCheck(s, pid, "B-05", c))
        c.strategic = nil
        -- nối đường từ HQ tới sát ô c
        for _, h in ipairs(Hex.line(hq, c)) do
            local t = s.map:get(h.q, h.r)
            if t and not (t.q == hq.q and t.r == hq.r) and not (t.q == c.q and t.r == c.r) then Roads.build(s, t) end
        end
        expect.truthy(Game.buildCheck(s, pid, "B-05", c))
        -- liền Nhà Chính
        local near = s.map:neighbors(hq)[1]
        s.owner[key(near)] = pid
        expect.truthy(Game.buildCheck(s, pid, "B-05", near))
        -- chợ khác loại không bị ràng buộc
        c.strategic = nil
        for _, h in ipairs(Hex.line(hq, c)) do
            local t = s.map:get(h.q, h.r)
            if t then s.roads[key(t)] = nil end
        end
        expect.truthy(Game.buildCheck(s, pid, "B-01", c))
    end)

    it("nâng Khu Chợ C1 -> C2 cũng kiểm tra đường; C2 -> C3 thì không", function()
        local s, pid, c = arena()
        farRebel(s)
        local m = Structures.place(s, { id = "B-05", level = 1, owner = pid }, { c })
        local opts = Construction.upgradeOptions(s, m.uid)
        expect.eq(#opts, 0, "xa Nhà Chính và chưa có đường")
        c.strategic = "TN-03"
        opts = Construction.upgradeOptions(s, m.uid)
        expect.truthy(#opts > 0)
        c.strategic = nil
        m.level = 2
        for _, t in ipairs({ off(s, c, 1, 0), off(s, c, 0, 1) }) do t.terrain = "DH-01" end
        expect.truthy(#Construction.upgradeOptions(s, m.uid) > 0, "C3 không cần đường")
    end)

    it("Khu Chợ C2: +0.5 V mỗi tuyến đường kề (tối đa 3)", function()
        local s, pid, c = arena()
        farRebel(s)
        Structures.place(s, { id = "B-05", level = 2, owner = pid }, { c, off(s, c, 1, 0) })
        local function gold()
            local n = 0
            for _, g in ipairs(Passives.compute(s, pid)) do if g.res == "gold" then n = n + g.amount end end
            return n
        end
        expect.eq(gold(), 0)
        Roads.build(s, off(s, c, 0, 1))
        expect.eq(gold(), 0.5)
        for _, d in ipairs({ { -1, 0 }, { 0, -1 }, { 1, -1 }, { 2, -1 } }) do Roads.build(s, off(s, c, d[1], d[2])) end
        expect.eq(gold(), 1.5, "giới hạn 3 tuyến")
    end)
end)

describe("trade: giữa người chơi", function()
    local function setup()
        local s, pid, c = arena()
        farRebel(s)
        local oc, other = twoMarkets(s, pid, c, 2, 0)
        Roads.build(s, off(s, c, 1, 0))
        for k in pairs(s.players[other].res) do s.players[other].res[k] = (k == "bond") and 0 or 20 end
        return s, pid, other, c, oc
    end

    it("phí 1 V/ô đường; Lát Đá toàn tuyến giảm nửa (làm tròn lên); Cảng miễn phí; kề nhau miễn phí", function()
        local s, pid, other, c = setup()
        expect.eq(Trade.route(s, pid, other).fee, 1)
        expect.eq(Trade.fee(3, false, false), 3)
        expect.eq(Trade.fee(3, true, false), 2)
        expect.eq(Trade.fee(4, true, false), 2)
        expect.eq(Trade.fee(5, false, true), 0)
        expect.eq(Trade.fee(0, false, false), 0)
        s.roads[key(off(s, c, 1, 0))].level = 2
        expect.eq(Trade.route(s, pid, other).fee, 1)
        off(s, c, 1, 0).strategic = "TN-10"
        expect.eq(Trade.route(s, pid, other).fee, 0)
        off(s, c, 1, 0).strategic = nil
        s.roads = {}
        expect.eq(Trade.route(s, pid, other), nil)
    end)

    it("Khu Chợ C3 trong bán kính 2 coi như đã nối, không cần đường", function()
        local s, pid, other, c = setup()
        s.roads = {}
        local mine = Structures.at(s, c)
        mine.level = 3
        local r = Trade.route(s, pid, other)
        expect.truthy(r); expect.eq(r.length, 1); expect.eq(r.fee, 1)
        mine.level = 1
        expect.eq(Trade.route(s, pid, other), nil)
    end)

    it("Khu Chợ bị Phiến Quân phong tỏa thì không có tuyến", function()
        local s, pid, other, c = setup()
        s.rebel = { q = c.q, r = c.r }
        expect.eq(Trade.route(s, pid, other), nil)
        local ok, why = Trade.check(s, pid, other, { gold = 1 }, { science = 1 })
        expect.falsy(ok); expect.eq(why, "Hai Khu Chợ chưa được nối bằng đường (hoặc đang bị phong tỏa)")
    end)

    it("từ chối: cho không, cùng loại, thiếu tài nguyên, chưa có chợ, thiếu Vàng trả phí", function()
        local s, pid, other = setup()
        local ok, why = Trade.check(s, pid, other, { science = 1 }, {})
        expect.falsy(ok); expect.eq(why, "Mỗi bên phải đưa ít nhất 1 tài nguyên (không cho không)")
        ok, why = Trade.check(s, pid, other, {}, { science = 1 })
        expect.falsy(ok); expect.eq(why, "Mỗi bên phải đưa ít nhất 1 tài nguyên (không cho không)")
        ok, why = Trade.check(s, pid, other, { science = 1 }, { science = 2 })
        expect.falsy(ok); expect.eq(why, "Không đổi cùng loại tài nguyên")
        ok, why = Trade.check(s, pid, other, { science = 500 }, { culture = 1 })
        expect.falsy(ok); expect.eq(why, "Bạn không đủ tài nguyên để đưa")
        ok, why = Trade.check(s, pid, other, { science = 1 }, { culture = 500 })
        expect.falsy(ok); expect.eq(why, "Đối phương không đủ tài nguyên")
        ok, why = Trade.check(s, pid, pid, { science = 1 }, { culture = 1 })
        expect.falsy(ok); expect.eq(why, "Chọn một người chơi khác")
        ok, why = Trade.check(s, pid, other, { gold = 99 }, { culture = 1 })
        expect.falsy(ok); expect.eq(why, "Không đủ Vàng trả phí đường (1 V)")
        ok, why = Trade.check(s, pid, other, { fire = 1 }, { culture = 1 })
        expect.falsy(ok); expect.eq(why, "Tài nguyên không hợp lệ")
        local s2, pid2 = arena()
        ok, why = Trade.check(s2, pid2, 3 - pid2, { science = 1 }, { culture = 1 })
        expect.falsy(ok); expect.eq(why, "Bạn cần có Khu Chợ")
        ok = Trade.check(s, pid, other, { science = 2, gold = 1 }, { culture = 3 })
        expect.truthy(ok)
    end)

    it("đề xuất mở lời nhắc cho người nhận; chấp nhận thì đổi và trừ phí; người nhận là actor", function()
        local s, pid, other = setup()
        local give, get = { science = 2 }, { culture = 3 }
        local mine, theirs = s.players[pid].res, s.players[other].res
        local sci, cul, gold, osci, ocul = mine.science, mine.culture, mine.gold, theirs.science, theirs.culture
        local ev = Game.apply(s, { type = "proposeTrade", to = other, give = give, get = get })
        expect.eq(ev[1].kind, "trade_proposed"); expect.eq(ev[1].fee, 1)
        expect.eq(s.phase, "prompt"); expect.eq(Game.actor(s), other)
        expect.falsy(Game.check(s, { type = "endTurn" }))
        local legal = Game.legal(s)
        expect.eq(#legal, 2)
        local ev2 = Game.apply(s, { type = "respond", choice = "accept" })
        expect.eq(ev2[1].kind, "trade_accepted")
        expect.eq(mine.science, sci - 2); expect.eq(mine.culture, cul + 3); expect.eq(mine.gold, gold - 1)
        expect.eq(theirs.science, osci + 2); expect.eq(theirs.culture, ocul - 3)
        expect.eq(s.phase, "action"); expect.eq(Game.actor(s), pid)
        expect.truthy(Sim.invariants(s))
    end)

    it("từ chối thì không đổi gì; chấp nhận khi điều kiện đã đổi (đường đứt) bị từ chối", function()
        local s, pid, other, c = setup()
        local snap = s.players[pid].res.science
        Game.apply(s, { type = "proposeTrade", to = other, give = { science = 1 }, get = { culture = 1 } })
        local ev = Game.apply(s, { type = "respond", choice = "decline" })
        expect.eq(ev[1].kind, "trade_declined"); expect.eq(s.players[pid].res.science, snap)
        expect.eq(s.phase, "action")

        Game.apply(s, { type = "proposeTrade", to = other, give = { science = 1 }, get = { culture = 1 } })
        s.roads = {}                                   -- đường bị phá giữa chừng
        local ok, why = Game.check(s, { type = "respond", choice = "accept" })
        expect.falsy(ok); expect.eq(why, "Hai Khu Chợ chưa được nối bằng đường (hoặc đang bị phong tỏa)")
        expect.truthy(Game.check(s, { type = "respond", choice = "decline" }))
    end)

    it("legal() có đề xuất 1 đổi 1 khi có tuyến; lời nhắc sống qua save/load", function()
        local s, pid, other = setup()
        local n = 0
        for _, cmd in ipairs(Game.legal(s)) do
            if cmd.type == "proposeTrade" then n = n + 1; expect.truthy(Game.check(s, cmd)) end
        end
        expect.truthy(n > 0)
        Game.apply(s, { type = "proposeTrade", to = other, give = { science = 1 }, get = { culture = 1 } })
        local s2 = reload(s)   -- thế cờ dựng tay không qua được kiểm tra của Game.load
        expect.eq(s2.phase, "prompt"); expect.eq(s2.prompt.kind, "trade"); expect.eq(Game.actor(s2), other)
        Game.apply(s2, { type = "respond", choice = "accept" })
        expect.eq(s2.phase, "action")
    end)

    it("đổi ngân hàng 1:1 khi có Khu Chợ C2+ đứng trên TN-06 của mình; ngược lại 4:1", function()
        local s, pid, c = arena()
        farRebel(s)
        expect.eq(Trade.bankRate(s, pid), C.BANK_TRADE_RATE)
        local m = Structures.place(s, { id = "B-05", level = 1, owner = pid }, { c })
        c.strategic = "TN-06"
        expect.eq(Trade.bankRate(s, pid), C.BANK_TRADE_RATE, "C1 chưa đủ")
        m.level = 2
        expect.eq(Trade.bankRate(s, pid), C.TN06_MARKET_RATE)
        s.players[pid].res.science = 1
        local ev = Game.apply(s, { type = "trade", give = "science", get = "culture" })
        expect.eq(ev[1].rate, 1)
        s.lostStrategic[key(c)] = true
        expect.eq(Trade.bankRate(s, pid), C.BANK_TRADE_RATE)
        c.strategic = nil
    end)
end)

describe("roads: mô phỏng có tài nguyên dồi dào", function()
    it("chơi ngẫu nhiên: Giao Thương xây đường, trao đổi, bất biến luôn đúng", function()
        local s = arena(14)
        local roads, trades = 0, 0
        local seen = #s.log
        for _ = 1, 150 do
            Sim.advance(s, 10, 14)
            for p = 1, 2 do
                for k, v in pairs(s.players[p].res) do if v < 30 and k ~= "bond" then s.players[p].res[k] = 30 end end
            end
            local ok, why = Sim.invariants(s)
            expect.truthy(ok, why)
            for i = seen + 1, #s.log do
                local e = s.log[i]
                if e.kind == "unit_move" and (e.roads or 0) > 0 then roads = roads + e.roads end
                if e.kind == "trade_accepted" then trades = trades + 1 end
            end
            seen = #s.log
            if s.phase == "over" then break end
        end
        expect.truthy(roads > 0, "phải có đường được xây")
    end)
end)
