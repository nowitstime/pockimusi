-- ============================================================================
-- src/instruments/harp.lua — "Pocket Omnichord" Strum Harp Instrument Module
--
-- The harp's chords are its own: they never steer the other tracks (track C
-- sets the song's chords, src/harmony.lua).
-- FOLLOW row (off by default): the harp stops choosing chords and plays
-- track C's chord. The strings are that chord's root, 3rd, 5th and top note;
-- L1 / R1 still move them an octave. What it records then is strings, and
-- played back each string sounds over the chord at its tick.
-- ============================================================================

local Theory = require("src.theory")
local Input  = require("src.input")
local Synth  = require("src.synth")
local Looper = require("src.looper")
local Patches = require("src.instruments.patches")
local Harmony = require("src.harmony")

local math_max   = math.max

local Harp = {
    id = "harp",
    group = "CHORDS",
    name = "CHORD HARP",
    shortName = "HARP",
    defaultGridIndex = 5, -- FREE
    -- Track page PATCH row: the sound pool (src/instruments/patches.lua)
    HOME_GROUP = "PLUCK",
    DEFAULT_PATCH = "harp",
    REGISTER = 4,              -- 0 semitones = C4
    VOICES = 8,
    ALLOW_SILENT = true,       -- a chord track that isn't heard
    -- A press has no length. Patches that ring are left to ring; a patch that
    -- sustains is held for this long, then released.
    GATE = 0.35,
    RING = 1.6,
    BUTTON_TO_INDEX = { B = 1, A = 2, Y = 3, X = 4 },
}

function Harp:newState()
    return {
        currentChord = nil,
        patch = "harp",            -- Track page PATCH row
        colour = "TRIAD",          -- Track page COLOUR row (Theory.COLOURS)
        follow = false,            -- Track page FOLLOW row: play track C's chords
        strings = {
            { button = "B", label = "STR 1 (ROOT)", energy = 0.0, phase = 0.0, lastSemis = 0 },
            { button = "A", label = "STR 2 (3RD)",  energy = 0.0, phase = 0.0, lastSemis = 4 },
            { button = "Y", label = "STR 3 (7TH)",  energy = 0.0, phase = 0.0, lastSemis = 7 },
            { button = "X", label = "STR 4 (9TH)",  energy = 0.0, phase = 0.0, lastSemis = 12 },
        },
    }
end

function Harp:updateVisuals(dt, state, controlsBlocked, isActive)
    for i = 1, 4 do
        local s = state.strings[i]
        if s.energy > 0 then
            s.energy = math_max(0.0, s.energy - dt * 1.65)
            s.phase = s.phase + dt * (42.0 + i * 9.0)
        end
    end

    if state.follow then
        local l1 = isActive and not controlsBlocked and Input.down.L1
        local r1 = isActive and not controlsBlocked and Input.down.R1
        state.currentChord = self:followedChord(state, Harmony:current(), l1, r1)
        return
    end

    -- The D-pad chooses this harp's chord only while its track is the active one
    if isActive or not state.currentChord then
        local dirKey = controlsBlocked and "NEUTRAL" or Input:get8WayDirection()
        state.currentChord = Theory:getChordForDirection(dirKey, Input.down.L1, Input.down.R1, state.colour)
    end
end

-- ---------------------------------------------------------------------------
-- Following: track C's chord as a harp chord (name, roman, strings)
function Harp:followedChord(state, chord, l1, r1)
    local oct = (l1 and not r1) and -12 or ((r1 and not l1) and 12 or 0)
    local notes = Theory:getPadVoicing(chord, "FULL", 0)
    for i = 1, #notes do notes[i] = notes[i] + oct end
    while #notes < 4 do notes[#notes + 1] = notes[#notes - 2] + 12 end
    return { name = Theory:chordName(chord), roman = chord.roman or "?", colour = chord.colour or "TRIAD",
             notes = notes, octShift = oct, isWide = false, followed = true }
end

-- Track page rows: one sound row (PATCH), the COLOUR and FOLLOW settings
-- ---------------------------------------------------------------------------
function Harp:getPatch(state)
    return Patches.get(self, state)
end

function Harp:cycleRowSound(state, rowIdx, delta, quiet)
    if rowIdx ~= 1 then return end
    Patches.step(self, state, delta)
    if not quiet then self:previewRowSound(state, rowIdx) end
end

function Harp:previewRowSound(state, rowIdx)
    if rowIdx ~= 1 then return end
    self:pluck(state, nil, Theory:getRootSemis(), 0.82, 1.0)
end

function Harp:getSoundRows(state)
    local colours = {}
    for i, c in ipairs(Theory.COLOURS) do colours[i] = { label = c } end
    return {
        Patches.row(self, state),
        { key = "COLOUR", label = "COLOUR", value = state.colour, kind = "setting",
          items = colours, index = self:colourIndex(state) },
        { key = "FOLLOW", label = "FOLLOW", value = state.follow and "ON" or "OFF", kind = "setting",
          items = { { label = "OFF" }, { label = "ON" } }, index = state.follow and 2 or 1 },
    }
end

function Harp:colourIndex(state)
    for i, c in ipairs(Theory.COLOURS) do
        if c == state.colour then return i end
    end
    return 1
end

function Harp:cycleSetting(state, key, delta)
    if key == "FOLLOW" then
        state.follow = not state.follow
        Looper:showToast("HARP FOLLOWS CHORDS: " .. (state.follow and "ON - PLAYS TRACK C'S CHORDS" or "OFF"))
        return
    end
    if key ~= "COLOUR" then return end
    local n = #Theory.COLOURS
    state.colour = Theory.COLOURS[((self:colourIndex(state) - 1 + delta) % n) + 1]
    Looper:showToast("CHORD COLOUR: " .. state.colour)
end

function Harp:getDpadSubtitle(state)
    if state.follow then return "FOLLOWING" end
    return nil
end

function Harp:updateInput(dt, state, track, emitEvent)
    local chord = state.currentChord or Theory:getChordForDirection("NEUTRAL", false, false, state.colour)

    if state.follow and chord.followed then
        -- strings of the followed chord: recorded as strings, not chords
        for _, btn in ipairs({ "B", "A", "Y", "X" }) do
            if Input.pressed[btn] then
                local idx = self.BUTTON_TO_INDEX[btn]
                emitEvent({ action = btn, semis = chord.notes[idx] or 0, vel = 0.82, decay = 1.0,
                            follow = true, string = idx, octShift = chord.octShift })
            end
        end
        return
    end

    for _, btn in ipairs({ "B", "A", "Y", "X" }) do
        if Input.pressed[btn] then
            -- One-shot. The chord is stored relative to the key, for Harmony
            -- (chord-follow) and so a key change transposes the recording.
            local data = self:chordData(chord)
            emitEvent({
                action = btn,
                semis = chord.notes[self.BUTTON_TO_INDEX[btn]] or 0,
                vel = 0.82,
                decay = 1.0,
                chord = data,
            })
        end
    end
end

function Harp:chordData(chord)
    return { name = chord.name, roman = chord.roman, colour = chord.colour, suffix = chord.suffix,
             root = chord.root, third = chord.third, fifth = chord.fifth, seventh = chord.seventh,
             borrowed = chord.borrowed or nil, key = Theory:getRootSemis() }
end

-- One string. Without a sound pool (no Synth:init) it is the plain one-shot.
function Harp:pluck(state, track, semis, vel, decay)
    local patch = self:getPatch(state)
    if not patch then
        return Synth:trigger("harp", semis, vel, decay, nil, track and track.volume, track)
    end
    local v = Patches.noteOn(self, state, semis, vel, { track = track, decay = decay })
    if v and v.loopSrc then
        Synth:schedule((patch.rings and self.RING or self.GATE) * decay, function() v:noteOff() end)
    end
    return v
end

function Harp:noteOn(ev, state, track, isPlayback)
    -- recorded in another key: play it in this one
    local semis = (ev.semis or 0) + Theory:keyShift(ev.chord and ev.chord.key)
    if ev.follow and isPlayback then
        -- a followed string: over the chord at its tick
        local chord = self:followedChord(state, (Harmony:chordAt(ev.tick or 0)), false, false)
        semis = (chord.notes[ev.string or 1] or 0) + (ev.octShift or 0)
    end
    self:pluck(state, track, semis, ev.vel or 0.85, ev.decay or 1.0)
    local str = state.strings[self.BUTTON_TO_INDEX[ev.action] or 1]
    if str then
        str.energy = 1.0
        str.lastSemis = semis
    end
end

-- Save / load (Phase C)
function Harp:saveState(state)
    return { colour = state.colour, patch = state.patch, follow = state.follow }
end

function Harp:loadState(state, data)
    if type(data) ~= "table" then return end
    Patches.load(self, state, data.patch)
    for _, c in ipairs(Theory.COLOURS) do
        if data.colour == c then state.colour = c end
    end
    if type(data.follow) == "boolean" then state.follow = data.follow end
end

return Harp
