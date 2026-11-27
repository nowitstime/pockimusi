-- ============================================================================
-- src/ui/chrome/modeplate.lua — MOCK-UP: settings-page ("mode page") styles
-- for the Track page. Off unless Chrome.MOCK is "A", "B" or "C".
--   A  ENGRAVED : neutral silver plate, chamfered corners, limb ticks, dial
--                 left, gear watermark; the instrument colour only as accent
--                 and as a faint glow seeping from its ornaments
--   B  OVERLAY  : the instrument's own stage and ornaments, dimmed, with an
--                 edge-lit plate laid over the centre column
--   C  EDGE-LIT : the instrument-coloured stage, with a cool white edge light,
--                 limb ticks and notched corners marking it as a mode page
-- (part of src/ui/chrome.lua: adds methods to the Chrome table)
-- ============================================================================

local Config      = require("src.config")
local Input       = require("src.input")
local Looper      = require("src.looper")
local Instruments = require("src.instruments")
local Modes       = require("src.modes")
local Display     = require("src.ui.display")

local math_floor = math.floor
local math_sin   = math.sin
local math_cos   = math.cos
local math_pi    = math.pi
local clamp      = Config.clamp

return function(Chrome)

Chrome.MOCK = nil
-- Settings pages that take the mock style (style D) besides the Track page
Chrome.MOCK_PAGES = { TRANSPORT = true, MIX = true, FX = true }

-- Cool white "moonlight" used for every mode page's edge light
local MOON = { 0.86, 0.92, 1.0, 1.0 }

-- Chamfered rectangle outline / fill points
local function chamferPts(x, y, w, h, c)
    return {
        x + c, y,  x + w - c, y,  x + w, y + c,  x + w, y + h - c,
        x + w - c, y + h,  x + c, y + h,  x, y + h - c,  x, y + c,
    }
end

-- A soft glow: the same outline stroked several times, wide and faint to thin and bright
function Chrome:mockGlowPoly(pts, col, strength)
    strength = strength or 1.0
    love.graphics.setLineJoin("bevel")
    for _, s in ipairs({ { 7, 0.05 }, { 4.5, 0.08 }, { 2.5, 0.16 }, { 1.2, 0.75 } }) do
        self:setColor(col, s[2] * strength)
        love.graphics.setLineWidth(s[1])
        love.graphics.polygon("line", pts)
    end
    love.graphics.setLineWidth(1)
    love.graphics.setLineJoin("miter")
end

function Chrome:mockGlowRect(x, y, w, h, r, col, strength)
    strength = strength or 1.0
    for _, s in ipairs({ { 6, 0.05 }, { 3.5, 0.10 }, { 1.2, 0.8 } }) do
        self:setColor(col, s[2] * strength)
        love.graphics.setLineWidth(s[1])
        love.graphics.rectangle("line", x, y, w, h, r, r)
    end
    love.graphics.setLineWidth(1)
end

-- Graduation ticks along the inside of a frame, like an astrolabe's limb
function Chrome:mockLimbTicks(x, y, w, h, col, alpha)
    alpha = alpha or 1.0
    local step = 8
    for tx = x + 24, x + w - 24, step do
        local major = ((tx - x - 24) % (step * 4) == 0)
        local len = major and 5 or 2.5
        self:setColor(col, (major and 0.5 or 0.25) * alpha)
        love.graphics.line(tx, y + 3, tx, y + 3 + len)
        love.graphics.line(tx, y + h - 3, tx, y + h - 3 - len)
    end
    for ty = y + 24, y + h - 24, step do
        local major = ((ty - y - 24) % (step * 4) == 0)
        local len = major and 5 or 2.5
        self:setColor(col, (major and 0.5 or 0.25) * alpha)
        love.graphics.line(x + 3, ty, x + 3 + len, ty)
        love.graphics.line(x + w - 3, ty, x + w - 3 - len, ty)
    end
end

-- Corner brackets on a chamfered frame
function Chrome:mockCornerBrackets(x, y, w, h, c, col, alpha)
    self:setColor(col, alpha or 0.7)
    love.graphics.setLineWidth(1.4)
    local k = c + 10
    love.graphics.line(x + 4, y + k, x + 4, y + c + 1, x + c + 1, y + 4, x + k, y + 4)
    love.graphics.line(x + w - k, y + 4, x + w - c - 1, y + 4, x + w - 4, y + c + 1, x + w - 4, y + k)
    love.graphics.line(x + 4, y + h - k, x + 4, y + h - c - 1, x + c + 1, y + h - 4, x + k, y + h - 4)
    love.graphics.line(x + w - k, y + h - 4, x + w - c - 1, y + h - 4, x + w - 4, y + h - c - 1, x + w - 4, y + h - k)
    love.graphics.setLineWidth(1)
end

