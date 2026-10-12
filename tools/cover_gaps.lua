-- Khoảng trống phủ đã biết của bot ngẫu nhiên (xem tools/cover.lua). Danh sách chỉ được co lại:
-- loại nào trong danh sách mà batch đã phủ thì `make cover` fail, buộc xóa khỏi đây.
-- Đo 2026-10-12 trên 60 ván thường + 2 ván rich; quét thêm std seed 61..260 và rich 2 người seed 15..60 cũng không chạm các loại này.
return {
    commands = { "buildSpecial", "upgradeSpecial", "fortressStrike" },
    -- Ba event đầu là hệ quả của ba lệnh trên; broadcast (mặt Hex), rebel_pushed (đẩy Phiến Quân bằng prompt) và
    -- seven_cancelled (hủy tổng 7) chưa bao giờ xuất hiện trong ván của bot.
    events = { "fortress_strike", "special_built", "special_upgrade", "broadcast", "rebel_pushed", "seven_cancelled" },
}
