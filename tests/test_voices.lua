-- Sustained voices (A7): seamless loop layers, attack + loop, release,
-- glide, voice stealing, and the desktop test keys.
local H = require("helpers")

local function step(Synth, seconds, fps)
    fps = fps or 60
    for _ = 1, math.floor(seconds * fps + 0.5) do
        H.time = H.time + 1 / fps
        Synth:update(1 / fps)
    end
end

-- A small test patch: 2 attack sources, 2 loop sources
local function setup(opts)
    opts = opts or {}
    local M = H.fresh({ realSynth = true })
    local S = M.Synth
    S:initTrackFx()
    local sd = S:createBuffer(0.3, function(t) return math.sin(t * 2 * math.pi * 110) * math.exp(-t * 8) end)
    S:createPool("t_att", sd, 2, 0.3)
    local loop, _, tune = S:createLoop(110, 4, function(a) return math.sin(a) * 0.5 + math.sin(2 * a) * 0.2 end)
    S:createLoopPool("t_loop", loop, opts.loopVoices or 2)
    S:definePatch("t", { attack = "t_att", loop = "t_loop", tune = tune, sustain = 0.5, xfade = 0.1, release = 0.2 })
    return M, S
end

-- How far the loop's end is from its start, compared with the biggest step
-- between neighbouring samples inside it (1.0 = as smooth as anywhere else)
local function seamRatio(sd)
    local s, n = sd.samples, sd.n
    local maxStep = 0
    for i = 1, n - 1 do maxStep = math.max(maxStep, math.abs(s[i] - s[i - 1])) end
    return math.abs(s[0] - s[n - 1]) / maxStep
end
local SMOOTH = 1.0 + 1e-9   -- "no rougher than inside" (allowing float rounding)

local function expectedLevel(S, v)
    return v.patch.sustain * v.vel * v.trackVolume * S.masterVolume * S.duckEnvelope
end

