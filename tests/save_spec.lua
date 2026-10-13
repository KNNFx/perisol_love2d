-- Contract Save (Architecture_Hardening_Plan §5): mỗi lần đổi hình dạng state là một migration tường minh;
-- save cũ nạp ra đúng hình dạng của Game.new và chơi tiếp được; save hỏng bị từ chối bằng nil, lý do.
-- Fixture tests/fixtures/saves/*.sav, sinh bằng code cũ thật (git archive + luajit, chơi N lệnh theo legal rồi Game.save):
--   v1.sav              commit 5c91e32 (SAVE_VERSION=1), seed 41, 3 người, 120 lệnh
--   v2.sav              commit dbe282d (SAVE_VERSION=2), seed 42, 4 người, 150 lệnh
--   v3_thieu_truong.sav commit 62eeec7 (v3 lúc mới ra đời: chưa có derived / nextDerivedUid / nextUnitUid), seed 43, 2 người, 90 lệnh
--   v3.sav              commit 5707dcb (v3 đầy đủ, trước M2b-1), seed 44, 3 người, 130 lệnh
local C         = require("src.config.constants")
local Game      = require("src.core.game")
local Serialize = require("src.core.serialize")
local Sim       = require("src.core.sim")

local function readFixture(name)
    local path = "tests/fixtures/saves/" .. name
    local f = io.open(path, "rb")
    if f then local s = f:read("*a"); f:close(); return s end
    if rawget(_G, "love") and love.filesystem then return love.filesystem.read(path) end
    error("không đọc được fixture " .. path)
end

local function keySet(t)
    local k = {}
    for key in pairs(t) do k[#k + 1] = tostring(key) end
    table.sort(k)
    return table.concat(k, ",")
end

-- Chơi tiếp tới hết ván bằng bot sim, kiểm tra bất biến sau mỗi 40 lệnh.
local function playOut(state)
    local guard = 0
    while state.phase ~= "over" do
        guard = guard + 1
        assert(guard < 2000, "ván không kết thúc")
        Sim.advance(state, 40)
        local ok, msg = Sim.invariants(state)
        assert(ok, "vi phạm bất biến khi chơi tiếp: " .. tostring(msg))
    end
end

local FIXTURES = { "v1.sav", "v2.sav", "v3.sav", "v3_thieu_truong.sav" }

describe("save: migration và fixture", function()
    for _, name in ipairs(FIXTURES) do
        it("fixture " .. name .. " nạp được, đúng hình dạng Game.new, chơi tiếp hết ván", function()
            local state, err = Game.load(readFixture(name))
            expect.truthy(state, tostring(err))
            local fresh = Game.new({ seed = state.seed, players = state.playerCount })
            expect.eq(keySet(state), keySet(fresh), "khóa cấp cao nhất")
            for pid, p in ipairs(state.players) do
                expect.eq(keySet(p), keySet(fresh.players[pid]), "khóa người chơi " .. pid)
            end
            expect.truthy(Sim.invariants(state))
            playOut(state)
            expect.eq(state.phase, "over")
        end)
    end

    it("save hiện tại có version = SAVE_VERSION và khứ hồi save, load, save cho chuỗi giống hệt", function()
        for _, seed in ipairs({ 40, 41, 42 }) do
            local s = Game.new({ seed = seed, players = 2 + seed % 3 })
            Sim.advance(s, 60 + seed)
            local str = Game.save(s)
            expect.eq(Serialize.load(str).version, C.SAVE_VERSION)
            local back = assert(Game.load(str))
            expect.eq(Game.save(back), str)
        end
    end)

    it("save cũ đã migrate rồi lưu lại cũng khứ hồi giống hệt", function()
        for _, name in ipairs(FIXTURES) do
            local once = Game.save(assert(Game.load(readFixture(name))))
            expect.eq(Game.save(assert(Game.load(once))), once, name)
        end
    end)
end)

describe("save: từ chối dữ liệu hỏng", function()
    -- Một save hiện tại hợp lệ ở dạng bảng thuần để mỗi biến thể tự làm hỏng một chỗ.
    local function good()
        local s = Game.new({ seed = 44, players = 3 })
        Sim.advance(s, 130)
        return Serialize.load(Game.save(s))
    end

    -- Mỗi biến thể: hàm sửa bảng save (trả chuỗi thì dùng nguyên chuỗi đó làm file).
    local variants = {
        { "chuỗi rác",                 function() return "rác" end },
        { "chuỗi rỗng",                function() return "" end },
        { "không phải bảng",           function() return "return 5" end },
        { "Lua gọi error",             function() return "return error('x')" end },
        { "thiếu version",             function(d) d.version = nil end },
        { "version tương lai",         function(d) d.version = C.SAVE_VERSION + 1 end },
        { "version 0",                 function(d) d.version = 0 end },
        { "version không nguyên",      function(d) d.version = 3.5 end },
        { "version sai kiểu",          function(d) d.version = "3" end },
        { "thiếu state",               function(d) d.state = nil end },
        { "state sai kiểu",            function(d) d.state = 7 end },
        { "players rỗng",              function(d) d.state.players = {} end },
        { "players sai kiểu",          function(d) d.state.players = "x" end },
        { "playerCount lệch players",  function(d) d.state.playerCount = 2 end },
        { "phase lạ",                  function(d) d.state.phase = "bậy" end },
        { "round sai kiểu",            function(d) d.state.round = "mười" end },
        { "round ngoài khoảng",        function(d) d.state.round = 99 end },
        { "turn ngoài khoảng",         function(d) d.state.turn = 99 end },
        { "order không phải hoán vị",  function(d) d.state.order = { 1, 1, 1 } end },
        { "rng sai kiểu",              function(d) d.state.rng = "x" end },
        { "thiếu history",             function(d) d.state.history = nil end },
        { "tài nguyên âm",             function(d) d.state.players[1].res.gold = -5 end },
        { "tài nguyên sai kiểu",       function(d) d.state.players[1].res.gold = "nhiều" end },
        { "players[i] sai kiểu",       function(d) d.state.players[2] = 5 end },
        { "công trình thiếu tiles",    function(d) d.state.buildings[next(d.state.buildings)].tiles = nil end },
        { "đơn vị loại lạ",            function(d) d.state.units[1] = { uid = 1, owner = 1, q = 0, r = 0, mp = 0, type = "rồng" } end },
        { "phase prompt thiếu prompt", function(d) d.state.phase = "prompt"; d.state.prompt = false end },
        { "seed không khớp bản đồ",    function(d) d.state.seed = d.state.seed + 1 end },
        { "seed sai kiểu",             function(d) d.state.seed = {} end },
    }

    for _, v in ipairs(variants) do
        it("từ chối: " .. v[1], function()
            local d = good()
            local r = v[2](d)
            local text = type(r) == "string" and r or Serialize.dump(d)
            local okcall, state, err = pcall(Game.load, text)
            expect.truthy(okcall, "Game.load ném lỗi: " .. tostring(state))
            expect.eq(state, nil, "phải trả nil")
            expect.eq(type(err), "string", "phải kèm lý do")
        end)
    end
end)
