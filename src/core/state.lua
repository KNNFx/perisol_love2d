-- Trạng thái ván chơi: chỉ chứa dữ liệu thuần (serialize được), trừ `map` là tham chiếu sinh lại từ
-- (seed, players) nên KHÔNG bao giờ được lưu (D-011). Thuần Lua, không gọi love.*.
--
-- state = {
--   seed, playerCount, map,
--   round, turn, order = { pid... }, phase,
--   rng = { base, state },
--   players = { [pid] = { id, res = {science=..}, votes = n, hq = {q,r}|nil, subs = {} } },
--   owner     = { ["q,r"] = pid },
--   votes     = { ["q,r"] = { [pid] = n } },
--   buildings = { ["q,r"] = { id = "B-01", level = 1, owner = pid } },
--   rebel     = { q, r, pending = { points, roller } | nil } | nil,
--   dice, log = {},
-- }

local Rng       = require("src.core.rng")
local Resources = require("src.data.resources")

local State = {}

function State.key(tile) return tile.q .. "," .. tile.r end

-- State rỗng cho `playerCount` người; tài nguyên = 0 (Game.new phát tài nguyên khởi đầu).
function State.new(map, playerCount, seed)
    local players = {}
    for pid = 1, playerCount do
        local res = {}
        for _, r in ipairs(Resources.core) do res[r.key] = 0 end
        players[pid] = { id = pid, res = res, votes = 0, hq = nil, hqLevel = 1, subs = {} }
    end
    local order = {}
    for pid = 1, playerCount do order[pid] = pid end
    return {
        seed = seed, playerCount = playerCount, map = map,
        round = 1, turn = 1, order = order, phase = "setup_hq",
        rng = Rng.new(tostring(seed) .. ":game"),
        players = players,
        owner = {}, votes = {}, buildings = {},
        rebel = nil, dice = nil, log = {},
    }
end

-- Gắn lại metatable cho RNG sau khi load (rng chỉ là { base, state }).
function State.restoreRng(state)
    setmetatable(state.rng, Rng)
    return state
end

-- Bản sao dữ liệu thuần (bỏ `map`) dùng để lưu / so sánh.
function State.snapshot(state)
    local copy = {}
    for k, v in pairs(state) do
        if k ~= "map" then copy[k] = v end
    end
    return copy
end

return State
