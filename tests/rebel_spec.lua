local C       = require("src.config.constants")
local Hex     = require("src.core.hex")
local Mapgen  = require("src.core.mapgen")
local State   = require("src.core.state")
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

describe("rebel: hiệu ứng khi dừng", function()
    local function setup(victimRes)
        local s = newState()
        local here = arena(s)
        s.buildings[State.key(here)] = { id = "B-01", level = 1, owner = 2 }
        for k, v in pairs(victimRes) do s.players[2].res[k] = v end
        s.rebel.pending = { stage = "move", points = 3, roller = 1 }
        return s, here
    end

    it("chủ mất ceil(1/2) loại nhiều nhất; người đổ nhận ceil(1/2) số đó (5 -> mất 3, nhận 2)", function()
        local s = setup({ gold = 5, science = 1 })
        local ev = Rebel.stop(s)
        expect.eq(s.players[2].res.gold, 2)
        expect.eq(s.players[1].res.gold, 2)
        expect.eq(s.players[2].res.science, 1)
        local loss = ev[#ev]
        expect.eq(loss.kind, "rebel_loss"); expect.eq(loss.lost, 3); expect.eq(loss.gained, 2)
        expect.eq(Rebel.stage(s), nil)
    end)

    it("hòa loại nhiều nhất: chờ chủ chọn", function()
        local s = setup({ gold = 4, culture = 4 })
        local ev = Rebel.stop(s)
        expect.eq(Rebel.stage(s), "loss")
        expect.eq(ev[#ev].kind, "rebel_choose")
        expect.eq(s.players[2].res.gold, 4)               -- chưa mất gì
        expect.error(function() Rebel.resolveLoss(s, "faith") end)
        ev = Rebel.resolveLoss(s, "culture")
        expect.eq(s.players[2].res.culture, 2)
        expect.eq(s.players[1].res.culture, 1)
        expect.eq(s.players[2].res.gold, 4)
        expect.eq(Rebel.stage(s), nil)
    end)

    it("dừng trên HQ của người khác cũng bị tính", function()
        local s = newState()
        local hq = s.players[3].hq
        s.rebel = { q = hq.q, r = hq.r, pending = { stage = "move", points = 1, roller = 1 } }
        s.players[3].res.gold = 6
        Rebel.stop(s)
        expect.eq(s.players[3].res.gold, 3)
        expect.eq(s.players[1].res.gold, 2)
    end)

    it("ô trống, công trình của chính người đổ, hoặc chủ không có gì: không hiệu ứng", function()
        local s = setup({})
        local ev = Rebel.stop(s)                           -- chủ có 0 tài nguyên
        expect.eq(#ev, 1)
        local s2, here = setup({ gold = 5 })
        s2.buildings[State.key(here)].owner = 1            -- của chính người đổ
        Rebel.stop(s2)
        expect.eq(s2.players[2].res.gold, 5)
        local s3 = newState()
        arena(s3)
        s3.rebel.pending = { stage = "move", points = 1, roller = 1 }
        expect.eq(#Rebel.stop(s3), 1)
    end)
end)
