-- ============================================================================
-- src/synth/drums_bank.lua — 39 Procedural Drum & Percussion Sound Generators
-- ============================================================================

local Config      = require("src.config")
local clamp       = Config.clamp
local tanh_approx = Config.tanh_approx
local TWO_PI      = Config.TWO_PI

local math_sin = math.sin
local math_exp = math.exp
local math_abs = math.abs
local math_pi  = math.pi

local DrumsBank = {}

-- Sounds made in more than one version (PHASE_L L6): the generators draw
-- fresh noise each time, so a second render of a snare or hat is a slightly
-- different hit. Synth:trigger takes the versions in turn.
DrumsBank.VARIANT_COUNT = 3
DrumsBank.VARIANT_CATS = { SNARE = true, HAT = true, CLAP = true }

function DrumsBank.build(Synth, whiteNoise)
    -- Remember how each buffer was made, so variants can be rendered again
    local made = {}
    local createBuffer = Synth.createBuffer
    local function record(self, dur, fn)
        local sd = createBuffer(self, dur, fn)
        made[sd] = { dur, fn }
        return sd
    end
    Synth.createBuffer = record
    local ok, err = pcall(DrumsBank.buildSounds, Synth, whiteNoise)
    Synth.createBuffer = createBuffer
    if not ok then error(err, 0) end

    for _, item in ipairs(Synth.drumCatalog) do
        local sd = item.sd
        local how = sd and (sd.lazy and { sd.dur, sd.fn } or made[sd])
        local count = 1
        if how and (item.variants or DrumsBank.VARIANT_CATS[item.cat]) and item.variants ~= false then
            count = item.variants or DrumsBank.VARIANT_COUNT
            local names = { item.id }
            for k = 2, count do names[k] = item.id .. "#" .. k end
            Synth.VARIANTS[item.id] = names
        end
        local function buildVariants()
            for k = 2, count do
                Synth:createPool(item.id .. "#" .. k, createBuffer(Synth, how[1], how[2]), 8, item.dur)
            end
        end
        if sd and sd.lazy then
            -- built later: the pool, then its versions
            Synth.lazyDrums[item.id] = function()
                Synth:createPool(item.id, createBuffer(Synth, sd.dur, sd.fn), 8, item.dur)
                item.sd = Synth.pools[item.id].data
                buildVariants()
            end
            Synth.lazyOrder[#Synth.lazyOrder + 1] = item.id
        else
            Synth:createPool(item.id, sd, 8, item.dur)
            buildVariants()
        end
    end
end

function DrumsBank.buildSounds(Synth, whiteNoise)
    -- 1. 808 SUB KICK (0.42s): Deep booming sine sweep 135Hz -> 38Hz
    local k808Phase = 0.0
    local kick808SD = Synth:createBuffer(0.42, function(t)
        local freq = 38.0 + 97.0 * math_exp(-t / 0.026)
        k808Phase = k808Phase + (TWO_PI * freq / Config.SAMPLE_RATE)
        local body = math_sin(k808Phase) * math_exp(-t * 6.8)
        local click = (t < 0.002) and (whiteNoise() * 0.45 + math_sin(TWO_PI * 1400 * t) * 0.4) or 0.0
        return tanh_approx((body * 1.45 + click) * 1.1) * 0.92
    end)

    -- 2. 909 PUNCH KICK (0.30s): Fast punchy pitch envelope 210Hz -> 50Hz + click
    local k909Phase = 0.0
    local kick909SD = Synth:createBuffer(0.30, function(t)
        local freq = 50.0 + 160.0 * math_exp(-t / 0.014)
        k909Phase = k909Phase + (TWO_PI * freq / Config.SAMPLE_RATE)
        local body = (math_sin(k909Phase) + 0.22 * math_sin(k909Phase * 2.0) * math_exp(-t * 35.0)) * math_exp(-t * 11.5)
        local click = (t < 0.0035) and (math_sin(TWO_PI * 2400 * t) * 0.7 + whiteNoise() * 0.5) or 0.0
        return tanh_approx((body * 1.55 + click) * 1.2) * 0.92
    end)

    -- 3. CRUNCH KICK (0.28s): Gritty saturated boom-bap kick with warm harmonics
    local kLofiPhase = 0.0
    local kickLofiSD = Synth:createBuffer(0.28, function(t)
        local freq = 46.0 + 115.0 * math_exp(-t / 0.018)
        kLofiPhase = kLofiPhase + (TWO_PI * freq / Config.SAMPLE_RATE)
        local raw = math_sin(kLofiPhase) * 1.9 + math_sin(kLofiPhase * 3.0) * 0.35 * math_exp(-t * 24.0)
        local env = math_exp(-t * 12.5)
        return tanh_approx(raw * env * 1.6) * 0.90
    end)

    -- 4. ACOUSTIC KICK (0.24s): Warm dry acoustic bass drum thump with beater transient
    local kAcPhase = 0.0
    local kickAcousticSD = Synth:createBuffer(0.24, function(t)
        local freq = 58.0 + 95.0 * math_exp(-t / 0.012)
        kAcPhase = kAcPhase + (TWO_PI * freq / Config.SAMPLE_RATE)
        local body = (math_sin(kAcPhase) + 0.3 * math_sin(kAcPhase * 1.58) * math_exp(-t * 28.0)) * math_exp(-t * 16.0)
        local beater = whiteNoise() * math_exp(-t * 140.0) * 0.55
        return tanh_approx((body * 1.4 + beater) * 1.15) * 0.90
    end)

    -- 5. GABBER DIST KICK (0.32s): Hard-clipped industrial / rave distorted kick
    local kGabPhase = 0.0
    local kickGabberSD = Synth:createBuffer(0.32, function(t)
        local freq = 48.0 + 220.0 * math_exp(-t / 0.022)
        kGabPhase = kGabPhase + (TWO_PI * freq / Config.SAMPLE_RATE)
        local raw = math_sin(kGabPhase) * 3.8 + math_sin(kGabPhase * 2.0) * 1.2
        local env = math_exp(-t * 9.0)
        return tanh_approx(raw * env) * 0.88
    end)

    -- 6. ANALOG SNARE (0.25s): 180Hz -> 110Hz triangle body + bright snare wires
    local snarePhase = 0.0
    local snarePrevNoise = 0.0
    local snareAnalogSD = Synth:createBuffer(0.25, function(t)
        local freq = 110.0 + 70.0 * math_exp(-t * 28.0)
        snarePhase = (snarePhase + freq / Config.SAMPLE_RATE) % 1.0
        local tri = 4.0 * math_abs(snarePhase - 0.5) - 1.0
        local body = tri * math_exp(-t * 22.0) * 0.65

        local rawNoise = whiteNoise()
        local bandNoise = rawNoise - 0.55 * snarePrevNoise
        snarePrevNoise = rawNoise
        local wire = bandNoise * math_exp(-t * 18.0) * 0.75

        return tanh_approx((body + wire) * 1.25) * 0.88
    end)

    -- 7. TIGHT RIM SNARE (0.18s): Poppy high-pitched rim snare with fast crisp decay
    local sTightPhase = 0.0
    local snareTightSD = Synth:createBuffer(0.18, function(t)
        local freq = 165.0 + 120.0 * math_exp(-t * 42.0)
        sTightPhase = sTightPhase + (TWO_PI * freq / Config.SAMPLE_RATE)
        local body = math_sin(sTightPhase) * math_exp(-t * 30.0) * 0.75
        local wire = whiteNoise() * math_exp(-t * 32.0) * 0.65
        return tanh_approx((body + wire) * 1.4) * 0.88
    end)

    -- 8. LO-FI BOX SNARE (0.22s): Dusty boxy vintage drum-machine snare
    local sLofiPrev = 0.0
    local snareLofiSD = Synth:createBuffer(0.22, function(t)
        local n = whiteNoise()
        sLofiPrev = sLofiPrev * 0.45 + n * 0.55
        local body = math_sin(TWO_PI * (135.0 + 50.0 * math_exp(-t * 30.0)) * t) * math_exp(-t * 20.0) * 0.7
        local dust = sLofiPrev * math_exp(-t * 19.0) * 0.75
        return tanh_approx((body + dust) * 1.35) * 0.86
    end)

    -- 9. FAT GATED SNARE (0.28s): Big 80s synthwave snare with gated noise plateau
    local sGatePhase = 0.0
    local snareGatedSD = Synth:createBuffer(0.28, function(t)
        local freq = 128.0 + 90.0 * math_exp(-t * 32.0)
        sGatePhase = sGatePhase + (TWO_PI * freq / Config.SAMPLE_RATE)
        local body = math_sin(sGatePhase) * math_exp(-t * 16.0) * 0.75
        local gateEnv = (t < 0.16) and (1.0 - t * 2.2) or math_exp(-(t - 0.16) * 45.0) * 0.65
        local noise = whiteNoise() * gateEnv * 0.70
        return tanh_approx((body + noise) * 1.3) * 0.86
    end)

    -- 10. BRUSH SNARE (0.20s): Soft swishy brush attack snare
    local sBrushPrev = 0.0
    local snareBrushSD = Synth:createBuffer(0.20, function(t)
        local n = whiteNoise()
        local hp = n - sBrushPrev
        sBrushPrev = n * 0.6
        local attack = clamp(t / 0.015, 0.2, 1.0)
        local swish = hp * attack * math_exp(-t * 16.0) * 0.55
        local tone = math_sin(TWO_PI * 155.0 * t) * math_exp(-t * 28.0) * 0.35
        return tanh_approx((swish + tone) * 1.2) * 0.84
    end)

    -- 11. CLOSED HI-HAT (0.11s): 6 detuned high-frequency square oscillators + ring-mod noise
    local hatFreqs = { 3100.0, 3950.0, 4820.0, 5610.0, 6480.0, 7400.0 }
    local hatClosedSD = Synth:createBuffer(0.11, function(t)
        local sqSum = 0.0
        for i = 1, 6 do
            local p = (t * hatFreqs[i]) % 1.0
            sqSum = sqSum + (p < 0.5 and 1.0 or -1.0)
        end
        sqSum = sqSum / 6.0
        local metallic = (sqSum * 0.55 + whiteNoise() * 0.45) * (1.0 + 0.4 * sqSum * whiteNoise())
        local env = math_exp(-t * 48.0)
        return clamp(metallic * env * 0.82, -0.95, 0.95)
    end)

    -- 12. TIGHT TICK HAT (0.06s): Ultra-crisp minimal/trap micro hi-hat
    local hatTickSD = Synth:createBuffer(0.06, function(t)
        local n = whiteNoise()
        local ring = math_sin(TWO_PI * 6200.0 * t) * math_sin(TWO_PI * 8900.0 * t)
        local env = math_exp(-t * 95.0)
        return clamp((n * 0.65 + ring * 0.55) * env * 0.88, -0.95, 0.95)
    end)

    -- 13. OPEN HI-HAT (0.34s): Shimmering metallic open cymbal/hat sustain
    local hatOpenSD = Synth:createBuffer(0.34, function(t)
        local sqSum = 0.0
        for i = 1, 6 do
            local p = (t * hatFreqs[i]) % 1.0
            sqSum = sqSum + (p < 0.5 and 1.0 or -1.0)
        end
        sqSum = sqSum / 6.0
        local n = whiteNoise()
        local shimmer = (sqSum * 0.60 + n * 0.40) * (1.0 + 0.35 * math_sin(TWO_PI * 920.0 * t))
        local attack = clamp(t / 0.004, 0.2, 1.0)
        local env = attack * math_exp(-t * 9.5)
        return clamp(shimmer * env * 0.76, -0.95, 0.95)
    end)

    -- 14. RIDE CYMBAL (0.45s): Metallic FM bell ping + shimmering wash
    local rideCymbalSD = Synth:createBuffer(0.45, function(t)
        local bell = math_sin(TWO_PI * 880.0 * t + math_sin(TWO_PI * 2410.0 * t) * 2.1 * math_exp(-t * 14.0))
        local wash = whiteNoise() * math_sin(TWO_PI * 5200.0 * t) * math_exp(-t * 12.0) * 0.5
        local env = math_exp(-t * 7.5)
        return tanh_approx((bell * 0.55 * env + wash) * 1.1) * 0.78
    end)

    -- 15. CRASH SIZZLE (0.55s): Bright explosive crash cymbal tail
    local crashPrev = 0.0
    local crashCymbalSD = Synth:createBuffer(0.55, function(t)
        local n = whiteNoise()
        local hp = n - crashPrev * 0.75
        crashPrev = n
        local metal = math_sin(TWO_PI * 3400.0 * t + math_sin(TWO_PI * 5120.0 * t) * 3.0) * 0.35
        local env = math_exp(-t * 5.8)
        return clamp((hp * 0.65 + metal) * env * 0.78, -0.95, 0.95)
    end)

    -- 16. STUDIO CLAP (0.22s): Three 8ms micro-bursts followed by reverb noise tail
    local clapPrev = 0.0
    local clapStudioSD = Synth:createBuffer(0.22, function(t)
        local n = whiteNoise()
        local filtered = n - 0.65 * clapPrev
        clapPrev = n

        local env = 0.0
        if t < 0.008 then
            env = math_exp(-t * 120.0)
        elseif t >= 0.011 and t < 0.019 then
            env = math_exp(-(t - 0.011) * 120.0)
        elseif t >= 0.022 and t < 0.030 then
            env = math_exp(-(t - 0.022) * 100.0)
        else
            env = 0.58 * math_exp(-(t - 0.030) * 16.0)
        end
        local wood = math_sin(TWO_PI * 820.0 * t) * math_exp(-t * 55.0) * 0.25
        return tanh_approx((filtered * env + wood) * 1.2) * 0.85
    end)

    -- 17. FINGER SNAP (0.10s): Crisp organic resonant pop + micro-click
    local snapSD = Synth:createBuffer(0.10, function(t)
        local pop = math_sin(TWO_PI * (1950.0 - t * 9000.0) * t) * math_exp(-t * 75.0) * 0.75
        local click = whiteNoise() * math_exp(-t * 110.0) * 0.65
        return tanh_approx((pop + click) * 1.45) * 0.88
    end)

    -- 18. SHAKER / MARACA (0.11s): Swish-envelope high-frequency grain shaker
    local shakerPrev = 0.0
    local shakerSD = Synth:createBuffer(0.11, function(t)
        local n = whiteNoise()
        local hp = n - shakerPrev * 0.85
        shakerPrev = n
        local env = math_sin(clamp(t / 0.11, 0.0, 1.0) * math_pi) ^ 1.8
        return clamp(hp * env * 0.68, -0.95, 0.95)
    end)

    -- 19. FM SYNTH TOM (0.28s): Pitched electronic tom / disco sweep
    local tomPhase = 0.0
    local percTomSD = Synth:createBuffer(0.28, function(t)
        local freq = 82.0 + 110.0 * math_exp(-t / 0.045)
        tomPhase = tomPhase + (TWO_PI * freq / Config.SAMPLE_RATE)
        local mod = math_sin(tomPhase * 2.4) * 1.2 * math_exp(-t * 28.0)
        local body = math_sin(tomPhase + mod) * math_exp(-t * 11.5)
        return tanh_approx(body * 1.35) * 0.88
    end)

    -- 20. CONGA SLAP (0.22s): Warm hand-drum resonant slap tone
    local congaPhase = 0.0
    local percCongaSD = Synth:createBuffer(0.22, function(t)
        local freq = 195.0 + 65.0 * math_exp(-t / 0.015)
        congaPhase = congaPhase + (TWO_PI * freq / Config.SAMPLE_RATE)
        local body = (math_sin(congaPhase) + 0.35 * math_sin(congaPhase * 2.0) * math_exp(-t * 35.0)) * math_exp(-t * 15.0)
        local slap = whiteNoise() * math_exp(-t * 115.0) * 0.45
        return tanh_approx((body + slap) * 1.3) * 0.88
    end)

    -- 21. WOOD RIMSHOT (0.10s): Crisp woody rimshot / clave percussion
    local percWoodSD = Synth:createBuffer(0.10, function(t)
        local w1 = math_sin(TWO_PI * 840.0 * t)
        local w2 = math_sin(TWO_PI * 1380.0 * t) * math_exp(-t * 85.0)
        local click = (t < 0.002) and whiteNoise() * 0.6 or 0.0
        local env = math_exp(-t * 46.0)
        return tanh_approx((w1 * 0.75 + w2 * 0.55 + click) * env * 1.5) * 0.86
    end)

    -- 22. 808 COWBELL (0.24s): Classic dual band-limited square 540Hz + 800Hz
    local percCowbellSD = Synth:createBuffer(0.24, function(t)
        local p1 = (t * 540.0) % 1.0
        local p2 = (t * 800.0) % 1.0
        local sq1 = (p1 < 0.5) and 1.0 or -1.0
        local sq2 = (p2 < 0.5) and 1.0 or -1.0
        local ring = (sq1 + sq2) * 0.35 + math_sin(TWO_PI * 540.0 * t) * 0.45
        local env = 0.65 * math_exp(-t * 36.0) + 0.35 * math_exp(-t * 11.0)
        return tanh_approx(ring * env * 1.25) * 0.78
    end)

    -- 23. FM AGOGO BELL (0.20s): Bright pitched metallic Latin agogo bell
    local percAgogoSD = Synth:createBuffer(0.20, function(t)
        local f = 680.0
        local mod = math_sin(TWO_PI * f * 2.72 * t) * 1.8 * math_exp(-t * 22.0)
        local s = math_sin(TWO_PI * f * t + mod) * math_exp(-t * 15.0)
        return tanh_approx(s * 1.3) * 0.82
    end)

    -- 24. LASER ZAP (0.18s): Retro synth/arcade downward frequency sweep
    local zapPhase = 0.0
    local fxZapSD = Synth:createBuffer(0.18, function(t)
        local freq = 95.0 + 1850.0 * math_exp(-t / 0.028)
        zapPhase = zapPhase + (TWO_PI * freq / Config.SAMPLE_RATE)
        local s = math_sin(zapPhase + math_sin(zapPhase * 2.0) * 0.6) * math_exp(-t * 16.0)
        return tanh_approx(s * 1.35) * 0.84
    end)


    -- =======================================================================
    -- ACOUSTIC KIT (PHASE_L L7): the sounds of the famous funk breaks, a
    -- drummer in a room rather than a drum machine. Filtered noise and
    -- inharmonic partials; every generator resets its state at t = 0, so the
    -- versions rendered for Synth.VARIANTS each start clean.
    -- =======================================================================
    local SR = Config.SAMPLE_RATE

    -- These are built after boot, in the background (Synth:startPregen),
    -- or at once if one is hit first: lazy() stands in for createBuffer
    local function lazy(dur, fn) return { lazy = true, dur = dur, fn = fn } end
    local math_cos = math.cos

    -- A biquad filter (RBJ cookbook): kind "bp" (0 dB peak), "hp" or "lp"
    local function biquad(kind, f, q)
        local w0 = TWO_PI * f / SR
        local cs, sn = math_cos(w0), math_sin(w0)
        local alpha = sn / (2.0 * q)
        local b0, b1, b2
        if kind == "bp" then
            b0, b1, b2 = alpha, 0.0, -alpha
        elseif kind == "hp" then
            b0, b1, b2 = (1 + cs) * 0.5, -(1 + cs), (1 + cs) * 0.5
        else
            b0, b1, b2 = (1 - cs) * 0.5, 1 - cs, (1 - cs) * 0.5
        end
        local a0 = 1 + alpha
        b0, b1, b2 = b0 / a0, b1 / a0, b2 / a0
        local a1, a2 = -2 * cs / a0, (1 - alpha) / a0
        local x1, x2, y1, y2 = 0.0, 0.0, 0.0, 0.0
        return function(x, reset)
            if reset then x1, x2, y1, y2 = 0.0, 0.0, 0.0, 0.0 end
            local y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
            x2, x1, y2, y1 = x1, x, y1, y
            return y
        end
    end

    -- Sum of inharmonic sine partials { freq, amp, decay } at time t
    local function partials(list, t)
        local s = 0.0
        for i = 1, #list do
            local p = list[i]
            s = s + math_sin(TWO_PI * p[1] * t) * p[2] * math_exp(-t * p[3])
        end
        return s
    end

    -- 25. FUNK SNARE (0.32s): stick crack, a ringing shell (~200 Hz and its
    -- second mode), and the wires' rattle, which starts a moment late
    local fsCrack, fsWire, fsP1, fsP2 = biquad("hp", 2200, 0.7), biquad("bp", 4800, 0.6), 0.0, 0.0
    local snareFunkSD = lazy(0.32, function(t)
        local first = (t == 0)
        if first then fsP1, fsP2 = 0.0, 0.0 end
        local n = whiteNoise()
        local drop = math_exp(-t * 60.0)
        fsP1 = fsP1 + TWO_PI * (196.0 + 30.0 * drop) / SR
        fsP2 = fsP2 + TWO_PI * (338.0 + 40.0 * drop) / SR
        local shell = (math_sin(fsP1) * 0.8 + math_sin(fsP2) * 0.45) * math_exp(-t * 26.0)
        local crack = fsCrack(n, first) * math_exp(-t * 110.0) * 1.3
        local wireEnv = clamp((t - 0.0015) / 0.004, 0.0, 1.0) * (0.75 * math_exp(-t * 15.0) + 0.25 * math_exp(-t * 6.0))
        local wire = fsWire(n, first) * wireEnv * 2.4
        local env = clamp(t / 0.0007, 0.0, 1.0) * clamp((0.32 - t) / 0.03, 0.0, 1.0)
        return tanh_approx((shell + crack + wire) * env * 1.35) * 0.70
    end)

    -- 26. STICK HAT (0.12s): a stick tip on closed hats: a click, then a
    -- short bright "tss" with a little metal in it
    local shHp, shBp = biquad("hp", 7000, 0.7), biquad("bp", 9500, 1.2)
    local hatMetal = { { 3150, 0.10, 60 }, { 4790, 0.08, 70 }, { 6820, 0.07, 80 }, { 8340, 0.06, 90 } }
    local hatAcousticSD = lazy(0.12, function(t)
        local first = (t == 0)
        local n = whiteNoise()
        local tss = shHp(n, first) * math_exp(-t * 52.0) * 0.9
        local tip = shBp(n, first) * math_exp(-t * 380.0) * 2.0
        local metal = partials(hatMetal, t)
        local env = clamp(t / 0.0005, 0.0, 1.0) * clamp((0.12 - t) / 0.02, 0.0, 1.0)
        return clamp((tss + tip + metal) * env * 0.70, -0.95, 0.95)
    end)

    -- 27. HALF HAT (0.30s): half-open hats, loose and "sloshy": the plates
    -- rattle against each other while the wash dies away
    local hhHp, hhBp = biquad("hp", 5500, 0.6), biquad("bp", 8200, 0.9)
    local halfMetal = { { 3420, 0.08, 14 }, { 5130, 0.07, 16 }, { 7260, 0.06, 18 }, { 9010, 0.05, 20 } }
    local hatHalfSD = lazy(0.30, function(t)
        local first = (t == 0)
        local n = whiteNoise()
        local slosh = 1.0 + 0.35 * math_sin(TWO_PI * 26.0 * t) * math_exp(-t * 6.0)
        local wash = (hhHp(n, first) * 0.75 + hhBp(n, first) * 0.9) * slosh
        local env = clamp(t / 0.002, 0.0, 1.0) * (0.6 * math_exp(-t * 16.0) + 0.4 * math_exp(-t * 7.0))
            * clamp((0.30 - t) / 0.04, 0.0, 1.0)
        return clamp((wash + partials(halfMetal, t)) * env * 0.50, -0.95, 0.95)
    end)

    -- 28. HAT PEDAL (0.09s): the foot closing the hats: a soft "chick"
    local hpBp, hpHp = biquad("bp", 1700, 1.1), biquad("hp", 6000, 0.7)
    local hatPedalSD = lazy(0.09, function(t)
        local first = (t == 0)
        local n = whiteNoise()
        local chick = hpBp(n, first) * 1.6 + hpHp(n, first) * 0.45
        local env = clamp(t / 0.003, 0.0, 1.0) * math_exp(-t * 62.0) * clamp((0.09 - t) / 0.015, 0.0, 1.0)
        return clamp(chick * env * 1.3, -0.95, 0.95)
    end)

    -- 29. ACOUSTIC RIDE (0.90s): the stick's ping on the bow and a long wash
    local arHp = biquad("hp", 5200, 0.7)
    local rideMetal = { { 3080, 0.22, 5.0 }, { 4270, 0.18, 5.5 }, { 5410, 0.15, 6.0 }, { 6620, 0.12, 7.0 },
                        { 7890, 0.10, 8.0 }, { 2310, 0.10, 4.0 }, { 9350, 0.06, 9.0 } }
    local rideAcousticSD = lazy(0.90, function(t)
        local first = (t == 0)
        local n = whiteNoise()
        local ping = partials(rideMetal, t)
        local wash = arHp(n, first) * (0.10 * math_exp(-t * 3.2) + 0.22 * math_exp(-t * 40.0))
        local env = clamp(t / 0.0008, 0.0, 1.0) * clamp((0.90 - t) / 0.1, 0.0, 1.0)
        return clamp((ping + wash) * env * 0.82, -0.95, 0.95)
    end)

    -- 30. RIDE BELL (0.80s): the bell of the ride: clear, loud, ringing
    local bellMetal = { { 812, 0.45, 3.5 }, { 1243, 0.30, 4.0 }, { 2297, 0.26, 4.5 }, { 3412, 0.16, 5.5 },
                        { 4630, 0.10, 7.0 } }
    local rbHp = biquad("hp", 6000, 0.7)
    local rideBellSD = lazy(0.80, function(t)
        local first = (t == 0)
        local n = whiteNoise()
        local env = clamp(t / 0.0006, 0.0, 1.0) * clamp((0.80 - t) / 0.1, 0.0, 1.0)
        return clamp((partials(bellMetal, t) + rbHp(n, first) * 0.25 * math_exp(-t * 30.0)) * env * 0.65, -0.95, 0.95)
    end)

    -- 31-32. TOMS (high 0.36s, low 0.48s): a skin that drops a little in
    -- pitch, its inharmonic second mode, and the stick
    local function tom(f0, dur, decay)
        local p1, p2 = 0.0, 0.0
        local stick = biquad("bp", 2600, 0.8)
        return lazy(dur, function(t)
            local first = (t == 0)
            if first then p1, p2 = 0.0, 0.0 end
            local drop = math_exp(-t * 18.0)
            p1 = p1 + TWO_PI * f0 * (1.0 + 0.12 * drop) / SR
            p2 = p2 + TWO_PI * f0 * 1.59 * (1.0 + 0.08 * drop) / SR
            local skin = math_sin(p1) * math_exp(-t * decay) + math_sin(p2) * 0.3 * math_exp(-t * decay * 1.8)
            local hit = stick(whiteNoise(), first) * math_exp(-t * 90.0) * 1.2
            local env = clamp(t / 0.0008, 0.0, 1.0) * clamp((dur - t) / 0.05, 0.0, 1.0)
            return tanh_approx((skin + hit) * env * 1.3) * 0.86
        end)
    end
    local tomHighSD = tom(196.0, 0.36, 9.0)
    local tomLowSD = tom(108.0, 0.48, 7.0)

    -- 33-34. BONGOS (high 0.16s, low 0.20s): small, tight, high skins and a
    -- slap of the fingers
    local function bongo(f0, dur)
        local p = 0.0
        local slap = biquad("bp", 3200, 1.0)
        return lazy(dur, function(t)
            local first = (t == 0)
            if first then p = 0.0 end
            p = p + TWO_PI * f0 * (1.0 + 0.10 * math_exp(-t * 40.0)) / SR
            local skin = (math_sin(p) + 0.25 * math_sin(p * 2.3) * math_exp(-t * 40.0)) * math_exp(-t * 22.0)
            local hit = slap(whiteNoise(), first) * math_exp(-t * 160.0) * 1.4
            local env = clamp(t / 0.0006, 0.0, 1.0) * clamp((dur - t) / 0.03, 0.0, 1.0)
            return tanh_approx((skin + hit) * env * 1.3) * 0.84
        end)
    end
    local bongoHighSD = bongo(432.0, 0.16)
    local bongoLowSD = bongo(298.0, 0.20)

    -- 35. TAMBOURINE (0.24s): jingles: a few quick metal bursts as the
    -- zils shake, high and bright
    local tbBp = biquad("bp", 7600, 1.4)
    local zil = { { 5230, 0.10, 18 }, { 6870, 0.09, 20 }, { 8410, 0.08, 22 }, { 10120, 0.06, 26 } }
    local tambSD = lazy(0.24, function(t)
        local first = (t == 0)
        local n = whiteNoise()
        local shake = math_exp(-t * 16.0) + 0.6 * math_exp(-math.max(0, t - 0.011) * 30.0) * ((t > 0.011) and 1 or 0)
            + 0.4 * math_exp(-math.max(0, t - 0.024) * 34.0) * ((t > 0.024) and 1 or 0)
        local s = (tbBp(n, first) * 1.6 + partials(zil, t)) * shake
        local env = clamp(t / 0.001, 0.0, 1.0) * clamp((0.24 - t) / 0.03, 0.0, 1.0)
        return clamp(s * env * 0.55, -0.95, 0.95)
    end)

    -- 36. SIDESTICK (0.12s): the stick laid across the rim: a dry, woody knock
    local ssBp = biquad("bp", 1600, 2.5)
    local sidestickSD = lazy(0.12, function(t)
        local first = (t == 0)
        local n = whiteNoise()
        local knock = math_sin(TWO_PI * 520.0 * t) * math_exp(-t * 48.0) * 0.5
                    + math_sin(TWO_PI * 1140.0 * t) * math_exp(-t * 70.0) * 0.35
        local click = ssBp(n, first) * math_exp(-t * 120.0) * 2.0
        local env = clamp(t / 0.0004, 0.0, 1.0) * clamp((0.12 - t) / 0.02, 0.0, 1.0)
        return tanh_approx((knock + click) * env * 1.4) * 0.84
    end)

    -- 37. ACOUSTIC CRASH (1.30s): a real crash: a splash of noise and many
    -- clashing partials that bloom and fade slowly
    local acHp, acBp = biquad("hp", 3800, 0.6), biquad("bp", 6500, 0.7)
    local crashMetal = { { 2210, 0.08, 3.2 }, { 3170, 0.08, 3.0 }, { 4350, 0.07, 3.4 }, { 5480, 0.07, 3.6 },
                         { 6730, 0.06, 3.8 }, { 7910, 0.05, 4.2 }, { 9260, 0.04, 4.6 }, { 2780, 0.06, 2.8 } }
    local crashAcousticSD = lazy(1.30, function(t)
        local first = (t == 0)
        local n = whiteNoise()
        local splash = acHp(n, first) * 0.55 + acBp(n, first) * 0.8
        local env = clamp(t / 0.003, 0.0, 1.0) * (0.55 * math_exp(-t * 6.0) + 0.45 * math_exp(-t * 2.2))
            * clamp((1.30 - t) / 0.15, 0.0, 1.0)
        return clamp((splash + partials(crashMetal, t)) * env * 0.62, -0.95, 0.95)
    end)

    -- 38. REVERSE SNARE (0.50s): the funk snare backwards, a swell into a
    -- hard stop, the classic jungle lead-in. Press early: it peaks at the end
    local rsWire = biquad("bp", 4200, 0.6)
    local revSnareSD = lazy(0.50, function(t)
        local first = (t == 0)
        local r = 0.50 - t                         -- the snare's own clock, running backwards
        local n = whiteNoise()
        local shell = math_sin(TWO_PI * 200.0 * r) * math_exp(-r * 20.0) * 0.7
        local wire = rsWire(n, first) * (0.7 * math_exp(-r * 9.0) + 0.3 * math_exp(-r * 3.5)) * 2.2
        local env = clamp(t / 0.02, 0.0, 1.0) * clamp(r / 0.004, 0.0, 1.0)
        return tanh_approx((shell + wire) * env * 1.3) * 0.84
    end)

    -- 39. REVERSE CYMBAL (1.10s): a crash backwards: a rising swoosh into
    -- the downbeat
    local rcHp = biquad("hp", 4200, 0.6)
    local revCymbalSD = lazy(1.10, function(t)
        local first = (t == 0)
        local r = 1.10 - t
        local n = whiteNoise()
        local env = (0.6 * math_exp(-r * 4.5) + 0.4 * math_exp(-r * 1.8)) * clamp(t / 0.05, 0.0, 1.0) * clamp(r / 0.006, 0.0, 1.0)
        return clamp((rcHp(n, first) * 0.9 + partials(crashMetal, r) * 0.8) * env * 0.85, -0.95, 0.95)
    end)

    local catalog = {
        { id = "kick_808",      cat = "KICK",  short = "808 KICK",   full = "01. 808 SUB KICK",   sd = kick808SD,      dur = 0.42 },
        { id = "kick_909",      cat = "KICK",  short = "909 KICK",   full = "02. 909 PUNCH KCK",  sd = kick909SD,      dur = 0.30 },
        { id = "kick_lofi",     cat = "KICK",  short = "CRUNCH KCK", full = "03. CRUNCH KICK",    sd = kickLofiSD,     dur = 0.28 },
        { id = "kick_acoustic", cat = "KICK",  short = "ACOUST KCK", full = "04. ACOUSTIC KICK",  sd = kickAcousticSD, dur = 0.24 },
        { id = "kick_gabber",   cat = "KICK",  short = "GABBER KCK", full = "05. GABBER DIST",    sd = kickGabberSD,   dur = 0.32 },
        { id = "snare_analog",  cat = "SNARE", short = "ANA SNARE",  full = "06. ANALOG SNARE",   sd = snareAnalogSD,  dur = 0.25 },
        { id = "snare_tight",   cat = "SNARE", short = "TIGHT SNR",  full = "07. TIGHT RIM SNR",  sd = snareTightSD,   dur = 0.18 },
        { id = "snare_lofi",    cat = "SNARE", short = "LOFI SNARE", full = "08. LO-FI BOX SNR",  sd = snareLofiSD,    dur = 0.22 },
        { id = "snare_gated",   cat = "SNARE", short = "GATED SNR",  full = "09. FAT GATED SNR",  sd = snareGatedSD,   dur = 0.28 },
        { id = "snare_brush",   cat = "SNARE", short = "BRUSH SNR",  full = "10. BRUSH SNARE",    sd = snareBrushSD,   dur = 0.20 },
        { id = "hat_closed",    cat = "HAT",   short = "CLOSED HAT", full = "11. CLOSED HI-HAT",  sd = hatClosedSD,    dur = 0.11 },
        { id = "hat_tick",      cat = "HAT",   short = "TICK HAT",   full = "12. TIGHT TICK HAT", sd = hatTickSD,      dur = 0.06 },
        { id = "hat_open",      cat = "HAT",   short = "OPEN HAT",   full = "13. OPEN HI-HAT",    sd = hatOpenSD,      dur = 0.34 },
        { id = "cym_ride",      cat = "CYM",   short = "RIDE CYM",   full = "14. RIDE CYMBAL",    sd = rideCymbalSD,   dur = 0.45 },
        { id = "cym_crash",     cat = "CYM",   short = "CRASH CYM",  full = "15. CRASH SIZZLE",   sd = crashCymbalSD,  dur = 0.55 },
        { id = "clap_studio",   cat = "CLAP",  short = "HAND CLAP",  full = "16. STUDIO CLAP",    sd = clapStudioSD,   dur = 0.22 },
        { id = "perc_snap",     cat = "CLAP",  short = "FINGR SNAP", full = "17. FINGER SNAP",    sd = snapSD,         dur = 0.10 },
        { id = "perc_shaker",   cat = "PERC",  short = "SHAKER",     full = "18. SHAKER MARACA",  sd = shakerSD,       dur = 0.11 },
        { id = "perc_wood",     cat = "PERC",  short = "WOOD RIM",   full = "19. WOOD RIMSHOT",   sd = percWoodSD,     dur = 0.10 },
        { id = "perc_tom",      cat = "TOM",   short = "FM TOM",     full = "20. FM SYNTH TOM",   sd = percTomSD,      dur = 0.28 },
        { id = "perc_conga",    cat = "TOM",   short = "CONGA SLAP", full = "21. CONGA SLAP",     sd = percCongaSD,    dur = 0.22 },
        { id = "perc_cowbell",  cat = "BELL",  short = "COWBELL",    full = "22. 808 COWBELL",    sd = percCowbellSD,  dur = 0.24 },
        { id = "perc_agogo",    cat = "BELL",  short = "AGOGO BELL", full = "23. FM AGOGO BELL",  sd = percAgogoSD,    dur = 0.20 },
        { id = "fx_zap",        cat = "FX",    short = "LASER ZAP",  full = "24. LASER ZAP",      sd = fxZapSD,        dur = 0.18 },
        -- the acoustic kit (PHASE_L L7)
        { id = "snare_funk",    cat = "SNARE", short = "FUNK SNARE", full = "25. FUNK SNARE",     sd = snareFunkSD,    dur = 0.32 },
        { id = "hat_acoustic",  cat = "HAT",   short = "STICK HAT",  full = "26. STICK HAT",      sd = hatAcousticSD,  dur = 0.12 },
        { id = "hat_half",      cat = "HAT",   short = "HALF HAT",   full = "27. HALF-OPEN HAT",  sd = hatHalfSD,      dur = 0.30 },
        { id = "hat_pedal",     cat = "HAT",   short = "HAT PEDAL",  full = "28. HAT PEDAL",      sd = hatPedalSD,     dur = 0.09 },
        { id = "cym_ride_ac",   cat = "CYM",   short = "AC RIDE",    full = "29. ACOUSTIC RIDE",  sd = rideAcousticSD, dur = 0.90, variants = 2 },
        { id = "cym_bell",      cat = "CYM",   short = "RIDE BELL",  full = "30. RIDE BELL",      sd = rideBellSD,     dur = 0.80 },
        { id = "tom_high",      cat = "TOM",   short = "HIGH TOM",   full = "31. HIGH TOM",       sd = tomHighSD,      dur = 0.36 },
        { id = "tom_low",       cat = "TOM",   short = "LOW TOM",    full = "32. LOW TOM",        sd = tomLowSD,       dur = 0.48 },
        { id = "bongo_high",    cat = "TOM",   short = "HI BONGO",   full = "33. HIGH BONGO",     sd = bongoHighSD,    dur = 0.16, variants = 2 },
        { id = "bongo_low",     cat = "TOM",   short = "LO BONGO",   full = "34. LOW BONGO",      sd = bongoLowSD,     dur = 0.20, variants = 2 },
        { id = "perc_tamb",     cat = "PERC",  short = "TAMBOURINE", full = "35. TAMBOURINE",     sd = tambSD,         dur = 0.24, variants = 3 },
        { id = "perc_sidestick", cat = "PERC", short = "SIDESTICK",  full = "36. SIDESTICK",      sd = sidestickSD,    dur = 0.12 },
        { id = "cym_crash_ac",  cat = "CYM",   short = "AC CRASH",   full = "37. ACOUSTIC CRASH", sd = crashAcousticSD, dur = 1.30 },
        { id = "fx_revsnare",   cat = "FX",    short = "REV SNARE",  full = "38. REVERSE SNARE",  sd = revSnareSD,     dur = 0.50 },
        { id = "fx_revcym",     cat = "FX",    short = "REV CYMBAL", full = "39. REVERSE CYMBAL", sd = revCymbalSD,    dur = 1.10 },
    }

    -- The picker lists the sounds category by category, in the order each
    -- category first appears; the number in the long name follows that order
    local catOrder, rank = {}, {}
    for i, item in ipairs(catalog) do
        if not catOrder[item.cat] then catOrder[item.cat] = i end
        rank[item] = i
    end
    table.sort(catalog, function(a, b)
        if a.cat ~= b.cat then return catOrder[a.cat] < catOrder[b.cat] end
        return rank[a] < rank[b]
    end)
    for i, item in ipairs(catalog) do
        item.full = string.format("%02d. %s", i, item.full:gsub("^%d+%.%s*", ""))
    end

    Synth.drumCatalog = catalog
    for _, item in ipairs(catalog) do
        if item.cat == "KICK" then Synth.KICK_SOUNDS[item.id] = true end
    end
end

return DrumsBank
