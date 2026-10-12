-- Contract State (Architecture_Hardening_Plan §5): State.new khai đủ mọi trường một ván có thể mang;
-- không trường nào "mọc" giữa ván (save, replay và mạng M5 cần hình dạng cố định).
local Game  = require("src.core.game")
local Sim   = require("src.core.sim")
local State = require("src.core.state")

local function keySet(t)
    local k = {}
    for key in pairs(t) do k[key] = true end
    return k
end

local function sortedKeys(set)
    local out = {}
    for k in pairs(set) do out[#out + 1] = k end
    table.sort(out)
    return out
end

-- Chơi một ván, sau MỖI lệnh gom khóa cấp cao nhất của state và của từng người chơi mà Game.new chưa có.
local function grown(seed, players, rich)
    local base = Game.new({ seed = seed, players = players })
    local top, pk = keySet(base), keySet(base.players[1])
    local found = {}
    Sim.play(seed, players, { rich = rich, onCommand = function(st)
        for k in pairs(st) do if not top[k] then found["state." .. tostring(k)] = true end end
        for _, p in ipairs(st.players) do
            for k in pairs(p) do if not pk[k] then found["player." .. tostring(k)] = true end end
        end
    end })
    return found
end

describe("state: hình dạng cố định", function()
    it("không trường nào mọc thêm giữa ván (12 ván thường + 2 rich)", function()
        local all = {}
        for seed = 1, 12 do
            for k in pairs(grown(seed, 2 + (seed - 1) % 3, false)) do all[k] = true end
        end
        for seed = 1, 2 do
            for k in pairs(grown(seed, 2 + (seed - 1) % 3, true)) do all[k] = true end
        end
        expect.eq(#sortedKeys(all), 0, "trường mọc thêm: " .. table.concat(sortedKeys(all), ", "))
    end)

    it("State.new khai sẵn các trường trống (trường chưa có giá trị là false, không phải nil)", function()
        local s = Game.new({ seed = 3, players = 3 })
        for _, k in ipairs({ "history", "setupIdx", "takenStarts", "prompt", "rebel", "dice", "log" }) do
            expect.truthy(s[k] ~= nil, "state." .. k .. " thiếu trong State.new")
        end
        for _, k in ipairs({ "hq", "hqLevel", "subs", "carry", "strikeRound", "broadcastRound", "cancel7Used",
                             "knightRetreatRound" }) do
            expect.truthy(s.players[1][k] ~= nil, "player." .. k .. " thiếu trong State.new")
        end
    end)

    it("Game.new không thêm khóa nào ngoài State.new", function()
        local map = Game.new({ seed = 5, players = 2 }).map
        local raw = State.new(map, 2, 5)
        local made = Game.new({ seed = 5, players = 2 })
        expect.deepEq(sortedKeys(keySet(made)), sortedKeys(keySet(raw)))
        expect.deepEq(sortedKeys(keySet(made.players[1])), sortedKeys(keySet(raw.players[1])))
    end)
end)
