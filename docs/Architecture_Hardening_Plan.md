# Perisol — Kế hoạch chuẩn hóa kiến trúc và siết contract

Lập ngày 2026-10-12, trên commit `63abf37` (M0, M1, M1.5 đã xong; M2 chưa bắt đầu).
Trạng thái: **đã thực hiện tới commit `b2edf5d` (ghi ngày 2026-10-13).** Ba quyết định ở Giai đoạn 0 đã chốt. Các ô còn `[ ]` ở Giai đoạn 1–4 có lý do ghi ngay dưới, và danh sách tổng nằm ở cuối tài liệu (mục 11).

Tài liệu này là kế hoạch làm việc, không phải nguồn luật chơi. Luật vẫn nằm ở GDD, `Perisol_Data.md` và `Decisions.md`.

---

## 1. Mục tiêu và nguyên tắc

**Mục tiêu:** trước khi làm M2 (thẻ bài), đưa code về trạng thái mà mỗi dữ kiện và mỗi luật chỉ có một nguồn, mỗi contract có test canh giữ, và mọi thao tác dev đi qua một cửa (`make`).

**Nguyên tắc chọn việc:** kiến trúc của Perisol là hình dạng của luật chơi. Một cấu trúc chỉ được vào `src/core` khi:

- nó trùng tên với một khái niệm trong GDD: lệnh (hành động của người chơi), sự kiện (điều xảy ra, để ghi log), cửa sổ phản ứng (`prompt`), thứ tự modifier (Data §7), việc đầu lượt (`Upkeep`), aura, ID dữ liệu; hoặc
- nó gỡ một lỗi hay một trùng lặp đã đo được.

### Bộ lọc 3 câu

Mỗi hạng mục, kể cả design pattern, phải qua cả ba. Thiếu một thì hoãn.

1. **Nội dung nào cần nó?** Chỉ ra được ID cụ thể trong docs (thẻ, nhân vật, stub trong D-019) sẽ dùng tới trong milestone kế.
2. **Test nào đỏ nếu thiếu nó?** Contract không có test canh giữ thì chỉ là quy ước.
3. **Đã lặp từ 3 lần hoặc đã gây lỗi chưa?** Chưa thì viết thẳng, trích ra sau.

### Không làm trong đợt này

- Không ECS, class/kế thừa, DI container.
- Không dựng event bus hay effect registry trước khi có thẻ. `plan.md` P4 đang ghi dựng trước; đề xuất đổi thành: viết 3 thẻ mỗi loại (Tức Thì, Phản Ứng, Nội Tại) bằng các hook sẵn có (`prompt`, `Upkeep`, stage `character`/`tech`), rồi mới trích phần chung.
- Không tách `src/scenes/game.lua` theo MVC. Chỉ tách theo popup/panel khi UI thẻ bài tới.
- Không đổi tên hàng loạt vì thẩm mỹ. Code mới dùng `checkX(state, pid, …)`; code cũ đổi khi chạm tới.
- Không viết DSL luật cho các nhánh `if id ==`. Chỉ dùng hằng tên và cờ năng lực trong data khi một ID xuất hiện từ 2 chỗ.
- Không đụng 13 hằng số tầng công nghiệp chưa dùng trong `constants.lua`.

---

## 2. Hiện trạng làm căn cứ

Số liệu đo ngày 2026-10-12 trên Linux, LÖVE 11.5 và LuaJIT.

### Trước → sau

Cột "Trước" là mốc lịch sử 2026-10-12 (giữ nguyên bên dưới). Cột "Sau" đo ngày 2026-10-13 trên commit `b2edf5d`.

| Chỉ số | Trước (2026-10-12) | Sau (2026-10-13) |
|---|---|---|
| Số ca test pass | 255 (chạy bằng LÖVE) | 307 (chạy bằng `luajit`, `make test`) |
| Bản `canAfford` | 3 | 1 (`Wallet.canAfford`) |
| Chỗ ghi `.res` ngoài module chủ | 24 | 0 (`make layer`) |
| Điểm `Game.check` ném lỗi với lệnh méo | 5 | 0 (`tests/fuzz_spec.lua`) |
| Trường state sinh lười | 11 | 0 |
| File nối tay khóa ô | 10 | 1 (`src/core/hex.lua`) |
| Cặp UI lệch core về "đủ tiền" | 17 | 0 |
| Lỗi bất biến seed 5006 (2 người, rich) | Có | Hết (`make sweep N=1 BASE=5006 RICH=1`: 0 ván lỗi) |

