-- Thế cờ dựng sẵn để chụp màn hình / kiểm tra giao diện (chỉ dùng khi dev): `--demo loss`.
-- Không được dùng trong luật chơi hay test.

local Game = require("src.core.game")
local Rebel = require("src.core.rebel")
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
    state.buildings[State.key(tile)] = { id = "B-01", level = 1, owner = victim }
    for k in pairs(state.players[victim].res) do state.players[victim].res[k] = 0 end
    state.players[victim].res.gold, state.players[victim].res.culture = 4, 4

    state.rebel = { q = tile.q, r = tile.r, pending = { stage = "move", points = 1, roller = roller } }
    Rebel.stop(state)
    state.phase = Rebel.stage(state) == "loss" and "rebel_loss" or "action"
end

function Demo.apply(state, name)
    local fn = Demo[name]
    assert(fn and name ~= "apply", "demo không tồn tại: " .. tostring(name))
    fn(state)
end

return Demo
