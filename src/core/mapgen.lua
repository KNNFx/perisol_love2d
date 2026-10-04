-- Sinh bản đồ ngẫu nhiên, tất định theo seed. Thuần Lua, không gọi love.*
-- Quy trình (xem plan.md P1): rút 7 địa hình -> nền Voronoi -> bờ biển/sông -> vùng khởi đầu
-- -> Khu Dân Cư -> Danh Thắng -> tài nguyên chiến lược -> kiểm tra hợp lệ (fail thì thử lại).

local C         = require("src.config.constants")
local Hex       = require("src.core.hex")
local Map       = require("src.core.map")
local Rng       = require("src.core.rng")
local Terrains  = require("src.data.terrains")
local Strategic = require("src.data.strategic")

local M = {}

local PLAINS, RIVER, COAST = Terrains.PLAINS, Terrains.RIVER, Terrains.COAST
local SETTLEMENT, LANDMARK = Terrains.SETTLEMENT, Terrains.LANDMARK

local RARITY_WEIGHT = { common = 3, uncommon = 2, rare = 1 }

local function terrainOf(tile) return Terrains.byId[tile.terrain] end

-- ─── 1. Rút 7 địa hình ─────────────────────────────────────────────────────
-- Luôn có Đồng Bằng (nền, đặt HQ), Khu Dân Cư và Danh Thắng (số lượng = người chơi + 1).
local function drawTerrains(rng)
    local chosen = { PLAINS, SETTLEMENT, LANDMARK }
    local pool = {}
    for _, t in ipairs(Terrains.list) do
        if t.id ~= PLAINS and t.id ~= SETTLEMENT and t.id ~= LANDMARK then pool[#pool + 1] = t end
    end
    while #chosen < C.TERRAINS_PER_GAME do
        local t = rng:weighted(pool, function(x) return RARITY_WEIGHT[x.rarity] or 1 end)
        chosen[#chosen + 1] = t.id
        for i, x in ipairs(pool) do
            if x == t then table.remove(pool, i) break end
        end
    end
    return chosen
end

local function contains(list, v)
    for _, x in ipairs(list) do if x == v then return true end end
    return false
end

-- ─── 2. Nền Voronoi ────────────────────────────────────────────────────────
local function voronoiBase(map, rng, chosen)
    local types = { PLAINS }
    for _, id in ipairs(chosen) do
        if id ~= PLAINS and id ~= RIVER and id ~= COAST and id ~= SETTLEMENT and id ~= LANDMARK then
            types[#types + 1] = id
        end
    end

    local seedCount = math.max(#types, math.floor(#map.list * C.REGION_SEED_DENSITY + 0.5))
    local picked = {}
    local order = {}
    for i, t in ipairs(map.list) do order[i] = t end
    rng:shuffle(order)

    local seeds = {}
    for i = 1, seedCount do
        local tile = order[i]
        local terrain
        if i <= #types then
            terrain = types[i]                       -- mỗi loại có ít nhất 1 hạt giống
        else
            terrain = rng:weighted(types, function(id) return id == PLAINS and 2 or 1 end)
        end
        seeds[i] = { q = tile.q, r = tile.r, terrain = terrain }
        picked[i] = tile
    end

    for _, tile in ipairs(map.list) do
        local best, bestD = nil, math.huge
        for _, s in ipairs(seeds) do
            local d = Hex.distance(tile, s) + rng:next() * 0.8   -- nhiễu để viền không thẳng tắp
            if d < bestD then best, bestD = s, d end
        end
        tile.terrain = best.terrain
    end
end

-- ─── 3. Bờ biển & sông ─────────────────────────────────────────────────────
local function carveCoast(map, rng)
    local depth = rng:int(C.COAST_DEPTH_MIN, C.COAST_DEPTH_MAX)
    local edge = rng:int(1, 4)   -- 1 trên, 2 dưới, 3 trái, 4 phải
    for _, t in ipairs(map.list) do
        local hit = (edge == 1 and t.row < depth) or (edge == 2 and t.row >= map.rows - depth)
            or (edge == 3 and t.col < depth) or (edge == 4 and t.col >= map.cols - depth)
        if hit then t.terrain = COAST end
    end
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function carveRiver(map, rng)
    local horizontal = rng:chance(0.7)
    local points = {}
    local steps = 4
    for i = 0, steps do
        local f = i / steps
        local col, row
        if horizontal then
            col = math.floor(f * (map.cols - 1) + 0.5)
            row = rng:int(1, math.max(1, map.rows - 2))
        else
            row = math.floor(f * (map.rows - 1) + 0.5)
            col = rng:int(1, math.max(1, map.cols - 2))
        end
        points[#points + 1] = Hex.fromOffset(clamp(col, 0, map.cols - 1), clamp(row, 0, map.rows - 1))
    end
    for i = 1, #points - 1 do
        for _, h in ipairs(Hex.line(points[i], points[i + 1])) do
            local t = map:get(h.q, h.r)
            if t then t.terrain = RIVER end
        end
    end
end

-- ─── 4. Vùng khởi đầu ──────────────────────────────────────────────────────
local function startCandidate(map, tile)
    local def = terrainOf(tile)
    if not def.canHQ then return false end
    local zone = map:range(tile, C.START_ZONE_RADIUS)
    if #zone < 3 * C.START_ZONE_RADIUS * (C.START_ZONE_RADIUS + 1) + 1 then return false end  -- đủ 19 ô trong map
    for _, n in ipairs(map:neighbors(tile)) do
        if not terrainOf(n).passable then return false end
    end
    local blocked = 0
    for _, z in ipairs(zone) do
        if not terrainOf(z).passable then blocked = blocked + 1 end
    end
    return blocked <= 3
end

local function placeStarts(map, rng, players)
    local candidates = {}
    for _, t in ipairs(map.list) do
        if startCandidate(map, t) then candidates[#candidates + 1] = t end
    end
    if #candidates < players then return false end

    local best, bestScore
    for _ = 1, 20 do
        local order = {}
        for i, t in ipairs(candidates) do order[i] = t end
        rng:shuffle(order)
        local picked = {}
        for _, t in ipairs(order) do
            local ok = true
            for _, p in ipairs(picked) do
                if Hex.distance(t, p) < C.MIN_START_DISTANCE then ok = false break end
            end
            if ok then
                picked[#picked + 1] = t
                if #picked == players then break end
            end
        end
        if #picked == players then
            local score = math.huge
            for i = 1, #picked do
                for j = i + 1, #picked do
                    score = math.min(score, Hex.distance(picked[i], picked[j]))
                end
            end
            if players == 1 then score = 0 end
            if not bestScore or score > bestScore then best, bestScore = picked, score end
        end
    end
    if not best then return false end

    for i, center in ipairs(best) do
        map.starts[i] = { q = center.q, r = center.r, col = center.col, row = center.row }
        for _, z in ipairs(map:range(center, C.START_ZONE_RADIUS)) do
            z.zone = z.zone or i
        end
        center.isStart = i
    end
    return true
end

-- ─── 5. Khu Dân Cư ────────────────────────────────────────────────────────
local function settlementEligible(tile, id)
    if tile.zone or tile.settlement or tile.landmark or tile.isStart then return false end
    local def = terrainOf(tile)
    if not def.passable or tile.terrain == RIVER then return false end
    return true
end

local function placeSettlements(map, rng, count)
    local area = #map.list
    local cap = clamp(math.floor(area / 16), C.SETTLEMENT_SIZE_MIN, C.SETTLEMENT_SIZE_MAX)
    map.settlements = {}

    for id = 1, count do
        local placed
        for _ = 1, 30 do
            -- thiên về cụm nhỏ (u^2), thỉnh thoảng mới ra cụm lớn / Thành Bang
            local u = rng:next()
            local size = math.min(cap, C.SETTLEMENT_SIZE_MIN + math.floor((cap - C.SETTLEMENT_SIZE_MIN + 1) * u * u))
            local start = map.list[rng:int(1, #map.list)]
            local function free(t)
                if not settlementEligible(t, id) then return false end
                for _, n in ipairs(map:neighbors(t)) do
                    if n.settlement and n.settlement ~= id then return false end
                end
                return true
            end
            if free(start) then
                local tiles = { start }
                start.settlement = id
                local frontier = { start }
                local guard = 0
                while #tiles < size and #frontier > 0 and guard < 200 do
                    guard = guard + 1
                    local from = frontier[rng:int(1, #frontier)]
                    local options = {}
                    for _, n in ipairs(map:neighbors(from)) do
                        if not n.settlement and free(n) then options[#options + 1] = n end
                    end
                    if #options == 0 then
                        for i, f in ipairs(frontier) do
                            if f == from then table.remove(frontier, i) break end
                        end
                    else
                        local n = options[rng:int(1, #options)]
                        n.settlement = id
                        tiles[#tiles + 1] = n
                        frontier[#frontier + 1] = n
                    end
                end
                if #tiles >= C.SETTLEMENT_SIZE_MIN then
                    for _, t in ipairs(tiles) do
                        t.terrain = SETTLEMENT
                    end
                    placed = { id = id, tiles = tiles, size = #tiles, cityState = #tiles > C.CITY_STATE_THRESHOLD }
                    break
                end
                for _, t in ipairs(tiles) do t.settlement = nil end   -- hoàn tác, thử chỗ khác
            end
        end
        if not placed then return false end
        map.settlements[id] = placed
    end
    return true
end

-- ─── 6. Danh Thắng ────────────────────────────────────────────────────────
-- Hình dạng: đơn (1), tam giác (3), tứ giác hình thoi (4).
local function landmarkShape(shape, dir)
    local D = Hex.DIRECTIONS
    local a, b = D[dir], D[dir % 6 + 1]
    if shape == 1 then return { { q = 0, r = 0 } } end
    if shape == 3 then return { { q = 0, r = 0 }, { q = a.q, r = a.r }, { q = b.q, r = b.r } } end
    return { { q = 0, r = 0 }, { q = a.q, r = a.r }, { q = b.q, r = b.r }, { q = a.q + b.q, r = a.r + b.r } }
end

local function landmarkEligible(map, tile)
    if tile.zone or tile.settlement or tile.landmark or tile.isStart then return false end
    if tile.terrain == RIVER or not terrainOf(tile).passable then return false end
    for _, n in ipairs(map:neighbors(tile)) do
        if n.landmark then return false end    -- không dính nhau
    end
    return true
end

local function placeLandmarks(map, rng, count)
    map.landmarks = {}
    for id = 1, count do
        local placed
        for _ = 1, 200 do
            local shape = rng:pick({ 1, 3, 4 })
            local offsets = landmarkShape(shape, rng:int(1, 6))
            local origin = map.list[rng:int(1, #map.list)]
            local tiles, ok = {}, true
            for _, o in ipairs(offsets) do
                local t = map:get(origin.q + o.q, origin.r + o.r)
                if not t or not landmarkEligible(map, t) then ok = false break end
                tiles[#tiles + 1] = t
            end
            if ok then
                for _, t in ipairs(tiles) do t.terrain = LANDMARK; t.landmark = id end
                placed = { id = id, tiles = tiles, size = #tiles }
                break
            end
        end
        if not placed then return false end
        map.landmarks[id] = placed
    end
    return true
end

-- ─── 7. Tài nguyên chiến lược ─────────────────────────────────────────────
local function placeStrategic(map, rng)
    for _, tile in ipairs(map.list) do
        if tile.terrain ~= SETTLEMENT and tile.terrain ~= LANDMARK and not tile.isStart then
            local eligible = {}
            local total = 0
            for _, tn in ipairs(Strategic.list) do
                if tn.id ~= Strategic.LEY_NODE and Strategic.allowedOn(tn.id, tile.terrain) then
                    local p = C.STRATEGIC_CHANCE[tn.rarity] or 0
                    eligible[#eligible + 1] = { tn = tn, p = p }
                    total = total + p
                end
            end
            local roll = rng:next()
            if roll < total then
                for _, e in ipairs(eligible) do
                    roll = roll - e.p
                    if roll < 0 then tile.strategic = e.tn.id break end
                end
            end
        end
    end

    -- TN-12 Địa Linh: 1–2 ô, bất kỳ địa hình nào
    local count = rng:int(C.LEY_NODE_COUNT[1], C.LEY_NODE_COUNT[2])
    local free = {}
    for _, t in ipairs(map.list) do
        if t.terrain ~= SETTLEMENT and t.terrain ~= LANDMARK and not t.isStart and not t.strategic then
            free[#free + 1] = t
        end
    end
    rng:shuffle(free)
    for i = 1, math.min(count, #free) do free[i].strategic = Strategic.LEY_NODE end
end

-- ─── 8. Kiểm tra hợp lệ ───────────────────────────────────────────────────
-- Trả về true, hoặc false + lý do. Dùng cả trong generate (để thử lại) và trong test.
function M.validate(map, players)
    local counts = map:countByTerrain()
    local distinct = 0
    for id, n in pairs(counts) do
        distinct = distinct + 1
        if n < C.MIN_TILES_PER_TERRAIN then return false, "địa hình " .. id .. " chỉ có " .. n .. " ô" end
    end
    if distinct ~= C.TERRAINS_PER_GAME then return false, "có " .. distinct .. " loại địa hình" end

    if #map.starts ~= players then return false, "số vùng khởi đầu sai" end

    -- Công bằng: mỗi vùng khởi đầu đủ ô xây được và không chênh nhau quá nhiều.
    local buildable = {}
    for i = 1, players do buildable[i] = 0 end
    for _, t in ipairs(map.list) do
        if t.zone and terrainOf(t).canBuild then buildable[t.zone] = buildable[t.zone] + 1 end
    end
    local lo, hi = math.huge, 0
    for i = 1, players do
        lo, hi = math.min(lo, buildable[i]), math.max(hi, buildable[i])
    end
    if lo < C.START_ZONE_MIN_BUILDABLE then return false, "vùng khởi đầu ít ô xây được (" .. lo .. ")" end
    if hi - lo > C.START_ZONE_MAX_SPREAD then return false, "vùng khởi đầu chênh lệch " .. (hi - lo) end
    if #map.settlements ~= players + 1 then return false, "số Khu Dân Cư sai" end
    if #map.landmarks ~= players + 1 then return false, "số Danh Thắng sai" end

    for _, t in ipairs(map.list) do
        if t.strategic and not Strategic.allowedOn(t.strategic, t.terrain) then
            return false, "TN " .. t.strategic .. " trên địa hình " .. t.terrain
        end
    end

    -- Mọi tâm khởi đầu / cụm / danh thắng phải thông nhau qua ô đi được.
    local from = map:get(map.starts[1].q, map.starts[1].r)
    local seen, queue, head = { [from] = true }, { from }, 1
    while head <= #queue do
        local cur = queue[head]; head = head + 1
        for _, n in ipairs(map:neighbors(cur)) do
            if not seen[n] and terrainOf(n).passable then
                seen[n] = true
                queue[#queue + 1] = n
            end
        end
    end
    for i, s in ipairs(map.starts) do
        if not seen[map:get(s.q, s.r)] then return false, "khởi đầu " .. i .. " bị cô lập" end
    end
    for _, group in ipairs({ map.settlements, map.landmarks }) do
        for id, g in ipairs(group) do
            if not seen[g.tiles[1]] then return false, "cụm " .. id .. " bị cô lập" end
        end
    end
    return true
end

-- ─── Điểm vào ──────────────────────────────────────────────────────────────
local function tryGenerate(rng, players)
    local size = C.MAP_SIZE_BY_PLAYERS[players]
    local map = Map.new(size[1], size[2])
    local chosen = drawTerrains(rng:fork("terrains"))

    voronoiBase(map, rng:fork("base"), chosen)
    if contains(chosen, COAST) then carveCoast(map, rng:fork("coast")) end
    if contains(chosen, RIVER) then carveRiver(map, rng:fork("river")) end

    if not placeStarts(map, rng:fork("starts"), players) then return nil, "không đặt được vùng khởi đầu" end
    if not placeSettlements(map, rng:fork("settlements"), players + 1) then return nil, "không đặt được Khu Dân Cư" end
    if not placeLandmarks(map, rng:fork("landmarks"), players + 1) then return nil, "không đặt được Danh Thắng" end
    placeStrategic(map, rng:fork("strategic"))

    map.terrains = chosen
    local ok, why = M.validate(map, players)
    if not ok then return nil, why end
    return map
end

-- opts = { seed = số|chuỗi, players = 1..4 }
function M.generate(opts)
    local players = opts.players or 4
    assert(C.MAP_SIZE_BY_PLAYERS[players], "số người chơi không hợp lệ: " .. tostring(players))
    local seed = opts.seed or 1
    local lastErr
    for attempt = 1, C.MAPGEN_MAX_ATTEMPTS do
        local rng = Rng.new(tostring(seed) .. ":" .. attempt)
        local map, err = tryGenerate(rng, players)
        if map then
            map.seed, map.players, map.attempt = seed, players, attempt
            return map
        end
        lastErr = err
    end
    error("mapgen thất bại sau " .. C.MAPGEN_MAX_ATTEMPTS .. " lần thử (seed " .. tostring(seed) .. "): " .. tostring(lastErr))
end

return M