return {
    -- ------------------------------------------------------------------
    -- Loop buffers
    -- ------------------------------------------------------------------
    { "a loop is whole periods, seamless, and nearly in tune", function()
        H.captureSamples = true
        local _, S = setup()
        local sd, n, tune = S:createLoop(110, 4, function(a) return math.sin(a) + 0.3 * math.sin(3 * a) end)
        H.captureSamples = false
        H.eq(n, 401 * 4, "4 periods of 401 samples")
        H.truthy(seamRatio(sd) <= SMOOTH, "seam no rougher than inside: " .. seamRatio(sd))
        H.truthy(math.abs(tune) < 0.01, "tune correction tiny: " .. tune)
    end },

    { "the seam check catches a non-harmonic wave", function()
        H.captureSamples = true
        local _, S = setup()
        local sd = S:createLoop(110, 4, function(a) return math.sin(a * 1.37) end)
        H.captureSamples = false
        H.truthy(seamRatio(sd) > 2.0, "a click at the seam: " .. seamRatio(sd))
    end },

    { "every patch in the pool: loops seamless and in tune, levels sane, layers paired", function()
        H.captureSamples = true
        local M = H.fresh({ realSynth = true })
        M.Synth:init()
        local S = M.Synth
        local function peakOf(sd)
            local peak = 0
            for i = 0, sd.n - 1 do
                local x = sd.samples[i]
                H.truthy(x == x, "no NaN")
                peak = math.max(peak, math.abs(x))
            end
            return peak
        end
        local core, lazy = {}, {}
        for _, id in ipairs(S.patchOrder) do
            local patch = S.patches[id]
            if patch.silent then
                H.falsy(patch.attack or patch.loop, "silent: nothing to play")
            else
                local t = patch.core and core or lazy
                t[#t + 1] = id
                H.eq(patch.built, patch.core == true, id .. ": only core patches are generated at boot")
                S:preparePatch(id)
                H.truthy(patch.attack or patch.loop, id .. " has a layer")
                if patch.attack then
                    local peak = peakOf(S.pools[patch.attack].data)
                    H.truthy(peak > 0.25 and peak <= 0.95, id .. " attack peak " .. peak)
                end
                if patch.loop then
                    local src = S.loopPools[patch.loop].sources[1]
                    H.truthy(seamRatio(src.soundData) <= SMOOTH, id .. " seam " .. seamRatio(src.soundData))
                    H.truthy(math.abs(patch.tune) < 0.05, id .. " tune " .. patch.tune)
                    local peak = peakOf(src.soundData)
                    H.truthy(peak > 0.15 and peak <= 0.9, id .. " loop peak " .. peak)
                    if patch.bright then
                        local b = S.loopPools[patch.bright]
                        H.truthy(seamRatio(b.sources[1].soundData) <= SMOOTH, id .. " bright seam")
                        H.eq(#b.sources, #S.loopPools[patch.loop].sources, id .. " layers paired")
                        H.eq(b.sources[1].soundData.n, src.soundData.n, id .. " layers the same length")
                        local bp = peakOf(b.sources[1].soundData)
                        H.truthy(bp > 0.15 and bp <= 0.9, id .. " bright peak " .. bp)
                    end
                end
                H.truthy(patch.label and patch.full and patch.group, id .. " named for the picker")
                H.truthy(#patch.label <= 8, id .. " label fits a chip")
            end
        end
        H.captureSamples = false
        table.sort(core)
        H.eq(table.concat(core, " "), "bass_pluck bass_saw bass_sub harp lead_pluck lead_saw lead_square pad_bell pad_choir pad_drone pad_warm", "core patches")
        H.truthy(#lazy >= 12, "and the rest wait until they are chosen")
        H.truthy(S.bootTimes and S.bootTimes.patches >= 0, "boot time measured")
    end },

    -- ------------------------------------------------------------------
    -- The sound pool: generated on demand, any register, one-shot patches
    -- ------------------------------------------------------------------
    { "a patch is generated on its first note, and its pools grow to the voices asked for", function()
        local M = H.fresh({ realSynth = true })
        local S = M.Synth
        S:init()
        H.falsy(S.patches.pad_strings.built, "not at boot")
        H.eq(S.loopPools.pad_strings_loop, nil, "no pool yet")
        local v = S:noteOn("pad_strings", 0, 0.8)
        H.truthy(v and v.loopSrc.playing, "plays")
        H.eq(#S.loopPools.pad_strings_loop.sources, 12, "its own voice count")
        H.eq(#S.loopPools.lead_square_loop.sources, 6, "lead square: 6")
        S:noteOn("lead_square", 0, 0.8, { voices = 12 })
        H.eq(#S.loopPools.lead_square_loop.sources, 12, "grown for an instrument that needs 12")
        S:preparePatch("bass_saw", 12)
        H.eq(S.pools.bass.size, 12, "attack pool grown too")
        H.eq(#S.pools.bass.voices, 12, "with real sources")
    end },

    { "register: an instrument plays any patch in its own octave", function()
        local M = H.fresh({ realSynth = true })
        local S = M.Synth
        S:init()
        local home = S:noteOn("bass_saw", 0, 0.8, { register = 3 })
        local up = S:noteOn("bass_saw", 0, 0.8, { register = 4 })           -- a lead playing a bass patch
        local down = S:noteOn("lead_square", 0, 0.8, { register = 3 })      -- a bass playing a lead patch
        step(S, 0.1)
        H.near(home.loopSrc.pitch, 2 ^ (home.patch.tune / 12), "home register: as before", 1e-9)
        H.near(up.loopSrc.pitch, 2 * home.loopSrc.pitch, "an octave up", 1e-9)
        H.near(down.loopSrc.pitch, 0.5 * 2 ^ (down.patch.tune / 12), "an octave down", 1e-9)
        H.eq(up.currentSemis, 0, "the voice still reports the instrument's pitch")
        H.near(up.attack.currentSemis, 12, "attack layer moved too", 1e-9)
        up:setPitch(7)
        H.eq(up.attack.targetSemis, 19, "glides in the same register")
    end },

    { "a patch without a loop is a one-shot voice: it rings, ends by itself, and noteOff cuts it", function()
        local M = H.fresh({ realSynth = true })
        local S = M.Synth
        S:init()
        local p = S.patches.harp
        H.truthy(p.rings and not p.sustains, "harp rings")
        H.truthy(S.patches.lead_square.sustains and not S.patches.lead_square.rings, "square sustains")
        H.truthy(S.patches.lead_pluck.rings, "pluck rings")
        local v = S:noteOn("harp", 4, 0.8)
        H.eq(v.loopSrc, nil, "no loop layer")
        H.truthy(v.attack.source.playing, "the one-shot plays")
        step(S, 0.5)
        H.truthy(v:isSounding() and v:envelope() > 0, "ringing")
        step(S, 1.0)
        H.falsy(v:isSounding(), "over when the one-shot is")
        H.eq(#S.sustainVoices, 0, "voice freed")

        local cut = S:noteOn("harp", 0, 0.8)
        step(S, 0.1)
        cut:noteOff()
        step(S, p.release + 0.05)
        H.falsy(cut:isSounding(), "noteOff ends it after the patch's release")
        H.eq(S:noteOn("silent", 0, 0.8), nil, "the silent patch plays nothing")
    end },

    -- ------------------------------------------------------------------
    -- Voice lifecycle
    -- ------------------------------------------------------------------
    { "noteOn plays the attack and fades the loop in to the sustain level", function()
        local _, S = setup()
        local v = S:noteOn("t", 0, 0.8)
        H.truthy(v.loopSrc.playing and v.loopSrc.looping, "loop source playing, looping")
        H.truthy(S.pools.t_att.voices[1].playing, "attack played")
        step(S, 0.05)
        local mid = v.loopSrc.volume
        step(S, 0.1)
        H.truthy(mid > 0 and mid < v.loopSrc.volume, "fading in")
        H.near(v.loopSrc.volume, expectedLevel(S, v), "at sustain level", 1e-6)
    end },

    { "a held voice sustains for 4 s without fading", function()
        local _, S = setup()
        local v = S:noteOn("t", 0, 0.9)
        step(S, 0.2)
        local level = v.loopSrc.volume
        step(S, 4.0)
        H.truthy(v.loopSrc.playing, "still playing")
        H.near(v.loopSrc.volume, level, "same level", 1e-9)
        H.eq(#S.sustainVoices, 1, "one voice")
    end },

    { "noteOff releases over the patch's release time and frees the source", function()
        local _, S = setup()
        local v = S:noteOn("t", 0, 0.9)
        step(S, 0.3)
        v:noteOff()
        step(S, 0.1)
        local half = v.loopSrc.volume
        H.near(half, expectedLevel(S, v) * 0.5, "halfway through the release", 0.03)
        step(S, 0.15)
        H.falsy(v.loopSrc.playing, "stopped")
        H.eq(#S.sustainVoices, 0, "voice freed")
        H.eq(next(S.loopPools.t_loop.inUse), nil, "loop source back in the pool")
        H.truthy(v.attack.maxLife <= v.attack.elapsed + 0.2 + 1e-9, "attack layer cut to the release too")
    end },

    { "setPitch glides the loop to the new pitch", function()
        local _, S = setup()
        local v = S:noteOn("t", 0, 0.9)
        v:setPitch(7)
        step(S, 0.02)
        H.truthy(v.currentSemis > 0 and v.currentSemis < 7, "gliding")
        step(S, 0.5)
        H.near(v.loopSrc.pitch, 2 ^ ((7 + v.patch.tune) / 12), "arrived at +7", 1e-4)
    end },

    { "glideFrom starts the note at the previous pitch", function()
        local _, S = setup()
        local v = S:noteOn("t", 5, 0.9, { glideFrom = 0 })
        H.near(v.currentSemis, 0, "starts at 0")
        step(S, 0.5)
        H.near(v.currentSemis, 5, "ends at 5", 1e-3)
    end },

    { "half-speed FX drops sustained voices by a fifth too", function()
        local _, S = setup()
        local v = S:noteOn("t", 0, 0.9)
        S.fxHalfSpeed = true
        step(S, 0.05)
        H.near(v.loopSrc.pitch, 2 ^ ((-7 + v.patch.tune) / 12), "-7 semitones", 1e-6)
    end },

    { "running out of loop sources steals the oldest voice", function()
        local _, S = setup()
        local a = S:noteOn("t", 0, 0.9); step(S, 0.1)
        local b = S:noteOn("t", 2, 0.9); step(S, 0.1)
        local c = S:noteOn("t", 4, 0.9); step(S, 0.05)
        H.falsy(a:isSounding(), "oldest stolen")
        H.truthy(b:isSounding() and c:isSounding(), "newer two kept")
        H.eq(#S.sustainVoices, 2, "two voices")
        H.eq(c.loopSrc, a.loopSrc, "reused its source")
    end },

    { "an unknown patch gives no voice", function()
        local _, S = setup()
        H.eq(S:noteOn("nope", 0, 0.9), nil, "nil")
    end },

    -- ------------------------------------------------------------------
    -- In the game
    -- ------------------------------------------------------------------
    { "desktop test keys H and G hold voices until released", function()
        local M = H.loadMain()
        local S = M.Synth
        love.keypressed("h"); love.keypressed("g")
        H.play(1.0)
        H.eq(#S.sustainVoices, 2, "bass and pad sustaining")
        love.keyreleased("h"); love.keyreleased("g")
        H.play(1.2)
        H.eq(#S.sustainVoices, 0, "both released")
    end },
}
