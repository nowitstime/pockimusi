-- ============================================================================
-- src/synth/init.lua — Procedural Audio Engine & Voice Polyphony Pool
-- ============================================================================

local Config     = require("src.config")
local DrumsBank  = require("src.synth.drums_bank")
local SynthsBank = require("src.synth.synths_bank")
local Voice      = require("src.synth.voice")

local clamp      = Config.clamp
local math_sin   = math.sin
local math_floor = math.floor
local math_min   = math.min

local Synth = {
    pools = {},
    activeVoices = {},
    drumCatalog = {},
    -- Master Live Performance FX state
    fxBeatRepeat = false,
    fxHalfSpeed  = false,
    fxLowPass    = false,
    fxBitcrush   = false,
    duckEnvelope = 1.0,
    masterVolume = 0.85,
    -- Short-delay scheduler for sub-hits (flam main hit, ratchet bursts)
    clock = 0.0,
    scheduled = {},
}

-- Choke groups: triggering any sound in a group cuts ringing voices of the
-- listed "chokeable" sounds in the same group (closed hat cuts open hat).
Synth.CHOKE_GROUP = { hat_closed = "hat", hat_tick = "hat", hat_open = "hat" }
Synth.CHOKEABLE   = { hat_open = true }

-- Sustained voices: patches, loop pools, noteOn / updateVoices (voice.lua)
Voice.install(Synth)

function Synth:createBuffer(durationSec, generatorFn)
    local sampleCount = math_floor(durationSec * Config.SAMPLE_RATE)
    local sd = love.sound.newSoundData(sampleCount, Config.SAMPLE_RATE, 16, 1)
    for i = 0, sampleCount - 1 do
        local t = i / Config.SAMPLE_RATE
        local s = generatorFn(t, durationSec, i)
        sd:setSample(i, clamp(s, -1.0, 1.0))
    end
    return sd
end

function Synth:createPool(name, soundData, poolSize, baseDuration)
    local voices = {}
    for i = 1, poolSize do
        voices[i] = love.audio.newSource(soundData, "static")
    end
    self.pools[name] = {
        voices = voices,
        cursor = 1,
        size = poolSize,
        baseDuration = baseDuration,
    }
end

function Synth:init()
    local rng = love.math.newRandomGenerator(1337)
    local function whiteNoise()
        return rng:random() * 2.0 - 1.0
    end

    local t0 = love.timer.getTime()
    DrumsBank.build(self, whiteNoise)
    local t1 = love.timer.getTime()
    SynthsBank.build(self, whiteNoise)
    local t2 = love.timer.getTime()
    SynthsBank.buildSustain(self)
    local t3 = love.timer.getTime()
    self:initTrackFx()
    -- Boot cost, printed to the PortMaster log (log.txt) on the device
    self.bootTimes = { drums = t1 - t0, synths = t2 - t1, sustain = t3 - t2, total = t3 - t0 }
    print(string.format("[PocketGroove] sound generation: drums %.2fs, synths %.2fs, sustain loops %.2fs, total %.2fs",
        t1 - t0, t2 - t1, t3 - t2, t3 - t0))
end

-- ============================================================================
-- Per-track effects (Track page: X tone, Y drive, A echo, B space)
-- Uses OpenAL EFX through LÖVE: tone = low-pass filter on the voice, the
-- others are per-track effect sends. Without EFX, drive falls back to a gain
-- boost and the rest are silent no-ops.
-- ============================================================================
Synth.FX_SEND_ORDER = { "space", "echo", "drive" } -- priority when sends are limited

function Synth:initTrackFx()
    self.sourceFx = setmetatable({}, { __mode = "k" })
    self.fxSupported = false
    self.maxSends = 0
    if love.audio.isEffectsSupported and love.audio.isEffectsSupported() then
        self.fxSupported = true
        self.maxSends = love.audio.getMaxSourceEffects and love.audio.getMaxSourceEffects() or 0
    end
end

function Synth:fxName(trackSlot, slot)
    return "trk" .. trackSlot .. "_" .. slot
end

-- (Re)configure one track's effect units after its amounts change
function Synth:configureTrackFx(track)
    if not self.fxSupported or not track then return end
    local fx = track.fx
    local settings = {
        space = { type = "reverb", gain = 0.32, decaytime = 0.6 + fx.space * 3.4, density = 1.0, diffusion = 1.0 },
        echo  = { type = "echo", delay = 0.11 + fx.echo * 0.09, tapdelay = 0.2 + fx.echo * 0.2,
                  feedback = 0.25 + fx.echo * 0.5, damping = 0.4, spread = -0.8 },
        drive = { type = "distortion", gain = 0.2 + fx.drive * 0.6, edge = 0.2 + fx.drive * 0.7,
                  lowcut = 80, center = 3600, bandwidth = 3600 },
    }
    for slot, cfg in pairs(settings) do
        pcall(love.audio.setEffect, self:fxName(track.slot, slot), cfg)
    end
end

