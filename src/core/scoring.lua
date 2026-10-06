-- Tính điểm cuối ván (GDD §11.2, D-010). Thuần Lua, không gọi love.*.

local C         = require("src.config.constants")
local State     = require("src.core.state")
local Territory = require("src.core.territory")
local Resources = require("src.data.resources")

local Scoring = {}

local function totalResources(player)
    local n = 0
    for _, r in ipairs(Resources.core) do n = n + player.res[r.key] end
    return n
end

-- Điểm từng người chơi, kèm chi tiết theo tiêu chí. Trả list theo pid:
--   { pid, tiles, landmarks, buildings, resources, total, tileCount, leftover }
function Scoring.score(state)
    local tileCount, landmarkCount, buildingCount = {}, {}, {}
    for pid = 1, state.playerCount do tileCount[pid], landmarkCount[pid], buildingCount[pid] = 0, 0, 0 end

    for _, t in ipairs(state.map.list) do
        local o = state.owner[State.key(t)]
        if o then tileCount[o] = tileCount[o] + 1 end
    end

    -- Danh Thắng: người sở hữu nhiều ô nhất trong cụm (hơn hẳn) chi phối cả cụm (GDD §7.2, D-013)
    for _, lm in ipairs(state.map.landmarks or {}) do
        local owner = Territory.clusterController(state, lm)
        if owner then landmarkCount[owner] = landmarkCount[owner] + 1 end
    end

    for _, b in pairs(state.buildings) do
        if b.level >= 2 then buildingCount[b.owner] = buildingCount[b.owner] + 1 end
    end

    local out = {}
    for pid = 1, state.playerCount do
        local leftover = totalResources(state.players[pid])
        local s = {
            pid = pid, tileCount = tileCount[pid], leftover = leftover,
            tiles = tileCount[pid] * C.SCORE_TILE,
            landmarks = landmarkCount[pid] * C.SCORE_LANDMARK,
            buildings = buildingCount[pid] * C.SCORE_BUILDING_C2,
            resources = math.floor(leftover / C.SCORE_RES_PER_POINT),
        }
        s.total = s.tiles + s.landmarks + s.buildings + s.resources
        out[pid] = s
    end
    return out
end

-- Xếp hạng: điểm, rồi số ô thực hữu, rồi tổng tài nguyên. Vẫn hòa thì đồng hạng.
-- Trả list đã sắp xếp, mỗi phần tử có thêm `rank`.
function Scoring.ranking(state)
    local list = Scoring.score(state)
    table.sort(list, function(a, b)
        if a.total ~= b.total then return a.total > b.total end
        if a.tileCount ~= b.tileCount then return a.tileCount > b.tileCount end
        if a.leftover ~= b.leftover then return a.leftover > b.leftover end
        return a.pid < b.pid
    end)
    local function same(a, b)
        return a.total == b.total and a.tileCount == b.tileCount and a.leftover == b.leftover
    end
    for i, s in ipairs(list) do
        s.rank = (i > 1 and same(s, list[i - 1])) and list[i - 1].rank or i
    end
    return list
end

return Scoring
