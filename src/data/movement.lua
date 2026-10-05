-- Chi phí di chuyển theo địa hình. Nguồn: docs/Perisol_Data.md, "Các đơn vị cờ" §3.
-- Số = điểm di chuyển tiêu tốn để ĐI VÀO ô; math.huge = không vào được.
-- Đoàn Tàu (U-02T) chỉ chạy trên ray -> làm ở M1.5.

local C = require("src.config.constants")

local INF = math.huge

local M = {}

--                       01  02  03  04  05  06  07  08  09  10  11  12
--                       BằngRừngNúi Sông Biển Nguy SaM  Lầy Đồi KDC DT  Tuyết
local ORDER = { "DH-01", "DH-02", "DH-03", "DH-04", "DH-05", "DH-06",
                "DH-07", "DH-08", "DH-09", "DH-10", "DH-11", "DH-12" }

local function row(values)
    local t = {}
    for i, id in ipairs(ORDER) do t[id] = values[i] end
    return t
end

M.cost = {
    expedition = row({ 1, 2, INF, 2, 1, 2, 2, 3, 1, 1, 1, INF }),   -- U-01
    knight     = row({ 1, 1, 2,   2, 1, 1, 2, 2, 1, 1, 1, 3 }),     -- U-01K
    trade      = row({ 1, 2, INF, 2, 1, 2, 2, 3, 1, 1, 1, INF }),   -- U-02
    envoy      = row({ 1, 2, INF, 2, 1, 2, 2, 3, 1, 1, 1, INF }),   -- U-05
    -- Phiến Quân (U-03): Núi / Núi Tuyết bị khóa trong REBEL_MOUNTAIN_LOCK_ROUNDS vòng đầu,
    -- sau đó tốn REBEL_MOUNTAIN_COST (xem M.stepCost).
    rebel      = row({ 1, 2, INF, 2, 1, 1, 1, 2, 1, 1, 1, INF }),
}

local MOUNTAINS = { ["DH-03"] = true, ["DH-12"] = true }

-- Chi phí để `unit` đi vào ô địa hình `terrainId` ở vòng `round`.
function M.stepCost(unit, terrainId, round)
    if unit == "rebel" and MOUNTAINS[terrainId] then
        return (round or 1) <= C.REBEL_MOUNTAIN_LOCK_ROUNDS and INF or C.REBEL_MOUNTAIN_COST
    end
    local c = M.cost[unit] and M.cost[unit][terrainId]
    return c or INF
end

return M
