-- Dải đất cho test: dùng chung giữa derived_spec / specials_spec.

local Game      = require("src.core.game")
local State     = require("src.core.state")
local Territory = require("src.core.territory")

local key = State.key

-- Ván 2 người ở pha action; một dải Đồng Bằng 11 × 5 ô (q 0..10, r -2..2 quanh `c`) thuộc người đang lượt,
-- cách xa mọi Nhà Chính. Phiến Quân ở rất xa.
local function strip(seed)
    seed = seed or 4
    local s
    for attempt = 0, 40 do      -- thử vài seed cho tới khi bản đồ có đủ một dải đất không dính Nhà Chính
        s = Game.new({ seed = seed + attempt, players = 2 })
        while s.phase == "setup_hq" do Game.apply(s, Game.legal(s)[1]) end
        local found = false
        for _, t in ipairs(s.map.list) do
            local ok = true
            for q = -1, 10 do
                for r = -2, 2 do
                    local x = s.map:get(t.q + q, t.r + r)
                    if not x or Territory.isAnchorTile(s, x) then ok = false break end
                end
                if not ok then break end
            end
            if ok then found = true break end
        end
        if found then break end
    end
    s.phase = "action"
    s.rebel = { q = -99, r = -99 }
    local pid = Game.actor(s)
    local best
    for _, t in ipairs(s.map.list) do
        local ok = true
        for q = -1, 10 do
            for r = -2, 2 do
                local x = s.map:get(t.q + q, t.r + r)
                if not x or Territory.isAnchorTile(s, x) then ok = false break end
            end
            if not ok then break end
        end
        if ok then best = t break end
    end
    assert(best, "không tìm được dải đất")
    for q = -1, 10 do
        for r = -2, 2 do
            local x = s.map:get(best.q + q, best.r + r)
            x.terrain, x.settlement, x.landmark, x.strategic = "DH-01", nil, nil, nil
            s.owner[key(x)] = pid
            s.votes[key(x)] = { [pid] = 9 }
        end
    end
    for k in pairs(s.players[pid].res) do s.players[pid].res[k] = 50 end
    for _, m in ipairs({ "alloy", "paper", "steel", "silk", "bond" }) do s.players[pid].res[m] = 0 end   -- vật liệu bắt đầu từ 0
    return s, pid, best
end

return strip

