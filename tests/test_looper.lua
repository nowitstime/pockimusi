-- Looper: recording, dedup, playback, swing, loop length, undo/erase, click, live FX.
-- These characterise today's behaviour so the tick/event rewrite (Phase A5/A6)
-- can be checked against it. Default: 115 BPM, 2 bars, drums on track 1 at 1/16.
local H = require("helpers")

local GRID = { Q = 1, E = 2, S = 3, T = 4, FREE = 5 }  -- 1/4, 1/8, 1/16, 1/12T, FREE

local function setup(gridIndex)
    local M = H.fresh()
    M.Looper.tracks[1].gridIndex = gridIndex or GRID.S
    return M, M.Looper
end

local function phases(track)
    local t = {}
    for _, ev in ipairs(track.events) do t[#t + 1] = string.format("%.4f", ev.phase) end
    table.sort(t)
    return table.concat(t, " ")
end

local function mains(fired)
    local n = 0
    for _, f in ipairs(fired) do if not f.part then n = n + 1 end end
    return n
end

-- Start playback from `phase` with nothing pending
local function startAt(L, phase)
    L.phase, L.prevPhase = phase, phase
end

return {
    -- ------------------------------------------------------------------
    -- Recording & snapping
    -- ------------------------------------------------------------------
    { "1/16 snaps to the nearest 32nd of a 2-bar loop", function()
        local _, L = setup(GRID.S)
        local ev = H.record(L, 1, "B", 0.26)
        H.near(ev.phase, 0.25, "phase")
        H.eq(ev.step, 9, "step")
        H.eq(ev.gridSteps, 32, "gridSteps")
    end },

    { "1/4 grid snaps to quarter notes", function()
        local _, L = setup(GRID.Q)
        H.near(H.record(L, 1, "B", 0.30).phase, 0.25, "0.30 -> 0.25")
        H.eq(L.tracks[1].events[1].gridSteps, 8, "gridSteps")
    end },

    { "1/12T grid snaps to triplets (24 per 2 bars)", function()
        local _, L = setup(GRID.T)
        local ev = H.record(L, 1, "B", 0.10)
        H.near(ev.phase, 2 / 24, "phase")
        H.eq(ev.gridSteps, 24, "gridSteps")
    end },

    { "FREE keeps the exact phase", function()
        local _, L = setup(GRID.FREE)
        local ev = H.record(L, 1, "B", 0.3141)
        H.near(ev.phase, 0.3141, "phase")
        H.eq(ev.gridSteps, nil, "no gridSteps")
        H.eq(ev.step, 11, "display step")
    end },

    { "overrideGridSteps (note repeat) beats the track grid", function()
        local _, L = setup(GRID.S)
        local ev = H.record(L, 1, "B", 0.30, { overrideGridSteps = 8 })
        H.near(ev.phase, 0.25, "phase")
        H.eq(ev.gridSteps, 8, "gridSteps")
    end },

    { "a press just before the seam snaps to the loop start", function()
        local _, L = setup(GRID.S)
        local ev = H.record(L, 1, "B", 0.99)
        H.near(ev.phase, 0.0, "phase")
        H.eq(ev.step, 1, "step")
        H.truthy(ev.justRecorded, "marked as already played")
    end },

    { "snapping forward marks the event as already played; snapping back does not", function()
        local _, L = setup(GRID.S)
        H.truthy(H.record(L, 1, "B", 0.24).justRecorded, "0.24 -> 0.25 (forward)")
        H.falsy(H.record(L, 1, "A", 0.26).justRecorded, "0.26 -> 0.25 (back)")
    end },

    { "recorded events carry track, instrument and take", function()
        local _, L = setup(GRID.S)
        L:beginRecordingTake()
        local ev = H.record(L, 1, "B", 0.26)
        H.eq(ev.trackSlot, 1, "trackSlot")
        H.eq(ev.instrumentId, "drums", "instrumentId")
        H.eq(ev.takeId, L.currentTakeId, "takeId")
    end },

    -- ------------------------------------------------------------------
    -- Dedup
    -- ------------------------------------------------------------------
    { "same pad on the same step replaces the old hit", function()
        local _, L = setup(GRID.S)
        H.record(L, 1, "B", 0.26)
        H.record(L, 1, "B", 0.25)
        H.eq(#L.tracks[1].events, 1, "events")
    end },

    { "different pads on the same step both stay", function()
        local _, L = setup(GRID.S)
        H.record(L, 1, "B", 0.26)
        H.record(L, 1, "A", 0.26)
        H.eq(#L.tracks[1].events, 2, "events")
    end },

    { "neighbouring steps both stay", function()
        local _, L = setup(GRID.S)
        H.record(L, 1, "B", 0.25)
        H.record(L, 1, "B", 0.25 + 1 / 32)
        H.eq(#L.tracks[1].events, 2, "events")
    end },

    { "dedup works across the loop seam", function()
        local _, L = setup(GRID.S)
        H.record(L, 1, "B", 0.01)     -- -> 0.0
        H.record(L, 1, "B", 0.99)     -- -> 0.0 (wraps)
        H.eq(#L.tracks[1].events, 1, "events")
    end },

    { "dedup across the seam catches a FREE hit near the loop end", function()
        local _, L = setup(GRID.FREE)
        H.record(L, 1, "B", 0.995)    -- unquantized, just before the seam
        L.tracks[1].gridIndex = GRID.S
        H.record(L, 1, "B", 0.001)    -- snaps to 0.0, 0.005 away across the seam
        H.eq(#L.tracks[1].events, 1, "events")
        H.near(L.tracks[1].events[1].phase, 0.0, "new hit kept")
    end },

    -- ------------------------------------------------------------------
    -- Playback
    -- ------------------------------------------------------------------
    { "an event fires exactly once per loop pass", function()
        local _, L = setup(GRID.S)
        H.record(L, 1, "B", 0.26)
        startAt(L, 0.5)
        H.eq(mains(H.run(L, H.loopSeconds(L))), 1, "one pass")
        H.eq(mains(H.run(L, H.loopSeconds(L) * 3)), 3, "three passes")
    end },

    { "an event on the downbeat fires when the playhead wraps", function()
        local _, L = setup(GRID.S)
        H.record(L, 1, "B", 0.01)     -- -> 0.0
        startAt(L, 0.5)
        local fired = H.run(L, H.loopSeconds(L))
        H.eq(mains(fired), 1, "fires once")
        H.truthy(fired[1].phase < 0.01, "fires just after the wrap")
    end },

    { "an event marked already-played is skipped on the first pass only", function()
        local _, L = setup(GRID.S)
        H.record(L, 1, "B", 0.24)     -- snaps forward to 0.25
        H.eq(mains(H.run(L, H.loopSeconds(L))), 0, "first pass")
        H.eq(mains(H.run(L, H.loopSeconds(L))), 1, "second pass")
    end },

    { "muted tracks are silent", function()
        local _, L = setup(GRID.S)
        H.record(L, 1, "B", 0.26)
        L.tracks[1].muted = true
        startAt(L, 0.5)
        H.eq(mains(H.run(L, H.loopSeconds(L))), 0, "fired")
    end },

    { "playback callback gets the event, its track and isPlayback", function()
        local _, L = setup(GRID.S)
        local ev = H.record(L, 1, "B", 0.26)
        startAt(L, 0.5)
        local f = H.run(L, H.loopSeconds(L))[1]
        H.eq(f.ev, ev, "event")
        H.eq(f.track, L.tracks[1], "track")
        H.truthy(f.playback, "isPlayback")
    end },

    { "a flam's grace note fires 28 ms before the main hit", function()
        local _, L = setup(GRID.S)
        H.record(L, 1, "B", 0.26, { orn = "flam" })
        startAt(L, 0.5)
        local fired = H.run(L, H.loopSeconds(L), 1000)   -- 1 ms frames for precision
        H.eq(#fired, 2, "grace + main")
        H.eq(fired[1].part, "grace", "grace first")
        H.eq(fired[2].part, nil, "then main")
        local gapSec = (fired[2].phase - fired[1].phase) * H.loopSeconds(L)
        H.near(gapSec, 0.028, "gap", 0.0015)
    end },

    { "playback stops while paused", function()
        local _, L = setup(GRID.S)
        H.record(L, 1, "B", 0.26)
        startAt(L, 0.5)
        L.playing = false
        H.eq(mains(H.run(L, H.loopSeconds(L))), 0, "fired")
        H.near(L.phase, 0.5, "playhead holds")
    end },

    -- ------------------------------------------------------------------
    -- Swing
    -- ------------------------------------------------------------------
    { "swing pushes odd 16ths late and leaves even ones", function()
        local _, L = setup(GRID.S)
        local trk = L.tracks[1]
        trk.swing = 0.60
        local odd = H.record(L, 1, "B", 1 / 32 + 0.001)
        local even = H.record(L, 1, "A", 2 / 32 + 0.001)
        H.near(L:getSwingOffset(odd, trk), 0.1 * 2 / 32, "odd offset")
        H.near(L:getSwingOffset(even, trk), 0.0, "even offset")
    end },

    { "swing ignores quarter-note and triplet grids", function()
        local _, L = setup(GRID.Q)
        local trk = L.tracks[1]
        trk.swing = 0.70
        H.near(L:getSwingOffset(H.record(L, 1, "B", 0.126), trk), 0.0, "1/4")
        trk.gridIndex = GRID.T
        H.near(L:getSwingOffset(H.record(L, 1, "A", 1 / 24 + 0.001), trk), 0.0, "1/12T")
    end },

    { "a swung event plays late by the swing offset", function()
        local _, L = setup(GRID.S)
        L.tracks[1].swing = 0.60
        H.record(L, 1, "B", 1 / 32 + 0.001)
        startAt(L, 0.5)
        local fired = H.run(L, H.loopSeconds(L), 1000)
        local due = 1 / 32 + 0.1 * 2 / 32
        H.eq(#fired, 1, "fired")
        H.truthy(fired[1].phase >= due and fired[1].phase < due + 0.001,
            string.format("fired at %.5f, due %.5f", fired[1].phase, due))
    end },

    { "swing is clamped to 50-75 %", function()
        local _, L = setup(GRID.S)
        for _ = 1, 30 do L:adjustSwing(1, 0.02) end
        H.near(L.tracks[1].swing, 0.75, "max")
        for _ = 1, 30 do L:adjustSwing(1, -0.02) end
        H.near(L.tracks[1].swing, 0.50, "min")
    end },

    -- ------------------------------------------------------------------
    -- Loop length
    -- ------------------------------------------------------------------
    { "2 -> 4 bars duplicates bars 1-2 into 3-4", function()
        local _, L = setup(GRID.S)
        H.record(L, 1, "B", 0.26)
        L.phase = 0.5
        L:toggleBars()
        H.eq(L.bars, 4, "bars")
        H.eq(phases(L.tracks[1]), "0.1250 0.6250", "phases")
        H.eq(L.tracks[1].events[1].gridSteps, 64, "gridSteps doubled")
        H.near(L.phase, 0.25, "playhead keeps its bar position")
    end },

    { "4 -> 2 bars keeps bars 1-2 only", function()
        local _, L = setup(GRID.S)
        L:toggleBars()                         -- now 4 bars
        H.record(L, 1, "B", 0.126)             -- bar 1
        H.record(L, 1, "A", 0.626)             -- bar 3
        L:toggleBars()
        H.eq(L.bars, 2, "bars")
        H.eq(#L.tracks[1].events, 1, "bar-3 hit dropped")
        H.near(L.tracks[1].events[1].phase, 0.25, "phase rescaled")
        H.eq(L.tracks[1].events[1].action, "B", "bar-1 hit kept")
    end },

    { "2 -> 4 -> 2 bars round trip restores the pattern", function()
        local _, L = setup(GRID.S)
        H.record(L, 1, "B", 0.26)
        H.record(L, 1, "A", 0.76)
        L:toggleBars(); L:toggleBars()
        H.eq(phases(L.tracks[1]), "0.2500 0.7500", "phases")
        H.eq(L.tracks[1].events[1].gridSteps, 32, "gridSteps")
    end },

    { "loop duration follows tempo and length", function()
        local _, L = setup(GRID.S)
        L.bpm = 120
        H.near(L:getLoopDuration(), 4.0, "120 BPM, 2 bars")
        L:toggleBars()
        H.near(L:getLoopDuration(), 8.0, "120 BPM, 4 bars")
    end },

    -- ------------------------------------------------------------------
    -- Undo, erase, grid
    -- ------------------------------------------------------------------
    { "undo removes the last take only, then the one before", function()
        local _, L = setup(GRID.S)
        L:beginRecordingTake()
        H.record(L, 1, "B", 0.26)
        H.record(L, 1, "A", 0.51)
        L:beginRecordingTake()
        H.record(L, 1, "Y", 0.76)
        L:undo()
        H.eq(#L.tracks[1].events, 2, "after first undo")
        L:undo()
        H.eq(#L.tracks[1].events, 0, "after second undo")
        L:undo()
        H.eq(L.toastText, "NOTHING TO UNDO", "toast")
    end },

    { "undo follows the take to its track", function()
        local _, L = setup(GRID.S)
        L.tracks[2].gridIndex = GRID.S
        L:beginRecordingTake()
        H.record(L, 1, "B", 0.26)
        L:beginRecordingTake()
        H.record(L, 2, "B", 0.26)
        L:undo()
        H.eq(#L.tracks[1].events, 1, "track 1 untouched")
        H.eq(#L.tracks[2].events, 0, "track 2 undone")
    end },

    { "erase removes one pad's hits; clear removes all", function()
        local _, L = setup(GRID.S)
        H.record(L, 1, "B", 0.26)
        H.record(L, 1, "B", 0.51)
        H.record(L, 1, "A", 0.51)
        H.eq(L:countTrackAction(1, "B"), 2, "count B")
        L:clearTrackAction(1, "B")
        H.eq(#L.tracks[1].events, 1, "only A left")
        H.eq(L.tracks[1].events[1].action, "A", "A kept")
        L:clearTrack(1)
        H.eq(#L.tracks[1].events, 0, "cleared")
    end },

    { "grid cycles 1/16 -> 1/12T -> FREE -> 1/4", function()
        local _, L = setup(GRID.S)
        local seen = {}
        for _ = 1, 3 do
            L:cycleGridMode(1)
            seen[#seen + 1] = L:getTrackGrid(1).id
        end
        H.eq(table.concat(seen, " "), "1/12T FREE 1/4", "order")
    end },

    { "swapping an instrument clears the track; undo brings it all back", function()
        local M, L = setup(GRID.S)
        H.record(L, 1, "B", 0.26)
        local oldState, oldEvents = L.tracks[1].state, L.tracks[1].events
        M.Instruments:swapTrackInstrument(1, "harp")
        H.eq(L.tracks[1].instrumentId, "harp", "now harp")
        H.eq(#L.tracks[1].events, 0, "events cleared")
        L:undo()
        H.eq(L.tracks[1].instrumentId, "drums", "back to drums")
        H.eq(L.tracks[1].name, "DRUMS", "name restored")
        H.eq(L.tracks[1].state, oldState, "same state (kit, pad sounds)")
        H.eq(L.tracks[1].events, oldEvents, "same events")
        H.eq(L.tracks[1].gridIndex, GRID.S, "grid restored")
    end },

    { "undo unwinds takes and swaps in order", function()
        local M, L = setup(GRID.S)
        L:beginRecordingTake(); H.record(L, 1, "B", 0.26)       -- take 1 on drums
        M.Instruments:swapTrackInstrument(1, "bass")           -- swap
        L.tracks[1].gridIndex = GRID.S
        L:beginRecordingTake(); H.record(L, 1, "A", 0.51)       -- take 2 on bass
        L:undo()
        H.eq(L.tracks[1].instrumentId, "bass", "take 2 undone, still bass")
        H.eq(#L.tracks[1].events, 0, "bass events gone")
        L:undo()
        H.eq(L.tracks[1].instrumentId, "drums", "swap undone")
        H.eq(#L.tracks[1].events, 1, "drum hit back")
        L:undo()
        H.eq(#L.tracks[1].events, 0, "take 1 undone")
        L:undo()
        H.eq(L.toastText, "NOTHING TO UNDO", "empty")
    end },

    { "swapping to the same instrument does nothing", function()
        local M, L = setup(GRID.S)
        H.record(L, 1, "B", 0.26)
        M.Instruments:swapTrackInstrument(1, "drums")
        H.eq(#L.tracks[1].events, 1, "events kept")
        H.eq(#L.undoStack, 1, "no swap entry (only the take)")
    end },

    { "instrument steps wrap around the catalog", function()
        local M = setup(GRID.S)
        local I = M.Instruments
        H.eq(I:stepInstrumentId("drums", 1), "harp", "next")
        H.eq(I:stepInstrumentId("drums", -1), I.catalog[#I.catalog].id, "previous wraps")
    end },

    -- ------------------------------------------------------------------
    -- Click and live FX
    -- ------------------------------------------------------------------
    { "metronome clicks every beat, accented on each bar", function()
        local M, L = setup(GRID.S)
        L.clickOn = true
        H.run(L, H.loopSeconds(L) + 0.05)
        local clicks, accents = 0, 0
        for _, t in ipairs(M.triggers) do
            if t.sound == "perc_wood" then
                clicks = clicks + 1
                if t.semis == 5 then accents = accents + 1 end
            end
        end
        H.eq(clicks, 8, "8 beats in 2 bars")
        H.eq(accents, 2, "2 downbeats")
    end },

    { "half-speed FX halves the playhead speed", function()
        local M, L = setup(GRID.S)
        M.Synth.fxHalfSpeed = true
        startAt(L, 0.0)
        H.run(L, H.loopSeconds(L) * 0.5)
        H.near(L.phase, 0.25, "phase after half a loop of time", 0.005)
    end },

    { "stutter FX keeps the playhead inside one 1/16 window", function()
        local M, L = setup(GRID.S)
        startAt(L, 0.30)
        H.run(L, 0.05)                         -- establish the stutter anchor
        M.Synth.fxBeatRepeat = true
        local anchor = L.stutterAnchorPhase
        local maxSeen, minSeen = 0, 1
        for _ = 1, 120 do
            H.run(L, 1 / 60)
            maxSeen = math.max(maxSeen, L.phase)
            minSeen = math.min(minSeen, L.phase)
        end
        H.truthy(minSeen >= anchor - 1e-9, "never before the window")
        H.truthy(maxSeen < anchor + 1 / 32, "never past the window")
    end },
}
