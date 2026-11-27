-- ============================================================================
-- src/instruments/wobble.lua — Wobble: the D-pad sets how the tone moves in
-- time (PHASE_L.md L9)
--
-- Neuro, dubstep and EDM basses. The face buttons hold the notes; the D-pad
-- sets how fast the tone opens and closes, locked to the beat. Rocking
-- between directions while holding makes the bass talk.
--   B root · Y 3rd · X 5th · A octave (clockwise = up), over track C's chord;
--     a new note while one is held glides to it (no new attack)
--   D-pad  wobble rate: ↑ 1/4 · ↗ 1/8 · → 1/16 · ↘ 1/8T · ↓ closed (no
--          wobble) · ↙ 1/2 · ← 1 bar · ↖ 1/16T; neutral keeps the last
--   L1 / R1  octave down / up · both: OPEN (the tone fully open, the scream)
-- The tone is the patch's bright layer, faded in and out every frame (so it
-- works without EFX); with EFX a low-pass follows it too. Only patches with
-- a bright layer are offered (REESE, NEURO, the pads ...).
-- Built on the Bass: notes are ordinary held notes; the rate and OPEN are on
-- each note (ev.rate, ev.open) and changes while it is held are recorded as
-- bend keyframes { rate, open }, so playback wobbles as it was played.
-- ============================================================================

local Input   = require("src.input")
local Synth   = require("src.synth")
local Looper  = require("src.looper")
local Harmony = require("src.harmony")
local Bass    = require("src.instruments.bass")
local Patches = require("src.instruments.patches")

local math_floor = math.floor
local math_cos   = math.cos
local math_pi    = math.pi
local math_max   = math.max

local Wobble = setmetatable({
    id = "wobble",
    group = "BASS",
    name = "WOBBLE",
    shortName = "WOB",
    viewKind = "bass",        -- the Bass view, with its own panel and badge
    PANEL = "wobble",
    eventClass = "mono",
    defaultGridIndex = 3,

    HOME_GROUP = "BASS",
    DEFAULT_PATCH = "bass_neuro",
    REGISTER = 3,
    VOICES = 6,
    NEEDS_LOOP = true,
    NEEDS_BRIGHT = true,

    -- Face button -> degree over the chord (clockwise from B = up)
    NOTE_DEGREE = { B = 1, Y = 3, X = 5, A = 8 },
    NOTE_LABELS = { B = "ROOT", Y = "3RD", X = "5TH", A = "OCT" },

    -- D-pad direction -> wobble rate
    RATE_OF = { UP = "1/4", UP_RIGHT = "1/8", RIGHT = "1/16", DOWN_RIGHT = "1/8T",
                DOWN = "CLOSED", DOWN_LEFT = "1/2", LEFT = "1 BAR", UP_LEFT = "1/16T" },
    RATE_TICKS = { ["1/4"] = 480, ["1/8"] = 240, ["1/16"] = 120, ["1/8T"] = 160,
                   ["1/2"] = 960, ["1 BAR"] = 1920, ["1/16T"] = 80 },        -- CLOSED: none

    SHAPES = { "SINE", "SAW", "SQUARE", "STEPPED" },
    DEPTHS = { "LIGHT", "MEDIUM", "FULL" },
    DEPTH_AMOUNT = { LIGHT = 0.5, MEDIUM = 0.8, FULL = 1.0 },
    FLOOR = 0.04,              -- the bright layer when fully closed

    VIEW = {
        dpad = { NEUTRAL = "KEEP", UP = "1/4", UP_RIGHT = "1/8", RIGHT = "1/16", DOWN_RIGHT = "1/8T",
                 DOWN = "CLOSED", DOWN_LEFT = "1/2", LEFT = "1 BAR", UP_LEFT = "1/16T" },
        face = { B = "ROOT", Y = "3RD", X = "5TH", A = "OCT" },
        l1 = "OCT -1", r1 = "OCT +1", both = "OPEN",
    },
}, { __index = Bass })

function Wobble:newState()
    local state = Bass.newState(self)
    state.patch = self.DEFAULT_PATCH
    state.glide = "FAST"
    state.shape = "SINE"           -- Track page SHAPE row
    state.depth = "FULL"           -- Track page DEPTH row
    state.rate = "1/8"             -- the D-pad's rate (kept when it returns to neutral)
    state.open = false             -- both shoulders held
    state.freeTicks = 0.0          -- the wobble's own clock while the clock is paused
    state.level = 0.0              -- the tone right now (stage view)
    state.history = {}             -- recent tone levels (stage view)
    state.lastArticulation = "READY"
    return state
end

function Wobble:getDpadSubtitle()
    return "WOBBLE RATE"
end

function Wobble:getMiddleBadge(state)
    if state.open then return "OPEN" end
    return "WOB " .. state.rate
end

function Wobble:getActionLabel(state, btn)
    return self.NOTE_LABELS[btn] or btn
end

