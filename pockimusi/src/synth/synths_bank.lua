-- ============================================================================
-- src/synth/synths_bank.lua — The pitched sound pool (SPEC §6)
--
-- One catalogue of patches for every pitched instrument. Each patch says
-- what it has (an attack one-shot, a seamless loop, a bright layer) and the
-- instruments take what they can play: the Pad needs a loop, the others take
-- anything. The order here is the order in the Track page picker, group by
-- group; an instrument's own group comes first in its list.
--
-- Patches marked `core` are generated at boot (the instruments' defaults and
-- the first sounds); the others the first time they are selected.
--
-- Attack one-shots may contain anything (noise, inharmonic partials, pitch
-- sweeps). Loops must repeat exactly: whole harmonics of the fundamental's
-- angle, or of the whole loop's angle (SWARM).
-- ============================================================================

local Config      = require("src.config")
local clamp       = Config.clamp
local tanh_approx = Config.tanh_approx
local TWO_PI      = Config.TWO_PI

local math_sin   = math.sin
local math_exp   = math.exp
local math_floor = math.floor

local SynthsBank = { PAD_VOICES = 12 }

SynthsBank.GROUPS = { "BASS", "LEAD", "PAD", "PLUCK", "ODD" }

local C2, C3, C4 = 65.41, 130.81, 261.63

local function h(a, k) return math_sin(a * k) end

-- Register one patch. `def.gen` holds the generators; pool names follow the
-- patch id unless given.
local function add(Synth, id, def)
    local gen = def.gen or {}
    def.gen = gen
    if gen.attack then def.attack = def.attack or id end
    if gen.loop then
        def.loop = id .. "_loop"
        def.tune = Synth:loopTune(gen.freq)
    end
    if gen.bright then def.bright = id .. "_bright" end
    Synth:definePatch(id, def)
    if def.core then Synth:preparePatch(id) end
end

