-- Tween có easing (skill game-feel): mọi chuyển động UI đi qua đây, không dùng tuyến tính.
-- Dùng: local tw = Tween.new(); tw:to(obj, "scale", 1, 0.2, "outBack"); mỗi frame tw:update(dt).

local Tween = {}
Tween.__index = Tween

-- Các hàm easing nhận t in [0,1] -> [0,1] (outBack có thể vượt 1 một chút để "nảy").
Tween.ease = {
    linear   = function(t) return t end,
    outQuad  = function(t) return 1 - (1 - t) * (1 - t) end,
    outCubic = function(t) return 1 - (1 - t) ^ 3 end,
    inOutQuad = function(t) return t < 0.5 and 2 * t * t or 1 - (-2 * t + 2) ^ 2 / 2 end,
    outBack  = function(t)
        local c1, c3 = 1.70158, 2.70158
        return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
    end,
}

function Tween.new()
    return setmetatable({ list = {} }, Tween)
end

-- Đưa obj[key] tới `target` trong `duration` giây. Tween mới trên cùng (obj,key) thay tween cũ.
function Tween:to(obj, key, target, duration, easing, onDone)
    for i = #self.list, 1, -1 do
        local t = self.list[i]
        if t.obj == obj and t.key == key then table.remove(self.list, i) end
    end
    if duration <= 0 then
        obj[key] = target
        if onDone then onDone() end
        return
    end
    self.list[#self.list + 1] = {
        obj = obj, key = key, from = obj[key], to = target, t = 0, d = duration,
        ease = Tween.ease[easing or "outQuad"], onDone = onDone,
    }
end

-- Chạy `fn` sau `delay` giây.
function Tween:after(delay, fn)
    local dummy = { v = 0 }
    self:to(dummy, "v", 1, delay, "linear", fn)
end

function Tween:update(dt)
    for i = #self.list, 1, -1 do
        local t = self.list[i]
        t.t = math.min(t.d, t.t + dt)
        t.obj[t.key] = t.from + (t.to - t.from) * t.ease(t.t / t.d)
        if t.t >= t.d then
            table.remove(self.list, i)
            if t.onDone then t.onDone() end
        end
    end
end

function Tween:busy() return #self.list > 0 end

return Tween
