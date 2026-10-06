-- Địa hình DH-01..DH-12. Nguồn: docs/Perisol_Data.md, sheet "Địa hình".
-- rarity: "common" (Phổ biến) | "uncommon" (Không phổ biến) | "rare" (Hiếm)
-- sprite = key trong src/render/tileset.lua, nil = vẽ đa giác màu fallback.
-- effects (GDD §3.1, chỉ phần tác dụng với công trình cấp 1, D-013):
--   buildDiscount = { [res] = n }  giảm chi phí xây (không xuống dưới 0)
--   output = { [res] = -n | "none" }  chỉnh sản lượng mỗi viên khớp; "none" = không sản xuất loại đó

local T = {}

T.list = {
    { id = "DH-01", name = "Đồng Bằng",   en = "Plains",          rarity = "common",
      canHQ = true,  canSub = true,  canBuild = true,  canSpecial = false, passable = true,
      color = { 0.62, 0.78, 0.36 }, sprite = "plains" },
    { id = "DH-02", name = "Rừng",        en = "Forest",          rarity = "common",
      canHQ = true,  canSub = true,  canBuild = true,  canSpecial = true,  passable = true,
      color = { 0.24, 0.52, 0.22 }, sprite = "forest" },
    { id = "DH-03", name = "Núi",         en = "Mountain",        rarity = "common",
      canHQ = false, canSub = false, canBuild = false, canSpecial = true,  passable = false,
      color = { 0.55, 0.53, 0.52 }, sprite = "mountain" },
    { id = "DH-04", name = "Sông",        en = "River",           rarity = "common",
      canHQ = false, canSub = false, canBuild = false, canSpecial = true,  passable = true,
      color = { 0.30, 0.62, 0.86 }, sprite = "water" },
    { id = "DH-05", name = "Bờ Biển",     en = "Coast",           rarity = "common",
      canHQ = true,  canSub = true,  canBuild = true,  canSpecial = true,  passable = true,
      color = { 0.92, 0.82, 0.45 }, sprite = "coast" },
    { id = "DH-06", name = "Lãnh Nguyên", en = "Tundra",          rarity = "uncommon",
      canHQ = true,  canSub = true,  canBuild = true,  canSpecial = false, passable = true,
      color = { 0.80, 0.86, 0.88 }, sprite = "tundra",
      effects = { buildDiscount = { engineering = 1 }, output = { gold = -1 } } },
    { id = "DH-07", name = "Sa Mạc",      en = "Desert",          rarity = "uncommon",
      canHQ = true,  canSub = true,  canBuild = true,  canSpecial = false, passable = true,
      color = { 0.90, 0.68, 0.30 }, sprite = "desert",
      effects = { output = { faith = "none" } } },
    { id = "DH-08", name = "Đầm Lầy",     en = "Swamp",           rarity = "uncommon",
      canHQ = false, canSub = true,  canBuild = true,  canSpecial = false, passable = true,
      color = { 0.36, 0.45, 0.34 }, sprite = nil },
    { id = "DH-09", name = "Đồi Cỏ",      en = "Grassland Hills", rarity = "uncommon",
      canHQ = true,  canSub = true,  canBuild = true,  canSpecial = true,  passable = true,
      color = { 0.50, 0.70, 0.30 }, sprite = "hills" },
    { id = "DH-10", name = "Khu Dân Cư",  en = "Settlement",      rarity = "rare",
      canHQ = false, canSub = false, canBuild = false, canSpecial = false, passable = true,
      color = { 0.62, 0.44, 0.34 }, sprite = "settlement" },
    { id = "DH-11", name = "Danh Thắng",  en = "Landmark",        rarity = "rare",
      canHQ = false, canSub = false, canBuild = false, canSpecial = false, passable = true,
      color = { 0.78, 0.55, 0.85 }, sprite = nil },
    { id = "DH-12", name = "Núi Tuyết",   en = "Snow Peak",       rarity = "common",
      canHQ = false, canSub = false, canBuild = false, canSpecial = true,  passable = false,
      color = { 0.93, 0.95, 0.97 }, sprite = "snow" },
}

T.byId = {}
for i, t in ipairs(T.list) do
    t.index = i
    T.byId[t.id] = t
end

-- ID dùng thường xuyên trong code.
T.PLAINS     = "DH-01"
T.FOREST     = "DH-02"
T.MOUNTAIN   = "DH-03"
T.RIVER      = "DH-04"
T.COAST      = "DH-05"
T.SETTLEMENT = "DH-10"
T.LANDMARK   = "DH-11"
T.SNOW_PEAK  = "DH-12"

return T
