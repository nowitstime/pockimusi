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
-- REGION 3: THE CHORD STRIP (y: 359..373) AND THE TAPE DECK (y: 376..474)
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

    self:drawLaneStrip(lx, lw)
    self:drawFrame(8, 376, 624, 98, C.GRID, 1, activeCol)

    -- Vertical divider between headers and lanes
    self:setColor(C.GRID)
    love.graphics.line(136, 381, 136, 469)

    -- Continuous bar & beat grid lines spanning the 4 threads
    for s = 0, totalSixteenths, 4 do
        local sx = lx + (s / totalSixteenths) * lw
        local isBar = (s % 16 == 0)
        self:setColor(isBar and C.GRID or C.PANEL_HI)
        love.graphics.line(sx, 383, sx, 467)
        if isBar then
            self:drawDiamond(sx, 381, 2.0, C.MUTED)
            self:drawDiamond(sx, 469, 2.0, C.MUTED)
        end
    end

    for tIdx = 1, 4 do
        local ry = 382 + (tIdx - 1) * 22
        local cy = ry + 10
        local isSel = (Looper.activeTrack == tIdx)
        local tColor = self:trackColor(tIdx)
        local track = Looper.tracks[tIdx]
        local grid = Looper:getTrackGrid(tIdx)

        -- Left Track Header
        if isSel then
            self:setColor(Config.shade(tColor, 0.24))
            love.graphics.rectangle("fill", 12, ry, 120, 20, 3, 3)
            self:drawStarGlint(19, cy, 4.5, tColor, 1.0)
        else
            self:drawDiamond(19, cy, 2.0, track.muted and C.DIM or tColor)
        end

        self:setColor(isSel and C.TEXT or C.MUTED)
        love.graphics.setFont(self.fontSmall)
        love.graphics.print(string.format("%d %s", tIdx, track.shortName or "TRK"), 28, ry + 2)

        self:setColor((grid.id ~= "FREE") and tColor or C.DIM)
        love.graphics.setFont(self.fontTiny)
        love.graphics.print(grid.label, 84, ry + 3)

        -- Mute Rune Tag (Diamond vs M); song mode: a mute waiting for the bar is dashed
        local Song = package.loaded["src.song"]
        local pending = Song and Song.pendingMutes[tIdx]
        if pending ~= nil then
            self:setColor(pending and C.RED or tColor)
            self:dashedRect(113, ry + 2, 16, 16)
            if track.muted then
                self:setColor(C.RED)
                love.graphics.setFont(self.fontTiny)
                love.graphics.print("M", 117, ry + 4)
            end
        elseif track.muted then
            self:drawTag(113, ry + 2, 16, 16, "M", C.RED, C.RED, C.BG, self.fontTiny)
        else
            self:drawTag(113, ry + 2, 16, 16, "", C.GRID, C.PANEL_HI, tColor, self.fontTiny)
            self:drawDiamond(121, ry + 10, 2.4, tColor)
        end

        -- Constellation Thread Lane
        if isSel then
            self:setColor(Config.shade(tColor, 0.12))
            love.graphics.rectangle("fill", lx - 2, ry + 1, lw + 4, 18, 3, 3)
        end
        self:setColor(Config.shade(tColor, isSel and 0.5 or 0.3))
        love.graphics.line(lx, cy, lx + lw, cy)

        self:drawDiamond(lx, cy, isSel and 2.8 or 2.2, tColor)
        self:drawDiamond(lx + lw, cy, isSel and 2.8 or 2.2, tColor)

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
        love.graphics.line(616, ry + 3, 616, ry + 17)
        local mh = math_floor(14 * peak)
        if mh > 0 then
            self:setColor(col)
            love.graphics.setLineWidth(2.5)
            love.graphics.line(616, ry + 17 - mh, 616, ry + 17)
            self:drawDiamond(616, ry + 17 - mh, 2.2, col)
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
        love.graphics.rectangle("fill", px - wakeW, 381, wakeW, 88)
        self:setColor(playCol, 0.14)
        love.graphics.rectangle("fill", px - wakeW * 0.45, 381, wakeW * 0.45, 88)
    end

    self:setColor(playCol)
    love.graphics.setLineWidth(1.5)
    love.graphics.line(px, 380, px, 471)
    love.graphics.setLineWidth(1)
    self:drawStarGlint(px, 380, 6.0, playCol, 1.0)
    self:drawStarGlint(px, 471, 5.0, playCol, 0.9)
    self:drawDiamond(px, 380, 2.5, C.TEXT)

    -- Dim the deck while a settings page has focus
    local mode = Modes.current or "NORMAL"
    if mode == "TRACK" or mode == "TRANSPORT" or mode == "MIX" then
        self:setColor(C.BG, 0.55)
        love.graphics.rectangle("fill", 7, 358, 626, 117)
    end
end

