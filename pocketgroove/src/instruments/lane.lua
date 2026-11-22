-- ============================================================================
-- src/instruments/lane.lua — TRACK C: the chord lane (Phase K, PHASE_K.md)
--
-- The song's chords on a silent built-in track outside the four slots
-- (Looper.tracks[Looper.LANE]). Its chords sit on the lane's own timeline,
-- 2 / 4 / 8 / 16 bars (BARS row), which can be longer than the loop.
--
-- The playhead is the cursor; B writes where it is heading.
--   Clock running (live)
--     D-pad + B        change at the next bar line (a press up to a 1/16
--                      late counts for the line just gone). Recording: it is
--                      written. Not recording: the followers play it for its
--                      length, nothing is written.
--     L1 / R1 held + B sparser (lasts 2 bars) / denser (next half bar)
--     L1 + R1 + B      next beat
--     A held + D-pad   colour the chord playing
--     Y                delete the chord playing (hold: keep deleting)
--   Clock stopped (writing it out)
--     D-pad + B        write the box under the playhead, step on
--     L1 / R1 held + B write 2 bars / 1/2 bar and step that far (both: a beat)
--     L1 / R1 tap      step back / on a bar (the chord carries on)
--     A held + D-pad   colour the chord behind the playhead
--     Y                take back the last thing written, step back
--   Both
--     X held           the progression wheel: point at one to hear it on the
--                      other tracks; L1 / R1 flip the page; let go = picked
--     X tap            stamp the picked progression where the playhead is
--                      (running: from the next bar line) and step past it.
--                      Shoulders held: 2 bars / 1/2 bar / a beat a chord.
--
-- Edits (stamp, colour, delete, stopped writes) are one undo per press.
-- Recording live is one undo per pass of the lane.
-- ============================================================================

local Theory  = require("src.theory")
local Input   = require("src.input")
local Synth   = require("src.synth")
local Looper  = require("src.looper")
local Patches = require("src.instruments.patches")
local Chords  = require("src.instruments.chords")

local math_floor = math.floor
local math_max   = math.max
local math_min   = math.min

local Lane = {
    id = "lane",
    name = "CHORDS",
    shortName = "CHORD",
    viewKind = "lane",
    isLane = true,
    NO_FX = true,                 -- no effect rows: the lane is silent

    HOME_GROUP = "PLUCK",
    DEFAULT_PATCH = "harp",       -- the preview sound
    REGISTER = 4,
    VOICES = 8,
    GATE = 0.45,                  -- a sustaining preview sound is held this long
    STRUM_GAP = 0.02,

    BARS = { 2, 4, 8, 16 },
    PREVIEWS = { "STRUM", "STAB", "OFF" },
    LATE = 120,                   -- a press this soon after a line counts for that line
    TAP = 0.25,                   -- X held longer than this opens the wheel

    -- The progression wheel: two pages around the D-pad
    WHEEL = {
        { UP = "POP", UP_RIGHT = "50S", RIGHT = "SAD POP", DOWN_RIGHT = "ROCK",
          DOWN = "JAZZ ii-V-I", DOWN_LEFT = "ROYAL ROAD", LEFT = "MIXO", UP_LEFT = "CANON" },
        { UP = "DESCEND", UP_RIGHT = "HEROIC", RIGHT = "BITTERSWEET", DOWN_RIGHT = "BLUES 8" },
    },
    WHEEL_SHORT = { ["JAZZ ii-V-I"] = "JAZZ", ["ROYAL ROAD"] = "ROYAL", ["BITTERSWEET"] = "BITTER",
                    ["SAD POP"] = "SAD POP", ["BLUES 8"] = "BLUES" },

    ERASE = { B = { actions = { "B" }, label = "CHORDS" } },

    VIEW = {
        dpad = {},
        face = { B = "WRITE", A = "COLOUR", Y = "DELETE", X = "STAMP" },
    },
}

local ROMAN_LABELS = { NEUTRAL = "I", UP = "bVI", DOWN = "vi", LEFT = "IV", RIGHT = "V",
                       UP_LEFT = "ii", UP_RIGHT = "iii", DOWN_LEFT = "bVII", DOWN_RIGHT = "iv" }
