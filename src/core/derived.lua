-- Công trình Phái Sinh D-01..D-05 (D-018). Thuần Lua, không gọi love.*.
--
--   state.derived[did] = { did, id = "D-01", owner, a = uid chủ, b = uid đối tác | nil, site = uid ô riêng | nil,
--                          dep = did Phái Sinh phụ thuộc | nil, timer = số lượt đã đếm cho thụ động chu kỳ }
-- Phái Sinh không tự có ô (trừ D-03 / D-05 có công trình "site" riêng trong state.buildings). "Hoạt động" được
-- tính lại mỗi lần sản xuất: hai công trình còn đủ cấp, còn nối nhau (liền kề, hoặc cách 1–2 ô có đường nối liên tục),
-- không bị Phiến Quân phong tỏa. Đường bị phá hoặc công trình bị dỡ thì Phái Sinh tạm ngừng / bị xóa.

local C          = require("src.config.constants")
local Dice       = require("src.core.dice")
local Hex        = require("src.core.hex")
local Rebel      = require("src.core.rebel")
local Roads      = require("src.core.roads")
local State      = require("src.core.state")
local Structures = require("src.core.structures")
local Territory  = require("src.core.territory")
local Derived    = require("src.data.derived")

local D = {}

local key = State.key

function D.def(id) return Derived.byId[id] end

