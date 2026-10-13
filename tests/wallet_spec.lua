local C      = require("src.config.constants")
local Sim    = require("src.core.sim")
local Wallet = require("src.core.wallet")
local Resources = require("src.data.resources")

local function allKeys()
    local keys = {}
    for _, group in ipairs({ Resources.core, Resources.materials }) do
        for _, r in ipairs(group) do keys[#keys + 1] = r.key end
    end
    return keys
end

describe("tài nguyên: không nợ, Tín Phiếu có trần", function()
    it("gain kẹp Tín Phiếu ở trần, loại khác không bị kẹp", function()
        local res = { bond = C.BOND_MAX - 1, gold = 100 }
        Wallet.gain(res, "bond", 3)
        expect.eq(res.bond, C.BOND_MAX)
        Wallet.gain(res, "gold", 50)
        expect.eq(res.gold, 150)
        local fresh = {}
        Wallet.gain(fresh, "culture", 2)
        expect.eq(fresh.culture, 2)
    end)

    it("sau MỖI lệnh của 10 ván sim (9 thường + 1 rich) không tài nguyên nào âm/lẻ và Tín Phiếu <= trần", function()
        local keys, cmds = allKeys(), 0
        for i = 1, 10 do
            local rich = i > 9   -- ván rich chậm (~6 giây); quét rộng hơn thuộc về make sweep RICH=1
            local players = 2 + i % 3
            Sim.play((rich and 920 or 900) + i, players, { rich = rich, onCommand = function(state, cmd)
                cmds = cmds + 1
                for pid, p in ipairs(state.players) do
                    for _, k in ipairs(keys) do
                        local v = p.res[k]
                        if type(v) ~= "number" or v < 0 or v ~= math.floor(v) then
                            error(string.format("ván %d (%s) sau %s: P%d %s = %s", i, rich and "rich" or "thường",
                                cmd.type, pid, k, tostring(v)))
                        end
                    end
                    if p.res.bond > C.BOND_MAX then
                        error(string.format("ván %d sau %s: P%d bond = %d > trần", i, cmd.type, pid, p.res.bond))
                    end
                end
            end })
        end
        expect.truthy(cmds > 1000, "phải kiểm tra nhiều lệnh, có " .. cmds)
    end)
end)
