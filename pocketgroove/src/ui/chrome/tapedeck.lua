-- ============================================================================
-- src/ui/chrome/tapedeck.lua — Region 3: the tape deck (lanes, ribbons, playhead)
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
-- REGION 3: THEMATIC CONSTELLATION TAPE DECK (y: 362..474)
-- ============================================================================
-- A held note on a tape-deck lane: from x, w pixels long, wrapping from the
-- lane end (x1) back to its start (x0). `lit` = sounding now, `open` = still
-- being held while recording.
function Chrome:drawRibbon(x, w, x0, x1, cy, col, lit, open)
    local C = Config.COLORS
    w = math_max(w, 3)
    local h = 5            -- ribbon height (one sub-row of the lane per button)
    local segs = { { x, math.min(w, x1 - x) } }
    if x + w > x1 then
        table.insert(segs, { x0, x + w - x1 })
    end
    for _, sg in ipairs(segs) do
        local sx, sw = sg[1], math_max(sg[2], 1)
        self:setColor(col, lit and 0.35 or 0.18)
        love.graphics.rectangle("fill", sx, cy - h * 0.5, sw, h, 2, 2)
        self:setColor(col, lit and 1.0 or 0.75)
        love.graphics.rectangle("fill", sx, cy - 1, sw, 2, 1, 1)
    end
    -- Note start
    self:setColor(lit and C.TEXT or col)
    love.graphics.circle("fill", x, cy, lit and 2.3 or 1.9)
    if open then
        -- Growing end, pulsing
        local ex = x + w
        if ex > x1 then ex = x0 + (ex - x1) end
        local pulse = 0.6 + 0.4 * math.sin(love.timer.getTime() * 10)
        self:setColor(C.TEXT, pulse)
        love.graphics.circle("fill", ex, cy, 1.8)
    end
end

-- Held notes sit on one sub-row per button, ordered like the button diamond
Chrome.RIBBON_ROW = { X = -6, Y = -2, A = 2, B = 6 }
-- The four sub-rows, top to bottom, for an instrument's LANES
Chrome.LANE_ROW = { -6, -2, 2, 6 }

-- Where an event sits on its track's lane, as pixels from the lane's centre
-- line. An action the instrument names in LANES (a shoulder, say) goes on
-- that row, hits included; otherwise held notes go on their button's row and
-- hits on the centre line.
function Chrome:eventRow(def, ev)
    local lane = def.LANES and def.LANES[ev.action]
    if lane and self.LANE_ROW[lane] then return self.LANE_ROW[lane] end
    if (ev.len or 0) > 0 or ev.open then return self.RIBBON_ROW[ev.action] or 0 end
    return 0
end

