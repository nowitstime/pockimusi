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
Chrome.BOOT_TIME = 4.2
Chrome.BOOT_ZOOM = { 0.45, 1.75 }   -- the jump: from a held view of the galaxy to the stop
Chrome.BOOT_LINES = { 1.95, 3.05 }  -- the lines draw in over this window

-- The name as a constellation: each letter a list of strokes, each stroke a
-- list of stars in a unit box (x to the right, y down, height 1). The stars
-- are then nudged off the grid and given uneven brightness, as real stars are.
local GLYPHS = {
    P = { { { 0, 1 }, { 0.04, 0.48 }, { 0, 0 }, { 0.52, 0.04 }, { 0.66, 0.26 }, { 0.48, 0.5 }, { 0.04, 0.48 } } },
    O = { { { 0.2, 0 }, { 0.6, 0.12 }, { 0.68, 0.62 }, { 0.42, 1 }, { 0.06, 0.82 }, { 0, 0.3 }, { 0.2, 0 } } },
    C = { { { 0.66, 0.12 }, { 0.3, 0 }, { 0.02, 0.3 }, { 0.06, 0.78 }, { 0.36, 1 }, { 0.68, 0.86 } } },
    K = { { { 0, 0 }, { 0.02, 0.52 }, { 0, 1 } }, { { 0.62, 0.02 }, { 0.02, 0.52 }, { 0.66, 1 } } },
    I = { { { 0, 0 }, { 0.03, 0.46 }, { 0, 1 } } },
    M = { { { 0, 1 }, { 0.04, 0 }, { 0.36, 0.6 }, { 0.68, 0.02 }, { 0.72, 1 } } },
    U = { { { 0, 0 }, { 0.04, 0.72 }, { 0.32, 1 }, { 0.62, 0.74 }, { 0.66, 0 } } },
    S = { { { 0.64, 0.1 }, { 0.3, 0 }, { 0.02, 0.22 }, { 0.32, 0.5 }, { 0.64, 0.74 }, { 0.36, 1 }, { 0, 0.88 } } },
}
local GLYPH_W = { P = 0.66, O = 0.68, C = 0.68, K = 0.66, I = 0.03, M = 0.72, U = 0.66, S = 0.64 }
local TITLE = "POCKIMUSI"
local LETTER_H, LETTER_GAP = 58, 22           -- on screen, at the end of the zoom
local TITLE_Y = 192
local Z0, ZEND = 300, 14000                   -- the camera's zoom: whole galaxy, then the name

