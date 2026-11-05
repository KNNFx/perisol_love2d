local C         = require("src.config.constants")
local Game      = require("src.core.game")
local Movement  = require("src.data.movement")
local Rebel     = require("src.core.rebel")
local Rounds    = require("src.core.rounds")
local Sim       = require("src.core.sim")
local State     = require("src.core.state")
local Territory = require("src.core.territory")

describe("rounds: N = 10 x số người chơi (GDD 1.6 §11.3)", function()
    it("mặc định 10 / 20 / 30 / 40 vòng; N hợp lệ là bội của 10", function()
        for players = 1, 4 do expect.eq(Rounds.defaultFor(players), 10 * players) end
        expect.truthy(Rounds.valid(10)); expect.truthy(Rounds.valid(60)); expect.truthy(Rounds.valid(100))
        expect.falsy(Rounds.valid(0)); expect.falsy(Rounds.valid(15)); expect.falsy(Rounds.valid(-10)); expect.falsy(Rounds.valid("20"))
        expect.error(function() Game.new({ seed = 1, players = 2, rounds = 15 }) end)
        expect.eq(Game.new({ seed = 1, players = 3 }).rounds, 30)
        expect.eq(Game.new({ seed = 1, players = 2, rounds = 50 }).rounds, 50)
    end)

    it("mốc ghi cho ván 20 vòng quy đổi theo ceil(mốc x N / 20)", function()
        local s20, s40, s10 = { rounds = 20 }, { rounds = 40 }, { rounds = 10 }
        expect.eq(Rounds.scale(s20, C.HQ_C4_MIN_ROUND), 11)
        expect.eq(Rounds.scale(s40, C.HQ_C4_MIN_ROUND), 22)
        expect.eq(Rounds.scale(s10, C.HQ_C4_MIN_ROUND), 6)       -- ceil(5.5)
        expect.eq(Rounds.scale(s40, C.SUB_C3_MIN_ROUND), 32)
        expect.eq(Rounds.scale(s10, C.REBEL_MOUNTAIN_LOCK_ROUNDS), 5)
        expect.eq(Rounds.scale({}, C.HQ_C4_MIN_ROUND), 11, "state cũ không có rounds coi như 20 vòng")
    end)

    it("Sự Kiện Tổng lật mỗi 5 vòng tới vòng cuối; mức khốc liệt ceil(4 x vòng / N)", function()
        local s = { rounds = 40 }
        expect.truthy(Rounds.isEventRound(s, 5)); expect.truthy(Rounds.isEventRound(s, 40))
        expect.falsy(Rounds.isEventRound(s, 7)); expect.falsy(Rounds.isEventRound(s, 45)); expect.falsy(Rounds.isEventRound(s, 0))
        local t20 = { rounds = 20 }
        for round, tier in pairs({ [5] = 1, [10] = 2, [15] = 3, [20] = 4 }) do expect.eq(Rounds.eventTier(t20, round), tier) end
        expect.eq(Rounds.eventTier(s, 5), 1); expect.eq(Rounds.eventTier(s, 15), 2); expect.eq(Rounds.eventTier(s, 40), 4)
    end)

    it("khóa Núi của Phiến Quân và mốc nâng HQ/Sub theo số vòng của ván", function()
        local s = Game.new({ seed = 3, players = 2, rounds = 40 })
        while s.phase == "setup_hq" do Game.apply(s, Game.legal(s)[1]) end
        expect.eq(Rebel.stepCost(s, "DH-03"), math.huge)
        s.round = 20
        expect.eq(Rebel.stepCost(s, "DH-03"), math.huge, "ván 40 vòng: khóa 20 vòng")
        s.round = 21
        expect.eq(Rebel.stepCost(s, "DH-03"), C.REBEL_MOUNTAIN_COST)
        local s20 = Game.new({ seed = 3, players = 2 })
        s20.round = 11
        expect.eq(Rebel.stepCost(s20, "DH-12"), C.REBEL_MOUNTAIN_COST)
        s.players[1].hqLevel = 3
        s.round = 21
        local ok, why = Territory.canUpgradeHQ({ round = 21, rounds = 40, players = s.players, map = s.map, owner = s.owner,
                                                  buildings = s.buildings, occupied = s.occupied, lostStrategic = s.lostStrategic, roads = s.roads, units = s.units }, 1)
        expect.falsy(ok)
    end)

    it("ván 40 vòng cho 4 người; ván 1 người 10 vòng; custom 30 vòng cho 2 người chạy hết, bất biến đúng", function()
        local a = Sim.play(41, 1)
        expect.eq(a.rounds, 10); expect.eq(a.round, 11)
        local b = Sim.play(42, 2, { rounds = 30 })
        expect.eq(b.rounds, 30); expect.eq(b.round, 31)
        expect.truthy(Sim.invariants(b))
    end)

    it("lưu / nạp giữ nguyên số vòng; replay với rounds cho state giống hệt", function()
        local s = Game.new({ seed = 9, players = 2, rounds = 50 })
        Sim.advance(s, 120, 5)
        local back = assert(Game.load(Game.save(s)))
        expect.eq(back.rounds, 50)
        local again = Game.replay(s.seed, s.playerCount, s.history, s.rounds)
        expect.deepEq(State.snapshot(again), State.snapshot(s))
    end)

    it("hết ván đúng sau N vòng của từng ván", function()
        for _, case in ipairs({ { 1, 10 }, { 2, 20 }, { 2, 10 } }) do
            local s = Game.new({ seed = 70, players = case[1], rounds = case[2] })
            while s.phase == "setup_hq" do Game.apply(s, Game.legal(s)[1]) end
            local turns = 0
            while s.phase ~= "over" do
                local guard = 0
                while s.phase ~= "action" do guard = guard + 1; assert(guard < 100); Game.apply(s, Game.legal(s)[1]) end
                Game.apply(s, { type = "endTurn" }); turns = turns + 1
            end
            expect.eq(turns, case[2] * case[1])
        end
    end)
end)
