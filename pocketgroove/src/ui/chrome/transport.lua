-- ============================================================================
-- src/ui/chrome/transport.lua — Transport page, Erase page, Fresh Session
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
-- TRANSPORT PAGE: astrolabe dial (key ring, grid + swing ticks, loop hand)
-- ============================================================================
function Chrome:drawTransportView(track, trackCol, col)
    local C = Config.COLORS
    local cx, cy = 320, 190
    local rad = math_pi / 180

    self:setColor(col, 0.3)
    self:drawDashedCircle(cx, cy, 100, 2, 5)
    self:setColor(col, 0.18)
    love.graphics.circle("line", cx, cy, 64)

    -- Key ring in circle-of-fifths order; the scale is a contiguous arc on it
    local root = Theory.rootIndex - 1
    local scale = Theory.SCALES[Theory.scaleIndex]
    local inScale = {}
    for k = 1, 7 do inScale[(root + scale.intervals[k]) % 12] = true end
    local fifthsPc = {}
    for i = 0, 11 do fifthsPc[i] = (i * 7) % 12 end

    local arcStart = nil
    for st = 0, 11 do
        local ok = true
        for k = 0, 6 do
            if not inScale[fifthsPc[(st + k) % 12]] then ok = false break end
        end
        if ok then arcStart = st break end
    end
    if arcStart then
        local a1 = (-90 + arcStart * 30 - 12) * rad
        local a2 = (-90 + (arcStart + 6) * 30 + 12) * rad
        self:setColor(col, 0.45)
        love.graphics.setLineWidth(2.5)
        love.graphics.arc("line", "open", cx, cy, 72, a1, a2)
        love.graphics.setLineWidth(1)
    end

    love.graphics.setFont(self.fontTiny)
    for i = 0, 11 do
        local pc = fifthsPc[i]
        local ang = (-90 + i * 30) * rad
        local x, y = cx + math_cos(ang) * 86, cy + math_sin(ang) * 86
        local name = Theory.NOTE_NAMES[pc + 1]
        if pc == root then
            self:drawCapsule(math_floor(x - 11), math_floor(y - 8), 22, 16, name, col, col, C.BG, self.fontTiny)
        else
            self:setColor(inScale[pc] and C.TEXT or C.DIM, inScale[pc] and 0.8 or 1.0)
            love.graphics.print(name, math_floor(x - self.fontTiny:getWidth(name) * 0.5), math_floor(y - 6))
        end
    end

    -- Grid ticks for one bar; swing pushes the offbeat ticks late
    local grid = Looper:getTrackGrid(track.slot)
    local perBar = grid.stepsPerBar or 16
    local sw = 0.0
    if perBar == 8 or perBar == 16 then sw = math_max(0.0, ((track.swing or 0.5) - 0.5) * 2.0) end
    local stepDeg = 360 / perBar
    for k = 0, perBar - 1 do
        local odd = (k % 2 == 1)
        local ang = (-90 + (k + (odd and sw or 0)) * stepDeg) * rad
        local onBeat = (k % (perBar / 4) == 0)
        local r1 = onBeat and 54 or 58
        self:setColor(col, grid.stepsPerBar and (odd and 0.5 or 0.8) or 0.25)
        love.graphics.setLineWidth(1.2)
        love.graphics.line(cx + math_cos(ang) * r1, cy + math_sin(ang) * r1, cx + math_cos(ang) * 64, cy + math_sin(ang) * 64)
    end
    love.graphics.setLineWidth(1)

    -- Loop hand: a star travelling the ring once per loop, leaving a trail
    local endA = (-90 + Looper.phase * 360) * rad
    if Looper.phase > 0.002 then
        self:setColor(col)
        love.graphics.setLineWidth(2)
        love.graphics.arc("line", "open", cx, cy, 64, -90 * rad, endA)
        love.graphics.setLineWidth(1)
    end
    self:drawStarGlint(cx + math_cos(endA) * 64, cy + math_sin(endA) * 64, 6, C.TEXT, 1.0)

    -- Centre: tempo, key, loop length as moons
    love.graphics.setFont(self.fontHuge)
    self:setColor(C.TEXT)
    local bpmStr = tostring(Looper.bpm)
    love.graphics.print(bpmStr, math_floor(cx - self.fontHuge:getWidth(bpmStr) * 0.5), 148)
    love.graphics.setFont(self.fontTiny)
    self:setColor(C.MUTED)
    love.graphics.print("BPM", math_floor(cx - self.fontTiny:getWidth("BPM") * 0.5), 182)
    local keyStr = Theory.NOTE_NAMES[root + 1] .. " " .. scale.fullName:upper()
    love.graphics.setFont(self.fontSmall)
    self:setColor(col)
    love.graphics.print(keyStr, math_floor(cx - self.fontSmall:getWidth(keyStr) * 0.5), 196)
    for k = 1, 4 do
        local mx = cx - 15 + (k - 1) * 10
        if k <= Looper.bars then
            self:setColor(col)
            love.graphics.circle("fill", mx, 222, 3)
        else
            self:setColor(col, 0.5)
            love.graphics.circle("line", mx, 222, 3)
        end
    end

    -- Track identity + the active track's timing settings
    local timing
    if track.isLane then
        -- track C has no quantize grid or swing: its box length (GRID row) instead
        local _, unit = Instruments:getDefinition("lane"):unit(track.state)
        timing = { { "BOX " .. unit, col, col, col, 0.16 } }
    else
        timing = {
            { "GRID " .. grid.label, col, col, col, 0.16 },
            { string.format("SWING %d%%", math_floor((track.swing or 0.5) * 100 + 0.5)), col, col, col, 0.16 },
        }
    end
    table.insert(timing, 1, { Looper:slotLabel(track.slot) .. " - " .. track.name, trackCol, nil, trackCol })
    self:drawCapsuleRow(cx, 296, 16, timing)
