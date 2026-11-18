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

    { "new colours: aug, dim, sus2, 6th (names, strings, and the chord itself)", function()
        local M = H.fresh()
        local T = M.Theory
        local function check(dir, colour, name, notes, third, fifth)
            local c = T:getChordForDirection(dir, false, false, colour)
            H.eq(c.name, name, colour .. " name")
            H.eq(table.concat(c.notes, " "), notes, colour .. " strings")
            if third then H.eq(c.third, third, colour .. " third"); H.eq(c.fifth, fifth, colour .. " fifth") end
        end
        check("NEUTRAL", "AUG", "Caug", "0 4 8 12", 4, 8)
        check("NEUTRAL", "DIM", "Cdim", "0 3 6 12", 3, 6)
        check("NEUTRAL", "SUS2", "Csus2", "0 2 7 12")
        check("NEUTRAL", "6TH", "C6", "0 4 7 9")
        check("DOWN", "6TH", "Am6", "9 12 16 18")
        H.eq(table.concat(T:getPadVoicing(T:getChordForDirection("NEUTRAL", false, false, "6TH"), "FULL", 0), " "),
            "0 4 7 9", "pad: 6th on top")
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

    { "the progression is shown as numerals; the D-pad marks the one for this point", function()
        local M, L, st, def = boot()
        H.eq(def:progressionOf(st).name, "POP", "opens on POP")
        L:setPlaying(false); L:seek(0.55); H.play(0.05)          -- third quarter of the loop
        H.eq(def:guideIndex(st), 3, "FIT over 2 bars: vi's half bar")
        H.eq(def:getGuideDir(st), "DOWN", "the star suggests vi")
        H.eq(def.VIEW.dpad.DOWN, "vi", "labels stay plain numerals")
        local v = def:getView(st)
        H.eq(table.concat(v.romans, " "), "I V vi IV", "numerals in the view")
        H.eq(v.guide, 3, "the star on the third dot")
        H.eq(v.progRight, "FIT", "length")
        H.eq(v.emptyLabel, "X STAMPS POP  -  B WRITES", "an empty loop says how to fill it")
    end },

    { "hold A + D-pad colours the chord under the playhead; one undo per press", function()
        local M, L, st, def, track = boot()
        H.tap("X")
        L:setPlaying(false); L:seek(0.3); H.play(0.05)           -- on G
        H.hold("A"); H.play(0.05)
        H.hold("DOWN", "RIGHT"); H.play(0.05)
        H.eq(chordsOf(M, track), "0:C 960:Gaug 1920:Am 2880:F", "down-right = aug")
        H.release("DOWN", "RIGHT"); H.hold("UP"); H.play(0.05)
        H.eq(chordsOf(M, track), "0:C 960:G7 1920:Am 2880:F", "up = 7")
        H.release("UP"); H.play(0.05)
        H.eq(chordsOf(M, track), "0:C 960:G7 1920:Am 2880:F", "letting the D-pad go keeps it")
        H.release("A"); H.play(0.05)
        local labels = {}
        for i, sp in ipairs(def:getView(st).spans) do labels[i] = sp.label end
        H.eq(table.concat(labels, " "), "I V7 vi IV", "numerals with colour")
        H.eq(M.Theory:chordName(M.Harmony:chordAt(1000)), "G7", "followers get it")
        L:undo()
        H.eq(chordsOf(M, track), "0:C 960:G 1920:Am 2880:F", "one undo for the press")
    end },

    { "A with no chord under the playhead sets the colour new chords get", function()
        local M, L, st = boot()
        H.hold("A", "UP"); H.play(0.05); H.release("A", "UP"); H.play(0.05)
        H.eq(st.colour, "7TH", "new chords: 7TH")
    end },

    { "Y deletes the chord under the playhead; held, every chord it reaches", function()
        local M, L, st, def, track = boot()
        H.tap("X")
        L:setPlaying(false); L:seek(0.55); H.play(0.05)
        H.tap("Y")
        H.eq(chordsOf(M, track), "0:C 960:G 2880:F", "Am gone")
        L:undo()
        H.eq(chordsOf(M, track), "0:C 960:G 1920:Am 2880:F", "undo")
        L:setPlaying(true); at(L, 0.01)
        H.hold("Y"); H.play(L:getLoopDuration() * 0.95); H.release("Y"); H.play(0.05)
        H.eq(chordsOf(M, track), "", "held through the loop: all gone")
        L:undo()
        H.eq(chordsOf(M, track), "0:C 960:G 1920:Am 2880:F", "one undo for the whole hold")
    end },

    { "the view: spans of the loop, the playhead's chord, levels by root, the source", function()
        local M, L, st, def, track = boot()
        H.tap("X")
        L:setPlaying(false); L:seek(0.55); H.play(0.05)
        local v = def:getView(st, track)
        H.eq(#v.spans, 4, "four spans")
        H.near(v.spans[2].from, 0.25, "G from a quarter")
        H.near(v.spans[2].to, 0.5, "to half way")
        H.truthy(v.spans[3].now, "Am is now")
        H.falsy(v.spans[1].now, "C isn't")
        H.near(v.spans[1].level, 0, "I at the bottom")
        H.near(v.spans[3].level, 9 / 11, "vi up at its root")
        H.near(v.playhead.level, v.spans[3].level, "the star rides Am")
        H.eq(v.sourceLabel, "SETS CHORDS", "this track sets the chords")
        H.eq(v.sub, "I  -  TRIAD  -  ON THE BEAT", "the D-pad's chord (at rest: I)")
        -- a chord that starts late: the last one carries over to it
        track.events = { track.events[2], track.events[3] }      -- G at 960, Am at 1920
        L:seek(0.1); H.play(0.05)
        v = def:getView(st, track)
        H.truthy(v.spans[1].carry, "a carried span first")
        H.eq(v.spans[1].label, "vi", "Am carries over from the loop's end")
        H.truthy(v.spans[1].now, "and is what's playing")
        H.falsy(v.spans[3].now, "not twice")
    end },

    { "holding A: the view shows the colour, the star stops suggesting", function()
        local M, L, st, def, track = boot()
        H.tap("X")
        L:setPlaying(false); L:seek(0.3); H.play(0.05)
        H.hold("A", "DOWN", "RIGHT"); H.play(0.05)
        local v = def:getView(st, track)
        H.eq(v.name, "Gaug", "the chord under the playhead, recoloured")
        H.eq(v.middle, "COLOUR AUG", "the colour badge")
        H.truthy(v.colouring, "lit")
        H.eq(def:getGuideDir(st), nil, "no guide while colouring")
        H.eq(def:getDpadSubtitle(st), "D-PAD: COLOUR", "subtitle")
        H.release("A", "DOWN", "RIGHT"); H.play(0.05)
    end },

    { "SPICE colours plain chords on playback, for followers too, never recorded", function()
        local M, L, st, def, track = boot()
        H.tap("X")
        def.random = function() return 0 end                     -- always spice, first option
        def:cycleSetting(st, "SPICE", 1)
        H.eq(st.spiceLevel, "LIGHT", "LIGHT")
        H.play(0.05)
        H.eq(M.Theory:chordName(M.Harmony:chordAt(100)), "Cmaj7", "I becomes maj7 this pass")
        H.eq(chordsOf(M, track), "0:C 960:G 1920:Am 2880:F", "the recording is unchanged")
        def.random = function() return 0.99 end
        st.spiceTick = nil; H.play(0.05)
        H.eq(M.Theory:chordName(M.Harmony:chordAt(100)), "C", "no spice this pass")
        def:cycleSetting(st, "SPICE", -1)
        H.play(0.05)
        H.falsy(next(st.spice), "OFF clears it")
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
        H.eq(L.toastText, "UNDO STAMP ON TRACK 1", "says what it undid")
        H.eq(L.tracks[1].instrumentId, "chords", "still the chord track")
    end },

    { "a Harp that follows plays the Chord Track's chords and never becomes the source", function()
        local M, L, st, def, track = boot()
        def:stamp(st, track)                                  -- C G Am F on track 1
        local harpTrack = L.tracks[2]
        local Harp = M.Instruments.byId.harp
        local hs = harpTrack.state
        Harp:cycleSetting(hs, "FOLLOW", 1)
        H.truthy(hs.follow, "following")
        L.activeTrack = 2
        L:setPlaying(false); L:seek(0.55); H.play(0.05)      -- under Am
        H.eq(hs.currentChord.name, "Am", "the harp shows the Chord Track's chord")
        H.eq(table.concat(hs.currentChord.notes, " "), "-3 0 4 9", "its strings: A C E A")
        H.tap("L2"); H.tap("B"); H.tap("L2")
        H.eq(hs.strings[1].lastSemis, -3, "B plucks A")
        local ev = harpTrack.events[1]
        H.truthy(ev and ev.follow, "recorded as a followed string")
        H.eq(ev.chord, nil, "no chord on it")
        H.eq(M.Harmony:source(), track, "the Chord Track still sets the chords")
        H.eq(hs.liveChord, nil, "it chose nothing live")
        -- played back over a different chord: re-fits
        Harp:noteOn({ action = "B", follow = true, string = 1, octShift = 0, tick = 1000, semis = 99 }, hs, harpTrack, true)
        H.eq(hs.strings[1].lastSemis, -5, "over G: G")
        H.eq(Harp:getDpadSubtitle(hs), "D-PAD: - (FOLLOWING)", "the D-pad has no job")
        local fresh = Harp:newState()
        Harp:loadState(fresh, Harp:saveState(hs))
        H.truthy(fresh.follow, "follow saves")
    end },

    { "settings save and load by name", function()
        local M, L, st, def = boot()
        def:cycleSetting(st, "PROGRESSION", 3)     -- ROCK
        def:cycleSetting(st, "LENGTH", 1)          -- 2 BARS
        def:cycleSetting(st, "COLOUR", 1)          -- 7TH
        def:cycleSetting(st, "SPICE", 2)           -- WILD
        local saved = def:saveState(st)
        H.eq(saved.progression, "ROCK", "by name")
        local fresh = def:newState()
        def:loadState(fresh, saved)
        H.eq(fresh.progression, st.progression, "progression")
        H.eq(fresh.length, st.length, "length")
        H.eq(fresh.colour, "7TH", "colour")
        H.eq(fresh.patch, "silent", "patch")
        H.eq(fresh.spiceLevel, "WILD", "spice")
    end },
}
