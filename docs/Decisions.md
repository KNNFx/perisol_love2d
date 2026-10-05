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

## D-005 — Áp dụng skill dự án (love2d-core, camera-systems, procedural-gen, level-design, create-game-assets) — 2026-10-04
- Scene manager là **ngăn xếp** (push/pop/switch, vẽ từ dưới lên, chỉ màn trên cùng nhận input/update).
- Camera: zoom **chỉ bậc nguyên** (1–4×), giới hạn theo khung nhìn (+ lề `CAMERA_MARGIN`), vị trí vẽ snap về pixel.
- Mapgen: kiểm tra **công bằng vùng khởi đầu** (`START_ZONE_MIN_BUILDABLE`, `START_ZONE_MAX_SPREAD`) ngoài kiểm tra kết nối.
- Art: ghi `docs/art-direction-brief.md` và `docs/asset-manifest.json`; nguồn gốc/giấy phép sheet ô hex **chưa rõ** — cần chủ dự án xác nhận.

## D-006 — Chi Phối và mặt Hex (P0 #1, #4, #8) — 2026-10-05
- **Vấn đề:** GDD §7 chỉ nói "đủ phiếu theo ngưỡng khoảng cách", không cho con số. GDD §3.4 không nói mặt Hex cho cụ thể cái gì. Cũng chưa có hành động nào để đặt phiếu.
- **Quyết định:**
  - **Nguồn phiếu:**
    - Mỗi viên xúc xắc ra mặt Hex cho **người đang lượt** 1 phiếu, nên 2 viên Hex được 2 phiếu. Lá T-ECO "ngoài 1 phiếu Chi Phối" cũng hiểu theo cách này.
    - Khi tổng 7, ví dụ 1+6, mặt Hex **không** cho phiếu.
    - Trong Khâu Hành Động có thể mua thêm 1 phiếu với giá 1 VH + 1 V.
  - **Nơi đặt phiếu:** ô trong vùng ảnh hưởng (bán kính 1 quanh HQ, sau này cả Sub) hoặc ô kề Lãnh thổ thực hữu của mình. Ô đang bị Phiến Quân phong tỏa thì không đặt được.
  - **Ngưỡng** theo khoảng cách hex tới HQ gần nhất của người đặt: 1 ô cần **1 phiếu**, 2 ô cần **2**, từ 3 ô trở lên cần **3**.
    - Mức này khớp với T-ENG-02: lá này hạ ngưỡng ở khoảng cách 2 xuống 1 và ở khoảng cách 3+ xuống 2.
    - Ô có TN-06 Vàng Sa Khoáng được giảm ngưỡng 1, tối thiểu còn 1.
  - **Sở hữu:**
    - Một ô thuộc về người chơi khi số phiếu của họ ≥ ngưỡng **và** nhiều hơn hẳn mọi đối thủ. Nếu hòa thì chủ cũ giữ ô.
    - Ô có phiếu nhưng chưa ai đủ điều kiện là **Tranh chấp**.
  - **Khởi đầu:** ô HQ và 6 ô kề là Lãnh thổ thực hữu ngay từ đầu.
  - **Ô bị khóa** (đối thủ không đặt phiếu được): 7 ô nhà và mọi ô đang có công trình. Vì vậy M1 không cần xử lý việc mất ô đang có nhà.
- **Tunable:** `VOTES_PER_HEX_FACE`, `VOTE_COST`, `CHI_PHOI_THRESHOLD`, `INFLUENCE_RADIUS`.

## D-007 — Tài nguyên khởi đầu và setup (P0 #2) — 2026-10-05
- **Quyết định:**
  - Mỗi người chơi bắt đầu với **2 KH, 2 VH, 2 KT, 2 TN, 5 V**, đủ xây khoảng 2 công trình C1.
  - Đổi với ngân hàng theo tỉ lệ **4:1**: 4 tài nguyên cùng loại đổi 1 tài nguyên bất kỳ.
  - Thứ tự setup trong M1 dựa trên GDD §11.1:
    1. Sinh map.
    2. Đổ xúc xắc xếp thứ tự lượt; hòa thì đổ lại.
    3. Theo thứ tự lượt, mỗi người chọn 1 vùng khởi đầu (`map.starts`), HQ đặt ở tâm vùng đó.
    4. Phiến Quân xuất hiện. Bước này dời ra sau khi đặt HQ, vì luật xuất hiện cần biết vị trí HQ.
    5. Phát tài nguyên khởi đầu.
  - Chọn nhân vật để stub đến M3.
