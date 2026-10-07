local Game       = require("src.core.game")
local Hex        = require("src.core.hex")
local Passives   = require("src.core.passives")
local Production = require("src.core.production")
local Shapes     = require("src.data.shapes")
local Sim        = require("src.core.sim")
local State      = require("src.core.state")
local Structures = require("src.core.structures")
local Upkeep     = require("src.core.upkeep")
local Construction = require("src.core.construction")
local arena      = require("tests.arena")

local key = State.key

-- Phiến Quân đứng rất xa: có mặt trên bản đồ nhưng không phong tỏa gì.
local function farRebel(s) s.rebel = { q = -99, r = -99 } end

-- Đặt công trình `id` cấp `level` theo hình của cấp đó, ô gốc (q, r), xoay 0.
local function placeShaped(s, pid, id, level, q, r)
    local Buildings = require("src.data.buildings")
    local cells = Shapes.footprint(Buildings.level(id, level).shape, q, r, 0)
    local tiles = {}
    for i, c in ipairs(cells) do tiles[i] = s.map:get(c.q, c.r) end
    return Structures.place(s, { id = id, level = level, owner = pid }, tiles), tiles
end

local function total(list, res)
    local n = 0
    for _, g in ipairs(list) do if g.res == res then n = n + g.amount end end
    return n
end

