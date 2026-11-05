-- Số vòng của ván và các mốc theo tiến độ (GDD 1.6 §11.3, D-020 #1). Thuần Lua, không gọi love.*.
--
-- N = 10 x số người chơi (1 người 10 vòng, 2 người 20, 3 người 30, 4 người 40), người tạo ván có thể đặt N là bội
-- của ROUND_STEP. Các mốc ghi sẵn cho ván 20 vòng (HQ C4 vòng 11, Sub C3 vòng 16, khóa Núi 10 vòng) quy đổi
-- theo ceil(mốc x N / 20). Sự Kiện Tổng lật mỗi EVENT_EVERY vòng, mức khốc liệt ceil(4 x vòng / N).

local C = require("src.config.constants")

local R = {}

-- Số vòng mặc định cho `players` người chơi.
function R.defaultFor(players)
    return C.ROUNDS_PER_PLAYER * players
end

-- N hợp lệ: bội của ROUND_STEP, ít nhất ROUND_STEP.
function R.valid(n)
    return type(n) == "number" and n >= C.ROUND_STEP and n == math.floor(n) and n % C.ROUND_STEP == 0
end

-- Tổng số vòng của ván (state cũ chưa có `rounds` được coi là ván 20 vòng).
function R.total(state)
    return state.rounds or C.ROUNDS_REFERENCE
end

-- Mốc `m` (ghi cho ván 20 vòng) quy đổi sang ván của `state`.
function R.scale(state, m)
    return math.ceil(m * R.total(state) / C.ROUNDS_REFERENCE)
end

-- Vòng `round` có lật Sự Kiện Tổng không (mỗi EVENT_EVERY vòng, tính tới vòng cuối).
function R.isEventRound(state, round)
    return round >= C.EVENT_EVERY and round % C.EVENT_EVERY == 0 and round <= R.total(state)
end

-- Mốc khốc liệt 1..4 của vòng `round` (GDD §11.3).
function R.eventTier(state, round)
    return math.max(1, math.min(4, math.ceil(4 * round / R.total(state))))
end

return R
