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
    local Song = package.loaded["src.song"]
    local songOn = Song and Song:isOn()
    local songPage = songOn and Song.page and (self:isPlayMode(mode) or mode == "TRACK")
    if songPage then instCol = Config.COLORS.SONG end

    -- Frame with corner accent diamonds
    self:drawFrame(8, 6, 624, 38, C.GRID, 1, instCol)

    -- Left Active Track Accent Block
    self:setColor(Config.shade(instCol, 0.22))
    love.graphics.rectangle("fill", 12, 10, 126, 30, 4, 4)
    self:setColor(instCol)
    love.graphics.rectangle("fill", 12, 10, 3.5, 30, 1.5, 1.5)
    self:drawStarGlint(26, 25, 5.5, instCol, 1.0)

    self:setColor(C.TEXT)
    love.graphics.setFont(self.fontSmall)
    love.graphics.print(songPage and "S - SONG" or string.format("%s - %s", Looper:slotLabel(sl), track and track.name or "TRK"), 36, 17)

    -- Hairline dividers & Metadata
    self:setColor(C.GRID)
    love.graphics.line(146, 13, 146, 37)

    love.graphics.setFont(self.fontTiny)
    self:setColor(C.MUTED)
    if track and track.isLane then
        -- track C has no grid: its lane length instead
        love.graphics.print("LANE", 156, 11)
        love.graphics.setFont(self.fontSmall)
        self:setColor(instCol)
        love.graphics.print(Looper:getLaneBars() .. "B", 156, 21)
    else
        love.graphics.print("GRID", 156, 11)
        love.graphics.setFont(self.fontSmall)
        self:setColor((grid.id ~= "FREE") and instCol or C.MUTED)
        love.graphics.print(grid.label, 156, 21)
    end

    self:setColor(C.GRID)
    love.graphics.line(200, 13, 200, 37)

    love.graphics.setFont(self.fontTiny)
    self:setColor(C.MUTED)
    if songOn then
        -- song mode: the pattern playing, and its length
        local Session = require("src.session")
        love.graphics.print("SONG", 210, 11)
        love.graphics.setFont(self.fontSmall)
        self:setColor(Config.COLORS.SONG)
        love.graphics.print((Session.patternSlot or "-") .. " " .. Looper.bars .. "B", 210, 21)
    else
        love.graphics.print("LOOP", 210, 11)
        love.graphics.setFont(self.fontSmall)
        self:setColor(C.TEXT)
        love.graphics.print(Looper.bars .. " BAR", 210, 21)
    end

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
    -- where in track C's lane we are, when it has chords
    local lane = Looper:getLane()
    if lane and Harmony:source() == lane then
        local laneBar = math_floor(Looper:lanePos() / Looper.BAR_TICKS) + 1
        love.graphics.print(laneBar .. "/" .. Looper:getLaneBars(), 408 + self.fontTiny:getWidth("CHORD") + 6, 11)
    end
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
            self:drawStarGlint(bx, by, 7, mc, 1.0)
            self:drawDiamond(bx, by, 2, C.BG)
        else
            self:drawDiamond(bx, by, isBar and 3 or 1.8, isBar and instCol or C.DIM)
        end
    end

    -- Right Mode Status Tag (rx=4) with vector icon + ASCII text
    local modeConfigs = {
        NORMAL    = { label = "PLAY",       icon = "GLINT",   stroke = C.GRID,   fill = C.PANEL_HI, txt = C.TEXT,   iconCol = C.AMBER },
        REC_LATCH = { label = "REC LATCH",   icon = "DOT",     stroke = C.RED,    fill = C.RED,      txt = C.BG,     iconCol = C.BG },
        REC_HOLD  = { label = "REC HOLD",    icon = "DOT",     stroke = C.RED,    fill = C.RED,      txt = C.BG,     iconCol = C.BG },
        TRACK     = { label = "TRACK", icon = "GLINT",   stroke = C.PINK,   fill = C.PINK,     txt = C.BG,     iconCol = C.BG },
        MIX       = { label = "MIX",         icon = "FADERS",  stroke = C.SILVER, fill = C.SILVER,   txt = C.BG,     iconCol = C.BG },
        TRANSPORT = { label = "CLOCK",       icon = "GLINT",   stroke = C.AMBER,  fill = C.AMBER,    txt = C.BG,     iconCol = C.BG },
        ERASE     = { label = "ERASE",       icon = "CROSS",   stroke = C.RED,    fill = C.RED,      txt = C.BG,     iconCol = C.BG },
        NEW       = { label = "FRESH", icon = "CROSS",   stroke = C.RED,    fill = C.RED,      txt = C.BG,     iconCol = C.BG },
        FX        = { label = "LIVE FX",     icon = "GLINT",   stroke = C.SILVER, fill = C.SILVER,   txt = C.BG,     iconCol = C.BG },
        MENU_HOLD = { label = "MENU",        icon = "GLINT",   stroke = C.CYAN,   fill = C.PANEL_HI, txt = C.CYAN,   iconCol = C.CYAN },
        MENU      = { label = "MENU",        icon = "GLINT",   stroke = C.CYAN,   fill = C.CYAN,     txt = C.BG,     iconCol = C.BG },
    }
    local mc = modeConfigs[mode] or modeConfigs.NORMAL
    -- Count-in: recording is armed and the beats left are counted down
    if Song and Song.recording then
        mc = { label = "SONG REC", icon = "DOT", stroke = C.RED, fill = C.RED, txt = C.BG, iconCol = C.BG }
    elseif Song and Song.armed then
        mc = { label = "SONG ARMED", icon = "DOT", stroke = C.RED, fill = C.PANEL_HI, txt = C.RED, iconCol = C.RED }
    elseif Song and Song.playing and mode == "NORMAL" then
        mc = { label = "SONG", icon = "PLAY", stroke = C.SONG, fill = C.PANEL_HI, txt = C.SONG, iconCol = C.SONG }
    end
    local countBeats = Modes:countInBeats()
    if countBeats and mode == "NORMAL" then
        mc = { label = "COUNT-IN  " .. countBeats, icon = "DOT", stroke = C.RED, fill = C.PANEL_HI, txt = C.RED, iconCol = C.RED }
    end
    local mockGear = false
    if self.MOCK and (mode == "TRACK" or (self.MOCK == "D" and self.MOCK_PAGES[mode])) then
        mc = { label = mc.label, icon = "NONE", stroke = C.SILVER, fill = C.PANEL_HI, txt = C.SILVER, iconCol = C.SILVER }
        mockGear = true
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
    elseif mockGear then
        self:mockGlyph(mode, icx, icy, C.SILVER)
    elseif mc.icon == "GLINT" then
        self:drawStarGlint(icx, icy, 5.0, mc.iconCol, 1.0)
    end

    love.graphics.setFont(self.fontSmall)
    self:setColor(mc.txt)
    love.graphics.print(mc.label, bx + 32, by + 6)
    if mockGear then self:mockGlowRect(bx, by, bw, bh, 4, { 0.86, 0.92, 1.0, 1.0 }, 0.7) end
end

end
