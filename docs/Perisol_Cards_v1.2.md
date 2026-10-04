**PERISOL**

Thiết Kế Bộ Thẻ --- v1.2

*80 thẻ · 4 bộ · Thẻ \[MỚI\] bổ sung thiết kế*

  --------------------------------------------------------------------------------------------------------
  **Bộ Thẻ**            **Tổng**   **Sẵn có**   **Mới thêm**   **Ghi chú**
  --------------------- ---------- ------------ -------------- -------------------------------------------
  Cây Công Nghệ         30         6            24             5 trường phái × 6 thẻ, mỗi thẻ 3 cấp nâng

  Sắc Lệnh              30         9            21             3 nhóm: Tức Thì / Phản Ứng / Nội Tại

  Sự Kiện Tổng          20         7            13             4 mốc: Vòng 5 / 10 / 15 / 20

  Kỹ Năng Nhân Vật      ---        ---          ---            Gắn liền nhân vật, thiết kế riêng
  --------------------------------------------------------------------------------------------------------

# I. CÂY CÔNG NGHỆ (30 THẺ)

*Mua bằng 3 Khoa Học + 3 Kỹ Thuật. Tối đa 5 thẻ hoạt động cùng lúc. Mỗi thẻ có 3 cấp nâng cấp.*

*Chi phí nâng cấp = ceil(chi_phí_trước × 1.8) + Vàng. Thẻ ký hiệu ✦ là thẻ thiết kế mới.*

## ⚙ Trường Phái Kỹ Thuật --- Hạ tầng & Lãnh thổ

+--------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------+
| **T-ENG-01**             | **⬡** Mở khóa khả năng xây dựng Cảng và Chợ.                                                                                                    |
|                          |                                                                                                                                                 |
| **Mạng Lưới Giao Thông** | > **Cấp 1:** Đơn vị Giao thương +1 bước di chuyển. Giảm 1 Vàng chi phí xây Đường Đất.                                                           |
|                          | >                                                                                                                                               |
|                          | > **Cấp 2:** Đơn vị Giao thương +2 bước di chuyển. Đường Đất không tốn Vàng.                                                                    |
|                          | >                                                                                                                                               |
|                          | > **Cấp 3:** Khi Giao thương hoàn thành 1 vòng đi-về, nhận thêm 1 Vàng thưởng.                                                                  |
+==========================+=================================================================================================================================================+
| **T-ENG-02**             | **⬡** Giảm ngưỡng token Chi Phối khi mở rộng Lãnh thổ thực hữu từ tâm HQ/Subsidiary.                                                            |
|                          |                                                                                                                                                 |
| **Kiến Trúc Kiên Cố**    | > **Cấp 1:** Ngưỡng phiếu ở khoảng cách 2 giảm xuống còn 1.                                                                                     |
|                          | >                                                                                                                                               |
|                          | > **Cấp 2:** Ngưỡng phiếu ở khoảng cách 3+ giảm xuống còn 2.                                                                                    |
|                          | >                                                                                                                                               |
|                          | > **Cấp 3:** Mỗi Subsidiary xây dựng thêm mang lại 1 phiếu Chi Phối miễn phí tại vị trí đặt.                                                    |
+--------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------+
| **T-ENG-03**             | **⬡** Công trình trên Lãnh thổ thực hữu của bạn không thể bị dỡ bỏ bởi Sắc Lệnh của đối thủ.                                                    |
|                          |                                                                                                                                                 |
| **Gia Cố Phòng Thủ** ✦   | > **Cấp 1:** Nếu Phiến Quân dừng trên tile có công trình của bạn, giảm 50% lượng tài nguyên bị mất (thay vì ceil).                              |
|                          | >                                                                                                                                               |
|                          | > **Cấp 2:** Khi dỡ bỏ công trình của chính mình bằng Sắc Lệnh, hoàn lại 100% tài nguyên và nhận thêm 1 Kỹ Thuật.                               |
|                          | >                                                                                                                                               |
|                          | > **Cấp 3:** Công trình Cấp 3 trên lãnh thổ của bạn hoàn toàn miễn nhiễm với hiệu ứng Phiến Quân.                                               |
+--------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------+
| **T-ENG-04**             | **⬡** Khi nâng cấp một công trình, được giảm 1 Kỹ Thuật trong chi phí nâng cấp.                                                                 |
|                          |                                                                                                                                                 |
| **Quy Hoạch Đô Thị** ✦   | > **Cấp 1:** Có thể nâng cấp 2 công trình trong cùng 1 lượt (thay vì 1).                                                                        |
|                          | >                                                                                                                                               |
|                          | > **Cấp 2:** Chi phí nâng cấp lên Cấp 2 giảm thêm 1 Kỹ Thuật nữa.                                                                               |
|                          | >                                                                                                                                               |
|                          | > **Cấp 3:** Nâng cấp công trình lên Cấp tối đa miễn toàn bộ Vàng.                                                                              |
+--------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------+
| **T-ENG-05**             | **⬡** Đặt 1 Chốt Phòng Thủ lên bất kỳ tile Lãnh thổ thực hữu nào. Phiến Quân không thể dừng tại tile đó.                                        |
|                          |                                                                                                                                                 |
| **Pháo Đài Biên Giới** ✦ | > **Cấp 1:** Chốt Phòng Thủ cũng ngăn Đơn vị Viễn Chinh đối thủ đi qua tile đó trong 1 vòng.                                                    |
|                          | >                                                                                                                                               |
|                          | > **Cấp 2:** Chốt Phòng Thủ ảnh hưởng thêm 1 ô xung quanh (bán kính 1).                                                                         |
|                          | >                                                                                                                                               |
|                          | > **Cấp 3:** Khi Phiến Quân bị ngăn bởi Chốt, người chơi kích hoạt PQ mất 2 Vàng.                                                               |
+--------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------+
| **T-ENG-06**             | **⬡** Cho phép xây công trình đặc trưng trên tile Sông trong vùng ảnh hưởng của bạn. Nhận +1 Tín Ngưỡng mỗi khi xúc xắc khớp với công trình đó. |
|                          |                                                                                                                                                 |
| **Tuyến Vận Tải Nước** ✦ | > **Cấp 1:** Công trình đặc trưng trên Sông sản xuất gấp đôi Tín Ngưỡng khi cả 2 mặt xúc xắc khớp.                                              |
|                          | >                                                                                                                                               |
|                          | > **Cấp 2:** Tile Sông liền kề Lãnh thổ của bạn không thể bị Phiến Quân phong tỏa.                                                              |
|                          | >                                                                                                                                               |
|                          | > **Cấp 3:** Khi xúc xắc ra mặt Tín Ngưỡng, tất cả công trình trên Sông nhân đôi sản lượng lượt đó.                                             |
+--------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------+

