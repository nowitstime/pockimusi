-- Harmony and chord-follow (Phase D): the current chord, and the bass
-- playing its degrees over it.
local H = require("helpers")

local function boot()
    local M = H.loadMain()
    M.Harmony = require("src.harmony")
    H.play(0.1)
    return M, M.Looper
end

local function chordEv(M, dir, tick, colour)
    local Harp = M.Instruments:getDefinition("harp")
    local c = M.Theory:getChordForDirection(dir, false, false, colour)
    return { tick = tick, len = 0, action = "B", semis = c.notes[1], vel = 0.8, chord = Harp:chordData(c) }
end

-- C - Am - F - G, one chord per half bar (2 bars = 3840 ticks)
local function chordLoop(M, L, slot)
    L.tracks[slot or 2].events = {
        chordEv(M, "NEUTRAL", 0), chordEv(M, "DOWN", 960), chordEv(M, "LEFT", 1920), chordEv(M, "RIGHT", 2880),
    }
end

local function bassNote(tick, degree, extra)
    local ev = { tick = tick, len = 240, action = "B", degree = degree, octave = 0, semis = 0, vel = 0.85 }
    for k, v in pairs(extra or {}) do ev[k] = v end
    return ev
end

-- Pitches of the sustained voices started during one loop of playback, in order
local function playLoop(M, L)
    local started = {}
    local orig = M.Synth.noteOn
    M.Synth.noteOn = function(self, patch, semis, ...)
        if patch:find("^bass") then started[#started + 1] = semis end
        return orig(self, patch, semis, ...)
    end
    L:seek(0.999); L.lastClockTime = H.time
    H.play(L:getLoopDuration())
    M.Synth.noteOn = orig
    return table.concat(started, " ")
end

local function name(M, chord) return M.Theory:chordName(chord) end

return {
    -- ------------------------------------------------------------------
    -- D3: the current chord
    -- ------------------------------------------------------------------
    { "no chords anywhere: the tonic", function()
        local M, L = boot()
        local chord, from = M.Harmony:chordAt(500)
        H.eq(name(M, chord), "C", "I")
        H.eq(from, "tonic", "source")
        M.Theory.rootIndex, M.Theory.scaleIndex = 10, 2
        H.eq(name(M, M.Harmony:chordAt(0)), "Am", "follows the key")
    end },

    { "recorded chords: the latest at each position, wrapping before the first", function()
        local M, L = boot()
        chordLoop(M, L)
        local function at(tick) local c, from = M.Harmony:chordAt(tick); return name(M, c), from end
        H.eq(at(0), "C", "start")
        H.eq(at(700), "C", "between")
        H.eq(at(960), "Am", "on the change")
        H.eq(at(2500), "F", "third chord")
        H.eq(at(3700), "G", "last chord")
        H.eq(select(2, at(0)), "recorded", "source")
        L.tracks[2].events = { chordEv(M, "DOWN", 960), chordEv(M, "RIGHT", 2880) }
        H.eq(at(100), "G", "before the first chord: the last one carries over")
    end },

    { "a chord played a touch late still counts on the beat", function()
        local M, L = boot()
        L.tracks[2].events = { chordEv(M, "NEUTRAL", 30), chordEv(M, "DOWN", 1000) }
        H.eq(name(M, M.Harmony:chordAt(960)), "Am", "40 ticks late: new chord on the beat")
        H.eq(name(M, M.Harmony:chordAt(800)), "C", "but not a whole 1/8 early")
        H.eq(name(M, M.Harmony:chordAt(0)), "C", "same at the loop start")
    end },

    { "the lowest-numbered harp with chords is the source; muting doesn't matter", function()
        local M, L = boot()
        M.Instruments:swapTrackInstrument(4, "harp")
        L.tracks[4].events = { chordEv(M, "LEFT", 0) }
        H.eq(M.Harmony:source(), L.tracks[4], "track 2 has no chords yet")
        L.tracks[2].events = { chordEv(M, "RIGHT", 0) }
        H.eq(M.Harmony:source(), L.tracks[2], "track 2 wins")
        L.tracks[2].muted = true
        H.eq(name(M, M.Harmony:chordAt(0)), "G", "muted source still sets the harmony")
    end },

    { "nothing recorded: the chord last played live on the harp", function()
        local M, L = boot()
        H.tap("SELECT")                                 -- harp
        H.hold("LEFT"); H.tap("B"); H.release("LEFT")   -- play IV, not recording
        local chord, from = M.Harmony:chordAt(0)
        H.eq(name(M, chord), "F", "live chord")
        H.eq(from, "live", "source")
        H.tap("SELECT")                                 -- on to the bass: D-pad now plays bass
        H.hold("RIGHT"); H.play(0.2)
        H.eq(L.tracks[2].state.currentChord.roman, "I", "the harp's own chord ignores the D-pad while the bass is active")
        H.release("RIGHT")
        H.eq(name(M, M.Harmony:chordAt(0)), "F", "moving the D-pad on another track doesn't change it")
        chordLoop(M, L)
        H.eq(select(2, M.Harmony:chordAt(0)), "recorded", "recorded chords win")
    end },

    { "erasing, clearing or swapping the chord track falls back", function()
        local M, L = boot()
        chordLoop(M, L)
        H.eq(name(M, M.Harmony:chordAt(960)), "Am", "following")
        L:clearTrack(2)
        H.eq(select(2, M.Harmony:chordAt(960)), "tonic", "cleared")
        chordLoop(M, L)
        M.Instruments:swapTrackInstrument(2, "drums")
        H.eq(select(2, M.Harmony:chordAt(960)), "tonic", "swapped away")
        L:undo()
        H.eq(name(M, M.Harmony:chordAt(960)), "Am", "undo brings the chords back")
    end },

    { "a key change moves recorded chords, and the harp plays them in the new key", function()
        local M, L = boot()
        chordLoop(M, L)
        M.Theory.rootIndex = 3                          -- D
        H.eq(name(M, M.Harmony:chordAt(960)), "Bm", "vi in D")
        local heard = {}
        local orig = M.Synth.trigger
        M.Synth.trigger = function(self, snd, semis, ...)
            if snd == "harp" then heard[#heard + 1] = semis end
            return orig(self, snd, semis, ...)
        end
        L:seek(0.999); L.lastClockTime = H.time
        H.play(L:getLoopDuration())
        H.eq(table.concat(heard, " "), "2 11 7 9", "roots D B G A (recorded as C A F G)")
    end },

    { "harp notes record their chord relative to the key", function()
        local M, L = boot()
        H.tap("SELECT"); H.tap("L2")
        H.hold("RIGHT"); H.tap("A"); H.release("RIGHT")
        H.tap("L2")
        local c = L.tracks[2].events[1].chord
        H.eq(c.root, 7, "root offset")
        H.eq(c.third .. " " .. c.fifth .. " " .. c.seventh, "4 7 10", "intervals")
        H.eq(c.key, 0, "recorded in C")
        H.eq(c.roman, "V", "numeral")
    end },

    -- ------------------------------------------------------------------
    -- D4: the bass follows
    -- ------------------------------------------------------------------
    { "a root-note bass line follows C - Am - F - G", function()
        local M, L = boot()
        chordLoop(M, L)
        L.tracks[3].events = { bassNote(0, 1), bassNote(960, 1), bassNote(1920, 1), bassNote(2880, 1) }
        H.eq(playLoop(M, L), "0 -3 5 -5", "C, A below, F, G below")
    end },

    { "thirds, fifths and the low fifth follow each chord too", function()
        local M, L = boot()
        chordLoop(M, L)
        L.tracks[3].events = { bassNote(0, 3), bassNote(960, 3), bassNote(1920, 5), bassNote(2880, -2) }
        H.eq(playLoop(M, L), "4 0 12 -10", "E, C, C, D")
    end },

    { "borrowed chords give their own root and third", function()
        local M, L = boot()
        L.tracks[2].events = { chordEv(M, "DOWN_LEFT", 0), chordEv(M, "UP", 1920) }
        L.tracks[3].events = { bassNote(0, 1), bassNote(480, 3), bassNote(1920, 1), bassNote(2400, 3) }
        H.eq(playLoop(M, L), "-2 2 -4 0", "Bb, D, Ab, C")
    end },

    { "recording chords after the bass re-harmonises it; FOLLOW OFF plays what was recorded", function()
        local M, L = boot()
        L.tracks[3].events = { bassNote(0, 1), bassNote(960, 1, { semis = 0 }) }
        H.eq(playLoop(M, L), "0 0", "no chords: both on C")
        chordLoop(M, L)
        H.eq(playLoop(M, L), "0 -3", "chords added: the second note moves to A")
        L.tracks[3].state.follow = false
        H.eq(playLoop(M, L), "0 0", "follow off: as recorded")
    end },

    { "octave and the 7th colour carry through", function()
        local M, L = boot()
        L.tracks[2].events = { chordEv(M, "RIGHT", 0, "7TH") }
        L.tracks[3].events = { bassNote(0, 7), bassNote(960, 1, { octave = 1 }) }
        H.eq(playLoop(M, L), "5 7", "F (b7 of G7), G an octave up from G below")
    end },

    { "live playing follows the chord at the playhead", function()
        local M, L = boot()
        chordLoop(M, L)
        H.tap("SELECT"); H.tap("SELECT")                -- bass
        L:setPlaying(false)
        local function press(phase)
            L:seek(phase)
            H.hold("B"); H.play(0.05)
            local v = M.Synth.sustainVoices[#M.Synth.sustainVoices]
            local semis = v.targetSemis
            H.release("B"); H.play(0.4)
            return semis
        end
        H.eq(press(0.30), -3, "over Am: A")
        H.eq(press(0.55), 5, "over F: F")
        H.eq(press(0.80), -5, "over G: G")
    end },

    { "a live note records the pitch heard, and its bends stay over its chord", function()
        local M, L = boot()
        chordLoop(M, L)
        H.tap("SELECT"); H.tap("SELECT")
        L:setPlaying(false); L:seek(0.30)               -- Am
        H.tap("L2")
        H.hold("B"); H.play(0.1)
        H.hold("UP"); H.play(0.2)                       -- degree 5 of Am = E
        local v = M.Synth.sustainVoices[#M.Synth.sustainVoices]
        H.eq(v.targetSemis, 4, "bend to E (fifth of Am)")
        H.release("UP", "B"); H.play(0.1); H.tap("L2")
        local ev = L.tracks[3].events[1]
        H.eq(ev.degree, 1, "degree stored")
        H.eq(ev.semis, -3, "heard pitch stored")
        H.eq(ev.bend[1].degree, 5, "bend degree")
        H.eq(ev.bend[1].semis, 4, "bend pitch")
    end },

    { "a held note keeps its pitch when the chord changes under it", function()
        local M, L = boot()
        chordLoop(M, L)
        L.tracks[3].events = { bassNote(0, 1, { len = 1800 }) }      -- held across C -> Am
        L:seek(0.999); L.lastClockTime = H.time
        H.play(L:getLoopDuration() * 0.4)                             -- now over Am
        local v = M.Synth.sustainVoices[1]
        H.truthy(v and not v.releasedAt, "still held")
        H.eq(v.targetSemis, 0, "still C")
    end },

    { "recorded bends replay over the note's chord", function()
        local M, L = boot()
        chordLoop(M, L)
        L.tracks[3].events = { bassNote(960, 1, { len = 600, bend = { { dt = 200, degree = 3, octave = 0, semis = 99 } } }) }
        L:seek(0.24); L.lastClockTime = H.time
        H.play(L:getLoopDuration() * 0.12)
        local v = M.Synth.sustainVoices[1]
        H.eq(v.targetSemis, 0, "third of Am = C (not the stored 99)")
    end },

    { "FOLLOW row toggles, saves and loads", function()
        local M, L = boot()
        local Bass = M.Instruments:getDefinition("bass")
        local st = L.tracks[3].state
        H.truthy(st.follow, "on by default")
        Bass:cycleSetting(st, "FOLLOW", 1)
        H.falsy(st.follow, "off")
        local data = M.Save.decode(M.Save.encode(M.Session.snapshot()))
        local M2, L2 = boot()
        M2.Session.restore(data)
        H.falsy(L2.tracks[3].state.follow, "restored off")
    end },

    { "with no harp at all the bass plays in the key, as before", function()
        local M, L = boot()
        M.Instruments:swapTrackInstrument(2, "drums")
        M.Theory.scaleIndex = 2
        L.tracks[3].events = { bassNote(0, 3), bassNote(960, 6), bassNote(1920, -2) }
        H.eq(playLoop(M, L), "3 8 -5", "C minor degrees")
    end },
}
