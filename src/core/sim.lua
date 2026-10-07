-- Mô phỏng ván chơi bằng người chơi ngẫu nhiên (có thiên hướng) — bắt crash / vòng lặp vô hạn và
-- kiểm tra bất biến. Thuần Lua, không gọi love.*. Dùng trong tests/sim_spec.lua và `lovec . --sim N`.

local C         = require("src.config.constants")
local Game      = require("src.core.game")
local Rng       = require("src.core.rng")
local State     = require("src.core.state")
local Territory = require("src.core.territory")
local Units     = require("src.core.units")
local Buildings = require("src.data.buildings")
local Resources = require("src.data.resources")

local Sim = {}

local MAX_COMMANDS_PER_TURN = 40
local MAX_TOTAL_COMMANDS    = 100000

-- Trọng số chọn loại lệnh trong pha action (kiểu lệnh nào có thì mới được chọn).
local TYPE_WEIGHT = { build = 6, buyTile = 4, placeVote = 3, foundSub = 2, upgradeHQ = 2, trade = 1,
                         upgrade = 12, buyUnit = 3, moveUnit = 4, suppress = 3, garrison = 1 }
local P_END_TURN  = 0.12
local P_DEMOLISH  = 0.01   -- xác suất mỗi lệnh action chọn dỡ công trình hoặc giải thể đơn vị

-- Kiểm tra bất biến của state. Trả true hoặc false, mô tả lỗi.
function Sim.invariants(state)
    for pid, p in ipairs(state.players) do
        for _, group in ipairs({ Resources.core, Resources.materials }) do
            for _, r in ipairs(group) do
                local v = p.res[r.key]
                if type(v) ~= "number" or v < 0 or v ~= math.floor(v) then
                    return false, string.format("P%d %s = %s", pid, r.key, tostring(v))
                end
            end
        end
        if p.votes < 0 then return false, "P" .. pid .. " có phiếu âm" end
        for res, v in pairs(p.carry) do   -- phần lẻ chưa cộng: luôn trong [0, 1) và là bội của 0.5
            if type(v) ~= "number" or v < 0 or v >= 1 or (v * 2) ~= math.floor(v * 2) then
                return false, string.format("P%d carry %s = %s", pid, res, tostring(v))
            end
        end
    end

    for k, pid in pairs(state.owner) do
        if not state.players[pid] then return false, "chủ ô " .. k .. " không hợp lệ" end
    end

    local seen = 0
    for uid, b in pairs(state.buildings) do
        if b.uid ~= uid then return false, "uid công trình lệch " .. tostring(uid) end
        local def = Buildings.level(b.id, b.level)
        if not def or #b.tiles ~= def.tiles then
            return false, string.format("công trình %d (%s C%d) có %d ô, cần %d", uid, b.id, b.level, #b.tiles,
                def and def.tiles or -1)
        end
        for _, k in ipairs(b.tiles) do
            seen = seen + 1
            if state.occupied[k] ~= uid then return false, "occupied lệch tại " .. k end
            if state.owner[k] ~= b.owner then return false, "công trình " .. k .. " không nằm trên ô của chủ" end
            local tile = state.map:get(k:match("^(-?%d+),(-?%d+)$"))
            if not tile then return false, "công trình ngoài bản đồ " .. k end
            if not Buildings.allowedOn(b.id, b.level, tile.terrain) then
                return false, "công trình " .. k .. " trên địa hình không hợp lệ " .. tile.terrain
            end
            for pid in ipairs(state.players) do
                for _, a in ipairs(Territory.anchors(state, pid)) do
                    if a.q == tile.q and a.r == tile.r then return false, "công trình đè lên HQ " .. k end
                end
            end
        end
    end
    local occ = 0
    for _ in pairs(state.occupied) do occ = occ + 1 end
    if occ ~= seen then return false, "occupied có ô thừa" end

    local perQuota = {}
    for uid, u in pairs(state.units) do
        if u.uid ~= uid then return false, "uid đơn vị lệch " .. tostring(uid) end
        if not state.players[u.owner] then return false, "đơn vị " .. uid .. " có chủ không hợp lệ" end
        if not state.map:get(u.q, u.r) then return false, "đơn vị " .. uid .. " ngoài bản đồ" end
        if type(u.mp) ~= "number" or u.mp < 0 then return false, "đơn vị " .. uid .. " có mp " .. tostring(u.mp) end
        local def = Units.TYPES[u.type]
        if not def then return false, "loại đơn vị lạ " .. tostring(u.type) end
        local k = u.owner .. ":" .. def.quota
        perQuota[k] = (perQuota[k] or 0) + 1
        if perQuota[k] > Units.quotaMax(def.quota) then return false, "vượt quota đơn vị của P" .. u.owner end
    end

    -- ô không phải HQ/Sub chỉ có chủ khi chủ đủ phiếu theo ngưỡng
    for k, pid in pairs(state.owner) do
        local q, r = k:match("^(-?%d+),(-?%d+)$")
        local tile = state.map:get(tonumber(q), tonumber(r))
        if not Territory.isAnchorTile(state, tile) then
            local have = Territory.votesOn(state, tile, pid)
            local need = Territory.threshold(state, pid, tile)
            if have < need then
                return false, string.format("ô %s của P%d có %d phiếu < ngưỡng %d", k, pid, have, need)
            end
        end
    end

    if state.phase == "over" and state.round ~= C.ROUNDS_PER_GAME + 1 then
        return false, "ván kết thúc sai vòng " .. state.round
    end
    return true