### Cái đang giữ được

- `src/core` không gọi `love.*` hay `math.random`.
- Mọi thay đổi state đi qua `Game.check` / `Game.apply`; UI hỏi `Game.check` cho ghost và highlight.
- `love . --test`: 255 passed, 0 failed, 31 giây.
- Core chạy được bằng `luajit` thuần, không cần LÖVE: khoảng 0,2 giây mỗi ván ngẫu nhiên (1.270 lệnh/giây).
- Đã có test cho: tất định theo seed, replay từ `history`, lưu/nạp giữa ván, `legal ⊆ check`, bất biến sau mỗi lượt.

### Lỗ hổng đã đo

| Vấn đề | Bằng chứng |
|---|---|
| Seed test cố định | Spec dùng seed 1000–1029 và 100–112; `--sim` luôn bắt đầu từ seed 1 |
| Vi phạm bất biến khi đổi seed | Seed 5006, 2 người, `rich`: `ô 3,1 của P2 có 1 phiếu < ngưỡng 2` (xem D-022 bên dưới) |
| Bot thường không phủ M1.5 | 300 ván: 9/27 loại lệnh không bao giờ chạy (`foundSub`, `upgradeSub`, `proposeTrade`, `respond`, `buildDerived`, `redeemBond`, `buildSpecial`, `upgradeSpecial`, `fortressStrike`) |
| Bot `rich` chưa chạm Đặc Biệt | 30 ván seed 5000–5029: 3 lệnh Đặc Biệt vẫn bằng 0; 5,3 giây mỗi ván |
| Runner dính LÖVE | `tests/runner.lua` dùng `love.filesystem.getDirectoryItems` |
| Không có CI; lệnh dev chỉ có `.bat` | `test.bat`, `run.bat` trỏ đường dẫn Windows |
| Thứ tự đầu lượt ngầm định | Do thứ tự `require` trong `game.lua`: dỡ → upkeep đơn vị → thu nhập thụ động. `CLAUDE.md` ghi thứ tự khác |

### Dữ kiện có nhiều nguồn

| Dữ kiện | Đang nằm ở |
|---|---|
| "Đủ tiền không" | `canAfford` chép 3 bản: `core/game.lua:50`, `scenes/game.lua:89`, `dev/drive.lua:14`. UI so với giá thô trong data, core dùng `Construction.cost` |
| Ai trừ tài nguyên | Đa số ở `game.lua`; `units.lua:200`, `:334`, `:350` tự trừ/cộng |
| Khóa ô `"q,r"` | `State.key`, `Hex.key`, `key` riêng ở `game_layers.lua:25`, nối chuỗi tay ở `construction`/`passives`; regex parse ngược lặp ở 8 file |
| "Khu Chợ của tôi" | Cùng vị từ `B-05` ở `territory.lua:177`, `trade.lua:27`, `units.lua:228`, `:236` |
| ID tài nguyên chiến lược | 3/12 có tên trong `data/strategic.lua`; 7 cái khác là chuỗi rải ở 6 file core |
| Ngưỡng cấp | Số trần: HQ ≥ 4 (`game.lua:350`, `units.lua:373`), HQ ≥ 5, Chợ ≥ 3, Sub ≥ 3, đường cấp 2; thưởng hủy tổng 7 là `+1` (`game.lua:425`) |
| Vị trí Phiến Quân | Ghi ở `rebel.lua`, `units.lua:348`, `game.lua:454` |
| Hình dạng `state` | `State.new` thiếu `history`, `setupIdx`, `takenStarts`, `prompt`; `broadcastRound`, `cancel7Used`, `strikeRound` sinh lười |
| Phiên bản save | `Game.load` vá `s.derived = s.derived or {}` thay vì migration, nên "v3" chỉ nhiều hình dạng |
| Trần Tín Phiếu | Chỉ kẹp trong `Production.apply` |

---

## 3. Giai đoạn 0 — Quyết định của chủ dự án

Chặn một phần Giai đoạn 2. Giai đoạn 1 và 3 không cần chờ.

