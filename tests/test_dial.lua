-- DIAL (lab/DIAL.md): roll the thumb round the scale. Runs because "dial" is
-- a reserved lab id (tests/run.lua).
local H = require("helpers")

local FACE = { "B", "A", "X", "Y" }
-- The eight positions, clockwise from B, as the buttons held
local POS = {
    { "B" }, { "B", "A" }, { "A" }, { "A", "X" }, { "X" }, { "X", "Y" }, { "Y" }, { "Y", "B" },
}

local function boot()
    local M = H.loadMain()
    H.play(0.1)
    M.Instruments:swapTrackInstrument(2, "dial")
    M.Looper.activeTrack = 2
    H.play(0.05)
    local track = M.Looper.tracks[2]
    return M, track, M.Instruments.byId.dial
end

-- Count new voices (attacks) the instrument starts
local function countNoteOns(Synth)
    local n = { 0 }
    local orig = Synth.noteOn
    Synth.noteOn = function(self, ...)
        n[1] = n[1] + 1
        return orig(self, ...)
    end
    return n
end

-- Exactly these face buttons down (others up)
local function finger(btns)
    H.release("B", "A", "X", "Y")
    H.hold(unpack(btns or {}))
end

-- The live voice of the sounding note
local function liveVoice(state)
    return state.h and state.voices[state.h.ev]
end

local function rec() H.tap("L2") end

