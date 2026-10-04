# Art direction brief — Perisol

Theo mẫu của skill `create-game-assets`. Phần bỏ trống = chưa quyết định, cần chủ dự án xác nhận.

## Game frame

- Player fantasy: người cầm quyền một thế lực mở rộng lãnh thổ trên bản đồ lục giác, đọc địa thế và Long Mạch (GDD §1, §2.1).
- Core verbs: đổ xúc xắc, mở rộng lãnh thổ (Chi Phối), xây công trình, di chuyển đơn vị, dùng Sắc Lệnh.
- Engine and renderer: LÖVE 11.5 (LuaJIT), `love.graphics`, filter `nearest`.
- Target platforms: PC (Windows).
- Camera/view/facing: top-down 2D, hex **pointy-top**, nhìn hơi nghiêng (sprite có độ dày ở đáy ô).
- Native viewport and common display scale: cửa sổ 1280×720 (tối thiểu 1024×576); zoom nguyên 1×–4×.
- Typical asset size on screen: ô hex 32×32 px ở zoom 1× (64–128 px ở zoom 2×–4×).
- Tone (GDD §2.2): hoạt hình 2D, màu tươi; tránh tả thực và màu quá u tối.

## Visual system

- Shape language: hex đều, cạnh dày ~4 px ở đáy; công trình/cây nhô lên trên đỉnh ô tối đa 4 px.
- Silhouette priorities: loại địa hình phải đọc được ngay ở zoom 1× (rừng, núi tuyết, nước, sa mạc, khu dân cư).
- Value structure: nền tối `#1a1f26`; ô sáng/bão hòa vừa phải; overlay vùng người chơi alpha 0.28.
- Palette roles: tham khảo sheet hiện tại (xanh lá = đồng bằng/rừng, vàng cát = bờ biển/sa mạc, xanh lam = nước, xám/trắng = núi/tuyết). Màu người chơi: vàng, xanh dương, xanh lá, đỏ (GDD §4.2).
- Materials and surface cues: pixel art phẳng, đổ bóng nhẹ.
- Edge/line treatment: viền sáng 1 px quanh mặt ô, mặt bên tối hơn.
- Lighting direction and contrast: sáng từ trên, đồng nhất giữa mọi ô.
- Detail density and focal hierarchy: ô nền ít chi tiết; công trình/tài nguyên là điểm nhấn.
- Explicit exclusions: chữ trong sprite, sprite tả thực.

## Technical contract

- Asset dimensions/aspect: ô 32×32 px; bước lát gạch 32 (ngang) × 24 (dọc); hàng lẻ lệch 16 px.
- Alpha/background: PNG RGBA, nền trong suốt.
- Grid/tile/frame size: lưới 32 px trong sheet; tâm ô tại (16,16).
- Anchor/pivot/baseline: tâm ô; phần nhô lên trên khai báo bằng `overhang` trong `src/render/tileset.lua`.
- Filtering/mipmaps/compression: `nearest`, không mipmap, PNG không nén mất dữ liệu.
- Color space: sRGB.
- Naming and folders: sheet hiện ở `Image/`; sprite tách riêng (khi có) vào `assets/tiles/<terrain>_<n>.png`.

## Visual target

- Approved seed/reference paths: `Image/HexaTiles_Test_V001.png` (sheet thử nghiệm, chưa duyệt chính thức).
- Cần vẽ thêm: Sông riêng, Đầm Lầy, Danh Thắng (hiện là đa giác màu), Núi/Núi Tuyết thật sự phân biệt, HQ/Sub theo giai đoạn (Data, sheet "Hình ảnh các đơn vị").
- Native-scale gameplay capture: chạy `lovec . --seed 42 --players 4 --shot x.png`.
- Approval owner/date:
