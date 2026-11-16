-- ============================================================================
-- src/instruments/valves.lua — VALVES: fingerings and breath, like a brass
-- instrument (lab/VALVES.md)
--
--   D-pad (left thumb)    the open note, a tone of the current chord:
--                         down = 5th below, neutral = root, left = 3rd,
--                         up = 5th, right = 7th, down-right = octave
--   Face (right thumb)    the valves: each fingering lowers the open note
--                         A 1 · B 2 · A+B or X 3 · A+X 4 · Y 5 · all four 6
--                         (VALVES row: scale notes or semitones)
--   R1                    blow: the note sounds while it is held
--   L1                    tongue: a second, softer breath (75 %)
-- Nothing sounds without breath. Changing a valve or the open note while
-- blowing slurs (a recorded bend on the same voice). A change within the
-- settle window of the breath is a correction: the note is re-pitched.
--
-- Built on the Bass (voice, trace, view); replaces the input, the pitch rule,
-- the rows, playback and the save / load.
-- ============================================================================

local Theory  = require("src.theory")
local Input   = require("src.input")
local Looper  = require("src.looper")
local Harmony = require("src.harmony")
local Bass    = require("src.instruments.bass")
local Patches = require("src.instruments.patches")

local math_floor = math.floor

local Valves = setmetatable({
    id = "valves",
    name = "VALVES",
    shortName = "VALV",
    title = "VALVES",
    lab = true,
    viewKind = "bass",
    eventClass = "valves",     -- its notes mean nothing to the Bass (and the reverse)
    defaultGridIndex = 3,      -- 1/16

    HOME_GROUP = "LEAD",
    DEFAULT_PATCH = "lead_saw",
    REGISTER = 4,              -- 0 semitones = C4 (MID)
    VOICES = 4,

    -- D-pad direction -> open note (tone). The other diagonals keep the last.
    DPAD_TONE = { DOWN = -1, NEUTRAL = 0, LEFT = 1, UP = 2, RIGHT = 3, DOWN_RIGHT = 4 },
    -- tone -> the Bass's chord degree for it
    TONE_DEGREE = { [-1] = -2, [0] = 1, [1] = 3, [2] = 5, [3] = 7, [4] = 8 },
    TONE_LABELS = { [-1] = "L5", [0] = "ROOT", [1] = "3RD", [2] = "5TH", [3] = "7TH", [4] = "OCT" },
    -- The chart: fingering (Input:getFingering().id) -> steps down. Fingerings
    -- not here (X+Y, Y+B, three buttons, opposite pairs) keep the last position.
    CHART = { NONE = 0, A = 1, B = 2, BA = 3, X = 3, AX = 4, Y = 5, ALL = 6 },

    -- Track page rows
    MODES = { "SCALE", "CHROMATIC" },
    REGISTERS = { "LOW", "MID", "HIGH" },
    REGISTER_OCTAVE = { LOW = -1, MID = 0, HIGH = 1 },

    VEL = 0.85,                -- R1
    TONGUE_LEVEL = 0.75,       -- L1 = 75 % of R1
    -- Slur glides (fraction of the remaining distance per second): a valve
    -- change as GLIDE FAST on the Bass, an open-note change a little slower
    VALVE_GLIDE = 40.0,
    TONE_GLIDE = 18.0,

    LANES = { R1 = 1, L1 = 2 },
    ERASE = {
        B = { actions = { "R1" }, label = "R1 BREATHS" },
        A = { actions = { "L1" }, label = "L1 BREATHS" },
    },
    VIEW = {
        dpad = { DOWN = "L5", NEUTRAL = "ROOT", LEFT = "3RD", UP = "5TH", RIGHT = "7TH", DOWN_RIGHT = "OCT",
                 DOWN_LEFT = "", UP_LEFT = "", UP_RIGHT = "" },
        face = { B = "-2", A = "-1", X = "-3", Y = "-5" },
        l1 = "TONGUE", r1 = "BLOW",
    },
}, { __index = Bass })

function Valves:newState()
    local state = Bass.newState(self)
    state.patch = self.DEFAULT_PATCH
    state.glide = "FAST"           -- shown on the Bass view's capsule
    state.lastArticulation = "BLOW"
    state.mode = "SCALE"           -- VALVES row
    state.register = "MID"         -- REGISTER row
    state.follow = true            -- FOLLOW row
    -- Live playing
    state.tone = 0                 -- the open note the D-pad picks now
    state.steps = 0                -- the valve steps the right thumb holds now
    state.targetAge = 0.0          -- seconds tone and steps have stood still
    state.breath = nil             -- the newest breath: { h, ev, age, tone, steps, semis, chord }
    return state
