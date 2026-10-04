local C         = require("src.config.constants")
local Hex       = require("src.core.hex")
local Mapgen    = require("src.core.mapgen")
local Terrains  = require("src.data.terrains")
local Strategic = require("src.data.strategic")

local function snapshot(map)
    local out = {}
    for _, t in ipairs(map.list) do
        out[#out + 1] = t.q .. "," .. t.r .. "=" .. t.terrain .. "/" .. tostring(t.strategic) .. "/" .. tostring(t.zone)
    end
    return out
end

describe("data", function()
    it("12 địa hình và 12 tài nguyên chiến lược với ID ổn định", function()
        expect.eq(#Terrains.list, 12)
        expect.eq(Terrains.byId["DH-03"].en, "Mountain")
        expect.eq(#Strategic.list, 12)
        expect.eq(Strategic.byId["TN-12"].rarity, "very_rare")
        expect.truthy(Strategic.allowedOn("TN-12", "DH-07"))
        expect.falsy(Strategic.allowedOn("TN-10", "DH-02"))
    end)
end)

describe("mapgen", function()
    it("cùng seed + số người cho map giống hệt", function()
        local a = Mapgen.generate({ seed = 2024, players = 3 })
        local b = Mapgen.generate({ seed = 2024, players = 3 })
        expect.deepEq(snapshot(a), snapshot(b))
    end)

    it("seed khác cho map khác", function()
        local a = Mapgen.generate({ seed = 1, players = 2 })
        local b = Mapgen.generate({ seed = 2, players = 2 })
        local sa, sb, diff = snapshot(a), snapshot(b), 0
        for i = 1, #sa do if sa[i] ~= sb[i] then diff = diff + 1 end end
        expect.truthy(diff > 10, "hai map gần như giống nhau")
    end)

    for players = 1, 4 do
        it("ràng buộc đúng với " .. players .. " người (30 seed)", function()
            local size = C.MAP_SIZE_BY_PLAYERS[players]
            for seed = 1, 30 do
                local map = Mapgen.generate({ seed = seed, players = players })
                local tag = "players " .. players .. " seed " .. seed

                expect.eq(map.cols, size[1], tag)
                expect.eq(map.rows, size[2], tag)
                expect.eq(#map.list, size[1] * size[2], tag)

                local distinct = 0
                for _ in pairs(map:countByTerrain()) do distinct = distinct + 1 end
                expect.eq(distinct, C.TERRAINS_PER_GAME, tag .. ": số loại địa hình")

                expect.eq(#map.settlements, players + 1, tag .. ": Khu Dân Cư")
                expect.eq(#map.landmarks, players + 1, tag .. ": Danh Thắng")
                expect.eq(#map.starts, players, tag .. ": khởi đầu")

                -- mỗi tâm khởi đầu: HQ hợp lệ, 6 ô kề đi được, đủ 19 ô vùng an toàn
                for i, s in ipairs(map.starts) do
                    local center = map:get(s.q, s.r)
                    expect.truthy(Terrains.byId[center.terrain].canHQ, tag .. ": HQ " .. i .. " không hợp lệ")
                    local ns = map:neighbors(center)
                    expect.eq(#ns, 6, tag)
                    for _, n in ipairs(ns) do
                        expect.truthy(Terrains.byId[n.terrain].passable, tag .. ": ô kề HQ không đi được")
                    end
                    expect.eq(#map:range(center, C.START_ZONE_RADIUS), 19, tag)
                    for j = i + 1, #map.starts do
                        local o = map.starts[j]
                        expect.truthy(Hex.distance(s, o) >= C.MIN_START_DISTANCE, tag .. ": 2 HQ quá gần")
                    end
                end

                -- Khu Dân Cư / Danh Thắng không đè lên vùng khởi đầu; TN đúng địa hình
                for _, t in ipairs(map.list) do
                    if t.settlement or t.landmark then expect.falsy(t.zone, tag .. ": đè vùng khởi đầu") end
                    if t.strategic then
                        expect.truthy(Strategic.allowedOn(t.strategic, t.terrain), tag .. ": TN sai địa hình")
                    end
                end

                local leys = 0
                for _, t in ipairs(map.list) do
                    if t.strategic == Strategic.LEY_NODE then leys = leys + 1 end
                end
                expect.truthy(leys >= 1 and leys <= 2, tag .. ": TN-12 có " .. leys)

                expect.truthy(Mapgen.validate(map, players), tag)
            end
        end)
    end

    it("kích thước cụm Khu Dân Cư nằm trong 2..10", function()
        for seed = 1, 20 do
            local map = Mapgen.generate({ seed = seed, players = 4 })
            for _, s in ipairs(map.settlements) do
                expect.truthy(s.size >= C.SETTLEMENT_SIZE_MIN and s.size <= C.SETTLEMENT_SIZE_MAX)
                expect.eq(s.cityState, s.size > C.CITY_STATE_THRESHOLD)
            end
            for _, l in ipairs(map.landmarks) do
                expect.truthy(l.size == 1 or l.size == 3 or l.size == 4)
            end
        end
    end)

    it("vùng khởi đầu công bằng: đủ ô xây được và chênh lệch nhỏ", function()
        for players = 2, 4 do
            for seed = 1, 30 do
                local map = Mapgen.generate({ seed = seed, players = players })
                local buildable = {}
                for i = 1, players do buildable[i] = 0 end
                for _, t in ipairs(map.list) do
                    if t.zone and Terrains.byId[t.terrain].canBuild then buildable[t.zone] = buildable[t.zone] + 1 end
                end
                local lo, hi = math.huge, 0
                for i = 1, players do lo, hi = math.min(lo, buildable[i]), math.max(hi, buildable[i]) end
                local tag = "players " .. players .. " seed " .. seed
                expect.truthy(lo >= C.START_ZONE_MIN_BUILDABLE, tag .. ": min " .. lo)
                expect.truthy(hi - lo <= C.START_ZONE_MAX_SPREAD, tag .. ": spread " .. (hi - lo))
            end
        end
    end)

    it("quét 100 seed: luôn sinh được và ít phải thử lại", function()
        for players = 1, 4 do
            local retries = 0
            for seed = 1000, 1099 do
                local map = Mapgen.generate({ seed = seed, players = players })
                retries = retries + (map.attempt - 1)
            end
            expect.truthy(retries / 100 < 3, "players " .. players .. ": trung bình " .. retries / 100 .. " lần thử lại")
        end
    end)

    it("số người không hợp lệ báo lỗi", function()
        expect.error(function() Mapgen.generate({ seed = 1, players = 5 }) end)
    end)
end)
