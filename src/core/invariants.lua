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

local Invariants = {}

Invariants.PHASES = { setup_hq = true, roll = true, rebel_move = true, rebel_loss = true, prompt = true,
                      action = true, over = true }

local function isInt(v) return type(v) == "number" and v == math.floor(v) end
local function isTable(v) return type(v) == "table" end
local function isStampOrFalse(v) return v == false or isInt(v) end

-- Mỗi trường: tên, kiểm tra kiểu. Danh sách này đi cùng State.new (src/core/state.lua).
local STATE_TABLES = { "owner", "votes", "buildings", "occupied", "lostStrategic", "units", "roads", "derived",
                       "log", "history", "takenStarts", "order", "players", "rng" }
local STATE_INTS   = { "nextUid", "nextUnitUid", "nextDerivedUid", "round", "turn", "setupIdx", "playerCount" }

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
    if n < 1 or n > 4 or #s.players ~= n then return false, "số người chơi không hợp lệ" end
    if s.round < 1 or s.round > C.ROUNDS_PER_GAME + 1 then return false, "vòng ngoài khoảng" end
    if s.turn < 1 or s.turn > n then return false, "lượt ngoài khoảng" end
    if s.setupIdx < 1 or s.setupIdx > n + 1 then return false, "setupIdx ngoài khoảng" end
    if not Invariants.PHASES[s.phase] then return false, "phase lạ: " .. tostring(s.phase) end
    if #s.order ~= n then return false, "order sai độ dài" end
    local seen = {}
    for _, pid in ipairs(s.order) do
        if not isInt(pid) or pid < 1 or pid > n or seen[pid] then return false, "order không phải hoán vị" end
        seen[pid] = true
    end
    if type(s.rng.state) ~= "number" then return false, "rng.state sai kiểu" end
    if type(s.rng.base) ~= "string" and type(s.rng.base) ~= "number" then return false, "rng.base sai kiểu" end

    for pid = 1, n do
        local p = s.players[pid]
        if not isTable(p) or p.id ~= pid then return false, "người chơi " .. pid .. " sai kiểu" end
        if not (isTable(p.res) and isTable(p.subs) and isTable(p.carry)) then return false, "P" .. pid .. " thiếu res/subs/carry" end
        if type(p.votes) ~= "number" or not isInt(p.hqLevel) then return false, "P" .. pid .. " sai votes/hqLevel" end
        if p.hq ~= false and not (isTable(p.hq) and isInt(p.hq.q) and isInt(p.hq.r)) then return false, "P" .. pid .. " sai hq" end
        for _, k in ipairs({ "strikeRound", "broadcastRound", "knightRetreatRound" }) do
            if not isStampOrFalse(p[k]) then return false, "P" .. pid .. " sai " .. k end
        end
        if not isInt(p.cancel7Used) then return false, "P" .. pid .. " sai cancel7Used" end
    end

    for _, k in ipairs({ "rebel", "dice", "prompt" }) do
        if s[k] ~= false and not isTable(s[k]) then return false, k .. " phải là bảng hoặc false" end
    end
    if s.rebel and not (type(s.rebel.q) == "number" and type(s.rebel.r) == "number") then return false, "rebel thiếu vị trí" end
    if s.phase == "prompt" then
        local pr = s.prompt
        if not (pr and type(pr.kind) == "string" and isTable(pr.options) and isInt(pr.pid) and pr.pid >= 1 and pr.pid <= n) then
            return false, "phase prompt nhưng prompt thiếu hoặc sai"
        end
    end
    if (s.phase == "rebel_move" or s.phase == "rebel_loss") and not (s.rebel and isTable(s.rebel.pending)) then
        return false, "phase " .. s.phase .. " nhưng Phiến Quân không có pending"
    end
    return true
end

-- Kiểm tra bất biến của state. Trả true hoặc false, mô tả lỗi.
function Invariants.check(state)
    for pid, p in ipairs(state.players) do
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
            -- D-020: ô chiếm nhờ TN-06 rồi mất TN (dỡ công trình) vẫn thuộc chủ: xét theo ngưỡng lúc TN-06 còn
            if state.lostStrategic[k] then need = Territory.thresholdAtClaim(state, pid, tile) end
            if have < need then
                return false, string.format("ô %s của P%d có %d phiếu < ngưỡng %d", k, pid, have, need)
            end
        end
    end

    if state.phase == "over" and state.round ~= C.ROUNDS_PER_GAME + 1 then
        return false, "ván kết thúc sai vòng " .. state.round
    end
    return true
end

return Invariants
