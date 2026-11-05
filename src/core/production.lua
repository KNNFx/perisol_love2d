-- Khâu Sản Xuất (Long Mạch). Luật: docs/Decisions.md D-008. Thuần Lua, không gọi love.*.
--
-- Mọi công trình của MỌI người chơi khớp mặt xúc xắc đều sản xuất, không phụ thuộc ai đổ.
-- Sản lượng = (giá trị trong bảng Data + bonus modifier) × số viên khớp. Tổng 7 -> không ai sản xuất.
-- Mặt Hex không sản xuất, chỉ cho người đang lượt phiếu Chi Phối.

local C         = require("src.config.constants")
local Wallet = require("src.core.wallet")
local Dice      = require("src.core.dice")
local Hex       = require("src.core.hex")
local Derived   = require("src.core.derived")
local Aura      = require("src.core.aura")
local Specials  = require("src.core.specials")
local State     = require("src.core.state")
local Modifiers = require("src.core.modifiers")
local Rebel     = require("src.core.rebel")
local Structures = require("src.core.structures")
local Territory = require("src.core.territory")
local Resources = require("src.data.resources")
local Buildings = require("src.data.buildings")
local Strategic = require("src.data.strategic")
local Terrains  = require("src.data.terrains")

local P = {}

-- Registry modifier dùng chung. Hệ thống khác (nhân vật, công nghệ, aura...) register vào đây.
P.modifiers = Modifiers.new()

-- Stage "base": hiệu ứng địa hình lên sản lượng (GDD §3.1: Lãnh Nguyên Vàng −1, Sa Mạc không ra Tín Ngưỡng).
-- Hiệu ứng địa hình luôn xét theo ô neo `ctx.tile` (D-014). Đồi Cỏ: Trại KT C2+ +1 KT mỗi viên khớp.
P.modifiers:register("base", function(value, ctx)
    local fx = Terrains.byId[ctx.tile.terrain].effects
    if fx and fx.bonus then
        for _, bn in ipairs(fx.bonus) do
            if bn.building == ctx.buildingId and ctx.level >= bn.minLevel and bn.face == ctx.face
                and bn.res == ctx.res then
                value = value + bn.n
            end
        end
    end
    local o = fx and fx.output and fx.output[ctx.res]
    if o == "none" then return 0 end
    if o then return math.max(0, value + o) end
    return value
end)

-- Stage "strategic": bonus của TN chưa bị mất (D-014) trên MỖI ô thuộc footprint (`ctx.tiles`).
P.modifiers:register("strategic", function(value, ctx)
    for _, t in ipairs(ctx.tiles or { ctx.tile }) do
        local tn = Structures.strategicAt(ctx.state, t)
        local b = tn and Strategic.productionBonus[tn]
        if b and (not b.building or b.building == ctx.buildingId)
            and (b.all or (b.face == ctx.face and b.res == ctx.res)) then
            value = value + b.n
        end
    end
    return value
end)

-- Stage "aura": HQ C5 cho +1 sản lượng mỗi viên cho công trình "nội đô" của chủ, tức ô neo trong bán kính
-- HQ_C5_AURA_RADIUS quanh Nhà Chính (Data §9.1, D-016).
P.modifiers:register("aura", function(value, ctx)
    local state = ctx.state
    local p = state.players[ctx.owner]
    if p and p.hq and p.hqLevel >= C.HQ_AURA_LEVEL and Hex.distance(p.hq, ctx.tile) <= C.HQ_C5_AURA_RADIUS then
        value = value + 1
    end
    -- S-01 Tháp Thiên Văn: công trình của chủ trong aura +1 mỗi viên KH (D-019)
    if ctx.face == 1 and ctx.res == "science" then
        for _, b in ipairs(Aura.each(state, "S-01", ctx.owner)) do
            if Specials.isActive(state, b) and Aura.covers(state, b, ctx.tile) then value = value + 1 break end
        end
    end
    return value
end)

-- Có TN `tn` (chưa mất) trên ô nào của footprint không.
local function hasTN(state, tiles, tn)
    for _, t in ipairs(tiles) do
        if Structures.strategicAt(state, t) == tn then return true end
    end
    return false
