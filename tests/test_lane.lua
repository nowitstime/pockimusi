-- TRACK C, the chord lane (src/instruments/lane.lua, PHASE_K.md): the song's
-- chords outside the four slots, on their own 2..16-bar timeline.
local H = require("helpers")

local function boot()
    local M = H.loadMain()
    M.Harmony = require("src.harmony")
    M.Chords = M.Instruments.byId.chords
    H.play(0.1)
    local L = M.Looper
    local lane = L:getLane()
    return M, L, lane, M.Instruments:getDefinition("lane")
end

local DIR = { I = "NEUTRAL", ii = "UP_LEFT", iii = "UP_RIGHT", IV = "LEFT", V = "RIGHT", vi = "DOWN" }

local function chord(M, roman)
    return M.Chords:chordData(M.Theory:getChordForDirection(DIR[roman], false, false, "TRIAD"))
end

-- Put chords on the lane, one per bar from bar 1: { "I", "V", ... }
local function fill(M, L, lane, romans, bars)
    lane.state.bars = bars or #romans
    lane.events = {}
    for i, r in ipairs(romans) do
        lane.events[i] = { tick = (i - 1) * L.BAR_TICKS, len = 0, action = "B", chord = chord(M, r), vel = 0.75 }
    end
    L:touch(lane)
end

