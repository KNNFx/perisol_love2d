# Perisol — Kế hoạch chuẩn hóa kiến trúc và siết contract

Lập ngày 2026-10-12, trên commit `63abf37` (M0, M1, M1.5 đã xong; M2 chưa bắt đầu).
Trạng thái: **đề xuất, chưa thực hiện.** Ba quyết định ở Giai đoạn 0 đang chờ chủ dự án.

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

- [ ] Chốt D-020 và ghi vào `docs/Decisions.md`
- [ ] Chốt D-021 và ghi vào `docs/Decisions.md`
- [ ] Chốt vai trò của Windows

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

- [ ] `Makefile` với các target trên
- [ ] `tests/runner.lua`: thay `love.filesystem.getDirectoryItems` bằng danh sách spec không phụ thuộc LÖVE
- [ ] `tools/sim.lua`, `tools/sweep.lua`, `tools/cover.lua` chạy bằng `luajit`; `main.lua` chỉ còn bootstrap và cờ dev của scene
- [ ] `Sim.play` chế độ `rich`: ghi các lần nạp tài nguyên vào bản repro để phát lại được
- [ ] Kiểm tra lớp trong `make check`: `src/core` không chứa `love.`; không ghi thẳng `state.roads` / `state.units` / vị trí Phiến Quân ngoài module chủ (bật sau Giai đoạn 2)
- [ ] `.bat` thành shim gọi cùng cờ, hoặc bỏ theo quyết định ở Giai đoạn 0

**Xong khi:** `make check` xanh trên máy sạch, và `make sweep` tái hiện được lỗi seed 5006.

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

- [ ] Tài nguyên
- [ ] Giá hiệu lực
- [ ] State
- [ ] Save
- [ ] Lệnh
- [ ] Chủ sở hữu ghi
- [ ] Đầu lượt (cần D-021)
- [ ] Bất biến TN-06 (cần D-020)

**Xong khi:** mỗi contract có ít nhất một test đỏ khi vi phạm, và `make check` + `make sweep N=200` xanh.

---

## 6. Giai đoạn 3 — Dọn SSOT cơ học

Không đổi hành vi. `make check` và `make sweep` là lưới an toàn; state cuối của các seed mốc phải giữ nguyên.

- [ ] `State.key` và `State.unkey` duy nhất; bỏ `Hex.key` trùng, `key` riêng ở `game_layers.lua`, các chỗ nối chuỗi và regex parse tay
- [ ] `Structures.marketsOf(state, pid)` thay 4 bản chép vị từ Khu Chợ
- [ ] Hằng tên cho đủ 12 TN trong `data/strategic.lua`; core thôi dùng chuỗi `"TN-xx"`
- [ ] Hằng cho ngưỡng cấp trong `constants.lua`: HQ C4 (Hiệp Sĩ), HQ C5 (aura), Chợ C3, Sub C3, đường Lát Đá, thưởng hủy tổng 7
- [ ] Payload event thống nhất `pid`, `q`, `r` (sửa `rebel_step.to`)
- [ ] Sửa nhãn `PHASE_NAME.prompt` cho `cancel7` / `pushrebel`
- [ ] Gộp ba dòng `Game.prompts = Game.prompts or {}`; cập nhật comment đầu `game.lua` và `state.lua`

**Xong khi:** hash state cuối của bộ seed mốc không đổi so với trước giai đoạn này.

---

## 7. Giai đoạn 4 — Đồng bộ tài liệu

- [ ] `CLAUDE.md`: mục Commands trỏ về `make`; sửa câu "không có Lua standalone"; sửa thứ tự upkeep; thêm mục "Contract" ngắn kèm bộ lọc 3 câu
- [ ] `docs/Decisions.md`: D-020, D-021
- [ ] `plan.md`: P4 đổi "effect registry and event bus" thành "trích sau 3 thẻ mỗi loại"; trỏ sang tài liệu này

---

## 8. Hoãn có chủ đích

| Việc | Điều kiện kích hoạt |
|---|---|
| Đưa phần liệt kê `legal` về cạnh từng lệnh trong bảng `H` | Khi thêm lệnh đầu tiên của M2 |
| Hàng đợi `prompt` (thay ô đơn `state.prompt`) | Khi thẻ Phản Ứng đầu tiên cần lồng |
| Tách file `scenes/game.lua` theo popup/panel | Khi bắt đầu UI thẻ bài |
| Bot tham lam, bot theo trường phái, chỉ số cân bằng, quét hằng số | Sau Giai đoạn 1, song song với M2 |
| `Production.modifiers` thành instance thay vì singleton | Khi có test hoặc tính năng cần hai registry |

---

## 9. Thứ tự và phụ thuộc

```
Giai đoạn 0 (quyết định) ──┐
                           ├─→ Giai đoạn 2 (contract) ─→ Giai đoạn 3 (SSOT) ─→ Giai đoạn 4 (docs) ─→ M2
Giai đoạn 1 (Makefile) ────┘
```

Giai đoạn 1 bắt đầu được ngay. Trong Giai đoạn 2, chỉ hai mục "Đầu lượt" và "Bất biến TN-06" phải chờ quyết định.
