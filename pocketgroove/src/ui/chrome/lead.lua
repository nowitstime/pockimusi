-- ============================================================================
-- src/ui/chrome/lead.lua — Lead stage view
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
-- LEAD VIEW: sounding note, the arp's ladder (one dot per step of a pass,
-- the playing one lit), pitch trace of the last 1.2 s
-- ============================================================================
function Chrome:drawLeadView(def, state, track, col)
    local C = Config.COLORS
    local voice = def:getDisplayVoice(state)

    local semis = voice and math_floor(voice.currentSemis + 0.5) or Theory:getScaleDegreeSemis(state.activeDegree or 1)
    local noteName = Theory.NOTE_NAMES[(semis % 12) + 1]
    self:setColor(voice and C.TEXT or col)
    love.graphics.setFont(self.fontHuge)
    love.graphics.print(noteName, math_floor(320 - self.fontHuge:getWidth(noteName) * 0.5), 112)

    love.graphics.setFont(self.fontSmall)
    self:setColor(C.MUTED)
    local both = Input.down.L1 and Input.down.R1
    local oct = both and 0 or ((Input.down.L1 and -1 or 0) + (Input.down.R1 and 1 or 0))
    local sub = string.format("DEG %s  -  OCT %s%d  -  %s", def:degreeLabel(state.activeDegree or 1), (oct > 0 and "+" or ""), oct,
        (voice or state.arpBtn) and (state.lastArticulation or "NOTE") or "READY")
    love.graphics.print(sub, math_floor(320 - self.fontSmall:getWidth(sub) * 0.5), 148)

    local patch = def:getPatch(state)
    local rate = state.rate .. (state.arpDouble and " x2" or "")
    self:drawCapsuleRow(320, 166, 16, {
        { patch and patch.label or "?", C.GRID, C.PANEL_HI, col },
        { "ARP " .. rate, state.arpBtn and col or C.GRID, state.arpBtn and col or C.PANEL_HI, state.arpBtn and C.BG or C.MUTED },
        { state.follow and ("FOLLOW " .. Theory:chordName((Harmony:current()))) or "FOLLOW OFF",
          C.GRID, C.PANEL_HI, state.follow and C.CYAN or C.DIM },
    })

    -- Arp ladder: one pass of the sequence a press would play (or is playing)
    local ox, oy, ow, oh = 212, 188, 216, 50
    self:setColor(C.BG)
    love.graphics.rectangle("fill", ox, oy, ow, oh, 4, 4)
    self:setColor(C.GRID)
    love.graphics.rectangle("line", ox, oy, ow, oh, 4, 4)
    local mode = def.ARP_MODES[state.arpBtn or "A"]
    local seq = def:arpSequence(state, mode, state.activeDegree or 1)
    local lo, hi = seq[1], seq[1]
    for _, r in ipairs(seq) do lo, hi = math_min(lo, r), math_max(hi, r) end
    local n = #seq
    local px, py = {}, {}
    for i, r in ipairs(seq) do
        px[i] = ox + 12 + (i - 0.5) / n * (ow - 24)
        py[i] = oy + oh - 9 - ((hi > lo) and ((r - lo) / (hi - lo)) or 0.5) * (oh - 18)
    end
    self:setColor(col, state.arpBtn and 0.45 or 0.2)
    for i = 2, n do love.graphics.line(px[i - 1], py[i - 1], px[i], py[i]) end
    for i = 1, n do
        local lit = state.arpBtn and state.arpPos == i - 1
        if lit then
            self:drawStarGlint(px[i], py[i], 6.5, C.TEXT, 1.0)
        else
            self:setColor(col, state.arpBtn and 0.9 or 0.45)
            love.graphics.circle("fill", px[i], py[i], 2.4)
        end
    end
    love.graphics.setFont(self.fontTiny)
    self:setColor(C.DIM)
    love.graphics.print(state.pattern, ox + 5, oy + 3)

    self:drawPitchTrace(def, state, col, 244, 34)
end

end
