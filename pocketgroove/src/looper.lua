-- ============================================================================
-- src/looper.lua — Master Clock, 4-Track Looper, Quantize Grids & Undo Stack
-- ============================================================================

local Config = require("src.config")
local Synth  = require("src.synth")

local math_floor = math.floor
local math_abs   = math.abs
local math_max   = math.max

local Looper = {
    bpm = Config.DEFAULT_BPM,
    bars = 2,          -- 2 Bars or 4 Bars
    playing = true,

    -- Clock. Positions are integer ticks at PPQN per beat; the playhead `tick`
    -- is a float advanced by real elapsed time (love.timer), never by the
    -- clamped frame dt, so dropped frames can't slow the tempo.
    PPQN = 480,
    GAP_LIMIT = 0.25,     -- a frame longer than this (hitch, suspend) skips its events
    tick = 0.0,
    prevTick = 0.0,
    lastClockTime = nil,
    resetPending = false, -- playhead reset: let events on tick 0 fire
    stutterAnchorTick = 0,

    -- Playback output: noteHandler(kind, ev, track) with kind "on", "off" or
    -- "grace" (drum flam). Set once by main.lua (Looper:setNoteHandler).
    noteHandler = nil,

    -- Derived each frame (drawing, drum repeat)
    phase = 0.0,
    prevPhase = 0.0,
    currentBeat = 1,
    currentStep = 1,
    activeTrack = 1,   -- Active track slot (1..4)
    currentTakeId = 0,
    undoStack = {},    -- { kind = "take", takeId, trackSlot } or { kind = "swap", ... }
    tracks = {},
    clickOn = false,   -- metronome click (Transport X)
    toastText = "READY - TAP [SELECT] TO SWITCH TRACKS",
    toastTimer = 2.5,

    -- Quantize grids per track. stepTicks at PPQN 480; FREE rounds to 1 tick.
    GRID_MODES = {
        { id = "1/4",   label = "1/4",   stepsPerBar = 4,   stepTicks = 480 },
        { id = "1/8",   label = "1/8",   stepsPerBar = 8,   stepTicks = 240 },
        { id = "1/16",  label = "1/16",  stepsPerBar = 16,  stepTicks = 120 },
        { id = "1/12T", label = "1/12T", stepsPerBar = 12,  stepTicks = 160 },
        { id = "FREE",  label = "FREE",  stepsPerBar = nil, stepTicks = nil },
    }
}

-- Each of the 4 tracks has an assigned instrumentId and its own per-track state,
-- so tracks can later switch instruments or share instrument types independently!
function Looper:init(Instruments)
    local defaultInstruments = { "drums", "harp", "bass", "pad" }
    self.tracks = {}
    for slot = 1, 4 do
        local instId = defaultInstruments[slot]
        local instDef = Instruments:getDefinition(instId)
        self.tracks[slot] = {
            id = slot,
            slot = slot,
            instrumentId = instId,
            name = instDef.name,
            shortName = instDef.shortName,
            gridIndex = instDef.defaultGridIndex or 3,
            volume = 0.80,
            swing = 0.50,      -- 0.50 = straight .. 0.75 = heavy (applied at playback)
            fx = { tone = 0.5, drive = 0.5, echo = 0.4, space = 0.5,
                   on = { tone = false, drive = false, echo = false, space = false } },
            meterPeak = 0.0,
            muted = false,
            events = {},
            sounding = {},     -- events whose playback note-on has fired and note-off not yet
            state = instDef:newState(),
        }
        Synth:configureTrackFx(self.tracks[slot])
    end
end

-- Reassign any track slot (1..4) to any registered instrumentId
function Looper:setTrackInstrument(trackIdx, instrumentId, Instruments)
    local track = self.tracks[trackIdx]
    local instDef = Instruments:getDefinition(instrumentId)
    if not track or not instDef then return end
    self:silenceTrack(trackIdx)
    track.instrumentId = instrumentId
    track.name = instDef.name
    track.shortName = instDef.shortName
    track.gridIndex = instDef.defaultGridIndex or track.gridIndex
    track.state = instDef:newState()
    track.events = {}
    self:showToast(string.format("TRACK %d -> %s", trackIdx, instDef.title or instDef.name))
end

