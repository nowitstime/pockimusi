-- ============================================================================
-- src/ui/chrome/views.lua — Stage view dispatch and the plain lab view
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
-- CENTER VISUALIZERS (DRUMS, HARP, BASS, PAD)
-- ============================================================================
function Chrome:drawInstrumentVisualizer(def, state, track, col, t)
    local C = Config.COLORS
    local kind = self:viewKind(def)
    if kind == "drums" then
        self:drawDrumLanes(def, state, track, col)
    elseif kind == "harp" then
        local chord = state.currentChord or Theory:getChordForDirection("NEUTRAL", false, false, state.colour)
        self:setColor(C.TEXT)
        love.graphics.setFont(self.fontHuge)
        local cw = self.fontHuge:getWidth(chord.name)
        love.graphics.print(chord.name, math_floor(320 - cw * 0.5), 122)

        love.graphics.setFont(self.fontSmall)
        self:setColor(col)
        local octStr = chord.isWide and "WIDE OPEN" or (chord.octShift < 0 and "OCT -1" or (chord.octShift > 0 and "OCT +1" or "OCT 0"))
        local sub = string.format("%s  -  %s  -  %s", chord.roman, octStr, chord.colour or "TRIAD")
        if state.follow then sub = sub .. "  -  FOLLOW" end
        local patch = def:getPatch(state)
        if patch and patch.id ~= def.DEFAULT_PATCH then sub = sub .. "  -  " .. patch.label end
        local sw = self.fontSmall:getWidth(sub)
        love.graphics.print(sub, math_floor(320 - sw * 0.5), 158)

        -- 4 Starlight vibrating strings
        local xs = { 248, 296, 344, 392 }
        self:setColor(C.GRID)
        love.graphics.line(232, 182, 408, 182)
        love.graphics.line(232, 276, 408, 276)

        for i = 1, 4 do
            local sx = xs[i]
            local str = state.strings[i]
            local amp = (str and str.energy or 0.0) * 9.0
            local ph = t * 40.0 + i * 2.0
            local pts = {}
            for seg = 0, 16 do
                local frac = seg / 16.0
                local py = 182 + frac * 94
                local wave = math_sin(math_pi * frac) * math_sin(ph + frac * 6.0) * amp
                table.insert(pts, sx + wave)
                table.insert(pts, py)
            end

            if str and str.energy > 0.05 then
                self:setColor(col, 0.25)
                love.graphics.setLineWidth(4)
                love.graphics.line(pts)
            end
            self:setColor((str and str.energy > 0.05) and col or C.MUTED)
            love.graphics.setLineWidth((str and str.energy > 0.05) and 2.0 or 1.2)
            love.graphics.line(pts)
            love.graphics.setLineWidth(1)

            self:drawStarGlint(sx, 182, (str and str.energy > 0.05) and 5 or 3, (str and str.energy > 0.05) and col or C.MUTED)
            self:drawStarGlint(sx, 276, (str and str.energy > 0.05) and 5 or 3, (str and str.energy > 0.05) and col or C.MUTED)
        end

    elseif kind == "bass" then
        self:drawBassView(def, state, track, col)

    elseif kind == "lead" then
        self:drawLeadView(def, state, track, col)

    elseif kind == "pad" then
        self:drawPadView(def, state, track, col, t)

    elseif kind == "chords" then
        self:drawChordTrackView(def, state, track, col)

    elseif kind == "strum" then
        self:drawStrumView(def, state, track, col, t)

    else
        self:drawLabView(def, state, track, col)
    end
end

-- ============================================================================
-- LAB VIEW: the plain view for an instrument without one of its own.
-- def:getReadout(state) -> a large line, a small line, and (optional) a list
-- of further lines
-- ============================================================================
Chrome.LAB_LINES = 9            -- further lines that fit

function Chrome:drawLabView(def, state, track, col)
    local C = Config.COLORS
    local big, small, lines
    if def.getReadout then big, small, lines = def:getReadout(state) end
    big = tostring(big or def.name)

    -- the large line steps down a size when it is too long for the column
    local font = self.fontHuge
    if font:getWidth(big) > 224 then font = self.fontLarge end
    self:setColor(C.TEXT)
    love.graphics.setFont(font)
    love.graphics.print(big, math_floor(320 - font:getWidth(big) * 0.5), 112 + math_floor((28 - font:getHeight()) * 0.5))

    if small and small ~= "" then
        small = tostring(small)
        love.graphics.setFont(self.fontSmall)
        self:setColor(col)
        love.graphics.print(small, math_floor(320 - self.fontSmall:getWidth(small) * 0.5), 148)
    end

    local items = {}
    local patch = def.getPatch and def:getPatch(state)
    if patch then items[#items + 1] = { patch.label or "?", C.GRID, C.PANEL_HI, col } end
    items[#items + 1] = { "LAB", C.GRID, C.PANEL_HI, C.MUTED }
    self:drawCapsuleRow(320, 166, 16, items)

    if type(lines) == "table" then
        love.graphics.setFont(self.fontSmall)
        self:setColor(C.MUTED)
        for i = 1, math_min(#lines, self.LAB_LINES) do
            local text = tostring(lines[i])
            love.graphics.print(text, math_floor(320 - self.fontSmall:getWidth(text) * 0.5), 176 + i * 13)
        end
    end
end

end
