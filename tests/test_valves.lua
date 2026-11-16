-- VALVES (lab/VALVES.md): fingerings and breath, like a brass instrument.
-- This file runs because "valves" is a reserved lab id (tests/run.lua).
local H = require("helpers")

-- Track 3 plays Valves, in C major on the tonic chord
local function boot()
    local M = H.loadMain()
    H.play(0.1)
    M.Instruments:swapTrackInstrument(3, "valves")
    M.Looper.activeTrack = 3
    local track = M.Looper.tracks[3]
    return M, track.state, M.Instruments.byId.valves, track
end

-- The chord followers hear, as if played live on the harp
local function setChord(M, dir)
    M.Looper.tracks[2].state.liveChord = M.Theory:getChordForDirection(dir, false, false)
end

-- Voices that are holding (not released)
local function heldVoices(M)
    local out = {}
    for _, v in ipairs(M.Synth.sustainVoices) do
        if not v.releasedAt then out[#out + 1] = v end
    end
    return out
end

-- Set the thumbs, blow R1 for a moment, let everything go: the pitch played
local function blowWith(M, state, buttons)
    H.hold(unpack(buttons))
    H.play(0.1)
    H.hold("R1"); H.play(0.1)
    local b = state.breath
    local v = state.voices[b.ev]
    local semis = b.ev.semis
    H.eq(v.targetSemis, semis, "the voice plays the breath's pitch")
    H.release("R1", unpack(buttons)); H.play(0.1)
    return semis
end

local function releaseAll()
    for btn in pairs(H.KEY) do H.release(btn) end
end

return {
    { "VALVES is a lab instrument on the Bass view, with its rows", function()
        local M, state, def, track = boot()
        H.truthy(def, "registered")
        H.truthy(def.lab, "marked lab")
        H.eq(def.viewKind, "bass", "the Bass's pitch trace")
        H.eq(def.HOME_GROUP, "LEAD", "lead sounds first")
        H.eq(def:getPatch(state).id, "lead_saw", "opens on SAW")
        local rows = M.Instruments:getSoundRows(def, state)
        local names = {}
        for i, r in ipairs(rows) do names[i] = r.label .. "=" .. r.value end
        H.eq(table.concat(names, " "), "PATCH=SAW VALVES=SCALE REGISTER=MID FOLLOW=ON", "rows")
        H.eq(def.VIEW.face.A, "-1", "the chart is on the screen")
        H.eq(def.VIEW.face.X, "-3", "X = 3 steps")
        H.truthy(def.eventClass ~= "mono", "Bass notes are not kept on a swap")
        H.eq(track.instrumentId, "valves", "on track 3")
    end },

    { "nothing sounds without a shoulder, whatever the thumbs do", function()
        local M, state, _, track = boot()
        H.tap("L2")
        for _, combo in ipairs({ { "UP" }, { "A" }, { "B", "A" }, { "DOWN", "RIGHT", "Y" },
                                 { "B", "A", "X", "Y" }, { "LEFT", "X" } }) do
            H.play(0.15, combo); H.play(0.05)
        end
        H.tap("L2")
        H.eq(#M.Synth.sustainVoices, 0, "no voice")
        H.eq(#track.events, 0, "nothing recorded")
        H.eq(state.breath, nil, "no breath")
    end },

    { "each D-pad direction gives its chord tone; the unused diagonals keep the last", function()
        local M, state = boot()
        local expect = { NEUTRAL = 0, DOWN = -5, LEFT = 4, UP = 7, RIGHT = 11, DOWN_RIGHT = 12 }
        local buttons = { NEUTRAL = {}, DOWN = { "DOWN" }, LEFT = { "LEFT" }, UP = { "UP" },
                          RIGHT = { "RIGHT" }, DOWN_RIGHT = { "DOWN", "RIGHT" } }
        for dir, semis in pairs(expect) do
            H.eq(blowWith(M, state, buttons[dir]), semis, dir .. " over C")
        end
        -- up, then up + left: still the fifth
        H.hold("UP"); H.play(0.1); H.hold("LEFT"); H.play(0.1)
        H.eq(state.tone, 2, "up-left keeps the fifth")
        H.hold("R1"); H.play(0.1)
        H.eq(state.breath.ev.semis, 7, "and plays it")
        releaseAll(); H.play(0.1)
        H.hold("LEFT"); H.play(0.1); H.release("LEFT"); H.hold("DOWN", "LEFT"); H.play(0.1)
        H.eq(state.tone, 1, "down-left keeps the third")
        releaseAll(); H.play(0.1)
    end },

    { "a chord change gives new open notes at the next breath; FOLLOW off stays on the tonic", function()
        local M, state, def = boot()
        H.hold("R1"); H.play(0.1)
        setChord(M, "RIGHT")                                   -- G
        H.play(0.1)
        H.eq(state.voices[state.breath.ev].targetSemis, 0, "the held breath keeps its chord")
        H.release("R1"); H.play(0.1)
        H.eq(blowWith(M, state, {}), -5, "root of G (below C)")
        H.eq(blowWith(M, state, { "LEFT" }), -1, "third of G")
        H.eq(blowWith(M, state, { "UP" }), 2, "fifth of G")
        def:cycleSetting(state, "FOLLOW", 1)
        H.falsy(state.follow, "FOLLOW off")
        H.eq(blowWith(M, state, { "LEFT" }), 4, "the tonic's third")
    end },

    { "each fingering on the chart lowers by its steps, in scale notes and in semitones", function()
        local M, state, def = boot()
        local chart = { {}, { "A" }, { "B" }, { "B", "A" }, { "A", "X" }, { "Y" }, { "B", "A", "X", "Y" } }
        local scale = { 0, -1, -3, -5, -7, -8, -10 }           -- C B A G F E D
        for i, btns in ipairs(chart) do
            H.eq(blowWith(M, state, btns), scale[i], "scale: " .. table.concat(btns, "+") .. " lowers " .. (i - 1))
        end
        H.eq(blowWith(M, state, { "X" }), blowWith(M, state, { "B", "A" }), "X equals A + B")
        H.eq(blowWith(M, state, { "UP", "Y" }), -1, "G lowered 5 scale notes: B")

        M.Instruments:cycleRow(def, state, 2, 1, M.Looper.tracks[3])   -- VALVES row
        H.eq(state.mode, "CHROMATIC", "CHROMATIC")
        for i, btns in ipairs(chart) do
            H.eq(blowWith(M, state, btns), -(i - 1), "chromatic: lowers " .. (i - 1) .. " semitones")
        end
        H.eq(blowWith(M, state, { "X" }), -3, "X: 3 semitones")
        H.truthy(state.breath.ev.chromatic, "the breath remembers it was chromatic")
    end },

    { "fingerings off the chart keep the last valve position", function()
        local M, state = boot()
        H.hold("B"); H.play(0.1)
        H.eq(state.steps, 2, "B")
        H.hold("Y"); H.play(0.1)
        H.eq(M.Input:getFingering().id, "YB", "Y + B down")
        H.eq(state.steps, 2, "Y + B keeps B's")
        H.release("Y"); H.hold("X"); H.play(0.1)
        H.eq(M.Input:getFingering().id, "OTHER", "an opposite pair")
        H.eq(state.steps, 2, "B + X keeps it")
        releaseAll(); H.play(0.1)
        H.hold("B", "A"); H.play(0.1); H.hold("X"); H.play(0.1)
        H.eq(state.steps, 3, "three buttons keep A + B's")
        H.hold("R1"); H.play(0.1)
        H.eq(state.breath.ev.semis, -5, "and play it")
        releaseAll(); H.play(0.1)
        H.hold("X"); H.play(0.1); H.hold("Y"); H.play(0.1)
        H.eq(M.Input:getFingering().id, "XY", "X + Y down")
        H.eq(state.steps, 3, "X + Y keeps X's")
        releaseAll(); H.play(0.1)
    end },

    { "a valve or D-pad change while blowing is a recorded slur on the same voice", function()
        local M, state, def, track = boot()
        H.tap("L2")
        H.hold("R1"); H.play(0.3)
        local voice = state.voices[state.breath.ev]
        H.hold("A"); H.play(0.2)                                -- a valve
        H.eq(#heldVoices(M), 1, "one voice")
        H.eq(state.voices[state.breath.ev], voice, "the same voice")
        H.eq(voice.targetSemis, -1, "down one scale note")
        H.eq(voice.glideRate, def.VALVE_GLIDE, "a valve glides fast")
        H.hold("UP"); H.play(0.2)                               -- the open note
        H.eq(voice.targetSemis, 5, "the fifth, one valve down: F")
        H.eq(voice.glideRate, def.TONE_GLIDE, "an open-note change glides slower")
        H.truthy(def.TONE_GLIDE < def.VALVE_GLIDE, "slower")
        releaseAll(); H.play(0.1)
        H.tap("L2")
        H.eq(#track.events, 1, "one breath, one event")
        local ev = track.events[1]
        H.eq(ev.action, "R1", "blown on R1")
        H.eq(ev.tone .. "/" .. ev.steps .. "/" .. ev.semis, "0/0/0", "the breath's own pitch")
        H.eq(#ev.bend, 2, "two slurs")
        H.eq(ev.bend[1].semis, -1, "first bend")
        H.eq(ev.bend[2].semis, 5, "second bend")
        H.eq(#ev.slur, 2, "with their tone and steps")
        H.eq(ev.slur[1].dt, ev.bend[1].dt, "same time")
        H.eq(ev.slur[1].tone .. "/" .. ev.slur[1].steps, "0/1", "valve 1")
        H.eq(ev.slur[2].tone .. "/" .. ev.slur[2].steps, "2/1", "fifth, valve 1")
        H.truthy(ev.bend[1].dt > 0, "after the start")
    end },

    { "a change inside the settle window rewrites the note and records no slur", function()
        local M, state, _, track = boot()
        H.tap("L2")
        H.hold("R1"); H.play(1 / 60)
        H.hold("A"); H.play(1 / 60)                              -- one frame late
        H.hold("B"); H.play(0.3)                                 -- and its pair, a frame later still
        local voice = state.voices[state.breath.ev]
        H.eq(voice.currentSemis, -5, "jumped to A + B straight away (no glide)")
        releaseAll(); H.play(0.1)
        H.tap("L2")
        local ev = track.events[1]
        H.eq(#track.events, 1, "one event")
        H.eq(ev.steps, 3, "recorded as A + B")
        H.eq(ev.semis, -5, "at its pitch")
        H.eq(ev.bend, nil, "no slur")
        H.eq(ev.slur, nil, "no slur data")

        -- a pair landing a frame apart in the middle of a breath slurs once, to the pair
        H.tap("L2")
        H.hold("R1"); H.play(0.3)
        H.hold("A"); H.play(1 / 60); H.hold("B"); H.play(0.2)
        releaseAll(); H.play(0.1)
        H.tap("L2")
        ev = track.events[2]
        H.eq(#ev.bend, 1, "one slur")
        H.eq(ev.bend[1].semis, -5, "straight to the pair")
    end },

    { "L1 while R1 is held re-attacks at 75 %; R1's release then does nothing", function()
        local M, state, def, track = boot()
        H.tap("L2")
        H.hold("R1"); H.play(0.2)
        local first = state.voices[state.breath.ev]
        H.near(first.vel, def.VEL, "R1 level")
        H.hold("L1"); H.play(0.2)
        local second = state.voices[state.breath.ev]
        H.truthy(second ~= first, "a new attack")
        H.near(second.vel, def.VEL * 0.75, "75 % of R1", 1e-6)
        H.truthy(first.releasedAt, "the first breath ended")
        H.eq(#heldVoices(M), 1, "mono")
        H.release("R1"); H.play(0.2)
        H.falsy(second.releasedAt, "letting go of R1 doesn't stop the note")
        H.release("L1"); H.play(0.1)
        H.truthy(second.releasedAt, "letting go of L1 does")
        H.tap("L2")
        H.eq(#track.events, 2, "two breaths")
        local r1, l1 = track.events[1], track.events[2]
        if r1.action ~= "R1" then r1, l1 = l1, r1 end
        H.eq(r1.action .. l1.action, "R1L1", "one per shoulder")
        H.eq(r1.len, (l1.tick - r1.tick) % M.Looper:getLoopTicks(), "R1 ends where L1 starts")
    end },

    { "alternating shoulders gives one event per breath, with no gaps", function()
        local M, state, _, track = boot()
        H.tap("L2")
        H.hold("R1"); H.play(0.1)
        H.hold("L1"); H.play(0.05); H.release("R1"); H.play(0.05)
        H.hold("R1"); H.play(0.05); H.release("L1"); H.play(0.05)
        H.hold("L1"); H.play(0.05); H.release("R1"); H.play(0.05)
        local soundingThroughout = #heldVoices(M) == 1
        H.release("L1"); H.play(0.1)
        H.tap("L2")
        H.truthy(soundingThroughout, "a note sounds the whole time")
        H.eq(#track.events, 4, "four breaths")
        local r1, l1 = M.Looper:countTrackAction(3, "R1"), M.Looper:countTrackAction(3, "L1")
        H.eq(r1 .. "/" .. l1, "2/2", "two on each shoulder")
    end },

    { "a recorded line replays its pitches; with FOLLOW on it moves with the chords, off it doesn't", function()
        local M, state, def, track = boot()
        H.tap("L2")
        H.hold("R1"); H.play(0.3)
        H.hold("A"); H.play(0.3)                                 -- slur down one valve
        releaseAll(); H.play(0.05)
        H.hold("LEFT"); H.play(0.1); H.hold("R1"); H.play(0.2)   -- the third
        releaseAll(); H.play(0.05)
        H.tap("L2")
        H.eq(#track.events, 2, "two breaths")

        -- each note's start pitch and its pitch near the end, on playback
        local function listen()
            local got = {}
            local orig = def.noteOn
            def.noteOn = function(self, ev, st, tr, isPb)
                orig(self, ev, st, tr, isPb)
                if isPb then got[#got + 1] = { ev = ev, base = st.playing[ev].base } end
            end
            local seen = {}
            for _ = 1, math.floor(M.Looper:getLoopDuration() * 60 + 30) do
                H.play(1 / 60)
                for ev, p in pairs(state.playing) do seen[ev] = p.semis end
            end
            def.noteOn = orig
            table.sort(got, function(a, b) return a.ev.tick < b.ev.tick end)
            local out = {}
            for _, g in ipairs(got) do
                if not out[g.ev] then
                    out[#out + 1] = g.base .. ">" .. tostring(seen[g.ev])
                    out[g.ev] = true
                end
            end
            return table.concat(out, " ")
        end

        H.eq(listen(), "0>-1 4>4", "the same pitches as played")
        setChord(M, "RIGHT")                                     -- G under the line
        H.eq(listen(), "-5>-7 -1>-1", "follows G: root G, a valve down F; third B")
        def:cycleSetting(state, "FOLLOW", 1)
        H.eq(listen(), "0>-1 4>4", "FOLLOW off: as recorded")
    end },

    { "REGISTER moves the breath an octave; rows save and load", function()
        local M, state, def, track = boot()
        H.eq(blowWith(M, state, {}), 0, "MID")
        def:cycleSetting(state, "REGISTER", 1)
        H.eq(state.register, "HIGH", "HIGH")
        H.eq(blowWith(M, state, {}), 12, "an octave up")
        def:cycleSetting(state, "REGISTER", 1)
        H.eq(blowWith(M, state, { "A" }), -13, "LOW, wrapped round")
        def:cycleSetting(state, "VALVES", 1)
        def:cycleSetting(state, "FOLLOW", 1)
        M.Instruments:cycleRow(def, state, 1, 1, track, true)    -- the next patch
        local patch = state.patch
        H.truthy(patch ~= "lead_saw", "another patch")

        -- a recorded slur
        H.tap("L2"); H.hold("R1"); H.play(0.2); H.hold("A"); H.play(0.2); releaseAll(); H.play(0.1); H.tap("L2")

        local snap = M.Session.snapshot()
        local text = M.Save.encode(snap)
        local ok = M.Session.restore(M.Save.decode(text))
        H.truthy(ok, "restored")
        local st = M.Looper.tracks[3].state
        H.eq(M.Looper.tracks[3].instrumentId, "valves", "still valves")
        H.truthy(st ~= state, "a fresh state")
        H.eq(st.mode, "CHROMATIC", "VALVES row")
        H.eq(st.register, "LOW", "REGISTER row")
        H.falsy(st.follow, "FOLLOW row")
        H.eq(st.patch, patch, "PATCH row")
        local ev = M.Looper.tracks[3].events[1]
        H.eq(ev.action, "R1", "the breath")
        H.eq(ev.octave, -1, "its register")
        H.truthy(ev.chromatic, "chromatic")
        H.eq(ev.slur[1].steps, 1, "slur data kept")
        H.eq(ev.bend[1].semis, -13, "bend kept")

        def:loadState(st, { valves = "WRONG", register = 7, follow = "yes", patch = "drum_kick" })
        H.eq(st.mode .. st.register, "CHROMATICLOW", "bad values ignored")
    end },

    { "erase clears by breath: B the R1 breaths, A the L1 breaths", function()
        local M, _, _, track = boot()
        local L = M.Looper
        L:beginRecordingTake()
        H.record(L, 3, "R1", 0.0, { tone = 0, steps = 0, semis = 0, len = 100 })
        H.record(L, 3, "R1", 0.25, { tone = 1, steps = 0, semis = 4, len = 100 })
        H.record(L, 3, "L1", 0.5, { tone = 2, steps = 0, semis = 7, len = 100 })
        H.eq(M.Instruments.byId.valves.LANES.R1, 1, "R1 on the top row")
        H.eq(M.Instruments.byId.valves.LANES.L1, 2, "L1 below")
        H.hold("L2", "R2"); H.play(0.1)
        H.tap("B")
        H.eq(L:countTrackAction(3, "R1"), 0, "R1 breaths cleared")
        H.eq(L:countTrackAction(3, "L1"), 1, "L1 kept")
        H.eq(L.toastText, "ERASED R1 BREATHS (2 HITS)", "toast")
        H.tap("A")
        H.eq(#track.events, 0, "L1 breaths cleared")
        H.release("L2", "R2"); H.play(0.1)
    end },

    { "the stage shows the note and the fingering", function()
        local M, state, def = boot()
        H.hold("UP", "A"); H.play(0.1)
        local big, small = def:getReadout(state)
        H.eq(big, "F", "the 5th one valve down, before blowing")
        H.truthy(small:find("5TH  -1 SCALE", 1, true), "the fingering: " .. small)
        H.truthy(small:find("BREATHE", 1, true), "not blowing")
        H.hold("R1"); H.play(0.1)
        big, small = def:getReadout(state)
        H.eq(big, "F", "sounding")
        H.truthy(small:find("BLOW", 1, true), "blowing")
        releaseAll(); H.play(0.1)
    end },
}
