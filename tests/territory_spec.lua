local C         = require("src.config.constants")
local Hex       = require("src.core.hex")
local Mapgen    = require("src.core.mapgen")
local State     = require("src.core.state")
local Structures = require("src.core.structures")
local Territory = require("src.core.territory")

-- State 2 người trên map 32x16: HQ1 ở giữa, HQ2 cách 4 ô theo hướng Đông.
-- Xóa TN, Khu Dân Cư, Danh Thắng và Tài Nguyên Cơ Bản quanh đó để luật thuần (các test cụm tự gán cờ).
local function twoPlayerState(level)
    local map = Mapgen.generate({ seed = 7, players = 4 })
    for _, t in ipairs(map.list) do
        t.strategic, t.settlement, t.landmark, t.base = nil, nil, nil, nil
        t.terrain = "DH-01"
    end
    local s = State.new(map, 2, 7)
    local c = Hex.fromOffset(12, 8)
    Territory.placeHQ(s, 1, map:get(c.q, c.r))
    Territory.placeHQ(s, 2, map:get(c.q + 4, c.r))
    for pid = 1, 2 do s.players[pid].hqLevel = level or 1 end
    return s
end

local function tileAtDistance(s, pid, d, dirIndex)
    local hq = s.players[pid].hq
    local ring = Hex.ring(hq, d)
    local h = ring[dirIndex or 1]
    return s.map:get(h.q, h.r)
end

-- Ô cách mỗi HQ đúng 2 ô (giữa hai Nhà Chính).
local function midTile(s)
    local mid = Hex.line(s.players[1].hq, s.players[2].hq)[3]
    return s.map:get(mid.q, mid.r)
end

