-- ============================================================================
-- src/ui/chrome/song.lua — The S page (song mode, PHASE_M): labels and the
-- centre view. The frame, shoulders, compass, face diamond and footer are
-- the stage's own (stage.lua), so S looks like every other page.
-- (part of src/ui/chrome.lua: adds methods to the Chrome table)
-- ============================================================================

local Config   = require("src.config")
local Looper   = require("src.looper")
local Session  = require("src.session")
local Theory   = require("src.theory")
local Harmony  = require("src.harmony")
local Song     = require("src.song")

local math_floor = math.floor

return function(Chrome)

-- The compass: a letter per slot (lower case = empty, a number = its place
-- in the queue); the face diamond: the four tracks, or the pattern actions
-- while the D-pad is held. Returns dpad, face, activeMap, guideDir.
function Chrome:songLabels()
    local dpad, face, active = {}, {}, {}
    for slot, dir in pairs(Song.SLOT_DIR) do
        local sum = Song.summaries[slot]
        local empty = (not sum or sum.empty) and slot ~= Session.patternSlot
        local label = empty and slot:lower() or slot
        local q = Song:isQueued(slot)
        if q then label = label .. q end
        if Song.cutTo and Song.cutTo.slot == slot then label = label .. "!" end
        dpad[dir] = label
    end
    if Song.pointing then
        face = { B = "QUEUE", A = "CUT", Y = "COPY", X = "CLEAR" }
        active.B = Song:isQueued(Song.pointing) ~= nil
    else
        for btn, slot in pairs({ B = 1, A = 2, Y = 3, X = 4 }) do
            local t = Looper.tracks[slot]
            local name = t and t.shortName or tostring(slot)
            local pending = Song.pendingMutes[slot]
            if pending ~= nil then
                face[btn] = name .. (pending and " >M" or " >ON")
            else
                face[btn] = t and t.muted and (name .. " [M]") or name
            end
            active[btn] = t and t.muted or false
        end
    end
    local guide = Session.patternSlot and Song.SLOT_DIR[Session.patternSlot] or nil
    return dpad, face, active, guide
end

