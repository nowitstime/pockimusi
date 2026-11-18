-- ============================================================================
-- src/ui/chrome/bass.lua — Bass stage view and the sunken panel
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
-- BASS VIEW: sounding note, live oscilloscope, pitch trace of the last 1.2 s
-- ============================================================================
function Chrome:drawBassView(def, state, track, col)
    local C = Config.COLORS
    local voice = def:getDisplayVoice(state)

    -- Note name: what's sounding now (mid-glide too), else the D-pad's degree
    local semis = voice and math_floor(voice.currentSemis + 0.5) or Theory:getScaleDegreeSemis(state.activeDegree or 1)
    local noteName = Theory.NOTE_NAMES[(semis % 12) + 1]
    self:setColor(voice and C.TEXT or col)
    local oct = (Input.down.L1 and -1 or 0) + (Input.down.R1 and 1 or 0)
    local sub = string.format("DEG %s  -  OCT %s%d  -  %s", def:degreeLabel(state.activeDegree or 1), (oct > 0 and "+" or ""), oct,
        voice and (state.lastArticulation or "HOLD") or "READY")
    -- an instrument borrowing this view may word the two lines itself
    if def.getReadout then
        local big, small = def:getReadout(state)
        noteName, sub = tostring(big or noteName), tostring(small or sub)
    end
    love.graphics.setFont(self.fontHuge)
    local nw = self.fontHuge:getWidth(noteName)
    love.graphics.print(noteName, math_floor(320 - nw * 0.5), 112)

    love.graphics.setFont(self.fontSmall)
    self:setColor(C.MUTED)
    local sw = self.fontSmall:getWidth(sub)
    love.graphics.print(sub, math_floor(320 - sw * 0.5), 148)

    -- Patch and glide (an instrument may name its own middle badge)
    local patch = def:getPatch(state)
    local middle = def.getMiddleBadge and def:getMiddleBadge(state) or ("GLIDE " .. (state.glide or "MEDIUM"))
    self:drawCapsuleRow(320, 166, 16, {
        { patch and patch.label or "?", C.GRID, C.PANEL_HI, col },
        { middle, C.GRID, C.PANEL_HI, C.MUTED },
        { state.follow and ("FOLLOW " .. Theory:chordName((Harmony:current()))) or "FOLLOW OFF",
          C.GRID, C.PANEL_HI, state.follow and C.CYAN or C.DIM },
    })

    -- An instrument borrowing this view may draw its own top panel
    -- (def.PANEL = "dial", "rail" or "valves"); the pitch trace stays
    if def.PANEL and self["drawPanel_" .. def.PANEL] then
        self["drawPanel_" .. def.PANEL](self, def, state, col, 212, 188, 216, 50)
        self:drawPitchTrace(def, state, col, 244, 34)
        return
    end

    -- Oscilloscope: the live voice's real pitch and level
    local ox, oy, ow, oh = 212, 188, 216, 50
    self:setColor(C.BG)
    love.graphics.rectangle("fill", ox, oy, ow, oh, 4, 4)
    self:setColor(C.GRID)
    love.graphics.rectangle("line", ox, oy, ow, oh, 4, 4)
    local pts = {}
    local midY = oy + oh * 0.5
    for x = 0, ow - 8, 4 do
        local w = (x / (ow - 8)) * math_pi * 2.0 * 2.5 * state.oscFreqRatio + state.oscPhase
        local wave = (math_sin(w) + 0.5 * math_sin(w * 2.0) + 0.25 * math_sin(w * 3.0)) * 0.6
        table.insert(pts, ox + 4 + x)
        table.insert(pts, midY + wave * (oh * 0.36) * state.oscAmp)
    end
    self:setColor(col, voice and 1.0 or 0.4)
    love.graphics.setLineWidth(1.6)
    love.graphics.line(pts)
    love.graphics.setLineWidth(1)

    self:drawPitchTrace(def, state, col, 244, 34)
end

-- A sunken panel, as under the Lead's arp and the Bass's trace
function Chrome:drawSunkenPanel(x, y, w, h)
    local C = Config.COLORS
    self:setColor(C.BG)
    love.graphics.rectangle("fill", x, y, w, h, 4, 4)
    self:setColor(C.GRID)
    love.graphics.rectangle("line", x, y, w, h, 4, 4)
end

end