function Wobble:getActiveButtons(state)
    local on = {}
    local h = state.handles[#state.handles]
    if h and h:isHeld() and Input.down[h.ev.action] then on[h.ev.action] = true end
    return on
end

-- ---------------------------------------------------------------------------
-- Track page rows: PATCH (sound), SHAPE, DEPTH, GLIDE, FOLLOW (settings)
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

function Wobble:getSoundRows(state)
    return {
        Patches.row(self, state),
        { key = "SHAPE", label = "SHAPE", value = state.shape, kind = "setting",
          items = itemsOf(self.SHAPES), index = indexOf(self.SHAPES, state.shape) },
        { key = "DEPTH", label = "DEPTH", value = state.depth, kind = "setting",
          items = itemsOf(self.DEPTHS), index = indexOf(self.DEPTHS, state.depth) },
        { key = "GLIDE", label = "GLIDE", value = state.glide, kind = "setting",
          items = itemsOf(self.GLIDES), index = indexOf(self.GLIDES, state.glide) },
        { key = "FOLLOW", label = "FOLLOW", value = state.follow and "ON" or "OFF", kind = "setting",
          items = ON_OFF, index = state.follow and 2 or 1 },
    }
end

function Wobble:cycleSetting(state, key, delta)
    local function step(list, value)
        return list[((indexOf(list, value) - 1 + delta) % #list) + 1]
    end
    if key == "SHAPE" then
        state.shape = step(self.SHAPES, state.shape)
        Looper:showToast("WOBBLE SHAPE: " .. state.shape)
    elseif key == "DEPTH" then
        state.depth = step(self.DEPTHS, state.depth)
        Looper:showToast("WOBBLE DEPTH: " .. state.depth)
    elseif key == "GLIDE" then
        state.glide = step(self.GLIDES, state.glide)
        Looper:showToast("WOBBLE GLIDE: " .. state.glide)
    elseif key == "FOLLOW" then
        state.follow = not state.follow
        Looper:showToast("WOBBLE FOLLOWS CHORDS: " .. (state.follow and "ON" or "OFF"))
    end
end

-- ---------------------------------------------------------------------------
-- The wobble: the tone (0..1) at a song position
-- ---------------------------------------------------------------------------
-- A fixed pseudo-random level per step (STEPPED), the same every pass
local function stepRandom(i)
    local x = math.sin(i * 12.9898 + 78.233) * 43758.5453
    return x - math_floor(x)
end

function Wobble:lfo(shape, ph, stepIdx)
    if shape == "SAW" then return 1.0 - ph end                     -- opens on the beat, falls: "wub"
    if shape == "SQUARE" then return (ph < 0.5) and 1.0 or 0.0 end
    if shape == "STEPPED" then return stepRandom(stepIdx) end
    return 0.5 - 0.5 * math_cos(ph * 2.0 * math_pi)                -- SINE: closed on the beat
end

-- The tone for a rate / open at song tick `tick`
function Wobble:toneAt(state, rate, open, tick)
    if open then return 1.0 end
    local rt = self.RATE_TICKS[rate or state.rate]
    if not rt then return self.FLOOR end                           -- CLOSED
    local idx = math_floor(tick / rt)
    local ph = (tick - idx * rt) / rt
    local depth = self.DEPTH_AMOUNT[state.depth] or 1.0
    return self.FLOOR + (1.0 - self.FLOOR) * depth * self:lfo(state.shape, ph, idx)
end

-- The song position the wobble follows (its own clock while paused)
function Wobble:wobbleTick(state)
    if Looper.playing then return Looper.tick end
    return state.freeTicks
end

-- Put a tone on a voice: the bright layer, and with EFX a low-pass too
function Wobble:applyTone(v, track, b)
    if not v then return end
    v.bright, v.brightNow = b, b
    if Synth.fxSupported then
        local tone = 0.1 + 0.9 * b
        for _, src in ipairs({ v.loopSrc or false, v.brightSrc or false }) do
            if src then
                Synth.sourceTone[src] = (tone < 0.999) and tone or nil
                Synth:applyFilter(src, track)
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Live input
-- ---------------------------------------------------------------------------
local function physicallyHeld(h)
    return h:isHeld() and Input.down[h.ev.action]
end

function Wobble:updateInput(dt, state, track, play, hold)
    local dir = Input:get8WayDirection()
    if self.RATE_OF[dir] then state.rate = self.RATE_OF[dir] end
    local both = Input.down.L1 and Input.down.R1
    state.open = both and true or false
    local octave = both and 0 or ((Input.down.L1 and -1 or 0) + (Input.down.R1 and 1 or 0))
    local chordNow = state.follow and Harmony:chordAt(Looper.tick) or nil

    -- forget notes that are over (keep the newest)
    for i = #state.handles - 1, 1, -1 do
        local h = state.handles[i]
        local v = state.voices[h.ev]
        if not h:isHeld() and not (v and v:isSounding()) then
            state.voices[h.ev] = nil
            table.remove(state.handles, i)
        end
    end

    for _, btn in ipairs({ "B", "Y", "X", "A" }) do
        if Input.pressed[btn] then
            local deg = self.NOTE_DEGREE[btn]
            local semis = self:pitchFor(state, deg, octave, chordNow)
            local prev = state.handles[#state.handles]
            local ev = { action = btn, degree = deg, octave = octave, semis = semis, vel = 0.9,
                         rate = state.rate, wobbleOpen = state.open or nil }
            -- a new note while one is held: glide to it on the same voice
            local legato = prev and physicallyHeld(prev)
            if legato then
                ev.glideFrom = state.lastSemis
                ev.glideFromDegree, ev.glideFromOctave = state.lastDegree, state.lastOctave
                state.takeover = state.voices[prev.ev]
                state.voices[prev.ev] = nil
                ev.legato = true
                prev:release()
            end
            state.lastArticulation = self.NOTE_LABELS[btn]
            local h = hold(ev)
            h.bentSemis, h.bentOctave, h.chord = semis, octave, chordNow
            h.bentRate, h.bentOpen = state.rate, state.open
            table.insert(state.handles, h)
            state.takeover = nil
            state.lastSemis, state.lastDegree, state.lastOctave = semis, deg, octave
            if legato and prev.rec and h.rec then
                local len = (h.rec.tick - prev.rec.tick) % Looper:getLoopTicks()
                if len > 0 then prev.rec.len = len end
            end
        end
    end

    -- while held: rate, OPEN and octave changes are recorded as keyframes
    local h = state.handles[#state.handles]
    if h and physicallyHeld(h) then
        local deg = h.ev.degree
        local tSemis = self:pitchFor(state, deg, octave, h.chord)
        if state.rate ~= h.bentRate or state.open ~= h.bentOpen or tSemis ~= h.bentSemis then
            h.bentRate, h.bentOpen = state.rate, state.open
            local fields = { rate = state.rate, open = state.open or false }
            if tSemis ~= h.bentSemis then
                h.bentSemis, h.bentOctave = tSemis, octave
                state.lastSemis, state.lastOctave = tSemis, octave
            end
            fields.degree, fields.octave, fields.semis = deg, h.bentOctave, h.bentSemis
            h:bend(fields)
        end
    end
end

-- A live change: pitch as the Bass; the tone is set every frame anyway
function Wobble:bendTo(ev, fields, state, track)
    if fields.semis then Bass.bendTo(self, ev, fields, state, track) end
end

function Wobble:startVoice(ev, state, track, semis, glideFrom)
    semis = semis or ev.semis or 0
    if glideFrom == nil then glideFrom = ev.glideFrom end
    return Patches.noteOn(self, state, semis, ev.vel or 0.9, {
        track = track,
        glideFrom = glideFrom,
        glideRate = self:getGlideRate(state),
        bright = self:toneAt(state, ev.rate, ev.wobbleOpen, self:wobbleTick(state)),
    })
end

-- The rate and OPEN in effect `elapsed` ticks into a recorded note
local function rateAt(ev, elapsed)
    local rate, open = ev.rate, ev.wobbleOpen
    local bend = ev.bend
    if bend then
        for i = 1, #bend do
            local kf = bend[i]
            if kf.dt > elapsed then break end
            if kf.rate then rate = kf.rate end
            if kf.open ~= nil then open = kf.open end
        end
    end
    return rate, open
end

-- Every frame: playback pitch (the Bass), then the tone of every voice
function Wobble:updateVoices(dt, state, track)
    Bass.updateVoices(self, dt, state, track)
    if not Looper.playing then
        state.freeTicks = state.freeTicks + dt * Looper:getTicksPerSecond()
    end
    local tick = self:wobbleTick(state)
    local shown
    -- live notes follow the D-pad and shoulders now
    for _, h in ipairs(state.handles) do
        local v = state.voices[h.ev]
        if v and v.isSounding and v:isSounding() then
            local b = self:toneAt(state, state.rate, state.open, tick)
            self:applyTone(v, track, b)
            shown = b
        end
    end
    -- recorded notes as they were played
    for ev, p in pairs(state.playing) do
        local v = p.voice
        if v and v.isSounding and v:isSounding() then
            local rate, open = rateAt(ev, p.elapsed)
            local b = self:toneAt(state, rate, open, tick)
            self:applyTone(v, track, b)
            shown = shown or b
        end
    end
    state.level = shown or 0.0
    local hist = state.history
    hist[#hist + 1] = shown or false
    if #hist > 72 then table.remove(hist, 1) end
end

-- ---------------------------------------------------------------------------
-- Save / load (Phase C)
-- ---------------------------------------------------------------------------
function Wobble:saveState(state)
    return { patch = state.patch, shape = state.shape, depth = state.depth, glide = state.glide, follow = state.follow }
end

function Wobble:loadState(state, data)
    if type(data) ~= "table" then return end
    Patches.load(self, state, data.patch)
    for _, v in ipairs(self.SHAPES) do if data.shape == v then state.shape = v end end
    for _, v in ipairs(self.DEPTHS) do if data.depth == v then state.depth = v end end
    for _, v in ipairs(self.GLIDES) do if data.glide == v then state.glide = v end end
    if type(data.follow) == "boolean" then state.follow = data.follow end
end

return Wobble
