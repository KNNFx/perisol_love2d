local C       = require("src.config.constants")
local Hex     = require("src.core.hex")
local Mapgen  = require("src.core.mapgen")
local State   = require("src.core.state")
local Structures = require("src.core.structures")
local Rebel   = require("src.core.rebel")
local Territory = require("src.core.territory")

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
    here.base = nil
    for _, n in ipairs(s.map:range(here, 3)) do n.base = nil end   -- không Tài Nguyên Cơ Bản: test đo tiền
    for _, n in ipairs(s.map:neighbors(here)) do n.strategic = nil end
    return here
end

describe("rebel: xuất hiện và phong tỏa", function()
    it("xuất hiện ở giữa bản đồ (dời tới ô hợp lệ gần nhất), cách mọi HQ >= 2, không đứng trên HQ, tất định", function()
        for seed = 1, 20 do
            local s = newState(seed)
            local t = Rebel.spawn(s)
            expect.truthy(Rebel.stepCost(s, t.terrain) < math.huge, "seed " .. seed .. ": ô phải đi được")
            expect.falsy(Rebel.isHQTile(s, t))
            for _, p in ipairs(s.players) do
                expect.truthy(Hex.distance(p.hq, t) >= C.REBEL_SPAWN_MIN_HQ_DIST)
            end
            local mid = Hex.fromOffset(math.floor((s.map.cols - 1) / 2), math.floor((s.map.rows - 1) / 2))
            for _, o in ipairs(s.map.list) do   -- không có ô hợp lệ nào gần tâm hơn
                local okTile = Rebel.stepCost(s, o.terrain) < math.huge and not Rebel.isHQTile(s, o)
                for _, p in ipairs(s.players) do
                    if Hex.distance(p.hq, o) < C.REBEL_SPAWN_MIN_HQ_DIST then okTile = false end
                end
                if okTile then expect.truthy(Hex.distance(mid, o) >= Hex.distance(mid, t), "seed " .. seed) end
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

describe("rebel: cướp phá khi bước lên công trình (GDD 1.6 §6.2)", function()
    -- Phiến Quân đứng ở giữa, công trình của P2 ở ô kề `target`; P1 điều khiển với 3 điểm.
    local function setup(victimRes, points)
        local s = newState()
        local here = arena(s)
        local target = s.map:neighbors(here)[1]
        Structures.place(s, { id = "B-01", level = 1, owner = 2 }, { target })
        for k, v in pairs(victimRes) do s.players[2].res[k] = v end
        s.rebel.pending = { stage = "move", points = points or 3, roller = 1, visited = { [State.key(here)] = true } }
        return s, here, target
    end

    it("bước lên: chủ mất ceil(1/2) loại nhiều nhất, người điều khiển nhận TOÀN BỘ (5 -> mất 3, nhận 3), kể cả đi ngang", function()
        local s, here, target = setup({ gold = 5, science = 1 })
        local ev = Rebel.step(s, target.q, target.r)
        expect.eq(s.players[2].res.gold, 2)
        expect.eq(s.players[1].res.gold, 3)
        expect.eq(s.players[2].res.science, 1)
        local loss
        for _, e in ipairs(ev) do if e.kind == "rebel_loss" then loss = e end end
        expect.truthy(loss); expect.eq(loss.lost, 3); expect.eq(loss.gained, 3)
        expect.eq(Rebel.stage(s), "move", "còn điểm nên chưa dừng (đi ngang qua vẫn bị cướp)")
        for _, e in ipairs(ev) do expect.truthy(e.kind ~= "rebel_stop") end
    end)

    it("mỗi công trình chỉ bị cướp 1 lần mỗi vòng; sang vòng sau bị cướp lại", function()
        local s, here, target = setup({ gold = 10 })
        s.round = 3
        Rebel.step(s, target.q, target.r)
        expect.eq(s.players[2].res.gold, 5)
        s.rebel.q, s.rebel.r = here.q, here.r           -- đưa Phiến Quân lui về rồi bước lên lần nữa
        s.rebel.pending = { stage = "move", points = 3, roller = 1, visited = { [State.key(here)] = true } }
        Rebel.step(s, target.q, target.r)
        expect.eq(s.players[2].res.gold, 5, "cùng vòng: không bị cướp lại")
        s.round = 4
        s.rebel.q, s.rebel.r = here.q, here.r
        s.rebel.pending = { stage = "move", points = 3, roller = 1, visited = { [State.key(here)] = true } }
        Rebel.step(s, target.q, target.r)
        expect.eq(s.players[2].res.gold, 2, "vòng sau: ceil(5/2) = 3 nữa")
    end)

    it("hòa loại nhiều nhất: chủ chọn, rồi Phiến Quân đi tiếp", function()
        local s, here, target = setup({ gold = 4, culture = 4 })
        local ev = Rebel.step(s, target.q, target.r)
        expect.eq(Rebel.stage(s), "loss")
        expect.eq(ev[#ev].kind, "rebel_choose")
        expect.eq(s.players[2].res.gold, 4)               -- chưa mất gì
        expect.error(function() Rebel.resolveLoss(s, "faith") end)
        ev = Rebel.resolveLoss(s, "culture")
        expect.eq(s.players[2].res.culture, 2)
        expect.eq(s.players[1].res.culture, 2)
        expect.eq(s.players[2].res.gold, 4)
        expect.eq(Rebel.stage(s), "move", "trả lại quyền đi tiếp cho người điều khiển")
        expect.eq(s.rebel.pending.points, 2)
        expect.truthy(#Rebel.legalSteps(s) > 0)
    end)

    it("hòa ở bước cuối thì dừng sau khi chủ chọn", function()
        local s, here, target = setup({ gold = 4, culture = 4 }, 1)
        Rebel.step(s, target.q, target.r)
        expect.eq(Rebel.stage(s), "loss")
        local ev = Rebel.resolveLoss(s, "gold")
        expect.eq(ev[#ev].kind, "rebel_stop")
        expect.eq(Rebel.stage(s), nil)
    end)

    it("cướp cả Khu Trực Thuộc; không cướp công trình của chính người điều khiển hay chủ không có gì", function()
        local s, here, target = setup({})
        expect.eq(#select(1, Rebel.plunder(s, target)), 0, "chủ có 0 tài nguyên")
        s.players[2].res.gold = 5
        Structures.at(s, target).owner = 1
        expect.eq(#select(1, Rebel.plunder(s, target)), 0, "của chính người điều khiển")
        local s2 = newState()
        local here2 = arena(s2)
        local t2 = s2.map:neighbors(here2)[2]
        s2.players[3].subs = { { q = t2.q, r = t2.r, level = 1 } }
        s2.players[3].res.gold = 6
        s2.rebel.pending = { stage = "move", points = 3, roller = 1 }
        local ev = Rebel.plunder(s2, t2)
        expect.eq(ev[1].kind, "rebel_loss"); expect.eq(s2.players[3].res.gold, 3); expect.eq(s2.players[1].res.gold, 3)
    end)

    it("ô Nhà Chính là ô chặn: không vào, không dừng, không bị đẩy tới", function()
        local s = newState()
        local hq = s.players[3].hq
        local here = s.map:neighbors(s.map:get(hq.q, hq.r))[1]
        s.rebel = { q = here.q, r = here.r, pending = { stage = "move", points = 6, roller = 1, visited = { [State.key(here)] = true } } }
        for _, t in ipairs(Rebel.legalSteps(s)) do expect.falsy(t.q == hq.q and t.r == hq.r) end
        expect.truthy(Rebel.isHQTile(s, s.map:get(hq.q, hq.r)))
        -- đẩy (Trấn Áp / Thiên Đàn) cũng không đi vào HQ
        for dir = 1, 6 do
            for _, t in ipairs(Rebel.pushPath(s, dir, 2)) do expect.falsy(t.q == hq.q and t.r == hq.r) end
        end
    end)

    it("dừng trên ô chưa có chủ có Tài Nguyên Cơ Bản: người điều khiển nhận ceil(1/2) mỗi loại từ ngân hàng", function()
        local s = newState()
        local here = arena(s)
        here.base = { gold = 3, science = 1, culture = 2 }
        s.rebel.pending = { stage = "move", points = 1, roller = 1 }
        local ev = Rebel.stop(s)
        local bank
        for _, e in ipairs(ev) do if e.kind == "rebel_bank" then bank = e end end
        expect.truthy(bank)
        expect.eq(s.players[1].res.gold, 2); expect.eq(s.players[1].res.science, 1); expect.eq(s.players[1].res.culture, 1)
        s.owner[State.key(here)] = 2                       -- ô đã có chủ thì không
        s.rebel.pending = { stage = "move", points = 1, roller = 1 }
        local before = s.players[1].res.gold
        Rebel.stop(s)
        expect.eq(s.players[1].res.gold, before)
    end)

    it("ô trống và dừng không cướp: chỉ có sự kiện dừng", function()
        local s3 = newState()
        arena(s3)
        s3.rebel.pending = { stage = "move", points = 1, roller = 1 }
        expect.eq(#Rebel.stop(s3), 1)
    end)

    it("người bị quấy phá được tính theo ô thực hữu hoặc công trình trong vùng phong tỏa", function()
        local s = newState()
        local here = arena(s)
        expect.falsy(Rebel.harassed(s, 2))
        s.owner[State.key(s.map:neighbors(here)[3])] = 2
        expect.truthy(Rebel.harassed(s, 2))
        s.owner = {}
        Structures.place(s, { id = "B-01", level = 1, owner = 3 }, { s.map:neighbors(here)[4] })
        expect.truthy(Rebel.harassed(s, 3)); expect.falsy(Rebel.harassed(s, 2))
        s.rebel.suppressedRound = s.round
        expect.falsy(Rebel.harassed(s, 3), "đang được Trấn Áp thì không bị quấy phá")
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
