-- ============================================================================
-- src/ui/chrome/strum.lua — Strum stage view and the pitch trace
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

-- ============================================================================
-- STRUM VIEW: the strings (held ones glow, plucked ones ring, a pick sweeps
-- the way of the stroke) and the strum pattern of the loop (down and up
-- strokes as marks). def:getView(state, track) gives the data.
-- ============================================================================
function Chrome:drawStrumView(def, state, track, col, t)
    local C = Config.COLORS
    local v = def:getView(state, track)
    self:setColor(C.TEXT)
    love.graphics.setFont(self.fontHuge)
    printCentre(self, self.fontHuge, v.name, 320, 112)
    love.graphics.setFont(self.fontSmall)
    self:setColor(C.MUTED)
    printCentre(self, self.fontSmall, v.sub, 320, 148)
    self:drawCapsuleRow(320, 166, 16, {
        { v.patch, C.GRID, C.PANEL_HI, col },
        { v.middle, C.GRID, C.PANEL_HI, C.MUTED },
        { v.follow, C.GRID, C.PANEL_HI, v.followOn and C.CYAN or C.DIM },
    })

    -- strings, high at the top
    local ox, oy, ow, oh = 212, 188, 216, 50
    self:drawSunkenPanel(ox, oy, ow, oh)
    love.graphics.setFont(self.fontTiny)
    local x1, x2 = ox + 36, ox + ow - 18
    for i, str in ipairs(v.strings) do
        local y = oy + 6 + (i - 1) * 9.5
        local e = str.energy
        self:setColor((e > 0.05 or str.held) and col or C.DIM)
        love.graphics.print(str.label, ox + 5, math_floor(y - 5))
        if e > 0.05 or str.held then
            local pts = {}
            for seg = 0, 24 do
                local f = seg / 24
                pts[#pts + 1] = x1 + f * (x2 - x1)
                pts[#pts + 1] = y + math_sin(math_pi * f) * math_sin(f * 14 + t * 38 + i) * e * 2.6
            end
            if e > 0.05 then
                self:setColor(col, 0.2 * e)
                love.graphics.setLineWidth(4)
                love.graphics.line(pts)
            end
            self:setColor(col, 0.55 + 0.45 * e)
            love.graphics.setLineWidth(1.5)
            love.graphics.line(pts)
            love.graphics.setLineWidth(1)
        else
            self:setColor(C.DIM)
            love.graphics.line(x1, y, x2, y)
        end
        self:setColor((e > 0.05 or str.held) and C.TEXT or C.DIM)
        printRight(self, str.note, ox + ow - 5, math_floor(y - 5))
    end
    -- the pick, sweeping the way of the last stroke
    if v.pick then
        local px = ox + ow * 0.62
        local f = v.pick.progress
        local yTop, yBot = oy + 4, oy + oh - 4
        local py = v.pick.down and (yTop + f * (yBot - yTop)) or (yBot - f * (yBot - yTop))
        self:setColor(C.TEXT, 0.3 * v.pick.alpha)
        love.graphics.line(px, yTop, px, yBot)
        self:drawStarGlint(px, py, 5, C.TEXT, v.pick.alpha)
    end

    -- the strum pattern of the loop
    local py, ph = 244, 34
    self:drawSunkenPanel(ox, py, ow, ph)
    self:setColor(C.DIM)
    love.graphics.print("PATTERN", ox + 5, py + 3)
    local beats = Looper:getTotalBeats()
    local lx0, lw = ox + 8, ow - 16
    for b = 1, beats - 1 do
        local bx = math_floor(lx0 + b / beats * lw) + 0.5
        self:setColor(C.GRID, (b % 4 == 0) and 0.9 or 0.35)
        love.graphics.line(bx, py + 14, bx, py + ph - 3)
    end
    local my = py + 23
    for _, m in ipairs(v.marks) do
        local x = lx0 + m.frac * lw
        self:setColor(col, m.down and 1.0 or 0.75)
        if m.down then
            love.graphics.polygon("fill", x - 3, my - 3, x + 3, my - 3, x, my + 3)
        else
            love.graphics.polygon("fill", x - 3, my + 3, x + 3, my + 3, x, my - 3)
        end
    end
    local loop = Looper:getLoopTicks()
    local phx = lx0 + ((Looper.tick % loop) / loop) * lw
    self:setColor(C.TEXT)
    love.graphics.line(phx, py + 13, phx, py + ph - 2)
    if #v.marks == 0 then
        self:setColor(C.MUTED)
        printCentre(self, self.fontTiny, "R1 DOWN  -  L1 UP  -  BOTH DAMP", 320, py + 17)
    end
end

-- Pitch trace: last 1.2 s, newest on the right; brighter = louder
function Chrome:drawPitchTrace(def, state, col, ty, th)
    local C = Config.COLORS
    local tx, tw = 212, 216
    self:setColor(C.BG)
    love.graphics.rectangle("fill", tx, ty, tw, th, 4, 4)
    self:setColor(C.GRID)
    love.graphics.rectangle("line", tx, ty, tw, th, 4, 4)
    local trace = def:getTrace(state)
    local lo, hi = nil, nil
    for _, smp in ipairs(trace) do
        if smp then
            lo = lo and math_min(lo, smp.semis) or smp.semis
            hi = hi and math_max(hi, smp.semis) or smp.semis
        end
    end
    if lo then
        -- at least an octave tall, centred on what was played
        local mid = (lo + hi) * 0.5
        local span = math_max(12, hi - lo + 4)
        lo, hi = mid - span * 0.5, mid + span * 0.5
        local n = #trace
        local function px(i) return tx + 4 + (i - 1) / (n - 1) * (tw - 8) end
        local function py(semis) return ty + th - 4 - (semis - lo) / (hi - lo) * (th - 8) end
        love.graphics.setLineWidth(2)
        for i = 2, n do
            local a, b = trace[i - 1], trace[i]
            if a and b then
                self:setColor(col, 0.35 + 0.65 * math_min(1.0, b.level * 1.6))
                love.graphics.line(px(i - 1), py(a.semis), px(i), py(b.semis))
            end
        end
        love.graphics.setLineWidth(1)
        local last = trace[n]
        if last then
            self:setColor(C.TEXT)
            love.graphics.circle("fill", px(n), py(last.semis), 2.2)
        end
    else
        love.graphics.setFont(self.fontTiny)
        self:setColor(C.DIM)
        local hint = "PITCH TRACE"
        love.graphics.print(hint, math_floor(320 - self.fontTiny:getWidth(hint) * 0.5), ty + 12)
    end
end

end
