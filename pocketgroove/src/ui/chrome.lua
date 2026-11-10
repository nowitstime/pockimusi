-- ============================================================================
-- src/ui/chrome.lua — Shared 640x480 Vector UI Chrome (Top Bar, HUD, Tape Deck)
-- ============================================================================

local Config      = require("src.config")
local Theory      = require("src.theory")
local Input       = require("src.input")
local Synth       = require("src.synth")
local Looper      = require("src.looper")
local Instruments = require("src.instruments")

local clamp      = Config.clamp
local math_floor = math.floor
local math_min   = math.min

local Chrome = {
    fontSmall = nil,
    fontMed   = nil,
    fontLarge = nil,
    fontHuge  = nil,
}

function Chrome:init()
    self.fontSmall = love.graphics.newFont(11)
    self.fontMed   = love.graphics.newFont(13)
    self.fontLarge = love.graphics.newFont(17)
    self.fontHuge  = love.graphics.newFont(30)
    love.graphics.setLineStyle("smooth")
end

function Chrome:setColor(c, alphaOverride)
    if alphaOverride then
        love.graphics.setColor(c[1], c[2], c[3], alphaOverride)
    else
        love.graphics.setColor(c[1], c[2], c[3], c[4] or 1.0)
    end
end

function Chrome:drawBadge(x, y, w, h, text, bgColor, textColor, font)
    self:setColor(bgColor)
    love.graphics.rectangle("fill", x, y, w, h, 4, 4)
    self:setColor(textColor)
    local f = font or self.fontSmall
    love.graphics.setFont(f)
    local tw = f:getWidth(text)
    local th = f:getHeight()
    love.graphics.print(text, math_floor(x + (w - tw) * 0.5), math_floor(y + (h - th) * 0.5))
end

-- ----------------------------------------------------------------------------
-- Region 1: Top Status Bar (y: 0..48)
-- ----------------------------------------------------------------------------
function Chrome:drawTopBar()
    local C = Config.COLORS
    self:setColor(C.PANEL)
    love.graphics.rectangle("fill", 8, 6, 624, 42, 6, 6)
    self:setColor(C.GRID)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", 8, 6, 624, 42, 6, 6)

    local slotIdx = Looper.activeTrack
    local track = Looper.tracks[slotIdx]
    local instColor = Config.TRACK_COLORS[slotIdx]
    local grid = Looper:getTrackGrid(slotIdx)
    local badgeTitle = string.format("%d: %s", slotIdx, track and track.name or "TRACK")

    -- Left: Active Track/Instrument Badge + Quantize Grid Badge + Bars Badge
    self:drawBadge(14, 13, 120, 28, badgeTitle, instColor, C.BG, self.fontSmall)

    local qBg = (grid.id ~= "FREE") and C.PANEL_HI or C.BG
    local qFg = (grid.id ~= "FREE") and C.MINT or C.MUTED
    self:drawBadge(138, 13, 56, 28, "Q:" .. grid.label, qBg, qFg, self.fontSmall)

    self:drawBadge(198, 13, 46, 28, Looper.bars .. " BAR", C.PANEL_HI, C.TEXT, self.fontSmall)

    -- Center: BPM | KEY | Beat Metronome Dots
    love.graphics.setFont(self.fontSmall)
    self:setColor(C.TEXT)
    love.graphics.print(string.format("BPM:%d", Looper.bpm), 252, 12)
    self:setColor(C.CYAN)
    love.graphics.print("KEY:" .. Theory:getKeyLabel(), 316, 12)

    local totalBeats = Looper:getTotalBeats()
    local dotSpacing = (totalBeats == 8) and 17 or 9
    local dotStartX = 256
    for b = 1, totalBeats do
        local bx = dotStartX + (b - 1) * dotSpacing
        local by = 36
        local isBarStart = ((b - 1) % 4 == 0)
        local isCurrent = (Looper.playing and Looper.currentBeat == b)
        local radius = isBarStart and 4.0 or 2.5

        if isCurrent then
            self:setColor(Input.down.L2 and C.ORANGE or C.TEXT)
            love.graphics.circle("fill", bx, by, radius + 1.2)
        else
            self:setColor(isBarStart and C.MUTED or C.DIM)
            love.graphics.circle("fill", bx, by, radius)
        end
    end

    -- Right: Mode / Clutch Status Badge
    if Input.down.L2 and Input.down.R2 then
        self:drawBadge(470, 13, 154, 28, "✕ L2+R2: ERASE", C.RED, C.BG, self.fontSmall)
    elseif Input.down.SELECT then
        self:drawBadge(470, 13, 154, 28, "⚙ SELECT: CONFIGURE", C.CYAN, C.BG, self.fontSmall)
    elseif Input.down.R2 then
        local fxLabel = "R2: FX / MUTE"
        if Synth.fxBeatRepeat then fxLabel = "FX: 1/16 STUTTER"
        elseif Synth.fxHalfSpeed then fxLabel = "FX: HALF-SPEED"
        elseif Synth.fxLowPass then fxLabel = "FX: DUCK SWELL"
        elseif Synth.fxBitcrush then fxLabel = "FX: BITCRUSH"
        end
        self:drawBadge(470, 13, 154, 28, fxLabel, C.AMBER, C.BG, self.fontSmall)
    elseif Input.down.L2 then
        self:drawBadge(470, 13, 154, 28, "● L2: RECORDING", C.ORANGE, C.BG, self.fontSmall)
    else
        self:drawBadge(470, 13, 154, 28, "L2: JAM SAFE", C.PANEL_HI, C.MUTED, self.fontSmall)
    end