## 🔬 Trường Phái Khoa Học --- Tối ưu Long Mạch

+------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------+
| **T-SCI-01**                 | **⬡** Khi xúc xắc đổ ra mặt tài nguyên khớp với công trình, nhận thêm 1 sản lượng tài nguyên đó.                                              |
|                              |                                                                                                                                               |
| **Khai Thác Chuyên Sâu**     | > **Cấp 1:** Khi đổ ra mặt Hex (⬡), ngoài 1 phiếu Chi Phối, nhận thêm 1 tài nguyên bất kỳ.                                                    |
|                              | >                                                                                                                                             |
|                              | > **Cấp 2:** Sản lượng thêm tăng từ +1 lên +2 khi cả 2 viên xúc xắc đều khớp.                                                                 |
|                              | >                                                                                                                                             |
|                              | > **Cấp 3:** Khi xúc xắc khớp với 2 công trình trở lên, nhận thêm 1 Khoa Học miễn phí.                                                        |
+==============================+===============================================================================================================================================+
| **T-SCI-02**                 | **⬡** Mỗi đầu vòng, nhận 1 Khoa Học miễn phí nếu bạn có ít nhất 3 loại công trình sản xuất khác nhau đang hoạt động.                          |
|                              |                                                                                                                                               |
| **Lý Thuyết Địa Mạch** ✦     | > **Cấp 1:** Điều kiện giảm còn 2 loại công trình khác nhau.                                                                                  |
|                              | >                                                                                                                                             |
|                              | > **Cấp 2:** Thưởng tăng từ 1 lên 2 Khoa Học.                                                                                                 |
|                              | >                                                                                                                                             |
|                              | > **Cấp 3:** Khi Long Mạch kích hoạt và bạn nhận tài nguyên từ người chơi khác đổ xúc xắc, nhận thêm 1 Khoa Học.                              |
+------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------+
| **T-SCI-03**                 | **⬡** Xem trước tất cả disc tài nguyên chưa lật trong bán kính 3 ô từ HQ của bạn.                                                             |
|                              |                                                                                                                                               |
| **Bản Đồ Địa Lý Học** ✦      | > **Cấp 1:** Có thể hoán đổi 2 disc tài nguyên chưa lật một lần mỗi ván.                                                                      |
|                              | >                                                                                                                                             |
|                              | > **Cấp 2:** Khi đặt HQ hoặc Subsidiary, nhận 2 Khoa Học.                                                                                     |
|                              | >                                                                                                                                             |
|                              | > **Cấp 3:** Khi tranh chấp tile có tài nguyên quý (Vàng), ngưỡng Chi Phối giảm 1.                                                            |
+------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------+
| **T-SCI-04**                 | **⬡** Một lần mỗi vòng, trước khi đổ xúc xắc, bạn có thể chọn giữ lại 1 viên và chỉ đổ lại viên còn lại.                                      |
|                              |                                                                                                                                               |
| **Phân Tích Xúc Xắc** ✦      | > **Cấp 1:** Có thể dùng khả năng này 2 lần mỗi vòng.                                                                                         |
|                              | >                                                                                                                                             |
|                              | > **Cấp 2:** Khi giữ viên xúc xắc, nhận thêm 1 tài nguyên tương ứng với mặt viên giữ.                                                         |
|                              | >                                                                                                                                             |
|                              | > **Cấp 3:** Một lần mỗi ván, sau khi đổ cả 2 viên, chọn lại 1 mặt bất kỳ cho 1 trong 2 viên.                                                 |
+------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------+
| **T-SCI-05**                 | **⬡** Khi đối thủ mua thẻ Công Nghệ, bạn được biết tên thẻ đó. Nhận 1 Khoa Học mỗi khi đối thủ mua thẻ Công Nghệ.                             |
|                              |                                                                                                                                               |
| **Mạng Lưới Quan Sát** ✦     | > **Cấp 1:** Nhận 1 Khoa Học mỗi khi BẤT KỲ đối thủ nào xây dựng hoặc nâng cấp công trình.                                                    |
|                              | >                                                                                                                                             |
|                              | > **Cấp 2:** Sau khi quan sát thẻ Công Nghệ của đối thủ, bạn có thể mua cùng thẻ đó với giá giảm 1 Khoa Học.                                  |
|                              | >                                                                                                                                             |
|                              | > **Cấp 3:** Nhận 2 Khoa Học mỗi khi Sự Kiện Tổng được lật. Bạn được xem trước thẻ Sự Kiện tiếp theo.                                         |
+------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------+
| **T-SCI-06**                 | **⬡** Một lần mỗi ván, khi Long Mạch kích hoạt, bạn có thể chuyển toàn bộ sản lượng Long Mạch của lượt đó sang 1 loại tài nguyên do bạn chọn. |
|                              |                                                                                                                                               |
| **Tái Cấu Trúc Long Mạch** ✦ | > **Cấp 1:** Dùng được 2 lần mỗi ván.                                                                                                         |
|                              | >                                                                                                                                             |
|                              | > **Cấp 2:** Khi chuyển đổi, sản lượng nhận được tăng thêm 1.                                                                                 |
|                              | >                                                                                                                                             |
|                              | > **Cấp 3:** Tất cả người chơi trong ván nhận cùng loại tài nguyên bạn chọn (thay vì nhận theo công trình của mình).                          |
+------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------+

