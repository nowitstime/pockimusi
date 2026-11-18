-- ============================================================================
-- src/ui/chrome/panels.lua — Small stage panels: Dial, Rail (Slide), Valves
-- (part of src/ui/chrome.lua: adds methods to the Chrome table)
-- ============================================================================

local Config      = require("src.config")
local Theory      = require("src.theory")
local Input       = require("src.input")
local Synth       = require("src.synth")
local Looper      = require("src.looper")
local Instruments = require("src.instruments")
local Modes       = require("src.modes")
local Harmony     = require("src.harmony")
local Display     = require("src.ui.display")

local clamp      = Config.clamp
local math_floor = math.floor
local math_min   = math.min
local math_max   = math.max
local math_sin   = math.sin
local math_cos   = math.cos
local math_abs   = math.abs
local math_pi    = math.pi
local Text       = require("src.ui.chrome.text")
local printRight, printCentre = Text.printRight, Text.printCentre

return function(Chrome)

-- ---------------------------------------------------------------------------
-- DIAL panel: the dial (its 8 positions where the buttons are: 1 bottom,
-- 3 right, 5 top, 7 left), a needle to the thumb, a lit arc for the roll
-- just made; beside it the 8 notes it walks, the sounding one lit.
-- def:getPanel(state) -> { pos, trailFrom, trailAlpha, notes = { name x8 }, lit, octave }
-- ---------------------------------------------------------------------------
function Chrome:drawPanel_dial(def, state, col, ox, oy, ow, oh)
    local C = Config.COLORS
    local p = def:getPanel(state)
    self:drawSunkenPanel(ox, oy, ow, oh)
    local cx, cy, r = ox + 26, oy + oh * 0.5, 13
    local function ang(i) return math_pi * 0.5 - (i - 1) * math_pi * 0.25 end
    self:setColor(C.GRID)
    love.graphics.circle("line", cx, cy, r)
    if p.trailFrom and p.pos and p.trailAlpha > 0 then
        -- the roll, the short way round
        local a1, a2 = ang(p.trailFrom), ang(p.pos)
        local d = (a2 - a1 + math_pi) % (2 * math_pi) - math_pi
        self:setColor(col, 0.7 * p.trailAlpha)
        love.graphics.setLineWidth(2)
        love.graphics.arc("line", "open", cx, cy, r, a1, a1 + d, 12)
        love.graphics.setLineWidth(1)
    end
    love.graphics.setFont(self.fontTiny)
    for i = 1, 8 do
        local a = ang(i)
        local on = (p.pos == i)
        self:setColor(on and C.TEXT or (p.trailFrom == i and p.trailAlpha > 0 and col or C.MUTED))
        love.graphics.circle("fill", cx + math_cos(a) * r, cy + math_sin(a) * r, on and 3 or 1.6)
        self:setColor(on and C.TEXT or C.DIM)
        printCentre(self, self.fontTiny, tostring(i), cx + math_cos(a) * (r + 7), math_floor(cy + math_sin(a) * (r + 7) - 5))
    end
    if p.pos then
        local a = ang(p.pos)
        self:setColor(col)
        love.graphics.setLineWidth(2)
        love.graphics.line(cx, cy, cx + math_cos(a) * (r - 4), cy + math_sin(a) * (r - 4))
        love.graphics.setLineWidth(1)
    end
    self:drawStarGlint(cx, cy, 4, col, p.home and 1.0 or 0.8)

    -- the 8 notes the dial walks, as rising steps
    local bx = ox + 62
    for i = 1, 8 do
        local x = bx + (i - 1) * 15
        local h = 5 + i * 2.6
        local on = (p.lit == i)
        local base = oy + 34
        self:setColor(on and col or C.PANEL_HI)
        love.graphics.rectangle("fill", x, base - h, 10, h, 2, 2)
        self:setColor(on and col or C.GRID)
        love.graphics.rectangle("line", x, base - h, 10, h, 2, 2)
        self:setColor(on and C.TEXT or C.MUTED)
        printCentre(self, self.fontTiny, p.notes[i] or "", x + 5, base + 2)
    end
    self:setColor(C.DIM)
    printRight(self, string.format("OCT %s%d", p.octave > 0 and "+" or "", p.octave), ox + ow - 5, oy + 3)
end

