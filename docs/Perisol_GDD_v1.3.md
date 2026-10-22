PERISOL

<p align="center">戊 地</p>

# *Game Design Document*

**Thể loại** · Chiến lược lãnh thổ theo lượt
**Nền tảng** · PC (Love2D / Lua)
**Phiên bản · 1.3 — Tài liệu lưu trữ nội bộ**

*Phiên bản 1.3 sau playtest đợt 1 của bản build Love2D: chuyển nền tảng từ Godot 4/C# sang Love2D (Lua); 6 ô quanh Nhà Chính là Lãnh thổ thực hữu miễn phí ngay từ đầu ván; giá mua tile đổi thành 2 Văn Hóa + 3 Vàng và tăng dần theo khoảng cách, cho phép mở rộng ra ngoài Vùng ảnh hưởng; sửa luật Phiến Quân (không vào ô Nhà Chính, cướp phá khi bước lên công trình, Lệnh Đuổi Phiến Quân); chốt Lãnh Nguyên "−1 Kỹ Thuật" là ưu đãi; thêm yêu cầu giao diện và kết quả playtest. Phiên bản 1.3 bổ sung hệ chiếm đóng công trình bằng Bộ Binh theo kiểu Advance Wars (mục 7.4), chốt công trình đi theo tile khi đổi chủ và Khu Trực Thuộc không được tặng ô miễn phí. Phiên bản 1.6 khóa việc xây trên Sông (và Hồ/Biển) cho tới khi mở khóa, đặt số vòng mặc định theo số người chơi, và thêm mục Hệ chiến đấu dự thảo tham chiếu Advance Wars (mục 7.5).*

---

## 1. Tổng quan trò chơi

### 1.1 Elevator Pitch
Perisol là game chiến lược lãnh thổ theo lượt cho 1–4 người chơi, lấy cảm hứng từ các trò chơi chiến thuật quản lý tài nguyên. Trên một bản đồ ô lưới lục giác, các phe tranh nhau kiểm soát ảnh hưởng thông qua Sản Xuất Chung — cơ chế mọi người cùng hưởng kết quả xúc xắc — trong khi mở rộng lãnh thổ, xây dựng công trình và dùng Sắc Lệnh bí mật để lật ngược cục diện.