| # | Câu hỏi | Mặc định đề xuất |
|---|---|---|
| D-022 | Ô có TN-06 được chiếm bằng ngưỡng giảm; sau đó công trình trên ô bị dỡ, TN mất, ngưỡng tăng lại. Giữ ô hay xét lại chủ? | Giữ ô; đồng bộ phiếu tới ngưỡng hiện hành khi TN mất |
| D-021 | Thứ tự việc đầu lượt | Dỡ → thu nhập thụ động (kèm Phái Sinh) → upkeep đơn vị, để thu nhập lượt đó trả được upkeep |
| — | Windows còn là máy dev không? | Makefile là nguồn chính; `.bat` giữ làm shim một dòng |

- [x] Chốt D-022 và ghi vào `docs/Decisions.md` — giữ ô
- [x] Chốt D-021 và ghi vào `docs/Decisions.md` — dỡ → thụ động → upkeep
- [x] Chốt vai trò của Windows — `.bat` giữ làm shim

---

## 4. Giai đoạn 1 — Makefile là cửa giao tiếp duy nhất

Làm trước vì đây là lưới an toàn cho mọi bước sau. Người, agent và CI dùng cùng một bộ lệnh. Biến `LOVE ?= love` và `LUA ?= luajit` ghi đè được.

| Target | Việc | Ghi chú |
|---|---|---|
| `make help` | Liệt kê target | Mặc định khi gõ `make` |
| `make check` | Kiểm tra lớp + spec hành vi + golden hash + smoke sim | Cổng trước commit |
| `make test` | Chạy spec bằng `luajit` thuần | Từ đó "core không gọi `love.*`" được canh giữ tự động |
| `make test-love` | Chạy suite trong LÖVE (`--test`) | Cho phần cần LÖVE |
| `make sim N=` | Batch ván ngẫu nhiên, in thống kê | Thay nhánh `--sim` trong `main.lua` |
| `make sim-rich N=` | Batch ván nạp đầy tài nguyên | |
| `make sweep N= BASE=` | Dải seed mới mỗi lần; khi fail ghi `build/repro/<seed>.lua` | Seed 5006 phải bị bắt ở đây |
| `make repro F=` | Phát lại một ca hỏng | |
| `make cover` | Fail nếu có loại lệnh hoặc loại event không xuất hiện trong batch | |
| `make run ARGS=` | Chạy game | |
| `make shot NAME=` | Chụp màn hình | |

Việc cần làm:

- [x] `Makefile` với các target trên (có đủ `help`, `check`, `test`, `test-love`, `sim`, `sim-rich`, `sweep`, `repro`, `cover`, `run`, `shot`; thêm `layer`, `hash`, `hash-write`)
  > **Lệch:** `make cover` còn khoảng trống khai báo trong `tools/cover_gaps.lua`: 3 lệnh (`buildSpecial`, `upgradeSpecial`, `fortressStrike`) và 6 event (`fortress_strike`, `special_built`, `special_upgrade`, `broadcast`, `rebel_pushed`, `seven_cancelled`).
- [x] `tests/runner.lua`: không còn `love.filesystem`; danh sách `SPECS` khai tường minh, ca `it.love` bị bỏ qua khi không có LÖVE
- [x] `tools/sim.lua`, `tools/sweep.lua`, `tools/cover.lua` chạy bằng `luajit`; `main.lua` chỉ còn bootstrap và cờ dev của scene
- [x] `Sim.play` chế độ `rich`: ghi các lần nạp tài nguyên (`topups`) vào bản repro để phát lại được
- [x] Kiểm tra lớp trong `make check` (target `layer`): `src/core` không chứa `love.`; không ghi thẳng `state.roads` / `state.units` / vị trí Phiến Quân ngoài module chủ
- [x] `.bat` thành shim gọi cùng cờ với Makefile (giữ Windows là máy dev phụ; Makefile là nguồn chính)

**Xong khi:** `make check` xanh (đo ở mốc này), và `make sweep` với seed 5006 hiện không còn lỗi. Chưa xác minh trên máy sạch.

---

## 5. Giai đoạn 2 — Siết contract

Mỗi dòng: viết test trước, rồi mới sửa code.

