-- CHORD TRACK (src/instruments/chords.lua): an instrument whose job is
-- choosing the chords. Runs because "chords" is a lab id (tests/run.lua).
local H = require("helpers")

-- The real game, track 1 playing the Chord Track (the harp stays on track 2)
local function boot()
    local M = H.loadMain()
    M.Harmony = require("src.harmony")
    H.play(0.1)
    M.Instruments:swapTrackInstrument(1, "chords")
    M.Looper.activeTrack = 1
    local track = M.Looper.tracks[1]
    return M, M.Looper, track.state, M.Instruments.byId.chords, track
end

local function at(L, phase) L:seek(phase); L.lastClockTime = H.time end

-- The track's chords as names in tick order: "0:C 960:G"
local function chordsOf(M, track)
    local list = {}
    for _, ev in ipairs(track.events) do
        if ev.chord then list[#list + 1] = ev end
    end
    table.sort(list, function(a, b) return a.tick < b.tick end)
    local out = {}
    for i, ev in ipairs(list) do out[i] = ev.tick .. ":" .. M.Theory:chordName(ev.chord) end
    return table.concat(out, " ")
end

return {
    { "CHORD TRACK is an instrument that sets chords, silent by default", function()
        local M = H.fresh()
        local def = M.Instruments.byId.chords
        H.truthy(def, "registered")
        H.falsy(def.lab, "an ordinary instrument")
        H.truthy(def.chordSource, "a chord source")
        H.eq(def.DEFAULT_PATCH, "silent", "opens on SILENT")
        H.eq(def.ERASE.B.actions[1], "B", "CLR B clears the chords")
        H.truthy(require("src.harmony").SOURCES.chords, "Harmony reads it")
        for _, p in ipairs(def.PROGRESSIONS) do
            H.eq(#p.dirs, #p.romans, p.name .. ": every chord on the D-pad")
        end
    end },

    { "B plays the D-pad's chord live; followers follow it", function()
        local M, L, st = boot()
        H.hold("DOWN"); H.play(0.05); H.tap("B"); H.release("DOWN"); H.play(0.05)
        local chord, from = M.Harmony:current()
        H.eq(M.Theory:chordName(chord), "Am", "vi")
        H.eq(from, "live", "played live")
    end },

    { "the top chord track wins: Chord Track on 1 over the Harp on 2", function()
        local M, L, st, def, track = boot()
        H.eq(L.tracks[2].instrumentId, "harp", "harp on track 2")
        local Harp = M.Instruments.byId.harp
        local G = M.Theory:getChordForDirection("RIGHT", false, false)
        L.tracks[2].events = { { tick = 0, len = 0, action = "B", semis = 0, vel = 0.8, chord = Harp:chordData(G) } }
        H.eq(M.Theory:chordName(M.Harmony:chordAt(100)), "G", "harp alone sets it")
        local F = M.Theory:getChordForDirection("LEFT", false, false)
        track.events = { { tick = 0, len = 0, action = "B", vel = 0.8, chord = def:chordData(F) } }
        H.eq(M.Theory:chordName(M.Harmony:chordAt(100)), "F", "the chord track on 1 wins")
        H.eq(M.Harmony:source(), track, "source")
    end },

    { "with L1 a chord snaps to the nearest bar line", function()
        local M, L, st, def, track = boot()
        H.tap("L2")
        at(L, 0.62)                               -- early in bar 2 (2 bars)
        H.hold("L1", "LEFT"); H.play(0.05); H.tap("B"); H.release("L1", "LEFT")
        H.tap("L2")
        H.eq(chordsOf(M, track), "1920:F", "written at bar 2's start")
    end },

    { "A walks the progression, Y goes back to the top", function()
        local M, L, st, def = boot()
        H.eq(def:progressionOf(st).name, "POP", "opens on POP")
        local names = {}
        for i = 1, 5 do
            H.tap("A")
            names[i] = M.Theory:chordName(st.lastPlaced.chord)
        end
        H.eq(table.concat(names, " "), "C G Am F C", "I V vi IV, round again")
        H.tap("Y")
        H.eq(M.Theory:chordName(st.lastPlaced.chord), "C", "top")
        H.tap("A")
        H.eq(M.Theory:chordName(st.lastPlaced.chord), "G", "then the second")
    end },

    { "holding A + R1 records the progression a half bar per chord", function()
        local M, L, st, def, track = boot()
        H.tap("L2")
        at(L, 0.0)
        H.hold("R1", "A")
        H.play(L:getLoopDuration() * 0.97)
        H.release("R1", "A")
        H.tap("L2")
        H.eq(chordsOf(M, track), "0:C 960:G 1920:Am 2880:F", "one chord on every half bar")
    end },

    { "holding B + L1 writes the D-pad's chord on each bar line", function()
        local M, L, st, def, track = boot()
        H.tap("L2")
        at(L, 0.0)
        H.hold("L1", "B"); H.play(0.1)
        H.hold("DOWN"); H.play(L:getLoopDuration() * 0.5)   -- steer to vi before bar 2
        H.release("L1", "B", "DOWN")
        H.tap("L2")
        H.eq(chordsOf(M, track), "0:C 1920:Am", "C, then Am on bar 2")
    end },

    { "X stamps the progression over the loop; undo brings the old chords back", function()
        local M, L, st, def, track = boot()
        local old = { { tick = 0, len = 0, action = "B", vel = 0.8,
                        chord = def:chordData(M.Theory:getChordForDirection("UP", false, false)) } }
        track.events = old
        H.tap("X")
        H.eq(chordsOf(M, track), "0:C 960:G 1920:Am 2880:F", "FIT: four chords over two bars")
        def:cycleSetting(st, "LENGTH", 2)          -- 1 BAR
        H.tap("X")
        H.eq(chordsOf(M, track), "0:C 1920:G", "1 BAR: the first two fit")
        L:undo(); L:undo()
        H.eq(track.events, old, "both stamps undone")
        H.eq(L.tracks[1].instrumentId, "chords", "still the chord track")
    end },

    { "settings save and load by name", function()
        local M, L, st, def = boot()
        def:cycleSetting(st, "PROGRESSION", 3)     -- ROCK
        def:cycleSetting(st, "LENGTH", 1)          -- 2 BARS
        def:cycleSetting(st, "COLOUR", 1)          -- 7TH
        local saved = def:saveState(st)
        H.eq(saved.progression, "ROCK", "by name")
        local fresh = def:newState()
        def:loadState(fresh, saved)
        H.eq(fresh.progression, st.progression, "progression")
        H.eq(fresh.length, st.length, "length")
        H.eq(fresh.colour, "7TH", "colour")
        H.eq(fresh.patch, "silent", "patch")
    end },
}
