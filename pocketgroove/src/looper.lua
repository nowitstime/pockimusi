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
    activeTrack = 1,   -- Active track slot (1..4, or LANE = track C)
    -- Track C: the chord lane (Phase K), kept in tracks[LANE] outside the four
    -- instrument slots. Its chords live on their own timeline (2..16 bars),
    -- so the looper counts loop passes to know where in the lane it is.
    LANE = 5,
    pass = 0,          -- loop passes since the playhead was reset
    currentTakeId = 0,
    undoStack = {},    -- { kind = "take", takeId, trackSlot }, { kind = "swap", ... }, { kind = "events", trackSlot, events, label },
                       -- { kind = "fresh", tracks } or { kind = "bars", tracks, takeId }
    UNDO_LIMIT = 64,   -- oldest entries are dropped past this (swaps and fresh starts hold whole tracks)
    tracks = {},
    -- Click (Transport X cycles off -> on -> count-in -> on + count-in)
    clickOn = false,   -- metronome click on every beat
    countIn = false,   -- a record tap counts in to the next bar line (SPEC §3.5)
    counting = false,  -- a count-in is running (set by Modes): clicks even if clickOn is off
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
            pump = 1,          -- PUMP row: index into Synth.PUMP_LEVELS (1 = off)
            swing = 0.50,      -- 0.50 = straight .. 0.75 = heavy (applied at playback)
            fx = { tone = 0.5, drive = 0.5, echo = 0.4, space = 0.5,
                   on = { tone = false, drive = false, echo = false, space = false } },
            muted = false,
            events = {},
            rev = 0,           -- bumped whenever the events change (Looper:touch; Harmony's cache)
            sounding = {},     -- events whose playback note-on has fired and note-off not yet
            state = instDef:newState(),
        }
        Synth:configureTrackFx(self.tracks[slot])
    end
    self:initLane(Instruments)
end

-- After the loop length changes: keep the song position (and so the place
-- in track C's lane) where it was. `oldSong` = songTick() before the change.
-- Going 2 -> 4 bars on an odd pass puts the playhead in bars 3-4, which are
-- a copy of bars 1-2 (or, on undo, the bars that were there), so it sounds
-- the same.
function Looper:keepSongPos(oldSong)
    local loop = self:getLoopTicks()
    self.pass = math_floor(oldSong / loop)
    self.tick = oldSong - self.pass * loop
end

-- Track C: the chord lane. A track object (events, state, rev) like the
-- others, so pages, undo and Harmony can treat it as one, but it is never
-- played back and never takes another instrument.
function Looper:initLane(Instruments)
    local def = Instruments:getDefinition("lane")
    local lane = {
        id = self.LANE, slot = self.LANE, isLane = true,
        instrumentId = "lane", name = def.name, shortName = def.shortName,
        gridIndex = 1, volume = 0.8, swing = 0.5,
        fx = { tone = 0.5, drive = 0.5, echo = 0.4, space = 0.5,
               on = { tone = false, drive = false, echo = false, space = false } },
        muted = false, events = {}, rev = 0, sounding = {},
        state = def:newState(),
    }
    -- (no Synth:configureTrackFx: the lane's effects are always off, so its
    -- preview voices never send to them and it needs no effect units)
    self.tracks[self.LANE] = lane
end

function Looper:getLane()
    return self.tracks[self.LANE]
end

-- How a track is named on screen: 1..4, or C for the chord lane
function Looper:slotLabel(slot)
    return slot == self.LANE and "C" or tostring(slot)
end

Looper.BAR_TICKS = 4 * Looper.PPQN

function Looper:getLaneBars()
    local lane = self.tracks[self.LANE]
    return (lane and lane.state.bars) or 4
end

function Looper:getLaneTicks()
    return self:getLaneBars() * self.BAR_TICKS
end

-- The song position: ticks since the playhead was reset, counting passes
function Looper:songTick()
    return self.pass * self:getLoopTicks() + self.tick
end

-- The song position of a loop tick near the playhead: a tick far behind the
-- playhead is in the next pass (the playhead is about to wrap to it), one
-- far ahead is in the pass before
function Looper:songTickAt(t)
    local loop = self:getLoopTicks()
    local p = self.pass
    local d = t - self.tick
    if d < -loop * 0.5 then p = p + 1 elseif d > loop * 0.5 then p = p - 1 end
    return p * loop + t
end

-- Where in the lane a song position is (the lane repeats)
function Looper:lanePos(song)
    return (song or self:songTick()) % self:getLaneTicks()
end

-- Move the playhead to a lane position without firing anything (track C
-- with the clock stopped: the playhead is the cursor)
function Looper:seekLane(pos)
    local loop = self:getLoopTicks()
    pos = pos % self:getLaneTicks()
    self.pass = math_floor(pos / loop)
    self.tick = pos % loop
    self.prevTick = self.tick
    self:syncPhase()
end

-- Mark a track's events as changed (anything that adds, removes or edits
-- events in place calls this; replacing track.events with a new table is
-- seen without it)
function Looper:touch(track)
    track.rev = (track.rev or 0) + 1
