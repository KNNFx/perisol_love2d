# PERISOL - Game Design Document
**Thể loại:** Chiến lược lãnh thổ theo lượt
**Nền tảng:** PC (Love2D)
**Phiên bản:** 1.2 – Tài liệu lưu trữ nội bộ

Tài liệu này hợp nhất GDD v1.1 với các thiết kế mới: hệ thống Công Trình, Hạ Tầng, mở rộng Địa Hình & Tài Nguyên Chiến Lược, bộ thẻ hoàn chỉnh (Công Nghệ / Sắc Lệnh / Sự Kiện Tổng) và 5 nhân vật đầy đủ điều kiện thẳng.

---

## 1. Tổng quan trò chơi

### 1.1 Elevator Pitch
Perisol là game chiến lược lãnh thổ theo lượt cho 1-4 người chơi, lấy cảm hứng từ các trò chơi chiến thuật quản lý tài nguyên. Trên một bản đồ ô lưới lục giác, các phe tranh nhau kiểm soát ảnh hưởng thông qua **Long Mạch** – cơ chế chia sẻ sản lượng xúc xắc – trong khi mở rộng lãnh thổ, xây dựng công trình và dùng Sắc Lệnh bí mật để lật ngược cục diện.

### 1.2 Thông tin dự án
| Trường | Nội dung |
|---|---|
| **Tên dự án** | Perisol |
| **Thể loại** | Turn-based, strategy |
| **Số người chơi** | 1-4 (có chế độ chơi đơn và nhiều người chơi) |
| **Thời gian ván** | 25-45 phút (mặc định 20 vòng chơi) |
| **Nền tảng** | PC-Love2D, Lua |
| **Trạng thái** | Pre-production – hệ thống thẻ bài & công trình đã có thiết kế đầy đủ, chờ playtesting cân bằng |
| **Phiên bản GDD** | 1.2 |

### 1.3 Mục tiêu thiết kế
*   **Bản đồ sinh ngẫu nhiên mỗi ván** – người chơi đọc được địa thế, lập kế hoạch. Mọi địa hình đều mang ý nghĩa chiến lược: núi chặn đường đi nhưng cho điểm Kỹ Thuật và Khoa Học; Sông không thể xây nhưng tạo biên tự nhiên và tăng giá trị tín ngưỡng ô xung quanh; danh thắng là điểm nóng tranh chấp.
*   **Rủi ro có cấu trúc** – xúc xắc tạo biến động nhưng người chơi có nhiều công cụ để giảm thiểu hoặc tận dụng. Phiến Quân là mối đe dọa nhưng người thông minh biến nó thành vũ khí nhắm vào đối thủ. Thẻ Sắc Lệnh là lớp kiểm soát thứ hai.
*   **Mỗi lượt đều có sức nặng.** Không có lượt "đợi cho xong". Hiệu ứng Long Mạch đảm bảo mọi người đều tham gia vào kết quả xúc xắc – dù không phải lượt của mình.

### 1.4 Tham chiếu
| Yếu tố | Tham chiếu |
|---|---|
| **Cơ chế lục giác** | Catan (hex map, resource production) |
| **Vòng lượt động** | Agricola (mọi hành động đều có chi phí cơ hội) |
| **Lãnh thổ tầng lớp** | Twilight Imperium (influence vs ownership) |
| **Xúc xắc định nghĩa** | King of Tokyo (custom dice faces) |
| **Phong thủy / chủ đề** | Original IP - không có tham chiếu trực tiếp |

---

## 2. Thế giới & Chủ đề

### 2.1 Bối cảnh
"Long Mạch" trong phong thủy là những đường khí thiêng chạy dọc theo địa thế núi sông, quyết định vận số của đất đai và con người sống trên đó. Trong game, Long Mạch được thể hiện như một cơ chế chia sẻ tài nguyên: khi một phe khai thác một vùng đất, năng lượng của đất lan truyền theo các tuyến địa hình, vô tình (hoặc cố ý) nuôi dưỡng cả những phe kiểm soát vùng đất lân cận.
Năm phe không được đặt tên cụ thể – họ là những thế lực mang màu sắc văn hóa trừu tượng, cạnh tranh để thiết lập trụ sở trên vùng đất có long mạch mạnh nhất và bành trướng ảnh hưởng trước khi đối thủ kịp ổn định.

### 2.2 Tone
| Chiều | Hướng tới | Tránh |
|---|---|---|
| **Hình ảnh** | Hoạt hình, 2D top-down | Tả thực, màu quá u tối |
| **Âm thanh** | Nhạc tiết tấu vui tươi, hơi nhanh | OST hành động ồn ào |
| **Cảm xúc** | Tập trung, cân nhắc, thưởng thức | Căng thẳng nhịp độ cao |
| **Độ phức tạp** | Trung bình – học được trong 1 ván | Cần rulebook 20 trang để bắt đầu |