| Contract | Thay đổi | Nội dung Perisol đòi hỏi | Test canh giữ |
|---|---|---|---|
| Tài nguyên | Một chỗ `canAfford` / `pay` / `gain` trong core, trần Tín Phiếu đặt ở đó; `units.lua` thôi tự trừ | Phiến Quân cướp, phụ phí Sắc Lệnh, lãi Ngân Hàng | Bảo toàn: chênh lệch tài nguyên khớp tổng event |
| Giá hiệu lực | Giá đi qua pipeline modifier như sản lượng; UI đọc cùng nguồn, bỏ `canAfford` riêng | Stub D-019: giảm giá Tech, giảm giá kỹ năng nhân vật, phụ phí Sắc Lệnh | Nút sáng khi và chỉ khi `Game.check` qua |
| State | `State.new` khai đủ mọi trường, kể cả `history`, `prompt`, cờ theo vòng của người chơi | Save/replay, multiplayer M5 | `Game.load` chạy bất biến; save hỏng bị từ chối |
| Save | Thêm trường thì tăng `SAVE_VERSION` và viết migration; bỏ kiểu vá `or {}` | M2 thêm bộ bài, tay bài vào state | Fixture save v1/v2/v3 nạp được |
| Lệnh | Fuzz lệnh méo; chỉ thêm kiểm tra ở chỗ fuzz làm vỡ | Replay và mạng nhận lệnh không tin cậy | `Game.check` không bao giờ ném lỗi |
| Chủ sở hữu ghi | `Rebel.moveTo`, `Roads.upgrade`, dùng `Units.remove` | "Phá hoại hạ tầng", thẻ dời Phiến Quân cần một điểm móc | Grep trong `make check` |
| Đầu lượt | Danh sách bước khai tường minh một chỗ theo D-021 | "Mỗi vòng" trong D-014 | Spec thứ tự |

- [x] Tài nguyên: `Wallet` (`src/core/wallet.lua`) là nơi duy nhất ghi `player.res`; `units.lua` không tự trừ tài nguyên nữa.
  > **Lệch:** test "bảo toàn tài nguyên khớp tổng event" không làm. Thay bằng: sau mỗi lệnh không tài nguyên nào âm, Tín Phiếu không vượt trần. Hiện thực trong `tests/wallet_spec.lua` (10 ván sim, kiểm qua `onCommand` của `Sim.play`). Riêng `Invariants.check` chạy sau mỗi lượt (`endTurn`) và cuối ván trong `Sim.play`.
- [ ] Giá hiệu lực: UI và core đều đọc `Game.price` (một hàm), nên phần "nguồn giá chung" đã xong.
  > **Chưa xong:** pipeline modifier cho giá chưa có, vì chưa có nội dung nào đăng ký giảm giá. Làm khi có giảm giá đầu tiên (Tech, kỹ năng nhân vật, phụ phí Sắc Lệnh).
- [x] State: `State.new` khai đủ mọi trường; `Invariants.shape` kiểm hình dạng khi nạp save.
  > **Lệch:** không có spec riêng. Contract được canh qua test save: fixture nạp xong đúng hình dạng `Game.new` (`tests/save_spec.lua`).
- [x] Save: migration v1→v4 trong `Game.load` (`MIGRATIONS`); fixture `v1`, `v2`, `v3`, `v3_thieu_truong` trong `tests/fixtures/saves` nạp được.
  > **Lệch:** còn một chỗ vá `or {}` trong migration v3→v4 (`src/core/game.lua`). Không còn trong `Game.load`.
- [x] Lệnh: `tests/fuzz_spec.lua` (lệnh méo); `Game.check` không ném lỗi.
- [x] Chủ sở hữu ghi: `Rebel.moveTo`, `Roads.build/upgrade/damage*`, `Units.spawn/remove` là điểm ghi duy nhất.
  > **Lệch:** canh bằng grep trong `make layer`, không bằng test.
- [x] Đầu lượt (cần D-021): `Upkeep.steps` khai tường minh (demolish → passives → units); `tests/upkeep_spec.lua` canh thứ tự.
- [x] Bất biến TN-06 (cần D-022): khi dỡ làm mất TN, đồng bộ phiếu với ngưỡng mới và giữ quyền sở hữu; `tests/tn06_spec.lua`.

**Xong khi:** mỗi contract có ít nhất một test đỏ khi vi phạm, và `make check` + `make sweep N=200` xanh.

---

## 6. Giai đoạn 3 — Dọn SSOT cơ học

Không đổi hành vi. `make check` và `make sweep` là lưới an toàn; state cuối của các seed mốc phải giữ nguyên.

