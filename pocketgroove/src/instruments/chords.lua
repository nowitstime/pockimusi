-- ============================================================================
-- src/instruments/chords.lua — CHORD TRACK: lay down the song's chords
--
-- An instrument whose job is choosing the chords the other tracks follow
-- (Harmony, SPEC §5). It opens on the SILENT patch, so it is a chord track
-- you see but don't hear; pick any patch to hear the chords as a light strum.
--
--   D-pad            one of the Harp's nine chords (same map: neutral I,
--                    ↑ ♭VI, ↖ ii, ↗ iii, ← IV, → V, ↓ vi, ↙ ♭VII, ↘ iv).
--                    The progression's chord for this point in the loop is
--                    marked `>`, so a progression is entered by following it.
--   B  WRITE         write the D-pad's chord (recording) / play it live
--   A  COLOUR        hold A and point the D-pad: the chord under the
--                    playhead takes that colour (7, 9, add9, aug, dim, sus2,
--                    sus4, 6; neutral = plain). No chord there: sets the
--                    colour new chords get.
--   Y  DELETE        delete the chord under the playhead; keep holding to
--                    delete each chord the playhead reaches
--   X  STAMP         fill the whole loop with the progression
--   L1 / R1 / both   B snaps to the bar / half bar / beat; hold B with a
--                    shoulder and it writes again on every line
-- COLOUR, DELETE and STAMP are edits: they work without recording, and each
-- press is one undo. Track page rows: PATCH, COLOUR (for new chords),
-- PROGRESSION, LENGTH (chord length for STAMP), SPICE (random colours on
-- playback, never recorded; followers hear them too).
--
-- Every chord is recorded under action "B", so a new chord on a line
-- replaces the old one there, and the Erase page's CLR B clears them all.
-- ============================================================================

local Theory  = require("src.theory")
local Input   = require("src.input")
local Synth   = require("src.synth")
local Looper  = require("src.looper")
local Patches = require("src.instruments.patches")

local math_floor = math.floor
local math_max   = math.max

