-- Scene chơi M1 (hot-seat). Chỉ đọc state và gửi lệnh qua Game.check/Game.apply (D-011);
-- mọi luật nằm trong src/core. File này lo bố cục HUD, nhập liệu và phản hồi (game feel).
--
-- Mở bằng manager.switch(scene, { seed = N, players = N }) hoặc { state = <state đã nạp> }.

local C           = require("src.config.constants")
local Cli         = require("src.cli")
local Game        = require("src.core.game")
local Territory   = require("src.core.territory")
local Rebel       = require("src.core.rebel")
local Scoring     = require("src.core.scoring")
local Sim         = require("src.core.sim")
local Save        = require("src.save")
local Buildings   = require("src.data.buildings")
local Resources   = require("src.data.resources")
local Terrains    = require("src.data.terrains")
local Strategic   = require("src.data.strategic")
local Camera      = require("src.render.camera")
local Tileset     = require("src.render.tileset")
local MapRenderer = require("src.render.map_renderer")
local Layers      = require("src.render.game_layers")
local Theme       = require("src.ui.theme")
local UI          = require("src.ui.widgets")
local Tween       = require("src.ui.tween")
local Fmt         = require("src.ui.log_format")
local Actions     = require("src.input.actions")
local manager     = require("src.scenes.manager")

local Scene = {}

local PHASE_NAME = {
    setup_hq = "Đặt Nhà Chính", roll = "Sản xuất", rebel_move = "Phiến Quân",
    rebel_loss = "Phiến Quân", action = "Hành động", over = "Kết thúc",
}
local FACE_COLOR_HEX = { 0.45, 0.47, 0.52 }
local LOG_MAX = 200
local QUICKSAVE = "quick"

-- ─── Tiện ích ───────────────────────────────────────────────────────────────

