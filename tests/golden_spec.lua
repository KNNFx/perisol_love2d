-- Golden: hash state cuối ván của bộ seed mốc phải khớp fixture (tests/fixtures/golden_hashes.lua).
-- Đổi luật/bot làm lệch hash là chủ ý phải thấy: sinh lại bằng `make hash-write` và ghi lý do.
local Hash = require("tools.hash")

describe("golden: hash state cuối ván", function()
    it("15 ván mốc khớp fixture", function()
        local want = require("tests.fixtures.golden_hashes")
        local got = Hash.compute()
        for _, c in ipairs(Hash.cases()) do
            local n = Hash.name(c)
            expect.eq(got[n], want[n], n)
        end
    end)
end)