end

-- ----------------------------------------------------------------------------
-- Region 2: Center Stage Visualizer (y: 54..358)
-- ----------------------------------------------------------------------------
function Chrome:drawCenterStage()
    local C = Config.COLORS
    self:setColor(C.PANEL)
    love.graphics.rectangle("fill", 8, 54, 624, 304, 6, 6)

    -- Border glows based on held modifier clutch
    if Input.down.L2 and Input.down.R2 then
        self:setColor(C.RED)
        love.graphics.setLineWidth(2)
    elseif Input.down.L2 then
        self:setColor(C.ORANGE)
        love.graphics.setLineWidth(2)
    elseif Input.down.SELECT then
        self:setColor(C.CYAN)
        love.graphics.setLineWidth(2)
    elseif Input.down.R2 then
        self:setColor(C.AMBER)
        love.graphics.setLineWidth(2)
    else
        self:setColor(C.GRID)
        love.graphics.setLineWidth(1)
    end
    love.graphics.rectangle("line", 8, 54, 624, 304, 6, 6)
    love.graphics.setLineWidth(1)

    -- Delegate stage rendering to the active track's assigned instrument module
    local def, state, track = Instruments:getTrackInstrument(Looper.activeTrack)
    if def and def.drawStage and track then
        def:drawStage(state, track, self)
    end

    -- Reactive Modifier HUD Bar at bottom of Center Stage (y: 320..352)
    self:drawReactiveModifierHUD(def)
end

function Chrome:drawReactiveModifierHUD(activeInstDef)
    local C = Config.COLORS
    local x, y, w, h = 14, 320, 612, 32

    if Input.down.L2 and Input.down.R2 then
        self:setColor(C.RED, 0.18)
        love.graphics.rectangle("fill", x, y, w, h, 4, 4)
        self:setColor(C.RED)
        love.graphics.rectangle("line", x, y, w, h, 4, 4)
        love.graphics.setFont(self.fontSmall)
        love.graphics.print("ERASE:  [B/Y/A/X] Clear Pad   [LEFT/L1] Undo Take   [START] Clear Track", x + 12, y + 9)

    elseif Input.down.SELECT then
        self:setColor(C.CYAN, 0.16)
        love.graphics.rectangle("fill", x, y, w, h, 4, 4)
        self:setColor(C.CYAN)
        love.graphics.rectangle("line", x, y, w, h, 4, 4)
        love.graphics.setFont(self.fontSmall)
        local hint = (activeInstDef and activeInstDef.getSelectHint and activeInstDef:getSelectHint())
            or "CONFIGURE:  [U/D] BPM   [L/R] Key/Scale   [START] 2/4 Bars   (Quick Tap SELECT: Next Track)"
        love.graphics.print(hint, x + 10, y + 9)

    elseif Input.down.L2 then
        self:setColor(C.ORANGE, 0.16)
        love.graphics.rectangle("fill", x, y, w, h, 4, 4)
        self:setColor(C.ORANGE)
        love.graphics.rectangle("line", x, y, w, h, 4, 4)
        love.graphics.setFont(self.fontSmall)
        love.graphics.print("RECORD:  [B/Y/A/X] Overdub   [R2] Erase   [SELECT] Grid   [START] Clear Track", x + 12, y + 9)

    elseif Input.down.R2 then
        self:setColor(C.AMBER, 0.16)
        love.graphics.rectangle("fill", x, y, w, h, 4, 4)
        self:setColor(C.AMBER)
        love.graphics.rectangle("line", x, y, w, h, 4, 4)
        love.graphics.setFont(self.fontSmall)
        love.graphics.print("FX / MUTE:  [B/A/Y/X] Mute 1-4   [UP] Stutter   [DN] Slow   [LT] Duck   [RT] Crush", x + 12, y + 9)

    else
        self:setColor(C.BG, 0.85)
        love.graphics.rectangle("fill", x, y, w, h, 4, 4)
        love.graphics.setFont(self.fontSmall)
        if Looper.toastTimer > 0 then
            self:setColor(C.AMBER)
            love.graphics.print("▸ " .. Looper.toastText, x + 12, y + 9)
        else
            self:setColor(C.MUTED)
            love.graphics.print("[L2] Record   [L2+R2] Erase   [SELECT] Configure   [R2] FX / Mute", x + 12, y + 9)
        end
    end
