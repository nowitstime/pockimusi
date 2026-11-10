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

return SynthsBank
