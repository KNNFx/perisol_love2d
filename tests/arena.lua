-- Dựng thế cờ cho test: ván đã qua setup, đang ở pha action, quanh một ô xa mọi HQ có vùng bán kính 2
-- (19 ô) toàn Đồng Bằng, không TN, thuộc người đang lượt và đủ phiếu; người chơi có nhiều tài nguyên.

local Game  = require("src.core.game")
local Hex   = require("src.core.hex")
local State = require("src.core.state")

return function(seed, players)
    local s = Game.new({ seed = seed or 4, players = players or 2 })
    while s.phase == "setup_hq" do Game.apply(s, Game.legal(s)[1]) end
    s.phase = "action"
    local pid = Game.actor(s)

    local best, bestD = nil, -1
    for _, t in ipairs(s.map.list) do
        local ok, d = true, math.huge
        for _, h in ipairs(Hex.range(t, 3)) do
            if not s.map:get(h.q, h.r) then ok = false end
        end
        if ok then
            for p = 1, s.playerCount do d = math.min(d, Hex.distance(s.players[p].hq, t)) end
            if d > bestD then best, bestD = t, d end
        end
    end
    assert(best and bestD > 3, "không tìm được vùng trống")
    for _, h in ipairs(Hex.range(best, 2)) do
        local t = s.map:get(h.q, h.r)
        t.terrain, t.settlement, t.landmark, t.strategic = "DH-01", nil, nil, nil
        s.owner[State.key(t)] = pid
        s.votes[State.key(t)] = { [pid] = 9 }
    end
    for k in pairs(s.players[pid].res) do s.players[pid].res[k] = (k == "bond") and 0 or 99 end   -- Tín Phiếu tối đa 5
    return s, pid, best
end
