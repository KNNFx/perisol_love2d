local C         = require("src.config.constants")
local Hex       = require("src.core.hex")
local Mapgen    = require("src.core.mapgen")
local State     = require("src.core.state")
local Territory = require("src.core.territory")

-- State 2 người trên map 32x16: HQ1 ở giữa, HQ2 cách 4 ô theo hướng Đông. Xóa TN để ngưỡng thuần.
local function twoPlayerState()
    local map = Mapgen.generate({ seed = 7, players = 4 })
    for _, t in ipairs(map.list) do t.strategic = nil end
    local s = State.new(map, 2, 7)
    local c = Hex.fromOffset(12, 8)
    Territory.placeHQ(s, 1, map:get(c.q, c.r))
    Territory.placeHQ(s, 2, map:get(c.q + 4, c.r))
    return s
end

local function tileAtDistance(s, pid, d)
    local hq = s.players[pid].hq
    for _, h in ipairs(Hex.ring(hq, d)) do
        local t = s.map:get(h.q, h.r)
        if t then return t end
    end
end

describe("territory: nhà và ngưỡng", function()
    it("HQ + 6 ô kề là lãnh thổ thực hữu ngay", function()
        local s = twoPlayerState()
        expect.eq(#Territory.ownedTiles(s, 1), 7)
        expect.eq(#Territory.ownedTiles(s, 2), 7)
        local hq = s.players[1].hq
        expect.eq(Territory.ownerOf(s, s.map:get(hq.q, hq.r)), 1)
        expect.eq(Territory.statusOf(s, s.map:get(hq.q, hq.r)), "owned")
    end)

    it("ngưỡng 1 / 2 / 3 theo khoảng cách tới HQ (3+ giữ nguyên 3)", function()
        local s = twoPlayerState()
        expect.eq(Territory.threshold(s, 1, tileAtDistance(s, 1, 1)), 1)
        expect.eq(Territory.threshold(s, 1, tileAtDistance(s, 1, 2)), 2)
        expect.eq(Territory.threshold(s, 1, tileAtDistance(s, 1, 3)), 3)
        expect.eq(Territory.threshold(s, 1, tileAtDistance(s, 1, 5)), 3)
    end)

    it("TN-06 giảm ngưỡng 1 nhưng không dưới 1", function()
        local s = twoPlayerState()
        local t2, t1 = tileAtDistance(s, 1, 2), tileAtDistance(s, 1, 1)
        t2.strategic, t1.strategic = "TN-06", "TN-06"
        expect.eq(Territory.threshold(s, 1, t2), 1)
        expect.eq(Territory.threshold(s, 1, t1), 1)
    end)
end)

describe("territory: đặt phiếu", function()
    it("từ chối khi hết phiếu, ô xa, ô nhà đối thủ, công trình đối thủ, phong tỏa", function()
        local s = twoPlayerState()
        local near = tileAtDistance(s, 1, 2)
        local ok, why = Territory.canVote(s, 1, near)
        expect.falsy(ok); expect.eq(why, "Không còn phiếu Chi Phối")

        s.players[1].votes = 10
        expect.truthy(Territory.canVote(s, 1, near))

        local far = tileAtDistance(s, 1, 5)
        ok, why = Territory.canVote(s, 1, far)
        expect.falsy(ok); expect.eq(why, "Ô phải kề lãnh thổ của bạn")

        local h2 = s.players[2].hq
        ok, why = Territory.canVote(s, 1, s.map:get(h2.q, h2.r))
        expect.falsy(ok); expect.eq(why, "Ô thuộc vùng nhà của đối thủ")

        s.buildings[State.key(near)] = { id = "B-01", level = 1, owner = 2 }
        ok, why = Territory.canVote(s, 1, near)
        expect.falsy(ok); expect.eq(why, "Ô có công trình của đối thủ")
        s.buildings[State.key(near)] = nil

        s.rebel = { q = near.q, r = near.r }
        ok, why = Territory.canVote(s, 1, near)
        expect.falsy(ok); expect.eq(why, "Ô đang bị Phiến Quân phong tỏa")
    end)

    it("2 phiếu ở khoảng cách 2: tranh chấp rồi thực hữu; phiếu bị trừ", function()
        local s = twoPlayerState()
        s.players[1].votes = 3
        local t = tileAtDistance(s, 1, 2)
        local before, after = Territory.addVote(s, 1, t)
        expect.eq(before, nil); expect.eq(after, nil)
        expect.eq(Territory.statusOf(s, t), "contested")
        expect.eq(s.players[1].votes, 2)
        before, after = Territory.addVote(s, 1, t)
        expect.eq(after, 1)
        expect.eq(Territory.statusOf(s, t), "owned")
        expect.eq(#Territory.ownedTiles(s, 1), 8)
        -- ô đã là của mình, không bị tranh -> không đặt thêm
        expect.falsy(Territory.canVote(s, 1, t))
    end)

    it("cướp ô: cần nhiều phiếu hơn hẳn, hòa thì chủ cũ giữ", function()
        local s = twoPlayerState()
        s.players[1].votes, s.players[2].votes = 5, 5
        -- ô giữa hai HQ, cách mỗi bên 2 ô
        local mid = Hex.line(s.players[1].hq, s.players[2].hq)[3]
        local t = s.map:get(mid.q, mid.r)
        expect.eq(Territory.threshold(s, 1, t), 2)
        expect.eq(Territory.threshold(s, 2, t), 2)

        Territory.addVote(s, 1, t); Territory.addVote(s, 1, t)
        expect.eq(Territory.ownerOf(s, t), 1)

        Territory.addVote(s, 2, t); Territory.addVote(s, 2, t)   -- 2 vs 2: hòa
        expect.eq(Territory.ownerOf(s, t), 1, "hòa phải giữ chủ cũ")
        expect.truthy(Territory.isDisputed(s, t))
        expect.truthy(Territory.canVote(s, 1, t), "chủ được phép đặt thêm để bảo vệ")

        Territory.addVote(s, 2, t)                                -- 3 vs 2: P2 vượt hẳn
        expect.eq(Territory.ownerOf(s, t), 2)
    end)

    it("người có nhiều phiếu nhưng chưa đạt ngưỡng không cướp được", function()
        local s = twoPlayerState()
        s.players[1].votes, s.players[2].votes = 5, 5
        local mid = Hex.line(s.players[1].hq, s.players[2].hq)[3]
        local t = s.map:get(mid.q, mid.r)
        Territory.addVote(s, 1, t); Territory.addVote(s, 1, t)   -- P1 chủ (2 phiếu)
        Territory.addVote(s, 2, t)                                -- P2 mới 1 phiếu
        expect.eq(Territory.ownerOf(s, t), 1)
    end)

    it("voteTargets chỉ trả ô hợp lệ", function()
        local s = twoPlayerState()
        expect.eq(#Territory.voteTargets(s, 1), 0)   -- chưa có phiếu
        s.players[1].votes = 1
        local targets = Territory.voteTargets(s, 1)
        expect.truthy(#targets > 0)
        for _, t in ipairs(targets) do
            expect.truthy(Territory.canVote(s, 1, t))
            expect.truthy(Territory.ownerOf(s, t) ~= 1 or Territory.isDisputed(s, t))
        end
    end)
end)
