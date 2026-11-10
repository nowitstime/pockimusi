-- ============================================================================
-- src/synth/drums_bank.lua — 24 Procedural Drum & Percussion Sound Generators
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

function DrumsBank.build(Synth, whiteNoise)
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
        { id = "perc_tom",      cat = "TOM",   short = "FM TOM",     full = "19. FM SYNTH TOM",   sd = percTomSD,      dur = 0.28 },
        { id = "perc_conga",    cat = "TOM",   short = "CONGA SLAP", full = "20. CONGA SLAP",     sd = percCongaSD,    dur = 0.22 },
        { id = "perc_wood",     cat = "PERC",  short = "WOOD RIM",   full = "21. WOOD RIMSHOT",   sd = percWoodSD,     dur = 0.10 },
        { id = "perc_cowbell",  cat = "BELL",  short = "COWBELL",    full = "22. 808 COWBELL",    sd = percCowbellSD,  dur = 0.24 },
        { id = "perc_agogo",    cat = "BELL",  short = "AGOGO BELL", full = "23. FM AGOGO BELL",  sd = percAgogoSD,    dur = 0.20 },
        { id = "fx_zap",        cat = "FX",    short = "LASER ZAP",  full = "24. LASER ZAP",      sd = fxZapSD,        dur = 0.18 },
    }

    Synth.drumCatalog = catalog
    for _, item in ipairs(catalog) do
        Synth:createPool(item.id, item.sd, 8, item.dur)
    end
end

return DrumsBank
