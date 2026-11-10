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
    phase = 0.0,
    prevPhase = 0.0,
    currentBeat = 1,
    currentStep = 1,
    stutterAnchorPhase = 0.0,
    activeTrack = 1,   -- Active track slot (1..4)
    currentTakeId = 0,
    takeStack = {},    -- Stack of takeIds for Undo Last Take
    tracks = {},
    toastText = "READY — TAP [SELECT] TO SWITCH TRACKS",
    toastTimer = 2.5,

    -- Quantize Grid Modes per track: stepsPerBar (nil = Free unquantized)
    GRID_MODES = {
        { id = "1/4",   label = "1/4",   stepsPerBar = 4   },
        { id = "1/8",   label = "1/8",   stepsPerBar = 8   },
        { id = "1/16",  label = "1/16",  stepsPerBar = 16  },
        { id = "1/12T", label = "1/12T", stepsPerBar = 12  },
        { id = "FREE",  label = "FREE",  stepsPerBar = nil },
    }
}

-- Each of the 4 tracks has an assigned instrumentId and its own per-track state,
-- so tracks can later switch instruments or share instrument types independently!
function Looper:init(Instruments)
    local defaultInstruments = { "drums", "harp", "bass", "grain" }
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
            muted = false,
            events = {},
            state = instDef:newState(),
        }
    end
end

-- Reassign any track slot (1..4) to any registered instrumentId
function Looper:setTrackInstrument(trackIdx, instrumentId, Instruments)
    local track = self.tracks[trackIdx]
    local instDef = Instruments:getDefinition(instrumentId)
    if not track or not instDef then return end
    track.instrumentId = instrumentId
    track.name = instDef.name
    track.shortName = instDef.shortName
    track.gridIndex = instDef.defaultGridIndex or track.gridIndex
    track.state = instDef:newState()
    track.events = {}
    self:showToast(string.format("TRACK %d -> %s", trackIdx, instDef.title or instDef.name))
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

function Looper:getTrackGrid(trackIdx)
    local track = self.tracks[trackIdx]
    return self.GRID_MODES[track.gridIndex] or self.GRID_MODES[3]
end

function Looper:beginRecordingTake()
    self.currentTakeId = self.currentTakeId + 1
end

function Looper:recordEvent(ev)
    local trackIdx = ev.trackSlot or ev.instrument or self.activeTrack
    local track = self.tracks[trackIdx]
    if not track then return end

    ev.trackSlot = trackIdx
    ev.instrumentId = ev.instrumentId or track.instrumentId
    ev.takeId = self.currentTakeId

    if #self.takeStack == 0 or self.takeStack[#self.takeStack].takeId ~= self.currentTakeId then
        table.insert(self.takeStack, { takeId = self.currentTakeId, trackSlot = trackIdx })
    end

    local grid = self:getTrackGrid(trackIdx)
    local snapSteps = ev.overrideGridSteps or (grid.stepsPerBar and (grid.stepsPerBar * self.bars) or nil)

    if snapSteps then
        local step = (math_floor(self.phase * snapSteps + 0.5) % snapSteps) + 1
        local snappedPhase = (step - 1) / snapSteps
        ev.step = step
        ev.gridSteps = snapSteps
        ev.phase = snappedPhase

        local phaseDiff = (snappedPhase - self.phase) % 1.0
        if phaseDiff > 0.0 and phaseDiff < 0.05 then
            ev.justRecorded = true
        end

        -- Deduplicate same action at same quantized phase window (handling 1.0 circular wrap)
        for i = #track.events, 1, -1 do
            local existing = track.events[i]
            if existing.action == ev.action then
                local diff = math_abs(existing.phase - snappedPhase)
                if diff > 0.5 then diff = 1.0 - diff end
                if diff < (0.4 / snapSteps) then
                    table.remove(track.events, i)
                end
            end
        end
    else
        ev.phase = self.phase
        ev.step = math_floor(self.phase * self:getTotalSixteenths()) + 1
    end

    table.insert(track.events, ev)
end

-- Undo most recent L2 recording take
function Looper:undoLastTake()
    for s = #self.takeStack, 1, -1 do
        local entry = self.takeStack[s]
        local track = self.tracks[entry.trackSlot]
        local removedCount = 0
        if track then
            for i = #track.events, 1, -1 do
                if track.events[i].takeId == entry.takeId then
                    table.remove(track.events, i)
                    removedCount = removedCount + 1
                end
            end
        end
        table.remove(self.takeStack, s)
        if removedCount > 0 then
            self:showToast(string.format("UNDO TAKE #%d (%d HITS REMOVED)", entry.takeId, removedCount))
            return
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
            table.remove(track.events, i)
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

