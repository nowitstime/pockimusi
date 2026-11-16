-- ============================================================================
-- src/instruments/slide.lua — SLIDE: steer the pitch instead of choosing it
-- (lab instrument, plan: lab/SLIDE.md)
--
-- Like a trombone, a fretless or a theremin. The track has one pitch, in
-- semitones with fractions, kept between notes:
--   UP / DOWN     the pitch rises / falls while held, and stays where left
--   LEFT / RIGHT  step to the previous / next scale note
--   B  a note at the current pitch, while held
--   A  a note that settles on the nearest scale note when the D-pad is let go
--   Y  dive: the note falls an octave as it fades (the track's pitch stays)
--   X  accent with vibrato
--   L1 / R1       octave down / up; held while sliding = four times faster
--   L1 + R1       back to the root
-- Built on the Bass: voices, bends, the pitch trace and the stage view.
-- ============================================================================

local Theory  = require("src.theory")
local Input   = require("src.input")
local Looper  = require("src.looper")
local Bass    = require("src.instruments.bass")
local Patches = require("src.instruments.patches")

local math_floor = math.floor
local math_abs   = math.abs
local math_min   = math.min
local math_max   = math.max

local Slide = setmetatable({
    id = "slide",
    name = "SLIDE",
    shortName = "SLID",
    title = "SLIDE",
    lab = true,
    viewKind = "bass",
    eventClass = "slide",      -- its own: Bass / Lead notes are not kept on a swap

    HOME_GROUP = "LEAD",
    DEFAULT_PATCH = "lead_square",
    REGISTER = 4,              -- 0 semitones = C4
    VOICES = 4,

    -- Track page SPEED row: semitones per second while UP / DOWN is held
    SPEEDS = { "SLOW", "MEDIUM", "FAST" },
    SPEED_RATES = { SLOW = 4.0, MEDIUM = 8.0, FAST = 14.0 },
    SHOULDER_BOOST = 4.0,      -- a shoulder held while sliding
    -- Track page SNAP row
    SNAPS = { "OFF", "SOFT", "HARD" },
    SETTLE_TIME = 0.25,        -- seconds: SOFT (and A) ease onto the nearest scale note

    RANGE = 24,                -- the pitch stays within two octaves of the root
    GLIDE_RATE = 60.0,         -- the voice follows the steering this quickly
    KF_SPACING = 30,           -- ticks: at most one bend keyframe this often while sliding
    MAX_SEGMENT = 90,          -- ticks: playback slides between keyframes closer than this
    OFF_SCALE = 0.05,          -- semitones from a scale note that read as "between"
    DIVE_TIME = 0.4,           -- seconds: a Y note fades (and falls) over at least this

    ACTION_LABELS = { B = "NOTE", A = "SETTLE", Y = "DIVE", X = "ACCENT" },

    VIEW = {
        dpad = { UP = "RISE", DOWN = "FALL", LEFT = "STEP -", RIGHT = "STEP +", NEUTRAL = "STAY" },
        face = { B = "NOTE", A = "SETTLE", Y = "DIVE", X = "ACCENT" },
        l1 = "OCT - / FAST", r1 = "OCT + / FAST", both = "ROOT",
    },
}, { __index = Bass })

function Slide:newState()
    local state = Bass.newState(self)
    state.patch = self.DEFAULT_PATCH
    state.glide = "FAST"           -- shown on the stage's capsule; the rate is GLIDE_RATE
    state.follow = false           -- the Bass's chord-follow: not used here
    state.lastArticulation = "NOTE"
    state.speed = "MEDIUM"         -- Track page SPEED row
    state.snap = "SOFT"            -- Track page SNAP row
    state.pitch = 0.0              -- the track's pitch: semitones from the root
    state.travel = 0.0             -- SNAP HARD: where the D-pad has steered (pitch = nearest note)
    state.settle = nil             -- { from, to, t }: easing onto a scale note
    state.sliding = false          -- UP / DOWN held last frame
    state.dives = {}               -- { voice, from, t, dur }: Y notes falling away
    return state
end

-- ---------------------------------------------------------------------------
-- Scale notes (semitones from the root)
-- ---------------------------------------------------------------------------

-- Every scale note within an octave beyond the range, low to high
function Slide:scaleNotes()
    local intervals = Theory.SCALES[Theory.scaleIndex].intervals
    local out = {}
    local lo, hi = -self.RANGE - 12, self.RANGE + 12
    for oct = math_floor(lo / 12), math_floor(hi / 12) do
        for i = 1, 7 do
            local s = oct * 12 + intervals[i]
            if s >= lo and s <= hi then out[#out + 1] = s end
        end
    end
    return out
end

-- The scale note nearest `p` (the lower one when exactly between)
function Slide:nearestNote(p)
    local best
    for _, s in ipairs(self:scaleNotes()) do
        if not best or math_abs(s - p) < math_abs(best - p) - 1e-9 then best = s end
    end
    return best
end

-- The next scale note above (dir = 1) or below (dir = -1) `p`
function Slide:neighbourNote(p, dir)
    local notes = self:scaleNotes()
    if dir > 0 then
        for i = 1, #notes do
            if notes[i] > p + 1e-6 then return notes[i] end
        end
        return notes[#notes]
    end
    for i = #notes, 1, -1 do
        if notes[i] < p - 1e-6 then return notes[i] end
    end
    return notes[1]
end

function Slide:clampPitch(p)
    return math_max(-self.RANGE, math_min(self.RANGE, p))
end

-- The pitch a note pressed now sounds at (the voice's semitones)
function Slide:currentSemis(state)
    return Theory:getRootSemis() + state.pitch
end

-- ---------------------------------------------------------------------------
-- Track page rows: PATCH (sound), SPEED and SNAP (settings)
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

function Slide:getGlideRate()
    return self.GLIDE_RATE
end

function Slide:getSpeed(state)
    return self.SPEED_RATES[state.speed] or self.SPEED_RATES.MEDIUM
end

function Slide:getSoundRows(state)
    return {
        Patches.row(self, state),
        { key = "SPEED", label = "SPEED", value = state.speed, kind = "setting",
          items = itemsOf(self.SPEEDS), index = indexOf(self.SPEEDS, state.speed) },
        { key = "SNAP", label = "SNAP", value = state.snap, kind = "setting",
          items = itemsOf(self.SNAPS), index = indexOf(self.SNAPS, state.snap) },
    }
end

function Slide:cycleSetting(state, key, delta)
    local list = (key == "SPEED" and self.SPEEDS) or (key == "SNAP" and self.SNAPS) or nil
    if not list then return end
    local field = key:lower()
    state[field] = list[((indexOf(list, state[field]) - 1 + delta) % #list) + 1]
    if key == "SNAP" and state.snap == "HARD" then
        state.pitch = self:nearestNote(state.pitch)      -- HARD never rests between notes
        state.travel, state.settle = state.pitch, nil
    end
    Looper:showToast("SLIDE " .. key .. ": " .. state[field])
end

-- ---------------------------------------------------------------------------
-- Live input
-- ---------------------------------------------------------------------------

-- Ease onto the nearest scale note (SNAP SOFT, and A notes)
local function startSettle(self, state)
    local to = self:nearestNote(state.pitch)
    if math_abs(to - state.pitch) < 1e-9 then
        state.pitch, state.settle = to, nil
        return
    end
    state.settle = { from = state.pitch, to = to, t = 0.0 }
end

local function physicallyHeld(h)
    return h:isHeld() and Input.down[h.ev.action]
end

-- Move the track's pitch from the D-pad and shoulders
function Slide:steer(dt, state)
    local d = Input.down
    local p = state.pitch
    local up, down = d.UP and not d.DOWN, d.DOWN and not d.UP
    local slidingNow = up or down
    local held = state.handles[#state.handles]
    local aHeld = held and held.ev.action == "A" and physicallyHeld(held)

    -- L1 + R1: the root. A shoulder alone: an octave, unless it was pressed
    -- while sliding (then it only speeds the slide up)
    if d.L1 and d.R1 and (Input.pressed.L1 or Input.pressed.R1) then
        p, state.settle = 0.0, nil
    elseif not slidingNow and (Input.pressed.L1 or Input.pressed.R1) then
        local q = p + (Input.pressed.R1 and 12 or -12)
        if q >= -self.RANGE - 1e-9 and q <= self.RANGE + 1e-9 then p = q end
        state.settle = nil
    end

    -- LEFT / RIGHT: the neighbouring scale note
    if Input.pressed.LEFT or Input.pressed.RIGHT then
        local q = self:neighbourNote(p, Input.pressed.RIGHT and 1 or -1)
        p, state.settle = self:clampPitch(q), nil
    end

    if slidingNow then
        state.settle = nil
        if not state.sliding then state.travel = p end
        local speed = self:getSpeed(state) * ((d.L1 or d.R1) and self.SHOULDER_BOOST or 1.0)
        state.travel = self:clampPitch(state.travel + (up and 1 or -1) * speed * dt)
        if state.snap == "HARD" then
            p = self:clampPitch(self:nearestNote(state.travel))
        else
            p = state.travel
        end
    elseif state.sliding then
        -- the D-pad was let go: SOFT and A notes ease onto the nearest note
        state.pitch = p
        if state.snap == "SOFT" or aHeld then startSettle(self, state) end
        p = state.pitch
    end
    state.sliding = slidingNow
    if not slidingNow then state.travel = p end

    if state.settle then
        local s = state.settle
        s.t = s.t + dt
        local k = math_min(1.0, s.t / self.SETTLE_TIME)
        k = k * k * (3.0 - 2.0 * k)                       -- smoothstep
        p = s.from + (s.to - s.from) * k
        if s.t >= self.SETTLE_TIME then p, state.settle = s.to, nil end
    end
    state.pitch = p
end

-- The live note's voice follows the pitch every frame; the recording gets a
-- keyframe at most every KF_SPACING ticks while it moves, and one when it stops
function Slide:followPitch(state, track, moved)
    local h = state.handles[#state.handles]
    if not (h and h:isHeld()) then return end
    local semis = self:currentSemis(state)
    if semis ~= h.liveSemis then
        h.liveSemis = semis
        self:bendTo(h.ev, { semis = semis }, state, track)
    end
    if h.recSemis == semis then return end
    local e = h:advance()
    if not moved or e - h.kfTick >= self.KF_SPACING then
        h:bend({ semis = semis })
        h.recSemis, h.kfTick = semis, e
    end
end

function Slide:updateInput(dt, state, track, play, hold)
    -- Forget handles whose notes are over (keep the newest: the stage follows it)
    for i = #state.handles - 1, 1, -1 do
        local h = state.handles[i]
        local v = state.voices[h.ev]
        if not h:isHeld() and not (v and v:isSounding()) then
            state.voices[h.ev] = nil
            table.remove(state.handles, i)
        end
    end

    local before = state.pitch
    self:steer(dt, state)

    for _, btn in ipairs({ "B", "A", "Y", "X" }) do
        if Input.pressed[btn] then
            -- an A note is a safe note: off the scale, it eases onto it
            if btn == "A" and not state.sliding and not state.settle
               and math_abs(state.pitch - self:nearestNote(state.pitch)) > 1e-9 then
                startSettle(self, state)
            end
            local prev = state.handles[#state.handles]
            local semis = self:currentSemis(state)
            local ev = { action = btn, semis = semis, vel = (btn == "X") and 1.0 or 0.85 }
            local cut = prev and physicallyHeld(prev)
            if cut then prev:release() end             -- mono: the new note takes over
            state.lastArticulation = self.ACTION_LABELS[btn]
            local h = hold(ev)
            h.liveSemis, h.recSemis, h.kfTick = semis, semis, 0
            table.insert(state.handles, h)
            -- the old note ends exactly where the new one starts
            if cut and prev.rec and h.rec then
                local len = (h.rec.tick - prev.rec.tick) % Looper:getLoopTicks()
                if len > 0 then prev.rec.len = len end
            end
        end
    end

    self:followPitch(state, track, state.pitch ~= before)
end

-- ---------------------------------------------------------------------------
-- Sound
-- ---------------------------------------------------------------------------

-- A note's voice. Y notes get a release of at least DIVE_TIME, so the dive
-- can be heard on patches that stop short.
function Slide:startVoice(ev, state, track, semis, glideFrom)
    local patch = self:getPatch(state)
    local release
    if ev.action == "Y" and patch then release = math_max(self.DIVE_TIME, patch.release or 0) end
    return Patches.noteOn(self, state, semis or ev.semis or 0, ev.vel or 0.85, {
        track = track,
        glideFrom = glideFrom,
        glideRate = self.GLIDE_RATE,
        vibrato = (ev.action == "X"),
        release = release,
    })
end

-- Y: the note falls an octave over its release; the track's pitch stays
function Slide:startDive(state, voice)
    if not (voice and voice.setPitch and voice:isSounding()) then return end
    state.dives[#state.dives + 1] = { voice = voice, from = voice.targetSemis, t = 0.0,
                                      dur = math_max(0.05, voice.releaseTime or 0.3) }
end

function Slide:noteOff(ev, state, track, isPlayback)
    local voice
    if isPlayback then
        local p = state.playing[ev]
        voice = p and p.voice
        if p then p.diving = (ev.action == "Y") end
    else
        voice = state.voices[ev]
    end
    if voice and voice.noteOff then voice:noteOff() end
    if ev.action == "Y" then self:startDive(state, voice) end
end

-- The pitch a recorded note has `elapsed` ticks after its start: keyframes
-- close together were one slide, so playback slides between them; a keyframe
-- after a long still stretch is a step (the voice glides to it)
function Slide:pitchAt(ev, base, elapsed)
    local bend = ev.bend
    if not bend then return base end
    local prevDt, prevSemis = 0, base
    for i = 1, #bend do
        local kf = bend[i]
        if kf.semis then
            if kf.dt > elapsed then
                if kf.dt - prevDt <= self.MAX_SEGMENT and kf.dt > prevDt then
                    return prevSemis + (kf.semis - prevSemis) * (elapsed - prevDt) / (kf.dt - prevDt)
                end
                return prevSemis
            end
            prevDt, prevSemis = kf.dt, kf.semis
        end
    end
    return prevSemis
end

function Slide:updateVoices(dt, state, track)
    self:sampleTrace(state)

    -- Dives
    for i = #state.dives, 1, -1 do
        local d = state.dives[i]
        d.t = d.t + dt
        if not d.voice:isSounding() or d.t > d.dur then
            table.remove(state.dives, i)
        else
            d.voice.glideRate = self.GLIDE_RATE
            d.voice:setPitch(d.from - 12.0 * (d.t / d.dur))
        end
    end

    -- Playback: follow the recorded slide
    local loop = Looper:getLoopTicks()
    for ev, p in pairs(state.playing) do
        local v = p.voice
        if not (v.isSounding and v:isSounding()) then
            state.playing[ev] = nil
            if state.lastPlay == p then state.lastPlay = nil end
        elseif not p.diving then
            local d = (Looper.tick - p.lastTick) % loop
            if d < loop * 0.5 then p.elapsed = p.elapsed + d end
            p.lastTick = Looper.tick
            local target = self:pitchAt(ev, p.base or ev.semis or 0, p.elapsed)
            if target ~= p.semis then
                p.semis = target
                v.glideRate = self.GLIDE_RATE
                v:setPitch(target)
                self:showNote(state, target)
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Stage (the Bass view): the nearest scale note, + or - when between notes
-- ---------------------------------------------------------------------------
function Slide:getReadout(state)
    local p = state.pitch
    local near = self:nearestNote(p)
    local off = p - near
    local sign = (off > self.OFF_SCALE and "+") or (off < -self.OFF_SCALE and "-") or ""
    local name = Theory.NOTE_NAMES[((Theory:getRootSemis() + near) % 12) + 1]
    -- the scale degree of the nearest note, 1..7
    local intervals = Theory.SCALES[Theory.scaleIndex].intervals
    local deg = 1
    for i = 1, 7 do
        if intervals[i] == near % 12 then deg = i end
    end
    local oct = math_floor(near / 12)
    local playing = self:getDisplayVoice(state) ~= nil
    local small = string.format("DEG %d%s  -  OCT %s%d  -  SNAP %s  -  %s", deg, sign, (oct > 0 and "+" or ""), oct,
        state.snap, playing and (state.lastArticulation or "NOTE") or "READY")
    return name .. sign, small
end

-- ---------------------------------------------------------------------------
-- Save / load
-- ---------------------------------------------------------------------------
function Slide:saveState(state)
    return { patch = state.patch, speed = state.speed, snap = state.snap, pitch = state.pitch }
end

function Slide:loadState(state, data)
    if type(data) ~= "table" then return end
    Patches.load(self, state, data.patch)
    for _, s in ipairs(self.SPEEDS) do
        if data.speed == s then state.speed = s end
    end
    for _, s in ipairs(self.SNAPS) do
        if data.snap == s then state.snap = s end
    end
    if type(data.pitch) == "number" and data.pitch == data.pitch then
        state.pitch = self:clampPitch(data.pitch)
        state.travel = state.pitch
    end
end

return Slide
