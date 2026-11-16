-- ============================================================================
-- src/instruments/strum.lua — STRUM: set the notes with the thumbs, pluck
-- with the shoulders (lab/STRUM.md)
--
--   D-pad          degree, the Bass compass (neutral = root). Silent
--   B A Y X held   strings above the root: B 3rd, A 5th, Y 7th, X octave. Silent
--   R1             downstroke: the root and every held string, low to high
--   L1             upstroke: the same, high to low
--   L1 + R1        damp: everything ringing stops (the second shoulder
--                  landing within Input.FINGER_SETTLE of the first)
--
-- A patch that rings is plucked: a stroke is a hit, its strings ring over
-- each other. A patch that sustains is bowed: the stroke sounds while its
-- shoulder is held and the D-pad glides every string.
-- Strings are stored as scale steps above the root, so a recorded strum
-- re-harmonises with FOLLOW on.
-- ============================================================================

local Theory  = require("src.theory")
local Input   = require("src.input")
local Synth   = require("src.synth")
local Looper  = require("src.looper")
local Harmony = require("src.harmony")
local Patches = require("src.instruments.patches")
local Bass    = require("src.instruments.bass")

local math_floor = math.floor
local math_abs   = math.abs
local math_sqrt  = math.sqrt
local math_min   = math.min

local Strum = {
    id = "strum",
    name = "STRUM",
    shortName = "STRM",
    title = "STRUM",
    lab = true,
    viewKind = "lab",
    eventClass = "strum",
    defaultGridIndex = 3, -- 1/16

    -- Sound pool (src/instruments/patches.lua)
    HOME_GROUP = "PLUCK",
    DEFAULT_PATCH = "pluck_nylon",
    REGISTER = 4,             -- 0 semitones = C4
    VOICES = 10,

    COMPASS_DEGREE_MAP = Bass.COMPASS_DEGREE_MAP,

    -- Strings: scale steps above the D-pad's degree, in pitch order
    STRINGS = { B = 2, A = 4, Y = 6, X = 7 },
    STRING_BUTTONS = { "B", "A", "Y", "X" },
    STRING_NAMES = { [2] = "3RD", [4] = "5TH", [6] = "7TH", [7] = "8VE" },

    -- Track page rows
    REGISTERS = { "LOW", "MID", "HIGH" },
    REGISTER_OCTAVES = { LOW = -1, MID = 0, HIGH = 1 },
    STRUMS = { "TIGHT", "LOOSE" },
    STRUM_GAPS = { TIGHT = 0.012, LOOSE = 0.030 },   -- seconds between strings

    VEL = 0.85,               -- a stroke's level, shared between its strings
    GLIDE = 18.0,             -- bowed: how fast the strings follow the D-pad
    DAMP_RELEASE = 0.04,      -- seconds a damped voice takes to stop

    -- Lab contract (lab/L0_FOUNDATION.md)
    LANES = { R1 = 1, L1 = 2 },
    ERASE = {
        B = { actions = { "R1" }, label = "DOWNSTROKES" },
        A = { actions = { "L1" }, label = "UPSTROKES" },
    },
    VIEW = {
        dpad = { NEUTRAL = "1", DOWN = "L5", DOWN_LEFT = "2", LEFT = "3", UP_LEFT = "4",
                 UP = "5", UP_RIGHT = "6", RIGHT = "7", DOWN_RIGHT = "8" },
        face = { B = "3RD", A = "5TH", Y = "7TH", X = "8VE" },
        l1 = "UPSTROKE", r1 = "DOWNSTROKE", both = "DAMP",
    },
}

function Strum:newState()
    return {
        patch = self.DEFAULT_PATCH,    -- PATCH row
        register = "MID",              -- REGISTER row
        strum = "TIGHT",               -- STRUM row
        follow = true,                 -- FOLLOW row

        activeDegree = 1,              -- the D-pad's degree now
        heldStack = {},                -- the strings held now (steps)
        lastDir = nil,                 -- "R1" / "L1": the last stroke's direction
        damped = false,                -- the last thing played was a damp

        live = {},                     -- [live ev] = stroke
        playing = {},                  -- [recorded ev] = stroke
        ringing = {},                  -- [pitch] = voice: a string plucked again restarts
        handles = {},                  -- live bow handles
        last = nil,                    -- the newest stroke: { at, action, handle | rec }
    }
