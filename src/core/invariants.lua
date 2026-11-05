-- Kiểm tra bất biến và hình dạng của state. Thuần Lua, không gọi love.*. Tách khỏi sim.lua để Game.load dùng được
-- mà không tạo vòng phụ thuộc (sim.lua require game.lua).
--   Invariants.shape(state)  hình dạng: đủ trường, đúng kiểu, trong khoảng (an toàn với dữ liệu hỏng, không ném lỗi).
--   Invariants.check(state)  luật: tài nguyên, công trình, lãnh thổ, đơn vị ... (cần state.map; gọi sau shape).
-- Cả hai trả true, hoặc false, mô tả lỗi.

local C         = require("src.config.constants")
local Territory = require("src.core.territory")
local Units     = require("src.core.units")
local Buildings = require("src.data.buildings")
local Resources = require("src.data.resources")
local State     = require("src.core.state")
local Derived   = require("src.data.derived")
local Rounds    = require("src.core.rounds")

local Invariants = {}

Invariants.PHASES = { setup_hq = true, roll = true, rebel_move = true, rebel_loss = true, prompt = true,
                      action = true, over = true }

local function isInt(v) return type(v) == "number" and v > -math.huge and v < math.huge and v == math.floor(v) end
local function isTable(v) return type(v) == "table" end
local function nonnegative(v) return isInt(v) and v >= 0 end
local function isStampOrFalse(v) return v == false or (isInt(v) and v >= 1 and v <= C.MAX_ROUNDS) end
local function array(t)
    if not isTable(t) then return false end
    local n = 0
    for k in pairs(t) do
        if not isInt(k) or k < 1 or k > #t then return false end
        n = n + 1
    end
    return n == #t
end
local function coordinate(t) return isTable(t) and isInt(t.q) and isInt(t.r) end
local function tileKey(k) return type(k) == "string" and State.unkey(k) ~= nil end
local function optionalBool(v) return v == nil or type(v) == "boolean" end

-- Mỗi trường: tên, kiểm tra kiểu. Danh sách này đi cùng State.new (src/core/state.lua).
local STATE_TABLES = { "owner", "votes", "buildings", "occupied", "lostStrategic", "units", "roads", "derived", "plundered",
                       "log", "history", "takenStarts", "order", "players", "rng" }
local STATE_INTS   = { "nextUid", "nextUnitUid", "nextDerivedUid", "round", "turn", "setupIdx", "playerCount", "rounds" }

