-- ============================================================================
-- src/synth/voice.lua — Sustained voices (SPEC §9.2)
--
-- A patch = an attack layer (an existing one-shot pool) + a loop layer (a
-- buffer of whole waveform periods, played looping so it never clicks).
-- noteOn starts both; the loop fades in under the attack; noteOff fades both
-- out over the patch's release time. Installed into Synth by Voice.install.
--
-- Pad patches add a second, "bright" loop layer (the upper harmonics) played
-- alongside the main one: its level is the voice's brightness, and the
-- voice's movement detunes and shimmers it (SPEC §7.4).
-- ============================================================================

local Config = require("src.config")

local clamp     = Config.clamp
local math_min  = math.min
local math_max  = math.max
local math_sin  = math.sin
local math_log  = math.log
local math_floor = math.floor

local Voice = {}
Voice.__index = Voice

local TWO_PI = Config.TWO_PI

-- Movement at full depth (opts.move = 1)
Voice.DRIFT   = 0.09     -- semitones of slow pitch drift either way (9 cents)
Voice.DETUNE  = 0.07     -- semitones the bright layer sits above the main one
Voice.SHIMMER = 0.35     -- how far the bright layer's level dips

local Install = {}

-- ---------------------------------------------------------------------------
-- Loop buffers
-- ---------------------------------------------------------------------------

-- Build a seamless loop at `freq` Hz from `wave(angle)`, a function of the
-- fundamental's angle (radians) that must only contain whole harmonics.
-- Returns soundData, the number of samples, and the tuning correction in
-- semitones (the loop's real frequency is snapped to SAMPLE_RATE / period).
function Install.createLoop(Synth, freq, periods, wave)
    local sr = Config.SAMPLE_RATE
    local period = math_max(2, math_floor(sr / freq + 0.5))
    local n = period * periods
    local sd = love.sound.newSoundData(n, sr, 16, 1)
    local twoPi = Config.TWO_PI
    for i = 0, n - 1 do
        sd:setSample(i, clamp(wave(twoPi * i / period), -1.0, 1.0))
    end
    local actual = sr / period
    local tune = 12.0 * math_log(freq / actual) / math_log(2.0)
    return sd, n, tune
end

-- A pool of looping sources for a patch's loop layer
function Install.createLoopPool(Synth, name, soundData, size)
    local sources = {}
    for i = 1, size do
        local src = love.audio.newSource(soundData, "static")
        src:setLooping(true)
        sources[i] = src
    end
    Synth.loopPools[name] = { sources = sources, inUse = {} }
end

-- Register a sustaining patch
--   attack   name of the one-shot pool played at note start (optional)
--   loop     name of the loop pool
--   bright   name of the bright layer's loop pool (optional; same size as
--            `loop`, sources paired by index)
--   tune     semitone correction for the loop layer (from createLoop)
--   sustain  loop level (0..1) relative to the note's velocity
--   xfade    seconds for the loop to fade in under the attack
--   release  seconds to fade out after noteOff
function Install.definePatch(Synth, id, def)
    Synth.patches[id] = def
end

-- ---------------------------------------------------------------------------
-- Voices
-- ---------------------------------------------------------------------------

local function semisToRatio(semis)
    return clamp(2.0 ^ (semis / 12.0), 0.125, 8.0)
end