- [x] Khóa ô: một nguồn duy nhất trong `src/core/hex.lua` (`Hex.key`, `Hex.keyQR`, `Hex.unkey`). Key riêng ở `game_layers.lua`, chỗ nối chuỗi và regex parse tay đã bỏ.
  > **Lệch:** khóa ô đặt ở `hex.lua` (module không require gì), không ở `State`. `State.key` và `State.unkey` chỉ là alias.
- [x] `Structures.marketsOf(state, pid)` (predicate `Structures.isMarket`) thay các bản chép vị từ Khu Chợ (`trade.lua`, `territory.lua`, `units.lua`).
- [x] Hằng tên cho đủ 12 TN trong `data/strategic.lua` (`Strategic.GRANITE` … `Strategic.LEY_NODE`); core không còn chuỗi `"TN-xx"`.
- [x] Hằng cho ngưỡng cấp trong `constants.lua`: `C.HQ_KNIGHT_LEVEL`, `C.HQ_AURA_LEVEL`, `C.MARKET_C3_LEVEL`, `C.SUB_C3_LEVEL`, `C.ROAD_STONE_LEVEL`, `C.SEVEN_CANCEL_FAITH`.
- [x] Sửa nhãn: `PROMPT_NAME` trong `src/scenes/game.lua` có `cancel7` và `pushrebel`.
- [x] Gộp `Game.prompts = {}` còn một dòng (`src/core/game.lua`); comment đầu `game.lua` và `state.lua` mô tả registry và trường `prompt`.

**Xong khi:** `make check` xanh, trong đó `make hash` so golden hash với fixture (đo ở mốc này).
  > **Lệch:** golden hash chạy qua `tools/hash.lua` trong `make check`, không nằm trong bộ spec.

---

## 7. Giai đoạn 4 — Đồng bộ tài liệu

- [x] `CLAUDE.md`: mục Commands trỏ về `make`; câu "không có Lua standalone" đã sửa; thứ tự upkeep đã khớp D-021; thêm mục "Contracts and tests" kèm bộ lọc 3 câu
- [x] `docs/Decisions.md`: D-021, D-022; D-020 được dùng cho quyết định GDD 1.6 trên main
- [x] `plan.md`: P4 đổi "effect registry and event bus" thành "viết 3 thẻ mỗi loại trước, trích sau"; trỏ sang tài liệu này

---

## 8. Hoãn có chủ đích

| Việc | Điều kiện kích hoạt |
|---|---|
| Đưa phần liệt kê `legal` về cạnh từng lệnh trong bảng `H` | Khi thêm lệnh đầu tiên của M2 |
| Hàng đợi `prompt` (thay ô đơn `state.prompt`) | Khi thẻ Phản Ứng đầu tiên cần lồng |
| Tách file `scenes/game.lua` theo popup/panel | Khi bắt đầu UI thẻ bài |
| Bot tham lam, bot theo trường phái, chỉ số cân bằng, quét hằng số | Sau Giai đoạn 1, song song với M2 |
| `Production.modifiers` thành instance thay vì singleton | Khi có test hoặc tính năng cần hai registry |
| Payload event thống nhất `pid`, `q`, `r` (sửa `rebel_step.to`) | Khi thẻ hoặc UI đầu tiên phải đọc event theo vị trí/người chơi một cách tổng quát |
| Gỡ `require` muộn `units.lua` trong `Rebel.stop` (`src/core/rebel.lua`) | Khi chạm lại hai module `rebel.lua` và `units.lua` |

---

## 9. Nguyên tắc test

- Test kiểm **đầu vào, kết quả và side effect**. Không kiểm cách cài đặt: cấu trúc bên trong, tên nội bộ, thứ tự nạp module, nội dung mã nguồn.
- Kiểm tra cấu trúc (lớp, ai được ghi gì) thuộc về `make layer`, không thuộc về spec.
- Không viết test để lấy coverage hay để đạt chỉ tiêu số lượng.

---

## 10. Thứ tự và phụ thuộc

```
Giai đoạn 0 (quyết định) ──┐
                           ├─→ Giai đoạn 2 (contract) ─→ Giai đoạn 3 (SSOT) ─→ Giai đoạn 4 (docs) ─→ M2
Giai đoạn 1 (Makefile) ────┘
```

Giai đoạn 1 bắt đầu được ngay. Trong Giai đoạn 2, chỉ hai mục "Đầu lượt" và "Bất biến TN-06" phải chờ quyết định.

---

## 11. Ô còn lại (đo 2026-10-13)

