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

    { "the real bass and pad loops are all seamless and in tune", function()
        H.captureSamples = true
        local M = H.fresh({ realSynth = true })
        M.Synth:init()
        H.captureSamples = false
        local S = M.Synth
        local names = {}
        for id, patch in pairs(S.patches) do
            names[#names + 1] = id
            local src = S.loopPools[patch.loop].sources[1]
            H.truthy(seamRatio(src.soundData) <= SMOOTH, id .. " seam " .. seamRatio(src.soundData))
            H.truthy(math.abs(patch.tune) < 0.05, id .. " tune " .. patch.tune)
            if patch.attack then H.truthy(S.pools[patch.attack] ~= nil, id .. " has its attack pool") end
            if patch.bright then
                local b = S.loopPools[patch.bright]
                H.truthy(seamRatio(b.sources[1].soundData) <= SMOOTH, id .. " bright seam")
                H.eq(#b.sources, #S.loopPools[patch.loop].sources, id .. " layers paired")
                H.eq(b.sources[1].soundData.n, src.soundData.n, id .. " layers the same length")
            end
        end
        table.sort(names)
        H.eq(table.concat(names, " "), "bass_pluck bass_saw bass_sub pad_bell pad_choir pad_drone pad_warm", "patches")
        H.truthy(S.bootTimes and S.bootTimes.sustain >= 0, "boot time measured")
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
