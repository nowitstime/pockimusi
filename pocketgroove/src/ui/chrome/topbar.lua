-- ============================================================================
-- src/ui/chrome/topbar.lua — Region 1: the top status bar
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
-- REGION 1: TOP STATUS BAR (CROWN) (y: 6..44)
-- ============================================================================
function Chrome:drawTopBar()
    local C = Config.COLORS
    local sl = Looper.activeTrack
    local track = Looper.tracks[sl]
    local instCol = self:trackColor(sl)
    local grid = Looper:getTrackGrid(sl)
    local mode = Modes.current or "NORMAL"

    -- Frame with corner accent diamonds
    self:drawFrame(8, 6, 624, 38, C.GRID, 1, instCol)

    -- Left Active Track Accent Block
    self:setColor(instCol, 0.16)
    love.graphics.rectangle("fill", 12, 10, 126, 30, 4, 4)
    self:setColor(instCol)
    love.graphics.rectangle("fill", 12, 10, 3.5, 30, 1.5, 1.5)

    self:setColor(C.TEXT)
    love.graphics.setFont(self.fontSmall)
    love.graphics.print(string.format("%d - %s", sl, track and track.name or "TRK"), 24, 17)

    -- Hairline dividers & Metadata
    self:setColor(C.GRID)
    love.graphics.line(146, 13, 146, 37)

    love.graphics.setFont(self.fontTiny)
    self:setColor(C.MUTED)
    love.graphics.print("GRID", 156, 11)
    love.graphics.setFont(self.fontSmall)
    self:setColor((grid.id ~= "FREE") and C.MINT or C.MUTED)
    love.graphics.print(grid.label, 156, 21)

    self:setColor(C.GRID)
    love.graphics.line(200, 13, 200, 37)

    love.graphics.setFont(self.fontTiny)
    self:setColor(C.MUTED)
    love.graphics.print("LOOP", 210, 11)
    love.graphics.setFont(self.fontSmall)
    self:setColor(C.TEXT)
    love.graphics.print(Looper.bars .. " BAR", 210, 21)

    self:setColor(C.GRID)
    love.graphics.line(256, 13, 256, 37)

    -- Center Tempo, Key & Diamond Metronome
    love.graphics.setFont(self.fontSmall)
    self:setColor(C.TEXT)
    love.graphics.print(string.format("%d BPM", Looper.bpm), 268, 12)
    self:setColor(C.CYAN)
    love.graphics.print(Theory:getKeyLabel(), 332, 12)

    -- Current chord (what followers play over): lit when it comes from the
    -- harp (recorded or played live), dim when it's just the key's tonic
    local chord, chordFrom = Harmony:current()
    self:setColor(C.GRID)
    love.graphics.line(398, 13, 398, 37)
    love.graphics.setFont(self.fontTiny)
    self:setColor(C.MUTED)
    love.graphics.print("CHORD", 408, 11)
    love.graphics.setFont(self.fontSmall)
    self:setColor(chordFrom == "tonic" and C.MUTED or C.CYAN)
    love.graphics.print(Theory:chordName(chord), 408, 21)

    local totalBeats = Looper:getTotalBeats()
    local sp = (totalBeats == 8) and 16 or 8.5
    for b = 1, totalBeats do
        local bx = 271 + (b - 1) * sp
        local by = 33
        local isBar = ((b - 1) % 4 == 0)
        local isCur = (Looper.playing and Looper.currentBeat == b)

        if isCur then
            local mc = (mode == "REC_LATCH" or mode == "REC_HOLD") and C.RED or C.TEXT
            self:drawStarGlint(bx, by, 6.5, mc, 1.0)
            self:drawDiamond(bx, by, 2.5, C.TEXT)
        else
            self:drawDiamond(bx, by, isBar and 2.5 or 1.6, isBar and C.MUTED or C.DIM)
        end
    end

    -- Right Mode Status Tag (rx=4) with vector icon + ASCII text
    local modeConfigs = {
        NORMAL    = { label = "JAM SAFE",   icon = "STAR",    stroke = C.GRID,   fill = C.PANEL_HI, txt = C.MUTED,  iconCol = C.GRID },
        REC_LATCH = { label = "REC LATCH",   icon = "DOT",     stroke = C.RED,    fill = C.RED,      txt = C.BG,     iconCol = C.BG },
        REC_HOLD  = { label = "REC HOLD",    icon = "DOT",     stroke = C.RED,    fill = C.RED,      txt = C.BG,     iconCol = C.BG },
        TRACK     = { label = "TRACK SOUND", icon = "GLINT",   stroke = C.PINK,   fill = C.PINK,     txt = C.BG,     iconCol = C.BG },
        MIX       = { label = "MIXER",       icon = "FADERS",  stroke = C.SILVER, fill = C.SILVER,   txt = C.BG,     iconCol = C.BG },
        TRANSPORT = { label = "TRANSPORT",   icon = "GLINT",   stroke = C.AMBER,  fill = C.AMBER,    txt = C.BG,     iconCol = C.BG },
        ERASE     = { label = "ERASE",       icon = "CROSS",   stroke = C.RED,    fill = C.RED,      txt = C.BG,     iconCol = C.BG },
        NEW       = { label = "FRESH START", icon = "CROSS",   stroke = C.RED,    fill = C.RED,      txt = C.BG,     iconCol = C.BG },
        FX        = { label = "LIVE FX",     icon = "GLINT",   stroke = C.SILVER, fill = C.SILVER,   txt = C.BG,     iconCol = C.BG },
    }
    local mc = modeConfigs[mode] or modeConfigs.NORMAL
    -- Count-in: recording is armed and the beats left are counted down
    local countBeats = Modes:countInBeats()
    if countBeats and mode == "NORMAL" then
        mc = { label = "COUNT-IN  " .. countBeats, icon = "DOT", stroke = C.RED, fill = C.PANEL_HI, txt = C.RED, iconCol = C.RED }
    end
    local bx, by, bw, bh = 488, 11, 138, 28
    self:setColor(mc.fill, (mode == "NORMAL") and 1.0 or 0.92)
    love.graphics.rectangle("fill", bx, by, bw, bh, 4, 4)
    self:setColor(mc.stroke)
    love.graphics.rectangle("line", bx, by, bw, bh, 4, 4)

    -- Vector icon before label
    local icx, icy = bx + 18, by + 14
    if mc.icon == "STAR" then
        self:drawStarGlint(icx, icy, 4.2, mc.iconCol, 0.9)
    elseif mc.icon == "DOT" then
        self:setColor(mc.iconCol)
        love.graphics.circle("fill", icx, icy, 3.8)
    elseif mc.icon == "DIAMOND" then
        self:drawDiamond(icx, icy, 3.5, mc.iconCol)
    elseif mc.icon == "FADERS" then
        self:setColor(mc.iconCol)
        love.graphics.rectangle("fill", icx - 4, icy - 4.5, 2.5, 9, 1, 1)
        love.graphics.rectangle("fill", icx + 1, icy - 4.5, 2.5, 9, 1, 1)
    elseif mc.icon == "PLAY" then
        self:setColor(mc.iconCol)
        love.graphics.polygon("fill", icx - 3, icy - 4.5, icx + 4, icy, icx - 3, icy + 4.5)
    elseif mc.icon == "CROSS" then
        self:setColor(mc.iconCol)
        love.graphics.setLineWidth(1.8)
        love.graphics.line(icx - 3.5, icy - 3.5, icx + 3.5, icy + 3.5)
        love.graphics.line(icx - 3.5, icy + 3.5, icx + 3.5, icy - 3.5)
        love.graphics.setLineWidth(1)
    elseif mc.icon == "GLINT" then
        self:drawStarGlint(icx, icy, 5.0, mc.iconCol, 1.0)
    end

    love.graphics.setFont(self.fontSmall)
    self:setColor(mc.txt)
    love.graphics.print(mc.label, bx + 32, by + 6)
end

end
