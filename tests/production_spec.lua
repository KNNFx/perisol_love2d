local Mapgen     = require("src.core.mapgen")
local State      = require("src.core.state")
local Production = require("src.core.production")

-- State 3 người trên map 32x16, không TN; trả state + hàm đặt công trình tại tile bất kỳ.
local function newState()
    local map = Mapgen.generate({ seed = 11, players = 4 })
    for _, t in ipairs(map.list) do t.strategic = nil end
    local s = State.new(map, 3, 11)
    local function put(i, id, level, pid)
        local t = map.list[i]
        s.buildings[State.key(t)] = { id = id, level = level or 1, owner = pid }
        return t
    end
    return s, put
end

local function sum(events, pid, res)
    local n = 0
    for _, e in ipairs(events) do
        if e.kind == "produce" and e.pid == pid and (not res or e.res == res) then n = n + e.amount end
    end
    return n
end

describe("production: Long Mạch", function()
    it("chia sẻ: P1 đổ ra KT thì Trại Khai Thác của P2 cũng nhận", function()
        local s, put = newState()
        put(10, "B-01", 1, 2)
        local ev = Production.run(s, { 3, 1 }, 1)
        expect.eq(sum(ev, 2, "engineering"), 1)
        expect.eq(s.players[2].res.engineering, 1)
        expect.eq(s.players[1].res.engineering, 0)
    end)

    it("hai viên cùng khớp thì nhân đôi; công trình khác mặt không sản xuất", function()
        local s, put = newState()
        put(10, "B-01", 1, 1)
        put(11, "B-02", 1, 1)
        local ev = Production.run(s, { 3, 3 }, 2)
        expect.eq(sum(ev, 1, "engineering"), 2)
        expect.eq(sum(ev, 1, "science"), 0)
    end)

    it("C2/C3 theo bảng Data: 2 KT ra KT, +1 KT khi ra KH", function()
        local s, put = newState()
        put(10, "B-01", 2, 1)
        expect.eq(sum(Production.compute(s, { 3, 5 }, 1), 1, "engineering"), 2)
        expect.eq(sum(Production.compute(s, { 1, 5 }, 1), 1, "engineering"), 1)
        s.buildings[State.key(s.map.list[10])].level = 3
        expect.eq(sum(Production.compute(s, { 3, 3 }, 1), 1, "engineering"), 6)
        expect.eq(sum(Production.compute(s, { 1, 2 }, 1), 1, "engineering"), 2)
    end)

    it("mặt Hex chỉ cho người đang lượt phiếu Chi Phối, không sản xuất", function()
        local s, put = newState()
        put(10, "B-01", 1, 2)
        local ev = Production.run(s, { 6, 6 }, 3)
        expect.eq(s.players[3].votes, 2)
        expect.eq(s.players[1].votes, 0)
        expect.eq(s.players[2].votes, 0)
        expect.eq(sum(ev, 2), 0)
        ev = Production.run(s, { 6, 3 }, 1)
        expect.eq(s.players[1].votes, 1)
        expect.eq(s.players[2].res.engineering, 1)
    end)

    it("tổng 7 (1+6, 2+5, 3+4): không ai nhận gì, kể cả phiếu Hex", function()
        for _, d in ipairs({ { 1, 6 }, { 2, 5 }, { 3, 4 } }) do
            local s, put = newState()
            put(10, "B-01", 1, 1); put(11, "B-02", 1, 2); put(12, "B-03", 1, 3)
            local ev = Production.run(s, d, 1)
            expect.eq(#ev, 1)
            expect.eq(ev[1].kind, "seven")
            for pid = 1, 3 do
                expect.eq(s.players[pid].votes, 0)
                for _, v in pairs(s.players[pid].res) do expect.eq(v, 0) end
            end
        end
    end)

    it("công trình trong vùng phong tỏa không sản xuất", function()
        local s, put = newState()
        local t = put(40, "B-01", 1, 2)
        s.rebel = { q = t.q, r = t.r }
        expect.eq(sum(Production.compute(s, { 3, 1 }, 1), 2), 0)
        s.rebel = nil
        expect.eq(sum(Production.compute(s, { 3, 1 }, 1), 2), 1)
    end)
end)

describe("production: bonus tài nguyên chiến lược", function()
    it("TN-05: +2 KT mỗi viên ra KT; TN-01: +1", function()
        local s, put = newState()
        local t = put(10, "B-01", 1, 1)
        t.strategic = "TN-05"
        expect.eq(sum(Production.compute(s, { 3, 1 }, 1), 1, "engineering"), 3)
        expect.eq(sum(Production.compute(s, { 3, 3 }, 1), 1, "engineering"), 6)
        t.strategic = "TN-01"
        expect.eq(sum(Production.compute(s, { 3, 1 }, 1), 1, "engineering"), 2)
    end)

    it("bonus chỉ cộng khi dòng sản xuất đúng mặt và đúng tài nguyên", function()
        local s, put = newState()
        local t = put(10, "B-02", 2, 1)   -- C2 Viện NC: ra KT cho 1 KH (không phải KT)
        t.strategic = "TN-05"
        expect.eq(sum(Production.compute(s, { 3, 1 }, 1), 1, "engineering"), 0)
        expect.eq(sum(Production.compute(s, { 3, 1 }, 1), 1, "science"), 1 + 2)   -- 1 (ra KT) + 2 (ra KH, 1 viên)
    end)

    it("TN-03 chỉ cho Khu Chợ; TN-06 cho Vàng; TN-08 +1 mọi dòng", function()
        local s, put = newState()
        local t = put(10, "B-05", 1, 1)
        t.strategic = "TN-03"
        expect.eq(sum(Production.compute(s, { 5, 1 }, 1), 1, "gold"), 3)
        t.strategic = "TN-06"
        expect.eq(sum(Production.compute(s, { 5, 1 }, 1), 1, "gold"), 4)
        local t2 = put(11, "B-03", 1, 1)
        t2.strategic = "TN-03"                 -- không phải Khu Chợ -> không bonus
        expect.eq(sum(Production.compute(s, { 2, 1 }, 1), 1, "culture"), 1)
        t2.strategic = "TN-08"
        expect.eq(sum(Production.compute(s, { 2, 2 }, 1), 1, "culture"), 4)
    end)
end)

describe("production: hiệu ứng địa hình (GDD §3.1)", function()
    it("Lãnh Nguyên: Vàng −1 sản lượng; Sa Mạc: không ra Tín Ngưỡng", function()
        local s, put = newState()
        local market = put(10, "B-05", 1, 1)
        market.terrain = "DH-06"
        expect.eq(sum(Production.compute(s, { 5, 1 }, 1), 1, "gold"), 0)
        market.terrain = "DH-01"
        expect.eq(sum(Production.compute(s, { 5, 1 }, 1), 1, "gold"), 1)

        local temple = put(11, "B-04", 1, 1)
        temple.terrain = "DH-07"
        expect.eq(sum(Production.compute(s, { 4, 1 }, 1), 1, "faith"), 0)
        temple.terrain = "DH-01"
        expect.eq(sum(Production.compute(s, { 4, 1 }, 1), 1, "faith"), 1)
    end)
end)
