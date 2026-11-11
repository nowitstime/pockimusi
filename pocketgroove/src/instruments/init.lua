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

-- Rows for the Track page. Instruments with a single patch get one PATCH row.
function Instruments:getSoundRows(def, state)
    if def.getSoundRows then
        return def:getSoundRows(state)
    end
    return { { key = "PATCH", label = "PATCH", value = def.patchName or def.title or def.name } }
end

-- L1 / R1 on a Track page row: setting rows change their value, sound rows
-- change the sound (with a preview)
function Instruments:cycleRow(def, state, rowIdx, delta)
    local row = self:getSoundRows(def, state)[rowIdx]
    if not row then return end
    if row.kind == "setting" then
        if def.cycleSetting then def:cycleSetting(state, row.key, delta) end
    elseif def.cycleRowSound then
        def:cycleRowSound(state, rowIdx, delta)
    else
        Looper:showToast(def.name .. ": ONE PATCH FOR NOW")
    end
end

-- The instrument `delta` steps away from `instrumentId` in the catalog
function Instruments:stepInstrumentId(instrumentId, delta)
    local curIdx = 1
    for i, inst in ipairs(self.catalog) do
        if inst.id == instrumentId then
            curIdx = i
            break
        end
    end
    return self.catalog[((curIdx - 1 + delta) % #self.catalog) + 1].id
end

-- Put a different instrument in a slot. The old instrument, its state and
-- its events go on the undo stack, so undo brings the track back.
function Instruments:swapTrackInstrument(trackSlot, instrumentId)
    local track = Looper.tracks[trackSlot]
    if not track or track.instrumentId == instrumentId then return end
    Looper:pushUndo({
        kind = "swap",
        trackSlot = trackSlot,
        instrumentId = track.instrumentId,
        name = track.name,
        shortName = track.shortName,
        gridIndex = track.gridIndex,
        state = track.state,
        events = track.events,
    })
    Looper:setTrackInstrument(trackSlot, instrumentId, self)
end

function Instruments:triggerEvent(ev, track, isPlayback, part)
    track = track or Looper.tracks[ev.trackSlot or ev.instrument or Looper.activeTrack]
    if not track then return end

    local instId = ev.instrumentId or track.instrumentId
    local def = self:getDefinition(instId)
    def:triggerEvent(ev, track.state, isPlayback, part)

    if not isPlayback and not part and Input:isRecording() then
        Looper:recordEvent({
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
            orn               = ev.orn,
            ratchet           = ev.ratchet,
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
