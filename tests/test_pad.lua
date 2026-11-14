-- Pad (Phase E): voicings, held chords that follow the chord track, tone on
-- the D-pad (recorded and replayed), the layered voices, and old Grain saves.
local H = require("helpers")

local function boot()
    local M = H.loadMain()
    M.Harmony = require("src.harmony")
    H.play(0.1)
    for _ = 1, 3 do H.tap("SELECT") end                 -- track 4 = pad
    return M, M.Looper, M.Looper.tracks[4].state
end

local function chordEv(M, dir, tick, colour)
    local Harp = M.Instruments:getDefinition("harp")
    local c = M.Theory:getChordForDirection(dir, false, false, colour)
    return { tick = tick, len = 0, action = "B", semis = c.notes[1], vel = 0.8, chord = Harp:chordData(c) }
end

-- C - Am - F - G, one chord per half bar (2 bars = 3840 ticks)
local function chordLoop(M, L)
    L.tracks[2].events = {
        chordEv(M, "NEUTRAL", 0), chordEv(M, "DOWN", 960), chordEv(M, "LEFT", 1920), chordEv(M, "RIGHT", 2880),
    }
end

local function seekTick(L, tick)
    L:seek(tick / L:getLoopTicks()); L.lastClockTime = H.time
end

-- Play until the playhead reaches `tick` (same pass)
local function playTo(L, tick)
    local guard = 0
    while L.tick < tick and guard < 2000 do H.play(1 / 60); guard = guard + 1 end
end

local function join(t) return table.concat(t, " ") end