end

-- A deep copy of an event: its keyframe lists and chord are its own
local function copyValue(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = copyValue(x) end
    return out
end
Looper.copyEvent = copyValue

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
    self:showToast(string.format("TRACK %d -> %s", trackIdx, instDef.name))
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
Looper.FX_BUTTONS = { tone = "X", drive = "Y", echo = "A", space = "B" }

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
    -- whole percent, so ten 10 % steps down from 100 % land on exactly 0
    track.fx[slot] = math_floor(math_max(0.0, math.min(1.0, track.fx[slot] + delta)) * 100 + 0.5) / 100
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
    if ev then self:touch(track) end
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
    self.pass = 0
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

    -- Plays ahead of the playhead (where swing puts it, too): the live press
    -- already played it
    local ahead = (snapped + self:getSwingOffset(ev, track) - now) % loop
    if ahead > 0 and ahead < loop * 0.05 then
        ev.skipOnce = true
    end

    table.insert(track.events, ev)
    self:touch(track)
    return ev
end

function Looper:pushUndo(entry)
    table.insert(self.undoStack, entry)
    while #self.undoStack > self.UNDO_LIMIT do table.remove(self.undoStack, 1) end
end

-- Undo the most recent take or instrument swap. Takes whose events are all
-- gone already (erased, cleared) are skipped.
function Looper:undo()
    while #self.undoStack > 0 do
        local entry = table.remove(self.undoStack)
        local track = self.tracks[entry.trackSlot]
        if entry.kind == "bars" then
            -- 4 -> 2 bars: back to 4 bars with bars 3-4 as they were; notes
            -- recorded since (later takes) stay
            self:silenceAll()
            local song = self:songTick()
            self.bars = entry.bars
            self:keepSongPos(song)
            for slot = 1, 4 do
                local t = self.tracks[slot]
                local events = entry.tracks[slot]
                for _, ev in ipairs(t.events) do
                    if (ev.takeId or 0) > entry.takeId then table.insert(events, ev) end
                end
                t.events = events
            end
            self.prevTick = self.tick
            self:syncPhase()
            self:showToast(string.format("UNDO: LOOP LENGTH BACK TO %d BARS", entry.bars))
            return
        elseif entry.kind == "fresh" then
            self:silenceAll()
            local total = 0
            for slot = 1, #self.tracks do
                local t = self.tracks[slot]
                local saved = entry.tracks[slot] or { events = {}, muted = false }
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
        elseif entry.kind == "events" and track then
            -- an edit that replaced a track's events (track C: write, stamp, clear, colour)
            self:silenceTrack(entry.trackSlot)
            track.events = entry.events
            if entry.laneBars then track.state.bars = entry.laneBars end   -- track C's BARS row
            self:showToast(string.format("UNDO %s ON TRACK %s", entry.label or "EDIT", self:slotLabel(entry.trackSlot)))
            return
        elseif entry.kind == "take" and track then
            local removed = 0
            for i = #track.events, 1, -1 do
                if track.events[i].takeId == entry.takeId then
                    self:removeEventAt(track, i)       -- (touches the track)
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

-- Per-Drum / Per-Button Clear: delete only the events on `trackIdx` whose
-- action is `actions`: one action ("B", "A", "Y", "X", "L1", "R1") or a list
function Looper:clearTrackAction(trackIdx, actions, label)
    local track = self.tracks[trackIdx]
    if not track then return end
    if type(actions) ~= "table" then actions = { actions } end
    local match = {}
    for _, a in ipairs(actions) do match[a] = true end
    local removed = 0
    for i = #track.events, 1, -1 do
        if match[track.events[i].action] then
            self:removeEventAt(track, i)
            removed = removed + 1
        end
    end
    self:showToast(string.format("ERASED %s (%d HITS)", label or table.concat(actions, " + "), removed))
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
    for slot = 1, #self.tracks do
        local track = self.tracks[slot]
        saved[slot] = { events = track.events, muted = track.muted }
        total = total + #track.events
        track.events = {}
        track.muted = false
    end
    self:pushUndo({ kind = "fresh", tracks = saved })
    self:showToast(string.format("FRESH: %d NOTES CLEARED - L2+R2+LEFT UNDOES", total))
end

function Looper:clearTrack(trackIdx)
    local track = self.tracks[trackIdx]
    if track then
        self:silenceTrack(trackIdx)
        track.events = {}
        self:touch(track)
        self:showToast("CLEARED ALL ON TRACK " .. self:slotLabel(trackIdx) .. " (" .. track.name .. ")")
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
    local song = self:songTick()
    if self.bars == 2 then
        -- 2 -> 4 bars: bars 1-2 stay where they are and are copied into bars 3-4
        local oldLoop = self:getLoopTicks()
        self.bars = 4
        for tIdx = 1, 4 do
            local track = self.tracks[tIdx]
            for i = 1, #track.events do
                local ev = track.events[i]
                if not ev.open then                    -- a note still held has no length yet
                    local copy = copyValue(ev)         -- own keyframes and chord, not shared
                    copy.tick = copy.tick + oldLoop
                    copy.skipOnce = nil
                    table.insert(track.events, copy)
                end
            end
            self:touch(track)
        end
        self:showToast("LOOP LENGTH: 4 BARS (AUTO-DOUBLED BARS 1-2 -> 3-4)")
    else
        -- 4 -> 2 bars: keep bars 1-2. Bars 3-4 (and the lengths cut at the
        -- new end) go on the undo stack.
        local saved = {}
        for tIdx = 1, 4 do
            local list = {}
            for i, ev in ipairs(self.tracks[tIdx].events) do list[i] = copyValue(ev) end
            saved[tIdx] = list
        end
        self:pushUndo({ kind = "bars", bars = 4, tracks = saved, takeId = self.currentTakeId })
        self:beginRecordingTake()            -- notes from here on are newer than the saved ones
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
            self:touch(track)
        end
        self:showToast("LOOP LENGTH: 2 BARS (UNDO BRINGS BARS 3-4 BACK)")
    end
    self:keepSongPos(song)
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

Looper.CLICK_MODES = { "OFF", "ON", "COUNT-IN", "ON + COUNT-IN" }

function Looper:getClickMode()
    return self.CLICK_MODES[(self.clickOn and 1 or 0) + (self.countIn and 2 or 0) + 1]
end

function Looper:cycleClickMode()
    local i = (self.clickOn and 1 or 0) + (self.countIn and 2 or 0)
    i = (i + 1) % 4
    self.clickOn, self.countIn = (i % 2 == 1), (i >= 2)
    self:showToast("CLICK: " .. self:getClickMode())
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
            if nextTick >= loop then self.pass = self.pass + math_floor(nextTick / loop) end
            self.tick = nextTick % loop
        end
    else
        local nextTick = self.tick + advance
        if nextTick >= loop then self.pass = self.pass + math_floor(nextTick / loop) end
        self.tick = nextTick % loop
        self.stutterAnchorTick = math_floor(self.tick / window) * window
    end

    -- A long hitch or suspend: keep time, but don't fire a burst of old events
    if elapsed > self.GAP_LIMIT then
        self.prevTick = self.tick
    end

    local prevBeat = self.currentBeat
    self:syncPhase()
    if (self.clickOn or self.counting) and self.currentBeat ~= prevBeat then
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

                    -- The end of the last pass first: a note nearly a loop
                    -- long ends just before it starts again, and must not
                    -- end the moment it starts
                    local offT = (t + math.min(ev.len, loop - 1)) % loop
                    if ev.len > 0 and track.sounding[ev] and crossedAt(offT) then
                        track.sounding[ev] = nil
                        handler("off", ev, track)
                    end

                    -- Flam grace note sounds just before the main hit
                    if ev.orn == "flam" and not ev.skipOnce and crossedAt((t - graceTicks) % loop) then
                        handler("grace", ev, track)
                    end

                    if crossedAt(t) then
                        if ev.skipOnce then
                            ev.skipOnce = nil     -- the live press already played this pass
                        else
                            -- Still sounding from before (stutter replays its
                            -- start before its end): end it first, or the
                            -- instrument loses that voice and it rings forever
                            if track.sounding[ev] then
                                track.sounding[ev] = nil
                                handler("off", ev, track)
                            end
                            if ev.len > 0 then track.sounding[ev] = true end
                            handler("on", ev, track)
                            -- shorter than this frame: it ends in it too
                            if ev.len > 0 and ev.len <= (cur - t) % loop then
                                track.sounding[ev] = nil
                                handler("off", ev, track)
                            end
                        end
                    end
                end
            end
        end
    end
end

return Looper