-- The Track page's glyph: a gear (12 teeth) with an astrolabe hub
function Chrome:mockGear(cx, cy, r, col, alpha, fill)
    local teeth = 12
    local pts = {}
    for i = 0, teeth * 4 - 1 do
        local a = (i / (teeth * 4)) * 2 * math_pi
        local outer = (i % 4 == 1 or i % 4 == 2)
        local rr = outer and r or r * 0.8
        pts[#pts + 1] = cx + math_cos(a) * rr
        pts[#pts + 1] = cy + math_sin(a) * rr
    end
    self:setColor(col, alpha)
    if fill then
        love.graphics.setLineWidth(math.max(1, r * 0.28))
        love.graphics.polygon("line", pts)
        love.graphics.setLineWidth(1)
        love.graphics.circle("fill", cx, cy, r * 0.22)
    else
        love.graphics.polygon("line", pts)
        love.graphics.circle("line", cx, cy, r * 0.55)
        love.graphics.circle("line", cx, cy, r * 0.18)
        for i = 0, 5 do
            local a = i * math_pi / 3
            love.graphics.line(cx + math_cos(a) * r * 0.18, cy + math_sin(a) * r * 0.18,
                               cx + math_cos(a) * r * 0.55, cy + math_sin(a) * r * 0.55)
        end
    end
end

-- Spaced title between rules:  ──  T R A C K  ──
function Chrome:mockSpacedTitle(cx, y, text, col, alpha, font)
    font = font or self.fontTiny
    local spaced = text:gsub(".", "%0 "):sub(1, -2)
    love.graphics.setFont(font)
    local tw = font:getWidth(spaced)
    local ly = y + math_floor(self:lineHeight(font) * 0.5)
    self:setColor(col, (alpha or 1) * 0.45)
    love.graphics.line(cx - tw * 0.5 - 30, ly, cx - tw * 0.5 - 8, ly)
    love.graphics.line(cx + tw * 0.5 + 8, ly, cx + tw * 0.5 + 30, ly)
    self:drawDiamond(cx - tw * 0.5 - 32, ly, 2, col)
    self:drawDiamond(cx + tw * 0.5 + 32, ly, 2, col)
    self:setColor(col, alpha or 1)
    love.graphics.print(spaced, math_floor(cx - tw * 0.5), y)
end

-- The setting dial: a graduated ring with four stations (rows / values) and a needle
function Chrome:mockDial(cx, cy, col, accent, labelCol, plain, labels)
    local C = Config.COLORS
    local R = 58
    local dir = Input:get8WayDirection()
    if dir == "NEUTRAL" then dir = nil end
    -- faint face
    self:setColor(col, 0.04)
    love.graphics.circle("fill", cx, cy, R)
    self:setColor(col, 0.55)
    love.graphics.circle("line", cx, cy, R)
    self:setColor(col, 0.25)
    love.graphics.circle("line", cx, cy, R - 12)
    love.graphics.circle("line", cx, cy, R + 8)
    -- graduation
    for i = 0, 71 do
        local a = i / 72 * 2 * math_pi
        local major = (i % 18 == 0)
        local mid = (i % 6 == 0)
        local r1 = R - (major and 10 or (mid and 6 or 3))
        self:setColor(col, major and 0.9 or (mid and 0.5 or 0.28))
        love.graphics.line(cx + math_cos(a) * r1, cy + math_sin(a) * r1, cx + math_cos(a) * R, cy + math_sin(a) * R)
    end
    -- stations
    local st = {
        { k = "UP",    a = -math_pi * 0.5, text = "ROW",   arrow = "up" },
        { k = "DOWN",  a =  math_pi * 0.5, text = "ROW",   arrow = "down" },
        { k = "LEFT",  a =  math_pi,       text = "VALUE", arrow = "left" },
        { k = "RIGHT", a =  0,             text = "VALUE", arrow = "right" },
    }
    love.graphics.setFont(self.fontTiny)
    for _, s in ipairs(st) do
        local on = (dir == s.k)
        local ox, oy = cx + math_cos(s.a) * (R + 8), cy + math_sin(s.a) * (R + 8)
        if on or not plain then
            self:drawDiamond(ox, oy, on and 4 or 3, on and accent or C.PANEL, on and accent or col)
        end
        local tw = self.fontTiny:getWidth(s.text)
        local lx, ly
        if s.k == "UP" then lx, ly = cx - tw * 0.5, cy - R - 26
        elseif s.k == "DOWN" then lx, ly = cx - tw * 0.5, cy + R + 16
        elseif s.k == "LEFT" then lx, ly = cx - R - 2 - tw, cy - R * 0.5 - 6
        else lx, ly = cx + R + 2, cy - R * 0.5 - 6 end
        if not plain then
            local text = s.text
            if labels then text = labels[s.k] or "" end
            text = text:gsub("%s*[<>]%s*", ""):gsub("^%s+", ""):gsub("%s+$", "")
            if text ~= "" then self:mockDialLabel(cx, cy, R, s.k, s.a, text, on, accent, col, labelCol) end
        end
    end
    -- needle: points at the held direction, else rests up
    local na = -math_pi * 0.5
    local map = { UP = -0.5, DOWN = 0.5, LEFT = 1.0, RIGHT = 0.0, UP_LEFT = -0.75, UP_RIGHT = -0.25, DOWN_LEFT = 0.75, DOWN_RIGHT = 0.25 }
    if dir and map[dir] then na = map[dir] * math_pi end
    local held = dir and map[dir]
    if (plain or labels) and not held then
        -- at rest: an empty face, just the hub
        self:setColor(col, 0.6)
        love.graphics.circle("line", cx, cy, 4)
        return
    end
    local tipx, tipy = cx + math_cos(na) * (R - 14), cy + math_sin(na) * (R - 14)
    local px, py = math_cos(na + math_pi * 0.5) * 4, math_sin(na + math_pi * 0.5) * 4
    self:setColor(held and accent or col, held and 1 or 0.7)
    love.graphics.polygon("fill", tipx, tipy, cx + px, cy + py, cx - px, cy - py)
    self:setColor(held and accent or col, 0.35)
    love.graphics.line(cx, cy, cx - math_cos(na) * 14, cy - math_sin(na) * 14)
    self:setColor(C.PANEL)
    love.graphics.circle("fill", cx, cy, 5)
    self:setColor(col, 0.9)
    love.graphics.circle("line", cx, cy, 5)
    self:drawStarGlint(cx, cy, 3, accent, 1)
end

-- Style D's stage for any settings page: the instrument's scenery, dimmed,
-- a solid plate under the centre column, a clean chamfered moonlit frame
function Chrome:mockModeBackdrop(def, instCol)
    local C = Config.COLORS
    local X, Y, W, Hh, CH = 8, 50, 624, 306, 12
    self.haloDrawn = self:drawStageMood(def, instCol, 102, 188, 538, 188)
    self:setColor(C.BG, 0.3)
    love.graphics.rectangle("fill", 9, 51, 622, 304)
    local plate = chamferPts(184, 86, 272, 240, 10)
    self:setColor(C.BG, 1.0)
    love.graphics.polygon("fill", plate)
    self:mockGlowPoly(plate, MOON, 0.75)
    self:setColor(C.BG)
    love.graphics.polygon("fill", X - 1, Y - 1, X + CH, Y - 1, X - 1, Y + CH)
    love.graphics.polygon("fill", X + W + 1, Y - 1, X + W - CH, Y - 1, X + W + 1, Y + CH)
    love.graphics.polygon("fill", X - 1, Y + Hh + 1, X + CH, Y + Hh + 1, X - 1, Y + Hh - CH)
    love.graphics.polygon("fill", X + W + 1, Y + Hh + 1, X + W - CH, Y + Hh + 1, X + W + 1, Y + Hh - CH)
    self:mockGlowPoly(chamferPts(X, Y, W, Hh, CH), MOON, 0.8)
end

-- A page glyph for the top-bar badge
function Chrome:mockGlyph(mode, cx, cy, col)
    self:setColor(col)
    if mode == "TRACK" then
        self:mockGear(cx, cy, 6.5, col, 1.0, true)
    elseif mode == "TRANSPORT" then
        -- hourglass
        love.graphics.setLineWidth(1.4)
        love.graphics.line(cx - 4.5, cy - 6, cx + 4.5, cy - 6)
        love.graphics.line(cx - 4.5, cy + 6, cx + 4.5, cy + 6)
        love.graphics.polygon("line", cx - 3.5, cy - 5, cx + 3.5, cy - 5, cx, cy, cx + 3.5, cy + 5, cx - 3.5, cy + 5, cx, cy)
        love.graphics.polygon("fill", cx - 2.5, cy + 4.5, cx + 2.5, cy + 4.5, cx, cy + 1.5)
        love.graphics.setLineWidth(1)
    elseif mode == "MIX" then
        for i, h in ipairs({ -2, 2, -1 }) do
            local x = cx - 5 + (i - 1) * 5
            love.graphics.line(x, cy - 6, x, cy + 6)
            love.graphics.rectangle("fill", x - 2, cy + h * 2 - 1.5, 4, 3)
        end
    elseif mode == "FX" then
        -- lightning bolt
        love.graphics.polygon("fill", cx + 1.5, cy - 7, cx - 4, cy + 1, cx - 0.5, cy + 1, cx - 1.5, cy + 7, cx + 4, cy - 1, cx + 0.5, cy - 1)
    end
end

-- A dial station's label, in the style Chrome.MOCK_LABELS names:
-- "tab" (a small engraved plate on the ring) or "arc" (lettering along the ring)
Chrome.MOCK_LABELS = "tab"
function Chrome:mockDialLabel(cx, cy, R, k, a, text, on, accent, col, labelCol)
    local C = Config.COLORS
    local ft = self.fontTiny
    if self.MOCK_LABELS == "arc" then
        local rr = R + 18
        local spacing = 1.0
        local widths, total = {}, 0
        for i = 1, #text do
            local ch = text:sub(i, i)
            widths[i] = ft:getWidth(ch) + spacing
            total = total + widths[i]
        end
        -- bottom half reads left to right the other way round so it stays upright
        local flip = (k == "DOWN")
        local span = total / rr
        local ang = flip and (a + span * 0.5) or (a - span * 0.5)
        love.graphics.setFont(ft)
        local fh = self:lineHeight(ft)
        self:setColor(on and accent or labelCol, on and 1 or 0.85)
        for i = 1, #text do
            local ch = text:sub(i, i)
            local da = widths[i] / rr
            local mid = flip and (ang - da * 0.5) or (ang + da * 0.5)
            local px, py = cx + math_cos(mid) * rr, cy + math_sin(mid) * rr
            local rot = flip and (mid - math_pi * 0.5) or (mid + math_pi * 0.5)
            love.graphics.print(ch, px, py, rot, 1, 1, (widths[i] - spacing) * 0.5, fh * 0.5)
            ang = flip and (ang - da) or (ang + da)
        end
        return
    end
    -- tab: a chamfered plate sitting on the ring at the station
    local tw = ft:getWidth(text)
    local w, h = tw + 12, 14
    local ox, oy = cx + math_cos(a) * (R + 8), cy + math_sin(a) * (R + 8)
    local x, y = ox - w * 0.5, oy - h * 0.5
    if k == "LEFT" then x = math.max(13, ox - w + 6) end
    if k == "RIGHT" then x = math.min(ox - 6, 181 - w) end
    x, y = math_floor(x) + 0.5, math_floor(y) + 0.5
    local pts = chamferPts(x, y, w, h, 3)
    self:setColor(on and accent or C.BG, on and 0.25 or 1.0)
    love.graphics.polygon("fill", pts)
    if on then
        self:setColor(C.BG, 0.6)
        love.graphics.polygon("fill", pts)
        self:setColor(accent, 0.3)
        love.graphics.polygon("fill", pts)
        self:mockGlowPoly(pts, MOON, 0.9)
    else
        self:setColor(col, 0.45)
        love.graphics.polygon("line", pts)
    end
    love.graphics.setFont(ft)
    self:setColor(on and C.TEXT or labelCol, on and 1 or 0.9)
    love.graphics.print(text, math_floor(x + 6), math_floor(y + (h - self:lineHeight(ft)) * 0.5))
end

-- Clock: the GRID and SWING buttons carry their values (the chips under the
-- dial are gone)
function Chrome:mockClockFaceLabels(face, track)
    if track.isLane then return end
    local grid = Looper:getTrackGrid(track.slot)
    face.A = { l1 = "GRID", l2 = grid.label }
    face.Y = { l1 = "SWING", l2 = string.format("%d%%", math_floor((track.swing or 0.5) * 100 + 0.5)) }
end

-- Clock: a change to grid, swing, bars or click shows on the dial face for a
-- moment (and stays while Y is held to set swing)
Chrome.MOCK_FLASH_TIME = 1.4
function Chrome:mockClockFlash(track, accent)
    local C = Config.COLORS
    local now = love.timer.getTime()
    local grid = not track.isLane and Looper:getTrackGrid(track.slot) or nil
    local swingPct = math_floor((track.swing or 0.5) * 100 + 0.5)
    local sig = {
        grid = grid and ("GRID " .. grid.label) or nil,
        swing = string.format("SWING %d%%", swingPct),
        bars = string.format("LOOP %d BAR%s", Looper.bars, Looper.bars > 1 and "S" or ""),
        click = "CLICK " .. tostring(Looper:getClickMode()),
    }
    local last = self.mockClockSig
    if last and last.slot == track.slot then
        for _, key in ipairs({ "grid", "swing", "bars", "click" }) do
            if sig[key] ~= last[key] then
                self.mockFlash = { text = sig[key], time = now }
            end
        end
    end
    sig.slot = track.slot
    self.mockClockSig = sig
    local f = self.mockFlash
    local text, age
    if Input.down.Y and not track.isLane then
        text, age = sig.swing, 0
    elseif f and now - f.time < self.MOCK_FLASH_TIME then
        text, age = f.text, now - f.time
    end
    if not text then return end
    local a = (age < self.MOCK_FLASH_TIME - 0.3) and 1 or ((self.MOCK_FLASH_TIME - age) / 0.3)
    local name = (track.shortName or track.name)
    love.graphics.setFont(self.fontMed)
    local w = math.max(self.fontMed:getWidth(text), self.fontTiny:getWidth(name)) + 28
    local x, y, h = math_floor(320 - w * 0.5), 192, 38
    local pts = chamferPts(x, y, w, h, 6)
    self:setColor(C.BG, 0.96 * a)
    love.graphics.polygon("fill", pts)
    self:mockGlowPoly(pts, MOON, a)
    self:setColor(C.TEXT, a)
    love.graphics.print(text, math_floor(320 - self.fontMed:getWidth(text) * 0.5), y + 5)
    love.graphics.setFont(self.fontTiny)
    self:setColor(self:trackColor(track.slot), a)
    love.graphics.print(name, math_floor(320 - self.fontTiny:getWidth(name) * 0.5), y + 24)
end

-- Engraved two-word captions under the zones, in the spaced lettering
function Chrome:mockZoneCaptions(col, alpha)
    self:mockSpacedTitle(102, 297, "ROWS", col, alpha)
    self:mockSpacedTitle(538, 297, "EFFECTS", col, alpha)
end

-- ----------------------------------------------------------------------------
-- The whole Track-page stage in one of the mock styles
-- ----------------------------------------------------------------------------
function Chrome:drawMockTrackStage(def, state, track, instCol, t)
    local C = Config.COLORS
    local style = self.MOCK
    local shade = Config.shade
    local X, Y, W, Hh = 8, 50, 624, 306
    local CH = 12
    local frame = chamferPts(X, Y, W, Hh, CH)
    local inner = chamferPts(X + 1, Y + 1, W - 2, Hh - 2, CH)

    -- Background
    if style == "A" then
        self:setColor(C.PANEL)
        love.graphics.polygon("fill", inner)
        -- the instrument's ornaments, ghosted, so its colour seeps in at the zones
        local clip = Display:pushClip(9, 51, 622, 271)
        self:mockGhostMood(def, instCol, 0.22)
        Display:popClip(clip)
        -- a soft pool of the instrument's colour behind each zone
        for _, zx in ipairs({ 102, 538 }) do
            for r = 96, 40, -14 do
                self:setColor(instCol, 0.018)
                love.graphics.circle("fill", zx, 188, r)
            end
        end
        -- gear watermark behind the rows
        self:mockGear(320, 200, 92, C.SILVER, 0.045)
    elseif style == "B" then
        self.haloDrawn = self:drawStageMood(def, instCol, 102, 188, 538, 188)
        -- dim it like a stage seen through glass
        self:setColor(C.BG, 0.38)
        love.graphics.rectangle("fill", 9, 51, 622, 304)
        -- the plate over the centre column
        local plate = chamferPts(184, 84, 272, 230, 10)
        self:setColor(C.PANEL, 0.94)
        love.graphics.polygon("fill", plate)
        self:mockGear(320, 204, 84, C.SILVER, 0.04)
        self:mockGlowPoly(plate, MOON, 0.9)
        self:mockCornerBrackets(184, 84, 272, 230, 10, MOON, 0.55)
    elseif style == "D" then
        self.haloDrawn = self:drawStageMood(def, instCol, 102, 188, 538, 188)
        self:setColor(C.BG, 0.3)
        love.graphics.rectangle("fill", 9, 51, 622, 304)
        -- a solid, darker plate under the rows so they read easily
        local plate = chamferPts(184, 86, 272, 240, 10)
        self:setColor(C.BG, 1.0)
        love.graphics.polygon("fill", plate)
        self:mockGlowPoly(plate, MOON, 0.75)
    else -- C
        self:setColor(shade(instCol, self.STAGE_SHADE))
        love.graphics.polygon("fill", inner)
        self:drawZoneMotifs(self:viewKind(def), instCol, t)
        self:mockGear(320, 200, 92, instCol, 0.05)
    end

    -- Clear the corners the chamfer cuts away
    self:setColor(C.BG)
    love.graphics.polygon("fill", X - 1, Y - 1, X + CH, Y - 1, X - 1, Y + CH)
    love.graphics.polygon("fill", X + W + 1, Y - 1, X + W - CH, Y - 1, X + W + 1, Y + CH)
    love.graphics.polygon("fill", X - 1, Y + Hh + 1, X + CH, Y + Hh + 1, X - 1, Y + Hh - CH)
    love.graphics.polygon("fill", X + W + 1, Y + Hh + 1, X + W - CH, Y + Hh + 1, X + W + 1, Y + Hh - CH)

    -- Frame: chamfered, edge-lit in moonlight
    if style == "A" then
        self:setColor(C.SILVER, 0.35)
        love.graphics.polygon("line", chamferPts(X + 5, Y + 5, W - 10, Hh - 10, CH - 3))
        self:mockGlowPoly(frame, MOON, 0.9)
        self:mockLimbTicks(X + 5, Y + 5, W - 10, 268, C.SILVER, 0.9)
        self:mockCornerBrackets(X, Y, W, Hh, CH, MOON, 0.6)
        self:setColor(C.SILVER, 0.18)
        love.graphics.line(198, 92, 198, 300)
        love.graphics.line(442, 92, 442, 300)
    elseif style == "D" then
        self:mockGlowPoly(frame, MOON, 0.8)
    elseif style == "B" then
        self:mockGlowPoly(frame, MOON, 0.6)
        self:setColor(shade(instCol, 0.6), 0.6)
        love.graphics.polygon("line", chamferPts(X + 3, Y + 3, W - 6, Hh - 6, CH - 2))
    else
        self:setColor(shade(instCol, 0.5), 0.8)
        love.graphics.polygon("line", chamferPts(X + 4, Y + 4, W - 8, Hh - 8, CH - 2))
        self:mockGlowPoly(frame, MOON, 0.85)
        self:mockLimbTicks(X + 4, Y + 4, W - 8, 270, MOON, 0.6)
        self:setColor(C.GRID, 0.55)
        love.graphics.line(198, 92, 198, 300)
        love.graphics.line(442, 92, 442, 300)
    end

    -- Header pill: the instrument's colour, no group word
    self:mockInstrumentPill(track, instCol)

    -- Left: the setting dial
    if style == "A" then
        self:mockDial(102, 188, C.SILVER, instCol, C.MUTED)
    elseif style == "D" then
        self:mockDial(102, 188, MOON, instCol, C.TEXT, true)
    elseif style == "B" then
        self:mockDial(102, 188, MOON, instCol, C.TEXT)
    else
        self:mockDial(102, 188, instCol, C.TEXT, C.MUTED)
    end

    -- Right: the FX ring (silver on A, the instrument's colour on B / C)
    local _, faceLabels, flashMap, activeMap = self:getControlLabels(def, state, "TRACK")
    local faceCol = (style == "A" or style == "D") and C.SILVER or instCol
    self:drawCircleFaceButtons(538, 188, faceLabels, faceCol, flashMap, activeMap)

    -- Captions
    if style == "D" then
        self:mockSpacedTitle(538, 297, "EFFECTS", C.SILVER, 0.75)
    else
        self:mockZoneCaptions(style == "A" and C.SILVER or (style == "B" and MOON or instCol), 0.75)
    end

    -- Rows (or the swap card)
    self.mockRowGlow = true
    self.mockBright = (style == "D")
    self:drawTrackPageView(def, state, track, instCol)
    self.mockRowGlow = false

    self:drawFooterStrip(def, "TRACK")
end

-- The instrument's sky and halos at a fraction of their strength
function Chrome:mockGhostMood(def, instCol, k)
    local dim = Config.shade(instCol, k)
    self.haloDrawn = false
    -- draw the halo in a dimmed colour on the plain panel (sky skipped)
    local halo = self:haloFor(def)
    if halo and self.mockHalo then
        self.mockHalo(self, halo, 102, 188, dim)
        self.mockHalo(self, halo, 538, 188, dim)
        self.haloDrawn = true
    end
end

-- Header pill: L1 / R1 caps and the instrument name in its own colour
function Chrome:mockInstrumentPill(track, col)
    local C = Config.COLORS
    local pending = Modes.trackPage.pending
    local inst = Instruments:getDefinition(pending or track.instrumentId)
    local pc = Config.INST_COLORS[inst.id] or col
    local lOn, rOn = Input.down.L1, Input.down.R1
    self:drawCapsule(206, 58, 28, 20, "L1", C.SILVER, lOn and C.SILVER or C.PANEL_HI, lOn and C.BG or C.SILVER, self.fontTiny)
    self:drawCapsule(406, 58, 28, 20, "R1", C.SILVER, rOn and C.SILVER or C.PANEL_HI, rOn and C.BG or C.SILVER, self.fontTiny)
    local px, py, pw, ph = 240, 56, 160, 24
    self:setColor(pc, pending and 0.9 or 0.2)
    love.graphics.rectangle("fill", px, py, pw, ph, ph * 0.5, ph * 0.5)
    self:mockGlowRect(px, py, pw, ph, ph * 0.5, pc, 0.9)
    love.graphics.setFont(self.fontMed)
    local name = inst.name
    local f = (self.fontMed:getWidth(name) <= pw - 40) and self.fontMed or self.fontSmall
    love.graphics.setFont(f)
    self:setColor(pending and C.BG or C.TEXT)
    love.graphics.print(name, math_floor(px + (pw - f:getWidth(name)) * 0.5), math_floor(py + (ph - self:lineHeight(f)) * 0.5))
    -- position as dots under the pill
    local n = #Instruments.catalog
    local idx = self:selectedTab(track)
    local dx0 = 320 - (n - 1) * 3
    for i = 1, n do
        if i == idx then
            self:drawDiamond(dx0 + (i - 1) * 6, py + ph + 5, 2.2, pc)
        else
            self:setColor(C.DIM)
            love.graphics.circle("fill", dx0 + (i - 1) * 6, py + ph + 5, 0.9)
        end
    end
end


-- ----------------------------------------------------------------------------
-- Style D centre views: Mix and Live FX
-- ----------------------------------------------------------------------------

-- Mix: five engraved fader slots on the plate. The level is a line in the
-- track's colour with a knob; the live meter runs beside it; the selected
-- channel wears the moonlight edge.
function Chrome:drawMixerViewD(t)
    local C = Config.COLORS
    local Synth = require("src.synth")
    local SongM = package.loaded["src.song"]
    local top, bot = 122, 258                -- fader travel
    local travel = bot - top
    for i = 1, 5 do
        local cx = 222 + (i - 1) * 49
        if i == 5 then cx = cx + 4 end
        local isMaster = (i == 5)
        local trk = not isMaster and Looper.tracks[i] or nil
        local lvl = isMaster and Synth.masterVolume or trk.volume
        local sel = (Modes.mixTrack == i)
        local muted = not isMaster and trk.muted or false
        if not isMaster and SongM and SongM.pendingMutes[i] ~= nil then muted = SongM.pendingMutes[i] end
        local col = isMaster and C.SILVER or self:trackColor(i)

        if sel then
            self:setColor(col, 0.08)
            love.graphics.rectangle("fill", cx - 22, 94, 44, 220, 5, 5)
            self:mockGlowRect(cx - 22, 94, 44, 220, 5, MOON, 0.8)
        end

        -- name
        love.graphics.setFont(self.fontSmall)
        local label = isMaster and "MST" or (trk.shortName or trk.name)
        if self.fontSmall:getWidth(label) > 40 then love.graphics.setFont(self.fontTiny) end
        local f = love.graphics.getFont()
        self:setColor(muted and C.DIM or col)
        love.graphics.print(label, math_floor(cx - f:getWidth(label) * 0.5), 100)

        -- engraved scale either side of the slot
        for k = 0, 10 do
            local y = bot - k * travel / 10
            local major = (k % 5 == 0)
            self:setColor(C.SILVER, major and 0.45 or 0.18)
            love.graphics.line(cx - 12 - (major and 4 or 2), y, cx - 12, y)
        end
        -- the slot
        self:setColor(C.GRID)
        love.graphics.rectangle("fill", cx - 5, top - 4, 4, travel + 8, 2, 2)
        -- level line in the track's colour
        local ly = bot - travel * clamp(lvl, 0, 1)
        if not muted then
            self:setColor(col, 0.18)
            love.graphics.rectangle("fill", cx - 7, ly, 8, bot - ly + 2, 3, 3)
            self:setColor(col)
            love.graphics.rectangle("fill", cx - 5, ly, 4, bot - ly + 2, 2, 2)
        end
        -- knob
        local kc = muted and C.DIM or (sel and C.TEXT or col)
        self:setColor(C.BG)
        love.graphics.rectangle("fill", cx - 12, ly - 4, 18, 8, 2, 2)
        self:setColor(kc)
        love.graphics.rectangle("line", cx - 12, ly - 4, 18, 8, 2, 2)
        love.graphics.line(cx - 8, ly, cx + 2, ly)

        -- live meter: thin bar with a peak tick (red when the master is hot)
        local m = isMaster and Synth.meters.master or Synth.meters[i]
        local hot = isMaster and m.peak > Synth.METER_HOT
        self:setColor(C.PANEL_HI)
        love.graphics.rectangle("fill", cx + 9, top - 4, 3, travel + 8, 1, 1)
        local mh = math_floor((travel + 8) * math.min(1, m.level))
        if mh > 0 then
            self:setColor(hot and C.RED or C.TEXT, 0.85)
            love.graphics.rectangle("fill", cx + 9, bot + 4 - mh, 3, mh, 1, 1)
        end
        local ph = math_floor((travel + 8) * math.min(1, m.peak))
        if ph > 1 then
            self:setColor(hot and C.RED or col)
            love.graphics.rectangle("fill", cx + 8, bot + 4 - ph - 1, 5, 2)
        end

        -- value
        love.graphics.setFont(self.fontTiny)
        local v = tostring(math_floor(lvl * 100 + 0.5))
        self:setColor(sel and C.TEXT or C.MUTED)
        love.graphics.print(v, math_floor(cx - self.fontTiny:getWidth(v) * 0.5), 268)

        -- mute state
        if not isMaster then
            if muted then
                self:drawCapsule(cx - 14, 286, 28, 16, "M", C.RED, C.RED, C.BG, self.fontTiny)
            else
                self:drawCapsule(cx - 14, 286, 28, 16, "ON", C.GRID, C.PANEL_HI, C.MUTED, self.fontTiny)
            end
        else
            self:drawCapsule(cx - 14, 286, 28, 16, "OUT", C.GRID, C.PANEL_HI, C.SILVER, self.fontTiny)
        end
    end
    -- master divider
    self:setColor(C.SILVER, 0.18)
    love.graphics.line(398, 104, 398, 300)
end

-- Live FX: the four punch-ins as tiles placed like the D-pad. Held ones
-- light up in moonlight with a small moving picture of what they do.
local FX_TILES = {
    { k = "UP",    name = "STUTTER", flag = "fxBeatRepeat", x = 320, y = 128 },
    { k = "LEFT",  name = "FILTER",  flag = "fxLowPass",    x = 250, y = 194 },
    { k = "RIGHT", name = "CRUSH",   flag = "fxBitcrush",   x = 390, y = 194 },
    { k = "DOWN",  name = "SLOW",    flag = "fxHalfSpeed",  x = 320, y = 260 },
}

function Chrome:mockFxGlyph(name, x, y, w, h, col, alpha, on, t)
    self:setColor(col, alpha)
    love.graphics.setLineWidth(1.4)
    if name == "STUTTER" then
        local step = on and (math_floor(t * 16) % 4) or -1
        for i = 0, 3 do
            local bx = x + i * (w / 4) + 2
            self:setColor(col, (i == step) and 1.0 or alpha)
            love.graphics.rectangle(i == step and "fill" or "line", bx, y + 2, w / 4 - 5, h - 4, 1, 1)
        end
    elseif name == "SLOW" then
        local pts = {}
        local ph = on and t * 3 or 0
        for i = 0, 24 do
            local f = i / 24
            pts[#pts + 1] = x + f * w
            pts[#pts + 1] = y + h * 0.5 + math_sin(f * 9 * (1 - f * 0.6) + ph) * h * 0.4 * (1 - f * 0.5)
        end
        love.graphics.line(pts)
    elseif name == "FILTER" then
        local cut = on and (0.45 + 0.15 * math_sin(t * 4)) or 0.6
        local pts = {}
        for i = 0, 24 do
            local f = i / 24
            local v = (f < cut) and 0 or ((f - cut) / (1 - cut)) ^ 1.6
            pts[#pts + 1] = x + f * w
            pts[#pts + 1] = y + 2 + v * (h - 4)
        end
        love.graphics.line(pts)
    else -- CRUSH
        local pts = {}
        local ph = on and t * 6 or 0
        local steps = 10
        for i = 0, steps - 1 do
            local f1, f2 = i / steps, (i + 1) / steps
            local v = math_sin(f1 * 2 * math_pi + ph)
            local yy = y + h * 0.5 - math_floor(v * 2 + 0.5) / 2 * h * 0.4
            pts[#pts + 1] = x + f1 * w; pts[#pts + 1] = yy
            pts[#pts + 1] = x + f2 * w; pts[#pts + 1] = yy
        end
        love.graphics.line(pts)
    end
    love.graphics.setLineWidth(1)
end

function Chrome:drawLiveFxViewD(def, state, track, instCol, t)
    local C = Config.COLORS
    local Synth = require("src.synth")
    local w, h = 104, 46
    -- spokes from the hub to each tile
    for _, tile in ipairs(FX_TILES) do
        self:setColor(C.SILVER, 0.14)
        love.graphics.line(320, 194, tile.x, tile.y)
    end
    for _, tile in ipairs(FX_TILES) do
        local on = Synth[tile.flag] and true or false
        local x, y = tile.x - w * 0.5, tile.y - h * 0.5
        local pts = chamferPts(x, y, w, h, 7)
        self:setColor(on and instCol or C.PANEL, on and 0.16 or 1.0)
        love.graphics.polygon("fill", pts)
        if on then
            self:mockGlowPoly(pts, MOON, 1.0)
        else
            self:setColor(C.SILVER, 0.3)
            love.graphics.polygon("line", pts)
        end
        love.graphics.setFont(self.fontSmall)
        self:setColor(on and C.TEXT or C.MUTED)
        if on then self:printBold(tile.name, math_floor(tile.x - self.fontSmall:getWidth(tile.name) * 0.5), y + 6)
        else love.graphics.print(tile.name, math_floor(tile.x - self.fontSmall:getWidth(tile.name) * 0.5), y + 6) end
        self:mockFxGlyph(tile.name, tile.x - 30, y + 24, 60, 16, on and instCol or C.SILVER, on and 0.9 or 0.35, on, t)
    end
    -- hub: the beat, as a glint that pulses on each beat
    local beatFrac = 0
    if Looper.playing then
        local ppq = Looper.PPQN or 480
        beatFrac = (Looper.tick % ppq) / ppq
    end
    self:setColor(C.BG)
    love.graphics.circle("fill", 320, 194, 14)
    self:setColor(C.SILVER, 0.5)
    love.graphics.circle("line", 320, 194, 14)
    self:drawStarGlint(320, 194, 6 + (1 - beatFrac) * 4, instCol, Looper.playing and (1 - beatFrac * 0.7) or 0.5)
    -- what it acts on
    love.graphics.setFont(self.fontTiny)
    local note = "ALL TRACKS  -  HOLD TO PUNCH IN"
    self:setColor(C.MUTED)
    love.graphics.print(note, math_floor(320 - self.fontTiny:getWidth(note) * 0.5), 300)
end

end