end

-- ---------------------------------------------------------------------------
-- Pitch: the open note (a chord tone) lowered by the valve steps
-- ---------------------------------------------------------------------------
local function scaleSemis(d) return Theory:getScaleDegreeSemis(d) end

-- The scale degree d (any integer) with scaleSemis(d) <= p < scaleSemis(d + 1)
local function scaleIndexBelow(p)
    local d = math_floor((p - Theory:getRootSemis()) / 12) * 7 + 1
    while scaleSemis(d) > p do d = d - 1 end
    while scaleSemis(d + 1) <= p do d = d + 1 end
    return d
end

-- `open` lowered by `steps`: semitones when chromatic, else scale notes (an
-- open note outside the scale lands on the scale note below it first)
function Valves:lower(open, steps, chromatic)
    steps = steps or 0
    if chromatic then return open - steps end
    if steps <= 0 then return open end
    local d = scaleIndexBelow(open)
    if scaleSemis(d) == open then return scaleSemis(d - steps) end
    return scaleSemis(d - steps + 1)
end

-- The pitch of a tone and valve steps over `chord` (nil = the tonic chord)
function Valves:pitchFor(state, tone, steps, octave, chord, chromatic)
    chord = chord or Harmony:tonic()
    local open = Theory:getChordDegreeSemis(chord, self.TONE_DEGREE[tone] or 1)
    return self:lower(open, steps, chromatic) + (octave or 0) * 12
end

-- The chord a breath taken now plays over
function Valves:chordNow(state)
    if state.follow then return (Harmony:chordAt(Looper.tick)) end
    return Harmony:tonic()
end

-- ---------------------------------------------------------------------------
-- Track page rows: PATCH (sound), VALVES, REGISTER, FOLLOW (settings)
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

function Valves:getSoundRows(state)
    return {
        Patches.row(self, state),
        { key = "VALVES", label = "VALVES", value = state.mode, kind = "setting",
          items = itemsOf(self.MODES), index = indexOf(self.MODES, state.mode) },
        { key = "REGISTER", label = "REGISTER", value = state.register, kind = "setting",
          items = itemsOf(self.REGISTERS), index = indexOf(self.REGISTERS, state.register) },
        { key = "FOLLOW", label = "FOLLOW", value = state.follow and "ON" or "OFF", kind = "setting",
          items = ON_OFF, index = state.follow and 2 or 1 },
    }
end

function Valves:previewRowSound(state, rowIdx)
    if rowIdx ~= 1 then return end
    Patches.preview(self, state, Theory:getRootSemis() + self.REGISTER_OCTAVE[state.register] * 12, 0.8, nil, 0.3)
end