---

## 3. Thành phần & Không gian chơi

### 3.1 Bản đồ lục giác
Kích thước bản đồ đảm bảo mỗi người chơi có bán kính 3 ô từ tâm ra, đảm bảo an toàn (không bị người chơi khác lấn sớm) với tổng 19 ô (tính HQ). Mỗi ván phải đảm bảo đủ 7 kiểu địa hình được rút ra từ bộ 12 loại địa hình đã thiết kế.
Mặc định tỉ lệ map 16:8; bản đồ cơ bản cho 4 người chơi đảm bảo 32:16 tile.

*Cập nhật v1.2: Bộ địa hình mở rộng từ 7 lên 12 loại (bổ sung Lãnh Nguyên, Sa Mạc, Đầm Lầy, Đồi Cỏ, Núi Tuyết) để tăng biến thiên giữa các ván. Luật – mỗi ván đủ 7 kiểu địa hình vẫn giữ nguyên – 7 loại được rút ngẫu nhiên từ bộ 12.*

| ID | Địa hình | HQ/Sub | Công trình | CT Đặc Biệt | Di chuyển | Ghi chú |
|---|---|---|---|---|---|---|
| DH-01 | Đồng Bằng | X | X | X | Bình thường | Tile cơ bản, không penalty |
| DH-02 | Rừng | X | X | X | -1 bước | Đền Thờ, Nhà Văn Hóa ưu tiên; Viện NC C1 +1 KH thụ động |
| DH-03 | Núi | | | X | Không đi được | Chỉ CT Đặc Biệt & Pháo Đài; không đặt HQ/Sub |
| DH-04 | Sông | | | X | -1 bước | Đền Thờ, Xưởng Dệt Lụa được xây; không đặt HQ/Sub |
| DH-05 | Bờ Biển | X | X | X | Bình thường | Khu Chợ Cấp 3 miễn Đơn Vị Giao Thương |
| DH-06 | Lãnh Nguyên | X | X | | Bình thường | Vàng -1 sản lượng; xây công trình -1 Kỹ Thuật |
| DH-07 | Sa Mạc | X | X | | Bình thường | Không sản xuất Tín Ngưỡng |
| DH-08 | Đầm Lầy | | X | | -1 bước | Không đặt HQ; Tín Ngưỡng & Văn Hóa cao |
| DH-09 | Đồi Cỏ | X | X | X | Bình thường | Trại Khai Thác Cấp 2 +1 Kỹ Thuật |
| DH-10 | Khu Dân Cư | | | | Bình thường | Chỉ Chi Phối; cho điểm cuối ván; cụm 2-10 tile, >7 thành Thành Bang Tự Do |
| DH-11 | Danh Thắng | | | | Bình thường | Chỉ Chi Phối; 3 điểm cuối ván; 4 kiểu hình (đơn/tam giác/tứ giác) |
| DH-12 | Núi Tuyết | | | X | Không đi được | Hoạt động như Núi |

Khu Dân Cư Tự Do và Danh Thắng: số lượng khu dân cư và số danh thắng trên bản đồ đều bằng số người chơi + 1. Cả hai loại tile này chỉ cho phép Chi Phối (không xây dựng).

### 3.2 Tài nguyên chiến lược (bonus theo tile)
Ngoài loại địa hình, mỗi tile có thể mang một Tài Nguyên Chiến Lược – một lớp bonus hiếm không cần sở hữu để hưởng bonus ô, nhưng cần sở hữu để hưởng bonus công trình. Đây là lớp thiết kế mới bổ sung trong v1.2, làm phong phú giá trị chiến lược của từng ô đất.