-- Các instance theo thứ tự did (duyệt tất định); `pid` nil = mọi người.
function D.list(state, pid)
    local out = {}
    for _, inst in pairs(state.derived) do
        if not pid or inst.owner == pid then out[#out + 1] = inst end
    end
    table.sort(out, function(x, y) return x.did < y.did end)
    return out
end

local function tilesOf(state, uid)
    local b = state.buildings[uid]
    return b and Structures.tilesOf(state, b) or nil
end

-- Số ô trống giữa hai footprint (khoảng cách hex gần nhất − 1; kề nhau = 0).
function D.gap(tilesA, tilesB)
    local best = math.huge
    for _, x in ipairs(tilesA) do
        for _, y in ipairs(tilesB) do best = math.min(best, Hex.distance(x, y)) end
    end
    return best - 1
end

-- Hai footprint nối được không? Trả ok, dùngĐường (true nếu phải nhờ đường), lý do.
-- Quy tắc GDD §8.2: 0 ô = liền kề; 1–2 ô cần đường liên tục; từ 3 ô trở lên không thể.
function D.link(state, tilesA, tilesB, maxGap)
    local gap = D.gap(tilesA, tilesB)
    if gap > math.min(maxGap, C.DERIVED_MAX_GAP) then
        return false, false, string.format("Hai công trình cách %d ô, tối đa %d", gap, maxGap)
    end
    if gap == 0 then return true, false end
    if Roads.route(state, tilesA, tilesB) then return true, true end
    return false, false, "Cần đường liên tục nối hai công trình"
end

local function blocked(state, tiles)
    for _, t in ipairs(tiles) do
        if Rebel.isBlockaded(state, t) then return true end
    end
    return false
end

-- Công trình `uid` hợp lệ cho vai trò (id, cấp tối thiểu)? Trả building hoặc nil, lý do.
local function role(state, owner, uid, want, label)
    local b = uid and state.buildings[uid]
    if not b or b.owner ~= owner then return nil, "Không có " .. label end
    if b.demolishing then return nil, label .. " đang chờ dỡ" end
    if b.id ~= want[1] then return nil, label .. " sai loại công trình" end
    if b.level < want[2] then return nil, string.format("%s cần cấp %d trở lên", label, want[2]) end
    return b
end

-- Đánh giá liên kết của một instance (hoặc ứng viên `inst` chưa lưu): trả ok, dùngĐường, lý do.
function D.evaluate(state, inst)
    local def = D.def(inst.id)
    local a, why = role(state, inst.owner, inst.a, def.host, "công trình chủ")
    if not a then return false, false, why end
    local aTiles = Structures.tilesOf(state, a)
    local usedRoad = false
    local sitedTiles
    if def.site then
        local site = inst.site and state.buildings[inst.site]
        if not site or site.owner ~= inst.owner then return false, false, "Ô công trình riêng đã mất" end
        sitedTiles = Structures.tilesOf(state, site)
    end

    if def.partner then
        local b, whyB = role(state, inst.owner, inst.b, def.partner, "công trình đối tác")
        if not b then return false, false, whyB end
        local bTiles = Structures.tilesOf(state, b)
        local ok, road, whyL = D.link(state, aTiles, bTiles, def.maxGap)
        if not ok then return false, false, whyL end
        usedRoad = road
        if blocked(state, bTiles) then return false, false, "Bị Phiến Quân phong tỏa" end
    end
    if def.dep then
        local dep = state.derived[inst.dep or -1]
        if not dep or dep.id ~= def.dep or dep.owner ~= inst.owner or not D.evaluate(state, dep) then
            return false, false, "Cần " .. D.def(def.dep).name .. " đang hoạt động"
        end
    end
    if def.site then
        -- D-03: ô riêng phải liền kề công trình chủ; D-05: ô riêng cách chủ tối đa maxGap (đường nếu không liền)
        local siteMax = def.partner and 0 or def.maxGap
        local ok, road, whyS = D.link(state, sitedTiles, aTiles, siteMax)
        if not ok then return false, false, whyS end
        usedRoad = usedRoad or road
        if blocked(state, sitedTiles) then return false, false, "Bị Phiến Quân phong tỏa" end
    end
    if blocked(state, aTiles) then return false, false, "Bị Phiến Quân phong tỏa" end
    return true, usedRoad
end

function D.isActive(state, inst) return (D.evaluate(state, inst)) end

-- ─── Xây ────────────────────────────────────────────────────────────────────

-- Ứng viên đối tác cho Phái Sinh `id` gắn vào công trình chủ `aUid`: danh sách uid (D-05: danh sách did phụ thuộc).
function D.partnerCandidates(state, pid, id, aUid)
    local def = D.def(id)
    local out = {}
    local a = role(state, pid, aUid, def.host, "chủ")
    if not a then return out end
    if def.dep then
        for _, inst in ipairs(D.list(state, pid)) do
            if inst.id == def.dep and D.isActive(state, inst) then out[#out + 1] = inst.did end
        end
        return out
    end
    for _, b in ipairs(Structures.list(state)) do
        if b.owner == pid and b.uid ~= aUid and role(state, pid, b.uid, def.partner, "đối tác") then
            local ok = D.link(state, Structures.tilesOf(state, a), Structures.tilesOf(state, b), def.maxGap)
            if ok then out[#out + 1] = b.uid end
        end
    end
    return out
end

-- Các ô có thể đặt công trình riêng của `id` (D-03 / D-05) cạnh chủ `aUid`.
function D.siteCandidates(state, pid, id, aUid)
    local def = D.def(id)
    local out = {}
    if not def.site then return out end
    local a = state.buildings[aUid]
    if not a then return out end
    local aTiles = Structures.tilesOf(state, a)
    local seen = {}
    local radius = def.partner and 1 or (def.maxGap + 1)
    for _, t in ipairs(aTiles) do
        for _, h in ipairs(Hex.range(t, radius)) do
            local tile = state.map:get(h.q, h.r)
            if tile and not seen[key(tile)] then
                seen[key(tile)] = true
                if D.checkSite(state, pid, id, aUid, tile) then out[#out + 1] = tile end
            end
        end
    end
    table.sort(out, function(x, y) if x.r ~= y.r then return x.r < y.r end return x.q < y.q end)
    return out
end

-- Ô `tile` hợp lệ làm công trình riêng cho `id` cạnh chủ `aUid`? Trả ok, lý do.
function D.checkSite(state, pid, id, aUid, tile)
    local def = D.def(id)
    if not tile then return false, "Không có ô này" end
    if state.owner[key(tile)] ~= pid then return false, "Chỉ xây trên lãnh thổ thực hữu của bạn" end
    if Structures.at(state, tile) or Territory.isAnchorTile(state, tile) then return false, "Ô đã có công trình" end
    if Rebel.isBlockaded(state, tile) then return false, "Ô đang bị Phiến Quân phong tỏa" end
    if not def.siteTerrains[tile.terrain] then return false, "Địa hình này không xây được " .. def.name end
    local a = state.buildings[aUid]
    local siteMax = def.partner and 0 or def.maxGap
    local ok, _, why = D.link(state, { tile }, Structures.tilesOf(state, a), siteMax)
    if not ok then return false, why end
    return true
end

-- Kiểm tra lập Phái Sinh `id` (chưa tính tiền). `sel` = { a = uid, b = uid | did, tile }. Trả ok, lý do.
function D.checkBuild(state, pid, id, sel)
    local def = D.def(id)
    if not def then return false, "Công trình Phái Sinh không tồn tại" end
    local a, why = role(state, pid, sel.a, def.host, "công trình chủ")
    if not a then return false, why end
    for _, inst in pairs(state.derived) do
        if inst.id == id and inst.a == sel.a and inst.owner == pid then return false, "Đã có " .. def.name .. " ở công trình này" end
    end
    local cand = { id = id, owner = pid, a = sel.a }
    if def.dep then
        local dep = state.derived[sel.b or -1]
        if not dep or dep.owner ~= pid or dep.id ~= def.dep or not D.isActive(state, dep) then
            return false, "Cần " .. D.def(def.dep).name .. " đang hoạt động"
        end
        cand.dep = dep.did
    elseif def.partner then
        local b, whyB = role(state, pid, sel.b, def.partner, "công trình đối tác")
        if not b then return false, whyB end
        local ok, _, whyL = D.link(state, Structures.tilesOf(state, a), Structures.tilesOf(state, b), def.maxGap)
        if not ok then return false, whyL end
        cand.b = sel.b
    end
    if def.site then
        local okS, whyS = D.checkSite(state, pid, id, sel.a, sel.tile)
        if not okS then return false, whyS end
    end
    return true, nil, cand
end

-- Áp dụng (đã qua checkBuild và thanh toán). Trả instance.
function D.build(state, pid, id, sel)
    local ok, why, cand = D.checkBuild(state, pid, id, sel)
    assert(ok, why)
    local def = D.def(id)
    if def.site then
        local site = Structures.place(state, { id = id, level = 1, owner = pid }, { sel.tile })
        cand.site = site.uid
    end
    local did = state.nextDerivedUid
    state.nextDerivedUid = did + 1
    cand.did, cand.timer = did, 0
    state.derived[did] = cand
    return cand
end

-- Xóa các instance mà công trình chủ / đối tác / ô riêng không còn. Trả danh sách instance đã xóa.
function D.cleanup(state, pid)
    local removed = {}
    for _, inst in ipairs(D.list(state, pid)) do
        local def = D.def(inst.id)
        local gone = not state.buildings[inst.a]
            or (def.partner and not state.buildings[inst.b or -1])
            or (def.site and not state.buildings[inst.site or -1])
            or (def.dep and not state.derived[inst.dep or -1])
        if gone then
            removed[#removed + 1] = inst
            state.derived[inst.did] = nil
            if def.site and inst.site and state.buildings[inst.site] then Structures.remove(state, inst.site) end
        end
    end
    return removed
end

-- ─── Sản xuất theo xúc xắc (Long Mạch chia sẻ) ──────────────────────────────

-- Sự kiện produce vật liệu cho mọi Phái Sinh đang hoạt động: +1 vật liệu mỗi viên khớp mặt của nó.
function D.produce(state, dice, activePid)
    local events = {}
    for _, inst in ipairs(D.list(state)) do
        local def = D.def(inst.id)
        if D.isActive(state, inst) then
            local anchor = Structures.tilesOf(state, state.buildings[inst.a])[1]
            for _, face in ipairs(def.faces) do
                local n = Dice.count(dice, face)
                if n > 0 then
                    events[#events + 1] = {
                        kind = "produce", pid = inst.owner, key = key(anchor), buildingId = inst.id, level = 1,
                        face = face, res = def.material, amount = n, dice = n, roller = activePid,
                    }
                end
            end
        end
    end
    return events
end

-- ─── Thụ động đầu lượt chủ ──────────────────────────────────────────────────

local function adjacentTerrain(state, tiles, terrain)
    for _, t in ipairs(tiles) do
        for _, nb in ipairs(state.map:neighbors(t)) do
            if nb.terrain == terrain then return true end
        end
    end
    return false
end

-- Thu nhập thụ động của các Phái Sinh của `pid` (tăng bộ đếm chu kỳ). Trả { src, res, amount, q, r }.
-- Bộ đếm chỉ chạy khi đang hoạt động.
function D.tick(state, pid)
    local gains = {}
    for _, inst in ipairs(D.list(state, pid)) do
        local def = D.def(inst.id)
        local active, usedRoad = D.evaluate(state, inst)
        if active then
            local a = state.buildings[inst.a]
            local aTiles = Structures.tilesOf(state, a)
            local at = aTiles[1]
            local function add(res, amount) if amount > 0 then gains[#gains + 1] = { src = inst.id, res = res, amount = amount, q = at.q, r = at.r } end end
            if def.period then
                inst.timer = (inst.timer or 0) + 1
                if inst.timer >= def.period then inst.timer = 0; add(def.material, 1) end
            end
            if inst.id == "D-01" then
                for _, t in ipairs(aTiles) do
                    if Structures.strategicAt(state, t) == "TN-05" then add("alloy", C.TN05_ALLOY_BONUS) break end
                end
            elseif inst.id == "D-02" then
                if usedRoad then add("paper", 1) end
            elseif inst.id == "D-04" then
                if adjacentTerrain(state, aTiles, "DH-10") then add("silk", 1) end
                if adjacentTerrain(state, aTiles, "DH-08") or adjacentTerrain(state, aTiles, "DH-04") then add("silk", 1) end
            elseif inst.id == "D-05" then
                add("gold", C.BOND_INTEREST * state.players[pid].res.bond)
            end
        end
    end
    return gains
end

-- Có D-05 đang hoạt động của `pid` (cần cho việc đổi Tín Phiếu).
function D.hasBank(state, pid)
    for _, inst in ipairs(D.list(state, pid)) do
        if inst.id == "D-05" and D.isActive(state, inst) then return true end
    end
    return false
end

return D