### 1.2 Thông tin dự án
| Trường | Nội dung |
|---|---|
| Tên dự án | Perisol |
| Thể loại | Turn-based, strategy |
| Số người chơi | 1 – 4 (local hot-seat, mở rộng online sau) |
| Thời gian ván | Số vòng mặc định = 10 × số người chơi (2 người: 20 vòng, 3 người: 30, 4 người: 40; 1 người: 10), tùy chỉnh theo bội của 10, không giới hạn trên. Thời lượng cần đo lại (playtest #1: 20 vòng mất 10–15 phút cho 2 người, mỗi người thêm +10 phút) |
| Nền tảng | PC — Love2D (Lua) |
| Trạng thái | Prototype Love2D đã chơi được — xong playtest đợt 1; đang thiết kế lớp chiếm đóng bằng Bộ Binh, cân bằng kinh tế đầu ván và luật Phiến Quân |
| Phiên bản GDD | 1.6 |

### 1.3 Mục tiêu thiết kế
- Bản đồ sinh ngẫu nhiên mỗi ván — người chơi đọc được địa thế, lập kế hoạch. Mọi địa hình đều mang ý nghĩa chiến lược: núi chặn đường đi nhưng cho điểm Kỹ Thuật và Khoa Học; Sông ban đầu không thể xây gì (chỉ sau khi mở khóa mới xây được Đền Thờ) nhưng tạo biên tự nhiên và tăng giá trị tín ngưỡng ô xung quanh; danh thắng là điểm nóng tranh chấp.
- Rủi ro có cấu trúc — xúc xắc tạo biến động nhưng người chơi có nhiều công cụ để giảm thiểu hoặc tận dụng. Phiến Quân là mối đe dọa nhưng người thông minh biến nó thành vũ khí nhắm vào đối thủ. Thẻ Sắc Lệnh là lớp kiểm soát thứ hai.
- Mỗi lượt đều có sức nặng. Không có lượt "đợi cho xong". Cơ chế Sản Xuất Chung đảm bảo mọi người đều tham gia vào kết quả xúc xắc — dù không phải lượt của mình.

### 1.4 Tham chiếu
| Yếu tố | Tham chiếu |
|---|---|
| Cơ chế lục giác | Catan (hex map, resource production) |
| Vòng lượt động | Agricola (mọi hành động đều có chi phí cơ hội) |
| Lãnh thổ tầng lớp | Twilight Imperium (influence vs ownership) |
| Xúc xắc định nghĩa | King of Tokyo (custom dice faces) |
| Phong thủy / chủ đề | Original IP — không có tham chiếu trực tiếp |
| Chiến đấu & chiếm công trình | Advance Wars (HP thang 10/100%, chiếm công trình 20 điểm, khắc chế đơn vị, địa hình cộng phòng thủ) — mục 7.4, 7.5 |

## 2. Thế giới & Chủ đề

### 2.1 Bối cảnh
Trong phong thủy, địa mạch là những đường khí thiêng chạy dọc theo địa thế núi sông, quyết định vận số của đất đai và con người sống trên đó. Trong game, ý niệm này được thể hiện bằng cơ chế Sản Xuất Chung: mỗi lần xúc xắc được đổ, "khí đất" tỏa ra khắp bản đồ — không chỉ người đổ mà mọi phe có đất hoặc công trình phù hợp đều nhận được sản lượng. Mỗi ô đất còn mang sẵn những nguồn tài nguyên tự nhiên của riêng nó (mục 3.3).

Năm phe không được đặt tên cụ thể — họ là những thế lực mang màu sắc văn hóa trừu tượng, cạnh tranh để thiết lập trụ sở trên vùng đất giàu tài nguyên nhất và bành trướng ảnh hưởng trước khi đối thủ kịp ổn định.

### 2.2 Tone
| Chiều | Hướng tới | Tránh |
|---|---|---|
| Hình ảnh | Hoạt hình, 2D top-down | Tả thực, màu quá u tối |
| Âm thanh | Nhạc tiết tấu vui tươi, hơi nhanh | OST hành động ồn ào |
| Cảm xúc | Tập trung, cân nhắc, thưởng thức | Căng thẳng nhịp độ cao |
| Độ phức tạp | Trung bình — học được trong 1 ván | Cần rulebook 20 trang để bắt đầu |

## 3. Thành phần & Không gian chơi

### 3.1 Bản đồ lục giác
Kích thước bản đồ đảm bảo mỗi người chơi có một vùng an toàn quanh HQ gồm 19 ô (HQ + 2 vòng ô bao quanh, tức bán kính 2 ô tính từ tâm), không bị người chơi khác lấn sớm. Mỗi ván phải đảm bảo đủ 7 kiểu địa hình được rút ra từ bộ 12 loại địa hình đã thiết kế (xem bảng dưới).

Mặc định tỉ lệ map 16:8; bản đồ cơ bản cho 4 người chơi đảm bảo 32:16 tile.

> **Cập nhật v1.2**
> Bộ địa hình mở rộng từ 7 lên 12 loại (bổ sung Lãnh Nguyên, Sa Mạc, Đầm Lầy, Đồi Cỏ, Núi Tuyết) để tăng biến thiên giữa các ván. Luật "mỗi ván đủ 7 kiểu địa hình" vẫn giữ nguyên — 7 loại được rút ngẫu nhiên từ bộ 12.

| ID | Địa hình | HQ/Sub | Công trình | CT Đặc Biệt | Di chuyển | Ghi chú |
|---|---|---|---|---|---|---|
| DH-01 | Đồng Bằng | ✅ | ✅ | ❌ | Bình thường | Tile cơ bản, không penalty |
| DH-02 | Rừng | ✅ | ✅ | ✅ | −1 bước | Đền Thờ, Viện NC ưu tiên (⭐): giảm 1 tài nguyên chính khi xây Cấp 1 (xem 9.4) |
| DH-03 | Núi | ❌ | Hạn chế | ✅ | Không đi được | Chỉ Trại Khai Thác (từ Cấp 2), Mỏ Than và CT Đặc Biệt (kể cả Pháo Đài); không đặt HQ/Sub. Phiến Quân vào Núi (sau khi hết khóa) tốn 3 bước |
| DH-04 | Sông | ❌ | 🔒 Khóa (mở bằng nghiên cứu) | 🔒 Khóa (mở bằng nghiên cứu) | −1 bước | Ban đầu không xây được công trình nào. Sau khi mở khóa (nghiên cứu/nâng cấp; đề xuất gắn vào thẻ Công Nghệ Tuyến Vận Tải Nước) mới xây được Đền Thờ và Thiên Đàn như cũ (Xưởng Dệt Lụa là công trình Phái Sinh, không đặt trực tiếp); không đặt HQ/Sub. Hồ (ô nước nội địa) áp dụng như Sông; Biển cần Cảng (mục 8.4) |
| DH-05 | Bờ Biển | ✅ | ✅ | ✅ | Bình thường | Khu Chợ Cấp 3 miễn Đơn Vị Giao Thương |
| DH-06 | Lãnh Nguyên | ✅ | ✅ | ❌ | Bình thường | Ưu đãi: chi phí xây công trình trên ô −1 Kỹ Thuật (chỉ giảm khoản KT, tối thiểu 0). Đánh đổi: sản lượng Vàng của công trình trên ô −1 (tối thiểu 0) |
| DH-07 | Sa Mạc | ✅ | ✅ | ❌ | Bình thường | Không sản xuất Tín Ngưỡng |
| DH-08 | Đầm Lầy | ❌ | ✅ | ❌ | −1 bước | Không đặt HQ; Tài Nguyên Cơ Bản thiên về Tín Ngưỡng (45%) & Văn Hóa (40%) — xem 3.3 |
| DH-09 | Đồi Cỏ | ✅ | ✅ | ✅ | Bình thường | Trại Khai Thác Cấp 2 +1 Kỹ Thuật |
| DH-10 | Khu Dân Cư | ❌ | Hạn chế | Hạn chế | Bình thường | Chi Phối; cho điểm cuối ván; cụm 2–10 tile, >7 thành Thành Bang Tự Do; chỉ xây Nhà Văn Hóa, Khu Chợ C1–C2 và Bảo Tàng Quốc Gia (S-03) |
| DH-11 | Danh Thắng | ❌ | ❌ | ❌ | Bình thường | Chỉ Chi Phối; 3 điểm cuối ván; 4 kiểu hình (1 ô / 2 ô liền / tam giác 3 ô / tứ giác 4 ô); mỗi Danh Thắng gắn 1 loại Tài Nguyên Cơ Bản và phát aura (xem 3.3) |
| DH-12 | Núi Tuyết | ❌ | ❌ | ✅ | Không đi được | Hoạt động như Núi |

Khu Dân Cư Tự Do và Danh Thắng: số lượng khu dân cư và số danh thắng trên bản đồ đều bằng số người chơi + 1. Danh Thắng chỉ cho phép Chi Phối (không xây dựng); Khu Dân Cư cho phép Chi Phối và một số ít công trình (xem bảng trên và ma trận mục 9.4).

### 3.2 Tài nguyên cốt lõi
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

### 3.3 Tài nguyên cơ bản trên tile
Mỗi tile (trừ Danh Thắng — xem ghi chú dưới bảng) mang sẵn từ 0 đến vài loại Tài Nguyên Cơ Bản (CB) thuộc 5 tài nguyên cốt lõi: Khoa Học (KH), Văn Hóa (VH), Kỹ Thuật (KT), Tín Ngưỡng (TN) và Vàng (V). Đây là lớp nền của bản đồ: tile càng giàu TNCB càng đáng tranh chấp. TNCB độc lập với công trình và với Tài Nguyên Chiến Lược (mục 3.4).

**Quy tắc sinh khi tạo bản đồ:**
- Mỗi tile tung xác suất riêng cho từng loại trong 5 loại tài nguyên theo bảng bên dưới (tỉ lệ xuất hiện tính độc lập). Ô ghi "—" nghĩa là địa hình đó không có loại tài nguyên ấy.
- Loại nào xuất hiện thì có lượng 1 hoặc 2 (mặc định 70% ra 1, 30% ra 2; ngoại lệ ghi dưới bảng).
- Vì tung độc lập nên số loại trên một tile dao động từ 0 đến số loại địa hình cho phép. Với bảng này khoảng 95–99% tile chỉ có 0–2 loại; tile có 3 loại trở lên là "tile giàu" hiếm (khoảng 1–5% tùy địa hình). Tham số MaxKindsPerTile (mặc định: không giới hạn) cho phép khóa cứng, ví dụ đặt 2 để mọi tile tối đa 2 loại (loại dư bị bỏ ngẫu nhiên).
- Mức 1–2 chỉ áp dụng lúc sinh bản đồ. Sau đó lượng CB của tile có thể tăng không giới hạn nhờ công trình, aura Danh Thắng, Tài Nguyên Chiến Lược và hiệu ứng thẻ (xem "Nguồn cộng dồn").

| Địa hình | KH | VH | KT | TN | Vàng | Số loại TB | Tile trống |
|---|---|---|---|---|---|---|---|
| Đồng Bằng | — | 20% | 30% | 15% | 25% | 0,90 | 36% |
| Rừng | 25% | 10% | 15% | 30% | — | 0,80 | 40% |
| Núi | 35% | — | 45% | 10% | 15% | 1,05 | 27% |
| Sông | — | 15% | — | 35% | 20% | 0,70 | 44% |
| Bờ Biển | 10% | 20% | 10% | 10% | 40% | 0,90 | 35% |
| Lãnh Nguyên | 10% | 5% | 20% | 15% | 10% | 0,60 | 52% |
| Sa Mạc | 20% | 5% | 25% | — | 30% | 0,80 | 40% |
| Đầm Lầy | 15% | 40% | 10% | 45% | — | 1,10 | 25% |
| Đồi Cỏ | 10% | 20% | 35% | 15% | 20% | 1,00 | 32% |
| Khu Dân Cư | — | 50% | — | 20% | 40% | 1,10 | 24% |
| Núi Tuyết | 40% | — | 30% | 15% | 10% | 0,95 | 32% |

Ngoại lệ: Đầm Lầy — TN và VH ra lượng 2 với xác suất 40% (thay vì 30%); Lãnh Nguyên — Vàng luôn chỉ ra 1. Hiệu ứng kề: sau khi đặt địa hình, mọi tile kề Sông được +10 điểm phần trăm xác suất TN. Mỗi Danh Thắng gắn cố định 1 loại TNCB theo chỉ định của danh sách các loại danh thắng, mỗi tile của nó có lượng loại đó.

Ví dụ: tile Đồng Bằng tọa độ (0,1) sau khi sinh có VH 1, KT 2, TN 1, Vàng 0 (lần tung Vàng không trúng), KH 0 (Đồng Bằng không có KH). Tile này có 3 loại nên thuộc nhóm "tile giàu" hiếm (khoảng 4% tile Đồng Bằng).

**Quy tắc thu hoạch:**
- Khi xúc xắc ra mặt tài nguyên X (Sản Xuất Chung, mục 5.2), mỗi tile có CB loại X nhả đúng lượng ghi trên tile cho người có quyền thu hoạch tile đó, nhân với số viên khớp. Mặt Hex và tổng 7 không thu hoạch.
- Quyền thu hoạch thuộc về: (1) chủ tile (Lãnh thổ thực hữu); (2) nếu tile chưa có chủ và chỉ nằm trong Vùng ảnh hưởng của đúng một người chơi thì thuộc người đó; (3) nếu chưa có chủ mà nhiều người cùng ảnh hưởng, hoặc không ai có ảnh hưởng, thì chưa ai thu hoạch được — tile trở thành mục tiêu tranh phiếu.
- CB độc lập với công trình: xây hay dỡ công trình không làm mất CB (chỉ Tài Nguyên Chiến Lược bị mất khi dỡ, mục 3.4). Công trình nhiều ô thu hoạch CB của mọi tile nó chiếm, đồng thời vẫn sản xuất bình thường — hai nguồn cộng dồn.
- Phiến Quân phong tỏa chặn cả công trình lẫn CB trong vùng (mục 6.2). Khi Phiến Quân dừng trên tile chưa có chủ nhưng có CB, áp dụng dòng tương ứng ở bảng 6.2.
- Khởi đầu ván: 6 ô quanh HQ là Lãnh thổ thực hữu miễn phí (mục 7.3); mỗi người nhận 1 lần toàn bộ CB của 6 ô đó làm tài nguyên khởi đầu (mục 11.1), và 6 ô này tiếp tục thu hoạch CB mỗi khi xúc xắc khớp.

**Nguồn cộng dồn (không giới hạn):**
- Tài Nguyên Chiến Lược (mục 3.4): các dòng "+x [loại] khi ra [loại]" cộng thẳng vào lượng CB cùng loại của tile, kể cả khi tile vốn không có loại đó.
- Cộng hưởng công trình (đề xuất, cần test): công trình Cơ Bản sản xuất loại X đặt lên tile đã có CB loại X thì CB đó +1 trên mỗi tile công trình chiếm. Không tạo CB mới cho tile chưa có.
- Aura Danh Thắng (đề xuất, cần test): người đang Chi Phối hoàn toàn một Danh Thắng được +1 CB cùng loại với Danh Thắng đó trên mỗi tile của mình trong bán kính 2 quanh Danh Thắng (kể cả tile chưa có loại đó).
- Công Nghệ, Sắc Lệnh, Sự Kiện Tổng và Công Trình Đặc Biệt có thể cộng hoặc trừ lượng CB theo nội dung từng thẻ / công trình.

> **Lưu ý cân bằng — chờ playtest**
> Ước tính sơ bộ: mỗi tile có trung bình khoảng 0,6–1,1 loại CB (khoảng 0,8–1,4 đơn vị); 6 ô quanh HQ cho khoảng 5–8 đơn vị. Mỗi đơn vị CB nhận được khi mặt xúc xắc khớp, kỳ vọng 2N/6 lần mỗi vòng với N người chơi, tức khoảng 4–9 tài nguyên/vòng từ vùng khởi đầu nếu tile đã có chủ. Nguồn này giúp kéo kinh tế lên kịp mốc Nhà Chính Cấp 3 và Công Trình Đặc Biệt trong 20 vòng. Nếu playtest thấy quá nhanh, giảm xác suất toàn bảng thay vì sửa từng công trình.
> Playtest #1: bản build chưa có CB mặc định trên tile nên mỗi người chỉ mở rộng được khoảng 6–7 ô sau 20 vòng (không đủ nhanh). v1.4 xử lý bằng 3 thay đổi cùng lúc: 6 ô thực hữu khởi đầu, CB trên tile, và giá mua ô tăng dần (mục 7.2). Cần test lại cả ba cùng nhau vì giá mua mới đắt hơn bản cũ (2 VH + 3 V thay vì 1 VH + 1 V).

### 3.4 Tài nguyên chiến lược (bonus theo tile)
Ngoài loại địa hình, mỗi tile có thể mang một Tài Nguyên Chiến Lược — một lớp bonus hiếm không cần sở hữu để hưởng bonus ô, nhưng cần sở hữu để hưởng bonus công trình. Đây là lớp thiết kế mới bổ sung trong v1.2, làm phong phú giá trị chiến lược của từng ô đất. Tài Nguyên Chiến Lược nằm trên lớp Tài Nguyên Cơ Bản (mục 3.3): các dòng "+x [loại] khi ra [loại]" cộng thẳng vào lượng Tài Nguyên Cơ Bản cùng loại của tile, kể cả khi tile vốn không có loại đó.

| ID | Tên | Rarity | Địa hình xuất hiện | Bonus ô (không cần sở hữu) | Bonus công trình (cần sở hữu) |
|---|---|---|---|---|---|
| TN-01 | Đá Granite | Phổ biến | Núi, Đồi Cỏ | Tile +1 Kỹ Thuật bổ sung khi xúc xắc ra KT | Pháo Đài: −2 Kỹ Thuật chi phí xây |
| TN-02 | Rừng Cổ Thụ | Phổ biến | Rừng | +1 Tín Ngưỡng và +1 Khoa Học thụ động/vòng | Thiên Đàn: bỏ yêu cầu địa hình Rừng |
| TN-03 | Cá | Phổ biến | Bờ Biển, Sông | Khu Chợ +2 Vàng khi ra Vàng; kết nối HQ ảo | Khu Chợ: không cần Đường Đất đến HQ |
| TN-04 | Ngựa | Không phổ biến | Đồng Bằng, Đồi Cỏ, Lãnh Nguyên | Viễn Chinh +2 bước nếu HQ trong bán kính 2 | Chưa có công trình áp dụng (dự kiến Phase 2: Chuồng Ngựa) |
| TN-05 | Quặng Lộ Thiên | Không phổ biến | Núi, Đồi Cỏ, Đồng Bằng | Tile +2 Kỹ Thuật khi ra KT; Hợp Kim tỷ lệ 1:1 | Phòng TN Vật Liệu: +1 Hợp Kim thụ động/vòng |
| TN-06 | Vàng Sa Khoáng | Hiếm | Sông, Bờ Biển, Đồng Bằng | Tile +3 Vàng khi ra Vàng; Chi Phối −1 ngưỡng | Khu Chợ Cấp 2+: tỷ lệ đổi 1:1 mọi tài nguyên |
| TN-07 | Đá Thiêng | Hiếm | Núi, Rừng, Đồi Cỏ | Tile +2 Tín Ngưỡng khi ra TN | Thiên Đàn: aura +1 ô nếu đặt trên tile này; Đền Thờ: +1 Tín Ngưỡng thụ động/vòng |
| TN-08 | Đất Màu Mỡ | Phổ biến | Đồng Bằng, Đồi Cỏ | +1 sản lượng cơ bản cho mọi công trình trên tile | Công trình Cấp 1 trên tile: −1 Kỹ Thuật chi phí xây |
| TN-09 | Suối Nước Nóng | Hiếm | Núi, Đồi Cỏ, Đồng Bằng | Tile liền kề: +1 Văn Hóa thụ động/vòng, không cần công trình | Đền Thờ Cấp 2+ kề: aura +1 Tín Ngưỡng bán kính 1 |
| TN-10 | Cảng Tự Nhiên | Không phổ biến | Bờ Biển | Giao Thương miễn phí Vàng/tile; Đơn vị +3 bước | Khu Chợ Cấp 1 hoạt động như Cấp 3 khi trên tile này |
| TN-11 | Gió Mạnh | Không phổ biến | Bờ Biển, Đồng Bằng, Lãnh Nguyên | Viễn Chinh +1 bước qua tile; Phiến Quân +2 bước ngẫu nhiên | Tháp Quan Sát Thiên Văn (S-01) kề: aura +1 ô |
| TN-12 | Địa Linh | Rất hiếm | Bất kỳ (1–2 tile/ván) | Mỗi viên xúc xắc ra Hex (⬡), chủ tile được chọn cho nó thay thế 1 loại tài nguyên mà công trình hoặc Tài Nguyên Cơ Bản trên tile này sản xuất (kể cả ngoài lượt của chủ; Hex vẫn cho phiếu Chi Phối nếu đang trong lượt) | Đài Khí Tượng: chu kỳ đổ lại xúc xắc giảm 1 vòng (5→4, 3→2) |

Ghi chú thiết kế: các tài nguyên chiến lược không cần sở hữu để nhận bonus ô — với loại bonus "di chuyển", người chơi cũng không cần sở hữu tile. Phá dỡ công trình đã xây trên tài nguyên chiến lược sẽ làm mất tài nguyên và người chơi nhận thông báo về thay đổi này.

### 3.5 Xúc xắc
Hai viên xúc xắc, mỗi viên 6 mặt: 5 mặt tài nguyên (một mặt mỗi loại) + 1 mặt Hex trống. Số ghi trên mỗi mặt chỉ dùng để cộng tổng khi xét số 7 (kích hoạt Phiến Quân). Ký hiệu các mặt: Khoa Học (1), Văn Hóa (2), Kỹ Thuật (3), Tín Ngưỡng (4), Vàng (5), Hex (6).

> **Lưu ý thiết kế**
> Mặt Hex trống (⬡) không sản xuất tài nguyên trực tiếp, nhưng cung cấp lợi thế khác (phiếu Chi Phối để tuyên bố lãnh thổ). Tỉ lệ 4:1 có thể điều chỉnh trong playtesting.

### 3.6 Thẻ bài
Bốn bộ thẻ riêng biệt, mỗi bộ có cơ chế và thời điểm sử dụng khác nhau. Số lượng đã được chốt trong bản thiết kế bộ thẻ v1.2 (xem mục 10 và tài liệu Perisol_Cards_v1.2 để có danh sách đầy đủ 80 thẻ).

| Bộ thẻ | Số lượng (chốt) | Ai giữ | Khi nào dùng |
|---|---|---|---|
| Công Nghệ | 30 lá (5 trường phái × 6) | Người chơi | Mua bằng tài nguyên, dùng khi đủ điều kiện; mỗi thẻ 3 cấp nâng |
| Sắc Lệnh | 30 lá (10 Tức Thì / 10 Phản Ứng / 10 Nội Tại) | Bí mật cá nhân; đối thủ biết số lượng, không biết nội dung | Khâu Hành Động, Khâu Giải Quyết, hoặc phản ứng |
| Sự Kiện Tổng | 20 lá (4 mốc × 5 lá) | Chồng bài chung | Tự động — mỗi 5 vòng lật 1 lá (vòng 5, 10, 15…; mức khốc liệt theo tiến độ ván, mục 11.3) |
| Kỹ Năng | 5 nhân vật × kỹ năng gốc + 4 điều kiện thắng riêng | Gắn với nhân vật | Kỹ năng bị động hoặc kích hoạt |

## 4. Nhân vật

### 4.1 Vai trò nhân vật
Mỗi người chơi chọn một nhân vật trước khi bắt đầu ván (từ pool 3 nhân vật được rút ngẫu nhiên trong Khâu Thiết Lập). Nhân vật không thay đổi chiến lược một cách áp đặt, mà mở ra một lộ trình chơi ưu thế — người chơi vẫn tự do đi theo hướng khác, nhưng sẽ không tối ưu bằng. Mỗi nhân vật có 1 kỹ năng gốc bị động và 4 Điều Kiện Thắng riêng biệt gắn với bản chất phe của họ.

### 4.2 Roster nhân vật

> **Trạng thái thiết kế**
> So với v1.1 (4 nhân vật placeholder chờ art/concept), v1.2 chốt roster ở 5 nhân vật với kỹ năng gốc và 4 điều kiện thắng riêng biệt mỗi nhân vật, đã sẵn sàng cho playtesting cân bằng. Số nhân vật có thể mở rộng thêm 6–8 trong tương lai để tăng tính chơi lại.

#### 1. Địa Sư (The Geomancer)
**Màu sắc phe:** Vàng

**Bản chất phe:** Bậc thầy phong thủy & địa lý. Tập trung kiểm soát địa thế, thâu tóm các Danh thắng và kết nối các vùng đất thành chuỗi lãnh thổ dài.

**Kỹ năng gốc:** Tuyên bố 1 tile không cần đổ ra mặt Hex (⬡) mỗi 3 vòng.

**4 Điều kiện thắng:**

| Điều kiện | Mô tả |
|---|---|
| Xuyên Lục Địa (The Great Chain) | Kiểm soát chuỗi Lãnh thổ thực hữu liền mạch dài tối thiểu 12 tile nối thông suốt giữa hai đầu bản đồ hoặc đi qua trung tâm. |
| Tứ Tuyệt Danh Thắng (Scenic Dominance) | Chi phối hoàn toàn từ 3 Danh thắng trở lên trên bản đồ cùng một lúc. |
| Phong Thủy Trấn Trạch (Hex Supremacy) | Sở hữu từ 15 tile Lãnh thổ thực hữu trở lên, trong đó có ít nhất 3 công trình Cấp 3 trên các địa hình đặc trưng (Núi/Sông/Rừng). |
| Thánh Địa Tối Thượng (Sanctuary of Earth) | Nâng cấp Nhà Chính (HQ) lên Cấp 5 tối đa và sở hữu 2 Công Trình Đặc Biệt đang hoạt động, không bị Phiến Quân phong tỏa. |

#### 2. Thương Nhân (The Merchant)
**Màu sắc phe:** Xanh dương

**Bản chất phe:** Nhà tài phiệt & thao túng dòng tiền. Tối ưu hóa mạng lưới giao thương, bòn rút phí thông quan và kiểm soát thị trường các Thành Bang Tự Do.

**Kỹ năng gốc:** Đơn vị giao thương di chuyển nhanh hơn (+bước); giảm chi phí Vàng tiêu hao khi xây/di chuyển trên đường.

**4 Điều kiện thắng:**

| Điều kiện | Mô tả |
|---|---|
| Độc Quyền Giao Thương (Trade Monopoly) | Thiết lập mạng lưới đường giao thương kết nối HQ của mình tới toàn bộ Khu Dân Cư / Thành Bang Tự Do trên bản đồ. |
| Kho Bạc Đế Vương (Golden Vault) | Trữ đạt mốc 30 Vàng trong kho mà không bị âm tài nguyên ở bất kỳ vòng nào trong 3 vòng liên tiếp. |
| Bá Chủ Thị Trường (Commercial Nexus) | Xây dựng và vận hành thành công 4 Khu Chợ; thu tối thiểu 10 Vàng tiền thuế/phí giao thương từ đối thủ. |
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
| Bình Định Loạn Quân (Subjugation) | Dùng Đơn vị Viễn Chinh hoặc kỹ năng đẩy lui/hóa giải Phiến Quân 4 lần, đồng thời sở hữu ít nhất 1 Pháo Đài Chiến Lược (S-02). |
| Thôn Tính Thành Bang (Subjugate Free States) | Chi phối bằng Đơn vị Viễn Chinh trên toàn bộ các Khu Dân Cư Tự Do / Thành Bang có mặt trên bản đồ. |
| Chiến Tranh Tiêu Hao (Economic Strangulation) | Khiến các đối thủ mất tổng cộng 20 tài nguyên/vàng thông qua các đợt cướp phá của Phiến Quân do mình điều hướng. |

#### 5. Học Sĩ (The Scholar / Bác Học)
**Màu sắc phe:** Chưa định

**Bản chất phe:** Nhà phát minh, tri thức & nghiên cứu công nghệ. Tập trung tối ưu hóa nhánh Khoa Học, tăng tốc độ mở khóa Cây Công Nghệ và khai thác Sản Xuất Chung để thu tài nguyên vượt trội từ cả xúc xắc của đối thủ.

**Kỹ năng gốc:** Tư Duy Đột Phá: giảm 1 Khoa Học khi mua bất kỳ thẻ Công Nghệ nào. Mỗi khi một Sự Kiện Tổng được lật, Học Sĩ nhận ngay 1 Khoa Học miễn phí.

**4 Điều kiện thắng:**

| Điều kiện | Mô tả |
|---|---|
| Kỷ Nguyên Khai Sáng (The Age of Enlightenment) | Mở khóa thành công 6 thẻ Công Nghệ khác nhau và nâng cấp ít nhất 3 thẻ lên Cấp 3 (Cấp tối đa). |
| Kỳ Quan Tri Thức (The Great Observatory) | Xây dựng và duy trì thành công một công trình Khoa Học Cấp 3 trên một ô Núi hoặc Danh Thắng trong 3 vòng liên tiếp mà không bị Phiến Quân phong tỏa. |
| Cộng Hưởng Tuyệt Đối (Absolute Resonance) | Trong một lượt đổ xúc xắc (bất kể là lượt của mình hay đối thủ), nhận cùng lúc từ 12 tài nguyên trở lên từ Sản Xuất Chung (cộng cả công trình lẫn tile Tài Nguyên Cơ Bản) nhờ mạng lưới dày đặc. |
| Độc Quyền Phát Minh (Intellectual Monopoly) | Tích lũy đạt 20 Khoa Học trong kho và sở hữu trọn vẹn 1 nhánh trường phái Công Nghệ (mua và kích hoạt đủ cả 6 thẻ của trường phái đó). |

## 5. Core Loop

### 5.1 Vòng lặp tổng thể
Một ván chơi diễn ra theo vòng lặp ba lớp:

| Lớp | Đơn vị | Nội dung chính | Tần suất |
|---|---|---|---|
| Macro | Ván chơi | Mở rộng lãnh thổ → xây dựng kinh tế → kết thúc với điểm cao nhất | 1 lần/ván |
| Meso | Vòng (Round) | 5 vòng = 1 Sự Kiện Tổng; kết thúc sau N vòng (mục 11.3) | N vòng/ván (mục 11.3) |
| Micro | Lượt (Turn) | Sản Xuất → Giải Quyết → Hành Động → chuyển xúc xắc | 1–4 lần/vòng |

### 5.2 Khâu Sản Xuất
Người chơi đổ hai viên xúc xắc. Kết quả kích hoạt sản xuất cho mọi người chơi có công trình hoặc tile Tài Nguyên Cơ Bản thuộc loại tài nguyên tương ứng — đây là cơ chế Sản Xuất Chung. Bản digital tự động đổ xúc xắc khi bắt đầu lượt, người chơi không cần bấm Space; mỗi tile nhận tài nguyên hiện popup +x, kể cả ở lượt người khác (mục 12.4).

> **Cơ chế Sản Xuất Chung**
> Kết quả xúc xắc áp dụng cho TẤT CẢ người chơi, không chỉ người đổ. Khi Người A đổ ra mặt Kỹ Thuật, mọi người chơi (A, B, C…) có công trình Kỹ Thuật hoặc tile có Tài Nguyên Cơ Bản Kỹ Thuật thuộc quyền thu hoạch của mình đều nhận tài nguyên tương ứng. Ngoại lệ duy nhất: mặt Hex chỉ áp dụng cho người đang trong lượt. Phiến Quân phong tỏa vùng bị ảnh hưởng — công trình và tile trong vùng đó không sản xuất lượt này.

**Công thức sản lượng:** *Sản lượng công trình = Sản lượng ghi ở bảng 8.1 (đã theo cấp) × Số viên xúc xắc khớp. Sản lượng tile = Lượng Tài Nguyên Cơ Bản của tile × Số viên xúc xắc khớp loại đó.*

Ví dụ: Hai Trại Khai Thác Cấp 2 (mỗi cái sản xuất 2 Kỹ Thuật khi ra Kỹ Thuật). Đổ ra cả hai mặt Kỹ Thuật → mỗi Trại cho 2 × 2 = 4, tổng 8 Kỹ Thuật. Nếu một Trại đứng trên tile có sẵn 2 Kỹ Thuật Cơ Bản, tile đó cho thêm 2 × 2 = 4 Kỹ Thuật nữa trong cùng lượt.
- Mặt Hex trống (⬡): không sản xuất tài nguyên — mỗi mặt cho 1 phiếu (token) Chi Phối dùng trong Khâu Hành Động.
- Đổ ra số 7 (tổng hai viên): không nhận tài nguyên, kích hoạt Phiến Quân.

### 5.3 Khâu Giải Quyết
Khâu này xử lý tất cả hiệu ứng ngoại sinh theo thứ tự cố định. Thứ tự quan trọng vì một số hiệu ứng phụ thuộc lẫn nhau.
- 1. Phiến Quân — nếu số 7 bị kích hoạt ở Khâu Sản Xuất.
- 2. Sự Kiện Tổng — nếu đây là vòng chia hết cho 5 (5, 10, 15…; mục 11.3).
- 3. Thẻ Sắc Lệnh — người chơi chọn kích hoạt thẻ có điều kiện đã thỏa.
- 4. Kỹ năng nhân vật — hiệu ứng nội tại của nhân vật đang giữ.

### 5.4 Khâu Hành Động
Người chơi thực hiện các hành động theo thứ tự tự chọn, miễn đủ tài nguyên. Không có giới hạn số lượng hành động — giới hạn duy nhất là tài nguyên.

#### Trao đổi tài nguyên
Cho phép giữa hai phe có lãnh thổ được nối với nhau bằng đường giao thông. Chỉ người đang trong lượt mới được đề xuất. Không được cho không, không đổi cùng loại. Ngoài ra có thể đổi với Ngân Hàng theo tỉ lệ 4:1. Cửa sổ trao đổi không tự đóng sau mỗi giao dịch, cho phép đổi liên tục, mỗi lần đổi hiện popup +1 loại tài nguyên nhận được.

#### Xây dựng — Nâng cấp & Dỡ bỏ
Đặt hoặc nâng cấp công trình trên tile thuộc lãnh thổ thực hữu (xem mục 8 — Hệ thống Công Trình). Công trình cao cấp hơn sản xuất nhiều hơn nhưng đắt hơn — buộc người chơi phải cân nhắc giữa mở rộng nhanh và đầu tư sâu. Người chơi có thể hủy bỏ công trình nếu cần nhưng không được hoàn lại tài nguyên đã dùng; tile trở lại thành ô trống, Tài Nguyên Cơ Bản của tile vẫn giữ nguyên nhưng Tài Nguyên Chiến Lược trên các ô đó bị mất vĩnh viễn. Có thể dùng Sắc Lệnh để dỡ ngay và được hoàn tài nguyên.

> **Về phá công trình**
> GDD 1.3: Về sau sẽ cho người chơi nâng cấp kỹ năng phá dỡ công trình mà không làm mất tài nguyên chiến lược, cùng nâng cấp phá dỡ công trình sẽ hoàn lại 1 ít phí tổn.

#### Tuyên bố Chi Phối (sở hữu tile)
Mỗi mặt ⬡ từ xúc xắc cho 1 phiếu Chi Phối. Phiếu được đặt lên tile đủ điều kiện claim (mục 7.2: tile trong Vùng ảnh hưởng, hoặc tile mở rộng liền kề Lãnh thổ thực hữu). Khi đủ phiếu, tile trở thành Lãnh thổ thực hữu — cho phép xây dựng. Thay vì dùng phiếu, người chơi có thể mua tile bằng Văn Hóa + Vàng theo bảng giá ở 7.2. Người chơi tranh chấp đủ điều kiện sẽ có thể sở hữu trước.

> **Phân biệt quan trọng**
> Vùng ảnh hưởng (bán kính 1 ở Cấp 1: 6 ô quanh HQ/Sub; bán kính 2 từ Cấp 2: 18 ô) ≠ Lãnh thổ thực hữu. Vùng ảnh hưởng cho phép thu hoạch CB của tile chưa có chủ và bỏ phiếu với ngưỡng thấp hơn; Lãnh thổ thực hữu cho phép xây dựng và thu hoạch CB. Vì 6 ô quanh HQ là thực hữu ngay từ đầu ván, ở Cấp 1 hai vùng này trùng nhau; sự khác biệt chỉ hiện ra từ vòng ô thứ 2 trở ra (cách thể hiện màu sắc: mục 12.4). Ngưỡng phiếu và giá mua tăng theo khoảng cách d tính từ tâm HQ/Sub gần nhất (bảng ở mục 7.2).

#### Trao đổi và xây đường
Người chơi có thể trao đổi tài nguyên với nhau nếu có tuyến đường nối hai Khu Chợ của các bên lại. Mua Đơn vị Giao Thương mất 5 Vàng, đi được 5 bước không cần xúc xắc. Mỗi bước đi của Đơn Vị Giao Thương sẽ mở 1 ô Đường Đất, người chơi trả 1 Vàng cho mỗi ô đường mới (mục 9.2). Đi và về xem như hoàn thành 1 lần trade. Vùng ảnh hưởng của Phiến Quân có thể khiến Giao Thương đình trệ; Phiến Quân có thể hủy Đơn vị Giao Thương.

Chỉ trong lượt người chơi mới có thể tiến hành đề xuất trao đổi tài nguyên và nhận đề xuất trao đổi từ người khác. Không thể trao đổi tài nguyên giống nhau và với chính mình. Số lượng đổi không giới hạn nhưng mỗi bên phải nhận lại ít nhất 1 tài nguyên (không cho không). Chi phí trao đổi tính bằng quãng đường với mỗi tile là 1 Vàng.

Nếu Khu Dân Cư có Khu Chợ, có thể trade với tỉ lệ nhất định. Hảo Cảm, Sứ Giả và trao đổi với Khu Dân Cư là lớp ngoại giao thuộc Phase 2 — chưa có luật chi tiết, sẽ thiết kế sau khi core loop 20 vòng ổn định (xem 13.2). Cảng là công trình dự kiến Phase 2; hiện chỉ dùng Khu Chợ. Có thể nâng cấp đường và đơn vị Giao Thương (xem mục 9.2 — Đường Giao Thông). Mọi đơn vị đi trên Đường sẽ +1 di chuyển.

## 6. Hệ thống Phiến Quân

### 6.1 Vai trò thiết kế
Phiến Quân là yếu tố gây hỗn loạn có kiểm soát. Không có Phiến Quân, game trở thành bài toán tối ưu thuần túy. Phiến Quân buộc người chơi phải phản ứng, thích nghi và đôi khi tận dụng làm công cụ tấn công.

### 6.2 Cơ chế
- Kích hoạt: Người chơi đổ tổng 7 → không nhận tài nguyên → đổ thêm 1 viên xúc xắc (1–6) làm số bước di chuyển.
- Di chuyển: Phiến Quân di chuyển đúng số bước, mỗi bước sang ô kề chưa đi qua trong lượt này (không trùng); không thể đi qua núi ở 10 lượt đầu (ván 20 vòng; quy đổi theo mục 11.3); vào Rừng hoặc Sông tốn 2 bước; vào Núi (sau khi hết khóa) tốn 3 bước. Phiến Quân không được phép bước vào hoặc dừng trên ô Nhà Chính (HQ) của bất kỳ người chơi nào — ô HQ là ô chặn đối với Phiến Quân (đã sửa theo playtest #1: trước đây Phiến Quân đè lên HQ làm khựng toàn bộ phát triển đầu ván).
- Phong tỏa: Phiến Quân phong tỏa ô đứng và 6 ô lân cận — công trình và tile Tài Nguyên Cơ Bản trong vùng này không sản xuất cho đến khi Phiến Quân rời đi.
- Phiến Quân có thể hủy đơn vị Viễn Chinh và Giao Thương.
- Cướp phá: mỗi khi Phiến Quân bước lên một công trình của người chơi khác (kể cả chỉ đi ngang qua, với công trình nhiều ô thì chỉ cần bước lên 1 ô của nó), công trình đó bị cướp phá: chủ công trình mất một nửa (làm tròn lên) số tài nguyên loại nhiều nhất trong kho — lấy thẳng từ kho của bên bị hại và chuyển cho người đang điều khiển Phiến Quân. Mỗi công trình chỉ bị cướp 1 lần trong 1 vòng chơi (đã bị cướp thì không bị cướp lại cho tới vòng sau). Công trình của chính người điều khiển không bị cướp.
- Bị quấy phá: một người chơi coi là bị quấy phá ở lượt của mình khi có ít nhất 1 tile thực hữu hoặc công trình của họ nằm trong vùng phong tỏa của Phiến Quân (đầu Khâu Sản Xuất). Nếu bị quấy phá hơn 3 lượt liên tiếp, người đó nhận Lệnh Đuổi Phiến Quân ở lượt thứ 4: đổ 1 viên xúc xắc (1–6) để điều khiển Phiến Quân đi chỗ khác, hành động như vừa đổ ra tổng 7 (không mất sản xuất của lượt). Dùng xong thì bộ đếm về 0; bộ đếm cũng về 0 khi Phiến Quân rời khỏi vùng của người đó.
- Hiển thị: trên đầu Phiến Quân luôn có số bước còn lại và người điều khiển lần cuối; xong lượt điều khiển, camera lia về HQ của người vừa điều khiển (mục 12.4).
- Hiệu ứng khi bước lên / dừng: tùy vào tile Phiến Quân đi tới (xem bảng).

| Tile Phiến Quân đi tới | Hiệu ứng |
|---|---|
| Ô trống (không có công trình) | Chỉ phong tỏa vùng xung quanh |
| Ô có công trình của người khác (tính cả khi chỉ đi ngang qua) | Cướp phá: chủ công trình mất một nửa (làm tròn lên) số tài nguyên loại nhiều nhất trong kho, người điều khiển Phiến Quân nhận số đó; mỗi công trình chỉ bị cướp 1 lần/vòng |
| Ô chưa có chủ nhưng có Tài Nguyên Cơ Bản | Người kích hoạt nhận từ Ngân Hàng một nửa (làm tròn lên) lượng mỗi loại Tài Nguyên Cơ Bản trên tile |
| Ô Nhà Chính (HQ) | Không được bước vào hoặc dừng — ô chặn đối với Phiến Quân |

### 6.3 Cách đuổi Phiến Quân
- Sắc Lệnh có hiệu ứng di dời — đẩy Phiến Quân đến tile chỉ định.
- Đơn Vị Viễn Chinh — Trấn Áp Phiến Quân (ngưỡng 4) để đẩy Phiến Quân đi; chi tiết luật Trấn Áp xem Perisol_Data.
- Một số kỹ năng nhân vật cho phép điều khiển trực tiếp.
- Một số Công Trình Đặc Biệt (xem mục 8.3) cho phép né hoặc đẩy Phiến Quân — Pháo Đài Chiến Lược, Thiên Đàn.
- Lệnh Đuổi Phiến Quân — nhận khi bị quấy phá hơn 3 lượt liên tiếp (mục 6.2), không tốn tài nguyên.

## 7. Hệ thống Lãnh thổ

### 7.1 Ba tầng kiểm soát
Kiểm soát lãnh thổ trong Perisol không phải trạng thái nhị phân (có/không). Có ba tầng riêng biệt, mỗi tầng mở ra quyền năng khác nhau và có thể tồn tại đồng thời giữa các phe.

| Tầng | Điều kiện | Quyền năng |
|---|---|---|
| Vùng ảnh hưởng | Tile nằm trong bán kính 1 (Cấp 1) hoặc 2 (Cấp 2+) quanh HQ/Subsidiary | Thu hoạch CB của tile chưa có chủ (nếu chỉ một người ảnh hưởng); bỏ phiếu với ngưỡng thấp hơn |
| Tranh chấp | Có phiếu nhưng chưa đủ ngưỡng | Chặn đối thủ claim; có thể mất nếu thua phiếu |
| Lãnh thổ thực hữu | Đủ phiếu theo ngưỡng, hoặc mua bằng Văn Hóa + Vàng; 6 ô quanh HQ thực hữu từ đầu ván | Xây dựng công trình, bảo vệ tài nguyên |

### 7.2 Tranh chấp lãnh thổ
Khi hai người chơi cùng trong phạm vi ảnh hưởng của một tile chưa có chủ, cả hai đều có thể bỏ phiếu; người đạt ngưỡng trước giành quyền sở hữu. Tranh lại tile đã có chủ (luật "gấp đôi"): chỉ áp dụng cho tile giá trị cao (có Tài Nguyên Chiến Lược, hoặc tổng lượng CB ≥ 3) nằm trong Vùng ảnh hưởng của người tranh. Người tranh phải đặt số phiếu bằng 2 × ngưỡng phiếu của tile đó (tính theo khoảng cách d của chính họ), toàn bộ trong cùng một Khâu Hành Động — phiếu không tích lũy qua lượt, và chỉ thực hiện được khi đủ phiếu trong tay. Ví dụ: tile ở d = 2 có ngưỡng 2 phiếu thì tranh lại cần 4 phiếu trong một lượt. Không thể tranh lại ô HQ/Sub bằng phiếu (chỉ mất qua chiếm đóng, mục 7.4). Công trình đã xây không bị phá khi tile đổi chủ và đi theo tile sang chủ mới (đã chốt); công trình chỉ mất khi bị Sắc Lệnh, kỹ năng hoặc Pháo (S-02) phá hủy, hoặc khi chính chủ dỡ bỏ.

Người chơi có thể dùng 3 Tín Ngưỡng, 3 Vàng, 3 Kỹ Thuật để mua Đơn vị Viễn Chinh với cơ chế di chuyển như Phiến Quân nhưng di được 4 bước mỗi vòng không cần xúc xắc. Mỗi lượt chỉ có thể chọn Di Chuyển hoặc Lập Khu Trực Thuộc (Subsidiary). Khu Trực Thuộc hoạt động như nhà chính, mở rộng phạm vi ảnh hưởng ra 6 ô xung quanh. Đơn vị Viễn Chinh xuất hiện trên bản đồ như một đơn vị di chuyển; khi tới vị trí mong muốn, người chơi chọn Lập Khu Trực Thuộc và đơn vị biến thành Khu Trực Thuộc (đơn vị bị tiêu thụ).

Người chơi có thể nâng cấp HQ/Sub: lên Cấp 2 thì bán kính Vùng ảnh hưởng tăng từ 1 lên 2 (các cấp sau không đổi bán kính; xem bảng cấp độ đầy đủ ở mục 9.1). Sub chỉ cho phép nâng cấp 2 lần; HQ 5 lần.

Mua tile bằng tài nguyên: thay vì dùng phiếu, người chơi có thể trả Văn Hóa + Vàng để mua ngay một tile đủ điều kiện (mua không cần phiếu). Giá tính theo khoảng cách d (số bước từ tâm HQ/Sub gần nhất) và tăng dần khi ra xa: Giá = (1 + d) Văn Hóa + (2 + d) Vàng, tức d = 1 là 2 VH + 3 V, mỗi vòng ô xa thêm +1 VH và +1 V. Ngưỡng phiếu giữ nguyên 1 / 2 / 3 theo d (tối đa 3). Bảng giá dưới đây là giá trị mặc định, chỉnh trong constants.lua:

| Khoảng cách d | Ngưỡng phiếu (trong Vùng ảnh hưởng) | Ngưỡng phiếu (ngoài Vùng ảnh hưởng) | Giá mua (VH + V) |
|---|---|---|---|
| 1 | 1 | — (luôn trong vùng) | 2 VH + 3 V (với HQ: miễn phí, 6 ô khởi đầu) |
| 2 | 2 | 3 | 3 VH + 4 V |
| 3 | 3 | 4 | 4 VH + 5 V |
| 4 | 3 | 4 | 5 VH + 6 V |
| 5 trở lên | 3 | 4 | (d+1) VH + (d+2) V |

Mở rộng liền kề (ngoài Vùng ảnh hưởng): người chơi được claim (bằng phiếu hoặc mua) cả tile nằm ngoài Vùng ảnh hưởng, miễn tile đó kề ít nhất 1 tile thực hữu của mình. Ngưỡng phiếu ngoài vùng +1 như bảng; giá mua tính theo d như trên; khi mua bằng phiếu đủ hay trả đủ tài nguyên thì tile thành thực hữu ngay. Hiệu ứng giảm ngưỡng/giá (TN-06, thẻ) áp dụng sau cùng, tối thiểu 1 phiếu hoặc 1 VH + 1 V.

Khu Dân Cư và Danh Thắng không áp dụng mở rộng liền kề và không mua được bằng tài nguyên: chỉ claim bằng phiếu khi nằm trong Vùng ảnh hưởng (thường cần HQ Cấp 2 hoặc Khu Trực Thuộc), giữ đúng chủ ý dùng Sub để tiếp cận các khu này. Với Khu Dân Cư Tự Do và Danh Thắng, chỉ cần 1 phiếu cho mỗi tile; vùng đó nằm dưới quyền chi phối hoàn toàn của 1 người chơi nếu họ chiếm ưu thế về số ô Chi Phối; trường hợp bằng nhau có thể tranh chấp ô với chi phí cấp số cộng (+1).

Ngoài phiếu xúc xắc, một số Sự Kiện và Sắc Lệnh có thể trao quyền lãnh thổ trực tiếp, tạo ra những khoảnh khắc bất ngờ không thể dự đoán hoàn toàn.

### 7.3 Đặt HQ & Khu Trực Thuộc
Đây là quyết định quan trọng nhất đầu ván, xác định phạm vi ảnh hưởng ban đầu và định hình chiến lược cả ván.

| Công trình | Điều kiện đặt | Tác dụng |
|---|---|---|
| HQ (Nhà Chính) | Không trên Núi/Sông; cách HQ/Sub khác ≥ 1 vòng chu vi; đủ 6 ô xung quanh | Vùng ảnh hưởng 7 tile; 6 ô xung quanh thành Lãnh thổ thực hữu miễn phí ngay khi đặt |
| Subsidiary (Khu Trực Thuộc) | Không trên Núi/Sông; cách HQ/Sub khác ≥ 1 vòng chu vi; đủ 6 ô xung quanh | Mở rộng vùng ảnh hưởng; 6 ô quanh phải claim hoặc mua theo giá d = 1 |

Điều kiện đặt: khi đặt HQ/Sub (mặc định Cấp 1) phải luôn đảm bảo có 1 vòng chu vi xung quanh không xung đột với bất kì vòng chu vi (Cấp 1) HQ/Sub nào khác. Phạm vi vùng ảnh hưởng (vòng chu vi Cấp 1) không được trùng lên tile của danh thắng hay khu dân cư.

Khởi đầu ván: ngay khi đặt HQ, 6 ô xung quanh trở thành Lãnh thổ thực hữu của người chơi (không tốn phiếu hay tài nguyên) và xây dựng được ngay; các ô này nhả CB bình thường (mục 3.3). Khu Trực Thuộc không được tặng ô miễn phí, chỉ mở Vùng ảnh hưởng (đã chốt); 6 ô quanh Sub phải claim hoặc mua theo giá d = 1.

### 7.4 Chiếm đóng công trình (Bộ Binh)
Bộ Binh là đơn vị quân sự (tối đa 10 HP) dùng để chiếm công trình của người chơi khác. Mục này chỉ quy định luật chiếm đóng; chỉ số, các đơn vị khác và hệ chiến đấu sẽ được bổ sung sau (xem mục 13.2).
- Khả năng riêng của Bộ Binh: chỉ Bộ Binh mới có thể chiếm đóng công trình; Đơn Vị Viễn Chinh, Giao Thương và mọi đơn vị khác không có khả năng này.
- Điểm chống trả: mọi công trình, kể cả Nhà Chính và Khu Trực Thuộc, có 20 điểm chống trả, không phụ thuộc cấp. Công trình nhiều ô chỉ có một bộ 20 điểm chung.
- Chiếm đóng: Bộ Binh đứng trên một ô của công trình đối thủ và chọn Chiếm (thay cho di chuyển) vào lượt của chủ Bộ Binh. Mỗi lượt chiếm, điểm chống trả bị trừ bằng số HP hiện tại của Bộ Binh; về 0 thì công trình lập tức đổi chủ sang người chiếm.
- HP càng thấp càng chậm: số lượt cần = ⌈20 ÷ HP⌉. Bộ Binh đầy máu (10 HP) chiếm sau 2 lượt, 9 HP sau 3 lượt, 1 HP sau 20 lượt (xem bảng). Tốc độ tính theo HP hiện tại ở mỗi lượt, nên Bộ Binh bị thương giữa chừng sẽ chậm lại.
- Thu Phục (+100%): hiệu ứng nhân đôi tốc độ chiếm của người kích hoạt — Bộ Binh 10 HP chỉ cần 1 lượt thay vì 2 để triệt tiêu toàn bộ 20 điểm chống trả. Nguồn kỹ năng (nhân vật, Sắc Lệnh hay Công Nghệ) và điều kiện kích hoạt chưa chốt.
- Đổi chủ không giới hạn: công trình đổi chủ bất cứ khi nào điểm chống trả về 0, bao nhiêu lần cũng được. Ví dụ: P1 đã chiếm một công trình; P2 tiêu diệt Bộ Binh của P1, rồi dùng Bộ Binh của mình chiếm lại — khi đủ số lượt công trình về tay P2 ngay (nếu P2 dùng Thu Phục thì chỉ 1 lượt với Bộ Binh 10 HP).
- Hồi điểm chống trả: khi Bộ Binh đang chiếm bị tiêu diệt hoặc rời ô, điểm chống trả hồi lại đủ 20; công trình vừa đổi chủ cũng được đặt lại 20 điểm cho chủ mới (đề xuất, cần test).
- Đang bị chiếm đóng: từ lúc Bộ Binh địch bắt đầu chiếm cho tới khi nó bị tiêu diệt, rời đi hoặc công trình đổi chủ, công trình đó không sản xuất tài nguyên (kể cả khi xúc xắc khớp) và không sản sinh đơn vị. CB trên các ô của công trình không bị ảnh hưởng.
- Công trình đi theo tile: khi công trình đổi chủ, các ô nó chiếm đổi chủ theo; khi tile đổi chủ (phiếu, mua), công trình trên tile đi theo sang chủ mới. Công trình giữ nguyên cấp và Tài Nguyên Chiến Lược trên ô.
- Nhà Chính / Khu Trực Thuộc bị chiếm như một công trình thường. Mất Khu Trực Thuộc: toàn bộ tile và công trình trực thuộc (tile thực hữu có tâm gần nhất là Sub đó; hòa thì ưu tiên tâm cấp cao hơn, rồi HQ) về tay người chiếm. Mất Nhà Chính: toàn bộ tile và công trình của người chơi đó, kể cả các Khu Trực Thuộc, về tay người chiếm. Người mất Nhà Chính chưa bị loại ngay và vẫn tiếp tục chơi; các hệ quả tiếp theo (điều kiện thắng, lập lại Nhà Chính…) chưa quy định.

| HP Bộ Binh | Điểm trừ mỗi lượt | Số lượt chiếm | Số lượt với Thu Phục |
|---|---|---|---|
| 10 | 10 (Thu Phục: 20) | 2 | 1 |
| 9 | 9 (Thu Phục: 18) | 3 | 2 |
| 8 | 8 (Thu Phục: 16) | 3 | 2 |
| 7 | 7 (Thu Phục: 14) | 3 | 2 |
| 6 | 6 (Thu Phục: 12) | 4 | 2 |
| 5 | 5 (Thu Phục: 10) | 4 | 2 |
| 4 | 4 (Thu Phục: 8) | 5 | 3 |
| 3 | 3 (Thu Phục: 6) | 7 | 4 |
| 2 | 2 (Thu Phục: 4) | 10 | 5 |
| 1 | 1 (Thu Phục: 2) | 20 | 10 |

Ghi chú: số lượt tăng rất nhanh khi HP thấp (HP 2 cần 10 lượt, HP 1 cần 20 lượt), nên Bộ Binh bị thương nặng gần như không còn khả năng chiếm.

### 7.5 Hệ chiến đấu (dự thảo — tham chiếu Advance Wars)
Toàn bộ mục này là dự thảo ý tưởng, chưa cần thiết cho bản build hiện tại; được đưa vào GDD để làm khung khi thiết kế đơn vị. Luật chiếm đóng ở mục 7.4 đã dựa trên Advance Wars; bảng dưới so sánh những điểm Perisol giữ và những điểm đổi.

| Hạng mục | Advance Wars | Perisol (dự thảo) |
|---|---|---|
| HP đơn vị | HP hiển thị thang 10; đơn vị đầy máu là 10. | Giữ thang 10 HP. |
| Chiếm công trình | Bộ Binh trừ 20 điểm chiếm mỗi lượt bằng HP hiện tại; chiếm được HQ địch là thắng ngay. | Giữ 20 điểm và công thức theo HP (mục 7.4). Chiếm Nhà Chính không thắng ngay mà chuyển toàn bộ tile và công trình. |
| Sát thương | Bảng sát thương cơ sở theo cặp đơn vị, nhân theo HP bên tấn công, trừ bớt theo địa hình bên thủ; bên thủ còn sống phản công. | Đổ xúc xắc: bên tấn công tung lấy Công, bên thủ tung lấy Thủ, lấy chênh lệch làm sát thương. |
| Khắc chế | Mỗi cặp đơn vị có mức sát thương khác nhau. | Vòng khắc chế kéo–búa–bao theo chất đơn vị. |
| Địa hình | Sao phòng thủ theo địa hình đứng. | Địa hình và công trình cộng chỉ số Thủ hoặc Công. |
| Chỉ số đơn vị | HP, di chuyển, tầm bắn và nhiều chỉ số phụ. | Hai chỉ số chính: Máu và Tốc. |
| Mua đơn vị | Mua bằng tiền tại công trình sản xuất. | Cần công trình và sản phẩm đặc biệt (vật liệu Phái Sinh, Tài Nguyên Chiến Lược) làm điều kiện. |

- Chỉ số đơn vị: mỗi đơn vị có hai chỉ số chính là Máu (HP, thang 10) và Tốc (số bước di chuyển mỗi lượt). Công và Thủ không cố định mà được tung xúc xắc mỗi lần giao tranh.
- Giải quyết giao tranh: phe chủ công tung xúc xắc để lấy chỉ số Công, phe bị công tung xúc xắc để lấy chỉ số Thủ; chênh lệch giữa hai số là sát thương gây ra (nếu Công không vượt Thủ thì không gây sát thương — đề xuất). Ví dụ: Kỵ sĩ đánh Kỵ sĩ thì bên tấn công tung Công, bên bị tấn công tung Thủ.
- Chất đơn vị: Kỵ sĩ, Thương, Cung… khắc chế nhau kiểu kéo–búa–bao; đánh trúng loại bị khắc chế gây sát thương mạnh hơn, đánh phải loại khắc mình thì yếu hơn. Vòng khắc chế cụ thể chưa chốt (ví dụ minh họa: Thương thắng Kỵ sĩ, Kỵ sĩ thắng Cung, Cung thắng Thương).
- Địa hình và công trình: ô địa hình hoặc công trình mà đơn vị đang đứng có thể cộng +x vào Thủ hoặc Công (x chưa chốt). Ví dụ minh họa: Rừng và Núi cộng Thủ, Pháo Đài Chiến Lược (S-02) cộng Thủ cho đơn vị đứng trong aura.
- Mua đơn vị: cần công trình và sản phẩm đặc biệt làm nhu yếu. Ví dụ minh họa: Kỵ sĩ cần Chuồng Ngựa (Phase 2) và Tài Nguyên Chiến Lược Ngựa (TN-04); đơn vị giáp nặng cần Thép (D-03).
- Cần chốt khi thiết kế: loại và số viên xúc xắc chiến đấu; sát thương có nhân theo HP bên tấn công như Advance Wars không; có phản công không; tầm đánh (kề hay xa); và tiêu diệt đơn vị đang chiếm đóng tác động thế nào tới điểm chống trả (mục 7.4).

## 8. Hệ thống Công Trình

Mục mới trong v1.2, hợp nhất từ tài liệu thiết kế Perisol_Buildings_v1.0. Hệ thống công trình có ba tầng: Cơ Bản → Phái Sinh → Đặc Biệt, phản ánh chiều sâu phát triển kinh tế của mỗi phe.

| Loại | Số lượng | Yêu cầu | Mô tả ngắn |
|---|---|---|---|
| ⛏ Cơ Bản | 5 loại × 3 cấp | Ô trống + tài nguyên | Sản xuất 1 loại tài nguyên theo xúc xắc |
| ⚗ Phái Sinh | 5 loại | Kết hợp 2 công trình | Tạo vật liệu mới từ 2 công trình liền kề/nối đường |
| 🔭 Đặc Biệt | 5 loại | Vật liệu phái sinh + không gian lớn | Aura bonus hex xung quanh, khả năng đặc biệt |

### 8.1 Công trình Cơ Bản (5 loại × 3 cấp)
Mỗi công trình sản xuất 1 loại tài nguyên chính khi xúc xắc ra mặt tương ứng (Sản Xuất Chung). Cấp cao hơn cần nhiều ô trống hơn nhưng cho sản lượng và bonus cross-resource cao hơn.

| ID | Công trình | Tài nguyên | Địa hình | Cấp 1 | Cấp 2 | Cấp 3 |
|---|---|---|---|---|---|---|
| B-01 | Trại Khai Thác | Kỹ Thuật | Đồng Bằng, Rừng, Bờ Biển, Đồi Cỏ; Núi từ C2 | 1 ô · 2 KT+1V · 1 KT khi ra KT | 3 ô (Δ) · 4 KT+2 KH+3V · 2 KT khi ra KT, 1 KT khi ra KH | 6 ô (hình 3+3) · 7 KT+4 KH+6V · 3 KT ra KT, 2 KT ra KH, +1 KT thụ động/vòng |
| B-02 | Viện Nghiên Cứu | Khoa Học | Đồng Bằng, Rừng (⭐), Bờ Biển, Đồi Cỏ | 1 ô · 2 KH+1V · 1 KH khi ra KH | 3 ô (Δ) · 4 KH+2 KT+3V · 2 KH ra KH, 1 KH ra KT | 6 ô (hình 3+3) · 7 KH+3 KT+5V · 3 KH ra KH, 2 KH ra KT, +1 KH thụ động/vòng |
| B-03 | Nhà Văn Hóa | Văn Hóa | Đồng Bằng, Bờ Biển, Khu Dân Cư (⭐); Đồi Cỏ từ C2 | 1 ô · 2 VH+1V · 1 VH khi ra VH | 2 ô liền · 3 VH+1 TN+2V · 2 VH ra VH, 1 VH ra TN | 4 ô (chữ nhật hex) · 5 VH+3 TN+4V · 3 VH ra VH, +0.5 VH thụ động/vòng theo tile tiếp giáp |
| B-04 | Đền Thờ | Tín Ngưỡng | Đồng Bằng, Rừng (⭐); Sông sau khi mở khóa; Đồi Cỏ từ C2 | 1 ô · 2 TN+1V · 1 TN khi ra TN | 2 ô liền (có thể trên Sông sau khi mở khóa) · 3 TN+2 VH+2V · 2 TN ra TN, 1 TN ra VH | 3 ô liền · 5 TN+3 VH+3V · 3 TN ra TN, +1 TN thụ động nếu Phiến Quân hiện diện |
| B-05 | Khu Chợ | Vàng | Đồng Bằng, Bờ Biển, Khu Dân Cư (C1–C2, ⭐); C3 không đặt trên Khu Dân Cư | 1 ô · 3V+1 KT · 1V khi ra Vàng | 2 ô liền · 5V+3 KT · 2V ra Vàng, +0.5V/vòng mỗi tuyến Đường Đất nối (tối đa 3) | 3 ô (L hex) · 8V+5 KT+2 VH · 3V ra Vàng, Giao Thương không cần Đơn Vị trong bán kính 2 ô |

Ghi chú bảng trên: mỗi ô cấp trình bày theo thứ tự "chiếm ô · chi phí xây · sản xuất". KT = Kỹ Thuật, KH = Khoa Học, VH = Văn Hóa, TN = Tín Ngưỡng, V = Vàng.

Hình 3+3: hai hàng song song, mỗi hàng 3 ô liền kề, hai hàng sát nhau (hình bình hành trên lưới lục giác). Mọi công trình Cấp 3 chiếm 6 ô dùng đúng hình này; phím Q đổi hướng xoay khi đặt.

### 8.2 Công trình Phái Sinh (5 loại)
Hình thành khi hai công trình đủ cấp đứng liền kề hoặc được nối bằng Đường Đất. Tạo ra vật liệu mới dùng cho Công Trình Đặc Biệt.

> **Quy tắc khoảng cách kết hợp**
> 0 ô (liền kề): kết hợp tức thì, không cần điều kiện thêm.
> 1–2 ô: cần ít nhất 1 đoạn Đường Đất nối liên tục giữa hai công trình.
> 3+ ô: không thể kết hợp dù có đường — cần xây lại gần hơn hoặc dùng thẻ Công Nghệ đặc biệt.

| ID | Công trình → Vật liệu | Công thức | Kích hoạt | Công dụng |
|---|---|---|---|---|
| D-01 | Phòng TN Vật Liệu → Hợp Kim | Trại Khai Thác C2+ ⟺ Viện NC C2+ | Ra Kỹ Thuật hoặc Khoa Học: nhận 1 Hợp Kim thay vì tài nguyên gốc (chọn 1 trong 2 viên). +1 Hợp Kim thụ động mỗi 3 vòng. | Xây Công Trình Đặc Biệt, nâng cấp Đơn Vị Viễn Chinh. 1 Hợp Kim = 2 KT + 1 KH quy đổi. |
| D-02 | Xưởng In Ấn → Giấy | Nhà Văn Hóa C1+ ⟺ Trại Khai Thác C2+ | Ra Văn Hóa hoặc Kỹ Thuật: sản xuất 1 Giấy. +1 Giấy/vòng nếu có Đường Đất nối. | Mua Sắc Lệnh giảm 1 Văn Hóa, hoặc xây Nhà Ngân Hàng. |
| D-03 | Xưởng Luyện Kim → Thép | Trại Khai Thác C3 ⟺ Đền Thờ C2+ | Ra Kỹ Thuật: nhận 1 Thép (thay 1 Kỹ Thuật thường). +1 Thép thụ động mỗi 4 vòng. | Xây và nâng cấp Pháo Đài. 1 Thép = 2 KT + 1 TN. |
| D-04 | Xưởng Dệt Lụa → Lụa | Nhà Văn Hóa C2+ ⟺ Đền Thờ C2+ | Ra Văn Hóa hoặc Tín Ngưỡng: nhận 1 Lụa. +1 Lụa/vòng nếu tiếp giáp Khu Dân Cư. | Tăng giá trị đề nghị Giao Thương (1 Lụa = 3 Vàng khi đổi), thay Văn Hóa trong một số Sắc Lệnh. |
| D-05 | Nhà Ngân Hàng → Tín Phiếu | Khu Chợ C2+ ⟺ Xưởng In Ấn | Ra Vàng: có thể chuyển 1–2 Vàng thành Tín Phiếu. Mỗi Tín Phiếu chưa chi trả sinh lãi 0.5 Vàng/vòng. | 1 Tín Phiếu = 2 Vàng hoãn chi trả đến cuối vòng tiếp theo. Tối đa 5 Tín Phiếu cùng lúc. |

### 8.3 Công trình Đặc Biệt (5 loại)
Yêu cầu vật liệu phái sinh và chiếm nhiều ô. Mỗi công trình đặc biệt phát ra Aura — bonus passif ảnh hưởng các hex lân cận — và có thể nâng cấp thêm 2 cấp.

#### Tháp Quan Sát Thiên Văn [S-01]
*Cột mốc khoa học. Nhìn xa, hiểu sâu, kiểm soát thông tin.*

| Trường | Nội dung |
|---|---|
| Nguyên liệu | Hợp Kim ×3, Khoa Học ×5, Giấy ×2 |
| Địa hình | Núi, Đồng Bằng |
| Chiếm ô | 1 ô trung tâm + 6 ô xung quanh phải trống |
| Hiệu ứng Aura | Bán kính 2 ô: mỗi công trình hoặc tile của bạn trong aura sản xuất Khoa Học được +1 Khoa Học bổ sung khi xúc xắc ra Khoa Học (tính theo từng viên khớp). |

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

#### Đài Khí Tượng [S-04]
*Đọc trời, đoán mùa — dự báo Sự Kiện Tổng và nắn lại vận xúc xắc của chính mình.*

| Trường | Nội dung |
|---|---|
| Nguyên liệu | Hợp Kim ×2, Giấy ×2, Khoa Học ×4, Kỹ Thuật ×4 |
| Địa hình | Đồng Bằng, Bờ Biển |
| Chiếm ô | 1 ô trung tâm + 6 ô xung quanh (tất cả thuộc lãnh thổ bạn) |
| Hiệu ứng Aura | Bán kính 2 ô: công trình và tile của bạn trong aura miễn nhiễm hiệu ứng tiêu cực của các Sự Kiện Tổng thuộc loại thời tiết (ví dụ Bão Tuyết Qua Núi, Mùa Hạn, Lũ Lớn). |

**Thụ động thường trực:**
- Bạn được xem trước lá Sự Kiện Tổng kế tiếp ngay khi Đài hoàn thành.
- +1 Khoa Học và +1 Kỹ Thuật thụ động mỗi vòng.
- 1 lần/5 vòng: sau khi đổ xúc xắc trong lượt của bạn, được chọn đổ lại 1 viên và bắt buộc dùng kết quả mới.

**Nâng cấp:**

| Cấp | Chi phí | Hiệu ứng |
|---|---|---|
| +1 | Hợp Kim ×2 + Khoa Học ×3 + Vàng ×4 | Aura mở rộng lên bán kính 3 ô. Chu kỳ đổ lại xúc xắc rút xuống còn 1 lần/3 vòng. |
| +2 | Hợp Kim ×3 + Giấy ×3 + Vàng ×6 | 1 lần/ván: "Hô Phong Hoán Vũ" — chọn mặt kết quả của 1 viên xúc xắc bạn vừa đổ (không được chọn để tạo tổng 7). |

#### Thiên Đàn [S-05]
*Trung tâm tâm linh tối thượng. Can thiệp trực tiếp vào cơ chế xúc xắc và Phiến Quân.*

| Trường | Nội dung |
|---|---|
| Nguyên liệu | Lụa ×2, Thép ×1, Tín Ngưỡng ×6, Vàng ×4 |
| Địa hình | Rừng, Núi, Sông (Sông cần mở khóa) |
| Chiếm ô | 1 ô trung tâm + 2 ô cùng loại địa hình |
| Hiệu ứng Aura | Bán kính 2: khi Phiến Quân dừng trong vùng, chủ sở hữu trả 2 Tín Ngưỡng để đẩy PQ ra 1 tile ngẫu nhiên bên ngoài aura. |

**Thụ động thường trực:**
- +2 Tín Ngưỡng thụ động mỗi vòng.
- 1 lần/ván: hủy bỏ kết quả tổng 7 — Phiến Quân không di chuyển, người đổ xúc xắc nhận 1 Tín Ngưỡng thay thế.
- Kỹ năng nhân vật tốn Tín Ngưỡng giảm 1 chi phí khi dùng trong bán kính 3 ô từ Thiên Đàn.

**Nâng cấp:**

| Cấp | Chi phí | Hiệu ứng |
|---|---|---|
| +1 | Tín Ngưỡng ×4 + Vàng ×3 | Hủy tổng 7 tăng từ 1 lên 2 lần/ván. Đẩy Phiến Quân không còn ngẫu nhiên — bạn chọn hướng. |
| +2 | Lụa ×2 + Tín Ngưỡng ×5 + Vàng ×5 | 1 lần/ván: "Niết Bàn" — bỏ qua toàn bộ hiệu ứng Sự Kiện Tổng lượt này. Chỉ bạn miễn nhiễm, các người chơi khác vẫn chịu hiệu ứng. |

### 8.4 Cảng (dự thảo)
Cảng là công trình đặt trên Bờ Biển, cho phép xây công trình trên ô nước ngoài khơi (Biển). Cảng, bán kính tác dụng, chi phí và số cấp chưa được thiết kế.

Lưu ý: bản đồ hiện chỉ có Bờ Biển (bộ 12 địa hình không có ô Biển hay Hồ). Muốn áp dụng luật xây trên Biển/Hồ cần bổ sung hai địa hình này hoặc định nghĩa lại; trong lúc đó Sông là ô nước duy nhất chịu luật khóa/mở khóa ở trên. Cảng cũng liên quan tới trao đổi với Khu Dân Cư (Phase 2).

## 9. Hệ thống Hạ Tầng

Mục mới trong v1.2, tổng hợp từ bảng dữ liệu Perisol_Data (sheet "Hạ tầng"). Bao gồm cấp độ HQ/Subsidiary, hệ thống Đường Giao Thông và hai chuỗi tài nguyên công nghiệp phụ trợ (Than, Dầu Mỏ).

### 9.1 Cấp độ HQ & Khu Trực Thuộc
| Công trình | Cấp | Chi phí xây/nâng | Điều kiện | Tác dụng |
|---|---|---|---|---|
| Nhà Chính (HQ) | Cấp 1 | Khởi đầu miễn phí | Không đặt trên Núi/Sông | Vùng ảnh hưởng 7 ô (tâm + 6 ô); 6 ô quanh là Lãnh thổ thực hữu miễn phí từ đầu ván |
| | Cấp 2 | 4 KT + 2 KH + 3 Vàng | Lãnh thổ thực hữu | Bán kính Vùng ảnh hưởng tăng lên 2 (tổng 19 ô) |
| | Cấp 3 | 6 KT + 2 Hợp Kim + 5 Vàng | Cần kết nối ít nhất 1 Khu Chợ | Cho phép xây Công Trình Đặc Biệt trong lãnh thổ |
| | Cấp 4 | 8 KT + 3 Thép + 8 Vàng | Đạt mốc vòng 11+ (ván 20 vòng; quy đổi theo mục 11.3) | Đơn Vị Viễn Chinh +1 bước di chuyển mỗi vòng (Hiệp Sĩ — chi tiết Phase 2) |
| | Cấp 5 | 10 KT + 4 Thép + 4 Hợp Kim + 12 Vàng | Cần sở hữu ít nhất 1 Khu Chợ Cấp 3 | Mở khóa aura thủ đô: +1 sản lượng cho mọi công trình nội đô |
| Khu Trực Thuộc (Sub) | Cấp 1 | Lập từ Đơn Vị Viễn Chinh (đã mua: 3 TN + 3 Vàng + 3 KT) | Cách HQ/Sub khác 1 vòng chu vi | Hoạt động như nhà phụ, mở vùng ảnh hưởng 7 ô |
| | Cấp 2 | 4 KT + 3 Vàng | Lãnh thổ thực hữu | Mở rộng ảnh hưởng thêm 1 vòng bán kính |
| | Cấp 3 | 6 KT + 2 Thép + 5 Vàng | Đạt mốc vòng 16+ (ván 20 vòng; quy đổi theo mục 11.3) | Biến Sub thành Đô Thị Vệ Tinh (miễn nhiễm phong tỏa 1 ô tâm) |

> **Khớp với mục 7.3**
> Bảng trên là bản chi tiết hóa quy tắc "Sub nâng cấp tối đa 2 lần, HQ tối đa 5 lần" đã nêu ở mục 7.2/7.3 của v1.1 — không mâu thuẫn, chỉ định lượng chi phí và mốc vòng cụ thể.

### 9.2 Đường Giao Thông
| Cấp | Chi phí / tile | Điều kiện / địa hình | Tác dụng |
|---|---|---|---|
| Cấp 1: Đường Đất | 1 Vàng / tile | Đồng Bằng, Rừng, Bờ Biển, Đồi Cỏ | Kết nối Chợ để Trade; đơn vị đi trên đường +1 di chuyển |
| Cấp 2: Đường Lát Đá | 1 KT + 1 Vàng / tile | Nâng từ Đường Đất | Đơn vị +2 di chuyển; giảm 50% phí Vàng khi Giao Thương |
| Cấp 3: Đường Ray Xe Lửa | 1 Thép + 1 Than + 2 Vàng / tile | Yêu cầu thẻ Công Nghệ Mạng Lưới Giao Thông | Đơn Vị Giao Thương hóa Đoàn Tàu Hỏa (+4 bước); kết nối phái sinh xa 4 ô |
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
| Đền Thờ (mọi cấp) | ✅ | ⭐ ưu tiên | ❌ | 🔒 sau mở khóa | ❌ | C2+ | ❌ |
| Khu Chợ C1–C2 | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ | ⭐ ưu tiên |
| Khu Chợ C3 | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |

✅ Được phép · ❌ Không được · ⭐ Ưu tiên: giảm 1 đơn vị tài nguyên chính trong chi phí xây Cấp 1 của công trình đó trên ô này (tối thiểu còn 1; không áp dụng khi nâng cấp). Ví dụ: Viện Nghiên Cứu Cấp 1 trên Rừng ⭐ chỉ tốn 1 Khoa Học thay vì 2.

## 10. Hệ thống Sự Kiện & Thẻ bài

Mục cập nhật trong v1.2: số lượng thẻ đã được chốt và thiết kế chi tiết trong tài liệu riêng Perisol_Cards_v1.2 (80 thẻ: 30 Công Nghệ + 30 Sắc Lệnh + 20 Sự Kiện Tổng). Phần dưới đây tóm tắt cấu trúc; xem tài liệu đó để có toàn văn từng thẻ.

### 10.1 Cây Công Nghệ (30 thẻ)
Mua bằng 3 Khoa Học + 3 Kỹ Thuật. Tối đa 5 thẻ hoạt động cùng lúc, có thể hủy để đổi công nghệ khác (thẻ bị hủy vào lại chồng bài). Mỗi thẻ có 3 cấp nâng cấp; chi phí nâng cấp = ceil(chi phí trước × 1.8) + Vàng. Chia thành 5 trường phái, mỗi trường phái 6 thẻ:

| Trường phái | Trọng tâm | Thẻ tiêu biểu (Cấp gốc) |
|---|---|---|
| ⚙ Kỹ Thuật | Hạ tầng & Lãnh thổ | Mạng Lưới Giao Thông, Kiến Trúc Kiên Cố, Gia Cố Phòng Thủ, Quy Hoạch Đô Thị, Pháo Đài Biên Giới, Tuyến Vận Tải Nước |
| 🔬 Khoa Học | Tối ưu Sản Xuất | Khai Thác Chuyên Sâu, Lý Thuyết Địa Mạch, Bản Đồ Địa Lý Học, Phân Tích Xúc Xắc, Mạng Lưới Quan Sát, Tái Cấu Trúc Sản Xuất |
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
Tự động lật mỗi 5 vòng từ chồng bài chung; lá mới thay thế và hủy hiệu lực lá cũ. Tác động toàn bộ người chơi đồng thời. Mức độ khốc liệt tăng dần theo 4 mốc, mỗi mốc 5 thẻ: Với ván dài hơn 20 vòng, mốc được tính theo tiến độ ván (mục 11.3).

| Mốc vòng | Chủ đề | Ví dụ |
|---|---|---|
| Vòng 5 | Định Hình Thế Trận | Mùa Màng Bội Thu, Bùng Nổ Dân Số, Đất Đai Màu Mỡ, Hội Chợ Thương Mại, Thời Bình Tương Đối |
| Vòng 10 | Giao Tranh Tài Nguyên | Bão Tuyết Qua Núi, Hỗn Loạn Biên Giới, Mùa Hạn, Lũ Lớn, Phong Trào Ly Khai |
| Vòng 15 | Cạnh Tranh Khốc Liệt | Khủng Hoảng Niềm Tin, Cách Mạng Công Nghiệp, Bóng Tối Địa Chính Trị, Xuân Phân, Thiên Địa Biến Đổi |
| Vòng 20 | Chốt Hạ Ván Cờ | Ngày Tàn Của Đế Chế, Di Sản Lịch Sử, Đêm Trước Quyết Chiến, Huyết Thống Địa Mạch, Màn Sương Chiến Trận |

> **Ghi chú đồng bộ với tài liệu cũ**
> Bản tổng hợp thiết kế bộ thẻ trước đó ("Các bộ thẻ Perisol") từng nêu 40 lá Sắc Lệnh — con số này đã được điều chỉnh và chốt lại thành 30 lá (10/10/10) trong Perisol_Cards_v1.2, là số liệu chính thức áp dụng cho GDD v1.2.

## 11. Thiết lập & Kết thúc ván

### 11.1 Thiết lập (Setup Phase)
Thực hiện tuần tự trước khi ván bắt đầu:
- 1. Ghép bản đồ — đảm bảo đủ 7 loại địa hình (rút từ bộ 12 loại, mục 3.1).
- 2. Sinh Tài Nguyên Cơ Bản cho từng tile (mục 3.3), rồi đặt Tài Nguyên Chiến Lược (mục 3.4).
- 3. Xào và đặt bốn bộ bài cạnh bàn.
- 4. Đặt Phiến Quân lên tile trung tâm. Sau khi mọi HQ đã được đặt (bước 6) kiểm tra lại: Phiến Quân phải cách mọi HQ ít nhất 2 bước (có tối thiểu 1 ô ở giữa), nếu chưa thỏa thì dời tới tile hợp lệ gần nhất; HQ cũng không được đặt kề Phiến Quân.
- 5. Thứ tự đi: ở bản digital hiện tại luôn bắt đầu từ P1 (P1 → P2 → …) vì chưa cho người chơi chọn vị trí HQ tự do. Khi mở chọn HQ tự do thì quay lại luật cũ: đổ xúc xắc, cao nhất đi trước, theo chiều kim đồng hồ.
- 6. Lần lượt theo thứ tự, mỗi người chọn tile đặt HQ (validation tự động trong bản digital).
- 7. Mỗi người chọn 1 trong 3 nhân vật từ pool nhân vật (rút ngẫu nhiên từ 5 nhân vật, mục 4.2).
- 8. Mỗi người nhận 6 ô quanh HQ làm Lãnh thổ thực hữu miễn phí và nhận tài nguyên khởi đầu bằng toàn bộ Tài Nguyên Cơ Bản (1 lần) của 6 ô đó.

### 11.2 Kết thúc ván
Ván kết thúc sau vòng cuối (N vòng, mục 11.3), hoặc sớm hơn nếu một Sắc Lệnh / Sự Kiện kích hoạt điều kiện thắng sớm, hoặc nếu một nhân vật hoàn thành 1 trong 4 Điều Kiện Thắng riêng (mục 4.2). Tính điểm ngay sau vòng cuối.

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

### 11.3 Số vòng chơi
Số vòng mỗi ván (N) phụ thuộc số người chơi để ván dài ra khi có thêm người; mặc định và cách tùy chỉnh như sau.
- Mặc định: N = 10 × số người chơi, tức 2 người 20 vòng, 3 người 30 vòng, 4 người 40 vòng (1 người chơi: 10 vòng).
- Tùy chỉnh: người tạo ván có thể đặt N là bội của 10 (10, 20, 30…), không giới hạn trên.
- Sự Kiện Tổng vẫn lật mỗi 5 vòng. Mức khốc liệt (mốc 1–4 ở mục 10.3) tính theo tiến độ ván: mốc = ⌈4 × vòng ÷ N⌉. Ván 20 vòng giữ nguyên 4 mốc như cũ; ván dài hơn có nhiều lá cùng mốc. Nếu hết thẻ trong một mốc thì xào lại các thẻ đã lật của mốc đó.
- Các mốc vòng ghi sẵn cho ván 20 vòng (HQ Cấp 4 từ vòng 11, Sub Cấp 3 từ vòng 16, Phiến Quân bị khóa Núi 10 lượt đầu) quy đổi theo tỉ lệ: mốc mới = ⌈mốc × N ÷ 20⌉ (đề xuất, cần test).
- Cần rà lại: các điều kiện thắng nhân vật có con số cố định (ví dụ 15 tile, 12 tile liền mạch, 30 Vàng) và bảng điểm cuối ván có thể quá dễ khi ván dài; thời lượng thực của ván 30 và 40 vòng chưa được đo.

## 12. Trải nghiệm người chơi

### 12.1 Đường cong học
Game được thiết kế để người chơi mới hiểu được luật cốt lõi trong 15 phút đầu ván — nhưng mất 3–5 ván để bắt đầu hiểu chiều sâu chiến lược.

| Ván | Người chơi mới học được |
|---|---|
| 1 | Luồng 3 khâu, cách đặt HQ, Sản Xuất Chung và Tài Nguyên Cơ Bản trên tile hoạt động ra sao |
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
Perisol chủ yếu là cạnh tranh gián tiếp: tranh chấp lãnh thổ, điều khiển Phiến Quân và thẻ Sắc Lệnh. Từ v1.5 có thêm một lớp quân sự nhẹ: Bộ Binh chiếm đóng công trình (mục 7.4), nên công trình, kể cả Nhà Chính, có thể đổi chủ qua lại. Cần playtest để chắc rằng lớp này không làm game quá khốc liệt cho người mới.

### 12.4 Yêu cầu giao diện & phản hồi trực quan (từ playtest #1)
Các mục dưới đây tổng hợp lỗi và đề xuất từ playtest đợt 1 của bản Love2D. Art chính thức cho địa hình và Tài Nguyên Chiến Lược sẽ thay icon mini ở bản sau.
- Phân biệt trạng thái ô: Lãnh thổ thực hữu tô đặc màu phe và viền dày; Vùng ảnh hưởng chưa sở hữu chỉ tô nhạt với viền nét đứt màu phe; ô đang tranh chấp có sọc chéo kèm số phiếu/ngưỡng; ô đang được chọn để claim hoặc mua dùng viền sáng khác hẳn màu ô đã mua (lỗi đã biết: hiện hai màu này gần như trùng nhau).
- Hiển thị giá: khi rê chuột hoặc chọn một ô khả dụng, hiện cả ngưỡng phiếu và giá mua (ví dụ d = 2: 2 phiếu hoặc 3 VH + 4 V; nếu ngoài Vùng ảnh hưởng: 3 phiếu). Mọi khoảng cách d đều phải có giá hiển thị, không chỉ vòng 1.
- Icon mini trên từng ô: địa hình, Tài Nguyên Cơ Bản (5 loại, kèm số lượng 1–2 hoặc cao hơn), Tài Nguyên Chiến Lược (icon tạm), kèm tooltip nêu bonus của ô.
- Phiến Quân: số bước còn lại và người điều khiển lần cuối hiện trên đầu; xong lượt điều khiển camera lia về HQ của người vừa điều khiển; ô HQ hiện trạng thái khóa khi chọn đường đi; popup −x [loại] tại công trình bị cướp phá; nút riêng cho Lệnh Đuổi Phiến Quân khi đủ điều kiện (mục 6.2). Thao tác điều khiển Phiến Quân cần kiểm tra thêm.
- Xúc xắc tự động đổ ở đầu lượt, không cần bấm Space. Popup +x bay lên từ mỗi tile nhận tài nguyên, kể cả ở lượt người khác, để người chơi cảm nhận mình đang tham gia (playtest: ngoài tài nguyên nhận được thì chưa thấy rõ sự tham gia). Nhật ký ghi rõ lý do nhận.
- Cửa sổ trao đổi: không tự đóng sau mỗi giao dịch; mỗi lần đổi hiện popup +1 loại tài nguyên nhận được để đổi liên tục.
- Bảng điểm: chú thích trực tiếp cách ghi điểm (từng dòng của mục 11.2 kèm giá trị đang đạt) vì người chơi chưa rõ hình thức ghi điểm.
- Công cụ test: nút Undo; hiển thị seed ở menu và F1; F5 lưu ván; camera và thứ tự lượt bắt đầu từ P1 (mục 11.1).

## 13. Lộ trình phát triển

### 13.1 Milestone
| Giai đoạn | Nội dung | Trạng thái |
|---|---|---|
| M0 — Sandbox | Hex map, đặt HQ, vùng ảnh hưởng, đổ xúc xắc cơ bản | Hoàn thành (bản Love2D) |
| M1 — Core Loop | Đủ 3 khâu hoàn chỉnh, Phiến Quân, trao đổi, xây dựng | Đang playtest — xong đợt 1 |
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
- Phase 2 (sau khi test xong 20 vòng cơ bản): Hảo Cảm, Sứ Giả, trao đổi với Khu Dân Cư (Khu Chợ / Cảng), Cảng, Chuồng Ngựa (gắn TN-04), Chốt Phòng Thủ, Hiệp Sĩ.
- QUAN TRỌNG — Cân bằng chi phí vật liệu để ván 20 vòng lên được Nhà Chính Cấp 3 và xây được Công Trình Đặc Biệt (máy chơi ngẫu nhiên gần như không bao giờ tới được nên nghi chi phí vật liệu quá cao). v1.4 vừa thêm 6 ô thực hữu khởi đầu và CB (tăng tốc), vừa tăng giá mua ô (làm chậm) — cần test lại tổng tác động lên tốc độ kinh tế (mục 3.3, 7.2).
- Còn mở: luật Trấn Áp / Trú Đóng của Đơn Vị Viễn Chinh chưa được viết vào GDD; điểm tài nguyên dư (5 tài nguyên = 1 điểm) đang khó kiếm theo playtest #1, xem lại sau khi kinh tế đầu ván tăng. Đã chốt ở v1.4: Lãnh Nguyên "−1 Kỹ Thuật" là ưu đãi; cột Địa hình bảng 8.1 khớp ma trận 9.4; giá mua tile có số cụ thể (mục 7.2).
- Cần xác nhận các đề xuất còn lại: (a) mỗi công trình chỉ bị cướp 1 lần/vòng; (b) người điều khiển Phiến Quân nhận tài nguyên bị cướp; (c) công thức giá (1+d) VH + (2+d) V và ngưỡng phiếu ngoài vùng +1; (d) Khu Dân Cư/Danh Thắng chỉ claim bằng phiếu trong Vùng ảnh hưởng. Đã chốt ở v1.5: Khu Trực Thuộc không được tặng ô miễn phí; công trình đi theo tile khi đổi chủ.
- Sẽ bổ sung sau (designer cung cấp): các đơn vị quân sự và hệ chiến đấu (mua, chi phí, di chuyển, sát thương, hồi máu). Còn cần xác nhận cho mục 7.4: nguồn của Thu Phục (+100%); điểm chống trả có hồi lại khi Bộ Binh rời/chết không; ranh giới "trực thuộc" khi mất Khu Trực Thuộc; hệ quả sau khi mất Nhà Chính; Phiến Quân có tác động lên Bộ Binh không.
- Cần chốt trong v1.6: cách mở khóa xây trên Sông/Hồ (đề xuất thẻ Tuyến Vận Tải Nước, cần đồng bộ Perisol_Cards); bổ sung địa hình Hồ và Biển hay định nghĩa lại; thiết kế Cảng (mục 8.4); rà lại điều kiện thắng nhân vật, bảng điểm và mốc vòng theo số vòng mới (mục 11.3); hệ chiến đấu dự thảo (mục 7.5).

## Phụ lục A — Từ điển thuật ngữ

| Thuật ngữ | Định nghĩa |
|---|---|
| Sản Xuất Chung | Cơ chế chia sẻ sản lượng xúc xắc: kết quả xúc xắc áp dụng cho mọi người chơi có công trình hoặc tile tài nguyên khớp (trừ mặt Hex). |
| HQ (Nhà Chính) | Công trình chính, điểm xuất phát vùng ảnh hưởng. Mỗi người 1 HQ, tối đa Cấp 5. |
| Subsidiary | Khu Trực Thuộc — mở rộng vùng ảnh hưởng, tối đa Cấp 3. |
| Vùng ảnh hưởng | Tile trong bán kính 1 (Cấp 1) hoặc 2 (Cấp 2+) quanh HQ/Subsidiary — thu hoạch CB của tile chưa có chủ, bỏ phiếu với ngưỡng thấp hơn. Chỉ xây được khi tile đã là Lãnh thổ thực hữu. |
| Lãnh thổ thực hữu | Tile đã đủ phiếu, đã mua bằng Văn Hóa + Vàng, hoặc là 6 ô khởi đầu quanh HQ. Được phép xây dựng. |
| Chi Phối (CP) | Token phiếu đặt lên tile để tuyên bố chủ quyền. |
| Phiến Quân | Nhân vật trung lập, phong tỏa 7 tile khi đứng, cướp phá công trình người khác khi bước lên; không được vào ô HQ. Kích hoạt bởi đổ số 7. |
| Sắc Lệnh | Thẻ bí mật cá nhân, chi phí 2+2+2. Hiệu ứng Tức Thì, Phản Ứng hoặc Nội Tại. |
| Sự Kiện Tổng | Lá bài lật lên mỗi 5 vòng, tác động toàn bộ người chơi. |
| Ngưỡng phiếu | Số phiếu tối thiểu để claim tile: d = 1 là 1 phiếu, d = 2 là 2, d ≥ 3 là 3; ngoài Vùng ảnh hưởng +1. |
| Tài Nguyên Chiến Lược | Bonus hiếm gắn theo tile (12 loại) — cho bonus ô không cần sở hữu, bonus công trình cần sở hữu. |
| Công trình Phái Sinh | Vật liệu mới (Hợp Kim, Giấy, Thép, Lụa, Tín Phiếu) sinh ra khi 2 công trình Cơ Bản đủ cấp kết hợp. |
| Công trình Đặc Biệt | 5 công trình cao cấp nhất, dùng vật liệu Phái Sinh, phát Aura và có 2 cấp nâng cấp. |
| Aura | Hiệu ứng bị động của Công trình Đặc Biệt ảnh hưởng các hex trong bán kính nhất định. |
| Điều Kiện Thắng | 4 mục tiêu riêng biệt gắn với mỗi nhân vật, hoàn thành sẽ kết thúc ván sớm hoặc tính điểm thưởng lớn. |
| Than / Dầu Mỏ | Tài nguyên công nghiệp phụ trợ, khai thác qua Mỏ Than/Giếng Dầu, quy đổi sang tài nguyên cốt lõi hoặc dùng cho Đường Ray Xe Lửa. |
| Tài Nguyên Cơ Bản (CB) | Lượng KH / VH / KT / TN / Vàng có sẵn trên mỗi tile (1–2 mỗi loại khi sinh bản đồ), nhả ra khi xúc xắc ra mặt tương ứng cho người có quyền thu hoạch tile. |
| Quyền thu hoạch | Người được nhận CB của tile: chủ tile; hoặc người duy nhất có Vùng ảnh hưởng phủ tile chưa có chủ. |
| Khoảng cách d | Số bước từ tâm HQ/Sub gần nhất tới tile; quyết định ngưỡng phiếu và giá mua. |
| Mở rộng liền kề | Claim tile ngoài Vùng ảnh hưởng nhưng kề ít nhất 1 tile thực hữu của mình, với ngưỡng phiếu +1 và giá theo d. |
| Cướp phá | Hiệu ứng khi Phiến Quân bước lên công trình người khác: chủ mất một nửa (làm tròn lên) tài nguyên loại nhiều nhất, người điều khiển nhận; mỗi công trình 1 lần/vòng. |
| Lệnh Đuổi Phiến Quân | Quyền đổ 1 viên xúc xắc để điều khiển Phiến Quân, nhận ở lượt thứ 4 khi bị quấy phá hơn 3 lượt liên tiếp. |
| Bộ Binh | Đơn vị quân sự tối đa 10 HP; là đơn vị duy nhất có khả năng chiếm đóng công trình đối thủ (mục 7.4). |
| Điểm chống trả | 20 điểm của mỗi công trình; Bộ Binh trừ dần bằng HP của nó mỗi lượt chiếm, về 0 thì công trình đổi chủ. |
| Chiếm đóng | Trạng thái công trình có Bộ Binh địch đang chiếm: không sản xuất tài nguyên hay đơn vị. |
| Thu Phục | Hiệu ứng +100% tốc độ chiếm đóng của người kích hoạt. |

## Phụ lục B — Change log

- v1.0: Thiết lập cho trò chơi, làm GDD, xác định milestone và định hướng game.
- v1.1: Sửa đổi các nội dung ở mục 2.2, 7.3. Hạ thời gian chơi. Các event tổng ở mốc 5/10/15/20 sẽ khác nhau.
- v1.2: Hợp nhất toàn bộ tài liệu thiết kế rời rạc vào GDD chính.
  - — Mở rộng hệ thống địa hình từ 7 lên 12 loại, bổ sung 12 Tài Nguyên Chiến Lược làm lớp bonus tile (mục 3.1–3.2).
  - — Thêm đầy đủ Hệ Thống Công Trình: 5 Cơ Bản × 3 cấp, 5 Phái Sinh, 5 Đặc Biệt với Aura và nâng cấp (mục 8, từ Perisol_Buildings_v1.0).
  - — Thêm Hệ Thống Hạ Tầng: cấp độ HQ/Subsidiary, 4 cấp Đường Giao Thông, chuỗi tài nguyên Than/Dầu Mỏ, ma trận đặt công trình theo địa hình (mục 9, từ Perisol_Data).
  - — Chốt số lượng bộ thẻ: 30 Công Nghệ, 30 Sắc Lệnh (10/10/10), 20 Sự Kiện Tổng — thay thế số liệu placeholder của v1.1 và số liệu cũ (40 Sắc Lệnh) trong tài liệu tổng hợp trước đó (mục 10, từ Perisol_Cards_v1.2).
  - — Hoàn thiện 5 nhân vật đầy đủ (bổ sung Học Sĩ) với kỹ năng gốc và 4 Điều Kiện Thắng riêng biệt mỗi nhân vật, thay thế bảng placeholder 4 nhân vật của v1.1 (mục 4, từ Characters.txt).
  - — Cập nhật Phụ lục A (từ điển) với các thuật ngữ mới; cập nhật roadmap (mục 13) để phản ánh các hệ thống đã có thiết kế đầy đủ.
- v1.3: Dọn các khái niệm không rõ nghĩa, thêm hệ Tài Nguyên Cơ Bản trên tile, chốt các quyết định trước playtest.
  - Thay đổi về Tên gọi & Text trong game.
  - Cập nhật Cơ chế (Mechanic) & Logic game
  - Cân bằng chỉ số & Luật xây dựng
  - Giới hạn Scope, bổ sung các phụ lục D và E, sẽ xóa ở GDD sau
  - Đổi engine sang Love2D

## Phụ lục C — Tài liệu tham chiếu liên quan

- Perisol_Cards_v1.2.docx — toàn văn 80 thẻ (30 Công Nghệ, 30 Sắc Lệnh, 20 Sự Kiện Tổng).
- Perisol_Buildings_v1.0.docx — toàn văn chi tiết 15 công trình (Cơ Bản/Phái Sinh/Đặc Biệt).
- Perisol_Data.xlsx — bảng dữ liệu sống: Địa hình, Tài Nguyên Chiến Lược, Công trình, Đặt công trình, Hạ tầng, Hình ảnh đơn vị (chờ art).
- Characters.txt — nguồn cho 5 nhân vật và 4 Điều Kiện Thắng mỗi nhân vật.

## Phụ lục D — Kết quả playtest đợt 1 (bản Love2D)

Tóm tắt phản hồi và cách v1.4 xử lý. Các hạng mục designer tự test (Nâng C2/C3, Dỡ công trình, Viễn Chinh, đường Giao Thương, Phái Sinh…) chưa có kết quả nên chưa ghi ở đây.

| Hạng mục | Kết quả playtest | Xử lý trong v1.4 |
|---|---|---|
| Nhịp ván | 2 người 10–15 phút, thêm 1 người +10 phút; không có lượt chờ; người nhiều tài nguyên hành động lâu hơn (trong tầm kiểm soát). | Cập nhật mục 1.2. |
| Sản Xuất Chung | Nhật ký đủ để hiểu vì sao nhận tài nguyên; ngoài tài nguyên nhận được thì chưa thấy rõ việc tham gia ở lượt người khác. | Popup +x trên tile (mục 12.4). |
| Tốc độ mở rộng | Không đủ nhanh: khoảng 6–7 ô/người sau 20 vòng, do chưa có CB mặc định và chưa có 6 ô đầu. | 6 ô thực hữu khởi đầu, CB trên tile, mở rộng liền kề (mục 3.3, 7.2, 7.3). |
| Ngưỡng phiếu / luật gấp đôi | Ngưỡng 1/2/3 ổn; luật cướp gấp đôi chưa rõ. | Giữ ngưỡng; viết lại luật có ví dụ (mục 7.2). |
| Khu Trực Thuộc | Xứng đáng lập; tài nguyên đầu game chưa đủ để mua sớm. | Xử lý bằng 6 ô khởi đầu và CB. |
| Khu Dân Cư & Danh Thắng | Vẫn với tới được qua Sub, Giao Thương, Viễn Chinh nhưng rất khó. | Giữ chủ ý; chỉ claim trong Vùng ảnh hưởng (mục 7.2). |
| Kinh tế | Chưa có CB trên tile; đổi 4:1 ổn; chưa thấy tài nguyên thừa/thiếu kéo dài. | Thêm CB mặc định; ghi 4:1 ở mục 5.4. |
| Phiến Quân | Tỉ lệ ra 7 ổn (nên ra thường xuyên); thao tác điều khiển chưa tốt; mất/cướp một nửa khá nặng nhưng giữ để test thêm. | Luật HQ, cướp phá, Lệnh Đuổi (mục 6.2); UI (mục 12.4); giữ mức một nửa. |
| Điểm số | Người chơi chưa rõ cách ghi điểm; điểm tài nguyên dư khó kiếm. | Bảng điểm có chú thích (mục 12.4); theo dõi ở mục 13.2. |
| Lỗi đã biết | Màu ô đã mua gần trùng ô đang chọn; chưa có icon địa hình/tài nguyên; chưa hiện giá mua ô xa; Phiến Quân xuất hiện sát HQ ngay vòng 1; Phiến Quân đè lên HQ chặn phát triển; cướp kết thúc ở HQ người khác nhưng không cướp được. | Mục 6.2, 11.1, 12.4. |

Cách báo lỗi: ghi seed (hiện ở menu và F1), ghi vòng và lượt đang chơi, chụp màn hình, và nếu có thể bấm F5 lưu ván để dev nạp lại đúng thế cờ.

## Phụ lục E — Pseudo Bảng hằng số cân bằng (src/config/constants.lua)

Tên tham số là đề xuất, đồng bộ lại với constants.lua khi lập trình. Bảng địa hình quanh Nhà Chính → tài nguyên khởi đầu cần designer duyệt trong file này.

| Tham số | Giá trị v1.4 | Ghi chú |
|---|---|---|
| StartOwnedRing | 1 (6 ô) | Số vòng ô quanh HQ được tặng thực hữu |
| TileBuyBase (VH / V) | 2 / 3 | Giá mua d = 1 |
| TileBuyStep (VH / V) | +1 / +1 | Cộng thêm mỗi vòng ô xa tâm |
| VoteThreshold | 1, 2, 3 (tối đa 3) | Theo d, trong Vùng ảnh hưởng |
| VoteOutsideBonus | +1 | Ngoài Vùng ảnh hưởng |
| ContestMultiplier | ×2 | Tranh lại tile giá trị cao |
| PQPlunderFraction | 1/2 (làm tròn lên) | Loại nhiều nhất trong kho; mỗi công trình 1 lần/vòng |
| PQSpawnMinDist | 2 | Bước tối thiểu từ mọi HQ |
| PQHarassTurnsBeforeExpel | >3 (nhận ở lượt 4) | Lệnh Đuổi Phiến Quân |
| PQMountainStepCost | 3 | Phiến Quân vào Núi (theo Data) |
| ExpeditionCost / Steps | 3 TN + 3 V + 3 KT / 4 bước | Đơn vị Viễn Chinh |
| BankTradeRatio | 4:1 | Đổi với Ngân Hàng |
| RoadCostPerTile | 1 Vàng | Đường Đất |
| MaxKindsPerTile | Không giới hạn | Mục 3.3 |
| CaptureDefensePoints | 20 | Điểm chống trả mỗi công trình |
| InfantryMaxHP | 10 | HP tối đa Bộ Binh |
| CaptureSkillMult | ×2 | Thu Phục (+100%) |
| RoundsPerPlayer | 10 | N mặc định = 10 × số người |
| RoundStep | 10 | Tùy chỉnh theo bội của 10 |
| EventEveryRounds | 5 | Chu kỳ Sự Kiện Tổng |
| BuildOnRiverLocked | true | Sông khóa xây tới khi mở khóa |

<p align="center"><i>Perisol · GDD v1.6 · Nội bộ · Không phát hành ngoài</i></p>