| ID | Tên | Rarity | Địa hình xuất hiện | Bonus ô (không cần sở hữu) | Bonus công trình (cần sở hữu) |
|---|---|---|---|---|---|
| TN-01 | Đá Granite | Phổ biến | Núi, Đồi Cỏ | Tile +1 Kỹ Thuật bổ sung khi xúc xắc ra KT | Pháo Đài: -2 Kỹ Thuật chi phí xây |
| TN-02 | Rừng Cổ Thụ | Phổ biến | Rừng | +1 Tín Ngưỡng và +1 Khoa Học thụ động/vòng | Thiên Đình: bỏ yêu cầu địa hình Rừng |
| TN-03 | Cá | Phổ biến | Bờ Biển, Sông | Khu Chợ +2 Vàng khi ra Vàng; kết nối HQ ảo | Khu Chợ: không cần Đường Đất đến HQ |
| TN-04 | Ngựa | Không phổ biến | Đồng Bằng, Đồi Cỏ, Tundra | Viễn Chinh +2 bước nếu HQ trong bán kính 2 | Chuồng Ngựa: -2 Tín Ngưỡng chi phí Viễn Chinh |
| TN-05 | Quặng Lộ Thiên | Không phổ biến | Núi, Đồi Cỏ, Đồng Bằng | Tile +2 Kỹ Thuật khi ra KT; Hợp Kim tỷ lệ 1:1 | Phòng TN Vật Liệu: +1 Hợp Kim thụ động/vòng |
| TN-06 | Vàng Sa Khoáng | Hiếm | Sông, Bờ Biển, Đồng Bằng | Tile +3 Vàng khi ra Vàng; Chi Phối - 1 ngưỡng | Khu Chợ Cấp 2+: tỷ lệ đổi 1:1 mọi tài nguyên |
| TN-07 | Đá Thiêng | Hiếm | Núi, Rừng, Đồi Cỏ | Tile +2 Tín Ngưỡng khi ra TN; Đền Thờ miễn cooldown 1 lần/5 vòng | Thiên Đình: aura +1 ô nếu đặt trên tile này |
| TN-08 | Đất Màu Mỡ | Phổ biến | Đồng Bằng, Đồi Cỏ | +1 sản lượng cơ bản cho mọi công trình trên tile | Công trình Cấp 1 trên tile: -1 Kỹ Thuật chi phí xây |
| TN-09 | Suối Nước Nóng | Hiếm | Núi, Đồi Cỏ, Đồng Bằng | Tile liền kề: +1 Văn Hóa thụ động/vòng, không cần công trình | Đền Thờ Cấp 2+ kề: aura +1 Tín Ngưỡng bán kính 1 |
| TN-10 | Cảng Tự Nhiên | Không phổ biến | Bờ Biển | Giao Thương miễn phí Vàng/tile; Đơn vị +3 bước | Khu Chợ Cấp 1 hoạt động như Cấp 3 khi trên tile này |
| TN-11 | Gió Mạnh | Không phổ biến | Bờ Biển, Đồng Bằng, Tundra | Viễn Chinh +1 bước qua tile; Phiến Quân +2 bước ngẫu nhiên | Tháp Thiên Văn kề: aura +1 |
| TN-12 | Địa Linh | Rất hiếm | Bất kỳ (1-2 tile/ván) | Long Mạch +1 ô; công trình nhận sản lượng từ cả 2 viên xúc xắc | Đài Long Mạch: "Phát Sóng Toàn Cầu" 2 lần/3 vòng |

*Ghi chú thiết kế: các tài nguyên chiến lược không cần sở hữu để nhận bonus ô – với loại bonus "di chuyển", người chơi cũng không cần sở hữu tile. Phá dỡ công trình đã xây trên tài nguyên chiến lược sẽ làm mất tài nguyên và người chơi nhận thông báo về thay đổi này.*

### 3.3 Tài nguyên cốt lõi
Có 5 loại tài nguyên cốt lõi, mỗi loại phục vụ mục đích riêng biệt trong vòng kinh tế của game. Không có loại nào là "tốt nhất" – sức mạnh của từng loại thay đổi tùy theo chiến lược và trạng thái ván.

| Tài nguyên | Mặt xúc xắc | Chức năng chính |
|---|---|---|
| **Khoa Học** | Science | Dùng chủ yếu để Nghiên cứu Công Nghệ, xây công trình |
| **Văn Hóa** | Culture | Mua Sắc Lệnh, ảnh hưởng ngoại giao |
| **Kỹ Thuật** | Engineering | Xây dựng và nâng cấp công trình |
| **Tín Ngưỡng** | Faith | Kỹ năng nhân vật, hóa giải Phiến Quân |
| **Vàng** | Gold | Trao đổi đa năng, mua hầu hết thứ |

**Chiến thuật trọng tâm của 5 chỉ số:**
*   **Vàng (Động cơ Tài nguyên):** tích lũy sự giàu có để thao túng thị trường, mua đứt công trình.
*   **Khoa Học (Khai phá Tiềm năng):** nhiên liệu chính để nâng cấp cây công nghệ nhanh chóng.
*   **Kỹ Thuật (Kiểm soát Không gian):** tối ưu hóa hạ tầng trên hex, bành trướng lãnh thổ, xây và nâng cấp công trình.
*   **Văn Hóa (Quyền lực Mềm & Xâm lấn):** vũ khí ngoại giao, lan tỏa ảnh hưởng qua biên giới, mua Sắc Lệnh.
*   **Tín Ngưỡng (Đột biến & Phá vỡ Quy tắc):** can thiệp luật lệ, chống chịu thảm họa, kích hoạt kỹ năng nhân vật và hóa giải Phiến Quân.

*Cập nhật v1.2 – tài nguyên công nghiệp phụ trợ:* Hệ thống Hạ Tầng (mục 9) giới thiệu hai tài nguyên phụ mới – Than và Dầu Mỏ - khai thác từ Mỏ Than / Giếng Dầu để phục vụ luyện Thép và Đường Ray Xe Lửa. Đây là tài nguyên công nghiệp phụ trợ, quy đổi được sang tài nguyên cốt lõi, không thay thế 5 loại chính.

