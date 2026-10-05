-- Chuyển sự kiện của Game.apply thành câu tiếng Việt cho panel log (log phải đọc được ngay,
-- nhất là sản xuất chia sẻ: "P2 +2 KT từ Trại Khai Thác nhờ lượt đổ của P1").
-- Thuần Lua (không gọi love.*), nên test được headless.

local Buildings = require("src.data.buildings")
local Resources = require("src.data.resources")

local Fmt = {}

local FACE_NAME = { "KH", "VH", "KT", "TN", "V", "Hex" }

function Fmt.face(f) return FACE_NAME[f] or "?" end

function Fmt.res(key)
    local r = Resources.byKey[key]
    return r and r.abbr or tostring(key)
end

local function P(pid) return "P" .. tostring(pid) end

local function at(e) return string.format("(%d,%d)", e.q, e.r) end

local function buildingName(id)
    local b = Buildings.byId[id]
    return b and b.name or tostring(id)
end

-- Trả { text, pid, tier } hoặc nil nếu sự kiện không cần hiện. tier: "small" | "medium" | "large".
function Fmt.line(e)
    local k = e.kind
    if k == "roll" then
        return { text = string.format("%s đổ xúc xắc: %s + %s", P(e.pid), Fmt.face(e.dice[1]), Fmt.face(e.dice[2])),
                 pid = e.pid, tier = "small" }
    elseif k == "seven" then
        return { text = "Tổng 7! Không ai sản xuất, Phiến Quân hành động", pid = e.pid, tier = "large" }
    elseif k == "produce" then
        return { text = string.format("%s +%d %s từ %s nhờ lượt đổ của %s", P(e.pid), e.amount, Fmt.res(e.res),
                 buildingName(e.buildingId), P(e.roller)), pid = e.pid, tier = "small" }
    elseif k == "votes" then
        return { text = string.format("%s nhận +%d phiếu Chi Phối (mặt Hex)", P(e.pid), e.amount),
                 pid = e.pid, tier = "small" }
    elseif k == "place_hq" then
        return { text = string.format("%s đặt Nhà Chính tại %s", P(e.pid), at(e)), pid = e.pid, tier = "small" }
    elseif k == "rebel_spawn" then
        return { text = "Phiến Quân xuất hiện tại " .. at(e), tier = "medium" }
    elseif k == "rebel_roll" then
        return { text = string.format("%s đổ cho Phiến Quân: %d điểm di chuyển", P(e.roller), e.points),
                 pid = e.roller, tier = "medium" }
    elseif k == "rebel_step" then
        return { text = string.format("Phiến Quân bước tới (%d,%d), còn %d điểm", e.to.q, e.to.r, e.left),
                 tier = "small" }
    elseif k == "rebel_stop" then
        return { text = "Phiến Quân dừng tại " .. at(e), tier = "medium" }
    elseif k == "rebel_loss" then
        return { text = string.format("%s mất %d %s, %s nhận %d", P(e.victim), e.lost, Fmt.res(e.res),
                 P(e.roller), e.gained), pid = e.victim, tier = "large" }
    elseif k == "rebel_choose" then
        return { text = string.format("%s phải chọn loại tài nguyên mất (%d)", P(e.victim), e.amount),
                 pid = e.victim, tier = "medium" }
    elseif k == "trade" then
        return { text = string.format("%s đổi %d %s lấy 1 %s", P(e.pid), e.rate, Fmt.res(e.give), Fmt.res(e.get)),
                 pid = e.pid, tier = "small" }
    elseif k == "buy_vote" then
        return { text = P(e.pid) .. " mua 1 phiếu Chi Phối", pid = e.pid, tier = "small" }
    elseif k == "vote" then
        local state = e.status == "owned" and "thực hữu" or (e.status == "contested" and "tranh chấp" or "chưa đủ")
        return { text = string.format("%s đặt phiếu tại %s (%s)", P(e.pid), at(e), state), pid = e.pid, tier = "small" }
    elseif k == "claim" then
        local from = e.from and (" từ " .. P(e.from)) or ""
        return { text = string.format("%s chiếm ô %s%s", P(e.pid), at(e), from), pid = e.pid, tier = "medium" }
    elseif k == "build" then
        return { text = string.format("%s xây %s C%d tại %s", P(e.pid), buildingName(e.id), e.level, at(e)),
                 pid = e.pid, tier = "medium" }
    elseif k == "end_turn" then
        return { text = "Hết lượt " .. P(e.pid), pid = e.pid, tier = "small" }
    elseif k == "global_event" then
        return { text = "Mốc Sự Kiện Tổng (chưa có ở M1)", tier = "medium" }
    elseif k == "game_over" then
        return { text = "Ván đấu kết thúc", tier = "large" }
    end
    return nil
end

return Fmt