local function costText(cost)
    local parts = {}
    for _, r in ipairs(Resources.core) do
        local n = cost[r.key]
        if n then parts[#parts + 1] = n .. " " .. r.abbr end
    end
    return table.concat(parts, " + ")
end

local function buildTip(b)
    local lv = b.levels[1]
    local prod = {}
    for _, p in ipairs(lv.produces) do
        prod[#prod + 1] = string.format("+%d %s khi ra %s", p[3], Fmt.res(p[2]), Fmt.face(p[1]))
    end
    local names = {}
    for _, t in ipairs(Terrains.list) do
        if lv.terrains[t.id] then names[#names + 1] = t.name end
    end
    return string.format("%s (cấp 1)\nChi phí: %s\nSản xuất: %s\nĐịa hình: %s",
        b.name, costText(lv.cost), table.concat(prod, ", "), table.concat(names, ", "))
end

local function canAfford(res, cost)
    for k, n in pairs(cost) do
        if (res[k] or 0) < n then return false end
    end
    return true
end

-- ─── Vòng đời ───────────────────────────────────────────────────────────────

function Scene:enter(opts)
    opts = opts or {}
    self.state = opts.state or Game.new({ seed = opts.seed or os.time() % 1000000, players = opts.players or 2 })
    -- dev: `--play N` tự chơi N lệnh ngẫu nhiên để dựng thế cờ cho ảnh chụp màn hình
    local play = tonumber(Cli.option("--play"))
    if play and not opts.state then Sim.advance(self.state, play) end
    local demo = Cli.option("--demo")           -- dev: thế cờ dựng sẵn (src/dev/demo.lua)
    if demo and not opts.state then require("src.dev.demo").apply(self.state, demo) end
    local untilPhase = Cli.option("--until")   -- dev: tự chơi từng lệnh tới khi vào pha này
    if untilPhase and not opts.state then
        for _ = 1, 3000 do
            if self.state.phase == untilPhase then break end
            Sim.advance(self.state, 1)
        end
    end

    self.tileset = Tileset.load()
    self.camera = Camera.new()
    self.ui = UI.new()
    self.tween = Tween.new()
    self.mode, self.popup = nil, nil
    self.trade = {}
    self.rollAnim = nil
    self.dieScale = { 1, 1 }
    self.pop, self.pulses, self.logLines = {}, {}, {}
    self.trauma, self.flash, self.time = 0, { a = 0 }, 0
    self.toast = nil
    self.reduceMotion, self.debug, self.showZones = false, false, false
    self.hover = nil

    Theme.update(love.graphics.getDimensions())
    self:updateCameraMargin()
    local w, h = MapRenderer.worldSize(self.state.map)
    self.camera:setWorld(w, h)
    self.camera:fit(love.graphics.getWidth())
    self:rebuildLog()
end

-- Lề camera đủ rộng để kéo bất kỳ ô nào (kể cả ô sát mép bản đồ) ra khỏi vùng bị panel HUD che.
function Scene:updateCameraMargin()
    self.camera.margin = Theme.px(260) / self.camera.zoom
end

function Scene:rebuildLog()
    self.logLines = {}
    for _, e in ipairs(self.state.log) do self:pushLog(e) end
end

function Scene:pushLog(e)
    local line = Fmt.line(e)
    if not line then return end
    line.round = e.round
    self.logLines[#self.logLines + 1] = line
    if #self.logLines > LOG_MAX then table.remove(self.logLines, 1) end
end

-- ─── Lệnh và phản hồi ───────────────────────────────────────────────────────

function Scene:say(text)
    self.toast = { text = text, a = 1, t = 2.4 }
end

function Scene:addTrauma(amount)
    self.trauma = math.min(1, self.trauma + amount)
end

function Scene:pulseAt(q, r)
    local t = self.state.map:get(q, r)
    if t then self.pulses[#self.pulses + 1] = { tile = t, t = 0, d = 0.7 } end
end

-- Số vừa đổi "nảy" lên rồi về cỡ thường.
function Scene:popValue(pid, res)
    local k = pid .. res
    self.pop[k] = 1.6
    self.tween:to(self.pop, k, 1, 0.4, "outBack")
end

-- Di chuyển camera mượt tới một ô.
function Scene:focusTile(t)
    if not t then return end
    local x, y = MapRenderer.tileCenter(t)
    self.tween:to(self.camera, "x", x, 0.45, "outCubic")
    self.tween:to(self.camera, "y", y, 0.45, "outCubic")
end

function Scene:onEvents(events)
    local state = self.state
    for _, e in ipairs(events) do
        self:pushLog(e)
        local k = e.kind
        if k == "produce" then
            self:popValue(e.pid, e.res)
        elseif k == "votes" then
            self:popValue(e.pid, "votes")
        elseif k == "seven" then
            self:addTrauma(0.7)
            self.flash.a = 0.45
            self.tween:to(self.flash, "a", 0, 0.7, "outQuad")
            self:say("Tổng 7! Phiến Quân hành động")
        elseif k == "rebel_roll" then
            local rb = state.rebel
            self:focusTile(state.map:get(rb.q, rb.r))
        elseif k == "rebel_stop" then
            self:addTrauma(0.35)
            self:pulseAt(e.q, e.r)
        elseif k == "rebel_loss" then
            self:addTrauma(0.3)
            self:popValue(e.victim, e.res)
            self:popValue(e.roller, e.res)
        elseif k == "claim" or k == "build" or k == "place_hq" or k == "found_sub" or k == "upgrade_hq" then
            self:pulseAt(e.q, e.r)
        elseif k == "end_turn" then
            local nextActor = Game.actor(state)
            if nextActor and state.players[nextActor].hq then
                local hq = state.players[nextActor].hq
                self:focusTile(state.map:get(hq.q, hq.r))
            end
        elseif k == "game_over" then
            self.tween:after(0.9, function()
                manager.switch(require("src.scenes.results"), state)
            end)
        end
    end
end

-- Gửi lệnh qua Game; báo lý do bằng toast nếu bị từ chối. Trả true nếu thành công.
function Scene:cmd(c)
    local ok, why = Game.check(self.state, c)
    if not ok then self:say(why or "Không thực hiện được") return false end
    self:onEvents(Game.apply(self.state, c))
    return true
end

function Scene:startRoll()
    if self.state.phase ~= "roll" or self.rollAnim or self.popup then return end
    self.rollAnim = { t = 0, d = 0.8, swap = 0, faces = { 1, 1 } }
end

function Scene:finishRoll()
    self.rollAnim = nil
    if self:cmd({ type = "roll" }) then
        for i = 1, 2 do
            self.dieScale[i] = 1.4
            self.tween:to(self.dieScale, i, 1, 0.4, "outBack")
        end
    end
end

function Scene:quicksave()
    local ok, err = Save.write(QUICKSAVE, self.state)
    self:say(ok and "Đã lưu nhanh" or ("Lưu thất bại: " .. tostring(err)))
end

function Scene:quickload()
    local st, err, usedBackup = Save.read(QUICKSAVE)
    if not st then self:say("Không nạp được: " .. tostring(err)) return end
    self.state = st
    self.mode, self.popup, self.rollAnim = nil, nil, nil
    self:rebuildLog()
    self:say(usedBackup and "Đã nạp từ bản sao lưu" or "Đã nạp bản lưu nhanh")
end

-- ─── Update ─────────────────────────────────────────────────────────────────

function Scene:update(dt)
    self.time = self.time + dt
    self.tween:update(dt)
    self:updateCameraMargin()
    if self.tween:busy() then self.camera:clamp() end

    if not self.popup then self.camera:update(dt) end
    self.trauma = math.max(0, self.trauma - 1.4 * dt)

    if self.rollAnim then
        local a = self.rollAnim
        a.t = a.t + dt
        a.swap = a.swap - dt
        if a.swap <= 0 then
            a.faces = { love.math.random(6), love.math.random(6) }   -- chỉ để trang trí, không dùng RNG của ván
            a.swap = 0.07
        end
        if a.t >= a.d then self:finishRoll() end
    end

    for i = #self.pulses, 1, -1 do
        local p = self.pulses[i]
        p.t = p.t + dt
        if p.t >= p.d then table.remove(self.pulses, i) end
    end
    if self.toast then
        self.toast.t = self.toast.t - dt
        self.toast.a = math.max(0, math.min(1, self.toast.t / 0.6))
        if self.toast.t <= 0 then self.toast = nil end
    end

    local mx, my = love.mouse.getPosition()
    if self.popup or self.ui:isOver(mx, my) then
        self.hover = nil
    else
        local wx, wy = self.camera:screenToWorld(mx, my)
        self.hover = MapRenderer.tileAt(self.state.map, wx, wy)
    end
end

-- ─── Vẽ bản đồ ──────────────────────────────────────────────────────────────

-- Danh sách ô cần tô sáng theo chế độ hiện tại, và hàm đánh giá ô đang hover.
function Scene:computeTargets()
    local state, items = self.state, {}
    local actor = Game.actor(state)
    local ghostCheck

    if state.phase == "rebel_move" then
        for _, t in ipairs(Rebel.legalSteps(state)) do
            items[#items + 1] = { tile = t, color = { 1, 0.45, 0.35 }, alpha = 0.3 }
        end
        ghostCheck = function(t) return Game.check(state, { type = "rebelStep", q = t.q, r = t.r }) end
    elseif state.phase == "action" and self.mode and self.mode.kind == "build" then
        local id = self.mode.id
        for _, t in ipairs(Territory.ownedTiles(state, actor)) do
            if Game.buildCheck(state, actor, id, t) then
                items[#items + 1] = { tile = t, color = { 0.35, 0.9, 0.5 }, alpha = 0.3 }
            end
        end
        ghostCheck = function(t) return Game.buildCheck(state, actor, id, t) end
    elseif state.phase == "action" and self.mode and self.mode.kind == "vote" then
        for _, t in ipairs(Territory.voteTargets(state, actor)) do
            items[#items + 1] = { tile = t, color = { 0.4, 0.8, 1 }, alpha = 0.25 }
        end
        ghostCheck = function(t) return Territory.canVote(state, actor, t) end
    elseif state.phase == "action" and self.mode and self.mode.kind == "buy" then
        for _, t in ipairs(Territory.buyTargets(state, actor)) do
            items[#items + 1] = { tile = t, color = { 1, 0.85, 0.3 }, alpha = 0.25 }
        end
        ghostCheck = function(t) return Game.check(state, { type = "buyTile", q = t.q, r = t.r }) end
    elseif state.phase == "action" and self.mode and self.mode.kind == "sub" then
        for _, t in ipairs(Territory.ownedTiles(state, actor)) do
            if Territory.canFoundSub(state, actor, t) then
                items[#items + 1] = { tile = t, color = { 0.9, 0.5, 1 }, alpha = 0.3 }
            end
        end
        ghostCheck = function(t) return Game.check(state, { type = "foundSub", q = t.q, r = t.r }) end
    end
    return items, ghostCheck
end

function Scene:drawMap()
    local state, zoom = self.state, self.camera.zoom
    local W, H = love.graphics.getDimensions()

    love.graphics.push()
    if self.trauma > 0 and not self.reduceMotion then
        local shake = self.trauma * self.trauma * Theme.px(10)
        love.graphics.translate(math.sin(self.time * 53) * shake, math.cos(self.time * 61) * shake)
    end
    self.camera:attach()

    MapRenderer.drawTerrain(state.map, { tileset = self.tileset })
    Layers.drawInfluence(state, { zoom = zoom })
    Layers.drawTerritory(state, {
        zoom = zoom,
        thresholdFn = function(tile, pid) return Territory.threshold(state, pid, tile) end,
    })
    MapRenderer.drawMarkers(state.map, { zoom = zoom, showZones = self.showZones })
    Layers.drawBuildings(state, { zoom = zoom })
    Layers.drawRebel(state, { zoom = zoom, time = self.time })

    if state.phase == "setup_hq" then
        Layers.drawStartPicks(state, zoom, self.hover and self.hover.zone)
    else
        local items, ghostCheck = self:computeTargets()
        Layers.drawHighlights(items, zoom)
        if self.hover and ghostCheck then
            local ok, why = ghostCheck(self.hover)
            MapRenderer.drawHover(self.hover, zoom, ok and { 0.35, 1, 0.5 } or { 1, 0.35, 0.3 })
            if not ok and why then self.ghostReason = why end
        elseif self.hover then
            MapRenderer.drawHover(self.hover, zoom)
        end
    end
    Layers.drawPulses(self.pulses, zoom)

    self.camera:detach()
    love.graphics.pop()

    if self.flash.a > 0 and not self.reduceMotion then
        love.graphics.setColor(0.8, 0.1, 0.1, self.flash.a)
        love.graphics.rectangle("fill", 0, 0, W, H)
    end
    love.graphics.setColor(1, 1, 1)
end

-- ─── Vẽ HUD ─────────────────────────────────────────────────────────────────

function Scene:hintText()
    local state = self.state
    local actor = Game.actor(state)
    local who = actor and Theme.playerName(actor) or ""
    local ph = state.phase
    if ph == "setup_hq" then
        return who .. ": chọn một vùng khởi đầu (vòng có số) để đặt Nhà Chính"
    elseif ph == "roll" then
        return string.format("%s: bấm Đổ xúc xắc (%s)", who, Actions.label("roll"))
    elseif ph == "rebel_move" then
        return string.format("%s điều khiển Phiến Quân: còn %d điểm — bấm một ô sáng (không thể hoàn tác)",
            who, state.rebel.pending.points)
    elseif ph == "rebel_loss" then
        return who .. " chọn loại tài nguyên bị mất"
    elseif ph == "action" then
        if self.mode and self.mode.kind == "build" then
            return "Chọn ô để xây " .. Buildings.byId[self.mode.id].name .. " (Esc để hủy)"
        elseif self.mode and self.mode.kind == "vote" then
            return string.format("Chọn ô trong vùng ảnh hưởng để đặt phiếu Chi Phối — còn %d phiếu (Esc để hủy)",
                state.players[actor].votes)
        elseif self.mode and self.mode.kind == "buy" then
            return "Chọn ô sáng trong vùng ảnh hưởng để mua (di chuột để xem giá, Esc để hủy)"
        elseif self.mode and self.mode.kind == "sub" then
            return "Chọn ô thực hữu của bạn để lập Khu Trực Thuộc (Esc để hủy)"
        end
        return who .. ": chọn hành động hoặc Kết thúc lượt (" .. Actions.label("endTurn") .. ")"
    end
    return ""
end

function Scene:drawTopBar(W)
    local ui, state = self.ui, self.state
    local h = Theme.px(28)
    ui:panel(0, 0, W, h, { border = false })
    local actor = Game.actor(state)
    local f = Theme.font(12, true)
    ui:label("Perisol", Theme.px(10), (h - f:getHeight()) / 2, { font = f, color = Theme.color.accent })

    local round = math.min(state.round, C.ROUNDS_PER_GAME)
    local text = string.format("Vòng %d/%d   ·   Lượt: %s   ·   %s", round, C.ROUNDS_PER_GAME,
        actor and Theme.playerName(actor) or "-", PHASE_NAME[state.phase] or "")
    ui:label(text, 0, (h - f:getHeight()) / 2, { font = f, width = W, align = "center" })
    if actor then
        local tw = f:getWidth(text)
        local pc = Theme.player[actor]
        love.graphics.setColor(pc[1], pc[2], pc[3])
        love.graphics.circle("fill", W / 2 - tw / 2 - Theme.px(12), h / 2, Theme.px(5))
    end

    ui:button("menu", W - Theme.px(96), Theme.px(3), Theme.px(90), h - Theme.px(6), "Menu (Esc)", {
        font = Theme.font(11), onClick = function() self.popup = "pause" end,
    })
    return h
end

function Scene:drawPlayers(x, y, w)
    local ui, state = self.ui, self.state
    local cardH, gap = Theme.px(66), Theme.px(5)
    local actor = Game.actor(state)
    local scores = Scoring.score(state)
    local fb, fs, fn = Theme.font(12, true), Theme.font(9), Theme.font(13, true)

    for pid = 1, state.playerCount do
        local p = state.players[pid]
        local cy = y + (pid - 1) * (cardH + gap)
        local active = pid == actor
        ui:panel(x, cy, w, cardH, { borderColor = active and Theme.color.accent or Theme.color.panelLine })
        local pc = Theme.player[pid]
        love.graphics.setColor(pc[1], pc[2], pc[3])
        love.graphics.rectangle("fill", x, cy, Theme.px(4), cardH, 2, 2)

        local order = 0
        for i, id in ipairs(state.order) do if id == pid then order = i end end
        ui:label(Theme.playerName(pid),
            x + Theme.px(10), cy + Theme.px(3), { font = fb, color = active and Theme.color.accent or Theme.color.text })
        ui:label(active and "ĐANG LƯỢT" or ("lượt #" .. order), x, cy + Theme.px(5),
            { font = fs, color = active and Theme.color.accent or Theme.color.dim, width = w - Theme.px(6), align = "right" })

        local chipW = (w - Theme.px(14)) / 5
        for i, r in ipairs(Resources.core) do
            local cx = x + Theme.px(10) + (i - 1) * chipW
            ui:label(r.abbr, cx, cy + Theme.px(20), { font = fs, color = Theme.resource[r.key] })
            local sc = self.pop[pid .. r.key] or 1
            love.graphics.push()
            local nx, ny = cx + chipW * 0.35, cy + Theme.px(37)
            love.graphics.translate(nx, ny)
            love.graphics.scale(sc)
            love.graphics.translate(-nx, -ny)
            ui:label(tostring(p.res[r.key]), cx, cy + Theme.px(30), { font = fn })
            love.graphics.pop()
        end

        local sc = self.pop[pid .. "votes"] or 1
        local vx, vy = x + Theme.px(10), cy + Theme.px(52)
        love.graphics.push()
        love.graphics.translate(vx, vy)
        love.graphics.scale(sc)
        love.graphics.translate(-vx, -vy)
        ui:label("Phiếu " .. p.votes, vx, cy + Theme.px(48), { font = fs, color = Theme.color.good })
        love.graphics.pop()
        ui:label(string.format("Ô %d · Điểm %d", scores[pid].tileCount, scores[pid].total),
            x, cy + Theme.px(48), { font = fs, color = Theme.color.dim, width = w - Theme.px(6), align = "right" })
    end
end

function Scene:drawDie(x, y, size, face, scale)
    local color = face and face <= 5 and Theme.resource[Resources.byFace[face].key] or FACE_COLOR_HEX
    love.graphics.push()
    local cx, cy = x + size / 2, y + size / 2
    love.graphics.translate(cx, cy)
    love.graphics.scale(scale or 1)
    love.graphics.translate(-cx, -cy)
    Theme.setColor(face and color or Theme.color.buttonOff, face and 0.9 or 1)
    love.graphics.rectangle("fill", x, y, size, size, 6, 6)
    Theme.setColor(Theme.color.text)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, size - 1, size - 1, 6, 6)
    local f = Theme.font(14, true)
    love.graphics.setFont(f)
    love.graphics.setColor(0.07, 0.08, 0.1)
    love.graphics.printf(face and Fmt.face(face) or "?", x, y + (size - f:getHeight()) / 2, size, "center")
    love.graphics.pop()
end

function Scene:drawActions(x, y, w)
    local ui, state = self.ui, self.state
    local actor = Game.actor(state)
    local p = actor and state.players[actor]
    local inAction = state.phase == "action"
    local bh, gap = Theme.px(24), Theme.px(4)
    local fs = Theme.font(10)

    -- xúc xắc
    local diceH = Theme.px(88)
    ui:panel(x, y, w, diceH)
    local dsz = Theme.px(40)
    local faces = self.rollAnim and self.rollAnim.faces or state.dice or {}
    self:drawDie(x + Theme.px(12), y + Theme.px(8), dsz, faces[1], self.dieScale[1])
    self:drawDie(x + Theme.px(12) + dsz + Theme.px(10), y + Theme.px(8), dsz, faces[2], self.dieScale[2])
    if not self.rollAnim and state.dice then
        local sum = state.dice[1] + state.dice[2]
        ui:label("Tổng " .. sum, x + Theme.px(12) + 2 * dsz + Theme.px(20), y + Theme.px(18),
            { font = Theme.font(12, true), color = sum == C.SEVEN and Theme.color.bad or Theme.color.text })
    end
    local canRoll = state.phase == "roll" and not self.rollAnim and not self.popup
    ui:button("roll", x + Theme.px(8), y + diceH - Theme.px(32), w - Theme.px(16), Theme.px(26),
        "Đổ xúc xắc (" .. Actions.label("roll") .. ")", {
            enabled = canRoll, color = canRoll and { 0.25, 0.45, 0.30 } or nil,
            tip = "Hai viên xúc xắc: mặt tài nguyên sản xuất cho MỌI người chơi có công trình khớp. Mặt Hex cho người đổ phiếu Chi Phối. Tổng 7 đánh thức Phiến Quân.",
            onClick = function() self:startRoll() end,
        })
    y = y + diceH + gap

    -- xây công trình
    local buildH = Theme.px(18) + 5 * (bh + gap)
    ui:panel(x, y, w, buildH)
    ui:label("Xây công trình (cấp 1)", x + Theme.px(8), y + Theme.px(3), { font = fs, color = Theme.color.dim })
    local by = y + Theme.px(18)
    for _, b in ipairs(Buildings.list) do
        local lv = b.levels[1]
        local affordable = p and canAfford(p.res, lv.cost)
        local selected = self.mode and self.mode.kind == "build" and self.mode.id == b.id
        local tip = buildTip(b)
        if inAction and not affordable then tip = tip .. "\n(Không đủ tài nguyên)" end
        local label = b.name .. "  " .. (costText(lv.cost):gsub(" %+ ", "+"))
        ui:button("build" .. b.id, x + Theme.px(6), by, w - Theme.px(12), bh, label, {
            enabled = inAction and affordable, focused = selected, font = Theme.font(10, true), tip = tip,
            onClick = function()
                if selected then self.mode = nil else self.mode = { kind = "build", id = b.id } end
            end,
        })
        local rc = Theme.resource[b.main]
        love.graphics.setColor(rc[1], rc[2], rc[3])
        love.graphics.rectangle("fill", x + Theme.px(6), by + 2, Theme.px(3), bh - 4)
        by = by + bh + gap
    end
    y = y + buildH + gap

    -- lãnh thổ, đổi, kết thúc
    local function toggle(kind)
        self.mode = (self.mode and self.mode.kind == kind) and nil or { kind = kind }
    end
    local function isMode(kind) return self.mode and self.mode.kind == kind end

    local votes = p and p.votes or 0
    ui:button("vote", x, y, w, bh, string.format("Đặt phiếu Chi Phối (%d)", votes), {
        enabled = inAction and votes > 0, focused = isMode("vote"), font = Theme.font(11, true),
        tip = "Đặt 1 phiếu lên ô trong vùng ảnh hưởng của bạn. Ô cần 1 / 2 / 3 phiếu tùy khoảng cách tới Nhà Chính. Muốn cướp ô của người khác cần gấp đôi ngưỡng và hơn phiếu của chủ.",
        onClick = function() toggle("vote") end,
    })
    y = y + bh + gap
    local buyBase = costText(C.BUY_TILE_BASE)
    ui:button("buytile", x, y, w, bh, "Mua ô trong vùng ảnh hưởng", {
        enabled = inAction, focused = isMode("buy"), font = Theme.font(11, true),
        tip = "Mua ô chưa có chủ trong vùng ảnh hưởng bằng tài nguyên. Giá cơ bản " .. buyBase
            .. " ở ô sát mốc, gấp đôi mỗi vòng xa hơn.",
        onClick = function() toggle("buy") end,
    })
    y = y + bh + gap
    local hqLevel = p and p.hqLevel or 1
    local upgradeOk = inAction and Game.check(state, { type = "upgradeHQ" })
    local upCost = C.HQ_UPGRADE_COST[hqLevel + 1]
    ui:button("upgradehq", x, y, w, bh, upCost and ("Nâng Nhà Chính C" .. hqLevel + 1) or "Nhà Chính đã tối đa (M1)", {
        enabled = upgradeOk and true or false, font = Theme.font(11, true),
        tip = upCost and ("Nâng Nhà Chính lên cấp " .. hqLevel + 1 .. ": " .. costText(upCost)
            .. ". Mở rộng vùng ảnh hưởng thêm 1 vòng (tổng 18 ô quanh Nhà Chính).") or nil,
        onClick = function() self:cmd({ type = "upgradeHQ" }) end,
    })
    y = y + bh + gap
    local subCost = costText(C.SUB_COST)
    ui:button("foundsub", x, y, w, bh, "Lập Khu Trực Thuộc", {
        enabled = inAction and p and canAfford(p.res, C.SUB_COST), focused = isMode("sub"), font = Theme.font(11, true),
        tip = "Đặt Khu Trực Thuộc (" .. subCost .. ") lên ô thực hữu của bạn cách Nhà Chính ít nhất 2 ô và cách đối thủ ít nhất 3 ô. Mở thêm vùng ảnh hưởng quanh nó.",
        onClick = function() toggle("sub") end,
    })
    y = y + bh + gap
    ui:button("trade", x, y, w, bh, string.format("Đổi tài nguyên (%d:1)", C.BANK_TRADE_RATE), {
        enabled = inAction, font = Theme.font(11, true),
        tip = string.format("Đổi %d tài nguyên cùng loại lấy 1 loại bất kỳ với ngân hàng.", C.BANK_TRADE_RATE),
        onClick = function() self.popup, self.trade = "trade", {} end,
    })
    y = y + bh + gap
    ui:button("end", x, y, w, Theme.px(28), "Kết thúc lượt (" .. Actions.label("endTurn") .. ")", {
        enabled = inAction, color = inAction and { 0.42, 0.30, 0.18 } or nil, font = Theme.font(12, true),
        onClick = function() self.mode = nil; self:cmd({ type = "endTurn" }) end,
    })
end

function Scene:drawLog(x, y, w, h)
    local ui = self.ui
    ui:panel(x, y, w, h)
    local f = Theme.font(10)
    ui:label("Nhật ký", x + Theme.px(8), y + Theme.px(2), { font = Theme.font(10, true), color = Theme.color.dim })
    love.graphics.setFont(f)
    love.graphics.setScissor(x + 1, y + Theme.px(16), w - 2, h - Theme.px(18))
    local ty = y + h - Theme.px(4)
    local textW = w - Theme.px(16)
    for i = #self.logLines, 1, -1 do
        local line = self.logLines[i]
        local _, wrapped = f:getWrap(line.text, textW)
        ty = ty - #wrapped * f:getHeight()
        if ty < y then break end
        local c = line.pid and Theme.player[line.pid] or Theme.color.dim
        local tierAlpha = line.tier == "large" and 1 or (line.tier == "medium" and 0.92 or 0.75)
        love.graphics.setColor(c[1] * 0.6 + 0.4, c[2] * 0.6 + 0.4, c[3] * 0.6 + 0.4, tierAlpha)
        love.graphics.printf(line.text, x + Theme.px(8), ty, textW, "left")
    end
    love.graphics.setScissor()
end

function Scene:drawInfo(x, y, w, h)
    local t, state, ui = self.hover, self.state, self.ui
    if not t then return end
    local def = Terrains.byId[t.terrain]
    local parts = { string.format("(%d,%d) %s", t.q, t.r, def.name) }
    if t.strategic then parts[#parts + 1] = Strategic.byId[t.strategic].name end
    local k = t.q .. "," .. t.r
    local owner = state.owner[k]
    parts[#parts + 1] = owner and ("Chủ: P" .. owner) or "Chưa có chủ"
    local v = state.votes[k]
    if v then
        local vs = {}
        for pid = 1, state.playerCount do
            if v[pid] and v[pid] > 0 then vs[#vs + 1] = string.format("P%d:%d", pid, v[pid]) end
        end
        if #vs > 0 then parts[#parts + 1] = "Phiếu " .. table.concat(vs, " ") end
    end
    local actor = Game.actor(state)
    if actor and state.players[actor].hq and not owner then
        parts[#parts + 1] = string.format("Ngưỡng P%d: %d", actor, Territory.threshold(state, actor, t))
    end
    local b = state.buildings[k]
    if b then parts[#parts + 1] = Buildings.byId[b.id].name .. " C" .. b.level end
    if state.rebel and Rebel.isBlockaded(state, t) then parts[#parts + 1] = "BỊ PHONG TỎA" end
    ui:panel(x, y, w, h)
    ui:label(table.concat(parts, "  ·  "), x + Theme.px(8), y + (h - Theme.font(11):getHeight()) / 2, { font = Theme.font(11) })
end

-- ─── Popup ──────────────────────────────────────────────────────────────────

local function dim(W, H)
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 0, 0, W, H)
end

function Scene:drawPausePopup(W, H)
    local ui = self.ui
    ui:blockBelow()
    dim(W, H)
    local w, h = Theme.px(300), Theme.px(250)
    local x, y = (W - w) / 2, (H - h) / 2
    ui:panel(x, y, w, h)
    ui:label("Tạm dừng", x, y + Theme.px(8), { font = Theme.font(15, true), width = w, align = "center", color = Theme.color.accent })
    local bw, bh, bx = w - Theme.px(40), Theme.px(30), x + Theme.px(20)
    local by = y + Theme.px(40)
    local function btn(id, text, opts)
        opts = opts or {}
        opts.font = Theme.font(12, true)
        ui:button(id, bx, by, bw, bh, text, opts)
        by = by + bh + Theme.px(6)
    end
    btn("p_resume", "Tiếp tục", { onClick = function() self.popup = nil end })
    btn("p_save", "Lưu nhanh (" .. Actions.label("quicksave") .. ")", { onClick = function() self:quicksave(); self.popup = nil end })
    btn("p_load", "Nạp bản lưu nhanh (" .. Actions.label("quickload") .. ")", {
        enabled = Save.exists(QUICKSAVE), onClick = function() self:quickload() end,
    })
    btn("p_shake", "Rung màn hình: " .. (self.reduceMotion and "Tắt" or "Bật"), {
        tip = "Tắt để giảm rung và nhấp nháy khi ra 7.",
        onClick = function() self.reduceMotion = not self.reduceMotion end,
    })
    btn("p_menu", "Về menu chính", { onClick = function()
        manager.switch(require("src.scenes.menu"))
    end })
end

function Scene:drawTradePopup(W, H)
    local ui, state = self.ui, self.state
    ui:blockBelow()
    dim(W, H)
    local p = state.players[Game.actor(state)]
    local w, h = Theme.px(380), Theme.px(210)
    local x, y = (W - w) / 2, (H - h) / 2
    ui:panel(x, y, w, h)
    ui:label(string.format("Đổi tài nguyên với ngân hàng (%d : 1)", C.BANK_TRADE_RATE), x, y + Theme.px(8),
        { font = Theme.font(14, true), width = w, align = "center", color = Theme.color.accent })

    local bw = (w - Theme.px(30)) / 5
    local function row(title, ry, enabledFn, selected, showCount, onPick)
        ui:label(title, x + Theme.px(12), ry, { font = Theme.font(11), color = Theme.color.dim })
        for i, r in ipairs(Resources.core) do
            local bx = x + Theme.px(12) + (i - 1) * (bw + Theme.px(2))
            ui:button("t_" .. title .. r.key, bx, ry + Theme.px(16), bw, Theme.px(34),
                r.abbr .. "\n" .. (showCount and p.res[r.key] or ""), {
                    enabled = enabledFn(r.key), focused = selected == r.key, font = Theme.font(11, true),
                    onClick = function() onPick(r.key) end,
                })
        end
    end
    row("Đưa", y + Theme.px(34), function(k) return p.res[k] >= C.BANK_TRADE_RATE end, self.trade.give, true,
        function(k) self.trade.give = k end)
    row("Nhận", y + Theme.px(100), function(k) return self.trade.give ~= nil and k ~= self.trade.give end, nil, false,
        function(k)
            if self:cmd({ type = "trade", give = self.trade.give, get = k }) then self.popup = nil end
        end)
    ui:label(self.trade.give and ("Đưa " .. C.BANK_TRADE_RATE .. " " .. Fmt.res(self.trade.give) .. " — chọn loại muốn nhận")
        or "Chọn loại tài nguyên để đưa", x, y + Theme.px(158), { font = Theme.font(11), width = w, align = "center" })
    ui:button("t_cancel", x + w / 2 - Theme.px(50), y + h - Theme.px(36), Theme.px(100), Theme.px(26), "Hủy", {
        font = Theme.font(11, true), onClick = function() self.popup = nil end,
    })
end

function Scene:drawLossPopup(W, H)
    local ui, state = self.ui, self.state
    ui:blockBelow()
    dim(W, H)
    local pend = state.rebel.pending
    local w, h = Theme.px(380), Theme.px(150)
    local x, y = (W - w) / 2, (H - h) / 2
    ui:panel(x, y, w, h, { borderColor = Theme.color.bad })
    ui:label(string.format("P%d: Phiến Quân cướp phá!", pend.owner), x, y + Theme.px(8),
        { font = Theme.font(14, true), width = w, align = "center", color = Theme.color.bad })
    ui:label(string.format("Chọn loại tài nguyên mất %d (các loại đang bằng nhau):", pend.amount), x, y + Theme.px(34),
        { font = Theme.font(11), width = w, align = "center" })
    local n = #pend.options
    local bw = math.min(Theme.px(64), (w - Theme.px(30)) / n)
    local startX = x + (w - n * (bw + Theme.px(4))) / 2
    for i, key in ipairs(pend.options) do
        ui:button("loss" .. key, startX + (i - 1) * (bw + Theme.px(4)), y + Theme.px(68), bw, Theme.px(40),
            Fmt.res(key) .. "\n" .. state.players[pend.owner].res[key], {
                font = Theme.font(12, true), color = Theme.resource[key], textColor = { 0.07, 0.08, 0.1 },
                onClick = function() self:cmd({ type = "chooseLoss", res = key }) end,
            })
    end
end

-- ─── Draw ───────────────────────────────────────────────────────────────────

function Scene:draw()
    local W, H = love.graphics.getDimensions()
    Theme.update(W, H)
    self.ghostReason = nil
    self:drawMap()

    local ui, state = self.ui, self.state
    ui:begin()
    local barH = self:drawTopBar(W)
    local pad = Theme.px(6)

    local panelW = Theme.px(184)
    local cardsW = Theme.px(176)
    local logH = Theme.px(150)
    self:drawPlayers(pad, barH + pad, cardsW)
    self:drawActions(W - panelW - pad, barH + pad, panelW)
    local logW = Theme.px(310)
    self:drawLog(pad, H - logH - pad, logW, logH)
    self:drawInfo(pad + logW + pad, H - Theme.px(24) - pad, W - (pad + logW + pad) - pad, Theme.px(24))

    -- gợi ý thao tác (tự xuống dòng khi dài)
    local hint = self:hintText()
    if hint ~= "" then
        local f = Theme.font(12, true)
        local maxW = math.max(Theme.px(260), W - 2 * (cardsW + panelW + 3 * pad))
        local tw = math.min(maxW, f:getWidth(hint) + Theme.px(24))
        local _, lines = f:getWrap(hint, tw - Theme.px(16))
        local th = #lines * f:getHeight() + Theme.px(10)
        ui:panel((W - tw) / 2, barH + pad, tw, th)
        ui:label(hint, (W - tw) / 2 + Theme.px(8), barH + pad + Theme.px(5),
            { font = f, width = tw - Theme.px(16), align = "center", color = Theme.color.accent })
    end

    if self.toast then
        local f = Theme.font(13, true)
        local tw = f:getWidth(self.toast.text) + Theme.px(28)
        love.graphics.setColor(0, 0, 0, 0.75 * self.toast.a)
        love.graphics.rectangle("fill", (W - tw) / 2, H * 0.62, tw, Theme.px(30), 6, 6)
        ui:label(self.toast.text, (W - tw) / 2, H * 0.62 + Theme.px(6),
            { font = f, color = { 1, 1, 1, self.toast.a }, width = tw, align = "center" })
    end

    if self.debug then
        local lines = {
            string.format("FPS %d  phase %s  actor %s  zoom %.1f", love.timer.getFPS(), state.phase,
                tostring(Game.actor(state)), self.camera.zoom),
            "seed " .. tostring(state.seed) .. "  lệnh " .. #state.history,
        }
        for i, l in ipairs(lines) do
            ui:label(l, W / 2 - Theme.px(130), H - Theme.px(80) - i * Theme.px(14), { font = Theme.font(10) })
        end
    end

    if state.phase == "rebel_loss" then
        self:drawLossPopup(W, H)
    elseif self.popup == "pause" then
        self:drawPausePopup(W, H)
    elseif self.popup == "trade" then
        self:drawTradePopup(W, H)
    elseif self.ghostReason and self.mode then
        ui.tip = self.ghostReason
    end
    ui:finish()
    love.graphics.setColor(1, 1, 1)
end

-- ─── Input ──────────────────────────────────────────────────────────────────

function Scene:keypressed(key)
    local state = self.state
    if state.phase == "rebel_loss" then return end   -- bắt buộc chọn

    if Actions.matches("cancel", key) then
        if self.popup then self.popup = nil
        elseif self.mode then self.mode = nil
        else self.popup = "pause" end
        return
    end
    if self.popup then return end

    if Actions.matches("roll", key) and state.phase == "roll" then
        self:startRoll()
    elseif Actions.matches("endTurn", key) and state.phase == "action" then
        self.mode = nil
        self:cmd({ type = "endTurn" })
    elseif Actions.matches("quicksave", key) then
        self:quicksave()
    elseif Actions.matches("quickload", key) then
        if Save.exists(QUICKSAVE) then self:quickload() else self:say("Chưa có bản lưu nhanh") end
    elseif Actions.matches("toggleDebug", key) then
        self.debug = not self.debug
    elseif Actions.matches("toggleZones", key) then
        self.showZones = not self.showZones
    end
end

function Scene:mousepressed(x, y, button)
    if self.ui:mousepressed(x, y, button) then return end
    if button ~= 1 or self.popup or self.rollAnim then return end

    local state = self.state
    local wx, wy = self.camera:screenToWorld(x, y)
    local tile = MapRenderer.tileAt(state.map, wx, wy)
    if not tile then return end
    local actor = Game.actor(state)

    if state.phase == "setup_hq" then
        if tile.zone and not state.takenStarts[tile.zone] then
            self:cmd({ type = "placeHQ", start = tile.zone })
        else
            self:say("Hãy chọn một vùng khởi đầu còn trống")
        end
    elseif state.phase == "rebel_move" then
        self:cmd({ type = "rebelStep", q = tile.q, r = tile.r })
    elseif state.phase == "action" and self.mode then
        if self.mode.kind == "build" then
            if self:cmd({ type = "build", id = self.mode.id, q = tile.q, r = tile.r }) then self.mode = nil end
        elseif self.mode.kind == "vote" then
            self:cmd({ type = "placeVote", q = tile.q, r = tile.r })
            if state.players[actor].votes < 1 then self.mode = nil end
        elseif self.mode.kind == "buy" then
            self:cmd({ type = "buyTile", q = tile.q, r = tile.r })
        elseif self.mode.kind == "sub" then
            if self:cmd({ type = "foundSub", q = tile.q, r = tile.r }) then self.mode = nil end
        end
    end
end

function Scene:mousemoved(x, y, dx, dy)
    if (love.mouse.isDown(2) or love.mouse.isDown(3)) and not self.popup then
        self.camera:pan(-dx, -dy)
    end
end

function Scene:wheelmoved(dx, dy)
    if dy ~= 0 and not self.popup then
        local mx, my = love.mouse.getPosition()
        self.camera:zoomAt(dy > 0 and 1 or -1, mx, my)
    end
end

function Scene:resize(w, h)
    Theme.update(w, h)
    self.camera:clamp()
end

return Scene
