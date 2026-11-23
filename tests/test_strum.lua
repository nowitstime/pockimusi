-- STRUM (lab/STRUM.md): choose the notes with the thumbs, pluck with the
-- shoulders. Runs because "strum" is a reserved lab id (tests/run.lua).
local H = require("helpers")

local FRAME = 1 / 60

-- The real game, track 3 playing Strum
local function boot()
    local M = H.loadMain()
    M.Modes = require("src.modes")
    H.play(0.1)
    M.Instruments:swapTrackInstrument(3, "strum")
    M.Looper.activeTrack = 3
    local track = M.Looper.tracks[3]
    return M, track.state, M.Instruments.byId.strum, track
end

-- Every note Strum starts from now on: { semis, vel, at, voice }
local function capture(S)
    local got = {}
    local orig = S.noteOn
    S.noteOn = function(self, id, semis, vel, opts)
        local v = orig(self, id, semis, vel, opts)
        got[#got + 1] = { semis = semis, vel = vel, at = S.clock, voice = v }
        return v
    end
    return got
end

local function clear(t) for i = #t, 1, -1 do t[i] = nil end end

local function semisOf(got)
    local out = {}
    for i, g in ipairs(got) do out[i] = g.semis end
    return table.concat(out, " ")
end

-- A stroke with `buttons` held (face buttons and D-pad), then let go
local function strum(shoulder, buttons)
    H.hold(table.unpack(buttons or {}))
    H.play(FRAME)
    H.hold(shoulder); H.play(0.15); H.release(shoulder)
    H.release(table.unpack(buttons or {}))
    H.play(0.05)
end

-- Voices of `track` still sounding and not released
local function heldVoices(S, track)
    local n = 0
    for _, v in ipairs(S.sustainVoices) do
        if v.track == track and v.alive and not v.releasedAt then n = n + 1 end
    end
    return n
end

table.unpack = table.unpack or unpack

return {
    { "the view: strings by name, held ones lit, a struck one rings, the pattern marks strokes", function()
        local M, state, def, track = boot()
        state.follow = false
        H.tap("L2")
        H.hold("UP", "B", "A"); H.play(0.05)        -- degree 5 (G) with the 3rd and 5th held
        local v = def:getView(state, track)
        H.eq(v.name, "G", "the root")
        local labels, notes = {}, {}
        for i, s in ipairs(v.strings) do labels[i] = s.label; notes[i] = s.note end
        H.eq(table.concat(labels, " "), "8VE 7TH 5TH 3RD ROOT", "high to low")
        H.eq(table.concat(notes, " "), "G F D B G", "their notes")
        H.truthy(v.strings[4].held and v.strings[3].held, "3rd and 5th held")
        H.falsy(v.strings[2].held, "7th not")
        H.hold("R1"); H.play(0.05); H.release("R1"); H.play(0.05)
        H.release("UP", "B", "A"); H.tap("L2")
        v = def:getView(state, track)
        H.truthy(v.strings[5].energy > 0.5, "the root rings")
        H.truthy(v.strings[4].energy > 0.5, "the 3rd rings")
        H.eq(v.strings[2].energy, 0, "the 7th wasn't struck")
        H.truthy(v.pick and v.pick.down, "the pick swept down")
        H.eq(#v.marks, 1, "one stroke in the pattern")
        H.truthy(v.marks[1].down, "a downstroke")
        H.play(2.0)
        H.truthy(def:getView(state, track).strings[5].energy < 0.1, "and fades")
    end },

    { "STRUM is a lab instrument on the plucked sounds, with lanes, erase map and view", function()
        local M = H.fresh()
        local def = M.Instruments.byId.strum
        H.truthy(def, "registered")
        H.falsy(def.dev, "an ordinary instrument")
        H.eq(def.viewKind, "strum", "its own view")
        H.eq(def.HOME_GROUP, "PLUCK", "plucked sounds first")
        H.eq(def.DEFAULT_PATCH, "pluck_nylon", "opens on NYLON")
        H.eq(def.VOICES, 10, "ten voices")
        H.eq(def.LANES.R1, 1, "downstrokes on the top row")
        H.eq(def.LANES.L1, 2, "upstrokes on the next")
        local Chrome = require("src.ui.chrome")
        H.eq(Chrome:eventRow(def, { action = "L1", len = 0 }), Chrome.LANE_ROW[2], "an upstroke sits on its row")
        H.eq(def.VIEW.both, "DAMP", "both shoulders read DAMP")
    end },

    { "no face button = one note at the D-pad's degree; each button adds its step; all four add four", function()
        local M, state = boot()
        local T = M.Theory
        state.follow = false
        H.eq(M.Synth.patches[require("src.instruments.patches").list(M.Instruments.byId.strum)[1]].group,
            "PLUCK", "the PLUCK group leads the patch list")
        local got = capture(M.Synth)
        local function scale(d, o) return T:getScaleDegreeSemis(d) + 12 * (o or 0) end

        strum("R1")
        H.eq(semisOf(got), tostring(scale(1)), "a single root note")
        clear(got); strum("R1", { "UP" })
        H.eq(semisOf(got), tostring(scale(5)), "UP = the 5th degree")

        local cases = { { "B", 3 }, { "A", 5 }, { "Y", 7 }, { "X", 8 } }
        for _, c in ipairs(cases) do
            clear(got); strum("R1", { c[1] })
            H.eq(semisOf(got), scale(1) .. " " .. scale(c[2]), c[1] .. " adds its string")
        end
        clear(got); strum("R1", { "B", "A", "Y", "X" })
        H.eq(semisOf(got), table.concat({ scale(1), scale(3), scale(5), scale(7), scale(8) }, " "), "all four strings")

        -- strings are scale steps above the degree, in the register's octave
        state.register = "HIGH"
        clear(got); strum("R1", { "LEFT", "B", "A" })
        H.eq(semisOf(got), table.concat({ scale(3, 1), scale(5, 1), scale(7, 1) }, " "), "3rd degree, triad, an octave up")
        H.eq(state.live and next(state.live) ~= nil, true, "the stroke is tracked while it rings")
    end },

    { "R1 plays low to high, L1 high to low, the row's spread apart, the first at once", function()
        local M, state = boot()
        state.follow = false
        local got = capture(M.Synth)
        for _, spread in ipairs({ "TIGHT", "LOOSE" }) do
            state.strum = spread
            local gap = M.Instruments.byId.strum.STRUM_GAPS[spread]
            for _, dir in ipairs({ "R1", "L1" }) do
                clear(got)
                H.hold("B", "A", "X"); H.play(FRAME)
                local before = M.Synth.clock
                H.hold(dir); H.play(FRAME)
                local pressedAt = M.Synth.clock
                H.play(0.2); H.release(dir, "B", "A", "X"); H.play(0.05)
                H.eq(#got, 4, dir .. " " .. spread .. ": four strings")
                H.truthy(got[1].at > before - 1e-9 and got[1].at <= pressedAt + 1e-9, "the first at once")
                for i = 2, 4 do
                    local d = got[i].at - got[1].at
                    H.truthy(d >= (i - 1) * gap - 1e-6 and d <= (i - 1) * gap + FRAME + 1e-6,
                        string.format("%s %s string %d at %.3f s", dir, spread, i, d))
                    if dir == "R1" then
                        H.truthy(got[i].semis > got[i - 1].semis, "downstroke climbs")
                    else
                        H.truthy(got[i].semis < got[i - 1].semis, "upstroke falls")
                    end
                end
            end
        end
    end },

    { "a stroke's strings share one level", function()
        local M, state, def = boot()
        local got = capture(M.Synth)
        strum("R1")
        H.near(got[1].vel, def.VEL, "a single note at the full level")
        clear(got); strum("R1", { "B", "A", "X" })
        H.eq(#got, 4, "four notes")
        for i = 1, 4 do H.near(got[i].vel, def.VEL / 2, "string " .. i .. ": the level shared") end
    end },

    { "a second shoulder inside the window damps the track and removes the stroke", function()
        local M, state, def, track = boot()
        local S = M.Synth
        H.tap("L2")                                    -- record
        strum("R1", { "B", "A" })
        H.eq(#track.events, 1, "the first stroke is recorded")
        H.eq(track.events[1].len, 0, "a ringing patch records a hit")
        H.eq(table.concat(track.events[1].stack, " "), "2 4", "its strings, as steps")
        H.play(0.3)
        H.hold("A"); H.play(FRAME)
        H.hold("R1"); H.play(FRAME)
        H.eq(#track.events, 2, "the second stroke is recorded at once")
        H.hold("L1"); H.play(FRAME)                    -- one frame later: a damp
        H.eq(#track.events, 1, "the stroke that just started is withdrawn")
        H.eq(track.events[1].stack[1], 2, "the first stroke stays")
        H.eq(heldVoices(S, track), 0, "every voice on the track is stopped")
        H.play(0.1)
        local alive = 0
        for _, v in ipairs(S.sustainVoices) do if v.track == track and v.alive then alive = alive + 1 end end
        H.eq(alive, 0, "and silent soon after")
        H.truthy(state.damped, "the view says so")
        H.eq(select(2, def:getReadout(state)), "DAMPED", "small line")
        H.release("R1", "L1", "A"); H.play(0.05)

        -- both shoulders in the same frame: a damp, nothing recorded
        local got = capture(S)
        H.play(0.1, { "R1", "L1" }); H.play(0.05)
        H.eq(#got, 0, "no stroke")
        H.eq(#track.events, 1, "nothing recorded")
        H.tap("L2")
    end },

    { "outside the window the second shoulder is the next stroke and nothing is cut", function()
        local M, state, _, track = boot()
        local S = M.Synth
        local got = capture(S)
        H.tap("L2")
        H.hold("B"); H.play(FRAME)
        H.hold("R1"); H.play(4 * FRAME)                -- 67 ms
        H.hold("UP")                                   -- other strings, so none restarts
        H.hold("L1"); H.play(4 * FRAME)
        H.eq(#got, 4, "two strokes of two strings")
        for _, g in ipairs(got) do H.falsy(g.voice.releasedAt, "nothing damped") end
        H.release("UP")
        H.falsy(state.damped, "not a damp")
        H.release("R1", "L1", "B"); H.play(0.05)
        H.tap("L2")
        H.eq(#track.events, 2, "both strokes recorded")
        -- a string plucked again restarts: the old voice of that pitch lets go
        clear(got)
        strum("R1"); H.play(0.2); strum("R1")
        H.eq(#got, 2, "the root twice")
        H.truthy(got[1].voice.releasedAt or not got[1].voice.alive, "the first pluck stops")
        H.truthy(got[2].voice.alive and not got[2].voice.releasedAt, "the new one rings")
        H.eq(track.events[1].action, "R1", "down")
        H.eq(track.events[2].action, "L1", "then up")
        H.truthy(track.events[2].strum < 0, "the upstroke's spread is negative")
    end },

    { "a sustaining patch records the held length and ends on release", function()
        local M, state, _, track = boot()
        local S = M.Synth
        state.patch = "bass_saw"
        H.truthy(S.patches.bass_saw.sustains, "a sustaining patch")
        H.tap("L2")
        H.hold("A"); H.play(FRAME)
        H.hold("R1"); H.play(0.5)
        H.eq(heldVoices(S, track), 2, "root and fifth sound while R1 is held")
        H.release("R1", "A"); H.play(0.05)
        H.eq(heldVoices(S, track), 0, "released with the shoulder")
        H.tap("L2")
        H.eq(#track.events, 1, "one stroke")
        H.near(track.events[1].len / M.Looper:getTicksPerSecond(), 0.5, "len = time held", 0.05)
    end },

    { "bowed: a D-pad move glides every string and records one bend", function()
        local M, state, _, track = boot()
        local S, T = M.Synth, M.Theory
        state.patch = "bass_saw"
        state.follow = false
        local got = capture(S)
        H.tap("L2")
        H.hold("B"); H.play(FRAME)
        H.hold("R1"); H.play(0.2)
        H.eq(#got, 2, "root and third")
        H.hold("UP"); H.play(0.2)
        local root, third = got[1].voice, got[2].voice
        H.eq(root.targetSemis, T:getScaleDegreeSemis(5), "the root glides to the 5th degree")
        H.eq(third.targetSemis, T:getScaleDegreeSemis(5) + T:getScaleDegreeSemis(3) - T:getScaleDegreeSemis(1),
            "the third moves by the same interval")
        H.eq(#got, 2, "no new attack")
        H.release("R1", "B", "UP"); H.play(0.05)
        H.tap("L2")
        local ev = track.events[1]
        H.eq(#ev.bend, 1, "one bend")
        H.eq(ev.bend[1].degree, 5, "to degree 5")

        -- the other shoulder starts a new bow stroke
        clear(got)
        H.hold("R1"); H.play(0.2)
        H.hold("L1"); H.play(0.2)
        H.eq(#got, 2, "two bow strokes")
        H.truthy(got[1].voice.releasedAt, "the downbow ends")
        H.falsy(got[2].voice.releasedAt, "the upbow sounds")
        H.release("R1", "L1"); H.play(0.05)
    end },

    { "playback over a changed chord moves root and strings with FOLLOW on, not with it off", function()
        local M, state, def, track = boot()
        local T, S = M.Theory, M.Synth
        local V = T:getChordForDirection("RIGHT", false, false)
        H.setChord(V)                                         -- track C's chord is now V
        local root = T:getScaleDegreeSemis(1)
        local ev = { action = "R1", tick = 0, degree = 1, octave = 0, semis = root, stack = { 2, 4 },
                     strum = 0.012, vel = 0.85, len = 0 }
        local got = capture(S)

        state.follow = true
        def:noteOn(ev, state, track, true); H.play(0.1)
        local want = { T:getChordDegreeSemis(V, 1), T:getChordDegreeSemis(V, 3), T:getChordDegreeSemis(V, 5) }
        table.sort(want)
        H.eq(semisOf(got), table.concat(want, " "), "re-harmonised over V")

        clear(got)
        state.follow = false
        def:noteOn(ev, state, track, true); H.play(0.1)
        H.eq(semisOf(got), table.concat({ root, T:getScaleDegreeSemis(3), T:getScaleDegreeSemis(5) }, " "),
            "as played")
    end },

    { "rows step, save and load; erase clears by direction", function()
        local M, state, def, track = boot()
        local L = M.Looper
        local rows = M.Instruments:getSoundRows(def, state)
        local labels = {}
        for i = 1, 4 do labels[i] = rows[i].label .. "=" .. rows[i].value end
        H.eq(table.concat(labels, " "), "PATCH=NYLON REGISTER=MID STRUM=TIGHT FOLLOW=ON", "the rows")
        def:cycleSetting(state, "REGISTER", 1)
        def:cycleSetting(state, "STRUM", 1)
        def:cycleSetting(state, "FOLLOW", 1)
        H.eq(state.register .. " " .. state.strum .. " " .. tostring(state.follow), "HIGH LOOSE false", "stepped")
        state.patch = "pluck_rhodes"

        H.record(L, 3, "R1", 0.0, { degree = 3, octave = 1, semis = 16, stack = { 2, 7 }, strum = 0.03 })
        H.record(L, 3, "L1", 0.25, { degree = 1, octave = 0, semis = 0, stack = {}, strum = -0.012 })
        H.record(L, 3, "R1", 0.5, { degree = 5, octave = 0, semis = 7, stack = { 4 }, strum = 0.012 })
        local snap = M.Session.snapshot()
        M.Looper:setTrackInstrument(3, "bass", M.Instruments)
        H.truthy(M.Session.restore(snap), "restored")
        local t3 = L.tracks[3]
        H.eq(t3.instrumentId, "strum", "back on Strum")
        local s = t3.state
        H.eq(s.register .. " " .. s.strum .. " " .. tostring(s.follow) .. " " .. s.patch,
            "HIGH LOOSE false pluck_rhodes", "rows kept")
        H.eq(#t3.events, 3, "strokes kept")
        H.eq(table.concat(t3.events[1].stack, " "), "2 7", "strings kept")
        H.near(t3.events[2].strum, -0.012, "spread kept")

        def:loadState(s, { register = "LOUD", strum = 7, follow = "yes", patch = "no_such" })
        H.eq(s.register .. " " .. s.strum .. " " .. s.patch, "HIGH LOOSE pluck_rhodes", "bad values ignored")

        -- a damaged stack still plays
        H.eq(table.concat(def:stackOf({ stack = { 7, "x", 2, 2, 99, 4.5 } }), " "), "2 7", "checked")

        local actions, label = M.Modes:eraseTarget(def, s, "B")
        L:clearTrackAction(3, actions, label)
        H.eq(#t3.events, 1, "downstrokes erased")
        H.eq(t3.events[1].action, "L1", "the upstroke stays")
        H.eq(L.toastText, "ERASED DOWNSTROKES (2 HITS)", "toast")
        H.eq(M.Modes:eraseTarget(def, s, "Y"), nil, "Y clears nothing")
        actions, label = M.Modes:eraseTarget(def, s, "A")
        L:clearTrackAction(3, actions, label)
        H.eq(#t3.events, 0, "upstrokes erased")
    end },

    { "the lab view names the degree, the strings held and the last direction", function()
        local M, state, def = boot()
        H.hold("LEFT", "A", "X"); H.play(FRAME)
        local big, small, lines = def:getReadout(state)
        H.eq(big, "3  +  5TH  8VE", "degree and strings")
        H.hold("L1"); H.play(0.1); H.release("L1"); H.play(FRAME)
        big, small, lines = def:getReadout(state)
        H.eq(small, "UPSTROKE", "the last stroke")
        H.truthy(#lines <= require("src.ui.chrome").LAB_LINES, "the lines fit")
        H.release("LEFT", "A", "X"); H.play(FRAME)
        H.eq((def:getReadout(state)), "1", "just the root")
        H.play(0.2)                                     -- draws every frame without error
    end },
}
