-- ============================================================================
-- src/ui/chrome/footer.lua — Footer strip under the stage: hints and toasts
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
-- BOTTOM FOOTER HINT STRIP (y: 322..355)
-- ============================================================================
function Chrome:drawFooterStrip(def)
    local C = Config.COLORS
    local mode = Modes.current or "NORMAL"
    local hintText = "[L2] Record   [SELECT] Track   [SELECT+R2] Mix   [START] Transport"
    local hintCol = C.MUTED

    if mode == "REC_LATCH" then
        hintText = "REC LATCHED | Tap L2 to stop | Hold L2 for momentary punch-in"
        hintCol = C.RED
    elseif mode == "REC_HOLD" then
        hintText = "REC (HOLD) | Release L2 to stop punch-in | Quick tap latches"
        hintCol = C.RED
    elseif mode == "TRACK" then
        hintText = "TRACK | UP/DN Row | < > Change | L1/R1 Instrument (on release) | Face: FX on/off"
        hintCol = C.PINK
    elseif mode == "MIX" then
        hintText = "MIXER | < > Track | UP/DN Volume | B/A/Y/X Mute | L1/R1 Master"
        hintCol = C.SILVER
    elseif mode == "TRANSPORT" then
        hintText = "TRANSPORT | UP/DN BPM | < > Key | L1/R1 Scale | A Grid | Y+UP/DN Swing | X Click/Count"
        hintCol = C.AMBER
    elseif mode == "ERASE" then
        hintText = "ERASE | B/A/Y/X Clear pad | LEFT Undo | START Clear track | +SELECT Fresh"
    elseif mode == "NEW" then
        hintText = "FRESH SESSION | Hold 1 s: clear all notes | Undo: L2 + R2 + LEFT"
        hintCol = C.RED
    elseif mode == "FX" then
        hintText = "LIVE FX | UP Stutter | DN Slow | LEFT Filter | RIGHT Bitcrush | B/A/Y/X Mute"
        hintCol = C.SILVER
    elseif Looper.toastTimer > 0 then
        hintText = "> " .. Looper.toastText
        hintCol = C.AMBER
    end

    self:setColor(C.GRID)
    love.graphics.line(9, 322, 631, 322)
    self:setColor(C.BG)
    love.graphics.rectangle("fill", 9, 323, 622, 32, 4, 4)

    self:setColor(hintCol)
    love.graphics.setFont(self.fontSmall)
    love.graphics.print(hintText, 24, 331)
end

end