### 3.4 Xúc xắc
Hai viên xúc xắc, mỗi viên 6 mặt: 5 mặt tài nguyên (một mặt mỗi loại) + 1 mặt Hex trống. Mặt Hex trống luôn là mặt nút; các nút còn lại không mang nhiều ý nghĩa ngoài combat. Ký hiệu các mặt: Khoa Học (1), Văn Hóa (2), Kỹ Thuật (3), Tín Ngưỡng (4), Vàng (5), Hex (6).
*Lưu ý thiết kế: Mặt Hex trống (0) không sản xuất tài nguyên trực tiếp, nhưng cung cấp lợi thế khác (tuyên bố lãnh thổ, rút thẻ). Tỉ lệ 5:1 có thể điều chỉnh trong playtesting.*

### 3.5 Thẻ bài
Bốn bộ thẻ riêng biệt, mỗi bộ có cơ chế và thời điểm sử dụng khác nhau. Số lượng đã được chốt trong bản thiết kế bộ thẻ v1.2.

| Bộ thẻ | Số lượng (chốt) | Ai giữ | Khi nào dùng |
|---|---|---|---|
| **Công Nghệ** | 30 lá (5 trường phái × 6) | Người chơi | Mua bằng tài nguyên, dùng khi đủ điều kiện; mỗi thẻ 3 cấp nâng |
| **Sắc Lệnh** | 30 lá (10 Tức Thì / 10 Phản Ứng /10 Nội Tại) | Bí mật cá nhân | Khâu Hành Động, Khâu Giải Quyết, hoặc phản ứng |
| **Sự Kiện Tổng** | 20 lá (4 mốc x 5 lá) | Chồng bài chung | Tự động – mỗi 5 vòng lật 1 lá (vòng 5/10/15/20) |
| **Kỹ Năng** | 5 nhân vật x kỹ năng gốc + 4 ĐK Thắng | Gắn với nhân vật | Kỹ năng bị động hoặc kích hoạt |

---

## 4. Nhân vật
### 4.1 Vai trò nhân vật
Mỗi người chơi chọn một nhân vật trước khi bắt đầu ván (từ pool 3 nhân vật rút ngẫu nhiên). Nhân vật không thay đổi chiến lược một cách áp đặt, mà mở ra lộ trình chơi ưu thế. Mỗi nhân vật có 1 kỹ năng gốc bị động và 4 Điều Kiện Thắng riêng biệt.

### 4.2 Roster nhân vật (v1.2 – đầy đủ 5 nhân vật)

#### 1. Địa Sư (The Geomancer)
*   **Màu sắc phe:** Vàng
*   **Bản chất phe:** Bậc thầy phong thủy & địa lý. Tập trung kiểm soát Long Mạch tự nhiên, thâu tóm Danh thắng.
*   **Kỹ năng gốc:** Tuyên bố 1 tile không cần đổ ra mặt Hex (0) mỗi 3 vòng.
*   **4 Điều kiện thắng:**
    *   *Đại Long Mạch:* Kiểm soát chuỗi Lãnh thổ thực hữu liền mạch dài tối thiểu 12 tile nối thông suốt giữa hai đầu bản đồ hoặc đi qua trung tâm.
    *   *Tứ Tuyệt Danh Thắng:* Chi phối hoàn toàn từ 3 Danh thắng trở lên trên bản đồ cùng một lúc.
    *   *Phong Thủy Trấn Trạch:* Sở hữu từ 15 tile Lãnh thổ thực hữu trở lên, trong đó có ít nhất 3 công trình Cấp 3 trên các địa hình đặc trưng (Núi/Sông/Rừng).
    *   *Thánh Địa Tối Thượng:* Nâng cấp Nhà Chính (HQ) lên Cấp 5 tối đa và kích hoạt thành công 2 Thánh Địa không bị phong tỏa bởi Phiến Quân.

#### 2. Thương Nhân (The Merchant)
*   **Màu sắc phe:** Xanh dương
*   **Bản chất phe:** Nhà tài phiệt & thao túng dòng tiền. Tối ưu hóa mạng lưới giao thương.
*   **Kỹ năng gốc:** Đơn vị giao thương di chuyển nhanh hơn (+bước); giảm chi phí Vàng tiêu hao khi xây/di chuyển trên đường.
*   **4 Điều kiện thắng:**
    *   *Độc Quyền Giao Thương:* Thiết lập mạng lưới đường giao thương kết nối HQ của mình tới toàn bộ Khu Dân Cư / Thành Bang Tự Do trên bản đồ.
    *   *Kho Bạc Đế Vương:* Trữ đạt mốc 30 Vàng trong kho mà không bị âm tài nguyên ở bất kỳ vòng nào trong 3 vòng liên tiếp.
    *   *Bá Chủ Thị Trường:* Xây dựng và vận hành thành công 4 Cảng/Chợ thương mại; thu tối thiểu 10 Vàng tiền thuế phí giao thương từ đối thủ.
    *   *Mua Đứt Bản Đồ:* Bỏ Vàng và Văn Hóa để mua đứt quyền sở hữu vĩnh viễn 8 tile trực thuộc phạm vi ảnh hưởng của các đối thủ khác.