end

-- ----------------------------------------------------------------------------
-- Region 3: Bottom 4-Track Tape Deck (y: 364..476)
-- ----------------------------------------------------------------------------
function Chrome:drawTapeDeck()
    local C = Config.COLORS
    self:setColor(C.PANEL)
    love.graphics.rectangle("fill", 8, 364, 624, 110, 6, 6)
    self:setColor(C.GRID)
    love.graphics.rectangle("line", 8, 364, 624, 110, 6, 6)

    local timelineX = 148
    local timelineW = 472
    local rowH = 24
    local totalSixteenths = Looper:getTotalSixteenths()

    for tIdx = 1, 4 do
        local track = Looper.tracks[tIdx]
        local grid = Looper:getTrackGrid(tIdx)
        local ry = 370 + (tIdx - 1) * 26
        local isSelected = (Looper.activeTrack == tIdx)
        local tColor = Config.TRACK_COLORS[tIdx]
        local shortLabel = string.format("%d:%s", tIdx, track.shortName or "TRK")

        -- Left Track Header
        self:setColor(isSelected and tColor or C.PANEL_HI)
        love.graphics.rectangle("fill", 14, ry, 62, rowH - 2, 3, 3)
        self:setColor(isSelected and C.BG or C.TEXT)
        love.graphics.setFont(self.fontSmall)
        love.graphics.print(shortLabel, 18, ry + 5)

        -- Quantize Grid Badge (e.g. 1/4, 1/8, 1/16, 1/12T, FREE)
        self:drawBadge(80, ry, 36, rowH - 2, grid.label,
            (grid.id ~= "FREE") and C.PANEL_HI or C.BG,
            (grid.id ~= "FREE") and C.MINT or C.DIM,
            self.fontSmall)

        -- Mute Badge [ON / M]
        self:drawBadge(120, ry, 24, rowH - 2, track.muted and "M" or "ON",
            track.muted and C.RED or C.PANEL_HI,
            track.muted and C.BG or C.MUTED,
            self.fontSmall)

        -- Track Timeline Lane
        self:setColor(C.BG)
        love.graphics.rectangle("fill", timelineX, ry, timelineW, rowH - 2, 3, 3)

        -- Grid Ticks (supports 2 Bars = 32 steps or 4 Bars = 64 steps)
        for step = 0, totalSixteenths - 1 do
            local sx = timelineX + (step / totalSixteenths) * timelineW
            local isBarLine = (step % 16 == 0)
            local isBeatLine = (step % 4 == 0)
            if isBarLine then
                self:setColor(C.TEXT, 0.55)
                love.graphics.line(sx, ry + 1, sx, ry + rowH - 3)
            elseif isBeatLine then
                self:setColor(C.GRID)
                love.graphics.line(sx, ry + 3, sx, ry + rowH - 5)
            elseif Looper.bars == 2 then
                self:setColor(C.PANEL_HI)
                love.graphics.line(sx, ry + 2, sx, ry + 7)
            end
        end

        -- Recorded Event Pill Markers (height reflects velocity: Accent = tall, Ghost = short)
        for _, ev in ipairs(track.events) do
            local ex = timelineX + ev.phase * (timelineW - 5)
            local vel = ev.velocity or 0.85
            local pillH = clamp(math_floor((rowH - 8) * vel), 5, rowH - 6)
            local pillY = ry + math_floor((rowH - 2 - pillH) * 0.5)

            if track.muted then
                self:setColor(C.DIM)
            else
                self:setColor(tColor, clamp(0.45 + vel * 0.55, 0.4, 1.0))
            end
            love.graphics.rectangle("fill", ex, pillY, 4, pillH, 2, 2)
        end
    end

    -- Sweeping Playhead Line across all 4 tracks
    local playheadX = timelineX + Looper.phase * timelineW
    self:setColor(Input.down.L2 and C.ORANGE or C.TEXT)
    love.graphics.setLineWidth(2)
    love.graphics.line(playheadX, 368, playheadX, 470)
    love.graphics.polygon("fill", playheadX - 5, 366, playheadX + 5, 366, playheadX, 373)
    love.graphics.setLineWidth(1)
end

function Chrome:draw()
    local C = Config.COLORS
    love.graphics.clear(C.BG[1], C.BG[2], C.BG[3], 1.0)

    local winW, winH = love.graphics.getDimensions()
    local scale = math_min(winW / Config.SCREEN_W, winH / Config.SCREEN_H)
    local offsetX = math_floor((winW - Config.SCREEN_W * scale) * 0.5)
    local offsetY = math_floor((winH - Config.SCREEN_H * scale) * 0.5)

    love.graphics.push()
    love.graphics.translate(offsetX, offsetY)
    love.graphics.scale(scale, scale)

    self:drawTopBar()
    self:drawCenterStage()
    self:drawTapeDeck()

    love.graphics.pop()
end

return Chrome