-- Start a sustained note.
-- opts: { track, glideFrom, glideRate, vibrato,
--         attack, release   seconds, instead of the patch's xfade / release
--         bright, move      0..1: bright layer level, drift and shimmer depth
--         noAttack          true = skip the patch's attack one-shot }
-- Returns the voice, or nil if the patch doesn't exist.
function Install.noteOn(Synth, patchId, semis, vel, opts)
    local patch = Synth.patches[patchId]
    if not patch then return nil end
    opts = opts or {}
    local pool = Synth.loopPools[patch.loop]

    -- Free loop source, or steal this patch's oldest voice
    local idx
    for i, s in ipairs(pool.sources) do
        if not pool.inUse[s] then idx = i break end
    end
    if not idx then
        local oldest
        for _, v in ipairs(Synth.sustainVoices) do
            if v.patch == patch and (not oldest or v.age > oldest.age) then oldest = v end
        end
        oldest:kill()
        idx = oldest.srcIndex
    end
    local src = pool.sources[idx]
    pool.inUse[src] = true
    local brightPool = patch.bright and Synth.loopPools[patch.bright]
    local brightSrc = brightPool and brightPool.sources[idx] or nil

    local track = opts.track
    local startSemis = opts.glideFrom or semis
    local v = setmetatable({
        synth = Synth,
        patch = patch,
        pool = pool,
        loopSrc = src,
        brightSrc = brightSrc,
        srcIndex = idx,
        track = track,
        vel = clamp(vel or 0.85, 0.0, 1.0),
        trackVolume = track and track.volume or 1.0,
        currentSemis = startSemis,
        targetSemis = semis,
        glideRate = opts.glideRate or 18.0,
        vibrato = opts.vibrato or false,
        attackTime = opts.attack or patch.xfade,
        releaseTime = opts.release or patch.release,
        bright = clamp(opts.bright or 0.0, 0.0, 1.0),      -- target; brightNow follows it
        brightNow = clamp(opts.bright or 0.0, 0.0, 1.0),
        move = clamp(opts.move or 0.0, 0.0, 1.0),
        -- each source drifts at its own speed, so a chord's notes move apart
        lfoRate = 0.31 + (idx % 5) * 0.09,
        lfoPhase = idx * 1.7,
        age = 0.0,
        releasedAt = nil,
        alive = true,
    }, Voice)

    -- Attack layer: the patch's one-shot, glided the same way
    if patch.attack and not opts.noAttack then
        v.attack = Synth:trigger(patch.attack, semis, v.vel, patch.attackDecay or 1.0, opts.glideFrom, v.trackVolume, track)
    end

    for _, s in ipairs({ src, brightSrc }) do
        s:stop()
        Synth:applyTrackFx(s, track)
        s:setPitch(semisToRatio(startSemis + patch.tune))
        s:setVolume(0.0)
        s:play()
    end

    table.insert(Synth.sustainVoices, v)
    return v
end

-- Glide to a new pitch (semitones)
function Voice:setPitch(semis)
    self.targetSemis = semis
    if self.attack then
        self.attack.hasGlide = true
        self.attack.targetSemis = semis
    end
end

-- Start the release; the voice frees itself when silent
function Voice:noteOff()
    if self.releasedAt or not self.alive then return end
    self.releaseFrom = self:envelope()      -- fade from here (a slow attack may not be done)
    self.releasedAt = self.age
    if self.attack then
        self.attack.maxLife = math_min(self.attack.maxLife, self.attack.elapsed + self.releaseTime)
    end
end

-- Cancel a release that has started (legato takes the voice over)
function Voice:resume()
    if self.alive then self.releasedAt = nil end
end

-- Seconds since noteOff, or nil if not released
function Voice:releasedFor()
    return self.releasedAt and (self.age - self.releasedAt) or nil
end

-- Stop at once (voice stealing)
function Voice:kill()
    if not self.alive then return end
    self.alive = false
    self.loopSrc:stop()
    if self.brightSrc then self.brightSrc:stop() end
    self.pool.inUse[self.loopSrc] = nil
    if self.attack and self.attack.source then self.attack.maxLife = 0 end
end

function Voice:isSounding()
    return self.alive
end

-- Loop level for this frame (0..1, before velocity and mix)
function Voice:envelope()
    if self.releasedAt then
        return self.releaseFrom * math_max(0.0, 1.0 - (self.age - self.releasedAt) / math_max(self.releaseTime, 0.001))
    end
    return self.patch.sustain * math_min(1.0, self.age / math_max(self.attackTime, 0.001))
end

function Install.updateVoices(Synth, dt)
    local fxPitch = Synth.fxHalfSpeed and -7.0 or 0.0
    local voices = Synth.sustainVoices
    for i = #voices, 1, -1 do
        local v = voices[i]
        if v.alive then
            v.age = v.age + dt
            local diff = v.targetSemis - v.currentSemis
            v.currentSemis = v.currentSemis + diff * math_min(1.0, dt * v.glideRate)
            local vib = v.vibrato and (math_sin(v.age * 38.0) * 0.35) or 0.0
            -- movement: a slow drift of up to DRIFT semitones either way
            local lfo = v.age * v.lfoRate * TWO_PI + v.lfoPhase
            local drift = (v.move > 0.0) and (math_sin(lfo) * v.move * Voice.DRIFT) or 0.0
            local pitch = v.currentSemis + vib + drift + fxPitch + v.patch.tune
            v.loopSrc:setPitch(semisToRatio(pitch))

            local level = v:envelope()
            local gain = level * v.vel * v.trackVolume * Synth.masterVolume * Synth.duckEnvelope
            v.loopSrc:setVolume(clamp(gain, 0.0, 1.0))

            if v.brightSrc then
                -- bright layer: level = brightness (smoothed), detuned against
                -- the main layer and shimmering with the movement
                v.brightNow = v.brightNow + (v.bright - v.brightNow) * math_min(1.0, dt * 12.0)
                local shimmer = 1.0 - v.move * Voice.SHIMMER * (0.5 + 0.5 * math_sin(lfo * 2.3))
                v.brightSrc:setPitch(semisToRatio(pitch + v.move * Voice.DETUNE))
                v.brightSrc:setVolume(clamp(gain * v.brightNow * shimmer, 0.0, 1.0))
            end
            if v.releasedAt and level <= 0.0 then
                v:kill()
            end
        end
        if not v.alive then
            table.remove(voices, i)
        end
    end
end

-- Stop every sustained voice at once
function Install.killAllVoices(Synth)
    for _, v in ipairs(Synth.sustainVoices) do v:kill() end
    Synth.sustainVoices = {}
end

-- ---------------------------------------------------------------------------
function Voice.install(Synth)
    Synth.patches = Synth.patches or {}
    Synth.loopPools = Synth.loopPools or {}
    Synth.sustainVoices = Synth.sustainVoices or {}
    for name, fn in pairs(Install) do
        Synth[name] = fn
    end
end

Voice.class = Voice
return Voice