| Ô | Lý do chưa xong |
|---|---|
| Giai đoạn 2 — Giá hiệu lực (pipeline modifier cho giá) | Chưa có nội dung nào đăng ký giảm giá. Xem dòng "Chưa xong" ở Giai đoạn 2. |
| Xong khi Giai đoạn 1 và 2 trên máy sạch | Chưa thử trên máy sạch. `make check` và `make sweep` chạy trên máy dev hiện tại. |

---

## 12. Chuẩn contract, abstraction, API và enforcement — 2026-10-14

Áp dụng cho API hiện có. Mỗi API phải ghi: đầu vào hợp lệ và tiền điều kiện; đầu ra; ai sở hữu bảng;
phần state được sửa và thời điểm sửa; cách báo lỗi; nơi kiểm tra và ca hồi quy chứng minh hành vi.
Một interface chung không mặc nhiên cho phép thay thế mọi nghiệp vụ. Khi thêm nội dung, kiểm tra xem
nó có cùng tiền/hậu điều kiện với abstraction đang dùng trước khi đưa vào.

### 12.1. Ranh giới và cách báo lỗi

| Ranh giới | Contract | Enforcement |
|---|---|---|
| `Game.check(state, cmd)` | State do `Game.new`/`Game.load` tạo và được cập nhật qua command. Cmd là bảng dữ liệu thuần, `type` đã biết; `pid` nếu có phải đúng actor; cờ `pay`/`broadcast` là boolean. Trả `true` hoặc `false, reason`; không sửa state/RNG. | Kiểm dữ liệu thuần, envelope và handler; fuzz + `contracts_spec`. Không hứa chấp nhận state bị caller sửa tùy ý. |
| `Game.apply(state, cmd)` | Kiểm tra trước; lệnh bị từ chối không đổi state/history. Sao chép payload, handler chạy đồng bộ; chỉ ghi history sau khi handler thành công. Trả events, thêm chúng vào log. | Gọi `Game.check`, sao chép dữ liệu; test từ chối và caller sửa command sau apply. Lỗi lập trình trong handler vẫn ném lỗi, không có rollback cả command. |
| `Game.legal(state)` | Liệt kê các lựa chọn bot/UI hỗ trợ; mỗi lựa chọn phải qua `Game.check`. Không hứa liệt kê mọi lượng trao đổi hoặc mọi tổ hợp có thể nhập. | Sim kiểm lệnh trước apply, fuzz và spec. Riêng `prompt` lọc từng lựa chọn qua check để loại accept không còn hợp lệ. |
| `Game.load(text)` | File save cục bộ có version hỗ trợ. Chuyển về schema hiện tại, dựng map, kiểm shape và invariant, kiểm payload prompt. Trả state hoặc `nil, reason`. | Kiểm dữ liệu thuần, migration, `Invariants.shape/check`, `Game.validatePrompt`; fixture v1–v3 và các ca save hỏng. Không phải sandbox chạy Lua không tin cậy: serializer vẫn đọc biểu thức Lua. |
| `Game.validatePrompt(state, p)` | Người trả lời hợp lệ; options là danh sách chuỗi không trùng; phase tiếp tục hợp lệ; kind có đủ `validate/check/apply`; payload riêng do kind kiểm tra. Không sửa state. | Dùng chung khi mở, trả lời và load. Payload hợp lệ không có nghĩa mọi lựa chọn còn thực hiện được; `check` xét điều kiện hiện tại. |
| `Game.openPrompt(state, p)` | Một prompt đang chờ tại một thời điểm. Sao chép payload trước khi lưu. Payload sai hoặc đang có prompt thì lỗi trước khi đổi state. | Assert + validator chung; test giữ nguyên state khi từ chối và test save/resume. Handler `respond` đóng prompt cũ trước khi có thể mở prompt kế tiếp. |
| `Wallet.canAfford/pay/gain/take` | Ví là bảng; key thuộc Resources; số dư và lượng thay đổi là số nguyên hữu hạn không âm; Tín Phiếu không vượt trần. Key thiếu trong ví có nghĩa 0. | Validate trước khi ghi. `pay` thiếu tiền trả false và không trừ dở; đầu vào sai contract ném lỗi. Test số âm/lẻ/NaN/vô cực/sai kiểu/key lạ và hành vi thanh toán. |
| `Structures.place/upgrade/remove` | Primitive quản lý UID và chỉ mục occupied. Caller đã kiểm địa hình/quyền xây/giá. Place cần footprint không rỗng, không trùng/đè ô. Upgrade phải giữ neo và mọi ô cũ. | Preflight toàn footprint trước khi sửa occupied/UID; test từ chối không chiếm dở ô. Đây không phải phép di chuyển hoặc thu nhỏ công trình tổng quát. |
| `Modifiers` | Chuỗi biến đổi số hữu hạn theo stage đã định; chỉ floor ở cuối. Callback là hàm, nhận context chỉ đọc theo quy ước. | Guard callback/kết quả số và test thứ tự/làm tròn. Không mô hình hóa cấm hành động, thay tài nguyên, chi phí hay lựa chọn xen lượt. Không có proxy chống callback sửa context. |