## 💰 Trường Phái Kinh Tế --- Thao túng Vàng

+------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------+
| **T-ECO-01**                 | **⬡** Khi người chơi khác thực hiện Giao thương đi qua Lãnh thổ thực hữu của bạn, họ phải trả cho bạn 1 Vàng.                              |
|                              |                                                                                                                                            |
| **Hợp Đồng Độc Quyền**       | > **Cấp 1:** Giảm chi phí duy trì Đơn vị Giao thương. Tăng Hảo Cảm Khu Dân Cư để đổi tài nguyên có lợi hơn.                                |
|                              | >                                                                                                                                          |
|                              | > **Cấp 2:** Phí độc quyền tăng từ 1 lên 2 Vàng mỗi lượt giao thương qua lãnh thổ của bạn.                                                 |
|                              | >                                                                                                                                          |
|                              | > **Cấp 3:** Người chơi không thể đi Giao thương qua lãnh thổ của bạn mà không có sự đồng ý. Nếu bị từ chối, họ phải vòng sang đường khác. |
+==============================+============================================================================================================================================+
| **T-ECO-02**                 | **⬡** Mỗi đầu vòng, bạn có thể đặt cược tối đa 3 Vàng. Nếu xúc xắc ra mặt Vàng trong lượt của bạn, nhận lại số tiền đặt cược × 2.          |
|                              |                                                                                                                                            |
| **Quỹ Đầu Tư Chiến Lược** ✦  | > **Cấp 1:** Giới hạn đặt cược tăng từ 3 lên 5 Vàng.                                                                                       |
|                              | >                                                                                                                                          |
|                              | > **Cấp 2:** Nếu thua cược (không ra mặt Vàng), chỉ mất 50% số đặt cược.                                                                   |
|                              | >                                                                                                                                          |
|                              | > **Cấp 3:** Khi thắng cược, nhận thêm 1 tài nguyên bất kỳ.                                                                                |
+------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------+
| **T-ECO-03**                 | **⬡** Nhận 1 Vàng mỗi khi bất kỳ người chơi nào (kể cả bạn) hoàn thành 1 lượt Giao thương.                                                 |
|                              |                                                                                                                                            |
| **Thuế Đường Biên** ✦        | > **Cấp 1:** Thuế tăng lên 2 Vàng mỗi lượt Giao thương.                                                                                    |
|                              | >                                                                                                                                          |
|                              | > **Cấp 2:** Khi thu thuế từ đối thủ, họ không thể đề xuất Giao thương với bạn trong vòng tiếp theo trừ khi trả 3 Vàng phí phạt.           |
|                              | >                                                                                                                                          |
|                              | > **Cấp 3:** Nhận thêm 1 Văn Hóa mỗi khi thu thuế thành công.                                                                              |
+------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------+
| **T-ECO-04**                 | **⬡** Có thể trữ tối đa 10 Vàng vượt giới hạn thông thường. Nhận 1 Vàng lãi suất mỗi 5 vòng nếu đang giữ ít nhất 8 Vàng.                   |
|                              |                                                                                                                                            |
| **Kho Bạc Dự Phòng** ✦       | > **Cấp 1:** Giới hạn trữ tăng thêm 5 Vàng nữa.                                                                                            |
|                              | >                                                                                                                                          |
|                              | > **Cấp 2:** Lãi suất trả mỗi 3 vòng thay vì 5.                                                                                            |
|                              | >                                                                                                                                          |
|                              | > **Cấp 3:** Khi ván kết thúc, mỗi 5 Vàng dư được tính 2 điểm thay vì 1.                                                                   |
+------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------+
| **T-ECO-05**                 | **⬡** Một lần mỗi vòng, đổi 3 Vàng lấy 2 tài nguyên bất kỳ cùng loại hoặc khác loại tự chọn.                                               |
|                              |                                                                                                                                            |
| **Thị Trường Chợ Đen** ✦     | > **Cấp 1:** Tỷ lệ giảm còn 2 Vàng lấy 2 tài nguyên.                                                                                       |
|                              | >                                                                                                                                          |
|                              | > **Cấp 2:** Có thể dùng 2 lần mỗi vòng.                                                                                                   |
|                              | >                                                                                                                                          |
|                              | > **Cấp 3:** Khi giao dịch Chợ Đen, đối thủ bên trái mất 1 tài nguyên ngẫu nhiên (không áp dụng nếu họ cũng có thẻ này).                   |
+------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------+
| **T-ECO-06**                 | **⬡** Trả 5 Vàng để nhận ngay 3 tài nguyên bất kỳ + 1 phiếu Chi Phối. Hiệu ứng áp dụng trong Khâu Hành Động.                               |
|                              |                                                                                                                                            |
| **Trái Phiếu Chiến Tranh** ✦ | > **Cấp 1:** Chi phí giảm từ 5 xuống 4 Vàng.                                                                                               |
|                              | >                                                                                                                                          |
|                              | > **Cấp 2:** Nhận thêm 1 phiếu Chi Phối (tổng 2 phiếu khi kích hoạt).                                                                      |
|                              | >                                                                                                                                          |
|                              | > **Cấp 3:** Dùng được 2 lần mỗi lượt thay vì 1.                                                                                           |
+------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------+

## 🏛 Trường Phái Văn Hóa --- Ngoại giao & Chi phối

