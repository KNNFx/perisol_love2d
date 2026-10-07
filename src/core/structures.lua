-- Công trình theo uid (D-014). Thuần Lua, không gọi love.*.
--
--   state.buildings[uid] = { uid, id, level, owner, tiles = { "q,r", ... }, anchor = "q,r", rot = 0 }
--   state.occupied["q,r"] = uid
--   state.lostStrategic["q,r"] = true     -- TN đã mất do dỡ công trình (map không được lưu, D-011)
--
-- Mọi code đọc/ghi công trình đi qua module này; không đụng state.buildings theo khóa ô nữa.

local State = require("src.core.state")

local S = {}

local key = State.key

-- Công trình đang chiếm `tile` hoặc nil.
function S.at(state, tile)
    local uid = state.occupied[key(tile)]
    return uid and state.buildings[uid] or nil
end

-- Chủ của công trình tại `tile` hoặc nil.
function S.ownerAt(state, tile)
    local b = S.at(state, tile)
    return b and b.owner or nil
end

-- Danh sách ô (bảng tile của map) mà công trình chiếm.
function S.tilesOf(state, b)
    local out = {}
    for _, k in ipairs(b.tiles) do
        local q, r = k:match("^(-?%d+),(-?%d+)$")
        out[#out + 1] = state.map:get(tonumber(q), tonumber(r))
    end
    return out
end

-- Đặt công trình mới. `tiles` là danh sách tile; tile đầu là ô neo. Trả công trình.
function S.place(state, spec, tiles)
    local uid = state.nextUid
    state.nextUid = uid + 1
    local keys = {}
    for i, t in ipairs(tiles) do
        keys[i] = key(t)
        assert(not state.occupied[keys[i]], "ô đã có công trình: " .. keys[i])
        state.occupied[keys[i]] = uid
    end
    local b = { uid = uid, id = spec.id, level = spec.level or 1, owner = spec.owner,
                tiles = keys, anchor = keys[1], rot = spec.rot or 0 }
    state.buildings[uid] = b
    return b
end

-- Gỡ công trình, giải phóng mọi ô.
function S.remove(state, uid)
    local b = state.buildings[uid]
    if not b then return end
    for _, k in ipairs(b.tiles) do state.occupied[k] = nil end
    state.buildings[uid] = nil
end

-- Danh sách công trình theo thứ tự uid (duyệt tất định).
function S.list(state)
    local out = {}
    for _, b in pairs(state.buildings) do out[#out + 1] = b end
    table.sort(out, function(a, c) return a.uid < c.uid end)
    return out
end

-- Tài nguyên chiến lược trên `tile` (nil nếu không có hoặc đã mất).
function S.strategicAt(state, tile)
    if state.lostStrategic[key(tile)] then return nil end
    return tile.strategic
end

return S