#### 3. Pháp Sư (The Arcanist)
*   **Màu sắc phe:** Xanh lá
*   **Bản chất phe:** Bậc thầy tâm linh & thao túng luật chơi. Sử dụng Sắc Lệnh bí mật, Cây Công Nghệ và Tín Ngưỡng để thay đổi cục diện.
*   **Kỹ năng gốc:** Rút thêm 1 thẻ Sắc Lệnh miễn phí mỗi khi mua thẻ.
*   **4 Điều kiện thắng:**
    *   *Thiên Mệnh Chi Đạo:* Kích hoạt thành công chuỗi 5 thẻ Sắc Lệnh (thuộc cả 3 nhóm Tức Thì, Phản Ứng và Nội Tại) trong cùng một ván đấu.
    *   *Đỉnh Cao Tri Thức:* Nghiên cứu mở khóa và nâng cấp tối đa (Cấp 3) toàn bộ 5 thẻ Công Nghệ đang kích hoạt trên bảng cá nhân.
    *   *Phổ Độ Chúng Sinh:* Tích lũy đạt 20 Tín Ngưỡng và chi phối hoàn toàn toàn bộ các ô Sông liền kề các Thành Bang Tự Do.
    *   *Bẻ Cong Luật Pháp:* Dùng Sắc Lệnh/Kỹ năng can thiệp hoặc miễn nhiễm thành công 3 kỳ Sự Kiện Tổng liên tiếp (ở các mốc vòng 5, 10, 15).

#### 4. Tướng Quân (The Warlord)
*   **Màu sắc phe:** Đỏ
*   **Bản chất phe:** Thế lực quân phiệt & chiến lược vùng cấm. Thao túng Phiến Quân, triển khai Đơn vị Viễn Chinh và phong tỏa bóp nghẹt tài nguyên đối phương.
*   **Kỹ năng gốc:** Có khả năng trực tiếp điều khiển/di dời Phiến Quân mà không cần đổ xúc xắc ra tổng số 7.
*   **4 Điều kiện thắng:**
    *   *Bao Vây Tiêu Diệt:* Dùng Phiến Quân hoặc Đơn vị Viễn Chinh phong tỏa hoàn toàn Vùng ảnh hưởng của ít nhất 2 HQ đối thủ trong 2 vòng liên tiếp.
    *   *Bình Định Loạn Quân:* Dùng Đơn vị Viễn Chinh hoặc kỹ năng tiêu diệt/hóa giải Phiến Quân 4 lần, đồng thời xây 3 Chốt Phòng Thủ trên biên giới.
    *   *Thôn Tính Thành Bang:* Chi phối bằng Đơn vị Viễn Chinh trên toàn bộ các Khu Dân Cư Tự Do / Thành Bang có mặt trên bản đồ.
    *   *Chiến Tranh Tiêu Hao:* Khiến các đối thủ mất tổng cộng 20 tài nguyên/vàng thông qua các đợt cướp phá của Phiến Quân do mình điều hướng.

#### 5. Học Sĩ (The Scholar / Bác Học) - MỚI trong v1.2
*   **Màu sắc phe:** Chưa định
*   **Bản chất phe:** Nhà phát minh, tri thức & nghiên cứu công nghệ.
*   **Kỹ năng gốc:** Tư Duy Đột Phá: giảm 1 Khoa Học khi mua bất kỳ thẻ Công Nghệ nào. Mỗi khi một người chơi khác kích hoạt thành công một Sự Kiện Tổng, Học Sĩ nhận ngay 1 Khoa Học miễn phí.
*   **4 Điều kiện thắng:**
    *   *Kỷ Nguyên Khai Sáng:* Mở khóa thành công 6 thẻ Công Nghệ khác nhau và nâng cấp ít nhất 3 thẻ lên Cấp 3.
    *   *Kỳ Quan Tri Thức:* Xây dựng và duy trì thành công một công trình Khoa Học Cấp 3 trên một ô Núi hoặc Danh Thắng trong 3 vòng liên tiếp mà không bị Phiến Quân phong tỏa.
    *   *Cộng Hưởng Long Mạch Tuyệt Đối:* Trong một lượt đổ xúc xắc (bất kể lượt ai), kích hoạt Long Mạch nhận cùng lúc từ 12 tài nguyên trở lên.
    *   *Độc Quyền Phát Minh:* Tích lũy đạt 20 Khoa Học trong kho và sở hữu trọn vẹn 1 nhánh trường phái Công Nghệ (mua và kích hoạt đủ cả 6 thẻ).

