-- ============================================================================
-- src/instruments/chords.lua — CHORD TRACK: lay down the song's chords
--
-- An instrument whose job is choosing the chords the other tracks follow
-- (Harmony, SPEC §5). It opens on the SILENT patch, so it is a chord track
-- you see but don't hear; pick any patch to hear the chords as a light strum.
--
--   D-pad          one of the Harp's nine chords (same map: neutral I,
--                  ↑ ♭VI, ↖ ii, ↗ iii, ← IV, → V, ↓ vi, ↙ ♭VII, ↘ iv)
--   B  PLACE       write the D-pad's chord
--   A  NEXT        write the progression's next chord (no D-pad needed)
--   Y  TOP         back to the progression's first chord, and write it
--   X  STAMP       fill the whole loop with the progression (undoable)
--   L1 / R1 / both snap to the bar / half bar / beat. Holding B or A with a
--                  shoulder writes again on every line: hold B + L1 and
--                  steer the D-pad, or hold A + L1 to play the progression
--                  a bar per chord.
-- Track page rows: PATCH, COLOUR, PROGRESSION, LENGTH (chord length for STAMP).
--
-- Every chord is recorded under action "B", whichever button wrote it, so a
-- new chord on a line replaces the old one there, and the Erase page's CLR B
-- clears them all.
-- ============================================================================

local Theory  = require("src.theory")
local Input   = require("src.input")
local Synth   = require("src.synth")
local Looper  = require("src.looper")
local Patches = require("src.instruments.patches")

local math_floor = math.floor
local math_max   = math.max

