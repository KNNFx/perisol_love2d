local C         = require("src.config.constants")
local Hex       = require("src.core.hex")
local Mapgen    = require("src.core.mapgen")
local State     = require("src.core.state")
local Territory = require("src.core.territory")

-- State 2 người trên map 32x16: HQ1 ở giữa, HQ2 cách 4 ô theo hướng Đông.
-- Xóa TN, Khu Dân Cư và Danh Thắng quanh đó để luật thuần (các test cụm tự gán cờ).
local function twoPlayerState(level)
    local map = Mapgen.generate({ seed = 7, players = 4 })
    for _, t in ipairs(map.list) do
        t.strategic, t.settlement, t.landmark = nil, nil, nil
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

describe("territory: HQ, vùng ảnh hưởng, ngưỡng", function()
    it("lúc đầu chỉ ô HQ là thực hữu; 6 ô quanh là vùng ảnh hưởng, ô xa hơn chưa", function()
        local s = twoPlayerState()
        expect.eq(#Territory.ownedTiles(s, 1), 1)
        local hq = s.map:get(s.players[1].hq.q, s.players[1].hq.r)
        expect.eq(Territory.ownerOf(s, hq), 1)
        expect.truthy(Territory.inInfluence(s, 1, tileAtDistance(s, 1, 1)))
        expect.falsy(Territory.inInfluence(s, 1, tileAtDistance(s, 1, 2)))
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
        expect.falsy(ok); expect.eq(why, "Nhà Chính đã ở cấp tối đa của M1")
    end)

    it("ngưỡng 1 / 2 / 3 theo khoảng cách tới HQ (3+ giữ nguyên 3)", function()
        local s = twoPlayerState()
        expect.eq(Territory.threshold(s, 1, tileAtDistance(s, 1, 1)), 1)
        expect.eq(Territory.threshold(s, 1, tileAtDistance(s, 1, 2)), 2)
        expect.eq(Territory.threshold(s, 1, tileAtDistance(s, 1, 3)), 3)
        expect.eq(Territory.threshold(s, 1, tileAtDistance(s, 1, 5)), 3)
    end)

    it("TN-06 giảm ngưỡng 1 nhưng không dưới 1; ô trong cụm luôn cần 1 phiếu", function()
        local s = twoPlayerState()
        local t2, t1 = tileAtDistance(s, 1, 2), tileAtDistance(s, 1, 1)
        t2.strategic, t1.strategic = "TN-06", "TN-06"
        expect.eq(Territory.threshold(s, 1, t2), 1)
        expect.eq(Territory.threshold(s, 1, t1), 1)
        local far = tileAtDistance(s, 1, 3)
        expect.eq(Territory.threshold(s, 1, far), 3)
        far.settlement = 1
        expect.eq(Territory.threshold(s, 1, far), C.CLUSTER_TILE_VOTES)
    end)
end)

describe("territory: đặt phiếu", function()
    it("từ chối: hết phiếu, ngoài vùng ảnh hưởng, ô HQ, công trình đối thủ, phong tỏa", function()
        local s = twoPlayerState()
        local near = tileAtDistance(s, 1, 1)
        local ok, why = Territory.canVote(s, 1, near)
        expect.falsy(ok); expect.eq(why, "Không còn phiếu Chi Phối")

        s.players[1].votes = 10
        expect.truthy(Territory.canVote(s, 1, near))

        ok, why = Territory.canVote(s, 1, tileAtDistance(s, 1, 2))
        expect.falsy(ok); expect.eq(why, "Chỉ đặt phiếu trong vùng ảnh hưởng của bạn")

        local hq = s.map:get(s.players[1].hq.q, s.players[1].hq.r)
        ok, why = Territory.canVote(s, 1, hq)
        expect.falsy(ok); expect.eq(why, "Không đặt phiếu lên ô Nhà Chính / Khu Trực Thuộc")

        s.buildings[State.key(near)] = { id = "B-01", level = 1, owner = 2 }
        ok, why = Territory.canVote(s, 1, near)
        expect.falsy(ok); expect.eq(why, "Ô có công trình của đối thủ")
        s.buildings[State.key(near)] = nil

        s.rebel = { q = near.q, r = near.r }
        ok, why = Territory.canVote(s, 1, near)
        expect.falsy(ok); expect.eq(why, "Ô đang bị Phiến Quân phong tỏa")
    end)

    it("1 phiếu ở sát HQ là đủ; ô cách 2 cần 2 phiếu (tranh chấp rồi thực hữu)", function()
        local s = twoPlayerState(2)
        s.players[1].votes = 5
        local t1 = tileAtDistance(s, 1, 1)
        local before, after = Territory.addVote(s, 1, t1)
        expect.eq(before, nil); expect.eq(after, 1)
        expect.eq(s.players[1].votes, 4)
        expect.falsy(Territory.canVote(s, 1, t1), "ô đã thuộc về bạn")

        local t2 = tileAtDistance(s, 1, 2, 3)
        Territory.addVote(s, 1, t2)
        expect.eq(Territory.statusOf(s, t2), "contested")
        Territory.addVote(s, 1, t2)
        expect.eq(Territory.statusOf(s, t2), "owned")
        expect.eq(#Territory.ownedTiles(s, 1), 3)
    end)

    it("cướp ô thường: cần ≥ 2 × ngưỡng của mình và hơn phiếu của chủ", function()
        local s = twoPlayerState(2)
        s.players[1].votes, s.players[2].votes = 9, 9
        local mid = Hex.line(s.players[1].hq, s.players[2].hq)[3]   -- cách mỗi HQ 2 ô
        local t = s.map:get(mid.q, mid.r)
        expect.eq(Territory.threshold(s, 1, t), 2)
        expect.eq(Territory.threshold(s, 2, t), 2)

        Territory.addVote(s, 1, t); Territory.addVote(s, 1, t)
        expect.eq(Territory.ownerOf(s, t), 1)

        for _ = 1, 3 do Territory.addVote(s, 2, t) end                -- 3 < 2×2 = 4
        expect.eq(Territory.ownerOf(s, t), 1, "chưa đủ gấp đôi ngưỡng")
        expect.truthy(Territory.isDisputed(s, t))
        expect.truthy(Territory.canVote(s, 1, t), "chủ được đặt thêm để bảo vệ")

        Territory.addVote(s, 2, t)                                    -- 4 = 2×2 và > 2
        expect.eq(Territory.ownerOf(s, t), 2)
    end)

    it("chủ bảo vệ bằng cách thêm phiếu khi bị tranh: người cướp phải hơn phiếu của chủ", function()
        local s = twoPlayerState(2)
        s.players[1].votes, s.players[2].votes = 20, 20
        local mid = Hex.line(s.players[1].hq, s.players[2].hq)[3]
        local t = s.map:get(mid.q, mid.r)
        for _ = 1, 2 do Territory.addVote(s, 1, t) end                -- P1 chủ với 2 phiếu
        for _ = 1, 3 do Territory.addVote(s, 2, t) end                -- P2 tranh với 3 phiếu
        for _ = 1, 2 do Territory.addVote(s, 1, t) end                -- P1 bảo vệ, lên 4 phiếu
        Territory.addVote(s, 2, t)                                    -- P2 = 4: đủ 2x ngưỡng nhưng không hơn 4
        expect.eq(Territory.ownerOf(s, t), 1)
        Territory.addVote(s, 2, t)                                    -- P2 = 5 > 4
        expect.eq(Territory.ownerOf(s, t), 2)
    end)

    it("ô trong cụm: mỗi ô 1 phiếu, cướp cần phiếu của chủ + 1", function()
        local s = twoPlayerState(2)
        s.players[1].votes, s.players[2].votes = 9, 9
        local mid = Hex.line(s.players[1].hq, s.players[2].hq)[3]
        local t = s.map:get(mid.q, mid.r)
        t.settlement = 1
        Territory.addVote(s, 1, t)
        expect.eq(Territory.ownerOf(s, t), 1)
        Territory.addVote(s, 2, t)                                    -- 1 không hơn 1 + 1
        expect.eq(Territory.ownerOf(s, t), 1)
        Territory.addVote(s, 2, t)                                    -- 2 = 1 + 1
        expect.eq(Territory.ownerOf(s, t), 2)
    end)

    it("người chi phối cụm là người sở hữu nhiều ô nhất (hơn hẳn)", function()
        local s = twoPlayerState()
        local cluster = { tiles = { tileAtDistance(s, 1, 1, 1), tileAtDistance(s, 1, 1, 2), tileAtDistance(s, 1, 1, 3) } }
        expect.eq(Territory.clusterController(s, cluster), nil)
        s.owner[State.key(cluster.tiles[1])] = 1
        expect.eq(Territory.clusterController(s, cluster), 1)
        s.owner[State.key(cluster.tiles[2])] = 2
        expect.eq(Territory.clusterController(s, cluster), nil, "hòa thì chưa ai chi phối")
        s.owner[State.key(cluster.tiles[3])] = 2
        expect.eq(Territory.clusterController(s, cluster), 2)
    end)

    it("voteTargets chỉ trả ô hợp lệ", function()
        local s = twoPlayerState()
        expect.eq(#Territory.voteTargets(s, 1), 0)
        s.players[1].votes = 1
        local targets = Territory.voteTargets(s, 1)
        expect.eq(#targets, 6)
        for _, t in ipairs(targets) do expect.truthy(Territory.canVote(s, 1, t)) end
    end)
end)

describe("territory: mua ô", function()
    it("giá = (1 V + 1 VH) × 2^(khoảng cách − 1)", function()
        local s = twoPlayerState(2)
        local c1 = Territory.buyTileCost(s, 1, tileAtDistance(s, 1, 1))
        expect.eq(c1.gold, 1); expect.eq(c1.culture, 1)
        local c2 = Territory.buyTileCost(s, 1, tileAtDistance(s, 1, 2))
        expect.eq(c2.gold, 2); expect.eq(c2.culture, 2)
    end)

    it("chỉ mua ô chưa có chủ trong vùng ảnh hưởng; mua xong ô thuộc về mình", function()
        local s = twoPlayerState()
        local t = tileAtDistance(s, 1, 1)
        expect.truthy(Territory.canBuyTile(s, 1, t))
        local ok, why = Territory.canBuyTile(s, 1, tileAtDistance(s, 1, 2))
        expect.falsy(ok); expect.eq(why, "Chỉ mua ô trong vùng ảnh hưởng của bạn")
        Territory.buyTile(s, 1, t)
        expect.eq(Territory.ownerOf(s, t), 1)
        ok, why = Territory.canBuyTile(s, 1, t)
        expect.falsy(ok); expect.eq(why, "Ô đã có chủ")
        local hq = s.map:get(s.players[1].hq.q, s.players[1].hq.r)
        expect.falsy(Territory.canBuyTile(s, 1, hq))
        expect.eq(#Territory.buyTargets(s, 1), 5)
    end)

    it("ô đã mua vẫn bị cướp theo luật ×2 (phiếu được ghi bằng ngưỡng)", function()
        local s = twoPlayerState(2)
        s.players[2].votes = 9
        local mid = Hex.line(s.players[1].hq, s.players[2].hq)[3]
        local t = s.map:get(mid.q, mid.r)
        Territory.buyTile(s, 1, t)
        expect.eq(Territory.votesOn(s, t, 1), 2)
        for _ = 1, 3 do Territory.addVote(s, 2, t) end
        expect.eq(Territory.ownerOf(s, t), 1)
        Territory.addVote(s, 2, t)
        expect.eq(Territory.ownerOf(s, t), 2)
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

    it("từ chối: quá gần HQ của mình, quá gần đối thủ, trùng cụm, địa hình cấm", function()
        local s = twoPlayerState(2)
        local near = tileAtDistance(s, 1, 1)
        Territory.buyTile(s, 1, near)
        local ok, why = Territory.canFoundSub(s, 1, near)
        expect.falsy(ok); expect.eq(why, "Phải cách Nhà Chính/Khu Trực Thuộc của bạn ít nhất 2 ô")

        local mid = Hex.line(s.players[1].hq, s.players[2].hq)[3]
        local m = s.map:get(mid.q, mid.r)
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
    end)
end)
