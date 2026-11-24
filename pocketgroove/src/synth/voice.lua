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

-- A loop pool grows past its patch's voice count (tracks sharing the patch)
-- up to this many sources
Voice.MAX_LOOP_SOURCES = 24

local Install = {}

-- ---------------------------------------------------------------------------
-- Loop buffers
-- ---------------------------------------------------------------------------

-- The tuning correction (semitones) for a loop at `freq` Hz: the loop's real
-- frequency is snapped to SAMPLE_RATE / period
function Install.loopTune(Synth, freq)
    local sr = Config.SAMPLE_RATE
    local period = math_max(2, math_floor(sr / freq + 0.5))
    return 12.0 * math_log(freq / (sr / period)) / math_log(2.0)
end

-- Build a seamless loop at `freq` Hz from `wave(angle, loopAngle)`.
--   angle      the fundamental's angle (radians): use whole harmonics of it
--   loopAngle  the angle of the whole loop (one turn over all `periods`):
--              whole harmonics of it also loop, and sit between the
--              fundamental's harmonics (detuned partials that beat once per
--              loop, or a timbre that changes over the loop)
-- Returns soundData, the number of samples, and the tuning correction.
function Install.createLoop(Synth, freq, periods, wave)
    local sr = Config.SAMPLE_RATE
    local period = math_max(2, math_floor(sr / freq + 0.5))
    local n = period * periods
    local sd = love.sound.newSoundData(n, sr, 16, 1)
    local twoPi = Config.TWO_PI
    Synth:fillSamples(sd, n, function(i)
        return wave(twoPi * i / period, twoPi * i / n)
    end)
    return sd, n, Install.loopTune(Synth, freq)
end

-- A pool of looping sources for a patch's loop layer
function Install.createLoopPool(Synth, name, soundData, size)
    Synth.loopPools[name] = { sources = {}, inUse = {}, data = soundData }
    Install.growLoopPool(Synth, name, size)
end

function Install.growLoopPool(Synth, name, size)
    local pool = Synth.loopPools[name]
    if not pool or not pool.data then return end
    for i = #pool.sources + 1, size do
        local src = love.audio.newSource(pool.data, "static")
        src:setLooping(true)
        pool.sources[i] = src
    end
end

