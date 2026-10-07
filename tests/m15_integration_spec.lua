-- Kiểm tra tích hợp M1.5: replay tất định và lưu/nạp giữa ván với đủ các hệ thống (đơn vị, đường, Phái Sinh, Đặc Biệt...).

local Game       = require("src.core.game")
local Serialize  = require("src.core.serialize")
local Sim        = require("src.core.sim")
local State      = require("src.core.state")

describe("M1.5 tích hợp: replay và lưu/nạp", function()
    it("replay từ seed + lịch sử lệnh cho đúng state cuối của 12 ván mô phỏng (2-4 người)", function()
        for i = 1, 12 do
            local players = 2 + (i % 3)
            local state = Sim.play(100 + i, players)
            local again = Game.replay(state.seed, state.playerCount, state.history)
            expect.deepEq(State.snapshot(again), State.snapshot(state), "ván " .. i)
        end
    end)

    it("lưu giữa ván rồi nạp: tiếp tục cùng dãy lệnh cho state giống hệt (đủ tài nguyên để chạm nhiều hệ thống)", function()
        local s = Game.new({ seed = 21, players = 3 })     -- ván thật: bản đồ sinh lại từ seed khi nạp (không dùng state đã sửa bản đồ)
        local used = {}
        for step = 1, 12 do
            Sim.advance(s, 25, 21 + step)
            for p = 1, 3 do
                for k, v in pairs(s.players[p].res) do if k ~= "bond" then s.players[p].res[k] = math.max(v, 40) end end
            end
            local ok, why = Sim.invariants(s)
            expect.truthy(ok, why)
            local loaded = assert(Game.load(Game.save(s)))
            expect.deepEq(State.snapshot(loaded), State.snapshot(s), "ngay sau khi nạp, bước " .. step)
            Sim.advance(s, 30, 900 + step)
            Sim.advance(loaded, 30, 900 + step)
            expect.deepEq(State.snapshot(loaded), State.snapshot(s), "sau khi chơi tiếp, bước " .. step)
            for k in pairs(s.units) do used.units = true end
            for k in pairs(s.roads) do used.roads = true end
            if s.phase == "over" then break end
        end
        expect.truthy(used.units or used.roads, "ván phải có đơn vị hoặc đường để phép thử có ý nghĩa")
    end)

    it("save v3 chuỗi hóa ổn định: dump(load(dump(state))) == dump(state)", function()
        local s = Game.new({ seed = 9, players = 2 })
        Sim.advance(s, 200, 3)
        local text = Game.save(s)
        local again = Game.save(assert(Game.load(text)))
        expect.eq(again, text)
    end)

    it("lệnh trong history đều là dữ liệu thuần (serialize được, không có hàm/userdata)", function()
        local state = Sim.play(7, 3)
        local text = Serialize.dump({ history = state.history })
        local back = assert(Serialize.load(text))
        expect.eq(#back.history, #state.history)
    end)
end)