-- Swing pushes events on odd 8th/16th grid positions late, at playback only.
-- Returns the offset in ticks for an event on `track`.
function Looper:getSwingOffset(ev, track)
    local sw = track.swing or 0.5
    local g = ev.grid
    if sw <= 0.5 or not g then return 0.0 end
    if g ~= self.PPQN / 2 and g ~= self.PPQN / 4 then return 0.0 end
    local idx = math_floor(ev.tick / g + 0.5)
    if idx % 2 == 1 then
        return (sw - 0.5) * 2.0 * g
    end
    return 0.0
end

-- Swing amount in sub-step units for a live repeat running at `stepsPerBar`.
function Looper:getLiveSwing(trackIdx, stepsPerBar)
    local track = self.tracks[trackIdx]
    if not track or (stepsPerBar ~= 8 and stepsPerBar ~= 16) then return 0.0 end
    return math_max(0.0, ((track.swing or 0.5) - 0.5) * 2.0)
end

function Looper:adjustSwing(trackIdx, delta)
    local track = self.tracks[trackIdx]
    if not track then return end
    track.swing = math_max(0.50, math.min(0.75, (track.swing or 0.5) + delta))
    self:showToast(string.format("TRACK %d SWING: %d%%", trackIdx, math_floor(track.swing * 100 + 0.5)))
end

-- Track page effect slots on the face buttons
Looper.FX_SLOTS = { X = "tone", Y = "drive", A = "echo", B = "space" }
Looper.FX_ORDER = { "tone", "drive", "echo", "space" }

function Looper:toggleTrackFx(trackIdx, slot)
    local track = self.tracks[trackIdx]
    if not track or not slot then return end
    track.fx.on[slot] = not track.fx.on[slot]
    if track.fx.on[slot] and track.fx[slot] <= 0.0 then track.fx[slot] = 0.5 end
    Synth:configureTrackFx(track)
    self:showToast(string.format("TRACK %d %s: %s", trackIdx, slot:upper(),
        track.fx.on[slot] and (math_floor(track.fx[slot] * 100 + 0.5) .. "%") or "OFF"))
end

function Looper:adjustTrackFx(trackIdx, slot, delta)
    local track = self.tracks[trackIdx]
    if not track or not slot then return end
    track.fx[slot] = math_max(0.0, math.min(1.0, track.fx[slot] + delta))
    track.fx.on[slot] = track.fx[slot] > 0.0
    Synth:configureTrackFx(track)
    self:showToast(string.format("TRACK %d %s: %d%%", trackIdx, slot:upper(), math_floor(track.fx[slot] * 100 + 0.5)))
end

Looper.FLAM_TIME = 0.028 -- seconds between grace note and main hit

function Looper:setNoteHandler(fn)
    self.noteHandler = fn
end

-- Send note-off for every note the looper started on this track
function Looper:silenceTrack(trackIdx)
    local track = self.tracks[trackIdx]
    if not track then return end
    local handler = self.noteHandler
    for ev in pairs(track.sounding) do
        track.sounding[ev] = nil
        if handler then handler("off", ev, track) end
    end
end

function Looper:silenceAll()
    for tIdx = 1, #self.tracks do self:silenceTrack(tIdx) end
end

-- Remove one event, releasing it first if it is sounding
function Looper:removeEventAt(track, i)
    local ev = table.remove(track.events, i)
    if ev and track.sounding[ev] then
        track.sounding[ev] = nil
        if self.noteHandler then self.noteHandler("off", ev, track) end
    end
    return ev
end

function Looper:showToast(msg)
    self.toastText = msg
    self.toastTimer = 2.4
end

function Looper:getTotalBeats()
    return self.bars * 4
end

function Looper:getTotalSixteenths()
    return self.bars * 16
end

function Looper:getLoopDuration()
    return (60.0 / self.bpm) * self:getTotalBeats()
end

function Looper:getLoopTicks()
    return self.bars * 4 * self.PPQN
end

function Looper:getTicksPerSecond()
    return self.bpm / 60.0 * self.PPQN
end

-- An event's position as a 0..1 fraction of the loop (for drawing)
function Looper:evPhase(ev)
    return ev.tick / self:getLoopTicks()
end

