-- Thu nhập thụ động mỗi vòng (D-014): chạy ở đầu lượt của chính chủ (Upkeep), trước khi đổ xúc xắc.
-- Thuần Lua, không gọi love.*.
--
-- Nguồn:
--   * công trình cấp cao của chủ (`yield` trong src/data/buildings.lua);
--   * hiệu ứng địa hình (`effects.passive`, ví dụ Rừng: Viện NC C1 +1 KH), xét theo ô neo;
--   * TN trên ô thực hữu (Strategic.passive: TN-02 trên ô của chủ, TN-09 cho ô thực hữu kề).
-- Công trình bị Phiến Quân phong tỏa (bất kỳ ô nào) hoặc đang chờ dỡ không nhận thu nhập; ô TN bị phong tỏa cũng vậy.
-- Phần lẻ (0.5) dồn vào player.carry và chỉ cộng vào tài nguyên khi đủ 1.

local C          = require("src.config.constants")
local Wallet = require("src.core.wallet")
local Hex        = require("src.core.hex")
local Roads      = require("src.core.roads")
local Derived    = require("src.core.derived")
local Rebel      = require("src.core.rebel")
local Structures = require("src.core.structures")
local Upkeep     = require("src.core.upkeep")
local Buildings  = require("src.data.buildings")
local Strategic  = require("src.data.strategic")
local Terrains   = require("src.data.terrains")

local Passives = {}

-- Số ô thực hữu của `pid` nằm kề footprint (không thuộc footprint), mỗi ô tính một lần.
local function adjacentOwned(state, pid, tiles)
    local inFoot, seen, n = {}, {}, 0
    for _, t in ipairs(tiles) do inFoot[t.q .. "," .. t.r] = true end
    for _, t in ipairs(tiles) do
        for _, h in ipairs(Hex.ring(t, 1)) do
            local k = h.q .. "," .. h.r
            if not inFoot[k] and not seen[k] and state.owner[k] == pid and state.map:get(h.q, h.r) then
                seen[k] = true
                n = n + 1
            end
        end
    end
    return n
end

local function blocked(state, tiles)
    for _, t in ipairs(tiles) do
        if Rebel.isBlockaded(state, t) then return true end
    end
    return false
end

-- Danh sách { src, res, amount, q, r } thu nhập thụ động của `pid` (không đổi state).
function Passives.compute(state, pid)
    local out = {}
    local function add(src, res, amount, tile)
        if amount > 0 then out[#out + 1] = { src = src, res = res, amount = amount, q = tile.q, r = tile.r } end
    end

    for _, b in ipairs(Structures.list(state)) do
        if b.owner == pid and not b.demolishing then
            local tiles = Structures.tilesOf(state, b)
            if not blocked(state, tiles) then
                local def = Buildings.level(b.id, b.level)
                for _, y in ipairs(def.yield or {}) do
                    if y.when == "rebel" then
                        if state.rebel then add(b.id, y.res, y.n, tiles[1]) end
                    elseif y.when == "adjacent" then
                        add(b.id, y.res, y.n * adjacentOwned(state, pid, tiles), tiles[1])
                    elseif y.when == "roads" then
                        add(b.id, y.res, y.n * math.min(C.MARKET_ROUTE_BONUS_MAX, Roads.adjacentRoadCount(state, tiles)),
                            tiles[1])
                    else
                        add(b.id, y.res, y.n, tiles[1])
                    end
                end
                local fx = Terrains.byId[tiles[1].terrain].effects
                for _, p in ipairs(fx and fx.passive or {}) do
                    if p.building == b.id and p.level == b.level then add(b.id, p.res, p.n, tiles[1]) end
                end
            end
        end
    end

    -- TN trên ô thực hữu (không cần công trình)
    for _, t in ipairs(state.map.list) do
        local tn = Structures.strategicAt(state, t)
        local def = tn and Strategic.passive[tn]
        if def and not Rebel.isBlockaded(state, t) then
            if def.own and state.owner[t.q .. "," .. t.r] == pid then
                for _, y in ipairs(def.own) do add(tn, y.res, y.n, t) end
            end
            if def.adjacent then
                for _, h in ipairs(Hex.ring(t, 1)) do
                    local nb = state.map:get(h.q, h.r)
                    if nb and state.owner[nb.q .. "," .. nb.r] == pid then
                        for _, y in ipairs(def.adjacent) do add(tn, y.res, y.n, nb) end
                    end
                end
            end
        end
    end
    return out
end

-- Áp dụng: cộng vào carry, phần nguyên chuyển sang tài nguyên. Trả events { kind = "passive", ... }.
function Passives.step(state, pid, events)
    local p = state.players[pid]
    for _, inst in ipairs(Derived.cleanup(state, pid)) do   -- Phái Sinh mất chủ / đối tác / ô riêng thì bị xóa
        events[#events + 1] = { kind = "derived_lost", pid = pid, id = inst.id }
    end
    local gains = Passives.compute(state, pid)
    for _, g in ipairs(Derived.tick(state, pid)) do gains[#gains + 1] = g end   -- thụ động Phái Sinh (chu kỳ, lãi)
    for _, g in ipairs(gains) do
        p.carry[g.res] = (p.carry[g.res] or 0) + g.amount
        events[#events + 1] = { kind = "passive", pid = pid, src = g.src, res = g.res, amount = g.amount, q = g.q, r = g.r }
    end
    for res, v in pairs(p.carry) do
        local whole = math.floor(v)
        if whole > 0 then Wallet.gain(p.res, res, whole) end
        p.carry[res] = v - whole
        if p.carry[res] == 0 then p.carry[res] = nil end
    end
end

Upkeep.register(Passives.step)

return Passives