end

local function chooseCommand(prng, state, legal, perTurn)
    if state.phase ~= "action" then return prng:pick(legal) end

    local byType, types, demolish = {}, {}, {}
    for _, cmd in ipairs(legal) do
        if cmd.type == "demolish" or cmd.type == "disband" then
            demolish[#demolish + 1] = cmd           -- hiếm: không để thành lựa chọn duy nhất của lượt
        elseif cmd.type ~= "endTurn" then
            if not byType[cmd.type] then byType[cmd.type] = {}; types[#types + 1] = cmd.type end
            table.insert(byType[cmd.type], cmd)
        end
    end
    if #demolish > 0 and prng:chance(P_DEMOLISH) then return prng:pick(demolish) end
    if #types == 0 or perTurn >= MAX_COMMANDS_PER_TURN or prng:chance(P_END_TURN) then
        return { type = "endTurn" }
    end
    table.sort(types)   -- thứ tự cố định để tất định
    local t = prng:weighted(types, function(name) return TYPE_WEIGHT[name] or 1 end)
    return prng:pick(byType[t])
end

-- Chơi trọn một ván. Trả state, stats. Báo lỗi nếu lệnh hợp lệ bị từ chối hoặc vi phạm bất biến.
function Sim.play(seed, players)
    local state = Game.new({ seed = seed, players = players })
    local prng = Rng.new("sim:" .. tostring(seed) .. ":" .. players)
    local stats = { sevens = 0, builds = 0, claims = 0, commands = 0, rebelStops = 0, losses = 0,
                    upgrades = 0, demolishes = 0, tnLost = 0, unitsBought = 0, unitMoves = 0, suppressWins = 0,
                    suppressLosses = 0, unitsLost = 0, subsFounded = 0 }
    local perTurn = 0

    while state.phase ~= "over" do
        stats.commands = stats.commands + 1
        assert(stats.commands < MAX_TOTAL_COMMANDS, "ván không kết thúc (vòng lặp?)")

        local legal = Game.legal(state)
        assert(#legal > 0, "không có lệnh hợp lệ ở pha " .. state.phase)
        local cmd = chooseCommand(prng, state, legal, perTurn)
        perTurn = perTurn + 1

        local ok, reason = Game.check(state, cmd)
        assert(ok, "lệnh trong legal() bị check() từ chối: " .. tostring(cmd.type) .. " - " .. tostring(reason))
        local events = Game.apply(state, cmd)
        for _, e in ipairs(events) do
            if e.kind == "seven" then stats.sevens = stats.sevens + 1
            elseif e.kind == "build" then stats.builds = stats.builds + 1
            elseif e.kind == "claim" then stats.claims = stats.claims + 1
            elseif e.kind == "rebel_stop" then stats.rebelStops = stats.rebelStops + 1
            elseif e.kind == "rebel_loss" then stats.losses = stats.losses + 1
            elseif e.kind == "upgrade" then stats.upgrades = stats.upgrades + 1
            elseif e.kind == "demolished" then stats.demolishes = stats.demolishes + 1
            elseif e.kind == "strategic_lost" then stats.tnLost = stats.tnLost + 1
            elseif e.kind == "unit_buy" then stats.unitsBought = stats.unitsBought + 1
            elseif e.kind == "unit_move" then stats.unitMoves = stats.unitMoves + 1
            elseif e.kind == "suppress" then
                if e.ok then stats.suppressWins = stats.suppressWins + 1 else stats.suppressLosses = stats.suppressLosses + 1 end
            elseif e.kind == "unit_destroyed" then stats.unitsLost = stats.unitsLost + 1
            elseif e.kind == "found_sub" then stats.subsFounded = stats.subsFounded + 1 end
        end

        if cmd.type == "endTurn" then
            perTurn = 0
            local good, msg = Sim.invariants(state)
            assert(good, "vi phạm bất biến (seed " .. tostring(seed) .. ", vòng " .. state.round .. "): " .. tostring(msg))
        end
    end

    local good, msg = Sim.invariants(state)
    assert(good, "vi phạm bất biến cuối ván (seed " .. tostring(seed) .. "): " .. tostring(msg))
    return state, stats
end

-- Tự chơi tối đa `n` lệnh trên state sẵn có (dùng để dựng thế cờ cho ảnh chụp / debug). Trả số lệnh đã chạy.
function Sim.advance(state, n, seed)
    local prng = Rng.new("advance:" .. tostring(seed or state.seed))
    local perTurn, done = 0, 0
    while done < n and state.phase ~= "over" do
        local legal = Game.legal(state)
        if #legal == 0 then break end
        local cmd = chooseCommand(prng, state, legal, perTurn)
        perTurn = cmd.type == "endTurn" and 0 or perTurn + 1
        Game.apply(state, cmd)
        done = done + 1
    end
    return done
end

-- Chạy `count` ván, số người xoay vòng 2..4. Trả bảng thống kê gộp.
function Sim.batch(count, firstSeed, onGame)
    local sum = { games = 0, sevens = 0, builds = 0, claims = 0, commands = 0, rebelStops = 0, losses = 0,
                  upgrades = 0, demolishes = 0, tnLost = 0, unitsBought = 0, unitMoves = 0, suppressWins = 0,
                  suppressLosses = 0, unitsLost = 0, subsFounded = 0, score = 0, tiles = 0, winnerTiles = 0 }
    for i = 0, count - 1 do
        local seed = (firstSeed or 1) + i
        local players = 2 + (i % 3)
        local state, stats = Sim.play(seed, players)
        local ranking = Game.ranking(state)
        sum.games = sum.games + 1
        for k, v in pairs(stats) do sum[k] = sum[k] + v end
        for _, s in ipairs(ranking) do
            sum.score = sum.score + s.total
            sum.tiles = sum.tiles + s.tileCount
        end
        sum.winnerTiles = sum.winnerTiles + ranking[1].tileCount
        sum.players = (sum.players or 0) + players
        if onGame then onGame(i + 1, seed, players, state, ranking) end
    end
    return sum
end

return Sim