local WHEEL_LABELS = { NEUTRAL = "PLAIN", UP = "7", UP_RIGHT = "9", RIGHT = "ADD9", UP_LEFT = "6",
                       LEFT = "SUS4", DOWN_LEFT = "SUS2", DOWN = "DIM", DOWN_RIGHT = "AUG" }
local DIRS = { "NEUTRAL", "UP", "UP_RIGHT", "RIGHT", "DOWN_RIGHT", "DOWN", "DOWN_LEFT", "LEFT", "UP_LEFT" }

function Lane:newState()
    return {
        bars = 4,
        colour = "TRIAD",          -- colour new chords get
        spiceLevel = "OFF",
        spice = {},                -- [event] = coloured chord, this lane pass (Harmony)
        patch = self.DEFAULT_PATCH,
        previewStyle = "STRUM",    -- PREVIEW row
        picked = "POP",            -- the progression a tap of X puts down
        wheelOpen = false,
        wheelPage = 1,
        hover = nil,               -- the progression the wheel points at
        xHeld = 0.0,
        override = nil,            -- { chord, start, len } a live change (song ticks; Harmony)
        preview = nil,             -- { chords, start, len } the wheel's progression (Harmony)
        queued = nil,              -- { chord, at, len, rec } for the view
        currentChord = nil,
        history = {},              -- stopped writes, for Y
        flash = { B = 0, A = 0, Y = 0, X = 0 },
        recTake = nil,             -- { pass } the lane pass being recorded
    }
end

-- ---------------------------------------------------------------------------
-- Chords and progressions
-- ---------------------------------------------------------------------------
function Lane:chordFor(state, dirKey, colour)
    return Theory:getChordForDirection(dirKey, false, false, colour or state.colour)
end

function Lane:progression(name)
    for _, p in ipairs(Chords.PROGRESSIONS) do
        if p.name == name then return p end
    end
    return Chords.PROGRESSIONS[1]
end

function Lane:progressionChords(state, name)
    local p = self:progression(name)
    local out = {}
    for i, dir in ipairs(p.dirs) do out[i] = Chords:chordData(self:chordFor(state, dir)) end
    return out
end

function Lane:numeral(chord)
    return Chords:numeral(chord)
end

-- The shoulders say where a chord lands and how long it lasts: { grid, len, label }
function Lane:shoulderLength(l1, r1)
    local bar = Looper.BAR_TICKS
    if l1 and r1 then return Looper.PPQN, Looper.PPQN, "1 BEAT" end
    if l1 then return bar, 2 * bar, "2 BARS" end
    if r1 then return bar / 2, bar / 2, "1/2 BAR" end
    return bar, bar, "1 BAR"
end

