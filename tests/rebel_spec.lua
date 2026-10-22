local C       = require("src.config.constants")
local Game    = require("src.core.game")
local Hex     = require("src.core.hex")
local Mapgen  = require("src.core.mapgen")
local State   = require("src.core.state")
local Structures = require("src.core.structures")
local Rebel   = require("src.core.rebel")
local Specials = require("src.core.specials")
local Territory = require("src.core.territory")
local Units   = require("src.core.units")
local Upkeep  = require("src.core.upkeep")

-- 4 người, HQ đặt ở các vùng khởi đầu của map.
local function newState(seed)
    local map = Mapgen.generate({ seed = seed or 5, players = 4 })
    local s = State.new(map, 4, seed or 5)
    for pid, st in ipairs(map.starts) do Territory.placeHQ(s, pid, map:get(st.q, st.r)) end
    return s
end

-- Đặt Phiến Quân ở ô giữa bản đồ và làm "sạch" các ô kề thành Đồng Bằng.
local function arena(s)
    local c = Hex.fromOffset(15, 8)
    local here = s.map:get(c.q, c.r)
    s.rebel = { q = here.q, r = here.r }
    for _, n in ipairs(s.map:neighbors(here)) do n.terrain = "DH-01" end
    here.terrain = "DH-01"
    return here
end

