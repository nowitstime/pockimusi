-- SLIDE (lab/SLIDE.md): steer the pitch instead of choosing it. This file
-- runs because "slide" is a reserved lab id (tests/run.lua).
local H = require("helpers")

local function boot()
    local M = H.loadMain()
    H.play(0.1)
    M.Instruments:swapTrackInstrument(3, "slide")
    M.Looper.activeTrack = 3
    local track = M.Looper.tracks[3]
    return M, track.state, M.Instruments.byId.slide, track
end

local function setPitch(st, p)
    st.pitch, st.travel, st.settle = p, p, nil
end

local function onTrackPage(fn)
    H.hold("SELECT"); H.play(0.3)
    fn()
    H.release("SELECT"); H.play(0.1)
end

local function isScaleNote(def, p)
    return math.abs(p - def:nearestNote(p)) < 1e-9
end

-- The live voice of the newest held note
local function liveVoice(st)
    local h = st.handles[#st.handles]
    return h and st.voices[h.ev]
end

-- The newest playback entry (a recorded note sounding)
local function playEntry(st)
    for _, p in pairs(st.playing) do return p end
end

return {
    { "FOLLOW: steps and snapping land on the chord's notes; saves", function()
        local M, st, def, track = boot()
        local L = M.Looper
        M.Instruments:swapTrackInstrument(1, "chords")
        local ct = L.tracks[1]
        M.Instruments.byId.chords:stamp(ct.state, ct)        -- C G Am F, a half bar each
        L.activeTrack = 3
        L:setPlaying(false); L:seek(0.3); H.play(0.05)       -- under G
        H.eq(def:nearestNote(5, st), 5, "off: F is a scale note")
        setPitch(st, 2); H.tap("RIGHT")
        H.eq(st.pitch, 4, "off: D steps to E")
        def:cycleSetting(st, "FOLLOW", 1)
        H.eq(def:nearestNote(5, st), 7, "on: F snaps to G (G B D)")
        setPitch(st, 2); H.tap("RIGHT")
        H.eq(st.pitch, 7, "on: D steps to G")
        H.tap("RIGHT")
        H.eq(st.pitch, 11, "then B")
        local fresh = def:newState()
        def:loadState(fresh, def:saveState(st))
        H.truthy(fresh.follow, "follow saves")
    end },

    { "SLIDE is an instrument on the Bass view with PATCH, SPEED and SNAP rows", function()
        local M, st, def = boot()
        H.truthy(def, "registered")
        H.falsy(def.lab, "an ordinary instrument")
        H.eq(def.viewKind, "bass", "drawn by the Bass view")
        local rows = M.Instruments:getSoundRows(def, st)
        H.eq(#rows, 4, "four rows")
        H.eq(rows[4].label .. "=" .. rows[4].value, "FOLLOW=OFF", "follow, off by default")
        H.eq(rows[1].label .. "=" .. rows[1].value, "PATCH=SQUARE", "opens on SQUARE")
        H.eq(rows[2].label .. "=" .. rows[2].value, "SPEED=MEDIUM", "speed")
        H.eq(rows[3].label .. "=" .. rows[3].value, "SNAP=SOFT", "snap defaults to SOFT")
        H.eq(rows[2].kind, "setting", "a setting row")
        H.eq(M.Synth.patches[require("src.instruments.patches").list(def)[1]].group, "LEAD", "LEAD sounds first")
    end },

    { "holding UP raises the pitch by the row's speed and it stays; a shoulder is four times faster; it stops at the ends", function()
        local _, st, def = boot()
        st.snap = "OFF"
        H.hold("UP"); H.play(1.0); H.release("UP"); H.play(0.3)
        H.near(st.pitch, 8.0, "MEDIUM: 8 semitones in a second", 0.05)
        st.speed = "SLOW"
        setPitch(st, 0)
        H.hold("DOWN"); H.play(1.0); H.release("DOWN"); H.play(0.3)
        H.near(st.pitch, -4.0, "SLOW: 4 down in a second", 0.05)

        -- a shoulder pressed while sliding: faster, and no octave jump
        setPitch(st, 0)
        H.hold("UP"); H.play(1 / 60)
        H.hold("R1"); H.play(0.5)
        H.release("UP"); H.play(1 / 60); H.release("R1"); H.play(0.1)
        H.near(st.pitch, 4 / 60 + 4 * 4 * 0.5, "four times as far", 0.1)

        st.speed = "FAST"
        setPitch(st, 0)
        H.hold("UP"); H.play(4.0); H.release("UP"); H.play(0.1)
        H.near(st.pitch, def.RANGE, "stops two octaves up", 1e-9)
        H.hold("DOWN"); H.play(6.0); H.release("DOWN"); H.play(0.1)
        H.near(st.pitch, -def.RANGE, "stops two octaves down", 1e-9)
    end },

    { "LEFT / RIGHT land exactly on the neighbouring scale notes", function()
        local _, st = boot()
        st.snap = "OFF"
        H.tap("RIGHT"); H.eq(st.pitch, 2, "C -> D")
        H.tap("RIGHT"); H.eq(st.pitch, 4, "D -> E")
        H.tap("RIGHT"); H.eq(st.pitch, 5, "E -> F")
        H.tap("LEFT");  H.eq(st.pitch, 4, "F -> E")
        setPitch(st, 2.5)
        H.tap("RIGHT"); H.eq(st.pitch, 4, "between D and E -> E")
        setPitch(st, 2.5)
        H.tap("LEFT"); H.eq(st.pitch, 2, "between D and E -> D")
        setPitch(st, -0.3)
        H.tap("RIGHT"); H.eq(st.pitch, 0, "just under the root -> the root")
    end },

    { "a shoulder alone moves an octave; both shoulders return to the root", function()
        local _, st = boot()
        st.snap = "OFF"
        setPitch(st, 2)
        H.tap("R1"); H.eq(st.pitch, 14, "an octave up")
        H.tap("L1"); H.tap("L1"); H.eq(st.pitch, -10, "two octaves down")
        setPitch(st, 7.3)
        H.tap("L1", "R1"); H.eq(st.pitch, 0, "both together: the root")
        setPitch(st, 7.3)
        H.hold("L1"); H.play(0.1); H.hold("R1"); H.play(0.1); H.release("L1", "R1"); H.play(0.1)
        H.eq(st.pitch, 0, "one after the other: the root")
        setPitch(st, 20)
        H.tap("R1"); H.eq(st.pitch, 20, "an octave that would leave the range does nothing")
    end },

    { "a slide while holding records thinned bends ending on the stopping pitch; playback follows it", function()
        local M, st, def, track = boot()
        local L = M.Looper
        st.snap = "OFF"
        H.tap("L2")
        H.hold("B"); H.play(1 / 60)
        local v = liveVoice(st)
        local live = { v.targetSemis }
        local function frames(n)
            for _ = 1, n do H.play(1 / 60); live[#live + 1] = v.targetSemis end
        end
        frames(12)
        H.hold("UP"); frames(54)
        H.release("UP"); frames(20)
        H.release("B"); H.play(0.05); H.tap("L2")
        local final = M.Theory:getRootSemis() + st.pitch
        H.near(live[#live], final, "the live voice ended on the pitch")

        H.eq(#track.events, 1, "one note")
        local ev = track.events[1]
        H.truthy(ev.bend and #ev.bend >= 10, "bends recorded")
        for i = 2, #ev.bend - 1 do
            H.truthy(ev.bend[i].dt - ev.bend[i - 1].dt >= def.KF_SPACING,
                "keyframes at least 30 ticks apart (" .. i .. ")")
        end
        local last = ev.bend[#ev.bend]
        H.eq(last.semis, final, "the last keyframe is the exact stopping pitch")
        H.eq(last.degree, nil, "no degree")
        local ticksHeld = 0.9 * L:getTicksPerSecond()
        H.truthy(#ev.bend <= ticksHeld / def.KF_SPACING + 2, "thinned: no more than one per 30 ticks")

        -- playback follows the same curve
        local played, started = {}, false
        for _ = 1, math.floor(L:getLoopDuration() * 60) + 10 do
            H.play(1 / 60)
            local p = playEntry(st)
            if p and not started then started = p end
            if started then
                if p ~= started or #played >= #live then break end
                played[#played + 1] = p.voice.targetSemis
            end
        end
        H.truthy(#played >= #live - 2, "the whole note played back")
        local worst = 0
        for i = 1, math.min(#played, #live) do
            worst = math.max(worst, math.abs(played[i] - live[i]))
        end
        H.truthy(worst < 0.5, "playback within half a semitone of the live curve (" .. worst .. ")")
        H.near(played[#played], final, "playback ends on the same pitch")
    end },

    { "SNAP: SOFT eases onto a scale note, OFF stays, HARD never rests between notes, A settles with OFF", function()
        local _, st, def = boot()
        H.hold("UP"); H.play(0.3); H.release("UP"); H.play(1 / 60)
        H.falsy(isScaleNote(def, st.pitch), "SOFT: still between notes just after letting go")
        H.play(0.4)
        H.truthy(isScaleNote(def, st.pitch), "SOFT: on a scale note")
        H.near(st.pitch, 2, "the nearest one", 1e-9)

        st.snap = "OFF"
        setPitch(st, 0)
        H.hold("UP"); H.play(0.3); H.release("UP"); H.play(0.5)
        H.near(st.pitch, 2.4, "OFF: stays where it was left", 0.05)

        st.snap = "HARD"
        setPitch(st, 0)
        H.hold("UP")
        local moved = 0
        for _ = 1, 60 do
            H.play(1 / 60)
            H.truthy(isScaleNote(def, st.pitch), "HARD: always on a scale note")
            if st.pitch ~= 0 then moved = moved + 1 end
        end
        H.release("UP"); H.play(0.1)
        H.truthy(moved > 0 and st.pitch >= 7, "HARD still moves (" .. st.pitch .. ")")

        st.snap = "OFF"
        setPitch(st, 0)
        H.hold("A"); H.play(0.05)
        H.hold("UP"); H.play(0.3); H.release("UP"); H.play(0.5)
        H.truthy(isScaleNote(def, st.pitch), "A settles with SNAP off")
        H.release("A"); H.play(0.1)

        setPitch(st, 3.3)
        H.tap("A"); H.play(0.4)
        H.eq(st.pitch, 4, "an A pressed between notes eases onto the nearest")
    end },

    { "Y dives on release, live and on playback; the next note starts from the pitch before the dive", function()
        local M, st, def, track = boot()
        local L = M.Looper
        st.snap = "OFF"
        setPitch(st, 5)
        local start = M.Theory:getRootSemis() + 5
        H.tap("L2")
        H.hold("Y"); H.play(0.2)
        local v = liveVoice(st)
        H.near(v.targetSemis, start, "sounds at the pitch")
        H.release("Y"); H.play(0.05); H.tap("L2")
        local lowest = v.targetSemis
        for _ = 1, 40 do
            H.play(1 / 60)
            lowest = math.min(lowest, v.targetSemis)
        end
        H.truthy(lowest < start - 9, "the voice fell towards an octave below (" .. lowest .. ")")
        H.eq(st.pitch, 5, "the track's pitch did not move")
        H.eq(#track.events, 1, "recorded")
        H.eq(track.events[1].bend, nil, "the dive is not recorded as bends")

        H.hold("B"); H.play(0.1)
        H.near(liveVoice(st).targetSemis, start, "the next note starts from the pitch before the dive")
        H.release("B"); H.play(0.3)

        -- playback: the recorded Y note dives when it ends
        local entry, low = nil, nil
        for _ = 1, math.floor(L:getLoopDuration() * 60) + 10 do
            H.play(1 / 60)
            local p = playEntry(st)
            if p then entry = entry or p end
            if entry then
                low = math.min(low or entry.voice.targetSemis, entry.voice.targetSemis)
                if not entry.voice:isSounding() then break end
            end
        end
        H.truthy(entry, "played back")
        H.truthy(low < start - 6, "and dived on playback (" .. tostring(low) .. ")")
    end },

    { "the stage shows the nearest scale note, with + or - between notes, even when silent", function()
        local _, st, def = boot()
        setPitch(st, 2)
        H.eq((def:getReadout(st)), "D", "on D")
        setPitch(st, 2.4)
        local big, small = def:getReadout(st)
        H.eq(big, "D+", "above D")
        H.truthy(small:find("DEG 2+", 1, true), "degree with + (" .. small .. ")")
        H.truthy(small:find("READY", 1, true), "silent")
        setPitch(st, 1.7)
        H.eq((def:getReadout(st)), "D-", "below D")
        setPitch(st, -12)
        H.eq((def:getReadout(st)), "C", "an octave down")
        H.play(0.1)                                       -- the view draws
    end },

    { "rows and the pitch save and load", function()
        local M, st = boot()
        local L = M.Looper
        onTrackPage(function()
            H.tap("RIGHT")                                -- PATCH
            H.tap("DOWN"); H.tap("RIGHT")                 -- SPEED: FAST
            H.tap("DOWN"); H.tap("LEFT")                  -- SNAP: OFF
        end)
        H.eq(st.speed, "FAST", "speed")
        H.eq(st.snap, "OFF", "snap")
        local patch = st.patch
        H.truthy(patch ~= "lead_square", "patch changed")
        setPitch(st, 3.75)
        local data = assert(M.Save.decode(M.Save.encode(M.Session.snapshot())))
        H.truthy(M.Session.restore(data), "restored")
        local st2 = L.tracks[3].state
        H.eq(L.tracks[3].instrumentId, "slide", "slide")
        H.eq(st2.patch .. " " .. st2.speed .. " " .. st2.snap, patch .. " FAST OFF", "rows")
        H.near(st2.pitch, 3.75, "pitch", 1e-6)
    end },

    { "recorded slide notes save and load with their fractional bends", function()
        local M, st = boot()
        local L = M.Looper
        st.snap = "OFF"
        H.tap("L2"); H.hold("B"); H.play(0.1); H.hold("UP"); H.play(0.4); H.release("UP"); H.play(0.1)
        H.release("B"); H.play(0.05); H.tap("L2")
        local ev = L.tracks[3].events[1]
        local data = assert(M.Save.decode(M.Save.encode(M.Session.snapshot())))
        H.truthy(M.Session.restore(data), "restored")
        local ev2 = L.tracks[3].events[1]
        H.eq(#ev2.bend, #ev.bend, "every keyframe")
        H.near(ev2.bend[#ev2.bend].semis, ev.bend[#ev.bend].semis, "the end pitch", 1e-6)
    end },
}