function Synth:applyTrackFx(src, track)
    -- Clear whatever this pooled source carried for its previous track
    local prev = self.sourceFx[src]
    if prev then
        for _, name in ipairs(prev) do pcall(src.setEffect, src, name, false) end
    end
    self.sourceFx[src] = nil
    if not self.fxSupported then return end

    local fx = track and track.fx
    if fx and fx.on.tone then
        pcall(src.setFilter, src, { type = "lowpass", volume = 1.0, highgain = math.max(0.03, 1.0 - fx.tone * 0.97) })
    else
        pcall(src.setFilter, src)
    end
    if not fx then return end

    local applied, used = {}, 0
    for _, slot in ipairs(self.FX_SEND_ORDER) do
        if fx.on[slot] and used < self.maxSends then
            local name = self:fxName(track.slot, slot)
            local sendGain = (slot == "drive") and 1.0 or clamp(0.25 + fx[slot] * 0.75, 0.0, 1.0)
            local ok = pcall(src.setEffect, src, name, { type = "lowpass", volume = sendGain, highgain = 1.0 })
            if ok then
                table.insert(applied, name)
                used = used + 1
            end
        end
    end
    if #applied > 0 then self.sourceFx[src] = applied end
end

-- Run fn after `delay` seconds (frame resolution).
function Synth:schedule(delay, fn)
    table.insert(self.scheduled, { at = self.clock + delay, fn = fn })
end

function Synth:choke(soundName)
    local group = self.CHOKE_GROUP[soundName]
    if not group then return end
    for i = 1, #self.activeVoices do
        local v = self.activeVoices[i]
        if v.soundName ~= soundName and self.CHOKEABLE[v.soundName] and self.CHOKE_GROUP[v.soundName] == group then
            v.maxLife = math_min(v.maxLife, v.elapsed + 0.03)
        end
    end
end

function Synth:trigger(soundName, pitchSemis, volume, decayMod, glideFromSemis, trackVolume, track)
    local pool = self.pools[soundName]
    if not pool then return nil end
    self:choke(soundName)

    local src = pool.voices[pool.cursor]
    pool.cursor = (pool.cursor % pool.size) + 1

    pitchSemis = pitchSemis or 0
    volume = volume or 0.85
    decayMod = decayMod or 1.0
    local trkVol = trackVolume or 1.0

    local fxPitchOffset = self.fxHalfSpeed and -7.0 or 0.0
    if self.fxBitcrush then
        pitchSemis = math_floor(pitchSemis * 0.5) * 2.0 + 0.35
        volume = math_min(1.0, volume * 1.15)
    end

    -- Drive without EFX: a plain gain push so the slot still does something
    if track and track.fx.on.drive and not self.fxSupported then
        volume = math_min(1.0, volume * (1.0 + track.fx.drive * 0.5))
    end

    local effectiveVolume = clamp(volume * trkVol * self.masterVolume * self.duckEnvelope, 0.0, 1.0)
    local startSemis = glideFromSemis or pitchSemis
    local pitchRatio = clamp(2.0 ^ ((startSemis + fxPitchOffset) / 12.0), 0.125, 8.0)

    -- Evict any old active voice using this source before reusing it
    for i = #self.activeVoices, 1, -1 do
        if self.activeVoices[i].source == src then
            table.remove(self.activeVoices, i)
        end
    end

    src:stop()
    self:applyTrackFx(src, track)
    src:setPitch(pitchRatio)
    src:setVolume(effectiveVolume)
    src:play()

    local voiceRecord = {
        source = src,
        soundName = soundName,
        elapsed = 0.0,
        maxLife = pool.baseDuration * clamp(decayMod, 0.15, 2.5),
        baseVolume = clamp(volume, 0.05, 1.0),
        trackVolume = trkVol,
        targetSemis = pitchSemis,
        currentSemis = startSemis,
        hasGlide = (glideFromSemis ~= nil and glideFromSemis ~= pitchSemis),
        vibrato = false,
    }
    table.insert(self.activeVoices, voiceRecord)
    return voiceRecord
end

function Synth:update(dt)
    self.clock = self.clock + dt
    self:updateVoices(dt)
    if #self.scheduled > 0 then
        local due = {}
        for i = #self.scheduled, 1, -1 do
            if self.scheduled[i].at <= self.clock then
                table.insert(due, 1, self.scheduled[i])
                table.remove(self.scheduled, i)
            end
        end
        for _, job in ipairs(due) do job.fn() end
    end

    if self.fxLowPass then
        self.duckEnvelope = clamp(self.duckEnvelope - dt * 4.5, 0.22, 1.0)
    else
        self.duckEnvelope = clamp(self.duckEnvelope + dt * 3.2, 0.22, 1.0)
    end

    local fxPitchOffset = self.fxHalfSpeed and -7.0 or 0.0

    for i = #self.activeVoices, 1, -1 do
        local v = self.activeVoices[i]
        v.elapsed = v.elapsed + dt

        if not v.source:isPlaying() or v.elapsed >= v.maxLife then
            v.source:stop()
            table.remove(self.activeVoices, i)
        else
            if v.hasGlide then
                local diff = v.targetSemis - v.currentSemis
                v.currentSemis = v.currentSemis + diff * math_min(1.0, dt * 18.0)
            end
            local vibOffset = v.vibrato and (math_sin(v.elapsed * 38.0) * 0.35) or 0.0
            local pitchRatio = clamp(2.0 ^ ((v.currentSemis + vibOffset + fxPitchOffset) / 12.0), 0.125, 8.0)
            v.source:setPitch(pitchRatio)

            local remaining = v.maxLife - v.elapsed
            local fade = (remaining < 0.04) and (remaining / 0.04) or 1.0
            v.source:setVolume(clamp(v.baseVolume * (v.trackVolume or 1.0) * self.masterVolume * fade * self.duckEnvelope, 0.0, 1.0))
        end
    end
end

return Synth
