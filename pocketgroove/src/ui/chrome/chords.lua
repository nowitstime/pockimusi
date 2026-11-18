-- ============================================================================
-- src/ui/chrome/chords.lua — Chord Track stage view
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
-- CHORD TRACK VIEW (src/instruments/chords.lua): the chord, then the loop's
-- chords as a stepped line (height = the chord's root above the key, a star
-- riding it as the playhead, as on the Lead's arp) and the progression as a
-- row of dots with a star on the chord for this point in the loop.
-- def:getView(state, track) gives the data.
-- ============================================================================
function Chrome:drawChordTrackView(def, state, track, col)
    local C = Config.COLORS
    local v = def:getView(state, track)

    self:setColor(C.TEXT)
    love.graphics.setFont(self.fontHuge)
    love.graphics.print(v.name, math_floor(320 - self.fontHuge:getWidth(v.name) * 0.5), 112)

    love.graphics.setFont(self.fontSmall)
    self:setColor(C.MUTED)
    love.graphics.print(v.sub, math_floor(320 - self.fontSmall:getWidth(v.sub) * 0.5), 148)

    local srcCol = (v.source == "this") and C.CYAN or C.DIM
    local middle = v.colouring and { v.middle, col, col, C.BG } or { v.middle, C.GRID, C.PANEL_HI, C.MUTED }
    self:drawCapsuleRow(320, 166, 16, {
        { v.patch, C.GRID, C.PANEL_HI, col },
        middle,
        { v.sourceLabel, C.GRID, C.PANEL_HI, srcCol },
    })

    -- The loop: a stepped line through the chords
    local ox, oy, ow, oh = 212, 188, 216, 54
    self:setColor(C.BG)
    love.graphics.rectangle("fill", ox, oy, ow, oh, 4, 4)
    self:setColor(C.GRID)
    love.graphics.rectangle("line", ox, oy, ow, oh, 4, 4)
    local beats = Looper:getTotalBeats()
    for b = 1, beats - 1 do
        local bx = math_floor(ox + b / beats * ow) + 0.5
        self:setColor(C.GRID, (b % 4 == 0) and 0.9 or 0.3)
        love.graphics.line(bx, oy + 3, bx, oy + oh - 3)
    end
    love.graphics.setFont(self.fontTiny)
    self:setColor(C.DIM)
    love.graphics.print(v.loopLabel, ox + 5, oy + 3)

    local lx0, lw = ox + 8, ow - 16
    local function X(frac) return lx0 + frac * lw end
    local function Y(level) return oy + oh - 9 - level * (oh - 24) end

    if #v.spans == 0 then
        local msg = v.emptyLabel
        self:setColor(C.MUTED)
        love.graphics.print(msg, math_floor(320 - self.fontTiny:getWidth(msg) * 0.5), oy + oh * 0.5 - 2)
    end
    local lastLabelX
    for i, sp in ipairs(v.spans) do
        local x1, x2, y = X(sp.from), X(sp.to), Y(sp.level)
        local nxt = v.spans[i + 1]
        -- plateau, then the step to the next chord
        self:setColor(col, sp.now and 0.9 or 0.45)
        love.graphics.setLineWidth(sp.now and 2 or 1.4)
        love.graphics.line(x1, y, math_max(x1, x2 - 3), y)
        love.graphics.setLineWidth(1)
        if nxt then
            self:setColor(col, 0.35)
            love.graphics.line(math_max(x1, x2 - 3), y, X(nxt.from), Y(nxt.level))
        end
        if not sp.carry then
            self:setColor(col)
            love.graphics.circle("fill", x1, y, sp.now and 3.6 or 2.8)
            -- the numeral beside each dot, when there's room (the current one always)
            if sp.now or not lastLabelX or x1 - lastLabelX >= 20 then
                self:setColor(sp.now and C.TEXT or C.MUTED)
                -- high chords put it under the line, clear of the panel's label
                love.graphics.print(sp.label, math_floor(x1 + 4), math_floor(sp.level > 0.6 and (y + 3) or (y - 14)))
                lastLabelX = x1
            end
        end
    end
    if v.playhead then
        self:drawStarGlint(X(v.playhead.frac), Y(v.playhead.level), 6.5, C.TEXT, 1.0)
    end

    -- The progression: a dot per chord, a star on the one for this point
    local py, ph = 248, 34
    self:setColor(C.BG)
    love.graphics.rectangle("fill", ox, py, ow, ph, 4, 4)
    self:setColor(C.GRID)
    love.graphics.rectangle("line", ox, py, ow, ph, 4, 4)
    love.graphics.setFont(self.fontTiny)
    self:setColor(C.DIM)
    love.graphics.print(v.progName, ox + 5, py + 3)
    love.graphics.print(v.progRight, math_floor(ox + ow - 5 - self.fontTiny:getWidth(v.progRight)), py + 3)
    local n = #v.romans
    local stepX = (n > 1) and (ow - 60) / (n - 1) or 0
    local dy = py + ph * 0.5 + 2
    for i, r in ipairs(v.romans) do
        local x = (n > 1) and (ox + 30 + (i - 1) * stepX) or (ox + ow * 0.5)
        if i > 1 then
            self:setColor(C.GRID)
            love.graphics.line(x - stepX + 6, dy, x - 6, dy)
        end
        local g = (i == v.guide)
        if g then
            self:drawStarGlint(x, dy, 5.5, col, 1.0)
        else
            self:setColor(C.MUTED)
            love.graphics.circle("fill", x, dy, 2.2)
        end
        self:setColor(g and col or C.MUTED)
        love.graphics.print(r, math_floor(x - self.fontTiny:getWidth(r) * 0.5), dy + 5)
    end
end

end
