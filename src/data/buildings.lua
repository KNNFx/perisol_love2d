-- Công trình Cơ Bản B-01..B-05 × 3 cấp. Nguồn: docs/Perisol_Data.md, sheet "Công trình"
-- (chi phí, số ô, sản xuất) và sheet "Đặt công trình" (địa hình hợp lệ).
--
-- Mỗi cấp:
--   cost     = { [resKey] = số }                  (resKey: science/culture/engineering/faith/gold)
--   tiles    = số ô hex chiếm
--   shape    = mô tả hình dạng (dùng ở M1.5 khi công trình nhiều ô)
--   produces = { { face, res, n }, ... }          khi xúc xắc ra `face`, nhận n × (số viên khớp) `res`
--   passive  = mô tả hiệu ứng thụ động (chưa có logic, M1.5)
--   terrains = { ["DH-xx"] = true | "pref" }      "pref" = ô ưu tiên (⭐, chưa có bonus ở M1, D-010)
--
-- Mặt xúc xắc: Khoa Học 1, Văn Hóa 2, Kỹ Thuật 3, Tín Ngưỡng 4, Vàng 5 (src/data/resources.lua).

local B = {}

-- Rút gọn tên mặt xúc xắc cho bảng sản xuất.
local SCI, CUL, ENG, FAI, GOLD = 1, 2, 3, 4, 5
local R_SCI, R_CUL, R_ENG, R_FAI, R_GOLD = "science", "culture", "engineering", "faith", "gold"