describe("rebel: xuất hiện và phong tỏa", function()
    it("xuất hiện đúng luật, cách mọi HQ >= 2, tất định theo seed", function()
        for seed = 1, 20 do
            local s = newState(seed)
            local t = Rebel.spawn(s)
            expect.truthy(t.terrain == "DH-01" or t.terrain == "DH-06" or t.terrain == "DH-07",
                "seed " .. seed .. ": " .. t.terrain)
            for _, p in ipairs(s.players) do
                expect.truthy(Hex.distance(p.hq, t) >= C.REBEL_SPAWN_MIN_HQ_DIST)
            end
            local s2 = newState(seed)
            local t2 = Rebel.spawn(s2)
            expect.eq(t2.q, t.q); expect.eq(t2.r, t.r)
        end
    end)

    it("phong tỏa 7 ô ở giữa bản đồ, ít hơn ở mép", function()
        local s = newState()
        local here = arena(s)
        expect.eq(#Rebel.blockade(s), C.REBEL_BLOCKADE_TILES)
        expect.truthy(Rebel.isBlockaded(s, here))
        expect.truthy(Rebel.isBlockaded(s, s.map:neighbors(here)[1]))
        local far = s.map:get(Hex.fromOffset(0, 0).q, 0)
        expect.falsy(Rebel.isBlockaded(s, far))
        s.rebel = { q = far.q, r = far.r }
        expect.truthy(#Rebel.blockade(s) < C.REBEL_BLOCKADE_TILES)
    end)
end)

describe("rebel: di chuyển", function()
    it("đổ 1d6 điểm, đi từng bước theo chi phí địa hình, dừng khi hết điểm", function()
        local s = newState()
        local here = arena(s)
        local n = s.map:neighbors(here)
        n[1].terrain = "DH-02"                       -- Rừng: tốn 2
        local points = Rebel.startMove(s, 1)
        expect.truthy(points >= 1 and points <= 6)
        s.rebel.pending.points = 3                   -- ép giá trị để kiểm tra chi phí
        local ev = Rebel.step(s, n[1].q, n[1].r)
        expect.eq(s.rebel.pending.points, 1)
        expect.eq(ev[1].kind, "rebel_step")
        expect.eq(s.rebel.q, n[1].q)
        -- còn 1 điểm: chỉ ô Đồng Bằng (tốn 1) đi được, Rừng thì không
        for _, t in ipairs(Rebel.legalSteps(s)) do expect.truthy(t.terrain ~= "DH-02") end
        for _, t in ipairs(s.map:neighbors(n[1])) do t.terrain = "DH-01" end
        local nxt = Rebel.legalSteps(s)[1]
        ev = Rebel.step(s, nxt.q, nxt.r)
        expect.eq(Rebel.stage(s), nil)               -- hết điểm -> đã dừng
        expect.eq(ev[#ev].kind, "rebel_stop")
    end)

    it("dừng sớm khi không còn ô kề đủ điểm", function()
        local s = newState()
        local here = arena(s)
        for _, n in ipairs(s.map:neighbors(here)) do n.terrain = "DH-08" end   -- Đầm Lầy tốn 2
        -- đổ cho tới khi được 1 điểm (xác suất cao ở vài lần thử), kiểm tra hành vi dừng ngay
        local found = false
        for _ = 1, 60 do
            s.rebel.pending = nil
            local points, ev = Rebel.startMove(s, 1)
            if points == 1 then
                expect.eq(Rebel.stage(s), nil)
                expect.eq(ev[#ev].kind, "rebel_stop")
                found = true
                break
            end
            s.rebel.pending = nil
        end
        expect.truthy(found, "không đổ ra 1 điểm trong 60 lần")
    end)

    it("Núi: cấm trong 10 vòng đầu, vòng 11 tốn 3", function()
        local s = newState()
        local here = arena(s)
        local m = s.map:neighbors(here)[1]
        m.terrain = "DH-03"
        s.round = C.REBEL_MOUNTAIN_LOCK_ROUNDS
        s.rebel.pending = { stage = "move", points = 6, roller = 1 }
        for _, t in ipairs(Rebel.legalSteps(s)) do expect.truthy(t ~= m) end
        s.round = C.REBEL_MOUNTAIN_LOCK_ROUNDS + 1
        local ok = false
        for _, t in ipairs(Rebel.legalSteps(s)) do if t == m then ok = true end end
        expect.truthy(ok)
        s.rebel.pending.points = 2
        for _, t in ipairs(Rebel.legalSteps(s)) do expect.truthy(t ~= m, "2 điểm không đủ leo Núi") end
    end)

    it("bước không hợp lệ báo lỗi", function()
        local s = newState()
        arena(s)
        s.rebel.pending = { stage = "move", points = 1, roller = 1 }
        expect.error(function() Rebel.step(s, 0, 0) end)
    end)
end)

describe("rebel: cướp phá và hiệu ứng khi bước qua / dừng (GDD v1.3 §6.2)", function()
    local function setup(victimRes)
        local s = newState()
        local here = arena(s)
        Structures.place(s, { id = "B-01", level = 1, owner = 2 }, { here })
        for k, v in pairs(victimRes) do s.players[2].res[k] = v end
        s.rebel.pending = { stage = "move", points = 3, roller = 1 }
        return s, here
    end

    it("chủ mất ceil(1/2) loại nhiều nhất; người điều khiển nhận toàn bộ số mất (5 -> mất 3, nhận 3)", function()
        local s = setup({ gold = 5, science = 1 })
        local ev = Rebel.stop(s)
        expect.eq(s.players[2].res.gold, 2)
        expect.eq(s.players[1].res.gold, 3)
        expect.eq(s.players[2].res.science, 1)
        local loss = ev[#ev]
        expect.eq(loss.kind, "rebel_loss"); expect.eq(loss.lost, 3); expect.eq(loss.gained, 3)
        expect.eq(Rebel.stage(s), nil)
    end)

    it("hòa loại nhiều nhất: chờ chủ chọn, người điều khiển nhận đủ số mất", function()
        local s = setup({ gold = 4, culture = 4 })
        local ev = Rebel.stop(s)
        expect.eq(Rebel.stage(s), "loss")
        expect.eq(ev[#ev].kind, "rebel_choose")
        expect.eq(s.players[2].res.gold, 4)               -- chưa mất gì
        expect.error(function() Rebel.resolveLoss(s, "faith") end)
        ev = Rebel.resolveLoss(s, "culture")
        expect.eq(s.players[2].res.culture, 2)
        expect.eq(s.players[1].res.culture, 2)
        expect.eq(s.players[2].res.gold, 4)
        expect.eq(Rebel.stage(s), nil)
    end)

    it("cướp phá ngay khi đi xuyên qua công trình đối thủ (không cần dừng lại)", function()
        local s = newState()
        local here = arena(s)
        local ns = s.map:neighbors(here)
        for _, t in ipairs(s.map:neighbors(ns[1])) do t.terrain = "DH-01" end
        Structures.place(s, { id = "B-01", level = 1, owner = 2 }, { ns[1] })
        s.players[2].res.gold = 5
        s.rebel.pending = { stage = "move", points = 3, roller = 1, visited = { [State.key(here)] = true } }

        local ev = Rebel.step(s, ns[1].q, ns[1].r)
        expect.eq(Rebel.stage(s), "move", "còn điểm nên vẫn đang di chuyển")
        expect.eq(s.rebel.pending.points, 2)
        expect.eq(s.players[2].res.gold, 2, "bị cướp ngay khi bước vào")
        expect.eq(s.players[1].res.gold, 3, "người điều khiển nhận toàn bộ số mất")
        local foundLoss = false
        for _, e in ipairs(ev) do
            if e.kind == "rebel_loss" then
                foundLoss = true
                expect.eq(e.q, ns[1].q); expect.eq(e.r, ns[1].r)
            end
        end
        expect.truthy(foundLoss)
    end)

    it("hòa tài nguyên khi đi xuyên qua: chủ chọn xong thì Phiến Quân đi tiếp số bước còn lại", function()
        local s = newState()
        local here = arena(s)
        local ns = s.map:neighbors(here)
        for _, t in ipairs(s.map:neighbors(ns[1])) do t.terrain = "DH-01" end
        Structures.place(s, { id = "B-01", level = 1, owner = 2 }, { ns[1] })
        s.players[2].res.gold = 4
        s.players[2].res.science = 4
        s.phase = "rebel_move"
        s.rebel.pending = { stage = "move", points = 2, roller = 1, visited = { [State.key(here)] = true } }

        Game.apply(s, { type = "rebelStep", q = ns[1].q, r = ns[1].r })
        expect.eq(s.phase, "rebel_loss")
        expect.eq(Game.actor(s), 2)

        Game.apply(s, { type = "chooseLoss", res = "science" })
        expect.eq(s.players[2].res.science, 2)
        expect.eq(s.players[1].res.science, 2)
        expect.eq(s.phase, "rebel_move", "sau khi chọn tài nguyên mất, Phiến Quân tiếp tục bước còn lại")
        expect.eq(Game.actor(s), 1)
        expect.eq(s.rebel.pending.points, 1)

        local nxt = Rebel.legalSteps(s)[1]
        Game.apply(s, { type = "rebelStep", q = nxt.q, r = nxt.r })
        expect.eq(s.phase, "action")
    end)

    it("mỗi công trình chỉ bị cướp tối đa 1 lần trong 1 vòng (kể cả công trình nhiều ô); sang vòng mới mới bị cướp lại", function()
        local s = newState()
        local here = arena(s)
        local ns = s.map:neighbors(here)
        for _, t in ipairs(s.map:neighbors(ns[1])) do t.terrain = "DH-01" end
        for _, t in ipairs(s.map:neighbors(ns[2])) do t.terrain = "DH-01" end
        -- Công trình C2 chiếm 3 ô liên tiếp quanh here
        Structures.place(s, { id = "B-01", level = 2, owner = 2 }, { ns[1], ns[2], ns[3] })
        s.players[2].res.gold = 8
        s.rebel.pending = { stage = "move", points = 2, roller = 1, visited = { [State.key(here)] = true } }

        -- Bước 1 vào ô đầu của công trình C2 -> bị cướp (8 -> mất 4, còn 4)
        Rebel.step(s, ns[1].q, ns[1].r)
        expect.eq(s.players[2].res.gold, 4)
        expect.eq(s.players[1].res.gold, 4)

        -- Bước 2 vào ô thứ hai của CÙNG công trình C2 trong cùng vòng -> không bị cướp thêm
        Rebel.step(s, ns[2].q, ns[2].r)
        expect.eq(s.players[2].res.gold, 4, "cùng công trình trong cùng vòng không bị cướp lần 2")
        expect.eq(s.players[1].res.gold, 4)

        -- Lần kích hoạt thứ 2 trong cùng vòng đi vào ô thứ 3 của công trình đó -> vẫn không bị cướp
        s.rebel = { q = here.q, r = here.r, plundered = s.rebel.plundered,
                    pending = { stage = "move", points = 1, roller = 1, visited = { [State.key(here)] = true } } }
        Rebel.step(s, ns[3].q, ns[3].r)
        expect.eq(s.players[2].res.gold, 4)

        -- Sang vòng tiếp theo -> cướp lại được (4 -> mất 2, còn 2)
        s.round = s.round + 1
        s.rebel = { q = here.q, r = here.r, plundered = s.rebel.plundered,
                    pending = { stage = "move", points = 1, roller = 1, visited = { [State.key(here)] = true } } }
        Rebel.step(s, ns[1].q, ns[1].r)
        expect.eq(s.players[2].res.gold, 2)
        expect.eq(s.players[1].res.gold, 6)
    end)

    it("ô trống, công trình của chính người đổ, hoặc chủ không có gì: không hiệu ứng", function()
        local s = setup({})
        local ev = Rebel.stop(s)                           -- chủ có 0 tài nguyên
        expect.eq(#ev, 1)
        local s2, here = setup({ gold = 5 })
        Structures.at(s2, here).owner = 1           -- của chính người đổ
        Rebel.stop(s2)
        expect.eq(s2.players[2].res.gold, 5)
        local s3 = newState()
        arena(s3)
        s3.rebel.pending = { stage = "move", points = 1, roller = 1 }
        expect.eq(#Rebel.stop(s3), 1)
    end)
end)

describe("rebel: ô Nhà Chính (HQ) là ô chặn (GDD v1.3 §6.2, §12.4)", function()
    it("không được bước vào hoặc dừng trên HQ của bất kỳ người chơi nào; check trả lý do rõ ràng", function()
        local s = newState()
        local hq = s.players[2].hq
        local hqTile = s.map:get(hq.q, hq.r)
        local adj = s.map:neighbors(hqTile)[1]
        for _, n in ipairs(s.map:neighbors(adj)) do n.terrain = "DH-01" end
        hqTile.terrain = "DH-01"
        s.phase = "rebel_move"
        s.rebel = { q = adj.q, r = adj.r, pending = { stage = "move", points = 3, roller = 1, visited = { [State.key(adj)] = true } } }

        expect.truthy(Rebel.isHQ(s, hqTile))
        for _, t in ipairs(Rebel.legalSteps(s)) do
            expect.falsy(t.q == hq.q and t.r == hq.r, "ô HQ không được nằm trong legalSteps")
        end
        local ok, why = Game.check(s, { type = "rebelStep", q = hq.q, r = hq.r })
        expect.falsy(ok)
        expect.eq(why, "Không thể đi vào Nhà Chính")
    end)

    it("Trấn Áp (pushPath) và Thiên Đình (pushCandidates) cũng không đẩy Phiến Quân vào ô HQ", function()
        local s = newState()
        local here = arena(s)
        local d = Hex.DIRECTIONS[1]
        local n1 = s.map:get(here.q + d.q, here.r + d.r)
        -- Đặt HQ của P2 ngay ở n1 theo hướng 1
        s.players[2].hq = { q = n1.q, r = n1.r }
        expect.eq(#Rebel.pushPath(s, 1, 2), 0, "không đẩy được vào ô HQ")

        -- Nếu HQ ở ô thứ 2 theo hướng đẩy thì chỉ đẩy được 1 ô (dừng trước HQ)
        local n2 = s.map:get(n1.q + d.q, n1.r + d.r)
        n2.terrain = "DH-01"
        s.players[2].hq = { q = n2.q, r = n2.r }
        local path = Rebel.pushPath(s, 1, 2)
        expect.eq(#path, 1)
        expect.eq(path[1], n1)

        -- Thiên Đình S-05: pushCandidates loại trừ ô HQ
        local b = Structures.place(s, { id = "S-05", level = 1, owner = 1 }, { here })
        for _, cand in ipairs(Specials.pushCandidates(s, b)) do
            expect.falsy(Rebel.isHQ(s, cand), "pushCandidates không được chứa ô HQ")
        end
    end)
end)

describe("rebel: đếm lượt Bị Quấy Phá & Lệnh Đuổi Phiến Quân (GDD v1.3 §6.2, §6.3)", function()
    it("bị phong tỏa quá 3 lượt liên tiếp (từ lượt thứ 4) mở khóa expelRebel; dùng xong hoặc PQ rời đi thì reset về 0", function()
        local s = Game.new({ seed = 15, players = 2 })
        while s.phase == "setup_hq" do Game.apply(s, Game.legal(s)[1]) end
        local pid = s.order[1]
        local p = s.players[pid]
        local hqTile = s.map:get(p.hq.q, p.hq.r)
        local near = s.map:neighbors(hqTile)[1]
        for _, n in ipairs(s.map:neighbors(near)) do n.terrain = "DH-01" end
        near.terrain = "DH-01"

        -- Đặt Phiến Quân sát HQ của pid (phong tỏa HQ thuộc lãnh thổ thực hữu của pid)
        s.rebel = { q = near.q, r = near.r }
        expect.truthy(Rebel.isHarassing(s, pid))

        -- Lượt 1, 2, 3 bị quấy phá: harassTurns tăng lên 1, 2, 3 nhưng chưa mở khóa expelRebel (cần > 3)
        for expected = 1, C.REBEL_HARASS_TURNS do
            Upkeep.startTurn(s, pid)
            expect.eq(p.harassTurns, expected)
            s.phase = "action"
            local ok = Game.check(s, { type = "expelRebel" })
            expect.falsy(ok, "lượt " .. expected .. " chưa đủ > 3 lượt liên tiếp")
        end

        -- Lượt thứ 4 liên tiếp bị quấy phá: harassTurns = 4 -> mở khóa expelRebel trong pha action
        Upkeep.startTurn(s, pid)
        expect.eq(p.harassTurns, C.REBEL_HARASS_TURNS + 1)
        s.phase = "action"
        expect.truthy(Game.check(s, { type = "expelRebel" }))
        local inLegal = false
        for _, cmd in ipairs(Game.legal(s)) do
            if cmd.type == "expelRebel" then inLegal = true end
        end
        expect.truthy(inLegal, "Game.legal phải liệt kê expelRebel khi đủ điều kiện")

        -- Thực thi expelRebel: bộ đếm về 0, điều khiển Phiến Quân rồi quay lại pha action của chính lượt đó
        local ev = Game.apply(s, { type = "expelRebel" })
        expect.eq(ev[1].kind, "rebel_expel")
        expect.eq(p.harassTurns, 0, "dùng xong expelRebel thì bộ đếm reset về 0")
        while s.phase == "rebel_move" do
            Game.apply(s, Game.legal(s)[1])
        end
        if s.phase == "rebel_loss" then
            Game.apply(s, Game.legal(s)[1])
        end
        expect.eq(s.phase, "action", "sau khi Đuổi Phiến Quân xong thì tiếp tục pha action của lượt hiện tại")
        expect.eq(Game.actor(s), pid)
        expect.falsy(Game.check(s, { type = "expelRebel" }), "không dùng lại ngay khi bộ đếm đã về 0")
    end)

    it("Phiến Quân rời khỏi lãnh thổ hoặc bị Trấn Áp thì bộ đếm bị quấy phá reset về 0", function()
        local s = Game.new({ seed = 16, players = 2 })
        while s.phase == "setup_hq" do Game.apply(s, Game.legal(s)[1]) end
        local pid = s.order[1]
        local p = s.players[pid]
        local hqTile = s.map:get(p.hq.q, p.hq.r)
        local near = s.map:neighbors(hqTile)[1]
        s.rebel = { q = near.q, r = near.r }

        Upkeep.startTurn(s, pid)
        Upkeep.startTurn(s, pid)
        expect.eq(p.harassTurns, 2)

        -- Phiến Quân dời đi xa -> bộ đếm về 0 ngay lập tức
        local far = s.map.list[#s.map.list]
        Rebel.moveTo(s, far.q, far.r)
        if not Rebel.isHarassing(s, pid) then
            expect.eq(p.harassTurns, 0)
        end

        -- Quay lại quấy phá 2 lượt rồi bị Trấn Áp -> hủy phong tỏa -> bộ đếm về 0
        s.rebel = { q = near.q, r = near.r }
        Upkeep.startTurn(s, pid)
        Upkeep.startTurn(s, pid)
        expect.eq(p.harassTurns, 2)
        for _, n in ipairs(s.map:range(near, 3)) do n.terrain = "DH-01" end
        local u = Units.spawn(s, pid, "expedition", hqTile)
        p.res.faith = 10
        for dir = 1, 6 do
            if Units.checkSuppress(s, pid, u, dir, true) then
                Units.suppress(s, u, dir, true)
                break
            end
        end
        expect.eq(p.harassTurns, 0, "Trấn Áp thành công hủy phong tỏa nên bộ đếm về 0")
    end)
end)

describe("rebel: không đi lại ô cũ (GDD §6.2)", function()
    it("ô đã đi qua trong lần di chuyển này không còn là bước hợp lệ", function()
        local s = newState()
        local here = arena(s)
        local start = { q = here.q, r = here.r }
        Rebel.startMove(s, 1)
        s.rebel.pending.points = 6
        local first = Rebel.legalSteps(s)[1]
        Rebel.step(s, first.q, first.r)
        for _, t in ipairs(Rebel.legalSteps(s)) do
            expect.truthy(not (t.q == start.q and t.r == start.r), "không được quay lại ô xuất phát")
            expect.truthy(not (t.q == first.q and t.r == first.r))
        end
    end)

    it("kẹt giữa các ô đã đi thì dừng sớm", function()
        local s = newState()
        local here = arena(s)
        local ns = s.map:neighbors(here)
        for i = 2, #ns do ns[i].terrain = "DH-03" end         -- Núi: cấm trong 10 vòng đầu
        for _, n in ipairs(s.map:neighbors(ns[1])) do
            if not (n.q == here.q and n.r == here.r) then n.terrain = "DH-03" end
        end
        s.rebel.pending = { stage = "move", points = 6, roller = 1, visited = { [State.key(here)] = true } }
        local ev = Rebel.step(s, ns[1].q, ns[1].r)
        expect.eq(ev[#ev].kind, "rebel_stop")
        expect.eq(Rebel.stage(s), nil)
    end)
end)