### 12.2. Quyền sở hữu dữ liệu và phạm vi abstraction

- `state` thuộc ván; scene/render đọc các bảng và gửi command. Các module core nhận quyền sửa phần dữ liệu
  theo trách nhiệm đã ghi ở §5. Lua không đóng kín các bảng này.
- Command gửi vào và prompt mở mới được sao chép sâu bằng `Serialize.copy`: không chia sẻ bảng con với caller.
  Hàm này chỉ sao chép dữ liệu thuần không vòng, khóa chuỗi/số nguyên hữu hạn. Dữ liệu sai ném lỗi;
  các ranh giới nhận dữ liệu ngoài dùng `pcall` để chuyển thành lỗi có lý do.
- `Game.price` trả bảng riêng của caller. `nil` nghĩa không còn giá cho thao tác đó; không có nghĩa miễn phí.
  State/pid và tham số của kind phải hợp lệ; kind không hỗ trợ là lỗi lập trình. API mua/nâng gồm:

| kind | a | b |
|---|---|---|
| build | ID Cơ Bản | tile; bỏ trống chỉ để hỏi giá nền |
| upgrade | instance Cơ Bản | — |
| buyTile | tile | — |
| hq | — | — |
| sub | cấp muốn nâng tới | — |
| foundSub | — | — |
| unit | expedition/trade | — |
| road | — | — |
| special | ID Đặc Biệt | — |
| specialUp | instance Đặc Biệt | — |
| derived | ID Phái Sinh | — |

- Phí di chuyển, trấn áp, upkeep, giao thương thuộc module tính nghiệp vụ tương ứng; vẫn thanh toán qua Wallet.
  Pipeline giảm giá chỉ thêm khi có nội dung cần ghép nhiều hiệu ứng, không suy từ facade hiện tại.
- `Trade.checkOffer` kiểm payload tài nguyên dùng chung cho đề xuất và prompt/load. `Trade.check` bổ sung
  người tham gia, số dư và tuyến hiện tại; trả lời accept luôn kiểm lại.
- Events trả về từ apply cũng được lưu trong log: caller chỉ đọc. Events là thông báo kết quả, không có reducer
  tổng quát để replay hoặc rollback. Replay chạy command dưới cùng phiên bản luật/mapgen.
- `State.snapshot` là bản sao nông bỏ map, chỉ dùng ngay để serialize/hash; không phải snapshot độc lập để giữ và sửa.
- State.new khai các trường gốc/người chơi; optional payload như `demolishing`, `spawnBonus`, `rebel.pending`
  được module tạo entity quản lý. Shape load kiểm cấp HQ/Sub, UID cấp tiếp, bảng entity, phase/pending, xúc xắc và RNG.
- `Upkeep.steps` là thứ tự luật dỡ → thụ động → đơn vị. Thêm bước có nghĩa chọn thời điểm nghiệp vụ;
  danh sách này không hỗ trợ tự dừng chờ input.
- Schema `levels` của Phái Sinh là adapter tra cứu/hiển thị; không cấp cho Phái Sinh quyền nâng footprint như Cơ Bản.
  `state.derived` vẫn là instance quan hệ chủ/đối tác/ô riêng; `Derived.evaluate` quyết định hoạt động hiện tại.

### 12.3. Enforcement và điều kiện hoàn tất

1. **Runtime ở ranh giới:** dữ liệu bên ngoài bị từ chối có lý do; lỗi dùng sai API nội bộ fail-fast trước các phép ghi
   mà API có thể preflight. Không thêm fallback tự chữa dữ liệu ngoài migration.