-- D-pad directions by roman numeral (the Harp's chord map)
local DIR = {
    I = "NEUTRAL", ii = "UP_LEFT", iii = "UP_RIGHT", IV = "LEFT", V = "RIGHT",
    vi = "DOWN", bVI = "UP", bVII = "DOWN_LEFT", iv = "DOWN_RIGHT",
}

local function prog(name, romans, about)
    local dirs = {}
    for i, r in ipairs(romans) do dirs[i] = assert(DIR[r], r) end
    return { name = name, romans = romans, dirs = dirs, about = about }
end

local Chords = {
    id = "chords",
    name = "CHORD TRACK",
    shortName = "CHRD",
    title = "CHORD TRACK",
    viewKind = "lab",
    defaultGridIndex = 1,        -- 1/4: a chord lands on a beat
    chordSource = true,          -- Harmony takes chords from this track (src/harmony.lua)

    HOME_GROUP = "PLUCK",
    DEFAULT_PATCH = "silent",
    ALLOW_SILENT = true,
    REGISTER = 4,
    VOICES = 8,
    GATE = 0.6,                  -- a sustaining patch is held this long
    STRUM_GAP = 0.018,           -- seconds between the strings of the strum

    -- Common progressions, built only from the nine D-pad chords, so every
    -- one can also be played by hand. Romans are in a major key; in a minor
    -- key the scale chords turn minor as the D-pad's do.
    PROGRESSIONS = {
        prog("POP",         { "I", "V", "vi", "IV" },   "the four-chord pop song"),
        prog("50S",         { "I", "vi", "IV", "V" },   "doo-wop, ballads"),
        prog("SAD POP",     { "vi", "IV", "I", "V" },   "the pop one, starting on the minor"),
        prog("ROCK",        { "I", "IV", "V", "IV" },   "three-chord rock"),
        prog("JAZZ ii-V-I", { "ii", "V", "I", "I" },    "the jazz turnaround"),
        prog("ROYAL ROAD",  { "IV", "V", "iii", "vi" }, "J-pop, anime themes"),
        prog("DESCEND",     { "vi", "V", "IV", "V" },   "minor, stepping down and back"),
        prog("MIXO",        { "I", "bVII", "IV", "I" }, "classic rock, borrowed bVII"),
        prog("HEROIC",      { "bVI", "bVII", "I", "I" }, "the big lift into I"),
        prog("BITTERSWEET", { "I", "IV", "iv", "I" },   "major to minor IV and home"),
        prog("CANON",       { "I", "V", "vi", "iii", "IV", "I", "IV", "V" }, "Pachelbel, eight chords"),
        prog("BLUES 8",     { "I", "V", "IV", "IV", "I", "V", "I", "V" },    "eight-bar blues"),
    },

    -- LENGTH row: how long each chord is when STAMP fills the loop.
    -- FIT spreads the progression over the whole loop.
    LENGTHS = {
        { label = "FIT" },
        { label = "2 BARS",  beats = 8 },
        { label = "1 BAR",   beats = 4 },
        { label = "1/2 BAR", beats = 2 },
        { label = "1 BEAT",  beats = 1 },
    },

    ERASE = { B = { actions = { "B" }, label = "CHORDS" } },

    VIEW = {
        dpad = { NEUTRAL = "I", UP = "bVI", DOWN = "vi", LEFT = "IV", RIGHT = "V",
                 UP_LEFT = "ii", UP_RIGHT = "iii", DOWN_LEFT = "bVII", DOWN_RIGHT = "IVm" },
        face = { B = "PLACE", A = "NEXT", Y = "TOP", X = "STAMP" },
        l1 = "SNAP BAR", r1 = "SNAP 1/2", both = "SNAP BEAT",
    },
}

-- The D-pad labels again, kept to mark the progression's next chord
local BASE_DPAD = {}
for k, v in pairs(Chords.VIEW.dpad) do BASE_DPAD[k] = v end

function Chords:newState()
    return {
        patch = self.DEFAULT_PATCH,
        colour = "TRIAD",
        progression = 1,           -- index into PROGRESSIONS
        length = 1,                -- index into LENGTHS
        step = 1,                  -- the progression's next chord
        currentChord = nil,        -- the D-pad's chord
        liveChord = nil,           -- the chord last written live (Harmony)
        lastPlaced = nil,          -- { chord, via } for the readout
        flash = { B = 0, A = 0, Y = 0, X = 0 },
        lastLine = nil,            -- the snap line last written (repeat)
    }
end

function Chords:progressionOf(state)
    return self.PROGRESSIONS[state.progression] or self.PROGRESSIONS[1]
end

function Chords:chordFor(state, dirKey)
    return Theory:getChordForDirection(dirKey, false, false, state.colour)
end

-- Same chord data as the Harp records (Harmony and followers read it)
function Chords:chordData(chord)
    return { name = chord.name, roman = chord.roman, colour = chord.colour, suffix = chord.suffix,
             root = chord.root, third = chord.third, fifth = chord.fifth, seventh = chord.seventh,
             borrowed = chord.borrowed or nil, key = Theory:getRootSemis() }
end

-- ---------------------------------------------------------------------------
-- Visuals: the D-pad's chord, and the next progression chord marked on the star
-- ---------------------------------------------------------------------------
function Chords:updateVisuals(dt, state, controlsBlocked, isActive)
    for k, v in pairs(state.flash) do state.flash[k] = math_max(0.0, v - dt * 4.0) end
    if isActive or not state.currentChord then
        local dirKey = controlsBlocked and "NEUTRAL" or Input:get8WayDirection()
        state.currentChord = self:chordFor(state, dirKey)
    end
    if isActive then
        local p = self:progressionOf(state)
        local nextDir = p.dirs[state.step] or p.dirs[1]
        for k, v in pairs(BASE_DPAD) do
            self.VIEW.dpad[k] = (k == nextDir) and ("> " .. v) or v
        end
    end
end

-- ---------------------------------------------------------------------------
-- Track page rows
-- ---------------------------------------------------------------------------
function Chords:getPatch(state)
    return Patches.get(self, state)
end

function Chords:cycleRowSound(state, rowIdx, delta, quiet)
    if rowIdx ~= 1 then return end
    Patches.step(self, state, delta)
    if not quiet then self:previewRowSound(state, rowIdx) end
end

function Chords:previewRowSound(state, rowIdx)
    if rowIdx ~= 1 then return end
    self:strum(state, nil, self:chordData(self:chordFor(state, "NEUTRAL")), 0.7)
end

local function listRow(key, label, list, index, field)
    local items = {}
    for i, it in ipairs(list) do items[i] = { label = it[field or "label"] } end
    return { key = key, label = label, kind = "setting", value = items[index].label, items = items, index = index }
end

local function indexOf(list, value)
    for i, v in ipairs(list) do if v == value then return i end end
    return 1
end

function Chords:getSoundRows(state)
    local colours = {}
    for i, c in ipairs(Theory.COLOURS) do colours[i] = { label = c } end
    return {
        Patches.row(self, state),
        listRow("COLOUR", "COLOUR", colours, indexOf(Theory.COLOURS, state.colour)),
        listRow("PROGRESSION", "PROGRESSION", self.PROGRESSIONS, state.progression, "name"),
        listRow("LENGTH", "LENGTH", self.LENGTHS, state.length),
    }
end

function Chords:cycleSetting(state, key, delta)
    if key == "COLOUR" then
        local n = #Theory.COLOURS
        state.colour = Theory.COLOURS[((indexOf(Theory.COLOURS, state.colour) - 1 + delta) % n) + 1]
        Looper:showToast("CHORD COLOUR: " .. state.colour)
    elseif key == "PROGRESSION" then
        local n = #self.PROGRESSIONS
        state.progression = ((state.progression - 1 + delta) % n) + 1
        state.step = 1
        local p = self:progressionOf(state)
        Looper:showToast(p.name .. ": " .. table.concat(p.romans, " - "))
    elseif key == "LENGTH" then
        local n = #self.LENGTHS
        state.length = ((state.length - 1 + delta) % n) + 1
        Looper:showToast("STAMP LENGTH: " .. self.LENGTHS[state.length].label)
    end
end

-- ---------------------------------------------------------------------------
-- Playing
-- ---------------------------------------------------------------------------
-- Snap lines per bar from the shoulders: L1 bar, R1 half bar, both a beat
function Chords:getSnap()
    local l1, r1 = Input.down.L1, Input.down.R1
    if l1 and r1 then return 4, "1 BEAT" end
    if l1 then return 1, "1 BAR" end
    if r1 then return 2, "1/2 BAR" end
    return nil, nil
end

-- The snap line nearest the playhead (what Looper:recordEvent snaps to),
-- counted over the whole loop (`total` lines)
local function nearestLine(total)
    local step = Looper:getLoopTicks() / total
    return math_floor(Looper.tick / step + 0.5) % total
end

-- The chord a button writes now (A and Y move through the progression)
function Chords:chordForButton(state, btn)
    if btn == "B" then
        return state.currentChord or self:chordFor(state, "NEUTRAL")
    end
    local p = self:progressionOf(state)
    if btn == "Y" then state.step = 1 end
    local chord = self:chordFor(state, p.dirs[state.step] or p.dirs[1])
    state.step = (state.step % #p.dirs) + 1
    return chord
end

function Chords:write(state, btn, lines, emit)
    local chord = self:chordForButton(state, btn)
    local data = self:chordData(chord)
    state.lastLine = lines and nearestLine(lines * Looper.bars) or nil
    emit({
        action = "B",            -- every chord on one action: a new one replaces the old on its line
        via = btn,
        chord = data,
        vel = 0.75,
        overrideGridSteps = lines and lines * Looper.bars or nil,
    })
end

function Chords:updateInput(dt, state, track, emit)
    local lines, label = self:getSnap()
    state.snapLabel = label

    for _, btn in ipairs({ "B", "A", "Y" }) do
        if Input.pressed[btn] then self:write(state, btn, lines, emit) end
    end
    if Input.pressed.X then self:stamp(state, track) end

    -- Held B or A with a shoulder: write again on every new line
    if lines and Looper.playing then
        local total = lines * Looper.bars
        local u, uPrev = Looper.phase * total, Looper.prevPhase * total
        if math_floor(u) ~= math_floor(uPrev) then
            local line = math_floor(u) % total
            if line ~= state.lastLine then
                for _, btn in ipairs({ "B", "A" }) do
                    if Input.down[btn] and not Input.pressed[btn] then
                        self:write(state, btn, lines, emit)
                        break
                    end
                end
            end
            state.lastLine = nil
        end
    end
end

-- STAMP: replace this track's chords with the progression, over the whole loop
function Chords:stampLength(state, count)
    local loop = Looper:getLoopTicks()
    local beats = self.LENGTHS[state.length].beats
    if not beats then return loop / count end
    return beats * Looper.PPQN
end

function Chords:stamp(state, track)
    local p = self:progressionOf(state)
    local loop = Looper:getLoopTicks()
    local len = self:stampLength(state, #p.dirs)

    -- one undo entry brings the old chords back
    Looper:silenceTrack(track.slot)
    Looper:pushUndo({
        kind = "swap", trackSlot = track.slot, instrumentId = track.instrumentId,
        name = track.name, shortName = track.shortName, gridIndex = track.gridIndex,
        state = track.state, events = track.events,
    })
    Looper:beginRecordingTake()
    local events, i = {}, 0
    while i * len < loop - 0.5 do
        local chord = self:chordFor(state, p.dirs[(i % #p.dirs) + 1])
        events[#events + 1] = { tick = math_floor(i * len + 0.5), len = 0, action = "B", via = "X",
                                chord = self:chordData(chord), vel = 0.75, takeId = Looper.currentTakeId }
        i = i + 1
    end
    track.events = events
    state.step = 1
    state.flash.X = 1.0
    local fits = (i % #p.dirs == 0) and "" or string.format(" (%d OF %d FIT)", math.min(i, #p.dirs), #p.dirs)
    Looper:showToast(string.format("STAMPED %s: %d CHORDS%s - UNDO BRINGS BACK THE OLD", p.name, i, fits))
end

-- A light strum of the chord, unless the patch is SILENT
function Chords:strum(state, track, chord, vel)
    local patch = self:getPatch(state)
    if not patch or patch.silent then return end
    local notes = Theory:getPadVoicing(chord, "FULL", 0)
    for i, semis in ipairs(notes) do
        Synth:schedule((i - 1) * self.STRUM_GAP, function()
            local v = Patches.noteOn(self, state, semis, vel * (1.0 - 0.06 * (i - 1)), { track = track })
            if v and v.loopSrc then Synth:schedule(self.GATE, function() v:noteOff() end) end
        end)
    end
end

function Chords:noteOn(ev, state, track, isPlayback)
    if not ev.chord then return end
    if not isPlayback then state.liveChord = ev.chord end
    state.lastPlaced = { chord = ev.chord, via = ev.via }
    state.flash[ev.via or "B"] = 1.0
    self:strum(state, track, ev.chord, ev.vel or 0.75)
end

-- ---------------------------------------------------------------------------
-- Readout (the plain lab view)
-- ---------------------------------------------------------------------------
-- The chords written on a track, bar by bar: "C G | Am F"
local function barLine(track)
    if not track then return "" end
    local barTicks = Looper.PPQN * 4
    local bars = {}
    for b = 1, Looper.bars do bars[b] = {} end
    local list = {}
    for _, ev in ipairs(track.events) do
        if ev.chord and not ev.open then list[#list + 1] = ev end
    end
    table.sort(list, function(a, b) return a.tick < b.tick end)
    for _, ev in ipairs(list) do
        local b = math_floor(ev.tick / barTicks) + 1
        if bars[b] then table.insert(bars[b], Theory:chordName(ev.chord)) end
    end
    local out = {}
    for b = 1, Looper.bars do out[b] = (#bars[b] > 0) and table.concat(bars[b], " ") or "-" end
    return "| " .. table.concat(out, " | ") .. " |"
end

-- Is this track the one setting the chords? (lazy: harmony requires looper)
local function sourceLine(track)
    local Harmony = require("src.harmony")
    local src = Harmony:source()
    if not src then return "CHORDS: NONE RECORDED YET - FOLLOWING LIVE" end
    if track and src == track then return "THIS TRACK SETS THE CHORDS" end
    return string.format("CHORDS COME FROM TRACK %d (%s)", src.slot, src.shortName or "")
end

function Chords:getReadout(state)
    local chord = state.currentChord or self:chordFor(state, "NEUTRAL")
    local p = self:progressionOf(state)

    local names = {}
    for i, dir in ipairs(p.dirs) do
        local n = Theory:chordName(self:chordFor(state, dir))
        names[i] = (i == state.step) and ("[" .. n .. "]") or n
    end

    local track
    for slot = 1, 4 do
        local t = Looper.tracks[slot]
        if t and t.state == state then track = t end
    end

    local small = chord.roman .. "  -  " .. (state.snapLabel and ("SNAP " .. state.snapLabel) or "ON THE BEAT")
    return chord.name, small, {
        p.name .. ":  " .. table.concat(names, " "),
        "LOOP  " .. barLine(track),
        sourceLine(track),
        "",
        "B PLACE   A NEXT   Y FROM TOP",
        "X STAMP WHOLE LOOP (" .. self.LENGTHS[state.length].label .. ")",
        "HOLD B/A + L1 BAR  R1 HALF  BOTH BEAT",
    }
end

-- ---------------------------------------------------------------------------
-- Save / load
-- ---------------------------------------------------------------------------
function Chords:saveState(state)
    return { patch = state.patch, colour = state.colour,
             progression = self:progressionOf(state).name, length = self.LENGTHS[state.length].label }
end

function Chords:loadState(state, data)
    if type(data) ~= "table" then return end
    Patches.load(self, state, data.patch)
    for _, c in ipairs(Theory.COLOURS) do
        if data.colour == c then state.colour = c end
    end
    for i, p in ipairs(self.PROGRESSIONS) do
        if data.progression == p.name then state.progression = i end
    end
    for i, l in ipairs(self.LENGTHS) do
        if data.length == l.label then state.length = i end
    end
end

return Chords
