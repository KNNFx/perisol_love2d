-- Đường giao thông (D-016). Thuần Lua, không gọi love.*.
--
--   state.roads["q,r"] = { level = 1 | 2 }     1 = Đường Đất (độ bền 1), 2 = Đường Lát Đá (độ bền 2)
-- Đường không có chủ (Data Hỏi đáp #11): đơn vị Giao Thương tạo ra và vĩnh viễn thuộc về bản đồ cho tới khi
-- Phiến Quân phá. Module này chỉ chứa truy vấn và tìm tuyến; thanh toán và lệnh nằm ở game.lua / units.lua.

local C         = require("src.config.constants")
local State     = require("src.core.state")
local Structures = require("src.core.structures")
local Strategic = require("src.data.strategic")

local R = {}

local key = State.key

function R.get(state, tile) return state.roads[key(tile)] end
function R.has(state, tile) return state.roads[key(tile)] ~= nil end
function R.isStone(state, tile)
    local r = state.roads[key(tile)]
    return r ~= nil and r.level >= 2
end

-- Địa hình của `tile` cho xây đường được không (GDD §9.2).
function R.canBuildOn(tile) return C.ROAD_TERRAINS[tile.terrain] == true end

function R.build(state, tile) state.roads[key(tile)] = { level = 1 } end

-- Nâng Đường Đất lên Lát Đá (đã qua kiểm tra ở game.lua). Cùng R.build / R.damage* là nơi duy nhất ghi state.roads.
function R.upgrade(state, tile) state.roads[key(tile)].level = 2 end

-- Phiến Quân đi qua (không dừng): Đường Đất bị xóa, Lát Đá miễn nhiễm (Data §6.2). Trả true nếu có đổi.
function R.damagePass(state, tile)
    local r = state.roads[key(tile)]
    if r and r.level == 1 then state.roads[key(tile)] = nil return true end
    return false
end

-- Phiến Quân dừng: mọi đường trên ô −1 độ bền: Đất mất, Lát Đá tụt về Đất. Trả true nếu có đổi.
function R.damageStop(state, tile)
    local r = state.roads[key(tile)]
    if not r then return false end
    if r.level >= 2 then r.level = 1 else state.roads[key(tile)] = nil end
    return true
end

-- Danh sách tile có đường theo thứ tự hàng (tất định).
function R.list(state)
    local out = {}
    for _, t in ipairs(state.map.list) do
        if state.roads[key(t)] then out[#out + 1] = t end
    end
    return out
end

-- Số tile có đường kề footprint `tiles` (mỗi tile đếm một lần): dùng cho B-05 C2.
function R.adjacentRoadCount(state, tiles)
    local inFoot, seen, n = {}, {}, 0
    for _, t in ipairs(tiles) do inFoot[key(t)] = true end
    for _, t in ipairs(tiles) do
        for _, nb in ipairs(state.map:neighbors(t)) do
            local k = key(nb)
            if not inFoot[k] and not seen[k] and state.roads[k] then
                seen[k] = true
                n = n + 1
            end
        end
    end
    return n
end

-- Tuyến đường ngắn nhất (ít ô đường nhất) nối footprint A với footprint B qua các ô có đường.
-- Hai footprint kề nhau: tuyến dài 0. Trả { length, stone, harbor, path = { tile... } } hoặc nil.
--   stone  = có ít nhất 1 ô đường và mọi ô đường là Lát Đá
--   harbor = có ô đường nằm trên TN-10 Cảng Tự Nhiên (chưa mất)
function R.route(state, tilesA, tilesB)
    local inB = {}
    for _, t in ipairs(tilesB) do inB[key(t)] = true end
    local parent, queue, head = {}, {}, 1

    local function finish(lastKey)
        local path, k = {}, lastKey
        while k do
            table.insert(path, 1, state.map:get(k:match("^(-?%d+),(-?%d+)$")))
            k = parent[k]
        end
        local stone, harbor = #path > 0, false
        for _, t in ipairs(path) do
            if not R.isStone(state, t) then stone = false end
            if Structures.strategicAt(state, t) == Strategic.HARBOR then harbor = true end
        end
        return { length = #path, stone = stone, harbor = harbor, path = path }
    end

    -- nguồn: các ô footprint A. Kề B ngay thì tuyến 0.
    for _, a in ipairs(tilesA) do
        for _, nb in ipairs(state.map:neighbors(a)) do
            if inB[key(nb)] then return { length = 0, stone = false, harbor = false, path = {} } end
        end
    end
    for _, a in ipairs(tilesA) do
        for _, nb in ipairs(state.map:neighbors(a)) do
            local k = key(nb)
            if state.roads[k] and parent[k] == nil then parent[k] = false; queue[#queue + 1] = k end
        end
    end
    while head <= #queue do
        local k = queue[head]
        head = head + 1
        local tile = state.map:get(k:match("^(-?%d+),(-?%d+)$"))
        for _, nb in ipairs(state.map:neighbors(tile)) do
            local nk = key(nb)
            if inB[nk] then return finish(k) end
        end
        for _, nb in ipairs(state.map:neighbors(tile)) do
            local nk = key(nb)
            if state.roads[nk] and parent[nk] == nil then parent[nk] = k; queue[#queue + 1] = nk end
        end
    end
    return nil
end

return R