function Looper:clearTrack(trackIdx)
    local track = self.tracks[trackIdx]
    if track then
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
    if self.bars == 2 then
        -- Expand 2 Bars -> 4 Bars by duplicating Bars 1-2 into Bars 3-4!
        self.bars = 4
        local totalSteps = self:getTotalSixteenths()
        for tIdx = 1, 4 do
            local track = self.tracks[tIdx]
            local origCount = #track.events
            for i = 1, origCount do
                local ev = track.events[i]
                ev.phase = ev.phase * 0.5
                ev.step = math_floor(ev.phase * totalSteps) + 1
                if ev.gridSteps then ev.gridSteps = ev.gridSteps * 2 end
                local copy = {}
                for k, v in pairs(ev) do copy[k] = v end
                copy.phase = ev.phase + 0.5
                copy.step = math_floor(copy.phase * totalSteps) + 1
                copy.justRecorded = false
                table.insert(track.events, copy)
            end
        end
        self.phase = self.phase * 0.5
        self.prevPhase = self.phase
        self:showToast("LOOP LENGTH: 4 BARS (AUTO-DOUBLED BARS 1-2 -> 3-4)")
    else
        -- Contract 4 Bars -> 2 Bars (keep Bars 1-2)
        self.bars = 2
        local totalSteps = self:getTotalSixteenths()
        for tIdx = 1, 4 do
            local track = self.tracks[tIdx]
            for i = #track.events, 1, -1 do
                local ev = track.events[i]
                if ev.phase < 0.5 then
                    ev.phase = ev.phase * 2.0
                    ev.step = math_floor(ev.phase * totalSteps) + 1
                    if ev.gridSteps then ev.gridSteps = math_max(1, math_floor(ev.gridSteps * 0.5)) end
                else
                    table.remove(track.events, i)
                end
            end
        end
        self.phase = (self.phase * 2.0) % 1.0
        self.prevPhase = self.phase
        self:showToast("LOOP LENGTH: 2 BARS")
    end
end

function Looper:toggleMute(trackIdx)
    local track = self.tracks[trackIdx]
    if track then
        track.muted = not track.muted
        self:showToast("TRACK " .. trackIdx .. " " .. (track.muted and "MUTED" or "UNMUTED"))
    end
end

function Looper:update(dt, triggerCallback)
    if self.toastTimer > 0 then
        self.toastTimer = math_max(0, self.toastTimer - dt)
    end

    if not self.playing then return end

    local loopDuration = self:getLoopDuration()
    local rateMultiplier = Synth.fxHalfSpeed and 0.5 or 1.0
    local totalSixteenths = self:getTotalSixteenths()
    local totalBeats = self:getTotalBeats()

    self.prevPhase = self.phase

    if Synth.fxBeatRepeat then
        local windowWidth = 1.0 / totalSixteenths
        local nextPhase = self.phase + (dt / loopDuration) * rateMultiplier
        if nextPhase >= self.stutterAnchorPhase + windowWidth then
            self.prevPhase = self.stutterAnchorPhase - 0.0001
            self.phase = self.stutterAnchorPhase + ((nextPhase - self.stutterAnchorPhase) % windowWidth)
        else
            self.phase = nextPhase % 1.0
        end
    else
        self.phase = (self.phase + (dt / loopDuration) * rateMultiplier) % 1.0
        self.stutterAnchorPhase = math_floor(self.phase * totalSixteenths) / totalSixteenths
    end

    self.currentBeat = math_floor(self.phase * totalBeats) + 1
    self.currentStep = math_floor(self.phase * totalSixteenths) + 1

    local wrapped = (self.phase < self.prevPhase)
    for tIdx = 1, 4 do
        local track = self.tracks[tIdx]
        if not track.muted then
            for i = 1, #track.events do
                local ev = track.events[i]
                local crossed = false
                if not wrapped then
                    crossed = (ev.phase > self.prevPhase and ev.phase <= self.phase)
                else
                    crossed = (ev.phase > self.prevPhase or ev.phase <= self.phase)
                end

                if crossed then
                    if ev.justRecorded then
                        ev.justRecorded = false
                    else
                        triggerCallback(ev, track, true)
                    end
                end
            end
        end
    end
end

return Looper
