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

end
