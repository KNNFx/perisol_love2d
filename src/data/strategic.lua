-- Tài nguyên chiến lược TN-01..TN-12. Nguồn: docs/Perisol_Data.md, sheet "Tài nguyên Chiến lược".
-- terrains = nil nghĩa là xuất hiện trên bất kỳ địa hình nào (TN-12).
-- tileBonus: không cần sở hữu; buildingBonus: cần sở hữu. Chỉ là mô tả, logic ở M1.5.

local S = {}

S.list = {
    { id = "TN-01", name = "Đá Granite",    en = "Granite",        rarity = "common",   letter = "G",
      terrains = { "DH-03", "DH-09" },
      tileBonus = "Tile +1 KT bổ sung khi xúc xắc ra KT", buildingBonus = "Pháo Đài: -2 KT chi phí xây" },
    { id = "TN-02", name = "Rừng Cổ Thụ",   en = "Ancient Forest", rarity = "common",   letter = "A",
      terrains = { "DH-02" },
      tileBonus = "+1 TN và +1 KH thụ động/vòng", buildingBonus = "Thiên Đình: bỏ yêu cầu địa hình Rừng" },
    { id = "TN-03", name = "Cá",            en = "Fishing Ground", rarity = "common",   letter = "F",
      terrains = { "DH-05", "DH-04" },
      tileBonus = "Khu Chợ +2V khi ra Vàng; kết nối HQ ảo", buildingBonus = "Khu Chợ: không cần Đường Đất đến HQ" },
    { id = "TN-04", name = "Ngựa",          en = "Horse Pasture",  rarity = "uncommon", letter = "H",
      terrains = { "DH-01", "DH-09", "DH-06" },
      tileBonus = "Viễn Chinh +2 bước nếu HQ trong bán kính 2", buildingBonus = "Chuồng Ngựa: -2 TN chi phí Viễn Chinh" },
    { id = "TN-05", name = "Quặng Lộ Thiên", en = "Open-cast Ore", rarity = "uncommon", letter = "O",
      terrains = { "DH-03", "DH-09", "DH-01" },
      tileBonus = "Tile +2 KT khi ra KT; Hợp Kim tỷ lệ 1:1", buildingBonus = "Phòng TN Vật Liệu: +1 Hợp Kim thụ động/vòng" },
    { id = "TN-06", name = "Vàng Sa Khoáng", en = "Alluvial Gold", rarity = "rare",     letter = "V",
      terrains = { "DH-04", "DH-05", "DH-01" },
      tileBonus = "Tile +3V khi ra Vàng; Chi Phối -1 ngưỡng", buildingBonus = "Khu Chợ Cấp 2+: tỷ lệ đổi 1:1 tất cả" },
    { id = "TN-07", name = "Đá Thiêng",     en = "Sacred Stone",   rarity = "rare",     letter = "S",
      terrains = { "DH-03", "DH-02", "DH-09" },
      tileBonus = "Tile +2 TN khi ra TN; Đền Thờ miễn cooldown 1v/5v", buildingBonus = "Thiên Đình: aura +1 ô nếu trên tile này" },
    { id = "TN-08", name = "Đất Màu Mỡ",    en = "Fertile Land",   rarity = "common",   letter = "M",
      terrains = { "DH-01", "DH-09" },
      tileBonus = "+1 sản lượng cơ bản cho mọi CT trên tile", buildingBonus = "CT Cấp 1 trên tile: -1 KT chi phí xây" },
    { id = "TN-09", name = "Suối Nước Nóng", en = "Hot Spring",    rarity = "rare",     letter = "W",
      terrains = { "DH-03", "DH-09", "DH-01" },
      tileBonus = "Tile liền kề: +1 VH thụ động/vòng", buildingBonus = "Đền Thờ Cấp 2+ kề: aura +1 TN bán kính 1" },
    { id = "TN-10", name = "Cảng Tự Nhiên", en = "Natural Harbor", rarity = "uncommon", letter = "P",
      terrains = { "DH-05" },
      tileBonus = "Giao Thương miễn phí Vàng/tile; ĐV +3 bước", buildingBonus = "Khu Chợ Cấp 1 = Cấp 3 khi trên tile này" },
    { id = "TN-11", name = "Gió Mạnh",      en = "Wind Corridor",  rarity = "uncommon", letter = "N",
      terrains = { "DH-05", "DH-01", "DH-06" },
      tileBonus = "Viễn Chinh +1 bước qua tile; PQ +2 bước ngẫu nhiên", buildingBonus = "Tháp Thiên Văn kề: aura +1 ô" },
    { id = "TN-12", name = "Địa Linh",      en = "Ley Line Node",  rarity = "very_rare", letter = "L",
      terrains = nil,
      tileBonus = "Long Mạch +1 ô; CT nhận sản lượng từ cả 2 viên", buildingBonus = "Đài LM: Phát Sóng Toàn Cầu 2 lần/3 vòng" },
}

S.byId = {}
for i, s in ipairs(S.list) do
    s.index = i
    S.byId[s.id] = s
end

S.LEY_NODE = "TN-12"

-- true nếu TN `id` được phép xuất hiện trên địa hình `terrainId`.
function S.allowedOn(id, terrainId)
    local s = S.byId[id]
    if not s then return false end
    if not s.terrains then return true end
    for _, t in ipairs(s.terrains) do
        if t == terrainId then return true end
    end
    return false
end

return S
