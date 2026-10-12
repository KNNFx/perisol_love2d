-- Mô phỏng ván chơi bằng người chơi ngẫu nhiên (có thiên hướng) — bắt crash / vòng lặp vô hạn và
-- kiểm tra bất biến. Thuần Lua, không gọi love.*. Dùng trong tests/sim_spec.lua và tools/*.lua (`make sim`, `make sweep`, `make repro`).

local C          = require("src.config.constants")
local Game       = require("src.core.game")
local Invariants = require("src.core.invariants")
local Rng        = require("src.core.rng")
local State      = require("src.core.state")

local Sim = {}

local MAX_COMMANDS_PER_TURN = 40
local MAX_TOTAL_COMMANDS    = 100000

-- Trọng số chọn loại lệnh trong pha action (kiểu lệnh nào có thì mới được chọn).
local TYPE_WEIGHT = { build = 6, buyTile = 4, placeVote = 3, foundSub = 2, trade = 1,
                         upgrade = 12, buyUnit = 3, moveUnit = 4, suppress = 3, garrison = 1, buildDerived = 8, redeemBond = 2,
                         upgradeHQ = 6, upgradeSub = 6, buildSpecial = 10, upgradeSpecial = 6, fortressStrike = 3 }
local P_END_TURN  = 0.12
local P_DEMOLISH  = 0.01   -- xác suất mỗi lệnh action chọn dỡ công trình hoặc giải thể đơn vị

Sim.invariants = Invariants.check   -- giữ tên cũ cho spec và tools; bản thật ở src/core/invariants.lua

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
-- opts.rich: sau mỗi lượt nạp đầy tài nguyên và vật liệu (trừ Tín Phiếu) để ván ngẫu nhiên chạm tới Nhà Chính C3+, Phái Sinh,
-- Đặc Biệt, trao đổi...; dùng để bắt crash ở các hệ thống ít khi xuất hiện trong ván ngẫu nhiên thường (`make sim-rich`).
-- opts.trace: bảng do người gọi cấp; Sim.play điền {state, topups} để dựng bản repro kể cả khi ván lỗi giữa chừng.

-- topups[n] = danh sách {pid, key, value} đã nạp ngay sau lệnh thứ n của history (luôn là endTurn).
local RICH_FLOOR = 25

local function violation(seed, round, msg)
    return string.format("vi phạm bất biến (seed %s, vòng %d): %s", tostring(seed), round, tostring(msg))
end

-- Phát lại bản repro {seed, players, rich, history, topups}: áp lại từng lệnh, nạp lại tài nguyên đúng chỗ, kiểm tra bất biến
-- như Sim.play. Trả true, state nếu không lỗi; nếu lỗi trả false, thông điệp (cùng thông điệp với Sim.play), state.
function Sim.replay(repro)
    local state = Game.new({ seed = repro.seed, players = repro.players })
    for n, cmd in ipairs(repro.history) do
        local ok, err = pcall(Game.apply, state, cmd)
        if not ok then return false, "lệnh thứ " .. n .. " bị từ chối khi phát lại: " .. tostring(err), state end
        if cmd.type == "endTurn" then
            for _, t in ipairs((repro.topups or {})[n] or {}) do state.players[t.pid].res[t.key] = t.value end   -- wallet:ok nạp rich
            local good, msg = Sim.invariants(state)
            if not good then return false, violation(repro.seed, state.round, msg), state end
        end
    end
    local good, msg = Sim.invariants(state)
    if not good then return false, "vi phạm bất biến cuối ván (seed " .. tostring(repro.seed) .. "): " .. tostring(msg), state end
    return true, state
end

function Sim.play(seed, players, opts)
    opts = opts or {}
    local state = Game.new({ seed = seed, players = players })
    local prng = Rng.new("sim:" .. tostring(seed) .. ":" .. players)
    local stats = { sevens = 0, builds = 0, claims = 0, commands = 0, rebelStops = 0, losses = 0,
                    upgrades = 0, demolishes = 0, tnLost = 0, unitsBought = 0, unitMoves = 0, suppressWins = 0,
                    suppressLosses = 0, unitsLost = 0, subsFounded = 0, roadsBuilt = 0, roadUpgrades = 0,
                    tradesProposed = 0, tradesAccepted = 0, derivedBuilt = 0, specialsBuilt = 0, sevensCancelled = 0 }
    local perTurn = 0
    local trace = opts.trace
    if trace then trace.state, trace.topups = state, {} end

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
        if opts.onCommand then opts.onCommand(state, cmd, events) end   -- móc kiểm tra theo từng lệnh (spec)
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
            elseif e.kind == "unit_move" then
                stats.unitMoves = stats.unitMoves + 1
                stats.roadsBuilt = stats.roadsBuilt + (e.roads or 0)
            elseif e.kind == "road_upgrade" then stats.roadUpgrades = stats.roadUpgrades + 1
            elseif e.kind == "derived_built" then stats.derivedBuilt = stats.derivedBuilt + 1
            elseif e.kind == "special_built" then stats.specialsBuilt = stats.specialsBuilt + 1
            elseif e.kind == "seven_cancelled" then stats.sevensCancelled = stats.sevensCancelled + 1
            elseif e.kind == "trade_proposed" then stats.tradesProposed = stats.tradesProposed + 1
            elseif e.kind == "trade_accepted" then stats.tradesAccepted = stats.tradesAccepted + 1
            elseif e.kind == "suppress" then
                if e.ok then stats.suppressWins = stats.suppressWins + 1 else stats.suppressLosses = stats.suppressLosses + 1 end
            elseif e.kind == "unit_destroyed" then stats.unitsLost = stats.unitsLost + 1
            elseif e.kind == "found_sub" then stats.subsFounded = stats.subsFounded + 1 end
        end

        if cmd.type == "endTurn" then
            perTurn = 0
            if opts.rich then
                local ups = {}
                for pid, p in ipairs(state.players) do
                    local keys = {}
                    for k, v in pairs(p.res) do
                        if k ~= "bond" and v < RICH_FLOOR then keys[#keys + 1] = k end
                    end
                    table.sort(keys)
                    for _, k in ipairs(keys) do
                        p.res[k] = RICH_FLOOR   -- wallet:ok nạp rich
                        ups[#ups + 1] = { pid = pid, key = k, value = RICH_FLOOR }
                    end
                end
                if trace then trace.topups[#state.history] = ups end
            end
            local good, msg = Sim.invariants(state)
            assert(good, violation(seed, state.round, msg))
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
function Sim.batch(count, firstSeed, onGame, opts)
    local sum = { games = 0, sevens = 0, builds = 0, claims = 0, commands = 0, rebelStops = 0, losses = 0,
                  upgrades = 0, demolishes = 0, tnLost = 0, unitsBought = 0, unitMoves = 0, suppressWins = 0,
                  suppressLosses = 0, unitsLost = 0, subsFounded = 0, roadsBuilt = 0, roadUpgrades = 0,
                  tradesProposed = 0, tradesAccepted = 0, derivedBuilt = 0, specialsBuilt = 0, sevensCancelled = 0, score = 0, tiles = 0, winnerTiles = 0 }
    for i = 0, count - 1 do
        local seed = (firstSeed or 1) + i
        local players = 2 + (i % 3)
        local state, stats = Sim.play(seed, players, opts)
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