end

-- ---------------------------------------------------------------------------
-- Rows: PATCH (sound), REGISTER, STRUM, FOLLOW (settings)
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
local ON_OFF = { { label = "OFF" }, { label = "ON" } }

function Strum:getPatch(state)
    return Patches.get(self, state)
end

function Strum:getSoundRows(state)
    return {
        Patches.row(self, state),
        { key = "REGISTER", label = "REGISTER", value = state.register, kind = "setting",
          items = itemsOf(self.REGISTERS), index = indexOf(self.REGISTERS, state.register) },
        { key = "STRUM", label = "STRUM", value = state.strum, kind = "setting",
          items = itemsOf(self.STRUMS), index = indexOf(self.STRUMS, state.strum) },
        { key = "FOLLOW", label = "FOLLOW", value = state.follow and "ON" or "OFF", kind = "setting",
          items = ON_OFF, index = state.follow and 2 or 1 },
    }
end

function Strum:cycleRowSound(state, rowIdx, delta, quiet)
    if rowIdx ~= 1 then return end
    Patches.step(self, state, delta)
    if not quiet then self:previewRowSound(state, rowIdx) end
end

function Strum:previewRowSound(state, rowIdx)
    if rowIdx ~= 1 then return end
    Patches.preview(self, state, Theory:getRootSemis(), 0.8)
end