-- Where the voices of a set of notes are heading, lowest first
local function targets(set)
    local out = {}
    for _, note in pairs(set) do
        for _, v in ipairs(note.voices) do out[#out + 1] = v.targetSemis end
    end
    table.sort(out)
    return join(out)
end

local function padEv(tick, len, action, extra)
    local ev = { tick = tick, len = len, action = action or "B", octave = 0, vel = 0.6, bright = 0.2, move = 0.1 }
    for k, v in pairs(extra or {}) do ev[k] = v end
    return ev
end

local function step(Synth, seconds)
    for _ = 1, math.floor(seconds * 60 + 0.5) do
        H.time = H.time + 1 / 60
        Synth:update(1 / 60)
    end
end

return {
    -- ------------------------------------------------------------------
    -- Voicings
    -- ------------------------------------------------------------------
    { "each shape's notes on C major's I, vi and V", function()
        local M = H.fresh()
        local T = M.Theory
        local function v(dir, shape, oct, colour)
            return join(T:getPadVoicing(T:getChordForDirection(dir, false, false, colour), shape, oct))
        end
        H.eq(v("NEUTRAL", "FULL", 0), "0 4 7 12", "C full")
        H.eq(v("NEUTRAL", "OPEN", 0), "0 7 12", "C open")
        H.eq(v("NEUTRAL", "HIGH", 0), "7 12 16", "C high")
        H.eq(v("DOWN", "FULL", 0), "-3 0 4 9", "Am full, below C")
        H.eq(v("RIGHT", "FULL", 0), "-5 -1 2 7", "G full, below C")
        H.eq(v("NEUTRAL", "FULL", 1), "12 16 19 24", "octave up")
        H.eq(v("NEUTRAL", "FULL", -1), "-12 -8 -5 0", "octave down")
    end },

    { "the full chord takes the harp's colour", function()
        local M = H.fresh()
        local T = M.Theory
        local function v(colour)
            return join(T:getPadVoicing(T:getChordForDirection("NEUTRAL", false, false, colour), "FULL", 0))
        end
        H.eq(v("7TH"), "0 4 7 11", "maj7")
        H.eq(v("9TH"), "0 4 11 14", "maj9")
        H.eq(v("SUS4"), "0 5 7 12", "sus4")
        H.eq(v("ADD9"), "0 4 7 14", "add9")
    end },

    { "voicings stay in the playable range in every key", function()
        local M = H.fresh()
        local T = M.Theory
        for root = 1, 12 do
            T.rootIndex = root
            for _, dir in ipairs({ "NEUTRAL", "UP", "LEFT", "RIGHT", "DOWN", "DOWN_LEFT" }) do
                for _, shape in ipairs({ "FULL", "OPEN", "HIGH" }) do
                    for oct = -1, 1 do
                        local n = T:getPadVoicing(T:getChordForDirection(dir, false, false), shape, oct)
                        H.truthy(n[1] >= T.PAD_RANGE.low and n[#n] <= T.PAD_RANGE.high,
                            string.format("key %d %s %s oct %d: %s", root, dir, shape, oct, join(n)))
                    end
                end
            end
        end
    end },

    -- ------------------------------------------------------------------
    -- Playing
    -- ------------------------------------------------------------------
    { "with no harp chords a press holds the key's I chord", function()
        local M, L, st = boot()
        H.hold("B"); H.play(0.2)
        H.eq(targets(st.live), "0 4 7 12", "C major")
        H.release("B"); H.play(0.1)
        M.Theory.rootIndex, M.Theory.scaleIndex = 10, 2          -- A minor
        H.hold("A"); H.play(0.2)
        H.eq(targets(st.live), "-3 4 9", "A minor, open")
        H.release("A"); H.play(0.1)
    end },

    { "buttons layer, and shoulders set the octave at the press", function()
        local M, L, st = boot()
        H.hold("B"); H.play(0.1)
        H.hold("R1"); H.play(0.05); H.hold("Y"); H.play(0.1)
        H.eq(targets(st.live), "0 4 7 12 19 24 28", "full + high an octave up")
        H.release("R1"); H.play(0.1)
        H.eq(targets(st.live), "0 4 7 12 19 24 28", "letting go of R1 changes nothing")
        H.release("B", "Y"); H.play(0.1)
        H.eq(targets(st.live), "", "all released")
    end },

    { "X is the full chord with a slow attack", function()
        local M, L, st = boot()
        local Pad = M.Instruments:getDefinition("pad")
        H.hold("X"); H.play(0.1)
        local _, note = next(st.live)
        H.eq(#note.voices, 4, "four notes")
        H.near(note.voices[1].attackTime, 1.2, "swell attack", 1e-9)
        H.release("X"); H.hold("B"); H.play(0.1)
        _, note = next(st.live)
        H.near(note.voices[1].attackTime, Pad.ATTACK_TIMES.MEDIUM, "B uses the ATTACK row", 1e-9)
        H.near(note.voices[1].releaseTime, Pad.RELEASE_TIMES.MEDIUM, "and the RELEASE row", 1e-9)
        H.release("B"); H.play(0.1)
    end },

    { "a chord's notes share the level", function()
        local M, L, st = boot()
        H.hold("B"); H.play(0.1)
        local _, full = next(st.live)
        local v4 = full.voices[1].vel
        H.release("B"); H.play(0.1); H.hold("A"); H.play(0.1)
        local _, open = next(st.live)
        H.near(v4 * math.sqrt(4), open.voices[1].vel * math.sqrt(3), "same total", 1e-9)
        H.release("A"); H.play(0.1)
    end },

    -- ------------------------------------------------------------------
    -- Follow
    -- ------------------------------------------------------------------
    { "a held pad moves with the chords", function()
        local M, L, st = boot()
        chordLoop(M, L)
        seekTick(L, 200)
        H.hold("B"); H.play(0.1)
        H.eq(targets(st.live), "0 4 7 12", "C")
        playTo(L, 1000); H.eq(targets(st.live), "-3 0 4 9", "Am")
        playTo(L, 1960); H.eq(targets(st.live), "5 9 12 17", "F")
        playTo(L, 2920); H.eq(targets(st.live), "-5 -1 2 7", "G")
        H.release("B"); H.play(0.1)
    end },

    { "a held pad changes on the chord's own tick, not a 1/16 early", function()
        local M, L, st = boot()
        chordLoop(M, L)
        seekTick(L, 700)
        H.hold("B"); H.play(0.1)
        playTo(L, 900)                                   -- inside the bass's 1/16 lookahead
        H.eq(targets(st.live), "0 4 7 12", "still C")
        playTo(L, 975)
        H.eq(targets(st.live), "-3 0 4 9", "Am once it sounds")
        H.release("B"); H.play(0.1)
    end },

    { "pressed just before a late chord: takes it and doesn't flip back", function()
        local M, L, st = boot()
        L.tracks[2].events = { chordEv(M, "NEUTRAL", 0), chordEv(M, "DOWN", 1020) }
        seekTick(L, 950)
        local seen = {}
        H.hold("B")
        for _ = 1, 12 do H.play(1 / 60); seen[targets(st.live)] = true end
        H.truthy(L.tick > 1020, "past the chord")
        H.truthy(seen["-3 0 4 9"], "Am")
        H.falsy(seen["0 4 7 12"], "never C")
        H.release("B"); H.play(0.1)
    end },

    { "FOLLOW OFF: a held pad stays on the chord it was pressed on", function()
        local M, L, st = boot()
        chordLoop(M, L)
        st.follow = false
        seekTick(L, 1100)
        H.hold("B"); H.play(0.1)
        H.eq(targets(st.live), "-3 0 4 9", "pressed on Am")
        playTo(L, 2000)
        H.eq(targets(st.live), "-3 0 4 9", "still Am over F")
        H.release("B"); H.play(0.1)
    end },

    { "a recorded pad replays the chords, and re-harmonises when they change", function()
        local M, L, st = boot()
        chordLoop(M, L)
        L.tracks[4].events = { padEv(100, 3600, "A", { notes = { 0, 7, 12 }, key = 0 }) }
        seekTick(L, 0)
        playTo(L, 300);  H.eq(targets(st.playing), "0 7 12", "C")
        playTo(L, 1100); H.eq(targets(st.playing), "-3 4 9", "Am")
        playTo(L, 3000); H.eq(targets(st.playing), "-5 2 7", "G")
        playTo(L, 3780); H.eq(targets(st.playing), "", "ended")
        -- new chords under the same recording
        L.tracks[2].events = { chordEv(M, "LEFT", 0) }
        seekTick(L, 0)
        playTo(L, 300);  H.eq(targets(st.playing), "5 12 17", "F now")
    end },

    { "FOLLOW OFF: a recorded pad plays its stored notes, moved with the key", function()
        local M, L, st = boot()
        chordLoop(M, L)
        st.follow = false
        L.tracks[4].events = { padEv(1000, 2000, "B", { notes = { -3, 0, 4, 9 }, key = 0 }) }
        seekTick(L, 900)
        playTo(L, 1100); H.eq(targets(st.playing), "-3 0 4 9", "Am as recorded")
        playTo(L, 2100); H.eq(targets(st.playing), "-3 0 4 9", "unchanged over F")
        M.Theory.rootIndex = 3                             -- D: up two semitones
        L:silenceAll(); seekTick(L, 900)
        playTo(L, 1100); H.eq(targets(st.playing), "-1 2 6 11", "moved with the key")
    end },

    { "damaged notes in a save can't break playback", function()
        local M, L, st = boot()
        st.follow = false
        L.tracks[4].events = { padEv(100, 500, "B", { notes = { "x", 0 / 0, 999, {} }, octave = "up", bright = "no" }),
                               padEv(1000, 500, "Y", { notes = 7 }) }
        seekTick(L, 0)
        playTo(L, 300);  H.eq(targets(st.playing), "43", "only the number, clamped")
        playTo(L, 1200); H.eq(targets(st.playing), "7 12 16", "no notes: the chord's")
    end },

    -- ------------------------------------------------------------------
    -- Tone
    -- ------------------------------------------------------------------
    { "the D-pad sweeps brightness and movement and live voices follow", function()
        local M, L, st = boot()
        local b0, m0 = st.bright, st.move
        H.hold("B"); H.play(0.1)
        H.hold("UP", "LEFT"); H.play(0.3); H.release("UP", "LEFT")
        H.truthy(st.bright > b0 + 0.15, "brighter")
        H.truthy(st.move < m0 - 0.15, "less movement")
        local _, note = next(st.live)
        H.near(note.voices[1].bright, st.bright, "voice brightness", 1e-9)
        H.near(note.voices[1].move, st.move, "voice movement", 1e-9)
        H.hold("UP"); H.play(3.0); H.release("UP")
        H.eq(st.bright, 1.0, "clamped at the top")
        H.hold("DOWN", "RIGHT"); H.play(3.0); H.release("DOWN", "RIGHT")
        H.eq(st.bright, 0.0, "clamped at the bottom")
        H.eq(st.move, 1.0, "movement clamped")
        H.release("B"); H.play(0.1)
    end },

    { "a sweep while holding is recorded as keyframes and replayed", function()
        local M, L, st = boot()
        st.bright = 0.2
        seekTick(L, 0)
        H.tap("L2")
        H.hold("B"); H.play(0.2)
        H.hold("UP"); H.play(0.5); H.release("UP"); H.play(0.1)
        H.release("B"); H.play(0.05)
        H.tap("L2")
        local ev = L.tracks[4].events[1]
        H.near(ev.bright, 0.2, "brightness at the press", 1e-9)
        H.truthy(ev.bend and #ev.bend >= 5 and #ev.bend <= 10, "a keyframe per step (" .. (ev.bend and #ev.bend or 0) .. ")")
        local last = ev.bend[#ev.bend]
        H.truthy(last.bright > 0.45 and last.semis == nil, "tone only")
        -- playback: starts dark, ends bright
        st.bright = 0.9                                    -- the live value doesn't matter
        seekTick(L, L:getLoopTicks() - 60)
        while L.tick > 1000 do H.play(1 / 60) end        -- over the seam
        playTo(L, ev.tick + 60)
        local _, note = next(st.playing)
        H.near(note.voices[1].bright, 0.2, "starts as recorded", 1e-9)
        playTo(L, ev.tick + ev.len - 30)
        _, note = next(st.playing)
        H.near(note.voices[1].bright, last.bright, "ends at the last keyframe", 1e-9)
    end },

    { "tone keyframes survive save and load, and 2 -> 4 bars copies them", function()
        local M, L, st = boot()
        L.tracks[4].events = { padEv(100, 800, "B", { bend = { { dt = 100, bright = 0.5, move = 0.2 }, { dt = 300, bright = 7 } } }) }
        local data = assert(M.Save.decode(M.Save.encode(M.Session.snapshot())))
        H.truthy(M.Session.restore(data), "restored")
        local b = L.tracks[4].events[1].bend
        H.eq(#b, 2, "both keyframes")
        H.near(b[1].bright, 0.5, "bright", 1e-9); H.near(b[1].move, 0.2, "move", 1e-9)
        H.eq(b[2].bright, 1.0, "clamped"); H.eq(b[2].semis, nil, "no pitch invented")
        L:toggleBars()
        local copy = L.tracks[4].events[2].bend
        H.truthy(copy ~= b and copy[1].bright == 0.5 and copy[1].move == 0.2, "own copy with the tone")
    end },

    -- ------------------------------------------------------------------
    -- Rows, saves
    -- ------------------------------------------------------------------
    { "Track page rows: PATCH, FOLLOW, ATTACK, RELEASE", function()
        local M, L, st = boot()
        H.hold("SELECT"); H.play(0.3)
        H.tap("R1");                H.eq(st.patch, "pad_bell", "patch")
        H.tap("DOWN"); H.tap("R1"); H.falsy(st.follow, "follow off")
        H.tap("DOWN"); H.tap("R1"); H.eq(st.attack, "SLOW", "attack")
        H.tap("DOWN"); H.tap("L1"); H.eq(st.release, "SHORT", "release")
        H.release("SELECT"); H.play(0.1)
        H.hold("B"); H.play(0.1)
        local _, note = next(st.live)
        H.eq(note.voices[1].patch.label, "BELL", "plays the patch")
        H.near(note.voices[1].releaseTime, 0.25, "short release", 1e-9)
        H.release("B"); H.play(0.1)
    end },

    { "BELL strikes on a fast attack only", function()
        local M, L, st = boot()
        st.patch = "pad_bell"
        local strikes = 0
        local orig = M.Synth.trigger
        M.Synth.trigger = function(self, name, ...)
            if name == "pad_bell" then strikes = strikes + 1 end
            return orig(self, name, ...)
        end
        H.hold("B"); H.play(0.1); H.release("B"); H.play(0.1)
        H.eq(strikes, 0, "medium attack: no strike")
        st.attack = "FAST"
        H.hold("B"); H.play(0.1); H.release("B"); H.play(0.1)
        H.eq(strikes, 4, "fast attack: one per note")
    end },

    { "an old save with a Grain track loads as a Pad with its notes", function()
        local M, L = boot()
        local data = M.Session.snapshot()
        data.tracks[4].instrumentId = "grain"
        data.tracks[4].settings = { scanPos = 0.5, density = 0.4 }
        data.tracks[4].events = { { tick = 480, len = 600, action = "Y", semis = 4, scanPos = 0.5, density = 0.4, vel = 0.55 } }
        H.truthy(M.Session.restore(data), "restored")
        H.eq(L.tracks[4].instrumentId, "pad", "pad")
        H.eq(#L.tracks[4].events, 1, "note kept")
        local st = L.tracks[4].state
        seekTick(L, 400); playTo(L, 600)
        H.eq(targets(st.playing), "7 12 16", "plays as a high chord")
    end },

    -- ------------------------------------------------------------------
    -- Voice engine: layers, envelope, movement
    -- ------------------------------------------------------------------
    { "the bright layer's level is the brightness, smoothed; silent at 0", function()
        local M = H.fresh({ realSynth = true })
        local S = M.Synth
        S:init()
        local v = S:noteOn("pad_warm", 0, 0.8, { attack = 0.1, bright = 0.0 })
        step(S, 0.3)
        H.truthy(v.loopSrc.volume > 0.1, "dark layer sounding")
        H.eq(v.brightSrc.volume, 0.0, "bright layer silent")
        v.bright = 1.0
        step(S, 1 / 60)
        H.truthy(v.brightSrc.volume > 0 and v.brightSrc.volume < v.loopSrc.volume * 0.5, "fading in, not jumping")
        step(S, 1.0)
        H.near(v.brightSrc.volume, v.loopSrc.volume, "full brightness = the envelope's level", 1e-4)
        H.truthy(v.brightSrc.playing and v.brightSrc.looping, "looping")
    end },

    { "per-note attack and release times replace the patch's", function()
        local M = H.fresh({ realSynth = true })
        local S = M.Synth
        S:init()
        local v = S:noteOn("pad_warm", 0, 1.0, { attack = 1.0, release = 2.0 })
        step(S, 0.5)
        H.near(v:envelope(), v.patch.sustain * 0.5, "halfway up a 1 s attack", 0.02)
        step(S, 1.0)
        v:noteOff(); step(S, 1.0)
        H.near(v:envelope(), v.patch.sustain * 0.5, "halfway down a 2 s release", 0.02)
        step(S, 1.1)
        H.falsy(v:isSounding(), "over")
        H.falsy(v.brightSrc.playing, "bright layer stopped too")
    end },

    { "a tap during a slow attack only fades", function()
        local M = H.fresh({ realSynth = true })
        local S = M.Synth
        S:init()
        local v = S:noteOn("pad_warm", 0, 1.0, { attack = 2.0, release = 1.0 })
        step(S, 0.2)
        local level = v:envelope()
        v:noteOff()
        for _ = 1, 30 do
            step(S, 1 / 60)
            H.truthy(v:envelope() <= level + 1e-9, "never louder than at the release")
            level = v:envelope()
        end
    end },

    { "movement stays within its cents, and is off at 0", function()
        local M = H.fresh({ realSynth = true })
        local S = M.Synth
        S:init()
        local Voice = require("src.synth.voice")
        local still = S:noteOn("pad_warm", 0, 0.8, { move = 0.0, bright = 1.0 })
        local moving = S:noteOn("pad_warm", 0, 0.8, { move = 1.0, bright = 1.0 })
        local lo, hi = 1e9, -1e9
        for _ = 1, 600 do
            step(S, 1 / 60)
            H.near(still.loopSrc.pitch, 2 ^ (still.patch.tune / 12), "no drift", 1e-9)
            H.near(still.brightSrc.pitch, still.loopSrc.pitch, "no detune", 1e-9)
            local semis = 12 * math.log(moving.loopSrc.pitch) / math.log(2) - moving.patch.tune
            lo, hi = math.min(lo, semis), math.max(hi, semis)
        end
        H.truthy(hi <= Voice.DRIFT + 1e-6 and lo >= -Voice.DRIFT - 1e-6, "inside the drift")
        H.truthy(hi > Voice.DRIFT * 0.8 and lo < -Voice.DRIFT * 0.8, "and it does move")
        H.truthy(moving.brightSrc.pitch > moving.loopSrc.pitch, "bright layer detuned up")
    end },

    { "stealing a pad voice frees and reuses both layers", function()
        local M = H.fresh({ realSynth = true })
        local S = M.Synth
        S:init()
        local n = require("src.synth.synths_bank").PAD_VOICES
        local first = S:noteOn("pad_choir", 0, 0.5, { bright = 0.5 })
        step(S, 0.1)
        for i = 1, n - 1 do S:noteOn("pad_choir", i, 0.5, { bright = 0.5 }) end
        step(S, 0.1)
        H.truthy(first:isSounding(), "pool exactly full")
        local extra = S:noteOn("pad_choir", 5, 0.5, { bright = 0.5 })
        H.falsy(first:isSounding(), "oldest stolen")
        H.eq(extra.loopSrc, first.loopSrc, "main layer reused")
        H.eq(extra.brightSrc, first.brightSrc, "bright layer reused")
        H.truthy(extra.brightSrc.playing, "and playing")
    end },

    { "the pad loops stay clear of clipping when a full bright chord sums", function()
        H.captureSamples = true
        local M = H.fresh({ realSynth = true })
        M.Synth:init()
        H.captureSamples = false
        local S = M.Synth
        for _, id in ipairs({ "pad_warm", "pad_bell", "pad_choir", "pad_drone" }) do
            local patch = S.patches[id]
            for _, pool in ipairs({ patch.loop, patch.bright }) do
                local sd = S.loopPools[pool].sources[1].soundData
                local peak = 0
                for i = 0, sd.n - 1 do peak = math.max(peak, math.abs(sd.samples[i])) end
                H.truthy(peak > 0.15 and peak <= 0.9, pool .. " peak " .. peak)
            end
        end
    end },
}
