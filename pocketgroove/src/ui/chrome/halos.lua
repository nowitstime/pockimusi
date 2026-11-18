-- ============================================================================
-- src/ui/chrome/halos.lua — The stage's mood: each instrument's dark stage,
-- one big flat shape behind it (the sky), and the ornament round both zones
-- (the halo). The star D-pad and the face ring are the same on every
-- instrument; the halo is what tells them apart, from pointy (drums) to
-- soft (pad). Flat fills only: no gradients, no glows.
-- (part of src/ui/chrome.lua: adds methods to the Chrome table)
-- ============================================================================

local Config      = require("src.config")
local Display     = require("src.ui.display")

local math_floor = math.floor
local math_sin   = math.sin
local math_cos   = math.cos
local math_pi    = math.pi
local rad        = math.rad

return function(Chrome)

-- Which halo each instrument wears (by instrument id)
Chrome.HALOS = {
    drums = "starburst", hands = "starburst",
    lead = "northstar", slide = "comets", strum = "garland",
    harp = "constellation", chords = "tiara",
    dial = "bezel",
    bass = "crescent",
    pad = "clouds",
}

Chrome.STAGE_SHADE = 0.13      -- how much of the colour the stage takes

local function pol(cx, cy, deg, r)
    local a = rad(deg)
    return cx + math_cos(a) * r, cy + math_sin(a) * r
end