-- The lane's chords as "bar.beat:name" in time order
local function laneOf(M, L, lane)
    local list = {}
    for _, ev in ipairs(lane.events) do list[#list + 1] = ev end
    table.sort(list, function(a, b) return a.tick < b.tick end)
    local out = {}
    for i, ev in ipairs(list) do
        local bar = math.floor(ev.tick / L.BAR_TICKS) + 1
        local beat = math.floor((ev.tick % L.BAR_TICKS) / L.PPQN) + 1
        out[i] = bar .. "." .. beat .. ":" .. M.Theory:chordName(ev.chord)
    end
    return table.concat(out, " ")
end

-- The chord Harmony gives at a lane position (bars from 1, fraction of a bar)
local function chordAtLane(M, L, bar, frac)
    local pos = ((bar - 1) + (frac or 0.5)) * L.BAR_TICKS
    L.pass = math.floor(pos / L:getLoopTicks())
    L:seek((pos % L:getLoopTicks()) / L:getLoopTicks())
    return M.Theory:chordName((M.Harmony:chordAt(L.tick, 0)))
end

local function stopped(L) L:setPlaying(false); L:seekLane(0) end
local function lanePos(L) return L:lanePos() / L.BAR_TICKS + 1 end      -- in bars, from 1

return {
    { "track C is a lane outside the four slots, reached by SELECT after track 4", function()
        local M, L, lane, def = boot()
        H.truthy(lane and lane.isLane, "tracks[LANE] is the lane")
        H.eq(lane.instrumentId, "lane", "it plays the lane")
        for _, inst in ipairs(M.Instruments.catalog) do
            H.falsy(inst.id == "lane", "never offered for a slot")
        end
        local seen = {}
        L.activeTrack = 1
        for _ = 1, 5 do
            H.tap("SELECT")
            seen[#seen + 1] = L:slotLabel(L.activeTrack)
        end
        H.eq(table.concat(seen, " "), "2 3 4 C 1", "1 -> 2 -> 3 -> 4 -> C -> 1")
        local rows = M.Instruments:getSoundRows(def, lane.state, lane)
        local keys = {}
        for i, r in ipairs(rows) do keys[i] = r.key end
        H.eq(table.concat(keys, " "), "BARS GRID PREVIEW PATCH COLOUR SPICE", "its rows; no effect rows")
    end },

    { "an 8-bar lane over a 2-bar loop: each pass gets its own chords", function()
        local M, L, lane = boot()
        fill(M, L, lane, { "I", "V", "vi", "IV", "ii", "V", "I", "iii" })
        local got = {}
        for bar = 1, 8 do got[bar] = chordAtLane(M, L, bar) end
        H.eq(table.concat(got, " "), "C G Am F Dm G C Em", "bar by bar")
        H.eq(M.Harmony:source(), lane, "the lane is the chord source")
    end },

    { "a lane shorter than the loop repeats inside it", function()
        local M, L, lane = boot()
        L:toggleBars()                          -- 4-bar loop
        fill(M, L, lane, { "I", "vi" })         -- 2-bar lane
        H.eq(chordAtLane(M, L, 3), "C", "bar 3 = bar 1 of the lane")
        H.eq(chordAtLane(M, L, 4), "Am", "bar 4 = bar 2")
    end },

    { "the playhead counts passes; a double START tap goes back to pass 1", function()
        local M, L, lane = boot()
        fill(M, L, lane, { "I", "V", "vi", "IV" })
        L:seek(0.0); L.pass = 0
        H.run(L, H.loopSeconds(L) * 1.25)
        H.eq(L.pass, 1, "one wrap, one pass")
        H.eq(M.Theory:chordName((M.Harmony:current())), "Am", "pass 2 plays bars 3-4")
        H.tap("START"); H.tap("START")
        H.eq(L.pass, 0, "reset")
    end },

    { "the lane is saved and restored; a fresh session clears it and undo brings it back", function()
        local M, L, lane = boot()
        fill(M, L, lane, { "I", "V", "vi", "IV", "I", "V", "IV", "V" })
        lane.state.picked = "CANON"
        local text = M.Save.encode(M.Session.snapshot())
        fill(M, L, lane, { "ii" }, 2)
        H.truthy(M.Session.restore(M.Save.decode(text)), "restored")
        lane = L:getLane()
        H.eq(lane.state.bars, 8, "bars")
        H.eq(lane.state.picked, "CANON", "picked progression")
        H.eq(laneOf(M, L, lane), "1.1:C 2.1:G 3.1:Am 4.1:F 5.1:C 6.1:G 7.1:F 8.1:G", "chords")
        L:freshSession()
        H.eq(#lane.events, 0, "fresh clears track C")
        L:undo()
        H.eq(#lane.events, 8, "undo brings it back")
    end },

    { "running: B changes on the next bar line; live unless recording", function()
        local M, L, lane = boot()
        fill(M, L, lane, { "I", "V", "vi", "IV" })
        L.activeTrack = L.LANE
        L.pass = 0; L:seek(0.3)                -- in bar 1
        H.play(0.05, { "LEFT", "B" })          -- IV
        H.eq(laneOf(M, L, lane), "1.1:C 2.1:G 3.1:Am 4.1:F", "not recording: nothing written")
        H.eq(M.Theory:chordName((M.Harmony:chordAt(L.tick, 0))), "C", "bar 1 still C")
        H.eq(chordAtLane(M, L, 2, 0.2), "F", "bar 2 plays the live F")
        H.eq(chordAtLane(M, L, 3, 0.2), "Am", "and bar 3 the lane again")

        H.play(0.05)
        M.Input.recLatched = true
        L.pass = 0; L:seek(0.3)
        H.play(0.05, { "DOWN", "B" })          -- vi, recorded
        M.Input.recLatched = false
        H.eq(laneOf(M, L, lane), "1.1:C 2.1:Am 4.1:F", "written on bar 2 (joins the Am after it)")
        L:undo()
        H.eq(laneOf(M, L, lane), "1.1:C 2.1:G 3.1:Am 4.1:F", "one undo per lane pass")
    end },

    { "running: GRID sets the box a change lands on", function()
        local M, L, lane = boot()
        fill(M, L, lane, { "I", "V", "vi", "IV" })
        lane.state.grid = 0.5
        M.Input.recLatched = true
        L.activeTrack = L.LANE
        L.pass = 0; L:seek(0.1)                -- early in bar 1
        H.play(0.05, { "LEFT", "B" })          -- IV on the half bar
        H.eq(laneOf(M, L, lane), "1.1:C 1.3:F 2.1:G 3.1:Am 4.1:F", "a 1/2-bar box: lands half way through bar 1")
        M.Input.recLatched = false
    end },

    { "stopped: B writes the box under the playhead and steps on", function()
        local M, L, lane, def = boot()
        lane.state.bars = 8
        L.activeTrack = L.LANE
        stopped(L)
        H.tap("B")                             -- C in bar 1
        H.play(0.05, { "RIGHT", "B" }); H.play(0.05)   -- G in bar 2
        H.eq(laneOf(M, L, lane), "1.1:C 2.1:G", "two boxes")
        H.eq(lanePos(L), 3, "playhead on bar 3")
        H.tap("R1")                            -- step on: G carries on
        H.play(0.05, { "DOWN", "B" }); H.play(0.05)          -- Am
        H.play(0.05, { "DOWN", "B" }); H.play(0.05)          -- Am again: joins
        H.eq(laneOf(M, L, lane), "1.1:C 2.1:G 4.1:Am", "carry, then the same chord twice = one 2-bar chord")
        H.eq(lanePos(L), 6, "stepped 2 boxes")
        H.tap("L1"); H.tap("L1")
        H.eq(lanePos(L), 4, "L1 taps step back")
        H.tap("Y")
        H.eq(laneOf(M, L, lane), "1.1:C 2.1:G", "Y clears the box under the playhead")
        H.eq(lanePos(L), 4, "and the playhead stays")
        H.tap("Y")
        H.eq(laneOf(M, L, lane), "1.1:C 2.1:G", "an empty box: nothing to clear")
    end },

    { "writing one box over a full lane leaves the rest as it was", function()
        local M, L, lane, def = boot()
        fill(M, L, lane, { "I", "IV" }, 4)     -- C over bars 1, F over bars 2-4
        def:write(lane, chord(M, "V"), 2 * L.BAR_TICKS, L.BAR_TICKS, "B")
        H.eq(laneOf(M, L, lane), "1.1:C 2.1:F 3.1:G", "nothing after: G carries on")
        fill(M, L, lane, { "I", "IV", "IV", "V" }, 4)
        table.remove(lane.events, 3)           -- bars 2-3 are one F
        def:write(lane, chord(M, "ii"), L.BAR_TICKS, L.BAR_TICKS, "B")
        H.eq(laneOf(M, L, lane), "1.1:C 2.1:Dm 3.1:F 4.1:G", "F comes back after the box")
    end },

    { "stamp: tap X puts the picked progression down and steps past it", function()
        local M, L, lane = boot()
        lane.state.bars = 16
        L.activeTrack = L.LANE
        stopped(L)
        H.tap("X")
        H.eq(laneOf(M, L, lane), "1.1:C 2.1:G 3.1:Am 4.1:F", "POP in bars 1-4")
        H.eq(lanePos(L), 5, "playhead on bar 5")
        H.tap("X")
        H.eq(#lane.events, 8, "a second tap: bars 5-8")
        H.tap("L1")
        H.tap("Y")
        H.eq(#lane.events, 7, "Y clears one box of it")
        L:undo()
        H.eq(#lane.events, 8, "undo brings it back")
    end },

    { "stamp: hold X for the wheel, point, let go = picked, nothing written", function()
        local M, L, lane, def = boot()
        lane.state.bars = 8
        L.activeTrack = L.LANE
        L.pass = 0; L:seek(0.1)
        H.hold("X"); H.play(0.4)
        H.truthy(lane.state.wheelOpen, "the wheel opens")
        H.hold("DOWN"); H.play(0.1)            -- JAZZ ii-V-I
        H.eq(lane.state.hover, "JAZZ ii-V-I", "pointing at it")
        H.eq(M.Theory:chordName((M.Harmony:current())), "Dm", "the other tracks hear it")
        H.release("X", "DOWN"); H.play(0.05)
        H.falsy(lane.state.wheelOpen, "closed")
        H.eq(lane.state.picked, "JAZZ ii-V-I", "picked")
        H.eq(#lane.events, 0, "nothing written")
        H.hold("X"); H.play(0.4); H.tap("R1"); H.hold("UP"); H.play(0.1)
        H.eq(lane.state.hover, "DESCEND", "L1 / R1 flip the page")
        H.release("X", "UP"); H.play(0.05)

        stopped(L)
        lane.state.picked = "JAZZ ii-V-I"
        lane.state.grid = 2
        H.tap("X")
        H.eq(laneOf(M, L, lane), "1.1:Dm 3.1:G 5.1:C", "GRID 2 bars: two bars a chord; I I joins into one")
        H.eq(lanePos(L), 1, "stepped past it (wraps to bar 1)")
    end },

    { "stamp while running starts in the box the playhead is on", function()
        local M, L, lane = boot()
        lane.state.bars = 8
        L.activeTrack = L.LANE
        L.pass = 0; L:seek(0.3)                -- in bar 1
        H.tap("X")
        H.eq(laneOf(M, L, lane), "1.1:C 2.1:G 3.1:Am 4.1:F", "from bar 1, no waiting")
    end },

    { "running: Y clears the box playing, and each box reached while held", function()
        local M, L, lane = boot()
        fill(M, L, lane, { "I", "V", "vi", "IV" })
        L.activeTrack = L.LANE
        L.pass = 0; L:seek(0.3)                -- in bar 1
        H.tap("Y")
        H.eq(laneOf(M, L, lane), "2.1:G 3.1:Am 4.1:F", "bar 1 cleared")
        L.pass = 0; L:seek(0.45)               -- near the end of bar 1
        H.hold("Y"); H.play(0.6); H.release("Y"); H.play(0.05)
        H.eq(laneOf(M, L, lane), "3.1:Am 4.1:F", "held into bar 2: cleared too")
    end },

    { "BARS: a longer lane repeats what is there, a shorter one drops the end", function()
        local M, L, lane, def = boot()
        fill(M, L, lane, { "I", "V", "vi", "IV" })
        def:setBars(lane.state, lane, 8)
        H.eq(laneOf(M, L, lane), "1.1:C 2.1:G 3.1:Am 4.1:F 5.1:C 6.1:G 7.1:Am 8.1:F", "repeated")
        def:setBars(lane.state, lane, 2)
        H.eq(laneOf(M, L, lane), "1.1:C 2.1:G", "cut")
        L:undo()
        H.eq(#lane.events, 8, "undo")
    end },
    { "FOLLOW says when there is nothing to follow; recording with FOLLOW OFF over chords warns", function()
        local M, L, lane = boot()
        local Modes = require("src.modes")
        local bassDef, bassState, bass = M.Instruments:getTrackInstrument(3)
        local function followRow()
            for _, r in ipairs(M.Instruments:getSoundRows(bassDef, bassState, bass)) do
                if r.key == "FOLLOW" then return r.value .. (r.note and (" - " .. r.note) or "") end
            end
        end
        bassState.follow = true
        M.Instruments:swapTrackInstrument(2, "drums")          -- no Harp chords either
        H.eq(followRow(), "ON - NO CHORDS YET", "nothing set: the row says so")
        H.eq(M.Harmony:followChip(true), "FOLLOW - NO CHORDS", "and the chip")
        fill(M, L, lane, { "I", "V" })
        H.eq(followRow(), "ON", "chords on track C")
        H.eq(M.Harmony:followChip(true):sub(1, 7), "FOLLOW ", "chip names the chord")
        L.activeTrack = 3
        bassState.follow = false
        H.truthy(Modes:followWarning(), "FOLLOW OFF over chords: a warning")
        bassState.follow = true
        H.falsy(Modes:followWarning(), "FOLLOW ON: none")
    end },

    { "GRID: one box per unit; changing it moves no chords", function()
        local M, L, lane, def = boot()
        fill(M, L, lane, { "I", "V", "vi", "IV" })
        lane.state.grid = 0.5
        H.eq(#def:cells(lane.state, lane), 8, "1/2 bar: 8 boxes in 4 bars")
        lane.state.grid = 3
        local cells = def:cells(lane.state, lane)
        H.eq(#cells, 2, "3 bars: 2 boxes (the last is short)")
        H.eq(#cells[1].starts, 3, "the first box holds C G Am")
        H.eq(laneOf(M, L, lane), "1.1:C 2.1:G 3.1:Am 4.1:F", "nothing moved")
        L.activeTrack = L.LANE
        L:setPlaying(false); L:seekLane(0)
        H.tap("R1")
        H.eq(lanePos(L), 4, "R1 steps one 3-bar box")
        H.tap("R1")
        H.eq(lanePos(L), 1, "past the short last box: back to the start")
    end },
}
