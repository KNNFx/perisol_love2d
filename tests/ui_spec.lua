local Sim     = require("src.core.sim")
local Fmt     = require("src.ui.log_format")
local Tween   = require("src.ui.tween")
local Actions = require("src.input.actions")
local Game    = require("src.core.game")
local Wallet  = require("src.core.wallet")
local Territory = require("src.core.territory")
local Buildings = require("src.data.buildings")

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

-- Luật bật/tắt nút của UI phải trùng nguồn giá mà Game.check dùng. Mỗi "cặp" = (state, lựa chọn mua/xây/nâng):
-- bên UI là hàm scenes/game.lua gọi, bên core tính độc lập từ Game.buildCost / Game.upgradeCost.
describe("ui: giá hiệu lực khớp core", function()
    local function sameCost(a, b)
        for k, n in pairs(a) do if (b[k] or 0) ~= n then return false end end
        for k, n in pairs(b) do if (a[k] or 0) ~= n then return false end end
        return true
    end

    it("nút xây/nâng sáng khi và chỉ khi core cho là đủ tiền (>= 200 cặp từ ván sim)", function()
        local pairsN, rawDiffer, affordDiffer, mismatches = 0, 0, 0, {}
        for seed = 1, 8 do
            Sim.play(seed, 2 + seed % 3, { onCommand = function(state)
                if state.phase ~= "action" then return end
                local pid = Game.actor(state)
                local res = state.players[pid].res
                local owned = Territory.ownedTiles(state, pid)
                -- xây: nút theo loại công trình; core: có ô thực hữu nào trả nổi giá THỰC trên ô đó
                for _, b in ipairs(Buildings.list) do
                    local ui = Game.affordBuild(state, pid, b.id)
                    local core = false
                    local differs = false
                    for _, t in ipairs(owned) do
                        local eff = Game.buildCost(state, pid, b.id, t)
                        if Wallet.canAfford(res, eff) then core = true end
                        if not sameCost(eff, b.levels[1].cost) then differs = true end
                    end
                    pairsN = pairsN + 1
                    if differs then rawDiffer = rawDiffer + 1 end
                    if core ~= Wallet.canAfford(res, b.levels[1].cost) and #owned > 0 then affordDiffer = affordDiffer + 1 end
                    if ui ~= core then mismatches[#mismatches + 1] = string.format("seed %d vòng %d build %s ui=%s core=%s",
                        seed, state.round, b.id, tostring(ui), tostring(core)) end
                end
                -- nâng cấp tại chỗ: nút dùng Game.upgradeCost
                for _, b in pairs(state.buildings) do
                    if b.owner == pid then
                        local cost = Game.upgradeCost(state, b)
                        if cost then
                            local ui = Game.afford(state, pid, "upgrade", b)
                            local core = Wallet.canAfford(res, cost)
                            pairsN = pairsN + 1
                            if ui ~= core then mismatches[#mismatches + 1] = "upgrade " .. b.id end
                        end
                    end
                end
            end })
        end
        print(string.format("    [giá] %d cặp so; %d cặp giá thô != giá hiệu lực; %d cặp thô/hiệu lực khác kết luận đủ tiền",
            pairsN, rawDiffer, affordDiffer))
        expect.truthy(pairsN >= 200, "cần >= 200 cặp, có " .. pairsN)
        expect.eq(#mismatches, 0, table.concat(mismatches, "; ", 1, math.min(#mismatches, 5)))
    end)
end)