2. **Test hành vi:** xác nhận đầu ra, lượng tài nguyên, tiếp tục sau load, quyền sở hữu payload và state không đổi khi từ chối.
   Test phải qua API thực, không khẳng định tên hàm hay cấu trúc cài đặt. Các test hiện có của từng luật vẫn là nguồn kiểm chứng.
3. **Lint cấu trúc:** `make layer` quét mẫu nguồn trong `src/core/*.lua`, có ngoại lệ ghi rõ bằng marker. Nó không
   theo alias (`local r = state.roads[k]`) và không chứng minh quyền ghi được đóng kín. Thêm cách ghi mới phải review
   theo ownership; không diễn giải dòng lint xanh thành bảo đảm runtime.
4. **Hồi quy tích hợp:** `make check` gồm layer, specs hành vi, golden và smoke sim. `make cover` là báo cáo tùy chọn về các command/event bot chưa kích hoạt; coverage không phải mục tiêu của test.
   `make test-love` kiểm cả Save.write/read trên filesystem LÖVE. Thay đổi contract giữ nguyên luật phải giữ golden;
   không sinh lại fixture để che lỗi. Save hợp lệ cũ phải tiếp tục chơi được; siết validation không cần đổi version nếu
   hình dạng state hợp lệ không đổi.

Khi thêm API hoặc mở rộng abstraction, cập nhật contract, enforcement và test trong cùng thay đổi. Nếu còn tiền điều kiện
chỉ được caller bảo đảm, ghi rõ thay vì tuyên bố API an toàn với mọi đầu vào.

---

## 13. Port sang luật M1.6 trên `main` — 2026-11-05

Nhánh hardening được ghép với M1.6. Luật và data từ GDD 1.6 là chuẩn; API Wallet, giá, command, prompt và save được điều chỉnh theo các luật đó.

- D-020 giữ nghĩa đồng bộ GDD 1.6; D-021 là thứ tự đầu lượt; quyết định TN-06 cũ chuyển thành D-022.
- Save hiện v5: v3→v4 thêm dữ liệu M1.6; v4→v5 chuẩn hóa schema/contract. `Game.replay` và repro giữ `rounds` tùy chỉnh.
- Prompt `reroll` và `ley` được validate khi mở, trả lời và load. Cờ vắng mặt dùng `false` nhất quán với các guard của M1.6.
- Khi TN mất, phiếu của chủ được đồng bộ tới ngưỡng hiện hành để giữ quyền sở hữu; save cũ được hòa giải sau khi dựng lại map.
- Thu nhập từ ô, cướp phá, phí Pháo Đài và chuyển Tín Phiếu đi qua Wallet.
- Xác minh theo nhóm: 370 ca `luajit` pass, 0 fail; sweep 10 ván thường và 6 ván `rich` sạch; golden hash M1.6 khớp 15/15. `test-love` không chạy được do môi trường thiếu SDL display.
- `make cover` là công cụ chẩn đoán tùy chọn, không nằm trong `make check`; coverage không phải mục tiêu test.

---

## 13. Port sang luật M1.6 trên `main` — 2026-11-05

Nhánh hardening được ghép với M1.6. Luật và dữ liệu GDD 1.6 từ `main` là chuẩn; các API Wallet, giá, command, prompt và save được port theo các luật đó.

- D-020 giữ nghĩa quyết định GDD 1.6; D-021 là thứ tự đầu lượt; quyết định TN-06 cũ được đánh lại D-022.
- Save hiện v5: v3→v4 thêm trường luật M1.6; v4→v5 chuẩn hóa schema/contract. `Game.replay` và repro giữ `rounds` tùy chỉnh.
- Prompt `reroll` và `ley` được validate cùng lúc mở, trả lời và load. Các cờ M1.6 dùng sentinel `false` nhất quán.
- Khi TN mất, phiếu chủ được đồng bộ tới ngưỡng mới để giữ quyền sở hữu; save cũ được hòa giải sau khi dựng lại map.
- Các khoản tài nguyên M1.6 (thu nhập ô, cướp phá, Pháo Đài, chuyển Tín Phiếu) đi qua Wallet.
- Xác minh theo nhóm: 370 ca luajit pass, 0 fail; sweep 10 ván thường và 6 ván rich sạch; golden hash M1.6 khớp 15/15. `test-love` không chạy được do thiếu SDL display.
- `make cover` là công cụ chẩn đoán tùy chọn; không nằm trong `make check`.