-- ---------------------------------------------------------------------------
-- The lane's chords
-- ---------------------------------------------------------------------------
local function chordEvents(track)
    local list = {}
    for _, ev in ipairs(track.events) do
        if ev.chord and not ev.open then list[#list + 1] = ev end
    end
    table.sort(list, function(a, b) return a.tick < b.tick end)
    return list
end
Lane.chordEvents = chordEvents

-- The chord event sounding at lane position `pos` (the latest at or before
-- it; before the first, the last carries over), and its index in track.events
function Lane:activeAt(track, pos)
    local best, bestD
    local laneT = Looper:getLaneTicks()
    for _, ev in ipairs(track.events) do
        if ev.chord and not ev.open then
            local d = (pos - ev.tick) % laneT
            if not bestD or d < bestD then best, bestD = ev, d end
        end
    end
    if not best then return nil end
    for i, ev in ipairs(track.events) do
        if ev == best then return best, i end
    end
end

-- Write `chord` over lane positions [pos, pos + len) (never past the lane's
-- end). What was there goes; if a chord was sounding at the end of the span
-- and more chords follow, it comes back there, so writing one box leaves the
-- rest of the lane as it was. Replaces track.events with a new list.
function Lane:write(track, chord, pos, len, via, takeId)
    local laneT = Looper:getLaneTicks()
    pos = math_floor(pos + 0.5) % laneT
    len = math_max(1, math_min(len, laneT - pos))
    local endPos = pos + len
    local active, after, atEnd
    for _, ev in ipairs(track.events) do
        if ev.chord and not ev.open then
            if ev.tick < endPos and (not active or ev.tick > active.tick) then active = ev end
            if ev.tick > endPos then after = true end
            if ev.tick == endPos then atEnd = true end
        end
    end
    local out = {}
    for _, ev in ipairs(track.events) do
        if not (ev.tick >= pos and ev.tick < endPos) then out[#out + 1] = ev end
    end
    if endPos < laneT and active and after and not atEnd then
        out[#out + 1] = { tick = endPos, len = 0, action = "B", via = active.via, chord = active.chord,
                          vel = active.vel or 0.75, takeId = active.takeId }
    end
    out[#out + 1] = { tick = pos, len = 0, action = "B", via = via or "B", chord = chord, vel = 0.75,
                      takeId = takeId or Looper.currentTakeId }
    track.events = out
    Looper:touch(track)
    return out
end

-- One undo entry for an edit (the whole list as it was)
function Lane:pushEdit(track, label)
    local entry = { kind = "events", trackSlot = track.slot, events = track.events, label = label }
    Looper:pushUndo(entry)
    return entry
end

-- Recording live: one undo entry per pass of the lane
function Lane:recordUndo(state, track)
    local lanePass = math_floor(Looper:songTick() / Looper:getLaneTicks())
    if not state.recTake or state.recTake.pass ~= lanePass then
        Looper:beginRecordingTake()
        state.recTake = { pass = lanePass, id = Looper.currentTakeId }
        self:pushEdit(track, "LANE PASS")
    end
    return state.recTake.id
end

-- BARS row: a longer lane repeats what is there; a shorter one drops the end
function Lane:setBars(state, track, bars)
    if bars == state.bars then return end
    local oldT = Looper:getLaneTicks()
    if track then self:pushEdit(track, "BARS").laneBars = state.bars end
    state.bars = bars
    local newT = Looper:getLaneTicks()
    if track then
        local out = {}
        for _, ev in ipairs(track.events) do
            if ev.tick < newT then out[#out + 1] = ev end
        end
        if newT > oldT and #out > 0 then
            local base = {}
            for i, ev in ipairs(out) do base[i] = ev end
            local offset = oldT
            while offset < newT do
                for _, ev in ipairs(base) do
                    if ev.tick + offset < newT then
                        local copy = Looper.copyEvent(ev)
                        copy.tick = ev.tick + offset
                        out[#out + 1] = copy
                    end
                end
                offset = offset + oldT
            end
        end
        track.events = out
        Looper:touch(track)
    end
    state.history = {}
    Looper:showToast(string.format("TRACK C: %d BARS%s", bars, newT > oldT and " (REPEATS WHAT IS THERE)" or ""))
end

-- ---------------------------------------------------------------------------
-- Preview sound (PREVIEW row): a soft strum or stab of a chord
-- ---------------------------------------------------------------------------
function Lane:getPatch(state)
    return Patches.get(self, state)
end

function Lane:previewChord(state, track, chord, vel)
    if state.previewStyle == "OFF" or not chord then return end
    local notes = Theory:getPadVoicing(chord, "FULL", 0)
    local stab = state.previewStyle == "STAB"
    vel = vel or 0.6
    for i, semis in ipairs(notes) do
        Synth:schedule(stab and 0 or (i - 1) * self.STRUM_GAP, function()
            local v = Patches.noteOn(self, state, semis, vel * (1.0 - 0.06 * (i - 1)), { track = track })
            if v then Synth:schedule(stab and 0.22 or self.GATE, function() v:noteOff() end) end
        end)
    end
end

-- ---------------------------------------------------------------------------
-- Live (clock running)
-- ---------------------------------------------------------------------------
-- The line a press lands on: the next one, or the one just gone if it is
-- less than LATE ticks back
function Lane:landing(grid)
    local song = Looper:songTick()
    local line = math_floor(song / grid) * grid
    if song - line < self.LATE then return line end
    return line + grid
end

function Lane:liveChange(state, track)
    local grid, len, label = self:shoulderLength(Input.down.L1, Input.down.R1)
    local chord = Chords:chordData(state.currentChord or self:chordFor(state, "NEUTRAL"))
    local at = self:landing(grid)
    local rec = Input:isRecording()
    if rec then
        local take = self:recordUndo(state, track)
        self:write(track, chord, Looper:lanePos(at), len, "B", take)
    else
        state.override = { chord = chord, start = at, len = len }
    end
    state.queued = { chord = chord, at = at, len = len, rec = rec }
    state.flash.B = 1.0
    local soon = at > Looper:songTick()
    Looper:showToast(string.format("%s%s - %s%s", soon and "NEXT: " or "", Theory:chordName(chord), label,
        rec and "" or " - LIVE, NOT RECORDED"))
end

-- ---------------------------------------------------------------------------
-- Writing it out (clock stopped)
-- ---------------------------------------------------------------------------
local function barOf(pos) return math_floor(pos / Looper.BAR_TICKS) + 1 end

function Lane:stepWrite(state, track)
    local grid, len, label = self:shoulderLength(Input.down.L1, Input.down.R1)
    local chord = Chords:chordData(state.currentChord or self:chordFor(state, "NEUTRAL"))
    local from = Looper:lanePos()
    local pos = math_floor(from / grid) * grid
    local before = track.events
    local entry = self:pushEdit(track, "WRITE")
    self:write(track, chord, pos, len, "B")
    table.insert(state.history, { entry = entry, events = before, after = track.events, from = from })
    Looper:seekLane(pos + len)
    state.flash.B = 1.0
    self:previewChord(state, track, chord)
    Looper:showToast(string.format("BAR %d: %s (%s) - %s", barOf(pos), Theory:chordName(chord), self:numeral(chord), label))
end

-- L1 / R1 tap: back / on to a bar line
function Lane:step(dir)
    local bar = Looper.BAR_TICKS
    local pos = Looper:lanePos()
    local line = math_floor(pos / bar) * bar
    local target
    if dir < 0 then
        target = (pos - line > 1) and line or line - bar
    else
        target = line + bar
    end
    Looper:seekLane(target)
    Looper:showToast(string.format("BAR %d OF %d", barOf(Looper:lanePos()), Looper:getLaneBars()))
end

-- Y stopped: take back the last write (a chord or a stamp)
function Lane:takeBack(state, track)
    local h = table.remove(state.history)
    if not h or track.events ~= h.after then
        state.history = {}
        Looper:showToast("NOTHING TO TAKE BACK")
        return
    end
    track.events = h.events
    Looper:touch(track)
    if Looper.undoStack[#Looper.undoStack] == h.entry then table.remove(Looper.undoStack) end
    Looper:seekLane(h.from)
    state.flash.Y = 1.0
    Looper:showToast(string.format("TAKEN BACK - BAR %d", barOf(Looper:lanePos())))
end

-- ---------------------------------------------------------------------------
-- Colour and delete
-- ---------------------------------------------------------------------------
-- The chord being worked on: the one playing (running), the one behind the
-- playhead (stopped)
function Lane:targetChord(track)
    if Looper.playing then
        return self:activeAt(track, Looper:lanePos(Looper:songTick() + self.LATE))
    end
    return self:activeAt(track, (Looper:lanePos() - 1) % Looper:getLaneTicks())
end

function Lane:applyColour(state, track, colour, fresh)
    local ev, i = self:targetChord(track)
    if not ev then
        state.colour = colour
        Looper:showToast("NO CHORD HERE - NEW CHORDS: " .. colour)
        return
    end
    local chord = Chords:recolour(ev.chord, colour)
    if not chord then return end
    if fresh then self:pushEdit(track, "COLOUR") end
    local out = {}
    for k, e in ipairs(track.events) do out[k] = e end
    local copy = {}
    for k, v in pairs(ev) do copy[k] = v end
    copy.chord = chord
    out[i] = copy
    track.events = out
    Looper:touch(track)
    state.flash.A = 1.0
    if not Looper.playing then self:previewChord(state, track, chord) end
    Looper:showToast(string.format("%s -> %s (%s)", Theory:chordName(ev.chord), Theory:chordName(chord), self:numeral(chord)))
end

function Lane:deleteEvent(state, track, ev, fresh)
    if fresh then self:pushEdit(track, "DELETE") end
    local out = {}
    for _, e in ipairs(track.events) do
        if e ~= ev then out[#out + 1] = e end
    end
    track.events = out
    Looper:touch(track)
    state.flash.Y = 1.0
    Looper:showToast(string.format("DELETED %s (%s)", Theory:chordName(ev.chord), self:numeral(ev.chord)))
end

-- ---------------------------------------------------------------------------
-- Stamp: hold X for the wheel, tap X to put the picked progression down
-- ---------------------------------------------------------------------------
function Lane:wheelPick(state, dir)
    local page = self.WHEEL[state.wheelPage] or self.WHEEL[1]
    return page[dir]
end

function Lane:setHover(state, track, name)
    if name == state.hover then return end
    state.hover = name
    if not name then
        state.preview = nil
        return
    end
    local chords = self:progressionChords(state, name)
    local bar = Looper.BAR_TICKS
    state.preview = { chords = chords, start = math_floor(Looper:songTick() / bar) * bar, len = bar }
    if not Looper.playing then self:previewChord(state, track, chords[1]) end
    local p = self:progression(name)
    Looper:showToast(string.format("%s: %s - LET GO OF X TO PICK", p.name, table.concat(p.romans, " ")))
end

function Lane:closeWheel(state)
    state.wheelOpen = false
    state.hover = nil
    state.preview = nil
end

function Lane:stamp(state, track, l1, r1)
    local p = self:progression(state.picked)
    local grid, len, label = self:shoulderLength(l1, r1)
    local laneT = Looper:getLaneTicks()
    local running = Looper.playing
    local from = Looper:lanePos()
    local start = running and Looper:lanePos(self:landing(grid)) or math_floor(from / grid) * grid
    local before = track.events
    local entry = self:pushEdit(track, "STAMP")
    Looper:beginRecordingTake()
    local pos, n = start, 0
    for _, dir in ipairs(p.dirs) do
        if pos >= laneT then break end
        self:write(track, Chords:chordData(self:chordFor(state, dir)), pos, len, "X")
        pos = pos + len
        n = n + 1
    end
    state.flash.X = 1.0
    state.spice, state.spiceKey = {}, nil
    if not running then
        table.insert(state.history, { entry = entry, events = before, after = track.events, from = from })
        Looper:seekLane(pos)
        self:previewChord(state, track, Chords:chordData(self:chordFor(state, p.dirs[1])))
    end
    local cut = (n < #p.dirs) and string.format(" (%d OF %d FIT)", n, #p.dirs) or ""
    Looper:showToast(string.format("STAMPED %s: BARS %d-%d - %s A CHORD%s", p.name, barOf(start),
        barOf(math_max(start, pos - 1)), label, cut))
end

-- ---------------------------------------------------------------------------
-- Input
-- ---------------------------------------------------------------------------
-- A shoulder tap (stopped) steps; one used with B, X or the other shoulder doesn't
local function shoulderTaps(state)
    for _, s in ipairs({ "L1", "R1" }) do
        local other = (s == "L1") and "R1" or "L1"
        if Input.pressed[s] then
            state[s .. "used"] = Input.down[other] or false
            if Input.down[other] then state[other .. "used"] = true end
        end
    end
    if Input.pressed.B or Input.pressed.X or state.wheelOpen then
        if Input.down.L1 then state.L1used = true end
        if Input.down.R1 then state.R1used = true end
    end
end

function Lane:updateInput(dt, state, track)
    shoulderTaps(state)

    -- X: hold for the wheel, tap to stamp
    if Input.down.X then
        -- the shoulders held at any point during the tap set the chord length
        if Input.pressed.X then state.xL1, state.xR1 = false, false end
        state.xL1 = state.xL1 or Input.down.L1
        state.xR1 = state.xR1 or Input.down.R1
        state.xHeld = state.xHeld + dt
        if not state.wheelOpen and state.xHeld >= self.TAP then
            state.wheelOpen = true
            state.hover = nil
            Looper:showToast("WHEEL: POINT AT A PROGRESSION - L1 / R1: MORE")
        end
        if state.wheelOpen then
            if Input.pressed.L1 or Input.pressed.R1 then
                state.wheelPage = (state.wheelPage % #self.WHEEL) + 1
                self:setHover(state, track, nil)
                Looper:showToast(string.format("WHEEL PAGE %d OF %d", state.wheelPage, #self.WHEEL))
            end
            local dir = Input:get8WayDirection()
            local name = dir ~= "NEUTRAL" and self:wheelPick(state, dir) or nil
            if name then self:setHover(state, track, name) end
        end
        return
    end
    if Input.released.X then
        if state.wheelOpen then
            if state.hover then
                state.picked = state.hover
                Looper:showToast(string.format("PICKED %s - TAP X TO PUT IT DOWN", state.picked))
            else
                Looper:showToast("WHEEL CLOSED - " .. state.picked .. " STAYS PICKED")
            end
            self:closeWheel(state)
        else
            self:stamp(state, track, state.xL1 or Input.down.L1, state.xR1 or Input.down.R1)
        end
        state.xHeld = 0.0
    end

    -- A: colour (the D-pad is the colour wheel while A is held)
    if Input.down.A then
        local dir = Input:get8WayDirection()
        if Input.pressed.A then
            self:applyColour(state, track, Chords.COLOUR_WHEEL[dir], true)
            state.colourDir = dir
        elseif dir ~= "NEUTRAL" and dir ~= state.colourDir then
            self:applyColour(state, track, Chords.COLOUR_WHEEL[dir], false)
            state.colourDir = dir
        end
        return
    end
    state.colourDir = nil

    if Looper.playing then
        if Input.pressed.B then self:liveChange(state, track) end
        -- Y: delete the chord playing, then each one reached while held
        if Input.pressed.Y then
            local ev = self:targetChord(track)
            if ev then self:deleteEvent(state, track, ev, true) else Looper:showToast("NO CHORD TO DELETE") end
            state.deleting = Looper:songTick() + self.LATE
        elseif Input.down.Y and state.deleting then
            local a, b = state.deleting, Looper:songTick() + self.LATE
            if b > a then
                local laneT = Looper:getLaneTicks()
                for _, ev in ipairs(chordEvents(track)) do
                    local d = (ev.tick - a) % laneT
                    if d > 0 and d <= b - a then self:deleteEvent(state, track, ev, false) end
                end
                state.deleting = b
            end
        elseif not Input.down.Y then
            state.deleting = nil
        end
    else
        if Input.pressed.B then self:stepWrite(state, track) end
        if Input.pressed.Y then self:takeBack(state, track) end
        if Input.released.L1 and not state.L1used and not Input.down.R1 then self:step(-1) end
        if Input.released.R1 and not state.R1used and not Input.down.L1 then self:step(1) end
    end
end

-- ---------------------------------------------------------------------------
-- Every frame
-- ---------------------------------------------------------------------------
function Lane:updateVisuals(dt, state, controlsBlocked, isActive)
    for k, v in pairs(state.flash) do state.flash[k] = math_max(0.0, v - dt * 4.0) end
    local colouring = isActive and not controlsBlocked and Input.down.A
    local wheel = state.wheelOpen
    if (isActive and not colouring and not wheel) or not state.currentChord then
        local dirKey = (controlsBlocked or not isActive) and "NEUTRAL" or Input:get8WayDirection()
        state.currentChord = self:chordFor(state, dirKey)
    end
    if not isActive then return end
    if controlsBlocked and wheel then self:closeWheel(state); state.xHeld = 0.0 end

    local dpad = self.VIEW.dpad
    for _, d in ipairs(DIRS) do dpad[d] = nil end
    if wheel then
        local page = self.WHEEL[state.wheelPage] or self.WHEEL[1]
        for d, name in pairs(page) do dpad[d] = self.WHEEL_SHORT[name] or name end
        dpad.NEUTRAL = "P" .. state.wheelPage
    else
        for k, v in pairs(colouring and WHEEL_LABELS or ROMAN_LABELS) do dpad[k] = v end
    end
    local face = self.VIEW.face
    face.Y = Looper.playing and "DELETE" or "BACK"
    face.X = "STAMP"
    if wheel then
        self.VIEW.l1, self.VIEW.r1, self.VIEW.both = "PAGE", "PAGE", nil
    elseif Looper.playing then
        self.VIEW.l1, self.VIEW.r1, self.VIEW.both = "2 BARS", "1/2 BAR", "1 BEAT"
    else
        self.VIEW.l1, self.VIEW.r1, self.VIEW.both = "< STEP", "STEP >", "1 BEAT"
    end
end

-- Spice: on each pass of the lane some plain chords get a colour
function Lane:checkSpice(state, track)
    if state.spiceLevel == "OFF" then
        if next(state.spice) then state.spice = {} end
        state.spiceKey = nil
        return
    end
    local key = math_floor(Looper:songTick() / Looper:getLaneTicks())
    if state.spiceKey ~= key or state.spiceEvents ~= track.events then
        Chords.rollSpice(Chords, state, track)
        state.spiceKey, state.spiceEvents = key, track.events
    end
end

function Lane:updateVoices(dt, state, track)
    local song = Looper:songTick()
    local o = state.override
    if o and (not Looper.playing or song >= o.start + o.len) then state.override = nil end
    local q = state.queued
    if q and (song >= q.at + q.len or song < q.at - 4 * Looper.BAR_TICKS) then state.queued = nil end
    if not Input:isRecording() then state.recTake = nil end
    self:checkSpice(state, track)
end

-- ---------------------------------------------------------------------------
-- Track page rows: BARS, PREVIEW, SOUND (the preview sound), COLOUR, SPICE
-- ---------------------------------------------------------------------------
local function indexOf(list, value)
    for i, v in ipairs(list) do if v == value then return i end end
    return 1
end

local function listRow(key, label, labels, index)
    local items = {}
    for i, l in ipairs(labels) do items[i] = { label = l } end
    return { key = key, label = label, kind = "setting", value = labels[index], items = items, index = index }
end

Lane.SOUND_ROW = 3

function Lane:getSoundRows(state)
    local bars = {}
    for i, b in ipairs(self.BARS) do bars[i] = b .. " BARS" end
    local sound = Patches.row(self, state)
    sound.label = "SOUND"
    return {
        listRow("BARS", "BARS", bars, indexOf(self.BARS, state.bars)),
        listRow("PREVIEW", "PREVIEW", self.PREVIEWS, indexOf(self.PREVIEWS, state.previewStyle)),
        sound,
        listRow("COLOUR", "COLOUR", Theory.COLOURS, indexOf(Theory.COLOURS, state.colour)),
        listRow("SPICE", "SPICE", Chords.SPICES, indexOf(Chords.SPICES, state.spiceLevel)),
    }
end

function Lane:cycleRowSound(state, rowIdx, delta, quiet)
    if rowIdx ~= self.SOUND_ROW then return end
    Patches.step(self, state, delta)
    if not quiet then self:previewRowSound(state, rowIdx) end
end

function Lane:previewRowSound(state, rowIdx)
    if rowIdx ~= self.SOUND_ROW then return end
    local was = state.previewStyle
    if was == "OFF" then state.previewStyle = "STRUM" end
    self:previewChord(state, Looper:getLane(), Chords:chordData(self:chordFor(state, "NEUTRAL")), 0.7)
    state.previewStyle = was
end

local function step(list, value, delta)
    return list[((indexOf(list, value) - 1 + delta) % #list) + 1]
end

function Lane:cycleSetting(state, key, delta)
    if key == "BARS" then
        self:setBars(state, Looper:getLane(), step(self.BARS, state.bars, delta))
    elseif key == "PREVIEW" then
        state.previewStyle = step(self.PREVIEWS, state.previewStyle, delta)
        Looper:showToast("PREVIEW: " .. state.previewStyle .. (state.previewStyle ~= "OFF" and " - WHEN WRITING WITH THE CLOCK STOPPED" or ""))
        self:previewChord(state, Looper:getLane(), Chords:chordData(self:chordFor(state, "NEUTRAL")), 0.7)
    elseif key == "COLOUR" then
        state.colour = step(Theory.COLOURS, state.colour, delta)
        Looper:showToast("NEW CHORDS: " .. state.colour)
    elseif key == "SPICE" then
        state.spiceLevel = step(Chords.SPICES, state.spiceLevel, delta)
        state.spice, state.spiceKey = {}, nil
        Looper:showToast("SPICE: " .. state.spiceLevel .. (state.spiceLevel ~= "OFF" and " - RANDOM COLOURS ON PLAYBACK" or ""))
    end
end

-- The lane never sounds on playback (the looper doesn't play it)
function Lane:noteOn() end

-- ---------------------------------------------------------------------------
-- The chart (Chrome:drawLaneView) and the strip (Chrome:drawLaneStrip)
-- ---------------------------------------------------------------------------
local function shown(state, ev)
    return (state.spice and state.spice[ev]) or ev.chord
end

-- One entry per bar: the chords starting in it ({ chord, frac }), or a
-- carried chord (`carry`), or nothing before the lane's first chord
function Lane:cells(state, track)
    local list = chordEvents(track)
    local bar = Looper.BAR_TICKS
    local out = {}
    local n = state.bars
    local k, current = 1, nil
    for b = 1, n do
        local from, to = (b - 1) * bar, b * bar
        local cell = { starts = {}, bar = b }
        while list[k] and list[k].tick < to do
            local ev = list[k]
            cell.starts[#cell.starts + 1] = { chord = shown(state, ev), frac = (ev.tick - from) / bar, ev = ev }
            current = ev
            k = k + 1
        end
        if #cell.starts == 0 and current then cell.carry = shown(state, current) end
        out[b] = cell
    end
    return out
end

-- The lane as spans for the strip: { from, to (0..1 of the lane), chord, ev }
function Lane:spans(state, track)
    local list = chordEvents(track)
    local laneT = Looper:getLaneTicks()
    local spans = {}
    for i, ev in ipairs(list) do
        local to = list[i + 1] and list[i + 1].tick or laneT
        spans[#spans + 1] = { from = ev.tick / laneT, to = to / laneT, chord = shown(state, ev), ev = ev }
    end
    return spans
end

function Lane:getDpadSubtitle(state)
    if state.wheelOpen then return "D-PAD: PROGRESSION" end
    if Input.down.A then return "D-PAD: COLOUR" end
    return Looper.playing and "D-PAD: CHORD" or "D-PAD: CHORD B WRITES"
end

-- ---------------------------------------------------------------------------
-- Save / load (the events are saved by Session with the lane)
-- ---------------------------------------------------------------------------
function Lane:saveState(state)
    return { bars = state.bars, colour = state.colour, spice = state.spiceLevel, patch = state.patch,
             preview = state.previewStyle, picked = state.picked }
end

function Lane:loadState(state, data)
    if type(data) ~= "table" then return end
    for _, b in ipairs(self.BARS) do
        if data.bars == b then state.bars = b end
    end
    for _, c in ipairs(Theory.COLOURS) do
        if data.colour == c then state.colour = c end
    end
    for _, s in ipairs(Chords.SPICES) do
        if data.spice == s then state.spiceLevel = s end
    end
    for _, p in ipairs(self.PREVIEWS) do
        if data.preview == p then state.previewStyle = p end
    end
    for _, p in ipairs(Chords.PROGRESSIONS) do
        if data.picked == p.name then state.picked = p.name end
    end
    Patches.load(self, state, data.patch)
end

return Lane