function Invariants.shape(s)
    if not isTable(s) then return false, "state không phải bảng" end
    if not (isInt(s.seed) or type(s.seed) == "string") then return false, "seed sai kiểu" end
    for _, k in ipairs(STATE_TABLES) do
        if not isTable(s[k]) then return false, "thiếu hoặc sai kiểu: " .. k end
    end
    for _, k in ipairs(STATE_INTS) do
        if not isInt(s[k]) then return false, "thiếu hoặc sai kiểu: " .. k end
    end
    local n = s.playerCount
    if n < 1 or n > 4 or not array(s.players) or #s.players ~= n then return false, "số người chơi không hợp lệ" end
    local function pid(v) return isInt(v) and v >= 1 and v <= n end
    if not Rounds.valid(s.rounds) or s.rounds > C.MAX_ROUNDS then return false, "số vòng ngoài khoảng" end
    if s.round < 1 or s.round > s.rounds + 1 then return false, "vòng ngoài khoảng" end
    if s.turn < 1 or s.turn > n then return false, "lượt ngoài khoảng" end
    if s.setupIdx < 1 or s.setupIdx > n + 1 then return false, "setupIdx ngoài khoảng" end
    if not Invariants.PHASES[s.phase] then return false, "phase lạ: " .. tostring(s.phase) end
    if not array(s.order) or #s.order ~= n then return false, "order sai độ dài" end
    local seen = {}
    for _, pid in ipairs(s.order) do
        if not isInt(pid) or pid < 1 or pid > n or seen[pid] then return false, "order không phải hoán vị" end
        seen[pid] = true
    end
    if not isInt(s.rng.state) or s.rng.state < 1 or s.rng.state >= 2147483647 then return false, "rng.state ngoài miền MINSTD" end
    if type(s.rng.base) ~= "string" and type(s.rng.base) ~= "number" then return false, "rng.base sai kiểu" end

    for pid = 1, n do
        local p = s.players[pid]
        if not isTable(p) or p.id ~= pid then return false, "người chơi " .. pid .. " sai kiểu" end
        if not (isTable(p.res) and isTable(p.subs) and isTable(p.carry)) then return false, "P" .. pid .. " thiếu res/subs/carry" end
        if not nonnegative(p.votes) or not isInt(p.hqLevel) or p.hqLevel < 1 or p.hqLevel > C.HQ_MAX_LEVEL then
            return false, "P" .. pid .. " sai votes/hqLevel"
        end
        if p.hq ~= false and not (isTable(p.hq) and isInt(p.hq.q) and isInt(p.hq.r)) then return false, "P" .. pid .. " sai hq" end
        if s.phase ~= "setup_hq" and p.hq == false then return false, "P" .. pid .. " chưa có HQ sau setup" end
        for _, k in ipairs({ "strikeRound", "broadcastRound", "knightRetreatRound", "rerollRound" }) do
            if not isStampOrFalse(p[k]) then return false, "P" .. pid .. " sai " .. k end
        end
        if not nonnegative(p.cancel7Used) then return false, "P" .. pid .. " sai cancel7Used" end
        if not nonnegative(p.harass) or not nonnegative(p.bondAllow) or p.bondAllow > C.BOND_ALLOW_MAX
            or type(p.expelReady) ~= "boolean" or type(p.setFaceUsed) ~= "boolean" then
            return false, "P" .. pid .. " sai trạng thái M1.6"
        end
        if not array(p.subs) then return false, "P" .. pid .. " subs không phải danh sách" end
        for _, sub in ipairs(p.subs) do
            if not coordinate(sub) or not isInt(sub.level) or sub.level < 1 or sub.level > C.SUB_MAX_LEVEL then
                return false, "P" .. pid .. " Khu Trực Thuộc không hợp lệ"
            end
        end
        for k, v in pairs(p.res) do
            if not Resources.byKey[k] or not nonnegative(v) then return false, "P" .. pid .. " tài nguyên không hợp lệ" end
        end
        for k in pairs(p.carry) do
            if not Resources.byKey[k] then return false, "P" .. pid .. " carry có tài nguyên lạ" end
        end
    end

    for k, owner in pairs(s.owner) do
        if not tileKey(k) or not pid(owner) then return false, "owner không hợp lệ" end
    end
    for k, votes in pairs(s.votes) do
        if not tileKey(k) or not isTable(votes) then return false, "votes không hợp lệ" end
        for owner, v in pairs(votes) do
            if not pid(owner) or not nonnegative(v) then return false, "phiếu trên ô không hợp lệ" end
        end
    end
    for k, lost in pairs(s.lostStrategic) do
        if not tileKey(k) or lost ~= true then return false, "lostStrategic không hợp lệ" end
    end
    for k, road in pairs(s.roads) do
        if not tileKey(k) or not isTable(road) or (road.level ~= 1 and road.level ~= 2) then return false, "roads không hợp lệ" end
    end
    for k, uid in pairs(s.occupied) do
        if not tileKey(k) or not isInt(uid) or uid < 1 then return false, "occupied không hợp lệ" end
    end
    local maxBuilding, maxUnit, maxDerived = 0, 0, 0
    for uid, b in pairs(s.buildings) do
        if not isInt(uid) or uid < 1 or not isTable(b) or b.uid ~= uid or not pid(b.owner)
            or type(b.id) ~= "string" or not isInt(b.level) or not Buildings.level(b.id, b.level)
            or not array(b.tiles) or #b.tiles == 0 or b.anchor ~= b.tiles[1] or not isInt(b.rot)
            or not optionalBool(b.demolishing) then return false, "công trình sai hình dạng" end
        local tiles = {}
        for _, k in ipairs(b.tiles) do
            if not tileKey(k) or tiles[k] then return false, "footprint trùng hoặc sai ô" end
            tiles[k] = true
        end
        maxBuilding = math.max(maxBuilding, uid)
    end
    for uid, u in pairs(s.units) do
        if not isInt(uid) or uid < 1 or not coordinate(u) or u.uid ~= uid or not pid(u.owner)
            or not Units.TYPES[u.type] or not nonnegative(u.mp) or type(u.acted) ~= "boolean"
            or type(u.garrison) ~= "boolean" or type(u.recentGarrison) ~= "boolean"
            or (u.spawnBonus ~= nil and not nonnegative(u.spawnBonus)) then return false, "đơn vị sai hình dạng" end
        maxUnit = math.max(maxUnit, uid)
    end
    for did, inst in pairs(s.derived) do
        if not isInt(did) or did < 1 or not isTable(inst) or inst.did ~= did or not pid(inst.owner)
            or not Derived.byId[inst.id] or not isInt(inst.a) or inst.a < 1 or not nonnegative(inst.timer) then
            return false, "Phái Sinh sai hình dạng"
        end
        local def = Derived.byId[inst.id]
        for _, field in ipairs({ "b", "site", "dep" }) do
            local required = (field == "b" and def.partner) or (field == "site" and def.site) or (field == "dep" and def.dep)
            if (required or inst[field] ~= nil) and (not isInt(inst[field]) or inst[field] < 1) then
                return false, "Phái Sinh sai tham chiếu " .. field
            end
        end
        maxDerived = math.max(maxDerived, did)
    end
    if s.nextUid <= maxBuilding or s.nextUnitUid <= maxUnit or s.nextDerivedUid <= maxDerived then
        return false, "bộ cấp UID có thể ghi đè đối tượng đã tồn tại"
    end
    if (s.phase == "over") ~= (s.round == s.rounds + 1) then return false, "phase không khớp vòng kết thúc" end
    for _, name in ipairs({ "history", "log" }) do
        if not array(s[name]) then return false, name .. " không phải danh sách" end
        for _, item in ipairs(s[name]) do
            if not isTable(item) or type(item[name == "history" and "type" or "kind"]) ~= "string" then
                return false, name .. " có mục sai kiểu"
            end
        end
    end

    for _, k in ipairs({ "rebel", "dice", "prompt" }) do
        if s[k] ~= false and not isTable(s[k]) then return false, k .. " phải là bảng hoặc false" end
    end
    if s.rebel and not coordinate(s.rebel) then return false, "rebel thiếu vị trí" end
    if s.dice and (not array(s.dice) or #s.dice ~= 2 or not isInt(s.dice[1]) or not isInt(s.dice[2])
        or s.dice[1] < 1 or s.dice[1] > 6 or s.dice[2] < 1 or s.dice[2] > 6) then return false, "xúc xắc không hợp lệ" end
    if s.phase == "prompt" then
        local pr = s.prompt
        if not (pr and type(pr.kind) == "string" and isTable(pr.options) and isInt(pr.pid) and pr.pid >= 1 and pr.pid <= n) then
            return false, "phase prompt nhưng prompt thiếu hoặc sai"
        end
    end
    if s.phase ~= "prompt" and s.prompt ~= false then return false, "prompt ngoài pha chờ trả lời" end
    if (s.phase == "rebel_move" or s.phase == "rebel_loss") and not (s.rebel and isTable(s.rebel.pending)) then
        return false, "phase " .. s.phase .. " nhưng Phiến Quân không có pending"
    end
    local pending = s.rebel and s.rebel.pending
    if s.rebel and s.rebel.suppressedRound ~= nil and not isStampOrFalse(s.rebel.suppressedRound) then
        return false, "vòng trấn áp Phiến Quân không hợp lệ"
    end
    if pending then
        if not isTable(pending) or not pid(pending.roller) or pending.roller ~= s.order[s.turn] then
            return false, "Phiến Quân sai người điều khiển"
        end
        if pending.stage == "move" then
            if s.phase ~= "rebel_move" or not isInt(pending.points) or pending.points < 1 or pending.points > 6
                or not isTable(pending.visited) then return false, "Phiến Quân sai bước di chuyển" end
            for k, v in pairs(pending.visited) do
                if not tileKey(k) or v ~= true then return false, "Phiến Quân sai ô đã đi" end
            end
        elseif pending.stage == "loss" then
            if s.phase ~= "rebel_loss" or not pid(pending.owner) or not isInt(pending.amount) or pending.amount < 1
                or not array(pending.options) or #pending.options < 2 then return false, "Phiến Quân sai lựa chọn mất tài nguyên" end
            local options = {}
            for _, k in ipairs(pending.options) do
                if not Resources.byKey[k] or not Resources.byKey[k].face or options[k] then return false, "Phiến Quân sai loại tài nguyên" end
                options[k] = true
            end
        else return false, "Phiến Quân sai stage" end
    end
    return true
