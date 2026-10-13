local Sim     = require("src.core.sim")
local Fmt     = require("src.ui.log_format")
local Tween   = require("src.ui.tween")
local Actions = require("src.input.actions")
local Game    = require("src.core.game")
local Territory = require("src.core.territory")

describe("ui: log_format", function()
    it("sản xuất chia sẻ ghi rõ người nhận và người đổ", function()
        local line = Fmt.line({ kind = "produce", pid = 2, amount = 2, res = "engineering",
                                buildingId = "B-01", roller = 1, level = 1, face = 3 })
        expect.eq(line.text, "P2 +2 KT từ Trại Khai Thác nhờ lượt đổ của P1")
        expect.eq(line.pid, 2)
    end)

    it("các câu chính đúng định dạng", function()
        expect.eq(Fmt.line({ kind = "roll", pid = 1, dice = { 3, 6 } }).text, "P1 đổ xúc xắc: KT + Hex")
        expect.eq(Fmt.line({ kind = "trade", pid = 1, give = "science", get = "gold", rate = 4 }).text,
            "P1 đổi 4 KH lấy 1 V")
        expect.eq(Fmt.line({ kind = "rebel_loss", victim = 2, roller = 1, res = "gold", lost = 3, gained = 2 }).text,
            "P2 mất 3 V, P1 nhận 2")
        expect.eq(Fmt.line({ kind = "claim", pid = 1, from = 2, q = 4, r = 5 }).text, "P1 chiếm ô (4,5) từ P2")
        expect.eq(Fmt.line({ kind = "seven", pid = 1 }).tier, "large")
        expect.eq(Fmt.line({ kind = "không_biết" }), nil)
    end)

    it("mọi loại sự kiện trong 20 ván mô phỏng đều có câu log (trừ setup)", function()
        local seen = {}
        for seed = 1, 20 do
            local state = Sim.play(seed, 2 + seed % 3)
            for _, e in ipairs(state.log) do
                seen[e.kind] = true
                if e.kind ~= "setup" then
                    expect.truthy(Fmt.line(e), "sự kiện chưa có câu log: " .. e.kind)
                end
            end
        end
        for _, kind in ipairs({ "roll", "produce", "votes", "seven", "build", "vote", "claim", "end_turn" }) do
            expect.truthy(seen[kind], "mô phỏng không sinh sự kiện " .. kind)
        end
    end)
end)

describe("ui: tween", function()
    it("đi tới đích đúng thời gian, easing không tuyến tính", function()
        local tw, o = Tween.new(), { v = 0 }
        tw:to(o, "v", 10, 1, "outQuad")
        tw:update(0.5)
        expect.near(o.v, 7.5, 1e-9)        -- outQuad(0.5) = 0.75
        expect.truthy(tw:busy())
        tw:update(0.6)
        expect.eq(o.v, 10)
        expect.falsy(tw:busy())
    end)

    it("outBack vượt đích rồi về (nảy)", function()
        local tw, o = Tween.new(), { v = 1.6 }
        tw:to(o, "v", 1, 1, "outBack")
        local lowest = 10
        for _ = 1, 20 do tw:update(0.05); lowest = math.min(lowest, o.v) end
        expect.truthy(lowest < 1, "outBack phải vượt qua đích")
        expect.eq(o.v, 1)
    end)

    it("tween mới thay tween cũ trên cùng (obj, key); after chạy callback", function()
        local tw, o, fired = Tween.new(), { v = 0 }, false
        tw:to(o, "v", 5, 1)
        tw:to(o, "v", 1, 0.5, "linear")
        expect.eq(#tw.list, 1)
        tw:after(0.2, function() fired = true end)
        tw:update(0.25)
        expect.truthy(fired)
        tw:update(1)
        expect.eq(o.v, 1)
    end)
end)

describe("input: actions", function()
    it("phím được gán vào action có tên", function()
        expect.truthy(Actions.matches("roll", "space"))
        expect.truthy(Actions.matches("endTurn", "e"))
        expect.truthy(Actions.matches("cancel", "escape"))
        expect.falsy(Actions.matches("roll", "x"))
        expect.falsy(Actions.matches("khong_co", "space"))
        expect.eq(Actions.label("quicksave"), "F5")
    end)
end)

-- Nút Xây của UI (Game.affordBuild) phải dựa trên giá THỰC trên ô, không phải giá gốc: lỗi cũ là nút tối dù đủ tiền
-- khi ô có giảm giá (TN-08 Đất Màu Mỡ: Trại KT C1 giảm 1 KT).
describe("ui: nút Xây theo giá hiệu lực", function()
    local function newPosition()
        local s, pid, plain = require("tests.arena")()
        local discounted
        for _, t in ipairs(Territory.ownedTiles(s, pid)) do
            if t ~= plain and Game.buildCheck(s, pid, "B-01", t) then discounted = t break end
        end
        discounted.strategic = "TN-08"            -- đúng một ô thực hữu được giảm giá
        local full = Game.buildCost(s, pid, "B-01", plain)
        local cut = Game.buildCost(s, pid, "B-01", discounted)
        expect.truthy(cut.engineering < full.engineering, "thế cờ phải có giảm giá")
        return s, pid, discounted, plain, full, cut
    end
    local function setRes(s, pid, cost, less)
        for k in pairs(s.players[pid].res) do s.players[pid].res[k] = 0 end
        for k, n in pairs(cost) do s.players[pid].res[k] = n end
        if less then s.players[pid].res.engineering = s.players[pid].res.engineering - 1 end
    end

    it("đủ đúng giá đã giảm (không đủ giá gốc): nút sáng và lệnh build trên ô giảm giá thành công", function()
        local s, pid, tile, _, _, cut = newPosition()
        setRes(s, pid, cut)
        expect.truthy(Game.affordBuild(s, pid, "B-01"))
        expect.truthy(Game.check(s, { type = "build", id = "B-01", q = tile.q, r = tile.r }))
        Game.apply(s, { type = "build", id = "B-01", q = tile.q, r = tile.r })
        expect.truthy(require("src.core.structures").at(s, tile))
        for k, v in pairs(s.players[pid].res) do expect.eq(v, 0, "còn dư " .. k) end
    end)

    it("thiếu 1 so với giá đã giảm: nút tối và lệnh build bị từ chối", function()
        local s, pid, tile, plain, _, cut = newPosition()
        setRes(s, pid, cut, true)
        expect.falsy(Game.affordBuild(s, pid, "B-01"))
        expect.falsy(Game.check(s, { type = "build", id = "B-01", q = tile.q, r = tile.r }))
        expect.falsy(Game.check(s, { type = "build", id = "B-01", q = plain.q, r = plain.r }))
    end)
end)