describe("territory: HQ, vùng ảnh hưởng, ngưỡng", function()
    it("ô HQ và 6 ô quanh là thực hữu miễn phí ngay khi đặt (GDD 1.6 §7.3); ô xa hơn chưa", function()
        local s = twoPlayerState()
        expect.eq(#Territory.ownedTiles(s, 1), 7)
        local hq = s.map:get(s.players[1].hq.q, s.players[1].hq.r)
        expect.eq(Territory.ownerOf(s, hq), 1)
        for _, n in ipairs(s.map:neighbors(hq)) do
            expect.eq(Territory.ownerOf(s, n), 1)
            expect.truthy(Territory.votesOn(s, n, 1) >= Territory.threshold(s, 1, n), "phiếu ghi bằng ngưỡng")
        end
        expect.truthy(Territory.inInfluence(s, 1, tileAtDistance(s, 1, 1)))
        expect.falsy(Territory.inInfluence(s, 1, tileAtDistance(s, 1, 2)))
        expect.eq(Territory.ownerOf(s, tileAtDistance(s, 1, 2)), nil)
        expect.truthy(Territory.isAnchorTile(s, hq))
        expect.falsy(Territory.isAnchorTile(s, tileAtDistance(s, 1, 1)))
    end)

    it("nâng HQ lên C2 mở rộng vùng ảnh hưởng ra bán kính 2 (18 ô)", function()
        local s = twoPlayerState()
        expect.truthy(Territory.canUpgradeHQ(s, 1))
        Territory.upgradeHQ(s, 1)
        expect.eq(s.players[1].hqLevel, 2)
        expect.truthy(Territory.inInfluence(s, 1, tileAtDistance(s, 1, 2)))
        expect.falsy(Territory.inInfluence(s, 1, tileAtDistance(s, 1, 3)))
        local ok, why = Territory.canUpgradeHQ(s, 1)
        expect.falsy(ok); expect.eq(why, "Cần một Khu Chợ liền hoặc nối đường tới Nhà Chính")   -- C3 cần Khu Chợ nối HQ (phase F)
    end)

    it("ngưỡng 1 / 2 / 3 theo khoảng cách trong vùng ảnh hưởng; ngoài vùng +1 (d = 2: 3, d >= 3: 4)", function()
        local s = twoPlayerState(2)           -- C2: bán kính 2
        expect.eq(Territory.threshold(s, 1, tileAtDistance(s, 1, 1)), 1)
        expect.eq(Territory.threshold(s, 1, tileAtDistance(s, 1, 2)), 2)
        expect.eq(Territory.threshold(s, 1, tileAtDistance(s, 1, 3)), 3 + C.VOTE_OUTSIDE_BONUS)
        expect.eq(Territory.threshold(s, 1, tileAtDistance(s, 1, 5)), 3 + C.VOTE_OUTSIDE_BONUS)
        local s1 = twoPlayerState(1)          -- C1: bán kính 1, nên d = 2 đã là ngoài vùng
        expect.eq(Territory.threshold(s1, 1, tileAtDistance(s1, 1, 2)), 3)
        expect.eq(Territory.threshold(s1, 1, tileAtDistance(s1, 1, 3)), 4)
    end)

    it("TN-06 giảm ngưỡng 1 (áp dụng sau cùng) nhưng không dưới 1; ô trong cụm luôn cần 1 phiếu", function()
        local s = twoPlayerState(2)
        local t2, t3 = tileAtDistance(s, 1, 2), tileAtDistance(s, 1, 3)
        t2.strategic, t3.strategic = "TN-06", "TN-06"
        expect.eq(Territory.threshold(s, 1, t2), 1)
        expect.eq(Territory.threshold(s, 1, t3), 3, "3 + 1 ngoài vùng - 1")
        t3.strategic = nil
        expect.eq(Territory.threshold(s, 1, t3), 4)
        t3.settlement = 1
        expect.eq(Territory.threshold(s, 1, t3), C.CLUSTER_TILE_VOTES)
    end)
end)

describe("territory: đặt phiếu", function()
    it("từ chối: hết phiếu, ngoài tầm, ô HQ, phong tỏa, cụm ngoài vùng ảnh hưởng, ô của mình", function()
        local s = twoPlayerState()
        local near = tileAtDistance(s, 1, 2)         -- ngoài vùng ảnh hưởng C1 nhưng kề lãnh thổ của mình
        local ok, why = Territory.canVote(s, 1, near)
        expect.falsy(ok); expect.eq(why, "Không còn phiếu Chi Phối")

        s.players[1].votes = 10
        expect.truthy(Territory.canVote(s, 1, near), "mở rộng liền kề được phép")

        ok, why = Territory.canVote(s, 1, tileAtDistance(s, 1, 3))
        expect.falsy(ok); expect.eq(why, "Chỉ đặt phiếu trong vùng ảnh hưởng hoặc ô kề lãnh thổ của bạn")

        local cluster = tileAtDistance(s, 1, 2, 2)
        cluster.settlement = 1
        ok, why = Territory.canVote(s, 1, cluster)
        expect.falsy(ok); expect.eq(why, "Khu Dân Cư / Danh Thắng chỉ đặt phiếu trong vùng ảnh hưởng của bạn")
        cluster.settlement = nil

        local hq = s.map:get(s.players[1].hq.q, s.players[1].hq.r)
        ok, why = Territory.canVote(s, 1, hq)
        expect.falsy(ok); expect.eq(why, "Không đặt phiếu lên ô Nhà Chính / Khu Trực Thuộc")

        ok, why = Territory.canVote(s, 1, tileAtDistance(s, 1, 1))
        expect.falsy(ok); expect.eq(why, "Ô đã thuộc về bạn")

        s.rebel = { q = near.q, r = near.r }
        ok, why = Territory.canVote(s, 1, near)
        expect.falsy(ok); expect.eq(why, "Ô đang bị Phiến Quân phong tỏa")
    end)

    it("ô trong vùng ảnh hưởng cách 2 cần 2 phiếu (tranh chấp rồi thực hữu); ngoài vùng cần 3", function()
        local s = twoPlayerState(2)
        s.players[1].votes = 9
        local t2 = tileAtDistance(s, 1, 2, 3)
        Territory.addVote(s, 1, t2)
        expect.eq(Territory.statusOf(s, t2), "contested")
        Territory.addVote(s, 1, t2)
        expect.eq(Territory.statusOf(s, t2), "owned")
        expect.eq(#Territory.ownedTiles(s, 1), 8)
        expect.eq(s.players[1].votes, 7)

        local out, anchorTile                          -- d = 3: ngoài vùng ảnh hưởng C2, cần kề một ô thực hữu của mình
        for _, h in ipairs(Hex.ring(s.players[1].hq, 3)) do
            local cand = s.map:get(h.q, h.r)
            local touching = false
            for _, n in ipairs(s.map:neighbors(cand)) do
                if Territory.ownerOf(s, n) == 1 then touching = true end
                if Hex.distance(n, s.players[1].hq) == 2 and not anchorTile then anchorTile = n end
            end
            if not touching and not out then out = cand end
        end
        expect.falsy(Territory.canVote(s, 1, out), "chưa kề lãnh thổ của mình")
        for _, n in ipairs(s.map:neighbors(out)) do
            if Hex.distance(n, s.players[1].hq) == 2 then s.owner[State.key(n)] = 1 break end   -- một ô d = 2 liền kề thuộc về mình
        end
        expect.truthy(Territory.canVote(s, 1, out), "kề lãnh thổ của mình thì mở rộng được")
        expect.eq(Territory.threshold(s, 1, out), 4, "d = 3 ngoài vùng: 3 + 1")
        for _ = 1, 3 do Territory.addVote(s, 1, out) end
        expect.eq(Territory.statusOf(s, out), "contested")
        Territory.addVote(s, 1, out)
        expect.eq(Territory.statusOf(s, out), "owned")
    end)

    it("tranh lại ô thường chỉ với ô giá trị cao trong vùng ảnh hưởng của mình, đặt trọn 2 x ngưỡng trong một lệnh", function()
        local s = twoPlayerState(2)
        s.players[1].votes, s.players[2].votes = 9, 9
        local t = midTile(s)                          -- cách mỗi HQ 2 ô
        expect.eq(Territory.threshold(s, 2, t), 2)
        Territory.buyTile(s, 1, t)
        expect.eq(Territory.ownerOf(s, t), 1)

        local ok, why = Territory.canVote(s, 2, t)
        expect.falsy(ok); expect.truthy(why:find("giá trị cao", 1, true), "ô thường không bị tranh lại: " .. tostring(why))

        t.strategic = "TN-07"                         -- ô giá trị cao
        s.players[2].votes = 3
        ok, why = Territory.canVote(s, 2, t)
        expect.falsy(ok); expect.eq(why, "Cần 4 phiếu trong tay để tranh lại ô này")
        expect.eq(Territory.voteCost(s, 2, t), 4)

        s.players[2].votes = 4
        local before, after = Territory.addVote(s, 2, t)
        expect.eq(before, 1); expect.eq(after, 2)
        expect.eq(Territory.ownerOf(s, t), 2)
        expect.eq(s.players[2].votes, 0, "tiêu trọn 4 phiếu")
        expect.eq(Territory.votesOn(s, t, 2), 2, "phiếu mới của chủ ghi bằng ngưỡng; phiếu cũ bị xóa")
        expect.eq(Territory.votesOn(s, t, 1), 0)

        t.strategic = nil
        t.base = { gold = 2, culture = 1 }            -- tổng Tài Nguyên Cơ Bản >= 3 cũng là giá trị cao
        expect.truthy(Territory.isHighValue(s, t))
        t.base = { gold = 2 }
        expect.falsy(Territory.isHighValue(s, t))
    end)

    it("tranh lại ô ngoài vùng ảnh hưởng của mình thì không được (kể cả khi kề)", function()
        local s = twoPlayerState(1)                   -- C1: ô giữa nằm ngoài vùng ảnh hưởng của cả hai
        s.players[2].votes = 20
        local t = midTile(s)
        t.strategic = "TN-07"
        Territory.buyTile(s, 1, t)
        local ok, why = Territory.canVote(s, 2, t)
        expect.falsy(ok); expect.eq(why, "Chỉ tranh lại ô trong vùng ảnh hưởng của bạn")
    end)

    it("công trình đi theo ô khi ô đổi chủ, cả footprint đổi chủ; Đặc Biệt thì không bị cướp bằng phiếu", function()
        local s = twoPlayerState(2)
        s.players[2].votes = 40
        local t = midTile(s)
        t.strategic = "TN-07"
        local next1 = s.map:get(t.q, t.r - 1)
        Territory.buyTile(s, 1, t); Territory.buyTile(s, 1, next1)
        local b = Structures.place(s, { id = "B-03", level = 2, owner = 1 }, { t, next1 })
        Territory.addVote(s, 2, t)
        expect.eq(Territory.ownerOf(s, t), 2)
        expect.eq(b.owner, 2, "công trình đi theo ô")
        expect.eq(Territory.ownerOf(s, next1), 2, "cả footprint đổi chủ")
        expect.eq(Structures.at(s, t).uid, b.uid, "công trình không bị phá")

        local t2 = tileAtDistance(s, 1, 2, 1)         -- trong vùng ảnh hưởng của P1
        t2.strategic = "TN-07"
        Territory.buyTile(s, 2, t2)
        Structures.place(s, { id = "S-01", level = 1, owner = 2 }, { t2 })
        s.players[1].votes = 40
        local ok, why = Territory.canVote(s, 1, t2)
        expect.falsy(ok); expect.eq(why, "Công trình Đặc Biệt / Phái Sinh không bị cướp bằng phiếu")
    end)

    it("ô trong cụm: mỗi ô 1 phiếu, cướp cần phiếu của chủ + 1 (phiếu cộng dồn)", function()
        local s = twoPlayerState(2)
        s.players[1].votes, s.players[2].votes = 9, 9
        local t = midTile(s)
        t.settlement = 1
        Territory.addVote(s, 1, t)
        expect.eq(Territory.ownerOf(s, t), 1)
        Territory.addVote(s, 2, t)                                    -- 1 không hơn 1 + 1
        expect.eq(Territory.ownerOf(s, t), 1)
        expect.truthy(Territory.isDisputed(s, t))
        Territory.addVote(s, 2, t)                                    -- 2 = 1 + 1
        expect.eq(Territory.ownerOf(s, t), 2)
    end)

    it("người chi phối cụm là người sở hữu nhiều ô nhất (hơn hẳn)", function()
        local s = twoPlayerState()
        local cluster = { tiles = { tileAtDistance(s, 1, 2, 1), tileAtDistance(s, 1, 2, 2), tileAtDistance(s, 1, 2, 3) } }
        expect.eq(Territory.clusterController(s, cluster), nil)
        s.owner[State.key(cluster.tiles[1])] = 1
        expect.eq(Territory.clusterController(s, cluster), 1)
        s.owner[State.key(cluster.tiles[2])] = 2
        expect.eq(Territory.clusterController(s, cluster), nil, "hòa thì chưa ai chi phối")
        s.owner[State.key(cluster.tiles[3])] = 2
        expect.eq(Territory.clusterController(s, cluster), 2)
    end)

    it("voteTargets chỉ trả ô hợp lệ (12 ô d = 2 kề lãnh thổ khi chỉ có HQ C1)", function()
        local s = twoPlayerState()
        expect.eq(#Territory.voteTargets(s, 1), 0)
        s.players[1].votes = 1
        local targets = Territory.voteTargets(s, 1)
        expect.eq(#targets, 12)
        for _, t in ipairs(targets) do expect.truthy(Territory.canVote(s, 1, t)) end
    end)
end)

describe("territory: mua ô", function()
    it("giá = (1 + d) VH + (2 + d) V (d = khoảng cách tới HQ/Sub gần nhất, tối thiểu 1 mỗi loại)", function()
        local s = twoPlayerState(2)
        local c1 = Territory.buyTileCost(s, 1, tileAtDistance(s, 1, 1))
        expect.eq(c1.culture, 2); expect.eq(c1.gold, 3)                       -- d = 1: 2 VH + 3 V
        local c2 = Territory.buyTileCost(s, 1, tileAtDistance(s, 1, 2))
        expect.eq(c2.culture, 3); expect.eq(c2.gold, 4)
        local c3 = Territory.buyTileCost(s, 1, tileAtDistance(s, 1, 3))
        expect.eq(c3.culture, 4); expect.eq(c3.gold, 5)
        local c5 = Territory.buyTileCost(s, 1, tileAtDistance(s, 1, 5))
        expect.eq(c5.culture, 6); expect.eq(c5.gold, 7)
    end)

    it("mua ô chưa có chủ trong vùng ảnh hưởng hoặc kề lãnh thổ; không mua cụm; mua xong ô thuộc về mình", function()
        local s = twoPlayerState()
        local t = tileAtDistance(s, 1, 2)            -- ngoài vùng ảnh hưởng nhưng kề ô thực hữu
        expect.truthy(Territory.canBuyTile(s, 1, t))
        local ok, why = Territory.canBuyTile(s, 1, tileAtDistance(s, 1, 3))
        expect.falsy(ok); expect.eq(why, "Chỉ mua ô trong vùng ảnh hưởng hoặc kề lãnh thổ của bạn")
        local cl = tileAtDistance(s, 1, 2, 4)
        cl.settlement = 1
        ok, why = Territory.canBuyTile(s, 1, cl)
        expect.falsy(ok); expect.eq(why, "Khu Dân Cư / Danh Thắng chỉ lấy được bằng phiếu")
        cl.settlement = nil
        Territory.buyTile(s, 1, t)
        expect.eq(Territory.ownerOf(s, t), 1)
        expect.eq(Territory.votesOn(s, t, 1), Territory.threshold(s, 1, t), "phiếu ghi bằng ngưỡng (có +1 ngoài vùng)")
        ok, why = Territory.canBuyTile(s, 1, t)
        expect.falsy(ok); expect.eq(why, "Ô đã có chủ")
        local hq = s.map:get(s.players[1].hq.q, s.players[1].hq.r)
        expect.falsy(Territory.canBuyTile(s, 1, hq))
        local targets = Territory.buyTargets(s, 1)
        expect.truthy(#targets >= 11, "ô d = 2 còn lại và các ô kề ô vừa mua")
        for _, x in ipairs(targets) do expect.truthy(Territory.canBuyTile(s, 1, x)) end
    end)
end)

describe("territory: Khu Trực Thuộc", function()
    local function westTile(s)   -- ô cách HQ1 2 ô về phía Tây, xa HQ2
        local hq = s.players[1].hq
        local t = s.map:get(hq.q - 2, hq.r)
        return t
    end

    it("lập được trên ô thực hữu cách HQ ≥ 2 và cách đối thủ ≥ 3", function()
        local s = twoPlayerState(2)
        local t = westTile(s)
        local ok, why = Territory.canFoundSub(s, 1, t)
        expect.falsy(ok); expect.eq(why, "Phải lập Khu Trực Thuộc trên lãnh thổ thực hữu của bạn")
        Territory.buyTile(s, 1, t)
        expect.truthy(Territory.canFoundSub(s, 1, t))
        Territory.addSub(s, 1, t)
        expect.eq(#Territory.anchors(s, 1), 2)
        expect.truthy(Territory.isAnchorTile(s, t))
        expect.truthy(Territory.inInfluence(s, 1, s.map:get(t.q - 1, t.r)))
        local ok2, why2 = Territory.canFoundSub(s, 1, t)
        expect.falsy(ok2)
    end)

    it("từ chối: quá gần HQ của mình, quá gần đối thủ, trùng cụm, địa hình cấm (kể cả Đầm Lầy)", function()
        local s = twoPlayerState(2)
        local near = tileAtDistance(s, 1, 1)
        local ok, why = Territory.canFoundSub(s, 1, near)
        expect.falsy(ok); expect.eq(why, "Phải cách Nhà Chính/Khu Trực Thuộc của bạn ít nhất 2 ô")

        local m = midTile(s)
        Territory.buyTile(s, 1, m)                       -- cách HQ2 2 ô
        ok, why = Territory.canFoundSub(s, 1, m)
        expect.falsy(ok); expect.eq(why, "Phải cách Nhà Chính/Khu Trực Thuộc của đối thủ ít nhất 3 ô")

        local w = westTile(s)
        Territory.buyTile(s, 1, w)
        s.map:get(w.q - 1, w.r).settlement = 1
        ok, why = Territory.canFoundSub(s, 1, w)
        expect.falsy(ok); expect.eq(why, "Vùng ảnh hưởng không được trùng Khu Dân Cư / Danh Thắng")
        s.map:get(w.q - 1, w.r).settlement = nil

        w.terrain = "DH-04"
        ok, why = Territory.canFoundSub(s, 1, w)
        expect.falsy(ok); expect.eq(why, "Không đặt Khu Trực Thuộc trên địa hình này")
        w.terrain = "DH-08"                              -- GDD 1.6: Đầm Lầy không đặt HQ/Sub
        ok, why = Territory.canFoundSub(s, 1, w)
        expect.falsy(ok); expect.eq(why, "Không đặt Khu Trực Thuộc trên địa hình này")
    end)
end)
