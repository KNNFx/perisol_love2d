# Perisol — Nhật ký quyết định thiết kế / kỹ thuật

Mỗi quyết định ghi: bối cảnh, lựa chọn, lý do.

- **Nguồn chuẩn khi tài liệu mâu thuẫn:**
  - Từ 2026-11-01 (D-020), **GDD 1.6** (`Perisol_GDD_v1.6_Full.md`) thắng khi lệch với `Perisol_Data.md`. Data dùng cho số liệu mà GDD không nói tới.
  - Trước đó (D-001..D-019), Data là chuẩn.
  - Mọi chỗ lệch được ghi vào bảng xung đột ở cuối file.
- **Tham chiếu "§x":**
  - Trong D-001..D-019, "§x" trỏ tới GDD v1.2. File `Perisol_GDD_v1.2_Full.md` đã xóa, xem lại trong git history.
  - Từ D-020, "§x" trỏ tới GDD 1.6. Số mục phần lớn giữ nguyên; các mục mới là 3.3, 7.4, 7.5, 8.4, 11.3, 12.4 và Phụ lục D, E.

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

## D-012 — Đối chiếu GDD v1.2 bản đầy đủ (PDF) với M1 — 2026-10-05
*(Trạng thái 2026-10-06: các điểm #1–#7 và #9 đã xử lý ở D-013; #8, #10, #11 giữ nguyên có chủ đích. Cập nhật 2026-10-07: #8 đã chốt ở D-014 (không cho không, giữ ngân hàng 4:1); hiệu ứng Đồi Cỏ/Rừng của #9 làm ở M1.5. Cập nhật 2026-11-01: GDD 1.6 viết lại #1, #2, #3, #6, #7 và chốt #5 (Núi tốn 3), #11 (Khu Dân Cư cho xây Nhà Văn Hóa, Khu Chợ C1–C2 và Bảo Tàng); xem D-020.)*
`docs/Perisol_GDD_v1.2_Full.md` đã được chép lại khớp 100% với `Perisol_GDD_v1.2.pdf`. Bản cũ là bản rút gọn và thiếu nhiều luật. Đối chiếu bản đầy đủ với các quyết định D-006..D-011 và code M1 cho kết quả dưới đây.

**PDF xác nhận (không cần đổi):**
- Ngưỡng phiếu 1 / 2 / 3+ theo khoảng cách (§5.4 khung "Phân biệt quan trọng", Phụ lục A). D-006 trước đây là suy luận, nay đã có chữ.
- Mỗi mặt Hex cho người đang lượt 1 phiếu Chi Phối, dùng trong Khâu Hành Động (§5.2). Khớp D-006.
- Tổng 7: không ai nhận tài nguyên, Phiến Quân kích hoạt (§5.2). Công trình trong vùng phong tỏa không sản xuất (§5.2 khung "Cơ chế Long Mạch", §6.2). Khớp D-008 và D-009.
- Công thức sản lượng `Cấp × Sản lượng cơ bản × số viên khớp` (§5.2) cho cùng kết quả với bảng theo cấp ở §8.1 / Data khi sản lượng cơ bản = 1: C1 = 1, C2 = 2, C3 = 3 cho mặt chính. Các dòng "cross-resource" (vd. "+1 KT khi ra KH") chỉ có trong bảng. D-008 vẫn đúng. Ví dụ "nhà máy thép, cơ bản 2" ở §5.2 chỉ là minh họa.
- Thứ tự lượt: cao nhất đi trước (§11.1 bước 5). Bảng điểm (§11.2) khớp D-010 (ngoại trừ cách tính Danh Thắng, xem bảng dưới).

**Mâu thuẫn giữa PDF và M1 (cần chủ dự án quyết định):**

| # | Chủ đề | PDF nói | M1 hiện tại | Đề xuất |
|---|---|---|---|---|
| 1 | Vùng ảnh hưởng ≠ thực hữu | 6 ô quanh HQ là **vùng ảnh hưởng**, chỉ thu tài nguyên và bỏ phiếu, **không xây được** (§5.4, §7.1, Phụ lục A). Chỉ đặt phiếu **trong** vùng ảnh hưởng. Muốn với tới ô xa phải nâng HQ lên C2 (19 ô) hoặc lập Sub (§7.2, §9.1). | 7 ô nhà là của người chơi ngay từ đầu. Được đặt phiếu lên ô kề lãnh thổ của mình (D-006). | Nếu theo đúng PDF, M1 cần thêm **nâng HQ C2** và **Sub** (đang để M1.5). Nếu không, người chơi tối đa chỉ có 7 ô. Phương án tạm: giữ D-006 cho M1 và áp luật PDF khi làm M1.5. |
| 2 | Cướp ô | Người đạt ngưỡng trước được ô. Đối thủ muốn tranh lại phải trả **gấp đôi yêu cầu** (§7.2). Công trình đã xây không bị mất. | Cần nhiều phiếu hơn hẳn chủ và đạt ngưỡng; ô có công trình bị khóa (D-006). | Đổi theo PDF: ngưỡng cướp = 2 × ngưỡng. Phần khóa ô có công trình vẫn khớp. |
| 3 | Mua đất | Bỏ Vàng + Văn Hóa mua thẳng **tile** trong vùng ảnh hưởng, phí **gấp đôi theo khoảng cách** (§7.2). PDF không cho giá gốc. | Mua **phiếu** giá 1 VH + 1 V (D-006). | Cần chốt giá gốc. Gợi ý: (1 V + 1 VH) × 2^(khoảng cách − 1) cho cả ô. |
| 4 | Khu Dân Cư / Danh Thắng | 1 phiếu mỗi ô. Ai chiếm nhiều ô hơn trong cụm thì chi phối **cả cụm**. Hòa thì tranh chấp với chi phí cấp số cộng (+1) (§7.2). | Ngưỡng thường theo khoảng cách. Danh Thắng chỉ tính điểm khi sở hữu **mọi** ô (D-010). | Đổi theo PDF. Luật này ảnh hưởng trực tiếp tới điểm Danh Thắng (3 điểm/cụm). |
| 5 | Phiến Quân di chuyển | Đi **đúng** số bước; **không đi lại ô đã qua** trong lượt; Núi cấm trong "10 **lượt** đầu"; Rừng/Sông/Núi tốn thêm 1 bước (tốn 2) (§6.2). | Chi phí theo Data U-03 (Rừng 2, Sông 2, **Đầm Lầy 2**, Núi **3** sau vòng 10). **Được** đi lại ô cũ. Khóa Núi theo **vòng** (D-009). | Thêm luật không đi lại ô cũ (PDF ghi rõ, Data không nói gì). Núi giữ chi phí 3 của Data hay đổi thành 2 theo GDD: cần chốt. "Lượt" hiểu là "vòng". |
| 6 | Phiến Quân xuất hiện | Đặt ở **tile trung tâm** (hoặc tile chỉ định), **trước** khi đặt HQ (§11.1 bước 4). | Ngẫu nhiên trên Đồng Bằng/Lãnh Nguyên/Sa Mạc, cách HQ ≥ 2, **sau** khi đặt HQ (Data U-03, D-009). | Cần chốt. Data mới hơn và tránh việc PQ chặn chỗ đặt HQ. |
| 7 | Tài nguyên khởi đầu | Nhận "**từ 6 ô xung quanh HQ**" (§11.1 bước 8). | Cố định 2/2/2/2/5 (D-007). | PDF không nói địa hình nào cho tài nguyên gì. Cần bảng địa hình → tài nguyên, hoặc giữ D-007. |
| 8 | Trao đổi | Chỉ giữa **người chơi**, cần đường nối hai Khu Chợ, phí 1 Vàng mỗi ô (§5.4). §5.4 tự mâu thuẫn: "không được cho không" và "bao gồm cả cho không". | Đổi với **ngân hàng** 4:1 (D-007, PDF không có). | Giữ ngân hàng làm phương án tạm của M1 (chưa có đường). Đổi giữa người chơi làm ở M1.5. Cần chốt chuyện "cho không". |
| 9 | Hiệu ứng địa hình | Lãnh Nguyên: Vàng −1 sản lượng, xây công trình −1 KT. Sa Mạc: không sản xuất Tín Ngưỡng. Đồi Cỏ: Trại KT C2 +1 KT. Rừng: Viện NC C1 +1 KH thụ động. Đầm Lầy: "Tín Ngưỡng & Văn Hóa cao" (§3.1). | Chưa làm. | Thêm vào pipeline modifier (stage `base`). Riêng "Đầm Lầy cao" chưa có con số. |
| 10 | Đặt HQ | Chọn **tile bất kỳ** hợp lệ, có kiểm tra tự động (§11.1 bước 6). | Chọn một trong các vùng khởi đầu do mapgen tạo sẵn. | Giữ cho M1, vì như vậy công bằng hơn. Có thể mở cho chọn tự do khi có kiểm tra hợp lệ. |
| 11 | Xây trên Khu Dân Cư | §3.1: Khu Dân Cư / Danh Thắng chỉ cho Chi Phối, không xây. Nhưng §9.4 của **chính PDF** cho Nhà Văn Hóa và Khu Chợ C1–C2 ⭐ trên Khu DC. | Theo ma trận (§9.4 / Data): cho xây. | Giữ ma trận. Ghi nhận PDF tự mâu thuẫn. |

**Ghi nhận khác:**
- Trang bìa PDF ghi "PC (Godot 4 / C#)", trong khi bảng §1.2 ghi "PC — Love2D, Lua". Đây là chữ sót lại; engine đích là Love2D.
- Danh Thắng có "4 kiểu hình (đơn/tam giác/tứ giác)" (§3.1). Mapgen hiện có 3 hình (1/3/4 ô).
- Mục lộ trình nay là **§13.1** (bản cũ ghi §12).

## D-013 — Chỉnh M1 theo GDD v1.2 bản đầy đủ — 2026-10-06
Chủ dự án chọn các điểm dưới đây từ D-012. Điểm không nêu giữ như cũ. D-013 thay thế các phần tương ứng của D-006, D-007, D-009 và D-010.
*(Cập nhật 2026-11-01: GDD 1.6 thay phần lớn D-013. Bị thay: lãnh thổ khởi đầu, tài nguyên khởi đầu, giá mua ô, luật tranh lại ô, điều kiện đặt Sub, Phiến Quân cướp và xuất hiện. Code vẫn chạy theo D-013 cho tới khi làm M1.6; xem D-020.)*
- **Vùng ảnh hưởng (D-012 #1, thay D-006):**
  - Lúc đầu chỉ **ô HQ** là thực hữu. 6 ô quanh HQ là vùng ảnh hưởng, ngưỡng 1 phiếu. Chỉ **đặt phiếu và mua ô trong vùng ảnh hưởng**; không đặt lên ô HQ/Sub.
  - **Nâng HQ C2** (4 KT + 2 KH + 3 V) mở vùng ảnh hưởng ra bán kính 2 (18 ô). C3+ cần vật liệu phái sinh nên để M1.5.
  - **Khu Trực Thuộc** lập thẳng trên ô thực hữu của mình (3 TN + 3 V + 3 KT), không cần Viễn Chinh (đơn vị để M1.5). Điều kiện: địa hình `canSub`, đủ 6 ô kề, **cách HQ/Sub của mình ≥ 2**, **cách của đối thủ ≥ 3**, vòng 6 ô quanh không có Khu Dân Cư/Danh Thắng, không bị phong tỏa. Bán kính vùng ảnh hưởng của Sub: 1. (GDD §7.3 viết hai cách khoảng cách; đây là cách hiểu để lập được Sub.)
- **Cướp ô và mua ô (#2, #3):**
  - Ô chưa có chủ: ai đạt ngưỡng trước được ô.
  - Cướp ô thường: phiếu ≥ **2 × ngưỡng** của mình và hơn phiếu của chủ. Ô có công trình vẫn bị khóa.
  - Lệnh `buyVote` bị bỏ. Thay bằng **`buyTile`**: mua ô chưa có chủ trong vùng ảnh hưởng, giá (1 V + 1 VH) × 2^(khoảng cách − 1). Ô mua được ghi phiếu bằng ngưỡng nên vẫn bị cướp theo luật ×2.
- **Khu Dân Cư / Danh Thắng (#4):** mỗi ô cần 1 phiếu; ai sở hữu nhiều ô nhất trong cụm (hơn hẳn) chi phối cả cụm; Danh Thắng cho người chi phối 3 điểm. Cướp ô trong cụm cần phiếu của chủ + 1. (Thay D-010 về "sở hữu mọi ô".)
- **Phiến Quân (#5, #6):** thêm luật **không đi lại ô đã qua** trong cùng một lần di chuyển (kẹt thì dừng sớm). Chi phí địa hình và cách xuất hiện giữ theo Data như D-009.
- **Khởi đầu (#7, thay D-007):** nền 1 KH, 1 VH, 1 KT, 1 TN, 3 V + **1 tài nguyên cho mỗi ô trong 6 ô quanh HQ** theo bảng `START_BONUS_BY_TERRAIN` (Đồng Bằng/Bờ Biển/Sa Mạc → V; Rừng → KH; Núi/Lãnh Nguyên/Đồi Cỏ/Núi Tuyết → KT; Sông/Đầm Lầy → TN; Khu Dân Cư/Danh Thắng → VH). Bảng này là đề xuất của dự án vì PDF không cho; chỉnh trong `constants.lua`.
- **Địa hình (#9):** chỉ phần tác dụng với công trình cấp 1: Lãnh Nguyên xây −1 KT và Vàng −1 sản lượng mỗi viên; Sa Mạc không sản xuất Tín Ngưỡng. Phần thụ động (Rừng) và cấp 2 (Đồi Cỏ) để M1.5.
- **Giữ nguyên:** đổi tài nguyên với ngân hàng 4:1 (#8), chọn vùng khởi đầu do mapgen tạo (#10), ma trận cho xây trên Khu Dân Cư (#11).
- **Save:** `SAVE_VERSION = 2`; save v1 được nâng cấp khi nạp (thêm `hqLevel`, `level` của Sub).
- **Tunable:** `INFLUENCE_RADIUS_HQ/SUB`, `HQ_UPGRADE_COST`, `SUB_COST`, `SUB_MIN_DIST_*`, `RETAKE_MULTIPLIER`, `CLUSTER_*`, `BUY_TILE_BASE/GROWTH`, `STARTING_RESOURCES`, `START_BONUS_*`.
- **Hệ quả cần theo dõi khi playtest:** mô phỏng ngẫu nhiên cho khoảng 6–7 ô thực hữu mỗi người sau 20 vòng (trước đó khoảng 9). Cụm Khu Dân Cư/Danh Thắng chỉ với tới được sau khi có Sub, nên điểm Danh Thắng hiếm.

## D-014 — Phạm vi và luật M1.5 (Công Trình & Hạ Tầng) — 2026-10-07
Kế hoạch triển khai chia theo phase A–I ở `plan.md` mục P3.

**Chủ dự án chốt:**
- **Phạm vi:**
  - M1.5 làm bước 1–7 của P3.
  - **Hoãn tầng công nghiệp** (Mỏ Than, Giếng Dầu, Đường Ray + U-02T, Đường Ống + U-04, độ bền/sửa chữa) đến sau M2/M3. Đường Ray vốn cần thẻ Công Nghệ "Mạng Lưới Giao Thông" của M2.
  - Ngoại lệ vẫn làm ở M1.5: Phiến Quân đi qua Đường Đất thì đường mất (độ bền 1); dừng trên Lát Đá thì đường tụt về Đường Đất.
- **Nâng cấp công trình Cơ Bản:**
  - Lệnh xây chỉ đặt **C1**. C2/C3 chỉ có được bằng cách **nâng tại chỗ**.
  - Nâng cấp trả **đủ chi phí của cấp mới** theo Data (không phải phần chênh lệch).
  - Hình của cấp mới phải chứa mọi ô của hình cũ.
- **Dỡ công trình (GDD §5.4 + Data sheet TN):**
  - Không hoàn tài nguyên. Công trình ngừng sản xuất ngay và được gỡ vào đầu lượt kế tiếp của chủ (tốn 1 vòng).
  - **TN trên mọi ô của công trình bị mất vĩnh viễn**, theo ghi chú sheet "Tài nguyên Chiến lược" của Data: "Phá dỡ công trình đã xây lên tài nguyên chiến lược sẽ làm mất tài nguyên". Luật này thay cho câu "trả về tài nguyên gốc cho tile" của GDD §5.4.
  - UI phải cảnh báo, ghi rõ TN nào sẽ mất, trước khi xác nhận.
  - Vì map không được lưu (D-011), TN đã mất được ghi trong state (`state.lostStrategic`). Mọi logic đọc TN phải đi qua hàm kiểm tra danh sách này.
  - Dỡ ngay và được hoàn tài nguyên bằng Sắc Lệnh để sang M2.
- **Trao đổi giữa người chơi (giải D-012 #8):**
  - **Không cho không:** mỗi bên đưa ít nhất 1 tài nguyên, và không loại nào nằm ở cả hai phía.
  - Chỉ người đang lượt đề xuất. Cần đường nối Khu Chợ của hai bên.
  - Người đề xuất trả phí `TRADE_FEE_PER_TILE` cho mỗi ô tuyến đường.
  - **Giữ đổi ngân hàng 4:1** (D-007), để người chơi không bị kẹt khi chưa có đường.
- **Khu Trực Thuộc:** từ M1.5, lập Sub bằng Viễn Chinh (A-02, đơn vị bị tiêu thụ), thay cho lệnh lập thẳng trên ô thực hữu của D-013. Đây là phương án tạm mà D-013 đã ghi "đơn vị để M1.5". Điều kiện đặt giữ như D-013.

**Đề xuất của dự án (dùng khi triển khai; chủ dự án chốt lại ở phase I nếu muốn đổi):**
- **Hình dạng** (offset axial, neo `(0,0)`, xoay 60°):

  | Hình | Số ô | Offset | Ghi chú |
  |---|---|---|---|
  | `pair` | 2 | (0,0)(1,0) | |
  | `triangle` | 3 | (0,0)(1,0)(0,1) | |
  | `line3` | 3 | (0,0)(1,0)(2,0) | |
  | `L` | 3 | (0,0)(1,0)(1,1) | |
  | `rect` | 4 | (0,0)(1,0)(0,1)(1,1) | hình bình hành |
  | `trapezoid` | 6 | (0,0)(1,0)(2,0)(3,0)(0,1)(1,1) | hàng 4 trên hàng 2 |
  | `cluster` | 6 | (0,0) + 5 ô kề | |

  Lưu ý: hex không có hình thang 6 ô đối xứng, nên `trapezoid` là đề xuất.
- **Luật theo footprint:**
  - Mọi ô của công trình phải là ô thực hữu của chủ, trống, đúng địa hình theo ma trận "Đặt công trình" của cấp đó, và không bị phong tỏa.
  - Công trình không sản xuất nếu **bất kỳ** ô nào của nó bị phong tỏa.
  - Phiến Quân dừng trên bất kỳ ô nào của công trình là trúng chủ của nó.
  - Mọi ô của công trình đều khóa phiếu của đối thủ.
  - Điểm C2+ tính 1 lần cho mỗi công trình.
- **Bonus TN và hiệu ứng địa hình:**
  - Bonus TN lấy từ mỗi ô có TN trong footprint.
  - Hiệu ứng địa hình (Lãnh Nguyên, Sa Mạc, Đồi Cỏ, Rừng) xét theo **ô neo** (ô C1 gốc), để không bị cộng nhiều lần.
  - TN-12: công trình tính như cả 2 viên khớp khi có ít nhất 1 viên khớp.
  - TN-10: Khu Chợ C1 sản xuất như C3.
  - TN-08: công trình C1 giảm 1 KT chi phí.
- **"Mỗi vòng" và phần lẻ:**
  - Thu nhập thụ động, upkeep đơn vị và việc hoàn tất dỡ đều chạy ở đầu lượt của chính người chơi (Khâu Sản Xuất, trước khi đổ).
  - Phần lẻ (0.5 VH của Nhà VH C3, 0.5 V của Khu Chợ C2, lãi Tín Phiếu) dồn vào `player.carry`; khi đủ 1 mới cộng vào tài nguyên.
- **Vật liệu và điểm:** vật liệu phái sinh (Hợp Kim, Giấy, Thép, Lụa, Tín Phiếu) nằm trong `player.res` nhưng **không** tính vào điểm "1 điểm / 5 tài nguyên dư". Điểm này chỉ cộng 5 loại cốt lõi như D-010.
- **Đơn vị:**
  - Không có HP/DEF (Data không định nghĩa). Trú Đóng (A-04) chỉ có hai tác dụng: PQ không được dừng ở ô kề, và ngưỡng Trấn Áp lượt sau −1.
  - Nếu mọi bước còn lại của PQ đều là ô cấm dừng thì vẫn cho đi, để PQ không kẹt.
  - Hướng đẩy khi Trấn Áp chọn trước khi đổ.
  - Upkeep tính từ Viễn Chinh thứ 2. Thiếu Vàng thì hủy đơn vị mới nhất.
- **Đường:**
  - Đường không có chủ (Data Hỏi đáp #11).
  - Vào ô có đường tốn `max(1, chi phí địa hình − 1)`. Đơn vị đứng trên Lát Đá đầu lượt được +1 bước.
  - Nâng Lát Đá được ở ô trong vùng ảnh hưởng hoặc lãnh thổ của mình.
  - Điều kiện "Khu Chợ cần đường nếu không liền HQ" chỉ kiểm lúc xây/nâng; mất đường sau đó không tắt chợ.
  - Khu Chợ C3 "giao thương bán kính 2 không cần đơn vị" được hiểu là: hai Khu Chợ trong bán kính 2 được coi như đã nối, không cần đường.
- **Phái Sinh:** theo Data, vật liệu được **cộng thêm** khi ra mặt khớp. Không theo GDD §8.2, nơi vật liệu "thay cho" tài nguyên gốc và phải chọn 1 trong 2 viên. Trạng thái "hoạt động" tính lại mỗi lần sản xuất, nên đường bị cắt thì Phái Sinh tạm ngừng.
- **Đặc Biệt:**
  - Địa hình lấy theo sheet "Công trình" của Data (xem bảng xung đột bên dưới).
  - Hiệu ứng cần thẻ hoặc nhân vật được stub và ghi log "chưa có ở bản này" cho tới M2/M3:
    - Giảm giá Công Nghệ của S-01.
    - Phụ phí, miễn nhiễm Sắc Lệnh và "Triển Lãm" của S-03.
    - "Niết Bàn" và giảm chi phí kỹ năng nhân vật của S-05.

**Còn mở (cần chủ dự án chốt, không chặn tiến độ):**
- "Bán kính Long Mạch" (S-04 +2/+3 ô, TN-12 +1 ô): GDD không định nghĩa khái niệm này. Hiện mọi công trình đều hưởng Long Mạch. Đề xuất bỏ qua.
- Sub C2 "giảm ngưỡng Chi Phối ô xa": không có số. Đề xuất không thêm, vì ngưỡng đã tính theo mốc gần nhất.
- S-04 "PQ trong bán kính 1 chỉ phong tỏa 3 ô thay vì 7": không nói là 3 ô nào.
- Ô ⭐ ưu tiên (D-010) và Đầm Lầy "TN & VH cao" vẫn chưa có số.
- Hảo Cảm, Sứ Giả U-05 và trao đổi với Khu Dân Cư có Cảng/Chợ (P0 #11): hoãn ra khỏi M1.5. A-05 Hộ Tống cũng hoãn.
- TN-04 "Chuồng Ngựa": công trình này không có trong Data, nên bonus công trình của TN-04 chưa làm.

*(Cập nhật 2026-11-01, D-020: GDD 1.6 đã trả lời phần lớn các mục trên:*
- *"Bán kính Long Mạch" và "phong tỏa 3 ô" không còn trong thiết kế, vì S-04 đã được thiết kế lại và TN-12 đổi hiệu ứng.*
- *Sub C2 bỏ dòng "giảm ngưỡng ô xa".*
- *Ô ⭐ = giảm 1 tài nguyên chính khi xây C1.*
- *Đầm Lầy có số liệu qua bảng Tài Nguyên Cơ Bản.*
- *Chuồng Ngựa, Hảo Cảm, Sứ Giả và Cảng chuyển sang Phase 2.*
- *Hình 6 ô C3 là "hình 3+3".)*

- **Tunable mới (thêm khi làm từng phase):** `HQ_UPGRADE_COST[3..5]`, `SUB_UPGRADE_COST[2..3]`, `HQ_MAX_LEVEL`, `TN06_MARKET_RATE`, `BOND_MAX`, cùng các hằng số Data §8.1 đã có (`MAX_*`, `*_BASE_MOVE`, `SUPPRESS_*`, `EXPEDITION_UPKEEP_GOLD`, `ROAD_COST_PER_TILE`, `TRADE_FEE_PER_TILE`).
- **Save:** `SAVE_VERSION = 3`. Save v2 được nâng khi nạp: công trình chuyển sang lưu theo uid, thêm `occupied`, vật liệu, `units`, `roads`, `lostStrategic`.

## D-015 — Đơn vị Viễn Chinh (M1.5 phase D) — 2026-10-07
Cụ thể hóa luật đơn vị khi Data (sheet "Các đơn vị cờ") chưa nói rõ. Mọi mục là đề xuất của dự án, chỉnh trong `constants.lua` hoặc đổi luật khi chủ dự án muốn.
- **Mua và sinh:** 3 TN + 3 V + 3 KT, chỉ ở ô Nhà Chính hoặc Khu Trực Thuộc của mình, ô không bị phong tỏa, quota `MAX_EXPEDITION_PER_PLAYER` (3). Đơn vị **không có điểm di chuyển ngay khi sinh** (Data §2: "Hành động ngay khi spawn: Không"); điểm di chuyển được cấp ở đầu lượt kế tiếp của chủ.
- **Di chuyển (A-01):**
  - Bước cơ bản 4 (`EXPEDITION_BASE_MOVE`), Dijkstra theo chi phí vào ô ở `src/data/movement.lua`. Có thể gọi `moveUnit` nhiều lần trong lượt tới hết điểm.
  - Đơn vị đi xuyên nhau, không chiếm ô, không chặn xây dựng.
  - TN-11 Gió Mạnh: vào ô có TN giảm `TN11_STEP_REFUND` (1) điểm, tối thiểu 0.
  - TN-04 Ngựa: +2 điểm đầu lượt nếu đơn vị đứng trên ô Ngựa và có HQ/Sub của chủ trong bán kính 2. Data viết "HQ trong bán kính 2" mà không nói tâm là ô nào; đây là cách hiểu.
- **Hành động dùng cả lượt (A-02, A-03, A-04):** đặt `acted = true` và `mp = 0`, nhưng được làm **sau khi đã đi** (Data §4 ghi "Toàn bộ lượt", GDD §7.2 ghi "chọn Di Chuyển hoặc Lập Sub"; cho đi trước rồi hành động để lập Sub ở đúng ô).
- **Lập Khu Trực Thuộc (A-02):** lệnh `foundSub{uid}`, thay lệnh lập thẳng của D-013 (xem D-014). Điều kiện ô giữ như D-013 (`Territory.canFoundSub`), trả `SUB_COST`, đơn vị bị tiêu thụ, UI xác nhận 2 bước.
- **Trấn Áp (A-03):**
  - Đơn vị phải kề Phiến Quân và chưa hành động. Chọn **hướng đẩy trước khi đổ** (một trong 6 ô kề Phiến Quân).
  - Ngưỡng: 4 (Hiệp Sĩ 3), −1 nếu đơn vị đứng Đồi Cỏ/Núi, −1 nếu lượt trước đã Trú Đóng, +1 nếu Phiến Quân đứng trên Núi/Núi Tuyết, sàn 2, trần 6. Các điều chỉnh khác của Data (aura Pháo Đài, Chốt Phòng Thủ, Tướng Quân) làm cùng hệ thống tương ứng.
  - Trả `SUPPRESS_GUARANTEE_FAITH` (2 TN) thì thắng chắc, không đổ.
  - **Thắng:** Phiến Quân bị đẩy tối đa 2 ô theo hướng đã chọn, dừng trước ô ngoài bản đồ hoặc Núi đang khóa (cần đẩy được ít nhất 1 ô thì mới chọn được hướng đó); người chơi +1 TN; phong tỏa bị hủy trong cả vòng hiện tại (`rebel.suppressedRound`). Đơn vị không di chuyển theo, và việc đẩy **không** kích hoạt hiệu ứng dừng của Phiến Quân.
  - **Thua:** mất đơn vị, Phiến Quân đứng yên. (Ngoại lệ Hiệp Sĩ rút về HQ làm ở phase F.)
- **Trú Đóng (A-04):** không làm được khi Phiến Quân ở kề. Từ lúc ra lệnh đến đầu lượt kế tiếp của chủ, Phiến Quân không được **dừng** trên ô đơn vị đứng hoặc ô kề nó; sang lượt sau ngưỡng Trấn Áp −1. Data nhắc HP/DEF nhưng không có số, nên chưa làm HP/DEF.
- **Cấm dừng cạnh đơn vị Trú Đóng:**
  - Người điều khiển Phiến Quân chỉ chọn được những bước còn dẫn tới một điểm dừng không bị cấm. Phiến Quân buộc phải đi tiếp khi còn bước, nên xét các điểm dừng bắt buộc.
  - Nếu mọi bước đều dẫn tới điểm dừng bị cấm thì vẫn cho đi hết, để Phiến Quân không kẹt.
- **Phiến Quân đè lên đơn vị:** dừng trên ô có đơn vị (của bất kỳ ai, kể cả người đổ) thì đơn vị bị tiêu hủy ngay, không kiểm tra. Hộ Tống (A-05) hoãn.
- **Upkeep:** từ đơn vị thứ 2 trở đi, mỗi đơn vị 1 V mỗi lượt của chủ (`EXPEDITION_UPKEEP_GOLD`), trả ở đầu lượt. Thiếu Vàng thì hủy đơn vị mới nhất (uid lớn nhất) cho tới khi trả nổi.
- **Giải Thể (A-06):** hoàn 1 V (Viễn Chinh, Hiệp Sĩ) hoặc 2 V (Giao Thương), không tốn hành động.
- **Tunable mới:** `EXPEDITION_COST`, `SUPPRESS_PUSH_TILES`, `SUPPRESS_REWARD_FAITH`, `TN04_BONUS_MOVE`, `TN04_HOME_RADIUS`, `TN11_STEP_REFUND`, `UNIT_DISBAND_REFUND`.
- **Chưa làm / còn mở:** FSM đầy đủ của Data §9 (chỉ dùng cờ `acted`, `garrison`); Hộ Tống; đơn vị không tính điểm cuối ván (Data Hỏi đáp #12); upkeep cho Giao Thương chưa định nghĩa.

## D-016 — Đường, Giao Thương, Khu Chợ, trao đổi giữa người chơi (M1.5 phase E) — 2026-10-07
Cụ thể hóa GDD §5.4, §9.2 và Data sheet Hạ tầng / Công trình. Mọi con số nằm trong `constants.lua`.
- **Đường:**
  - Lưu ở `state.roads["q,r"] = { level }` (1 = Đường Đất, 2 = Lát Đá). Đường **không có chủ** (Data Hỏi đáp #11), tồn tại vĩnh viễn cho tới khi Phiến Quân phá.
  - Chỉ xây trên Đồng Bằng, Rừng, Bờ Biển, Đồi Cỏ (`ROAD_TERRAINS`, GDD §9.2).
  - Vào ô có đường: chi phí di chuyển giảm 1, tối thiểu 1 (`ROAD_STEP_REDUCTION`). Đơn vị đầu lượt đứng trên Lát Đá được +1 bước (Data §3 viết "−1 và +1 bước/lượt, cộng dồn tối đa +2"; đây là cách hiểu đơn giản).
  - Áp dụng cho Viễn Chinh, Hiệp Sĩ và Giao Thương, không áp cho Phiến Quân (Data: "0, PQ không dùng đường").
- **Nâng Lát Đá:** lệnh `upgradeRoad{q,r}`, 1 KT + 1 V mỗi ô, ô nằm trong lãnh thổ hoặc vùng ảnh hưởng của người nâng.
- **Giao Thương (U-02):**
  - Mua 5 V, sinh ở ô thuộc một Khu Chợ của mình, chưa có chợ nào thì ở Nhà Chính. Quota 2 (riêng với Viễn Chinh). Đi ngay với đủ 5 bước.
  - **Mỗi ô đi vào mà chưa có đường (và địa hình cho phép) tự xây Đường Đất**, tốn `ROAD_COST_PER_TILE` (1 V). Thiếu Vàng cho cả quãng thì không đi được; TN-10 miễn phí đường trên ô đó và +3 bước đầu lượt đứng trên ô đó.
  - Không có "đi rồi về để hoàn tất trade" (A-07): trao đổi chỉ cần tuyến đường nối. Đơn vị Giao Thương chỉ dùng để mở đường và không bị tính upkeep (D-015).
- **Phiến Quân và đường (Data §6.2 phần Đường Đất/Lát Đá):**
  - Đi qua (không dừng): Đường Đất bị xóa, Lát Đá miễn nhiễm.
  - Dừng trên ô: Đường Đất mất, Lát Đá tụt về Đường Đất.
  - Vì vậy một lần dừng trên ô cuối của một tuyến Lát Đá đủ để cắt đường tạm thời.
- **Khu Chợ cần đường:** C1/C2 phải có ô liền Nhà Chính, hoặc nối đường tới Nhà Chính, hoặc có ô TN-03 Cá. Chỉ kiểm lúc xây hoặc nâng lên C2; mất đường về sau không tắt chợ. C3 không bị ràng buộc.
- **Khu Chợ C2:** +0.5 V mỗi vòng cho mỗi ô đường kề footprint, tối đa 3 (cách hiểu "tuyến đường nối tới").
- **Trao đổi giữa người chơi** (chốt ở D-014: không cho không, giữ ngân hàng 4:1):
  - Lệnh `proposeTrade{to, give, get}` mở `prompt` cho người nhận; người nhận trả lời `respond{accept|decline}`. Điều kiện được kiểm lại lúc chấp nhận (đường có thể đã bị phá).
  - Chỉ trao đổi 5 tài nguyên cốt lõi. Mỗi bên đưa ít nhất 1, không có loại nào ở cả hai phía, mỗi bên phải đang đủ.
  - Cần mỗi bên có một Khu Chợ không chờ dỡ, không bị phong tỏa, nối nhau bằng đường (hoặc một trong hai là C3 và khoảng cách hai chợ ≤ 2).
  - **Phí** do người đề xuất trả: số ô đường × `TRADE_FEE_PER_TILE`; toàn tuyến Lát Đá thì nhân 0.5 làm tròn lên; tuyến đi qua TN-10 miễn phí; hai chợ kề nhau miễn phí. Với đường tắt của Khu Chợ C3 phí = số ô trống giữa hai chợ. Nhiều cặp chợ thì lấy cặp rẻ nhất.
  - `Game.legal` chỉ liệt kê mẫu 1 đổi 1; `Game.check` chấp nhận mọi số lượng hợp lệ.
  - Hot-seat: người nhận phải qua màn che "Chuyền máy cho P#" trước khi thấy nội dung.
- **Đổi ngân hàng:** vẫn 4:1; nếu có Khu Chợ C2+ của mình có footprint chứa TN-06 Vàng Sa Khoáng thì 1:1 (Data, bonus công trình của TN-06).
- **Tunable mới:** `UNIT_COST`, `ROAD_TERRAINS`, `ROAD_UPGRADE_COST`, `ROAD_STEP_REDUCTION`, `STONE_ROAD_START_BONUS`, `STONE_FEE_FACTOR`, `TN10_BONUS_MOVE`, `MARKET_ROUTE_BONUS_MAX`, `MARKET_C3_RADIUS`, `TN06_MARKET_RATE`.
- **Chưa làm:** độ bền nhiều mức, sửa chữa và Đường Ray (hoãn cùng tầng công nghiệp, D-014); Hảo Cảm và trao đổi với Khu Dân Cư có Cảng/Chợ; cho không (đã loại).

## D-017 — Nhà Chính C3–C5, Khu Trực Thuộc C2–C3, Hiệp Sĩ (M1.5 phase F) — 2026-10-07
Theo Data §9.1 và sheet Đơn vị. Chi phí và mốc vòng ở `constants.lua`.
- **Nhà Chính:**

  | Cấp | Chi phí | Điều kiện | Hiệu ứng |
  |---|---|---|---|
  | C2 | 4 KT + 2 KH + 3 V | — | bán kính vùng ảnh hưởng 2 (18 ô) |
  | C3 | 6 KT + 2 Hợp Kim + 5 V | có Khu Chợ liền hoặc nối đường tới Nhà Chính | mở khóa Công Trình Đặc Biệt (phase H) |
  | C4 | 8 KT + 3 Thép + 8 V | từ vòng 11 | mọi Viễn Chinh thành Hiệp Sĩ |
  | C5 | 10 KT + 4 Thép + 4 Hợp Kim + 12 V | có Khu Chợ cấp 3 | aura +1 sản lượng mỗi viên cho công trình "nội đô" |

  - Data ghi C5 cần "Cảng/Chợ Cấp 3"; game chưa có Cảng nên chỉ tính Khu Chợ C3.
  - Bán kính ảnh hưởng không tăng thêm sau C2 (Data chỉ nâng bán kính ở C2).
  - **Chưa dùng được** C3–C5 cho tới phase G, vì Hợp Kim và Thép đến từ công trình Phái Sinh. Test và sim cấp vật liệu trực tiếp.
- **"Nội đô" của HQ C5** = công trình có ô neo trong bán kính 2 quanh Nhà Chính (`HQ_C5_AURA_RADIUS`), chỉ của chủ Nhà Chính. Hiệu ứng là modifier stage `aura` +1 mỗi viên khớp cho mọi dòng sản xuất của công trình đó.
- **Hiệp Sĩ (U-01K):**
  - Từ HQ C4, mọi Viễn Chinh của chủ đổi thành Hiệp Sĩ ngay lúc nâng cấp và ở đầu mỗi lượt sau (Viễn Chinh mới mua cũng đổi ở lượt kế tiếp). Giữ điểm di chuyển và trạng thái; dùng chung quota với Viễn Chinh; Giao Thương không đổi.
  - 6 bước, leo được Núi (tốn 2), ngưỡng Trấn Áp 3.
  - Thua Trấn Áp thì **rút về Nhà Chính** thay vì mất, tối đa 1 lần mỗi 5 vòng cho mỗi người chơi (Data §5 viết "1 lần mỗi 5 vòng", không nói theo từng Hiệp Sĩ hay từng người). Lần thứ hai trong 5 vòng thì mất như thường.
- **Khu Trực Thuộc:**
  - C2: 4 KT + 3 V, bán kính 2. C3: 6 KT + 2 Thép + 5 V, từ vòng 16, trở thành Đô Thị Vệ Tinh.
  - Lệnh `upgradeSub{q,r}`. UI: bấm vào ô Khu Trực Thuộc của mình để mở bảng nâng cấp.
  - **Ô tâm của Sub C3 miễn nhiễm phong tỏa** (không bị loại khỏi vùng phong tỏa 7 ô của Phiến Quân; ô kề vẫn bị). Ô tâm là Sub nên không có công trình; ảnh hưởng thực tế là vùng ảnh hưởng và đặt phiếu quanh tâm.
  - "Giảm ngưỡng Chi Phối ô xa" của Sub C2 (Data) vẫn chưa làm, vì không có con số (D-014 còn mở).
- **Tunable mới:** `HQ_MAX_LEVEL`, `SUB_MAX_LEVEL`, `HQ_UPGRADE_COST[3..5]`, `SUB_UPGRADE_COST`, `HQ_C4_MIN_ROUND`, `SUB_C3_MIN_ROUND`, `HQ_C5_AURA_RADIUS`, `KNIGHT_RETREAT_COOLDOWN`. Bỏ `HQ_MAX_LEVEL_M1`.
- *(Cập nhật 2026-11-01, D-020:*
  - *HQ C5 chỉ cần Khu Chợ C3, khớp GDD 1.6.*
  - *Sub C2 không có "giảm ngưỡng ô xa" (GDD và Data đều bỏ).*
  - ***Đã chốt:** theo GDD 1.6, Hiệp Sĩ tắt cho tới Phase 2; HQ C4 chỉ còn "Viễn Chinh +1 bước mỗi vòng". Code đổi ở M1.6.)*

## D-018 — Công trình Phái Sinh D-01..D-05 (M1.5 phase G) — 2026-10-07
Theo Data sheet "Công trình" (chuẩn); chỗ Data và GDD §8.2 khác nhau xem bảng xung đột bên dưới. Dữ liệu ở `src/data/derived.lua`, luật ở `src/core/derived.lua`.
- **Lập:** lệnh `buildDerived{id, a, b, q, r}` trả chi phí của loại đó. `a` = uid công trình **chủ**, `b` = uid đối tác (D-05: did của Xưởng In Ấn), `q,r` = ô riêng cho D-03 / D-05. Mỗi công trình chủ chỉ có một Phái Sinh mỗi loại.

  | ID | Chủ (cấp tối thiểu) | Đối tác | Khoảng cách | Ô riêng | Chi phí | Sản xuất |
  |---|---|---|---|---|---|---|
  | D-01 Phòng TN Vật Liệu | Trại KT C2 | Viện NC C2 | ≤ 2 | — | 3 KT + 2 KH + 2 V | +1 Hợp Kim mỗi viên KT hoặc KH; +1 mỗi 3 lượt; TN-05 trên ô chủ +1 mỗi lượt |
  | D-02 Xưởng In Ấn | Nhà VH C1 | Trại KT C2 | ≤ 1 | — | 2 VH + 2 KT + 1 V | +1 Giấy mỗi viên VH hoặc KT; +1 mỗi lượt nếu hai công trình nối bằng đường |
  | D-03 Xưởng Luyện Kim | Trại KT C3 | Đền Thờ C2 | **0 (liền kề)** | 1 ô kề Trại KT | 4 KT + 2 TN + 3 V | +1 Thép mỗi viên KT; +1 mỗi 4 lượt |
  | D-04 Xưởng Dệt Lụa | Nhà VH C2 | Đền Thờ C2 | ≤ 1 | — | 3 VH + 2 TN + 2 V | +1 Lụa mỗi viên VH hoặc TN; +1 mỗi lượt kề Khu Dân Cư; +1 nữa kề Đầm Lầy/Sông |
  | D-05 Nhà Ngân Hàng | Khu Chợ C2 | D-02 đang hoạt động | ô riêng cách chủ ≤ 2 | 1 ô | 5 V + 2 VH + 2 KT | +1 Tín Phiếu mỗi viên Vàng (tối đa 5); lãi 0.5 V mỗi Tín Phiếu mỗi lượt |

- **Khoảng cách** = số ô trống giữa hai footprint (liền kề = 0). 0 ô luôn nối được; 1–2 ô cần một tuyến đường liên tục (`Roads.route`); từ 3 ô trở lên không thể dù có đường (GDD §8.2). Mỗi loại còn có mức tối đa riêng như bảng; D-03 phải liền kề và không dùng đường.
- **Hoạt động** tính lại mỗi lần cần dùng: hai công trình còn đúng loại và đủ cấp, chưa chờ dỡ, còn nối nhau, không công trình nào bị phong tỏa. Đường bị Phiến Quân phá thì Phái Sinh tạm ngừng và hoạt động lại khi có đường. Khi công trình chủ, đối tác hoặc ô riêng biến mất thì instance bị xóa ở đầu lượt chủ (và ô riêng bị gỡ cùng).
- **Vật liệu cộng thêm, không thay thế:** theo Data, vật liệu được **cộng thêm** khi ra mặt khớp, không "thay cho tài nguyên gốc" (GDD §8.2). Long Mạch chia sẻ như công trình Cơ Bản: ai đổ cũng được, người nhận là chủ Phái Sinh. Vật liệu nằm trong `player.res`, không tính điểm cuối ván (D-014).
- **Thụ động theo chu kỳ:** bộ đếm `timer` của instance chạy mỗi lượt của chủ, chỉ khi đang hoạt động. Phần lẻ (lãi Tín Phiếu) dồn vào `player.carry` như D-014.
- **Tín Phiếu:**
  - GDD cho "chuyển 1–2 Vàng thành Tín Phiếu" và Data cho "Tín Phiếu khi ra Vàng" nhưng không có số; đây là cách hiểu: mỗi viên Vàng cộng 1 Tín Phiếu (ngoài Vàng của công trình khác), trần `BOND_MAX` = 5.
  - Lệnh `redeemBond{n}` đổi mỗi Tín Phiếu lấy `BOND_REDEEM_GOLD` (2) V, cần D-05 đang hoạt động. Cách "hoãn chi trả đến cuối vòng sau" của GDD được bỏ để đơn giản.
- **Chưa làm:** bonus "Rừng Cổ Thụ" của Xưởng In Ấn (Nhà VH không đặt được trên Rừng), "Quặng LT tỷ lệ 1:1", "Chuồng Ngựa". Các dòng "Cảng/Ngân hàng trao đổi theo tỉ lệ" cho Khu Dân Cư hoãn như D-014.
- **Save:** `state.derived`, `state.nextDerivedUid`. Save v3 tạo trước phase này được bù mặc định khi nạp (`Game.load`).
- **Tunable mới:** `DERIVED_MAX_GAP`, `BOND_MAX`, `BOND_INTEREST`, `BOND_REDEEM_GOLD`, `TN05_ALLOY_BONUS`.
- *(Cập nhật 2026-11-01, D-020: chủ dự án chốt theo GDD §8.2, thay cho "cộng thêm" ở trên:*
  - *D-01 và D-03 **thay thế** tài nguyên gốc.*
  - *D-02 và D-04 vẫn cộng thêm.*
  - *D-05 là chuyển 1–2 Vàng thành Tín Phiếu khi ra Vàng.*
  - *Code đổi ở M1.6.)*

## D-019 — Công trình Đặc Biệt S-01..S-05 (M1.5 phase H) — 2026-10-07
Dữ liệu ở `src/data/specials.lua`, aura ở `src/core/aura.lua`, luật ở `src/core/specials.lua`. Nguồn: Data sheet "Công trình" (chuẩn) và GDD §8.3.
- **Xây:** lệnh `buildSpecial{id, q, r, rot}`, cần **Nhà Chính C3** (Data §9.1), đủ vật liệu và công trình tiên quyết. Mỗi người chỉ có **một** công trình mỗi loại (đề xuất của dự án, để số lần "1 lần/ván" của S-05 rõ nghĩa).
  - **Footprint** theo hình: S-01 và S-04 `hex7` (ô giữa + 6 ô kề), S-02 `fort4` (ô giữa + 3 ô kề xen kẽ), S-03 và S-05 `triangle` (ô giữa + 2 ô kề). **Mọi ô** của hình phải là ô thực hữu của chủ, trống và không bị phong tỏa. Data viết S-01 chỉ cần "6 ô xung quanh trống"; ở đây hiểu là 6 ô đó cũng thuộc footprint nên phải là ô thực hữu của chủ (khớp S-04 "6 ô đều thực hữu").
  - **Địa hình:** theo danh sách của **ô trung tâm** trong sheet "Công trình" (S-05 gồm cả Đầm Lầy, khác sheet "Địa hình"; chọn sheet Công trình như D-013). Các ô còn lại phải xây được hoặc nằm trong danh sách; S-05 cần mọi ô cùng một loại địa hình. S-02 trên Núi cần ô trung tâm có TN-01 Đá Granite.
  - **Tiên quyết** (công trình Cơ Bản của chủ, ô neo trong bán kính quanh ô trung tâm): S-01 Viện NC C3 trong 3; S-02 Trại KT C2+ trong 2; S-03 Nhà VH C3 trong 2 và Xưởng In Ấn (D-02) đang hoạt động; S-04 Viện NC C2+ và Trại KT C2+ trong 3; S-05 Đền Thờ C3 trong 2.
  - Chi phí: bảng trong `specials.lua`. Riêng S-05 dùng **8 TN** (Data) thay vì 6 TN (GDD).
- **Nâng cấp "+1", "+2":** lệnh `upgradeSpecial{uid}`, không đổi footprint; cấp nội bộ 1..3 (cấp 1 = vừa xây). Công trình Đặc Biệt **không** nâng bằng hình mới như công trình Cơ Bản. Tính điểm như công trình C2+ ở mọi cấp.
- **Aura** (bán kính theo cấp; công trình chờ dỡ mất aura):
  - **S-01:** công trình của chủ trong bán kính +1 mỗi viên KH (modifier stage `aura`). Hiểu "khi xúc xắc ra KH nhận +1 KH" là bonus theo công trình trong vùng chứ không phải cho chủ tháp. Bán kính 2, +1 → 3.
  - **S-02:** Phiến Quân **không được dừng** trong aura (bao gồm Pháo Đài của chính người đổ; cùng cơ chế lọc bước của D-015, kèm lối thoát khi mọi bước đều bị cấm). Viễn Chinh/Hiệp Sĩ đối thủ vào ô trong aura tốn thêm 2 điểm; từ "+1" bị chặn đứng (hết điểm khi vào, không đi tiếp). Bán kính 2, +1 → 3.
  - **S-03:** phiếu Chi Phối trên ô Khu Dân Cư / Danh Thắng trong aura nhân 1.5 làm tròn lên (hệ số áp ở `Territory.votesOn`, phiếu lưu vẫn là số nguyên). Bán kính 2, +1 → 3.
  - **S-04:** khi **chủ đài** đổ, mọi công trình (kể cả của đối thủ) trong bán kính 3 có ô neo trong vùng sản xuất +1 mỗi viên khớp. "Aura Long Mạch +2 ô" và "PQ trong bán kính 1 chỉ phong tỏa 3 ô" **chưa làm** (D-014 còn mở).
  - **S-05:** hai khả năng chủ động ở mục sau. Bán kính 2.
- **Thụ động mỗi vòng** (qua `Passives`, bị phong tỏa thì mất): S-02 +1 KT; S-03 +2 VH; S-04 +1 KH +1 KT; S-05 +2 TN.
- **Khả năng chủ động:**
  - **S-01 xem trước:** hiện viên xúc xắc kế tiếp (1 viên, +2 thì 2 viên) mà không đổi RNG (`Rng:copy`). "Giữ 1 viên và đổ lại viên kia" (+2) **chưa làm**.
  - **S-02 +2 "Pháo":** `fortressStrike{uid, target}`, 1 lần mỗi 5 vòng mỗi người chơi, phá hủy **ngay** một công trình **Cơ Bản cấp 1** của đối thủ trong bán kính 3. Data ghi "−2 độ bền" (hệ độ bền thuộc tầng công nghiệp bị hoãn) nên hiểu là phá hủy theo GDD §8.3; TN trên ô mất vĩnh viễn như khi dỡ (D-014).
  - **S-02 sinh Viễn Chinh:** Viễn Chinh được mua ở ô thuộc footprint Pháo Đài; lượt đầu có +2 bước.
  - **S-03 điểm cuối ván:** +1 điểm cho mỗi Khu Dân Cư mà chủ chi phối (hơn hẳn số ô trong cụm) có ô trong bán kính 3 quanh Bảo Tàng. Hiện ở cột "Bảo Tàng" của màn kết quả.
  - **S-04 +2 "Phát Sóng":** khai báo trước khi đổ (`roll{broadcast=true}`), 1 lần mỗi 3 vòng; cả hai viên thành **mặt cao hơn** của lần đổ. Tổng chẵn nên không bao giờ ra 7; hai viên Hex cho 2 phiếu.
  - **S-05 hủy tổng 7:** khi có người đổ 7, chủ Thiên Đình còn lượt (1 lần mỗi ván, +1: 2 lần) được hỏi qua lời nhắc `cancel7`; hủy thì Phiến Quân không đi và **người đổ nhận 1 TN**. Hỏi lần lượt các chủ còn lượt, người đổ trước. Việc Phiến Quân kề không vô hiệu hóa khả năng này.
  - **S-05 đẩy Phiến Quân:** khi Phiến Quân dừng trong aura (sau khi xử lý mất tài nguyên) và chủ có ≥ 2 TN, lời nhắc `pushrebel` hỏi có trả 2 TN đẩy ra ngoài aura không. Ô đích nằm trong 2 bước quanh Phiến Quân, ngoài aura, Phiến Quân đứng được; cấp xây = **ngẫu nhiên** (chọn bằng RNG ván), từ "+1" = **chủ chọn ô**. Đẩy không kích hoạt hiệu ứng dừng mới.
- **Chưa làm, để M2/M3 hoặc chờ chốt:** giảm giá Công Nghệ (S-01), phụ phí và miễn nhiễm Sắc Lệnh, "Triển Lãm" (S-03), "Niết Bàn" và giảm chi phí kỹ năng nhân vật (S-05), bonus TN-02/TN-07/TN-11 cho Đặc Biệt, "Pháp Sư"…
- **Tunable mới:** nằm trong `src/data/specials.lua` (`STRIKE_COOLDOWN`, `STRIKE_RADIUS`, `BROADCAST_COOLDOWN`, `SCORE_SETTLEMENT_RADIUS`, bảng cấp) và `Specials.MIN_HQ_LEVEL`.
- *(Cập nhật 2026-11-01, D-020: GDD 1.6 sửa phần Đặc Biệt. Code sẽ đổi ở M1.6:*
  - *S-04 thành **Đài Khí Tượng**, hiệu ứng khác hẳn: bỏ Phát Sóng, thêm đổ lại xúc xắc.*
  - *S-05 đổi tên thành **Thiên Đàn**, chi phí 6 TN, địa hình Rừng/Núi/Sông.*
  - *S-03 đặt trên Đồng Bằng và Khu Dân Cư.*
  - *Hình S-02 và S-03 theo mã Data (4c, 3c).*
  - *S-02 thêm "đẩy Phiến Quân ra khỏi aura thì người kích hoạt mất 2 V".*
  - *S-01 thêm "thấy đường đi của Phiến Quân".)*

## D-020 — Đồng bộ GDD 1.6 và Data mới (sau playtest #1) — 2026-11-01
**Nguồn:**
- `docs/Perisol_GDD_v1.6.docx`: file gốc tên "Perisol_GDD_v1.3 (2).docx", nội dung ghi "Phiên bản GDD 1.6". Chép nguyên văn sang `Perisol_GDD_v1.6_Full.md`.
- `docs/Perisol Data.xlsx`: xuất lại toàn bộ sang `Perisol_Data.md`.
- `Perisol_GDD_v1.2_Full.md` đã xóa.
- GDD 1.6 viết sau playtest #1 (Phụ lục D). Phụ lục E đề xuất tên hằng số.

**Chủ dự án chốt:**
- **Phạm vi:** luật mới của GDD 1.6 được làm thành mốc **M1.6, trước M2** (`plan.md` P3.5).
- **Nguồn chuẩn:**
  - Khi GDD 1.6 và Data lệch nhau, **GDD 1.6 thắng**.
  - Data dùng cho số liệu mà GDD không nói tới. Ví dụ: ma trận đặt công trình ở các cột Lãnh Nguyên, Sa Mạc, Đầm Lầy (bảng §9.4 của GDD chỉ là bản trích, không có các cột này); mã hình dạng ô; bảng đơn vị.
  - Mọi chỗ lệch vẫn được liệt kê để hỏi designer.

**Đổi tên trong game** (UI và log sẽ đổi ở M1.6):

| Tên cũ | Tên mới |
|---|---|
| "Long Mạch" (cơ chế chia sẻ sản lượng) | **Sản Xuất Chung** |
| Thiên Đình Tín Ngưỡng (S-05) | **Thiên Đàn** |
| Đài Phát Thanh Long Mạch (S-04) | **Đài Khí Tượng** (Data ghi "Đài Quan Sát Khí Tượng") |
| Tháp Thiên Văn (S-01) | **Tháp Quan Sát Thiên Văn** |
| Nhà Ngân Hàng (D-05) | Data ghi "Ngân Hàng" |

**Mã hình dạng ô trong sheet "Công trình" của Data.** Lấy theo ảnh trong file xlsx. Hex đỉnh nhọn, đọc theo hàng từ trên xuống:

| Mã | Số ô | Hình (theo ảnh) | Công trình dùng (theo Data) |
|---|---|---|---|
| 3a | 3 | tam giác (2 ô trên, 1 ô dưới giữa) | B-01.2 |
| 3b | 3 | thẳng 3 ô | B-02.2, B-04.3 |
| 3c | 3 | gấp khúc (chữ L hex) | B-05.3, S-03 |
| 4a | 4 | hình bình hành 2+2 | B-03.3 |
| 4b | 4 | tam giác + 1 ô nối dài xuống dưới | — |
| 4c | 4 | hàng 3 + 1 ô dưới (ô giữa hàng có 3 ô kề) | S-02 |
| 4d | 4 | đường chéo 3 ô + 1 ô ngang | — |
| 5a | 5 | hàng 3 + hàng 2 bên dưới (hình thang) | — |
| 5b | 5 | ô giữa + 4 ô kề | — |
| 5c, 5d | 5 | khối dọc 1-2-1-1 (hai bản đối xứng) | — |
| 6a | 6 | tam giác lớn 3-2-1 | B-01.3 |
| 6b, 6c | 6 | hình bình hành 3+3 (hai chiều nghiêng) | B-02.3 |
| 6d | 6 | ô giữa + 5 ô kề | — |
| 6e, 6f | 6 | dải chéo / bậc thang | — |

- GDD §8.1 ghi **mọi** C3 chiếm 6 ô dùng "hình 3+3", nên B-01.3 dùng 6b chứ không dùng 6a như Data.
- Hình 3 và 4 ô theo Data, vì GDD chỉ mô tả bằng chữ và không mâu thuẫn.
- Code hiện tại khác Data ở các chỗ sau (sẽ sửa ở M1.6):
  - B-01.3 đang là `trapezoid`.
  - B-02.2 đang là `triangle`.
  - B-02.3 đang là `cluster`.
  - S-02 đang là `fort4`.
  - S-03 đang là `triangle`.

**Luật code hiện tại → luật GDD 1.6 (làm ở M1.6):**

| # | Chủ đề | Code hiện tại | GDD 1.6 |
|---|---|---|---|
| 1 | Số vòng | 20 vòng cố định (`ROUNDS_PER_GAME`) | N = 10 × số người (1 người 10, 2 người 20, 3 người 30, 4 người 40), tùy chỉnh theo bội của 10. Các mốc HQ C4 vòng 11, Sub C3 vòng 16 và khóa Núi 10 vòng quy đổi bằng ⌈mốc × N ÷ 20⌉ (đề xuất). Sự Kiện lật mỗi 5 vòng, mức khốc liệt ⌈4 × vòng ÷ N⌉ (§1.2, §11.3). |
| 2 | Tài Nguyên Cơ Bản trên ô | Không có | **Mới (§3.3):** mỗi ô tung xác suất cho từng loại theo bảng địa hình; lượng 1 (70%) hoặc 2 (30%). Ngoại lệ: Đầm Lầy TN và VH ra 2 với xác suất 40%; Lãnh Nguyên Vàng luôn 1; ô kề Sông +10 điểm phần trăm cho TN. Mỗi Danh Thắng gắn 1 loại. Nhả tài nguyên = lượng × số viên khớp, cho người có quyền thu hoạch (chủ ô, hoặc người duy nhất có vùng ảnh hưởng phủ ô chưa có chủ). Công trình nhiều ô thu cả nguồn này của mọi ô nó chiếm. Phong tỏa chặn. Dòng "+x khi ra x" của tài nguyên chiến lược cộng vào lượng này, kể cả khi ô không có loại đó. Hằng số `MaxKindsPerTile` (mặc định không giới hạn). |
| 3 | Lãnh thổ khởi đầu | Chỉ ô HQ là thực hữu (D-013) | **6 ô quanh HQ thực hữu miễn phí**, xây được ngay. Sub không được tặng ô; 6 ô quanh Sub phải lấy bằng phiếu hoặc mua với giá d = 1 (§7.3). |
| 4 | Tài nguyên khởi đầu | Nền 1/1/1/1/3 cộng 1 cho mỗi ô quanh HQ theo `START_BONUS_BY_TERRAIN` (D-013) | Toàn bộ Tài Nguyên Cơ Bản của 6 ô quanh HQ, nhận 1 lần (§3.3, §11.1 bước 8). |
| 5 | Mua ô | (1 V + 1 VH) × 2^(d−1), chỉ trong vùng ảnh hưởng (D-013) | **(1+d) VH + (2+d) V**, d tính từ tâm HQ/Sub gần nhất. Các hiệu ứng giảm giá áp dụng sau cùng, tối thiểu 1 VH + 1 V (§7.2). |
| 6 | Mở rộng liền kề | Không có | Được lấy (bằng phiếu hoặc mua) ô **ngoài** vùng ảnh hưởng nếu ô đó kề ô thực hữu của mình. Ngưỡng phiếu ngoài vùng +1, tức 3 ở d = 2 và 4 ở d ≥ 3 (§7.2). |
| 7 | Khu Dân Cư / Danh Thắng | 1 phiếu mỗi ô, ai nhiều ô hơn chi phối cả cụm (D-013) | Giữ luật đó. Thêm: **chỉ lấy bằng phiếu** và ô phải nằm trong vùng ảnh hưởng; không mua được; không mở rộng liền kề (§7.2). |
| 8 | Tranh lại ô đã có chủ | Phiếu ≥ 2 × ngưỡng và hơn phiếu chủ, phiếu tích lũy qua lượt; ô có công trình bị khóa (D-013) | Chỉ áp dụng cho **ô giá trị cao** (có tài nguyên chiến lược, hoặc tổng Tài Nguyên Cơ Bản ≥ 3) nằm trong vùng ảnh hưởng của người tranh. Phải đặt đủ 2 × ngưỡng **trong cùng một Khâu Hành Động** (không tích lũy). Không tranh ô HQ/Sub. **Công trình đi theo ô** sang chủ mới (§7.2, §7.4). |
| 9 | Đặt HQ / Sub | Chọn vùng khởi đầu do mapgen tạo. Sub cách HQ/Sub của mình ≥ 2, của đối thủ ≥ 3 (D-013). | Không đặt trên Núi/Sông. Vòng chu vi cấp 1 không chạm vòng chu vi của HQ/Sub khác, và không chạm Danh Thắng / Khu Dân Cư. HQ không được kề Phiến Quân. Thứ tự đi luôn bắt đầu từ P1 (§7.3, §11.1). Đầm Lầy: GDD ghi không đặt HQ/Sub, Data cho đặt Sub; theo GDD là không. |
| 10 | Phiến Quân xuất hiện | Trên Đồng Bằng / Lãnh Nguyên / Sa Mạc cách mọi HQ ≥ 2, sau khi đặt HQ (D-009) | Đặt ở ô trung tâm. Sau khi đặt HQ, nếu cách HQ nào dưới 2 bước thì dời tới ô hợp lệ gần nhất (§11.1 bước 4). |
| 11 | Phiến Quân và HQ | Được dừng trên HQ và cướp như công trình (D-009) | **Ô HQ là ô chặn:** không vào, không dừng (§6.2). |
| 12 | Phiến Quân cướp | Khi **dừng** trên công trình của người khác: chủ mất ceil(½) loại nhiều nhất, người đổ nhận ceil(½) số đó (D-009) | **Cướp phá khi bước lên** công trình của người khác, kể cả đi ngang; công trình nhiều ô chỉ cần đi qua 1 ô. Chủ mất ceil(½) loại nhiều nhất, **người điều khiển nhận toàn bộ số đó**. Mỗi công trình 1 lần mỗi vòng. Công trình của người điều khiển không bị cướp (§6.2). GDD không nói xử lý khi hòa; tạm giữ "chủ chọn". |
| 13 | Phiến Quân dừng trên ô chưa có chủ có tài nguyên cơ bản | — | Người kích hoạt nhận từ ngân hàng ceil(½) mỗi loại trên ô (§6.2). |
| 14 | Lệnh Đuổi Phiến Quân | — | Người chơi có ô thực hữu hoặc công trình nằm trong vùng phong tỏa ở đầu Khâu Sản Xuất **hơn 3 lượt liên tiếp** thì ở lượt thứ 4 được đổ 1d6 để điều khiển Phiến Quân như vừa ra 7, không mất sản xuất. Bộ đếm về 0 khi dùng xong, hoặc khi Phiến Quân rời vùng của người đó (§6.2, §6.3). |
| 15 | Sông | Đền Thờ C1–C3 xây được (Data) | **Khóa xây** cho tới khi mở khóa (đề xuất thẻ Công Nghệ Tuyến Vận Tải Nước). Sau khi mở: Đền Thờ và Thiên Đàn. Hằng số `BuildOnRiverLocked` (§3.1). |
| 16 | Ô ⭐ | Chưa có bonus (D-010) | **Giảm 1 tài nguyên chính** khi xây C1 trên ô ⭐, tối thiểu còn 1; không áp dụng khi nâng cấp (§9.4). Ô ⭐: Rừng cho Viện NC và Đền Thờ; Khu Dân Cư cho Nhà Văn Hóa và Khu Chợ C1–C2. |
| 17 | Xây trên Khu Dân Cư | Nhà Văn Hóa, Khu Chợ C1–C2 (ma trận) | Thêm **Bảo Tàng (S-03)** (§3.1, §8.3). |
| 18 | Hình 6 ô C3 | `trapezoid` / `cluster` (D-014 đề xuất) | **Hình 3+3** (mã 6b), dùng cho mọi C3 chiếm 6 ô. Phím Q đổi hướng xoay (§8.1). |
| 19 | S-04 | Đài Phát Thanh: +1 cho công trình cùng loại trong bán kính 3 khi chủ đổ; +1 KH +1 KT; Phát Sóng (D-019) | **Đài Khí Tượng:** aura bán kính 2 miễn nhiễm hiệu ứng xấu của Sự Kiện thời tiết; xem trước lá Sự Kiện kế tiếp; +1 KH +1 KT mỗi vòng; 1 lần mỗi 5 vòng được đổ lại 1 viên sau khi đổ ở lượt mình (bắt buộc dùng kết quả mới). Cấp +1: bán kính 3, chu kỳ 3 vòng. Cấp +2: 1 lần mỗi ván chọn mặt cho 1 viên (không được tạo tổng 7). Mọi ô đều phải thực hữu (Data ghi "6 ô xung quanh bất kỳ"). |
| 20 | TN-12 Địa Linh | Công trình nhận như cả 2 viên khớp (D-014) | Mỗi viên ra Hex: chủ ô được chọn thay viên đó bằng 1 loại tài nguyên mà công trình hoặc Tài Nguyên Cơ Bản trên ô sản xuất, kể cả ngoài lượt của mình (trong lượt thì Hex vẫn cho phiếu). Bonus công trình: Đài Khí Tượng giảm chu kỳ đổ lại 1 vòng (§3.4). Data vẫn ghi mô tả cũ. |
| 21 | TN-07 Đá Thiêng | +2 TN cho ô (D-008) | Thêm bonus công trình: Thiên Đàn aura +1 ô nếu đặt trên ô này; Đền Thờ +1 TN thụ động mỗi vòng (Data ghi "Đền Thờ: miễn cooldown 1v/5v") (§3.4). |
| 22 | S-01, S-02, S-03, S-05 | Theo D-019 | S-01 thêm: thấy đường đi của Phiến Quân ngay khi nó bắt đầu di chuyển; aura cộng cả cho ô có Tài Nguyên Cơ Bản KH. S-02 thêm: Phiến Quân bị đẩy ra khỏi aura thì người kích hoạt mất 2 V. S-03 đặt trên Đồng Bằng và Khu Dân Cư. S-05: 6 TN (Data ghi 8), địa hình Rừng / Núi / Sông (cần mở khóa), bỏ Đầm Lầy (§8.3). |
| 23 | Giao diện (§12.4) | — | Phân biệt rõ trạng thái ô (thực hữu tô đặc; vùng ảnh hưởng tô nhạt viền đứt; tranh chấp sọc chéo kèm phiếu/ngưỡng; ô đang chọn viền sáng khác hẳn). Hiện ngưỡng phiếu và giá mua cho mọi d. Icon nhỏ cho địa hình, Tài Nguyên Cơ Bản (kèm lượng) và tài nguyên chiến lược. Phiến Quân hiện số bước còn lại và người điều khiển, camera lia về HQ, popup −x khi cướp, nút Lệnh Đuổi. **Tự đổ xúc xắc** đầu lượt. Popup +x bay lên từ từng ô, kể cả ở lượt người khác. Cửa sổ trao đổi không tự đóng. Bảng điểm có chú thích. Nút Undo, hiện seed ở menu và F1. |

**Chủ dự án chốt thêm (2026-11-01): 4 câu mở chính theo GDD 1.6.**
1. **Tài nguyên khởi đầu** = toàn bộ Tài Nguyên Cơ Bản của 6 ô quanh HQ, nhận 1 lần (§3.3, §11.1 bước 8).
   - **Bỏ phần nền** `STARTING_RESOURCES` và bảng `START_BONUS_BY_TERRAIN` của D-013.
   - Rủi ro đầu ván thiếu tài nguyên: kiểm ở playtest #2.
2. **Danh Thắng** gắn **1 loại** Tài Nguyên Cơ Bản cố định; mọi ô của nó có lượng loại đó (§3.3).
   - Designer chưa có danh sách, nên tạm chọn ngẫu nhiên 1 loại cho mỗi Danh Thắng khi sinh map.
   - Lượng theo luật 70% ra 1, 30% ra 2.
3. **Hiệp Sĩ tắt cho tới Phase 2** (§9.1, §13.2).
   - HQ C4 chỉ còn "Viễn Chinh +1 bước mỗi vòng".
   - Code M1.5 (D-017) phải gỡ hoặc tắt Hiệp Sĩ bằng cờ, kèm migration cho save đang có Hiệp Sĩ.
4. **Phái Sinh theo đúng chữ GDD §8.2**, thay cho cách "cộng thêm" của D-018:
   - D-01: khi ra KT hoặc KH, nhận 1 Hợp Kim **thay vì** tài nguyên gốc (chọn 1 trong 2 viên).
   - D-03: nhận 1 Thép **thay 1 KT** thường.
   - D-02 và D-04: GDD chỉ ghi "sản xuất 1 Giấy" / "nhận 1 Lụa", không nói thay thế, nên giữ cộng thêm.
   - D-05: khi ra Vàng, **được chọn** chuyển 1–2 Vàng thành Tín Phiếu. Đây là chuyển đổi, không cộng thêm.
   - Việc chọn viên cần một lời nhắc cho chủ công trình. Phiên bản đầu, theo đề xuất của dự án: tự chọn viên khớp đầu tiên; thêm lời nhắc nếu playtest cần.

**Khớp hoặc được GDD 1.6 xác nhận (không đổi code):**
- Dỡ công trình mất tài nguyên chiến lược, giữ Tài Nguyên Cơ Bản (§5.4).
- Trao đổi: không cho không, không đổi cùng loại, phí 1 V/ô, giữ ngân hàng 4:1 (§5.4).
- Lãnh Nguyên được chốt là ưu đãi: xây −1 KT, Vàng −1 sản lượng.
- Phiến Quân vào Núi tốn 3 bước (D-012 #5).
- Rừng và Sông tốn 2.
- Không đi lại ô đã qua.
- HQ C3 cần Khu Chợ nối tới HQ; HQ C5 cần Khu Chợ C3.
- Sub C2 không có "giảm ngưỡng ô xa".
- Đường Đất +1 di chuyển; Lát Đá +2 và giảm 50% phí.
- Bảng điểm cuối ván giữ như D-010/D-013.

**Hoãn có chủ đích (GDD 1.6 ghi là dự thảo hoặc Phase 2):**
- §7.4 Bộ Binh chiếm công trình: 20 điểm chống trả, số lượt = ⌈20 ÷ HP⌉, Thu Phục ×2, công trình đi theo ô. Chỉ số đơn vị chưa có.
- §7.5 hệ chiến đấu (dự thảo).
- §8.4 Cảng và các địa hình Hồ / Biển.
- Danh sách Phase 2 ở §13.2: Hảo Cảm, Sứ Giả, trao đổi với Khu Dân Cư, Cảng, Chuồng Ngựa (TN-04), Chốt Phòng Thủ, Hiệp Sĩ.
- Hai đề xuất "cần test" của §3.3: công trình cộng hưởng +1 với Tài Nguyên Cơ Bản cùng loại; aura Danh Thắng +1 trong bán kính 2. Sẽ làm sau cờ bật/tắt, mặc định tắt.

**Còn mở, cần designer trả lời:**
1. ~~Tài nguyên khởi đầu có giữ phần nền cố định không?~~ **Đã chốt:** không giữ (xem khối chốt thêm).
2. Danh sách Danh Thắng và loại tài nguyên gắn với từng cái. Data ghi "bổ sung sau". **Đã chốt:** mỗi Danh Thắng 1 loại; tạm chọn ngẫu nhiên cho tới khi có danh sách.
3. Mở khóa Sông bằng gì? (Đề xuất: thẻ Tuyến Vận Tải Nước, M2.) Từ giờ tới M2 Sông bị khóa hẳn.
4. ~~Hiệp Sĩ giữ hay tắt?~~ **Đã chốt:** tắt cho tới Phase 2.
5. Viện NC C1 trên Rừng "+1 KH thụ động": Data và D-012 #9 vẫn có, nhưng GDD 1.6 không còn nhắc (Rừng chỉ còn ⭐). Bỏ hay giữ?
6. Phiến Quân cướp khi hòa "loại nhiều nhất": ai chọn? (Đề xuất: chủ chọn, như D-009.)
7. Ngưỡng ngoài vùng ảnh hưởng ở d = 1 không xảy ra; với Sub (không được tặng ô), 6 ô quanh Sub dùng ngưỡng nào? (Đề xuất: ngưỡng trong vùng, = 1.)
8. Với ván 30 và 40 vòng: điều kiện thắng nhân vật và bảng điểm có cần nhân theo N không (§11.3 ghi "cần rà lại")?
9. ~~Phái Sinh cộng thêm hay thay thế?~~ **Đã chốt:** theo GDD §8.2 (D-01, D-03 thay thế; D-02, D-04 cộng thêm; D-05 chuyển đổi).
10. **Bảng phân bổ Tài Nguyên Cơ Bản dạng 0/1/2** (ảnh designer gửi, 2026-11-01). **Chủ dự án chốt: GDD §3.3 vẫn chuẩn**; bảng này ghi lại để designer xác nhận đây là bản nháp hay bản sẽ thay §3.3.

    Mỗi ô ghi tỉ lệ % ra 0 / 1 / 2. Tung 1–100 cho mỗi loại; ví dụ 25/40/35 nghĩa là 1–25 ra 0, 26–65 ra 1, 66–100 ra 2.

    | Địa hình | Văn Hóa | Khoa Học | Kỹ Thuật | Vàng | Tín Ngưỡng | Kỳ vọng/ô |
    |---|---|---|---|---|---|---|
    | Đồng Bằng | — | — | 50/40/10 | 65/30/5 | — | 1 |
    | Rừng | — | — | 65/30/5 | — | 75/20/5 | 0,7 |
    | Núi | — | 80/15/5 | 70/25/5 | — | 75/20/5 | 0,9 |
    | Sông | 80/15/5 | — | — | 55/35/10 | — | 0,8 |
    | Bờ Biển | — | 80/15/5 | — | 25/40/35 | — | 1,35 |
    | Lãnh Nguyên | — | — | — | — | 85/12/3 | 0,18 |
    | Sa Mạc | — | — | — | 75/20/5 | 80/15/5 | 0,55 |
    | Đầm Lầy | — | 80/15/5 | — | — | — | 0,25 |
    | Đồi Cỏ | — | — | 30/40/30 | — | — | 1 |
    | Khu Dân Cư | 55/35/10 | 55/35/10 | 45/40/15 | 15/40/45 | — | 3,1 |
    | Danh Thắng | 0/20/80 | — | — | 40/45/15 | 0/20/80 | 4,35 |
    | Núi Tuyết | — | — | — | — | 88/10/2 | 0,14 |

    - Các con số kỳ vọng trong bảng tính đúng.
    - **Lệch với GDD 1.6:**
      - Cách tính khác: GDD dùng xác suất xuất hiện rồi lượng 1 (70%) / 2 (30%).
      - Loại tài nguyên theo địa hình khác hẳn. Ví dụ: Đồng Bằng mất Văn Hóa và Tín Ngưỡng; Rừng mất Khoa Học.
      - Sa Mạc có Tín Ngưỡng, nhưng §3.1 ghi Sa Mạc "không sản xuất Tín Ngưỡng".
      - Đầm Lầy chỉ có Khoa Học, nhưng §3.1 ghi "thiên về Tín Ngưỡng (45%) và Văn Hóa (40%)".
      - Danh Thắng có 3 loại, nhưng §3.3 ghi "gắn cố định 1 loại".
      - Lãnh Nguyên không có Vàng, nên ngoại lệ "Vàng luôn 1" mất ý nghĩa.
      - Không có ngoại lệ "+10% Tín Ngưỡng cạnh Sông".
    - **Hệ quả nếu dùng bảng này:** Văn Hóa chỉ còn trên Sông, Khu Dân Cư và Danh Thắng, nên 6 ô quanh HQ gần như không cho Văn Hóa. Mua ô cần 2 VH + 3 V, nên đầu ván phải đổi ngân hàng 4:1.

## Xung đột tài liệu đã phát hiện (chọn theo Data tới D-019; từ D-020 GDD 1.6 thắng)
| Chủ đề | GDD §3.1 / §8 | Data | Chọn |
|---|---|---|---|
| Đầm Lầy đặt Sub | Không | ✅ (sheet Địa hình: HQ ❌, Sub ✅) | Data |
| Đồng Bằng xây CT Đặc Biệt | GDD cho phép (X) | Sheet Địa hình ghi ❌ nhưng sheet Công trình liệt kê Đồng Bằng cho S-01/02/03/04 | Data sheet Công trình (chờ làm rõ ở M1.5) |
| Núi: Sông cho HQ | Không | Không | Khớp |
| Đồi Cỏ: CT Đặc Biệt | GDD X | ✅ | Khớp |
| Trại Khai Thác C1 trên Rừng/Bờ Biển | Đồng Bằng, Núi (§8.1) | Ma trận ✅ Rừng/Bờ Biển; sheet Công trình ❌ | Ma trận cho C1 ở M1 (D-010); C2/C3 chốt ở M1.5 |
| Sản lượng công trình | `Cấp × Cơ bản × số viên` (§5.2) | Bảng sản lượng theo cấp | Data × số viên khớp (D-008) |
| Phiến Quân cướp tài nguyên | 2 dòng tách rời, mơ hồ (§6.2) | — | Gộp: chủ mất ceil(½), người đổ nhận ceil(½) (D-009) |
| Chi phí Phiến Quân vào Núi (sau khóa) | −1 bước (= 2) (§6.2) | 3 (U-03) | Đang dùng Data. Chờ chốt (D-012 #5) |
| Phiến Quân vào Đầm Lầy | Không nhắc (= 1) (§6.2) | 2 (U-03) | Đang dùng Data |
| Đầm Lầy đặt HQ/Sub | ❌ cả hai (§3.1 bản PDF) | Sub ✅ | Data (như trên). GDD bản PDF xác nhận lại ❌ |
| Dỡ công trình trên ô có TN | "Trả về tài nguyên gốc cho tile" (§5.4) | "Phá dỡ ... sẽ làm mất tài nguyên" (sheet TN, ghi chú) | Data: TN mất vĩnh viễn, có cảnh báo (D-014, chủ dự án chốt) |
| Trao đổi "cho không" | §5.4 vừa cấm vừa cho phép | — | Không cho không, giữ ngân hàng 4:1 (D-014, chủ dự án chốt) |
| **Từ đây: GDD 1.6 ↔ Data (2026-11-01)** | **GDD 1.6** | **Data (xlsx 2026-11-01)** | **Chọn (D-020)** |
| S-04 | Đài Khí Tượng: miễn nhiễm Sự Kiện thời tiết, đổ lại xúc xắc (§8.3) | "CT cùng loại R3 +1"; sheet đơn vị vẫn ghi "Đài Long Mạch: PQ R1 phong tỏa 3 ô" | GDD |
| S-04, 6 ô quanh | Đều là ô thực hữu | "6 ô xung quanh bất kỳ" | GDD |
| TN-12 | Hex đổi thành tài nguyên của ô; Đài Khí Tượng giảm chu kỳ đổ lại (§3.4) | "Long Mạch +1 ô; CT nhận từ cả 2 viên"; "Đài QS: Phát Sóng" | GDD |
| TN-07, bonus Đền Thờ | +1 TN thụ động/vòng | "Đền Thờ: miễn cooldown 1v/5v" | GDD |
| Sông | Khóa xây tới khi mở khóa (§3.1) | Ma trận cho Đền Thờ C1–C3 | GDD |
| Đầm Lầy đặt Sub | ❌ (bảng §3.1, cột HQ/Sub) | Sub ✅ | GDD (đảo lựa chọn cũ) |
| Hình C3 của Trại Khai Thác | Hình 3+3 cho mọi C3 6 ô (§8.1) | 6a (tam giác lớn) | GDD (6b) |
| S-05 chi phí | 6 TN (§8.3) | 8 TN | GDD |
| S-05 địa hình | Rừng, Núi, Sông (mở khóa) | thêm Đầm Lầy | GDD |
| S-03 địa hình | Đồng Bằng, Khu Dân Cư | Đồng Bằng, Bờ Biển | GDD |
| Hiệp Sĩ | Phase 2; HQ C4 = Viễn Chinh +1 bước (§9.1, §13.2) | HQ C4 tự đổi Viễn Chinh thành Hiệp Sĩ | GDD (chủ dự án chốt): tắt Hiệp Sĩ ở M1.6 |
| Phân bổ Tài Nguyên Cơ Bản | §3.3: % xuất hiện + lượng 70/30, kèm ngoại lệ | Bảng 0/1/2 trong ảnh designer gửi (D-020 câu 10) | GDD (chủ dự án chốt) |
| Viện NC C1 trên Rừng | Rừng chỉ còn ⭐ | "+1 KH thụ động" | Còn mở (code đang có) |
| Trại KT / Đền Thờ / Khu Chợ trên Lãnh Nguyên, Sa Mạc, Đầm Lầy | Bảng §8.1 không liệt kê; §9.4 là bản trích không có các cột này | Ma trận có | Data (GDD không nói) |
| D-01, cách sản xuất vật liệu | "nhận Hợp Kim thay vì tài nguyên gốc (chọn 1 trong 2 viên)" (§8.2) | "1 HK khi ra KT hoặc KH" | GDD (chủ dự án chốt): D-01, D-03 thay thế; D-02, D-04 cộng thêm; D-05 chuyển đổi |
| Sản lượng Phái Sinh | Vật liệu **thay** tài nguyên gốc, chọn 1 trong 2 viên (§8.2) | Vật liệu cộng thêm khi ra mặt khớp | Data (D-014). Từ 2026-11-01 đổi theo GDD (D-020), xem dòng "D-01" bên dưới |
| Đặc Biệt: Đồng Bằng | §8.3 cho S-01/S-02/S-03/S-04 | Sheet Địa hình ❌ CT ĐB, sheet Công trình ✅ | Sheet Công trình (D-014) |
| Trại Khai Thác C2/C3 trên Rừng/Bờ Biển | §9.4: ✅ | Ma trận ✅, sheet Công trình ❌ | Ma trận cho mọi cấp (D-014, giữ theo D-010) |
