# PERISOL - BẢNG DỮ LIỆU TỔNG HỢP

*Tài liệu này được trích xuất từ Perisol Data.xlsx để làm context dữ liệu tĩnh cho hệ thống AI.*

## Sheet: Địa hình

|PERISOL — BẢNG ĐỊA HÌNH||||||||||||||
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
|ID|Tên|EN|Hình ảnh (chờ art)|Icon (chờ art)|Rarity|Flavor text|HQ|Sub|Công trình|CT ĐB|Movement|Mov Penalty|Ghi Chú|
|DH-01|Đồng Bằng|Plains||🌾|Phổ biến|Cỏ xanh, đất nâu nhạt, cảm giác mở rộng|✅|✅|✅|❌|✅|—|Tile cơ bản, không penalty|
|DH-02|Rừng|Forest||🌲|Phổ biến|Tán cây dày, ánh sáng lọc qua lá, nền đất ẩm|✅|✅|✅|✅|✅|−1 bước|Đền Thờ, Yến Đình ưu tiên; VNC Cấp 1 +1 KH thụ động|
|DH-03|Núi|Mountain||⛰|Phổ biến|Đá xám trắng, tuyết đỉnh, dốc đứng|❌|❌|❌|✅|❌|❌|Chỉ CT Đặc Biệt & Pháo Đài, về sau có nâng cấp cho đi qua|
|DH-04|Sông|River||🌊|Phổ biến|Dòng nước xanh, bờ cát hai bên|❌|❌|❌|✅|✅|−1 bước|Đền Thờ, Xưởng Dệt Lụa được xây|
|DH-05|Bờ Biển|Coast||🏖|Phổ biến|Cát vàng, sóng nhỏ, ánh nắng lấp lánh|✅|✅|✅|✅|✅|—|Khu Chợ Cấp 3 miễn ĐV Giao Thương|
|DH-06|Lãnh nguyên|Tundra||❄|Không phổ biến|Mặt đất đóng băng trắng xám|✅|✅|✅|❌|✅|—|Vàng −1 sản lượng; xây CT −1 KT|
|DH-07|Sa Mạc|Desert||🏜|Không phổ biến|Cát vàng cam, nắng gay gắt, khô khan|✅|✅|✅|❌|✅|—|Không sản xuất Tín Ngưỡng|
|DH-08|Đầm Lầy|Swamp||🌿|Không phổ biến|Nước tù đọng, bùn xám xanh, cây um tùm|❌|✅|✅|❌|✅|−1 bước|Không đặt HQ; TN & VH cao|
|DH-09|Đồi Cỏ|Grassland Hills||🏔|Không phổ biến|Đồi nhấp nhô xanh, hoa dại, gió nhẹ|✅|✅|✅|✅|✅|—|Trại KT Cấp 2 +1 KT|
|DH-10|Khu Dân Cư|Settlement||🏘|Hiếm|Nhà san sát, đường đất, chợ nhỏ, đông đúc|❌|❌|❌|❌|✅|—|Chỉ Chi Phối; cho điểm cuối ván|
|DH-11|Danh Thắng|Landmark||🗿|Hiếm|Công trình cổ đại hoặc địa hình nổi bật|❌|❌|❌|❌|✅|—|Chỉ Chi Phối; 3 điểm cuối ván|
|DH-12|Núi Tuyết|Snow Peak||⛰⛰|Phổ biến|Núi nhưng phủ nhiều tuyết|❌|❌|❌|✅|❌|❌|Như Núi|


---

## Sheet: Tài nguyên Chiến lược

|PERISOL — TÀI NGUYÊN CHIẾN LƯỢC|||||||||||
|---|---|---|---|---|---|---|---|---|---|---|
|ID|Tên|EN|Hình ảnh (chờ art)|Icon (chờ art)|Rarity|Địa Hình|Flavor text|Bonus ô|Hiệu Ứng Tile|Bonus Công Trình|
|TN-01|Đá Granite|Granite||🪨|Phổ biến|Núi, Đồi Cỏ|Khối đá xám xanh lớn, vân đen trắng|Kỹ Thuật|Tile +1 KT bổ sung khi xúc xắc ra KT|Pháo Đài: −2 KT chi phí xây|
|TN-02|Rừng Cổ Thụ|Ancient Forest||🌳|Phổ biến|Rừng|Cây cao vút, rễ lồi, ánh sáng xanh huyền ảo|TN + KH|Thêm 1 TN và 1 KH thụ động/vòng|Thiên Đình: bỏ yêu cầu địa hình Rừng|
|TN-03|Cá|Fishing Ground||🐟|Phổ biến|Bờ Biển, Sông|Mặt nước lấp lánh, vảy cá, lưới đánh cá|Vàng|Khu Chợ: +2V khi ra Vàng; kết nối HQ ảo|Khu Chợ: không cần Đường Đất đến HQ|
|TN-04|Ngựa|Horse Pasture||🐎|Không phổ biến|Đồng Bằng, Đồi Cỏ, Tundra|Đàn ngựa trên cánh đồng rộng, hàng rào gỗ|Di Chuyển|Viễn Chinh +2 bước nếu HQ trong bán kính 2|Chuồng Ngựa: −2 TN chi phí Viễn Chinh|
|TN-05|Quặng Lộ Thiên|Open-cast Ore||⛏|Không phổ biến|Núi, Đồi Cỏ, Đồng Bằng|Vết nứt cam đỏ, quặng lộ ra, ánh kim|Kỹ Thuật|Tile +2 KT khi ra KT; Hợp Kim tỷ lệ 1:1|Phòng TN Vật Liệu: +1 Hợp Kim thụ động/vòng|
|TN-06|Vàng Sa Khoáng|Alluvial Gold||✨|Hiếm|Sông, Bờ Biển, Đồng Bằng|Hạt vàng lấp lánh trong lòng suối, bãi cát|Vàng|Tile +3V khi ra Vàng; Chi Phối −1 ngưỡng|Khu Chợ Cấp 2+: tỷ lệ đổi 1:1 tất cả|
|TN-07|Đá Thiêng|Sacred Stone||🔮|Hiếm|Núi, Rừng, Đồi Cỏ|Phiến đá đen phát ánh tím xanh, khắc ký tự cổ|Tín Ngưỡng|Tile +2 TN khi ra TN; Đền Thờ: miễn cooldown 1v/5v|Thiên Đình: aura +1 ô nếu trên tile này|
|TN-08|Đất Màu Mỡ|Fertile Land||🌱|Phổ biến|Đồng Bằng, Đồi Cỏ|Đất nâu sẫm bóng, mầm xanh nhú, trù phú|Mọi tài nguyên|+1 sản lượng cơ bản cho mọi CT trên tile|CT Cấp 1 trên tile: −1 KT chi phí xây|
|TN-09|Suối Nước Nóng|Hot Spring||♨|Hiếm|Núi, Đồi Cỏ, Đồng Bằng|Hơi nước bốc lên, ao nước xanh ngọc, hoa dại|Văn Hóa|Tile liền kề: +1 VH thụ động/vòng không cần CT|Đền Thờ Cấp 2+ kề: aura +1 TN bán kính 1|
|TN-10|Cảng Tự Nhiên|Natural Harbor||⚓|Không phổ biến|Bờ Biển|Vũng biển kín gió, vách đá hai bên hình móng ngựa|Di Chuyển|Giao Thương miễn phí Vàng/tile; ĐV +3 bước|Khu Chợ Cấp 1 = Cấp 3 khi trên tile này|
|TN-11|Gió Mạnh|Wind Corridor||💨|Không phổ biến|Bờ Biển, Đồng Bằng, Tundra|Cỏ nghiêng, mây cuộn, địa hình trống trải|Di Chuyển|Viễn Chinh +1 bước qua tile; PQ +2 bước ngẫu nhiên|Tháp Thiên Văn kề: aura +1 ô|
|TN-12|Địa Linh|Ley Line Node||⭕|Rất hiếm|Bất kỳ (1–2 tile/ván)|Vòng sáng vàng trắng mờ trên mặt đất|Mọi tài nguyên|Long Mạch +1 ô; CT nhận sản lượng từ cả 2 viên|Đài LM: Phát Sóng Toàn Cầu 2 lần/3 vòng|
|Dự kiến có thay đổi trong tương lai.|||||||||||
|Ghi chú:|||||||||||
|Các tài nguyên ĐB không cần phải sở hữu, nhận bonus ô với các loại tài nguyên, với loại di chuyển thì không cần phải sở hữu.|||||||||||
|Một số loại công trình xây lên sẽ gây mất tài nguyên, người chơi sẽ được thông báo về thay đổi này.|||||||||||
|Phá dỡ công trình đã xây lên tài nguyên chiến lược sẽ làm mất tài nguyên, cũng sẽ nhận thông báo.|||||||||||


---

## Sheet: Công trình