function Valves:cycleSetting(state, key, delta)
    if key == "VALVES" then
        state.mode = self.MODES[((indexOf(self.MODES, state.mode) - 1 + delta) % #self.MODES) + 1]
        Looper:showToast("VALVE STEP: " .. (state.mode == "CHROMATIC" and "SEMITONE" or "SCALE NOTE"))
    elseif key == "REGISTER" then
        state.register = self.REGISTERS[((indexOf(self.REGISTERS, state.register) - 1 + delta) % #self.REGISTERS) + 1]
        Looper:showToast("VALVES REGISTER: " .. state.register)
    elseif key == "FOLLOW" then
        state.follow = not state.follow
        Looper:showToast("VALVES FOLLOW CHORDS: " .. (state.follow and "ON" or "OFF"))
    end
end

-- ---------------------------------------------------------------------------
-- Live input
-- ---------------------------------------------------------------------------
-- The shoulder of a breath is still down (its handle is released a moment
-- after its button goes up, after this instrument has read the input)
local function blowing(b)
    return b and b.h:isHeld() and Input.down[b.ev.action]
end

-- Steps of the current fingering, or nil (off the chart: keep the last)
function Valves:readSteps()
    return self.CHART[Input:getFingering().id]
end

function Valves:breathe(state, track, btn, hold)
    local octave = self.REGISTER_OCTAVE[state.register] or 0
    local chromatic = (state.mode == "CHROMATIC")
    local chord = self:chordNow(state)
    local semis = self:pitchFor(state, state.tone, state.steps, octave, chord, chromatic)
    local vel = self.VEL * ((btn == "L1") and self.TONGUE_LEVEL or 1.0)
    local ev = { action = btn, tone = state.tone, steps = state.steps, chromatic = chromatic,
                 octave = octave, semis = semis, vel = vel }

    -- Mono: a second shoulder takes the note over with a new attack; the
    -- first shoulder's release then does nothing (its note has ended)
    local prev = state.breath
    local cut = blowing(prev)
    if cut then prev.h:release() end

    local h = hold(ev)
    state.breath = { h = h, ev = ev, age = 0.0, tone = state.tone, steps = state.steps,
                     semis = semis, chord = chord }
    state.lastArticulation = (btn == "L1") and "TONGUE" or "BLOW"

    -- Both notes snap to the grid on their own: the old one ends exactly
    -- where the new one starts, so playback has no gap or overlap
    if cut and prev.h.rec and h.rec then
        local len = (h.rec.tick - prev.h.rec.tick) % Looper:getLoopTicks()
        if len > 0 then prev.h.rec.len = len end
    end
end

-- A change just after the breath: the thumb landed a frame late. Re-pitch
-- the note at once and fix what was recorded; no slur.
function Valves:correct(state, b)
    local semis = self:pitchFor(state, state.tone, state.steps, b.ev.octave, b.chord, b.ev.chromatic)
    b.tone, b.steps, b.semis = state.tone, state.steps, semis
    for _, ev in ipairs({ b.ev, b.h.rec }) do
        if ev then ev.tone, ev.steps, ev.semis = state.tone, state.steps, semis end
    end
    local voice = state.voices[b.ev]
    if voice and voice.setPitch then
        voice:setPitch(semis)
        voice.currentSemis = semis                  -- a jump, not a glide
    end
    self:showNote(state, semis)
end

-- A change while blowing: glide the same voice and record a bend, with the
-- tone and steps beside it (ev.slur, same dt) so it re-harmonises on playback
function Valves:slur(state, b)
    local rate = (state.tone ~= b.tone) and self.TONE_GLIDE or self.VALVE_GLIDE
    local semis = self:pitchFor(state, state.tone, state.steps, b.ev.octave, b.chord, b.ev.chromatic)
    b.tone, b.steps, b.semis = state.tone, state.steps, semis
    local rec = b.h.rec
    local before = rec and rec.bend and rec.bend[#rec.bend]
    b.h:bend({ semis = semis, octave = b.ev.octave, glideRate = rate })
    local kf = rec and rec.bend and rec.bend[#rec.bend]
    if kf and kf ~= before then
        rec.slur = rec.slur or {}
        local entry = { dt = kf.dt, tone = state.tone, steps = state.steps }
        local last = rec.slur[#rec.slur]
        if last and last.dt == kf.dt then rec.slur[#rec.slur] = entry else table.insert(rec.slur, entry) end
    end
end

function Valves:updateInput(dt, state, track, play, hold)
    -- What the thumbs choose now
    local tone, steps = self.DPAD_TONE[Input:get8WayDirection()], self:readSteps()
    tone = tone or state.tone
    steps = steps or state.steps
    if tone ~= state.tone or steps ~= state.steps then
        state.tone, state.steps, state.targetAge = tone, steps, 0.0
    else
        state.targetAge = state.targetAge + dt
    end
    state.activeDegree = self.TONE_DEGREE[state.tone]

    -- Forget voices of breaths that are over
    for ev, v in pairs(state.voices) do
        if not (state.breath and state.breath.ev == ev) and not (v.isSounding and v:isSounding()) then
            state.voices[ev] = nil
        end
    end

    -- Breath: R1 blows, L1 tongues (R1 wins if both land in one frame)
    local btn = (Input.pressed.R1 and "R1") or (Input.pressed.L1 and "L1") or nil
    if btn then
        self:breathe(state, track, btn, hold)
        return
    end

    local b = state.breath
    if not blowing(b) then return end
    b.age = b.age + dt
    if state.tone == b.tone and state.steps == b.steps then return end
    local window = Input.FINGER_SETTLE - 1e-6
    if b.age < window then
        self:correct(state, b)
    elseif state.targetAge >= window then
        -- a slur waits for the thumbs to stand still, so a pair landing a
        -- frame apart (or a passing diagonal) isn't heard on the way
        self:slur(state, b)
    end
end

-- ---------------------------------------------------------------------------
-- Sound
-- ---------------------------------------------------------------------------
function Valves:startVoice(ev, state, track, semis)
    return Patches.noteOn(self, state, semis or ev.semis or 0, ev.vel or self.VEL, {
        track = track,
        glideRate = self.VALVE_GLIDE,
    })
end

function Valves:noteOn(ev, state, track, isPlayback)
    local semis = ev.semis or 0
    if not isPlayback then
        state.voices[ev] = self:startVoice(ev, state, track, semis)
    else
        -- Following: tone and steps are played over the chord at the note's
        -- start, so a recorded line moves with changed chords
        local chord
        if state.follow and ev.tone then
            chord = Harmony:chordAt(ev.tick, self.CHORD_LOOKAHEAD)
            semis = self:pitchFor(state, ev.tone, ev.steps, ev.octave, chord, ev.chromatic)
        end
        local voice = self:startVoice(ev, state, track, semis)
        if voice then
            local entry = { voice = voice, elapsed = 0.0, lastTick = Looper.tick, semis = semis, base = semis, chord = chord }
            state.playing[ev] = entry
            state.lastPlay = entry
        end
    end
    self:showNote(state, semis)
end

function Valves:noteOff(ev, state, track, isPlayback)
    local voice
    if isPlayback then
        local p = state.playing[ev]
        voice = p and p.voice
    else
        voice = state.voices[ev]
    end
    if voice and voice.noteOff then voice:noteOff() end
end

-- Live slur from a handle
function Valves:bendTo(ev, fields, state, track)
    local voice = state.voices[ev]
    if voice and voice.setPitch and fields.semis then
        voice.glideRate = fields.glideRate or self.VALVE_GLIDE
        voice:setPitch(fields.semis)
        self:showNote(state, fields.semis)
    end
end

-- The latest entry of a list of { dt, ... } at `elapsed`, and the one before
local function latestAt(list, elapsed)
    if not list then return nil end
    local found, prev
    for i = 1, #list do
        if list[i].dt <= elapsed then prev, found = found, list[i] else break end
    end
    return found, prev
end

-- Playback: replay the slurs (over the note's chord when following); drop
-- notes that have gone silent
function Valves:updateVoices(dt, state, track)
    self:sampleTrace(state)
    local loop = Looper:getLoopTicks()
    for ev, p in pairs(state.playing) do
        local v = p.voice
        if not (v.isSounding and v:isSounding()) then
            state.playing[ev] = nil
            if state.lastPlay == p then state.lastPlay = nil end
        else
            local d = (Looper.tick - p.lastTick) % loop
            if d < loop * 0.5 then p.elapsed = p.elapsed + d end
            p.lastTick = Looper.tick
            local target, rate = p.base or ev.semis, self.VALVE_GLIDE
            local s, sPrev = latestAt(ev.slur, p.elapsed)
            if s then
                local fromTone = sPrev and sPrev.tone or ev.tone
                if s.tone ~= fromTone then rate = self.TONE_GLIDE end
            end
            if p.chord and s and s.tone then
                target = self:pitchFor(state, s.tone, s.steps, ev.octave, p.chord, ev.chromatic)
            else
                local kf = latestAt(ev.bend, p.elapsed)
                if kf and kf.semis then target = kf.semis end
            end
            if target and target ~= p.semis then
                p.semis = target
                v.glideRate = rate
                v:setPitch(target)
                self:showNote(state, target)
            end
        end
    end
end

-- The voice the stage view follows: the live breath while it sounds, else
-- the newest playback note
function Valves:getDisplayVoice(state)
    local b = state.breath
    local v = b and state.voices[b.ev]
    if v and v.isSounding and v:isSounding() then return v, b.ev end
    local p = state.lastPlay
    if p and p.voice.isSounding and p.voice:isSounding() then return p.voice end
    return nil
end

-- Bass view: the note (sounding, else what a breath would play) and the
-- fingering under it
function Valves:getReadout(state)
    local voice = self:getDisplayVoice(state)
    local semis
    if voice then
        semis = math_floor(voice.currentSemis + 0.5)
    else
        semis = self:pitchFor(state, state.tone, state.steps, 0, self:chordNow(state), state.mode == "CHROMATIC")
    end
    local name = Theory.NOTE_NAMES[(semis % 12) + 1]
    local small = string.format("%s  -%d %s  -  %s   A+X -4  ALL -6",
        self.TONE_LABELS[state.tone] or "ROOT", state.steps,
        (state.mode == "CHROMATIC") and "SEMI" or "SCALE",
        voice and (state.lastArticulation or "BLOW") or "BREATHE")
    return name, small
end

-- ---------------------------------------------------------------------------
-- Save / load
-- ---------------------------------------------------------------------------
function Valves:saveState(state)
    return { patch = state.patch, valves = state.mode, register = state.register, follow = state.follow }
end

function Valves:loadState(state, data)
    if type(data) ~= "table" then return end
    Patches.load(self, state, data.patch)
    for _, m in ipairs(self.MODES) do
        if data.valves == m then state.mode = m end
    end
    for _, r in ipairs(self.REGISTERS) do
        if data.register == r then state.register = r end
    end
    if type(data.follow) == "boolean" then state.follow = data.follow end
end

return Valves
