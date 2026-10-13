-- D-021: thứ tự việc đầu lượt (src/core/upkeep.lua): hoàn tất dỡ -> thu nhập thụ động -> upkeep đơn vị.
-- Mọi ca đi qua lệnh thật: lượt của người kia trôi qua bằng endTurn, việc đầu lượt chạy trong `roll` của chủ.

local Game       = require("src.core.game")
local Roads      = require("src.core.roads")
local Structures = require("src.core.structures")
local Units      = require("src.core.units")
local arena      = require("tests.arena")

-- Kết thúc lượt `pid` rồi cho các lượt khác trôi qua (lệnh đầu tiên của Game.legal, ưu tiên endTurn) tới lúc `pid` sắp đổ xúc xắc.
local function passToRoll(s, pid)
    Game.apply(s, { type = "endTurn" })
    local guard = 0
    while not (s.phase == "roll" and Game.actor(s) == pid) do
        guard = guard + 1
        assert(guard < 200, "lượt không quay lại người chơi " .. pid)
        local legal = Game.legal(s)
        local pick = legal[1]
        for _, c in ipairs(legal) do if c.type == "endTurn" then pick = c break end end
        Game.apply(s, pick)
    end
end

local function has(events, pred)
    for _, e in ipairs(events) do if pred(e) then return true end end
    return false
end

describe("D-021: thứ tự việc đầu lượt", function()
    it("thu nhập thụ động đầu lượt (Khu Chợ C2 + 2 đường = 1 Vàng) trả được upkeep: đơn vị không bị mất", function()
        local s, pid, c = arena()
        passToRoll(s, pid)
        Structures.place(s, { id = "B-05", level = 2, owner = pid }, { c, s.map:get(c.q + 1, c.r) })
        Roads.build(s, s.map:get(c.q - 1, c.r)); Roads.build(s, s.map:get(c.q + 2, c.r))
        for i = 0, 1 do Units.spawn(s, pid, "expedition", s.map:get(c.q + i, c.r + 1)) end
        s.players[pid].res.gold = 0          -- 2 đơn vị -> upkeep 1 Vàng; chỉ thu nhập thụ động của lượt này mới trả được
        local ev = Game.apply(s, { type = "roll" })
        expect.eq(#Units.ownedBy(s, pid), 2)
        expect.falsy(has(ev, function(e) return e.kind == "unit_destroyed" end))
        expect.truthy(has(ev, function(e) return e.kind == "unit_upkeep" and e.gold == 1 end))
    end)

    it("công trình dỡ xong đầu lượt thì TN trên ô mất ngay, thu nhập thụ động của chính lượt đó không còn tính nó", function()
        local function turnEvents(demolish)
            local s, pid, c = arena()
            c.strategic = "TN-02"             -- TN-02 trên ô của chủ: +1 Tín Ngưỡng +1 Khoa Học thụ động
            Game.apply(s, { type = "build", id = "B-01", q = c.q, r = c.r })
            if demolish then Game.apply(s, { type = "demolish", uid = Structures.at(s, c).uid }) end
            passToRoll(s, pid)
            local ev = Game.apply(s, { type = "roll" })
            c.strategic = nil
            return ev
        end
        local function tn02Income(ev) return has(ev, function(e) return e.kind == "passive" and e.src == "TN-02" end) end

        local control = turnEvents(false)
        expect.truthy(tn02Income(control), "không dỡ thì TN-02 phải cho thu nhập (ca đối chứng)")
        local ev = turnEvents(true)
        expect.truthy(has(ev, function(e) return e.kind == "demolished" end))
        expect.truthy(has(ev, function(e) return e.kind == "strategic_lost" and e.tn == "TN-02" end))
        expect.falsy(tn02Income(ev), "TN-02 đã mất lúc dỡ xong thì lượt này không còn thu nhập từ nó")
    end)
end)