|PERISOL — BẢNG CÔNG TRÌNH + ĐIỀU KIỆN||||||||||||||
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
|Loại|ID|Tên|Hình ảnh (chờ art)|Icon (chờ art)|Cấp|Số Ô Hex|Loại và hình dạng ô|Địa Hình Hợp Lệ|Tài Nguyên ĐB|Phụ Thuộc Công Trình|Khoảng Cách|Chi Phí Xây|Sản Xuất|
|Cơ Bản|B-01.1|Trại Khai Thác||⛏|1|1|Thực hữu|Đồng Bằng, Đồi Cỏ, Sa Mạc, Tundra|Quặng LT (bonus), Đất MM (bonus)|—|—|2 KT + 1V|1 KT khi ra KT|
|Cơ Bản|B-01.2|Trại Khai Thác||⛏|2|3|Thực hữu — tam giác hex|Đồng Bằng, Đồi Cỏ, Núi, Sa Mạc, Tundra|Quặng LT (unlock Hợp Kim tối ưu)|—|—|4 KT + 2 KH + 3V|2 KT khi ra KT; +1 KT khi ra KH|
|Cơ Bản|B-01.3|Trại Khai Thác||⛏|3|6|Thực hữu — hình thang hex|Đồng Bằng, Đồi Cỏ, Núi, Sa Mạc, Tundra|Quặng LT (+1 KT thụ động/vòng)|—|—|7 KT + 4 KH + 6V|3 KT ra KT; 2 KT ra KH; +1 KT thụ động/vòng|
|Cơ Bản|B-02.1|Viện Nghiên Cứu||🔬|1|1|Thực hữu|Đồng Bằng, Rừng, Đồi Cỏ, Bờ Biển|Rừng CT (bonus), Đất Linh (bonus)|—|—|2 KH + 1V|1 KH khi ra KH. Rừng: +1 KH thụ động|
|Cơ Bản|B-02.2|Viện Nghiên Cứu||🔬|2|3|Thực hữu — tam giác hex|Đồng Bằng, Rừng, Đồi Cỏ, Bờ Biển|Rừng CT, Đất Linh|—|—|4 KH + 2 KT + 3V|2 KH khi ra KH; +1 KH khi ra KT|
|Cơ Bản|B-02.3|Viện Nghiên Cứu||🔬|3|6|Thực hữu — cụm hex|Đồng Bằng, Rừng, Đồi Cỏ, Bờ Biển|Rừng CT, Đất Linh|—|—|7 KH + 3 KT + 5V|3 KH ra KH; 2 KH ra KT; +1 KH thụ động/vòng|
|Cơ Bản|B-03.1|Nhà Văn Hóa||🏛|1|1|Thực hữu|Đồng Bằng, Bờ Biển, Khu DC (ảnh hưởng)|Suối NN (bonus), Đất MM (bonus)|—|—|2 VH + 1V|1 VH khi ra VH|
|Cơ Bản|B-03.2|Nhà Văn Hóa||🏛|2|2|Thực hữu — 2 ô liền|Đồng Bằng, Bờ Biển, Đồi Cỏ|Suối NN, Đất MM|—|—|3 VH + 1 TN + 2V|2 VH ra VH; +1 VH khi ra TN|
|Cơ Bản|B-03.3|Nhà Văn Hóa||🏛|3|4|Thực hữu — 4 ô hình chữ nhật hex|Đồng Bằng, Bờ Biển, Đồi Cỏ|Suối NN, Đất MM|—|—|5 VH + 3 TN + 4V|3 VH; tile lãnh thổ kề +0.5 VH thụ động/vòng|
|Cơ Bản|B-04.1|Đền Thờ||⛩|1|1|Thực hữu|Đồng Bằng, Rừng, Sông, Đầm Lầy|Đá Thiêng (bonus), Rừng CT (bonus)|—|—|2 TN + 1V|1 TN khi ra TN|
|Cơ Bản|B-04.2|Đền Thờ||⛩|2|2|Thực hữu — 2 ô liền (kể cả Sông)|Đồng Bằng, Rừng, Sông, Đầm Lầy, Đồi Cỏ|Đá Thiêng, Suối NN|—|—|3 TN + 2 VH + 2V|2 TN ra TN; +1 TN khi ra VH|
|Cơ Bản|B-04.3|Đền Thờ||⛩|3|3|Thực hữu — 3 ô liền|Đồng Bằng, Rừng, Sông, Đầm Lầy, Đồi Cỏ|Đá Thiêng (aura +1 tự động)|—|—|5 TN + 3 VH + 3V|3 TN ra TN; +1 TN thụ động nếu PQ hiện diện|
|Cơ Bản|B-05.1|Khu Chợ||💰|1|1|Thực hữu|Đồng Bằng, Bờ Biển, Khu DC (ảnh hưởng)|Cảng TN (bonus lớn), Vàng SK (bonus), Cá|—|Cần đường nếu không liền HQ|3V + 1 KT|1V khi ra Vàng|
|Cơ Bản|B-05.2|Khu Chợ||💰|2|2|Thực hữu — 2 ô liền|Đồng Bằng, Bờ Biển, Khu DC, Sa Mạc|Cảng TN, Vàng SK, Cá|—|Đường nếu không liền HQ|5V + 3 KT|2V ra Vàng; +0.5V/vòng mỗi tuyến ĐĐ (max 3)|
|Cơ Bản|B-05.3|Khu Chợ||💰|3|3|Thực hữu — dạng L hex|Đồng Bằng, Bờ Biển, Sa Mạc|Cảng TN, Vàng SK, Cá|—|—|8V + 5 KT + 2 VH|3V ra Vàng; GT bán kính 2 ô không cần ĐV|
|Phái Sinh|D-01|Phòng TN Vật Liệu||⚗|—|0|Không chiếm ô mới|Tile của Trại KT Cấp 2+|Quặng LT (tỷ lệ 1:1)|Trại KT Cấp 2+ VÀ Viện NC Cấp 2+|Tối đa 2 ô; cần ĐĐ nếu 1–2 ô|3 KT + 2 KH + 2V|1 HK khi ra KT hoặc KH; +1 HK thụ động/3 vòng|
|Phái Sinh|D-02|Xưởng In Ấn||📄|—|0|Không chiếm ô mới|Tile của Nhà VH Cấp 1+|Rừng CT (NVH trên Rừng: +1 Giấy/vòng)|Nhà VH Cấp 1+ VÀ Trại KT Cấp 2+|Tối đa 1 ô; cần ĐĐ nếu cách 1 ô|2 VH + 2 KT + 1V|1 Giấy khi ra VH hoặc KT; có ĐĐ: +1 Giấy/vòng|
|Phái Sinh|D-03|Xưởng Luyện Kim||🔥|—|1|Thực hữu — 1 ô trống kề Trại KT Cấp 3|Đồng Bằng, Núi, Đồi Cỏ|Quặng LT (bắt buộc giảm chi phí)|Trại KT Cấp 3 VÀ Đền Thờ Cấp 2+|Phải LIỀN KỀ — không thể dùng ĐĐ|4 KT + 2 TN + 3V|1 Thép khi ra KT; +1 Thép thụ động/4 vòng|
|Phái Sinh|D-04|Xưởng Dệt Lụa||🪢|—|0|Không chiếm ô mới|Tile của Nhà VH Cấp 2+|Đầm Lầy hoặc Sông kề: +1 Lụa/vòng|Nhà VH Cấp 2+ VÀ Đền Thờ Cấp 2+|Tối đa 1 ô; cần ĐĐ nếu cách 1 ô|3 VH + 2 TN + 2V|1 Lụa khi ra VH hoặc TN; kề KDC: +1 Lụa/vòng|
|Phái Sinh|D-05|Nhà Ngân Hàng||🏦|—|1|Thực hữu — 1 ô trống độc lập|Đồng Bằng, Bờ Biển, Khu DC (ảnh hưởng)|Cảng TN (bonus), Vàng SK (bonus)|Khu Chợ Cấp 2+ VÀ Xưởng In Ấn hoạt động|Tối đa 2 ô; cần ĐĐ nếu không liền|5V + 2 VH + 2 KT|Tín Phiếu khi ra Vàng; lãi 0.5V/TP/vòng|
|Đặc Biệt|S-01|Tháp Thiên Văn||🔭|—|7|1 ô thực hữu + 6 ô xung quanh TRỐNG|Núi (ưu tiên), Đồi Cỏ, Đồng Bằng cao|Gió Mạnh kề: aura +1 ô; Đất Linh: bonus roll|Viện NC Cấp 3 trong lãnh thổ|VNC Cấp 3 trong bán kính 3 ô|3 HK + 5 KH + 2 Giấy|Aura R2: +1 KH khi xúc xắc ra KH|
|Đặc Biệt|S-02|Pháo Đài Chiến Lược||🏰|—|4|1 ô thực hữu + 3 ô liền thực hữu (tam giác)|Núi (ưu tiên, +1 bán kính), Đồi Cỏ, Đồng Bằng|Đá Granite (bắt buộc khi xây trên Núi)|Trại KT Cấp 2+ trong lãnh thổ|Trại KT trong bán kính 2 ô|3 Thép + 6 KT + 5V|Aura R2: PQ không dừng; ĐV đối thủ −2 bước|
|Đặc Biệt|S-03|Bảo Tàng Quốc Gia||🏺|—|3|1 ô thực hữu + 2 ô liền thực hữu|Đồng Bằng, Bờ Biển|Suối NN kề: +1 VH/vòng thêm|Nhà VH Cấp 3 + Xưởng In Ấn hoạt động|NVH Cấp 3 trong bán kính 2 ô|2 Lụa + 3 Giấy + 6 VH + 4V|Aura R2: phiếu Chi Phối ×1.5 tại DT/KDC|
|Đặc Biệt|S-04|Đài Phát Thanh LM||📡|—|7|1 ô TH + 6 ô xung quanh ĐỀU là thực hữu|Đồng Bằng, Bờ Biển|Đất Linh (bắt buộc để tối ưu)|Viện NC Cấp 2+ VÀ Trại KT Cấp 2+|Cả hai trong bán kính 3 ô|2 HK + 2 Giấy + 4 KH + 4 KT|Long Mạch +2 ô; CT cùng loại R3: +1 sản lượng|
|Đặc Biệt|S-05|Thiên Đình Tín Ngưỡng||🌙|—|3|1 ô TH + 2 ô cùng địa hình liền (TH)|Rừng (ưu tiên), Núi, Sông, Đầm Lầy|Đá Thiêng (aura +1 ô); Rừng CT (bonus TN)|Đền Thờ Cấp 3 trong lãnh thổ|Đền Thờ Cấp 3 trong bán kính 2 ô|8 TN + 2 Lụa + 1 Thép + 4V|Aura R2: đẩy PQ ra (2 TN); hủy tổng 7 tối đa 2 lần/ván|
|Dự kiến có thay đổi trong tương lai.||||||||||||||
|3.a||3.b||5.a|||5.b|5.c|5.d|||||
|4.a||4.b||4.c|||6.a|6.b|6.c|||||


---

## Sheet: Hình ảnh các đơn vị

|PERISOL — Hình ảnh các đơn vị|||||
|---|---|---|---|---|
|⬡ NHÀCHÍNH (HQ) — Thay đổi ngoại hình mỗi 5 vòng chơi, ngẫu nhiêu các tile trong đất thực hữu sẽ có các hình ảnh mini rải rác|||||
|Vòng|Hình ảnh|Tên Giai Đoạn|Mô Tả|Ghi Chú Art|
|Vòng 1–5||Định Cư|Lều vải, hàng rào gỗ thô, lửa trại nhỏ. Màu xám nâu.|2–3 tòa nhà nhỏ. Không có tường. Cờ hiệu nhỏ màu phe.|
|Vòng 6–10||Làng Xã|Nhà gỗ lợp rơm, giếng nước, chợ nhỏ. Tường đất bắt đầu hình thành.|5–6 công trình. Tường đất bao quanh. Cờ lớn hơn.|
|Vòng 11–15||Thị Trấn|Nhà đá, tháp canh, đường lát đá. Đèn lồng, sinh hoạt tấp nập.|Tường đá thấp. Tháp canh 2 góc. Đèn lồng ban đêm.|
|Vòng 16–20||Thành Phố|Tường thành cao, cổng lớn, tháp cao, nhiều đèn, tráng lệ.|Tường thành đầy đủ. Cổng có biểu tượng phe. Tháp 4 góc. Ánh sáng rực.|
|⬡ KHU TRỰC THUỘC (SUBSIDIARY) — Luôn trông có vẻ nhỏ hơn về quy mô hoặc kích cỡ so với HQ, ngẫu nhiêu các tile trong đất thực hữu sẽ có các hình ảnh mini rải rác|||||
|HQ Giai Đoạn|Hình ảnh|Tên Sub|Mô Tả|Ghi Chú Art|
|HQ Giai Đoạn 1 (v1–5)||Trại Tiền Tiêu|Lều nhỏ, cọc phân vùng, lửa nhỏ.|Giống HQ Định Cư nhưng nhỏ hơn 50%.|
|HQ Giai Đoạn 2 (v6–10)||Làng Nhỏ|2–3 nhà gỗ, hàng rào. Cờ nhỏ màu phe.|Không có giếng nước, không chợ.|
|HQ Giai Đoạn 3 (v11–15)||Tiền Đồn|Tường đất, tháp canh 1 góc. Nhà đá nhỏ.|Bằng HQ Làng Xã về quy mô.|
|HQ Giai Đoạn 4 (v16–20)||Thị Trấn|Có tường thấp, cổng nhỏ. Bằng HQ Thị Trấn.|Không có tháp canh 4 góc như HQ Thành Phố.|
|⚔ ĐƠN VỊ VIỄN CHINH — Thay đổi theo cấp HQ (giai đoạn)|||||
|Cấp HQ|Hình ảnh|Tên|Mô Tả Ngoại Hình|Ghi Chú Art|
|HQ Giai Đoạn 1||Thám Tử|Người đi bộ đơn độc, áo vải thô, ba lô đơn. Vũ khí: gậy gỗ.|Nhỏ nhắn, do dự. Không mặc giáp.|
|HQ Giai Đoạn 2||Lính Bộ|Áo giáp da, khiên gỗ, kiếm ngắn. Màu chủ đạo của phe.|Tư thế tự tin hơn. Có huy hiệu phe nhỏ.|
|HQ Giai Đoạn 3||Hiệp Sĩ|Giáp sắt, khiên kim loại, giáo dài. Huy hiệu phe ngực.|Oai vệ. Áo choàng ngắn. Bóng bẩy hơn.|
|HQ Giai Đoạn 4||Vệ Binh Elite|Giáp toàn thân, vũ khí rực sáng, áo choàng dài màu phe.|Aura phát sáng nhẹ. Kích thước lớn hơn 20%.|
|🛒 ĐƠN VỊ GIAO THƯƠNG — Thay đổi theo cấp HQ (giai đoạn)|||||
|Cấp HQ|Hình ảnh|Tên|Mô Tả Ngoại Hình|Ghi Chú Art|
|HQ Giai Đoạn 1||Lái Buôn Bộ|Người đội nón lá, gánh hàng trên vai. Đơn giản, khiêm tốn.|Chuyển động chậm. Hàng hóa nhỏ.|
|HQ Giai Đoạn 2||Xe Ngựa|Xe gỗ 2 bánh kéo bởi 1 ngựa. Hàng chất đống sau xe.|Có bảng hiệu thương hội nhỏ.|
|HQ Giai Đoạn 3||Xe Hàng Lớn|Xe 4 bánh, 2 ngựa. Mái che, biểu tượng thương hội lớn.|Đồ sộ, chuyên nghiệp. Lái buôn mặc áo vest.|
|HQ Giai Đoạn 4||Đoàn Tàu Hỏa|Đầu tàu nhỏ hơi nước, 2 toa hàng. Khói bốc lên.|Tốc độ animation cao. Còi tàu effect.|
|💀 PHIẾN QUÂN — Thay đổi theo Cấp Leo Thang mỗi 5 vòng, nếu có event up PQ thì sẽ có thể lên cấp 5|||||
|Cấp PQ|Hình ảnh|Tên|Mô Tả Ngoại Hình|Ghi Chú Art|
|Cấp 1 — Kẻ Quấy Phá||Kẻ Quấy Phá|Nhỏ bé, áo rách, côn gỗ. Hành động rụt rè.|Kích thước nhỏ hơn đơn vị thường. Màu xám tối.|
|Cấp 2 — Kẻ Cướp Bóc||Kẻ Cướp Bóc|To hơn, áo da, rìu nhỏ. Biểu cảm hung hăng.|Kích thước bằng đơn vị thường. Màu nâu đỏ.|
|Cấp 3 — Kẻ Phá Hoại||Kẻ Phá Hoại|Lớn hơn đáng kể, giáp da thô, búa nặng. Màu đỏ sẫm.|Kích thước 1.5× đơn vị. Aura đỏ nhẹ. Bụi bốc khi di chuyển.|
|Cấp 4 — Kẻ Chinh Phạt||Kẻ Chinh Phạt|Khổng lồ, giáp sắt hoen gỉ, vũ khí hai tay. Aura đen.|Kích thước 2×. Aura đen rực. Đất rung khi bước.|
|Cấp 5 — Kẻ Hủy Diệt||Kẻ Hủy Diệt|Quái vật, cao bằng CT Cấp 2. Tay cầm cả công trình.|Kích thước 3×. Aura đỏ đen rực. Hiệu ứng phá hủy khi tiến vào tile.|
|Lưu ý, nhân vật chơi/phe phái, quyết định kiểu ngoại hình của các properties người chơi|||||
|Dự kiến có thay đổi trong tương lai.|||||


---

## Sheet: Đặt công trình

|MA TRẬN ĐẶT CÔNG TRÌNH THEO ĐỊA HÌNH||||||||||||
|---|---|---|---|---|---|---|---|---|---|---|---|
|Công Trình \ Địa Hình|Đồng Bằng|Rừng|Núi|Sông|Bờ Biển|Tundra|Sa Mạc|Đầm Lầy|Đồi Cỏ|Khu DC|Danh Thắng|
|Trại Khai Thác C1|✅|✅|❌|❌|✅|✅|✅|❌|✅|❌|❌|
|Trại Khai Thác C2|✅|✅|✅|❌|✅|✅|✅|❌|✅|❌|❌|
|Trại Khai Thác C3|✅|✅|✅|❌|✅|✅|✅|❌|✅|❌|❌|
|Viện Nghiên Cứu C1|✅|⭐|❌|❌|✅|❌|❌|❌|✅|❌|❌|
|Viện NC C2|✅|⭐|❌|❌|✅|❌|❌|❌|✅|❌|❌|
|Viện NC C3|✅|⭐|❌|❌|✅|❌|❌|❌|✅|❌|❌|
|Nhà Văn Hóa C1|✅|❌|❌|❌|✅|❌|❌|❌|❌|⭐|❌|
|Nhà VH C2|✅|❌|❌|❌|✅|❌|❌|❌|✅|⭐|❌|
|Nhà VH C3|✅|❌|❌|❌|✅|❌|❌|❌|✅|⭐|❌|
|Đền Thờ C1|✅|⭐|❌|✅|❌|❌|❌|✅|❌|❌|❌|
|Đền Thờ C2|✅|⭐|❌|✅|❌|❌|❌|✅|✅|❌|❌|
|Đền Thờ C3|✅|⭐|❌|✅|❌|❌|❌|✅|✅|❌|❌|
|Khu Chợ C1|✅|❌|❌|❌|✅|❌|✅|❌|❌|⭐|❌|
|Khu Chợ C2|✅|❌|❌|❌|✅|❌|✅|❌|❌|⭐|❌|
|Khu Chợ C3|✅|❌|❌|❌|✅|❌|✅|❌|❌|❌|❌|
|✅ Được phép ❌ Không được ⭐ Ưu tiên (có bonus)||||||||||||
|Dự kiến có thay đổi trong tương lai.||||||||||||