---

## 5. Core Loop
### 5.1 Vòng lặp tổng thể
| Lớp | Đơn vị | Nội dung chính | Tần suất |
|---|---|---|---|
| **Macro** | Ván chơi | Mở rộng lãnh thổ -> xây dựng kinh tế -> kết thúc với điểm cao nhất | 1 lần/ván |
| **Meso** | Vòng (Round) | 5 vòng = 1 Sự Kiện Tổng; 20 vòng = kết thúc ván | 4-20 lần/ván |
| **Micro** | Lượt (Turn) | Sản Xuất -> Giải Quyết -> Hành Động -> chuyển xúc xắc | 1-4 lần/vòng |

### 5.2 Khâu Sản Xuất (Long Mạch)
Khi Người A đổ được mặt Kỹ Thuật, không chỉ Người A được nhận. Người B và C có nhà máy kỹ thuật trong lãnh thổ của mình cũng được hưởng. Mặt Hex chỉ áp dụng cho người đang trong lượt.
**Công thức:** Sản lượng = Cấp độ công trình × Sản lượng cơ bản × Số viên xúc xắc khớp.
*   Đổ ra số 7 (tổng hai viên): không nhận tài nguyên, kích hoạt Phiến Quân.

### 5.3 Khâu Giải Quyết
Xử lý theo thứ tự:
1. Phiến Quân (nếu số 7).
2. Sự Kiện Tổng (nếu vòng 5, 10, 15, 20).
3. Thẻ Sắc Lệnh.
4. Kỹ năng nhân vật.

### 5.4 Khâu Hành Động
Hành động tự chọn: Trao đổi tài nguyên, Xây dựng - Nâng cấp & Dỡ bỏ, Tuyên bố Chi Phối, Xây đường giao thông và trade.

---

## 6. Hệ thống Phiến Quân
### 6.1 Vai trò thiết kế
Phiến Quân là yếu tố gây hỗn loạn có kiểm soát. Bắt buộc người chơi phải phản ứng.

### 6.2 Cơ chế
*   **Kích hoạt:** Đổ tổng 7 -> đổ thêm 1 viên xúc xắc (1-6) làm số bước di chuyển.
*   **Phong tỏa:** Phong tỏa ô đứng và 6 ô lân cận.
*   **Hiệu ứng khi dừng:**
    | Tile dừng | Hiệu ứng |
    |---|---|
    | Ô trống | Chỉ phong tỏa vùng xung quanh |
    | Ô có công trình của người khác | Chủ công trình bỏ phân nửa (ceil) tài nguyên nhiều nhất |
    | Ô có tài nguyên ngoài chủ | Người kích hoạt lấy phân nửa (ceil) tài nguyên bị cướp |

### 6.3 Cách đuổi Phiến Quân
Dùng Sắc Lệnh, Quân đội viễn chinh, Kỹ năng nhân vật, Công Trình Đặc Biệt (Pháo Đài Chiến Lược, Thiên Đình Tín Ngưỡng).

---

## 7. Hệ thống Lãnh thổ
### 7.1 Ba tầng kiểm soát
| Tầng | Điều kiện | Quyền năng |
|---|---|---|
| **Vùng ảnh hưởng** | Tile nằm trong bán kính 1 quanh HQ/Subsidiary | Thu tài nguyên, bỏ phiếu Chi Phối |
| **Tranh chấp** | Có phiếu nhưng chưa đủ ngưỡng | Chặn đối thủ claim; có thể mất nếu thua phiếu |
| **Lãnh thổ thực hữu** | Đủ phiếu theo ngưỡng khoảng cách | Xây dựng công trình, bảo vệ tài nguyên |

### 7.2 Tranh chấp lãnh thổ
Có thể mua Đơn vị Viễn Chinh (3 Tín Ngưỡng, 3 Vàng, 3 Kỹ Thuật) di chuyển 4 bước/vòng. Mua Khu Trực Thuộc (Subsidiary) để mở rộng vùng ảnh hưởng.

### 7.3 Đặt HQ & Khu Trực Thuộc
| Công trình | Điều kiện đặt | Tác dụng |
|---|---|---|
| **HQ (Nhà Chính)** | Không trên Núi/Sông; cách HQ/Sub khác >= 1 vòng chu vi; đủ 6 ô xung quanh | Vùng ảnh hưởng 7 tile (bản thân + 6 ô) |
| **Subsidiary** | Không trên Núi/Sông; cách HQ/Sub khác >= 1 vòng chu vi; đủ 6 ô xung quanh | Mở rộng vùng ảnh hưởng; giảm ngưỡng phiếu |

