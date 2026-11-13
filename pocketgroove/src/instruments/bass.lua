-- ============================================================================
-- src/instruments/bass.lua — "Compass" Ribbon Bass & Lead Instrument Module
-- ============================================================================

local Theory = require("src.theory")
local Input  = require("src.input")
local Synth  = require("src.synth")
local Looper = require("src.looper")

local math_max   = math.max

-- The latest bend keyframe at `elapsed` ticks into a note (same rule as
-- Instruments:bendAt; local to avoid a circular require)
local function Instruments_bendAt(ev, elapsed)
    local bend, found = ev.bend, nil
    if not bend then return nil end
    for i = 1, #bend do
        if bend[i].dt <= elapsed then found = bend[i] else break end
    end
    return found
end

local Bass = {
    id = "bass",
    name = "RIBBON BASS",
    shortName = "BASS",
    title = "RIBBON BASS & LEAD",
    defaultGridIndex = 3, -- 1/16

    -- Track page PATCH row: synth patches (src/synth/synths_bank.lua)
    PATCHES = { "bass_saw", "bass_sub", "bass_pluck" },
    -- Track page GLIDE row: how fast legato and bends reach the new pitch
    -- (fraction of the remaining distance covered per second)
    GLIDES = { "FAST", "MEDIUM", "SLOW" },
    GLIDE_RATES = { FAST = 40.0, MEDIUM = 18.0, SLOW = 8.0 },
    COMPASS_DEGREE_MAP = {
        DOWN       = -2,      -- the 5th below the root (shown as "L5")
        DOWN_LEFT  = 2,
        LEFT       = 3,
        UP_LEFT    = 4,
        UP         = 5,
        UP_RIGHT   = 6,
        RIGHT      = 7,
        DOWN_RIGHT = 8,
        NEUTRAL    = 1,       -- resting D-pad = the root
    },
}

function Bass:newState()
    return {
        activeDegree = 1,
        lastSemis = 0,
        oscPhase = 0.0,
        oscAmp = 0.08,
        oscFreqRatio = 1.0,
        lastArticulation = "HOLD",
        patch = "bass_saw",        -- Track page PATCH row
        glide = "MEDIUM",          -- Track page GLIDE row

        -- Live playing
        voices = {},               -- [live ev] = voice
        handles = {},              -- live held-note handles, newest last (kept while their tail sounds)
        -- Playback
        playing = {},              -- [recorded ev] = { voice, elapsed, lastTick, semis }
        lastPlay = nil,            -- newest playback entry (legato takes its voice over)
        -- Stage view: the sounding voice's pitch and level, one sample per frame
        trace = {},                -- ring of { semis, level, released } or false (silent)
        traceHead = 0,
    }
end
-- How a degree is shown: 1..8, and "L5" for the 5th below the root (-2)
function Bass:degreeLabel(deg)
    if deg == -2 then return "L5" end
    return tostring(deg)
end

-- ---------------------------------------------------------------------------
-- Track page rows: PATCH (sound) and GLIDE (setting)
-- ---------------------------------------------------------------------------
local function indexOf(list, value)
    for i, v in ipairs(list) do
        if v == value then return i end
    end
    return 1
end

function Bass:getPatch(state)
    return Synth.patches[state.patch] or Synth.patches[self.PATCHES[1]]
end

function Bass:getGlideRate(state)
    return self.GLIDE_RATES[state.glide] or self.GLIDE_RATES.MEDIUM
end

