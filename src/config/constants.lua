-- Hằng số cân bằng (tunable). Nguồn: docs/Perisol_Data.md §8.1 "HẰNG SỐ CÂN BẰNG".
-- Sửa giá trị ở đây khi playtest; không hard-code số trong logic.

local C = {}

-- ─── Data §8.1 ──────────────────────────────────────────────────────────────
C.MAX_EXPEDITION_PER_PLAYER     = 3   -- Quota Viễn Chinh đồng thời
C.MAX_TRADE_PER_PLAYER          = 2   -- Quota Giao Thương (Thương Nhân = 3)
C.MAX_OUTPOST_PER_PLAYER        = 4   -- Quota Chốt Phòng Thủ (đề xuất)
C.EXPEDITION_BASE_MOVE          = 4
C.KNIGHT_BASE_MOVE              = 6
C.TRADE_BASE_MOVE               = 5
C.TRAIN_BASE_MOVE               = 9
C.SUPPRESS_THRESHOLD_EXPEDITION = 4
C.SUPPRESS_THRESHOLD_KNIGHT     = 3
C.SUPPRESS_THRESHOLD_FLOOR      = 2
C.SUPPRESS_GUARANTEE_FAITH      = 2
C.REBEL_BLOCKADE_TILES          = 7
C.REBEL_MOVE_DICE               = 6
C.REBEL_MOUNTAIN_LOCK_ROUNDS    = 10
C.EXPEDITION_UPKEEP_GOLD        = 1   -- Từ đơn vị thứ 2 (đề xuất)
C.ROAD_COST_PER_TILE            = 1
C.TRADE_FEE_PER_TILE            = 1
C.DURABILITY_DIRT_ROAD          = 1
C.DURABILITY_STONE_ROAD         = 2
C.DURABILITY_RAILWAY            = 3
C.DURABILITY_PIPELINE           = 2
C.RAIL_MIN_DURABILITY_FOR_TRAIN = 2
C.REPAIR_PER_ACTION_MAX         = 2
C.AUTO_REPAIR_PER_ROUND         = 1
C.AUTO_REPAIR_GOLD_COST         = 2
C.PIPELINE_WEAR_INTERVAL        = 5
C.ENVOY_LIFETIME_ROUNDS         = 3   -- Đề xuất

-- ─── Map generation (M0, docs/Decisions.md D-001) ──────────────────────────
-- Kích thước {cột, hàng} theo số người chơi (GDD §3.1: 16:8, 4 người = 32:16).
C.MAP_SIZE_BY_PLAYERS = {
    [1] = { 16, 8 },
    [2] = { 16, 8 },
    [3] = { 32, 16 },
    [4] = { 32, 16 },
}
C.START_ZONE_RADIUS     = 2      -- Vùng an toàn quanh HQ (19 ô)
C.MIN_START_DISTANCE    = 5      -- Khoảng cách hex tối thiểu giữa 2 tâm khởi đầu
C.TERRAINS_PER_GAME     = 7      -- Rút 7 trong 12 loại địa hình
C.MIN_TILES_PER_TERRAIN = 2      -- Mỗi địa hình đã rút phải có ít nhất ngần này ô
C.SETTLEMENT_SIZE_MIN   = 2      -- Cụm Khu Dân Cư: 2–10 ô
C.SETTLEMENT_SIZE_MAX   = 10
C.CITY_STATE_THRESHOLD  = 7      -- Cụm > 7 ô thành Thành Bang Tự Do
C.REGION_SEED_DENSITY   = 1 / 8  -- Số hạt giống Voronoi trên mỗi ô
C.COAST_DEPTH_MIN       = 1
C.COAST_DEPTH_MAX       = 2
C.STRATEGIC_CHANCE = {           -- Xác suất mỗi ô hợp lệ mang 1 TN, theo độ hiếm
    common   = 0.08,
    uncommon = 0.04,
    rare     = 0.02,
}
C.LEY_NODE_COUNT        = { 1, 2 } -- TN-12 Địa Linh: 1–2 ô/ván
C.MAPGEN_MAX_ATTEMPTS   = 50
-- Công bằng giữa các người chơi: số ô xây được trong vùng khởi đầu (19 ô).
C.START_ZONE_MIN_BUILDABLE = 12  -- mỗi vùng tối thiểu
C.START_ZONE_MAX_SPREAD    = 4   -- chênh lệch tối đa giữa vùng nhiều nhất và ít nhất

-- ─── Render ────────────────────────────────────────────────────────────────
-- Sprite hex pointy-top 32×32; lát gạch bước ngang 32, bước dọc 24.
C.TILE_W      = 32
C.TILE_H      = 32
C.TILE_STEP_Y = 24
C.ZOOM_LEVELS = { 1, 2, 3, 4 }   -- chỉ số nguyên: pixel art không méo khi phóng
C.CAMERA_PAN_SPEED = 600         -- px màn hình / giây
C.CAMERA_MARGIN    = 48          -- px thế giới cho phép kéo quá mép bản đồ

return C
