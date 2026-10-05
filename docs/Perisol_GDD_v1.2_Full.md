PERISOL

<p align="center">戊 地</p>

# *Game Design Document*

**Thể loại** · Chiến lược lãnh thổ theo lượt
**Nền tảng** · PC (Godot 4 / C#)
**Phiên bản · 1.2 — Tài liệu lưu trữ nội bộ**

*Tài liệu này hợp nhất GDD v1.1 với các thiết kế mới: hệ thống Công Trình, Hạ Tầng, mở rộng Địa Hình & Tài Nguyên Chiến Lược, bộ thẻ hoàn chỉnh (Công Nghệ / Sắc Lệnh / Sự Kiện Tổng) và 5 nhân vật đầy đủ điều kiện thắng.*

---

## 1. Tổng quan trò chơi

### 1.1 Elevator Pitch
Perisol là game chiến lược lãnh thổ theo lượt cho 1–4 người chơi, lấy cảm hứng từ các trò chơi chiến thuật quản lý tài nguyên. Trên một bản đồ ô lưới lục giác, các phe tranh nhau kiểm soát ảnh hưởng thông qua Long Mạch — cơ chế chia sẻ sản lượng xúc xắc — trong khi mở rộng lãnh thổ, xây dựng công trình và dùng Sắc Lệnh bí mật để lật ngược cục diện.

### 1.2 Thông tin dự án
| Trường | Nội dung |
|---|---|
| Tên dự án | Perisol |
| Thể loại | Turn-based, strategy |
| Số người chơi | 1 – 4 (có chế độ chơi đơn và nhiều người chơi) |
| Thời gian ván | 25 – 45 phút (mặc định 20 vòng chơi) |
| Nền tảng | PC — Love2D, Lua |
| Trạng thái | Pre-production — hệ thống thẻ bài & công trình đã có thiết kế đầy đủ, chờ playtesting cân bằng |
| Phiên bản GDD | 1.2 |

### 1.3 Mục tiêu thiết kế
- Bản đồ sinh ngẫu nhiên mỗi ván — người chơi đọc được địa thế, lập kế hoạch. Mọi địa hình đều mang ý nghĩa chiến lược: núi chặn đường đi nhưng cho điểm Kỹ Thuật và Khoa Học; Sông không thể xây nhưng tạo biên tự nhiên và tăng giá trị tín ngưỡng ô xung quanh; danh thắng là điểm nóng tranh chấp.
- Rủi ro có cấu trúc — xúc xắc tạo biến động nhưng người chơi có nhiều công cụ để giảm thiểu hoặc tận dụng. Phiến Quân là mối đe dọa nhưng người thông minh biến nó thành vũ khí nhắm vào đối thủ. Thẻ Sắc Lệnh là lớp kiểm soát thứ hai.
- Mỗi lượt đều có sức nặng. Không có lượt "đợi cho xong". Hiệu ứng Long Mạch đảm bảo mọi người đều tham gia vào kết quả xúc xắc — dù không phải lượt của mình.

### 1.4 Tham chiếu
| Yếu tố | Tham chiếu |
|---|---|
| Cơ chế lục giác | Catan (hex map, resource production) |
| Vòng lượt động | Agricola (mọi hành động đều có chi phí cơ hội) |
| Lãnh thổ tầng lớp | Twilight Imperium (influence vs ownership) |
| Xúc xắc định nghĩa | King of Tokyo (custom dice faces) |
| Phong thủy / chủ đề | Original IP — không có tham chiếu trực tiếp |

## 2. Thế giới & Chủ đề

### 2.1 Bối cảnh
"Long Mạch" trong phong thủy là những đường khí thiêng chạy dọc theo địa thế núi sông, quyết định vận số của đất đai và con người sống trên đó. Trong game, Long Mạch được thể hiện như một cơ chế chia sẻ tài nguyên: khi một phe khai thác một vùng đất, năng lượng của đất lan truyền theo các tuyến địa hình, vô tình (hoặc cố ý) nuôi dưỡng cả những phe kiểm soát vùng đất lân cận.

Năm phe không được đặt tên cụ thể — họ là những thế lực mang màu sắc văn hóa trừu tượng, cạnh tranh để thiết lập trụ sở trên vùng đất có long mạch mạnh nhất và bành trướng ảnh hưởng trước khi đối thủ kịp ổn định.

### 2.2 Tone
| Chiều | Hướng tới | Tránh |
|---|---|---|
| Hình ảnh | Hoạt hình, 2D top-down | Tả thực, màu quá u tối |
| Âm thanh | Nhạc tiết tấu vui tươi, hơi nhanh | OST hành động ồn ào |
| Cảm xúc | Tập trung, cân nhắc, thưởng thức | Căng thẳng nhịp độ cao |
| Độ phức tạp | Trung bình — học được trong 1 ván | Cần rulebook 20 trang để bắt đầu |

## 3. Thành phần & Không gian chơi

### 3.1 Bản đồ lục giác
Kích thước bản đồ đảm bảo mỗi người chơi có bán kính 3 ô từ tâm ra, đảm bảo an toàn (không bị người chơi khác lấn sớm) với tổng 19 ô (tính HQ). Mỗi ván phải đảm bảo đủ 7 kiểu địa hình được rút ra từ bộ 12 loại địa hình đã thiết kế (xem bảng dưới).

Mặc định tỉ lệ map 16:8; bản đồ cơ bản cho 4 người chơi đảm bảo 32:16 tile.

> **Cập nhật v1.2**
> Bộ địa hình mở rộng từ 7 lên 12 loại (bổ sung Lãnh Nguyên, Sa Mạc, Đầm Lầy, Đồi Cỏ, Núi Tuyết) để tăng biến thiên giữa các ván. Luật "mỗi ván đủ 7 kiểu địa hình" vẫn giữ nguyên — 7 loại được rút ngẫu nhiên từ bộ 12.

| ID | Địa hình | HQ/Sub | Công trình | CT Đặc Biệt | Di chuyển | Ghi chú |
|---|---|---|---|---|---|---|
| DH-01 | Đồng Bằng | ✅ | ✅ | ❌ | Bình thường | Tile cơ bản, không penalty |
| DH-02 | Rừng | ✅ | ✅ | ✅ | −1 bước | Đền Thờ, Nhà Văn Hóa ưu tiên; Viện NC C1 +1 KH thụ động |
| DH-03 | Núi | ❌ | ❌ | ✅ | Không đi được | Chỉ CT Đặc Biệt & Pháo Đài; không đặt HQ/Sub |
| DH-04 | Sông | ❌ | ❌ | ✅ | −1 bước | Đền Thờ, Xưởng Dệt Lụa được xây; không đặt HQ/Sub |
| DH-05 | Bờ Biển | ✅ | ✅ | ✅ | Bình thường | Khu Chợ Cấp 3 miễn Đơn Vị Giao Thương |
| DH-06 | Lãnh Nguyên | ✅ | ✅ | ❌ | Bình thường | Vàng −1 sản lượng; xây công trình −1 Kỹ Thuật |
| DH-07 | Sa Mạc | ✅ | ✅ | ❌ | Bình thường | Không sản xuất Tín Ngưỡng |
| DH-08 | Đầm Lầy | ❌ | ✅ | ❌ | −1 bước | Không đặt HQ; Tín Ngưỡng & Văn Hóa cao |
| DH-09 | Đồi Cỏ | ✅ | ✅ | ✅ | Bình thường | Trại Khai Thác Cấp 2 +1 Kỹ Thuật |
| DH-10 | Khu Dân Cư | ❌ | ❌ | ❌ | Bình thường | Chỉ Chi Phối; cho điểm cuối ván; cụm 2–10 tile, >7 thành Thành Bang Tự Do |
| DH-11 | Danh Thắng | ❌ | ❌ | ❌ | Bình thường | Chỉ Chi Phối; 3 điểm cuối ván; 4 kiểu hình (đơn/tam giác/tứ giác) |
| DH-12 | Núi Tuyết | ❌ | ❌ | ✅ | Không đi được | Hoạt động như Núi |

Khu Dân Cư Tự Do và Danh Thắng: số lượng khu dân cư và số danh thắng trên bản đồ đều bằng số người chơi + 1. Cả hai loại tile này chỉ cho phép Chi Phối (không xây dựng).

### 3.2 Tài nguyên chiến lược (bonus theo tile)
Ngoài loại địa hình, mỗi tile có thể mang một Tài Nguyên Chiến Lược — một lớp bonus hiếm không cần sở hữu để hưởng bonus ô, nhưng cần sở hữu để hưởng bonus công trình. Đây là lớp thiết kế mới bổ sung trong v1.2, làm phong phú giá trị chiến lược của từng ô đất.

| ID | Tên | Rarity | Địa hình xuất hiện | Bonus ô (không cần sở hữu) | Bonus công trình (cần sở hữu) |
|---|---|---|---|---|---|
| TN-01 | Đá Granite | Phổ biến | Núi, Đồi Cỏ | Tile +1 Kỹ Thuật bổ sung khi xúc xắc ra KT | Pháo Đài: −2 Kỹ Thuật chi phí xây |
| TN-02 | Rừng Cổ Thụ | Phổ biến | Rừng | +1 Tín Ngưỡng và +1 Khoa Học thụ động/vòng | Thiên Đình: bỏ yêu cầu địa hình Rừng |
| TN-03 | Cá | Phổ biến | Bờ Biển, Sông | Khu Chợ +2 Vàng khi ra Vàng; kết nối HQ ảo | Khu Chợ: không cần Đường Đất đến HQ |
| TN-04 | Ngựa | Không phổ biến | Đồng Bằng, Đồi Cỏ, Tundra | Viễn Chinh +2 bước nếu HQ trong bán kính 2 | Chuồng Ngựa: −2 Tín Ngưỡng chi phí Viễn Chinh |
| TN-05 | Quặng Lộ Thiên | Không phổ biến | Núi, Đồi Cỏ, Đồng Bằng | Tile +2 Kỹ Thuật khi ra KT; Hợp Kim tỷ lệ 1:1 | Phòng TN Vật Liệu: +1 Hợp Kim thụ động/vòng |
| TN-06 | Vàng Sa Khoáng | Hiếm | Sông, Bờ Biển, Đồng Bằng | Tile +3 Vàng khi ra Vàng; Chi Phối −1 ngưỡng | Khu Chợ Cấp 2+: tỷ lệ đổi 1:1 mọi tài nguyên |
| TN-07 | Đá Thiêng | Hiếm | Núi, Rừng, Đồi Cỏ | Tile +2 Tín Ngưỡng khi ra TN; Đền Thờ miễn cooldown 1 lần/5 vòng | Thiên Đình: aura +1 ô nếu đặt trên tile này |
| TN-08 | Đất Màu Mỡ | Phổ biến | Đồng Bằng, Đồi Cỏ | +1 sản lượng cơ bản cho mọi công trình trên tile | Công trình Cấp 1 trên tile: −1 Kỹ Thuật chi phí xây |
| TN-09 | Suối Nước Nóng | Hiếm | Núi, Đồi Cỏ, Đồng Bằng | Tile liền kề: +1 Văn Hóa thụ động/vòng, không cần công trình | Đền Thờ Cấp 2+ kề: aura +1 Tín Ngưỡng bán kính 1 |
| TN-10 | Cảng Tự Nhiên | Không phổ biến | Bờ Biển | Giao Thương miễn phí Vàng/tile; Đơn vị +3 bước | Khu Chợ Cấp 1 hoạt động như Cấp 3 khi trên tile này |
| TN-11 | Gió Mạnh | Không phổ biến | Bờ Biển, Đồng Bằng, Tundra | Viễn Chinh +1 bước qua tile; Phiến Quân +2 bước ngẫu nhiên | Tháp Thiên Văn kề: aura +1 ô |
| TN-12 | Địa Linh | Rất hiếm | Bất kỳ (1–2 tile/ván) | Long Mạch +1 ô; công trình nhận sản lượng từ cả 2 viên xúc xắc | Đài Long Mạch: "Phát Sóng Toàn Cầu" 2 lần/3 vòng |

Ghi chú thiết kế: các tài nguyên chiến lược không cần sở hữu để nhận bonus ô — với loại bonus "di chuyển", người chơi cũng không cần sở hữu tile. Phá dỡ công trình đã xây trên tài nguyên chiến lược sẽ làm mất tài nguyên và người chơi nhận thông báo về thay đổi này.

### 3.3 Tài nguyên cốt lõi
Có 5 loại tài nguyên cốt lõi, mỗi loại phục vụ mục đích riêng biệt trong vòng kinh tế của game. Không có loại nào là "tốt nhất" — sức mạnh của từng loại thay đổi tùy theo chiến lược và trạng thái ván.

| Tài nguyên | Mặt xúc xắc | Dùng chủ yếu để |
|---|---|---|
| Khoa Học | Science | Nghiên cứu Công Nghệ, xây công trình |
| Văn Hóa | Culture | Mua Sắc Lệnh, ảnh hưởng ngoại giao |
| Kỹ Thuật | Engineering | Xây dựng và nâng cấp công trình |
| Tín Ngưỡng | Faith | Kỹ năng nhân vật, hóa giải Phiến Quân |
| Vàng | Gold | Trao đổi đa năng, mua hầu hết thứ |

Chiến thuật trọng tâm của 5 chỉ số:
- Vàng (Động cơ Tài nguyên): tích lũy sự giàu có để thao túng thị trường, mua đứt công trình, nghiên cứu công nghệ đắt giá nhất, trở thành trung tâm giao thương.
- Khoa Học (Khai phá Tiềm năng): nhiên liệu chính để nâng cấp cây công nghệ nhanh chóng, mở khóa đặc quyền sớm.
- Kỹ Thuật (Kiểm soát Không gian): tối ưu hóa hạ tầng trên hex, bành trướng lãnh thổ, xây và nâng cấp công trình.
- Văn Hóa (Quyền lực Mềm & Xâm lấn): vũ khí ngoại giao, lan tỏa ảnh hưởng qua biên giới, mua Sắc Lệnh.
- Tín Ngưỡng (Đột biến & Phá vỡ Quy tắc): can thiệp luật lệ, chống chịu thảm họa, kích hoạt kỹ năng nhân vật và hóa giải Phiến Quân.

> **Cập nhật v1.2 — tài nguyên công nghiệp phụ trợ**
> Hệ thống Hạ Tầng (mục 9) giới thiệu hai tài nguyên phụ mới — Than và Dầu Mỏ — khai thác từ Mỏ Than / Giếng Dầu để phục vụ luyện Thép và Đường Ray Xe Lửa. Đây là tài nguyên công nghiệp phụ trợ, quy đổi được sang tài nguyên cốt lõi, không thay thế 5 loại chính.

### 3.4 Xúc xắc
Hai viên xúc xắc, mỗi viên 6 mặt: 5 mặt tài nguyên (một mặt mỗi loại) + 1 mặt Hex trống. Mặt Hex trống luôn là mặt nút; các nút còn lại không mang nhiều ý nghĩa ngoài combat. Ký hiệu các mặt: Khoa Học (1), Văn Hóa (2), Kỹ Thuật (3), Tín Ngưỡng (4), Vàng (5), Hex (6).

> **Lưu ý thiết kế**
> Mặt Hex trống (⬡) không sản xuất tài nguyên trực tiếp, nhưng cung cấp lợi thế khác (tuyên bố lãnh thổ, rút thẻ). Tỉ lệ 5:1 có thể điều chỉnh trong playtesting.

### 3.5 Thẻ bài
Bốn bộ thẻ riêng biệt, mỗi bộ có cơ chế và thời điểm sử dụng khác nhau. Số lượng đã được chốt trong bản thiết kế bộ thẻ v1.2 (xem mục 10 và tài liệu Perisol_Cards_v1.2 để có danh sách đầy đủ 80 thẻ).

| Bộ thẻ | Số lượng (chốt) | Ai giữ | Khi nào dùng |
|---|---|---|---|
| Công Nghệ | 30 lá (5 trường phái × 6) | Người chơi | Mua bằng tài nguyên, dùng khi đủ điều kiện; mỗi thẻ 3 cấp nâng |
| Sắc Lệnh | 30 lá (10 Tức Thì / 10 Phản Ứng / 10 Nội Tại) | Bí mật cá nhân; đối thủ biết số lượng, không biết nội dung | Khâu Hành Động, Khâu Giải Quyết, hoặc phản ứng |
| Sự Kiện Tổng | 20 lá (4 mốc × 5 lá) | Chồng bài chung | Tự động — mỗi 5 vòng lật 1 lá (vòng 5/10/15/20) |
| Kỹ Năng | 5 nhân vật × kỹ năng gốc + 4 điều kiện thắng riêng | Gắn với nhân vật | Kỹ năng bị động hoặc kích hoạt |

## 4. Nhân vật

### 4.1 Vai trò nhân vật
Mỗi người chơi chọn một nhân vật trước khi bắt đầu ván (từ pool 3 nhân vật được rút ngẫu nhiên trong Khâu Thiết Lập). Nhân vật không thay đổi chiến lược một cách áp đặt, mà mở ra một lộ trình chơi ưu thế — người chơi vẫn tự do đi theo hướng khác, nhưng sẽ không tối ưu bằng. Mỗi nhân vật có 1 kỹ năng gốc bị động và 4 Điều Kiện Thắng riêng biệt gắn với bản chất phe của họ.

### 4.2 Roster nhân vật (v1.2 — đầy đủ 5 nhân vật)

> **Trạng thái thiết kế**
> So với v1.1 (4 nhân vật placeholder chờ art/concept), v1.2 chốt roster ở 5 nhân vật với kỹ năng gốc và 4 điều kiện thắng riêng biệt mỗi nhân vật, đã sẵn sàng cho playtesting cân bằng. Số nhân vật có thể mở rộng thêm 6–8 trong tương lai để tăng tính chơi lại.

#### 1. Địa Sư (The Geomancer)
**Màu sắc phe:** Vàng

**Bản chất phe:** Bậc thầy phong thủy & địa lý. Tập trung kiểm soát Long Mạch tự nhiên, thâu tóm các Danh thắng và kết nối long mạch đất đai.

**Kỹ năng gốc:** Tuyên bố 1 tile không cần đổ ra mặt Hex (⬡) mỗi 3 vòng.

**4 Điều kiện thắng:**

| Điều kiện | Mô tả |
|---|---|
| Đại Long Mạch (The Great Leyline) | Kiểm soát chuỗi Lãnh thổ thực hữu liền mạch dài tối thiểu 12 tile nối thông suốt giữa hai đầu bản đồ hoặc đi qua trung tâm. |
| Tứ Tuyệt Danh Thắng (Scenic Dominance) | Chi phối hoàn toàn từ 3 Danh thắng trở lên trên bản đồ cùng một lúc. |
| Phong Thủy Trấn Trạch (Hex Supremacy) | Sở hữu từ 15 tile Lãnh thổ thực hữu trở lên, trong đó có ít nhất 3 công trình Cấp 3 trên các địa hình đặc trưng (Núi/Sông/Rừng). |
| Thánh Địa Tối Thượng (Sanctuary of Earth) | Nâng cấp Nhà Chính (HQ) lên Cấp 5 tối đa và kích hoạt thành công 2 Thánh Địa không bị phong tỏa bởi Phiến Quân. |

#### 2. Thương Nhân (The Merchant)
**Màu sắc phe:** Xanh dương

**Bản chất phe:** Nhà tài phiệt & thao túng dòng tiền. Tối ưu hóa mạng lưới giao thương, bòn rút phí thông quan và kiểm soát thị trường các Thành Bang Tự Do.

**Kỹ năng gốc:** Đơn vị giao thương di chuyển nhanh hơn (+bước); giảm chi phí Vàng tiêu hao khi xây/di chuyển trên đường.

**4 Điều kiện thắng:**

| Điều kiện | Mô tả |
|---|---|
| Độc Quyền Giao Thương (Trade Monopoly) | Thiết lập mạng lưới đường giao thương kết nối HQ của mình tới toàn bộ Khu Dân Cư / Thành Bang Tự Do trên bản đồ. |
| Kho Bạc Đế Vương (Golden Vault) | Trữ đạt mốc 30 Vàng trong kho mà không bị âm tài nguyên ở bất kỳ vòng nào trong 3 vòng liên tiếp. |
| Bá Chủ Thị Trường (Commercial Nexus) | Xây dựng và vận hành thành công 4 Cảng/Chợ thương mại; thu tối thiểu 10 Vàng tiền thuế/phí giao thương từ đối thủ. |
| Mua Đứt Bản Đồ (Buyout Victory) | Bỏ Vàng và Văn Hóa để mua đứt quyền sở hữu vĩnh viễn 8 tile trực thuộc phạm vi ảnh hưởng của các đối thủ khác. |

#### 3. Pháp Sư (The Arcanist)
**Màu sắc phe:** Xanh lá

**Bản chất phe:** Bậc thầy tâm linh & thao túng luật chơi. Sử dụng Sắc Lệnh bí mật, Cây Công Nghệ và Tín Ngưỡng để thay đổi cục diện ván cờ.

**Kỹ năng gốc:** Rút thêm 1 thẻ Sắc Lệnh miễn phí mỗi khi mua thẻ.

**4 Điều kiện thắng:**

| Điều kiện | Mô tả |
|---|---|
| Thiên Mệnh Chi Đạo (Grand Decree Combo) | Kích hoạt thành công chuỗi 5 thẻ Sắc Lệnh (thuộc cả 3 nhóm Tức Thì, Phản Ứng và Nội Tại) trong cùng một ván đấu. |
| Đỉnh Cao Tri Thức (Technological Singularity) | Nghiên cứu mở khóa và nâng cấp tối đa (Cấp 3) toàn bộ 5 thẻ Công Nghệ đang kích hoạt trên bảng cá nhân. |
| Phổ Độ Chúng Sinh (Faith Ascendance) | Tích lũy đạt 20 Tín Ngưỡng và chi phối hoàn toàn toàn bộ các ô Sông liền kề các Thành Bang Tự Do. |
| Bẻ Cong Luật Pháp (Event Sovereign) | Dùng Sắc Lệnh/Kỹ năng can thiệp hoặc miễn nhiễm thành công 3 kỳ Sự Kiện Tổng liên tiếp (ở các mốc vòng 5, 10, 15). |

#### 4. Tướng Quân (The Warlord)
**Màu sắc phe:** Đỏ

**Bản chất phe:** Thế lực quân phiệt & chiến lược vùng cấm. Thao túng Phiến Quân, triển khai Đơn vị Viễn Chinh và phong tỏa bóp nghẹt tài nguyên đối phương.

**Kỹ năng gốc:** Có khả năng trực tiếp điều khiển/di dời Phiến Quân mà không cần đổ xúc xắc ra tổng số 7.

**4 Điều kiện thắng:**

| Điều kiện | Mô tả |
|---|---|
| Bao Vây Tiêu Diệt (Iron Blockade) | Dùng Phiến Quân hoặc Đơn vị Viễn Chinh phong tỏa hoàn toàn Vùng ảnh hưởng của ít nhất 2 HQ đối thủ trong 2 vòng liên tiếp. |
| Bình Định Loạn Quân (Subjugation) | Dùng Đơn vị Viễn Chinh hoặc kỹ năng tiêu diệt/hóa giải Phiến Quân 4 lần, đồng thời xây 3 Chốt Phòng Thủ trên biên giới. |
| Thôn Tính Thành Bang (Subjugate Free States) | Chi phối bằng Đơn vị Viễn Chinh trên toàn bộ các Khu Dân Cư Tự Do / Thành Bang có mặt trên bản đồ. |
| Chiến Tranh Tiêu Hao (Economic Strangulation) | Khiến các đối thủ mất tổng cộng 20 tài nguyên/vàng thông qua các đợt cướp phá của Phiến Quân do mình điều hướng. |

#### 5. Học Sĩ (The Scholar / Bác Học) — MỚI trong v1.2
**Màu sắc phe:** Chưa định

**Bản chất phe:** Nhà phát minh, tri thức & nghiên cứu công nghệ. Tập trung tối ưu hóa nhánh Khoa Học, tăng tốc độ mở khóa Cây Công Nghệ và tối ưu hóa hệ thống Long Mạch để thu tài nguyên vượt trội từ xúc xắc của đối thủ.

**Kỹ năng gốc:** Tư Duy Đột Phá: giảm 1 Khoa Học khi mua bất kỳ thẻ Công Nghệ nào. Mỗi khi một người chơi khác kích hoạt thành công một Sự Kiện Tổng, Học Sĩ nhận ngay 1 Khoa Học miễn phí.

**4 Điều kiện thắng:**

| Điều kiện | Mô tả |
|---|---|
| Kỷ Nguyên Khai Sáng (The Age of Enlightenment) | Mở khóa thành công 6 thẻ Công Nghệ khác nhau và nâng cấp ít nhất 3 thẻ lên Cấp 3 (Cấp tối đa). |
| Kỳ Quan Tri Thức (The Great Observatory) | Xây dựng và duy trì thành công một công trình Khoa Học Cấp 3 trên một ô Núi hoặc Danh Thắng trong 3 vòng liên tiếp mà không bị Phiến Quân phong tỏa. |
| Cộng Hưởng Long Mạch Tuyệt Đối (Leyline Resonance) | Trong một lượt đổ xúc xắc (bất kể là lượt của mình hay đối thủ), kích hoạt Long Mạch nhận cùng lúc từ 12 tài nguyên trở lên nhờ mạng lưới công trình dày đặc. |
| Độc Quyền Phát Minh (Intellectual Monopoly) | Tích lũy đạt 20 Khoa Học trong kho và sở hữu trọn vẹn 1 nhánh trường phái Công Nghệ (mua và kích hoạt đủ cả 6 thẻ của trường phái đó). |

## 5. Core Loop

### 5.1 Vòng lặp tổng thể
Một ván chơi diễn ra theo vòng lặp ba lớp:

| Lớp | Đơn vị | Nội dung chính | Tần suất |
|---|---|---|---|
| Macro | Ván chơi | Mở rộng lãnh thổ → xây dựng kinh tế → kết thúc với điểm cao nhất | 1 lần/ván |
| Meso | Vòng (Round) | 5 vòng = 1 Sự Kiện Tổng; 20 vòng = kết thúc ván | 4–20 lần/ván tùy chế độ |
| Micro | Lượt (Turn) | Sản Xuất → Giải Quyết → Hành Động → chuyển xúc xắc | 1–4 lần/vòng |

### 5.2 Khâu Sản Xuất
Người chơi đổ hai viên xúc xắc. Kết quả kích hoạt sản xuất cho mọi người chơi có công trình sản xuất loại tài nguyên tương ứng — đây là cơ chế Long Mạch.

> **Cơ chế Long Mạch**
> Khi Người A đổ được mặt Kỹ Thuật, không chỉ Người A được nhận. Người B và C có nhà máy kỹ thuật trong lãnh thổ của mình cũng được hưởng. Ngoại lệ duy nhất: mặt Hex chỉ áp dụng cho người đang trong lượt. Phiến Quân phong tỏa vùng bị ảnh hưởng — ai có công trình trong vùng đó mất tài nguyên lượt này.

**Công thức sản lượng:** *Sản lượng = Cấp độ công trình × Sản lượng cơ bản × Số viên xúc xắc khớp*

Ví dụ: Hai nhà máy thép Cấp 2, sản lượng cơ bản 2 Kỹ Thuật. Đổ ra cả hai mặt Kỹ Thuật → mỗi nhà máy cho 2 × 2 × 2 = 8, tổng 16 Kỹ Thuật trong một lượt.
- Mặt Hex trống (⬡): không sản xuất tài nguyên — mỗi mặt cho 1 phiếu (token) Chi Phối dùng trong Khâu Hành Động.
- Đổ ra số 7 (tổng hai viên): không nhận tài nguyên, kích hoạt Phiến Quân.

### 5.3 Khâu Giải Quyết
Khâu này xử lý tất cả hiệu ứng ngoại sinh theo thứ tự cố định. Thứ tự quan trọng vì một số hiệu ứng phụ thuộc lẫn nhau.
- 1. Phiến Quân — nếu số 7 bị kích hoạt ở Khâu Sản Xuất.
- 2. Sự Kiện Tổng — nếu đây là vòng thứ 5, 10, 15, 20.
- 3. Thẻ Sắc Lệnh — người chơi chọn kích hoạt thẻ có điều kiện đã thỏa.
- 4. Kỹ năng nhân vật — hiệu ứng nội tại của nhân vật đang giữ.

### 5.4 Khâu Hành Động
Người chơi thực hiện các hành động theo thứ tự tự chọn, miễn đủ tài nguyên. Không có giới hạn số lượng hành động — giới hạn duy nhất là tài nguyên.

#### Trao đổi tài nguyên
Cho phép giữa hai phe có lãnh thổ được nối với nhau bằng đường giao thông. Chỉ người đang trong lượt mới được đề xuất. Không được cho không, không đổi cùng loại.

#### Xây dựng — Nâng cấp & Dỡ bỏ
Đặt hoặc nâng cấp công trình trên tile thuộc lãnh thổ thực hữu (xem mục 8 — Hệ thống Công Trình). Công trình cao cấp hơn sản xuất nhiều hơn nhưng đắt hơn — buộc người chơi phải cân nhắc giữa mở rộng nhanh và đầu tư sâu. Người chơi có thể hủy bỏ công trình nếu cần và không hoàn tài nguyên đã dùng, tiêu hao 1 vòng và trả về tài nguyên gốc cho tile. Có thể dùng Sắc Lệnh để dỡ ngay và được hoàn tài nguyên.

#### Tuyên bố Chi Phối (sở hữu tile)
Mỗi mặt ⬡ từ xúc xắc cho 1 phiếu Chi Phối. Phiếu được đặt lên tile trong phạm vi ảnh hưởng. Khi đủ phiếu, tile trở thành lãnh thổ thực hữu — cho phép xây dựng. Người chơi có thể tranh chấp miễn đủ điều kiện sẽ có thể sở hữu trước.

> **Phân biệt quan trọng**
> Vùng ảnh hưởng (6 ô mặc định / 18 ô nâng cấp quanh HQ/Subsidiary) ≠ Lãnh thổ thực hữu. Vùng ảnh hưởng: cho phép thu tài nguyên + bỏ phiếu. Lãnh thổ thực hữu: xây dựng được. Ngưỡng phiếu (token) tăng theo khoảng cách bán kính tính từ tâm: 1 tile = 1 phiếu, 2 tile = 2 phiếu, 3+ tile = 3 phiếu.

#### Trao đổi và xây đường
Người chơi có thể trao đổi tài nguyên với nhau nếu có tuyến đường nối hai Khu Chợ của các bên lại. Mua Đơn vị Giao Thương mất 5 Vàng, đi được 5 bước không cần xúc xắc. Mỗi bước đi của Đơn Vị Giao Thương sẽ tạo 1 Đường Đất. Đi và về xem như hoàn thành 1 lần trade. Vùng ảnh hưởng của Phiến Quân có thể khiến Giao Thương đình trệ; Phiến Quân có thể hủy Đơn vị Giao Thương.

Chỉ trong lượt người chơi mới có thể tiến hành đề xuất trao đổi tài nguyên và nhận đề xuất trao đổi từ người khác. Không thể trao đổi tài nguyên giống nhau và với chính mình. Số tài nguyên có thể đổi là không giới hạn, bao gồm cả cho không. Chi phí trao đổi tính bằng quãng đường với mỗi tile là 1 Vàng.

Nếu Khu dân cư có Cảng/Chợ, có thể trade với tỉ lệ nhất định. Nâng Hảo Cảm với Khu Dân Cư sẽ cho nhiều lợi ích. Người chơi học Công Nghệ sẽ cho phép xây Cảng/Chợ. Có thể nâng cấp đường và đơn vị Giao Thương (xem mục 9.2 — Đường Giao Thông). Mọi đơn vị đi trên Đường sẽ +1 di chuyển.

## 6. Hệ thống Phiến Quân

### 6.1 Vai trò thiết kế
Phiến Quân là yếu tố gây hỗn loạn có kiểm soát. Không có Phiến Quân, game trở thành bài toán tối ưu thuần túy. Phiến Quân buộc người chơi phải phản ứng, thích nghi và đôi khi tận dụng làm công cụ tấn công.

### 6.2 Cơ chế
- Kích hoạt: Người chơi đổ tổng 7 → không nhận tài nguyên → đổ thêm 1 viên xúc xắc (1–6) làm số bước di chuyển.
- Di chuyển: Phiến Quân di chuyển đúng số bước, mỗi bước sang ô kề chưa đi qua trong lượt này (không trùng); không thể đi qua núi ở 10 lượt đầu; bị trừ 1 bước nếu đi qua rừng, sông, núi.
- Phong tỏa: Phiến Quân phong tỏa ô đứng và 6 ô lân cận — công trình trong vùng này không sản xuất cho đến khi Phiến Quân rời đi.
- Phiến Quân có thể hủy đơn vị Viễn Chinh và Giao Thương.
- Hiệu ứng khi dừng: tùy vào tile Phiến Quân dừng lại (xem bảng).

| Tile dừng | Hiệu ứng |
|---|---|
| Ô trống (không có công trình) | Chỉ phong tỏa vùng xung quanh |
| Ô có công trình của người khác | Chủ công trình bỏ phân nửa (ceil) tài nguyên nhiều nhất |
| Ô có tài nguyên ngoài chủ | Người kích hoạt lấy phân nửa (ceil) tài nguyên bị cướp |

### 6.3 Cách đuổi Phiến Quân
- Sắc Lệnh có hiệu ứng di dời — đẩy Phiến Quân đến tile chỉ định.
- Quân đội viễn chinh — di chuyển Phiến Quân khi chiến đấu thắng.
- Một số kỹ năng nhân vật cho phép điều khiển trực tiếp.
- Một số Công Trình Đặc Biệt (xem mục 8.3) cho phép né hoặc đẩy Phiến Quân — Pháo Đài Chiến Lược, Thiên Đình Tín Ngưỡng.

## 7. Hệ thống Lãnh thổ

### 7.1 Ba tầng kiểm soát
Kiểm soát lãnh thổ trong Long Mạch không phải trạng thái nhị phân (có/không). Có ba tầng riêng biệt, mỗi tầng mở ra quyền năng khác nhau và có thể tồn tại đồng thời giữa các phe.

| Tầng | Điều kiện | Quyền năng |
|---|---|---|
| Vùng ảnh hưởng | Tile nằm trong bán kính 1 quanh HQ/Subsidiary | Thu tài nguyên, bỏ phiếu Chi Phối |
| Tranh chấp | Có phiếu nhưng chưa đủ ngưỡng | Chặn đối thủ claim; có thể mất nếu thua phiếu |
| Lãnh thổ thực hữu | Đủ phiếu theo ngưỡng khoảng cách | Xây dựng công trình, bảo vệ tài nguyên |

### 7.2 Tranh chấp lãnh thổ
Khi hai người chơi cùng trong phạm vi ảnh hưởng của một tile, cả hai đều có thể bỏ phiếu. Người đạt ngưỡng trước giành quyền sở hữu — nhưng đối thủ vẫn có thể tiếp tục bỏ phiếu để tranh lại nếu tile đó có chiến lược cao với chi phí gấp đôi yêu cầu. Công trình đã xây sẽ không mất trừ phi có Sắc Lệnh dỡ bỏ hoặc kỹ năng, hoặc là đất thuộc sở hữu của mình.

Người chơi có thể dùng 3 Tín Ngưỡng, 3 Vàng, 3 Kỹ Thuật để mua Đơn vị Viễn Chinh với cơ chế di chuyển như Phiến Quân nhưng di được 4 bước mỗi vòng không cần xúc xắc. Mỗi lượt chỉ có thể chọn Di Chuyển hoặc Lập Khu Trực Thuộc (Subsidiary). Khu Trực Thuộc hoạt động như nhà chính, mở rộng phạm vi ảnh hưởng ra 6 ô xung quanh.

Người chơi có thể nâng cấp HQ/Sub để mở rộng thêm phạm vi ảnh hưởng thêm 1 vòng bán kính nữa (xem bảng cấp độ đầy đủ ở mục 9.1). Sub chỉ cho phép nâng cấp 2 lần; HQ 5 lần.

Có thể bỏ Vàng và Văn Hóa để mua tile trong phạm vi ảnh hưởng, phí sẽ tăng gấp đôi theo khoảng cách tính từ tâm HQ/Sub. Với Khu dân cư tự do và danh thắng: chỉ cần 1 token cho mỗi tile, vùng đó sẽ nằm dưới quyền chi phối hoàn toàn của 1 người chơi nếu họ chiếm ưu thế về số ô Chi Phối; trường hợp bằng nhau có thể tranh chấp ô với chi phí cấp số cộng (+1).

Ngoài phiếu xúc xắc, một số Sự Kiện và Sắc Lệnh có thể trao quyền lãnh thổ trực tiếp, tạo ra những khoảnh khắc bất ngờ không thể dự đoán hoàn toàn.

### 7.3 Đặt HQ & Khu Trực Thuộc
Đây là quyết định quan trọng nhất đầu ván, xác định phạm vi ảnh hưởng ban đầu và định hình chiến lược cả ván.

| Công trình | Điều kiện đặt | Tác dụng |
|---|---|---|
| HQ (Nhà Chính) | Không trên Núi/Sông; cách HQ/Sub khác ≥ 1 vòng chu vi; đủ 6 ô xung quanh | Vùng ảnh hưởng 7 tile (bản thân + 6 ô) |
| Subsidiary (Khu Trực Thuộc) | Không trên Núi/Sông; cách HQ/Sub khác ≥ 1 vòng chu vi; đủ 6 ô xung quanh | Mở rộng vùng ảnh hưởng; giảm ngưỡng phiếu (token hex) xa |

Điều kiện đặt: khi đặt HQ/Sub (mặc định Cấp 1) phải luôn đảm bảo có 1 vòng chu vi xung quanh không xung đột với bất kì vòng chu vi (Cấp 1) HQ/Sub nào khác. Phạm vi vùng ảnh hưởng (vòng chu vi Cấp 1) không được trùng lên tile của danh thắng hay khu dân cư.

## 8. Hệ thống Công Trình
Mục mới trong v1.2, hợp nhất từ tài liệu thiết kế Perisol_Buildings_v1.0. Hệ thống công trình có ba tầng: Cơ Bản → Phái Sinh → Đặc Biệt, phản ánh chiều sâu phát triển kinh tế của mỗi phe.

| Loại | Số lượng | Yêu cầu | Mô tả ngắn |
|---|---|---|---|
| ⛏ Cơ Bản | 5 loại × 3 cấp | Ô trống + tài nguyên | Sản xuất 1 loại tài nguyên theo xúc xắc |
| ⚗ Phái Sinh | 5 loại | Kết hợp 2 công trình | Tạo vật liệu mới từ 2 công trình liền kề/nối đường |
| 🔭 Đặc Biệt | 5 loại | Vật liệu phái sinh + không gian lớn | Aura bonus hex xung quanh, khả năng đặc biệt |

### 8.1 Công trình Cơ Bản (5 loại × 3 cấp)
Mỗi công trình sản xuất 1 loại tài nguyên chính khi xúc xắc ra mặt tương ứng (Long Mạch). Cấp cao hơn cần nhiều ô trống hơn nhưng cho sản lượng và bonus cross-resource cao hơn.

| ID | Công trình | Tài nguyên | Địa hình | Cấp 1 | Cấp 2 | Cấp 3 |
|---|---|---|---|---|---|---|
| B-01 | Trại Khai Thác | Kỹ Thuật | Đồng Bằng, Núi | 1 ô · 2 KT+1V · 1 KT khi ra KT | 3 ô (Δ) · 4 KT+2 KH+3V · 2 KT khi ra KT, 1 KT khi ra KH | 6 ô (thang) · 7 KT+4 KH+6V · 3 KT ra KT, 2 KT ra KH, +1 KT thụ động/vòng |
| B-02 | Viện Nghiên Cứu | Khoa Học | Đồng Bằng, Rừng | 1 ô · 2 KH+1V · 1 KH khi ra KH | 3 ô (Δ) · 4 KH+2 KT+3V · 2 KH ra KH, 1 KH ra KT | 6 ô (cụm hex) · 7 KH+3 KT+5V · 3 KH ra KH, 2 KH ra KT, +1 KH thụ động/vòng |
| B-03 | Nhà Văn Hóa | Văn Hóa | Đồng Bằng, Bờ Biển, Khu Dân Cư | 1 ô · 2 VH+1V · 1 VH khi ra VH | 2 ô liền · 3 VH+1 TN+2V · 2 VH ra VH, 1 VH ra TN | 4 ô (chữ nhật hex) · 5 VH+3 TN+4V · 3 VH ra VH, +0.5 VH thụ động/vòng theo tile tiếp giáp |
| B-04 | Đền Thờ | Tín Ngưỡng | Đồng Bằng, Rừng, Sông | 1 ô · 2 TN+1V · 1 TN khi ra TN | 2 ô liền (có thể trên Sông) · 3 TN+2 VH+2V · 2 TN ra TN, 1 TN ra VH | 3 ô liền · 5 TN+3 VH+3V · 3 TN ra TN, +1 TN thụ động nếu Phiến Quân hiện diện |
| B-05 | Khu Chợ | Vàng | Đồng Bằng, Bờ Biển, Khu Dân Cư | 1 ô · 3V+1 KT · 1V khi ra Vàng | 2 ô liền · 5V+3 KT · 2V ra Vàng, +0.5V/vòng mỗi tuyến Đường Đất nối (tối đa 3) | 3 ô (L hex) · 8V+5 KT+2 VH · 3V ra Vàng, Giao Thương không cần Đơn Vị trong bán kính 2 ô |

Ghi chú bảng trên: mỗi ô cấp trình bày theo thứ tự "chiếm ô · chi phí xây · sản xuất". KT = Kỹ Thuật, KH = Khoa Học, VH = Văn Hóa, TN = Tín Ngưỡng, V = Vàng.

### 8.2 Công trình Phái Sinh (5 loại)
Hình thành khi hai công trình đủ cấp đứng liền kề hoặc được nối bằng Đường Đất. Tạo ra vật liệu mới dùng cho Công Trình Đặc Biệt.

> **Quy tắc khoảng cách kết hợp**
> 0 ô (liền kề): kết hợp tức thì, không cần điều kiện thêm.
> 1–2 ô: cần ít nhất 1 đoạn Đường Đất nối liên tục giữa hai công trình.
> 3+ ô: không thể kết hợp dù có đường — cần xây lại gần hơn hoặc dùng thẻ Công Nghệ đặc biệt.

| ID | Công trình → Vật liệu | Công thức | Kích hoạt | Công dụng |
|---|---|---|---|---|
| D-01 | Phòng TN Vật Liệu → Hợp Kim | Trại Khai Thác C2+ ⟺ Viện NC C2+ | Ra Kỹ Thuật hoặc Khoa Học: nhận 1 Hợp Kim thay vì tài nguyên gốc (chọn 1 trong 2 viên). +1 Hợp Kim thụ động mỗi 3 vòng. | Xây Công Trình Đặc Biệt, nâng cấp Đơn Vị Viễn Chinh. 1 Hợp Kim = 2 KT + 1 KH quy đổi. |
| D-02 | Xưởng In Ấn → Giấy | Nhà Văn Hóa C1+ ⟺ Trại Khai Thác C2+ | Ra Văn Hóa hoặc Kỹ Thuật: sản xuất 1 Giấy. +1 Giấy/vòng nếu có Đường Đất nối. | Mua Sắc Lệnh giảm 1 Văn Hóa, hoặc xây Thư Viện / Nhà Ngân Hàng. |
| D-03 | Xưởng Luyện Kim → Thép | Trại Khai Thác C3 ⟺ Đền Thờ C2+ | Ra Kỹ Thuật: nhận 1 Thép (thay 1 Kỹ Thuật thường). +1 Thép thụ động mỗi 4 vòng. | Xây Pháo Đài, nâng cấp Chốt Phòng Thủ. 1 Thép = 2 KT + 1 TN. |
| D-04 | Xưởng Dệt Lụa → Lụa | Nhà Văn Hóa C2+ ⟺ Đền Thờ C2+ | Ra Văn Hóa hoặc Tín Ngưỡng: nhận 1 Lụa. +1 Lụa/vòng nếu tiếp giáp Khu Dân Cư. | Tăng giá trị đề nghị Giao Thương (1 Lụa = 3 Vàng khi đổi), thay Văn Hóa trong một số Sắc Lệnh. |
| D-05 | Nhà Ngân Hàng → Tín Phiếu | Khu Chợ C2+ ⟺ Xưởng In Ấn | Ra Vàng: có thể chuyển 1–2 Vàng thành Tín Phiếu. Mỗi Tín Phiếu chưa chi trả sinh lãi 0.5 Vàng/vòng. | 1 Tín Phiếu = 2 Vàng hoãn chi trả đến cuối vòng tiếp theo. Tối đa 5 Tín Phiếu cùng lúc. |

### 8.3 Công trình Đặc Biệt (5 loại)
Yêu cầu vật liệu phái sinh và chiếm nhiều ô. Mỗi công trình đặc biệt phát ra Aura — bonus passif ảnh hưởng các hex lân cận — và có thể nâng cấp thêm 2 cấp.

#### Tháp Quan Sát Thiên Văn [S-01]
*Cột mốc khoa học. Nhìn xa, hiểu sâu, kiểm soát thông tin.*

| Trường | Nội dung |
|---|---|
| Nguyên liệu | Hợp Kim ×3, Khoa Học ×5, Giấy ×2 |
| Địa hình | Núi, Đồng Bằng (cao) |
| Chiếm ô | 1 ô trung tâm + 6 ô xung quanh phải trống |
| Hiệu ứng Aura | Bán kính 2 ô: khi xúc xắc ra Khoa Học, nhận +1 Khoa Học bổ sung (Long Mạch cộng thêm). |

**Thụ động thường trực:**
- Mỗi vòng: xem trước 1 trong 2 mặt xúc xắc trước khi đổ chính thức (sau đó úp lại và đổ bình thường).
- Biết vị trí di chuyển của Phiến Quân ngay khi nó bắt đầu di chuyển (thay vì cuối).
- Giảm 1 chi phí Khoa Học khi mua thẻ Công Nghệ.

**Nâng cấp:**

| Cấp | Chi phí | Hiệu ứng |
|---|---|---|
| +1 | Hợp Kim ×2 + Vàng ×4 | Aura mở rộng lên bán kính 3 ô. |
| +2 | Hợp Kim ×3 + Giấy ×3 + Vàng ×6 | Xem trước 2 viên xúc xắc thay vì 1; có thể giữ 1 viên trước khi đổ lại viên còn lại. |

#### Pháo Đài Chiến Lược [S-02]
*Trung tâm quân sự — kiểm soát toàn bộ vùng phòng thủ.*

| Trường | Nội dung |
|---|---|
| Nguyên liệu | Thép ×3, Kỹ Thuật ×6, Vàng ×5 |
| Địa hình | Núi, Đồng Bằng |
| Chiếm ô | 1 ô trung tâm + 3 ô kề (tam giác bảo vệ) |
| Hiệu ứng Aura | Bán kính 2 ô: Phiến Quân không thể dừng lại. Đơn Vị Viễn Chinh đối thủ vào vùng aura bị giảm 2 bước di chuyển còn lại. |

**Thụ động thường trực:**
- Khi Phiến Quân bị đẩy ra khỏi aura, người kích hoạt PQ mất 2 Vàng.
- +1 Kỹ Thuật thụ động mỗi vòng.
- Đơn Vị Viễn Chinh xuất phát từ Pháo Đài: +2 bước di chuyển lượt đầu tiên.

**Nâng cấp:**

| Cấp | Chi phí | Hiệu ứng |
|---|---|---|
| +1 | Thép ×2 + Vàng ×4 | Aura tăng lên bán kính 3. Đơn Vị Viễn Chinh đối thủ vào vùng aura bị dừng hoàn toàn 1 vòng. |
| +2 | Thép ×3 + Hợp Kim ×1 + Vàng ×6 | Pháo Đài phóng "Pháo": 1 lần/5 vòng, phá hủy 1 công trình Cấp 1 của đối thủ trong bán kính 3 ô. |

#### Bảo Tàng Quốc Gia [S-03]
*Biểu tượng quyền lực mềm. Chi phối lòng dân, khuất phục đối thủ không cần giao tranh.*

| Trường | Nội dung |
|---|---|
| Nguyên liệu | Lụa ×2, Giấy ×3, Văn Hóa ×6, Vàng ×4 |
| Địa hình | Đồng Bằng, Khu Dân Cư |
| Chiếm ô | 1 ô trung tâm + 2 ô liền kề |
| Hiệu ứng Aura | Bán kính 2 ô: phiếu Chi Phối của người sở hữu có giá trị ×1.5 (làm tròn lên) khi tranh chấp Danh thắng hoặc Khu Dân Cư. |

**Thụ động thường trực:**
- +2 Văn Hóa thụ động mỗi vòng.
- Mỗi Khu Dân Cư đang Chi Phối hoàn toàn trong bán kính 3 ô: +1 điểm cuối ván bổ sung.
- Đối thủ muốn mua Sắc Lệnh nhắm vào Bảo Tàng phải trả thêm 2 Văn Hóa phụ phí.

**Nâng cấp:**

| Cấp | Chi phí | Hiệu ứng |
|---|---|---|
| +1 | Lụa ×2 + Văn Hóa ×4 + Vàng ×3 | Aura mở rộng lên bán kính 3. Người chơi không thể dùng Sắc Lệnh Tức Thì nhắm vào tile trong aura. |
| +2 | Lụa ×3 + Giấy ×2 + Vàng ×5 | 1 lần/ván: "Triển Lãm" — tất cả người chơi thấy các Sắc Lệnh bạn đang giữ, nhưng bạn nhận 3 Văn Hóa từ mỗi đối thủ. |

#### Đài Phát Thanh Long Mạch [S-04]
*Khuếch đại tín hiệu Long Mạch — chia sẻ sản lượng trên diện rộng bất thường.*

| Trường | Nội dung |
|---|---|
| Nguyên liệu | Hợp Kim ×2, Giấy ×2, Khoa Học ×4, Kỹ Thuật ×4 |
| Địa hình | Đồng Bằng, Bờ Biển |
| Chiếm ô | 1 ô trung tâm + 6 ô xung quanh (tất cả thuộc lãnh thổ bạn) |
| Hiệu ứng Aura | Bán kính Long Mạch của bạn tăng thêm 2 ô (công trình trong vùng mở rộng cũng hưởng Long Mạch từ người khác). |

**Thụ động thường trực:**
- Khi bạn đổ xúc xắc, công trình cùng loại tài nguyên trong bán kính 3 ô (kể cả của đối thủ) sản xuất +1 bổ sung.
- +1 Khoa Học và +1 Kỹ Thuật thụ động mỗi vòng.
- Phiến Quân trong bán kính 1 ô từ Đài bị giảm phong tỏa xuống còn 3 tile thay vì 7.

**Nâng cấp:**

| Cấp | Chi phí | Hiệu ứng |
|---|---|---|
| +1 | Hợp Kim ×2 + Khoa Học ×3 + Vàng ×4 | Aura Long Mạch mở rộng thêm 1 ô (tổng +3 ô). Nhận thêm 1 tài nguyên bất kỳ khi Long Mạch kích hoạt từ người khác. |
| +2 | Hợp Kim ×3 + Giấy ×3 + Vàng ×6 | 1 lần/3 vòng: "Phát Sóng Toàn Cầu" — mọi người nhận tài nguyên như thể cả 2 viên xúc xắc đều ra cùng mặt của viên bạn đổ cao hơn. |

#### Thiên Đình Tín Ngưỡng [S-05]
*Trung tâm tâm linh tối thượng. Can thiệp trực tiếp vào cơ chế xúc xắc và Phiến Quân.*

| Trường | Nội dung |
|---|---|
| Nguyên liệu | Lụa ×2, Thép ×1, Tín Ngưỡng ×6, Vàng ×4 |
| Địa hình | Rừng, Núi, Sông |
| Chiếm ô | 1 ô trung tâm + 2 ô cùng loại địa hình |
| Hiệu ứng Aura | Bán kính 2: khi Phiến Quân dừng trong vùng, chủ sở hữu trả 2 Tín Ngưỡng để đẩy PQ ra 1 tile ngẫu nhiên bên ngoài aura. |

**Thụ động thường trực:**
- +2 Tín Ngưỡng thụ động mỗi vòng.
- 1 lần/ván: hủy bỏ kết quả tổng 7 — Phiến Quân không di chuyển, người đổ xúc xắc nhận 1 Tín Ngưỡng thay thế.
- Kỹ năng nhân vật tốn Tín Ngưỡng giảm 1 chi phí khi dùng trong bán kính 3 ô từ Thiên Đình.

**Nâng cấp:**

| Cấp | Chi phí | Hiệu ứng |
|---|---|---|
| +1 | Tín Ngưỡng ×4 + Vàng ×3 | Hủy tổng 7 tăng từ 1 lên 2 lần/ván. Đẩy Phiến Quân không còn ngẫu nhiên — bạn chọn hướng. |
| +2 | Lụa ×2 + Tín Ngưỡng ×5 + Vàng ×5 | 1 lần/ván: "Niết Bàn" — bỏ qua toàn bộ hiệu ứng Sự Kiện Tổng lượt này. Chỉ bạn miễn nhiễm, các người chơi khác vẫn chịu hiệu ứng. |

## 9. Hệ thống Hạ Tầng
Mục mới trong v1.2, tổng hợp từ bảng dữ liệu Perisol_Data (sheet "Hạ tầng"). Bao gồm cấp độ HQ/Subsidiary, hệ thống Đường Giao Thông và hai chuỗi tài nguyên công nghiệp phụ trợ (Than, Dầu Mỏ).

### 9.1 Cấp độ HQ & Khu Trực Thuộc
| Công trình | Cấp | Chi phí xây/nâng | Điều kiện | Tác dụng |
|---|---|---|---|---|
| Nhà Chính (HQ) | Cấp 1 | Khởi đầu miễn phí | Không đặt trên Núi/Sông | Vùng ảnh hưởng 7 ô (tâm + 6 ô) |
| | Cấp 2 | 4 KT + 2 KH + 3 Vàng | Lãnh thổ thực hữu | Mở rộng vùng ảnh hưởng thêm 1 vòng bán kính (tổng 19 ô) |
| | Cấp 3 | 6 KT + 2 Hợp Kim + 5 Vàng | Cần kết nối ít nhất 1 Khu Chợ | Cho phép xây Công Trình Đặc Biệt trong lãnh thổ |
| | Cấp 4 | 8 KT + 3 Thép + 8 Vàng | Đạt mốc vòng 11+ | Tự động nâng cấp Đơn Vị Viễn Chinh lên Hiệp Sĩ |
| | Cấp 5 | 10 KT + 4 Thép + 4 Hợp Kim + 12 Vàng | Cần sở hữu ít nhất 1 Cảng/Chợ Cấp 3 | Mở khóa aura thủ đô: +1 sản lượng cho mọi công trình nội đô |
| Khu Trực Thuộc (Sub) | Cấp 1 | 3 TN + 3 Vàng + 3 KT | Cách HQ/Sub khác 1 vòng chu vi | Hoạt động như nhà phụ, mở vùng ảnh hưởng 7 ô |
| | Cấp 2 | 4 KT + 3 Vàng | Lãnh thổ thực hữu | Mở rộng ảnh hưởng thêm 1 vòng bán kính; giảm ngưỡng Chi Phối ô xa |
| | Cấp 3 | 6 KT + 2 Thép + 5 Vàng | Đạt mốc vòng 16+ | Biến Sub thành Đô Thị Vệ Tinh (miễn nhiễm phong tỏa 1 ô tâm) |

> **Khớp với mục 7.3**
> Bảng trên là bản chi tiết hóa quy tắc "Sub nâng cấp tối đa 2 lần, HQ tối đa 5 lần" đã nêu ở mục 7.2/7.3 của v1.1 — không mâu thuẫn, chỉ định lượng chi phí và mốc vòng cụ thể.

### 9.2 Đường Giao Thông
| Cấp | Chi phí / tile | Điều kiện / địa hình | Tác dụng |
|---|---|---|---|
| Cấp 1: Đường Đất | 1 Vàng / tile | Đồng Bằng, Rừng, Bờ Biển, Đồi Cỏ | Kết nối Chợ để Trade; đơn vị đi trên đường +1 di chuyển |
| Cấp 2: Đường Lát Đá | 1 KT + 1 Vàng / tile | Nâng từ Đường Đất | Đơn vị +2 di chuyển; giảm 50% phí Vàng khi Giao Thương |
| Cấp 3: Đường Ray Xe Lửa | 1 Thép + 1 Than + 2 Vàng / tile | Yêu cầu Công Nghệ Mạng Lưới | Đơn Vị Giao Thương hóa Đoàn Tàu Hỏa (+4 bước); kết nối phái sinh xa 4 ô |
| Nhánh: Đường Ống Dẫn | 1 Hợp Kim + 1 KT + 2 Vàng / tile | Đi ngầm qua Núi, Sông, Đầm Lầy | Vận chuyển Dầu/Than tự động về HQ mỗi vòng, không cần Đơn Vị |

### 9.3 Khai khoáng & Năng lượng (Than, Dầu Mỏ)
Hai chuỗi tài nguyên công nghiệp phụ trợ nuôi hệ thống luyện Thép và Đường Ray Xe Lửa, quy đổi được sang tài nguyên cốt lõi.

| Công trình | Cấp | Chiếm ô | Chi phí | Điều kiện | Sản xuất |
|---|---|---|---|---|---|
| Mỏ Than | Cấp 1 | 1 ô | 3 KT + 2 Vàng | Núi, Đồi Cỏ, Lãnh Nguyên | 1 Than khi ra Kỹ Thuật; nhiên liệu luyện Thép/chạy Tàu |
| Mỏ Than | Cấp 2: Hầm Lò Sâu | 2 ô liền | 5 KT + 2 KH + 4 Vàng | Có quặng/mạch than | 2 Than; +1 Than thụ động mỗi 3 vòng |
| Giếng Dầu | Cấp 1: Bể Hút | 1 ô | 4 KT + 3 KH + 4 Vàng | Sa Mạc, Đầm Lầy, Bờ Biển Nông | 1 Dầu Mỏ khi ra Khoa Học; 1 Dầu = 3 Vàng hoặc 2 KT |
| Cụm Khai Thác Dầu | Cấp 2: Giàn Khoan | 3 ô liền | 7 KT + 4 Hợp Kim + 8 Vàng | Ven biển hoặc Sa Mạc lớn | 3 Dầu khi ra Khoa Học; năng lượng công nghiệp ×2 sản lượng máy móc |

### 9.4 Ma trận đặt công trình theo địa hình (trích)
Bảng đầy đủ do đội thiết kế duy trì trong Perisol_Data (sheet "Đặt công trình"). Trích các công trình cơ bản:

| Công trình | Đồng Bằng | Rừng | Núi | Sông | Bờ Biển | Đồi Cỏ | Khu DC |
|---|---|---|---|---|---|---|---|
| Trại Khai Thác (mọi cấp) | ✅ | ✅ | C2+ | ❌ | ✅ | ✅ | ❌ |
| Viện Nghiên Cứu (mọi cấp) | ✅ | ⭐ ưu tiên | ❌ | ❌ | ✅ | ✅ | ❌ |
| Nhà Văn Hóa (mọi cấp) | ✅ | ❌ | ❌ | ❌ | ✅ | C2+ | ⭐ ưu tiên |
| Đền Thờ (mọi cấp) | ✅ | ⭐ ưu tiên | ❌ | ✅ | ❌ | C2+ | ❌ |
| Khu Chợ C1–C2 | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ | ⭐ ưu tiên |
| Khu Chợ C3 | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |

✅ Được phép · ❌ Không được · ⭐ Ưu tiên (có bonus sản lượng, xem mục 8.1).

## 10. Hệ thống Sự Kiện & Thẻ bài
Mục cập nhật trong v1.2: số lượng thẻ đã được chốt và thiết kế chi tiết trong tài liệu riêng Perisol_Cards_v1.2 (80 thẻ: 30 Công Nghệ + 30 Sắc Lệnh + 20 Sự Kiện Tổng). Phần dưới đây tóm tắt cấu trúc; xem tài liệu đó để có toàn văn từng thẻ.

### 10.1 Cây Công Nghệ (30 thẻ)
Mua bằng 3 Khoa Học + 3 Kỹ Thuật. Tối đa 5 thẻ hoạt động cùng lúc, có thể hủy để đổi công nghệ khác (thẻ bị hủy vào lại chồng bài). Mỗi thẻ có 3 cấp nâng cấp; chi phí nâng cấp = ceil(chi phí trước × 1.8) + Vàng. Chia thành 5 trường phái, mỗi trường phái 6 thẻ:

| Trường phái | Trọng tâm | Thẻ tiêu biểu (Cấp gốc) |
|---|---|---|
| ⚙ Kỹ Thuật | Hạ tầng & Lãnh thổ | Mạng Lưới Giao Thông, Kiến Trúc Kiên Cố, Gia Cố Phòng Thủ, Quy Hoạch Đô Thị, Pháo Đài Biên Giới, Tuyến Vận Tải Nước |
| 🔬 Khoa Học | Tối ưu Long Mạch | Khai Thác Chuyên Sâu, Lý Thuyết Địa Mạch, Bản Đồ Địa Lý Học, Phân Tích Xúc Xắc, Mạng Lưới Quan Sát, Tái Cấu Trúc Long Mạch |
| 💰 Kinh Tế | Thao túng Vàng | Hợp Đồng Độc Quyền, Quỹ Đầu Tư Chiến Lược, Thuế Đường Biên, Kho Bạc Dự Phòng, Thị Trường Chợ Đen, Trái Phiếu Chiến Tranh |
| 🏛 Văn Hóa | Ngoại giao & Chi phối | Bộ Máy Tuyên Truyền, Ngoại Giao Bí Mật, Đồng Hóa Văn Hóa, Lễ Hội Liên Minh, Kiểm Soát Dư Luận, Sử Ký Chiến Thắng |
| ☯ Tín Ngưỡng | Quân sự & Bất thường | Cứu Chuộc, Nghi Lễ Phong Thủy, Lời Tiên Tri, Thần Binh Hộ Vệ, Bùa Chú Hỗn Loạn, Thiêng Liêng Hóa Đất Đai |

### 10.2 Thẻ Sắc Lệnh (30 thẻ)
Mua bằng 2 Văn Hóa + 2 Kỹ Thuật + 2 Vàng, giữ bí mật cá nhân — đối thủ biết số lượng, không biết nội dung. Đây là yếu tố bluff và đọc vị quan trọng nhất của game. Chia làm 3 nhóm, mỗi nhóm 10 thẻ:

| Nhóm | Thời điểm dùng | Vai trò | Ví dụ |
|---|---|---|---|
| Tức Thì | Khâu Hành Động | Tác động ngay lập tức để giành lợi thế | Lệnh Cưỡng Chế (di dời Phiến Quân), Cướp Đất, Nhân Bản Sản Lượng |
| Phản Ứng | Khâu Giải Quyết hoặc khi bị nhắm mục tiêu | Phá vỡ kế hoạch của đối thủ | Phủ Quyết, Biên Giới Thép, Gương Phản Chiếu |
| Nội Tại | Điều kiện ẩn — hiệu lực kéo dài | Tạo ra các lợi thế ngầm | Kế Hoạch B, Quỹ Tín Thác, Lưới Nhện |

### 10.3 Sự Kiện Tổng (20 thẻ)
Tự động lật mỗi 5 vòng từ chồng bài chung; lá mới thay thế và hủy hiệu lực lá cũ. Tác động toàn bộ người chơi đồng thời. Mức độ khốc liệt tăng dần theo 4 mốc, mỗi mốc 5 thẻ:

| Mốc vòng | Chủ đề | Ví dụ |
|---|---|---|
| Vòng 5 | Định Hình Thế Trận | Mùa Màng Bội Thu, Bùng Nổ Dân Số, Đất Đai Màu Mỡ, Hội Chợ Thương Mại, Thời Bình Tương Đối |
| Vòng 10 | Giao Tranh Tài Nguyên | Bão Tuyết Qua Núi, Hỗn Loạn Biên Giới, Mùa Hạn, Lũ Lớn, Phong Trào Ly Khai |
| Vòng 15 | Cạnh Tranh Khốc Liệt | Khủng Hoảng Niềm Tin, Cách Mạng Công Nghiệp, Bóng Tối Địa Chính Trị, Xuân Phân, Thiên Địa Biến Đổi |
| Vòng 20 | Chốt Hạ Ván Cờ | Ngày Tàn Của Đế Chế, Di Sản Lịch Sử, Đêm Trước Quyết Chiến, Huyết Thống Long Mạch, Màn Sương Chiến Trận |

> **Ghi chú đồng bộ với tài liệu cũ**
> Bản tổng hợp thiết kế bộ thẻ trước đó ("Các bộ thẻ Perisol") từng nêu 40 lá Sắc Lệnh — con số này đã được điều chỉnh và chốt lại thành 30 lá (10/10/10) trong Perisol_Cards_v1.2, là số liệu chính thức áp dụng cho GDD v1.2.

## 11. Thiết lập & Kết thúc ván

### 11.1 Thiết lập (Setup Phase)
Thực hiện tuần tự trước khi ván bắt đầu:
- 1. Ghép bản đồ — đảm bảo đủ 7 loại địa hình (rút từ bộ 12 loại, mục 3.1).
- 2. Đặt disc tài nguyên úp xuống → lật lên → loại bỏ disc X.
- 3. Xào và đặt bốn bộ bài cạnh bàn.
- 4. Đặt Phiến Quân lên tile trung tâm (hoặc tile được chỉ định).
- 5. Đổ xúc xắc xác định thứ tự đi — cao nhất đi trước, theo chiều kim đồng hồ.
- 6. Lần lượt theo thứ tự, mỗi người chọn tile đặt HQ (validation tự động trong bản digital).
- 7. Mỗi người chọn 1 trong 3 nhân vật từ pool nhân vật (rút ngẫu nhiên từ 5 nhân vật, mục 4.2).
- 8. Mỗi người nhận tài nguyên khởi đầu từ 6 ô xung quanh HQ.

### 11.2 Kết thúc ván
Ván kết thúc sau vòng 20, hoặc sớm hơn nếu một Sắc Lệnh / Sự Kiện kích hoạt điều kiện thắng sớm, hoặc nếu một nhân vật hoàn thành 1 trong 4 Điều Kiện Thắng riêng (mục 4.2). Tính điểm ngay sau vòng cuối.

| Tiêu chí | Điểm (dự kiến — cần playtesting) |
|---|---|
| Mỗi tile lãnh thổ thực hữu | 1 điểm |
| Mỗi Danh thắng đang chi phối | 3 điểm |
| Mỗi công trình Cấp 2+ | 2 điểm |
| Mỗi 5 tài nguyên còn dư | 1 điểm |
| Hoàn thành điều kiện thẻ đặc biệt | Theo thẻ |
| Hoàn thành 1 Điều Kiện Thắng nhân vật | Thắng ngay / điểm thưởng lớn — cần playtesting để xác định |

> **Trạng thái thiết kế**
> Bảng điểm trên là giá trị placeholder. Cân bằng điểm số, đặc biệt cách quy đổi Điều Kiện Thắng nhân vật thành điểm hoặc thắng tức thời, sẽ được xác định sau 5–10 ván playtesting.

## 12. Trải nghiệm người chơi

### 12.1 Đường cong học
Game được thiết kế để người chơi mới hiểu được luật cốt lõi trong 15 phút đầu ván — nhưng mất 3–5 ván để bắt đầu hiểu chiều sâu chiến lược.

| Ván | Người chơi mới học được |
|---|---|
| 1 | Luồng 3 khâu, cách đặt HQ, Long Mạch hoạt động ra sao |
| 2–3 | Khi nào bỏ phiếu Chi Phối có giá trị, Phiến Quân dùng như vũ khí |
| 4–5 | Đọc địa hình từ đầu ván, đặt HQ chiến lược, xây dựng kinh tế bền vững, kết hợp công trình Phái Sinh |
| 6+ | Asymmetric play theo nhân vật (5 lựa chọn), đọc vị đối thủ, dùng Sắc Lệnh đúng thời điểm, nhắm tới Điều Kiện Thắng riêng |

### 12.2 Tension points
- Đặt HQ đầu ván — quyết định không thể hoàn tác, ảnh hưởng cả ván.
- Đổ xúc xắc ra số 7 — lo lắng khi Phiến Quân đang nguy hiểm, phấn khích khi muốn tấn công.
- Tranh chấp tile cuối ván — cả hai phe đua nhau bỏ phiếu, thời gian chạy ngược.
- Tiết lộ Sắc Lệnh — khoảnh khắc "bài ngửa" khi dùng thẻ bất ngờ.
- Sự Kiện Tổng lật lên — bất ngờ thay đổi cục diện cho tất cả.
- Sắp hoàn thành một Điều Kiện Thắng nhân vật — đối thủ đua nhau phá hoặc trì hoãn.

### 12.3 Cân bằng Interaction
Perisol là game cạnh tranh gián tiếp — không có tấn công quân sự trực tiếp. Mọi xung đột đều qua: tranh chấp lãnh thổ, điều khiển Phiến Quân, và thẻ Sắc Lệnh. Điều này giữ cho game dễ tiếp cận hơn nhưng vẫn có độ căng cần thiết.

## 13. Lộ trình phát triển

### 13.1 Milestone
| Giai đoạn | Nội dung | Trạng thái |
|---|---|---|
| M0 — Sandbox | Hex map, đặt HQ, vùng ảnh hưởng, đổ xúc xắc cơ bản | Prototype |
| M1 — Core Loop | Đủ 3 khâu hoàn chỉnh, Phiến Quân, trao đổi, xây dựng | Tiếp theo |
| M1.5 — Buildings & Hạ Tầng | Công trình Cơ Bản/Phái Sinh/Đặc Biệt, HQ/Sub leveling, Đường Giao Thông, Than/Dầu | Thiết kế xong (v1.2) — chờ triển khai |
| M2 — Cards | Bộ thẻ Sắc Lệnh + Công Nghệ + Sự Kiện Tổng, UI thẻ bài | Thiết kế xong (80 thẻ, v1.2) — chờ UI/triển khai |
| M3 — Characters | 5 nhân vật asymmetric đầy đủ kỹ năng và điều kiện thắng | Thiết kế xong (v1.2) — chờ playtesting cân bằng |
| M4 — Polish | Art, âm thanh, animation xúc xắc, tutorial | Kế hoạch |
| M5 — Multiplayer | Hot-seat 4 người hoàn chỉnh, nhận tài nguyên theo lượt | Future |

### 13.2 Hệ thống chưa được thiết kế / cần xác nhận
- Cân bằng chi phí/hiệu ứng của 80 thẻ bài và toàn bộ hệ thống Công Trình/Hạ Tầng — chưa qua playtesting.
- Quy đổi Điều Kiện Thắng nhân vật thành điều kiện thắng sớm hoặc điểm số cụ thể ở bảng tính điểm cuối ván.
- Cây Công Nghệ — điều kiện tiên quyết chi tiết giữa các thẻ trong cùng trường phái.
- Online multiplayer — kiến trúc mạng, turn timer, reconnect.
- Art, icon chính thức cho 12 loại địa hình và 12 Tài Nguyên Chiến Lược (hiện đang chờ art theo ghi chú trong Perisol_Data).

## Phụ lục A — Từ điển thuật ngữ
| Thuật ngữ | Định nghĩa |
|---|---|
| Long Mạch | Cơ chế chia sẻ sản lượng xúc xắc với tất cả người chơi (trừ mặt Hex). |
| HQ (Nhà Chính) | Công trình chính, điểm xuất phát vùng ảnh hưởng. Mỗi người 1 HQ, tối đa Cấp 5. |
| Subsidiary | Khu Trực Thuộc — mở rộng vùng ảnh hưởng, giảm ngưỡng phiếu, tối đa Cấp 3. |
| Vùng ảnh hưởng | 6 tile xung quanh HQ/Subsidiary — thu tài nguyên, bỏ phiếu. Không xây được. |
| Lãnh thổ thực hữu | Tile đã đủ phiếu Chi Phối theo ngưỡng khoảng cách. Được phép xây dựng. |
| Chi Phối (CP) | Token phiếu đặt lên tile để tuyên bố chủ quyền. |
| Phiến Quân | Nhân vật trung lập, phong tỏa 7 tile khi đứng. Kích hoạt bởi đổ số 7. |
| Sắc Lệnh | Thẻ bí mật cá nhân, chi phí 2+2+2. Hiệu ứng Tức Thì, Phản Ứng hoặc Nội Tại. |
| Sự Kiện Tổng | Lá bài lật lên mỗi 5 vòng, tác động toàn bộ người chơi. |
| Ngưỡng phiếu | Số phiếu tối thiểu để claim tile: 1 tile = 1p, 2 tile = 2p, 3+ tile = 3p+. |
| Tài Nguyên Chiến Lược | Bonus hiếm gắn theo tile (12 loại) — cho bonus ô không cần sở hữu, bonus công trình cần sở hữu. |
| Công trình Phái Sinh | Vật liệu mới (Hợp Kim, Giấy, Thép, Lụa, Tín Phiếu) sinh ra khi 2 công trình Cơ Bản đủ cấp kết hợp. |
| Công trình Đặc Biệt | 5 công trình cao cấp nhất, dùng vật liệu Phái Sinh, phát Aura và có 2 cấp nâng cấp. |
| Aura | Hiệu ứng bị động của Công trình Đặc Biệt ảnh hưởng các hex trong bán kính nhất định. |
| Điều Kiện Thắng | 4 mục tiêu riêng biệt gắn với mỗi nhân vật, hoàn thành sẽ kết thúc ván sớm hoặc tính điểm thưởng lớn. |
| Than / Dầu Mỏ | Tài nguyên công nghiệp phụ trợ, khai thác qua Mỏ Than/Giếng Dầu, quy đổi sang tài nguyên cốt lõi hoặc dùng cho Đường Ray Xe Lửa. |

## Phụ lục B — Change log
- v1.0: Thiết lập cho trò chơi, làm GDD, xác định milestone và định hướng game.
- v1.1: Sửa đổi các nội dung ở mục 2.2, 7.3. Hạ thời gian chơi. Các event tổng ở mốc 5/10/15/20 sẽ khác nhau.
- v1.2 (bản này): Hợp nhất toàn bộ tài liệu thiết kế rời rạc vào GDD chính.
  - — Mở rộng hệ thống địa hình từ 7 lên 12 loại, bổ sung 12 Tài Nguyên Chiến Lược làm lớp bonus tile (mục 3.1–3.2).
  - — Thêm đầy đủ Hệ Thống Công Trình: 5 Cơ Bản × 3 cấp, 5 Phái Sinh, 5 Đặc Biệt với Aura và nâng cấp (mục 8, từ Perisol_Buildings_v1.0).
  - — Thêm Hệ Thống Hạ Tầng: cấp độ HQ/Subsidiary, 4 cấp Đường Giao Thông, chuỗi tài nguyên Than/Dầu Mỏ, ma trận đặt công trình theo địa hình (mục 9, từ Perisol_Data).
  - — Chốt số lượng bộ thẻ: 30 Công Nghệ, 30 Sắc Lệnh (10/10/10), 20 Sự Kiện Tổng — thay thế số liệu placeholder của v1.1 và số liệu cũ (40 Sắc Lệnh) trong tài liệu tổng hợp trước đó (mục 10, từ Perisol_Cards_v1.2).
  - — Hoàn thiện 5 nhân vật đầy đủ (bổ sung Học Sĩ) với kỹ năng gốc và 4 Điều Kiện Thắng riêng biệt mỗi nhân vật, thay thế bảng placeholder 4 nhân vật của v1.1 (mục 4, từ Characters.txt).
  - — Cập nhật Phụ lục A (từ điển) với các thuật ngữ mới; cập nhật roadmap (mục 13) để phản ánh các hệ thống đã có thiết kế đầy đủ.

## Phụ lục C — Tài liệu tham chiếu liên quan
- Perisol_Cards_v1.2.docx — toàn văn 80 thẻ (30 Công Nghệ, 30 Sắc Lệnh, 20 Sự Kiện Tổng).
- Perisol_Buildings_v1.0.docx — toàn văn chi tiết 15 công trình (Cơ Bản/Phái Sinh/Đặc Biệt).
- Perisol_Data.xlsx — bảng dữ liệu sống: Địa hình, Tài Nguyên Chiến Lược, Công trình, Đặt công trình, Hạ tầng, Hình ảnh đơn vị (chờ art).
- Characters.txt — 5 nhân vật và 4 Điều Kiện Thắng mỗi nhân vật.

<p align="center"><i>Perisol · GDD v1.2 · Nội bộ · Không phát hành ngoài</i></p>
