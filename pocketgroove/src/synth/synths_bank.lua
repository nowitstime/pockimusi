-- ============================================================================
-- src/synth/synths_bank.lua — Melodic & Granular Procedural Sound Generators
-- ============================================================================

local Config      = require("src.config")
local clamp       = Config.clamp
local tanh_approx = Config.tanh_approx
local TWO_PI      = Config.TWO_PI

local math_sin = math.sin
local math_cos = math.cos
local math_exp = math.exp

local SynthsBank = {}

function SynthsBank.build(Synth, whiteNoise)
    -- Harp / Plucked String Buffer (1.2s, Base Note C4 = 261.63 Hz)
    local harpBaseFreq = 261.63
    local harpSD = Synth:createBuffer(1.2, function(t)
        local w = TWO_PI * harpBaseFreq * t
        local modIndex = 2.6 * math_exp(-t * 14.0) + 0.22 * math_exp(-t * 2.5)
        local mod = math_sin(w * 2.0) * modIndex
        local shimmer = math_sin(w * 3.0) * 0.45 * math_exp(-t * 22.0)
        local carrier = math_sin(w + mod + shimmer)
        local subWarmth = math_sin(w * 0.5) * 0.18 * math_exp(-t * 4.0)
        local attack = clamp(t / 0.003, 0.0, 1.0)
        local env = attack * (0.72 * math_exp(-t * 2.8) + 0.28 * math_exp(-t * 0.95))
        return (carrier * 0.82 + subWarmth) * env * 0.72
    end)

    -- Bass / Synth Buffer (0.6s, Base Note C3 = 130.81 Hz)
    local bassBaseFreq = 130.81
    local bassSD = Synth:createBuffer(0.6, function(t)
        local w = TWO_PI * bassBaseFreq * t
        local filterEnv = math_exp(-t * 10.5)
        local saw = 0.0
        for k = 1, 9 do
            local harmAmp = (1.0 / k) * math_exp(-(k - 1) * (0.18 + (1.0 - filterEnv) * 0.55))
            saw = saw + math_sin(w * k) * harmAmp
        end
        local subPhase = (t * bassBaseFreq * 0.5) % 1.0
        local subSq = (subPhase < 0.5 and 1.0 or -1.0) * 0.38
        local resPeak = math_sin(w * 3.0) * 0.26 * math_exp(-t * 14.0)
        local attack = clamp(t / 0.0025, 0.0, 1.0)
        local env = attack * math_exp(-t * 3.4)
        return tanh_approx((saw * 0.65 + subSq + resPeak) * env * 1.45) * 0.82
    end)

    -- Granular Cloud Buffers (4 procedural textures, 0.42s Hann-windowed)
    local grainDur = 0.42
    local function hannWindow(t, dur)
        return 0.5 * (1.0 - math_cos(TWO_PI * t / dur))
    end

    local grainPadSD = Synth:createBuffer(grainDur, function(t, dur)
        local f = 261.63
        local s = math_sin(TWO_PI * f * t) * 0.5
                + math_sin(TWO_PI * (f * 1.004) * t) * 0.35
                + math_sin(TWO_PI * (f * 1.498) * t) * 0.2
                + math_sin(TWO_PI * (f * 0.5) * t) * 0.25
        return s * hannWindow(t, dur) * 0.65
    end)

    local grainBellSD = Synth:createBuffer(grainDur, function(t, dur)
        local f = 523.25
        local mod = math_sin(TWO_PI * f * 3.5 * t) * 1.8 * math_exp(-t * 8.0)
        local s = math_sin(TWO_PI * f * t + mod) * 0.6 + math_sin(TWO_PI * f * 2.0 * t) * 0.25
        return s * hannWindow(t, dur) * 0.55
    end)

    local choirPrev = 0.0
    local grainChoirSD = Synth:createBuffer(grainDur, function(t, dur)
        local f = 261.63
        local n = whiteNoise()
        choirPrev = choirPrev * 0.82 + n * 0.18
        local vocal = math_sin(TWO_PI * f * t) * 0.4
                    + math_sin(TWO_PI * f * 2.0 * t) * 0.3
                    + math_sin(TWO_PI * f * 3.0 * t) * 0.2
                    + choirPrev * 0.35
        return vocal * hannWindow(t, dur) * 0.60
    end)

    local grainDroneSD = Synth:createBuffer(grainDur, function(t, dur)
        local f = 130.81
        local s = tanh_approx(
            math_sin(TWO_PI * f * t) * 0.8 +
            math_sin(TWO_PI * f * 0.5 * t) * 0.6 +
            math_sin(TWO_PI * f * 1.5 * t) * 0.25
        )
        return s * hannWindow(t, dur) * 0.68
    end)

    Synth:createPool("harp",        harpSD,       14, 1.20)
    Synth:createPool("bass",        bassSD,       8,  0.60)
    Synth:createPool("grain_pad",   grainPadSD,   10, grainDur)
    Synth:createPool("grain_bell",  grainBellSD,  10, grainDur)
    Synth:createPool("grain_choir", grainChoirSD, 10, grainDur)
    Synth:createPool("grain_drone", grainDroneSD, 10, grainDur)
end

