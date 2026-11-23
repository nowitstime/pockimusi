-- ============================================================================
-- src/ui/chrome/electronic.lua — Stage panels for Phase L's instruments:
-- Roller's bead strip, Breaks' slice ring, Wobble's rate panel
-- (part of src/ui/chrome.lua: adds methods to the Chrome table)
-- ============================================================================

local Config      = require("src.config")
local Theory      = require("src.theory")
local Looper      = require("src.looper")

local math_floor = math.floor
local math_min   = math.min
local math_max   = math.max
local math_sin   = math.sin
local math_cos   = math.cos
local math_pi    = math.pi

return function(Chrome)

-- ============================================================================
-- ROLLER (inside the Bass view): the last repeats as beads on a strip, newest
-- on the right, height = pitch, size = velocity (X's accents stand out); the
-- step grid of the roll's rate behind them
-- ============================================================================
function Chrome:drawPanel_roller(def, state, col, x, y, w, h)
    local C = Config.COLORS
    self:drawSunkenPanel(x, y, w, h)
    local beads = state.beads or {}
    -- the rate's grid: one tick per step over the strip's 1.6 s
    local steps = def:getRollSteps(state, state.rollBtn or "B")
    local stepSec = Looper:getLoopDuration() / (steps * Looper.bars)
    local n = math_min(64, math_floor(1.6 / math_max(stepSec, 0.01)))
    self:setColor(C.GRID, state.rollBtn and 0.9 or 0.4)
    for i = 0, n do
        local px = math_floor(x + w - 8 - i * (w - 16) / math_max(n, 1)) + 0.5
        love.graphics.line(px, y + h - 6, px, y + h - 3)
    end
    if #beads == 0 then
        love.graphics.setFont(self.fontTiny)
        self:setColor(C.DIM)
        local t = "HOLD A BUTTON TO ROLL"
        love.graphics.print(t, math_floor(x + (w - self.fontTiny:getWidth(t)) * 0.5), y + h * 0.5 - 5)
        return
    end
    local lo, hi = beads[1].semis, beads[1].semis
    for _, b in ipairs(beads) do lo, hi = math_min(lo, b.semis), math_max(hi, b.semis) end
    if hi - lo < 7 then
        local mid = (hi + lo) * 0.5
        lo, hi = mid - 3.5, mid + 3.5
    end
    local prevX, prevY
    for i, b in ipairs(beads) do
        local px = x + w - 8 - (b.age / 1.6) * (w - 16)
        local py = y + h - 10 - (b.semis - lo) / (hi - lo) * (h - 20)
        local a = math_max(0.0, 1.0 - b.age / 1.6)
        if prevX then
            self:setColor(col, 0.3 * a)
            love.graphics.line(prevX, prevY, px, py)
        end
        prevX, prevY = px, py
        local r = 1.6 + (b.vel - 0.55) * 7.0
        if i == #beads and b.age < 0.12 then
            self:drawStarGlint(px, py, r + 3.5, C.TEXT, 1.0)
        else
            self:setColor(col, a)
            love.graphics.circle("fill", px, py, r)
        end
    end
end


-- ============================================================================
-- BREAKS VIEW: the break as a ring of eight slices (the D-pad's directions),
-- its hits as beads round it (inner = kick, then snare, hats, cymbals and
-- percussion outwards), the playhead lit, the move and speed underneath
-- ============================================================================
local RING_OF = { kick = 0, snare = 1, ghost = 1, hat = 2, pedal = 2, hat_open = 2, ride = 3, crash = 3, perc1 = 3, perc2 = 3 }

function Chrome:drawBreaksView(def, state, track, col)
    local C = Config.COLORS
    local brk = def:getBreak(state)
    local cx, cy, r0, gap = 320, 238, 22, 10
    -- name and the move
    love.graphics.setFont(self.fontLarge)
    self:setColor(C.TEXT)
    love.graphics.print(brk.name, math_floor(cx - self.fontLarge:getWidth(brk.name) * 0.5), 104)
    local move = "HOLD B TO PLAY"
    if state.viewMode then
        local sp = state.want and state.want.speed or 1
        move = ({ play = "PLAYING", stutter = "STUTTER", reverse = "REVERSE", roll = "SNARE ROLL" })[state.viewMode] or "PLAYING"
        if sp == 0.5 then move = move .. "  -  HALF" elseif sp == 2 then move = move .. "  -  DOUBLE" end
    end
    if state.pendingSlice then move = move .. "  -  TO " .. state.pendingSlice end
    love.graphics.setFont(self.fontSmall)
    self:setColor(state.viewMode and col or C.MUTED)
    love.graphics.print(move, math_floor(cx - self.fontSmall:getWidth(move) * 0.5), 126)
    self:drawCapsuleRow(cx, 142, 14, {
        { def:kitName(state), C.GRID, C.PANEL_HI, col },
        { brk.bars .. (brk.bars == 1 and " BAR" or " BARS"), C.GRID, C.PANEL_HI, C.MUTED },
    })

    -- the slices
    local slices = 8
    local outer = r0 + 3 * gap + 6
    for i = 0, slices - 1 do
        local a = -math_pi * 0.5 + i / slices * math_pi * 2
        self:setColor(C.GRID)
        love.graphics.line(cx + math_cos(a) * (r0 - 6), cy + math_sin(a) * (r0 - 6),
                           cx + math_cos(a) * outer, cy + math_sin(a) * outer)
        local lx, ly = cx + math_cos(a + math_pi / slices) * (outer + 7), cy + math_sin(a + math_pi / slices) * (outer + 7)
        local label = tostring(i + 1)
        love.graphics.setFont(self.fontTiny)
        local lit = state.viewPos and math_floor(state.viewPos * slices) == i
        self:setColor(lit and C.TEXT or C.DIM)
        love.graphics.print(label, math_floor(lx - self.fontTiny:getWidth(label) * 0.5), math_floor(ly - 5))
    end
    for k = 0, 3 do
        self:setColor(C.GRID, 0.6)
        love.graphics.circle("line", cx, cy, r0 + k * gap)
    end

    -- the hits
    local hits = def:hitList(state, track)
    local total = brk.ticks
    for _, h in ipairs(hits) do
        local a = -math_pi * 0.5 + (h.tick / total) * math_pi * 2
        local rr = r0 + (RING_OF[h.role] or 3) * gap
        local f = state.flash[h.role] or 0
        self:setColor(col, 0.35 + 0.65 * h.vel)
        love.graphics.circle("fill", cx + math_cos(a) * rr, cy + math_sin(a) * rr, 1.2 + h.vel * 2.0 + f * 0.8)
    end

    -- the playhead
    if state.viewPos then
        local a = -math_pi * 0.5 + state.viewPos * math_pi * 2
        self:setColor(C.TEXT)
        love.graphics.setLineWidth(1.6)
        love.graphics.line(cx + math_cos(a) * (r0 - 8), cy + math_sin(a) * (r0 - 8),
                           cx + math_cos(a) * (outer + 2), cy + math_sin(a) * (outer + 2))
        love.graphics.setLineWidth(1)
        self:drawStarGlint(cx + math_cos(a) * (outer + 2), cy + math_sin(a) * (outer + 2), 5, C.TEXT, 1.0)
    end
    -- the centre: a flash on the kick and snare
    local k = math_max(state.flash.kick or 0, (state.flash.snare or 0) * 0.8)
    self:setColor(col, 0.15 + 0.6 * k)
    love.graphics.circle("fill", cx, cy, 8 + k * 5)
end

-- ============================================================================
-- WOBBLE (inside the Bass view): the tone over the last 1.2 s as a filled
-- band (high = open), newest on the right; the rate and shape in the corner
-- ============================================================================
function Chrome:drawPanel_wobble(def, state, col, x, y, w, h)
    local C = Config.COLORS
    self:drawSunkenPanel(x, y, w, h)
    local hist = state.history or {}
    local n = #hist
    local base = y + h - 5
    local span = h - 18
    if n > 1 then
        for i = 1, n do
            local b = hist[i]
            if b then
                local px = x + 6 + (i - 1) / 71 * (w - 12)
                self:setColor(col, 0.25 + 0.75 * b)
                love.graphics.line(px, base, px, base - b * span)
            end
        end
    end
    love.graphics.setFont(self.fontTiny)
    self:setColor(C.DIM)
    local label = (state.open and "OPEN" or state.rate) .. "  " .. state.shape .. "  " .. state.depth
    love.graphics.print(label, x + 5, y + 3)
    if n == 0 or not hist[n] then
        self:setColor(C.DIM)
        local t = "HOLD A NOTE: THE D-PAD MOVES THE TONE"
        love.graphics.print(t, math_floor(x + (w - self.fontTiny:getWidth(t)) * 0.5), y + h * 0.5 - 2)
    end
end
end
