# Perisol — Nhật ký quyết định thiết kế / kỹ thuật

Mỗi quyết định ghi: bối cảnh, lựa chọn, lý do. Khi tài liệu thiết kế mâu thuẫn, `Perisol_Data.md` là chuẩn (xem `CLAUDE.md`).

## D-001 — Kích thước bản đồ (P0 #3) — 2026-10-04
- **Vấn đề:** GDD §3.1 ghi "bán kính 3 ô = 19 ô" (sai: bán kính 2 = 19 ô, bán kính 3 = 37 ô) và tỉ lệ map "16:8 / 4 người 32:16" nhưng không nói rõ 2–3 người.
- **Quyết định:** map hình chữ nhật, offset odd-r.
  - 1–2 người: **16×8** ô. 3–4 người: **32×16** ô.
  - Vùng an toàn mỗi HQ là bán kính 2 (19 ô) — `START_ZONE_RADIUS`.
- **Tunable:** `MAP_SIZE_BY_PLAYERS` trong `src/config/constants.lua`.

## D-002 — Hướng hex và kích thước sprite — 2026-10-04
- Hex **pointy-top** (đỉnh nhọn ở trên), khớp `Image/HexaTiles_Test_V001.png`.
- Sprite 32×32 px; lát gạch bước ngang **32**, bước dọc **24**, hàng lẻ lệch 16 px.
- Tọa độ logic: axial `(q, r)`; map chữ nhật dùng offset **odd-r** (hàng lẻ lệch phải).

## D-003 — Test chạy qua LÖVE — 2026-10-04
- Máy không có Lua/LuaJIT riêng. Test chạy bằng `lovec.exe . --test` với mini-runner tự viết (`tests/runner.lua`, API kiểu `describe/it/expect`).
- `src/core/` không được gọi `love.*` để test headless và dùng lại cho AI/multiplayer.

## D-004 — RNG tự viết — 2026-10-04
- Park–Miller (`s = s * 48271 % 2147483647`), thuần Lua, tất định theo seed, không phụ thuộc `love.math`.

## Xung đột tài liệu đã phát hiện (chọn theo Data)
| Chủ đề | GDD §3.1 / §8 | Data | Chọn |
|---|---|---|---|
| Đầm Lầy đặt Sub | Không | ✅ (sheet Địa hình: HQ ❌, Sub ✅) | Data |
| Đồng Bằng xây CT Đặc Biệt | GDD cho phép (X) | Sheet Địa hình ghi ❌ nhưng sheet Công trình liệt kê Đồng Bằng cho S-01/02/03/04 | Data sheet Công trình (chờ làm rõ ở M1.5) |
| Núi: Sông cho HQ | Không | Không | Khớp |
| Đồi Cỏ: CT Đặc Biệt | GDD X | ✅ | Khớp |
| Trại Khai Thác C1 trên Rừng/Bờ Biển | Đồng Bằng, Núi (§8.1) | Ma trận ✅ Rừng/Bờ Biển; sheet Công trình ❌ | Chờ quyết định ở M1.5 (đề xuất: ma trận) |
