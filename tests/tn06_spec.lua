-- D-020: ô chiếm nhờ TN-06 (ngưỡng giảm) vẫn thuộc chủ sau khi TN mất; bất biến chỉ nới đúng ca đó.

local Game       = require("src.core.game")
local Hex        = require("src.core.hex")
local Invariants = require("src.core.invariants")
local State      = require("src.core.state")
local Structures = require("src.core.structures")
local Territory  = require("src.core.territory")
local Upkeep     = require("src.core.upkeep")

local key = State.key

-- Ván đang ở pha action; HQ C2 (vùng ảnh hưởng bán kính 2). Trả state, pid, một ô cách HQ đúng 2 bước
-- (không cụm, chưa có chủ). Seed 30 có sẵn một ô TN-06 Đồng Bằng đúng vị trí đó; bản đồ không được lưu mà dựng
-- lại từ seed (D-011), nên ca save/load phải dùng ô TN-06 thật của bản đồ. `strategic` khác: ghi đè TN trên ô đó.
local function setup(strategic)
    local s = Game.new({ seed = 30, players = 2 })
    while s.phase == "setup_hq" do Game.apply(s, Game.legal(s)[1]) end
    s.phase = "action"
    s.rebel = { q = -99, r = -99 }
    local pid = Game.actor(s)
    local p = s.players[pid]
    p.hqLevel, p.votes = 2, 5
    for k in pairs(p.res) do p.res[k] = (k == "bond") and 0 or 99 end
    for _, t in ipairs(s.map.list) do
        if Hex.distance(p.hq, t) == 2 and t.strategic == "TN-06" and not t.settlement and not t.landmark and not s.owner[key(t)]
            and not Territory.isAnchorTile(s, t) then
            t.strategic = strategic
            return s, pid, t
        end
    end
    error("không có ô cách HQ 2 bước")
end

-- Chiếm `t` bằng 1 phiếu (ngưỡng giảm), xây B-01, dỡ, hoàn tất dỡ.
local function claimBuildDemolish(s, pid, t)
    Game.apply(s, { type = "placeVote", q = t.q, r = t.r })
    expect.eq(s.owner[key(t)], pid, "chiếm được bằng 1 phiếu")
    Game.apply(s, { type = "build", id = "B-01", q = t.q, r = t.r })
    local b = Structures.at(s, t)
    expect.truthy(b)
    Game.apply(s, { type = "demolish", uid = b.uid })
    Upkeep.startTurn(s, pid)
    expect.eq(Structures.at(s, t), nil)
end

describe("D-020: ô chiếm nhờ TN-06", function()
    it("mất TN-06 sau khi dỡ: chủ giữ ô, bất biến qua, save/load nạp được", function()
        local s, pid, t = setup("TN-06")
        expect.eq(Territory.threshold(s, pid, t), 1)
        claimBuildDemolish(s, pid, t)
        expect.truthy(s.lostStrategic[key(t)])
        expect.eq(Territory.threshold(s, pid, t), 2, "ngưỡng hiện hành đã tăng lại")
        expect.eq(s.owner[key(t)], pid, "chủ vẫn giữ ô")
        expect.eq(Territory.votesOn(s, t, pid), 1)
        local ok, why = Invariants.check(s)
        expect.truthy(ok, why)
        local loaded, err = Game.load(Game.save(s))
        expect.truthy(loaded, err)
        expect.eq(loaded.owner[key(t)], pid)
    end)

    it("phản ví dụ: ô không từng có TN-06 mà thiếu phiếu vẫn bị báo", function()
        local s, pid, t = setup(nil)
        s.owner[key(t)], s.votes[key(t)] = pid, { [pid] = 1 }
        local ok, why = Invariants.check(s)
        expect.falsy(ok)
        expect.truthy(why:find("phiếu", 1, true))
    end)

    it("phản ví dụ: ô mất TN khác (không phải TN-06) mà thiếu phiếu vẫn bị báo", function()
        local s, pid, t = setup("TN-05")
        s.owner[key(t)], s.votes[key(t)] = pid, { [pid] = 1 }
        s.lostStrategic[key(t)] = true
        expect.falsy(Invariants.check(s))
    end)

    it("ô còn nguyên TN-06 mà 0 phiếu vẫn bị báo", function()
        local s, pid, t = setup("TN-06")
        s.owner[key(t)], s.votes[key(t)] = pid, {}
        expect.falsy(Invariants.check(s))
    end)

    it("ô từng có TN-06 mà phiếu thấp hơn cả ngưỡng giảm vẫn bị báo", function()
        local s, pid, t = setup("TN-06")
        s.owner[key(t)], s.votes[key(t)] = pid, {}
        s.lostStrategic[key(t)] = true
        expect.falsy(Invariants.check(s))
    end)
end)
