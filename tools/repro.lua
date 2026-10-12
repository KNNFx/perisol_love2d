-- Phát lại một ca hỏng do tools/sweep.lua ghi: `luajit tools/repro.lua build/repro/5006.lua`.
-- Thoát 1 và in thông điệp lỗi nếu tái hiện được; thoát 0 nếu ván chạy sạch (không tái hiện).
local Sim       = require("src.core.sim")
local Serialize = require("src.core.serialize")

local path = arg[1]
if not path then io.stderr:write("dùng: luajit tools/repro.lua FILE\n") os.exit(2) end
local f, ferr = io.open(path, "r")
if not f then io.stderr:write("không mở được " .. path .. ": " .. tostring(ferr) .. "\n") os.exit(2) end
local repro, err = Serialize.load(f:read("*a"))
f:close()
if not repro then io.stderr:write("repro hỏng: " .. tostring(err) .. "\n") os.exit(2) end

print(string.format("phát lại seed %d, %d người%s, %d lệnh", repro.seed, repro.players, repro.rich and ", rich" or "", #repro.history))
local ok, msg = Sim.replay(repro)
if ok then
    print("không tái hiện được lỗi (ván chạy sạch). Thông điệp gốc: " .. tostring(repro.message))
    os.exit(0)
end
print("LỖI " .. tostring(msg))
os.exit(1)
