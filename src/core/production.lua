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
    if p and p.hq and p.hqLevel >= 5 and Hex.distance(p.hq, ctx.tile) <= C.HQ_C5_AURA_RADIUS then
        value = value + 1
    end
    -- S-01 Tháp Thiên Văn: công trình của chủ trong aura +1 mỗi viên KH (D-019)
    if ctx.face == 1 and ctx.res == "science" then
        for _, b in ipairs(Aura.each(state, "S-01", ctx.owner)) do
            if Specials.isActive(state, b) and Aura.covers(state, b, ctx.tile) then value = value + 1 break end
        end
    end
    -- S-04 Đài Phát Thanh: khi chủ đài đổ, công trình (của bất kỳ ai) trong bán kính 3 sản xuất +1 mỗi viên
    if ctx.activePid then
        for _, b in ipairs(Aura.each(state, "S-04", ctx.activePid)) do
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
function P.compute(state, dice, activePid)
    if Dice.isSeven(dice) then return { { kind = "seven" } } end

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
            -- TN-10 Cảng Tự Nhiên: Khu Chợ C1 sản xuất như C3. TN-12 Địa Linh: có ít nhất 1 viên khớp
            -- thì tính như cả 2 viên khớp (D-014).
            local prodLevel = b.level
            if b.id == "B-05" and b.level == 1 and hasTN(state, tiles, Strategic.HARBOR) then prodLevel = 3 end
            local ley = hasTN(state, tiles, Strategic.LEY_NODE)
            local def = Buildings.level(b.id, prodLevel)
            for _, entry in ipairs(def.produces) do
                local face, res, n = entry[1], entry[2], entry[3]
                local matching = Dice.count(dice, face)
                if matching > 0 and ley then matching = 2 end
                if matching > 0 then
                    local ctx = { state = state, tile = tile, tiles = tiles, buildingId = b.id, level = b.level,
                                  owner = b.owner, face = face, res = res, activePid = activePid }
                    local perDie = P.modifiers:apply(n, ctx)
                    if perDie > 0 then
                        events[#events + 1] = {
                            kind = "produce", pid = b.owner, key = k, buildingId = b.id, level = b.level,
                            face = face, res = res, amount = perDie * matching, dice = matching, roller = activePid,
                        }
                    end
                end
            end
        end
    end
    for _, e in ipairs(Derived.produce(state, dice, activePid)) do events[#events + 1] = e end   -- vật liệu Phái Sinh
    return events
end

-- Áp dụng sự kiện vào state.
function P.apply(state, events)
    for _, e in ipairs(events) do
        if e.kind == "produce" then
            Wallet.gain(state.players[e.pid].res, e.res, e.amount)
        elseif e.kind == "votes" then
            state.players[e.pid].votes = state.players[e.pid].votes + e.amount
        end
    end
end

-- compute + apply. Trả events.
function P.run(state, dice, activePid)
    local events = P.compute(state, dice, activePid)
    P.apply(state, events)
    return events
end

return P