end

function Chrome:drawEraseView(track, def)
    local C = Config.COLORS
    self:setColor(C.RED)
    love.graphics.setFont(self.fontLarge)
    local ew = self.fontLarge:getWidth("ASTRAL ERASE")
    love.graphics.print("ASTRAL ERASE", math_floor(320 - ew * 0.5), 142)

    love.graphics.setFont(self.fontSmall)
    self:setColor(C.TEXT)
    if def and def.ERASE then
        -- the instrument's erase map: what each face button clears
        local parts = {}
        for _, btn in ipairs({ "B", "A", "Y", "X" }) do
            local entry = def.ERASE[btn]
            if entry then parts[#parts + 1] = btn .. " - " .. (entry.label or table.concat(entry.actions, " + ")) end
        end
        local line = table.concat(parts, "   ")
        if self.fontSmall:getWidth(line) > 200 then love.graphics.setFont(self.fontTiny) end
        love.graphics.print(line, 232, 178)
        love.graphics.setFont(self.fontSmall)
    else
        love.graphics.print("B / A / Y / X - Clear pad lane", 232, 178)
    end
    love.graphics.print("LEFT / L1 - Undo last overdub", 232, 202)
    love.graphics.print("START - Clear entire track", 232, 226)
    self:setColor(C.MUTED)
    love.graphics.print("+ hold SELECT - Fresh session", 232, 250)
    love.graphics.print(string.format("%d EVENTS ON TRACK %s", #track.events, Looper:slotLabel(track.slot)), 244, 276)
end

-- Hold L2 + R2 + SELECT: a ring fills over NEW_HOLD seconds
function Chrome:drawFreshSessionView()
    local C = Config.COLORS
    local cx, cy, r = 320, 176, 34
    local frac = math_min(1.0, Modes.newHold / Modes.NEW_HOLD)
    local done = Modes.newFired

    self:setColor(C.RED, 0.25)
    love.graphics.setLineWidth(4)
    love.graphics.circle("line", cx, cy, r)
    if frac > 0 then
        self:setColor(C.RED)
        love.graphics.arc("line", "open", cx, cy, r, -math_pi * 0.5, -math_pi * 0.5 + frac * math_pi * 2.0)
    end
    love.graphics.setLineWidth(1)
    if done then self:drawStarGlint(cx, cy, 12, C.RED, 1.0) end

    local function centred(text, y, font, col)
        love.graphics.setFont(font)
        self:setColor(col)
        love.graphics.print(text, math_floor(320 - font:getWidth(text) * 0.5), y)
    end
    if done then
        centred("FRESH", 222, self.fontLarge, C.RED)
        centred("LET GO - UNDO WITH L2 + R2 + LEFT", 246, self.fontSmall, C.TEXT)
    else
        centred("KEEP HOLDING", 222, self.fontLarge, C.RED)
        centred("CLEARS THE NOTES ON ALL 4 TRACKS", 246, self.fontSmall, C.TEXT)
        centred("TEMPO, KEY, SOUNDS AND EFFECTS STAY", 264, self.fontSmall, C.MUTED)
    end
end

end