---

## 8. Hệ thống Công Trình
Hệ thống công trình có ba tầng: Cơ Bản -> Phái Sinh -> Đặc Biệt.

### 8.1 Công trình Cơ Bản (5 loại x 3 cấp)
| ID | Công trình | Tài nguyên | Địa hình | Cấp 1 | Cấp 2 | Cấp 3 |
|---|---|---|---|---|---|---|
| B-01 | Trại Khai Thác | Kỹ Thuật | Đồng Bằng, Núi | 1 ô, 2 KT+1V | 3 ô, 4 KT+2 KH+3V | 6 ô, 7 KT+4 KH+6V |
| B-02 | Viện Nghiên Cứu | Khoa Học | Đồng Bằng, Rừng | 1 ô, 2 KH+1V | 3 ô, 4 KH+2 KT+3V | 6 ô, 7 KH+3 KT+5V |
| B-03 | Nhà Văn Hóa | Văn Hóa | Đồng Bằng, Bờ Biển, Khu Dân Cư | 1 ô, 2 VH+1V | 2 ô, 3 VH+1 TN+2V | 4 ô, 5 VH+3 TN+4V |
| B-04 | Đền Thờ | Tín Ngưỡng | Đồng Bằng, Rừng, Sông | 1 ô, 2 TN+1V | 2 ô, 3 TN+2 VH+2V | 3 ô, 5 TN+3 VH+3V |
| B-05 | Khu Chợ | Vàng | Đồng Bằng, Bờ Biển, Khu Dân Cư | 1 ô, 3V+1 KT | 2 ô, 5V+3 KT | 3 ô, 8V+5 KT+2 VH |

### 8.2 Công trình Phái Sinh (5 loại)
Hình thành khi hai công trình đủ cấp đứng liền kề hoặc nối bằng Đường Đất.

| ID | Công trình -> Vật liệu | Công thức kết hợp |
|---|---|---|
| D-01 | Phòng TN Vật Liệu -> Hợp Kim | Trại Khai Thác C2+ ⇔ Viện NC C2+ |
| D-02 | Xưởng In Ấn -> Giấy | Nhà Văn Hóa C1+ ⇔ Trại Khai Thác C2+ |
| D-03 | Xưởng Luyện Kim -> Thép | Trại Khai Thác C3 ⇔ Đền Thờ C2+ |
| D-04 | Xưởng Dệt Lụa -> Lụa | Nhà Văn Hóa C2+ ⇔ Đền Thờ C2+ |
| D-05 | Nhà Ngân Hàng -> Tín Phiếu | Khu Chợ C2+ ⇔ Xưởng In Ấn |

### 8.3 Công trình Đặc Biệt (5 loại)
Yêu cầu vật liệu phái sinh và chiếm nhiều ô. Mỗi công trình phát ra Aura:
1.  **Tháp Quan Sát Thiên Văn [S-01]:** Xem trước xúc xắc, Aura bonus Khoa Học.
2.  **Pháo Đài Chiến Lược [S-02]:** Chặn Phiến Quân, phóng pháo hủy công trình đối thủ.
3.  **Bảo Tàng Quốc Gia [S-03]:** Token chi phối x1.5, thu Văn Hóa, bảo vệ khỏi Sắc lệnh Tức thì.
4.  **Đài Phát Thanh Long Mạch [S-04]:** Tăng bán kính Long Mạch, Phát Sóng Toàn Cầu.
5.  **Thiên Đình Tín Ngưỡng [S-05]:** Đẩy Phiến Quân, hủy tổng 7, "Niết Bàn" miễn nhiễm Sự Kiện Tổng.

---

## 9. Hệ thống Hạ Tầng
### 9.1 Cấp độ HQ & Khu Trực Thuộc
| Công trình | Cấp | Chi phí | Tác dụng |
|---|---|---|---|
| **HQ** | Cấp 1 | Miễn phí | Vùng ảnh hưởng 7 ô |
| | Cấp 2 | 4 KT + 2 KH + 3 V | Mở rộng vùng ảnh hưởng thêm 1 vòng |
| | Cấp 3 | 6 KT + 2 Hợp Kim + 5 V | Xây Công Trình Đặc Biệt |
| | Cấp 4 | 8 KT + 3 Thép + 8 V | Đơn vị Viễn Chinh lên Hiệp Sĩ |
| | Cấp 5 | 10 KT + 4 Thép + 4 Hợp Kim + 12 V | Aura thủ đô: +1 sản lượng cho nội đô |
| **Sub** | Cấp 1 | 3 TN + 3 V + 3 KT | Vùng ảnh hưởng 7 ô |
| | Cấp 2 | 4 KT + 3 V | Mở rộng ảnh hưởng, giảm ngưỡng Chi Phối |
| | Cấp 3 | 6 KT + 2 Thép + 5 V | Đô thị Vệ Tinh (miễn nhiễm phong tỏa tâm) |

