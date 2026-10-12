-- Khứ hồi save cho thế cờ dựng tay (tests/arena.lua, tests/strip.lua): các thế đó sửa địa hình và đặt công trình sai luật,
-- nên Game.load (kiểm tra bất biến, sinh lại bản đồ từ seed) sẽ từ chối. Hàm này chỉ chạy Game.save -> Serialize.load,
-- giữ nguyên bản đồ đã sửa và bỏ qua kiểm tra; dùng khi test chỉ cần thấy dữ liệu sống qua serialize.
local Game      = require("src.core.game")
local Serialize = require("src.core.serialize")
local State     = require("src.core.state")

return function(s)
    local state = assert(Serialize.load(Game.save(s))).state
    state.map = s.map
    return State.restoreRng(state)
end
