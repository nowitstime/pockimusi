-- ============================================================================
-- src/instruments/pad.lua — Chord Pad (SPEC §7.4, plan: PHASE_E.md)
--
-- Each face button holds the current chord as a sustained voicing:
--   B full · A open (root, 5th, octave) · Y high · X swell (full, slow attack)
-- L1 / R1 = octave, read at the press. Buttons layer.
-- D-pad = tone: UP / DOWN brightness, LEFT / RIGHT movement. The values stay
-- where they are left; sweeps while holding are recorded as keyframes.
-- FOLLOW ON: a held or recorded chord moves with the chord track.
-- FOLLOW OFF: it stays as played / recorded.
-- ============================================================================

local Config  = require("src.config")
local Theory  = require("src.theory")
local Input   = require("src.input")
local Synth   = require("src.synth")
local Looper  = require("src.looper")
local Harmony = require("src.harmony")

local clamp     = Config.clamp
local math_abs  = math.abs
local math_max  = math.max
local math_sqrt = math.sqrt

local Pad = {
    id = "pad",
    name = "CHORD PAD",
    shortName = "PAD",
    title = "AURORA CHORD PAD",
    defaultGridIndex = 5, -- FREE

    SHAPES = {
        B = { shape = "FULL", label = "FULL" },
        A = { shape = "OPEN", label = "OPEN" },
        Y = { shape = "HIGH", label = "HIGH" },
        X = { shape = "FULL", label = "SWELL", swell = true },
    },

    -- Track page rows
    PATCHES = { "pad_warm", "pad_bell", "pad_choir", "pad_drone" },
    ATTACKS = { "FAST", "MEDIUM", "SLOW" },
    ATTACK_TIMES = { FAST = 0.03, MEDIUM = 0.25, SLOW = 0.9 },
    RELEASES = { "SHORT", "MEDIUM", "LONG" },
    RELEASE_TIMES = { SHORT = 0.25, MEDIUM = 0.9, LONG = 2.5 },

    SWELL_FACTOR = 3.0,       -- X: this many times the ATTACK row...
    SWELL_MIN = 1.2,          -- ...and at least this long (seconds)
    STRIKE_MAX_ATTACK = 0.1,  -- a patch's attack one-shot plays on attacks up to this
    CHORD_GLIDE = 14.0,       -- how fast notes move to a new chord (as the bass's glide rates)
    SWEEP_RATE = 0.65,        -- D-pad: brightness / movement change per second
    TONE_STEP = 0.04,         -- a recorded sweep gets a keyframe per this much change
    LEVEL = 0.9,              -- a chord's level, shared between its notes
}

function Pad:newState()
    return {
        patch = "pad_warm",        -- Track page PATCH row
        follow = true,             -- Track page FOLLOW row
        attack = "MEDIUM",         -- Track page ATTACK row
        release = "MEDIUM",        -- Track page RELEASE row
        bright = 0.35,             -- D-pad UP / DOWN
        move = 0.30,               -- D-pad LEFT / RIGHT

        live = {},                 -- [live ev] = note
        playing = {},              -- [recorded ev] = note
        tails = {},                -- released voices still fading (for the stage view)
        lastLabel = nil,           -- the last button's shape, for the stage view
        lastChord = nil,
        lastLive = nil,            -- the newest live note
    }
end

-- ---------------------------------------------------------------------------
-- Track page rows: PATCH (sound), FOLLOW, ATTACK, RELEASE (settings)
-- ---------------------------------------------------------------------------
local function indexOf(list, value)
    for i, v in ipairs(list) do
        if v == value then return i end
    end
    return 1
end

local function step(list, value, delta)
    return list[((indexOf(list, value) - 1 + delta) % #list) + 1]
end

function Pad:getPatch(state)
    return Synth.patches[state.patch] or Synth.patches[self.PATCHES[1]]
end

function Pad:getAttackTime(state, swell)
    local t = self.ATTACK_TIMES[state.attack] or self.ATTACK_TIMES.MEDIUM
    if swell then t = math_max(self.SWELL_MIN, t * self.SWELL_FACTOR) end
    return t
end

function Pad:getReleaseTime(state)
    return self.RELEASE_TIMES[state.release] or self.RELEASE_TIMES.MEDIUM
end

function Pad:getSoundRows(state)
    local patch = self:getPatch(state)
    return {
        { key = "PATCH", label = "PATCH", value = patch and patch.label or state.patch,
          hint = string.format("%d/%d", indexOf(self.PATCHES, state.patch), #self.PATCHES) },
        { key = "FOLLOW", label = "FOLLOW", value = state.follow and "ON" or "OFF", kind = "setting",
          hint = "CHORDS" },
        { key = "ATTACK", label = "ATTACK", value = state.attack, kind = "setting",
          hint = string.format("%d/%d", indexOf(self.ATTACKS, state.attack), #self.ATTACKS) },
        { key = "RELEASE", label = "RELEASE", value = state.release, kind = "setting",
          hint = string.format("%d/%d", indexOf(self.RELEASES, state.release), #self.RELEASES) },
    }
end

function Pad:cycleRowSound(state, rowIdx, delta)
    if rowIdx ~= 1 then return end
    state.patch = step(self.PATCHES, state.patch, delta)
    local patch = self:getPatch(state)
    if patch then
        -- preview: a short note on the key's root
        local root = Theory:getPadVoicing(Harmony:tonic(), "OPEN", 0)[1]
        local v = Synth:noteOn(state.patch, root, 0.6, { attack = 0.03, release = 0.5, bright = state.bright, move = state.move })
        if v then Synth:schedule(0.45, function() v:noteOff() end) end
        Looper:showToast("PAD PATCH: " .. patch.label)
    end
end

function Pad:cycleSetting(state, key, delta)
    if key == "FOLLOW" then
        state.follow = not state.follow
        Looper:showToast("PAD FOLLOWS CHORDS: " .. (state.follow and "ON" or "OFF"))
    elseif key == "ATTACK" then
        state.attack = step(self.ATTACKS, state.attack, delta)
        Looper:showToast("PAD ATTACK: " .. state.attack)
    elseif key == "RELEASE" then
        state.release = step(self.RELEASES, state.release, delta)
        Looper:showToast("PAD RELEASE: " .. state.release)
    end
end

-- Erase page: the button's shape instead of its letter
function Pad:getActionLabel(state, btn)
    local s = self.SHAPES[btn]
    return s and s.label or btn
end

-- ---------------------------------------------------------------------------
-- Live input
-- ---------------------------------------------------------------------------
function Pad:updateInput(dt, state, track, play, hold)
    -- D-pad: tone. The values stay where they are left.
    local sweep = dt * self.SWEEP_RATE
    if Input.down.UP then state.bright = clamp(state.bright + sweep, 0.0, 1.0)
    elseif Input.down.DOWN then state.bright = clamp(state.bright - sweep, 0.0, 1.0) end
    if Input.down.RIGHT then state.move = clamp(state.move + sweep, 0.0, 1.0)
    elseif Input.down.LEFT then state.move = clamp(state.move - sweep, 0.0, 1.0) end

    local octave = (Input.down.L1 and -1 or 0) + (Input.down.R1 and 1 or 0)

    for _, btn in ipairs({ "B", "A", "Y", "X" }) do
        if Input.pressed[btn] then
            -- The chord now (FOLLOW OFF too: it only stops chords from moving later)
            local chord = Harmony:chordAt(Looper.tick)
            local notes = Theory:getPadVoicing(chord, self.SHAPES[btn].shape, octave)
            local ev = { action = btn, octave = octave, notes = notes, semis = notes[1],
                         key = Theory:getRootSemis(), vel = 0.6,
                         bright = state.bright, move = state.move }
            state.pressChord = chord
            local h = hold(ev)
            state.pressChord = nil
            local note = state.live[ev]
            if note then note.handle = h end
        end
    end

    -- A sweep while holding is recorded on every held note
    for _, note in pairs(state.live) do
        local h = note.handle
        if h and h:isHeld() and (math_abs(state.bright - note.bright) >= self.TONE_STEP
                                 or math_abs(state.move - note.move) >= self.TONE_STEP) then
            note.bright, note.move = state.bright, state.move
            h:bend({ bright = state.bright, move = state.move })
        end
    end
end

-- ---------------------------------------------------------------------------
-- Sound
-- ---------------------------------------------------------------------------
local function unit(v, default)
    if type(v) ~= "number" or v ~= v then return default end
    return clamp(v, 0.0, 1.0)
end

-- The notes a recorded event plays when it isn't following: as recorded,
-- moved with the key. Checked, because events can come from a save file.
function Pad:storedNotes(ev)
    local shift = Theory:keyShift(ev.key)
    local out = {}
    if type(ev.notes) == "table" then
        for i = 1, 4 do
            local n = ev.notes[i]
            if type(n) == "number" and n == n then
                out[#out + 1] = clamp(n + shift, Theory.PAD_RANGE.low - 12, Theory.PAD_RANGE.high + 12)
            end
        end
    end
    if #out > 0 then return out end
    return nil
end

function Pad:voicingFor(ev, chord)
    local shape = self.SHAPES[ev.action] or self.SHAPES.B
    local octave = (type(ev.octave) == "number") and clamp(math.floor(ev.octave), -1, 1) or 0
    return Theory:getPadVoicing(chord, shape.shape, octave)
end

-- Start a chord: one voice per note
function Pad:startNote(ev, state, track, notes, chord, bright, move)
    local shape = self.SHAPES[ev.action] or self.SHAPES.B
    local attack = self:getAttackTime(state, shape.swell)
    local vel = clamp((ev.vel or 0.6) / 0.6, 0.0, 1.0) * self.LEVEL / math_sqrt(#notes)
    local note = { ev = ev, voices = {}, chord = chord, bright = bright, move = move }
    -- the chord sounding exactly now (the note's own chord may be one that
    -- starts a moment later): changes of this one move a following note
    note.exact = Harmony:chordAt(Looper.tick, 0)
    for i, semis in ipairs(notes) do
        local v = Synth:noteOn(state.patch, semis, vel, {
            track = track,
            attack = attack,
            release = self:getReleaseTime(state),
            bright = bright,
            move = move,
            glideRate = self.CHORD_GLIDE,
            noAttack = attack > self.STRIKE_MAX_ATTACK,
        })
        if v then note.voices[#note.voices + 1] = v end
    end
    state.lastLabel, state.lastChord = shape.label, chord
    return note
end

function Pad:noteOn(ev, state, track, isPlayback)
    if not isPlayback then
        local chord = state.pressChord or Harmony:chordAt(Looper.tick)
        local notes = self:storedNotes(ev) or self:voicingFor(ev, chord)
        local note = self:startNote(ev, state, track, notes, chord, state.bright, state.move)
        state.live[ev] = note
        state.lastLive = note
        return
    end

    local chord = Harmony:chordAt(ev.tick)
    local notes = (not state.follow) and self:storedNotes(ev) or self:voicingFor(ev, chord)
    local old = state.playing[ev]
    if old then self:releaseNote(old, state) end        -- shouldn't happen; never leave a note hanging
    local note = self:startNote(ev, state, track, notes, chord, unit(ev.bright, state.bright), unit(ev.move, state.move))
    note.elapsed, note.lastTick = 0.0, Looper.tick
    state.playing[ev] = note
end

function Pad:releaseNote(note, state)
    for _, v in ipairs(note.voices) do
        v:noteOff()
        state.tails[#state.tails + 1] = v
    end
end

function Pad:noteOff(ev, state, track, isPlayback)
    local set = isPlayback and state.playing or state.live
    local note = set[ev]
    if not note then return end
    set[ev] = nil
    self:releaseNote(note, state)
end

-- FOLLOW ON: when the chord at the playhead changes, the note's voices glide
-- to the same shape on the new chord
function Pad:followChord(note)
    local exact = Harmony:chordAt(Looper.tick, 0)
    if Theory:sameChord(exact, note.exact) then return end
    note.exact = exact
    if Theory:sameChord(exact, note.chord) then return end
    note.chord = exact
    local notes = self:voicingFor(note.ev, exact)
    for i, v in ipairs(note.voices) do
        if notes[i] then
            v.glideRate = self.CHORD_GLIDE
            v:setPitch(notes[i])
        end
    end
end

local function setTone(note)
    for _, v in ipairs(note.voices) do
        v.bright, v.move = note.bright, note.move
    end
end

-- The latest tone keyframe at `elapsed` ticks into a recorded note
local function toneAt(ev, elapsed)
    local bend, found = ev.bend, nil
    if type(bend) ~= "table" then return nil end
    for i = 1, #bend do
        local kf = bend[i]
        if kf.dt > elapsed then break end
        if kf.bright or kf.move then found = kf end
    end
    return found
end

-- Every frame, every track: tone and chord changes on sounding notes
function Pad:updateVoices(dt, state, track)
    -- Live notes: the D-pad's tone right now
    for _, note in pairs(state.live) do
        for _, v in ipairs(note.voices) do
            v.bright, v.move = state.bright, state.move
        end
        if state.follow then
            self:followChord(note)
            state.lastChord = note.chord
        end
    end

    -- Recorded notes: the tone stored on the event, then its keyframes
    local loop = Looper:getLoopTicks()
    for ev, note in pairs(state.playing) do
        local d = (Looper.tick - note.lastTick) % loop
        if d < loop * 0.5 then note.elapsed = note.elapsed + d end
        note.lastTick = Looper.tick
        local kf = toneAt(ev, note.elapsed)
        if kf then
            note.bright = unit(kf.bright, note.bright)
            note.move = unit(kf.move, note.move)
            setTone(note)
        end
        if state.follow then self:followChord(note) end
    end

    for i = #state.tails, 1, -1 do
        if not state.tails[i]:isSounding() then table.remove(state.tails, i) end
    end
end

-- ---------------------------------------------------------------------------
-- Stage view helpers
-- ---------------------------------------------------------------------------
-- Every sounding voice: { semis, level (0..1), bright, held }
function Pad:getSounding(state)
    local out = {}
    local function add(v, held)
        if v:isSounding() then
            out[#out + 1] = { semis = v.currentSemis, level = clamp(v:envelope() * v.vel * 3.0, 0.0, 1.0),
                              bright = v.brightNow, move = v.move, held = held }
        end
    end
    for _, v in ipairs(state.tails) do add(v, false) end
    for _, note in pairs(state.playing) do
        for _, v in ipairs(note.voices) do add(v, true) end
    end
    for _, note in pairs(state.live) do
        for _, v in ipairs(note.voices) do add(v, true) end
    end
    return out
end

-- The newest live note (the one the stage view names), or nil
function Pad:getLiveNote(state)
    local note = state.lastLive
    if note and state.live[note.ev] == note then return note end
    local _, any = next(state.live)
    return any
end

-- ---------------------------------------------------------------------------
-- Save / load (Phase C)
-- ---------------------------------------------------------------------------
function Pad:saveState(state)
    return { patch = state.patch, follow = state.follow, attack = state.attack, release = state.release,
             bright = state.bright, move = state.move }
end

function Pad:loadState(state, data)
    if type(data) ~= "table" then return end
    for _, p in ipairs(self.PATCHES) do
        if data.patch == p then state.patch = p end
    end
    for _, a in ipairs(self.ATTACKS) do
        if data.attack == a then state.attack = a end
    end
    for _, r in ipairs(self.RELEASES) do
        if data.release == r then state.release = r end
    end
    if type(data.follow) == "boolean" then state.follow = data.follow end
    state.bright = unit(data.bright, state.bright)
    state.move = unit(data.move, state.move)
end

return Pad
