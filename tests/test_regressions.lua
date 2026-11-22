-- Regressions from the code review: long notes, swing and the live press,
-- stutter stranding voices, the START double-tap panic, undoable 4 -> 2 bars,
-- deep copies, the undo cap, Harmony's cache, shared voice pools, and saves
-- that break restore.
local H = require("helpers")

local function startAt(L, phase)
    L:seek(phase)
    L.lastClockTime = H.time
end

local function firstOf(fired, kind)
    for _, f in ipairs(fired) do
        if f.kind == kind then return f end
    end
end

local function unreleased(S)
    local n = 0
    for _, v in ipairs(S.sustainVoices) do
        if v.alive and not v.releasedAt then n = n + 1 end
    end
    return n
end

return {
    -- ------------------------------------------------------------------
    -- Looper playback
    -- ------------------------------------------------------------------
    { "a note one tick shorter than the loop doesn't end the moment it starts", function()
        local M = H.fresh(); local L = M.Looper
        local loop = L:getLoopTicks()
        L.tracks[3].events = { { action = "B", tick = 960, len = loop - 1, vel = 0.8 } }
        startAt(L, 0)
        local fired = H.run(L, L:getLoopDuration() * 1.5)
        local on, off = firstOf(fired, "on"), firstOf(fired, "off")
        H.truthy(on and off, "on and off")
        H.truthy(off.phase > on.phase + 0.9 or off.phase < on.phase, "ends a loop later, not with its start")
    end },

    { "a note shorter than one frame still ends in that frame", function()
        local M = H.fresh(); local L = M.Looper
        L.tracks[3].events = { { action = "B", tick = 960, len = 2, vel = 0.8 } }
        startAt(L, 0)
        local fired = H.run(L, L:getLoopDuration() * 0.5)
        local on, off = firstOf(fired, "on"), firstOf(fired, "off")
        H.truthy(on and off, "on and off")
        H.eq(off.phase, on.phase, "same frame")
        H.eq(next(L.tracks[3].sounding), nil, "nothing left sounding")
    end },

    { "with swing, a press between the grid line and its swung time isn't played twice", function()
        for _, off in ipairs({ 0, 20, 37 }) do
            local M = H.fresh(); local L = M.Looper
            L.tracks[1].gridIndex = 3          -- 1/16
            L.tracks[1].swing = 0.66            -- odd 1/16s 38 ticks late
            startAt(L, (120 + off) / L:getLoopTicks())
            local ev = L:recordEvent(1, { action = "B", vel = 0.8 })
            H.truthy(ev.skipOnce, "counts as played (+" .. off .. ")")
            local fired = H.run(L, 0.3)
            H.eq(#fired, 0, "no second hit (+" .. off .. ")")
        end
    end },

    { "stutter over a held note leaves no voice ringing", function()
        local M = H.loadMain()
        local L, S = M.Looper, M.Synth
        L.tracks[3].events = { { action = "B", tick = 480, len = 1400, vel = 0.8, degree = 1, octave = 0, semis = 0 } }
        startAt(L, 0)
        H.play(0.6)                             -- the bass note starts on beat 2
        H.play(0.5, { "R2", "UP" })             -- beat repeat while it sounds
        H.play(3.0)
        H.eq(unreleased(S), 0, "every voice released")
    end },

    -- ------------------------------------------------------------------
    -- START double-tap: everything stops
    -- ------------------------------------------------------------------
    { "START double-tap silences every voice, sub-hit and held note", function()
        local M = H.loadMain()
        local S, L = M.Synth, M.Looper
        H.play(0.1)
        local v = S:noteOn("pad_warm", 0, 0.9, { track = L.tracks[4] })
        S:schedule(5.0, function() error("a sub-hit survived the panic") end)
        H.truthy(v and v.alive, "a voice is sounding")
        H.tap("START"); H.tap("START")
        H.eq(L.toastText, "PLAYHEAD RESET TO BAR 1.1 - ALL SOUND CLEARED", "reset")
        H.falsy(v.alive, "voice killed")
        H.eq(#S.sustainVoices, 0, "no sustained voices")
        H.eq(#S.scheduled, 0, "no pending sub-hits")
        H.truthy(L.playing, "playing again")
        H.play(6.0)                             -- the cancelled job never runs
    end },

    -- ------------------------------------------------------------------
    -- Loop length
    -- ------------------------------------------------------------------
    { "4 -> 2 bars can be undone", function()
        local M = H.fresh(); local L = M.Looper
        L:toggleBars()                           -- 4 bars
        L:beginRecordingTake()
        H.record(L, 1, "B", 0.10)                -- bar 1
        local cut = H.record(L, 1, "A", 0.70)    -- bar 3, ...
        cut.len = 0
        local long = H.record(L, 1, "X", 0.45)   -- ... and a note across the bar 2/3 line
        long.len = 960
        L:toggleBars()                           -- 2 bars
        H.eq(#L.tracks[1].events, 2, "bar 3 cut")
        H.eq(long.len, L:getLoopTicks() - long.tick, "the long note cut at the new end")
        L:beginRecordingTake()
        H.record(L, 1, "Y", 0.50)                -- a take since
        L:undo()                                 -- that take
        L:undo()                                 -- the loop length
        H.eq(L.bars, 4, "back to 4 bars")
        H.eq(#L.tracks[1].events, 3, "bar 3 back")
        local x
        for _, ev in ipairs(L.tracks[1].events) do if ev.action == "X" then x = ev end end
        H.eq(x.len, 960, "the long note's full length back")
    end },

    { "undoing 4 -> 2 bars keeps notes newer than the cut", function()
        local M = H.fresh(); local L = M.Looper
        L:toggleBars()
        L.tracks[1].events = { { action = "B", tick = 5000, len = 0, vel = 0.8, takeId = 0 } }
        L:toggleBars()
        -- an event from a later take with no undo entry of its own
        table.insert(L.tracks[1].events, { action = "A", tick = 100, len = 0, vel = 0.8, takeId = L.currentTakeId + 1 })
        L:undo()
        H.eq(#L.tracks[1].events, 2, "the saved note and the newer one")
    end },

    { "2 -> 4 bars gives the copies their own chord and keyframes, and skips held notes", function()
        local M = H.fresh(); local L = M.Looper
        L.tracks[2].events = {
            { action = "B", tick = 0, len = 0, vel = 0.8, chord = { root = 0, third = 4, fifth = 7 },
              bend = { { dt = 10, semis = 2 } } },
            { action = "A", tick = 100, len = 0, vel = 0.8, open = true },
        }
        L:toggleBars()
        local evs = L.tracks[2].events
        H.eq(#evs, 3, "one copy (the held note isn't copied)")
        local copy = evs[3]
        H.truthy(copy.chord ~= evs[1].chord and copy.bend ~= evs[1].bend, "own tables")
        copy.chord.root = 5
        H.eq(evs[1].chord.root, 0, "original untouched")
    end },

    -- ------------------------------------------------------------------
    -- Undo stack
    -- ------------------------------------------------------------------
    { "the undo stack keeps at most UNDO_LIMIT entries, newest kept", function()
        local M = H.fresh(); local L = M.Looper
        for i = 1, L.UNDO_LIMIT + 10 do L:pushUndo({ kind = "take", takeId = i, trackSlot = 1 }) end
        H.eq(#L.undoStack, L.UNDO_LIMIT, "capped")
        H.eq(L.undoStack[#L.undoStack].takeId, L.UNDO_LIMIT + 10, "newest kept")
    end },

    -- ------------------------------------------------------------------
    -- Harmony's cache
    -- ------------------------------------------------------------------
    { "Harmony sees an event change made in place once the track is touched", function()
        local M = H.fresh(); local L = M.Looper
        local Harmony = require("src.harmony")
        local chord = { root = 5, third = 4, fifth = 7 }
        local ev = { action = "B", tick = 0, len = 0, vel = 0.8, chord = chord, open = true }
        local lane = L:getLane()
        lane.events = { ev }
        H.eq(select(2, Harmony:chordAt(0)), "tonic", "a held chord doesn't count yet")
        ev.open = nil
        L:touch(lane)
        H.eq(Harmony:chordAt(0), chord, "counts once released")
    end },

    -- ------------------------------------------------------------------
    -- Voices shared by two tracks
    -- ------------------------------------------------------------------
    { "a track doesn't steal voices from another track on the same patch", function()
        local M = H.fresh({ realSynth = true })
        local S, L = M.Synth, M.Looper
        S:initTrackFx()
        local loop, _, tune = S:createLoop(110, 4, function(a) return math.sin(a) end)
        S:createLoopPool("s_loop", loop, 2)
        S:definePatch("s", { loop = "s_loop", tune = tune, sustain = 0.5, xfade = 0.1, release = 0.2 })
        local a1 = S:noteOn("s", 0, 0.9, { track = L.tracks[1], voices = 2 })
        local a2 = S:noteOn("s", 2, 0.9, { track = L.tracks[1], voices = 2 })
        local b1 = S:noteOn("s", 4, 0.9, { track = L.tracks[2], voices = 2 })
        H.truthy(a1.alive and a2.alive and b1.alive, "track 1 keeps its notes; the pool grew")
        local a3 = S:noteOn("s", 5, 0.9, { track = L.tracks[1], voices = 2 })
        H.falsy(a1.alive, "track 1 over its count steals its own oldest")
        H.truthy(a2.alive and a3.alive and b1.alive, "the rest play on")
    end },

    -- ------------------------------------------------------------------
    -- Saves that break restore
    -- ------------------------------------------------------------------
    { "an error inside restore falls back to the older save instead of crashing", function()
        local M = H.loadMain()
        local Autosave, Session = require("src.autosave"), M.Session
        M.Looper.bpm = 101
        H.files["session_a.txt"] = "{seq=1,session=" .. M.Save.encode(Session.snapshot()) .. "}"
        M.Looper.bpm = 140
        H.files["session_b.txt"] = "{seq=2,session=" .. M.Save.encode(Session.snapshot()) .. "}"
        local restore, calls = Session.restore, 0
        Session.restore = function(data)
            calls = calls + 1
            if calls == 1 then
                restore(data)                    -- applies part of it ...
                error("boom")                    -- ... then breaks
            end
            return restore(data)
        end
        H.truthy(Autosave:load(), "restored")
        Session.restore = restore
        H.eq(M.Looper.bpm, 101, "the older save")
    end },

    { "if every save breaks restore, the session goes back to the clean start", function()
        local M = H.loadMain()
        local Autosave, Session = require("src.autosave"), M.Session
        local before = M.Looper.bpm            -- the boot state
        M.Looper.bpm = 150
        H.files["session_a.txt"] = "{seq=1,session=" .. M.Save.encode(Session.snapshot()) .. "}"
        M.Looper.bpm = before
        local restore = Session.restore
        local first = true
        Session.restore = function(data)
            if first then first = false; restore(data); error("boom") end
            return restore(data)
        end
        H.falsy(Autosave:load(), "nothing restored")
        Session.restore = restore
        H.eq(M.Looper.bpm, before, "boot state back")
        H.eq(M.Looper.toastText, "SAVE COULDN'T BE READ - FRESH SESSION", "message")
    end },

    { "restore drops events whose instrument fields are the wrong type", function()
        local M = H.loadMain()
        local data = M.Session.snapshot()
        data.tracks[2].instrumentId = "harp"
        data.tracks[2].events = {
            { action = "B", tick = 0, vel = 0.8, chord = { root = 0, third = 4, fifth = 7 } },   -- fine
            { action = "B", tick = 480, vel = 0.8, chord = { root = "C" } },                     -- bad chord
            { action = "B", tick = 960, vel = 0.8, degree = "two" },                             -- bad degree
            { action = "B", tick = 1440, vel = 0.8, chord = "Cmaj" },                            -- not a table
        }
        H.truthy(M.Session.restore(data), "restored")
        H.eq(#M.Looper.tracks[2].events, 1, "only the good event")
        H.play(5.0)                                -- and the loop plays without an error
    end },
}