-- Register a patch (the pitched sound pool, SPEC §6)
--   attack   name of the one-shot pool played at note start (optional)
--   loop     name of the loop pool (optional: without it the patch is a
--            one-shot that rings out)
--   bright   name of the bright layer's loop pool (optional; same size as
--            `loop`, sources paired by index)
--   tune     semitone correction for the loop layer (from createLoop)
--   sustain  loop level (0..1) relative to the note's velocity
--   xfade    seconds for the loop to fade in under the attack
--   release  seconds to fade out after noteOff
--   octave   the octave of C that 0 semitones plays (default 4); an
--            instrument's `register` moves the patch to its own octave
--   overlap  true = notes ring over each other
--   silent   true = makes no sound (a chord track that isn't heard)
--   label, full, group   names for the Track page picker
--   gen      how to generate the buffers, on first use (preparePatch):
--            { attack = { dur, voices, fn(t) | make(Synth) -> fn }, freq,
--              loop = fn(angle, loopAngle), bright = fn(...), voices }
-- What instruments may ask of a patch (set here):
--   rings     notes ring on by themselves (overlap, or no loop)
--   sustains  a note lasts as long as it is held
function Install.definePatch(Synth, id, def)
    def.id = id
    def.tune = def.tune or 0.0
    def.rings = (def.overlap or not def.loop) and not def.silent or false
    def.sustains = (def.loop ~= nil) and not def.overlap
    def.built = (def.gen == nil)
    if not Synth.patches[id] then Synth.patchOrder[#Synth.patchOrder + 1] = id end
    Synth.patches[id] = def
end

-- Make sure a patch's buffers exist, with at least `voices` voices. Patches
-- are generated the first time they are needed, so the boot only pays for
-- the sounds in use.
function Install.preparePatch(Synth, id, voices)
    local p = Synth.patches[id]
    if not p or p.silent then return p end
    if p.building then Synth:finishPregenOf(p) end -- half built in the background
    local gen = p.gen
    if gen and not p.built then
        p.built = true
        p.building = true
        if gen.attack then
            local fn = gen.attack.fn or gen.attack.make(Synth)
            local sd = Synth:createBuffer(gen.attack.dur, fn)
            Synth:createPool(p.attack, sd, math_max(gen.attack.voices or 8, voices or 0), gen.attack.dur)
        end
        local n = math_max(gen.voices or 6, voices or 0)
        if gen.loop then
            Synth:createLoopPool(p.loop, (Synth:createLoop(gen.freq, gen.periods or 24, gen.loop)), n)
        end
        if gen.bright then
            Synth:createLoopPool(p.bright, (Synth:createLoop(gen.freq, gen.periods or 24, gen.bright)), n)
        end
        p.building = false
    elseif voices then
        if p.attack then Synth:growPool(p.attack, voices) end
        if p.loop then Synth:growLoopPool(p.loop, voices) end
        if p.bright then Synth:growLoopPool(p.bright, voices) end
    end
    return p
end

-- ---------------------------------------------------------------------------
-- Voices
-- ---------------------------------------------------------------------------

local function semisToRatio(semis)
    return clamp(2.0 ^ (semis / 12.0), 0.125, 8.0)
end

-- Start a note.
-- opts: { track, glideFrom, glideRate, vibrato,
--         attack, release   seconds, instead of the patch's xfade / release
--         bright, move      0..1: bright layer level, drift and shimmer depth
--         noAttack          true = skip the patch's attack one-shot
--         register          the instrument's octave of C at 0 semitones
--         voices            how many voices the instrument needs
--         decay             length of a one-shot patch (as Synth:trigger) }
-- Returns the voice, or nil if the patch doesn't exist or is silent.
-- A patch without a loop gives a voice that is only its one-shot.
function Install.noteOn(Synth, patchId, semis, vel, opts)
    local patch = Synth.patches[patchId]
    if not patch or patch.silent then return nil end
    opts = opts or {}
    Synth:preparePatch(patchId, opts.voices)
    local pool = patch.loop and Synth.loopPools[patch.loop]
    local shift = opts.register and (opts.register - (patch.octave or 4)) * 12 or 0

    -- Free loop source, or steal this patch's oldest voice
    local idx, src, brightSrc = 0, nil, nil
    if pool then
        idx = nil
        for i, s in ipairs(pool.sources) do
            if not pool.inUse[s] then idx = i break end
        end
        local brightPool = patch.bright and Synth.loopPools[patch.bright]
        if not idx then
            -- None free. Tracks sharing a patch share its pool, so a track
            -- steals only from itself while it is within its own voice count;
            -- past that (or with nothing of its own playing) the pool grows,
            -- up to MAX_LOOP_SOURCES, before stealing from anyone.
            local track, budget = opts.track, opts.voices or #pool.sources
            local mine, oldestMine, oldest = 0, nil, nil
            for _, v in ipairs(Synth.sustainVoices) do
                if v.patch == patch and v.alive and v.loopSrc then
                    if not oldest or v.age > oldest.age then oldest = v end
                    if v.track == track then
                        mine = mine + 1
                        if not oldestMine or v.age > oldestMine.age then oldestMine = v end
                    end
                end
            end
            if oldestMine and mine >= budget then
                oldest = oldestMine
            elseif #pool.sources < Voice.MAX_LOOP_SOURCES then
                local n = #pool.sources + 1
                Synth:growLoopPool(patch.loop, n)
                if brightPool then Synth:growLoopPool(patch.bright, n) end
                idx, oldest = n, nil
            end
            if oldest then
                oldest:kill()
                idx = oldest.srcIndex
            elseif not idx then
                return nil                -- (can't happen: every busy source has a voice)
            end
        end
        src = pool.sources[idx]
        pool.inUse[src] = true
        brightSrc = brightPool and brightPool.sources[idx] or nil
    end

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
        shift = shift,                 -- the instrument's register against the patch's
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
    if patch.attack and not (opts.noAttack and pool) then
        v.attack = Synth:trigger(patch.attack, semis + shift, v.vel, opts.decay or patch.attackDecay or 1.0,
                                 opts.glideFrom and (opts.glideFrom + shift), v.trackVolume, track)
        if v.attack and not pool then v.attack.vibrato = v.vibrato end
    end
    if not pool and not (v.attack and v.attack.elapsed) then return nil end    -- nothing to play

    for _, s in ipairs({ src, brightSrc }) do
        s:stop()
        Synth:applyTrackFx(s, track)
        s:setPitch(semisToRatio(startSemis + shift + patch.tune))
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
        self.attack.targetSemis = semis + self.shift
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
    if self.loopSrc then
        self.loopSrc:stop()
        self.pool.inUse[self.loopSrc] = nil
    end
    if self.brightSrc then self.brightSrc:stop() end
    if self.attack and self.attack.source then self.attack.maxLife = 0 end
end

function Voice:isSounding()
    return self.alive
end

-- A one-shot voice lasts as long as its one-shot
local function attackSounding(a)
    return a and a.elapsed and not a.evicted and a.elapsed < a.maxLife and a.source:isPlaying()
end

-- Loop level for this frame (0..1, before velocity and mix)
function Voice:envelope()
    if not self.loopSrc then
        local a = self.attack
        if not attackSounding(a) then return 0.0 end
        local left = 1.0 - a.elapsed / a.maxLife
        return left * left
    end
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
            local pitch = v.currentSemis + v.shift + vib + drift + fxPitch + v.patch.tune
            local level = v:envelope()
            local gain = level * v.vel * v.trackVolume * Synth.masterVolume * Synth.duckEnvelope
                * Synth:pumpGain(v.track)
            if v.loopSrc then
                v.loopSrc:setPitch(semisToRatio(pitch))
                v.loopSrc:setVolume(clamp(gain, 0.0, 1.0))
            elseif not attackSounding(v.attack) then
                v:kill()                      -- a one-shot voice ends with its one-shot
            end

            if v.brightSrc then
                -- bright layer: level = brightness (smoothed), detuned against
                -- the main layer and shimmering with the movement
                v.brightNow = v.brightNow + (v.bright - v.brightNow) * math_min(1.0, dt * 12.0)
                local shimmer = 1.0 - v.move * Voice.SHIMMER * (0.5 + 0.5 * math_sin(lfo * 2.3))
                v.brightSrc:setPitch(semisToRatio(pitch + v.move * Voice.DETUNE))
                v.brightSrc:setVolume(clamp(gain * v.brightNow * shimmer, 0.0, 1.0))
            end
            if v.loopSrc and v.releasedAt and level <= 0.0 then
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
    Synth.patchOrder = Synth.patchOrder or {}      -- ids in the order they were defined
    Synth.loopPools = Synth.loopPools or {}
    Synth.sustainVoices = Synth.sustainVoices or {}
    for name, fn in pairs(Install) do
        Synth[name] = fn
    end
end

Voice.class = Voice
return Voice
