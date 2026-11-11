-- ============================================================================
-- src/instruments/bass.lua — "Compass" Ribbon Bass & Lead Instrument Module
-- ============================================================================

local Theory = require("src.theory")
local Input  = require("src.input")
local Synth  = require("src.synth")

local math_max   = math.max

local Bass = {
    id = "bass",
    name = "RIBBON BASS",
    shortName = "BASS",
    title = "RIBBON BASS & LEAD",
    patchName = "SUB RIBBON",
    defaultGridIndex = 3, -- 1/16
    COMPASS_DEGREE_MAP = {
        DOWN       = 1,
        DOWN_LEFT  = 2,
        LEFT       = 3,
        UP_LEFT    = 4,
        UP         = 5,
        UP_RIGHT   = 6,
        RIGHT      = 7,
        DOWN_RIGHT = 8,
        NEUTRAL    = 1,
    },
}

function Bass:newState()
    return {
        activeDegree = 1,
        lastSemis = 0,
        sustainedVoice = nil,
        oscPhase = 0.0,
        oscAmp = 0.08,
        oscFreqRatio = 1.0,
        lastArticulation = "PLUCK",
    }
end

function Bass:updateVisuals(dt, state)
    state.oscAmp = math_max(0.08, state.oscAmp - dt * 2.2)
    state.oscPhase = state.oscPhase + dt * 18.0 * state.oscFreqRatio
end

function Bass:updateInput(dt, state, track, emitEvent)
    local dirKey = Input:get8WayDirection()
    local deg = self.COMPASS_DEGREE_MAP[dirKey] or 1
    state.activeDegree = deg

    local octShift = 0
    if Input.down.L1 then octShift = octShift - 12 end
    if Input.down.R1 then octShift = octShift + 12 end
    local baseSemis = Theory:getScaleDegreeSemis(deg) + octShift

    if state.sustainedVoice and (not state.sustainedVoice.source or not state.sustainedVoice.source:isPlaying()) then
        state.sustainedVoice = nil
    end

    if Input.down.A and state.sustainedVoice then
        state.sustainedVoice.hasGlide = true
        state.sustainedVoice.targetSemis = baseSemis
        state.oscFreqRatio = 2.0 ^ (baseSemis / 12.0)
    end

    -- One-shots for now (A7/Phase B make them sustain). Events store the
    -- degree and octave as well as the absolute pitch (SPEC §8.2).
    local octave = octShift / 12
    local function note(action, semis, vel, decay, extra)
        local ev = { action = action, degree = deg, octave = octave, semis = semis, vel = vel, decay = decay }
        for k, v in pairs(extra or {}) do ev[k] = v end
        emitEvent(ev)
    end

    if Input.pressed.B then
        state.lastArticulation = "PLUCK"
        note("B", baseSemis, 0.88, 0.48)
    end
    if Input.pressed.A then
        state.lastArticulation = "GLIDE"
        note("A", baseSemis, 0.88, 1.35, { glideFrom = state.lastSemis })
    end
    if Input.pressed.Y then
        state.lastArticulation = "+OCT POP"
        note("Y", baseSemis + 12, 0.90, 0.42)
    end
    if Input.pressed.X then
        state.lastArticulation = "+5TH VIB"
        note("X", baseSemis + 7, 0.85, 0.95)
    end
end

function Bass:noteOn(ev, state, track, isPlayback)
    local semis = ev.semis or 0
    local voice = Synth:trigger("bass", semis, ev.vel or 0.85, ev.decay or 1.0, ev.glideFrom, track.volume, track)
    if voice and ev.action == "X" then
        voice.vibrato = true
    end
    if not isPlayback and ev.action == "A" then
        state.sustainedVoice = voice
    end
    state.lastSemis = semis
    state.oscAmp = 1.0
    state.oscFreqRatio = 2.0 ^ (semis / 12.0)
end

return Bass
