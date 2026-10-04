-- Mini test runner chạy trong LÖVE: `lovec.exe . --test` (xem test.bat).
-- API kiểu busted: describe / it / expect.*. Spec nằm ở tests/*_spec.lua.

local M = {}

local suites, stack = {}, {}

local function describe(name, fn)
    local suite = { name = name, tests = {} }
    suites[#suites + 1] = suite
    stack[#stack + 1] = suite
    fn()
    stack[#stack] = nil
end

local function it(name, fn)
    local suite = stack[#stack]
    assert(suite, "it() phải nằm trong describe()")
    suite.tests[#suite.tests + 1] = { name = name, fn = fn }
end

local function fmt(v)
    if type(v) == "table" then
        local parts = {}
        for k, x in pairs(v) do parts[#parts + 1] = tostring(k) .. "=" .. tostring(x) end
        table.sort(parts)
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return tostring(v)
end

local expect = {}

function expect.eq(actual, expected, msg)
    if actual ~= expected then
        error((msg and (msg .. ": ") or "") .. "expected " .. fmt(expected) .. ", got " .. fmt(actual), 2)
    end
end

function expect.near(actual, expected, eps, msg)
    eps = eps or 1e-9
    if math.abs(actual - expected) > eps then
        error((msg and (msg .. ": ") or "") .. "expected ~" .. expected .. ", got " .. actual, 2)
    end
end

function expect.truthy(v, msg)
    if not v then error(msg or ("expected truthy, got " .. fmt(v)), 2) end
end

function expect.falsy(v, msg)
    if v then error(msg or ("expected falsy, got " .. fmt(v)), 2) end
end

function expect.error(fn, msg)
    local ok = pcall(fn)
    if ok then error(msg or "expected an error, but none was raised", 2) end
end

-- So sánh sâu hai bảng (dùng cho kiểm tra tính tất định).
function expect.deepEq(a, b, msg, path)
    path = path or "root"
    if type(a) ~= type(b) then
        error((msg or "") .. " " .. path .. ": type " .. type(a) .. " vs " .. type(b), 2)
    end
    if type(a) ~= "table" then
        if a ~= b then error((msg or "") .. " " .. path .. ": " .. fmt(a) .. " vs " .. fmt(b), 2) end
        return
    end
    for k, v in pairs(a) do expect.deepEq(v, b[k], msg, path .. "." .. tostring(k)) end
    for k in pairs(b) do
        if a[k] == nil then error((msg or "") .. " " .. path .. "." .. tostring(k) .. ": missing in first", 2) end
    end
end

function M.run()
    local items = love.filesystem.getDirectoryItems("tests")
    table.sort(items)

    _G.describe, _G.it, _G.expect = describe, it, expect
    for _, file in ipairs(items) do
        local mod = file:match("^(.+_spec)%.lua$")
        if mod then require("tests." .. mod) end
    end

    local passed, failed = 0, 0
    for _, suite in ipairs(suites) do
        print(suite.name)
        for _, t in ipairs(suite.tests) do
            local ok, err = xpcall(t.fn, function(e) return e end)
            if ok then
                passed = passed + 1
                print("  ok   " .. t.name)
            else
                failed = failed + 1
                print("  FAIL " .. t.name)
                print("       " .. tostring(err))
            end
        end
    end

    print(string.format("\n%d passed, %d failed", passed, failed))
    io.stdout:flush()
    return failed == 0 and 0 or 1
end

return M
