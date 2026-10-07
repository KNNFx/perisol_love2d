-- Thế cờ dựng sẵn để chụp màn hình / kiểm tra giao diện (chỉ dùng khi dev): `--demo loss`.
-- Không được dùng trong luật chơi hay test.

local Game = require("src.core.game")
local Rebel = require("src.core.rebel")
local Structures = require("src.core.structures")
local State = require("src.core.state")

local Demo = {}

-- Phiến Quân vừa dừng trên công trình của P(không phải người đổ) có 2 loại tài nguyên bằng nhau:
-- phải hiện popup chọn loại bị mất.
function Demo.loss(state)
    while state.phase == "setup_hq" do Game.apply(state, Game.legal(state)[1]) end
    local roller = Game.actor(state)
    local victim = roller % state.playerCount + 1
    assert(victim ~= roller, "cần ít nhất 2 người chơi")

    local hq = state.players[victim].hq
    local tile
    for _, n in ipairs(state.map:neighbors(state.map:get(hq.q, hq.r))) do
        if n.terrain == "DH-01" then tile = n break end
    end
    tile = tile or state.map:get(hq.q, hq.r)
    Structures.place(state, { id = "B-01", level = 1, owner = victim }, { tile })
    for k in pairs(state.players[victim].res) do state.players[victim].res[k] = 0 end
    state.players[victim].res.gold, state.players[victim].res.culture = 4, 4

    state.rebel = { q = tile.q, r = tile.r, pending = { stage = "move", points = 1, roller = roller } }
    Rebel.stop(state)
    state.phase = Rebel.stage(state) == "loss" and "rebel_loss" or "action"
end

-- Vùng bán kính 2 toàn Đồng Bằng thuộc người đang lượt, xa mọi HQ; có 2 công trình C1 và đủ tài nguyên.
-- Trả tile trung tâm, pid, danh sách công trình.
local function upgradeArena(state)
    local Hex = require("src.core.hex")
    while state.phase == "setup_hq" do Game.apply(state, Game.legal(state)[1]) end
    state.phase = "action"
    local pid = Game.actor(state)
    local best, bestD = nil, -1
    for _, t in ipairs(state.map.list) do
        local ok, d = true, math.huge
        for _, h in ipairs(Hex.range(t, 3)) do
            if not state.map:get(h.q, h.r) then ok = false end
        end
        if ok then
            for p = 1, state.playerCount do d = math.min(d, Hex.distance(state.players[p].hq, t)) end
            if d > bestD then best, bestD = t, d end
        end
    end
    for _, h in ipairs(Hex.range(best, 2)) do
        local t = state.map:get(h.q, h.r)
        t.terrain, t.settlement, t.landmark, t.strategic = "DH-01", nil, nil, nil
        state.owner[State.key(t)] = pid
        state.votes[State.key(t)] = { [pid] = 9 }
    end
    for k in pairs(state.players[pid].res) do state.players[pid].res[k] = 20 end
    local a = Structures.place(state, { id = "B-01", level = 1, owner = pid }, { best })
    local ring = state.map:neighbors(best)
    local b = Structures.place(state, { id = "B-03", level = 1, owner = pid }, { state.map:get(best.q - 2, best.r + 1) or ring[4] })
    return best, pid, { a, b }
end

-- Chọn Trại Khai Thác và vào chế độ nâng cấp: xem ghost hình tam giác (phím Q đổi hình).
function Demo.upgrade(state)
    local best, _, bs = upgradeArena(state)
    local hover = state.map:get(best.q + 1, best.r)
    return { focus = best, selected = bs[1].uid, mode = { kind = "upgrade", uid = bs[1].uid, variant = 0 }, hover = hover }
end

-- Popup xác nhận dỡ khi công trình nằm trên TN (cảnh báo mất vĩnh viễn).
function Demo.demolish(state)
    local best, _, bs = upgradeArena(state)
    best.strategic = "TN-05"
    return { focus = best, selected = bs[1].uid, confirm = { kind = "demolish", uid = bs[1].uid } }
end

-- Viễn Chinh đã chọn, vùng đi được, đường xem trước và bảng đơn vị (Phiến Quân ở kề để thấy nút Trấn Áp).
function Demo.unit(state)
    local best, pid = upgradeArena(state)
    local Units = require("src.core.units")
    local u = Units.spawn(state, pid, "expedition", best)
    u.mp = 4
    local rb = state.map:get(best.q + 1, best.r + 1)
    state.rebel = { q = rb.q, r = rb.r }
    return { focus = best, selectedUnit = u.uid, hover = state.map:get(best.q - 2, best.r) }
end

-- Chế độ chọn hướng Trấn Áp: ô kề Phiến Quân sáng, xem trước đường bị đẩy.
function Demo.suppress(state)
    local best, pid = upgradeArena(state)
    local Units = require("src.core.units")
    local u = Units.spawn(state, pid, "expedition", best)
    u.mp = 4
    local rb = state.map:get(best.q + 1, best.r)
    state.rebel = { q = rb.q, r = rb.r }
    return { focus = best, selectedUnit = u.uid, mode = { kind = "suppress", uid = u.uid, pay = false },
             hover = state.map:get(best.q + 2, best.r) }
end

-- Trả bảng gợi ý cho scene (selected / selectedUnit / mode / confirm / hover / focus) hoặc nil.
function Demo.apply(state, name)
    local fn = Demo[name]
    assert(fn and name ~= "apply", "demo không tồn tại: " .. tostring(name))
    return fn(state)
end

return Demo
