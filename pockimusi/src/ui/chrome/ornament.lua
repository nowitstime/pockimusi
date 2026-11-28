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
-- Boot screen: the sky fades in, four stars in the tracks' colours join a
-- constellation, the name appears, then it fades into the app
-- ----------------------------------------------------------------------------
Chrome.BOOT_TIME = 2.6

local SKY = nil
local function skyStars()
    if SKY then return SKY end
    SKY = {}
    local seed = 7
    local function rnd()
        seed = (seed * 16807) % 2147483647
        return seed / 2147483647
    end
    for i = 1, 90 do
        SKY[i] = { x = rnd() * 640, y = rnd() * 480, r = 0.6 + rnd() * 1.2, ph = rnd() * 6.28, sp = 0.6 + rnd() * 1.4 }
    end
    return SKY
end

-- The constellation: an arch of stars over the name, the four track colours
-- among them
local CONST = {
    { 214, 214 }, { 246, 172 }, { 288, 146 }, { 320, 136 }, { 352, 146 }, { 394, 172 }, { 426, 214 },
}

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
    -- any press after the first moment skips it
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
    local out = (e > self.BOOT_TIME - 0.45) and ((self.BOOT_TIME - e) / 0.45) or 1
    local function ease(a, b) return clamp((e - a) / (b - a), 0, 1) end

    -- the night
    self:setColor(C.BG, out)
    lg.rectangle("fill", 0, 0, 640, 480)
    for r = 300, 60, -30 do
        lg.setColor(0.14, 0.12, 0.30, 0.035 * out)
        lg.circle("fill", 320, 230, r)
    end
    local skyIn = ease(0, 0.6)
    for _, s in ipairs(skyStars()) do
        local tw = 0.55 + 0.45 * math_sin(now * s.sp + s.ph)
        lg.setColor(0.85, 0.9, 1.0, skyIn * tw * 0.7 * out)
        lg.circle("fill", s.x, s.y, s.r)
    end

    -- the constellation draws in, star to star
    local trackCols = { C.ORANGE, C.CYAN, C.VIOLET, C.MINT }
    local lineIn = ease(0.35, 1.25)
    local segs = #CONST - 1
    lg.setLineWidth(1)
    for i = 1, segs do
        local a = clamp(lineIn * segs - (i - 1), 0, 1)
        if a > 0 then
            local p, q = CONST[i], CONST[i + 1]
            self:setColor(C.SILVER, 0.55 * out)
            lg.line(p[1], p[2], p[1] + (q[1] - p[1]) * a, p[2] + (q[2] - p[2]) * a)
        end
    end
    for i, p in ipairs(CONST) do
        local a = clamp(lineIn * segs - (i - 1) + 1, 0, 1)
        if a > 0 then
            -- the 2nd, 3rd, 5th and 6th stars wear the four tracks' colours
            local ci = ({ [2] = 1, [3] = 2, [5] = 3, [6] = 4 })[i]
            local col = ci and trackCols[ci] or C.TEXT
            self:drawStarGlint(p[1], p[2], (i == 4) and 9 or 5, col, a * out)
        end
    end
    -- the crown star bursts as the name appears
    local burst = ease(1.15, 1.6)
    if burst > 0 and burst < 1 then
        self:setColor(C.TEXT, (1 - burst) * 0.6 * out)
        lg.circle("line", 320, 136, 9 + burst * 26)
    end

    -- the name, and what it means
    local nameIn = ease(1.15, 1.75)
    local name = "P O C K I M U S I"
    lg.setFont(self.fontHuge)
    self:setColor(C.TEXT, nameIn * out)
    lg.print(name, math_floor(320 - self.fontHuge:getWidth(name) * 0.5), 228 + (1 - nameIn) * 6)
    local subIn = ease(1.5, 2.0)
    local sub = "POCKET  -  MUSIC"
    lg.setFont(self.fontSmall)
    self:setColor(C.MUTED, subIn * out)
    lg.print(sub, math_floor(320 - self.fontSmall:getWidth(sub) * 0.5), 274)
    self:setColor(C.SILVER, subIn * 0.4 * out)
    lg.line(230, 300, 410, 300)
    self:drawDiamond(320, 300, 2.5, { C.SILVER[1], C.SILVER[2], C.SILVER[3], subIn * 0.8 * out })
end

end