function Bass:getSoundRows(state)
    local patch = self:getPatch(state)
    return {
        { key = "PATCH", label = "PATCH", value = patch and patch.label or state.patch,
          hint = string.format("%d/%d", indexOf(self.PATCHES, state.patch), #self.PATCHES) },
        { key = "GLIDE", label = "GLIDE", value = state.glide, kind = "setting",
          hint = string.format("%d/%d", indexOf(self.GLIDES, state.glide), #self.GLIDES) },
    }
end

function Bass:cycleRowSound(state, rowIdx, delta)
    if rowIdx ~= 1 then return end
    local n = #self.PATCHES
    state.patch = self.PATCHES[((indexOf(self.PATCHES, state.patch) - 1 + delta) % n) + 1]
    local patch = self:getPatch(state)
    if patch then
        Synth:trigger(patch.attack, Theory:getRootSemis(), 0.85, 0.7)   -- preview
        Looper:showToast("BASS PATCH: " .. patch.label)
    end
end

function Bass:cycleSetting(state, key, delta)
    if key ~= "GLIDE" then return end
    local n = #self.GLIDES
    state.glide = self.GLIDES[((indexOf(self.GLIDES, state.glide) - 1 + delta) % n) + 1]
    Looper:showToast("BASS GLIDE: " .. state.glide)
end

function Bass:updateVisuals(dt, state)
    state.oscAmp = math_max(0.08, state.oscAmp - dt * 2.2)
    state.oscPhase = state.oscPhase + dt * 18.0 * state.oscFreqRatio
end

-- ---------------------------------------------------------------------------
-- Live input
--   B hold · A legato · Y staccato (one grid step) · X accent + vibrato
--   D-pad = degree, L1/R1 = octave. While a note is held, or still fading
--   after release, pitch changes glide and are recorded as bends.
-- ---------------------------------------------------------------------------
local ARTICULATION = { B = "HOLD", A = "LEGATO", Y = "STACCATO", X = "ACCENT" }

-- Held right now? The handle is released a moment after its button goes up
-- (after this instrument has read the input), so check the button too.
-- Staccato notes (fixed length) don't depend on the button.
local function physicallyHeld(h)
    return h:isHeld() and (h.fixedLen ~= nil or Input.down[h.ev.action])
end

-- The note that pitch changes go to: the newest held note, or the newest
-- note's fading tail
local function bendTarget(state)
    local h = state.handles[#state.handles]
    if not h then return nil end
    local v = state.voices[h.ev]
    if h:isHeld() or (v and v:isSounding()) then return h end
    return nil
end

function Bass:updateInput(dt, state, track, play, hold)
    local deg = self.COMPASS_DEGREE_MAP[Input:get8WayDirection()] or 1
    state.activeDegree = deg
    local octave = (Input.down.L1 and -1 or 0) + (Input.down.R1 and 1 or 0)
    local semis = Theory:getScaleDegreeSemis(deg) + octave * 12

    -- Forget handles whose notes are over (keep the newest: its tail may still bend)
    for i = #state.handles - 1, 1, -1 do
        local h = state.handles[i]
        local v = state.voices[h.ev]
        if not h:isHeld() and not (v and v:isSounding()) then
            state.voices[h.ev] = nil
            table.remove(state.handles, i)
        end
    end

    local patch = self:getPatch(state)
    local mono = not (patch and patch.overlap)

    for _, btn in ipairs({ "B", "A", "Y", "X" }) do
        if Input.pressed[btn] then
            local prev = state.handles[#state.handles]
            local ev = { action = btn, degree = deg, octave = octave, semis = semis,
                         vel = (btn == "X") and 1.0 or 0.85 }
            local opts

            if btn == "A" then
                ev.glideFrom = state.lastSemis
                ev.glideFromDegree, ev.glideFromOctave = state.lastDegree, state.lastOctave
                -- Legato: take over the held note's voice (no new attack)
                if prev and physicallyHeld(prev) and mono then
                    state.takeover = state.voices[prev.ev]
                    state.voices[prev.ev] = nil      -- so releasing it doesn't stop the voice
                    ev.legato = true                 -- replays on the same voice too
                end
            elseif btn == "Y" then
                local grid = Looper:getTrackGrid(track.slot)
                opts = { fixedLen = grid.stepTicks or (Looper.PPQN / 4) }
            end

            local cut = mono and prev and physicallyHeld(prev)
            if cut then
                prev:release()                       -- mono: the new note ends the old one here
            end

            state.lastArticulation = ARTICULATION[btn]
            local h = hold(ev, opts)
            h.bentSemis, h.bentOctave = semis, octave
            table.insert(state.handles, h)
            state.takeover = nil

            -- Both notes snap to the grid on their own: make the old one end
            -- exactly where the new one starts, so playback has no gap or overlap
            if cut and prev.rec and h.rec then
                local len = (h.rec.tick - prev.rec.tick) % Looper:getLoopTicks()
                if len > 0 then prev.rec.len = len end
            end
        end
    end

    -- Pitch changes glide the held note (or its fading tail) and are recorded.
    -- In the tail, only a D-pad direction moves the note: letting go of the
    -- D-pad or a shoulder together with the button doesn't drag it down.
    local h = bendTarget(state)
    if h then
        local tDeg, tOct = deg, octave
        if not physicallyHeld(h) then
            if Input:get8WayDirection() == "NEUTRAL" then tDeg = nil end
            if not (Input.down.L1 or Input.down.R1) then tOct = h.bentOctave end
        end
        if tDeg then
            local tSemis = Theory:getScaleDegreeSemis(tDeg) + tOct * 12
            if tSemis ~= h.bentSemis then
                h.bentSemis, h.bentOctave = tSemis, tOct
                h:bend({ degree = tDeg, octave = tOct, semis = tSemis })
                state.lastSemis, state.lastDegree, state.lastOctave = tSemis, tDeg, tOct
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Sound
-- ---------------------------------------------------------------------------
function Bass:startVoice(ev, state, track)
    local patch = self:getPatch(state)
    return Synth:noteOn(state.patch, ev.semis or 0, ev.vel or 0.85, {
        track = track,
        glideFrom = ev.glideFrom,
        glideRate = self:getGlideRate(state),
        vibrato = (ev.action == "X"),
    }) or (patch and Synth:trigger(patch.attack, ev.semis or 0, ev.vel or 0.85, 1.0, nil, track.volume, track))
end

function Bass:showNote(state, semis)
    state.lastSemis = semis
    state.oscAmp = 1.0
    state.oscFreqRatio = 2.0 ^ (semis / 12.0)
end

function Bass:noteOn(ev, state, track, isPlayback)
    local semis = ev.semis or 0
    if not isPlayback then
        local voice = state.takeover
        if voice and voice:isSounding() then
            voice:resume()
            voice.glideRate = self:getGlideRate(state)
            voice:setPitch(semis)                     -- legato: glide, no new attack
        else
            voice = self:startVoice(ev, state, track)
        end
        state.voices[ev] = voice
        state.lastDegree, state.lastOctave = ev.degree, ev.octave
    else
        -- Legato on playback: a note recorded as legato takes over the
        -- previous note's voice if it is still sounding or released only just
        -- now (the old note ends on this note's tick)
        local voice
        local prev = state.lastPlay
        if ev.legato and prev and prev.voice:isSounding() then
            local since = prev.voice:releasedFor()
            if not since or since <= 0.05 then
                voice = prev.voice
                voice:resume()
                voice.glideRate = self:getGlideRate(state)
                voice:setPitch(semis)
                for e, p in pairs(state.playing) do
                    if p == prev then state.playing[e] = nil end
                end
            end
        end
        voice = voice or self:startVoice(ev, state, track)
        local entry = { voice = voice, elapsed = 0.0, lastTick = Looper.tick, semis = semis }
        state.playing[ev] = entry
        state.lastPlay = entry
    end
    self:showNote(state, semis)
end

function Bass:noteOff(ev, state, track, isPlayback)
    local voice
    if isPlayback then
        local p = state.playing[ev]
        voice = p and p.voice                         -- entry stays: its tail may still bend
    else
        voice = state.voices[ev]
    end
    if voice and voice.noteOff then voice:noteOff() end
end

-- Live pitch change from a handle (B5)
function Bass:bendTo(ev, fields, state, track)
    local voice = state.voices[ev]
    if voice and voice.setPitch then
        voice.glideRate = self:getGlideRate(state)
        voice:setPitch(fields.semis)
        self:showNote(state, fields.semis)
    end
end

Bass.TRACE_SAMPLES = 72            -- 1.2 s at 60 fps

-- The voice the stage view follows: the newest live note while it sounds,
-- otherwise the newest playback note
function Bass:getDisplayVoice(state)
    local h = state.handles[#state.handles]
    local v = h and state.voices[h.ev]
    if v and v.isSounding and v:isSounding() then return v, h.ev end
    local p = state.lastPlay
    if p and p.voice.isSounding and p.voice:isSounding() then return p.voice end
    return nil
end

-- Pitch trace samples, oldest first (false = silent)
function Bass:getTrace(state)
    local out, n = {}, self.TRACE_SAMPLES
    for i = 1, n do
        local idx = ((state.traceHead + i - 1) % n) + 1
        local v = state.trace[idx]
        if v == nil then v = false end
        out[i] = v
    end
    return out
end

function Bass:sampleTrace(state)
    local v = self:getDisplayVoice(state)
    local n = self.TRACE_SAMPLES
    state.traceHead = (state.traceHead % n) + 1
    if v and v.envelope then
        local level = v:envelope() * v.vel
        state.trace[state.traceHead] = { semis = v.currentSemis, level = level, released = v.releasedAt ~= nil }
        -- the oscilloscope follows the real voice
        state.oscFreqRatio = 2.0 ^ (v.currentSemis / 12.0)
        state.oscAmp = math_max(0.08, math.min(1.0, level * 1.6))
    else
        state.trace[state.traceHead] = false
    end
end

-- Playback: apply recorded bends (including the release tail); drop notes
-- that have gone silent
function Bass:updateVoices(dt, state, track)
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
            local kf = Instruments_bendAt(ev, p.elapsed)
            local target = kf and kf.semis or ev.semis
            if target and target ~= p.semis then
                p.semis = target
                v.glideRate = self:getGlideRate(state)
                v:setPitch(target)
                self:showNote(state, target)
            end
        end
    end
end

return Bass
