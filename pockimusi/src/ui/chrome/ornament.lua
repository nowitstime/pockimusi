-- ============================================================================
-- src/ui/chrome/ornament.lua — TEST: ornament, motion and the boot screen
--
-- Menu test rows (saved in display.txt), each off by default:
--   ORNAMENT  OFF / CORNERS / CARTOUCHE / FULL
--             CORNERS: an engraved flourish in each corner of the stage frame
--             CARTOUCHE: the page title on a small engraved plaque
--             FULL: both, plus a fine inner rule and a mark mid-side
--   TICKS     OFF / LOOP: a graduated top edge whose ticks light up as the
--             loop passes them
--   MOTION    OFF / ON: a short rise-and-fade when a page opens, a ripple on
--             each press, corner stars that pulse on the beat, a rare twinkle
--   BOOT      OFF / ON: a constellation boot screen (B on its row previews it)
--
-- Ornament keeps to the edges, in hairlines, in one tone (silver on settings
-- pages, a dark shade of the instrument's colour on play pages), and repeats
-- the app's few marks: the four-point glint, the diamond, the tick.
-- (part of src/ui/chrome.lua: adds methods to the Chrome table)
-- ============================================================================

local Config  = require("src.config")
local Input   = require("src.input")
local Looper  = require("src.looper")
local Modes   = require("src.modes")

local math_floor = math.floor
local math_sin   = math.sin
local math_cos   = math.cos
local math_pi    = math.pi
local math_min   = math.min
local math_max   = math.max
local clamp      = Config.clamp

return function(Chrome)

-- How far through the current beat (0 on the beat), and a pulse that is 1 on
-- the beat and fades out over it
function Chrome:beatPulse()
    if not Looper.playing then return 0 end
    local ppq = Looper.PPQN or 480
    local f = ((Looper.tick or 0) % ppq) / ppq
    return math.exp(-f * 6)
end

local function motionOn(self) return self.mockOpt and self.mockOpt.MOTION == "ON" end
local function ornament(self) return self.mockOpt and self.mockOpt.ORNAMENT or "OFF" end

-- ----------------------------------------------------------------------------
-- Ornament
-- ----------------------------------------------------------------------------

-- One corner flourish: a glint set in from the corner, two short engraved
-- scrolls running out along the edges, a dot at each end. (sx, sy) point
-- along the edges away from the corner (+1 / -1).
function Chrome:drawCornerFlourish(cx, cy, sx, sy, col, alpha, pulse)
    local lg = love.graphics
    local p = pulse or 0
    self:setColor(col, alpha)
    lg.setLineWidth(1)
    -- along the horizontal edge: a line ending in a small curl that turns inward
    local hx = cx + sx * 26
    lg.line(cx + sx * 7, cy, hx, cy)
    if sx > 0 then lg.arc("line", "open", hx, cy + sy * 3, 3, -math_pi * 0.5, math_pi * 0.5)
    else lg.arc("line", "open", hx, cy + sy * 3, 3, math_pi * 0.5, math_pi * 1.5) end
    -- along the vertical edge, the same
    local vy = cy + sy * 26
    lg.line(cx, cy + sy * 7, cx, vy)
    if sy > 0 then lg.arc("line", "open", cx + sx * 3, vy, 3, 0, math_pi)
    else lg.arc("line", "open", cx + sx * 3, vy, 3, math_pi, math_pi * 2) end
    -- a small diamond on the diagonal, and the glint in the corner
    self:drawDiamond(cx + sx * 12, cy + sy * 12, 1.8, { col[1], col[2], col[3], alpha * 0.9 })
    self:drawStarGlint(cx, cy, 5 + p * 2.5, col, math_min(1, alpha * 1.6 + p * 0.4))
end

-- The four corner flourishes, set inside a frame
function Chrome:drawFrameCorners(x, y, w, h, col, alpha)
    local p = motionOn(self) and self:beatPulse() or 0
    local i = 10
    self:drawCornerFlourish(x + i, y + i, 1, 1, col, alpha, p)
    self:drawCornerFlourish(x + w - i, y + i, -1, 1, col, alpha, p)
    self:drawCornerFlourish(x + i, y + h - i, 1, -1, col, alpha, p)
    self:drawCornerFlourish(x + w - i, y + h - i, -1, -1, col, alpha, p)
end

-- FULL: a fine inner rule and a small winged diamond in the middle of each side
function Chrome:drawFrameRule(x, y, w, h, col, alpha, chamfer)
    local lg = love.graphics
    local k = 5
    self:setColor(col, alpha * 0.45)
    if chamfer then
        local c = 9
        lg.polygon("line", x + k + c, y + k, x + w - k - c, y + k, x + w - k, y + k + c, x + w - k, y + h - k - c,
            x + w - k - c, y + h - k, x + k + c, y + h - k, x + k, y + h - k - c, x + k, y + k + c)
    else
        lg.rectangle("line", x + k, y + k, w - 2 * k, h - 2 * k, 4, 4)
    end
    local function wing(mx, my, vertical)
        self:setColor(col, alpha)
        if vertical then
            lg.line(mx, my - 14, mx, my - 5); lg.line(mx, my + 5, mx, my + 14)
        else
            lg.line(mx - 14, my, mx - 5, my); lg.line(mx + 5, my, mx + 14, my)
        end
        self:drawDiamond(mx, my, 3, { col[1], col[2], col[3], alpha })
    end
    wing(x + k, y + h * 0.5, true)
    wing(x + w - k, y + h * 0.5, true)
end

-- The stage frame's ornament. `col` is the ornament tone; `chamfer` for the
-- cut-corner settings frame; `h` the visible height (the footer covers the bottom).
function Chrome:drawStageOrnament(x, y, w, h, col, chamfer)
    local o = ornament(self)
    if o == "OFF" or o == "CARTOUCHE" then
        if self.mockOpt.TICKS == "LOOP" then self:drawLoopTicks(x, y, w, col) end
        return
    end
    if self.mockOpt.TICKS == "LOOP" then self:drawLoopTicks(x, y, w, col) end
    if o == "FULL" then self:drawFrameRule(x, y, w, h, col, 0.5, chamfer) end
    self:drawFrameCorners(x, y, w, h, col, 0.55)
end

-- The page title on an engraved plaque: cut corners, diamond end caps and
-- hairlines running out towards the shoulders
function Chrome:drawCartouche(cx, ty, tw, col)
    local o = ornament(self)
    if o ~= "CARTOUCHE" and o ~= "FULL" then return end
    local lg = love.graphics
    local w, h = tw + 34, 22
    local x, y = math_floor(cx - w * 0.5) + 0.5, ty - 4.5
    local c = 6
    local pts = { x + c, y, x + w - c, y, x + w, y + c, x + w, y + h - c, x + w - c, y + h, x + c, y + h, x, y + h - c, x, y + c }
    self:setColor(Config.COLORS.BG, 0.85)
    lg.polygon("fill", pts)
    self:setColor(col, 0.55)
    lg.polygon("line", pts)
    self:setColor(col, 0.22)
    lg.polygon("line", x + 3 + c, y + 3, x + w - 3 - c, y + 3, x + w - 3, y + 3 + c, x + w - 3, y + h - 3 - c,
        x + w - 3 - c, y + h - 3, x + 3 + c, y + h - 3, x + 3, y + h - 3 - c, x + 3, y + 3 + c)
    local my = y + h * 0.5
    self:drawDiamond(x - 5, my, 3, { col[1], col[2], col[3], 0.8 })
    self:drawDiamond(x + w + 5, my, 3, { col[1], col[2], col[3], 0.8 })
    self:setColor(col, 0.3)
    lg.line(x - 10, my, math_max(140, x - 60), my)
    lg.line(x + w + 10, my, math_min(500, x + w + 60), my)
    self:drawStarGlint(math_max(140, x - 60) - 3, my, 3, col, 0.6)
    self:drawStarGlint(math_min(500, x + w + 60) + 3, my, 3, col, 0.6)
end

-- TICKS LOOP: a graduated top edge; the ticks the loop has just passed glow
-- and fade behind it, with a bright mark at the loop's position
function Chrome:drawLoopTicks(x, y, w, col)
    local lg = love.graphics
    local x0, x1 = x + 24, x + w - 24
    local ty = y + 4
    local phase = Looper.phase or 0
    local head = x0 + (x1 - x0) * phase
    local bars = Looper.bars or 2
    local n = bars * 16
    for i = 0, n do
        local tx = x0 + (x1 - x0) * i / n
        local isBar = (i % 16 == 0)
        local isBeat = (i % 4 == 0)
        local len = isBar and 6 or (isBeat and 4 or 2)
        local behind = head - tx
        local glow = (Looper.playing and behind >= 0) and math.exp(-behind / 40) or 0
        self:setColor(col, (isBar and 0.4 or (isBeat and 0.28 or 0.14)) + glow * 0.6)
        lg.line(tx, ty, tx, ty + len)
    end
    if Looper.playing then self:drawStarGlint(head, ty + 2, 4, col, 0.9) end
end

-- ----------------------------------------------------------------------------
-- Motion: page transitions, press ripples, a rare twinkle
-- ----------------------------------------------------------------------------
Chrome.TRANS_TIME = 0.18
Chrome.RIPPLE_TIME = 0.32

-- Called once per frame before the stage: notes a page change and new presses
function Chrome:motionUpdate()
    local now = love.timer.getTime()
    local mode = Modes.current or "NORMAL"
    local Menu = package.loaded["src.menu"]
    local key = mode .. ((Menu and Menu.open) and ":MENU" or "")
    if self.transKey ~= key then
        if self.transKey ~= nil then
            self.transT0 = now
            self.transSettings = not self:isPlayMode(mode) or (Menu and Menu.open)
        end
        self.transKey = key
    end
    if not motionOn(self) then self.ripples = nil; return end
    self.ripples = self.ripples or {}
    if Menu and Menu.open then return end
    local face = { X = { 538, 134 }, Y = { 484, 188 }, A = { 592, 188 }, B = { 538, 242 } }
    local dirs = { UP = { 102, 133 }, DOWN = { 102, 243 }, LEFT = { 47, 188 }, RIGHT = { 157, 188 } }
    local col = self:trackColor(Looper.activeTrack)
    for btn, p in pairs(face) do
        if Input.pressed[btn] then self.ripples[#self.ripples + 1] = { x = p[1], y = p[2], t0 = now, col = col, r = 24 } end
    end
    for btn, p in pairs(dirs) do
        if Input.pressed[btn] then self.ripples[#self.ripples + 1] = { x = p[1], y = p[2], t0 = now, col = col, r = 8 } end
    end
end

-- The rise-and-fade of a page that just opened: returns the y offset to draw
-- the stage at, and how much dark is still over it
function Chrome:transitionState()
    if not motionOn(self) or not self.transT0 then return 0, 0 end
    local e = (love.timer.getTime() - self.transT0) / self.TRANS_TIME
    if e >= 1 then return 0, 0 end
    local k = 1 - (1 - e) ^ 3                     -- ease out
    return (self.transSettings and (1 - k) * 8 or 0), (1 - k) * 0.8
end

function Chrome:drawMotionOverlay()
    if not motionOn(self) then return end
    local lg = love.graphics
    local now = love.timer.getTime()
    -- ripples
    local keep = {}
    for _, r in ipairs(self.ripples or {}) do
        local e = (now - r.t0) / self.RIPPLE_TIME
        if e < 1 then
            keep[#keep + 1] = r
            local k = 1 - e
            -- a soft flash inside, then a bright ring running outwards
            self:setColor(r.col, k * k * 0.22)
            lg.circle("fill", r.x, r.y, r.r)
            self:setColor(r.col, k * 0.25)
            lg.setLineWidth(6)
            lg.circle("line", r.x, r.y, r.r + 2 + e * 22)
            self:setColor(r.col, k * 0.95)
            lg.setLineWidth(2)
            lg.circle("line", r.x, r.y, r.r + 2 + e * 22)
            lg.setLineWidth(1)
        end
    end
    self.ripples = keep
    -- a rare twinkle in the halo, beyond the controls (play pages only)
    local mode = Modes.current or "NORMAL"
    local Menu = package.loaded["src.menu"]
    if self:isPlayMode(mode) and not (Menu and Menu.open) then
        local period = 2.7
        local slot = math_floor(now / period)
        local f = (now - slot * period) / 0.9
        if f < 1 then
            local hsh = (slot * 2654435761) % 4294967296
            local side = (hsh % 2 == 0) and 102 or 538
            local ang = ((hsh / 7) % 360) * math_pi / 180
            local rr = 80 + (hsh % 17)
            local tx, ty = side + math_cos(ang) * rr, 188 + math_sin(ang) * rr
            if ty > 62 and ty < 312 then
                self:drawStarGlint(tx, ty, 2 + math_sin(f * math_pi) * 4, Config.COLORS.TEXT, math_sin(f * math_pi) * 0.7)
            end
        end
    end
end

-- ----------------------------------------------------------------------------
-- Boot screen: a dense spiral galaxy; the camera rolls and zooms thousands of
-- times towards one spot on an arm, the stars streaming past; as they spread
-- apart the ones left on screen turn out to be the stars of the name, and
-- lines join them, letter by letter, into a constellation that spells it
-- ----------------------------------------------------------------------------
Chrome.BOOT_TIME = 4.4
Chrome.BOOT_ZOOM_END = 1.9          -- the zoom arrives
Chrome.BOOT_LINES = { 2.0, 3.2 }    -- the lines draw in over this window

-- The name as a constellation: each letter a list of strokes, each stroke a
-- list of stars in a unit box (x to the right, y down, height 1)
local GLYPHS = {
    P = { { { 0, 1 }, { 0, 0 }, { 0.5, 0 }, { 0.66, 0.13 }, { 0.66, 0.37 }, { 0.5, 0.5 }, { 0, 0.5 } } },
    O = { { { 0.17, 0 }, { 0.5, 0 }, { 0.68, 0.22 }, { 0.68, 0.78 }, { 0.5, 1 }, { 0.17, 1 }, { 0, 0.78 }, { 0, 0.22 }, { 0.17, 0 } } },
    C = { { { 0.66, 0.16 }, { 0.5, 0 }, { 0.17, 0 }, { 0, 0.22 }, { 0, 0.78 }, { 0.17, 1 }, { 0.5, 1 }, { 0.66, 0.84 } } },
    K = { { { 0, 0 }, { 0, 0.52 }, { 0, 1 } }, { { 0.64, 0 }, { 0, 0.52 } }, { { 0.24, 0.36 }, { 0.66, 1 } } },
    I = { { { 0, 0 }, { 0, 0.5 }, { 0, 1 } } },
    M = { { { 0, 1 }, { 0, 0 }, { 0.36, 0.56 }, { 0.72, 0 }, { 0.72, 1 } } },
    U = { { { 0, 0 }, { 0, 0.78 }, { 0.17, 1 }, { 0.5, 1 }, { 0.66, 0.78 }, { 0.66, 0 } } },
    S = { { { 0.66, 0.14 }, { 0.5, 0 }, { 0.17, 0 }, { 0, 0.16 }, { 0, 0.36 }, { 0.16, 0.5 }, { 0.5, 0.5 },
            { 0.66, 0.64 }, { 0.66, 0.86 }, { 0.5, 1 }, { 0.17, 1 }, { 0, 0.86 } } },
}
local GLYPH_W = { P = 0.66, O = 0.68, C = 0.66, K = 0.66, I = 0, M = 0.72, U = 0.66, S = 0.66 }
local TITLE = "POCKIMUSI"
local LETTER_H, LETTER_GAP = 58, 22           -- on screen, at the end of the zoom
local TITLE_Y = 196

-- Laid out once: the title's segments (screen space at the end of the zoom),
-- its unique stars, and the galaxy (world space)
local BOOT = nil
local function bootData()
    if BOOT then return BOOT end
    local B = { segs = {}, stars = {}, field = {} }
    -- the title, centred
    local total = 0
    for i = 1, #TITLE do
        total = total + GLYPH_W[TITLE:sub(i, i)] * LETTER_H + (i > 1 and LETTER_GAP or 0)
    end
    local x = 320 - total * 0.5
    local seen = {}
    local length = 0
    for i = 1, #TITLE do
        local ch = TITLE:sub(i, i)
        for _, stroke in ipairs(GLYPHS[ch]) do
            for k = 1, #stroke do
                local px, py = x + stroke[k][1] * LETTER_H, TITLE_Y + stroke[k][2] * LETTER_H
                local key = math_floor(px + 0.5) .. ":" .. math_floor(py + 0.5)
                if not seen[key] then
                    seen[key] = true
                    B.stars[#B.stars + 1] = { x = px, y = py, letter = i }
                end
                if k > 1 then
                    local qx, qy = x + stroke[k - 1][1] * LETTER_H, TITLE_Y + stroke[k - 1][2] * LETTER_H
                    local len = math.sqrt((px - qx) ^ 2 + (py - qy) ^ 2)
                    B.segs[#B.segs + 1] = { qx, qy, px, py, at = length, len = len }
                    length = length + len
                end
            end
        end
        x = x + GLYPH_W[ch] * LETTER_H + LETTER_GAP
    end
    B.length = length
    -- the galaxy: a bright core and two arms, seen tilted
    local seed = 11
    local function rnd()
        seed = (seed * 16807) % 2147483647
        return seed / 2147483647
    end
    local function gauss() return (rnd() + rnd() + rnd() - 1.5) * 0.8 end
    for _ = 1, 700 do
        local r = math.abs(gauss()) * 0.16
        local a = rnd() * 6.283
        B.field[#B.field + 1] = { x = math_cos(a) * r, y = math_sin(a) * r * 0.62, b = 0.6 + rnd() * 0.4 }
    end
    for arm = 0, 1 do
        for _ = 1, 1100 do
            local r = 0.08 + rnd() ^ 0.8 * 0.95
            local a = arm * math_pi + math.log(r) / 0.32 + gauss() * 0.35
            local sc = 0.03 + r * 0.07
            B.field[#B.field + 1] = { x = math_cos(a) * r + gauss() * sc, y = (math_sin(a) * r + gauss() * sc) * 0.62,
                                      b = 0.35 + rnd() * 0.65 }
        end
    end
    -- where the camera is heading: a spot on an arm
    B.tx, B.ty = 0.42, -0.2
    -- a local field round that spot at every scale, so stars keep streaming past
    for _ = 1, 150 do
        local d = 10 ^ (-2.1 + rnd() * 2.1)          -- 0.008 .. 1 world units away
        local a = rnd() * 6.283
        B.field[#B.field + 1] = { x = B.tx + math_cos(a) * d, y = B.ty + math_sin(a) * d * 0.8, b = 0.6 + rnd() * 0.4, near = true }
    end
    for i, f in ipairs(B.field) do f.ph = (i * 0.618) % 6.283 end
    BOOT = B
    return B
end

function Chrome:startBoot()
    self.bootStart = love.timer.getTime()
    self.bootDone = false
end

function Chrome:drawBoot()
    if self.bootDone then return end
    if not (self.mockOpt and self.mockOpt.BOOT == "ON") and not self.bootPreview then
        self.bootDone = true
        return
    end
    local now = love.timer.getTime()
    if not self.bootStart then self.bootStart = now end
    local e = now - self.bootStart
    if e > 0.3 then
        for _, b in ipairs(Input.BUTTON_LIST or {}) do
            if Input.pressed[b] then e = self.BOOT_TIME end
        end
    end
    if e >= self.BOOT_TIME then
        self.bootDone, self.bootPreview = true, false
        return
    end
    local C = Config.COLORS
    local lg = love.graphics
    local B = bootData()
    local out = (e > self.BOOT_TIME - 0.5) and ((self.BOOT_TIME - e) / 0.5) or 1
    local fadeIn = clamp(e / 0.35, 0, 1)

    -- the camera: log-zoom with a slow start and a slow arrival, drifting from
    -- the galaxy's centre to the target, rolling a little and settling level
    local zEnd = 14000
    local z0 = 300
    local u = clamp(e / self.BOOT_ZOOM_END, 0, 1)
    local s = u * u * (3 - 2 * u)                                -- smoothstep
    local s2 = s * s * (3 - 2 * s)                               -- softer still
    local z = z0 * (zEnd / z0) ^ s2
    -- the target's offset from the centre shrinks smoothly on screen
    local camX = B.tx - (1 - s) * B.tx * z0 / z
    local camY = B.ty - (1 - s) * B.ty * z0 / z
    local roll = (1 - s) * 0.5
    local cr, sr = math_cos(roll), math_sin(roll)
    -- the speed of the zoom, for the streaks
    local du = 0.012
    local u2 = clamp((e - du) / self.BOOT_ZOOM_END, 0, 1)
    local sp = u2 * u2 * (3 - 2 * u2); sp = sp * sp * (3 - 2 * sp)
    local zPrev = z0 * (zEnd / z0) ^ sp
    local streak = (z / zPrev - 1)                               -- 0 when still

    self:setColor(C.BG, out)
    lg.rectangle("fill", 0, 0, 640, 480)
    -- a faint glow of the galaxy's core while far away
    local glowA = (1 - s) * 0.14 * fadeIn * out
    if glowA > 0.002 then
        local gx, gy = 320 + (0 - camX) * z, 240 + (0 - camY) * z
        for r = 16, 1, -1 do
            lg.setColor(0.55, 0.5, 0.85, glowA * 0.35)
            lg.circle("fill", gx, gy, r * 0.016 * z)
        end
    end

    -- the stars: a point each, a streak when moving fast
    local pts, big = {}, {}
    lg.setLineWidth(1)
    for _, f in ipairs(B.field) do
        local wx, wy = f.x - camX, f.y - camY
        local x = 320 + (wx * cr - wy * sr) * z
        local y = 240 + (wx * sr + wy * cr) * z
        if x > -20 and x < 660 and y > -20 and y < 500 then
            local tw = 0.75 + 0.25 * math_sin(now * 2.3 + f.ph)
            local a = f.b * tw * fadeIn * out
            if f.b > 0.75 then big[#big + 1] = { x, y, 0.9, 0.93, 1.0, a }
            else pts[#pts + 1] = { x, y, 0.86, 0.9, 1.0, a } end
            if streak > 0.02 then
                local k = math_min(0.16, streak * 0.5)
                self:setColor(C.SILVER, a * 0.35)
                lg.line(x, y, 320 + (x - 320) * (1 - k), 240 + (y - 240) * (1 - k))
            end
        end
    end
    lg.setColor(1, 1, 1, 1)          -- per-point colours are multiplied by this
    lg.setPointSize(1.6)
    if #pts > 0 then lg.points(pts) end
    lg.setPointSize(2.4)
    if #big > 0 then lg.points(big) end
    lg.setPointSize(1)

    -- the title's stars arrive with the zoom: as points far from their places
    -- while the camera is still moving, then settled
    local arrive = clamp((e - self.BOOT_ZOOM_END * 0.55) / (self.BOOT_ZOOM_END * 0.45), 0, 1)
    local trackCols = { [1] = C.ORANGE, [4] = C.CYAN, [6] = C.VIOLET, [8] = C.MINT }
    local lineT = clamp((e - self.BOOT_LINES[1]) / (self.BOOT_LINES[2] - self.BOOT_LINES[1]), 0, 1)
    local drawn = lineT * B.length
    -- where each title star is now: its final place seen through the camera
    -- (they sit in world space at the target, scaled to the final zoom)
    local function place(px, py)
        local wx = (px - 320) / zEnd + B.tx - camX
        local wy = (py - 240) / zEnd + B.ty - camY
        return 320 + (wx * cr - wy * sr) * z, 240 + (wx * sr + wy * cr) * z
    end
    do
        -- the lines, letter by letter
        lg.setLineWidth(1.2)
        for _, sg in ipairs(B.segs) do
            local k = clamp((drawn - sg.at) / sg.len, 0, 1)
            if k > 0 then
                local ax, ay = place(sg[1], sg[2])
                local bx, by = place(sg[3], sg[4])
                self:setColor(C.SILVER, 0.7 * out)
                lg.line(ax, ay, ax + (bx - ax) * k, ay + (by - ay) * k)
            end
        end
        lg.setLineWidth(1)
        -- the stars, brightening as the lines reach them
        for i, st in ipairs(B.stars) do
            local x, y = place(st.x, st.y)
            local lit = lineT > 0 and 1 or 0.55
            local col = trackCols[st.letter] or C.TEXT
            if arrive > 0.02 then
                self:drawStarGlint(x, y, 1.5 + arrive * 3.5 + lit * 1.2, col, arrive * (0.55 + 0.45 * lit) * out)
            else
                local half = clamp((math.log(z / z0) / math.log(zEnd / z0) - 0.5) * 4, 0, 1)
                if half > 0 then
                    lg.setColor(0.9, 0.93, 1.0, 0.8 * half * out)
                    lg.setPointSize(2)
                    lg.points(x, y)
                    lg.setPointSize(1)
                end
            end
        end
    end

    -- underneath, once the name is drawn
    local subIn = clamp((e - self.BOOT_LINES[2] + 0.1) / 0.45, 0, 1)
    if subIn > 0 then
        local sub = "POCKET  -  MUSIC"
        lg.setFont(self.fontSmall)
        self:setColor(C.MUTED, subIn * out)
        lg.print(sub, math_floor(320 - self.fontSmall:getWidth(sub) * 0.5), TITLE_Y + LETTER_H + 34)
        self:setColor(C.SILVER, subIn * 0.4 * out)
        lg.line(250, TITLE_Y + LETTER_H + 60, 390, TITLE_Y + LETTER_H + 60)
        self:drawDiamond(320, TITLE_Y + LETTER_H + 60, 2.5, { C.SILVER[1], C.SILVER[2], C.SILVER[3], subIn * 0.8 * out })
    end
end


end