B.list = {
    {
        id = "B-01", name = "Trại Khai Thác", en = "Mining Camp", icon = "KT", main = R_ENG,
        levels = {
            { cost = { engineering = 2, gold = 1 }, tiles = 1, shape = "single",
              produces = { { ENG, R_ENG, 1 } },
              terrains = { ["DH-01"] = true, ["DH-02"] = true, ["DH-05"] = true, ["DH-06"] = true,
                           ["DH-07"] = true, ["DH-09"] = true } },
            { cost = { engineering = 4, science = 2, gold = 3 }, tiles = 3, shape = "triangle",
              produces = { { ENG, R_ENG, 2 }, { SCI, R_ENG, 1 } },
              terrains = { ["DH-01"] = true, ["DH-02"] = true, ["DH-03"] = true, ["DH-05"] = true,
                           ["DH-06"] = true, ["DH-07"] = true, ["DH-09"] = true } },
            { cost = { engineering = 7, science = 4, gold = 6 }, tiles = 6, shape = "trapezoid",
              produces = { { ENG, R_ENG, 3 }, { SCI, R_ENG, 2 } },
              passive = "+1 KT thụ động mỗi vòng",
              terrains = { ["DH-01"] = true, ["DH-02"] = true, ["DH-03"] = true, ["DH-05"] = true,
                           ["DH-06"] = true, ["DH-07"] = true, ["DH-09"] = true } },
        },
    },
    {
        id = "B-02", name = "Viện Nghiên Cứu", en = "Research Institute", icon = "KH", main = R_SCI,
        levels = {
            { cost = { science = 2, gold = 1 }, tiles = 1, shape = "single",
              produces = { { SCI, R_SCI, 1 } },
              passive = "Rừng: +1 KH thụ động",
              terrains = { ["DH-01"] = true, ["DH-02"] = "pref", ["DH-05"] = true, ["DH-09"] = true } },
            { cost = { science = 4, engineering = 2, gold = 3 }, tiles = 3, shape = "triangle",
              produces = { { SCI, R_SCI, 2 }, { ENG, R_SCI, 1 } },
              terrains = { ["DH-01"] = true, ["DH-02"] = "pref", ["DH-05"] = true, ["DH-09"] = true } },
            { cost = { science = 7, engineering = 3, gold = 5 }, tiles = 6, shape = "cluster",
              produces = { { SCI, R_SCI, 3 }, { ENG, R_SCI, 2 } },
              passive = "+1 KH thụ động mỗi vòng",
              terrains = { ["DH-01"] = true, ["DH-02"] = "pref", ["DH-05"] = true, ["DH-09"] = true } },
        },
    },
    {
        id = "B-03", name = "Nhà Văn Hóa", en = "Cultural House", icon = "VH", main = R_CUL,
        levels = {
            { cost = { culture = 2, gold = 1 }, tiles = 1, shape = "single",
              produces = { { CUL, R_CUL, 1 } },
              terrains = { ["DH-01"] = true, ["DH-05"] = true, ["DH-10"] = "pref" } },
            { cost = { culture = 3, faith = 1, gold = 2 }, tiles = 2, shape = "pair",
              produces = { { CUL, R_CUL, 2 }, { FAI, R_CUL, 1 } },
              terrains = { ["DH-01"] = true, ["DH-05"] = true, ["DH-09"] = true, ["DH-10"] = "pref" } },
            { cost = { culture = 5, faith = 3, gold = 4 }, tiles = 4, shape = "rect",
              produces = { { CUL, R_CUL, 3 } },
              passive = "Ô lãnh thổ kề: +0.5 VH thụ động mỗi vòng",
              terrains = { ["DH-01"] = true, ["DH-05"] = true, ["DH-09"] = true, ["DH-10"] = "pref" } },
        },
    },
    {
        id = "B-04", name = "Đền Thờ", en = "Temple", icon = "TN", main = R_FAI,
        levels = {
            { cost = { faith = 2, gold = 1 }, tiles = 1, shape = "single",
              produces = { { FAI, R_FAI, 1 } },
              terrains = { ["DH-01"] = true, ["DH-02"] = "pref", ["DH-04"] = true, ["DH-08"] = true } },
            { cost = { faith = 3, culture = 2, gold = 2 }, tiles = 2, shape = "pair",
              produces = { { FAI, R_FAI, 2 }, { CUL, R_FAI, 1 } },
              terrains = { ["DH-01"] = true, ["DH-02"] = "pref", ["DH-04"] = true, ["DH-08"] = true,
                           ["DH-09"] = true } },
            { cost = { faith = 5, culture = 3, gold = 3 }, tiles = 3, shape = "line3",
              produces = { { FAI, R_FAI, 3 } },
              passive = "+1 TN thụ động nếu Phiến Quân hiện diện",
              terrains = { ["DH-01"] = true, ["DH-02"] = "pref", ["DH-04"] = true, ["DH-08"] = true,
                           ["DH-09"] = true } },
        },
    },
    {
        id = "B-05", name = "Khu Chợ", en = "Market", icon = "V", main = R_GOLD,
        levels = {
            { cost = { gold = 3, engineering = 1 }, tiles = 1, shape = "single",
              produces = { { GOLD, R_GOLD, 1 } },
              passive = "Cần đường nếu không liền HQ (M1.5)",
              terrains = { ["DH-01"] = true, ["DH-05"] = true, ["DH-07"] = true, ["DH-10"] = "pref" } },
            { cost = { gold = 5, engineering = 3 }, tiles = 2, shape = "pair",
              produces = { { GOLD, R_GOLD, 2 } },
              passive = "+0.5 V mỗi vòng cho mỗi tuyến đường (tối đa 3)",
              terrains = { ["DH-01"] = true, ["DH-05"] = true, ["DH-07"] = true, ["DH-10"] = "pref" } },
            { cost = { gold = 8, engineering = 5, culture = 2 }, tiles = 3, shape = "L",
              produces = { { GOLD, R_GOLD, 3 } },
              passive = "Giao thương bán kính 2 ô không cần đơn vị",
              terrains = { ["DH-01"] = true, ["DH-05"] = true, ["DH-07"] = true } },
        },
    },
}

B.byId = {}
for i, b in ipairs(B.list) do
    b.index = i
    B.byId[b.id] = b
    for lv, def in ipairs(b.levels) do
        def.level = lv
        def.buildingId = b.id
        def.fullId = string.format("%s.%d", b.id, lv)
    end
end

-- Cấp `level` của công trình `id` (nil nếu không tồn tại).
function B.level(id, level)
    local b = B.byId[id]
    return b and b.levels[level] or nil
end

-- true / "pref" nếu đặt được công trình `id` cấp `level` trên địa hình `terrainId`, nil nếu không.
function B.allowedOn(id, level, terrainId)
    local def = B.level(id, level)
    return def and def.terrains[terrainId] or nil
end

return B
