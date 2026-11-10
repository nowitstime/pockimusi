-- ============================================================================
-- src/instruments/init.lua — Pluggable Instrument Registry & Track Router
-- ============================================================================

local Input  = require("src.input")
local Looper = require("src.looper")

local Drums = require("src.instruments.drums")
local Harp  = require("src.instruments.harp")
local Bass  = require("src.instruments.bass")
local Grain = require("src.instruments.grain")

local Instruments = {
    -- Ordered catalog of available instruments (add new instruments here!)
    catalog = {
        Drums,
        Harp,
        Bass,
        Grain,
    },
    byId = {},
}

for _, inst in ipairs(Instruments.catalog) do
    Instruments.byId[inst.id] = inst
end

function Instruments:getDefinition(instrumentId)
    return self.byId[instrumentId] or Drums
end

function Instruments:getTrackInstrument(trackSlot)
    local track = Looper.tracks[trackSlot or Looper.activeTrack]
    if not track then return Drums, nil, nil end
    local def = self:getDefinition(track.instrumentId)
    return def, track.state, track
end

function Instruments:cycleTrackInstrument(trackSlot, delta)
    delta = delta or 1
    local track = Looper.tracks[trackSlot or Looper.activeTrack]
    if not track then return end
    local curIdx = 1
    for i, inst in ipairs(self.catalog) do
        if inst.id == track.instrumentId then
            curIdx = i
            break
        end
    end
    local nextIdx = ((curIdx - 1 + delta) % #self.catalog) + 1
    local nextInst = self.catalog[nextIdx]
    Looper:setTrackInstrument(track.slot, nextInst.id, self)
end

function Instruments:triggerEvent(ev, track, isPlayback)
    track = track or Looper.tracks[ev.trackSlot or ev.instrument or Looper.activeTrack]
    if not track then return end

    local instId = ev.instrumentId or track.instrumentId
    local def = self:getDefinition(instId)
    def:triggerEvent(ev, track.state, isPlayback)

    if not isPlayback and Input:isRecording() then
        Looper:recordEvent({
            phase             = Looper.phase,
            step              = Looper.currentStep,
            trackSlot         = track.slot,
            instrumentId      = instId,
            action            = ev.action,
            soundId           = ev.soundId,
            pitchSemis        = ev.pitchSemis or 0,
            velocity          = ev.velocity or 0.85,
            chordName         = ev.chordName,
            decayMod          = ev.decayMod or 1.0,
            glideFromSemis    = ev.glideFromSemis,
            scanPos           = ev.scanPos,
            overrideGridSteps = ev.overrideGridSteps,
        })
    end
end

function Instruments:update(dt, controlsBlocked)
    -- Update visual animations across all 4 tracks so background tracks decay smoothly
    for slot = 1, 4 do
        local track = Looper.tracks[slot]
        if track then
            local def = self:getDefinition(track.instrumentId)
            if def.updateVisuals then
                def:updateVisuals(dt, track.state, controlsBlocked)
            end
        end
    end

    if controlsBlocked then
        return
    end

    -- Route live controller input to the currently active track's instrument
    local def, state, track = self:getTrackInstrument(Looper.activeTrack)
    if def and def.updateInput and track then
        def:updateInput(dt, state, track, function(ev, isPlayback)
            self:triggerEvent(ev, track, isPlayback)
        end)
    end
end

return Instruments
