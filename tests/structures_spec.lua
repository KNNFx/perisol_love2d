local C          = require("src.config.constants")
local Game       = require("src.core.game")
local Hex        = require("src.core.hex")
local Serialize  = require("src.core.serialize")
local Sim        = require("src.core.sim")
local State      = require("src.core.state")
local Structures = require("src.core.structures")
local Upkeep     = require("src.core.upkeep")
local reload     = require("tests.reload")

local function newGame(seed, players)
    local s = Game.new({ seed = seed, players = players })
    while s.phase == "setup_hq" do Game.apply(s, Game.legal(s)[1]) end
    return s
end

describe("hex: xoay", function()
    it("xoay 6 bước về chỗ cũ; một bước đưa DIRECTIONS[i] thành DIRECTIONS[i-1]; không sinh -0", function()
        local h = { q = 2, r = -1 }
        local r = Hex.rotate(h, 6)
        expect.eq(r.q, 2); expect.eq(r.r, -1)
        for i = 1, 6 do
            local d = Hex.rotate(Hex.DIRECTIONS[i], 1)
            local nxt = Hex.DIRECTIONS[(i - 2) % 6 + 1]
            expect.eq(d.q, nxt.q); expect.eq(d.r, nxt.r)
            expect.eq(Hex.key(d), Hex.key(nxt))
        end
        local back = Hex.rotate(Hex.rotate(h, 2), -2)
        expect.eq(back.q, 2); expect.eq(back.r, -1)
    end)

    it("xoay giữ nguyên khoảng cách tới gốc", function()
        local o = { q = 0, r = 0 }
        for steps = 0, 5 do
            expect.eq(Hex.distance(o, Hex.rotate({ q = 3, r = -2 }, steps)), Hex.distance(o, { q = 3, r = -2 }))
        end
    end)
end)

