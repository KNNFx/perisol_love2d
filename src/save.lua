-- Ghi / đọc file save bằng love.filesystem (D-011, skill save-systems).
-- Quy trình ghi: ghi file tạm -> đọc lại và kiểm tra hợp lệ -> chép bản cũ sang .bak -> ghi bản chính.
-- love.filesystem không có rename nên không "atomic" tuyệt đối; .bak là thứ đảm bảo phục hồi được
-- khi lần ghi bản chính bị gián đoạn. Khi đọc: thử bản chính, hỏng thì quay về .bak.
-- Thư mục: %APPDATA%/LOVE/perisol/

local Game = require("src.core.game")

local Save = {}

local function path(name) return name .. ".sav" end

function Save.exists(name)
    return love.filesystem.getInfo(path(name)) ~= nil or love.filesystem.getInfo(path(name) .. ".bak") ~= nil
end

function Save.remove(name)
    for _, p in ipairs({ path(name), path(name) .. ".bak", path(name) .. ".tmp" }) do
        if love.filesystem.getInfo(p) then love.filesystem.remove(p) end
    end
end

-- Trả true hoặc false, lỗi.
function Save.write(name, state)
    local main, bak, tmp = path(name), path(name) .. ".bak", path(name) .. ".tmp"
    local str = Game.save(state)

    local ok, err = love.filesystem.write(tmp, str)
    if not ok then return false, "không ghi được file tạm: " .. tostring(err) end

    local check = Game.load(love.filesystem.read(tmp))
    if not check then
        love.filesystem.remove(tmp)
        return false, "file tạm không đọc lại được"
    end

    local old = love.filesystem.getInfo(main) and love.filesystem.read(main)
    if old then love.filesystem.write(bak, old) end

    ok, err = love.filesystem.write(main, str)
    if not ok then return false, "không ghi được file save: " .. tostring(err) end
    love.filesystem.remove(tmp)
    return true
end

-- Trả state hoặc nil, lỗi. `usedBackup` (giá trị thứ ba) là true nếu phải dùng bản .bak.
function Save.read(name)
    local main = path(name)
    local firstErr
    for i, p in ipairs({ main, main .. ".bak" }) do
        if love.filesystem.getInfo(p) then
            local str = love.filesystem.read(p)
            local state, err = Game.load(str)
            if state then return state, nil, i == 2 end
            firstErr = firstErr or err
        end
    end
    return nil, firstErr or "không có file save"
end

return Save