-- Refresh the values derived from the playhead
function Looper:syncPhase()
    local loop = self:getLoopTicks()
    self.phase = self.tick / loop
    self.prevPhase = self.prevTick / loop
    self.currentBeat = math_floor(self.tick / self.PPQN) + 1
    self.currentStep = math_floor(self.tick / (self.PPQN / 4)) + 1
end

-- Move the playhead to a loop fraction without firing anything
function Looper:seek(phase)
    self.tick = (phase % 1.0) * self:getLoopTicks()
    self.prevTick = self.tick
    self:syncPhase()
end

-- Back to bar 1.1; events on the downbeat fire on the next frame
function Looper:resetPlayhead()
    self.tick, self.prevTick = 0.0, 0.0
    self.resetPending = true
    self:syncPhase()
end

function Looper:getTrackGrid(trackIdx)
    local track = self.tracks[trackIdx]
    return self.GRID_MODES[track.gridIndex] or self.GRID_MODES[3]
end

function Looper:beginRecordingTake()
    self.currentTakeId = self.currentTakeId + 1
end

-- Record `ev` (event format v2, SPEC §8.2) on a track at the playhead.
-- Sets ev.tick, ev.grid, ev.takeId and ev.len (0 unless the caller holds the
-- note open with ev.open and sets len on release). Returns the event.
function Looper:recordEvent(trackIdx, ev)
    local track = self.tracks[trackIdx]
    if not track then return nil end

    ev.takeId = self.currentTakeId
    ev.len = ev.len or 0

    local top = self.undoStack[#self.undoStack]
    if not (top and top.kind == "take" and top.takeId == self.currentTakeId and top.trackSlot == trackIdx) then
        self:pushUndo({ kind = "take", takeId = self.currentTakeId, trackSlot = trackIdx })
    end

    local loop = self:getLoopTicks()
    local step
    if ev.overrideGridSteps then
        step = loop / ev.overrideGridSteps           -- note repeat: steps per loop -> ticks
    else
        step = self:getTrackGrid(trackIdx).stepTicks  -- nil = FREE
    end
    ev.overrideGridSteps = nil

    local now = self.tick
    local snapped
    if step then
        snapped = (math_floor(now / step + 0.5) * step) % loop
        -- Same action on the same step replaces the old one (circular distance)
        for i = #track.events, 1, -1 do
            local existing = track.events[i]
            if existing.action == ev.action then
                local d = math_abs(existing.tick - snapped)
                if d > loop * 0.5 then d = loop - d end
                if d < 0.4 * step then
                    self:removeEventAt(track, i)
                end
            end
        end
    else
        snapped = math_floor(now + 0.5) % loop
    end
    ev.tick = snapped
    ev.grid = step

    -- Snapped ahead of the playhead: the live press already played it
    local ahead = (snapped - now) % loop
    if ahead > 0 and ahead < loop * 0.05 then
        ev.skipOnce = true
    end

    table.insert(track.events, ev)
    return ev
end

function Looper:pushUndo(entry)
    table.insert(self.undoStack, entry)
end

-- Undo the most recent take or instrument swap. Takes whose events are all
-- gone already (erased, cleared) are skipped.
function Looper:undo()
    while #self.undoStack > 0 do
        local entry = table.remove(self.undoStack)
        local track = self.tracks[entry.trackSlot]
        if entry.kind == "fresh" then
            self:silenceAll()
            local total = 0
            for slot = 1, 4 do
                local t = self.tracks[slot]
                local saved = entry.tracks[slot]
                -- notes recorded since the fresh start stay, after the restored ones
                local kept = t.events
                t.events = saved.events
                for _, ev in ipairs(kept) do table.insert(t.events, ev) end
                t.muted = saved.muted
                total = total + #saved.events
            end
            self:showToast(string.format("UNDO: SESSION BACK (%d NOTES)", total))
            return
        elseif entry.kind == "swap" and track then
            self:silenceTrack(entry.trackSlot)
            track.instrumentId = entry.instrumentId
            track.name = entry.name
            track.shortName = entry.shortName
            track.gridIndex = entry.gridIndex
            track.state = entry.state
            track.events = entry.events
            self:showToast(string.format("UNDO: TRACK %d BACK TO %s (%d EVENTS)", entry.trackSlot, entry.name, #entry.events))
            return
        elseif entry.kind == "take" and track then
            local removed = 0
            for i = #track.events, 1, -1 do
                if track.events[i].takeId == entry.takeId then
                    self:removeEventAt(track, i)
                    removed = removed + 1
                end
            end
            if removed > 0 then
                self:showToast(string.format("UNDO TAKE #%d (%d HITS REMOVED)", entry.takeId, removed))
                return
            end
        end
    end
    self:showToast("NOTHING TO UNDO")
end

-- Per-Drum / Per-Button Clear: Delete only events matching `action` ("B", "A", "Y", "X") on `trackIdx`
function Looper:clearTrackAction(trackIdx, action, label)
    local track = self.tracks[trackIdx]
    if not track then return end
    local removed = 0
    for i = #track.events, 1, -1 do
        if track.events[i].action == action then
            self:removeEventAt(track, i)
            removed = removed + 1
        end
    end
    self:showToast(string.format("ERASED %s (%d HITS)", label or action, removed))
end

function Looper:countTrackAction(trackIdx, action)
    local track = self.tracks[trackIdx]
    if not track then return 0 end
    local count = 0
    for i = 1, #track.events do
        if track.events[i].action == action then
            count = count + 1
        end
    end
    return count
end

-- Fresh session: clear every track's notes and mutes; tempo, key,
-- instruments, sounds and effects stay. One undo entry brings it all back.
function Looper:freshSession()
    self:silenceAll()
    local saved, total = {}, 0
    for slot = 1, 4 do
        local track = self.tracks[slot]
        saved[slot] = { events = track.events, muted = track.muted }
        total = total + #track.events
        track.events = {}
        track.muted = false
    end
    self:pushUndo({ kind = "fresh", tracks = saved })
    self:showToast(string.format("FRESH SESSION (%d NOTES CLEARED - L2+R2+LEFT UNDOES)", total))
end

function Looper:clearTrack(trackIdx)
    local track = self.tracks[trackIdx]
    if track then
        self:silenceTrack(trackIdx)
        track.events = {}
        self:showToast("CLEARED ALL ON TRACK " .. trackIdx .. " (" .. track.name .. ")")
    end
end

function Looper:cycleGridMode(trackIdx)
    local track = self.tracks[trackIdx]
    if track then
        track.gridIndex = (track.gridIndex % #self.GRID_MODES) + 1
        local g = self.GRID_MODES[track.gridIndex]
        self:showToast("TRACK " .. trackIdx .. " QUANTIZE GRID: " .. g.label)
    end
end

function Looper:toggleBars()
    self:silenceAll()
    if self.bars == 2 then
        -- 2 -> 4 bars: bars 1-2 stay where they are and are copied into bars 3-4
        local oldLoop = self:getLoopTicks()
        self.bars = 4
        for tIdx = 1, 4 do
            local track = self.tracks[tIdx]
            for i = 1, #track.events do
                local copy = {}
                for k, v in pairs(track.events[i]) do copy[k] = v end
                copy.tick = copy.tick + oldLoop
                copy.skipOnce = nil
                if copy.bend then                      -- own keyframe list, not shared
                    local kfs = {}
                    for k = 1, #copy.bend do
                        local kf = copy.bend[k]
                        kfs[k] = { dt = kf.dt, degree = kf.degree, octave = kf.octave, semis = kf.semis,
                                   bright = kf.bright, move = kf.move }
                    end
                    copy.bend = kfs
                end
                table.insert(track.events, copy)
            end
        end
        self:showToast("LOOP LENGTH: 4 BARS (AUTO-DOUBLED BARS 1-2 -> 3-4)")
    else
        -- 4 -> 2 bars: keep bars 1-2
        self.bars = 2
        local loop = self:getLoopTicks()
        for tIdx = 1, 4 do
            local track = self.tracks[tIdx]
            for i = #track.events, 1, -1 do
                local ev = track.events[i]
                if ev.tick >= loop then
                    table.remove(track.events, i)
                else
                    if ev.tick + ev.len > loop then
                        ev.len = loop - ev.tick                 -- cut at the new loop end
                    end
                    if ev.bend then                             -- and its bends
                        for k = #ev.bend, 1, -1 do
                            if ev.tick + ev.bend[k].dt >= loop then table.remove(ev.bend, k) end
                        end
                    end
                end
            end
        end
        self.tick = self.tick % loop
        self:showToast("LOOP LENGTH: 2 BARS")
    end
    self.prevTick = self.tick
    self:syncPhase()
end

function Looper:toggleMute(trackIdx)
    local track = self.tracks[trackIdx]
    if track then
        track.muted = not track.muted
        if track.muted then self:silenceTrack(trackIdx) end
        self:showToast("TRACK " .. trackIdx .. " " .. (track.muted and "MUTED" or "UNMUTED"))
    end
end

function Looper:setPlaying(on)
    self.playing = on
    if not on then self:silenceAll() end
end

function Looper:update(dt, handler)
    handler = handler or self.noteHandler
    if self.toastTimer > 0 then
        self.toastTimer = math_max(0, self.toastTimer - dt)
    end

    -- Real time since the last frame (not the clamped dt)
    local now = love.timer.getTime()
    local elapsed = self.lastClockTime and math_max(0.0, now - self.lastClockTime) or 0.0
    self.lastClockTime = now

    if not self.playing then return end

    local loop = self:getLoopTicks()
    local tps = self:getTicksPerSecond()
    local rate = Synth.fxHalfSpeed and 0.5 or 1.0
    local advance = elapsed * tps * rate
    local window = self.PPQN / 4               -- stutter repeats one 1/16

    self.prevTick = self.tick
    if self.resetPending then
        self.prevTick = -1e-6                   -- so events on tick 0 fire
        self.resetPending = false
    end

    if Synth.fxBeatRepeat then
        local nextTick = self.tick + advance
        local anchor = self.stutterAnchorTick
        if nextTick >= anchor + window then
            self.prevTick = anchor - 1e-6
            self.tick = anchor + ((nextTick - anchor) % window)
        else
            self.tick = nextTick % loop
        end
    else
        self.tick = (self.tick + advance) % loop
        self.stutterAnchorTick = math_floor(self.tick / window) * window
    end

    -- A long hitch or suspend: keep time, but don't fire a burst of old events
    if elapsed > self.GAP_LIMIT then
        self.prevTick = self.tick
    end

    local prevBeat = self.currentBeat
    self:syncPhase()
    if self.clickOn and self.currentBeat ~= prevBeat then
        local downbeat = ((self.currentBeat - 1) % 4 == 0)
        Synth:trigger("perc_wood", downbeat and 5 or 0, downbeat and 0.55 or 0.32, 0.8)
    end

    local prev, cur = self.prevTick, self.tick
    local wrapped = (cur < prev)
    local function crossedAt(t)
        if not wrapped then
            return t > prev and t <= cur
        end
        return t > prev or t <= cur
    end
    local graceTicks = self.FLAM_TIME * tps

    for tIdx = 1, 4 do
        local track = self.tracks[tIdx]
        if not track.muted then
            for i = 1, #track.events do
                local ev = track.events[i]
                local t = (ev.tick + self:getSwingOffset(ev, track)) % loop
                if ev.open then
                    -- Still held while recording: don't play it, but a pass of
                    -- the playhead still uses up its "already played live" mark
                    if ev.skipOnce and crossedAt(t) then ev.skipOnce = nil end
                else

                    -- Flam grace note sounds just before the main hit
                    if ev.orn == "flam" and not ev.skipOnce and crossedAt((t - graceTicks) % loop) then
                        handler("grace", ev, track)
                    end

                    if crossedAt(t) then
                        if ev.skipOnce then
                            ev.skipOnce = nil     -- the live press already played this pass
                        else
                            track.meterPeak = math_max(track.meterPeak, ev.vel or 0.85)
                            if ev.len > 0 then track.sounding[ev] = true end
                            handler("on", ev, track)
                        end
                    end

                    if ev.len > 0 and track.sounding[ev] and crossedAt((t + math.min(ev.len, loop - 1)) % loop) then
                        track.sounding[ev] = nil
                        handler("off", ev, track)
                    end
                end
            end
        end
        track.meterPeak = math_max(0.0, track.meterPeak - dt * 3.5)
    end
end

return Looper