-- ---------------------------------------------------------------------------
-- RAIL panel (Slide): a ruler of pitch that scrolls under a fixed handle.
-- A tick per semitone, taller named ticks for the notes steps and snapping
-- land on (scale notes, or chord notes when following); an arrow to the note
-- the slide will settle on, and how far off a note it sits.
-- def:getPanel(state) -> { pitch, notes = { semis... }, names = { [semis] = name },
--   target, cents, label }
-- ---------------------------------------------------------------------------
function Chrome:drawPanel_rail(def, state, col, ox, oy, ow, oh)
    local C = Config.COLORS
    local p = def:getPanel(state)
    self:drawSunkenPanel(ox, oy, ow, oh)
    local x0, w = ox + 8, ow - 16
    local cx = x0 + w * 0.5
    local span = 16                                  -- semitones across the panel
    local function X(s) return cx + (s - p.pitch) / span * w end
    local ry = oy + 24
    self:setColor(C.GRID)
    love.graphics.setLineWidth(2)
    love.graphics.line(x0, ry, x0 + w, ry)
    love.graphics.setLineWidth(1)
    love.graphics.setFont(self.fontTiny)
    local isNote = {}
    for _, s in ipairs(p.notes) do isNote[s] = true end
    for s = math.ceil(p.pitch - span * 0.5), math_floor(p.pitch + span * 0.5) do
        local x = X(s)
        if x >= x0 and x <= x0 + w then
            local n = isNote[s]
            self:setColor(n and C.MUTED or C.DIM)
            love.graphics.line(x, ry - (n and 6 or 3), x, ry + (n and 6 or 3))
            if n and x >= x0 + 4 and x <= x0 + w - 4 then
                local near = math_abs(s - p.pitch) < 0.5
                self:setColor(near and C.TEXT or C.MUTED)
                printCentre(self, self.fontTiny, p.names[s] or "", x, ry + 12)
            end
        end
    end
    -- where it will settle
    if p.target and math_abs(p.target - p.pitch) > 0.04 then
        local tx = X(p.target)
        self:setColor(col, 0.9)
        love.graphics.line(cx, ry - 15, tx, ry - 15)
        local dir = (tx > cx) and -1 or 1
        love.graphics.line(tx, ry - 15, tx + dir * 3, ry - 18)
        love.graphics.line(tx, ry - 15, tx + dir * 3, ry - 12)
    end
    -- the handle (fixed in the middle; the rail moves)
    self:setColor(col, 0.18)
    love.graphics.rectangle("fill", cx - 8, ry - 10, 16, 20, 3, 3)
    self:setColor(col)
    love.graphics.rectangle("line", cx - 8, ry - 10, 16, 20, 3, 3)
    self:setColor(C.TEXT)
    love.graphics.setLineWidth(1.5)
    love.graphics.line(cx, ry - 10, cx, ry + 10)
    love.graphics.setLineWidth(1)
    self:drawStarGlint(cx, ry - 11, 4.5, C.TEXT, 1.0)
    if p.cents then
        self:setColor(col)
        love.graphics.print(p.cents, math_floor(cx + 11), oy + 4)
    end
    self:setColor(C.DIM)
    printRight(self, p.label, ox + ow - 5, oy + 3)
end

-- ---------------------------------------------------------------------------
-- VALVES panel: four pistons that sink while pressed, the breath, and the
-- sum that makes the note (open note, minus the valves, = the note).
-- def:getPanel(state) -> { keys = { { btn, down } x4 }, breath (0..1), breathLabel,
--   open, openName, steps, note }
-- ---------------------------------------------------------------------------
function Chrome:drawPanel_valves(def, state, col, ox, oy, ow, oh)
    local C = Config.COLORS
    local p = def:getPanel(state)
    self:drawSunkenPanel(ox, oy, ow, oh)
    love.graphics.setFont(self.fontTiny)
    for i, k in ipairs(p.keys) do
        local x = ox + 12 + (i - 1) * 27
        local top = oy + (k.down and 13 or 6)
        -- stem, cap, casing
        self:setColor(C.PANEL_HI)
        love.graphics.rectangle("fill", x + 6, top + 8, 6, oy + 33 - top - 8, 2, 2)
        self:setColor(C.GRID)
        love.graphics.rectangle("line", x + 6, top + 8, 6, oy + 33 - top - 8, 2, 2)
        self:setColor(k.down and col or C.PANEL_HI)
        love.graphics.rectangle("fill", x, top, 18, 8, 3, 3)
        self:setColor(k.down and col or C.GRID)
        love.graphics.rectangle("line", x, top, 18, 8, 3, 3)
        self:setColor(C.PANEL)
        love.graphics.rectangle("fill", x - 2, oy + 33, 22, 4, 2, 2)
        self:setColor(C.GRID)
        love.graphics.rectangle("line", x - 2, oy + 33, 22, 4, 2, 2)
        self:setColor(k.down and C.TEXT or C.MUTED)
        printCentre(self, self.fontTiny, k.btn, x + 9, oy + 38)
    end
    local rx = ox + 124
    self:setColor(C.DIM)
    love.graphics.print("BREATH", rx, oy + 3)
    self:setColor(C.PANEL_HI)
    love.graphics.rectangle("fill", rx, oy + 15, 84, 5, 2, 2)
    if p.breath > 0 then
        self:setColor(col)
        love.graphics.rectangle("fill", rx, oy + 15, 84 * p.breath, 5, 2, 2)
    end
    self:setColor(p.breath > 0 and col or C.DIM)
    love.graphics.print(p.breathLabel, rx, oy + 22)
    -- open note - valves = note
    local x = rx
    self:setColor(C.MUTED)
    local open = p.open .. " " .. p.openName
    love.graphics.print(open, x, oy + 35)
    x = x + self.fontTiny:getWidth(open) + 6
    self:setColor(col)
    local steps = (p.steps > 0) and ("-" .. p.steps) or "OPEN"
    love.graphics.print(steps, x, oy + 35)
    x = x + self.fontTiny:getWidth(steps) + 6
    self:setColor(C.TEXT)
    love.graphics.setFont(self.fontSmall)
    love.graphics.print(p.note, x, oy + 33)
end

end
