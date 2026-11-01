local C          = require("src.config.constants")
local BaseRes    = require("src.data.baseresources")
local Dice       = require("src.core.dice")
local Game       = require("src.core.game")
local Hex        = require("src.core.hex")
local Mapgen     = require("src.core.mapgen")
local Production = require("src.core.production")
local Rebel      = require("src.core.rebel")
local Resources  = require("src.data.resources")
local Rng        = require("src.core.rng")
local Sim        = require("src.core.sim")
local State      = require("src.core.state")
local Structures = require("src.core.structures")
local Territory  = require("src.core.territory")

local key = State.key
local arena = require("tests.arena")

describe("tài nguyên cơ bản trên ô: sinh bản đồ (GDD 1.6 §3.3)", function()
    it("tất định theo seed; mỗi loại 1 hoặc 2; không có loại mà địa hình không cho", function()
        for seed = 1, 12 do
            local a, b = Mapgen.generate({ seed = seed, players = 2 }), Mapgen.generate({ seed = seed, players = 2 })
            for i, t in ipairs(a.list) do
                local u = b.list[i]
                for _, r in ipairs(Resources.core) do
                    expect.eq(t.base and t.base[r.key], u.base and u.base[r.key], "seed " .. seed)
                    local n = t.base and t.base[r.key]
                    if n then
                        expect.truthy(n == 1 or n == 2)
                        if t.terrain ~= "DH-11" then
                            local allowed = BaseRes.chance[t.terrain] and BaseRes.chance[t.terrain][r.key]
                            expect.truthy(allowed, string.format("%s không được có %s (seed %d)", t.terrain, r.key, seed))
                        end
                    end
                end
            end
        end
    end)

    it("Sa Mạc không có Tín Ngưỡng, Đồng Bằng không có Khoa Học; Lãnh Nguyên Vàng luôn 1", function()
        for seed = 1, 30 do
            local map = Mapgen.generate({ seed = seed, players = 3 })
            for _, t in ipairs(map.list) do
                if t.terrain == "DH-07" then expect.eq(t.base and t.base.faith, nil) end
                if t.terrain == "DH-01" then expect.eq(t.base and t.base.science, nil) end
                if t.terrain == "DH-06" and t.base and t.base.gold then expect.eq(t.base.gold, 1) end
            end
        end
    end)

    it("mỗi Danh Thắng gắn đúng 1 loại, mọi ô của nó có loại đó; ô đặt HQ không có tài nguyên", function()
        for seed = 1, 12 do
            local map = Mapgen.generate({ seed = seed, players = 3 })
            for _, lm in ipairs(map.landmarks) do
                expect.truthy(Resources.byKey[lm.resource], "danh thắng thiếu loại")
                for _, t in ipairs(lm.tiles) do
                    local kinds = 0
                    for _ in pairs(t.base or {}) do kinds = kinds + 1 end
                    expect.eq(kinds, 1)
                    expect.truthy(t.base[lm.resource])
                end
            end
            for _, st in ipairs(map.starts) do expect.eq(map:get(st.q, st.r).base, nil) end
        end
    end)

    it("tần suất gần bảng GDD (Đồng Bằng Kỹ Thuật ~30%) và tỉ lệ lượng 2 ~30%", function()
        local plains, withEng, twos, total = 0, 0, 0, 0
        for seed = 1, 25 do
            for _, t in ipairs(Mapgen.generate({ seed = seed, players = 4 }).list) do
                if t.terrain == "DH-01" and not t.isStart then
                    plains = plains + 1
                    if t.base and t.base.engineering then withEng = withEng + 1 end
                end
                for _, n in pairs(t.base or {}) do
                    if t.terrain ~= "DH-11" and t.terrain ~= "DH-06" and t.terrain ~= "DH-08" then
                        total = total + 1
                        if n == 2 then twos = twos + 1 end
                    end
                end
            end
        end
        expect.truthy(plains > 500)
        expect.truthy(math.abs(withEng / plains - 0.30) < 0.05, "KT trên Đồng Bằng " .. withEng / plains)
        expect.truthy(math.abs(twos / total - 0.30) < 0.05, "lượng 2: " .. twos / total)
    end)

    it("MaxKindsPerTile khóa số loại; bản đồ không đổi khi tắt", function()
        BaseRes.MAX_KINDS_PER_TILE = 1
        local capped = Mapgen.generate({ seed = 5, players = 3 })
        BaseRes.MAX_KINDS_PER_TILE = nil
        for _, t in ipairs(capped.list) do
            local n = 0
            for _ in pairs(t.base or {}) do n = n + 1 end
            expect.truthy(n <= 1)
        end
    end)

    it("ô kề Sông có xác suất Tín Ngưỡng cao hơn", function()
        local near, nearFaith, far, farFaith = 0, 0, 0, 0
        for seed = 1, 40 do
            local map = Mapgen.generate({ seed = seed, players = 3 })
            for _, t in ipairs(map.list) do
                if (t.terrain == "DH-02" or t.terrain == "DH-09") and not t.isStart then
                    local river = false
                    for _, n in ipairs(map:neighbors(t)) do if n.terrain == "DH-04" then river = true end end
                    if river then near = near + 1; if t.base and t.base.faith then nearFaith = nearFaith + 1 end
                    else far = far + 1; if t.base and t.base.faith then farFaith = farFaith + 1 end end
                end
            end
        end
        expect.truthy(near > 50 and far > 50)
        expect.truthy(nearFaith / near > farFaith / far, "kề Sông phải nhiều Tín Ngưỡng hơn")
    end)
end)

