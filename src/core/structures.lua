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
        out[#out + 1] = state.map:get(State.unkey(k))
    end
    return out
end

-- Đặt công trình mới. `tiles` là danh sách tile; tile đầu là ô neo. Trả công trình.
function S.place(state, spec, tiles)
    local uid = state.nextUid
    assert(type(uid) == "number" and uid >= 1 and uid < math.huge and uid == math.floor(uid)
        and not state.buildings[uid], "UID công trình không hợp lệ")
    assert(#tiles > 0, "công trình phải chiếm ít nhất một ô")
    local keys = {}
    local seen = {}
    for i, t in ipairs(tiles) do
        keys[i] = key(t)
        assert(not seen[keys[i]], "footprint có ô trùng")
        assert(not state.occupied[keys[i]], "ô đã có công trình: " .. keys[i])
        seen[keys[i]] = true
    end
    state.nextUid = uid + 1
    for _, k in ipairs(keys) do state.occupied[k] = uid end
    local b = { uid = uid, id = spec.id, level = spec.level or 1, owner = spec.owner,
                tiles = keys, anchor = keys[1], rot = spec.rot or 0 }
    state.buildings[uid] = b
    return b
end

-- Nâng cấp tại chỗ: đổi cấp và mở rộng footprint. `tiles` là danh sách tile mới, ô cũ đứng trước
-- (ô neo = tile đầu giữ nguyên). Trả công trình.
function S.upgrade(state, uid, tiles, level, rot)
    local b = state.buildings[uid]
    assert(b, "công trình không tồn tại: " .. tostring(uid))
    local keys = {}
    local seen = {}
    for i, t in ipairs(tiles) do
        keys[i] = key(t)
        local at = state.occupied[keys[i]]
        assert(not seen[keys[i]], "footprint có ô trùng")
        assert(at == nil or at == uid, "ô đã có công trình khác: " .. keys[i])
        seen[keys[i]] = true
    end
    assert(keys[1] == b.anchor, "nâng cấp phải giữ ô neo")
    for _, k in ipairs(b.tiles) do assert(seen[k], "nâng cấp phải giữ mọi ô cũ") end
    for _, k in ipairs(keys) do state.occupied[k] = uid end
    b.tiles, b.anchor, b.level, b.rot = keys, keys[1], level, rot or b.rot
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
    for uid = 1, (state.nextUid or 1) - 1 do   -- uid tăng dần nên duyệt theo uid đã có thứ tự, không cần sắp xếp
        local b = state.buildings[uid]
        if b then out[#out + 1] = b end
    end
    return out
end

-- Khu Chợ (B-05) của `pid`, không chờ dỡ.
function S.isMarket(b, pid) return b.owner == pid and b.id == "B-05" and not b.demolishing end

-- Các Khu Chợ của `pid` theo thứ tự uid.
function S.marketsOf(state, pid)
    local out = {}
    for _, b in ipairs(S.list(state)) do
        if S.isMarket(b, pid) then out[#out + 1] = b end
    end
    return out
end

-- Tài nguyên chiến lược trên `tile` (nil nếu không có hoặc đã mất).
function S.strategicAt(state, tile)
    if state.lostStrategic[key(tile)] then return nil end
    return tile.strategic
end

return S
