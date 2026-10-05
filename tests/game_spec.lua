local C        = require("src.config.constants")
local Hex      = require("src.core.hex")
local Game     = require("src.core.game")
local Scoring  = require("src.core.scoring")
local Serialize = require("src.core.serialize")
local State    = require("src.core.state")
local Rebel    = require("src.core.rebel")
local Save     = require("src.save")

-- Đặt HQ cho mọi người theo thứ tự (chọn vùng khởi đầu đầu tiên còn trống).
local function setup(seed, players)
    local s = Game.new({ seed = seed, players = players })
    while s.phase == "setup_hq" do Game.apply(s, Game.legal(s)[1]) end
    return s
end

-- Chạy tới khi tới pha action (xử lý cả Phiến Quân bằng lệnh đầu tiên hợp lệ).
local function toAction(s)
    local guard = 0
    while s.phase ~= "action" do
        guard = guard + 1
        assert(guard < 200 and s.phase ~= "over")
        Game.apply(s, Game.legal(s)[1])
    end
end

local function find(s, type_)
    for _, cmd in ipairs(Game.legal(s)) do
        if cmd.type == type_ then return cmd end
    end
end

describe("game: setup", function()
    it("thứ tự lượt là hoán vị của mọi người chơi, tất định theo seed", function()
        for players = 1, 4 do
            local s = Game.new({ seed = 3, players = players })
            local seen = {}
            for _, pid in ipairs(s.order) do seen[pid] = true end
            expect.eq(#s.order, players)
            for pid = 1, players do expect.truthy(seen[pid]) end
            expect.deepEq(Game.new({ seed = 3, players = players }).order, s.order)
        end
    end)

    it("mỗi người chọn một vùng khởi đầu; xong thì có Phiến Quân và sang pha roll", function()
        local s = Game.new({ seed = 5, players = 3 })
        expect.eq(s.phase, "setup_hq")
        local first = s.order[1]
        expect.eq(Game.actor(s), first)
        expect.eq(#Game.legal(s), 3)
        Game.apply(s, { type = "placeHQ", start = 2 })
        expect.eq(Game.actor(s), s.order[2])
        expect.eq(#Game.legal(s), 2)
        expect.falsy(Game.check(s, { type = "placeHQ", start = 2 }))   -- đã bị chọn
        Game.apply(s, Game.legal(s)[1]); Game.apply(s, Game.legal(s)[1])

        expect.eq(s.phase, "roll")
        expect.eq(s.round, 1); expect.eq(s.turn, 1)
        expect.truthy(s.rebel)
        for pid = 1, 3 do
            local p = s.players[pid]
            expect.truthy(p.hq)
            for k, v in pairs(C.STARTING_RESOURCES) do expect.eq(p.res[k], v) end
            local owned = 0
            for _, t in ipairs(s.map.list) do if s.owner[State.key(t)] == pid then owned = owned + 1 end end
            expect.eq(owned, 7)
            expect.truthy(Hex.distance(p.hq, s.rebel) >= C.REBEL_SPAWN_MIN_HQ_DIST)
        end
        expect.eq(Game.actor(s), s.order[1])
    end)

    it("từ chối lệnh sai người, sai pha, sai tham số", function()
        local s = Game.new({ seed = 5, players = 2 })
        local other = s.order[2]
        local ok, why = Game.check(s, { type = "placeHQ", start = 1, pid = other })
        expect.falsy(ok); expect.eq(why, "Chưa tới lượt của bạn")
        expect.falsy(Game.check(s, { type = "roll" }))
        expect.falsy(Game.check(s, { type = "placeHQ", start = 99 }))
        expect.falsy(Game.check(s, { type = "nope" }))
        expect.error(function() Game.apply(s, { type = "roll" }) end)
    end)
end)

describe("game: vòng chơi", function()
    it("roll sản xuất hoặc kích hoạt Phiến Quân; endTurn xoay lượt", function()
        local s = setup(8, 2)
        local sevens, rolls = 0, 0
        for _ = 1, 40 do
            toAction(s)
            expect.truthy(s.dice)
            expect.eq(Game.actor(s), s.order[s.turn])
            local before = s.turn
            Game.apply(s, { type = "endTurn" })
            if s.phase == "over" then break end
            expect.eq(s.turn, before % 2 + 1)
        end
        for _, e in ipairs(s.log) do
            if e.kind == "seven" then sevens = sevens + 1 end
            if e.kind == "roll" then rolls = rolls + 1 end
        end
        expect.eq(rolls, 40)
        expect.truthy(sevens >= 1, "40 lượt đổ phải có ít nhất một lần ra 7")
        expect.truthy(sevens < rolls)
    end)

    it("đủ 20 vòng thì kết thúc ở pha over; vòng và lượt đúng", function()
        for players = 1, 4 do
            local s = setup(20 + players, players)
            local turns = 0
            while s.phase ~= "over" do
                toAction(s)
                Game.apply(s, { type = "endTurn" })
                turns = turns + 1
            end
            expect.eq(turns, C.ROUNDS_PER_GAME * players)
            expect.eq(s.round, C.ROUNDS_PER_GAME + 1)
            expect.eq(Game.actor(s), nil)
            expect.eq(#Game.legal(s), 0)
            expect.falsy(Game.check(s, { type = "endTurn" }))
        end
    end)

    it("mốc Sự Kiện Tổng (vòng 5/10/15/20) được ghi nhận ở lượt đầu vòng", function()
        local s = setup(9, 2)
        while s.phase ~= "over" do
            toAction(s)
            Game.apply(s, { type = "endTurn" })
        end
        local rounds = {}
        for _, e in ipairs(s.log) do
            if e.kind == "global_event" then rounds[#rounds + 1] = e.round end
        end
        expect.deepEq(rounds, C.EVENT_ROUNDS)
    end)

    it("mọi lệnh trong legal() đều qua check()", function()
        local s = setup(14, 3)
        for _ = 1, 60 do
            if s.phase == "over" then break end
            for _, cmd in ipairs(Game.legal(s)) do
                local ok, why = Game.check(s, cmd)
                expect.truthy(ok, cmd.type .. ": " .. tostring(why))
            end
            local legal = Game.legal(s)
            Game.apply(s, legal[#legal > 1 and 2 or 1])
        end
    end)
end)

describe("game: hành động", function()
    it("mua phiếu, đổi tài nguyên 4:1, xây C1 đúng chi phí", function()
        local s = setup(31, 2)
        toAction(s)
        local pid = Game.actor(s)
        local res = s.players[pid].res

        res.culture, res.gold = 3, 6
        Game.apply(s, { type = "buyVote" })
        expect.eq(s.players[pid].votes >= 1, true)
        expect.eq(res.culture, 2); expect.eq(res.gold, 5)

        res.science = 4
        local sci, eng = res.science, res.engineering
        Game.apply(s, { type = "trade", give = "science", get = "engineering" })
        expect.eq(res.science, sci - C.BANK_TRADE_RATE)
        expect.eq(res.engineering, eng + 1)
        res.science = 3
        expect.falsy(Game.check(s, { type = "trade", give = "science", get = "gold" }))
        expect.falsy(Game.check(s, { type = "trade", give = "gold", get = "gold" }))

        res.engineering, res.gold = 5, 5
        local build = find(s, "build")
        expect.truthy(build, "phải có ô xây được trong vùng nhà")
        local def = require("src.data.buildings").level(build.id, 1)
        local before = {}
        for k, v in pairs(res) do before[k] = v end
        Game.apply(s, build)
        for k, n in pairs(def.cost) do expect.eq(res[k], before[k] - n) end
        local b = s.buildings[State.key(build)]
        expect.eq(b.id, build.id); expect.eq(b.owner, pid); expect.eq(b.level, 1)
        expect.falsy(Game.check(s, build), "không xây chồng lên công trình")
    end)

    it("không xây khi thiếu tiền, ngoài lãnh thổ, sai địa hình", function()
        local s = setup(31, 2)
        toAction(s)
        local pid = Game.actor(s)
        local p = s.players[pid]
        for k in pairs(p.res) do p.res[k] = 0 end
        local build = Game.legal(s)[1]
        expect.eq(build.type, "endTurn")
        for k in pairs(p.res) do p.res[k] = 20 end
        local far = s.map.list[1]
        local ok, why = Game.buildCheck(s, pid, "B-01", far)
        expect.falsy(ok); expect.eq(why, "Chỉ xây được trên lãnh thổ thực hữu của bạn")
        local hq = s.map:get(p.hq.q, p.hq.r)
        ok, why = Game.buildCheck(s, pid, "B-01", hq)
        expect.falsy(ok); expect.eq(why, "Ô đã có công trình")
    end)

    it("đặt phiếu và chiếm ô qua lệnh placeVote", function()
        local s = setup(33, 2)
        toAction(s)
        local pid = Game.actor(s)
        s.players[pid].votes = 6
        local target = find(s, "placeVote")
        expect.truthy(target, "phải có ô để đặt phiếu")
        local tile = s.map:get(target.q, target.r)
        local claimed = 0
        for _ = 1, C.CHI_PHOI_THRESHOLD[3] do
            if not Game.check(s, target) then break end
            for _, e in ipairs(Game.apply(s, target)) do
                if e.kind == "claim" then claimed = claimed + 1 end
            end
        end
        expect.eq(claimed, 1)
        expect.eq(s.owner[State.key(tile)], pid)
        expect.truthy(s.players[pid].votes >= 3 and s.players[pid].votes < 6)
    end)

    it("ra 7: Phiến Quân do người đổ điều khiển, rồi tiếp tục sang pha action", function()
        -- tìm seed có ra 7 ở lượt đầu rồi kiểm tra luồng pha
        for seed = 1, 200 do
            local s = setup(seed, 2)
            local actor = Game.actor(s)
            local ev = Game.apply(s, { type = "roll" })
            if s.phase ~= "action" then
                expect.eq(s.phase, "rebel_move")
                expect.eq(Game.actor(s), actor)
                local guard = 0
                while s.phase == "rebel_move" do
                    Game.apply(s, Game.legal(s)[1]); guard = guard + 1
                    expect.truthy(guard <= 6)
                end
                if s.phase == "rebel_loss" then
                    expect.eq(Game.actor(s), s.rebel.pending.owner)
                    Game.apply(s, Game.legal(s)[1])
                end
                expect.eq(s.phase, "action")
                expect.eq(Game.actor(s), actor)
                expect.eq(Rebel.stage(s), nil)
                return
            end
        end
        error("không tìm được seed ra 7 ở lượt đầu trong 200 seed")
    end)
end)

describe("game: lưu / nạp / phát lại", function()
    local function play(s, n)
        for i = 1, n do
            if s.phase == "over" then break end
            local legal = Game.legal(s)
            Game.apply(s, legal[(i * 7) % #legal + 1])
        end
    end

    it("save rồi load cho state giống hệt và chơi tiếp giống hệt", function()
        local s = setup(40, 3)
        play(s, 80)
        local back = assert(Game.load(Game.save(s)))
        expect.deepEq(State.snapshot(back), State.snapshot(s))
        play(s, 60); play(back, 60)
        expect.deepEq(State.snapshot(back), State.snapshot(s))
    end)

    it("replay từ seed + lịch sử lệnh cho state giống hệt", function()
        local s = setup(41, 4)
        play(s, 120)
        local again = Game.replay(s.seed, s.playerCount, s.history)
        expect.deepEq(State.snapshot(again), State.snapshot(s))
    end)

    it("load từ chối dữ liệu hỏng / version mới / thiếu trường", function()
        expect.eq(Game.load("rác"), nil)
        expect.eq(Game.load("return 5"), nil)
        local s = setup(42, 2)
        local data = Serialize.load(Game.save(s))
        data.version = C.SAVE_VERSION + 1
        local state, err = Game.load(Serialize.dump(data))
        expect.eq(state, nil); expect.truthy(err)
        data.version = C.SAVE_VERSION
        data.state.phase = "bậy"
        expect.eq(Game.load(Serialize.dump(data)), nil)
        data.state.phase = "roll"; data.state.players = {}
        expect.eq(Game.load(Serialize.dump(data)), nil)
    end)

    it("Save.write/read khứ hồi và dùng .bak khi bản chính hỏng", function()
        local name = "test_m1_spec"
        Save.remove(name)
        local s = setup(43, 2)
        local ok = Save.write(name, s)
        expect.truthy(ok)
        local back = assert(Save.read(name))
        expect.deepEq(State.snapshot(back), State.snapshot(s))

        toAction(s)                                   -- đổi state rồi ghi lần 2 -> bản cũ thành .bak
        expect.truthy(Save.write(name, s))
        love.filesystem.write(name .. ".sav", "hỏng")
        local recovered, err, usedBackup = Save.read(name)
        expect.truthy(recovered, tostring(err))
        expect.truthy(usedBackup)
        Save.remove(name)
        expect.falsy(Save.exists(name))
        expect.eq((Save.read(name)), nil)
    end)
end)

describe("scoring", function()
    it("điểm theo ô, Danh Thắng (đủ mọi ô), công trình C2+, tài nguyên dư", function()
        local s = setup(50, 2)
        for pid = 1, 2 do for k in pairs(s.players[pid].res) do s.players[pid].res[k] = 0 end end
        local base = Scoring.score(s)
        expect.eq(base[1].tiles, 7); expect.eq(base[1].total, 7)

        s.players[1].res.gold = 12                      -- 2 điểm (12 // 5)
        local lm = s.map.landmarks[1]
        for _, t in ipairs(lm.tiles) do s.owner[State.key(t)] = 1 end
        s.buildings["0,0"] = { id = "B-01", level = 2, owner = 1 }
        s.buildings["1,0"] = { id = "B-01", level = 1, owner = 1 }   -- C1 không tính
        local sc = Scoring.score(s)
        expect.eq(sc[1].resources, 2)
        expect.eq(sc[1].landmarks, C.SCORE_LANDMARK)
        expect.eq(sc[1].buildings, C.SCORE_BUILDING_C2)
        expect.eq(sc[1].tileCount, 7 + #lm.tiles)

        -- thiếu một ô của Danh Thắng thì không tính
        if #lm.tiles > 1 then
            s.owner[State.key(lm.tiles[1])] = nil
            expect.eq(Scoring.score(s)[1].landmarks, 0)
        end
    end)

    it("xếp hạng: điểm, rồi ô thực hữu, rồi tài nguyên; hòa hết thì đồng hạng", function()
        local s = setup(51, 3)
        for pid = 1, 3 do for k in pairs(s.players[pid].res) do s.players[pid].res[k] = 0 end end
        local r = Scoring.ranking(s)
        expect.eq(r[1].rank, 1); expect.eq(r[2].rank, 1); expect.eq(r[3].rank, 1)   -- cùng 7 ô, 0 tài nguyên

        s.players[3].res.gold = 5                       -- +1 điểm
        r = Scoring.ranking(s)
        expect.eq(r[1].pid, 3); expect.eq(r[1].rank, 1); expect.eq(r[2].rank, 2)

        s.players[3].res.gold = 0
        s.players[2].res.gold = 3                       -- cùng điểm, nhiều tài nguyên hơn
        r = Scoring.ranking(s)
        expect.eq(r[1].pid, 2); expect.eq(r[1].total, r[2].total); expect.eq(r[2].rank, 2)
    end)
end)
