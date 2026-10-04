-- Tài nguyên. Nguồn: GDD §3.3–3.4, Data §Công trình/Hạ tầng.
-- face = mặt xúc xắc (Khoa Học 1, Văn Hóa 2, Kỹ Thuật 3, Tín Ngưỡng 4, Vàng 5, Hex 6).

local R = {}

R.core = {
    { key = "science",     abbr = "KH", name = "Khoa Học",  face = 1 },
    { key = "culture",     abbr = "VH", name = "Văn Hóa",   face = 2 },
    { key = "engineering", abbr = "KT", name = "Kỹ Thuật",  face = 3 },
    { key = "faith",       abbr = "TN", name = "Tín Ngưỡng", face = 4 },
    { key = "gold",        abbr = "V",  name = "Vàng",      face = 5 },
}

R.materials = {   -- vật liệu phái sinh (D-01..D-05)
    { key = "alloy", abbr = "HK", name = "Hợp Kim" },
    { key = "paper", abbr = "GI", name = "Giấy" },
    { key = "steel", abbr = "TH", name = "Thép" },
    { key = "silk",  abbr = "LU", name = "Lụa" },
    { key = "bond",  abbr = "TP", name = "Tín Phiếu" },
}

R.industrial = {  -- tài nguyên công nghiệp phụ trợ
    { key = "coal", abbr = "Than", name = "Than" },
    { key = "oil",  abbr = "Dầu",  name = "Dầu Mỏ" },
}

R.HEX_FACE = 6    -- mặt Hex: không sản xuất, chỉ có lợi cho người đang trong lượt

R.byKey = {}
for _, group in ipairs({ R.core, R.materials, R.industrial }) do
    for _, r in ipairs(group) do R.byKey[r.key] = r end
end

R.byFace = {}
for _, r in ipairs(R.core) do R.byFace[r.face] = r end

return R