---

## Sheet: Hạ tầng

|Nhóm Hạ tầng|Tên Hạ tầng|Cấp Độ|Ô Chiếm|Hình ảnh|Chi Phí Xây / Nâng Cấp|Điều Kiện / Địa Hình Hợp Lệ|Tác Dụng & Hiệu Quả Vận Hành|Ghi chú|
|---|---|---|---|---|---|---|---|---|
|Trung Tâm Lãnh Thổ|Nhà Chính (HQ)|Cấp 1|1||Khởi đầu miễn phí|Không đặt trên Núi/Sông|Vùng ảnh hưởng 7 ô (tâm + 6 ô xung quanh).||
||Nhà Chính (HQ)|Cấp 2|1||4 KT + 2 KH + 3 Vàng|Lãnh thổ thực hữu|Mở rộng vùng ảnh hưởng thêm 1 vòng bán kính (tổng 19 ô).||
||Nhà Chính (HQ)|Cấp 3|1||6 KT + 2 Hợp Kim + 5 Vàng|Cần kết nối ít nhất 1 Khu Chợ|Cho phép xây dựng Công Trình Đặc Biệt trong lãnh thổ.||
||Nhà Chính (HQ)|Cấp 4|1||8 KT + 3 Thép + 8 Vàng|Đạt mốc vòng 11+|Tự động nâng cấp Đơn Vị Viễn Chinh lên Hiệp Sĩ.||
||Nhà Chính (HQ)|Cấp 5|1||10 KT + 4 Thép + 4 Hợp Kim + 12 Vàng|Cần sở hữu ít nhất 1 Cảng/Chợ Cấp 3|Mở khóa aura thủ đô: +1 sản lượng cho tất cả công trình nội đô.||
||Khu Trực Thuộc (Sub)|Cấp 1|1||3 TN + 3 Vàng + 3 KT|Cách HQ/Sub khác 1 vòng chu vi|Hoạt động như nhà phụ, mở vùng ảnh hưởng 7 ô.||
||Khu Trực Thuộc (Sub)|Cấp 2|1||4 KT + 3 Vàng|Lãnh thổ thực hữu|Mở rộng ảnh hưởng thêm 1 vòng bán kính; giảm ngưỡng Chi Phối ô xa.||
||Khu Trực Thuộc (Sub)|Cấp 3|1||6 KT + 2 Thép + 5 Vàng|Đạt mốc vòng 16+|Biến Sub thành Đô Thị Vệ Tinh (miễn nhiễm phong tỏa 1 ô tâm).||
|Mạng Lưới Giao Thông|Đường Giao Thông|Cấp 1: Đường Đất|1 / tile||1 Vàng / tile|Đồng Bằng, Rừng, Bờ Biển, Đồi Cỏ|Kết nối Chợ để Trade; Đơn vị đi trên đường +1 di chuyển.||
||Đường Giao Thông|Cấp 2: Đường Lát Đá|1 / tile||1 KT + 1 Vàng / tile|Nâng từ Đường Đất|Đơn vị +2 di chuyển; giảm 50% phí Vàng khi thực hiện Giao Thương.||
||Đường Giao Thông|Cấp 3: Đường Ray Xe Lửa|1 / tile||1 Thép + 1 Than + 2 Vàng / tile|Yêu cầu Công Nghệ Mạng Lưới|Đơn Vị Giao Thương hóa thành Đoàn Tàu Hỏa (+4 bước); kết nối phái sinh xa 4 ô.||
||Đường Giao Thông|Nhánh: Đường Ống Dẫn|1 / tile||1 Hợp Kim + 1 KT + 2 Vàng / tile|Đi ngầm qua Núi, Sông, Đầm Lầy|Vận chuyển Dầu/Than tự động về HQ mỗi vòng mà không cần Đơn Vị.||
|Khai Khoáng & Năng Lượng|Mỏ Than|Cấp 1|1||3 KT + 2 Vàng|Núi, Đồi Cỏ, lãnh nguyên|Sản xuất 1 Than khi xúc xắc ra KT; làm nhiên liệu luyện Thép/chạy Tàu.||
||Mỏ Than|Cấp 2: Hầm Lò Sâu|2 ô liền||5 KT + 2 KH + 4 Vàng|Có quặng/mạch than|Sản xuất 2 Than; +1 Than thụ động mỗi 3 vòng.||
||Giếng Dầu|Cấp 1: Bể Hút|1||4 KT + 3 KH + 4 Vàng|Sa Mạc, Đầm Lầy, Bờ Biển Nông|Sản xuất 1 Dầu Mỏ khi ra KH; 1 Dầu quy đổi thành 3 Vàng hoặc 2 KT.||
||Cụm Khai Thác Dầu|Cấp 2: Giàn Khoan|3 ô liền||7 KT + 4 Hợp Kim + 8 Vàng|Ven biển hoặc Sa Mạc lớn|Sản xuất 3 Dầu khi ra KH; cung cấp năng lượng công nghiệp x2 sản lượng máy móc.||
|Dự kiến có thay đổi trong tương lai.|||||||||


---

## Sheet: Các đơn vị cờ