end

-- Kiểm tra bất biến của state. Trả true hoặc false, mô tả lỗi.
function Invariants.check(state)
    local function exists(k)
        local q, r = State.unkey(k)
        return q ~= nil and state.map:get(q, r) ~= nil
    end
    for _, name in ipairs({ "owner", "votes", "lostStrategic" }) do
        for k in pairs(state[name]) do
            if not exists(k) then return false, name .. " chứa ô ngoài bản đồ" end
        end
    end
    if state.rebel and not state.map:get(state.rebel.q, state.rebel.r) then return false, "Phiến Quân ngoài bản đồ" end
    for pid, p in ipairs(state.players) do
        if p.hq and (not state.map:get(p.hq.q, p.hq.r) or state.owner[State.key(p.hq)] ~= pid) then
            return false, "Nhà Chính không nằm trên ô của chủ"
        end
        for _, sub in ipairs(p.subs) do
            if not state.map:get(sub.q, sub.r) then return false, "Khu Trực Thuộc ngoài bản đồ" end
        end
        for _, group in ipairs({ Resources.core, Resources.materials }) do
            for _, r in ipairs(group) do
                local v = p.res[r.key]
                if type(v) ~= "number" or v < 0 or v ~= math.floor(v) then
                    return false, string.format("P%d %s = %s", pid, r.key, tostring(v))
                end
            end
        end
        if p.votes < 0 then return false, "P" .. pid .. " có phiếu âm" end
        for res, v in pairs(p.carry) do   -- phần lẻ chưa cộng: luôn trong [0, 1) và là bội của 0.5
            if type(v) ~= "number" or v < 0 or v >= 1 or (v * 2) ~= math.floor(v * 2) then
                return false, string.format("P%d carry %s = %s", pid, res, tostring(v))
            end
        end
    end

    for k, pid in pairs(state.owner) do
        if not state.players[pid] then return false, "chủ ô " .. k .. " không hợp lệ" end
    end

    local seen = 0
    for uid, b in pairs(state.buildings) do
        if b.uid ~= uid then return false, "uid công trình lệch " .. tostring(uid) end
        local def = Buildings.level(b.id, b.level)
        if not def or #b.tiles ~= def.tiles then
            return false, string.format("công trình %d (%s C%d) có %d ô, cần %d", uid, b.id, b.level, #b.tiles,
                def and def.tiles or -1)
        end
        for i, k in ipairs(b.tiles) do
            seen = seen + 1
            if state.occupied[k] ~= uid then return false, "occupied lệch tại " .. k end
            if state.owner[k] ~= b.owner then return false, "công trình " .. k .. " không nằm trên ô của chủ" end
            local tile = state.map:get(State.unkey(k))
            if not tile then return false, "công trình ngoài bản đồ " .. k end
            -- Đặc Biệt: chỉ ô trung tâm bị ràng buộc theo danh sách địa hình (các ô còn lại xem Specials.checkBuild)
            local special = b.id:sub(1, 2) == "S-"
            if (not special or i == 1) and not Buildings.allowedOn(b.id, b.level, tile.terrain) then
                return false, "công trình " .. k .. " trên địa hình không hợp lệ " .. tile.terrain
            end
            for pid in ipairs(state.players) do
                for _, a in ipairs(Territory.anchors(state, pid)) do
                    if a.q == tile.q and a.r == tile.r then return false, "công trình đè lên HQ " .. k end
                end
            end
        end
    end
    local occ = 0
    for _ in pairs(state.occupied) do occ = occ + 1 end
    if occ ~= seen then return false, "occupied có ô thừa" end

    for k, road in pairs(state.roads) do
        local q, r = State.unkey(k)
        if not q or not state.map:get(q, r) then return false, "đường ngoài bản đồ " .. tostring(k) end
        if road.level ~= 1 and road.level ~= 2 then return false, "đường " .. k .. " có cấp " .. tostring(road.level) end
    end

    for did, inst in pairs(state.derived) do
        if inst.did ~= did or not state.players[inst.owner] then return false, "Phái Sinh " .. tostring(did) .. " không hợp lệ" end
        if not state.buildings[inst.a] then return false, "Phái Sinh " .. did .. " mất công trình chủ" end
        if inst.site and not state.buildings[inst.site] then return false, "Phái Sinh " .. did .. " mất ô riêng" end
    end
    for pid, p in ipairs(state.players) do
        if p.res.bond > C.BOND_MAX then return false, "P" .. pid .. " vượt " .. C.BOND_MAX .. " Tín Phiếu" end
    end

    local perQuota = {}
    for uid, u in pairs(state.units) do
        if u.uid ~= uid then return false, "uid đơn vị lệch " .. tostring(uid) end
        if not state.players[u.owner] then return false, "đơn vị " .. uid .. " có chủ không hợp lệ" end
        if not state.map:get(u.q, u.r) then return false, "đơn vị " .. uid .. " ngoài bản đồ" end
        if type(u.mp) ~= "number" or u.mp < 0 then return false, "đơn vị " .. uid .. " có mp " .. tostring(u.mp) end
        local def = Units.TYPES[u.type]
        if not def then return false, "loại đơn vị lạ " .. tostring(u.type) end
        local k = u.owner .. ":" .. def.quota
        perQuota[k] = (perQuota[k] or 0) + 1
        if perQuota[k] > Units.quotaMax(def.quota) then return false, "vượt quota đơn vị của P" .. u.owner end
    end

    -- ô không phải HQ/Sub chỉ có chủ khi chủ đủ phiếu theo ngưỡng
    for k, pid in pairs(state.owner) do
        local tile = state.map:get(State.unkey(k))
        if not Territory.isAnchorTile(state, tile) then
            local have = Territory.votesOn(state, tile, pid)
            local need = Territory.threshold(state, pid, tile)
            if have < need then
                return false, string.format("ô %s của P%d có %d phiếu < ngưỡng %d", k, pid, have, need)
            end
        end
    end

    for k, round in pairs(state.plundered) do
        if type(k) ~= "string" or not isInt(round) or round < 1 or round > state.round then
            return false, "bảng cướp phá không hợp lệ tại " .. tostring(k)
        end
    end
    for pid, p in ipairs(state.players) do
        if p.expelReady and p.harass <= C.REBEL_HARASS_BEFORE_EXPEL then return false, "P" .. pid .. " có Lệnh Đuổi sớm" end
    end
    if state.rebel then
        for pid, p in ipairs(state.players) do
            if p.hq and p.hq.q == state.rebel.q and p.hq.r == state.rebel.r then
                return false, "Phiến Quân đứng trên ô HQ của P" .. pid
            end
        end
    end
    if state.phase == "over" and state.round ~= state.rounds + 1 then return false, "ván kết thúc sai vòng " .. state.round end
    return true
end

return Invariants