function SynthsBank.build(Synth)
    -- =======================================================================
    -- BASS: 0 semitones = C3. Loops sit on a C2 fundamental, so the note is
    -- harmonic 2 (and a sub can sit an octave below it).
    -- =======================================================================

    -- SAW: filter-swept saw over a square sub
    add(Synth, "bass_saw", { label = "SAW", full = "SAW BASS", group = "BASS", octave = 3, core = true,
        attack = "bass", sustain = 0.55, xfade = 0.18, release = 0.10,
        gen = {
            attack = { dur = 0.6, voices = 8, fn = function(t)
                local w = TWO_PI * C3 * t
                local filterEnv = math_exp(-t * 10.5)
                local saw = 0.0
                for k = 1, 9 do
                    local harmAmp = (1.0 / k) * math_exp(-(k - 1) * (0.18 + (1.0 - filterEnv) * 0.55))
                    saw = saw + math_sin(w * k) * harmAmp
                end
                local subPhase = (t * C3 * 0.5) % 1.0
                local subSq = (subPhase < 0.5 and 1.0 or -1.0) * 0.38
                local resPeak = math_sin(w * 3.0) * 0.26 * math_exp(-t * 14.0)
                local attack = clamp(t / 0.0025, 0.0, 1.0)
                local env = attack * math_exp(-t * 3.4)
                return tanh_approx((saw * 0.65 + subSq + resPeak) * env * 1.45) * 0.82
            end },
            freq = C2, voices = 6,
            loop = function(a)
                local saw = 0.0
                for k = 1, 9 do
                    saw = saw + h(a, 2 * k) * (1.0 / k) * math_exp(-(k - 1) * 0.55)
                end
                local sub = (h(a, 1) >= 0 and 1.0 or -1.0) * 0.30
                return tanh_approx((saw * 0.65 + sub) * 1.2) * 0.75
            end,
        } })

    -- SUB: round and deep. Mostly the fundamental, a soft octave-down sine
    -- underneath, a touch of second harmonic; a small click on the attack.
    add(Synth, "bass_sub", { label = "SUB", full = "SUB BASS", group = "BASS", octave = 3, core = true,
        sustain = 0.6, xfade = 0.15, release = 0.12,
        gen = {
            attack = { dur = 0.6, voices = 8, fn = function(t)
                local w = TWO_PI * C3 * t
                local click = math_sin(w * 4.0) * 0.18 * math_exp(-t * 60.0)
                local body = math_sin(w) * 0.75 + math_sin(w * 0.5) * 0.35 + math_sin(w * 2.0) * 0.12 * math_exp(-t * 6.0)
                local attack = clamp(t / 0.004, 0.0, 1.0)
                local env = attack * (0.55 + 0.45 * math_exp(-t * 5.0)) * math_exp(-t * 1.2)
                return tanh_approx((body + click) * env * 1.3) * 0.78
            end },
            freq = C2, voices = 6,
            loop = function(a)
                return tanh_approx(h(a, 2) * 0.75 + h(a, 1) * 0.35 + h(a, 4) * 0.06) * 0.72
            end,
        } })

    -- PLUCK: sharp, bright attack that closes fast, then a soft triangle-ish
    -- body that rings out. Notes overlap.
    add(Synth, "bass_pluck", { label = "PLUCK", full = "PLUCK BASS", group = "BASS", octave = 3, core = true,
        sustain = 0.25, xfade = 0.10, release = 0.45, overlap = true,
        gen = {
            attack = { dur = 0.7, voices = 10, fn = function(t)
                local w = TWO_PI * C3 * t
                local bright = math_exp(-t * 22.0)
                local s = 0.0
                for k = 1, 12 do
                    s = s + math_sin(w * k) * (1.0 / k) * math_exp(-(k - 1) * (0.08 + (1.0 - bright) * 0.9))
                end
                local attack = clamp(t / 0.0015, 0.0, 1.0)
                local env = attack * (0.35 * math_exp(-t * 1.8) + 0.65 * math_exp(-t * 9.0))
                return tanh_approx(s * env * 1.6) * 0.8
            end },
            freq = C2, voices = 8,
            loop = function(a)
                return (h(a, 2) * 0.8 + h(a, 6) * (0.8 / 9) + h(a, 10) * (0.8 / 25) + h(a, 4) * 0.08) * 0.7
            end,
        } })

    -- 808: a long sub that drops onto its pitch, lightly driven. Made for GLIDE.
    add(Synth, "bass_808", { label = "808", full = "808 SUB", group = "BASS", octave = 3,
        sustain = 0.5, xfade = 0.30, release = 0.35,
        gen = {
            attack = { dur = 1.4, voices = 6, fn = function(t)
                -- the pitch falls from 2.5x to 1x in about 50 ms
                local phase = TWO_PI * C3 * (t + (1.5 / 40.0) * (1.0 - math_exp(-t * 40.0)))
                local click = math_sin(phase * 3.0) * 0.12 * math_exp(-t * 90.0)
                local attack = clamp(t / 0.002, 0.0, 1.0)
                local env = attack * (0.35 * math_exp(-t * 6.0) + 0.65 * math_exp(-t * 1.3))
                return tanh_approx((math_sin(phase) * 1.6 + click) * env) * 0.8
            end },
            freq = C2, voices = 6,
            loop = function(a)
                return tanh_approx(h(a, 2) * 1.3) * 0.72
            end,
        } })

    -- REESE: two saws a few cents apart over a sine sub, the drum and bass
    -- bass. Looped the way SWARM is: 96 periods of C2, the saws on harmonics
    -- 191 and 193 of the whole loop (the note is 192), so they beat about
    -- 1.4 times a second at C3 and still repeat exactly. The bright layer
    -- (the saws' upper harmonics) is what WOBBLE opens and closes.
    local function reeseSaws(loopAngle, from, to, tilt)
        local s = 0.0
        for m = from, to do
            local amp = (1.0 / m) * math_exp(-(m - 1) * tilt)
            s = s + (math_sin(loopAngle * 191 * m) + math_sin(loopAngle * 193 * m)) * amp
        end
        return s
    end
    add(Synth, "bass_reese", { label = "REESE", full = "REESE BASS", group = "BASS", octave = 3,
        sustain = 0.5, xfade = 0.05, release = 0.12,
        gen = {
            attack = { dur = 0.35, voices = 8, fn = function(t)
                local open = math_exp(-t * 9.0)
                local s = 0.0
                for k = 1, 10 do
                    local amp = (1.0 / k) * math_exp(-(k - 1) * (0.30 - open * 0.22))
                    s = s + (math_sin(TWO_PI * C3 * 0.9959 * k * t) + math_sin(TWO_PI * C3 * 1.0041 * k * t)) * amp
                end
                local sub = math_sin(TWO_PI * C3 * 0.5 * t) * 0.45
                local env = clamp(t / 0.003, 0.0, 1.0) * clamp((0.35 - t) / 0.25, 0.0, 1.0)
                return tanh_approx((s * 0.42 + sub) * env * 1.3) * 0.55
            end },
            freq = C2, periods = 96, voices = 6,
            loop = function(_, loopAngle)
                local saws = reeseSaws(loopAngle, 1, 7, 0.30)
                local sub = math_sin(loopAngle * 96) * 0.45
                return tanh_approx((saws * 0.42 + sub) * 1.25) * 0.74
            end,
            bright = function(_, loopAngle)
                return tanh_approx(reeseSaws(loopAngle, 4, 16, 0.04) * 0.55) * 0.42
            end,
        } })

    -- DNB SUB: a pure sine with a tight click, nothing soft at the start, for
    -- rolling basslines that sit under the kick (SUB has a softer 4 ms attack)
    add(Synth, "bass_dnbsub", { label = "DNB SUB", full = "DNB SUB", group = "BASS", octave = 3,
        sustain = 0.62, xfade = 0.05, release = 0.06,
        gen = {
            attack = { dur = 0.25, voices = 8, fn = function(t)
                -- the body hands over to the loop as it fades in (0.05 s)
                local w = TWO_PI * C3 * t
                local click = math_sin(TWO_PI * 1900 * t) * 0.16 * math_exp(-t * 160.0)
                local env = clamp(t / 0.0008, 0.0, 1.0) * math_exp(-t * 22.0) * clamp((0.25 - t) / 0.05, 0.0, 1.0)
                return tanh_approx((math_sin(w) * 0.95 + click) * env * 1.15) * 0.62
            end },
            freq = C2, voices = 6,
            loop = function(a)
                return tanh_approx(h(a, 2) * 1.15 + h(a, 4) * 0.03) * 0.72
            end,
        } })

    -- NEURO: an FM growl. The dark layer is a low-index FM tone; the bright
    -- layer turns the index up and puts a vowel on it ("yoi"), so WOBBLE and
    -- the Pad's brightness make it talk. Modulators on whole harmonics, so it
    -- loops.
    local function formant(k, f0, f1, f2)
        local f = k * f0
        local d1, d2 = (f - f1) / 160.0, (f - f2) / 240.0
        return math_exp(-d1 * d1) + 0.8 * math_exp(-d2 * d2) + 0.08
    end
    add(Synth, "bass_neuro", { label = "NEURO", full = "NEURO GROWL", group = "BASS", octave = 3,
        sustain = 0.6, xfade = 0.02, release = 0.10,
        gen = {
            freq = C2, voices = 6,
            loop = function(a)
                local m = h(a, 2) * 0.9 + h(a, 4) * 0.3
                return tanh_approx((math_sin(a * 2 + m) * 0.9 + h(a, 1) * 0.35) * 1.4) * 0.7
            end,
            bright = function(a)
                local s = 0.0
                for k = 2, 30 do s = s + h(a, k) * formant(k, C2, 620.0, 1150.0) / math.sqrt(k) end
                local fm = math_sin(a * 2 + h(a, 6) * 2.6 + h(a, 2) * 1.4)
                return tanh_approx((s * 0.55 + fm * 0.45) * 1.8) * 0.58
            end,
        } })

    -- HOOVER: detuned pulses that dip in pitch and swoop back up on the
    -- attack, the rave sound. Three pulses (30 % wide) on harmonics 191,
    -- 192 and 193 of a 96-period loop.
    local function pulseAmp(k) return math_sin(math.pi * k * 0.3) / k end
    add(Synth, "bass_hoover", { label = "HOOVER", full = "HOOVER", group = "BASS", octave = 3,
        sustain = 0.55, xfade = 0.16, release = 0.18,
        gen = {
            attack = { dur = 0.4, voices = 8, fn = function(t)
                -- pitch: down 3 semitones at once, back up over ~150 ms
                local dip = -3.0 * math_exp(-t * 18.0)
                local ratio = 2.0 ^ (dip / 12.0)
                local s = 0.0
                for k = 1, 12 do
                    local amp = pulseAmp(k)
                    local base = TWO_PI * C3 * k * t * ratio
                    s = s + (math_sin(base * 0.993) + math_sin(base) + math_sin(base * 1.007)) * amp
                end
                local env = clamp(t / 0.004, 0.0, 1.0) * clamp((0.4 - t) / 0.25, 0.0, 1.0)
                return tanh_approx(s * 0.45 * env) * 0.72
            end },
            freq = C2, periods = 96, voices = 6,
            loop = function(_, loopAngle)
                local s = 0.0
                for k = 1, 12 do
                    local amp = pulseAmp(k)
                    s = s + (math_sin(loopAngle * 191 * k) + math_sin(loopAngle * 192 * k)
                             + math_sin(loopAngle * 193 * k)) * amp
                end
                return tanh_approx(s * 0.45) * 0.8
            end,
        } })

    -- =======================================================================
    -- LEAD: 0 semitones = C4. Loops sit on a C3 fundamental and use its even
    -- harmonics. SQUARE and SAW have no attack one-shot: the loop fades in
    -- within a few milliseconds.
    -- =======================================================================

    -- SQUARE: hollow, the classic lead (odd harmonics of the note)
    add(Synth, "lead_square", { label = "SQUARE", full = "SQUARE LEAD", group = "LEAD", core = true,
        sustain = 0.5, xfade = 0.012, release = 0.09,
        gen = { freq = C3, voices = 6, loop = function(a)
            local s = 0.0
            for k = 1, 15, 2 do s = s + h(a, 2 * k) / k end
            return s * 0.42
        end } })

    -- SAW: bright and a little driven
    add(Synth, "lead_saw", { label = "SAW", full = "SAW LEAD", group = "LEAD", core = true,
        sustain = 0.5, xfade = 0.012, release = 0.10,
        gen = { freq = C3, voices = 6, loop = function(a)
            local s = 0.0
            for k = 1, 14 do s = s + h(a, 2 * k) * (1.0 / k) * math_exp(-(k - 1) * 0.12) end
            return tanh_approx(s * 0.9) * 0.5
        end } })

    -- PLUCK: a bright pick that closes fast over a soft ringing body. Notes overlap.
    add(Synth, "lead_pluck", { label = "PLUCK", full = "PLUCK LEAD", group = "LEAD", core = true,
        sustain = 0.22, xfade = 0.08, release = 0.40, overlap = true,
        gen = {
            attack = { dur = 0.6, voices = 10, fn = function(t)
                local w = TWO_PI * C4 * t
                local bright = math_exp(-t * 26.0)
                local s = 0.0
                for k = 1, 10 do
                    s = s + math_sin(w * k) * (1.0 / k) * math_exp(-(k - 1) * (0.10 + (1.0 - bright) * 0.9))
                end
                local attack = clamp(t / 0.0015, 0.0, 1.0)
                local env = attack * (0.30 * math_exp(-t * 2.2) + 0.70 * math_exp(-t * 11.0))
                return tanh_approx(s * env * 1.5) * 0.75
            end },
            freq = C3, voices = 8,
            loop = function(a)
                return (h(a, 2) * 0.8 + h(a, 6) * (0.8 / 9) + h(a, 10) * (0.8 / 25) + h(a, 4) * 0.06) * 0.6
            end,
        } })

    -- KEYS: a glassy FM electric piano. The modulator sits an octave above
    -- the note and dies away, so the tone starts bright and settles. Notes
    -- overlap, which suits arps.
    add(Synth, "lead_keys", { label = "KEYS", full = "FM KEYS", group = "LEAD",
        sustain = 0.20, xfade = 0.20, release = 0.50, overlap = true,
        gen = {
            attack = { dur = 1.1, voices = 10, fn = function(t)
                local w = TWO_PI * C4 * t
                local index = 2.2 * math_exp(-t * 9.0) + 0.3
                local s = math_sin(w + math_sin(w * 2.0) * index)
                local attack = clamp(t / 0.002, 0.0, 1.0)
                local env = attack * (0.55 * math_exp(-t * 7.0) + 0.45 * math_exp(-t * 2.0))
                return s * env * 0.7
            end },
            freq = C3, voices = 8,
            loop = function(a)
                return math_sin(a * 2 + math_sin(a * 4) * 0.3) * 0.6
            end,
        } })

    -- SUPERSAW: five saws spread around the note, the trance and EDM lead.
    -- 96 periods of C3, the saws on harmonics 189, 191, 192, 193 and 195 of
    -- the whole loop (the note is 192): wide and moving, less sub than SWARM.
    add(Synth, "lead_supersaw", { label = "SUPERSAW", full = "SUPERSAW", group = "LEAD",
        sustain = 0.5, xfade = 0.012, release = 0.22,
        gen = { freq = C3, periods = 96, voices = 6, loop = function(_, loopAngle)
            local s = 0.0
            for m = 1, 10 do
                local amp = (1.0 / m) * math_exp(-(m - 1) * 0.06)
                s = s + (math_sin(loopAngle * 189 * m) * 0.6 + math_sin(loopAngle * 191 * m) * 0.85
                         + math_sin(loopAngle * 192 * m) + math_sin(loopAngle * 193 * m) * 0.85
                         + math_sin(loopAngle * 195 * m) * 0.6) * amp
            end
            return tanh_approx(s * 0.3) * 0.7
        end } })

    -- =======================================================================
    -- PAD: 0 semitones = C4, on a C3 fundamental. Two seamless layers each:
    --   dark    the body of the sound, always playing
    --   bright  upper harmonics, mixed in by the voice's brightness; a little
    --           of the body's main harmonic too, so the detuned layer beats
    --           slowly against the dark one (movement)
    -- No attack one-shot (the voice's attack time shapes the start), except
    -- BELL's strike, which the Pad plays on fast attacks only.
    -- =======================================================================
    -- Scattered partials for ATMOS's and VOX's breath: { loop harmonic, phase }.
    -- A 24-period loop of C3 has a harmonic every ~5.45 Hz; these sit between
    -- about 2 and 7 kHz. Fixed numbers, so the sound is the same every boot.
    local AIR = {}
    do
        local seed = 12345
        local function rnd()
            seed = (seed * 16807) % 2147483647
            return seed / 2147483647
        end
        for j = 1, 48 do AIR[j] = { 370 + math_floor(rnd() * 920), rnd() * TWO_PI } end
    end

    local pads = {
        { id = "pad_warm", label = "WARM", full = "WARM PAD", core = true,   -- octave-down sub, the note, soft upper harmonics
          dark = function(a)
              return (h(a, 1) * 0.25 + h(a, 2) * 0.55 + h(a, 3) * 0.22 + h(a, 4) * 0.14 + h(a, 6) * 0.05) * 0.62
          end,
          bright = function(a)
              local s = h(a, 2) * 0.12
              for k = 3, 10 do s = s + h(a, 2 * k) * (0.5 / k) end
              return s * 0.6
          end },
        { id = "pad_bell", label = "BELL", full = "GLASS BELL", core = true,   -- glassy: harmonics of C5
          attack = { dur = 0.5, voices = SynthsBank.PAD_VOICES, fn = function(t)
              -- the strike: a short FM ping (C5 at 0 semitones, like the loop)
              local f = 523.25
              local mod = math_sin(TWO_PI * f * 3.5 * t) * 1.8 * math_exp(-t * 12.0)
              local s = math_sin(TWO_PI * f * t + mod) * 0.6 + math_sin(TWO_PI * f * 2.0 * t) * 0.25
              return s * clamp(t / 0.002, 0.0, 1.0) * math_exp(-t * 9.0) * 0.5
          end },
          dark = function(a)
              return (h(a, 4) * 0.5 + h(a, 8) * 0.3 + h(a, 12) * 0.15 + h(a, 16) * 0.08) * 0.55
          end,
          bright = function(a)
              return (h(a, 8) * 0.08 + h(a, 12) * 0.20 + h(a, 16) * 0.12 + h(a, 20) * 0.20) * 0.6
          end },
        { id = "pad_choir", label = "CHOIR", full = "CHOIR", core = true,    -- "ooh"; brightness opens it towards "ah"
          dark = function(a)
              return (h(a, 2) * 0.40 + h(a, 4) * 0.30 + h(a, 6) * 0.18) * 0.62
          end,
          bright = function(a)
              local s = h(a, 2) * 0.08
              for k = 7, 14 do s = s + h(a, k) * (0.11 - (k - 7) * 0.008) end
              return s * 0.6
          end },
        { id = "pad_drone", label = "DRONE", full = "DARK DRONE", core = true,    -- dark, sub-heavy, driven; brightness adds a buzz
          dark = function(a)
              return tanh_approx(h(a, 1) * 0.8 + h(a, 2) * 0.55 + h(a, 3) * 0.25) * 0.62
          end,
          bright = function(a)
              local s = h(a, 1) * 0.10
              for k = 4, 10 do s = s + h(a, k) * (0.35 / (k - 2)) end
              return s * 0.6
          end },
        { id = "pad_strings", label = "STRINGS", full = "STRING ENSEMBLE",   -- a soft saw; brightness adds the bow's edge
          dark = function(a)
              local s = 0.0
              for k = 1, 7 do s = s + h(a, 2 * k) * (1.0 / k) * math_exp(-(k - 1) * 0.45) end
              return s * 0.42
          end,
          bright = function(a)
              local s = h(a, 2) * 0.10
              for k = 3, 16 do s = s + h(a, 2 * k) * (0.9 / k) * ((k % 2 == 0) and 1.0 or 0.8) end
              return s * 0.38
          end },
        { id = "pad_atmos", label = "ATMOS", full = "ATMOSPHERE",   -- airy and soft; brightness lets in the air
          dark = function(a)
              return (h(a, 2) * 0.55 + h(a, 4) * 0.20 + h(a, 3) * 0.10 + h(a, 6) * 0.06) * 0.62
          end,
          bright = function(a, loopAngle)
              -- "air": many quiet partials scattered over 2-7 kHz on harmonics
              -- of the whole loop, so it hisses and still repeats exactly
              local s = h(a, 2) * 0.08
              for j = 1, #AIR do s = s + math_sin(loopAngle * AIR[j][1] + AIR[j][2]) * 0.035 end
              return s * 0.6
          end },
        { id = "pad_vox", label = "VOX", full = "VOX AH-OH",          -- a breathy voice: "oh", brightness opens it to "ah"
          dark = function(a)
              local s = 0.0
              for k = 1, 12 do s = s + h(a, 2 * k) * formant(k, C4, 450.0, 800.0) / k end
              return s * 0.55
          end,
          bright = function(a, loopAngle)
              local s = 0.0
              for k = 1, 12 do s = s + h(a, 2 * k) * formant(k, C4, 760.0, 1250.0) / k end
              for j = 1, 24 do s = s + math_sin(loopAngle * (AIR[j][1] - 160) + AIR[j][2]) * 0.02 end
              return s * 0.55
          end },
    }
    for _, pad in ipairs(pads) do
        add(Synth, pad.id, { label = pad.label, full = pad.full, group = "PAD", core = pad.core,
            sustain = 0.6, xfade = 0.25, release = 0.9,
            gen = { attack = pad.attack, freq = C3, voices = SynthsBank.PAD_VOICES,
                    loop = pad.dark, bright = pad.bright } })
    end

    -- =======================================================================
    -- PLUCK: 0 semitones = C4. Sounds that ring out by themselves; the first
    -- ones are one-shots with no loop.
    -- =======================================================================

    -- HARP: the Chord Harp's own sound, an FM pluck with a shimmer
    add(Synth, "harp", { label = "HARP", full = "STARLIGHT PLUCK", group = "PLUCK", core = true,
        release = 0.6,
        gen = { attack = { dur = 1.2, voices = 14, fn = function(t)
            local w = TWO_PI * C4 * t
            local modIndex = 2.6 * math_exp(-t * 14.0) + 0.22 * math_exp(-t * 2.5)
            local mod = math_sin(w * 2.0) * modIndex
            local shimmer = math_sin(w * 3.0) * 0.45 * math_exp(-t * 22.0)
            local carrier = math_sin(w + mod + shimmer)
            local subWarmth = math_sin(w * 0.5) * 0.18 * math_exp(-t * 4.0)
            local attack = clamp(t / 0.003, 0.0, 1.0)
            local env = attack * (0.72 * math_exp(-t * 2.8) + 0.28 * math_exp(-t * 0.95))
            return (carrier * 0.82 + subWarmth) * env * 0.72
        end } } })

    -- NYLON: a plucked string, made the way a string works (Karplus-Strong):
    -- a burst of noise goes round a delay one period long and loses its top
    -- on every pass.
    add(Synth, "pluck_nylon", { label = "NYLON", full = "NYLON STRING", group = "PLUCK",
        release = 0.5,
        gen = { attack = { dur = 1.5, voices = 10, make = function(S)
            local N = 169                      -- less the filter's half sample: 261.7 Hz
            local buf, prev, mean = {}, 0.0, 0.0
            for j = 1, N do
                prev = prev + (S.whiteNoise() - prev) * 0.4      -- a soft pick
                buf[j] = prev
                mean = mean + prev / N
            end
            for j = 1, N do buf[j] = buf[j] - mean end
            local pos = 1
            return function(t)
                local nxt = (pos % N) + 1
                local out = buf[pos]
                buf[pos] = (out + buf[nxt]) * 0.5 * 0.9988
                pos = nxt
                return tanh_approx(out * 3.2) * clamp(t / 0.001, 0.0, 1.0) * math_exp(-t * 0.8) * 0.85
            end
        end } } })

    -- RHODES: an electric piano. A mellow FM body with a bark at the start
    -- and a short metallic tine on top; held notes keep a soft tone.
    add(Synth, "pluck_rhodes", { label = "RHODES", full = "RHODES PIANO", group = "PLUCK",
        sustain = 0.16, xfade = 0.25, release = 0.45, overlap = true,
        gen = {
            attack = { dur = 1.6, voices = 10, fn = function(t)
                local w = TWO_PI * C4 * t
                local index = 1.5 * math_exp(-t * 6.0) + 0.25
                local body = math_sin(w + math_sin(w) * index)
                local tine = math_sin(w * 14.0 + math_sin(w) * 0.6) * 0.14 * math_exp(-t * 28.0)
                local attack = clamp(t / 0.002, 0.0, 1.0)
                local env = attack * (0.5 * math_exp(-t * 5.0) + 0.5 * math_exp(-t * 1.5))
                return (body * 0.75 + tine) * env * 0.8
            end },
            freq = C3, voices = 8,
            loop = function(a)
                return math_sin(a * 2 + math_sin(a * 2) * 0.25) * 0.6
            end,
        } })

    -- KALIMBA: a thumb piano. The tine's overtones are not harmonics, so
    -- this one is a one-shot only.
    add(Synth, "pluck_kalimba", { label = "KALIMBA", full = "KALIMBA", group = "PLUCK",
        release = 0.5,
        gen = { attack = { dur = 1.0, voices = 10, make = function(S)
            return function(t)
                local w = TWO_PI * C4 * t
                local tick = S.whiteNoise() * 0.25 * math_exp(-t * 450.0)
                local s = math_sin(w) * math_exp(-t * 4.0)
                        + math_sin(w * 5.6) * 0.22 * math_exp(-t * 16.0)
                        + math_sin(w * 9.3) * 0.10 * math_exp(-t * 40.0)
                        + math_sin(w * 2.0) * 0.08 * math_exp(-t * 7.0)
                return (s + tick) * clamp(t / 0.001, 0.0, 1.0) * 0.68
            end
        end } } })

    -- RAVE STAB: an organ chord stab, the early-90s rave and house sound.
    -- Drawbar-style harmonics, slightly detuned pairs for width, a key click,
    -- and a fast decay so chords hit and get out of the way. Rings out.
    add(Synth, "pluck_stab", { label = "STAB", full = "RAVE STAB", group = "PLUCK",
        release = 0.25,
        gen = { attack = { dur = 0.7, voices = 14, fn = function(t)
            local w = TWO_PI * C4 * t
            local s = 0.0
            local bars = { { 0.5, 0.35 }, { 1, 0.9 }, { 2, 0.55 }, { 3, 0.35 }, { 4, 0.28 }, { 6, 0.14 }, { 8, 0.10 } }
            for _, b in ipairs(bars) do
                s = s + (math_sin(w * b[1]) + math_sin(w * b[1] * 1.0035) * 0.6) * b[2]
            end
            local click = math_sin(TWO_PI * 3100 * t) * 0.25 * math_exp(-t * 300.0)
            local env = clamp(t / 0.0015, 0.0, 1.0) * (0.55 * math_exp(-t * 9.0) + 0.45 * math_exp(-t * 3.2))
            return tanh_approx((s * 0.38 + click) * env * 1.5) * 0.7
        end } } })

    -- SILENT: plays nothing. For a chord track that drives the followers
    -- without being heard (the Chord Harp only).
    add(Synth, "silent", { label = "SILENT", full = "SILENT (CHORDS ONLY)", group = "PLUCK", silent = true })

    -- =======================================================================
    -- ODD: experiments. 0 semitones = C4 unless noted.
    -- =======================================================================

    -- SHEPARD: only octaves of the note, so the pitch is clear and the octave
    -- is not. On the Pad, brightness moves the weight up the octaves.
    add(Synth, "odd_shepard", { label = "SHEPARD", full = "SHEPARD OCTAVES", group = "ODD",
        sustain = 0.55, xfade = 0.08, release = 0.5,
        gen = { freq = C3, voices = SynthsBank.PAD_VOICES,
            loop = function(a)
                return (h(a, 1) * 0.34 + h(a, 2) * 0.50 + h(a, 4) * 0.36 + h(a, 8) * 0.16) * 0.6
            end,
            bright = function(a)
                return (h(a, 4) * 0.10 + h(a, 8) * 0.40 + h(a, 16) * 0.42 + h(a, 32) * 0.26) * 0.55
            end } })

    -- JUST: harmonics 4, 5, 6 and 7 of a low C: a pure-tuned major chord in
    -- one note, with the "barbershop" seventh. On the Pad, brightness brings
    -- the seventh forward. It ignores the chord's own quality on purpose.
    add(Synth, "odd_just", { label = "JUST", full = "JUST CHORD", group = "ODD",
        sustain = 0.5, xfade = 0.06, release = 0.4,
        gen = { freq = C2, voices = SynthsBank.PAD_VOICES,
            loop = function(a)
                return (h(a, 4) * 0.50 + h(a, 5) * 0.34 + h(a, 6) * 0.34 + h(a, 7) * 0.12 + h(a, 8) * 0.10) * 0.58
            end,
            bright = function(a)
                return (h(a, 7) * 0.42 + h(a, 10) * 0.16 + h(a, 12) * 0.16 + h(a, 14) * 0.14) * 0.6
            end } })

    -- THROAT: overtone singing. A buzzing drone with one narrow peak of
    -- harmonics; brightness moves the peak from the 8th harmonic to the 12th
    -- (a fifth up), so the Pad's D-pad whistles over the note. 0 = C3.
    add(Synth, "odd_throat", { label = "THROAT", full = "THROAT SINGER", group = "ODD", octave = 3,
        sustain = 0.55, xfade = 0.12, release = 0.4,
        gen = { freq = C3, voices = SynthsBank.PAD_VOICES,
            loop = function(a)
                local s = 0.0
                for k = 1, 6 do s = s + h(a, k) / (k * math.sqrt(k)) end
                return (s * 0.55 + h(a, 7) * 0.07 + h(a, 8) * 0.24 + h(a, 9) * 0.07) * 0.6
            end,
            bright = function(a)
                return (h(a, 10) * 0.10 + h(a, 11) * 0.14 + h(a, 12) * 0.50 + h(a, 13) * 0.14) * 0.62
            end } })

    -- WAVE: a 32-step, 4-bit wavetable, as on an old handheld's wave channel.
    -- The steps are left rough on purpose.
    local waveTable = {}
    for i = 0, 31 do
        local x = TWO_PI * (i + 0.5) / 32
        local v = math_sin(x) * 0.62 + math_sin(x * 2.0) * 0.26 + math_sin(x * 5.0) * 0.12
        waveTable[i] = math_floor((v * 0.5 + 0.5) * 15 + 0.5) / 7.5 - 1.0
    end
    add(Synth, "odd_wave", { label = "WAVE", full = "4-BIT WAVE", group = "ODD",
        sustain = 0.5, xfade = 0.012, release = 0.08,
        gen = { freq = C3, voices = 8, loop = function(a)
            local phase = (a / TWO_PI * 2.0) % 1.0
            return waveTable[math_floor(phase * 32) % 32] * 0.55
        end } })

    -- GONG: struck metal. Partials that are not harmonics, two of them close
    -- enough to beat; the upper ones bloom after the strike. One-shot only.
    add(Synth, "odd_gong", { label = "GONG", full = "GONG", group = "ODD",
        release = 1.2,
        gen = { attack = { dur = 2.6, voices = 8, fn = function(t)
            local w = TWO_PI * C4 * t
            local bloom = 1.0 - math_exp(-t * 7.0)
            local s = math_sin(w * 0.5) * 0.50 * math_exp(-t * 1.1)
                    + math_sin(w) * 0.40 * math_exp(-t * 1.4)
                    + math_sin(w * 1.012) * 0.30 * math_exp(-t * 1.5)
                    + math_sin(w * 1.48) * 0.26 * bloom * math_exp(-t * 1.9)
                    + math_sin(w * 2.74) * 0.20 * bloom * math_exp(-t * 2.6)
                    + math_sin(w * 3.51) * 0.14 * bloom * math_exp(-t * 3.4)
                    + math_sin(w * 5.33) * 0.10 * math_exp(-t * 9.0)
            return s * clamp(t / 0.002, 0.0, 1.0) * clamp((2.6 - t) / 0.05, 0.0, 1.0) * 0.52
        end } } })

    -- REVERSE: a pluck played backwards. It swells into a hard stop, so the
    -- loudest moment comes late: press early.
    add(Synth, "odd_reverse", { label = "REVERSE", full = "REVERSE PLUCK", group = "ODD",
        release = 0.15,
        gen = { attack = { dur = 0.8, voices = 10, fn = function(t)
            local r = 0.8 - t                        -- time left: the pluck's own clock
            local w = TWO_PI * C4 * r
            local mod = math_sin(w * 2.0) * (2.4 * math_exp(-r * 12.0) + 0.2)
            local env = 0.75 * math_exp(-r * 4.5) + 0.25 * math_exp(-r * 1.6)
            return math_sin(w + mod) * env * clamp(r / 0.004, 0.0, 1.0) * clamp(t / 0.02, 0.0, 1.0) * 0.72
        end } } })

    -- TALK: a voice that says "wah": two vowel peaks slide from "oo" to "ah"
    -- over the attack, and held notes stay on "ah".
    local function vowel(k, f0, f1, f2)
        local f = k * f0
        local d1, d2 = (f - f1) / 140.0, (f - f2) / 190.0
        return (math_exp(-d1 * d1) + 0.7 * math_exp(-d2 * d2) + 0.06) / math.sqrt(k)
    end
    add(Synth, "odd_talk", { label = "TALK", full = "TALKING WAH", group = "ODD",
        sustain = 0.5, xfade = 0.35, release = 0.18,
        gen = {
            attack = { dur = 0.6, voices = 8, fn = function(t)
                local w = TWO_PI * C4 * t
                local open = 1.0 - math_exp(-t * 11.0)            -- 0 = "oo", 1 = "ah"
                local f1, f2 = 330.0 + 420.0 * open, 820.0 + 400.0 * open
                local s = 0.0
                for k = 1, 10 do s = s + math_sin(w * k) * vowel(k, C4, f1, f2) end
                return s * clamp(t / 0.006, 0.0, 1.0) * clamp((0.6 - t) / 0.35, 0.0, 1.0) * 0.55
            end },
            freq = C3, voices = 8,
            loop = function(a)
                local s = 0.0
                for k = 1, 10 do s = s + h(a, 2 * k) * vowel(k, C4, 750.0, 1220.0) end
                return s * 0.6
            end,
        } })

    -- SWARM: three saws a few cents apart. The loop is 96 periods long and
    -- the saws sit on harmonics 191, 192 and 193 of the whole loop, so they
    -- drift against each other and still repeat exactly. The beating gets
    -- faster with the pitch.
    add(Synth, "odd_swarm", { label = "SWARM", full = "SAW SWARM", group = "ODD",
        sustain = 0.5, xfade = 0.03, release = 0.25,
        gen = { freq = C3, periods = 96, voices = 6, loop = function(a, loopAngle)
            local s = 0.0
            for m = 1, 8 do
                local amp = (1.0 / m) * math_exp(-(m - 1) * 0.10)
                s = s + (math_sin(loopAngle * 191 * m) * 0.8 + math_sin(loopAngle * 192 * m)
                         + math_sin(loopAngle * 193 * m) * 0.8) * amp
            end
            return tanh_approx(s * 0.42) * 0.55
        end } })
end

return SynthsBank
