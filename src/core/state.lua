-- Trạng thái ván chơi: chỉ chứa dữ liệu thuần (serialize được), trừ `map` là tham chiếu sinh lại từ
-- (seed, players) nên KHÔNG bao giờ được lưu (D-011). Thuần Lua, không gọi love.*.
--
-- HÌNH DẠNG CỐ ĐỊNH: State.new khai MỌI trường mà một ván có thể mang; không trường nào được sinh lười giữa ván
-- (tests/state_spec.lua canh). Trường "chưa có giá trị" dùng `false` (không dùng nil: nil làm khóa biến mất khỏi bảng,
-- nên save, so sánh và hash không còn thấy trường). Đọc bằng `if state.rebel then` / `not p.hq`, đừng so với nil.
-- Thêm trường mới = thêm vào đây + tăng C.SAVE_VERSION + viết migration trong Game.load (src/core/game.lua).
--
-- state = {
--   seed, playerCount, map,
--   round, turn, order = { pid... }, phase,           -- phase: setup_hq | roll | rebel_move | rebel_loss | prompt | action | over
--   setupIdx = n, takenStarts = {},                    -- pha đặt HQ: người đang đặt, các ô khởi đầu đã bị chiếm
--   history = { cmd... },                              -- mọi lệnh đã áp dụng (replay = seed + history)
--   rng = { base, state },
--   players = { [pid] = {
--       id, res = {science=..}, votes = n, hq = {q,r} | false, hqLevel = n, subs = {}, carry = {},
--       strikeRound, broadcastRound, knightRetreatRound = vòng dùng gần nhất | false,   -- S-0x "Pháo" / "Phát Sóng", Knight rút lui
--       cancel7Used = số lần đã hủy tổng 7 nhờ Thiên Đình } },
--   owner     = { ["q,r"] = pid },
--   votes     = { ["q,r"] = { [pid] = n } },
--   buildings = { [uid] = { uid, id, level, owner, tiles = {"q,r"...}, anchor, rot } },   (src/core/structures.lua)
--   occupied  = { ["q,r"] = uid },  nextUid, lostStrategic = { ["q,r"] = true },
--   units = {}, nextUnitUid, roads = {}, derived = {}, nextDerivedUid,
--   rebel     = { q, r, pending = { points, roller } | nil } | false,   -- false cho tới khi tổng 7 đầu tiên sinh Phiến Quân
--   dice      = { d1, d2 } | false,                                      -- false cho tới lượt đổ đầu tiên
--   prompt    = { kind, pid, options, resume, ... } | false,             -- chỉ có giá trị khi phase == "prompt"
--   log = {},
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
        for _, r in ipairs(Resources.materials) do res[r.key] = 0 end
        players[pid] = { id = pid, res = res, votes = 0, hq = false, hqLevel = 1, subs = {}, carry = {},
                         strikeRound = false, broadcastRound = false, knightRetreatRound = false, cancel7Used = 0 }
    end
    local order = {}
    for pid = 1, playerCount do order[pid] = pid end
    return {
        seed = seed, playerCount = playerCount, map = map,
        round = 1, turn = 1, order = order, phase = "setup_hq",
        rng = Rng.new(tostring(seed) .. ":game"),
        players = players,
        owner = {}, votes = {}, buildings = {}, occupied = {}, nextUid = 1, lostStrategic = {},
        units = {}, nextUnitUid = 1, roads = {},
        derived = {}, nextDerivedUid = 1,   -- công trình Phái Sinh (src/core/derived.lua)
        setupIdx = 1, takenStarts = {}, history = {},
        rebel = false, dice = false, prompt = false, log = {},
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