function Chrome:drawTapeDeck()
    local C = Config.COLORS
    local activeCol = self:trackColor(Looper.activeTrack)
    local lx = 148
    local lw = 456
    local totalSixteenths = Looper:getTotalSixteenths()

    self:drawFrame(8, 362, 624, 112, C.GRID, 1, activeCol)

    -- Vertical divider between headers and lanes
    self:setColor(C.GRID)
    love.graphics.line(136, 368, 136, 468)

    -- Continuous bar & beat grid lines spanning the 4 threads
    for s = 0, totalSixteenths, 4 do
        local sx = lx + (s / totalSixteenths) * lw
        local isBar = (s % 16 == 0)
        self:setColor(isBar and C.GRID or C.PANEL_HI)
        love.graphics.line(sx, 370, sx, 466)
        if isBar then
            self:drawDiamond(sx, 368, 2.0, C.MUTED)
            self:drawDiamond(sx, 468, 2.0, C.MUTED)
        end
    end

    for tIdx = 1, 4 do
        local ry = 369 + (tIdx - 1) * 25
        local cy = ry + 11
        local isSel = (Looper.activeTrack == tIdx)
        local tColor = self:trackColor(tIdx)
        local track = Looper.tracks[tIdx]
        local grid = Looper:getTrackGrid(tIdx)

        -- Left Track Header
        if isSel then
            self:setColor(tColor, 0.14)
            love.graphics.rectangle("fill", 12, ry, 120, 22, 3, 3)
            self:drawStarGlint(19, cy, 4.5, tColor, 1.0)
        else
            self:drawDiamond(19, cy, 2.0, track.muted and C.DIM or tColor)
        end

        self:setColor(isSel and C.TEXT or C.MUTED)
        love.graphics.setFont(self.fontSmall)
        love.graphics.print(string.format("%d %s", tIdx, track.shortName or "TRK"), 28, ry + 3)

        self:setColor((grid.id ~= "FREE") and C.MINT or C.DIM)
        love.graphics.setFont(self.fontTiny)
        love.graphics.print(grid.label, 78, ry + 4)

        -- Mute Rune Tag (Diamond vs M)
        if track.muted then
            self:drawTag(112, ry + 2, 18, 18, "M", C.RED, C.RED, C.BG, self.fontTiny)
        else
            self:drawTag(112, ry + 2, 18, 18, "", C.GRID, C.PANEL_HI, tColor, self.fontTiny)
            self:drawDiamond(121, ry + 11, 2.6, tColor)
        end

        -- Constellation Thread Lane
        if isSel then
            self:setColor(tColor, 0.07)
            love.graphics.rectangle("fill", lx - 2, ry + 2, lw + 4, 18, 3, 3)
        end
        self:setColor(isSel and tColor or C.GRID, isSel and 0.55 or 0.8)
        love.graphics.line(lx, cy, lx + lw, cy)

        self:drawDiamond(lx, cy, isSel and 2.8 or 1.8, isSel and tColor or C.DIM)
        self:drawDiamond(lx + lw, cy, isSel and 2.8 or 1.8, isSel and tColor or C.DIM)

        -- Chord names along the chord-source lane, at each change (when there's room)
        if Harmony:source() == track then
            love.graphics.setFont(self.fontTiny)
            local lastName, lastX
            for _, ch in ipairs(Harmony:changes(track)) do
                local nm = Theory:chordName(ch.chord)
                local nx = lx + ch.tick / Looper:getLoopTicks() * (lw - 4)
                if nm ~= lastName and (not lastX or nx - lastX >= 26) then
                    self:setColor(track.muted and C.DIM or tColor, isSel and 1.0 or 0.75)
                    love.graphics.print(nm, math_floor(nx + 4), ry - 1)
                    lastName, lastX = nm, nx
                end
            end
        end

        -- Recorded events: beads for hits, ribbons for held notes
        local col = track.muted and C.DIM or tColor
        local loopTicks = Looper:getLoopTicks()
        local laneW = lw - 4
        local trackDef = Instruments:getDefinition(track.instrumentId)
        for _, ev in ipairs(track.events) do
            local x = lx + Looper:evPhase(ev) * laneW
            local len = ev.len or 0
            if ev.open then
                -- Being held while recording: grows up to the playhead
                len = (Looper.tick - ev.tick) % loopTicks
            end
            if len > 0 or ev.open then
                local lit = track.sounding[ev] or ev.open
                local ry2 = cy + self:eventRow(trackDef, ev)
                self:drawRibbon(x, len / loopTicks * laneW, lx, lx + laneW, ry2, col, lit, ev.open)
                -- Glide points: a tick above the ribbon for a glide up, below for down
                -- (tail glides land past the ribbon's end)
                if ev.bend then
                    local prevSemis = ev.semis or 0
                    for _, kf in ipairs(ev.bend) do
                      if kf.semis then                 -- (Pad tone keyframes have no pitch)
                        local bx = x + kf.dt / loopTicks * laneW
                        if bx > lx + laneW then bx = bx - laneW end
                        local up = (kf.semis or prevSemis) >= prevSemis
                        prevSemis = kf.semis or prevSemis
                        self:setColor(lit and C.TEXT or col)
                        love.graphics.setLineWidth(1.5)
                        if up then
                            love.graphics.line(bx, ry2 - 1, bx, ry2 - 5)
                        else
                            love.graphics.line(bx, ry2 + 1, bx, ry2 + 5)
                        end
                        love.graphics.setLineWidth(1)
                      end
                    end
                end
            else
                local vel = ev.vel or 0.85
                local hy = cy + self:eventRow(trackDef, ev)
                if vel >= 0.88 and not track.muted then
                    self:drawStarGlint(x, hy, 5.5, col, 0.95)
                    self:setColor(C.TEXT)
                    love.graphics.circle("fill", x, hy, 1.8)
                else
                    local radius = 2.0 + vel * 1.6
                    self:setColor(col, 0.22)
                    love.graphics.circle("fill", x, hy, radius + 1.5)
                    self:setColor(col)
                    love.graphics.circle("fill", x, hy, radius)
                end
            end
        end

        -- Level meter on far right
        local meter = Synth.meters[tIdx]
        local peak = math_min(1.0, meter.level)
        self:setColor(C.GRID)
        love.graphics.setLineWidth(2)
        love.graphics.line(616, ry + 3, 616, ry + 19)
        local mh = math_floor(16 * peak)
        if mh > 0 then
            self:setColor(col)
            love.graphics.setLineWidth(2.5)
            love.graphics.line(616, ry + 19 - mh, 616, ry + 19)
            self:drawDiamond(616, ry + 19 - mh, 2.2, col)
        end
        love.graphics.setLineWidth(1)
    end

    -- Shooting Star Sweeping Playhead
    local px = lx + Looper.phase * lw
    local isRec = (Modes.current == "REC_LATCH" or Modes.current == "REC_HOLD")
    local playCol = isRec and C.RED or C.TEXT

    -- Comet wake trailing behind playhead
    local wakeW = math_min(14, px - lx)
    if wakeW > 1 then
        self:setColor(playCol, 0.08)
        love.graphics.rectangle("fill", px - wakeW, 368, wakeW, 98)
        self:setColor(playCol, 0.14)
        love.graphics.rectangle("fill", px - wakeW * 0.45, 368, wakeW * 0.45, 98)
    end

    self:setColor(playCol)
    love.graphics.setLineWidth(1.5)
    love.graphics.line(px, 366, px, 470)
    love.graphics.setLineWidth(1)
    self:drawStarGlint(px, 366, 7.0, playCol, 1.0)
    self:drawStarGlint(px, 470, 5.5, playCol, 0.9)
    self:drawDiamond(px, 366, 2.5, C.TEXT)

    -- Dim the deck while a settings page has focus
    local mode = Modes.current or "NORMAL"
    if mode == "TRACK" or mode == "TRANSPORT" or mode == "MIX" then
        self:setColor(C.BG, 0.55)
        love.graphics.rectangle("fill", 7, 361, 626, 114)
    end
end

end
