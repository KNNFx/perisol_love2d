-- Phủ lệnh và event: `luajit tools/cover.lua`. Chơi một batch cố định (COVER_STD ván thường + các seed rich trong COVER_RICH),
-- đếm số lần mỗi loại lệnh (bảng H trong src/core/game.lua) và mỗi loại event xuất hiện.
-- Fail (thoát 1) khi (a) có loại không nằm trong tools/cover_gaps.lua mà đếm được 0, hoặc
-- (b) có loại nằm trong danh sách mà đã được phủ (để danh sách chỉ co lại).
local Sim  = require("src.core.sim")
local Gaps = require("tools.cover_gaps")

local COVER_STD = 60            -- ván thường seed 1..60, số người xoay vòng 2,3,4
local COVER_RICH = { 6, 12 }   -- seed rich cố định (đo 2026-10-12): 6 phủ foundSub/upgradeSub/proposeTrade/respond, 12 phủ redeemBond

local function read(path)
    local f = assert(io.open(path, "r"))
    local s = f:read("*a")
    f:close()
    return s
end

-- Tập lệnh: mọi `H.<tên> = {` trong game.lua. Tập event: mọi `kind = "<tên>"` trong src/core (trừ sim.lua) trừ các kind
-- không phải event (neo lãnh thổ, cửa sổ prompt, dòng log mở đầu).
local NOT_EVENT = { hq = true, sub = true, pushrebel = true, cancel7 = true, setup = true }

local commands, events = {}, {}
for name in read("src/core/game.lua"):gmatch("\nH%.([%w_]+) = {") do commands[#commands + 1] = name end
table.sort(commands)
local p = io.popen("ls src/core/*.lua")
for file in p:lines() do
    if not file:match("sim%.lua$") then
        for kind in read(file):gmatch('kind = "([%w_]+)"') do
            if not NOT_EVENT[kind] then events[kind] = true end
        end
    end
end
p:close()
local eventList = {}
for k in pairs(events) do eventList[#eventList + 1] = k end
table.sort(eventList)

local cmdCount, evCount = {}, {}
local function play(seed, players, rich)
    local state = Sim.play(seed, players, { rich = rich })
    for _, c in ipairs(state.history) do cmdCount[c.type] = (cmdCount[c.type] or 0) + 1 end
    for _, e in ipairs(state.log) do evCount[e.kind] = (evCount[e.kind] or 0) + 1 end
end
for i = 0, COVER_STD - 1 do play(1 + i, 2 + (i % 3), false) end
for _, seed in ipairs(COVER_RICH) do play(seed, 2 + ((seed - 1) % 3), true) end

local function set(list) local t = {} for _, v in ipairs(list) do t[v] = true end return t end
local gapCmd, gapEv = set(Gaps.commands), set(Gaps.events)
local bad = {}

local function report(title, names, counts, gaps, noun)
    print(string.format("%s (%d)", title, #names))
    for _, n in ipairs(names) do
        local c = counts[n] or 0
        local tag = ""
        if c == 0 and gaps[n] then tag = "  [khoảng trống đã khai]"
        elseif c == 0 then tag = "  <-- CHƯA PHỦ"; bad[#bad + 1] = noun .. " " .. n .. " đếm được 0 và không nằm trong cover_gaps"
        elseif gaps[n] then tag = "  <-- ĐÃ PHỦ, xóa khỏi cover_gaps"; bad[#bad + 1] = noun .. " " .. n .. " đã được phủ (" .. c .. " lần), xóa khỏi tools/cover_gaps.lua" end
        print(string.format("  %-18s %6d%s", n, c, tag))
    end
end

print(string.format("batch: %d ván thường (seed 1..%d) + rich seed %s", COVER_STD, COVER_STD, table.concat(COVER_RICH, ",")))
report("Lệnh", commands, cmdCount, gapCmd, "lệnh")
report("Event", eventList, evCount, gapEv, "event")

-- khai báo thừa: tên không tồn tại
local known = set(commands)
for _, n in ipairs(Gaps.commands) do if not known[n] then bad[#bad + 1] = "cover_gaps liệt kê lệnh không tồn tại: " .. n end end
known = set(eventList)
for _, n in ipairs(Gaps.events) do if not known[n] then bad[#bad + 1] = "cover_gaps liệt kê event không tồn tại: " .. n end end

print(string.format("khoảng trống khai báo: %d lệnh + %d event", #Gaps.commands, #Gaps.events))
if #bad > 0 then
    for _, b in ipairs(bad) do print("FAIL " .. b) end
    os.exit(1)
end
print("cover: đạt")