-- ============================================================================
-- THE CHORD STRIP: track C's whole lane at once, above the tape deck. Its
-- own playhead; a frame marks the part under this loop pass when the lane
-- is longer than the loop; only the chord playing now is lit.
-- ============================================================================
function Chrome:drawLaneStrip(lx, lw)
    local Song = package.loaded["src.song"]
    if Song and Song:isOn() then return self:drawSongStrip(lx, lw) end
    local lane = Looper:getLane()
    if not lane then return end
    local C = Config.COLORS
    local def = Instruments:getDefinition("lane")
    local col = self:trackColor(Looper.LANE)
    local isSel = (Looper.activeTrack == Looper.LANE)
    local y, h = 359, 14
    local cy = y + h * 0.5

    self:setColor(C.BG)
    love.graphics.rectangle("fill", 8, y, 624, h, 4, 4)
    self:setColor(isSel and Config.shade(col, 0.85) or C.GRID)
    love.graphics.rectangle("line", 8, y, 624, h, 4, 4)

    -- Header: C CHORDS, the lane's length, and which pass
    if isSel then
        self:setColor(Config.shade(col, 0.24))
        love.graphics.rectangle("fill", 11, y + 2, 122, h - 4, 3, 3)
        self:drawStarGlint(19, cy, 4.0, col, 1.0)
    else
        self:drawDiamond(19, cy, 2.0, col)
    end
    love.graphics.setFont(self.fontTiny)
    local fh = self:lineHeight(self.fontTiny)
    local ty = math_floor(cy - fh * 0.5)
    self:setColor(isSel and C.TEXT or Config.shade(col, 0.8))
    love.graphics.print("C CHORDS", 28, ty)
    self:setColor(col)
    love.graphics.print(Looper:getLaneBars() .. " BAR", 80, ty)
    local laneT, loopT = Looper:getLaneTicks(), Looper:getLoopTicks()
    local passes = math.max(1, math_floor(laneT / loopT))
    local pass = (Looper.pass % passes) + 1
    if passes > 4 then
        local txt = pass .. "/" .. passes
        self:setColor(col)
        love.graphics.print(txt, 131 - self.fontTiny:getWidth(txt), ty)
    elseif passes > 1 then
        for i = 1, passes do
            local px = 131 - (passes - i) * 6 - 4
            self:setColor(i == pass and col or C.DIM)
            love.graphics.rectangle("fill", px, cy - 2, 4, 4, 1, 1)
        end
    end
    self:setColor(C.GRID)
    love.graphics.line(136, y + 3, 136, y + h - 3)

    -- The chords
    local spans = def:spans(lane.state, lane)
    local nowPos = Looper:lanePos() / laneT
    if #spans == 0 then
        local msg = "NO CHORDS YET - EVERYTHING PLAYS IN " .. Theory:getKeyLabel() .. " - SELECT TAP TO REACH TRACK C"
        self:setColor(col, 0.75)
        love.graphics.print(msg, math_floor(lx + (lw - self.fontTiny:getWidth(msg)) * 0.5), ty)
    else
        local carry = nowPos < spans[1].from          -- before the first chord the last carries over
        local namesOnly = Looper:getLaneBars() >= 16
        for i, sp in ipairs(spans) do
            local x0, x1 = lx + sp.from * lw, lx + sp.to * lw
            local w = x1 - x0
            local now = (nowPos >= sp.from and nowPos < sp.to) or (carry and i == #spans)
            self:setColor(col, now and 0.34 or 0.10)
            love.graphics.rectangle("fill", x0 + 0.5, y + 2, math_max(1, w - 1), h - 4, 2, 2)
            self:setColor(col, 0.35)
            love.graphics.rectangle("line", x0 + 0.5, y + 2, math_max(1, w - 1), h - 4, 2, 2)
            local name = Theory:chordName(sp.chord)
            local label = namesOnly and name or (name .. " " .. def:numeral(sp.chord))
            if self.fontTiny:getWidth(label) > w - 4 then label = name end
            if self.fontTiny:getWidth(label) <= w - 4 then
                self:setColor(now and C.TEXT or col)
                love.graphics.print(label, math_floor(x0 + 3), ty)
            end
        end
    end

    -- A live change (not recorded) shows as a dashed box where it plays
    local o = lane.state.override
    if o and Looper.playing then
        local ox = lx + Looper:lanePos(o.start) / laneT * lw
        local ow = math_min(o.len / laneT * lw, lx + lw - ox)
        self:setColor(C.TEXT, 0.7)
        self:dashedRect(ox, y + 1, ow, h - 2)
    end

    -- This pass, when the lane is longer than the loop
    if laneT > loopT and #spans > 0 then
        local wpos = (Looper.pass * loopT) % laneT
        local wx = lx + wpos / laneT * lw
        local ww = loopT / laneT * lw
        self:setColor(C.TEXT, 0.7)
        love.graphics.setLineWidth(1.2)
        love.graphics.rectangle("line", wx - 1, y + 1, ww + 2, h - 2, 3, 3)
        love.graphics.setLineWidth(1)
    end

    -- The strip's own playhead
    if #spans > 0 then
        local px = lx + nowPos * lw
        self:setColor(C.TEXT)
        love.graphics.setLineWidth(1.5)
        love.graphics.line(px, y + 1, px, y + h - 1)
        love.graphics.setLineWidth(1)
    end
end

-- A dashed rectangle outline
function Chrome:dashedRect(x, y, w, h)
    local dash = 3
    local function seg(x1, y1, x2, y2)
        local len = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
        local n = math_floor(len / (dash * 2))
        for i = 0, n do
            local a, b = (i * 2 * dash) / len, math_min(1, (i * 2 + 1) * dash / len)
            if a < 1 then love.graphics.line(x1 + (x2 - x1) * a, y1 + (y2 - y1) * a, x1 + (x2 - x1) * b, y1 + (y2 - y1) * b) end
        end
    end
    seg(x, y, x + w, y); seg(x + w, y, x + w, y + h); seg(x + w, y + h, x, y + h); seg(x, y + h, x, y)
end

end
