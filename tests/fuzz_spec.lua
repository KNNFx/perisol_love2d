-- Fuzz lệnh méo: Game.check / Game.legal không bao giờ ném lỗi; lệnh bị từ chối luôn có lý do (chuỗi không rỗng)
-- và không làm đổi state. Tất định (Rng seed cố định). State lấy từ các ván sim ở đủ các pha.
-- Báo lỗi gom theo ĐIỂM vỡ (file:dòng của lỗi ném ra) để biết sửa bao nhiêu chỗ.

local Game      = require("src.core.game")
local Rng       = require("src.core.rng")
local Sim       = require("src.core.sim")
local State     = require("src.core.state")
local Units     = require("src.core.units")

-- Mẫu lệnh hợp lệ về hình dạng cho mọi loại (giá trị có thể sai ngữ cảnh), để đột biến khi Game.legal không có loại đó.
local TEMPL = {
    placeHQ = { start = 1 }, roll = {}, rebelStep = { q = 1, r = 1 }, chooseLoss = { res = "gold" },
    trade = { give = "gold", get = "science" }, buyTile = { q = 1, r = 1 }, upgradeHQ = {},
    upgradeSub = { q = 1, r = 1 }, buildSpecial = { id = "S-01", q = 1, r = 1, rot = 0 }, upgradeSpecial = { uid = 1 },
    fortressStrike = { uid = 1, target = "1,1" }, buildDerived = { id = "D-01", a = 1, b = 2, q = 1, r = 1 },
    redeemBond = { n = 1 }, foundSub = { uid = 1 }, buyUnit = { unit = "expedition", q = 1, r = 1 },
    moveUnit = { uid = 1, q = 1, r = 1 }, upgradeRoad = { q = 1, r = 1 }, proposeTrade = { to = 2, give = "gold", get = "science" },
    suppress = { uid = 1, dir = 1, pay = false }, garrison = { uid = 1 }, disband = { uid = 1 }, placeVote = { q = 1, r = 1 },
    build = { id = "B-01", q = 1, r = 1 }, upgrade = { uid = 1, q = 1, r = 1, rot = 0 }, demolish = { uid = 1 },
    respond = { choice = "accept" }, endTurn = {},
}
local TYPES = {}
for t in pairs(TEMPL) do TYPES[#TYPES + 1] = t end
table.sort(TYPES)

local NAN = 0 / 0
local BAD_VALUES = { "5", "", "abc", "1,1", {}, { 1 }, { q = 1, r = 1 }, 1.5, -1, 0, 2 ^ 53, 1e308, -1e308, NAN, math.huge, -math.huge,
    true, false, print }
local BAD_COORDS = { { 9999, 9999 }, { -50, -50 }, { 1e9, 0 }, { 0, -1e9 }, { -1, -1 }, { 1e3, 1e3 }, { 0.5, 0.5 }, { NAN, NAN } }
local BAD_IDS = { 99999, -1, 0, 0.5, 2 ^ 31, "X-99", "S-99", "D-99", "B-99", "dragon", "9,9", "zz", "gold " }
local BAD_PIDS = { 0, -1, 99, 1.5, "1", "", {}, true, NAN, math.huge }
local NON_TABLES = { 5, "x", true, print, 0, "" }

local function copy(t)
    local c = {}
    for k, v in pairs(t) do c[k] = v end
    return c
end

local function describe_cmd(cmd)
    if type(cmd) ~= "table" then return type(cmd) .. ":" .. tostring(cmd) end
    local parts = {}
    for k, v in pairs(cmd) do parts[#parts + 1] = tostring(k) .. "=" .. (type(v) == "table" and "{..}" or tostring(v)) end
    table.sort(parts)
    return "{" .. table.concat(parts, ",") .. "}"
end

-- Sao chép sâu / so sánh sâu (không tuần tự hóa: nhanh hơn nhiều khi phải so sau từng lệnh). Bỏ `map` (bất biến, tái sinh từ seed).
local function deepCopy(v, seen)
    if type(v) ~= "table" then return v end
    seen = seen or {}
    if seen[v] then return seen[v] end
    local c = {}
    seen[v] = c
    for k, x in pairs(v) do c[deepCopy(k, seen)] = deepCopy(x, seen) end
    return setmetatable(c, getmetatable(v))
end

local function same(a, b, seen)
    if a ~= a and b ~= b then return true end   -- NaN
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    if a == b then return true end
    seen = seen or {}
    if seen[a] == b then return true end
    seen[a] = b
    for k, x in pairs(a) do
        if type(k) == "table" then return false end
        if not same(x, b[k], seen) then return false end
    end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

local function cloneState(state) return assert(Game.load(Game.save(state))) end

-- ─── Thu state ở đủ pha ─────────────────────────────────────────────────────

local CAP = { roll = 5, rebel_move = 5, rebel_loss = 4, action = 14, prompt = 4, over = 4, setup_hq = 3 }

local function collect()
    local snaps = {}   -- snaps[i] = { phase, state }
    local counts = {}
    local function add(state)
        local ph = state.phase
        counts[ph] = (counts[ph] or 0) + 1
        snaps[#snaps + 1] = { phase = ph, state = cloneState(state) }
    end
    local function want(ph, n) return (counts[ph] or 0) < CAP[ph] and (ph ~= "action" and ph ~= "roll" or n % 37 == 0) end

    -- setup_hq: ván mới và sau các lần đặt HQ đầu
    for _, players in ipairs({ 2, 3, 4 }) do
        local s = Game.new({ seed = 400 + players, players = players })
        add(s)
        Game.apply(s, Game.legal(s)[1])
        if s.phase == "setup_hq" and (counts.setup_hq or 0) < CAP.setup_hq then add(s) end
    end

    for i, seed in ipairs({ 1, 2, 3, 4, 5, 6 }) do
        local n = 0
        local last
        local state = Sim.play(seed, 2 + (i % 3), { onCommand = function(s)
            n = n + 1
            last = s
            local ph = s.phase
            if ph ~= "over" and ph ~= "setup_hq" and want(ph, n) then add(s) end
        end })
        if (counts.over or 0) < CAP.over then add(state) end
    end

    -- ván nạp đầy tài nguyên (rich) cắt ở vòng 9: có Phái Sinh, Đặc Biệt, đơn vị, đường, Khu Trực Thuộc để lệnh méo chạm tới
    local STOP = {}
    local rn, richSnaps = 0, 0
    pcall(Sim.play, 21, 3, { rich = true, onCommand = function(s)
        rn = rn + 1
        if s.phase == "action" and rn % 45 == 0 and richSnaps < 8 then richSnaps = richSnaps + 1; add(s) end
        if s.round >= 9 then error(STOP) end
    end })

    -- pha prompt hiếm trong ván thường: dựng từ state action (lời nhắc trade và cancel7 đều đã đăng ký)
    local base
    for _, s in ipairs(snaps) do if s.phase == "action" then base = s.state break end end
    if base and (counts.prompt or 0) < CAP.prompt then
        local actor = Game.actor(base)
        local other = actor % base.playerCount + 1
        local a = cloneState(base)
        Game.openPrompt(a, { kind = "trade", pid = other, from = actor, give = "gold", get = "science", fee = 0,
                             options = { "accept", "decline" }, resume = "action" })
        add(a)
        local b = cloneState(base)
        Game.openPrompt(b, { kind = "cancel7", pid = actor, roller = actor, rest = {}, options = { "cancel", "pass" }, resume = "roll" })
        add(b)
    end
    return snaps
end

-- ─── Sinh lệnh méo ──────────────────────────────────────────────────────────

local function fieldsOf(cmd)
    local ks = {}
    for k in pairs(cmd) do if k ~= "type" then ks[#ks + 1] = k end end
    table.sort(ks)
    return ks
end

-- Gom lệnh gốc cho một state: lệnh từ Game.legal (mỗi loại tối đa 3) cộng mẫu của mọi loại.
local function basesFor(state, rng)
    local legal = Game.legal(state)
    local by, bases = {}, {}
    for _, c in ipairs(legal) do
        by[c.type] = by[c.type] or {}
        table.insert(by[c.type], c)
    end
    for _, t in ipairs(TYPES) do
        local list = by[t]
        if list then
            for _ = 1, math.min(3, #list) do bases[#bases + 1] = copy(rng:pick(list)) end
        end
        local m = copy(TEMPL[t]); m.type = t
        bases[#bases + 1] = m
    end
    return bases, legal
end

local function generate(state, rng, pool, emit)
    local bases, legal = basesFor(state, rng)
    local actor = Game.actor(state)
    local function base() return copy(rng:pick(bases)) end

    for _ = 1, 6 do emit("nonTable", rng:pick(NON_TABLES)) end
    emit("nonTable", nil)
    emit("noType", {})
    emit("noType", { pid = actor })
    emit("noType", { q = 1, r = 1 })
    emit("noType", { type = nil, uid = 1 })
    for _, tv in ipairs({ "foo", "", 123, true, {}, "ROLL", "roll ", NAN }) do emit("unknownType", { type = tv, pid = actor }) end
    emit("unknownType", { type = "__index" })
    emit("unknownType", { type = "constructor" })

    for _ = 1, 40 do   -- thiếu từng trường bắt buộc
        local c = base()
        local ks = fieldsOf(c)
        if #ks > 0 then c[rng:pick(ks)] = nil end
        emit("missingField", c)
    end
    for _, c0 in ipairs(bases) do   -- thiếu toàn bộ trường
        local c = { type = c0.type }
        emit("missingField", c)
    end

    for _ = 1, 60 do   -- sai kiểu / giá trị biên từng trường
        local c = base()
        local ks = fieldsOf(c)
        if #ks > 0 then c[rng:pick(ks)] = rng:pick(BAD_VALUES) end
        emit("wrongType", c)
    end
    for _ = 1, 20 do   -- nhiều trường cùng hỏng
        local c = base()
        for _, k in ipairs(fieldsOf(c)) do c[k] = rng:pick(BAD_VALUES) end
        emit("wrongType", c)
    end

    for _ = 1, 25 do   -- tọa độ ngoài bản đồ
        local c = base()
        local co = rng:pick(BAD_COORDS)
        c.q, c.r = co[1], co[2]
        emit("outOfMap", c)
    end

    for _ = 1, 30 do   -- pid sai / không tồn tại
        local c = base()
        c.pid = rng:pick(BAD_PIDS)
        emit("badPid", c)
    end
    for _ = 1, 10 do   -- người nhận / đích sai
        local c = base()
        c.to = rng:pick(BAD_PIDS)
        emit("badPid", c)
    end

    for _ = 1, 25 do   -- id công trình / đơn vị / uid không tồn tại
        local c = base()
        local ks = {}
        for _, k in ipairs(fieldsOf(c)) do
            if k == "uid" or k == "id" or k == "a" or k == "b" or k == "unit" or k == "target" or k == "res"
                or k == "give" or k == "get" or k == "choice" or k == "start" then ks[#ks + 1] = k end
        end
        if #ks > 0 then c[rng:pick(ks)] = rng:pick(BAD_IDS) end
        emit("badId", c)
    end

    for _ = 1, 25 do   -- lệnh hợp lệ ở state khác nhưng sai pha ở state này
        if #pool > 0 then emit("wrongPhase", copy(rng:pick(pool))) end
    end
    for _, t in ipairs(TYPES) do   -- mẫu của mọi loại lệnh (kể cả pha sai)
        local m = copy(TEMPL[t]); m.type = t
        emit("wrongPhase", m)
    end

    for _ = 1, 50 do   -- đột biến một trường của lệnh lấy từ Game.legal
        if #legal > 0 then
            local c = copy(rng:pick(legal))
            local ks = fieldsOf(c)
            if #ks > 0 then
                local k = rng:pick(ks)
                local v = c[k]
                local roll = rng:int(1, 4)
                if roll == 1 then c[k] = rng:pick(BAD_VALUES)
                elseif roll == 2 and type(v) == "number" then c[k] = v + rng:pick({ -1, 1, 7, 1000 })
                elseif roll == 3 and type(v) == "number" then c[k] = -v
                else c[k] = nil end
            end
            emit("mutateLegal", c)
        end
    end
end

-- ─── Chạy fuzz ──────────────────────────────────────────────────────────────

local function location(err)
    local s = tostring(err)
    return s:match("([%w_/%.]+%.lua:%d+):") or ("?: " .. s:sub(1, 60))
end

local function run()
    local snaps = collect()
    local rng = Rng.new("fuzz:v1")
    local R = {
        total = 0, byClass = {}, byPhase = {}, statesByPhase = {},
        accepted = 0, rejected = 0,
        checkThrew = 0, badReason = 0, stateChanged = 0, applyAcceptedThrew = 0, legalThrew = 0,
        sites = {},   -- "loại: file:dòng" -> { n, class, sample }
    }
    local cloneBudget = 150

    local function site(kind, where, class, cmd, phase)
        local k = kind .. " @ " .. where
        local s = R.sites[k]
        if not s then s = { n = 0, classes = {}, sample = phase .. " " .. describe_cmd(cmd) }; R.sites[k] = s end
        s.n = s.n + 1
        s.classes[class] = true
    end

    -- pool lệnh hợp lệ từ mọi state (cho lớp wrongPhase)
    local pool = {}
    for _, s in ipairs(snaps) do
        R.statesByPhase[s.phase] = (R.statesByPhase[s.phase] or 0) + 1
        local okL, legal = pcall(Game.legal, s.state)
        if not okL then
            R.legalThrew = R.legalThrew + 1
            site("legal threw", location(legal), "legal", {}, s.phase)
        else
            for i = 1, math.min(#legal, 6) do pool[#pool + 1] = legal[rng:int(1, #legal)] end
        end
    end

    for _, s in ipairs(snaps) do
        local state, phase = s.state, s.phase
        local baseline = deepCopy(State.snapshot(state))
        local function one(class, cmd)
            R.total = R.total + 1
            R.byClass[class] = (R.byClass[class] or 0) + 1
            R.byPhase[phase] = (R.byPhase[phase] or 0) + 1
            local okC, ok, why = pcall(Game.check, state, cmd)
            if not okC then
                R.checkThrew = R.checkThrew + 1
                site("check threw", location(ok), class, cmd, phase)
                return
            end
            if ok then
                R.accepted = R.accepted + 1
                if cloneBudget > 0 then   -- lệnh check cho qua thì apply cũng không được ném lỗi (làm trên bản sao)
                    cloneBudget = cloneBudget - 1
                    local c = cloneState(state)
                    local okA, err = pcall(Game.apply, c, cmd)
                    if not okA then
                        R.applyAcceptedThrew = R.applyAcceptedThrew + 1
                        site("apply threw after accepted check", location(err), class, cmd, phase)
                    end
                end
                return
            end
            R.rejected = R.rejected + 1
            if ok ~= false or type(why) ~= "string" or why == "" then
                R.badReason = R.badReason + 1
                site("rejected without string reason", (type(cmd) == "table" and tostring(cmd.type) or "non-table"), class, cmd, phase)
            end
            pcall(Game.apply, state, cmd)   -- cách báo từ chối của apply giữ nguyên; chỉ cần state không đổi
            local after = State.snapshot(state)
            if not same(after, baseline) then
                R.stateChanged = R.stateChanged + 1
                site("state changed after rejected command", (type(cmd) == "table" and tostring(cmd.type) or "non-table"), class, cmd, phase)
                baseline = deepCopy(after)
            end
        end
        generate(state, rng, pool, one)
    end
    return R
end

-- Điểm vỡ gom theo file:dòng, để thông điệp của ca đỏ đủ để tìm chỗ sửa.
local function siteLines(R, kindPrefix)
    local keys = {}
    for k in pairs(R.sites) do if k:sub(1, #kindPrefix) == kindPrefix then keys[#keys + 1] = k end end
    table.sort(keys)
    local out = {}
    for _, k in ipairs(keys) do
        local st = R.sites[k]
        local cl = {}
        for c in pairs(st.classes) do cl[#cl + 1] = c end
        table.sort(cl)
        out[#out + 1] = string.format("%s x%d [%s] mẫu: %s", k, st.n, table.concat(cl, ","), st.sample)
    end
    return table.concat(out, "\n       ")
end

-- Chạy fuzz đúng một lần, lúc ca đầu tiên cần; nếu lần chạy ném lỗi thì mọi ca dùng chung kết quả đều đỏ (runner không sập).
local cached
local function result()
    if not cached then
        local ok, R = pcall(run)
        cached = { ok = ok, R = R }
    end
    if not cached.ok then error("fuzz không chạy xong: " .. tostring(cached.R), 0) end
    return cached.R
end

local function noneOf(counter, kindPrefix, msg)
    local R = result()
    if R[counter] ~= 0 then error(msg .. ": " .. R[counter] .. "\n       " .. siteLines(R, kindPrefix), 0) end
end

describe("fuzz: lệnh méo", function()
    it("Game.check không bao giờ ném lỗi", function() noneOf("checkThrew", "check threw", "số lần check ném lỗi") end)
    it("Game.legal không ném lỗi ở mọi state đã thu", function() noneOf("legalThrew", "legal threw", "legal ném lỗi") end)
    it("lệnh bị từ chối luôn trả false kèm lý do chuỗi không rỗng", function()
        noneOf("badReason", "rejected without", "từ chối không kèm lý do")
    end)
    it("lệnh bị từ chối không làm đổi state", function() noneOf("stateChanged", "state changed", "state đổi sau lệnh bị từ chối") end)
    it("lệnh check cho qua thì apply không ném lỗi", function()
        noneOf("applyAcceptedThrew", "apply threw", "apply ném sau check ok")
    end)

    -- Tọa độ là chuỗi số ("3") không được coi như số: lệnh bị từ chối kèm lý do và state không đổi.
    it("lệnh có tọa độ chuỗi số bị từ chối, state không đổi", function()
        local s, pid, c = require("tests.arena")(4, 2)
        local cq, cr = tostring(c.q), tostring(c.r)
        local u = Units.spawn(s, pid, "expedition", c)
        -- bản đúng kiểu của chính các lệnh này phải qua được, để biết lệnh chuỗi bị từ chối vì tọa độ chứ không vì lý do khác
        expect.truthy(Game.check(s, { type = "build", id = "B-01", q = c.q, r = c.r }))
        local cmds = {
            { type = "placeVote", q = cq, r = cr }, { type = "placeVote", q = c.q, r = cr },
            { type = "buyTile", q = cq, r = cr }, { type = "build", id = "B-01", q = cq, r = cr },
            { type = "moveUnit", uid = u.uid, q = cq, r = cr }, { type = "upgradeRoad", q = cq, r = cr },
            { type = "buyUnit", unit = "expedition", q = cq, r = cr },
        }
        local before = deepCopy(State.snapshot(s))
        local hist = #s.history
        for _, cmd in ipairs(cmds) do
            local ok, why = Game.check(s, cmd)
            expect.falsy(ok, cmd.type .. " với tọa độ chuỗi phải bị từ chối")
            expect.truthy(type(why) == "string" and why ~= "", cmd.type .. " thiếu lý do")
            pcall(Game.apply, s, cmd)
        end
        expect.eq(#s.history, hist, "history không được nhận lệnh bị từ chối")
        expect.truthy(same(State.snapshot(s), before), "state không đổi")
    end)
end)
