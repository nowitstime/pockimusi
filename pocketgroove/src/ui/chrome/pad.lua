-- ============================================================================
-- src/ui/chrome/pad.lua — Pad stage view
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

return function(Chrome)

-- ============================================================================
-- PAD VIEW: the chord being held, one glowing line per sounding note
-- (height = pitch, strength = level, wobble = movement, glow = brightness),
-- and the two D-pad values
-- ============================================================================
function Chrome:drawPadView(def, state, track, col, t)
    local C = Config.COLORS
    local live = def:getLiveNote(state)
    local sounding = def:getSounding(state)

    -- Chord: the one being held, else the one a press would play
    local chord = live and live.chord or (Harmony:current())
    local name = Theory:chordName(chord)
    self:setColor(live and C.TEXT or col)
    love.graphics.setFont(self.fontHuge)
    love.graphics.print(name, math_floor(320 - self.fontHuge:getWidth(name) * 0.5), 106)

    love.graphics.setFont(self.fontSmall)
    self:setColor(C.MUTED)
    local oct = live and (live.ev.octave or 0) or ((Input.down.L1 and -1 or 0) + (Input.down.R1 and 1 or 0))
    local shape = live and def:getActionLabel(state, live.ev.action) or (#sounding > 0 and "PLAYING" or "READY")
    local sub = string.format("%s  -  OCT %s%d", shape, (oct > 0 and "+" or ""), oct)
    love.graphics.print(sub, math_floor(320 - self.fontSmall:getWidth(sub) * 0.5), 142)

    local patch = def:getPatch(state)
    self:drawCapsuleRow(320, 160, 16, {
        { patch and patch.label or "?", C.GRID, C.PANEL_HI, col },
        { Harmony:followChip(state.follow),
          C.GRID, C.PANEL_HI, state.follow and C.CYAN or C.DIM },
    })

    -- Note field
    local fx, fy, fw, fh = 212, 182, 216, 74
    self:setColor(C.BG)
    love.graphics.rectangle("fill", fx, fy, fw, fh, 4, 4)
    self:setColor(C.GRID)
    love.graphics.rectangle("line", fx, fy, fw, fh, 4, 4)

    -- Two octaves tall at least, centred on what is sounding (or would be)
    local idle = Theory:getPadVoicing(chord, "FULL", oct)
    local lo, hi
    for _, s in ipairs(#sounding > 0 and sounding or idle) do
        local semis = type(s) == "table" and s.semis or s
        lo = lo and math_min(lo, semis) or semis
        hi = hi and math_max(hi, semis) or semis
    end
    local mid, span = (lo + hi) * 0.5, math_max(24, hi - lo + 6)
    lo, hi = mid - span * 0.5, mid + span * 0.5
    local function py(semis)
        return fy + fh - 6 - clamp((semis - lo) / (hi - lo), 0.0, 1.0) * (fh - 12)
    end
    local function wave(semis, idx, amp, speed)
        local pts = {}
        local y = py(semis)
        for x = 0, fw - 12, 6 do
            local edge = math_sin(math_pi * x / (fw - 12))          -- pinned at both ends
            pts[#pts + 1] = fx + 6 + x
            pts[#pts + 1] = y + math_sin(x * 0.07 + t * speed + idx * 1.9) * amp * edge
        end
        return pts
    end

    if #sounding == 0 then
        -- Idle: the full chord a press would play, faintly
        for i, semis in ipairs(idle) do
            self:setColor(col, 0.22)
            love.graphics.line(wave(semis, i, 0.0, 0.0))
        end
    else
        for i, s in ipairs(sounding) do
            local pts = wave(s.semis, i, 0.4 + s.move * 2.2, 1.2 + s.move * 3.0)
            self:setColor(col, s.level * (0.10 + 0.30 * s.bright))
            love.graphics.setLineWidth(3 + s.bright * 5)
            love.graphics.line(pts)
            self:setColor(s.held and col or C.MUTED, 0.25 + 0.75 * s.level)
            love.graphics.setLineWidth(1.6)
            love.graphics.line(pts)
        end
        love.graphics.setLineWidth(1)
    end

    -- The D-pad's two values
    local function meter(x, label, value, on)
        love.graphics.setFont(self.fontTiny)
        self:setColor(on and col or C.MUTED)
        love.graphics.print(label, x, 263)
        local bx, bw = x + 44, 56
        self:setColor(C.PANEL_HI)
        love.graphics.rectangle("fill", bx, 265, bw, 6, 3, 3)
        self:setColor(on and C.TEXT or col)
        love.graphics.rectangle("fill", bx, 265, math_max(3, bw * value), 6, 3, 3)
        self:setColor(C.GRID)
        love.graphics.rectangle("line", bx, 265, bw, 6, 3, 3)
    end
    local active = (Modes.current or "NORMAL") ~= "FX"
    meter(214, "BRIGHT", state.bright, active and (Input.down.UP or Input.down.DOWN))
    meter(326, "MOVE", state.move, active and (Input.down.LEFT or Input.down.RIGHT))
end

end
