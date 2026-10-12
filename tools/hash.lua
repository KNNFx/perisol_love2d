-- Hash tất định của state cuối ván cho bộ seed mốc (golden). Chạy: `luajit tools/hash.lua` (so với fixture)
-- hoặc `luajit tools/hash.lua write` (sinh lại tests/fixtures/golden_hashes.lua; chỉ khi chủ ý đổi luật/bot).
-- Thuần Lua, không gọi love.*.

local M = {}

local function ktype(k) return type(k) == "number" and 0 or 1 end

local function ser(v, out, seen)
    local t = type(v)
    if t == "number" then
        out[#out + 1] = string.format("n%.17g", v)
    elseif t == "string" then
        out[#out + 1] = string.format("s%d:%s", #v, v)
    elseif t == "boolean" then
        out[#out + 1] = v and "T" or "F"
    elseif t == "nil" then
        out[#out + 1] = "N"
    elseif t == "table" then
        assert(not seen[v], "state có vòng tham chiếu")
        seen[v] = true
        local keys = {}
        for k in pairs(v) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b)
            local ta, tb = ktype(a), ktype(b)
            if ta ~= tb then return ta < tb end
            if ta == 0 then return a < b end
            return tostring(a) < tostring(b)
        end)
        out[#out + 1] = "{"
        for _, k in ipairs(keys) do
            ser(k, out, seen)
            out[#out + 1] = "="
            ser(v[k], out, seen)
            out[#out + 1] = ";"
        end
        out[#out + 1] = "}"
        seen[v] = nil
    else
        error("kiểu không tuần tự hóa được: " .. t)
    end
end

-- FNV-1a 32 bit với hai gốc khác nhau -> chuỗi hex 16 ký tự.
local function fnv32(str, basis)
    local bit = require("bit")
    local h = basis
    for i = 1, #str do
        h = bit.bxor(h, str:byte(i))
        -- h * 16777619 mod 2^32 = h*(2^24 + 403) = (h << 24) + h*403
        h = bit.tobit(bit.lshift(h, 24) + bit.tobit(h * 403))
    end
    return bit.tobit(h)
end

function M.hashState(state)
    local State = require("src.core.state")
    local out = {}
    ser(State.snapshot(state), out, {})
    local s = table.concat(out)
    return string.format("%08x%08x", fnv32(s, 0x811c9dc5) % 4294967296, fnv32(s, 0x01000193) % 4294967296)
end

-- Bộ mốc: seed 1..12 thường với số người 2,3,4 xoay vòng; seed 1..3 rich.
function M.cases()
    local list = {}
    for seed = 1, 12 do list[#list + 1] = { seed = seed, players = 2 + ((seed - 1) % 3), rich = false } end
    for seed = 1, 3 do list[#list + 1] = { seed = seed, players = 2 + ((seed - 1) % 3), rich = true } end
    return list
end

function M.name(c) return string.format("%s:%d:%d", c.rich and "rich" or "std", c.seed, c.players) end

function M.compute()
    local Sim = require("src.core.sim")
    local res = {}
    for _, c in ipairs(M.cases()) do
        local state = Sim.play(c.seed, c.players, { rich = c.rich })
        res[M.name(c)] = M.hashState(state)
    end
    return res
end

local function main()
    local got = M.compute()
    local names = {}
    for _, c in ipairs(M.cases()) do names[#names + 1] = M.name(c) end
    if arg[1] == "write" then
        local f = assert(io.open("tests/fixtures/golden_hashes.lua", "w"))
        f:write("-- Sinh bởi `make hash-write` (tools/hash.lua). Chỉ sinh lại khi chủ ý đổi luật hoặc bot, và ghi lý do vào commit.\nreturn {\n")
        for _, n in ipairs(names) do f:write(string.format("    [%q] = %q,\n", n, got[n])) end
        f:write("}\n")
        f:close()
        print("đã ghi tests/fixtures/golden_hashes.lua (" .. #names .. " mục)")
        return 0
    end
    local want = dofile("tests/fixtures/golden_hashes.lua")
    local bad = 0
    for _, n in ipairs(names) do
        local ok = want[n] == got[n]
        if not ok then bad = bad + 1 end
        print(string.format("%-14s %s %s", n, got[n], ok and "ok" or ("KHÁC (fixture " .. tostring(want[n]) .. ")")))
    end
    if bad > 0 then print(bad .. " hash lệch fixture") return 1 end
    print("golden hash khớp (" .. #names .. " ván)")
    return 0
end

if arg and arg[0] and arg[0]:match("hash%.lua$") then os.exit(main()) end
return M
