-- Đọc tham số dòng lệnh của LÖVE (`love . --seed 5 --players 3`).

local Cli = {}

-- Giá trị đi sau cờ `name`, hoặc nil nếu không có. (Phải trả nil tường minh: tonumber() không đối số báo lỗi.)
function Cli.option(name)
    local args = arg or {}
    for i, a in pairs(args) do
        if a == name then return args[i + 1] end
    end
    return nil
end

-- true nếu có cờ `name`.
function Cli.flag(name)
    for _, a in pairs(arg or {}) do
        if a == name then return true end
    end
    return false
end

return Cli