-- ---------------------------------------------------------------------------
-- Sustain loop layers (SPEC §9.2). Each loop holds whole periods of a purely
-- harmonic waveform, so it repeats without a click. Detune, noise and
-- inharmonic partials from the one-shot versions are left out on purpose:
-- they can't loop seamlessly in a short buffer (movement comes later from
-- the voice: vibrato, glide, Pad's own chorus).
-- ---------------------------------------------------------------------------
function SynthsBank.buildSustain(Synth)
    local function h(a, k) return math_sin(a * k) end

    -- -----------------------------------------------------------------------
    -- Bass patches (Bass Track page PATCH row). All share the C3 pitch
    -- reference; loops use C2 as the fundamental so the note is harmonic 2.
    --   label    shown on the Track page
    --   overlap  true = notes may overlap (otherwise the bass is mono)
    -- -----------------------------------------------------------------------
    local C3 = 130.81

    -- SAW: today's bass. Attack = the "bass" one-shot; loop = band-limited saw
    -- (softened like the one-shot's settled tone) + square sub an octave down.
    local sawLoop, _, sawTune = Synth:createLoop(65.41, 24, function(a)
        local saw = 0.0
        for k = 1, 9 do
            saw = saw + h(a, 2 * k) * (1.0 / k) * math_exp(-(k - 1) * 0.55)
        end
        local sub = (h(a, 1) >= 0 and 1.0 or -1.0) * 0.30
        return tanh_approx((saw * 0.65 + sub) * 1.2) * 0.75
    end)
    Synth:createLoopPool("bass_saw_loop", sawLoop, 6)
    Synth:definePatch("bass_saw", { label = "SAW", attack = "bass", loop = "bass_saw_loop", tune = sawTune,
                                    sustain = 0.55, xfade = 0.18, release = 0.10 })

    -- SUB: round and deep. Mostly the fundamental, a soft octave-down sine
    -- underneath, a touch of second harmonic; a small click on the attack.
    local subSD = Synth:createBuffer(0.6, function(t)
        local w = TWO_PI * C3 * t
        local click = math_sin(w * 4.0) * 0.18 * math_exp(-t * 60.0)
        local body = math_sin(w) * 0.75 + math_sin(w * 0.5) * 0.35 + math_sin(w * 2.0) * 0.12 * math_exp(-t * 6.0)
        local attack = clamp(t / 0.004, 0.0, 1.0)
        local env = attack * (0.55 + 0.45 * math_exp(-t * 5.0)) * math_exp(-t * 1.2)
        return tanh_approx((body + click) * env * 1.3) * 0.78
    end)
    Synth:createPool("bass_sub", subSD, 8, 0.60)
    local subLoop, _, subTune = Synth:createLoop(65.41, 24, function(a)
        return tanh_approx(h(a, 2) * 0.75 + h(a, 1) * 0.35 + h(a, 4) * 0.06) * 0.72
    end)
    Synth:createLoopPool("bass_sub_loop", subLoop, 6)
    Synth:definePatch("bass_sub", { label = "SUB", attack = "bass_sub", loop = "bass_sub_loop", tune = subTune,
                                    sustain = 0.6, xfade = 0.15, release = 0.12 })

    -- PLUCK: sharp, bright attack that closes fast, then a soft triangle-ish
    -- body that rings out. Notes overlap.
    local pluckSD = Synth:createBuffer(0.7, function(t)
        local w = TWO_PI * C3 * t
        local bright = math_exp(-t * 22.0)
        local s = 0.0
        for k = 1, 12 do
            s = s + math_sin(w * k) * (1.0 / k) * math_exp(-(k - 1) * (0.08 + (1.0 - bright) * 0.9))
        end
        local attack = clamp(t / 0.0015, 0.0, 1.0)
        local env = attack * (0.35 * math_exp(-t * 1.8) + 0.65 * math_exp(-t * 9.0))
        return tanh_approx(s * env * 1.6) * 0.8
    end)
    Synth:createPool("bass_pluck", pluckSD, 10, 0.70)
    local pluckLoop, _, pluckTune = Synth:createLoop(65.41, 24, function(a)
        return (h(a, 2) * 0.8 + h(a, 6) * (0.8 / 9) + h(a, 10) * (0.8 / 25) + h(a, 4) * 0.08) * 0.7
    end)
    Synth:createLoopPool("bass_pluck_loop", pluckLoop, 8)
    Synth:definePatch("bass_pluck", { label = "PLUCK", attack = "bass_pluck", loop = "bass_pluck_loop", tune = pluckTune,
                                      sustain = 0.25, xfade = 0.10, release = 0.45, overlap = true })

    -- Grain textures as sustained patches (become Pad sounds in Phase F).
    -- Fundamental C3 (130.81 Hz); the one-shots' "f" (C4) is harmonic 2.
    local textures = {
        pad = function(a)       -- warm: octave-down sub, fundamental, fifth, octave
            return (h(a, 1) * 0.25 + h(a, 2) * 0.55 + h(a, 3) * 0.22 + h(a, 4) * 0.14 + h(a, 6) * 0.05) * 0.62
        end,
        bell = function(a)      -- glassy: upper harmonics of C5
            return (h(a, 4) * 0.5 + h(a, 8) * 0.3 + h(a, 12) * 0.15 + h(a, 16) * 0.08) * 0.55
        end,
        choir = function(a)     -- "ah": fundamental with a formant bump around harmonics 6-10
            local s = h(a, 2) * 0.40 + h(a, 4) * 0.30 + h(a, 6) * 0.22
            for k = 7, 10 do s = s + h(a, k) * 0.07 end
            return s * 0.58
        end,
        drone = function(a)     -- dark: sub-heavy, driven
            return tanh_approx(h(a, 1) * 0.8 + h(a, 2) * 0.55 + h(a, 3) * 0.25) * 0.62
        end,
    }
    for name, wave in pairs(textures) do
        local sd, _, tune = Synth:createLoop(130.81, 24, wave)
        Synth:createLoopPool("grain_" .. name .. "_loop", sd, 6)
        Synth:definePatch("grain_" .. name, { attack = "grain_" .. name, loop = "grain_" .. name .. "_loop",
                                              tune = tune, sustain = 0.6, xfade = 0.12, release = 0.35 })
    end
end

return SynthsBank