describe("structures: công trình theo uid", function()
    it("place / at / remove giữ occupied nhất quán; không đặt chồng", function()
        local s = newGame(5, 2)
        local t1, t2 = s.map.list[3], s.map.list[4]
        local b = Structures.place(s, { id = "B-01", level = 1, owner = 1 }, { t1 })
        local b2 = Structures.place(s, { id = "B-02", level = 1, owner = 2 }, { t2 })
        expect.eq(b2.uid, b.uid + 1)
        expect.eq(Structures.at(s, t1).uid, b.uid)
        expect.eq(Structures.ownerAt(s, t2), 2)
        expect.error(function() Structures.place(s, { id = "B-01", owner = 1 }, { t1 }) end)
        Structures.remove(s, b.uid)
        expect.eq(Structures.at(s, t1), nil)
        expect.eq(Structures.ownerAt(s, t1), nil)
    end)

    it("công trình nhiều ô chiếm đủ ô; list theo thứ tự uid", function()
        local s = newGame(5, 2)
        local a, b = s.map.list[3], s.map.list[4]
        local m = Structures.place(s, { id = "B-03", level = 2, owner = 1 }, { a, b })
        expect.eq(Structures.at(s, b).uid, m.uid)
        expect.eq(#Structures.tilesOf(s, m), 2)
        Structures.place(s, { id = "B-01", owner = 1 }, { s.map.list[9] })
        local l = Structures.list(s)
        expect.eq(l[1].uid, m.uid); expect.eq(#l, 2)
    end)

    it("TN đã mất không còn tính (strategicAt)", function()
        local s = newGame(5, 2)
        local t
        for _, x in ipairs(s.map.list) do if x.strategic then t = x break end end
        expect.truthy(t, "map phải có TN")
        expect.eq(Structures.strategicAt(s, t), t.strategic)
        s.lostStrategic[State.key(t)] = true
        expect.eq(Structures.strategicAt(s, t), nil)
    end)
end)

describe("state: vật liệu và dữ liệu mới", function()
    it("người chơi có đủ vật liệu = 0 và carry rỗng", function()
        local s = newGame(7, 3)
        for _, p in ipairs(s.players) do
            for _, k in ipairs({ "alloy", "paper", "steel", "silk", "bond" }) do expect.eq(p.res[k], 0) end
            expect.eq(next(p.carry), nil)
        end
    end)

    it("bất biến bắt được vật liệu âm và occupied lệch", function()
        local s = newGame(7, 2)
        s.players[1].res.steel = -1
        local ok = Sim.invariants(s)
        expect.falsy(ok)
        s.players[1].res.steel = 0
        s.occupied["1,1"] = 99
        ok = Sim.invariants(s)
        expect.falsy(ok)
    end)
end)

describe("upkeep + prompt", function()
    it("bước upkeep đăng ký chạy khi đổ xúc xắc, trước khi đổ", function()
        local s = newGame(9, 2)
        local calls, seenPid = 0, nil
        local n0 = #Upkeep.steps
        Upkeep.register(function(state, pid, events)
            calls = calls + 1
            seenPid = pid
            events[#events + 1] = { kind = "test_upkeep", pid = pid }
        end)
        local actor = Game.actor(s)
        local ev = Game.apply(s, { type = "roll" })
        Upkeep.steps[#Upkeep.steps] = nil
        expect.eq(#Upkeep.steps, n0)
        expect.eq(calls, 1); expect.eq(seenPid, actor)
        expect.eq(ev[1].kind, "test_upkeep")
    end)

    it("lời nhắc: người trả lời là actor, legal chỉ gồm respond, trả lời xong quay về phase cũ", function()
        local s = newGame(9, 2)
        s.phase = "action"
        local seen
        Game.prompts.test_ask = {
            check = function(state, p, choice) return true end,
            apply = function(state, p, choice, events)
                seen = choice
                events[#events + 1] = { kind = "test_answer", choice = choice }
            end,
        }
        Game.openPrompt(s, { kind = "test_ask", pid = 2, options = { "yes", "no" } })
        expect.eq(s.phase, "prompt")
        expect.eq(Game.actor(s), 2)
        local legal = Game.legal(s)
        expect.eq(#legal, 2)
        for _, c in ipairs(legal) do expect.eq(c.type, "respond") end
        expect.falsy(Game.check(s, { type = "endTurn" }))
        expect.falsy(Game.check(s, { type = "respond", choice = "maybe" }))
        Game.apply(s, { type = "respond", choice = "no" })
        Game.prompts.test_ask = nil
        expect.eq(seen, "no")
        expect.eq(s.phase, "action")
        expect.eq(s.prompt, false)
    end)

    it("kind chưa đăng ký bị từ chối", function()
        local s = newGame(9, 2)
        expect.error(function() Game.openPrompt(s, { kind = "khong_co", pid = 1, options = { "x" } }) end)
    end)
end)

describe("save v3", function()
    it("save/load giữ nguyên công trình, occupied, lostStrategic", function()
        local s = newGame(21, 2)
        local t = s.map.list[12]
        Structures.place(s, { id = "B-01", level = 2, owner = 1 }, { t, s.map.list[13] })
        s.lostStrategic["3,3"] = true
        local s2 = reload(s)   -- công trình C2 hai ô đặt tay không qua được kiểm tra của Game.load
        expect.eq(Structures.at(s2, t).level, 2)
        expect.eq(#Structures.at(s2, t).tiles, 2)
        expect.eq(s2.nextUid, s.nextUid)
        expect.truthy(s2.lostStrategic["3,3"])
    end)

    it("nạp save v2 cũ: công trình theo ô được nâng lên uid, thêm vật liệu", function()
        local s = newGame(21, 2)
        local plains = {}   -- Đồng Bằng hợp lệ cho cả B-01 và B-04; map sinh lại giống hệt khi nạp
        for _, t in ipairs(s.map.list) do
            if t.terrain == "DH-01" and not t.settlement and not t.landmark then plains[#plains + 1] = t end
        end
        local a, b = plains[10], plains[20]
        s.owner[State.key(a)], s.owner[State.key(b)] = 1, 2
        s.votes[State.key(a)], s.votes[State.key(b)] = { [1] = 9 }, { [2] = 9 }   -- đủ ngưỡng cho bất biến
        Structures.place(s, { id = "B-01", level = 1, owner = 1 }, { a })
        Structures.place(s, { id = "B-04", level = 1, owner = 2 }, { b })
        local data = assert(Serialize.load(Game.save(s)))
        local st = data.state
        local old = {}
        for _, bd in pairs(st.buildings) do old[bd.anchor] = { id = bd.id, level = bd.level, owner = bd.owner } end
        st.buildings = old
        st.occupied, st.nextUid, st.lostStrategic, st.units, st.roads = nil, nil, nil, nil, nil
        for _, p in ipairs(st.players) do
            for _, k in ipairs({ "alloy", "paper", "steel", "silk", "bond" }) do p.res[k] = nil end
            p.carry = nil
        end
        data.version = 2

        local s2 = assert(Game.load(Serialize.dump(data)))
        local b1, b2 = Structures.at(s2, a), Structures.at(s2, b)
        expect.eq(b1.id, "B-01"); expect.eq(b1.owner, 1)
        expect.eq(b2.id, "B-04"); expect.eq(b2.level, 1)
        expect.truthy(b1.uid ~= b2.uid)
        expect.eq(s2.players[1].res.steel, 0)
        expect.eq(next(s2.lostStrategic), nil)
        expect.truthy(Sim.invariants(s2))
        expect.eq(C.SAVE_VERSION, 4)
    end)
end)