|PERISOL — BẢNG THÔNG SỐ ĐƠN VỊ (UNIT SPEC) v1.0|||||||||
|---|---|---|---|---|---|---|---|---|
|Nguyên tắc chung|1) Đơn vị KHÔNG chiếm quyền sở hữu tile và KHÔNG chặn việc xây dựng.||||||||
||2) Đơn vị chỉ hành động trong Khâu Hành Động của chủ sở hữu (ngoại lệ: Phiến Quân ở Khâu Giải Quyết).||||||||
||3) Mỗi đơn vị thực hiện tối đa 1 hành động/lượt.||||||||
||4) Điểm di chuyển reset đầu mỗi lượt, KHÔNG dồn sang lượt sau.||||||||
||5) Ô màu vàng là đề xuất, dự kiến có thay đổi||||||||
|1 · TỔNG QUAN THÔNG SỐ ĐƠN VỊ|||||||||
|Bảng master. Mọi chỉ số ở đây là giá trị gốc chưa cộng modifier.|||||||||
|ID|Tên đơn vị|Loại|Phe sở hữu|Vai trò chính|Bước/lượt (cơ bản)|Tầm nhìn (ô)|Sức chở|Giới hạn đồng thời / người|
|U-01|Đơn Vị Viễn Chinh|Di động — Quân sự|Người chơi|Bành trướng lãnh thổ, lập Khu Trực Thuộc, đẩy Phiến Quân, phong tỏa đối thủ|4|2|0|3|
|U-01K|Hiệp Sĩ (nâng cấp của U-01)|Di động — Quân sự|Người chơi|Bản nâng cấp tự động khi HQ đạt Cấp 4; cơ động cao, đi được Núi|6|3|0|3 (dùng chung quota U-01)|
|U-02|Đơn Vị Giao Thương|Di động — Dân sự|Người chơi|Tạo Đường Đất, nối Khu Chợ, thực hiện lượt trade, vận chuyển tài nguyên|5|1|5 đơn vị/loại tn|2|
|U-02T|Đoàn Tàu Hỏa (biến thể của U-02)|Di động — Dân sự|Người chơi|Trạng thái nâng cấp khi di chuyển trên Đường Ray Xe Lửa; vận tải khối lượng lớn|9|2|10|2 (dùng chung quota U-02)|
|U-03|Phiến Quân|Di động — Trung lập|N/A (điều khiển tạm thời)|Gây hỗn loạn có kiểm soát: phong tỏa 7 ô, cướp tài nguyên, hủy đơn vị|1–6 (xúc xắc)|3|0|1 trên bản đồ (2 sau Sự Kiện vòng 10)|
|U-04|Dòng Vận Ống (đơn vị ảo)|Tĩnh — Tự động|Người chơi|Không có mô hình trên bản đồ: tự chuyển Than/Dầu về HQ mỗi vòng qua Đường Ống Dẫn|n/a (tức thời)|0|2 Than/Dầu mỗi vòng|Không giới hạn (theo số tuyến ống)|
|U-05|Sứ Giả|Di động — Ngoại giao|Người chơi|Nâng Hảo Cảm với Khu Dân Cư / Thành Bang Tự Do; dùng 1 lần rồi tiêu hao|6|2|0|1|
|2 · CHI PHÍ, ĐIỀU KIỆN & CÁCH THỨC SPAWN|||||||||
|Đơn vị được sinh ra ở đâu, lúc nào, tốn gì, và bị chặn khi nào.|||||||||
|ID|Tên|Chi phí mua|Nơi spawn hợp lệ|Điều kiện spawn|Khâu được spawn|Hành động ngay khi spawn|Thời gian hồi (cooldown)|Hành vi khi vượt giới hạn|
|U-01|Viễn Chinh|3 TN + 3 V + 3 KT|Ô HQ (mọi cấp), ô Subsidiary C1+, ô Pháo Đài Chiến Lược (S-02)|Ô spawn không bị PQ phong tỏa; còn quota (<3 đơn vị); đủ tài nguyên|Khâu Hành Động (lượt của mình)|Không|Không (mua bao nhiêu lần/lượt cũng được, miễn đủ tài nguyên và quota)|Nút mua bị khóa (disabled) + tooltip 'Đã đạt giới hạn 3 Viễn Chinh'|
|U-01K|Hiệp Sĩ|Miễn phí (tự động)|Tại chỗ — mọi U-01 đang tồn tại chuyển thành Hiệp Sĩ|HQ đạt Cấp 4 (8 KT + 3 Thép + 8 V, mốc vòng 11+)|Ngay khi HQ hoàn tất nâng cấp (Khâu Hành Động)|Giữ nguyên trạng thái/điểm di chuyển còn lại của U-01||n/a — không tăng quota|
|U-02|Giao Thương|5 V|Ô Khu Chợ C1+ thuộc sở hữu; nếu chưa có chợ nào thì spawn ở HQ|Còn quota (<2); ô spawn không bị PQ phong tỏa|Khâu Hành Động (lượt của mình)|Có — di chuyển ngay với đủ 5 bước|Không|Nút mua bị khóa|
|U-02T|Đoàn Tàu Hỏa|Miễn phí (chuyển trạng thái)|Tại chỗ — khi U-02 đứng trên ô có Đường Ray Xe Lửa|Đã học Công Nghệ 'Mạng Lưới Giao Thông'; tuyến ray liên tục ≥ 2 ô|Tự động, đầu Khâu Hành Động|Có — nhận ngay bộ bước mới của Tàu|Trở lại U-02 khi rời khỏi ray||
|U-03|Phiến Quân|Không mua được|Vị trí ngẫu nhiên, hoặc ô bất kì ở tile Đồng Bằng, Tundra, Hoang Mạc cách HQ các người chơi tối thiểu 2 ô|Luôn có đúng 1 PQ khi ván bắt đầu. PQ thứ 2 spawn ở tile Khu Dân Cư xa nhất nếu Sự Kiện vòng 10 'Phong Trào Ly Khai' được lật|Setup / Khâu Giải Quyết (bước 1)|Không di chuyển ở vòng 0|Chỉ kích hoạt khi có người đổ tổng 7 (hoặc kỹ năng Tướng Quân: 1 lần/vòng)|Không thể vượt — hard cap 2|
|U-04|Dòng Vận Ống|Chi phí đường ống: 1 HK + 1 KT + 2 V / tile|Tuyến ống nối Mỏ Than/Giếng Dầu đến HQ|Tuyến ống liên tục, không bị đứt đoạn; không cần đơn vị vật lý|Tự động, đầu Khâu Sản Xuất||Không||
|U-05|Sứ Giả|2 VH + 2 V (ĐỀ XUẤT)|Ô HQ hoặc Nhà Văn Hóa C1+|Còn quota (<1); mục tiêu Khu Dân Cư phải nằm cách ≤ 6 ô|Khâu Hành Động|Có|3 vòng sau khi Sứ Giả trước tiêu hao|Nút mua bị khóa|
|3 · CHI PHÍ DI CHUYỂN THEO ĐỊA HÌNH|||||||||
|Số = điểm di chuyển tiêu tốn để ĐI VÀO ô đó. '∞' = không thể vào (pathfinding loại bỏ ô).|||||||||
|Địa hình|Viễn Chinh (U-01)|Hiệp Sĩ (U-01K)|Giao Thương (U-02)|Đoàn Tàu (U-02T)|Phiến Quân (U-03)|Sứ Giả (U-05)|Ghi chú||
|Đồng Bằng|1|1|1|1 (chỉ trên ray)|1|1|Chi phí cơ bản||
|Rừng|2|1|2|1 (chỉ trên ray)|2|2|−1 bước' = tốn 2 điểm di chuyển||
|Núi|∞ (cấm)|2|∞ (cấm)|∞ (chỉ qua Đường Ống)|∞ trong 10 vòng đầu, sau đó 3|∞ (cấm)|Chỉ Hiệp Sĩ leo được núi||
|Sông|2|2|2|1 (chỉ trên ray/cầu)|2|2|Cần Công Nghệ 'Tuyến Vận Tải Nước' để giảm còn 1||
|Bờ Biển|1|1|1|1 (chỉ trên ray)|1|1|Cảng Tự Nhiên (TN-10): ĐVGT miễn phí Vàng/tile||
|Lãnh Nguyên|2|1|2|1 (chỉ trên ray)|1|2|Lạnh giá làm chậm bộ binh||
|Sa Mạc|2|2|2|1 (chỉ trên ray)|1|2|ĐVGT hết hàng 1 ô/lượt nếu dừng lại ở đây (đề xuất)||
|Đầm Lầy|3|2|3|∞ (chỉ qua Đường Ống)|2|3|Địa hình cản trở nặng nhất còn đi được||
|Đồi Cỏ|1|1|1|1 (chỉ trên ray)|1|1|Tấn công từ Đồi Cỏ: +1 Uy Lực||
|Khu Dân Cư|1|1|1|1 (chỉ trên ray)|1|1|ĐVVC dừng ở đây để Chi Phối Thành Bang||
|Danh Thắng|1|1|1|∞ (cấm đặt ray)|1|1|Không được xây đường qua Danh Thắng||
|Núi Tuyết|∞ (cấm)|3|∞ (cấm)|∞|∞ trong 10 vòng đầu, sau đó 3|∞ (cấm)|Như Núi||
|— Đường Đất (C1)|−1 (tối thiểu 1)|−1|−1||0 (PQ không dùng đường)|−1|mọi đơn vị đi trên Đường +1 di chuyển||
|— Đường Lát Đá (C2)|−1 và +1 bước/lượt|−1 và +1 bước/lượt|−1 và +1 bước/lượt||0|−1 và +1 bước/lượt|Cộng dồn tối đa +2 bước/lượt||
|— Đường Ray (C3)|Đi như Đường Lát Đá|Đi như Đường Lát Đá|Chuyển thành Đoàn Tàu|1/ô|0|Đi như Đường Lát Đá|Chỉ ĐVGT được hưởng +4 bước||
|4 · CÁCH THỨC ĐIỀU KHIỂN — BẢNG HÀNH ĐỘNG|||||||||
|Mỗi đơn vị chỉ thực hiện 1 hành động/lượt (trừ A-06 Giải Thể). Điểm di chuyển reset đầu lượt, không dồn.|||||||||
|ID|Hành động|Đơn vị áp dụng|Chi phí hành động|Điều kiện|Kết quả|Thao tác người chơi (UX)|||
|A-01|Di Chuyển|U-01, U-01K, U-02, U-02T, U-05|Tiêu điểm di chuyển theo ô đi qua|Còn điểm di chuyển; ô đích không phải địa hình cấm|Đơn vị đổi vị trí; ĐVGT tự tạo Đường Đất trên mỗi ô chưa có đường (1 V/ô)|Click đơn vị → highlight vùng đi được (flood-fill theo cost) → click ô đích → preview đường đi + chi phí → xác nhận|||
|A-02|Lập Khu Trực Thuộc|U-01, U-01K|Toàn bộ lượt + 3 TN + 3 V + 3 KT (chi phí Sub C1)|Ô đứng là Lãnh thổ thực hữu; không phải Núi/Sông; cách HQ/Sub khác ≥ 1 vòng chu vi; vùng ảnh hưởng không đè lên Danh Thắng / Khu Dân Cư|Sub Cấp 1 được đặt; ĐƠN VỊ BỊ TIÊU THỤ (biến mất vĩnh viễn)|Click đơn vị → nút 'Lập Khu Trực Thuộc' → preview vòng ảnh hưởng 7 ô (đỏ nếu xung đột) → xác nhận 2 bước (có cảnh báo 'đơn vị sẽ mất')|||
|A-03|Giao Chiến|U-01, U-01K|Toàn bộ lượt|Mục tiêu (PQ / đơn vị địch / Chốt địch) ở ô kề|Giải quyết theo sheet 5|Click đơn vị → click mục tiêu kề (viền đỏ) → hộp thoại tỉ lệ thắng → xác nhận → animation xúc xắc|||
|A-04|Trú Đóng|U-01, U-01K|Toàn bộ lượt|Không có mục tiêu địch kề|+2 DEF đến hết vòng sau; hồi 1 HP; PQ không dừng được trên ô kề|Click đơn vị → nút 'Trú Đóng' (phím tắt F)|||
|A-05|Hộ Tống|U-01, U-01K|Toàn bộ lượt|Một ĐVGT của mình ở ô kề|ĐVGT được gắn cờ Hộ Tống: PQ không hủy được nó ở vòng này (thay vào đó ĐVVC mất 1 HP)|Kéo-thả ĐVVC lên ĐVGT, hoặc chọn rồi bấm 'Hộ Tống'|||
|A-06|Giải Thể|U-01, U-01K, U-02, U-02T, U-05|Tức thì, không tốn lượt|Bất kỳ lúc nào trong Khâu Hành Động của mình|Đơn vị biến mất; hoàn 1 V (ĐVVC) hoặc 2 V (ĐVGT)|Chuột phải vào đơn vị → 'Giải thể' → xác nhận|||
|A-07|Chốt Giao Thương|U-02, U-02T|Tức thì khi vào ô chợ đích|Đơn vị xuất phát từ 1 Khu Chợ và đã tới Khu Chợ khác (của mình hoặc đối tác đang trade)|Hoàn tất 1 lượt trade: chuyển hàng, tính phí 1 V/ô quãng đường (−50% nếu toàn tuyến là Đường Lát Đá)|Tự động kích hoạt, hiện popup tổng kết chuyến hàng|||
|A-08|Nâng Hảo Cảm|U-05|Toàn bộ lượt + tiêu hao đơn vị|Đơn vị đứng trên ô thuộc cụm Khu Dân Cư / Thành Bang Tự Do|+1 Hảo Cảm (thang 0–3) với cụm đó; ĐƠN VỊ BỊ TIÊU THỤ|Click đơn vị trên Khu Dân Cư → nút 'Giao Hảo' → xác nhận|||
|A-09|Điều Hướng Phiến Quân|U-03 (do người chơi điều khiển tạm thời)|Không tốn hành động của người chơi|Vừa đổ tổng 7 · HOẶC là Nhân vật Tướng Quân (1 lần/vòng, tối đa 3 bước)|PQ di chuyển đúng số bước; áp dụng hiệu ứng ô dừng (GDD 6.2)|Sau khi đổ 7: bản đồ vào chế độ 'Điều Hướng PQ', highlight từng ô kề hợp lệ, click từng bước một, bộ đếm bước giảm dần; không được Undo sau khi bước|||
|A-10|Điều Hướng Phiến Quân|U-03 (điều khiển tạm thời)|Không tốn hành động của người chơi|Vừa đổ tổng 7 · HOẶC là Tướng Quân (1 lần/vòng, tối đa 3 bước)|PQ di chuyển đúng số bước; áp dụng hiệu ứng ô dừng + hư hại hạ tầng|Sau khi đổ 7: bản đồ vào chế độ 'Điều Hướng PQ', highlight từng ô kề hợp lệ, click từng bước, bộ đếm giảm dần, KHÔNG được Undo|||
|A-11|Đẩy Phiến Quân (không cần đơn vị)|Sắc Lệnh / Thiên Đình S-05 / kỹ năng|Theo nguồn hiệu ứng|Theo thẻ; Thiên Đình: trả 2 TN khi PQ dừng trong aura bán kính 2|PQ bị dời ra ô chỉ định|Overlay chọn ô đích hợp lệ|||
|A-12|Phá Hoại Hạ Tầng|Sắc Lệnh (ĐỀ XUẤT) / Pháo Đài Cấp +2|Theo nguồn hiệu ứng|Ô hạ tầng mục tiêu nằm trong tầm của nguồn hiệu ứng|Trừ Độ Bền — đây là cách duy nhất người chơi chủ động cắt tuyến của đối thủ|Overlay chọn ô hạ tầng địch trong tầm; hiện độ bền hiện tại → sau khi phá|||
|5 · TRẤN ÁP PHIẾN QUÂN (A-03)|||||||||
|Đổ xúc xắc so với ngưỡng, hoặc trả Tín Ngưỡng để bỏ qua rủi ro.|||||||||
|Nội dung|Chi tiết||||||||
|Ai được Trấn Áp|Chỉ U-01 Viễn Chinh và U-01K Hiệp Sĩ. ĐVGT, Sứ Giả, Chốt Phòng Thủ không bao giờ trấn áp.||||||||
|Cách giải quyết|Đổ 1 viên xúc xắc (1–6). Kết quả ≥ NGƯỠNG TRẤN ÁP → THÀNH CÔNG.||||||||
|Ngưỡng cơ bản|Viễn Chinh: 4 · Hiệp Sĩ: 3||||||||
|Điều chỉnh ngưỡng (cộng dồn, sàn 2)|−1 nếu xuất phát từ ô Đồi Cỏ / Núi · −1 nếu đơn vị đang ở trong aura Pháo Đài của mình · −1 nếu vừa Trú Đóng lượt trước · −1 nếu là Tướng Quân · −1 nếu có Chốt Phòng Thủ của mình kề PQ · +1 nếu PQ đang đứng trên Núi hoặc Núi Tuyết||||||||
|Phương án chắc thắng (không đổ xúc xắc)|Trả 2 TN để Trấn Áp thành công tự động, không rủi ro. Giảm còn 1 TN nếu đơn vị nằm trong bán kính 3 ô của Thiên Đình (S-05). Cho người chơi không muốn mạo hiểm 9 tài nguyên.||||||||
|THÀNH CÔNG|PQ bị đẩy 2 ô theo hướng người chơi chọn (không đẩy vào Núi trong 10 vòng đầu, không đẩy ra ngoài bản đồ, không đẩy vào aura Pháo Đài). Người chơi nhận 1 TN. Phong tỏa của PQ bị hủy trong vòng này. Đơn vị Viễn Chinh KHÔNG di chuyển theo.||||||||
|THẤT BẠI|Đơn vị Viễn Chinh BỊ TIÊU HỦY hoàn toàn (mất 3 TN + 3 V + 3 KT). PQ đứng yên. Ngoại lệ: Hiệp Sĩ được rút về HQ thay vì mất — 1 lần mỗi 5 vòng.||||||||
|Không có combat giữa hai người chơi|Đơn vị của các phe khác nhau đi xuyên qua nhau, không tấn công, không chặn, không cướp hàng. Cách duy nhất làm hại đối thủ là: điều hướng PQ đè lên đơn vị của họ (A-10), dùng Sắc Lệnh, hoặc phá hạ tầng của họ (A-12).||||||||
|PQ đè lên đơn vị|Khi PQ dừng lại trên ô có đơn vị bất kỳ: đơn vị đó bị TIÊU HỦY ngay, không có phép kiểm tra. ĐVGT mất luôn hàng đang chở. Ngoại lệ duy nhất: có ĐVVC đang Hộ Tống (A-05), hoặc Chốt Phòng Thủ trên cùng ô.||||||||
|6 · ĐỘ BỀN HẠ TẦNG — PHÁ HOẠI & SỬA CHỮA|||||||||
|Độ Bền (ĐB) tính theo TỪNG Ô, không phải theo cả tuyến. Một ô về 0 là đủ cắt đứt toàn tuyến. Áp dụng cho Đường Ray và Đường Ống Dẫn là chính.|||||||||
|6.1 · Độ Bền tối đa và hệ quả khi xuống cấp|||||||||
|ID|Hạ tầng|ĐB tối đa / ô|ĐB = tối đa|ĐB = 1|ĐB = 0 (HỎNG)|Bị xóa khỏi bản đồ?|||
|HT-01|Đường Đất (C1)|1|Hoạt động bình thường: +1 di chuyển, nối chợ để trade|(không có mức trung gian)|Đường biến mất hoàn toàn khỏi ô; tuyến trade đứt|Có — phải xây lại 1 V|||
|HT-02|Đường Lát Đá (C2)|2|+2 di chuyển, giảm 50% phí giao thương|Tụt xuống hoạt động như Đường Đất (+1 di chuyển)|Ô chỉ còn lại Đường Đất ĐB 1 (không mất trắng)|Không — tụt cấp|||
|HT-03|Đường Ray (C3)|3|Đoàn Tàu chạy được: +4 bước, sức chở 10, nối phái sinh xa 4 ô|Ray sứt mẻ: Tàu KHÔNG chạy được, ĐVGT trở lại trạng thái thường; ô hoạt động như Đường Lát Đá|Ray hỏng: cắt đứt mạng ray; ô tụt về Đường Lát Đá ĐB 1|Không — tụt cấp|||
|HT-04|Đường Ống Dẫn|2|Dòng Vận Ống (U-04) chạy đủ công suất: 2 Than/Dầu mỗi vòng về HQ|Rò rỉ: công suất giảm còn 1 Than/Dầu mỗi vòng|Ống vỡ: TOÀN TUYẾN ngừng vận chuyển cho đến khi sửa xong ô này|Không — ô giữ trạng thái 'ống vỡ', sửa được|||
|6.2 · Nguồn gây hư hại (trừ Độ Bền)||||||6.4 · Cách tính công suất Dòng Vận Ống (U-04)|||
|Nguồn|Mục tiêu|Sát thương|Tần suất|Ghi chú||Bước|Quy tắc||
|Phiến Quân DỪNG trên ô|Mọi hạ tầng trên ô đó, kể cả Đường Ống ngầm (sụt lún)|−1 ĐB|Mỗi lần PQ dừng|Đây là lý do chính khiến tuyến dài khó giữ||1|Xác định tuyến ống liên tục từ Mỏ Than / Giếng Dầu về HQ (BFS trên các ô có Đường Ống).||
|Phiến Quân ĐI QUA (không dừng)|Chỉ Đường Đất|−1 ĐB (tức là xóa)|Mỗi lần đi qua|Ray, Lát Đá và Ống miễn nhiễm khi PQ chỉ đi qua||2|ĐB_tuyến = MIN(ĐB của mọi ô trên tuyến). Mắt xích yếu nhất quyết định toàn tuyến.||
|Sự Kiện 'Lũ Lớn' (vòng 10)|Mọi hạ tầng trên Sông / Bờ Biển / Đầm Lầy|−1 ĐB toàn bản đồ|1 lần khi lật thẻ|Tác động lên mọi người chơi cùng lúc||3|ĐB_tuyến = 2 → vận chuyển 2 Than/Dầu mỗi vòng. ĐB_tuyến = 1 → 1 mỗi vòng (rò rỉ). ĐB_tuyến = 0 → 0, tuyến ngừng hoàn toàn.||
|Sự Kiện 'Bão Tuyết Qua Núi' (vòng 10)|Mọi hạ tầng trên Núi / Núi Tuyết / Lãnh Nguyên|−1 ĐB toàn bản đồ|1 lần khi lật thẻ|Đánh mạnh vào tuyến Mỏ Than trên núi||4|Nếu có nhiều tuyến song song về cùng HQ, cộng công suất từng tuyến (khuyến khích xây tuyến dự phòng).||
|Sự Kiện 'Mùa Hạn' (vòng 10)|Đường Ống trên Sa Mạc|−1 ĐB|1 lần khi lật thẻ|Nhắm vào chuỗi Giếng Dầu||5|UI: tô màu tuyến ống theo ĐB — xanh (đủ), vàng (rò rỉ), đỏ nhấp nháy (vỡ), kèm cảnh báo ở đầu Khâu Sản Xuất.||
|Sự Kiện 'Cách Mạng Công Nghiệp' (vòng 15)|Đường Ray và Đường Ống|+1 ĐB TỐI ĐA (buff)|Kéo dài đến hết ván|Thẻ duy nhất làm hạ tầng bền hơn||6|Logic tương tự cho Đường Ray: mạng ray chỉ cho Đoàn Tàu chạy nếu MỌI ô trên đường đi có ĐB ≥ 2.||
|Sắc Lệnh 'Phá Hoại Tuyến' (ĐỀ XUẤT — nhóm Tức Thì)|1 ô hạ tầng của đối thủ trong vùng ảnh hưởng của mình|−2 ĐB|1 lần/thẻ|Cách duy nhất người chơi CHỦ ĐỘNG cắt tuyến đối thủ|||||
|Pháo Đài Chiến Lược Cấp +2 ('Pháo')|1 ô hạ tầng HOẶC 1 công trình Cấp 1 của đối thủ, bán kính 3|−2 ĐB|1 lần/5 vòng|Mở rộng từ GDD mục 8.3|||||
|Hao mòn tự nhiên|Đường Ống đi qua Đầm Lầy hoặc Sông|−1 ĐB|Mỗi 5 vòng|Đánh đổi của việc đi tắt qua địa hình xấu|||||
|Không trả nổi chi phí bảo trì|Hạ tầng đang đặt chế độ tự sửa (6.3)|Chế độ tự sửa tắt, không mất ĐB|Khi thiếu Vàng|Không trừng phạt kép|||||
|6.3 · Sửa chữa|||||||||
|Cách|Ai thực hiện|Chi phí (mỗi 1 điểm ĐB)|Tốc độ|Điều kiện|||||
|Sửa thủ công (A-06)|U-02 Giao Thương, U-02T, U-01, U-01K đứng trên ô|Đường Đất/Lát Đá: 1 V · Đường Ray: 1 Thép + 1 V · Đường Ống: 1 HK + 1 V|Tối đa 2 điểm/lượt, tốn toàn bộ lượt của đơn vị|Ô không bị PQ phong tỏa; đơn vị phải đứng đúng ô|||||
|Tự sửa từ HQ|Tự động, không cần đơn vị|2 V mỗi điểm (đắt hơn vì tiện)|1 điểm/vòng, mỗi vòng chỉ sửa 1 ô (ô hỏng gần HQ nhất trước)|Ô nằm trong Lãnh thổ thực hữu VÀ còn tuyến liên tục nối về HQ; bật/tắt bằng công tắc trong UI|||||
|Công Nghệ 'Mạng Lưới Giao Thông' Cấp 2|Tự động|Miễn phí|1 điểm/vòng cho toàn bộ mạng lưới|Đã nâng thẻ lên Cấp 2|||||
|Công Nghệ 'Kiến Trúc Kiên Cố'|Thụ động|||+1 ĐB TỐI ĐA cho mọi hạ tầng của mình — phòng bệnh thay vì chữa bệnh|||||
|Xây lại từ đầu|U-02 Giao Thương|Chi phí xây mới đầy đủ (sheet GDD 9.2)|Theo hành động xây đường thường|Tile trống|||||
|7 · MODIFIER TỪ TNCL / CÔNG TRÌNH / NHÂN VẬT / CÔNG NGHỆ|||||||||
|Thứ tự áp dụng: Gốc → Nhân vật → Công Nghệ → Công Trình (aura) → TNCL → Hạ tầng (đường). Làm tròn xuống ở bước cuối.|||||||||
|Nguồn|Loại|Đơn vị / hạ tầng bị ảnh hưởng|Hiệu ứng|Cộng dồn?|||||
|TN-04 Ngựa|TNCL (bonus ô)|U-01, U-01K|+2 bước nếu HQ nằm trong bán kính 2 ô|Có — không cần sở hữu tile|||||
|TN-04 Ngựa + Chuồng Ngựa|TNCL (bonus công trình)|U-01|−2 TN chi phí mua Viễn Chinh (còn 1 TN + 3 V + 3 KT)|Cần sở hữu tile|||||
|TN-10 Cảng Tự Nhiên|TNCL (bonus ô)|U-02, U-02T|+3 bước; miễn phí Vàng cho mỗi ô đường tạo ra|Có|||||
|TN-11 Gió Mạnh|TNCL (bonus ô)|U-01, U-03|Viễn Chinh +1 bước khi đi qua ô này; Phiến Quân +2 bước ngẫu nhiên|Có|||||
|TN-05 Quặng Lộ Thiên|TNCL (bonus công trình)|HT-03 Đường Ray|Sửa ray trên ô này chỉ tốn 1 V, không cần Thép (ĐỀ XUẤT)|Cần sở hữu tile|||||
|S-02 Pháo Đài Chiến Lược|Công Trình Đặc Biệt (aura R2)|U-03, U-01|PQ không được dừng trong aura → hạ tầng trong aura gần như không bao giờ hỏng vì PQ · ĐVVC của mình xuất phát từ Pháo Đài +2 bước lượt đầu · Ngưỡng Trấn Áp −1 trong aura|Aura R3 ở Cấp +1|||||
|S-02 Cấp +2 ('Pháo')|Công Trình Đặc Biệt|Hạ tầng & công trình địch|1 lần/5 vòng: −2 ĐB cho 1 ô hạ tầng, HOẶC phá 1 công trình Cấp 1 của đối thủ trong bán kính 3|Không|||||
|S-04 Đài Long Mạch|Công Trình Đặc Biệt|U-03|PQ trong bán kính 1 chỉ phong tỏa 3 ô thay vì 7|Không|||||
|S-05 Thiên Đình|Công Trình Đặc Biệt (aura R2)|U-03, U-01|Trả 2 TN đẩy PQ ra ngoài aura; chi phí 'chắc thắng' khi Trấn Áp giảm từ 2 TN xuống 1 TN trong bán kính 3|Không|||||
|Thương Nhân (nhân vật)|Kỹ năng gốc|U-02, U-02T|+2 bước; giảm 1 V chi phí xây đường/di chuyển mỗi ô; quota ĐVGT tăng lên 3|Có|||||
|Tướng Quân (nhân vật)|Kỹ năng gốc|U-01, U-03|Điều khiển PQ không cần đổ 7 (1 lần/vòng, 3 bước); ngưỡng Trấn Áp −1|Có|||||
|Học Sĩ (nhân vật)|Kỹ năng gốc|Hạ tầng|Không ảnh hưởng trực tiếp — nhưng mở Công Nghệ nhanh hơn nên đạt tự-sửa-miễn-phí sớm hơn||||||
|HQ Cấp 4|Hạ tầng|U-01 → U-01K|Tự động nâng toàn bộ Viễn Chinh thành Hiệp Sĩ|Một lần duy nhất|||||
|HQ Cấp 5|Hạ tầng|Hạ tầng nội đô|Aura thủ đô +1 sản lượng; ĐỀ XUẤT: hạ tầng trong lãnh thổ được tự sửa miễn phí 1 điểm/vòng|Có|||||
|Công Nghệ 'Mạng Lưới Giao Thông'|Thẻ Công Nghệ (⚙)|U-02, HT-03|C1: mở khóa Đường Ray · C2: tự sửa hạ tầng 1 điểm/vòng miễn phí · C3: ĐVGT không tốn Vàng khi đi trên đường của mình|Có|||||
|Công Nghệ 'Kiến Trúc Kiên Cố'|Thẻ Công Nghệ (⚙)|Mọi hạ tầng của mình|+1 Độ Bền TỐI ĐA (Ray lên 4, Ống lên 3)|Có|||||
|8 · HẰNG SỐ CÂN BẰNG (TUNABLE) + MÁY TÍNH BƯỚC DI CHUYỂN|||||||||
|Chữ xanh dương = ô nhập tay, sửa trực tiếp để playtest. Ô nền vàng = ô thử nghiệm. Ô đỏ = kết quả tính tự động.|||||||||
|8.1 Hằng số|||||||||
|Hằng số|Giá trị|Đơn vị|Ghi chú / Nguồn||||||
|MAX_EXPEDITION_PER_PLAYER|3|đơn vị|Quota Viễn Chinh đồng thời||||||
|MAX_TRADE_PER_PLAYER|2|đơn vị|Quota Giao Thương (Thương Nhân = 3)||||||
|MAX_OUTPOST_PER_PLAYER|4|đơn vị|Quota Chốt Phòng Thủ (đề xuất)||||||
|EXPEDITION_BASE_MOVE|4|bước|GDD 7.2||||||
|KNIGHT_BASE_MOVE|6|bước|Đề xuất||||||
|TRADE_BASE_MOVE|5|bước|GDD 5.4||||||
|TRAIN_BASE_MOVE|9|bước|5 + 4 (GDD 9.2)||||||
|SUPPRESS_THRESHOLD_EXPEDITION|4|mặt xúc xắc|Đổ ≥ giá trị này thì Trấn Áp thành công||||||
|SUPPRESS_THRESHOLD_KNIGHT|3|mặt xúc xắc|Hiệp Sĩ dễ hơn||||||
|SUPPRESS_THRESHOLD_FLOOR|2|mặt xúc xắc|Sàn — mọi modifier cộng lại không xuống thấp hơn||||||
|SUPPRESS_GUARANTEE_FAITH|2|TN|Trả để chắc thắng, bỏ qua xúc xắc||||||
|REBEL_BLOCKADE_TILES|7|ô|GDD 6.2 (tâm + 6 kề)||||||
|REBEL_MOVE_DICE|6|mặt|1d6, GDD 6.2||||||
|REBEL_MOUNTAIN_LOCK_ROUNDS|10|vòng|GDD 6.2||||||
|EXPEDITION_UPKEEP_GOLD|1|V/vòng|Từ đơn vị thứ 2 (đề xuất)||||||
|ROAD_COST_PER_TILE|1|V/ô|GDD 9.2 Cấp 1||||||
|TRADE_FEE_PER_TILE|1|V/ô|GDD 5.4||||||
|DURABILITY_DIRT_ROAD|1|điểm|Đường Đất — hỏng là mất hẳn||||||
|DURABILITY_STONE_ROAD|2|điểm|Đường Lát Đá||||||
|DURABILITY_RAILWAY|3|điểm|Đường Ray||||||
|DURABILITY_PIPELINE|2|điểm|Đường Ống Dẫn||||||
|RAIL_MIN_DURABILITY_FOR_TRAIN|2|điểm|Dưới mức này Đoàn Tàu không chạy||||||
|REPAIR_PER_ACTION_MAX|2|điểm/lượt|Sửa thủ công (A-06)||||||
|AUTO_REPAIR_PER_ROUND|1|điểm/vòng|Tự sửa từ HQ||||||
|AUTO_REPAIR_GOLD_COST|2|V/điểm|Tự sửa đắt hơn sửa tay||||||
|PIPELINE_WEAR_INTERVAL|5|vòng|Hao mòn ống qua Đầm Lầy/Sông||||||
|ENVOY_LIFETIME_ROUNDS|3|vòng|Đề xuất (U-06)||||||
|8.2 Tính bước di chuyển hiệu dụng|||||||||
|Thành phần|Giá trị|Ghi chú|||||||
|Bước cơ bản của đơn vị|4|Lấy từ 9.1 — ví dụ Viễn Chinh = 4|||||||
|Bonus nhân vật|0|Thương Nhân +2 cho ĐVGT|||||||
|Bonus TNCL (Ngựa / Cảng / Gió)|2|TN-04 Ngựa = +2|||||||
|Bonus công trình (xuất phát từ Pháo Đài)|2|S-02 = +2 lượt đầu|||||||
|Bonus đường (Đất +1 / Lát Đá +2 / Ray +4)|1|Chỉ tính cấp đường cao nhất còn nguyên vẹn|||||||
|TỔNG BƯỚC HIỆU DỤNG (tối thiểu 1)|9|MAX(1, tổng các thành phần trên)|||||||
|8.3 Tính ngưỡng Trấn Áp & xác suất|||||||||
|Thành phần (nhập số âm để giảm ngưỡng)|Giá trị|Ghi chú|||||||
|Ngưỡng cơ bản (Viễn Chinh 4 / Hiệp Sĩ 3)|4||||||||
|−1 nếu xuất phát từ Đồi Cỏ / Núi|0||||||||
|−1 nếu trong aura Pháo Đài của mình|0||||||||
|−1 nếu vừa Trú Đóng lượt trước|0||||||||
|−1 nếu là Tướng Quân|0||||||||
|−1 nếu có Chốt Phòng Thủ kề Phiến Quân|0||||||||
|+1 nếu PQ đứng trên Núi / Núi Tuyết|0||||||||
|NGƯỠNG CUỐI CÙNG (sàn 2, trần 6)|4|Sàn lấy từ SUPPRESS_THRESHOLD_FLOOR (ô B15)|||||||
|XÁC SUẤT TRẤN ÁP THÀNH CÔNG|50.0%|Số mặt xúc xắc thỏa mãn chia 6|||||||
|9 · TRẠNG THÁI ĐƠN VỊ|||||||||
|Dùng để dựng UnitController trong Godot 4 / C#. Phiến Quân chỉ dùng IDLE → MOVING → IDLE. Hạ tầng dùng FSM riêng: INTACT → DAMAGED → BROKEN → (sửa) → INTACT.|||||||||
|Trạng thái|Mô tả|Vào trạng thái khi|Ra khỏi trạng thái khi|Được phép hành động|||||
|SPAWNING|Vừa được tạo, chưa vào lưới hex|Người chơi bấm mua, trừ tài nguyên thành công|Đặt xong lên ô spawn (ngay lập tức)|Không|||||
|IDLE|Đang đứng yên, còn điểm di chuyển|Đầu Khâu Hành Động của chủ sở hữu; hoặc vừa spawn xong|Chọn bất kỳ hành động nào|Tất cả (A-01 → A-09)|||||
|MOVING|Đang thực thi đường đi|Xác nhận ô đích ở A-01|Hết điểm di chuyển · tới đích · bị đình trệ bởi aura PQ|Không (khóa input đến khi animation xong)|||||
|SUPPRESSING|Đang giải quyết Trấn Áp Phiến Quân|Xác nhận A-03|Xúc xắc giải quyết xong (hoặc trả 2 TN bỏ qua)|Không|||||
|GARRISONED|Đang Trú Đóng — chặn PQ dừng ở ô kề, ngưỡng Trấn Áp lượt sau −1|Chọn A-04|Đầu lượt kế tiếp nếu người chơi ra lệnh khác|Chỉ A-07 Giải Thể|||||
|REPAIRING|Đang sửa hạ tầng trên ô đang đứng|Xác nhận A-06|Cộng xong tối đa 2 điểm ĐB|Không|||||
|STALLED|Đình trệ — mất lượt (chủ yếu ĐVGT)|Bước vào bán kính 1 của PQ; hoặc Pháo Đài Cấp +1 chặn ĐVVC địch|Hết lượt hiện tại · PQ rời đi|Không|||||
|EXHAUSTED|Đã dùng hết lượt / điểm di chuyển|Kết thúc A-01..A-06, A-09|Đầu Khâu Hành Động lượt sau (reset về IDLE)|Chỉ A-07 Giải Thể|||||
|CONSUMED|Bị tiêu thụ có chủ ý (biến thành thứ khác)|A-02 Lập Sub · A-09 Nâng Hảo Cảm|Trạng thái cuối — xóa khỏi bộ nhớ|Không|||||
|DESTROYED|Bị xóa ngoài ý muốn|PQ dừng lên ô · Trấn Áp thất bại · Sắc Lệnh · không trả nổi upkeep|Trạng thái cuối — phát VFX rồi xóa|Không|||||
|TRANSFORMED|Đổi loại đơn vị|U-01 → U-01K khi HQ Cấp 4 · U-02 ⇄ U-02T khi lên/xuống Đường Ray còn ĐB ≥ 2|Ngay sau khi thay model + chỉ số|Kế thừa trạng thái trước đó|||||