-- A filled star with n points (n=4 is a sparkle, n=5 a star), as a fan from
-- the centre so the concave shape fills cleanly
function Chrome:fillStar(cx, cy, r, n, inner, rotDeg, col)
    self:setColor(col)
    local pts = {}
    for i = 0, 2 * n - 1 do
        local rr = (i % 2 == 0) and r or r * inner
        local x, y = pol(cx, cy, (rotDeg or -90) + i * 180 / n, rr)
        pts[#pts + 1] = { x, y }
    end
    for i = 1, #pts do
        local a, b = pts[i], pts[i % #pts + 1]
        love.graphics.polygon("fill", cx, cy, a[1], a[2], b[1], b[2])
    end
end

-- A tilted ellipse outline (a planet's ring)
local function ellipseLine(cx, cy, rx, ry, rotDeg)
    local pts = {}
    local c, s = math_cos(rad(rotDeg)), math_sin(rad(rotDeg))
    for i = 0, 31 do
        local a = i * math_pi / 16
        local x, y = math_cos(a) * rx, math_sin(a) * ry
        pts[#pts + 1] = cx + x * c - y * s
        pts[#pts + 1] = cy + x * s + y * c
    end
    love.graphics.polygon("line", pts)
end

-- A crescent: a disc with a disc of the background cut out of it
local function crescent(self, cx, cy, r, col, cut, dx, dy, k)
    self:setColor(col)
    love.graphics.circle("fill", cx, cy, r)
    self:setColor(cut)
    love.graphics.circle("fill", cx + r * dx, cy + r * dy, r * k)
end

-- A flat cloud: a rounded base with puffs on top
local function cloud(self, cx, cy, w, col)
    local h = w * 0.32
    self:setColor(col)
    love.graphics.rectangle("fill", cx - w / 2, cy - h * 0.2, w, h * 0.7, h * 0.35, h * 0.35)
    for _, p in ipairs({ { -0.3, 0.22 }, { -0.08, 0.32 }, { 0.18, 0.26 }, { 0.36, 0.16 } }) do
        love.graphics.circle("fill", cx + p[1] * w, cy - p[2] * w * 0.25, p[2] * w * 0.5)
    end
end

-- A moon phase, waxing: f = 0 new, 0.5 half, 1 full
function Chrome:drawMoonPhase(x, y, r, f, col, base)
    if base then
        self:setColor(base)
        love.graphics.circle("fill", x, y, r)
    end
    self:setColor(col)
    love.graphics.circle("line", x, y, r)
    if f >= 0.98 then
        love.graphics.circle("fill", x, y, r)
    elseif f > 0.02 then
        local k, n = 1 - 2 * f, 10
        for i = 0, n - 1 do
            local a0 = -math_pi * 0.5 + math_pi * i / n
            local a1 = -math_pi * 0.5 + math_pi * (i + 1) / n
            local c0, s0, c1, s1 = math_cos(a0), math_sin(a0), math_cos(a1), math_sin(a1)
            love.graphics.polygon("fill", x + c0 * r, y + s0 * r, x + c1 * r, y + s1 * r,
                x + c1 * r * k, y + s1 * r, x + c0 * r * k, y + s0 * r)
        end
    end
end

-- ---------------------------------------------------------------------------
-- HALOS: one zone's ornament, centred on (cx, cy)
-- ---------------------------------------------------------------------------
local H = {}

-- POINTIEST: sixteen slim rays set between the label points, long and short
-- alternating, standing on a fine ring; a dot past each long tip
function H.starburst(self, cx, cy, col, shade)
    self:setColor(shade(col, 0.55))
    love.graphics.circle("line", cx, cy, 76)
    for i = 0, 15 do
        local a = 11.25 + i * 22.5
        local long = (i % 2 == 0)
        local r1, w = long and 98 or 87, long and 3.2 or 2.4
        local x0, y0 = pol(cx, cy, a - w, 77)
        local x1, y1 = pol(cx, cy, a + w, 77)
        local tx, ty = pol(cx, cy, a, r1)
        self:setColor(long and col or shade(col, 0.55))
        love.graphics.polygon("fill", x0, y0, tx, ty, x1, y1)
        if long then
            local dx, dy = pol(cx, cy, a, r1 + 6)
            love.graphics.circle("fill", dx, dy, 1.6)
        end
    end
end

-- POINTY: a tall four-point star frames the zone; small stars on the diagonals
function H.northstar(self, cx, cy, col, shade)
    self:fillStar(cx, cy, 104, 4, 0.2, -90, shade(col, 0.32))
    self:setColor(col)
    local pts = {}
    for i = 0, 7 do
        local x, y = pol(cx, cy, -90 + i * 45, (i % 2 == 0) and 104 or 20.8)
        pts[#pts + 1] = x
        pts[#pts + 1] = y
    end
    love.graphics.polygon("line", pts)
    self:setColor(shade(col, 0.45))
    love.graphics.circle("line", cx, cy, 78)
    for _, a in ipairs({ -45, 45, 135, 225 }) do
        local x, y = pol(cx, cy, a, 88)
        self:fillStar(x, y, 7, 5, 0.45, -90, col)
        local x2, y2 = pol(cx, cy, a, 100)
        self:setColor(shade(col, 0.7))
        love.graphics.circle("fill", x2, y2, 1.8)
    end
end

-- A ring of five-point stars threaded on a fine line
function H.garland(self, cx, cy, col, shade)
    self:setColor(shade(col, 0.45))
    love.graphics.circle("line", cx, cy, 86)
    for i = 0, 15 do
        local a = -90 + i * 22.5
        local x, y = pol(cx, cy, a, 86)
        if i % 4 == 0 then
            self:fillStar(x, y, 10, 5, 0.45, a, col)
        elseif i % 2 == 0 then
            self:fillStar(x, y, 6, 5, 0.45, a, shade(col, 0.8))
        else
            self:setColor(shade(col, 0.7))
            love.graphics.circle("fill", x, y, 1.8)
        end
    end
end

-- Moving: shooting stars on the orbit, tails behind them
function H.comets(self, cx, cy, col, shade)
    self:setColor(shade(col, 0.3))
    love.graphics.circle("line", cx, cy, 82)
    for _, c in ipairs({ { -60, 70 }, { 120, 55 }, { 30, 30 } }) do
        for j = 0, 9 do
            local x, y = pol(cx, cy, c[1] - j * c[2] / 10, 82)
            self:setColor(shade(col, 1 - j / 10 * 0.8))
            love.graphics.circle("fill", x, y, 3.2 * (1 - j / 10) + 0.6)
        end
        local x, y = pol(cx, cy, c[1], 82)
        self:fillStar(x, y, 8, 5, 0.45, -90, col)
    end
end

-- SPARKLY: a constellation, stars joined by fine lines round the zone
local CONSTELLATION = { { -150, 84 }, { -118, 92 }, { -80, 86 }, { -40, 94 }, { -8, 84 }, { 30, 92 },
                        { 64, 86 }, { 102, 94 }, { 140, 86 }, { 176, 92 }, { 210, 84 } }
function H.constellation(self, cx, cy, col, shade)
    local pts = {}
    for _, p in ipairs(CONSTELLATION) do
        local x, y = pol(cx, cy, p[1], p[2])
        pts[#pts + 1] = x
        pts[#pts + 1] = y
    end
    self:setColor(shade(col, 0.45))
    love.graphics.line(pts)
    for i = 1, #CONSTELLATION do
        local big = ((i - 1) % 3 == 0)
        self:drawStarGlint(pts[i * 2 - 1], pts[i * 2], big and 6 or 3.5, big and col or shade(col, 0.75), 1.0)
    end
end

-- REGAL: a tiara over the zone, jewels on its points, short sun rays at its feet
function H.tiara(self, cx, cy, col, shade)
    love.graphics.setLineWidth(2)
    self:setColor(shade(col, 0.5))
    for i = 0, 23 do
        local a = 180 + i * (180 / 23)
        if not (a > 200 and a < 340) then
            local x0, y0 = pol(cx, cy, a, 76)
            local x1, y1 = pol(cx, cy, a, 82)
            love.graphics.line(x0, y0, x1, y1)
        end
    end
    love.graphics.setLineWidth(1)
    local outer, inner = {}, {}
    for i = 0, 10 do
        local r = (i % 2 == 0) and 84 or ((i == 5) and 106 or 97)
        outer[i] = { pol(cx, cy, -150 + i * 12, r) }
        inner[i] = { pol(cx, cy, -150 + i * 12, 78) }
    end
    self:setColor(shade(col, 0.45))
    for i = 0, 9 do
        local o0, o1, i0, i1 = outer[i], outer[i + 1], inner[i], inner[i + 1]
        love.graphics.polygon("fill", o0[1], o0[2], o1[1], o1[2], i1[1], i1[2])
        love.graphics.polygon("fill", o0[1], o0[2], i1[1], i1[2], i0[1], i0[2])
    end
    local line = {}
    for i = 0, 10 do line[#line + 1] = outer[i][1]; line[#line + 1] = outer[i][2] end
    for i = 10, 0, -1 do line[#line + 1] = inner[i][1]; line[#line + 1] = inner[i][2] end
    self:setColor(col)
    love.graphics.polygon("line", line)
    for _, i in ipairs({ 1, 3, 5, 7, 9 }) do
        self:drawDiamond(outer[i][1], outer[i][2], (i == 5) and 4.5 or 3, col)
    end
    local x, y = pol(cx, cy, -90, 90)
    self:fillStar(x, y, 6, 5, 0.45, -90, Config.COLORS.BG)
end

-- MECHANICAL: a clock bezel, a little ringed planet and a moon
function H.bezel(self, cx, cy, col, shade)
    for i = 0, 59 do
        local long = (i % 5 == 0)
        local x0, y0 = pol(cx, cy, i * 6, 80)
        local x1, y1 = pol(cx, cy, i * 6, long and 88 or 84)
        love.graphics.setLineWidth(long and 1.5 or 1)
        self:setColor(long and col or shade(col, 0.45))
        love.graphics.line(x0, y0, x1, y1)
    end
    love.graphics.setLineWidth(1.5)
    local px, py = pol(cx, cy, -140, 96)
    self:setColor(col)
    love.graphics.circle("fill", px, py, 7)
    self:setColor(Config.COLORS.TEXT)
    ellipseLine(px, py, 13, 4, -20)
    love.graphics.setLineWidth(1)
    local qx, qy = pol(cx, cy, 40, 98)
    self:setColor(shade(col, 0.7))
    love.graphics.circle("fill", qx, qy, 3)
end

-- ROUND, HEAVY: a big crescent cups the zone, small moons orbit it
function H.crescent(self, cx, cy, col, shade)
    crescent(self, cx - 6, cy, 96, shade(col, 0.38), shade(col, Chrome.STAGE_SHADE), 0.2, 0.0, 0.9)
    for i, f in ipairs({ 0.15, 0.35, 0.65, 0.85 }) do
        local x, y = pol(cx, cy, 200 + (i - 1) * 28, 88)
        self:drawMoonPhase(x, y, 6, f, col, shade(col, 0.2))
    end
end

-- SOFTEST: cloud banks hug the zone, no points at all
function H.clouds(self, cx, cy, col, shade)
    cloud(self, cx - 52, cy + 78, 96, shade(col, 0.38))
    cloud(self, cx + 50, cy + 84, 110, shade(col, 0.3))
    cloud(self, cx + 58, cy - 82, 72, shade(col, 0.3))
    cloud(self, cx - 64, cy - 72, 58, shade(col, 0.24))
    self:setColor(col)
    for _, p in ipairs({ { -86, -20 }, { 90, 10 }, { 20, -96 } }) do
        love.graphics.circle("fill", cx + p[1], cy + p[2], 2.5)
    end
end

-- ---------------------------------------------------------------------------
-- SKY: one big, flat shape behind the whole stage
-- ---------------------------------------------------------------------------
local SKY = {}

function SKY.starburst(self, col, k1, k2)
    self:fillStar(320, 200, 150, 8, 0.38, -67.5, k2)
end

function SKY.northstar(self, col, k1, k2)
    self:drawStarGlint(320, 200, 150, k2, 1.0)
    self:drawStarGlint(320, 200, 70, k1, 1.0)
end

function SKY.garland(self, col, k1, k2)
    self:fillStar(320, 205, 120, 5, 0.42, -90, k2)
end

function SKY.comets(self, col, k1, k2)
    self:setColor(k2)
    for j = 0, 17 do
        love.graphics.circle("fill", 140 + j * 22, 300 - j * 11, 26 - j * 1.2)
    end
    self:fillStar(540, 96, 34, 5, 0.45, -90, k1)
end

function SKY.constellation(self, col, k1, k2)
    for _, s in ipairs({ { 250, 120, 28 }, { 400, 250, 40 }, { 320, 300, 16 }, { 190, 270, 18 }, { 450, 110, 20 } }) do
        self:drawStarGlint(s[1], s[2], s[3], k1, 1.0)
    end
end

function SKY.tiara(self, col, k1, k2)
    self:setColor(k2)
    love.graphics.circle("fill", 320, 330, 150)
    for i = 0, 11 do
        local a = 180 + i * 15
        local x0, y0 = pol(320, 330, a - 4, 160)
        local x1, y1 = pol(320, 330, a + 4, 160)
        local tx, ty = pol(320, 330, a, 205)
        love.graphics.polygon("fill", x0, y0, tx, ty, x1, y1)
    end
end

function SKY.bezel(self, col, k1, k2)
    self:setColor(k2)
    love.graphics.circle("fill", 320, 220, 110)
    self:setColor(k1)
    love.graphics.setLineWidth(14)
    ellipseLine(320, 220, 200, 40, -14)
    love.graphics.setLineWidth(1)
end

function SKY.crescent(self, col, k1, k2, stage)
    crescent(self, 320, 230, 170, k2, stage, 0.32, -0.15, 0.86)
end

function SKY.clouds(self, col, k1, k2)
    cloud(self, 240, 300, 300, k2)
    cloud(self, 430, 280, 260, k1)
end

-- The halo an instrument wears, or nil
function Chrome:haloFor(def)
    return def and self.HALOS[def.id]
end

-- The playing stage: the dark shade, the sky, then the halo round both zones,
-- all kept inside the stage (above the footer). Returns true when a halo was
-- drawn (the face ring then leaves out its plain compass arcs).
function Chrome:drawStageMood(def, col, lx, ly, rx, ry)
    local shade = Config.shade
    local stage = shade(col, self.STAGE_SHADE)
    self:setColor(stage)
    love.graphics.rectangle("fill", 9, 51, 622, 304, 6, 6)
    local halo = self:haloFor(def)
    if not halo then return false end
    local clip = Display:pushClip(9, 51, 622, 271)
    SKY[halo](self, col, shade(col, 0.24), shade(col, 0.19), stage)
    H[halo](self, lx, ly, col, shade)
    H[halo](self, rx, ry, col, shade)
    Display:popClip(clip)
    return true
end

end