+-------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------+
| **T-CUL-01**            | **⬡** Giảm chi phí Vàng và Văn Hóa khi mua thẳng tile trong Vùng ảnh hưởng.                                                                          |
|                         |                                                                                                                                                      |
| **Bộ Máy Tuyên Truyền** | > **Cấp 1:** Khi tranh chấp Danh thắng hoặc Khu dân cư tự do, phiếu Chi Phối có giá trị ×1.5.                                                        |
|                         | >                                                                                                                                                    |
|                         | > **Cấp 2:** Phiếu Chi Phối tại Danh thắng/Khu dân cư tự do có giá trị ×2.                                                                           |
|                         | >                                                                                                                                                    |
|                         | > **Cấp 3:** Mỗi Danh thắng bạn đang Chi Phối hoàn toàn mang lại 1 Văn Hóa mỗi vòng.                                                                 |
+=========================+======================================================================================================================================================+
| **T-CUL-02**            | **⬡** Chọn 1 đối thủ. Trong 3 vòng tiếp theo, bạn không thể bị nhắm mục tiêu bởi Sắc Lệnh từ đối thủ đó.                                             |
|                         |                                                                                                                                                      |
| **Ngoại Giao Bí Mật** ✦ | > **Cấp 1:** Hiệu lực kéo dài 5 vòng thay vì 3.                                                                                                      |
|                         | >                                                                                                                                                    |
|                         | > **Cấp 2:** Áp dụng lên 2 đối thủ đồng thời.                                                                                                        |
|                         | >                                                                                                                                                    |
|                         | > **Cấp 3:** Khi hiệu ứng hết hạn, nhận 2 Văn Hóa từ mỗi đối thủ trong thỏa thuận.                                                                   |
+-------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------+
| **T-CUL-03**            | **⬡** Nếu lãnh thổ của bạn tiếp giáp với lãnh thổ đối thủ, nhận 1 Văn Hóa mỗi vòng cho mỗi cặp tile tiếp giáp (tối đa 3 Văn Hóa/vòng).               |
|                         |                                                                                                                                                      |
| **Đồng Hóa Văn Hóa** ✦  | > **Cấp 1:** Giới hạn tăng từ 3 lên 5 Văn Hóa/vòng.                                                                                                  |
|                         | >                                                                                                                                                    |
|                         | > **Cấp 2:** Nếu nhận được ít nhất 3 Văn Hóa từ hiệu ứng này trong 1 vòng, được đặt thêm 1 phiếu Chi Phối miễn phí.                                  |
|                         | >                                                                                                                                                    |
|                         | > **Cấp 3:** Mỗi lần nhận Văn Hóa từ hiệu ứng này, đối thủ mất 1 Văn Hóa tương ứng.                                                                  |
+-------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------+
| **T-CUL-04**            | **⬡** Tặng 2 tài nguyên bất kỳ cho 1 đối thủ. Đổi lại, trong 2 vòng tiếp theo, đối thủ đó không thể đặt phiếu Chi Phối lên tile bạn đang tranh chấp. |
|                         |                                                                                                                                                      |
| **Lễ Hội Liên Minh** ✦  | > **Cấp 1:** Thời hạn hiệu lực tăng từ 2 lên 3 vòng.                                                                                                 |
|                         | >                                                                                                                                                    |
|                         | > **Cấp 2:** Có thể dùng với 2 đối thủ cùng lúc (tặng 2 tài nguyên cho mỗi người).                                                                   |
|                         | >                                                                                                                                                    |
|                         | > **Cấp 3:** Khi hiệu lực kết thúc, đối thủ nhận quà phải trao 1 phiếu Chi Phối đang đặt (nếu có) cho bạn.                                           |
+-------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------+
| **T-CUL-05**            | **⬡** Khi Sự Kiện Tổng được lật, bạn có thể trả 3 Văn Hóa để chọn 1 trong 2 lá Sự Kiện (xem trước 2 lá từ đỉnh bộ bài rồi chọn 1).                   |
|                         |                                                                                                                                                      |
| **Kiểm Soát Dư Luận** ✦ | > **Cấp 1:** Xem trước 3 lá thay vì 2 lá.                                                                                                            |
|                         | >                                                                                                                                                    |
|                         | > **Cấp 2:** Chi phí giảm từ 3 xuống 2 Văn Hóa.                                                                                                      |
|                         | >                                                                                                                                                    |
|                         | > **Cấp 3:** Khi dùng khả năng này, nhận 1 Văn Hóa thưởng từ mỗi đối thủ không nhận được lợi từ Sự Kiện bạn chọn.                                    |
+-------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------+
| **T-CUL-06**            | **⬡** Mỗi khi bạn giành quyền Chi Phối hoàn toàn 1 tile (đạt đủ ngưỡng phiếu), nhận 1 Văn Hóa thưởng.                                                |
|                         |                                                                                                                                                      |
| **Sử Ký Chiến Thắng** ✦ | > **Cấp 1:** Thưởng tăng từ 1 lên 2 Văn Hóa khi chiếm Danh thắng hoặc Khu dân cư.                                                                    |
|                         | >                                                                                                                                                    |
|                         | > **Cấp 2:** Khi tổng lãnh thổ của bạn đạt mốc 10/15/20 tile, nhận 3 Văn Hóa thưởng mỗi mốc.                                                         |
|                         | >                                                                                                                                                    |
|                         | > **Cấp 3:** Cuối ván, mỗi Văn Hóa dư tính thêm 0.5 điểm (làm tròn xuống sau khi tổng kết).                                                          |
+-------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------+

## ☯ Trường Phái Tín Ngưỡng --- Quân sự & Bất thường