return {
    { "DIAL is a lab instrument drawn by the Bass view, with 1 3 5 7 on the buttons", function()
        local M = H.fresh()
        local def = M.Instruments.byId.dial
        H.truthy(def, "registered")
        H.truthy(def.lab, "lab")
        H.eq(def.viewKind, "bass", "pitch trace view")
        H.eq(def.VIEW.face.B .. def.VIEW.face.A .. def.VIEW.face.X .. def.VIEW.face.Y, "1357", "face labels")
        H.eq(def.HOME_GROUP .. " " .. def.DEFAULT_PATCH .. " " .. def.REGISTER .. " " .. def.VOICES,
            "LEAD lead_square 4 4", "sound")
        M.Config.LAB = false
        M.Instruments:buildCatalog()
        H.falsy(M.Instruments.byId.dial, "gone with the lab off")
    end },

    -- DL1 ---------------------------------------------------------------
    { "each of the eight positions gives its degree; lifting ends the note with its length", function()
        local M, track, def = boot()
        local L = M.Looper
        rec()
        for i, btns in ipairs(POS) do
            finger(btns); H.play(0.3)
            local v = liveVoice(track.state)
            H.truthy(v, "position " .. i .. " sounds")
            H.eq(track.state.h.ev.degree, i, "position " .. i .. " degree")
            H.eq(v.targetSemis, def:semisFor(i, 0, 0), "position " .. i .. " pitch")
            finger(); H.play(0.2)
            H.falsy(track.state.h, "lifted: no note")
        end
        rec()
        H.eq(#track.events, 8, "eight notes")
        table.sort(track.events, function(a, b) return a.degree < b.degree end)
        local actions = {}
        for i, ev in ipairs(track.events) do
            H.eq(ev.degree, i, "recorded degree")
            H.eq(ev.octave, 0, "home octave")
            H.eq(ev.bend, nil, "no slur")
            H.near(ev.len / L:getTicksPerSecond(), 0.3, "len = time held", 0.04)
            actions[#actions + 1] = ev.action
        end
        H.eq(table.concat(actions), "BBAAXXYY", "the button, or a pair's clockwise-first button")
    end },

    { "a pair arriving one frame apart plays and records the pair, with no bend", function()
        local M, track, def = boot()
        local ons = countNoteOns(M.Synth)
        rec()
        H.hold("B"); H.play(1 / 60)
        H.hold("A"); H.play(0.3)
        H.eq(liveVoice(track.state).currentSemis, def:semisFor(2, 0, 0), "the voice is on the pair's pitch")
        -- and a pair arriving two frames apart, the other way round
        finger(); H.play(0.2)
        H.hold("B"); H.play(2 / 60)
        H.hold("Y"); H.play(0.3)
        finger(); H.play(0.2)
        rec()
        H.eq(ons[1], 2, "one attack each")
        H.eq(#track.events, 2, "two notes")
        table.sort(track.events, function(a, b) return a.tick < b.tick end)
        local a, b = track.events[1], track.events[2]
        H.eq(a.degree .. a.action, "2B", "B+A")
        H.eq(a.semis, def:semisFor(2, 0, 0), "its pitch")
        H.eq(a.bend, nil, "a correction, not a slur")
        H.eq(b.degree .. b.action .. b.octave, "8Y0", "Y+B, no octave carry from the correction")
        H.eq(b.bend, nil, "no bend")
    end },

    -- DL2 ---------------------------------------------------------------
    { "a roll after the window is one note with bends, on one voice", function()
        local M, track, def = boot()
        local ons = countNoteOns(M.Synth)
        rec()
        for i = 1, 5 do finger(POS[i]); H.play(0.15) end
        finger(); H.play(0.2)
        rec()
        H.eq(ons[1], 1, "no new attack")
        H.eq(#track.events, 1, "one event")
        local ev = track.events[1]
        H.eq(ev.degree, 1, "starts on 1")
        H.eq(#ev.bend, 4, "four slurs")
        for i, kf in ipairs(ev.bend) do
            H.eq(kf.degree, i + 1, "slur " .. i)
            H.eq(kf.semis, def:semisFor(i + 1, 0, 0), "slur pitch " .. i)
        end
    end },

    { "clockwise across the seam carries the octave; anticlockwise undoes it; laps stop at the top", function()
        local _, track, def = boot()
        local s = track.state
        finger(POS[8]); H.play(0.15)
        local top = liveVoice(s).targetSemis
        finger(POS[1]); H.play(0.15)
        H.eq(s.octave, 1, "Y+B -> B: octave up")
        H.eq(liveVoice(s).targetSemis, top, "same pitch")
        finger(POS[2]); H.play(0.15)
        H.eq(liveVoice(s).targetSemis, def:semisFor(2, 1, 0), "then degree 2 of the higher octave")
        finger(POS[1]); H.play(0.15)
        finger(POS[8]); H.play(0.15)
        H.eq(s.octave, 0, "B -> Y+B: back down")
        H.eq(liveVoice(s).targetSemis, top, "on 8 again")
        -- a skipped pair still carries when the shortest way crosses the seam
        finger(POS[7]); H.play(0.15)
        finger(POS[1]); H.play(0.15)
        H.eq(s.octave, 1, "Y -> B (Y+B missed) still carries")
        finger(); H.play(0.1)

        -- laps from home: +1 a lap, up to the top octave
        finger({ "B", "A", "X", "Y" }); H.play(0.15); finger(); H.play(0.1)
        H.eq(s.octave, 0, "home")
        finger(POS[1]); H.play(0.15)
        local peak = -math.huge
        for lap = 1, 4 do
            for i = 2, 9 do
                finger(POS[(i - 1) % 8 + 1]); H.play(0.1)
                peak = math.max(peak, liveVoice(s).targetSemis)
            end
            if lap <= def.OCTAVE_MAX then H.eq(s.octave, lap, "lap " .. lap) end
        end
        H.eq(s.octave, def.OCTAVE_MAX, "capped")
        H.truthy(peak <= def:semisFor(8, def.OCTAVE_MAX, 0), "never above the top")
        finger(); H.play(0.1)
    end },

    { "all four returns home on degree 1; a shoulder sets the octave outright", function()
        local _, track, def = boot()
        local s = track.state
        finger(POS[8]); H.play(0.15); finger(POS[1]); H.play(0.15)
        H.eq(s.octave, 1, "carried up")
        finger(); H.play(0.1)
        finger(POS[3]); H.play(0.15)
        H.eq(liveVoice(s).targetSemis, def:semisFor(3, 1, 0), "a new note keeps the carried octave")
        finger({ "B", "A", "X", "Y" }); H.play(0.15)
        H.eq(s.octave, 0, "home")
        H.eq(liveVoice(s).targetSemis, def:semisFor(1, 0, 0), "degree 1 there")
        finger(); H.play(0.1)

        H.tap("L1")
        finger(POS[5]); H.play(0.15)
        H.eq(liveVoice(s).targetSemis, def:semisFor(5, -1, 0), "L1: octave -1")
        H.tap("R1")
        H.eq(liveVoice(s).targetSemis, def:semisFor(5, 1, 0), "R1 while sounding: +1, slurred")
        finger(); H.play(0.1)
        finger(POS[8]); H.play(0.15); finger(POS[1]); H.play(0.15)
        H.eq(s.octave, 2, "carried to +2")
        H.tap("R1")
        H.eq(s.octave, 1, "a shoulder replaces the carry")
        finger(); H.play(0.1)
    end },

    { "three buttons or an opposite pair change nothing", function()
        local M, track, def = boot()
        local ons = countNoteOns(M.Synth)
        rec()
        finger({ "B", "A" }); H.play(0.15)
        finger({ "B", "A", "X" }); H.play(0.15)
        H.eq(liveVoice(track.state).targetSemis, def:semisFor(2, 0, 0), "three buttons: still 2")
        finger({ "B", "X" }); H.play(0.15)
        H.eq(liveVoice(track.state).targetSemis, def:semisFor(2, 0, 0), "opposite pair: still 2")
        finger(); H.play(0.1)
        finger({ "A", "Y" }); H.play(0.15)
        H.falsy(track.state.h, "an opposite pair from nothing starts nothing")
        finger(); H.play(0.1)
        rec()
        H.eq(ons[1], 1, "one note")
        H.eq(#track.events, 1, "one event")
        H.eq(track.events[1].bend, nil, "no bend")
    end },

    -- DL3 ---------------------------------------------------------------
    { "LEFT / RIGHT shift a semitone; UP accents with vibrato; DOWN is soft", function()
        local _, track, def = boot()
        local s = track.state
        H.hold("RIGHT"); finger(POS[1]); H.play(0.15)
        H.eq(liveVoice(s).targetSemis, def:semisFor(1, 0, 0) + 1, "sharp")
        H.release("RIGHT"); H.hold("LEFT"); H.play(0.15)
        H.eq(liveVoice(s).targetSemis, def:semisFor(1, 0, 0) - 1, "flat while sounding")
        H.release("LEFT"); finger(); H.play(0.1)

        H.hold("UP"); finger(POS[3]); H.play(0.15)
        H.eq(s.h.ev.vel, def.VEL_ACCENT, "accent")
        H.truthy(liveVoice(s).vibrato, "vibrato")
        H.release("UP"); finger(); H.play(0.1)
        H.hold("DOWN"); finger(POS[3]); H.play(0.15)
        H.eq(s.h.ev.vel, def.VEL_SOFT, "soft")
        H.falsy(liveVoice(s).vibrato, "no vibrato")
        H.release("DOWN"); finger(); H.play(0.1)
        finger(POS[3]); H.play(0.15)
        H.eq(s.h.ev.vel, def.VEL_NORMAL, "plain")
        finger(); H.play(0.1)
    end },

    { "a recorded roll replays the same pitches at the same times", function()
        local M, track = boot()
        local L = M.Looper
        local function changes(sample)
            local out, last = {}, nil
            for _ = 1, math.floor(L:getLoopDuration() * 60) do
                H.play(1 / 60)
                local semis = sample()
                if semis and semis ~= last then out[#out + 1] = { t = H.time, semis = semis } end
                last = semis
            end
            return out
        end
        rec()
        local live, last = {}, nil
        for _, i in ipairs({ 1, 2, 3, 2, 1, 8, 1 }) do
            finger(POS[i])
            for _ = 1, 9 do
                H.play(1 / 60)
                local v = liveVoice(track.state)
                if v and v.targetSemis ~= last then live[#live + 1] = { t = H.time, semis = v.targetSemis } end
                last = v and v.targetSemis
            end
        end
        finger(); H.play(0.1)
        rec()
        H.eq(#track.events, 1, "one note")
        local ev = track.events[1]
        local played = changes(function()
            local p = track.state.playing[ev]
            return p and p.semis
        end)
        H.eq(#live, 5, "five pitches live (both seam crossings keep the pitch)")
        H.eq(#played, #live, "as many pitches")
        for i = 1, #live do
            H.eq(played[i].semis, live[i].semis, "pitch " .. i)
            if i > 1 then
                H.near(played[i].t - played[1].t, live[i].t - live[1].t, "time of change " .. i, 2.5 / 60)
            end
        end
    end },

    { "erase by face button clears a button's notes and its clockwise pair's", function()
        local M, track = boot()
        local L = M.Looper
        rec()
        for i = 1, 8 do finger(POS[i]); H.play(0.12); finger(); H.play(0.12) end
        rec()
        H.eq(#track.events, 8, "eight notes")
        H.hold("L2", "R2"); H.play(0.1)
        H.tap("B")
        H.release("L2", "R2"); H.play(0.1)
        H.eq(#track.events, 6, "two gone")
        for _, ev in ipairs(track.events) do
            H.truthy(ev.degree ~= 1 and ev.degree ~= 2, "1 and 2 cleared")
        end
        H.eq(L.toastText, "ERASED 1 + 2 (2 HITS)", "toast")
    end },

    { "rows are PATCH and GLIDE; they save and load", function()
        local M, track, def = boot()
        local rows = M.Instruments:getSoundRows(def, track.state)
        H.eq(#rows, 2, "two rows")
        H.eq(rows[1].label .. "=" .. rows[1].value, "PATCH=SQUARE", "patch")
        H.eq(rows[2].label .. "=" .. rows[2].value, "GLIDE=INSTANT", "glide")
        M.Instruments:cycleRow(def, track.state, 2, 1, track)
        H.eq(track.state.glide, "FAST", "INSTANT -> FAST")
        M.Instruments:cycleRow(def, track.state, 1, 1, track, true)
        local patch = track.state.patch
        H.truthy(patch ~= "lead_square", "patch stepped")

        local data = def:saveState(track.state)
        local fresh = def:newState()
        def:loadState(fresh, data)
        H.eq(fresh.patch, patch, "patch loads")
        H.eq(fresh.glide, "FAST", "glide loads")
        def:loadState(fresh, { glide = "NOPE", patch = "no_such" })
        H.eq(fresh.glide, "FAST", "bad glide ignored")
        H.eq(fresh.patch, patch, "bad patch ignored")
    end },

    { "the stage words degree and octave; a page taking the note waits for a lift", function()
        local _, track, def = boot()
        local s = track.state
        finger(POS[8]); H.play(0.15); finger(POS[1]); H.play(0.15)
        local _, small = def:getReadout(s)
        H.eq(small, "DEG 1  -  OCT +1  -  PLAIN", "readout")
        H.hold("SELECT"); H.play(0.3)
        H.falsy(s.h and s.h:isHeld(), "the page ended the note")
        H.release("SELECT"); H.play(0.2)
        H.falsy(s.h, "no note restarts with the thumb still down")
        finger(); H.play(0.1)
        finger(POS[3]); H.play(0.1)
        H.truthy(s.h, "the next press plays")
        finger(); H.play(0.1)
    end },
}