-- Centre column (x 204..436, y 90..314): what's playing, what's next, the
-- chords; while the D-pad is held, the pattern pointed at
function Chrome:drawSongView(accent)
    local C = Config.COLORS
    local cx = 320
    local f = self.fontHuge or self.fontLarge

    local function centre(text, font, y, col)
        love.graphics.setFont(font)
        self:setColor(col)
        love.graphics.print(text, math_floor(cx - font:getWidth(text) * 0.5), math_floor(y))
    end

    if Song.pointing then
        local slot = Song.pointing
        local sum = Song.summaries[slot] or { empty = true }
        centre("POINTING AT", self.fontTiny, 92, C.MUTED)
        centre(slot, f, 106, C.TEXT)
        if slot == Session.patternSlot then
            centre("PLAYING NOW", self.fontSmall, 170, accent)
        elseif sum.empty then
            centre("EMPTY - B MAKES A NEW PATTERN", self.fontTiny, 172, C.MUTED)
            centre("Y COPIES THIS ONE HERE", self.fontTiny, 188, C.MUTED)
        elseif sum.broken then
            centre("COULDN'T BE READ", self.fontSmall, 170, C.RED)
        else
            centre(string.format("%d BPM  %s  %d BAR", sum.bpm, sum.key, sum.bars or 2), self.fontSmall, 170, C.TEXT)
            local names = self:fitText(table.concat(sum.instruments or {}, " / "), self.fontTiny, 224)
            centre(names, self.fontTiny, 190, C.MUTED)
        end
        local q = Song:isQueued(slot)
        if q then centre("QUEUED, " .. q .. " OF " .. #Song.queue, self.fontTiny, 214, accent) end
        return
    end

    -- NOW -> NEXT
    local now = Session.patternSlot or "-"
    local nextSlot = Song:nextSlot()
    love.graphics.setFont(f)
    local nw = f:getWidth(now)
    local arrow, nf = "  >  ", self.fontLarge
    local nextW = nextSlot and (nf:getWidth(arrow) + nf:getWidth(nextSlot)) or 0
    local x0 = math_floor(cx - (nw + nextW) * 0.5)
    self:setColor(accent)
    love.graphics.print(now, x0, 96)
    if nextSlot then
        love.graphics.setFont(nf)
        self:setColor(C.MUTED)
        love.graphics.print(arrow .. nextSlot, x0 + nw, 108)
    end

    local beats = Song:beatsToSwitch()
    local line
    if nextSlot and beats then
        line = string.format("%s IN %d BEAT%s", nextSlot, beats, beats == 1 and "" or "S")
        local rest = {}
        for i = 2, #Song.queue do rest[#rest + 1] = Song.queue[i].slot end
        if #rest > 0 then line = line .. "  THEN " .. table.concat(rest, " ") end
    else
        line = "HOLD THE D-PAD + B TO QUEUE"
    end
    centre(line, self.fontSmall, 158, nextSlot and C.TEXT or C.MUTED)

    -- the loop, bar by bar
    local bars = Looper.bars
    local w, gap, y = 200, 4, 182
    local bw = (w - gap * (bars - 1)) / bars
    local cur = Looper.tick / Looper.BAR_TICKS
    for i = 1, bars do
        local x = cx - w * 0.5 + (i - 1) * (bw + gap)
        self:setColor(C.PANEL_HI)
        love.graphics.rectangle("fill", x, y, bw, 7, 2, 2)
        local fill = math.max(0, math.min(1, cur - (i - 1)))
        if fill > 0 then
            self:setColor(accent)
            love.graphics.rectangle("fill", x, y, bw * fill, 7, 2, 2)
        end
    end

    -- this pattern's chords (track C), the one sounding lit
    local lane = Looper:getLane()
    local names = {}
    if lane then
        local evs = {}
        for _, ev in ipairs(lane.events) do if ev.chord then evs[#evs + 1] = ev end end
        table.sort(evs, function(a, b) return a.tick < b.tick end)
        for _, ev in ipairs(evs) do
            local n = Theory:chordName(ev.chord)
            if names[#names] ~= n then names[#names + 1] = n end
            if #names >= 6 then break end
        end
    end
    local curName = Theory:chordName((Harmony:current()))
    if #names == 0 then
        centre("NO CHORDS - IN " .. Theory:getKeyLabel(), self.fontTiny, 206, C.MUTED)
    else
        local font = self.fontSmall
        local total = 0
        for _, n in ipairs(names) do total = total + font:getWidth(n) + 14 end
        local x = math_floor(cx - (total - 4) * 0.5)
        local amber = C.AMBER
        for _, n in ipairs(names) do
            local bw2 = font:getWidth(n) + 10
            local lit = (n == curName)
            if lit then
                self:setColor(amber, 0.25)
                love.graphics.rectangle("fill", x, 202, bw2, 20, 3, 3)
            end
            self:setColor(amber, lit and 1.0 or 0.5)
            love.graphics.rectangle("line", x, 202, bw2, 20, 3, 3)
            love.graphics.setFont(font)
            love.graphics.print(n, x + 5, 205)
            x = x + bw2 + 4
        end
    end

    local Synth = require("src.synth")
    if (Synth.fadeGain or 1) < 0.999 then
        centre(string.format("FADE %d%%", math_floor((Synth.fadeGain or 1) * 100 + 0.5)), self.fontTiny, 232, accent)
    end
end


-- ============================================================================
-- THE SONG STRIP (song mode, in place of the chord strip, y 359..373): the
-- patterns scroll past a fixed NOW line; the one playing is widened to show
-- its chords bar by bar (Song:stripLayout does the maths)
-- ============================================================================
function Chrome:drawSongStrip(lx, lw)
    local C = Config.COLORS
    local col, col2 = C.SONG, C.SONG_2
    local y, h = 359, 14
    local cy = y + h * 0.5
    local rec = Song.recording

    self:setColor(C.BG)
    love.graphics.rectangle("fill", 8, y, 624, h, 4, 4)
    self:setColor(rec and C.RED or col, 0.85)
    love.graphics.rectangle("line", 8, y, 624, h, 4, 4)

    love.graphics.setFont(self.fontTiny)
    local fh = self:lineHeight(self.fontTiny)
    local ty = math_floor(cy - fh * 0.5)
    self:drawStarGlint(19, cy, 4.0, col, 1.0)
    self:setColor(C.TEXT)
    love.graphics.print("SONG", 28, ty)
    local q = #Song.queue + (Song.cutTo and 1 or 0)
    local info = (Session.patternSlot or "-") .. (q > 0 and ("  +" .. q) or "")
    self:setColor(col)
    love.graphics.print(info, 131 - self.fontTiny:getWidth(info), ty)
    self:setColor(C.GRID)
    love.graphics.line(136, y + 3, 136, y + h - 3)

    local L = Song:stripLayout(lx, lw)
    local Display = require("src.ui.display")
    local clip = Display:pushClip(lx, y, lw, h)
    for _, b in ipairs(L.blocks) do
        local bx, bw = b.x + 1, math.max(2, b.w - 2)
        if b.kind == "now" then
            self:setColor(col, 0.12)
            love.graphics.rectangle("fill", bx, y + 1.5, bw, h - 3, 2, 2)
            self:setColor(col)
            love.graphics.rectangle("line", bx, y + 1.5, bw, h - 3, 2, 2)
            self:setColor(col)
            love.graphics.print(b.slot, math_floor(bx + 3), ty)
            local lw0 = self.fontTiny:getWidth(b.slot) + 6
            for i, ch in ipairs(b.chords) do
                local cx0 = ch.x + ((i == 1) and lw0 or 1)
                local cw = ch.w - ((i == 1) and lw0 or 1) - 1
                if cw > 4 then
                    self:setColor(C.AMBER, ch.lit and 0.32 or 0.0)
                    love.graphics.rectangle("fill", cx0, y + 3, cw, h - 6, 2, 2)
                    self:setColor(C.AMBER, ch.lit and 0.9 or 0.4)
                    love.graphics.rectangle("line", cx0, y + 3, cw, h - 6, 2, 2)
                    if self.fontTiny:getWidth(ch.name) <= cw - 3 then
                        self:setColor(ch.lit and C.TEXT or C.AMBER)
                        love.graphics.print(ch.name, math_floor(cx0 + 2), ty)
                    end
                end
            end
        else
            local past = (b.kind == "past")
            self:setColor(past and C.MUTED or col2, past and 0.10 or 0.14)
            love.graphics.rectangle("fill", bx, y + 1.5, bw, h - 3, 2, 2)
            if b.kind == "next" then
                self:setColor(col2)
                self:dashedRect(bx, y + 1.5, bw, h - 3)
            else
                self:setColor(past and C.DIM or Config.shade(col2, 0.6))
                love.graphics.rectangle("line", bx, y + 1.5, bw, h - 3, 2, 2)
            end
            local label = b.slot
            if b.names and #b.names > 0 then
                local more = b.slot .. " " .. table.concat(b.names, " ")
                if self.fontTiny:getWidth(more) <= bw - 5 then label = more end
            end
            if self.fontTiny:getWidth(label) <= bw - 4 then
                self:setColor(past and C.MUTED or C.TEXT)
                love.graphics.print(label, math_floor(bx + 3), ty)
            end
        end
    end
    -- the past darkened
    self:setColor(C.BG, 0.45)
    love.graphics.rectangle("fill", lx, y + 1, L.now - lx, h - 2)
    Display:popClip(clip)

    -- the NOW line
    self:setColor(rec and C.RED or C.TEXT)
    love.graphics.setLineWidth(2)
    love.graphics.line(L.now, y + 1, L.now, y + h - 1)
    love.graphics.setLineWidth(1)
end


-- ============================================================================
-- Writing the song (clock stopped on S): the steps as a grid around the
-- cursor. Columns = steps, rows = the pattern, its chords, tracks 1-4 in / out.
-- ============================================================================
function Chrome:drawSongGrid(accent)
    local C = Config.COLORS
    local steps = Song.data.steps
    local cur = Song.cursor
    local cols = 5
    local first = math.max(1, math.min(cur - 2, #steps + 2 - cols))
    local x0, y0, cw, lw = 206, 92, 44, 12
    local font = self.fontTiny
    love.graphics.setFont(font)
    local fh = self:lineHeight(font)

    local rowY = { pat = y0, ch = y0 + 26, t = { y0 + 46, y0 + 64, y0 + 82, y0 + 100 } }
    -- row labels
    self:setColor(C.MUTED)
    love.graphics.print("C", x0, rowY.ch + 3)
    for t = 1, 4 do love.graphics.print(tostring(t), x0, rowY.t[t] + 3) end

    for c = 0, cols - 1 do
        local idx = first + c
        local x = x0 + lw + c * cw
        local st = steps[idx]
        local isCur = (idx == cur)
        if isCur then
            self:setColor(C.TEXT, 0.8)
            self:dashedRect(x - 1, y0 - 3, cw - 2, rowY.t[4] + 18 - y0 + 3)
        end
        if st then
            local playing = Song.playing and idx == Song.stepIdx
            self:setColor(accent, playing and 0.45 or 0.18)
            love.graphics.rectangle("fill", x + 1, rowY.pat, cw - 6, 22, 3, 3)
            self:setColor(accent)
            love.graphics.rectangle("line", x + 1, rowY.pat, cw - 6, 22, 3, 3)
            love.graphics.setFont(self.fontSmall)
            self:setColor(C.TEXT)
            love.graphics.print(st.slot, x + 5, rowY.pat + 2)
            love.graphics.setFont(font)
            local loopT = (Song.summaries[st.slot] and Song.summaries[st.slot].bars or Looper.bars) * 4 * Looper.PPQN
            local loops = st.len / loopT
            self:setColor(C.MUTED)
            love.graphics.print("x" .. (math.abs(loops - math.floor(loops + 0.5)) < 0.01 and math.floor(loops + 0.5) or string.format("%.1f", loops)),
                x + 20, rowY.pat + 6)
            local sum = Song.summaries[st.slot]
            local chord = sum and sum.chordNames and sum.chordNames[1] or "-"
            self:setColor(C.AMBER)
            love.graphics.print(self:fitText(chord, font, cw - 8), x + 3, rowY.ch + 3)
            for t = 1, 4 do
                local out = st.mutes[t]
                local tc = self:trackColor(t)
                if out then
                    self:setColor(C.DIM)
                    self:dashedRect(x + 2, rowY.t[t], cw - 8, 14)
                else
                    self:setColor(tc, 0.35)
                    love.graphics.rectangle("fill", x + 2, rowY.t[t], cw - 8, 14, 2, 2)
                    self:setColor(tc)
                    love.graphics.rectangle("line", x + 2, rowY.t[t], cw - 8, 14, 2, 2)
                end
            end
        elseif idx == #steps + 1 then
            self:setColor(C.DIM)
            self:dashedRect(x + 1, rowY.pat, cw - 6, 22)
            love.graphics.setFont(self.fontSmall)
            self:setColor(C.MUTED)
            love.graphics.print("+", x + 14, rowY.pat + 2)
            love.graphics.setFont(font)
        end
        self:setColor(isCur and C.TEXT or C.DIM)
        love.graphics.print(tostring(idx), x + 2, rowY.t[4] + 20 - math_floor(fh * 0.5) + 4)
    end

    local msg = (#steps == 0) and "NO SONG YET - D-PAD + B WRITES STEP 1"
        or string.format("STEP %d OF %d  -  L1 / R1 MOVE", math.min(cur, #steps + 1), #steps)
    self:setColor(C.MUTED)
    love.graphics.print(msg, math_floor(320 - font:getWidth(msg) * 0.5), 232)
end

-- ============================================================================
-- The song's rows (hold SELECT on S): the Track page's look
-- ============================================================================
function Chrome:drawSongRows(col)
    local C = Config.COLORS
    local Modes = require("src.modes")
    local rows = Song:rows()
    local sel = Modes.trackPage.row
    local n = #rows
    local y0, step, nx = 102, 21, 226
    local shown = math.min(n, 9)
    local first = math.max(1, math.min(sel - 3, n - shown + 1))
    for i = first, first + shown - 1 do
        local row = rows[i]
        local y = y0 + (i - first) * step
        local isSel = (i == sel)
        if isSel then
            self:drawCapsule(240, y - 9, 192, 18, "", col, col, col, self.fontSmall, 0.18)
        end
        local markCol = isSel and col or C.MUTED
        if row.kind == "setting" then
            self:setColor(markCol, 0.9)
            love.graphics.circle("line", nx, y, isSel and 5 or 3.5)
        else
            self:drawStarGlint(nx, y, isSel and 6 or 3.2, markCol, 0.9)
        end
        love.graphics.setFont(self.fontTiny)
        self:setColor(isSel and col or C.MUTED)
        love.graphics.print(row.label, 250, y - 6)
        love.graphics.setFont(self.fontSmall)
        self:setColor(isSel and C.TEXT or C.MUTED)
        local value = isSel and ("<  " .. row.value .. "  >") or row.value
        love.graphics.print(value, 318, y - 7)
    end
    if first > 1 then
        self:setColor(col, 0.9)
        love.graphics.polygon("fill", nx - 4, y0 - 12, nx + 4, y0 - 12, nx, y0 - 17)
    end
    if first + shown - 1 < n then
        local by = y0 + (shown - 1) * step + 12
        self:setColor(col, 0.9)
        love.graphics.polygon("fill", nx - 4, by, nx + 4, by, nx, by + 5)
    end
end

end