+--------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------+
| **T-FAI-01**                   | **⬡** Giảm chi phí Tín Ngưỡng khi mua Đơn vị Viễn Chinh.                                                                                            |
|                                |                                                                                                                                                     |
| **Cứu Chuộc**                  | > **Cấp 1:** Đơn vị Viễn Chinh được tăng thêm số bước di chuyển mỗi vòng.                                                                           |
|                                | >                                                                                                                                                   |
|                                | > **Cấp 2:** Khi Đơn vị Viễn Chinh tiêu diệt Phiến Quân, nhận phần thưởng tài nguyên.                                                               |
|                                | >                                                                                                                                                   |
|                                | > **Cấp 3:** Đơn vị Viễn Chinh miễn nhiễm với hiệu ứng \'Biên Giới Thép\' của Sắc Lệnh đối thủ.                                                     |
+================================+=====================================================================================================================================================+
| **T-FAI-02**                   | **⬡** Một lần mỗi ván, chọn 1 vị trí tile. Phiến Quân không thể đặt chân đến tile đó trong 5 vòng tiếp theo (rào cản phong thủy).                   |
|                                |                                                                                                                                                     |
| **Nghi Lễ Phong Thủy** ✦       | > **Cấp 1:** Hiệu lực kéo dài 8 vòng.                                                                                                               |
|                                | >                                                                                                                                                   |
|                                | > **Cấp 2:** Dùng được 2 lần mỗi ván.                                                                                                               |
|                                | >                                                                                                                                                   |
|                                | > **Cấp 3:** Phạm vi rào cản mở rộng ra 1 ô lân cận xung quanh tile đã chọn.                                                                        |
+--------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------+
| **T-FAI-03**                   | **⬡** Trước khi đổ xúc xắc, tuyên bố 1 mặt cụ thể (ví dụ: \'Vàng\'). Nếu đúng, nhận gấp đôi sản lượng từ mặt đó lượt này.                           |
|                                |                                                                                                                                                     |
| **Lời Tiên Tri** ✦             | > **Cấp 1:** Nếu tuyên bố đúng 3 lần liên tiếp, nhận thêm 3 Tín Ngưỡng.                                                                             |
|                                | >                                                                                                                                                   |
|                                | > **Cấp 2:** Tuyên bố được 2 mặt mỗi lượt thay vì 1.                                                                                                |
|                                | >                                                                                                                                                   |
|                                | > **Cấp 3:** Mỗi lần tuyên bố đúng, nhận 1 Tín Ngưỡng thưởng bổ sung.                                                                               |
+--------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------+
| **T-FAI-04**                   | **⬡** Trả 2 Tín Ngưỡng để triệu hồi Thần Binh: trong 3 vòng tiếp theo, lãnh thổ của bạn miễn nhiễm mọi hiệu ứng phong tỏa từ Phiến Quân.            |
|                                |                                                                                                                                                     |
| **Thần Binh Hộ Vệ** ✦          | > **Cấp 1:** Thời hạn bảo vệ tăng từ 3 lên 5 vòng.                                                                                                  |
|                                | >                                                                                                                                                   |
|                                | > **Cấp 2:** Chi phí giảm từ 2 xuống 1 Tín Ngưỡng.                                                                                                  |
|                                | >                                                                                                                                                   |
|                                | > **Cấp 3:** Khi Thần Binh đang hoạt động, mỗi lượt bạn nhận thêm 1 Tín Ngưỡng thụ động.                                                            |
+--------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------+
| **T-FAI-05**                   | **⬡** Trả 3 Tín Ngưỡng. Chọn 1 đối thủ: lượt tiếp theo của họ, kết quả xúc xắc bị đảo ngược (đổi ra mặt A → tính như mặt đối diện trên xúc xắc).    |
|                                |                                                                                                                                                     |
| **Bùa Chú Hỗn Loạn** ✦         | > **Cấp 1:** Áp dụng lên 2 đối thủ cùng lúc.                                                                                                        |
|                                | >                                                                                                                                                   |
|                                | > **Cấp 2:** Chi phí giảm từ 3 xuống 2 Tín Ngưỡng.                                                                                                  |
|                                | >                                                                                                                                                   |
|                                | > **Cấp 3:** Sau khi đối thủ chịu hiệu ứng, nếu họ đổ ra số 7, Phiến Quân bị di chuyển đến tile của họ thay vì tile ngẫu nhiên.                     |
+--------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------+
| **T-FAI-06**                   | **⬡** Chọn 1 tile Lãnh thổ thực hữu của bạn: tile đó trở thành Thánh Địa. Mỗi vòng, tất cả công trình trong bán kính 1 ô từ Thánh Địa +1 sản lượng. |
|                                |                                                                                                                                                     |
| **Thiêng Liêng Hóa Đất Đai** ✦ | > **Cấp 1:** Bán kính hiệu ứng Thánh Địa tăng từ 1 lên 2 ô.                                                                                         |
|                                | >                                                                                                                                                   |
|                                | > **Cấp 2:** Có thể có 2 Thánh Địa cùng lúc thay vì 1.                                                                                              |
|                                | >                                                                                                                                                   |
|                                | > **Cấp 3:** Khi Phiến Quân tiến vào bán kính 1 ô từ Thánh Địa, lập tức bị đẩy ra ngoài phạm vi đó.                                                 |
+--------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------+

# II. SẮC LỆNH (30 THẺ)

*Mua bằng 2 Văn Hóa + 2 Kỹ Thuật + 2 Vàng. Giữ bí mật cá nhân. Đối thủ biết số lượng, không biết nội dung.*

## Tức Thì --- Tác động ngay lập tức để giành lợi thế.

**Thời điểm: Khâu Hành Động**

+--------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **E-IMM-01**                   | **⬡** Ép một Phiến Quân di dời sang tile lân cận theo ý muốn.                                                                                                |
|                                |                                                                                                                                                              |
| **Lệnh Cưỡng Chế**             |                                                                                                                                                              |
+================================+==============================================================================================================================================================+
| **E-IMM-02**                   | **⬡** Buộc đối thủ đang kết nối đường giao thương giao nộp một nửa số Vàng hiện có.                                                                          |
|                                |                                                                                                                                                              |
| **Lệnh Tịch Thu**              |                                                                                                                                                              |
+--------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **E-IMM-03**                   | **⬡** Hủy ngay 1 công trình của chính mình, hoàn lại toàn bộ tài nguyên gốc.                                                                                 |
|                                |                                                                                                                                                              |
| **Lệnh Giải Tỏa**              |                                                                                                                                                              |
+--------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **E-IMM-04**                   | **⬡** Chọn 1 tile đang ở trạng thái Tranh Chấp. Xóa toàn bộ phiếu Chi Phối của đối thủ trên tile đó. Phiếu của bạn giữ nguyên.                               |
|                                |                                                                                                                                                              |
| **Cướp Đất** ✦                 |                                                                                                                                                              |
+--------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **E-IMM-05**                   | **⬡** Đặt ngay 3 phiếu Chi Phối lên bất kỳ tile nào trong phạm vi ảnh hưởng của bạn, bất kể số phiếu hiện tại.                                               |
|                                |                                                                                                                                                              |
| **Triệu Hồi Lính Đánh Thuê** ✦ |                                                                                                                                                              |
+--------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **E-IMM-06**                   | **⬡** Hủy 1 đoạn Đường Đất của đối thủ (tối đa 3 tile liên tiếp). Đơn vị Giao thương của họ dừng lại 1 vòng.                                                 |
|                                |                                                                                                                                                              |
| **Tấn Công Cơ Sở Hạ Tầng** ✦   |                                                                                                                                                              |
+--------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **E-IMM-07**                   | **⬡** Chọn 1 công trình của mình: sản lượng của công trình đó nhân đôi trong lượt hiện tại.                                                                  |
|                                |                                                                                                                                                              |
| **Nhân Bản Sản Lượng** ✦       |                                                                                                                                                              |
+--------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **E-IMM-08**                   | **⬡** Chọn 1 đối thủ: họ không thể chi Vàng trong lượt tiếp theo của họ.                                                                                     |
|                                |                                                                                                                                                              |
| **Lệnh Phong Tỏa Tài Chính** ✦ |                                                                                                                                                              |
+--------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **E-IMM-09**                   | **⬡** Trong lượt này, tất cả hành động của bạn không tốn thêm Vàng (áp dụng cho phí đường, phí trao đổi).                                                    |
|                                |                                                                                                                                                              |
| **Quyền Lực Tối Cao** ✦        |                                                                                                                                                              |
+--------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **E-IMM-10**                   | **⬡** Lấy 1 công trình Cấp 1 của đối thủ trên tile tiếp giáp lãnh thổ bạn. Công trình đó trở thành của bạn nếu bạn sở hữu tile đó; nếu không, nó bị phá hủy. |
|                                |                                                                                                                                                              |
| **Lệnh Trưng Thu** ✦           |                                                                                                                                                              |
+--------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------+

## Phản Ứng --- Phá vỡ kế hoạch của đối thủ.

**Thời điểm: Khâu Giải Quyết hoặc khi bị nhắm mục tiêu**

+-------------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **E-REA-01**                  | **⬡** Hủy bỏ tác dụng của 1 lá Sắc Lệnh vừa được người chơi khác đánh ra.                                                                                               |
|                               |                                                                                                                                                                         |
| **Phủ Quyết**                 |                                                                                                                                                                         |
+===============================+=========================================================================================================================================================================+
| **E-REA-02**                  | **⬡** Khi Đơn vị Viễn Chinh đối phương bước vào Vùng ảnh hưởng, vô hiệu hóa đơn vị đó 1 vòng, buộc đưa về tile gần nhất ngoài vùng ảnh hưởng.                           |
|                               |                                                                                                                                                                         |
| **Biên Giới Thép**            |                                                                                                                                                                         |
+-------------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **E-REA-03**                  | **⬡** Khi Phiến Quân phong tỏa vùng có công trình của bạn, ngăn chặn việc mất tài nguyên lượt này.                                                                      |
|                               |                                                                                                                                                                         |
| **Bảo Vệ Tài Sản**            |                                                                                                                                                                         |
+-------------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **E-REA-04**                  | **⬡** Khi bị nhắm bởi Sắc Lệnh Tức Thì, sau khi hiệu ứng được thực thi, bạn được rút 1 Sắc Lệnh miễn phí từ bộ bài.                                                     |
|                               |                                                                                                                                                                         |
| **Phản Đòn Ngoại Giao** ✦     |                                                                                                                                                                         |
+-------------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **E-REA-05**                  | **⬡** Khi bị nhắm bởi bất kỳ Sắc Lệnh Tức Thì nào, đối chiếu hiệu ứng đó về phía người dùng thẻ (họ chịu hiệu ứng thay bạn). Chỉ dùng được 1 lần mỗi ván.               |
|                               |                                                                                                                                                                         |
| **Gương Phản Chiếu** ✦        |                                                                                                                                                                         |
+-------------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **E-REA-06**                  | **⬡** Khi bất kỳ đối thủ nào bị nhắm bởi Phiến Quân hoặc Sắc Lệnh gây thiệt hại, bạn có thể kích hoạt thẻ này để chia đôi thiệt hại với họ. Đổi lại, nhận 2 Tín Ngưỡng. |
|                               |                                                                                                                                                                         |
| **Liên Minh Khẩn Cấp** ✦      |                                                                                                                                                                         |
+-------------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **E-REA-07**                  | **⬡** Khi Đơn vị Giao thương của đối thủ đi qua lãnh thổ của bạn, bạn có thể kích hoạt để chặn đứng đơn vị đó và thu 2 Vàng phí thông quan.                             |
|                               |                                                                                                                                                                         |
| **Pháo Đài Phản Công** ✦      |                                                                                                                                                                         |
+-------------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **E-REA-08**                  | **⬡** Khi đối thủ tuyên bố Chi Phối tile kề lãnh thổ bạn, đặt ngay 2 phiếu Chi Phối phản tranh chấp lên tile đó mà không cần phiếu ⬡.                                   |
|                               |                                                                                                                                                                         |
| **Thiên La Địa Võng** ✦       |                                                                                                                                                                         |
+-------------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **E-REA-09**                  | **⬡** Khi Phiến Quân sắp dừng trên tile có công trình Cấp 2+ của bạn, đẩy PQ sang tile trống lân cận. Nếu không có tile trống, PQ dừng lại nhưng không gây hiệu ứng.    |
|                               |                                                                                                                                                                         |
| **Trường Thành Phong Thủy** ✦ |                                                                                                                                                                         |
+-------------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **E-REA-10**                  | **⬡** Khi một Sự Kiện Tổng vừa lật và gây bất lợi cho bạn, trả 3 Văn Hóa để miễn nhiễm hoàn toàn khỏi Sự Kiện đó trong 5 vòng hiệu lực.                                 |
|                               |                                                                                                                                                                         |
| **Mật Lệnh Đảo Ngược** ✦      |                                                                                                                                                                         |
+-------------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------+

## Nội Tại --- Tạo ra các lợi thế ngầm.

**Thời điểm: Điều kiện ẩn --- hiệu lực kéo dài**

+---------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **E-INT-01**              | **⬡** Khi xúc xắc đổ ra mặt Hex (⬡), rút thêm 1 Sắc Lệnh miễn phí.                                                                                                                   |
|                           |                                                                                                                                                                                      |
| **Kế Hoạch B**            |                                                                                                                                                                                      |
+===========================+======================================================================================================================================================================================+
| **E-INT-02**              | **⬡** Mỗi khi đổ tổng 7, thay vì không nhận gì, nhận 3 Vàng.                                                                                                                         |
|                           |                                                                                                                                                                                      |
| **Quỹ Tín Thác**          |                                                                                                                                                                                      |
+---------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **E-INT-03**              | **⬡** Khi một đối thủ mất tài nguyên vì Phiến Quân (bất kể do ai kích hoạt), bạn nhận 1 Vàng.                                                                                        |
|                           |                                                                                                                                                                                      |
| **Hợp Đồng Bóng Tối** ✦   |                                                                                                                                                                                      |
+---------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **E-INT-04**              | **⬡** Mỗi khi bất kỳ người chơi nào (kể cả bạn) chi tài nguyên để nâng cấp công trình, bạn nhận 1 Khoa Học.                                                                          |
|                           |                                                                                                                                                                                      |
| **Kẻ Cơ Hội** ✦           |                                                                                                                                                                                      |
+---------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **E-INT-05**              | **⬡** Mỗi khi Sự Kiện Tổng lật ra thẻ có lợi cho bạn, nhận thêm 2 Văn Hóa ngoài hiệu ứng thẻ đó.                                                                                     |
|                           |                                                                                                                                                                                      |
| **Thiên Thời** ✦          |                                                                                                                                                                                      |
+---------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **E-INT-06**              | **⬡** Khi bạn có từ 5 Sắc Lệnh trong tay trở lên, nhận 1 Vàng mỗi vòng (thu nhập thụ động từ uy lực bí mật).                                                                         |
|                           |                                                                                                                                                                                      |
| **Lưới Nhện** ✦           |                                                                                                                                                                                      |
+---------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **E-INT-07**              | **⬡** Khi đối thủ xem số Sắc Lệnh bạn đang giữ (do Sự Kiện hoặc kỹ năng), nhận 1 Tín Ngưỡng.                                                                                         |
|                           |                                                                                                                                                                                      |
| **Đòn Tâm Lý** ✦          |                                                                                                                                                                                      |
+---------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **E-INT-08**              | **⬡** Bỏ qua hoàn toàn Khâu Hành Động trong 1 vòng. Đổi lại, nhận 5 tài nguyên bất kỳ và 1 Sắc Lệnh miễn phí vào đầu vòng tiếp theo.                                                 |
|                           |                                                                                                                                                                                      |
| **Ngủ Đông Chiến Lược** ✦ |                                                                                                                                                                                      |
+---------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **E-INT-09**              | **⬡** Chọn 1 đối thủ. Mỗi khi họ đổ xúc xắc và nhận tài nguyên, bạn nhận 1 tài nguyên cùng loại. Hiệu lực 5 vòng. Đổi lại, họ miễn nhiễm Sắc Lệnh Tức Thì từ bạn trong thời gian đó. |
|                           |                                                                                                                                                                                      |
| **Giao Ước Huyết Thệ** ✦  |                                                                                                                                                                                      |
+---------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **E-INT-10**              | **⬡** Kích hoạt bí mật ngay khi mua thẻ. Nếu bạn là người cuối cùng bị loại ra khỏi cuộc tranh chấp cuối ván (điểm thấp nhất), nhận 5 Vàng và 3 Tín Ngưỡng làm \'di sản\'.           |
|                           |                                                                                                                                                                                      |
| **Di Chúc Cuối Cùng** ✦   |                                                                                                                                                                                      |
+---------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+

# III. SỰ KIỆN TỔNG (20 THẺ)

*Tự động lật mỗi 5 vòng. Lá mới thay thế và hủy hiệu lực lá cũ. Tác động toàn bộ người chơi.*

## Vòng 5 --- Định Hình Thế Trận

+---------------------------+--------------------------------------------------------------------------------------------------------+
| **EV-05-01**              | **⬡** Mọi kết quả xúc xắc ra mặt tài nguyên (trừ Hex) đều +1 sản lượng cơ bản cho toàn bộ người chơi.  |
|                           |                                                                                                        |
| **Mùa Màng Bội Thu**      |                                                                                                        |
+===========================+========================================================================================================+
| **EV-05-02**              | **⬡** Miễn phí 1 phiếu Chi Phối đầu tiên trong Khâu Hành Động cho mọi người chơi trong vòng này.       |
|                           |                                                                                                        |
| **Bùng Nổ Dân Số**        |                                                                                                        |
+---------------------------+--------------------------------------------------------------------------------------------------------+
| **EV-05-03**              | **⬡** Tất cả tile Đồng Bằng chưa có công trình trong 5 vòng tới mang lại +1 Kỹ Thuật nếu xúc xắc khớp. |
|                           |                                                                                                        |
| **Đất Đai Màu Mỡ** ✦      |                                                                                                        |
+---------------------------+--------------------------------------------------------------------------------------------------------+
| **EV-05-04**              | **⬡** Phí giao thương (chi phí Vàng/tile) giảm 50% trong 5 vòng tiếp theo.                             |
|                           |                                                                                                        |
| **Hội Chợ Thương Mại** ✦  |                                                                                                        |
+---------------------------+--------------------------------------------------------------------------------------------------------+
| **EV-05-05**              | **⬡** Trong 5 vòng tiếp theo, Phiến Quân không thể di chuyển tới tile có HQ hoặc Subsidiary.           |
|                           |                                                                                                        |
| **Thời Bình Tương Đối** ✦ |                                                                                                        |
+---------------------------+--------------------------------------------------------------------------------------------------------+

## Vòng 10 --- Giao Tranh Tài Nguyên

+--------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **EV-10-01**             | **⬡** Không thể trao đổi tài nguyên qua tuyến đường bị Núi chắn hoặc với Khu Dân Cư trong 5 vòng tới.                                                                   |
|                          |                                                                                                                                                                         |
| **Bão Tuyết Qua Núi**    |                                                                                                                                                                         |
+==========================+=========================================================================================================================================================================+
| **EV-10-02**             | **⬡** Phiến Quân xuất hiện tại tất cả ô Danh thắng và phong tỏa 6 ô xung quanh.                                                                                         |
|                          |                                                                                                                                                                         |
| **Hỗn Loạn Biên Giới**   |                                                                                                                                                                         |
+--------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **EV-10-03**             | **⬡** Tất cả thu hoạch Vàng giảm 50% trong 5 vòng tiếp theo.                                                                                                            |
|                          |                                                                                                                                                                         |
| **Mùa Hạn** ✦            |                                                                                                                                                                         |
+--------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **EV-10-04**             | **⬡** Tile Sông mở rộng ảnh hưởng: tất cả tile liền kề Sông nhận +1 Tín Ngưỡng khi xúc xắc ra Tín Ngưỡng trong 5 vòng tới.                                              |
|                          |                                                                                                                                                                         |
| **Lũ Lớn** ✦             |                                                                                                                                                                         |
+--------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **EV-10-05**             | **⬡** Mỗi Khu Dân Cư đang bị Chi Phối hoàn toàn có 30% cơ hội \'nổi dậy\': xóa toàn bộ phiếu của người sở hữu trong vòng này (quyết định bằng xúc xắc, 1--2 = nổi dậy). |
|                          |                                                                                                                                                                         |
| **Phong Trào Ly Khai** ✦ |                                                                                                                                                                         |
+--------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------+

## Vòng 15 --- Cạnh Tranh Khốc Liệt

+------------------------------+-------------------------------------------------------------------------------------------------------+
| **EV-15-01**                 | **⬡** Không thể dùng Tín Ngưỡng để hóa giải hay điều khiển Phiến Quân trong 5 vòng tới.               |
|                              |                                                                                                       |
| **Khủng Hoảng Niềm Tin**     |                                                                                                       |
+==============================+=======================================================================================================+
| **EV-15-02**                 | **⬡** Chi phí nâng cấp công trình lên Cấp 2 giảm một nửa lượng Kỹ Thuật yêu cầu trong 5 vòng tới.     |
|                              |                                                                                                       |
| **Cách Mạng Công Nghiệp**    |                                                                                                       |
+------------------------------+-------------------------------------------------------------------------------------------------------+
| **EV-15-03**                 | **⬡** Tất cả thẻ Sắc Lệnh Phản Ứng bị vô hiệu hóa trong 5 vòng tới. Không thể phản đòn hay phủ quyết. |
|                              |                                                                                                       |
| **Bóng Tối Địa Chính Trị** ✦ |                                                                                                       |
+------------------------------+-------------------------------------------------------------------------------------------------------+
| **EV-15-04**                 | **⬡** Lần đầu tiên mỗi người chơi tuyên bố tile mới trong vòng này không cần phiếu Chi Phối.          |
|                              |                                                                                                       |
| **Xuân Phân** ✦              |                                                                                                       |
+------------------------------+-------------------------------------------------------------------------------------------------------+
| **EV-15-05**                 | **⬡** Ngẫu nhiên lật lại 3 disc tài nguyên trên 3 tile chưa có công trình. Loại tài nguyên thay đổi.  |
|                              |                                                                                                       |
| **Thiên Địa Biến Đổi** ✦     |                                                                                                       |
+------------------------------+-------------------------------------------------------------------------------------------------------+

## Vòng 20 --- Chốt Hạ Ván Cờ

+-----------------------------+-----------------------------------------------------------------------------------------------------------------------------------------+
| **EV-20-01**                | **⬡** Công trình trên Vùng Tranh Chấp không được tính điểm khi kết thúc ván.                                                            |
|                             |                                                                                                                                         |
| **Ngày Tàn Của Đế Chế**     |                                                                                                                                         |
+=============================+=========================================================================================================================================+
| **EV-20-02**                | **⬡** Các ô Danh thắng đang được Chi Phối hoàn toàn mang lại điểm số gấp đôi khi tính điểm cuối ván.                                    |
|                             |                                                                                                                                         |
| **Di Sản Lịch Sử**          |                                                                                                                                         |
+-----------------------------+-----------------------------------------------------------------------------------------------------------------------------------------+
| **EV-20-03**                | **⬡** Tất cả người chơi đồng thời bí mật cam kết 1 hành động duy nhất cho lượt cuối cùng. Hành động được tiết lộ và thực hiện cùng lúc. |
|                             |                                                                                                                                         |
| **Đêm Trước Quyết Chiến** ✦ |                                                                                                                                         |
+-----------------------------+-----------------------------------------------------------------------------------------------------------------------------------------+
| **EV-20-04**                | **⬡** Người chơi nào kiểm soát tile chứa Long Mạch mạnh nhất (nhiều công trình trong bán kính 2 ô nhất) nhận thêm 5 điểm.               |
|                             |                                                                                                                                         |
| **Huyết Thống Long Mạch** ✦ |                                                                                                                                         |
+-----------------------------+-----------------------------------------------------------------------------------------------------------------------------------------+
| **EV-20-05**                | **⬡** Tất cả điểm Danh thắng được nhân 1.5× (làm tròn lên). Phiến Quân đang phong tỏa Danh thắng bị loại bỏ trước khi tính điểm.        |
|                             |                                                                                                                                         |
| **Màn Sương Chiến Trận** ✦  |                                                                                                                                         |
+-----------------------------+-----------------------------------------------------------------------------------------------------------------------------------------+
