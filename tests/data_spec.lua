local C         = require("src.config.constants")
local Buildings = require("src.data.buildings")
local Movement  = require("src.data.movement")
local Terrains  = require("src.data.terrains")
local Resources = require("src.data.resources")

describe("data: buildings", function()
    it("5 công trình cơ bản × 3 cấp, mỗi cấp có chi phí và sản xuất", function()
        expect.eq(#Buildings.list, 5)
        for _, b in ipairs(Buildings.list) do
            expect.eq(#b.levels, 3, b.id)
            for lv, def in ipairs(b.levels) do
                expect.truthy(next(def.cost) ~= nil, def.fullId .. ": thiếu chi phí")
                expect.truthy(#def.produces >= 1, def.fullId .. ": thiếu sản xuất")
                expect.truthy(def.tiles >= 1, def.fullId)
                expect.eq(def.fullId, b.id .. "." .. lv)
            end
        end
    end)

    it("mọi tham chiếu địa hình và tài nguyên đều tồn tại", function()
        for _, b in ipairs(Buildings.list) do
            expect.truthy(Resources.byKey[b.main], b.id .. ": tài nguyên chính")
            for _, def in ipairs(b.levels) do
                for terrain in pairs(def.terrains) do
                    expect.truthy(Terrains.byId[terrain], def.fullId .. ": " .. terrain)
                end
                for res in pairs(def.cost) do
                    expect.truthy(Resources.byKey[res], def.fullId .. ": cost " .. res)
                end
                for _, p in ipairs(def.produces) do
                    expect.truthy(Resources.byFace[p[1]], def.fullId .. ": mặt " .. tostring(p[1]))
                    expect.truthy(Resources.byKey[p[2]], def.fullId .. ": res " .. tostring(p[2]))
                    expect.truthy(p[3] >= 1, def.fullId)
                end
            end
        end
    end)

    it("số liệu khớp bảng Data (mẫu)", function()
        local l1 = Buildings.level("B-01", 1)
        expect.eq(l1.cost.engineering, 2)
        expect.eq(l1.cost.gold, 1)
        expect.eq(l1.produces[1][1], 3)   -- ra Kỹ Thuật
        local l3 = Buildings.level("B-01", 3)
        expect.eq(l3.tiles, 6)
        expect.eq(l3.produces[1][3], 3)   -- 3 KT khi ra KT
        expect.eq(l3.produces[2][3], 2)   -- 2 KT khi ra KH
        expect.eq(Buildings.level("B-05", 3).cost.culture, 2)
    end)

    it("ma trận đặt công trình (mẫu)", function()
        expect.truthy(Buildings.allowedOn("B-01", 1, "DH-01"))
        expect.falsy(Buildings.allowedOn("B-01", 1, "DH-03"))    -- Núi chỉ từ C2
        expect.truthy(Buildings.allowedOn("B-01", 2, "DH-03"))
        expect.eq(Buildings.allowedOn("B-02", 1, "DH-02"), "pref")
        expect.eq(Buildings.allowedOn("B-03", 1, "DH-10"), "pref")
        expect.truthy(Buildings.allowedOn("B-04", 1, "DH-04"))   -- Đền Thờ trên Sông
        expect.falsy(Buildings.allowedOn("B-05", 3, "DH-10"))
        expect.falsy(Buildings.allowedOn("B-01", 1, "DH-11"))    -- không ai xây trên Danh Thắng
    end)
end)

describe("data: movement + constants M1", function()
    it("Phiến Quân: Núi khóa trong 10 vòng đầu, sau đó tốn 3", function()
        expect.eq(Movement.stepCost("rebel", "DH-03", 1), math.huge)
        expect.eq(Movement.stepCost("rebel", "DH-03", C.REBEL_MOUNTAIN_LOCK_ROUNDS), math.huge)
        expect.eq(Movement.stepCost("rebel", "DH-03", C.REBEL_MOUNTAIN_LOCK_ROUNDS + 1), C.REBEL_MOUNTAIN_COST)
        expect.eq(Movement.stepCost("rebel", "DH-12", 11), C.REBEL_MOUNTAIN_COST)
        expect.eq(Movement.stepCost("rebel", "DH-02", 1), 2)
        expect.eq(Movement.stepCost("rebel", "DH-08", 1), 2)
    end)

    it("mọi đơn vị có chi phí cho cả 12 địa hình", function()
        for unit, tbl in pairs(Movement.cost) do
            for _, t in ipairs(Terrains.list) do
                expect.truthy(tbl[t.id], unit .. " thiếu " .. t.id)
            end
        end
        expect.eq(Movement.stepCost("expedition", "DH-03", 1), math.huge)
        expect.eq(Movement.stepCost("knight", "DH-03", 1), 2)
    end)

    it("hằng số M1 hợp lý", function()
        expect.eq(#C.CHI_PHOI_THRESHOLD, 3)
        expect.eq(C.ROUNDS_PER_GAME, 20)
        for _, r in ipairs(C.REBEL_SPAWN_TERRAINS) do expect.truthy(Terrains.byId[r], r) end
        for key in pairs(C.STARTING_RESOURCES) do expect.truthy(Resources.byKey[key], key) end
        for key in pairs(C.BUY_TILE_BASE) do expect.truthy(Resources.byKey[key], key) end
        for key in pairs(C.SUB_COST) do expect.truthy(Resources.byKey[key], key) end
        for terrain, res in pairs(C.START_BONUS_BY_TERRAIN) do
            expect.truthy(Resources.byKey[res], res)
            expect.truthy(Terrains.byId[terrain], terrain)
        end
        expect.eq(#C.INFLUENCE_RADIUS_HQ, C.HQ_MAX_LEVEL_M1)
    end)
end)
