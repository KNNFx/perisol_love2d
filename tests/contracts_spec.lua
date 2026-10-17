-- Contract quan sát được qua API: từ chối không đổi dữ liệu; không chia sẻ quyền sở hữu payload;
-- save lỗi không lọt qua ranh giới load. Không kiểm tên nội bộ hoặc văn bản nguồn.
local Game = require("src.core.game")
local Serialize = require("src.core.serialize")
local Wallet = require("src.core.wallet")
local Structures = require("src.core.structures")
local Modifiers = require("src.core.modifiers")

local function actionState()
    local s = Game.new({ seed = 44, players = 2 })
    while s.phase ~= "action" do Game.apply(s, Game.legal(s)[1]) end
    return s
end

local function offer(s)
    local from = Game.actor(s)
    return { kind = "trade", pid = from % 2 + 1, from = from, give = { gold = 1 }, get = { science = 1 },
        fee = 0, resume = "action", options = { "accept", "decline" } }
end

describe("contract: dữ liệu và quyền sở hữu", function()
    it("lệnh bị từ chối không đổi state/history, kể cả payload vòng hoặc không lưu được", function()
        local s = actionState()
        local before = Game.save(s)
        local loop = { type = "endTurn" }; loop.extra = loop
        for _, cmd in ipairs({ false, 4, loop, { type = "endTurn", pid = false },
            { type = "endTurn", extra = function() end }, { type = "endTurn", extra = math.huge },
            setmetatable({ type = "endTurn" }, {}) }) do
            local ok, why = Game.check(s, cmd)
            expect.eq(ok, false); expect.eq(type(why), "string")
            expect.error(function() Game.apply(s, cmd) end)
            expect.eq(Game.save(s), before)
        end
    end)

    it("caller sửa command sau apply không đổi history hoặc kết quả replay", function()
        local s = Game.new({ seed = 6, players = 2 })
        local cmd = { type = "placeHQ", start = 1, note = { text = "original" } }
        Game.apply(s, cmd)
        local before = Game.save(s)
        cmd.start, cmd.note.text = 2, "changed"
        expect.eq(Game.save(s), before)
        local replay = Game.replay(6, 2, s.history)
        expect.eq(Game.save(replay), before)
    end)

    it("đề xuất trao đổi có số lượng sai kiểu bị từ chối, không ném lỗi hay đổi state", function()
        local s = actionState()
        local before = Game.save(s)
        for _, bad in ipairs({ "1", {}, false, -1, 0.5, math.huge, 0/0 }) do
            local ok, why = Game.check(s, { type = "proposeTrade", to = Game.actor(s) % 2 + 1,
                give = { gold = bad }, get = { science = 1 } })
            expect.eq(ok, false); expect.eq(type(why), "string")
            expect.eq(Game.save(s), before)
        end
    end)

    it("sửa báo giá không đổi giá lần sau hoặc tiền thực trả", function()
        local s = actionState()
        local pid = Game.actor(s)
        local cost = Game.price(s, pid, "hq")
        for k, n in pairs(cost) do Wallet.gain(s.players[pid].res, k, n) end
        local before = Serialize.copy(s.players[pid].res)
        local expected = Serialize.copy(cost)
        cost.gold, cost.engineering = 0, 0
        expect.deepEq(Game.price(s, pid, "hq"), expected)
        Game.apply(s, { type = "upgradeHQ" })
        for k, n in pairs(expected) do expect.eq(s.players[pid].res[k], before[k] - n) end
    end)

    it("prompt giữ payload riêng, không bị ghi đè, lưu/nạp và từ chối vẫn tiếp tục đúng lượt", function()
        local s = actionState()
        local p = offer(s)
        local original = Serialize.copy(p)
        Game.openPrompt(s, p)
        p.give.gold, p.options[1] = 999, "changed"
        expect.deepEq(s.prompt, original)
        local before = Game.save(s)
        expect.error(function() Game.openPrompt(s, original) end)
        expect.eq(Game.save(s), before)
        local back = assert(Game.load(before))
        local resources = Serialize.copy(back.players)
        -- Hai người chưa có chợ: không được liệt kê accept mà check lại từ chối.
        local legal = Game.legal(back)
        expect.eq(#legal, 1); expect.eq(legal[1].choice, "decline")
        Game.apply(back, legal[1])
        expect.eq(back.phase, "action"); expect.eq(Game.actor(back), original.from)
        expect.deepEq(back.players, resources)
    end)
end)

describe("contract: phép cập nhật nội bộ", function()
    it("Wallet từ chối lượng sai trước khi ghi bất kỳ tài nguyên nào", function()
        for _, bad in ipairs({ -1, 0.5, math.huge, 0/0, "1", false }) do
            local res = { gold = 5, science = 4 }
            local before = Serialize.copy(res)
            expect.error(function() Wallet.pay(res, { gold = 1, science = bad }) end)
            expect.deepEq(res, before)
            expect.error(function() Wallet.gain(res, "gold", bad) end)
            expect.deepEq(res, before)
            expect.error(function() Wallet.take(res, "gold", bad) end)
            expect.deepEq(res, before)
        end
        local res = { gold = 2 }
        expect.error(function() Wallet.pay(res, { unknown = 1, gold = 1 }) end)
        expect.deepEq(res, { gold = 2 })
    end)

    it("đặt footprint xung đột không chiếm dở ô hoặc tiêu thụ UID", function()
        local s = Game.new({ seed = 6, players = 2 })
        local a, b = s.map.list[1], s.map.list[2]
        Structures.place(s, { id = "B-01", owner = 1 }, { b })
        local before = Game.save(s)
        expect.error(function() Structures.place(s, { id = "B-02", owner = 1 }, { a, b }) end)
        expect.eq(Game.save(s), before)
        expect.error(function() Structures.place(s, { id = "B-02", owner = 1 }, { a, a }) end)
        expect.eq(Game.save(s), before)
    end)

    it("nâng footprint không được bỏ ô cũ, đổi neo hoặc chiếm dở ô", function()
        local s = Game.new({ seed = 6, players = 2 })
        local a, b, c = s.map.list[1], s.map.list[2], s.map.list[3]
        local building = Structures.place(s, { id = "B-01", owner = 1 }, { a })
        Structures.place(s, { id = "B-02", owner = 1 }, { c })
        local before = Game.save(s)
        for _, tiles in ipairs({ { b }, { b, a }, { a, b, c } }) do
            expect.error(function() Structures.upgrade(s, building.uid, tiles, 2, 0) end)
            expect.eq(Game.save(s), before)
        end
    end)

    it("modifier phải trả số hữu hạn, không truyền kết quả sai sang bước sau", function()
        for _, bad in ipairs({ false, "1", math.huge, 0/0 }) do
            local modifiers = Modifiers.new()
            local called = false
            modifiers:register("base", function() return bad end)
            modifiers:register("aura", function(n) called = true; return n end)
            expect.error(function() modifiers:apply(1, {}) end)
            expect.eq(called, false)
        end
    end)
end)

describe("contract: save và việc đang chờ", function()
    local mutations = {
        { "HQ thiếu sau setup", function(s) s.players[1].hq = false end },
        { "phase chưa kết thúc ở vòng 21", function(s) s.round = 21 end },
        { "HQ quá cấp", function(s) s.players[1].hqLevel = 99 end },
        { "Sub sai cấp", function(s) s.players[1].subs = { { q = 0, r = 0, level = 99 } } end },
        { "UID âm", function(s) s.nextUid = -1 end },
        { "RNG không tiến triển", function(s) s.rng.state = 0 end },
        { "xúc xắc ngoài miền", function(s) s.dice = { 7, 1 } end },
        { "đơn vị sai payload", function(s) s.units = { [1] = { uid = 1, type = "trade", owner = 1 } }; s.nextUnitUid = 2 end },
        { "prompt lạ", function(s) local p = offer(s); p.kind = "unknown"; s.phase = "prompt"; s.prompt = p end },
        { "prompt không có lựa chọn", function(s) local p = offer(s); p.options = {}; s.phase = "prompt"; s.prompt = p end },
        { "prompt sai resume", function(s) local p = offer(s); p.resume = "prompt"; s.phase = "prompt"; s.prompt = p end },
        { "trade sai tài nguyên", function(s) local p = offer(s); p.give.gold = -1; s.phase = "prompt"; s.prompt = p end },
        { "cancel7 sai người còn lại", function(s)
            s.prompt = { kind = "cancel7", pid = Game.actor(s), roller = Game.actor(s), rest = { 99 },
                options = { "cancel", "allow" }, resume = "action" }; s.phase = "prompt"
        end },
        { "pushrebel thiếu công trình", function(s)
            s.prompt = { kind = "pushrebel", pid = Game.actor(s), uid = 999, cost = 2, rest = {},
                options = { "push", "decline" }, target = "0,0", resume = "action" }; s.phase = "prompt"
        end },
        { "rebel thiếu roller", function(s) s.phase = "rebel_move"; s.rebel.pending = { stage = "move", points = 2, visited = {} } end },
        { "rebel ngoài bản đồ", function(s) s.rebel = { q = -99, r = -99 } end },
    }
    for _, case in ipairs(mutations) do
        it("load từ chối " .. case[1] .. " bằng nil và lý do", function()
            local s = actionState()
            case[2](s)
            local ok, loaded, why = pcall(Game.load, Game.save(s))
            expect.truthy(ok); expect.eq(loaded, nil); expect.eq(type(why), "string")
        end)
    end
    it("load từ chối bộ cấp UID trùng công trình đang tồn tại", function()
        local s = actionState()
        local pid = Game.actor(s)
        for k in pairs(s.players[pid].res) do if k ~= "bond" then Wallet.gain(s.players[pid].res, k, 20) end end
        local buy
        for _, cmd in ipairs(Game.legal(s)) do if cmd.type == "buyTile" then buy = cmd break end end
        Game.apply(s, assert(buy))
        local build
        for _, cmd in ipairs(Game.legal(s)) do if cmd.type == "build" then build = cmd break end end
        Game.apply(s, assert(build))
        s.nextUid = next(s.buildings)
        local loaded, why = Game.load(Game.save(s))
        expect.eq(loaded, nil); expect.eq(type(why), "string")
    end)
    it("save chứa vòng tham chiếu, hàm hoặc số không hữu hạn bị từ chối", function()
        for _, text in ipairs({ "local s={}; s.state=s; s.version=4; return s",
            "return {version=0/0,state={}}", "return {version=4,state={x=function() end}}" }) do
            local ok, loaded, why = pcall(Game.load, text)
            expect.truthy(ok); expect.eq(loaded, nil); expect.eq(type(why), "string")
        end
    end)
end)
