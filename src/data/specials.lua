-- Công trình Đặc Biệt S-01..S-05 (M1.5 phase H). Nguồn: docs/Perisol_Data.md sheet "Công trình" (bản chuẩn),
-- docs/Perisol_GDD_v1.2_Full.md §8.3. Quyết định cụ thể hóa ở docs/Decisions.md D-019.
--
--   shape     = tên hình trong src/data/shapes.lua (chiếm đủ các ô, tất cả phải là ô thực hữu của chủ)
--   terrains  = địa hình hợp lệ của ô TRUNG TÂM (ô neo): true | "pref" (ưu tiên)
--   prereq    = { { id, level, radius } }: công trình Cơ Bản của chủ cần có trong bán kính quanh ô trung tâm
--   levels[1] = cấp xây ban đầu; levels[2], levels[3] = nâng cấp "+1", "+2" (không đổi footprint)
--   mỗi cấp: cost (kể cả vật liệu phái sinh), aura (bán kính) và cờ hiệu ứng đã cộng dồn tới cấp đó
--   yield     = thu nhập thụ động mỗi lượt của chủ
-- Dạng `levels[n]` cũng khớp công trình Cơ Bản (cost, tiles, shape, produces, terrains) nên Buildings.byId tra được.

local Shapes = require("src.data.shapes")

local S = {}

S.list = {
    {
        id = "S-01", name = "Tháp Thiên Văn", en = "Observatory", icon = "TV", main = "science",
        shape = "hex7", terrains = { ["DH-03"] = "pref", ["DH-09"] = true, ["DH-01"] = true },
        prereq = { { id = "B-02", level = 3, radius = 3 } },
        levels = {
            { cost = { alloy = 3, science = 5, paper = 2 }, aura = 2, peek = 1 },
            { cost = { alloy = 2, gold = 4 },               aura = 3, peek = 1 },
            { cost = { alloy = 3, paper = 3, gold = 6 },    aura = 3, peek = 2, reroll = true },
        },
        note = "Aura: +1 KH mỗi viên KH cho công trình của bạn trong bán kính. Xem trước viên xúc xắc kế tiếp.",
    },
    {
        id = "S-02", name = "Pháo Đài Chiến Lược", en = "Fortress", icon = "PD", main = "engineering",
        shape = "fort4", terrains = { ["DH-03"] = "pref", ["DH-09"] = true, ["DH-01"] = true },
        graniteOnMountain = true,     -- xây trên Núi cần ô có TN-01 Đá Granite (Data)
        prereq = { { id = "B-01", level = 2, radius = 2 } },
        levels = {
            { cost = { steel = 3, engineering = 6, gold = 5 }, aura = 2, speed = 2 },
            { cost = { steel = 2, gold = 4 },                  aura = 3, speed = 2, stall = true },
            { cost = { steel = 3, alloy = 1, gold = 6 },       aura = 3, speed = 2, stall = true, strike = true },
        },
        yield = { { res = "engineering", n = 1 } },
        note = "Aura: Phiến Quân không được dừng; Viễn Chinh đối thủ vào aura mất 2 bước. +1 KT mỗi vòng.",
    },
    {
        id = "S-03", name = "Bảo Tàng Quốc Gia", en = "National Museum", icon = "BT", main = "culture",
        shape = "triangle", terrains = { ["DH-01"] = true, ["DH-05"] = true },
        prereq = { { id = "B-03", level = 3, radius = 2 } }, needsDerived = "D-02",
        levels = {
            { cost = { silk = 2, paper = 3, culture = 6, gold = 4 }, aura = 2, voteMul = 1.5 },
            { cost = { silk = 2, culture = 4, gold = 3 },            aura = 3, voteMul = 1.5 },
            { cost = { silk = 3, paper = 2, gold = 5 },              aura = 3, voteMul = 1.5, exhibition = true },
        },
        yield = { { res = "culture", n = 2 } },
        note = "Aura: phiếu Chi Phối trên Khu Dân Cư/Danh Thắng ×1.5. +2 VH mỗi vòng; +1 điểm cuối ván mỗi Khu Dân Cư bạn chi phối trong bán kính 3.",
    },
    {
        id = "S-04", name = "Đài Phát Thanh Long Mạch", en = "Ley Broadcast Tower", icon = "DP", main = "science",
        shape = "hex7", terrains = { ["DH-01"] = true, ["DH-05"] = true },
        prereq = { { id = "B-02", level = 2, radius = 3 }, { id = "B-01", level = 2, radius = 3 } },
        levels = {
            { cost = { alloy = 2, paper = 2, science = 4, engineering = 4 }, aura = 3 },
            { cost = { alloy = 2, science = 3, gold = 4 },                   aura = 3 },
            { cost = { alloy = 3, paper = 3, gold = 6 },                     aura = 3, broadcast = true },
        },
        yield = { { res = "science", n = 1 }, { res = "engineering", n = 1 } },
        note = "Khi bạn đổ: công trình trong bán kính 3 (kể cả của đối thủ) sản xuất +1 mỗi viên. +1 KH +1 KT mỗi vòng.",
    },
    {
        id = "S-05", name = "Thiên Đình Tín Ngưỡng", en = "Celestial Temple", icon = "TD", main = "faith",
        shape = "triangle", sameTerrain = true,
        terrains = { ["DH-02"] = "pref", ["DH-03"] = true, ["DH-04"] = true, ["DH-08"] = true },
        prereq = { { id = "B-04", level = 3, radius = 2 } },
        levels = {
            { cost = { faith = 8, silk = 2, steel = 1, gold = 4 }, aura = 2, cancel7 = 1, pushPay = 2 },
            { cost = { faith = 4, gold = 3 },                      aura = 2, cancel7 = 2, pushPay = 2, pushChoose = true },
            { cost = { silk = 2, faith = 5, gold = 5 },            aura = 2, cancel7 = 2, pushPay = 2, pushChoose = true, nirvana = true },
        },
        yield = { { res = "faith", n = 2 } },
        note = "Aura: PQ dừng trong aura thì trả 2 TN để đẩy ra ngoài. +2 TN mỗi vòng; hủy tổng 7 (1 lần/ván, +1: 2 lần).",
    },
}

S.byId = {}
for i, d in ipairs(S.list) do
    d.index, d.special = i, true
    S.byId[d.id] = d
    local size = #Shapes.cells[d.shape]
    for lv, def in ipairs(d.levels) do
        def.level, def.tiles, def.shape, def.produces = lv, size, d.shape, {}
        def.terrains, def.buildingId, def.fullId = d.terrains, d.id, string.format("%s.%d", d.id, lv)
        def.yield = d.yield
    end
end

S.MAX_LEVEL = 3
S.STRIKE_COOLDOWN    = 5   -- S-02 +2 "Pháo": 1 lần mỗi 5 vòng
S.STRIKE_RADIUS      = 3
S.BROADCAST_COOLDOWN = 3   -- S-04 +2 "Phát Sóng": 1 lần mỗi 3 vòng
S.SCORE_SETTLEMENT_RADIUS = 3   -- S-03: +1 điểm mỗi Khu Dân Cư chi phối trong bán kính này

return S
