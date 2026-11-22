-- ============================================================================
-- src/ui/chrome/lane.lua — Track C's stage view: the chord chart
-- (part of src/ui/chrome.lua: adds methods to the Chrome table)
--
-- One box per GRID unit (1/2 to 4 bars), four to a row (eight past 16
-- boxes). The
-- playhead is the cursor: its box is outlined, and that is where B and a
-- stamp write (no greyed-out preview: it read as a chord already there).
-- Running, the playing box is lit and a change waiting for the bar line
-- shows dashed.
-- ============================================================================

local Config      = require("src.config")
local Theory      = require("src.theory")
local Input       = require("src.input")
local Looper      = require("src.looper")

local math_floor = math.floor
local math_min   = math.min
local math_max   = math.max

return function(Chrome)

function Chrome:drawLaneView(def, state, track, col)
    local C = Config.COLORS
    local bar = Looper.BAR_TICKS
    local laneT = Looper:getLaneTicks()
    local nBars = state.bars
    local song = Looper:songTick()
    local pos = Looper:lanePos()
    local running = Looper.playing
    local cells = def:cells(state, track)
    local nBoxes = #cells
    local boxStart, boxLen, boxIdx = def:boxAt(state, pos)
    local curBox = boxIdx + 1
    local _, unitLabel = def:unit(state)

    local q = state.queued
    local queuedBox
    if q and q.at > song then
        local _, _, qi = def:boxAt(state, Looper:lanePos(q.at))
        queuedBox = qi + 1
    end

    -- Header
    love.graphics.setFont(self.fontTiny)
    local info = (running and "LIVE" or "STOPPED") .. " - " .. nBars .. " BARS - BOX " .. unitLabel
    if state.spiceLevel ~= "OFF" then info = info .. " - SPICE " .. state.spiceLevel end
    self:setColor(C.MUTED)
    love.graphics.print(info, 208, 88)
    local badge = state.wheelOpen and ("WHEEL " .. state.wheelPage) or ("X: " .. (def.WHEEL_SHORT[state.picked] or state.picked))
    self:drawCapsuleRow(400, 87, 12, { { badge, C.GRID, C.PANEL_HI, col } })

    local big, sub, bigCol
    if state.wheelOpen then
        local p = state.hover and def:progression(state.hover)
        big = p and p.name or "POINT AT ONE"
        sub = p and table.concat(p.romans, " ") .. "  -  LET GO TO PICK" or "L1 / R1: MORE PROGRESSIONS"
        bigCol = col
    elseif Input.down.A then
        big, sub, bigCol = "COLOUR", running and "THE CHORD PLAYING" or "THE CHORD BEHIND THE PLAYHEAD", col
    elseif running then
        if q and q.at > song then
            big = "NEXT: " .. Theory:chordName(q.chord)
            sub = "AT " .. def:posLabel(Looper:lanePos(q.at)) .. (q.rec and "  -  RECORDED" or "  -  LIVE, NOT RECORDED")
        else
            local chord = state.currentChord
            big = chord and Theory:chordName(chord) or "-"
            sub = "B: NEXT BOX  -  L2 RECORDS"
        end
        bigCol = C.TEXT
    else
        local chord = state.currentChord
        big = chord and Theory:chordName(chord) or "-"
        sub = "B WRITES " .. def:posLabel(boxStart) .. ", STEPS ON"
        bigCol = C.TEXT
    end
    love.graphics.setFont(self.fontLarge)
    self:setColor(bigCol)
    love.graphics.print(big, math_floor(320 - self.fontLarge:getWidth(big) * 0.5), 102)
    love.graphics.setFont(self.fontTiny)
    self:setColor(C.MUTED)
    love.graphics.print(sub, math_floor(320 - self.fontTiny:getWidth(sub) * 0.5), 124)

    -- The chart
    local cols = (nBoxes > 16) and 8 or math_min(4, nBoxes)
    local rows = math.ceil(nBoxes / cols)
    local gx, gy, gw, gh = 206, 140, 228, 160
    local gap = 4
    local cw = (gw - (cols - 1) * gap) / cols
    local ch = math_min(44, (gh - (rows - 1) * gap) / rows)
    local small = ch < 30 or cols > 4
    for b = 1, nBoxes do
        local cell = cells[b]
        local cx = gx + ((b - 1) % cols) * (cw + gap)
        local cy = gy + math_floor((b - 1) / cols) * (ch + gap)
        local isCur = (b == curBox)
        local playing = running and isCur

        self:setColor(playing and Config.shade(col, 0.3) or C.PANEL)
        love.graphics.rectangle("fill", cx, cy, cw, ch, 3, 3)
        if b == queuedBox then
            self:setColor(C.TEXT, 0.85)
            self:dashedRect(cx + 0.5, cy + 0.5, cw - 1, ch - 1)
        else
            self:setColor(C.GRID)
            love.graphics.rectangle("line", cx, cy, cw, ch, 3, 3)
        end
        if isCur then
            self:setColor(running and C.TEXT or C.TEXT, running and 0.6 or 1.0)
            love.graphics.setLineWidth(running and 1 or 2)
            love.graphics.rectangle("line", cx - 1, cy - 1, cw + 2, ch + 2, 4, 4)
            love.graphics.setLineWidth(1)
        end

        -- what is in the box
        local name, numeral, fg, nfg
        if b == queuedBox then
            name, numeral = Theory:chordName(q.chord), def:numeral(q.chord)
            fg, nfg = C.TEXT, C.MUTED
        elseif #cell.starts == 1 then
            name, numeral = Theory:chordName(cell.starts[1].chord), def:numeral(cell.starts[1].chord)
            fg, nfg = playing and C.TEXT or col, playing and C.TEXT or Config.shade(col, 0.7)
        elseif #cell.starts > 1 then
            local names = {}
            for i, st in ipairs(cell.starts) do names[i] = Theory:chordName(st.chord) end
            name, fg = table.concat(names, " "), playing and C.TEXT or col
        elseif cell.carry then
            name, fg = "%", C.MUTED
        else
            name, fg = ".", C.DIM
        end
        local f = small and self.fontTiny or self.fontSmall
        if f:getWidth(name) > cw - 4 then f = self.fontTiny end
        love.graphics.setFont(f)
        self:setColor(fg)
        local showNum = numeral and not small and nBoxes < 16
        local ny = showNum and (cy + ch * 0.5 - f:getHeight() + 1) or (cy + (ch - f:getHeight()) * 0.5)
        love.graphics.print(name, math_floor(cx + (cw - f:getWidth(name)) * 0.5), math_floor(ny))
        if showNum then
            love.graphics.setFont(self.fontTiny)
            self:setColor(nfg)
            love.graphics.print(numeral, math_floor(cx + (cw - self.fontTiny:getWidth(numeral)) * 0.5), math_floor(cy + ch * 0.5 + 2))
        end
        if not small and cell.onBar then
            love.graphics.setFont(self.fontTiny)
            self:setColor(C.DIM)
            love.graphics.print(tostring(cell.bar), cx + 3, cy + 1)        -- the bar the box starts on
        end

        -- the playhead: stopped, a star on the box's edge; running, it rides through the box
        if isCur then
            local frac = running and ((pos - boxStart) / boxLen) or 0
            self:drawStarGlint(cx + frac * cw, cy + (running and 0 or ch * 0.5), running and 4.5 or 5.5, C.TEXT, 1.0)
        end
    end
end

end
