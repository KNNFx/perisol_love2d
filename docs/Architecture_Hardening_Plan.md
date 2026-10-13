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
| Vi phạm bất biến khi đổi seed | Seed 5006, 2 người, `rich`: `ô 3,1 của P2 có 1 phiếu < ngưỡng 2` (xem D-020 bên dưới) |
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
| D-020 | Ô có TN-06 được chiếm bằng ngưỡng giảm; sau đó công trình trên ô bị dỡ, TN mất, ngưỡng tăng lại. Giữ ô hay xét lại chủ? | Giữ ô và nới bất biến trong `Sim.invariants`; ít bất ngờ cho người chơi |
| D-021 | Thứ tự việc đầu lượt | Dỡ → thu nhập thụ động (kèm Phái Sinh) → upkeep đơn vị, để thu nhập lượt đó trả được upkeep |
| — | Windows còn là máy dev không? | Makefile là nguồn chính; `.bat` giữ làm shim một dòng |

- [x] Chốt D-020 và ghi vào `docs/Decisions.md` — giữ ô
- [x] Chốt D-021 và ghi vào `docs/Decisions.md` — dỡ → thụ động → upkeep
- [x] Chốt vai trò của Windows — `.bat` giữ làm shim

---

## 4. Giai đoạn 1 — Makefile là cửa giao tiếp duy nhất

Làm trước vì đây là lưới an toàn cho mọi bước sau. Người, agent và CI dùng cùng một bộ lệnh. Biến `LOVE ?= love` và `LUA ?= luajit` ghi đè được.

| Target | Việc | Ghi chú |
|---|---|---|
| `make help` | Liệt kê target | Mặc định khi gõ `make` |
| `make check` | Kiểm tra lớp + `test` + smoke sim + `cover` | Cổng duy nhất trước commit |
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
- [x] Bất biến TN-06 (cần D-020): `Invariants.check` nới cho ô trong `state.lostStrategic`; `tests/tn06_spec.lua`.

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
- [x] `docs/Decisions.md`: D-020, D-021 (đã có từ trước, `d5ced22`)
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
