-- Quét dải seed: `luajit tools/sweep.lua N BASE [--rich]`. Chơi N ván seed BASE..BASE+N-1 (số người xoay vòng 2,3,4).
-- Ván lỗi: in thông điệp, ghi build/repro/<seed>.lua (phát lại bằng tools/repro.lua). Thoát 1 nếu có ván lỗi.
local Sim       = require("src.core.sim")
local Serialize = require("src.core.serialize")

local count, base, rich = 30, 1, false
do
    local pos = 0
    for _, a in ipairs(arg) do
        if a == "--rich" then rich = true
        elseif tonumber(a) then
            pos = pos + 1
            if pos == 1 then count = tonumber(a) else base = tonumber(a) end
        end
    end
end

local failures = 0
for i = 0, count - 1 do
    local seed, players = base + i, 2 + (i % 3)
    local trace = {}
    local ok, err = pcall(Sim.play, seed, players, { rich = rich, trace = trace })
    if not ok then
        failures = failures + 1
        local msg = tostring(err):gsub("^[^:]*%.lua:%d+: ", "")   -- bỏ tiền tố vị trí để thông điệp giống repro
        print(string.format("LỖI seed %d (%d người%s): %s", seed, players, rich and ", rich" or "", msg))
        os.execute("mkdir -p build/repro")
        local path = string.format("build/repro/%d.lua", seed)
        local f = assert(io.open(path, "w"))
        f:write(Serialize.dump({ seed = seed, players = players, rich = rich, message = msg,
            history = trace.state and trace.state.history or {}, topups = trace.topups or {} }))
        f:close()
        print("  repro: " .. path)
    end
end
print(string.format("%d/%d ván lỗi (seed %d..%d%s)", failures, count, base, base + count - 1, rich and ", rich" or ""))
os.exit(failures > 0 and 1 or 0)
