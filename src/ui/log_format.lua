-- Chuyển sự kiện của Game.apply thành câu tiếng Việt cho panel log (log phải đọc được ngay,
-- nhất là sản xuất chia sẻ: "P2 +2 KT từ Trại Khai Thác nhờ lượt đổ của P1").
-- Thuần Lua (không gọi love.*), nên test được headless.

local Buildings = require("src.data.buildings")
local Resources = require("src.data.resources")
local Strategic = require("src.data.strategic")

local Fmt = {}

local FACE_NAME = { "KH", "VH", "KT", "TN", "V", "Hex" }

function Fmt.face(f) return FACE_NAME[f] or "?" end

function Fmt.res(key)
    local r = Resources.byKey[key]
    return r and r.abbr or tostring(key)
end

-- "2 KT + 1 V" từ bảng { [res] = n } (thứ tự cố định theo Resources.core).
function Fmt.bundle(t)
    local parts = {}
    for _, r in ipairs(Resources.core) do
        if t[r.key] and t[r.key] > 0 then parts[#parts + 1] = t[r.key] .. " " .. r.abbr end
    end
    return table.concat(parts, " + ")
end

local function P(pid) return "P" .. tostring(pid) end

local function at(e) return string.format("(%d,%d)", e.q, e.r) end

local function buildingName(id)
    local b = Buildings.byId[id]
    return b and b.name or tostring(id)
end

local UNIT_NAME = { expedition = "Viễn Chinh", knight = "Hiệp Sĩ", trade = "Giao Thương" }

local function unitName(t) return UNIT_NAME[t] or tostring(t) end

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
    elseif k == "buy_tile" then
        return { text = string.format("%s mua ô %s", P(e.pid), at(e)), pid = e.pid, tier = "medium" }
    elseif k == "upgrade_hq" then
        return { text = string.format("%s nâng Nhà Chính lên cấp %d", P(e.pid), e.level), pid = e.pid, tier = "medium" }
    elseif k == "found_sub" then
        return { text = string.format("%s lập Khu Trực Thuộc tại %s", P(e.pid), at(e)), pid = e.pid, tier = "medium" }
    elseif k == "start_bonus" then
        local parts = {}
        for _, r in ipairs(Resources.core) do
            if e.gains[r.key] then parts[#parts + 1] = "+" .. e.gains[r.key] .. " " .. r.abbr end
        end
        return { text = string.format("%s nhận thưởng khởi đầu từ 6 ô quanh Nhà Chính: %s", P(e.pid),
            #parts > 0 and table.concat(parts, ", ") or "không có"), pid = e.pid, tier = "small" }
    elseif k == "vote" then
        local state = e.status == "owned" and "thực hữu" or (e.status == "contested" and "tranh chấp" or "chưa đủ")
        return { text = string.format("%s đặt phiếu tại %s (%s)", P(e.pid), at(e), state), pid = e.pid, tier = "small" }
    elseif k == "claim" then
        local from = e.from and (" từ " .. P(e.from)) or ""
        return { text = string.format("%s chiếm ô %s%s", P(e.pid), at(e), from), pid = e.pid, tier = "medium" }
    elseif k == "build" then
        return { text = string.format("%s xây %s C%d tại %s", P(e.pid), buildingName(e.id), e.level, at(e)),
                 pid = e.pid, tier = "medium" }
    elseif k == "unit_buy" then
        return { text = string.format("%s mua %s tại %s", P(e.pid), unitName(e.unit), at(e)), pid = e.pid, tier = "medium" }
    elseif k == "unit_move" then
        local road = (e.roads or 0) > 0 and string.format(", xây %d đường (%d V)", e.roads, e.gold or 0) or ""
        return { text = string.format("%s đưa %s tới %s (tốn %d, còn %d%s)", P(e.pid), unitName(e.unit), at(e), e.cost,
                 e.left, road), pid = e.pid, tier = "small" }
    elseif k == "road_upgrade" then
        return { text = string.format("%s nâng đường tại %s lên Lát Đá", P(e.pid), at(e)), pid = e.pid, tier = "small" }
    elseif k == "road_damaged" then
        return { text = string.format("Phiến Quân %s đường tại %s", e.lost and "phá mất" or "làm hư (tụt xuống Đường Đất)", at(e)),
                 tier = "medium" }
    elseif k == "trade_proposed" then
        return { text = string.format("%s đề xuất đổi với %s: đưa %s, nhận %s (phí %d V)", P(e.pid), P(e.to),
                 Fmt.bundle(e.give), Fmt.bundle(e.get), e.fee), pid = e.pid, tier = "medium" }
    elseif k == "trade_accepted" then
        return { text = string.format("%s chấp nhận trao đổi với %s (phí %d V)", P(e.to), P(e.pid), e.fee),
                 pid = e.pid, tier = "medium" }
    elseif k == "trade_declined" then
        return { text = string.format("%s từ chối đề xuất của %s", P(e.to), P(e.pid)), pid = e.pid, tier = "small" }
    elseif k == "upgrade_sub" then
        return { text = string.format("%s nâng Khu Trực Thuộc tại %s lên cấp %d", P(e.pid), at(e), e.level),
                 pid = e.pid, tier = "medium" }
    elseif k == "unit_transform" then
        return { text = string.format("%s: %s tại %s thành %s", P(e.pid), unitName(e.from), at(e), unitName(e.to)),
                 pid = e.pid, tier = "medium" }
    elseif k == "unit_retreat" then
        return { text = string.format("Hiệp Sĩ của %s rút về Nhà Chính %s thay vì bị mất", P(e.pid), at(e)),
                 pid = e.pid, tier = "large" }
    elseif k == "unit_garrison" then
        return { text = string.format("%s cho đơn vị trú đóng tại %s", P(e.pid), at(e)), pid = e.pid, tier = "small" }
    elseif k == "unit_disband" then
        return { text = string.format("%s giải thể %s, hoàn %d V", P(e.pid), unitName(e.unit), e.refund),
                 pid = e.pid, tier = "small" }
    elseif k == "unit_upkeep" then
        return { text = string.format("%s trả %d V duy trì %d đơn vị", P(e.pid), e.gold, e.count), pid = e.pid, tier = "small" }
    elseif k == "unit_destroyed" then
        local why = ({ rebel = "bị Phiến Quân đè", suppress = "thua khi Trấn Áp", upkeep = "do thiếu Vàng duy trì" })[e.reason]
        return { text = string.format("%s của %s %s tại %s", unitName(e.unit), P(e.pid), why or "bị hủy", at(e)),
                 pid = e.pid, tier = "large" }
    elseif k == "suppress" then
        if e.ok then
            local how = e.paid and "trả TN chắc thắng" or string.format("đổ %d / cần %d", e.roll, e.threshold)
            return { text = string.format("%s Trấn Áp thành công (%s): Phiến Quân bị đẩy tới %s, +1 TN", P(e.pid), how, at(e)),
                     pid = e.pid, tier = "large" }
        end
        return { text = string.format("%s Trấn Áp thất bại (đổ %d / cần %d)", P(e.pid), e.roll, e.threshold),
                 pid = e.pid, tier = "large" }
    elseif k == "passive" then
        local from = Buildings.byId[e.src] and Buildings.byId[e.src].name
            or (Strategic.byId[e.src] and Strategic.byId[e.src].name) or tostring(e.src)
        return { text = string.format("%s +%g %s thụ động từ %s", P(e.pid), e.amount, Fmt.res(e.res), from),
                 pid = e.pid, tier = "small" }
    elseif k == "upgrade" then
        return { text = string.format("%s nâng %s lên C%d tại %s", P(e.pid), buildingName(e.id), e.level, at(e)),
                 pid = e.pid, tier = "medium" }
    elseif k == "demolish_start" then
        return { text = string.format("%s ra lệnh dỡ %s tại %s (xong đầu lượt sau)", P(e.pid), buildingName(e.id), at(e)),
                 pid = e.pid, tier = "medium" }
    elseif k == "demolished" then
        return { text = string.format("%s đã dỡ %s tại %s", P(e.pid), buildingName(e.id), at(e)),
                 pid = e.pid, tier = "medium" }
    elseif k == "strategic_lost" then
        local tn = Strategic.byId[e.tn]
        return { text = string.format("Mất %s tại %s do dỡ công trình", tn and tn.name or tostring(e.tn), at(e)),
                 pid = e.pid, tier = "large" }
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
