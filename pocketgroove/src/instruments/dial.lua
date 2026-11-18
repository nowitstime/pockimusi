-- ============================================================================
-- src/instruments/dial.lua — DIAL: roll the thumb round the scale
-- (lab/DIAL.md, lab wave 1)
--
-- The four face buttons and the four neighbouring pairs are eight positions
-- round the diamond, clockwise from B:
--   B 1 · B+A 2 · A 3 · A+X 4 · X 5 · X+Y 6 · Y 7 · Y+B 8
-- The right thumb chooses and triggers: a note sounds while any face button
-- is down. Rolling to another position slurs the same note to the new
-- pitch (a recorded bend); lifting and pressing elsewhere is a new note.
-- Rolling clockwise from Y+B (8) to B carries the octave up (8 and the next
-- octave's 1 are the same pitch); anticlockwise from B to Y+B carries it down.
-- All four = home octave, degree 1. Three buttons or an opposite pair change
-- nothing. A change within Input.FINGER_SETTLE of a fresh press is a
-- correction (a pair arriving a frame apart), not a slur.
--   D-pad UP accent + vibrato · DOWN soft (at the note's start)
--   D-pad LEFT / RIGHT flat / sharp by a semitone (while held)
--   L1 / R1 set the octave to -1 / +1 outright
-- FOLLOW row (off by default): the positions are degrees over the current
-- chord, as on the Bass (1 root, 3 third, 5 fifth, 7 seventh, 8 octave; 2, 4,
-- 6 walk the scale from the chord root). Read when a note starts; a roll
-- stays over that chord. Recorded notes re-fit when the chords change.
-- Built on the Bass for the voice, bends, playback and the stage view.
-- ============================================================================

local Theory  = require("src.theory")
local Input   = require("src.input")
local Harmony = require("src.harmony")
local Looper  = require("src.looper")
local Bass    = require("src.instruments.bass")
local Patches = require("src.instruments.patches")

local Dial = setmetatable({
    id = "dial",
    name = "DIAL",
    shortName = "DIAL",
    title = "DIAL",
    viewKind = "bass",
    PANEL = "dial",            -- the Bass view with the dial in place of the oscilloscope
    eventClass = "dial",       -- its notes carry accidentals Bass/Lead would re-pitch
    defaultGridIndex = 3,      -- 1/16

    HOME_GROUP = "LEAD",
    DEFAULT_PATCH = "lead_square",
    REGISTER = 4,              -- 0 semitones = C4
    VOICES = 4,

    -- Track page GLIDE row: slur speed (fraction of the distance per second)
    GLIDES = { "INSTANT", "FAST", "SLOW" },
    GLIDE_RATES = { INSTANT = 1000.0, FAST = 40.0, SLOW = 8.0 },

    -- Fingering -> position round the diamond (clockwise from B) = degree
    POSITIONS = { B = 1, BA = 2, A = 3, AX = 4, X = 5, XY = 6, Y = 7, YB = 8 },
    -- The button a note started on, per position: the button itself, or the
    -- clockwise-first button of a pair
    POSITION_ACTION = { "B", "B", "A", "A", "X", "X", "Y", "Y" },
    OCTAVE_MIN = -2,
    OCTAVE_MAX = 2,            -- degree 8 there is +36: the top of the voices' range

    VEL_NORMAL = 0.85,
    VEL_ACCENT = 1.0,
    VEL_SOFT   = 0.5,

    VIEW = {
        dpad = { UP = "ACCENT", DOWN = "SOFT", LEFT = "FLAT", RIGHT = "SHARP", NEUTRAL = "" },
        face = { B = "1", A = "3", X = "5", Y = "7" },
        l1 = "OCT -1", r1 = "OCT +1",
    },

    -- Erase page: a face button clears the notes started on it or its clockwise pair
    ERASE = {
        B = { actions = { "B" }, label = "1 + 2" },
        A = { actions = { "A" }, label = "3 + 4" },
        X = { actions = { "X" }, label = "5 + 6" },
        Y = { actions = { "Y" }, label = "7 + 8" },
    },
}, { __index = Bass })

function Dial:newState()
    local state = Bass.newState(self)
    state.patch = self.DEFAULT_PATCH
    state.glide = "INSTANT"
    state.follow = false           -- FOLLOW row: off = scale degrees, on = over the chord
    state.chord = nil              -- the chord the sounding note follows
    state.lastArticulation = "PLAIN"
    state.octave = 0               -- the carried octave
    state.pos = nil                -- the sounding note's position (nil: home / none)
    state.acc = 0                  -- -1 flat, +1 sharp (D-pad LEFT / RIGHT)
    state.h = nil                  -- the sounding note's handle
    state.age = 0.0                -- seconds since the note started (settle window)
    state.cur = nil                -- { degree, octave, semis } the note is at now
    state.waitLift = false         -- a page took the note: wait for the thumb to lift
    return state
end

-- ---------------------------------------------------------------------------
-- Track page rows: PATCH (sound), GLIDE and FOLLOW (settings)
-- ---------------------------------------------------------------------------
local function indexOf(list, value)
    for i, v in ipairs(list) do
        if v == value then return i end
    end
    return 1
end

local function itemsOf(list)
    local items = {}
    for i, v in ipairs(list) do items[i] = { label = v } end
    return items
end

function Dial:getGlideRate(state)
    return self.GLIDE_RATES[state.glide] or self.GLIDE_RATES.INSTANT
end

function Dial:getSoundRows(state)
    return {
        Patches.row(self, state),
        { key = "GLIDE", label = "GLIDE", value = state.glide, kind = "setting",
          items = itemsOf(self.GLIDES), index = indexOf(self.GLIDES, state.glide) },
        { key = "FOLLOW", label = "FOLLOW", value = state.follow and "ON" or "OFF", kind = "setting",
          items = itemsOf({ "OFF", "ON" }), index = state.follow and 2 or 1 },
    }
end

function Dial:cycleSetting(state, key, delta)
    if key == "FOLLOW" then
        state.follow = not state.follow
        Looper:showToast("DIAL FOLLOWS CHORDS: " .. (state.follow and "ON" or "OFF"))
        return
    end
    if key ~= "GLIDE" then return end
    local n = #self.GLIDES
    state.glide = self.GLIDES[((indexOf(self.GLIDES, state.glide) - 1 + delta) % n) + 1]
    Looper:showToast("DIAL GLIDE: " .. state.glide)
end

-- ---------------------------------------------------------------------------
-- Pitch
-- ---------------------------------------------------------------------------
function Dial:clampOctave(o)
    return math.max(self.OCTAVE_MIN, math.min(self.OCTAVE_MAX, o))
end

-- Degree 1..8 in an octave, plus a semitone accidental: a scale degree, or
-- over `chord` when following (the Bass's rule)
function Dial:semisFor(degree, octave, acc, chord)
    if chord then
        return Theory:getChordDegreeSemis(chord, degree) + octave * 12 + (acc or 0)
    end
    return Theory:getScaleDegreeSemis(degree) + octave * 12 + (acc or 0)
end

-- Does a roll from position a to b cross the seam between 8 and 1? By the
-- shortest way round: +1 clockwise, -1 anticlockwise, 0 not (or opposite).
function Dial:seamCrossing(a, b)
    local d = (b - a) % 8
    if d >= 1 and d <= 3 and b < a then return 1 end
    if d >= 5 and d <= 7 and b > a then return -1 end
    return 0
end

-- ---------------------------------------------------------------------------
-- Live input
-- ---------------------------------------------------------------------------
function Dial:updateInput(dt, state, track, play, hold)
    local f = Input:getFingering()
    local id = f.id

    -- A page or a track change ended the note: start again from a lifted thumb
    if state.h and not state.h:isHeld() then
        state.h = nil
        state.waitLift = true
    end
    if id == "NONE" then state.waitLift = false end

    -- Left thumb: flat / sharp while held; shoulders set the octave outright
    state.acc = (Input.down.LEFT and -1 or 0) + (Input.down.RIGHT and 1 or 0)
    local shoulder = false
    if Input.pressed.L1 then state.octave, shoulder = -1, true end
    if Input.pressed.R1 then state.octave, shoulder = 1, true end

    if state.h then state.age = state.age + dt end
    state.trailAge = (state.trailAge or 0) + dt

    -- Lift: the note ends
    if id == "NONE" then
        if state.h then
            state.h:release()
            state.h = nil
        end
        state.pos = nil
        return
    end
    if state.waitLift then return end

    -- Where the thumb is: a position, home (all four), or nothing new
    local pos, degree
    if id == "ALL" then
        state.octave = 0
        pos, degree = nil, 1
    elseif self.POSITIONS[id] then
        pos = self.POSITIONS[id]
        degree = pos
    elseif not state.h then
        return                       -- OTHER with no note: nothing to start
    else
        pos, degree = state.pos, state.cur.degree   -- OTHER: the note stays put
    end

    if not state.h then
        -- A fresh press: a new note in the current octave
        local octave = state.octave
        state.chord = state.follow and Harmony:chordAt(Looper.tick) or nil
        local semis = self:semisFor(degree, octave, state.acc, state.chord)
        local vel, accent = self.VEL_NORMAL, nil
        if Input.down.UP then
            vel, accent = self.VEL_ACCENT, true
            state.lastArticulation = "ACCENT"
        elseif Input.down.DOWN then
            vel = self.VEL_SOFT
            state.lastArticulation = "SOFT"
        else
            state.lastArticulation = "PLAIN"
        end
        local ev = { action = self.POSITION_ACTION[pos or 1], degree = degree, octave = octave,
                     semis = semis, vel = vel, accent = accent, acc = (state.acc ~= 0) and state.acc or nil }
        state.voices = {}            -- mono: the old note (released) is no longer followed
        local h = hold(ev, { manual = true })
        state.h, state.pos, state.age = h, pos, 0.0
        state.trailFrom = nil
        state.cur = { degree = degree, octave = octave, semis = semis }
        state.handles = { h }
        state.activeDegree = degree
        return
    end

    -- The note sounds: where should it be now?
    local fresh = state.age < Input.FINGER_SETTLE - 1e-6
    local octave = state.octave
    if id ~= "ALL" and pos ~= state.pos and not shoulder then
        -- octave carry across the seam (not for a correction of the first press)
        if pos and state.pos and not fresh then
            local cross = self:seamCrossing(state.pos, pos)
            if cross ~= 0 then
                local o = self:clampOctave(octave + cross)
                -- at the edge of the range the carry stops (the roll wraps)
                octave = o
                state.octave = o
            end
        end
    end
    if pos and state.pos and pos ~= state.pos then
        state.trailFrom, state.trailAge = state.pos, 0.0     -- the roll, for the stage
    end
    state.pos = pos
    local semis = self:semisFor(degree, octave, state.acc, state.chord)
    if degree == state.cur.degree and octave == state.cur.octave and semis == state.cur.semis then
        return
    end
    state.cur = { degree = degree, octave = octave, semis = semis }
    state.activeDegree = degree

    if fresh then
        self:correct(state, degree, octave, semis)
    else
        state.h:bend({ degree = degree, octave = octave, semis = semis, acc = state.acc })
    end
end

-- Inside the settle window: the note is re-pitched where it starts, live
-- and in the recording, with no slur
function Dial:correct(state, degree, octave, semis)
    local h = state.h
    local action = self.POSITION_ACTION[state.pos or 1]
    for _, ev in ipairs({ h.ev, h.rec }) do
        if ev then
            ev.degree, ev.octave, ev.semis, ev.action = degree, octave, semis, action
            ev.acc = (state.acc ~= 0) and state.acc or nil
        end
    end
    local v = state.voices[h.ev]
    if v and v.setPitch then
        v:setPitch(semis)
        v.currentSemis = semis
        if v.attack then v.attack.currentSemis = semis + v.shift end
    end
    self:showNote(state, semis)
end

-- Accent = vibrato (Bass ties vibrato to its X button)
function Dial:startVoice(ev, state, track, semis, glideFrom)
    semis = semis or ev.semis or 0
    return Patches.noteOn(self, state, semis, ev.vel or self.VEL_NORMAL, {
        track = track,
        glideFrom = glideFrom,
        glideRate = self:getGlideRate(state),
        vibrato = ev.accent == true,
    })
end

-- Stage panel (Chrome:drawPanel_dial): where the thumb is, the roll just
-- made, and the 8 notes the dial walks now (over the chord when following)
Dial.TRAIL_TIME = 0.6          -- seconds the roll stays lit

function Dial:getPanel(state)
    local sounding = state.h ~= nil
    local chord = state.follow and ((sounding and state.chord) or (Harmony:current())) or nil
    local oct = (sounding and state.cur) and state.cur.octave or state.octave
    local notes = {}
    for d = 1, 8 do
        local semis = self:semisFor(d, oct, 0, chord)
        notes[d] = Theory.NOTE_NAMES[(math.floor(semis + 0.5) % 12) + 1]
    end
    local age = state.trailAge or 99
    return {
        pos = sounding and state.pos or nil,
        home = sounding and state.pos == nil,
        trailFrom = sounding and state.trailFrom or nil,
        trailAlpha = math.max(0, 1 - age / self.TRAIL_TIME),
        notes = notes,
        lit = sounding and state.cur and state.cur.degree or nil,
        octave = oct,
    }
end

-- Stage (Bass view): keep the note name, word the line under it
function Dial:getReadout(state)
    local cur = state.cur
    local deg = cur and cur.degree or 1
    local oct = cur and state.h and cur.octave or state.octave
    local acc = state.acc < 0 and "  -  FLAT" or (state.acc > 0 and "  -  SHARP" or "")
    local what = state.h and state.lastArticulation or "READY"
    return nil, string.format("DEG %d  -  OCT %s%d%s  -  %s", deg, oct > 0 and "+" or "", oct, acc, what)
end

-- Save / load: patch, glide and follow
function Dial:saveState(state)
    return { patch = state.patch, glide = state.glide, follow = state.follow }
end

function Dial:loadState(state, data)
    if type(data) ~= "table" then return end
    Patches.load(self, state, data.patch)
    for _, g in ipairs(self.GLIDES) do
        if data.glide == g then state.glide = g end
    end
    if type(data.follow) == "boolean" then state.follow = data.follow end
end

return Dial
