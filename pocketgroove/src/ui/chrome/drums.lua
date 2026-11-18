-- ============================================================================
-- src/ui/chrome/drums.lua — Drum lanes (the Drums stage view)
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
-- DRUM LANES: one lane per pad, ordered like the button diamond (X, Y, A, B)
-- ============================================================================
function Chrome:drawMiniDiamond(x, y, pad, col)
    local C = Config.COLORS
    local pos = { X = { 0, -4 }, Y = { -4, 0 }, A = { 4, 0 }, B = { 0, 4 } }
    for k, o in pairs(pos) do
        self:setColor(k == pad and col or C.DIM)
        love.graphics.circle("fill", x + o[1], y + o[2], k == pad and 1.9 or 1.4)
    end
end

function Chrome:drawDrumLanes(def, state, track, col)
    local C = Config.COLORS
    local lx, lw = 205, 230
    local totalSteps = Looper:getTotalSixteenths()
    local isRec = Input:isRecording()

    for i, pad in ipairs(def.PADS) do
        local top = 88 + (i - 1) * 44
        local flash = state.padFlash[pad] or 0.0
        local down = Input.down[pad]
        if def.padDown then down = def:padDown(pad) end
        local lit = flash > 0.05 or (down and Modes.current ~= "FX")

        if lit then
            self:setColor(col, 0.16 + flash * 0.12)
            love.graphics.rectangle("fill", 204, top, 232, 40, 4, 4)
            self:setColor(col)
            love.graphics.rectangle("line", 204, top, 232, 40, 4, 4)
        end

        -- Header: mini diamond, pad letter, sound name, info
        self:drawMiniDiamond(212, top + 8, pad, col)
        love.graphics.setFont(self.fontTiny)
        self:setColor(col)
        love.graphics.print(pad, 221, top + 2)
        love.graphics.setFont(self.fontSmall)
        self:setColor(C.TEXT)
        local short = def:getPadSound(state, pad).short
        love.graphics.print(short, 232, top)
        -- tune and level, when they aren't the defaults
        local tune, level = state.padTune[pad] or 0, state.padLevel[pad] or 1.0
        local extra = {}
        if tune ~= 0 then extra[#extra + 1] = string.format("%+d", tune) end
        if math_abs(level - 1.0) > 0.001 then extra[#extra + 1] = math_floor(level * 100 + 0.5) .. "%" end
        if #extra > 0 then
            love.graphics.setFont(self.fontTiny)
            self:setColor(C.MUTED)
            love.graphics.print(table.concat(extra, " "), 232 + self.fontSmall:getWidth(short) + 6, top + 2)
        end

        local count = Looper:countTrackAction(track.slot, pad)
        local info = count .. (count == 1 and " HIT" or " HITS")
        if lit and state.expressionName ~= "NORMAL" then info = state.expressionName end
        love.graphics.setFont(self.fontTiny)
        self:setColor(lit and col or C.MUTED)
        local iw = self.fontTiny:getWidth(info)
        love.graphics.print(info, math_floor(434 - iw), top + 2)

        -- Step strip
        local sy = top + 16
        self:setColor(C.PANEL_HI)
        love.graphics.rectangle("fill", 204, sy, 232, 22, 2, 2)
        self:setColor(C.GRID)
        love.graphics.rectangle("line", 204, sy, 232, 22, 2, 2)
        for st = 4, totalSteps - 1, 4 do
            local gx = math_floor(lx + (st / totalSteps) * lw) + 0.5
            self:setColor((st % 16 == 0) and C.DIM or C.GRID)
            love.graphics.line(gx, sy + 1, gx, sy + 21)
        end

        -- Hits: height = dynamics, tick before = flam, slivers = ratchet
        local base = sy + 20
        local bw = (totalSteps > 32) and 2.5 or 4
        for _, ev in ipairs(track.events) do
            if ev.action == pad then
                local x = lx + Looper:evPhase(ev) * lw + 0.5
                local vel = ev.vel or 0.85
                local h = (vel >= 0.95) and 17 or ((vel <= 0.5) and 6 or 11)
                local a = (vel <= 0.5) and 0.55 or 1.0
                local c = track.muted and C.DIM or col
                if ev.orn == "flam" then
                    self:setColor(c, 0.65)
                    love.graphics.rectangle("fill", x - 2.8, base - h * 0.5, 1.2, h * 0.5)
                end
                self:setColor(c, a)
                if ev.ratchet and ev.ratchet > 1 then
                    for k = 0, 2 do
                        local hh = h * (1.0 - k * 0.2)
                        love.graphics.rectangle("fill", x + k * (bw / 3 + 0.3), base - hh, 1.2, hh)
                    end
                elseif ev.chance and ev.chance < 1.0 then
                    -- a "maybe" hit: hollow
                    love.graphics.rectangle("line", x + 0.5, base - h + 0.5, bw, h - 1)
                else
                    love.graphics.rectangle("fill", x, base - h, bw, h)
                    if vel >= 0.95 then
                        self:setColor(C.TEXT, 0.8)
                        love.graphics.rectangle("fill", x, base - h, bw, 2)
                    end
                end
            end
        end
    end

    -- Shared playhead across the lanes
    local px = math_floor(lx + Looper.phase * lw) + 0.5
    local phCol = isRec and C.RED or C.TEXT
    self:setColor(phCol, 0.9)
    love.graphics.setLineWidth(1.5)
    love.graphics.line(px, 102, px, 266)
    love.graphics.setLineWidth(1)
    love.graphics.polygon("fill", px - 3.5, 97, px + 3.5, 97, px, 102)

    -- Status capsules
    local items = {}
    if state.expressionName ~= "NORMAL" then
        table.insert(items, { state.expressionName, col, col, C.BG })
    else
        table.insert(items, { "NORMAL", C.GRID, C.PANEL_HI, C.MUTED })
    end
    if state.repeatLabel ~= "OFF" then
        table.insert(items, { "REPEAT " .. state.repeatLabel, col, col, C.BG })
    else
        table.insert(items, { "REPEAT OFF", C.GRID, C.PANEL_HI, C.MUTED })
    end
    if state.variation ~= "OFF" then
        table.insert(items, { "VAR " .. state.variation, C.GRID, C.PANEL_HI, col })
    end
    if (track.swing or 0.5) > 0.5 then
        table.insert(items, { string.format("SWING %d%%", math_floor(track.swing * 100 + 0.5)), C.GRID, C.PANEL_HI, C.TEXT })
    end
    self:drawCapsuleRow(320, 274, 18, items)
end

end