- **Tunable:** `STARTING_RESOURCES`, `BANK_TRADE_RATE`.

## D-008 — Xúc xắc, sản lượng, tổng 7 (P0 #5, #7) — 2026-10-05
- **Quyết định:**
  - **Tổng 7** tính theo số trên mặt (1+6, 2+5, 3+4; xác suất 1/6). Khi ra 7, **không ai sản xuất** (kể cả mặt Hex) và Phiến Quân kích hoạt.
  - **Sản lượng** dùng bảng theo cấp trong Data, sheet Công trình (ví dụ B-01.1 cho "1 KT khi ra KT"), **nhân với số viên khớp**. Bỏ công thức "Cấp × Cơ bản × số viên" của GDD §5.2.
  - **Long Mạch chia sẻ:** mọi công trình của mọi người chơi khớp mặt đều sản xuất, không phụ thuộc ai là người đổ.
  - **Bonus TN trong M1:** công trình đứng trên ô có TN nhận thêm bonus, tính theo **mỗi viên khớp**. Ô không cần sở hữu, nhưng phải có công trình thì mới có sản lượng để cộng.
    - TN-01: +1 KT khi ra KT.
    - TN-03: Khu Chợ +2 V khi ra Vàng.
    - TN-05: +2 KT khi ra KT.
    - TN-06: +3 V khi ra Vàng.
    - TN-07: +2 TN khi ra TN.
    - TN-08: +1 sản lượng.

    Các bonus còn lại (thụ động mỗi vòng, di chuyển, TN-12 "nhận từ cả 2 viên") để sang M1.5.
  - Mọi modifier đi qua pipeline Gốc → Nhân vật → Công Nghệ → Aura → TNCL → Đường, làm tròn xuống ở bước cuối (Data §7).
- **Tunable:** `SEVEN`, bảng `produces` trong `src/data/buildings.lua`.

## D-009 — Phiến Quân (P0 #9) — 2026-10-05
- **Vấn đề:** GDD §6.2 không nói cách xử lý khi hòa ở "tài nguyên nhiều nhất", và dòng "Ô có tài nguyên ngoài chủ" không rõ nghĩa.
- **Quyết định:**
  - **Xuất hiện:**
    - Sau khi đặt HQ, Phiến Quân xuất hiện trên một ô Đồng Bằng / Lãnh Nguyên / Sa Mạc (DH-01/06/07) cách mọi HQ ít nhất 2 ô.
    - Nếu không có ô nào như vậy thì chọn bất kỳ ô nào đi được.
  - **Di chuyển:**
    - Người đổ 7 đổ thêm 1d6, kết quả là số điểm di chuyển.
    - Chi phí vào từng ô theo cột U-03 trong Data §3. Núi và Núi Tuyết cấm đi trong 10 vòng đầu, sau đó tốn 3.
    - Người đổ 7 điều khiển từng bước, không undo (A-09). Phiến Quân dừng khi hết điểm hoặc khi không còn ô kề nào đủ điểm để vào.
  - **Phong tỏa** ô đứng và 6 ô kề:
    - Công trình trong vùng phong tỏa không sản xuất.
    - Không đặt phiếu và không xây được trên các ô đó.
  - **Khi dừng trên công trình (kể cả HQ) của người khác:**
    - Chủ công trình mất ceil(½) loại tài nguyên cốt lõi đang có nhiều nhất. Nếu có nhiều loại cùng nhiều nhất, **chủ tự chọn**.
    - Người đổ 7 nhận ceil(½) số vừa bị mất.
    - Như vậy hai dòng trong GDD §6.2 được gộp thành một luật. Ví dụ: chủ có 5 V, mất 3 V; người đổ nhận 2 V.
  - Dừng trên công trình của chính người đổ, hoặc trên ô trống: chỉ phong tỏa.
- **Tunable:** `REBEL_*` (Data §8.1) cộng thêm `REBEL_SPAWN_TERRAINS`, `REBEL_SPAWN_MIN_HQ_DIST`, `REBEL_MOUNTAIN_COST`.

