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
    self:releaseAll(trackSlot)
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

-- ---------------------------------------------------------------------------
-- Notes (event format v2, SPEC §8.2)
--
-- Instrument API:
--   def:noteOn(ev, state, track, isPlayback)   live press or playback start
--   def:noteOff(ev, state, track, isPlayback)  live release or playback end (len > 0)
--   def:grace(ev, state, track)                 drum flam grace note (playback)
--   def:updateVoices(dt, state, track)          every frame, every track (optional)
--   def:updateInput(dt, state, track, play, hold)
--       play(ev)  a one-shot: sounds now, recorded with len = 0
--       hold(ev)  a held note: sounds now, released automatically when
--                 ev.action's button goes up (or a page takes the controls);
--                 recorded with the held length
-- Events carry no track or instrument fields: the track owns them.
-- ---------------------------------------------------------------------------

Instruments.held = { {}, {}, {}, {} }      -- per track: live held notes

local function copyEvent(ev)
    local rec = {}
    for k, v in pairs(ev) do rec[k] = v end
    return rec
end

local function defOf(self, track)
    return self:getDefinition(track.instrumentId)
end

-- One-shot from a live press
function Instruments:playNote(track, ev)
    defOf(self, track):noteOn(ev, track.state, track, false)
    if Input:isRecording() then
        Looper:recordEvent(track.slot, copyEvent(ev))
    end
end

-- Held note from a live press; released by Instruments:update
function Instruments:holdNote(track, ev)
    defOf(self, track):noteOn(ev, track.state, track, false)
    local h = { ev = ev, pressTick = Looper.tick }
    if Input:isRecording() then
        local rec = copyEvent(ev)
        rec.open = true                    -- not played back until released
        h.rec = Looper:recordEvent(track.slot, rec)
    end
    table.insert(self.held[track.slot], h)
end

function Instruments:releaseNote(track, h)
    local def = defOf(self, track)
    if def.noteOff then def:noteOff(h.ev, track.state, track, false) end
    if h.rec then
        local loop = Looper:getLoopTicks()
        local held = (Looper.tick - h.pressTick) % loop
        h.rec.len = math.max(1, math.min(loop - 1, math.floor(held + 0.5)))
        h.rec.open = nil
    end
end

-- Release every live held note on a track (or all tracks)
function Instruments:releaseAll(slot)
    for s = slot or 1, slot or 4 do
        local track = Looper.tracks[s]
        local list = self.held[s]
        for i = #list, 1, -1 do
            self:releaseNote(track, table.remove(list, i))
        end
    end
end

-- Playback from the looper: kind = "on", "off" or "grace"
function Instruments:handleLooperNote(kind, ev, track)
    local def = defOf(self, track)
    if kind == "on" then
        def:noteOn(ev, track.state, track, true)
    elseif kind == "off" then
        if def.noteOff then def:noteOff(ev, track.state, track, true) end
    elseif kind == "grace" then
        if def.grace then def:grace(ev, track.state, track) end
    end
end

function Instruments:update(dt, controlsBlocked)
    -- Visual animations on all tracks, so background tracks decay smoothly
    for slot = 1, 4 do
        local track = Looper.tracks[slot]
        local def = self:getDefinition(track.instrumentId)
        if def.updateVisuals then
            def:updateVisuals(dt, track.state, controlsBlocked)
        end
    end

    -- Live input goes to the active track's instrument
    local def, state, track = self:getTrackInstrument(Looper.activeTrack)
    if not controlsBlocked and def.updateInput then
        def:updateInput(dt, state, track,
            function(ev) self:playNote(track, ev) end,
            function(ev) self:holdNote(track, ev) end)
    end

    -- Held notes end when their button goes up, a page takes the controls,
    -- or the track is no longer the active one
    for s = 1, 4 do
        local list = self.held[s]
        for i = #list, 1, -1 do
            local h = list[i]
            if controlsBlocked or s ~= Looper.activeTrack or not Input.down[h.ev.action] then
                table.remove(list, i)
                self:releaseNote(Looper.tracks[s], h)
            end
        end
    end

    -- Continuous voices (grain spawners, later sustained notes) on all tracks
    for slot = 1, 4 do
        local trk = Looper.tracks[slot]
        local d = self:getDefinition(trk.instrumentId)
        if d.updateVoices then
            d:updateVoices(dt, trk.state, trk)
        end
    end
end

return Instruments