---

## Sheet: Hỏi đáp

|#|Câu hỏi thiết kế còn bỏ ngỏ|Đề xuất trong file này|
|---|---|---|
|1|Không có combat thì Viễn Chinh đẩy Phiến Quân bằng cách nào? (GDD 6.3 nói 'chiến đấu thắng')|Trấn Áp: đổ 1d6 ≥ ngưỡng 4, thất bại thì mất đơn vị; hoặc trả 2 TN để chắc thắng (sheet 5)|
|2|Đơn vị hai người chơi gặp nhau thì sao?|Đi xuyên qua nhau, không chặn, không tấn công. Muốn hại nhau thì dùng PQ, Sắc Lệnh, hoặc phá hạ tầng, dừng ở tile nhau thì ưu tiên đv đã ở đó sẵn|
|3|ĐKT Tướng Quân yêu cầu 'phong tỏa HQ đối thủ bằng Viễn Chinh' — làm sao khi không có combat?|Phong tỏa = đặt ĐVVC/Chốt lên mọi ô lối ra của vùng ảnh hưởng HQ địch, chặn họ mở rộng — không phải giao tranh. Cần chốt lại định nghĩa 'phong tỏa'|
|4|Giới hạn số đơn vị mỗi người chơi?|3 Viễn Chinh|
|5|Có upkeep không? Không có thì người chơi spam Viễn Chinh cuối ván|1 V/unit/vòng từ đơn vị thứ 2|
|6|Độ Bền hạ tầng: theo ô hay theo tuyến?|THEO Ô. ĐB tuyến = MIN của các ô, để một điểm yếu là đủ cắt cả tuyến (sheet 6.4)|
|7|Người chơi có được chủ động phá hạ tầng của đối thủ không?|Có — qua Sắc Lệnh 'Phá Hoại Tuyến' (đề xuất thêm vào bộ 30 lá) và 'Pháo' của Pháo Đài Cấp +2|
|8|Đường Ống có bị Phiến Quân ảnh hưởng không dù đi ngầm?|PQ chỉ gây hại khi DỪNG trên ô (sụt lún −1 ĐB); đi qua thì không. Phong tỏa không ảnh hưởng ống|
|9|Đoàn Tàu Hỏa là đơn vị riêng hay trạng thái của ĐVGT?|Trạng thái (TRANSFORMED). Ray tụt xuống ĐB ≤ 1 thì tàu tự trở lại thành ĐVGT, không mất đơn vị|
|10|ĐVVC có đi được lên Núi không?|Không — chỉ Hiệp Sĩ (HQ Cấp 4), tạo động lực nâng HQ|
|11|Đường do ĐVGT tạo có mất khi ĐVGT bị hủy không?|Không — đường là hạ tầng vĩnh viễn thuộc về bản đồ|
|12|Đơn vị có tính điểm cuối ván không?|Không, tránh việc spam đơn vị farm điểm|


---

