-- Công trình Phái Sinh D-01..D-05 (M1.5 phase G). Nguồn: docs/Perisol_Data.md sheet "Công trình" (bản chuẩn),
-- GDD §8.2. Quyết định cụ thể hóa ở docs/Decisions.md D-018.
--
-- Mỗi công trình Phái Sinh nối hai công trình Cơ Bản đủ cấp:
--   host    = công trình "chủ" (id, cấp tối thiểu): Phái Sinh gắn vào đây và dùng ô của nó
--   partner = công trình đối tác (id, cấp tối thiểu), hoặc dep = Phái Sinh khác phải đang hoạt động (D-05)
--   maxGap  = số ô trống tối đa giữa hai footprint. 0 = phải liền kề; 1–2 cần đường nối liên tục; >2 không thể
--   site    = true nếu chiếm thêm 1 ô thực hữu trống (D-03, D-05), kèm siteTerrains
--   faces   = các mặt xúc xắc cho +1 vật liệu mỗi viên khớp (Long Mạch chia sẻ, như công trình Cơ Bản)
--   period  = cứ `period` lượt của chủ thì +1 vật liệu thụ động
-- Ô `levels[1]` có cùng dạng với src/data/buildings.lua nên Buildings.byId tra được tên/biểu tượng/địa hình.

local D = {}

D.list = {
    {
        id = "D-01", name = "Phòng TN Vật Liệu", en = "Materials Lab", icon = "HK", main = "engineering",
        material = "alloy", host = { "B-01", 2 }, partner = { "B-02", 2 }, maxGap = 2, site = false,
        cost = { engineering = 3, science = 2, gold = 2 }, faces = { 3, 1 }, period = 3,
        note = "+1 Hợp Kim khi ra KT hoặc KH; +1 mỗi 3 vòng; TN-05 trên ô chủ: +1 mỗi vòng",
    },
    {
        id = "D-02", name = "Xưởng In Ấn", en = "Print Works", icon = "GI", main = "culture",
        material = "paper", host = { "B-03", 1 }, partner = { "B-01", 2 }, maxGap = 1, site = false,
        cost = { culture = 2, engineering = 2, gold = 1 }, faces = { 2, 3 },
        note = "+1 Giấy khi ra VH hoặc KT; có đường nối hai công trình: +1 mỗi vòng",
    },
    {
        id = "D-03", name = "Xưởng Luyện Kim", en = "Foundry", icon = "TH", main = "engineering",
        material = "steel", host = { "B-01", 3 }, partner = { "B-04", 2 }, maxGap = 0, site = true,
        siteTerrains = { ["DH-01"] = true, ["DH-03"] = true, ["DH-09"] = true },
        cost = { engineering = 4, faith = 2, gold = 3 }, faces = { 3 }, period = 4,
        note = "+1 Thép khi ra KT; +1 mỗi 4 vòng; phải liền kề (không dùng đường); chiếm 1 ô kề Trại KT C3",
    },
    {
        id = "D-04", name = "Xưởng Dệt Lụa", en = "Silk Workshop", icon = "LU", main = "culture",
        material = "silk", host = { "B-03", 2 }, partner = { "B-04", 2 }, maxGap = 1, site = false,
        cost = { culture = 3, faith = 2, gold = 2 }, faces = { 2, 4 },
        note = "+1 Lụa khi ra VH hoặc TN; kề Khu Dân Cư: +1 mỗi vòng; kề Đầm Lầy/Sông: +1 mỗi vòng",
    },
    {
        id = "D-05", name = "Nhà Ngân Hàng", en = "Bank", icon = "TP", main = "gold",
        material = "bond", host = { "B-05", 2 }, dep = "D-02", maxGap = 2, site = true,
        siteTerrains = { ["DH-01"] = true, ["DH-05"] = true, ["DH-10"] = true },
        cost = { gold = 5, culture = 2, engineering = 2 }, faces = { 5 },
        note = "+1 Tín Phiếu khi ra Vàng (tối đa 5); mỗi Tín Phiếu lãi 0.5 V mỗi vòng; đổi 1 Tín Phiếu lấy 2 V",
    },
}

D.byId = {}
for i, d in ipairs(D.list) do
    d.index = i
    D.byId[d.id] = d
    -- cấp 1 giả cùng dạng với công trình Cơ Bản: Phái Sinh gắn vào chủ chiếm 0 ô, loại có ô riêng chiếm 1 ô
    d.levels = { {
        cost = d.cost, tiles = d.site and 1 or 0, shape = "single", produces = {},
        terrains = d.siteTerrains or {}, level = 1, buildingId = d.id, fullId = d.id .. ".1",
    } }
end

return D