## D-010 — Đặt công trình C1 (một phần P0 #6) và tính điểm — 2026-10-05
- **Đặt C1:**
  - Địa hình hợp lệ lấy theo ma trận "Đặt công trình" của Data.
  - Ô ⭐ (ưu tiên) chưa có bonus, vì Data chưa cho con số.
  - Điều kiện "cần đường nếu không liền HQ" của Khu Chợ để sang M1.5, vì M1 chưa có đường.
  - Xung đột của C2/C3 sẽ chốt ở M1.5.
- **Tính điểm (GDD §11.2):**
  - 1 điểm cho mỗi ô thực hữu.
  - 3 điểm cho mỗi Danh Thắng mà người chơi sở hữu **mọi ô** của nó.
  - 2 điểm cho mỗi công trình C2+.
  - 1 điểm cho mỗi 5 tài nguyên còn dư (cộng cả 5 loại cốt lõi).
- **Khi hòa điểm:** so số ô thực hữu, rồi so tổng tài nguyên. Vẫn hòa thì đồng hạng.
- **Tunable:** `SCORE_TILE`, `SCORE_LANDMARK`, `SCORE_BUILDING_C2`, `SCORE_RES_PER_POINT`.

## D-011 — Kiến trúc M1 (áp dụng skill save-systems, input-systems, game-ui-ux, game-feel) — 2026-10-05
- **Command:**
  - Mọi thay đổi trạng thái đi qua `Game.check(state, cmd)` và `Game.apply(state, cmd)`.
  - `Game.legal(state)` liệt kê các lệnh hợp lệ, dùng chung cho UI, test mô phỏng, AI (P6) và multiplayer (P7).
- **Save:**
  - Lưu dữ liệu thuần, có trường `version`.
  - **Không lưu map**: map là hàm tất định của `(seed, players)` nên được sinh lại khi load.
  - Ghi vào file tạm rồi đổi tên; giữ một bản `.bak`; kiểm tra hợp lệ khi load.
  - Replay = seed + danh sách lệnh.
- **Input:** phím được gán vào action có tên (`src/input/actions.lua`). Gameplay không đọc phím thô.
- **UI:**
  - Bố cục neo theo mép và góc màn hình, phải dùng được từ 1024×576 đến 1280×720 trở lên.
  - Màn hình quản lý bằng stack.
  - HUD cập nhật theo các sự kiện mà `Game.apply` trả về; log hiển thị từng sự kiện sản xuất.
- **Feedback:**
  - Tween có easing cho xúc xắc và số tài nguyên nhảy.
  - Chia mức theo độ quan trọng: ra 7 và Phiến Quân dừng ở mức lớn; sản xuất ở mức nhỏ.
  - Có tùy chọn giảm rung màn hình.

## Xung đột tài liệu đã phát hiện (chọn theo Data)
| Chủ đề | GDD §3.1 / §8 | Data | Chọn |
|---|---|---|---|
| Đầm Lầy đặt Sub | Không | ✅ (sheet Địa hình: HQ ❌, Sub ✅) | Data |
| Đồng Bằng xây CT Đặc Biệt | GDD cho phép (X) | Sheet Địa hình ghi ❌ nhưng sheet Công trình liệt kê Đồng Bằng cho S-01/02/03/04 | Data sheet Công trình (chờ làm rõ ở M1.5) |
| Núi: Sông cho HQ | Không | Không | Khớp |
| Đồi Cỏ: CT Đặc Biệt | GDD X | ✅ | Khớp |
| Trại Khai Thác C1 trên Rừng/Bờ Biển | Đồng Bằng, Núi (§8.1) | Ma trận ✅ Rừng/Bờ Biển; sheet Công trình ❌ | Ma trận cho C1 ở M1 (D-010); C2/C3 chốt ở M1.5 |
| Sản lượng công trình | `Cấp × Cơ bản × số viên` (§5.2) | Bảng sản lượng theo cấp | Data × số viên khớp (D-008) |
| Phiến Quân cướp tài nguyên | 2 dòng tách rời, mơ hồ (§6.2) | — | Gộp: chủ mất ceil(½), người đổ nhận ceil(½) (D-009) |
