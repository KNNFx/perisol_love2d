-- Batch ván ngẫu nhiên headless: `luajit tools/sim.lua N [--rich] [--base SEED]`. In từng ván và thống kê gộp.
-- Thoát 1 nếu có ván lỗi (crash, lệnh legal bị check từ chối, vi phạm bất biến).
local Sim = require("src.core.sim")

local count, rich, base = 100, false, 1
do
    local i = 1
    while i <= #arg do
        local a = arg[i]
        if a == "--rich" then rich = true
        elseif a == "--base" then i = i + 1; base = tonumber(arg[i]) or 1
        elseif tonumber(a) then count = tonumber(a) end
        i = i + 1
    end
end

local ok, sum = pcall(Sim.batch, count, base, function(i, seed, players, _, ranking)
    print(string.format("ván %3d seed %-4d %d người  thắng P%d (%d điểm, %d ô)", i, seed, players,
        ranking[1].pid, ranking[1].total, ranking[1].tileCount))
end, { rich = rich })
if not ok then
    io.stderr:write("LỖI: " .. tostring(sum) .. "\n")
    os.exit(1)
end

local g = sum.games
print(string.format("\n%d ván, không lỗi. Trung bình/ván: %.1f lần ra 7, %.1f công trình, %.1f lần chiếm ô, %.0f lệnh",
    g, sum.sevens / g, sum.builds / g, sum.claims / g, sum.commands / g))
print(string.format("Nâng cấp %.1f · dỡ %.1f · TN mất %.1f (mỗi ván)", sum.upgrades / g, sum.demolishes / g, sum.tnLost / g))
print(string.format("Đơn vị mỗi ván: mua %.1f · di chuyển %.1f · Trấn Áp thắng %.2f / thua %.2f · mất %.1f · lập Sub %.1f",
    sum.unitsBought / g, sum.unitMoves / g, sum.suppressWins / g, sum.suppressLosses / g, sum.unitsLost / g,
    sum.subsFounded / g))
print(string.format("Đường xây %.1f · nâng Lát Đá %.2f · đề xuất trao đổi %.2f · chấp nhận %.2f (mỗi ván)",
    sum.roadsBuilt / g, sum.roadUpgrades / g, sum.tradesProposed / g, sum.tradesAccepted / g))
print(string.format("Phái Sinh lập %.2f · Đặc Biệt xây %.2f · tổng 7 bị hủy %.2f (mỗi ván)", sum.derivedBuilt / g,
    sum.specialsBuilt / g, sum.sevensCancelled / g))
print(string.format("Điểm trung bình/người: %.1f · ô thực hữu trung bình/người: %.1f · ô của người thắng: %.1f",
    sum.score / sum.players, sum.tiles / sum.players, sum.winnerTiles / g))