-- D-pad directions by roman numeral (the Harp's chord map; Theory calls iv "IVm")
local DIR = {
    I = "NEUTRAL", ii = "UP_LEFT", iii = "UP_RIGHT", IV = "LEFT", V = "RIGHT",
    vi = "DOWN", bVI = "UP", bVII = "DOWN_LEFT", iv = "DOWN_RIGHT", IVm = "DOWN_RIGHT",
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
    LOOKAHEAD = 120,             -- a chord this close ahead already counts as under the playhead (as Harmony)

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

    -- LENGTH row: how long each chord is when STAMP fills the loop (and how
    -- the `>` guide moves). FIT spreads the progression over the whole loop.
    LENGTHS = {
        { label = "FIT" },
        { label = "2 BARS",  beats = 8 },
        { label = "1 BAR",   beats = 4 },
        { label = "1/2 BAR", beats = 2 },
        { label = "1 BEAT",  beats = 1 },
    },

    -- Hold A: the D-pad picks a colour. Up = richer, down = tense, sides = sus.
    COLOUR_WHEEL = {
        NEUTRAL = "TRIAD", UP = "7TH", UP_RIGHT = "9TH", RIGHT = "ADD9", UP_LEFT = "6TH",
        LEFT = "SUS4", DOWN_LEFT = "SUS2", DOWN = "DIM", DOWN_RIGHT = "AUG",
    },
    -- Short tags after a roman numeral ("V7", "IVsus4")
    COLOUR_TAG = { TRIAD = "", ["7TH"] = "7", ["9TH"] = "9", SUS4 = "sus4", ADD9 = "add9",
                   SUS2 = "sus2", ["6TH"] = "6", AUG = "+", DIM = "dim" },

    -- SPICE row: on playback some plain chords get a colour, new each pass
    SPICES = { "OFF", "LIGHT", "WILD" },
    SPICE_CHANCE = { LIGHT = 0.3, WILD = 0.55 },

    ERASE = { B = { actions = { "B" }, label = "CHORDS" } },

    VIEW = {
        dpad = {},               -- filled every frame (chords, or colours while A is held)
        face = { B = "WRITE", A = "COLOUR", Y = "DELETE", X = "STAMP" },
        l1 = "SNAP BAR", r1 = "SNAP 1/2", both = "SNAP BEAT",
    },
}

local ROMAN_LABELS = { NEUTRAL = "I", UP = "bVI", DOWN = "vi", LEFT = "IV", RIGHT = "V",
                       UP_LEFT = "ii", UP_RIGHT = "iii", DOWN_LEFT = "bVII", DOWN_RIGHT = "iv" }
local WHEEL_LABELS = { NEUTRAL = "PLAIN", UP = "7", UP_RIGHT = "9", RIGHT = "ADD9", UP_LEFT = "6",
                       LEFT = "SUS4", DOWN_LEFT = "SUS2", DOWN = "DIM", DOWN_RIGHT = "AUG" }
for k, v in pairs(ROMAN_LABELS) do Chords.VIEW.dpad[k] = v end

function Chords:newState()
    return {
        patch = self.DEFAULT_PATCH,
        colour = "TRIAD",          -- colour new chords get
        progression = 1,           -- index into PROGRESSIONS
        length = 1,                -- index into LENGTHS
        spiceLevel = "OFF",        -- SPICE row
        spice = {},                -- [event] = coloured chord, this pass (read by Harmony)
        currentChord = nil,        -- the D-pad's chord
        liveChord = nil,           -- the chord last played live (Harmony)
        lastPlaced = nil,          -- { chord, via } for the readout
        flash = { B = 0, A = 0, Y = 0, X = 0 },
        lastLine = nil,            -- the snap line last written (repeat)
        colourDir = nil,           -- the direction last applied while A is held
    }
end

function Chords:progressionOf(state)
    return self.PROGRESSIONS[state.progression] or self.PROGRESSIONS[1]
end

function Chords:chordFor(state, dirKey, colour)
    return Theory:getChordForDirection(dirKey, false, false, colour or state.colour)
end

-- Same chord data as the Harp records (Harmony and followers read it), plus
-- the D-pad direction, so the chord can be rebuilt in another colour
function Chords:chordData(chord)
    return { name = chord.name, roman = chord.roman, colour = chord.colour, suffix = chord.suffix,
             root = chord.root, third = chord.third, fifth = chord.fifth, seventh = chord.seventh,
             borrowed = chord.borrowed or nil, key = Theory:getRootSemis(), dirKey = chord.dirKey }
end

-- The same chord in another colour (nil if it can't be rebuilt)
function Chords:recolour(chord, colour)
    local dir = chord.dirKey or DIR[chord.roman]
    if not dir then return nil end
    local data = self:chordData(Theory:getChordForDirection(dir, false, false, colour))
    data.key = chord.key
    return data
end

-- "V7", "vi", "IV+": a chord as a numeral with its colour
function Chords:numeral(chord)
    local dir = chord.dirKey or DIR[chord.roman]
    local roman = (dir and ROMAN_LABELS[dir]) or chord.roman or "?"
    return roman .. (self.COLOUR_TAG[chord.colour or "TRIAD"] or "")
end

local function trackOf(state)
    for slot = 1, 4 do
        local t = Looper.tracks[slot]
        if t and t.state == state then return t end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Where we are in the loop
-- ---------------------------------------------------------------------------
-- Ticks per chord for STAMP and the guide
function Chords:stampLength(state, count)
    local beats = self.LENGTHS[state.length].beats
    if not beats then return Looper:getLoopTicks() / count end
    return beats * Looper.PPQN
end

-- The progression's slot for the playhead (what STAMP would put here)
function Chords:guideIndex(state)
    local p = self:progressionOf(state)
    local len = self:stampLength(state, #p.dirs)
    return (math_floor(Looper.tick / len) % #p.dirs) + 1
end

-- The chord event under the playhead on this track, and its index
function Chords:chordUnder(track)
    if not track then return nil end
    local loop = Looper:getLoopTicks()
    local pos = (Looper.tick + self.LOOKAHEAD) % loop
    local best, bestI, bestD
    for i, ev in ipairs(track.events) do
        if ev.chord and not ev.open then
            local d = (pos - ev.tick) % loop          -- how far back it starts
            if not bestD or d < bestD then best, bestI, bestD = ev, i, d end
        end
    end
    return best, bestI
end

-- ---------------------------------------------------------------------------
-- Visuals: the D-pad's chord; on the star, the guide (or colours while A is held)
-- ---------------------------------------------------------------------------
function Chords:updateVisuals(dt, state, controlsBlocked, isActive)
    for k, v in pairs(state.flash) do state.flash[k] = math_max(0.0, v - dt * 4.0) end
    local colouring = isActive and not controlsBlocked and Input.down.A
    if (isActive and not colouring) or not state.currentChord then
        local dirKey = controlsBlocked and "NEUTRAL" or Input:get8WayDirection()
        state.currentChord = self:chordFor(state, dirKey)
    end
    if isActive then
        local dpad = self.VIEW.dpad
        if colouring then
            for k, v in pairs(WHEEL_LABELS) do dpad[k] = v end
        else
            local p = self:progressionOf(state)
            local guide = p.dirs[self:guideIndex(state)]
            for k, v in pairs(ROMAN_LABELS) do dpad[k] = (k == guide) and ("> " .. v) or v end
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

local function indexOf(list, value)
    for i, v in ipairs(list) do if v == value then return i end end
    return 1
end

local function listRow(key, label, labels, index)
    local items = {}
    for i, l in ipairs(labels) do items[i] = { label = l } end
    return { key = key, label = label, kind = "setting", value = labels[index], items = items, index = index }
end

function Chords:getSoundRows(state)
    local progs, lengths = {}, {}
    for i, p in ipairs(self.PROGRESSIONS) do progs[i] = p.name end
    for i, l in ipairs(self.LENGTHS) do lengths[i] = l.label end
    return {
        Patches.row(self, state),
        listRow("COLOUR", "COLOUR", Theory.COLOURS, indexOf(Theory.COLOURS, state.colour)),
        listRow("PROGRESSION", "PROGRESSION", progs, state.progression),
        listRow("LENGTH", "LENGTH", lengths, state.length),
        listRow("SPICE", "SPICE", self.SPICES, indexOf(self.SPICES, state.spiceLevel)),
    }
end

local function step(list, value, delta)
    local n = #list
    return list[((indexOf(list, value) - 1 + delta) % n) + 1]
end

function Chords:cycleSetting(state, key, delta)
    if key == "COLOUR" then
        state.colour = step(Theory.COLOURS, state.colour, delta)
        Looper:showToast("NEW CHORDS: " .. state.colour)
    elseif key == "PROGRESSION" then
        local n = #self.PROGRESSIONS
        state.progression = ((state.progression - 1 + delta) % n) + 1
        local p = self:progressionOf(state)
        Looper:showToast(p.name .. ": " .. table.concat(p.romans, " - "))
    elseif key == "LENGTH" then
        local n = #self.LENGTHS
        state.length = ((state.length - 1 + delta) % n) + 1
        Looper:showToast("CHORD LENGTH: " .. self.LENGTHS[state.length].label)
    elseif key == "SPICE" then
        state.spiceLevel = step(self.SPICES, state.spiceLevel, delta)
        state.spice, state.spiceTick = {}, nil
        Looper:showToast("SPICE: " .. state.spiceLevel .. (state.spiceLevel ~= "OFF" and " - RANDOM COLOURS ON PLAYBACK" or ""))
    end
end

-- ---------------------------------------------------------------------------
-- Edits (COLOUR, DELETE, STAMP): replace the track's event list, so Harmony
-- sees the change; the first change of a press pushes one undo entry
-- ---------------------------------------------------------------------------
local function copyList(list)
    local out = {}
    for i, ev in ipairs(list) do out[i] = ev end
    return out
end

function Chords:edit(track, label, fresh)
    if fresh then
        Looper:pushUndo({ kind = "events", trackSlot = track.slot, events = track.events, label = label })
    end
    track.events = copyList(track.events)
    return track.events
end

-- Hold A + D-pad: colour the chord under the playhead (or set the new-chord colour)
function Chords:applyColour(state, track, colour, fresh)
    local ev, i = self:chordUnder(track)
    if not ev then
        state.colour = colour
        Looper:showToast("NO CHORD HERE - NEW CHORDS: " .. colour)
        return
    end
    local chord = self:recolour(ev.chord, colour)
    if not chord then return end
    local before = Theory:chordName(ev.chord)
    local list = self:edit(track, "COLOUR", fresh)
    local copy = {}
    for k, v in pairs(ev) do copy[k] = v end
    copy.chord = chord
    list[i] = copy
    state.spice[ev] = nil
    state.flash.A = 1.0
    state.lastPlaced = { chord = chord, via = "A" }
    self:strum(state, track, chord, 0.7)
    Looper:showToast(string.format("%s -> %s (%s)", before, Theory:chordName(chord), self:numeral(chord)))
end

-- Y: delete one chord event
function Chords:deleteAt(state, track, i, fresh)
    local list = self:edit(track, "DELETE", fresh)
    local ev = table.remove(list, i)
    state.flash.Y = 1.0
    Looper:showToast(string.format("DELETED %s (%s)", Theory:chordName(ev.chord), self:numeral(ev.chord)))
end

-- Is tick `t` in (a, b] going round the loop? (a short forward window)
local function inWindow(t, a, b, loop)
    local span = (b - a) % loop
    local d = (t - a) % loop
    return span < loop * 0.5 and d > 0 and d <= span
end

-- X: replace this track's chords with the progression, over the whole loop
function Chords:stamp(state, track)
    local p = self:progressionOf(state)
    local loop = Looper:getLoopTicks()
    local len = self:stampLength(state, #p.dirs)

    Looper:silenceTrack(track.slot)
    Looper:pushUndo({ kind = "events", trackSlot = track.slot, events = track.events, label = "STAMP" })
    Looper:beginRecordingTake()
    local events, i = {}, 0
    while i * len < loop - 0.5 do
        local chord = self:chordFor(state, p.dirs[(i % #p.dirs) + 1])
        events[#events + 1] = { tick = math_floor(i * len + 0.5), len = 0, action = "B", via = "X",
                                chord = self:chordData(chord), vel = 0.75, takeId = Looper.currentTakeId }
        i = i + 1
    end
    track.events = events
    state.spice, state.spiceTick = {}, nil
    state.flash.X = 1.0
    local fits = (i % #p.dirs == 0) and "" or string.format(" (%d OF %d FIT)", math.min(i, #p.dirs), #p.dirs)
    Looper:showToast(string.format("STAMPED %s: %d CHORDS%s - UNDO BRINGS BACK THE OLD", p.name, i, fits))
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
    local stepTicks = Looper:getLoopTicks() / total
    return math_floor(Looper.tick / stepTicks + 0.5) % total
end

function Chords:write(state, lines, emit)
    local chord = state.currentChord or self:chordFor(state, "NEUTRAL")
    state.lastLine = lines and nearestLine(lines * Looper.bars) or nil
    emit({
        action = "B",
        via = "B",
        chord = self:chordData(chord),
        vel = 0.75,
        overrideGridSteps = lines and lines * Looper.bars or nil,
    })
end

function Chords:updateInput(dt, state, track, emit)
    local lines, label = self:getSnap()
    state.snapLabel = label
    local loop = Looper:getLoopTicks()

    -- A: colour. The D-pad is the colour wheel while A is held.
    if Input.down.A then
        local dir = Input:get8WayDirection()
        if Input.pressed.A then
            self:applyColour(state, track, self.COLOUR_WHEEL[dir], true)
            state.colourDir = dir
        elseif dir ~= "NEUTRAL" and dir ~= state.colourDir then
            self:applyColour(state, track, self.COLOUR_WHEEL[dir], false)
            state.colourDir = dir
        end
    else
        state.colourDir = nil
        if Input.pressed.B then self:write(state, lines, emit) end
    end

    -- Y: delete the chord under the playhead, then each one reached while held
    if Input.pressed.Y then
        local _, i = self:chordUnder(track)
        if i then self:deleteAt(state, track, i, true) else Looper:showToast("NO CHORD TO DELETE") end
        state.deleting = true
    elseif Input.down.Y and state.deleting and Looper.playing then
        local a = Looper.prevTick + self.LOOKAHEAD
        local b = Looper.tick + self.LOOKAHEAD
        for i = #track.events, 1, -1 do
            local ev = track.events[i]
            if ev.chord and not ev.open and inWindow(ev.tick, a, b, loop) then
                self:deleteAt(state, track, i, false)
            end
        end
    elseif not Input.down.Y then
        state.deleting = nil
    end

    if Input.pressed.X then self:stamp(state, track) end

    -- Held B with a shoulder: write again on every new line
    if lines and Looper.playing and Input.down.B and not Input.pressed.B and not Input.down.A then
        local total = lines * Looper.bars
        local u, uPrev = Looper.phase * total, Looper.prevPhase * total
        if math_floor(u) ~= math_floor(uPrev) then
            if math_floor(u) % total ~= state.lastLine then self:write(state, lines, emit) end
            state.lastLine = nil
        end
    end
end

-- ---------------------------------------------------------------------------
-- SPICE: each pass of the loop, some plain chords get a colour. Harmony reads
-- state.spice, so followers play the coloured chord too. Never recorded.
-- ---------------------------------------------------------------------------
function Chords.random()
    return love.math.random()
end

function Chords:spiceOptions(chord, level)
    local minor = (chord.third == 3)
    local opts
    if minor then
        opts = { "7TH", "ADD9" }
        if level == "WILD" then opts[#opts + 1] = "9TH" end
    else
        opts = { "7TH", "ADD9", "SUS4" }
        if level == "WILD" then
            opts[#opts + 1] = "9TH"
            opts[#opts + 1] = "6TH"
            opts[#opts + 1] = "SUS2"
            if chord.roman == "V" then opts[#opts + 1] = "AUG" end
        end
    end
    return opts
end

function Chords:rollSpice(state, track)
    state.spice = {}
    local chance = self.SPICE_CHANCE[state.spiceLevel]
    if not chance then return end
    for _, ev in ipairs(track.events) do
        local c = ev.chord
        if c and not ev.open and (c.colour or "TRIAD") == "TRIAD" and self.random() < chance then
            local opts = self:spiceOptions(c, state.spiceLevel)
            local pick = opts[math.min(#opts, math_floor(self.random() * #opts) + 1)]
            state.spice[ev] = self:recolour(c, pick)
        end
    end
end

-- A new pass (the playhead wrapped) or new chords: roll again
function Chords:checkPass(state, track)
    if state.spiceLevel == "OFF" then
        if next(state.spice) then state.spice = {} end
        state.spiceTick = nil
        return
    end
    local tick = Looper.tick
    if state.spiceTick == nil or tick < state.spiceTick - 1 or state.spiceEvents ~= track.events then
        self:rollSpice(state, track)
        state.spiceEvents = track.events
    end
    state.spiceTick = tick
end

function Chords:updateVoices(dt, state, track)
    self:checkPass(state, track)
end

-- ---------------------------------------------------------------------------
-- Sound
-- ---------------------------------------------------------------------------
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
    local chord = ev.chord
    if isPlayback then
        self:checkPass(state, track)
        chord = state.spice[ev] or chord
    else
        state.liveChord = chord
    end
    state.lastPlaced = { chord = chord, via = ev.via }
    state.flash[ev.via or "B"] = 1.0
    self:strum(state, track, chord, ev.vel or 0.75)
end

-- ---------------------------------------------------------------------------
-- Readout (the plain lab view): numerals here, chord names on the tape deck
-- ---------------------------------------------------------------------------
-- This track's chords as numerals, bar by bar: "I V | vi IV"
function Chords:barLine(track)
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
        local chord = track.state.spice and track.state.spice[ev] or ev.chord
        if bars[b] then table.insert(bars[b], self:numeral(chord)) end
    end
    local out = {}
    for b = 1, Looper.bars do out[b] = (#bars[b] > 0) and table.concat(bars[b], " ") or "-" end
    return table.concat(out, " | ")
end

-- Is this track the one setting the chords? (lazy: harmony requires looper)
local function sourceLine(track)
    local Harmony = require("src.harmony")
    local src = Harmony:source()
    if not src then return "NO CHORDS RECORDED - OTHERS FOLLOW LIVE" end
    if track and src == track then return "THIS TRACK SETS THE CHORDS" end
    return string.format("CHORDS COME FROM TRACK %d (%s)", src.slot, src.shortName or "")
end

function Chords:getReadout(state)
    local track = trackOf(state)
    local p = self:progressionOf(state)
    local guide = self:guideIndex(state)
    local nums = {}
    for i, r in ipairs(p.romans) do nums[i] = (i == guide) and ("[" .. r .. "]") or r end

    local big, small
    if Input.down.A then
        local colour = self.COLOUR_WHEEL[Input:get8WayDirection()]
        local ev = self:chordUnder(track)
        big = ev and Theory:chordName(self:recolour(ev.chord, colour) or ev.chord) or colour
        small = "COLOUR: " .. colour .. (ev and "" or " FOR NEW CHORDS")
    else
        local chord = state.currentChord or self:chordFor(state, "NEUTRAL")
        big = chord.name
        small = self:numeral(chord) .. "  -  " .. (state.snapLabel and ("SNAP " .. state.snapLabel) or "ON THE BEAT")
            .. (Input:isRecording() and "  -  REC" or "")
    end

    return big, small, {
        p.name .. ":   " .. table.concat(nums, "  "),
        "LOOP:   " .. self:barLine(track),
        sourceLine(track) .. ((state.spiceLevel ~= "OFF") and ("  - SPICE " .. state.spiceLevel) or ""),
        "",
        "B WRITE    Y DELETE    X STAMP",
        "HOLD A + D-PAD: COLOUR (7, 9, AUG, DIM...)",
        "L1 BAR    R1 HALF BAR    BOTH BEAT",
    }
end

-- ---------------------------------------------------------------------------
-- Save / load
-- ---------------------------------------------------------------------------
function Chords:saveState(state)
    return { patch = state.patch, colour = state.colour, spice = state.spiceLevel,
             progression = self:progressionOf(state).name, length = self.LENGTHS[state.length].label }
end

function Chords:loadState(state, data)
    if type(data) ~= "table" then return end
    Patches.load(self, state, data.patch)
    for _, c in ipairs(Theory.COLOURS) do
        if data.colour == c then state.colour = c end
    end
    for _, s in ipairs(self.SPICES) do
        if data.spice == s then state.spiceLevel = s end
    end
    for i, p in ipairs(self.PROGRESSIONS) do
        if data.progression == p.name then state.progression = i end
    end
    for i, l in ipairs(self.LENGTHS) do
        if data.length == l.label then state.length = i end
    end
end

return Chords