function Strum:cycleSetting(state, key, delta)
    if key == "FOLLOW" then
        state.follow = not state.follow
        Looper:showToast("STRUM FOLLOWS CHORDS: " .. (state.follow and "ON" or "OFF"))
    elseif key == "REGISTER" then
        state.register = self.REGISTERS[((indexOf(self.REGISTERS, state.register) - 1 + delta) % #self.REGISTERS) + 1]
        Looper:showToast("STRUM REGISTER: " .. state.register)
    elseif key == "STRUM" then
        state.strum = self.STRUMS[((indexOf(self.STRUMS, state.strum) - 1 + delta) % #self.STRUMS) + 1]
        Looper:showToast("STRUM SPREAD: " .. state.strum)
    end
end

-- ---------------------------------------------------------------------------
-- Pitches
-- ---------------------------------------------------------------------------

-- Any scale degree (beyond 8 too) as Bass plays it: over `chord` when
-- following (chord tones on 3, 5, 7), else in the key
function Strum:degreeSemis(state, degree, octave, chord)
    local o = math_floor((degree - 1) / 7)
    return Bass.pitchFor(self, state, degree - 7 * o, (octave or 0) + o, chord)
end

-- The strings of an event, checked (events can come from a save file):
-- whole steps 1..7, each once, low to high, at most four
function Strum:stackOf(ev)
    local out, seen = {}, {}
    if type(ev.stack) == "table" then
        for _, s in ipairs(ev.stack) do
            if type(s) == "number" and s == math_floor(s) and s >= 1 and s <= 7 and not seen[s] then
                seen[s] = true
                out[#out + 1] = s
            end
        end
    end
    table.sort(out)
    while #out > 4 do table.remove(out) end
    return out
end

-- A stroke's pitches, low to high, and its root. Over `chord` the root and
-- strings are worked out afresh; without one the root is the stored pitch and
-- the strings sit the key's scale steps above it.
function Strum:strokeNotes(state, ev, chord)
    local deg = (type(ev.degree) == "number") and ev.degree or 1
    local oct = (type(ev.octave) == "number") and ev.octave or 0
    local root, notes = nil, {}
    if chord then
        root = self:degreeSemis(state, deg, oct, chord)
    else
        root = (type(ev.semis) == "number") and ev.semis or self:degreeSemis(state, deg, oct, nil)
    end
    notes[1] = root
    local base = self:degreeSemis(state, deg, oct, nil)
    for _, step in ipairs(self:stackOf(ev)) do
        if chord then
            notes[#notes + 1] = self:degreeSemis(state, deg + step, oct, chord)
        else
            notes[#notes + 1] = root + self:degreeSemis(state, deg + step, oct, nil) - base
        end
    end
    table.sort(notes)
    return notes, root
end

-- ---------------------------------------------------------------------------
-- Live input
-- ---------------------------------------------------------------------------
local function physicallyHeld(h)
    return h:isHeld() and Input.down[h.ev.action]
end

-- The event Looper:recordEvent stored for a one-shot just played (the copy
-- shares the live event's stack table)
local function findRecorded(track, ev)
    for i = #track.events, 1, -1 do
        if track.events[i].stack == ev.stack then return track.events[i] end
    end
    return nil
end

local function removeRecorded(track, rec)
    if not rec then return end
    for i = #track.events, 1, -1 do
        if track.events[i] == rec then
            Looper:removeEventAt(track, i)
            return
        end
    end
end

-- Stop a voice quickly
local function dampVoice(v, time)
    if not v.alive then return end
    v.releaseTime = math_min(v.releaseTime or time, time)
    v:noteOff()
    if v.attack and v.attack.maxLife and v.attack.elapsed then
        v.attack.maxLife = math_min(v.attack.maxLife, v.attack.elapsed + time)
    end
end

-- Damp: every voice of this track stops (live and playback), strings still
-- to come are dropped, held bows end
function Strum:damp(state, track)
    for _, set in ipairs({ state.live, state.playing }) do
        for _, stroke in pairs(set) do
            stroke.cancelled = true
            for _, sv in ipairs(stroke.voices) do dampVoice(sv.voice, self.DAMP_RELEASE) end
        end
    end
    state.ringing = {}
    for i = #state.handles, 1, -1 do
        state.handles[i]:release()
    end
    state.handles = {}
    state.damped = true
end

-- The newest stroke is withdrawn: its recording goes
function Strum:withdraw(state, track)
    local last = state.last
    if not last then return end
    if last.handle then
        removeRecorded(track, last.handle.rec)
        last.handle.rec = nil
    else
        removeRecorded(track, last.rec)
    end
    state.last = nil
end

function Strum:updateInput(dt, state, track, play, hold)
    local deg = self.COMPASS_DEGREE_MAP[Input:get8WayDirection()] or 1
    state.activeDegree = deg
    local stack = {}
    for _, btn in ipairs(self.STRING_BUTTONS) do
        if Input.down[btn] then stack[#stack + 1] = self.STRINGS[btn] end
    end
    state.heldStack = stack
    local octave = self.REGISTER_OCTAVES[state.register] or 0

    -- Forget bows that have ended
    for i = #state.handles, 1, -1 do
        if not state.handles[i]:isHeld() then table.remove(state.handles, i) end
    end

    local now = Synth.clock
    local pR, pL = Input.pressed.R1, Input.pressed.L1
    local last = state.last
    local inWindow = last and (now - last.at) <= Input.FINGER_SETTLE + 1e-6

    if pR and pL then
        -- both at once: a damp, and whatever just started goes
        if inWindow then self:withdraw(state, track) end
        self:damp(state, track)
        state.last = nil
    elseif pR or pL then
        local action = pR and "R1" or "L1"
        if inWindow and last.action ~= action then
            self:withdraw(state, track)
            self:damp(state, track)
        else
            self:stroke(state, track, play, hold, action, deg, octave, stack, now)
        end
    end

    -- Bowed: the D-pad glides the held stroke's strings (recorded as bends)
    local h = state.handles[#state.handles]
    if h and physicallyHeld(h) then
        local tSemis = self:degreeSemis(state, deg, h.ev.octave, h.chord)
        if tSemis ~= h.bentSemis then
            h.bentSemis = tSemis
            h:bend({ degree = deg, octave = h.ev.octave, semis = tSemis })
        end
    end
end

-- One stroke from a shoulder
function Strum:stroke(state, track, play, hold, action, deg, octave, stack, now)
    local chord = state.follow and Harmony:chordAt(Looper.tick) or nil
    local gap = self.STRUM_GAPS[state.strum] or self.STRUM_GAPS.TIGHT
    local strings = {}
    for i, s in ipairs(stack) do strings[i] = s end
    local ev = { action = action, degree = deg, octave = octave,
                 semis = self:degreeSemis(state, deg, octave, chord),
                 stack = strings, strum = (action == "R1") and gap or -gap, vel = self.VEL }

    state.pressChord = chord
    local patch = self:getPatch(state)
    if patch and patch.sustains then
        -- bowed: the other shoulder's bow ends, a new bow stroke starts
        for i = #state.handles, 1, -1 do state.handles[i]:release() end
        state.handles = {}
        local h = hold(ev)
        h.chord, h.bentSemis = chord, ev.semis
        state.handles[#state.handles + 1] = h
        state.last = { at = now, action = action, handle = h }
    else
        play(ev)
        state.last = { at = now, action = action,
                       rec = Input:isRecording() and findRecorded(track, ev) or nil }
    end
    state.pressChord = nil
    state.lastDir, state.damped = action, false
end

-- ---------------------------------------------------------------------------
-- Sound
-- ---------------------------------------------------------------------------

-- Start a stroke: the first string at once, the rest `gap` apart, in the
-- stroke's direction. The level is shared between the strings.
function Strum:startStroke(ev, state, track, notes, root)
    local patch = self:getPatch(state)
    local rings = not (patch and patch.sustains)
    local n = #notes
    local vel = ((type(ev.vel) == "number") and ev.vel or self.VEL) / math_sqrt(n)
    local strum = (type(ev.strum) == "number") and ev.strum or 0
    local gap, up = math_min(math_abs(strum), 0.25), strum < 0
    local stroke = { ev = ev, notes = notes, root = root, shift = 0, voices = {}, pending = n, rings = rings }

    for i = 1, n do
        local idx = up and (n - i + 1) or i
        local function go()
            stroke.pending = stroke.pending - 1
            if stroke.cancelled or (stroke.released and not rings) then return end
            local semis = notes[idx] + stroke.shift
            if rings then
                local old = state.ringing[semis]
                if old then dampVoice(old, self.DAMP_RELEASE) end
            end
            local v = Patches.noteOn(self, state, semis, vel, { track = track, glideRate = self.GLIDE })
            if v then
                stroke.voices[#stroke.voices + 1] = { voice = v, idx = idx }
                if rings then state.ringing[semis] = v end
            end
        end
        if i == 1 or gap <= 0 then go() else Synth:schedule((i - 1) * gap, go) end
    end
    return stroke
end

function Strum:noteOn(ev, state, track, isPlayback)
    local chord
    if isPlayback then
        if state.follow and type(ev.degree) == "number" then chord = Harmony:chordAt(ev.tick) end
    else
        chord = state.pressChord
    end
    local notes, root = self:strokeNotes(state, ev, chord)
    local stroke = self:startStroke(ev, state, track, notes, root)
    stroke.chord = chord
    if isPlayback then
        stroke.elapsed, stroke.lastTick = 0.0, Looper.tick
        state.playing[ev] = stroke
    else
        state.live[ev] = stroke
    end
    state.lastNotes = notes
end

function Strum:noteOff(ev, state, track, isPlayback)
    local stroke = (isPlayback and state.playing or state.live)[ev]
    if not stroke then return end
    stroke.released = true
    for _, sv in ipairs(stroke.voices) do sv.voice:noteOff() end
end

-- Move a stroke's strings by the same interval
function Strum:shiftStroke(stroke, shift)
    stroke.shift = shift
    for _, sv in ipairs(stroke.voices) do
        sv.voice.glideRate = self.GLIDE
        sv.voice:setPitch(stroke.notes[sv.idx] + shift)
    end
end

-- Live bend from a bow handle
function Strum:bendTo(ev, fields, state, track)
    local stroke = state.live[ev]
    if stroke and type(fields.semis) == "number" then
        self:shiftStroke(stroke, fields.semis - stroke.root)
    end
end

local function bendAt(ev, elapsed)
    local bend, found = ev.bend, nil
    if type(bend) ~= "table" then return nil end
    for i = 1, #bend do
        if bend[i].dt <= elapsed then found = bend[i] else break end
    end
    return found
end

local function silent(stroke)
    if stroke.pending > 0 and not stroke.cancelled then return false end
    for _, sv in ipairs(stroke.voices) do
        if sv.voice:isSounding() then return false end
    end
    return true
end

-- Every frame: recorded bends on playback; strokes that have gone quiet go
function Strum:updateVoices(dt, state, track)
    local loop = Looper:getLoopTicks()
    for ev, stroke in pairs(state.playing) do
        if silent(stroke) then
            state.playing[ev] = nil
        elseif ev.bend and not stroke.rings then
            local d = (Looper.tick - stroke.lastTick) % loop
            if d < loop * 0.5 then stroke.elapsed = stroke.elapsed + d end
            stroke.lastTick = Looper.tick
            local kf = bendAt(ev, stroke.elapsed)
            local target = stroke.root
            if kf then
                if stroke.chord and type(kf.degree) == "number" then
                    target = self:degreeSemis(state, kf.degree, kf.octave, stroke.chord)
                elseif type(kf.semis) == "number" then
                    target = kf.semis
                end
            end
            if target - stroke.root ~= stroke.shift then self:shiftStroke(stroke, target - stroke.root) end
        end
    end
    for ev, stroke in pairs(state.live) do
        if silent(stroke) then state.live[ev] = nil end
    end
    for semis, v in pairs(state.ringing) do
        if not v:isSounding() then state.ringing[semis] = nil end
    end
end

-- A page took the controls: no stroke to withdraw any more
function Strum:updateVisuals(dt, state, controlsBlocked)
    if controlsBlocked then state.last = nil end
end

-- ---------------------------------------------------------------------------
-- Stage view (lab view)
-- ---------------------------------------------------------------------------
function Strum:stackLabel(stack)
    local names = {}
    for _, s in ipairs(stack) do names[#names + 1] = self.STRING_NAMES[s] or tostring(s) end
    return table.concat(names, "  ")
end

-- Large: the degree and the strings held ("3  +  5TH  8VE").
-- Small: the last stroke's direction.
function Strum:getReadout(state)
    local big = Bass:degreeLabel(state.activeDegree or 1)
    local stack = state.heldStack or {}
    if #stack > 0 then big = big .. "  +  " .. self:stackLabel(stack) end

    local small
    if state.damped then
        small = "DAMPED"
    elseif state.lastDir == "R1" then
        small = "DOWNSTROKE"
    elseif state.lastDir == "L1" then
        small = "UPSTROKE"
    else
        small = "R1 DOWN  -  L1 UP  -  BOTH DAMP"
    end

    local patch = self:getPatch(state)
    local lines = {
        string.format("%s  -  %s  -  FOLLOW %s", state.register, state.strum, state.follow and "ON" or "OFF"),
        (patch and patch.sustains) and "BOWED: HOLD THE SHOULDER, D-PAD GLIDES" or "PLUCKED: STRINGS RING",
    }
    if state.lastNotes then
        local names = {}
        for _, s in ipairs(state.lastNotes) do
            names[#names + 1] = Theory.NOTE_NAMES[(math_floor(s + 0.5) % 12) + 1]
        end
        lines[#lines + 1] = "LAST: " .. table.concat(names, " ")
    end
    return big, small, lines
end

-- ---------------------------------------------------------------------------
-- Save / load
-- ---------------------------------------------------------------------------
function Strum:saveState(state)
    return { patch = state.patch, register = state.register, strum = state.strum, follow = state.follow }
end

function Strum:loadState(state, data)
    if type(data) ~= "table" then return end
    Patches.load(self, state, data.patch)
    for _, r in ipairs(self.REGISTERS) do
        if data.register == r then state.register = r end
    end
    for _, s in ipairs(self.STRUMS) do
        if data.strum == s then state.strum = s end
    end
    if type(data.follow) == "boolean" then state.follow = data.follow end
end

return Strum