end

-- Tính (không đổi state) danh sách sự kiện của một lần đổ.
--   { kind = "seven" }
--   { kind = "votes",   pid, amount }
--   { kind = "produce", pid, key, buildingId, level, face, res, amount, dice, roller }  (dice = số viên khớp)
function P.compute(state, dice, activePid, extras)
    if Dice.isSeven(dice) then return { { kind = "seven" } } end
    extras = extras or {}
    local derivedEvents, repl = Derived.produce(state, dice, activePid)   -- vật liệu Phái Sinh (thay một phần sản lượng công trình chủ)
    -- Địa Linh TN-12 (GDD 1.6 §3.4): mỗi viên Hex được chủ ô đổi thành một mặt tài nguyên cho riêng ô đó. extras = { { q, r, res } }.
    local function extraCount(tiles, face)
        local n = 0
        for _, x in ipairs(extras) do
            if Resources.byKey[x.res].face == face then
                for _, t in ipairs(tiles) do
                    if t.q == x.q and t.r == x.r then n = n + 1 break end
                end
            end
        end
        return n
    end

    local events = {}
    local hex = Dice.hexCount(dice)
    if hex > 0 then
        events[#events + 1] = { kind = "votes", pid = activePid, amount = hex * C.VOTES_PER_HEX_FACE }
    end

    for _, b in ipairs(Structures.list(state)) do
        local tiles = Structures.tilesOf(state, b)
        local tile, k = tiles[1], b.anchor
        local blocked = false
        for _, t in ipairs(tiles) do
            if Rebel.isBlockaded(state, t) then blocked = true end
        end
        if not blocked and not b.demolishing then
            -- TN-10 Cảng Tự Nhiên: Khu Chợ C1 sản xuất như C3.
            local prodLevel = b.level
            if b.id == "B-05" and b.level == 1 and hasTN(state, tiles, Strategic.HARBOR) then prodLevel = 3 end
            local def = Buildings.level(b.id, prodLevel)
            for _, entry in ipairs(def.produces) do
                local face, res, n = entry[1], entry[2], entry[3]
                local matching = Dice.count(dice, face) + extraCount(tiles, face)
                if matching > 0 then
                    local ctx = { state = state, tile = tile, tiles = tiles, buildingId = b.id, level = b.level,
                                  owner = b.owner, face = face, res = res, activePid = activePid }
                    local perDie = P.modifiers:apply(n, ctx)
                    local amount = perDie * matching
                    local r = repl[b.uid] and repl[b.uid][face]
                    if r then   -- Phái Sinh thay tài nguyên gốc (GDD 1.6 §8.2): bớt sản lượng của 1 viên hoặc 1 đơn vị
                        amount = math.max(0, amount - (r.mode == "die" and perDie or 1))
                    end
                    if amount > 0 then
                        events[#events + 1] = {
                            kind = "produce", pid = b.owner, key = k, buildingId = b.id, level = b.level,
                            face = face, res = res, amount = amount, dice = matching, roller = activePid,
                        }
                    end
                end
            end
        end
    end
    for _, e in ipairs(P.computeTiles(state, dice, activePid, extras)) do events[#events + 1] = e end   -- Tài Nguyên Cơ Bản trên ô
    for _, e in ipairs(derivedEvents) do events[#events + 1] = e end
    return events
end

-- Tài Nguyên Cơ Bản của ô (GDD 1.6 §3.3, D-020 #2): mỗi ô nhả (lượng CB + bonus TN cùng loại) x số viên khớp cho người
-- thu hoạch (chủ ô, hoặc người duy nhất có vùng ảnh hưởng phủ ô chưa có chủ). Ô bị Phiến Quân phong tỏa không nhả.
-- Công trình trên ô vẫn sản xuất riêng: hai nguồn cộng dồn.
--   { kind = "tile_produce", pid, q, r, res, amount, dice, roller }
function P.computeTiles(state, dice, activePid, extras)
    local out = {}
    extras = extras or {}
    local towers = {}   -- Tháp S-01 đang hoạt động theo chủ (tính một lần, không tính mỗi ô)
    for _, sb in ipairs(Aura.each(state, "S-01")) do
        if Specials.isActive(state, sb) then towers[sb.owner] = towers[sb.owner] or {}; table.insert(towers[sb.owner], sb) end
    end
    for _, tile in ipairs(state.map.list) do
        local tn = tile.strategic and Structures.strategicAt(state, tile) or nil
        local bonus = tn and Strategic.tileBonus[tn]
        if tile.base or bonus then
            local pid = Territory.harvester(state, tile)
            if pid and not Rebel.isBlockaded(state, tile) then
                for _, r in ipairs(Resources.core) do
                    local matching = Dice.count(dice, r.face)
                    for _, x in ipairs(extras) do
                        if x.q == tile.q and x.r == tile.r and x.res == r.key then matching = matching + 1 end   -- Hex đổi bởi TN-12
                    end
                    if matching > 0 then
                        local amount = (tile.base and tile.base[r.key]) or 0
                        if bonus and bonus.res == r.key and bonus.face == r.face then amount = amount + bonus.n end
                        if amount > 0 and r.key == "science" then   -- S-01: ô của bạn trong aura +1 KH mỗi viên (GDD 1.6 §8.3)
                            for _, sb in ipairs(towers[pid] or {}) do
                                if Aura.covers(state, sb, tile) then amount = amount + 1 break end
                            end
                        end
                        if amount > 0 then
                            out[#out + 1] = { kind = "tile_produce", pid = pid, q = tile.q, r = tile.r, res = r.key,
                                              amount = amount * matching, dice = matching, roller = activePid }
                        end
                    end
                end
            end
        end
    end
    return out
end

-- Các loại tài nguyên `tile` (ô Địa Linh) sản xuất: Tài Nguyên Cơ Bản của ô và tài nguyên mà công trình trên ô sản xuất,
-- theo thứ tự Resources.core.
local function leyOptions(state, tile)
    local have = {}
    for res in pairs(tile.base or {}) do have[res] = true end
    local b = Structures.at(state, tile)
    if b and not b.demolishing then
        local def = Buildings.level(b.id, b.level)
        for _, entry in ipairs(def and def.produces or {}) do have[entry[2]] = true end
    end
    local out = {}
    for _, r in ipairs(Resources.core) do if have[r.key] then out[#out + 1] = r.key end end
    return out
end

-- Địa Linh TN-12: mỗi viên Hex trong lần đổ cho mỗi ô Địa Linh (còn TN, có chủ, không bị phong tỏa) một lựa chọn của chủ ô.
-- Trả danh sách { pid, q, r, options } (chủ ô theo thứ tự ô trong bản đồ; mỗi viên Hex một lượt). Không đổi state.
function P.leyChoices(state, dice)
    local out = {}
    local hex = Dice.hexCount(dice)
    if hex == 0 then return out end
    for _, tile in ipairs(state.map.list) do
        if tile.strategic == Strategic.LEY_NODE and Structures.strategicAt(state, tile) == Strategic.LEY_NODE then
            local owner = state.owner[tile.q .. "," .. tile.r]
            local options = leyOptions(state, tile)
            if owner and #options > 0 and not Rebel.isBlockaded(state, tile) then
                for _ = 1, hex do out[#out + 1] = { pid = owner, q = tile.q, r = tile.r, options = options } end
            end
        end
    end
    return out
end

-- Áp dụng sự kiện vào state.
function P.apply(state, events)
    for _, e in ipairs(events) do
        if e.kind == "produce" or e.kind == "tile_produce" then
            Wallet.gain(state.players[e.pid].res, e.res, e.amount)
        elseif e.kind == "votes" then
            state.players[e.pid].votes = state.players[e.pid].votes + e.amount
        elseif e.kind == "bond_allow" then   -- Nhà Ngân Hàng: được chuyển thêm Vàng sang Tín Phiếu (lệnh convertBond)
            local p = state.players[e.pid]
            p.bondAllow = math.min(C.BOND_ALLOW_MAX, (p.bondAllow or 0) + e.amount)
        end
    end
end

-- compute + apply. Trả events.
function P.run(state, dice, activePid, extras)
    local events = P.compute(state, dice, activePid, extras)
    P.apply(state, events)
    return events
end

return P