-- Laid out once: the title's stars and lines (screen space at the end of the
-- zoom), the stars round them, and the galaxy (world space)
local BOOT = nil
local function bootData()
    if BOOT then return BOOT end
    local B = { segs = {}, stars = {}, near = {}, field = {}, rings = { 0.32, 0.62, 0.95 } }
    local seed = 23
    local function rnd()
        seed = (seed * 16807) % 2147483647
        return seed / 2147483647
    end
    -- the title, centred, each star nudged and given a magnitude
    local total = 0
    for i = 1, #TITLE do
        total = total + GLYPH_W[TITLE:sub(i, i)] * LETTER_H + (i > 1 and LETTER_GAP or 0)
    end
    local x = 320 - total * 0.5
    local index, length = {}, 0
    for i = 1, #TITLE do
        local ch = TITLE:sub(i, i)
        local base = (rnd() - 0.5) * 6                 -- letters don't sit on one line either
        for _, stroke in ipairs(GLYPHS[ch]) do
            local prev
            for k = 1, #stroke do
                local key = i .. ":" .. stroke[k][1] .. ":" .. stroke[k][2]
                local st = index[key]
                if not st then
                    st = { x = x + stroke[k][1] * LETTER_H + (rnd() - 0.5) * 6,
                           y = TITLE_Y + base + stroke[k][2] * LETTER_H + (rnd() - 0.5) * 6,
                           mag = 0.55 + rnd() * 0.45, letter = i, lit = math.huge }
                    index[key] = st
                    B.stars[#B.stars + 1] = st
                end
                if prev then
                    local len = math.sqrt((st.x - prev.x) ^ 2 + (st.y - prev.y) ^ 2)
                    B.segs[#B.segs + 1] = { a = prev, b = st, at = length, len = len }
                    prev.lit = math_min(prev.lit, length)
                    st.lit = math_min(st.lit, length + len)
                    length = length + len
                else
                    st.lit = math_min(st.lit, length)
                end
                prev = st
            end
        end
        x = x + GLYPH_W[ch] * LETTER_H + LETTER_GAP
    end
    B.length = length
    -- the stars round the name, looking just like its own until the lines come
    for n = 1, 170 do
        -- a third of them through the name's band, so it hides in the field
        local sx, sy = rnd() * 640, (n % 3 == 0) and (TITLE_Y - 12 + rnd() * (LETTER_H + 24)) or rnd() * 480
        local ok = true
        for _, st in ipairs(B.stars) do
            if math.abs(st.x - sx) < 9 and math.abs(st.y - sy) < 9 then ok = false break end
        end
        if ok then B.near[#B.near + 1] = { x = sx, y = sy, mag = 0.3 + rnd() * 0.7 } end
    end
    -- the galaxy, drawn as a clean graphic: a tight core and two arms of
    -- evenly spaced points along log spirals, seen tilted
    for _ = 1, 160 do
        local r = (rnd() ^ 2) * 0.13
        local a = rnd() * 6.283
        B.field[#B.field + 1] = { x = math_cos(a) * r, y = math_sin(a) * r * 0.62, b = 0.7 + rnd() * 0.3 }
    end
    for arm = 0, 1 do
        local n = 340
        for i = 1, n do
            local f = i / n
            local r = 0.1 + f * 0.9
            local a = arm * math_pi + math.log(r) / 0.3
            local w = 0.012 + f * 0.03                   -- the arm widens outwards
            local off = (rnd() - 0.5) * 2 * w
            B.field[#B.field + 1] = { x = math_cos(a) * (r + off), y = math_sin(a) * (r + off) * 0.62,
                                      b = 0.9 - f * 0.5 }
        end
    end
    -- where the camera is heading: a spot on an arm
    B.tx, B.ty = 0.42, -0.2
    -- stars at every scale round that spot, to stream past during the jump
    for _ = 1, 260 do
        local d = 10 ^ (-1.6 + rnd() * 1.6)          -- 0.025 .. 1 world units away
        local a = rnd() * 6.283
        B.field[#B.field + 1] = { x = B.tx + math_cos(a) * d, y = B.ty + math_sin(a) * d * 0.8, b = 0.6 + rnd() * 0.4 }
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
    local fadeIn = clamp(e / 0.3, 0, 1)

    -- the jump: a held view, then a sharp acceleration and a sudden stop
    local z0, zEnd = Z0, ZEND
    local function progress(t)
        local u = clamp((t - self.BOOT_ZOOM[1]) / (self.BOOT_ZOOM[2] - self.BOOT_ZOOM[1]), 0, 1)
        -- slow in, very fast through the middle, a short brake at the end
        local k = 9
        local lo, hi = 1 / (1 + math.exp(k * 0.5)), 1 / (1 + math.exp(-k * 0.5))
        return (1 / (1 + math.exp(-k * (u - 0.5))) - lo) / (hi - lo)
    end
    local s = progress(e)
    local z = z0 * (zEnd / z0) ^ s
    local zPrev = z0 * (zEnd / z0) ^ progress(e - 1 / 60)
    local speed = z / zPrev - 1                                  -- 0 when still
    local camX = B.tx - (1 - s) * B.tx * z0 / z
    local camY = B.ty - (1 - s) * B.ty * z0 / z
    local roll = (1 - s) * 0.35
    local cr, sr = math_cos(roll), math_sin(roll)
    local function toScreen(wx, wy)
        wx, wy = wx - camX, wy - camY
        return 320 + (wx * cr - wy * sr) * z, 240 + (wx * sr + wy * cr) * z
    end
    -- where the target sits on screen (the jump's vanishing point)
    local vx, vy = toScreen(B.tx, B.ty)

    self:setColor(C.BG, out)
    lg.rectangle("fill", 0, 0, 640, 480)

    -- the galaxy's graphic: thin orbit ellipses and a crisp core, fading as we leave
    local far = (1 - s) ^ 2 * fadeIn * out
    if far > 0.01 then
        local gx, gy = toScreen(0, 0)
        lg.setLineWidth(1)
        for i, r in ipairs(B.rings) do
            lg.setColor(0.7, 0.75, 1.0, far * (0.16 - i * 0.03))
            lg.push()
            lg.translate(gx, gy)
            lg.rotate(roll)
            lg.ellipse("line", 0, 0, r * z, r * z * 0.62, 64)
            lg.pop()
        end
        for r = 8, 1, -1 do
            lg.setColor(0.6, 0.55, 0.95, far * 0.05)
            lg.circle("fill", gx, gy, r * 0.012 * z)
        end
        self:drawStarGlint(gx, gy, 9, C.TEXT, far)
    end

    -- the stars: points, and during the jump, long streaks back towards the
    -- vanishing point (the faster, the longer)
    local warp = clamp(speed * 9, 0, 1)
    local pts, big = {}, {}
    lg.setLineWidth(1)
    for _, f in ipairs(B.field) do
        local x, y = toScreen(f.x, f.y)
        if x > -40 and x < 680 and y > -40 and y < 520 then
            local a = f.b * (0.8 + 0.2 * math_sin(now * 2.3 + f.ph)) * fadeIn * out
            if warp > 0.12 then
                local k = math_min(0.85, speed * 6)
                self:setColor(C.SILVER, a * (0.18 + warp * 0.32))
                lg.line(x, y, vx + (x - vx) * (1 - k), vy + (y - vy) * (1 - k))
            end
            if f.b > 0.8 then big[#big + 1] = { x, y, 0.92, 0.94, 1.0, a }
            else pts[#pts + 1] = { x, y, 0.86, 0.9, 1.0, a } end
        end
    end
    lg.setColor(1, 1, 1, 1)          -- per-point colours are multiplied by this
    lg.setPointSize(1.5)
    if #pts > 0 then lg.points(pts) end
    lg.setPointSize(2.3)
    if #big > 0 then lg.points(big) end
    lg.setPointSize(1)
    -- a brief brightening at the vanishing point at full speed
    if warp > 0.05 then
        for r = 6, 1, -1 do
            lg.setColor(0.85, 0.9, 1.0, warp * 0.05 * out)
            lg.circle("fill", vx, vy, r * 14)
        end
    end

    -- the last field: the name's stars and the ones round them, all alike,
    -- arriving with the stop (they sit in world space at the target)
    local arrive = clamp((s - 0.86) / 0.14, 0, 1)
    local function place(px, py)
        return toScreen((px - 320) / zEnd + B.tx, (py - 240) / zEnd + B.ty)
    end
    local lineT = clamp((e - self.BOOT_LINES[1]) / (self.BOOT_LINES[2] - self.BOOT_LINES[1]), 0, 1)
    local drawn = lineT * B.length
    if arrive > 0 then
        local starPts = {}
        for _, st in ipairs(B.near) do
            local x, y = place(st.x, st.y)
            local tw = 0.8 + 0.2 * math_sin(now * 2 + st.x)
            starPts[#starPts + 1] = { x, y, 0.88, 0.92, 1.0, st.mag * tw * arrive * out }
        end
        lg.setColor(1, 1, 1, 1)
        lg.setPointSize(2)
        lg.points(starPts)
        lg.setPointSize(1)
        -- the lines, letter by letter
        lg.setLineWidth(1.1)
        for _, sg in ipairs(B.segs) do
            local k = clamp((drawn - sg.at) / sg.len, 0, 1)
            if k > 0 then
                local ax, ay = place(sg.a.x, sg.a.y)
                local bx, by = place(sg.b.x, sg.b.y)
                self:setColor(C.SILVER, 0.6 * out)
                lg.line(ax, ay, ax + (bx - ax) * k, ay + (by - ay) * k)
            end
        end
        lg.setLineWidth(1)
        -- the name's stars: plain points like the rest until a line reaches
        -- them; then they brighten into glints (P, K, M, S in the tracks' colours)
        local trackCols = { [1] = C.ORANGE, [4] = C.CYAN, [6] = C.VIOLET, [8] = C.MINT }
        for _, st in ipairs(B.stars) do
            local x, y = place(st.x, st.y)
            local lit = clamp((drawn - st.lit) / 12, 0, 1)
            if lit > 0 then
                local col = trackCols[st.letter] or C.TEXT
                self:drawStarGlint(x, y, 2 + st.mag * 3 * lit, col, (0.5 + 0.5 * lit) * out)
            else
                lg.setColor(0.88, 0.92, 1.0, st.mag * arrive * out)
                lg.setPointSize(2)
                lg.points(x, y)
                lg.setPointSize(1)
            end
        end
    end

    -- underneath, once the name is drawn
    local subIn = clamp((e - self.BOOT_LINES[2] + 0.1) / 0.45, 0, 1)
    if subIn > 0 then
        local sub = "POCKET  -  MUSIC"
        lg.setFont(self.fontSmall)
        self:setColor(C.MUTED, subIn * out)
        lg.print(sub, math_floor(320 - self.fontSmall:getWidth(sub) * 0.5), TITLE_Y + LETTER_H + 38)
        self:setColor(C.SILVER, subIn * 0.4 * out)
        lg.line(250, TITLE_Y + LETTER_H + 64, 390, TITLE_Y + LETTER_H + 64)
        self:drawDiamond(320, TITLE_Y + LETTER_H + 64, 2.5, { C.SILVER[1], C.SILVER[2], C.SILVER[3], subIn * 0.8 * out })
    end
end


end