describe("passives: công trình cấp cao", function()
    it("Trại KT C3 cho +1 KT; chỉ vào lượt của chủ", function()
        local s, pid, c = arena()
        farRebel(s)
        placeShaped(s, pid, "B-01", 3, c.q - 1, c.r)
        local before = s.players[pid].res.engineering
        expect.eq(#Upkeep.startTurn(s, 3 - pid), 0)
        local ev = Upkeep.startTurn(s, pid)
        expect.eq(ev[1].kind, "passive"); expect.eq(ev[1].src, "B-01")
        expect.eq(s.players[pid].res.engineering, before + 1)
    end)

    it("Nhà VH C3: 0.5 VH cho mỗi ô thực hữu kề; phần lẻ dồn vào carry", function()
        local s, pid, c = arena()
        farRebel(s)
        local _, tiles = placeShaped(s, pid, "B-03", 3, c.q, c.r)
        local inFoot, adj = {}, {}
        for _, t in ipairs(tiles) do inFoot[key(t)] = true end
        for _, t in ipairs(tiles) do
            for _, h in ipairs(Hex.ring(t, 1)) do
                local k = key(h)
                if not inFoot[k] and s.owner[k] == pid and s.map:get(h.q, h.r) then adj[k] = true end
            end
        end
        local n = 0
        for _ in pairs(adj) do n = n + 1 end
        expect.truthy(n > 0)
        local before = s.players[pid].res.culture
        local got = total(Passives.compute(s, pid), "culture")
        expect.eq(got, n * 0.5)
        Upkeep.startTurn(s, pid)
        expect.eq(s.players[pid].res.culture, before + math.floor(n * 0.5))
        local frac = (n * 0.5) % 1
        expect.eq(s.players[pid].carry.culture or 0, frac)
        -- phần lẻ cộng dồn sang lượt sau: tổng sau 2 lượt = floor(2 * n * 0.5)
        Upkeep.startTurn(s, pid)
        expect.eq(s.players[pid].res.culture, before + math.floor(n))
        expect.eq(s.players[pid].carry.culture, nil)
        expect.truthy(Sim.invariants(s))
    end)

    it("Đền Thờ C3: +1 TN chỉ khi có Phiến Quân trên bản đồ", function()
        local s, pid, c = arena()
        placeShaped(s, pid, "B-04", 3, c.q, c.r)
        s.rebel = nil
        expect.eq(total(Passives.compute(s, pid), "faith"), 0)
        farRebel(s)
        expect.eq(total(Passives.compute(s, pid), "faith"), 1)
    end)

    it("công trình bị phong tỏa (bất kỳ ô nào) hoặc chờ dỡ không nhận thu nhập", function()
        local s, pid, c = arena()
        local b, tiles = placeShaped(s, pid, "B-01", 3, c.q - 1, c.r)
        farRebel(s)
        expect.eq(total(Passives.compute(s, pid), "engineering"), 1)
        local last = tiles[#tiles]
        s.rebel = { q = last.q, r = last.r }
        expect.eq(total(Passives.compute(s, pid), "engineering"), 0)
        farRebel(s)
        b.demolishing = true
        expect.eq(total(Passives.compute(s, pid), "engineering"), 0)
    end)

    it("cấp thấp hơn không có thu nhập (C2)", function()
        local s, pid, c = arena()
        farRebel(s)
        placeShaped(s, pid, "B-01", 2, c.q, c.r)
        expect.eq(total(Passives.compute(s, pid), "engineering"), 0)
    end)
end)

describe("passives: địa hình và TN", function()
    it("Rừng: Viện NC C1 +1 KH, C2 thì không", function()
        local s, pid, c = arena()
        farRebel(s)
        c.terrain = "DH-02"
        local b = Structures.place(s, { id = "B-02", level = 1, owner = pid }, { c })
        expect.eq(total(Passives.compute(s, pid), "science"), 1)
        b.level = 2
        expect.eq(total(Passives.compute(s, pid), "science"), 0)
        c.terrain = "DH-01"
    end)

    it("TN-02 trên ô của chủ: +1 TN +1 KH mỗi lượt; ô của người khác thì không", function()
        local s, pid, c = arena()
        farRebel(s)
        c.strategic = "TN-02"
        local g = Passives.compute(s, pid)
        expect.eq(total(g, "faith"), 1); expect.eq(total(g, "science"), 1)
        expect.eq(#Passives.compute(s, 3 - pid), 0)
        s.lostStrategic[key(c)] = true
        expect.eq(#Passives.compute(s, pid), 0)
        c.strategic = nil
    end)

    it("TN-09: mỗi ô thực hữu kề của chủ cho +1 VH", function()
        local s, pid, c = arena()
        farRebel(s)
        c.strategic = "TN-09"
        expect.eq(total(Passives.compute(s, pid), "culture"), 6)
        s.owner[key(s.map:get(c.q + 1, c.r))] = 3 - pid
        expect.eq(total(Passives.compute(s, pid), "culture"), 5)
        c.strategic = nil
    end)

    it("bước thu nhập chạy khi chủ đổ xúc xắc và ghi log", function()
        local s, pid, c = arena()
        farRebel(s)
        placeShaped(s, pid, "B-01", 3, c.q - 1, c.r)
        s.phase = "roll"
        for i, id in ipairs(s.order) do if id == pid then s.turn = i end end
        local before = s.players[pid].res.engineering
        local ev = Game.apply(s, { type = "roll" })
        expect.eq(ev[1].kind, "passive")
        local Fmt = require("src.ui.log_format")
        expect.truthy(Fmt.line(ev[1]).text:find("thụ động", 1, true))
        expect.truthy(s.players[pid].res.engineering >= before + 1)
    end)
end)

describe("production: TN trên footprint, Địa Linh, Cảng, Đất Màu Mỡ, Đồi Cỏ", function()
    local function eng(s, dice, pid)
        local n = 0
        for _, e in ipairs(Production.compute(s, dice, pid)) do
            if e.kind == "produce" and e.res == "engineering" then n = n + e.amount end
        end
        return n
    end

    it("TN-05 trên hai ô của cùng một công trình cộng dồn (+2 mỗi ô mỗi viên)", function()
        local s, pid, c = arena()
        farRebel(s)
        local _, tiles = placeShaped(s, pid, "B-01", 2, c.q, c.r)
        expect.eq(eng(s, { 3, 5 }, pid), 2)
        tiles[1].strategic = "TN-05"
        expect.eq(eng(s, { 3, 5 }, pid), 4)
        tiles[2].strategic = "TN-05"
        expect.eq(eng(s, { 3, 5 }, pid), 6)
        s.lostStrategic[key(tiles[2])] = true
        expect.eq(eng(s, { 3, 5 }, pid), 4)
        tiles[1].strategic, tiles[2].strategic = nil, nil
    end)

    it("TN-12 Địa Linh: 1 viên khớp tính như cả 2; không có viên khớp thì vẫn 0", function()
        local s, pid, c = arena()
        farRebel(s)
        c.strategic = "TN-12"
        Structures.place(s, { id = "B-01", level = 1, owner = pid }, { c })
        expect.eq(eng(s, { 3, 5 }, pid), 2)
        expect.eq(eng(s, { 3, 3 }, pid), 2)
        expect.eq(eng(s, { 1, 5 }, pid), 0)
        c.strategic = nil
    end)

    it("TN-10 Cảng Tự Nhiên: Khu Chợ C1 sản xuất như C3 (3 V), công trình khác thì không", function()
        local s, pid, c = arena()
        farRebel(s)
        c.strategic = "TN-10"
        Structures.place(s, { id = "B-05", level = 1, owner = pid }, { c })
        local gold = 0
        for _, e in ipairs(Production.compute(s, { 5, 1 }, pid)) do
            if e.kind == "produce" and e.res == "gold" then gold = gold + e.amount end
        end
        expect.eq(gold, 3)
        c.strategic = nil
    end)

    it("TN-08 Đất Màu Mỡ: C1 giảm 1 KT chi phí xây; C2 thì không", function()
        local s, pid, c = arena()
        c.strategic = "TN-08"
        expect.eq(Construction.cost(s, "B-01", 1, c).engineering, 1)   -- 2 KT -> 1
        expect.eq(Construction.cost(s, "B-01", 2, c).engineering, 4)
        s.lostStrategic[key(c)] = true
        expect.eq(Construction.cost(s, "B-01", 1, c).engineering, 2)
        c.strategic = nil
    end)

    it("Đồi Cỏ: Trại KT C2+ +1 KT mỗi viên khớp KT; C1 và mặt khác thì không", function()
        local s, pid, c = arena()
        farRebel(s)
        c.terrain = "DH-09"
        local b = Structures.place(s, { id = "B-01", level = 1, owner = pid }, { c })
        expect.eq(eng(s, { 3, 5 }, pid), 1)
        b.level = 2
        expect.eq(eng(s, { 3, 5 }, pid), 3)          -- 2 + 1
        expect.eq(eng(s, { 3, 3 }, pid), 6)
        expect.eq(eng(s, { 1, 5 }, pid), 1)          -- ra KH: dòng "+1 KT khi ra KH" không dính bonus
        c.terrain = "DH-01"
    end)
end)
