-- Tài Nguyên Cơ Bản (CB) trên ô. Nguồn: docs/Perisol_GDD_v1.6_Full.md §3.3 (D-020 #2; GDD thắng, bảng 0/1/2 trong ảnh
-- designer gửi chỉ được ghi lại ở D-020 câu 10, chưa dùng).
--
-- chance[địa hình][tài nguyên] = % xác suất ô có loại đó (tung độc lập từng loại); "—" trong GDD = không có khóa.
-- Loại nào xuất hiện thì có lượng 1 hoặc 2: TWO_CHANCE % ra 2, còn lại ra 1. Ngoại lệ: twoChance (Đầm Lầy TN và VH 40%) và
-- alwaysOne (Lãnh Nguyên Vàng luôn 1). Ô kề Sông được +RIVER_FAITH_BONUS điểm phần trăm xác suất TN (chỉ ở địa hình có TN).
-- Danh Thắng: mỗi cụm gắn cố định 1 loại (mapgen chọn ngẫu nhiên tới khi designer có danh sách), mọi ô của nó có loại đó.

local B = {}

B.TWO_CHANCE        = 30   -- % ra lượng 2 (còn lại ra 1)
B.RIVER_FAITH_BONUS = 10   -- điểm phần trăm xác suất TN cho ô kề Sông
B.MAX_KINDS_PER_TILE = nil -- GDD "MaxKindsPerTile": nil = không giới hạn; đặt 2 thì mỗi ô tối đa 2 loại (loại dư bị bỏ ngẫu nhiên)

--                   KH = science, VH = culture, KT = engineering, TN = faith, V = gold
B.chance = {
    ["DH-01"] = { culture = 20, engineering = 30, faith = 15, gold = 25 },                       -- Đồng Bằng
    ["DH-02"] = { science = 25, culture = 10, engineering = 15, faith = 30 },                    -- Rừng
    ["DH-03"] = { science = 35, engineering = 45, faith = 10, gold = 15 },                       -- Núi
    ["DH-04"] = { culture = 15, faith = 35, gold = 20 },                                         -- Sông
    ["DH-05"] = { science = 10, culture = 20, engineering = 10, faith = 10, gold = 40 },         -- Bờ Biển
    ["DH-06"] = { science = 10, culture = 5, engineering = 20, faith = 15, gold = 10 },          -- Lãnh Nguyên
    ["DH-07"] = { science = 20, culture = 5, engineering = 25, gold = 30 },                      -- Sa Mạc
    ["DH-08"] = { science = 15, culture = 40, engineering = 10, faith = 45 },                    -- Đầm Lầy
    ["DH-09"] = { science = 10, culture = 20, engineering = 35, faith = 15, gold = 20 },         -- Đồi Cỏ
    ["DH-10"] = { culture = 50, faith = 20, gold = 40 },                                         -- Khu Dân Cư
    ["DH-12"] = { science = 40, engineering = 30, faith = 15, gold = 10 },                       -- Núi Tuyết
}

-- Ngoại lệ về lượng (% ra 2) và về "luôn ra 1".
B.twoChance = { ["DH-08"] = { faith = 40, culture = 40 } }
B.alwaysOne = { ["DH-06"] = { gold = true } }

return B
