-- ============================================================================
-- src/ui/chrome/mixer.lua — Mixer page
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
-- MODE VIEWS: MIXER, TRACK PAGE, TRANSPORT, ERASE
-- ============================================================================
function Chrome:drawMixerView(t)
    local C = Config.COLORS
    for i = 1, 5 do
        local x = 212 + (i - 1) * 44
        local isMaster = (i == 5)
        local trk = not isMaster and Looper.tracks[i] or nil
        local lvl = isMaster and Synth.masterVolume or trk.volume
        local isSelected = (Modes.mixTrack == i)
        local isMuted = not isMaster and trk.muted or false
        local col = isMaster and C.TEXT or self:trackColor(i)

        if isSelected then
            self:setColor(col, 0.22)
            love.graphics.rectangle("fill", x - 2, 118, 40, 166, 4, 4)
            self:setColor(col)
            love.graphics.rectangle("line", x - 2, 118, 40, 166, 4, 4)
        end

        love.graphics.setFont(self.fontSmall)
        self:setColor(isMuted and C.DIM or col)
        local label = isMaster and "MST" or trk.shortName
        local lw = self.fontSmall:getWidth(label)
        love.graphics.print(label, math_floor(x + 18 - lw * 0.5), 126)

        -- Segmented LED bar (10 segments)
        local lit = math_floor(lvl * 10 + 0.5)
        for k = 1, 10 do
            local y = 252 - k * 11
            local on = (k <= lit)
            self:setColor(isMuted and C.GRID or (on and col or C.PANEL_HI))
            love.graphics.rectangle("fill", x + 3, y + 2, 22, 7, 2, 2)
        end

        -- Live meter beside the fader: what is sounding now, with a peak mark.
        -- The master's turns red when the sum is likely to clip.
        local meter = isMaster and Synth.meters.master or Synth.meters[i]
        local my, mh = 144, 106
        local hot = isMaster and meter.peak > Synth.METER_HOT
        self:setColor(C.PANEL_HI)
        love.graphics.rectangle("fill", x + 28, my, 5, mh, 2, 2)
        local lh = math_floor(mh * math_min(1.0, meter.level))
        if lh > 0 then
            self:setColor(hot and C.RED or C.TEXT, 0.9)
            love.graphics.rectangle("fill", x + 28, my + mh - lh, 5, lh, 2, 2)
        end
        local ph = math_floor(mh * math_min(1.0, meter.peak))
        if ph > 1 then
            self:setColor(hot and C.RED or col)
            love.graphics.rectangle("fill", x + 27, my + mh - ph - 1, 7, 2)
        end

        self:drawTag(x + 2, 260, 32, 18, isMuted and "M" or "ON", isMuted and C.RED or C.GRID, isMuted and C.RED or C.PANEL_HI, isMuted and C.BG or C.MUTED, self.fontTiny)
    end
end

end