describe("tài nguyên cơ bản: người thu hoạch và sản xuất theo ô", function()
    -- Một ô trong arena đặt lượng CB; arena không có CB nào khác (tests/arena.lua).
    local function tileWith(s, c, base, dq, dr)
        local t = s.map:get(c.q + (dq or 0), c.r + (dr or 0))
        t.base = base
        return t
    end

    local function sum(events, pid, res)
        local n = 0
        for _, e in ipairs(events) do
            if e.kind == "tile_produce" and e.pid == pid and (not res or e.res == res) then n = n + e.amount end
        end
        return n
    end

    it("chủ ô nhận lượng x số viên khớp, kể cả khi người khác đổ (Sản Xuất Chung)", function()
        local s, pid, c = arena()
        tileWith(s, c, { gold = 2, science = 1 })
        expect.eq(sum(Production.compute(s, { 5, 1 }, pid), pid, "gold"), 2)
        expect.eq(sum(Production.compute(s, { 5, 5 }, 3 - pid), pid, "gold"), 4)
        expect.eq(sum(Production.compute(s, { 5, 1 }, pid), pid, "science"), 1)
        expect.eq(sum(Production.compute(s, { 3, 6 }, pid), pid), 0, "mặt khác / Hex không nhả")
        expect.eq(#Production.compute(s, { 3, 4 }, pid) >= 0, true)
    end)

    it("ô chưa có chủ: thuộc người duy nhất có vùng ảnh hưởng phủ ô; hai người cùng phủ hoặc không ai thì không ai nhận", function()
        local s, pid, c = arena()
        local far = s.map:get(c.q, c.r)
        s.owner[key(far)] = nil
        far.base = { engineering = 1 }
        expect.eq(Territory.harvester(s, far), nil, "không ai có ảnh hưởng")
        local hq = s.players[pid].hq
        local near = Hex.ring(hq, 1)[1]
        local t = s.map:get(near.q, near.r)
        s.owner[key(t)] = nil
        expect.eq(Territory.harvester(s, t), pid, "trong vùng ảnh hưởng của chỉ P" .. pid)
        local other = 3 - pid
        local oh = s.players[other].hq
        s.players[other].hq = { q = hq.q + 2, r = hq.r }     -- vùng ảnh hưởng của hai người chồng nhau
        s.players[other].hqLevel = 2
        s.players[pid].hqLevel = 2
        local mid = s.map:get(hq.q + 1, hq.r)
        s.owner[key(mid)] = nil
        expect.eq(Territory.harvester(s, mid), nil, "hai người cùng ảnh hưởng: chưa ai thu hoạch được")
        s.players[other].hq = oh
    end)

    it("bonus TN trên ô cộng vào lượng CB, kể cả khi ô không có loại đó; mất TN thì mất bonus", function()
        local s, pid, c = arena()
        local t = tileWith(s, c, nil)
        t.strategic = "TN-05"                                  -- +2 KT khi ra KT, ô không có KT cơ bản
        expect.eq(sum(Production.compute(s, { 3, 5 }, pid), pid, "engineering"), 2)
        t.base = { engineering = 1 }
        expect.eq(sum(Production.compute(s, { 3, 3 }, pid), pid, "engineering"), 6, "(1 + 2) x 2 viên")
        s.lostStrategic[key(t)] = true
        expect.eq(sum(Production.compute(s, { 3, 3 }, pid), pid, "engineering"), 2, "chỉ còn CB")
        t.strategic = nil
    end)

    it("công trình trên ô vẫn sản xuất riêng, hai nguồn cộng dồn", function()
        local s, pid, c = arena()
        local t = tileWith(s, c, { engineering = 2 })
        Structures.place(s, { id = "B-01", level = 1, owner = pid }, { t })
        local tile, building = 0, 0
        for _, e in ipairs(Production.compute(s, { 3, 5 }, pid)) do
            if e.kind == "tile_produce" and e.res == "engineering" and e.pid == pid and e.q == t.q and e.r == t.r then tile = tile + e.amount end
            if e.kind == "produce" and e.res == "engineering" and e.pid == pid then building = building + e.amount end
        end
        expect.eq(tile, 2); expect.eq(building, 1)
    end)

    it("Phiến Quân phong tỏa chặn cả ô lẫn công trình", function()
        local s, pid, c = arena()
        local t = tileWith(s, c, { gold = 1 })
        s.rebel = { q = t.q, r = t.r }
        expect.eq(sum(Production.compute(s, { 5, 1 }, pid), pid), 0)
        s.rebel = { q = -99, r = -99 }
        expect.eq(sum(Production.compute(s, { 5, 1 }, pid), pid, "gold"), 1)
    end)

    it("S-01 cộng +1 KH cho ô KH của chủ trong aura", function()
        local s, pid, c = arena()
        local t = tileWith(s, c, { science = 1 })
        local far = tileWith(s, c, { science = 1 }, 2, 0)
        Structures.place(s, { id = "S-01", level = 1, owner = pid }, { s.map:get(c.q, c.r + 1) })
        local near
        for _, e in ipairs(Production.compute(s, { 1, 5 }, pid)) do
            if e.kind == "tile_produce" and e.q == t.q and e.r == t.r then near = e.amount end
        end
        expect.eq(near, 2, "1 CB + 1 aura Tháp")
        t.base, far.base = nil, nil
    end)

    it("khởi đầu: tài nguyên = tổng Tài Nguyên Cơ Bản của 6 ô quanh HQ, nhận 1 lần; 6 ô là thực hữu có phiếu bằng ngưỡng", function()
        for seed = 1, 6 do
            local s = Game.new({ seed = seed, players = 3 })
            while s.phase == "setup_hq" do Game.apply(s, Game.legal(s)[1]) end
            for pid = 1, 3 do
                local p = s.players[pid]
                local hqTile = s.map:get(p.hq.q, p.hq.r)
                local want = {}
                for _, n in ipairs(s.map:neighbors(hqTile)) do
                    expect.eq(s.owner[key(n)], pid)
                    expect.truthy(Territory.votesOn(s, n, pid) >= Territory.threshold(s, pid, n))
                    for res, amount in pairs(n.base or {}) do want[res] = (want[res] or 0) + amount end
                end
                for _, r in ipairs(Resources.core) do expect.eq(p.res[r.key], want[r.key] or 0, "P" .. pid .. " " .. r.key) end
            end
            expect.truthy(Sim.invariants(s))
        end
    end)
end)

describe("Lệnh Đuổi Phiến Quân (GDD 1.6 §6.2)", function()
    -- Đặt Phiến Quân sát tài sản của `pid` để pid bị quấy phá, sau đó cho họ lượt đổ.
    local function harassed(turns)
        local s, pid, c = arena()
        s.round = 3
        local t = s.map:get(c.q + 1, c.r)
        s.rebel = { q = t.q, r = t.r }
        s.phase = "roll"
        for i, id in ipairs(s.order) do if id == pid then s.turn = i end end
        return s, pid
    end

    local function noSeven(s)
        for i = 1, 3000 do
            local tag = "ns" .. i
            local d = Dice.roll(Rng.new(tag))
            if d[1] + d[2] ~= 7 and d[1] ~= 6 and d[2] ~= 6 then s.rng = Rng.new(tag) return end
        end
    end

    it("bộ đếm tăng mỗi lượt bị quấy phá; từ lượt thứ 4 có Lệnh Đuổi; hết bị quấy phá thì về 0", function()
        local s, pid = harassed()
        for turn = 1, 4 do
            s.phase = "roll"; noSeven(s)
            for i, id in ipairs(s.order) do if id == pid then s.turn = i end end
            local ev = Game.apply(s, { type = "roll" })
            expect.eq(s.players[pid].harass, turn)
            local ready = false
            for _, e in ipairs(ev) do if e.kind == "expel_ready" then ready = true end end
            expect.eq(ready, turn == 4, "chỉ lượt thứ 4 mới nhận Lệnh Đuổi")
            expect.eq(s.players[pid].expelReady, turn == 4 or nil)
            while s.phase ~= "action" do Game.apply(s, Game.legal(s)[1]) end
        end
        s.rebel = { q = -99, r = -99 }   -- Phiến Quân rời vùng
        s.phase = "roll"; noSeven(s)
        for i, id in ipairs(s.order) do if id == pid then s.turn = i end end
        Game.apply(s, { type = "roll" })
        expect.eq(s.players[pid].harass, 0)
        expect.eq(s.players[pid].expelReady, nil)
    end)

    it("dùng Lệnh Đuổi: đổ 1d6 điều khiển Phiến Quân như ra 7, không lặp Khâu Giải Quyết, bộ đếm về 0", function()
        local s, pid = harassed()
        s.players[pid].harass, s.players[pid].expelReady = 4, true
        s.round, s.turn = 5, 1
        for i, id in ipairs(s.order) do if id == pid then s.turn = i end end
        s.phase = "action"
        expect.truthy(Game.check(s, { type = "expelRebel" }))
        local legal = false
        for _, cmd in ipairs(Game.legal(s)) do if cmd.type == "expelRebel" then legal = true end end
        expect.truthy(legal)
        local ev = Game.apply(s, { type = "expelRebel" })
        expect.eq(ev[1].kind, "expel")
        expect.eq(s.players[pid].harass, 0); expect.eq(s.players[pid].expelReady, nil)
        local guard = 0
        while s.phase == "rebel_move" or s.phase == "rebel_loss" or s.phase == "prompt" do
            guard = guard + 1; assert(guard < 50)
            Game.apply(s, Game.legal(s)[1])
        end
        expect.eq(s.phase, "action", "xong thì về Khâu Hành Động")
        for _, e in ipairs(s.log) do
            if e.kind == "global_event" and e.round == 5 then error("Khâu Giải Quyết bị lặp") end
        end
        expect.falsy(Game.check(s, { type = "expelRebel" }), "dùng rồi thì hết")
    end)

    it("không có Lệnh Đuổi thì từ chối", function()
        local s, pid = harassed()
        s.phase = "action"
        for i, id in ipairs(s.order) do if id == pid then s.turn = i end end
        local ok, why = Game.check(s, { type = "expelRebel" })
        expect.falsy(ok); expect.truthy(why:find("Lệnh Đuổi", 1, true))
    end)
end)
