-- Chạy toàn bộ spec bằng luajit thuần: `luajit tools/test.lua`. Thoát 1 nếu có ca hỏng hoặc spec chưa vào danh sách.
local Runner = require("tests.runner")

-- Mọi tests/*_spec.lua phải có trong Runner.SPECS (runner không quét thư mục).
local listed = {}
for _, m in ipairs(Runner.SPECS) do listed[m] = true end
local missing = {}
local p = io.popen("ls tests")
for file in p:lines() do
    local m = file:match("^(.+)_spec%.lua$")
    if m and not listed[m] then missing[#missing + 1] = file end
end
p:close()
if #missing > 0 then
    print("FAIL: spec chưa nằm trong tests/runner.lua SPECS: " .. table.concat(missing, ", "))
    os.exit(1)
end

os.exit(Runner.run())
