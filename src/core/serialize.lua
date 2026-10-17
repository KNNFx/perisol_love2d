-- Serialize bảng Lua thuần dữ liệu <-> chuỗi (dùng cho save/load, replay). Không gọi love.*.
-- Kết quả ổn định: khóa được sắp xếp, nên cùng dữ liệu luôn ra cùng chuỗi (so sánh/diff được).
-- Chỉ hỗ trợ: nil, boolean, number hữu hạn, string, bảng không vòng. Từ chối hàm/userdata/metatable lạ.

local Serialize = {}

-- Sao chép payload ở ranh giới command/prompt/load. Chỉ nhận dữ liệu thuần, không metatable,
-- khóa chuỗi/số nguyên hữu hạn, không vòng. Lỗi lập trình ném lỗi; caller bên ngoài bọc pcall.
-- Tách quyền sở hữu bảng để người gửi không thể sửa history/prompt sau khi lệnh đã được nhận.
function Serialize.copy(value)
    local visiting = {}
    local function copy(v)
        local t = type(v)
        if t == "nil" or t == "boolean" or t == "string" then return v end
        if t == "number" then
            assert(v == v and v > -math.huge and v < math.huge, "dữ liệu có số không hữu hạn")
            return v
        end
        assert(t == "table" and getmetatable(v) == nil, "cần dữ liệu thuần, không hàm/metatable")
        assert(not visiting[v], "dữ liệu có vòng tham chiếu")
        visiting[v] = true
        local out = {}
        for k, item in pairs(v) do
            assert(type(k) == "string" or (type(k) == "number" and k > -math.huge and k < math.huge
                and k == math.floor(k)), "khóa phải là chuỗi hoặc số nguyên hữu hạn")
            out[k] = copy(item)
        end
        visiting[v] = nil
        return out
    end
    return copy(value)
end

local function keyOrder(a, b)
    local ta, tb = type(a), type(b)
    if ta ~= tb then return ta == "number" end   -- số trước chuỗi
    return a < b
end

local function encode(v, out, seen, path)
    local t = type(v)
    if t == "nil" then
        out[#out + 1] = "nil"
    elseif t == "boolean" then
        out[#out + 1] = tostring(v)
    elseif t == "number" then
        if v ~= v or v == math.huge or v == -math.huge then
            error("serialize: số không hữu hạn tại " .. path, 0)
        end
        if v == math.floor(v) and math.abs(v) < 1e15 then
            out[#out + 1] = string.format("%d", v)
        else
            out[#out + 1] = string.format("%.17g", v)
        end
    elseif t == "string" then
        out[#out + 1] = string.format("%q", v)
    elseif t == "table" then
        if seen[v] then error("serialize: bảng vòng tại " .. path, 0) end
        seen[v] = true
        local keys = {}
        for k in pairs(v) do
            local kt = type(k)
            if kt ~= "string" and kt ~= "number" then
                error("serialize: khóa kiểu " .. kt .. " tại " .. path, 0)
            end
            keys[#keys + 1] = k
        end
        table.sort(keys, keyOrder)
        out[#out + 1] = "{"
        for _, k in ipairs(keys) do
            out[#out + 1] = "[" .. (type(k) == "number" and string.format("%d", k) or string.format("%q", k)) .. "]="
            encode(v[k], out, seen, path .. "." .. tostring(k))
            out[#out + 1] = ","
        end
        out[#out + 1] = "}"
        seen[v] = nil
    else
        error("serialize: không hỗ trợ kiểu " .. t .. " tại " .. path, 0)
    end
end

-- Bảng -> chuỗi Lua ("return {...}").
function Serialize.dump(tbl)
    local out = { "return " }
    encode(tbl, out, {}, "root")
    return table.concat(out)
end

-- Chuỗi -> bảng. Chạy trong môi trường rỗng (không truy cập hàm toàn cục). Trả data hoặc nil, lỗi.
function Serialize.load(str)
    if type(str) ~= "string" then return nil, "không phải chuỗi" end
    local chunk, err
    if loadstring then
        chunk, err = loadstring(str, "=save")
        if chunk and setfenv then setfenv(chunk, {}) end
    else
        chunk, err = load(str, "=save", "t", {})
    end
    if not chunk then return nil, err end
    local ok, result = pcall(chunk)
    if not ok then return nil, result end
    return result
end

return Serialize
