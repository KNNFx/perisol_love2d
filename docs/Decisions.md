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

## D-012 — Đối chiếu GDD v1.2 bản đầy đủ (PDF) với M1 — 2026-10-05
*(Trạng thái 2026-10-06: các điểm #1–#7 và #9 đã xử lý ở D-013; #8, #10, #11 giữ nguyên có chủ đích.)*
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
| Chi phí Phiến Quân vào Núi (sau khóa) | −1 bước (= 2) (§6.2) | 3 (U-03) | Đang dùng Data. Chờ chốt (D-012 #5) |
| Phiến Quân vào Đầm Lầy | Không nhắc (= 1) (§6.2) | 2 (U-03) | Đang dùng Data |
| Đầm Lầy đặt HQ/Sub | ❌ cả hai (§3.1 bản PDF) | Sub ✅ | Data (như trên). GDD bản PDF xác nhận lại ❌ |