### 9.2 Đường Giao Thông
*   Cấp 1: Đường Đất (1 Vàng/tile)
*   Cấp 2: Đường Lát Đá (1 KT + 1 Vàng/tile)
*   Cấp 3: Đường Ray Xe Lửa (1 Thép + 1 Than + 2 Vàng/tile)
*   Đường Ống Dẫn (1 Hợp Kim + 1 KT + 2 Vàng/tile) – đi ngầm qua Núi, Sông.

### 9.3 Khai khoáng & Năng lượng (Than, Dầu Mỏ)
*   **Mỏ Than (C1/C2):** Khai thác Than tại Núi, Đồi Cỏ.
*   **Giếng Dầu (C1/C2):** Khai thác Dầu Mỏ tại Sa Mạc, Đầm Lầy, Bờ Biển Nông.

### 9.4 Ma trận đặt công trình theo địa hình
*(Chi tiết việc đặt Trại khai thác, Viện nghiên cứu, Nhà Văn hóa, Đền thờ, Khu chợ theo từng địa hình – quy định rõ việc ưu tiên và cấm xây trên Núi/Sông/Khu DC).*

---

## 10. Hệ thống Sự Kiện & Thẻ bài
### 10.1 Cây Công Nghệ (30 thẻ)
5 trường phái: Kỹ Thuật, Khoa Học, Kinh Tế, Văn Hóa, Tín Ngưỡng (Mỗi trường phái 6 thẻ, 3 cấp nâng cấp).

### 10.2 Thẻ Sắc Lệnh (30 thẻ)
Mua bằng 2 VH + 2 KT + 2 Vàng. Bí mật cá nhân. Gồm 10 Tức Thì, 10 Phản Ứng, 10 Nội Tại.

### 10.3 Sự Kiện Tổng (20 thẻ)
Tự động lật mỗi 5 vòng. 4 mốc (Vòng 5, 10, 15, 20). Mức độ khốc liệt tăng dần.

---

## 11. Thiết lập & Kết thúc ván
### 11.1 Thiết lập
1. Ghép bản đồ (đảm bảo đủ 7 loại địa hình).
2. Đặt disc tài nguyên.
3. Xào 4 bộ bài.
4. Đặt Phiến Quân.
5. Đổ xúc xắc thứ tự.
6. Đặt HQ.
7. Chọn nhân vật.
8. Nhận tài nguyên khởi đầu.

### 11.2 Kết thúc ván (Tính điểm)
| Tiêu chí | Điểm (dự kiến) |
|---|---|
| Mỗi tile lãnh thổ thực hữu | 1 điểm |
| Mỗi Danh thắng đang chi phối | 3 điểm |
| Mỗi công trình Cấp 2+ | 2 điểm |
| Mỗi 5 tài nguyên còn dư | 1 điểm |
| Hoàn thành điều kiện thẻ đặc biệt | Theo thẻ |
| Hoàn thành 1 Điều Kiện Thắng nhân vật | Thắng ngay / điểm thưởng lớn |

---

## 12. Trải nghiệm người chơi & Lộ trình phát triển
*   **Đường cong học:** Dễ tiếp cận trong ván đầu (15 phút), sâu sắc từ ván 3-5 (Asymmetric play, đọc vị Sắc Lệnh).
*   **Tension points:** Đổ xúc xắc ra 7, tranh chấp tile cuối ván, lật Sự Kiện Tổng.
*   **Milestone (Lộ trình):** Sandbox (M0) -> Core Loop (M1) -> Buildings & Hạ Tầng (M1.5 - Đã xong v1.2) -> Cards (M2 - Đã xong v1.2) -> Characters (M3 - Đã xong v1.2) -> Polish (M4) -> Multiplayer (M5).

---
## Phụ lục A - Từ điển thuật ngữ
*   **Long Mạch:** Cơ chế chia sẻ sản lượng xúc xắc.
*   **HQ / Subsidiary:** Nhà chính / Khu trực thuộc mở rộng.
*   **Chi Phối (CP):** Token phiếu đặt lên tile.
*   **Phiến Quân:** Nhân vật trung lập phong tỏa 7 tile khi đứng.
*   **Sắc Lệnh / Sự Kiện Tổng:** Bài hành động.
*   **Công trình Phái Sinh / Đặc Biệt:** Hệ thống nâng cấp hạ tầng cấp cao.
*   **Điều Kiện Thắng:** 4 mục tiêu riêng gắn với mỗi nhân vật.
*   **Than / Dầu Mỏ:** Tài nguyên công nghiệp phụ trợ.

*(Tài liệu này được xuất lại theo yêu cầu giữ nguyên cấu trúc và không lược bỏ chi tiết của Perisol GDD v1.2).*
