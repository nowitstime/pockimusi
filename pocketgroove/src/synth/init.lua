-- ============================================================================
-- src/synth/init.lua — Procedural Audio Engine & Voice Polyphony Pool
-- ============================================================================

local Config     = require("src.config")
local DrumsBank  = require("src.synth.drums_bank")
local SynthsBank = require("src.synth.synths_bank")

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
}

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

    DrumsBank.build(self, whiteNoise)
    SynthsBank.build(self, whiteNoise)
end

function Synth:trigger(soundName, pitchSemis, volume, decayMod, glideFromSemis)
    local pool = self.pools[soundName]
    if not pool then return nil end

    local src = pool.voices[pool.cursor]
    pool.cursor = (pool.cursor % pool.size) + 1

    pitchSemis = pitchSemis or 0
    volume = volume or 0.85
    decayMod = decayMod or 1.0

    local fxPitchOffset = self.fxHalfSpeed and -7.0 or 0.0
    if self.fxBitcrush then
        pitchSemis = math_floor(pitchSemis * 0.5) * 2.0 + 0.35
        volume = math_min(1.0, volume * 1.15)
    end

    local effectiveVolume = clamp(volume * self.duckEnvelope, 0.0, 1.0)
    local startSemis = glideFromSemis or pitchSemis
    local pitchRatio = clamp(2.0 ^ ((startSemis + fxPitchOffset) / 12.0), 0.125, 8.0)

    src:stop()
    src:setPitch(pitchRatio)
    src:setVolume(effectiveVolume)
    src:play()

    local voiceRecord = {
        source = src,
        soundName = soundName,
        elapsed = 0.0,
        maxLife = pool.baseDuration * clamp(decayMod, 0.15, 2.5),
        baseVolume = clamp(volume, 0.05, 1.0),
        targetSemis = pitchSemis,
        currentSemis = startSemis,
        hasGlide = (glideFromSemis ~= nil and glideFromSemis ~= pitchSemis),
        vibrato = false,
    }
    table.insert(self.activeVoices, voiceRecord)
    return voiceRecord
end

function Synth:update(dt)
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
            v.source:setVolume(clamp(v.baseVolume * fade * self.duckEnvelope, 0.0, 1.0))
        end
    end
end

return Synth
