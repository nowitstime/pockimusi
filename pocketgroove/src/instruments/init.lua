-- ============================================================================
-- src/instruments/init.lua — Pluggable Instrument Registry & Track Router
-- ============================================================================

local Input  = require("src.input")
local Looper = require("src.looper")

local Drums = require("src.instruments.drums")
local Harp  = require("src.instruments.harp")
local Bass  = require("src.instruments.bass")
local Pad   = require("src.instruments.pad")
local Lead  = require("src.instruments.lead")

local Instruments = {
    -- Ordered catalog of available instruments (add new instruments here!)
    catalog = {
        Drums,
        Harp,
        Bass,
        Pad,
        Lead,
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

local function copyEvent(ev)
    local rec = {}
    for k, v in pairs(ev) do rec[k] = v end
    return rec
end

-- Put a different instrument in a slot. The old instrument, its state and
-- its events go on the undo stack, so undo brings the track back.
-- Instruments of the same event class (Bass and Lead: `eventClass`) play each
-- other's notes, so the new one starts with a copy of the track's notes.
function Instruments:swapTrackInstrument(trackSlot, instrumentId)
    local track = Looper.tracks[trackSlot]
    if not track or track.instrumentId == instrumentId then return end
    self:releaseAll(trackSlot)
    local oldDef, newDef = self:getDefinition(track.instrumentId), self:getDefinition(instrumentId)
    local keep = oldDef.eventClass ~= nil and oldDef.eventClass == newDef.eventClass
    local oldEvents, oldGrid = track.events, track.gridIndex
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
    if keep then
        for i, ev in ipairs(oldEvents) do
            if not ev.open then track.events[#track.events + 1] = copyEvent(ev) end
        end
        track.gridIndex = oldGrid
        Looper:showToast(string.format("TRACK %d -> %s (%d NOTES KEPT)", trackSlot,
            newDef.title or newDef.name, #track.events))
    end
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

-- ---------------------------------------------------------------------------
-- Held-note handles (returned by hold(ev))
--   h:release()      end the note now (otherwise it ends on button-up)
--   h:bend(fields)   a change while the note sounds: pitch { degree, octave,
--                    semis } and / or Pad tone { bright, move }. The live
--                    voice follows (def:bendTo) and the recording gets a
--                    keyframe { dt, ...fields }. Works after release too,
--                    for as long as the instrument keeps bending the fading
--                    note; those keyframes land after len.
--   h:isHeld()
-- Time is counted in ticks since the press, frame by frame, so a note held
-- across the loop seam (or longer than half a loop) still measures right.
-- ---------------------------------------------------------------------------
local Handle = {}
Handle.__index = Handle

-- Ticks since the press; backward jumps (stutter FX) don't count
function Handle:advance()
    local loop = Looper:getLoopTicks()
    local d = (Looper.tick - self.lastTick) % loop
    if d < loop * 0.5 then self.elapsed = self.elapsed + d end
    self.lastTick = Looper.tick
    return self.elapsed
end

function Handle:isHeld()
    return self.held
end

function Handle:release()
    if not self.held then return end
    self.held = false
    local list = Instruments.held[self.track.slot]
    for i = #list, 1, -1 do
        if list[i] == self then table.remove(list, i) break end
    end
    Instruments:releaseNote(self.track, self)
end

function Handle:bend(fields)
    local def = defOf(Instruments, self.track)
    if def.bendTo then def:bendTo(self.ev, fields, self.track.state, self.track) end

    local rec = self.rec
    if not rec then return end
    local loop = Looper:getLoopTicks()
    local e = self:advance()
    if e >= loop - 1 then return end           -- longer than a loop: stop recording bends
    local dt = math.floor(e + 0.5)
    rec.bend = rec.bend or {}
    local kf = { dt = dt, degree = fields.degree, octave = fields.octave, semis = fields.semis,
                 bright = fields.bright, move = fields.move }
    local last = rec.bend[#rec.bend]
    if last and last.dt == dt then
        rec.bend[#rec.bend] = kf                 -- several changes in one tick: keep the latest
    else
        table.insert(rec.bend, kf)
    end
end

-- Held note from a live press; returns its handle.
-- opts.fixedLen = ticks: the note lasts exactly that long whatever the button
-- does (staccato); it still ends early if a page takes the controls.
-- opts.recLen = ticks: the length to record, if different (an arp note
-- pressed a moment off its grid step still records the step's length).
function Instruments:holdNote(track, ev, opts)
    defOf(self, track):noteOn(ev, track.state, track, false)
    local h = setmetatable({ ev = ev, track = track, held = true, elapsed = 0.0, lastTick = Looper.tick,
                             ageSec = 0.0, fixedLen = opts and opts.fixedLen or nil,
                             recLen = opts and opts.recLen or nil }, Handle)
    if Input:isRecording() then
        local rec = copyEvent(ev)
        rec.open = true                    -- not played back until released
        h.rec = Looper:recordEvent(track.slot, rec)
    end
    table.insert(self.held[track.slot], h)
    return h
end

function Instruments:releaseNote(track, h)
    local def = defOf(self, track)
    if def.noteOff then def:noteOff(h.ev, track.state, track, false) end
    if h.rec then
        local loop = Looper:getLoopTicks()
        local len = h.recLen or h.fixedLen or math.floor(h:advance() + 0.5)
        h.rec.len = math.max(1, math.min(loop - 1, len))
        h.rec.open = nil
    end
end

-- Release every live held note on a track (or all tracks)
function Instruments:releaseAll(slot)
    for s = slot or 1, slot or 4 do
        local list = self.held[s]
        for i = #list, 1, -1 do
            list[i]:release()
        end
    end
end

-- The bend keyframe in effect `elapsed` ticks after a note's start, or nil
-- (no bend yet: the note's own pitch)
function Instruments:bendAt(ev, elapsed)
    local bend = ev.bend
    if not bend then return nil end
    local found
    for i = 1, #bend do
        if bend[i].dt <= elapsed then found = bend[i] else break end
    end
    return found
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
            def:updateVisuals(dt, track.state, controlsBlocked, slot == Looper.activeTrack)
        end
    end

    -- Live input goes to the active track's instrument
    local def, state, track = self:getTrackInstrument(Looper.activeTrack)
    if not controlsBlocked and def.updateInput then
        def:updateInput(dt, state, track,
            function(ev) self:playNote(track, ev) end,
            function(ev, opts) return self:holdNote(track, ev, opts) end)
    end

    -- Held notes end when their button goes up, a page takes the controls,
    -- or the track is no longer the active one
    for s = 1, 4 do
        local list = self.held[s]
        for i = #list, 1, -1 do
            local h = list[i]
            h:advance()
            h.ageSec = h.ageSec + dt
            local done
            if h.fixedLen then
                -- fixed length: by ticks, or by time when the clock is paused
                done = h.elapsed >= h.fixedLen or h.ageSec >= h.fixedLen / Looper:getTicksPerSecond()
            else
                done = not Input.down[h.ev.action]
            end
            if done or controlsBlocked or s ~= Looper.activeTrack then
                h:release()
            end
        end
    end

    -- Sounding notes on all tracks (bass bends, pad chord changes and tone)
    for slot = 1, 4 do
        local trk = Looper.tracks[slot]
        local d = self:getDefinition(trk.instrumentId)
        if d.updateVoices then
            d:updateVoices(dt, trk.state, trk)
        end
    end
end

return Instruments
