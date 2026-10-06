-- Khâu Sản Xuất (Long Mạch). Luật: docs/Decisions.md D-008. Thuần Lua, không gọi love.*.
--
-- Mọi công trình của MỌI người chơi khớp mặt xúc xắc đều sản xuất, không phụ thuộc ai đổ.
-- Sản lượng = (giá trị trong bảng Data + bonus modifier) × số viên khớp. Tổng 7 -> không ai sản xuất.
-- Mặt Hex không sản xuất, chỉ cho người đang lượt phiếu Chi Phối.

local C         = require("src.config.constants")
local Dice      = require("src.core.dice")
local State     = require("src.core.state")
local Modifiers = require("src.core.modifiers")
local Rebel     = require("src.core.rebel")
local Buildings = require("src.data.buildings")
local Strategic = require("src.data.strategic")
local Terrains  = require("src.data.terrains")

local P = {}

-- Registry modifier dùng chung. Hệ thống khác (nhân vật, công nghệ, aura...) register vào đây.
P.modifiers = Modifiers.new()

-- Stage "base": hiệu ứng địa hình lên sản lượng (GDD §3.1: Lãnh Nguyên Vàng −1, Sa Mạc không ra Tín Ngưỡng).
P.modifiers:register("base", function(value, ctx)
    local fx = Terrains.byId[ctx.tile.terrain].effects
    local o = fx and fx.output and fx.output[ctx.res]
    if o == "none" then return 0 end
    if o then return math.max(0, value + o) end
    return value
end)

-- Stage "strategic": bonus ô của tài nguyên chiến lược (ctx.tile.strategic).
P.modifiers:register("strategic", function(value, ctx)
    local tn = ctx.tile.strategic
    local b = tn and Strategic.productionBonus[tn]
    if not b then return value end
    if b.building and b.building ~= ctx.buildingId then return value end
    if b.all or (b.face == ctx.face and b.res == ctx.res) then return value + b.n end
    return value
end)

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

    for _, tile in ipairs(state.map.list) do
        local k = State.key(tile)
        local b = state.buildings[k]
        if b and not Rebel.isBlockaded(state, tile) then
            local def = Buildings.level(b.id, b.level)
            for _, entry in ipairs(def.produces) do
                local face, res, n = entry[1], entry[2], entry[3]
                local matching = Dice.count(dice, face)
                if matching > 0 then
                    local ctx = { state = state, tile = tile, buildingId = b.id, level = b.level,
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
    return events
end

-- Áp dụng sự kiện vào state.
function P.apply(state, events)
    for _, e in ipairs(events) do
        if e.kind == "produce" then
            local res = state.players[e.pid].res
            res[e.res] = res[e.res] + e.amount
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
