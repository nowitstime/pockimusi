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

    -- ------------------------------------------------------------------
    -- Code review pass 2 regressions
    -- ------------------------------------------------------------------
    { "Song:playFromTop fires beat-1 pattern events and at==0 take notes/moves", function()
        local M = H.loadMain()
        local L, Song, Patterns = M.Looper, require("src.song"), require("src.patterns")
        H.play(0.05)
        L.tracks[1].events = { { action = "B", tick = 0, len = 0, vel = 0.9 } }
        Patterns.flush()
        local fired = {}
        local orig = L.noteHandler
        L:setNoteHandler(function(kind, ev, track)
            if kind == "on" then fired[#fired + 1] = { track = track.slot, action = ev.action, at = ev.at, tick = ev.tick } end
            return orig(kind, ev, track)
        end)
        Song.data = {
            steps = {
                {
                    slot = M.Session.patternSlot or "A",
                    start = 0,
                    len = L:getLoopTicks(),
                    mutes = { false, false, false, false },
                    moves = { { at = 0, kind = "fade", gain = 0.5 } },
                    takes = { [3] = { { action = "B", tick = 0, at = 0, len = 240, vel = 0.9, semis = 0, degree = 1, octave = 0 } } },
                },
            },
        }
        H.truthy(Song:playFromTop(), "started")
        H.play(0.1)
        local sawPat, sawTake = false, false
        for _, f in ipairs(fired) do
            if f.track == 1 and f.tick == 0 and f.at == nil then sawPat = true end
            if f.track == 3 and f.at == 0 then sawTake = true end
        end
        H.truthy(sawPat, "beat-1 pattern event fired")
        H.truthy(sawTake, "at==0 song take note fired")
        H.near(M.Synth.fadeGain, 0.5, "at==0 fade move fired")
    end },

    { "pausing or muting silences sounding song take notes", function()
        local M = H.loadMain()
        local L, Song = M.Looper, require("src.song")
        H.play(0.05)
        Song.data = {
            steps = {
                {
                    slot = M.Session.patternSlot or "A",
                    start = 0,
                    len = L:getLoopTicks(),
                    mutes = { false, false, false, false },
                    moves = {},
                    takes = { [3] = { { action = "B", tick = 0, at = 0, len = 1920, vel = 0.9, semis = 0, degree = 1, octave = 0 } } },
                },
            },
        }
        Song:playFromTop()
        H.play(0.1)
        H.eq(#Song.sounding, 1, "take note sounding")
        L:toggleMute(3)
        H.eq(#Song.sounding, 0, "muting track 3 silenced its take note")

        L:toggleMute(3)
        Song:playFromTop()
        H.play(0.1)
        H.eq(#Song.sounding, 1, "take note sounding again")
        L:setPlaying(false)
        H.eq(#Song.sounding, 0, "pausing silenced all take notes")
    end },

    { "Song:startRecording from stopped with fadeGain < 1 preserves existing fade moves", function()
        local M = H.loadMain()
        local L, Song, S = M.Looper, require("src.song"), M.Synth
        H.play(0.05)
        Song.data = {
            steps = {
                {
                    slot = M.Session.patternSlot or "A",
                    start = 0,
                    len = L:getLoopTicks(),
                    mutes = { false, false, false, false },
                    moves = { { at = 240, kind = "fade", gain = 0.4 } },
                    takes = {},
                },
            },
        }
        S.fadeGain = 0.25
        Song:startRecording()
        H.play(0.5)
        H.falsy(Song.touched.fade, "fade was not falsely marked touched")
        H.eq(#Song.data.steps[1].moves, 1, "existing fade move preserved")
        Song:stop()
    end },

    { "Wobble OPEN flag and rate/open bend keyframes survive release and session restore", function()
        local M = H.loadMain()
        local L, Session = M.Looper, M.Session
        H.play(0.05)
        M.Instruments:swapTrackInstrument(3, "wobble")
        H.tap("SELECT"); H.tap("SELECT")
        H.tap("L2")                                -- latch record
        H.hold("L1", "R1", "B"); H.play(0.15)      -- start note with OPEN held
        H.release("L1", "R1"); H.hold("RIGHT"); H.play(0.15) -- bend to 1/16, open=false
        H.release("RIGHT", "B"); H.play(0.05)
        H.tap("L2")
        local ev = L.tracks[3].events[1]
        H.truthy(ev, "recorded wobble note")
        H.truthy(ev.wobbleOpen, "wobbleOpen survived release")
        H.eq(ev.open, nil, "looper runtime open cleared")
        local snap = Session.snapshot()
        H.truthy(Session.restore(snap), "restored")
        local rev = L.tracks[3].events[1]
        H.truthy(rev and rev.wobbleOpen, "wobbleOpen survived restore")
        H.truthy(rev.bend and #rev.bend >= 1, "bend keyframes survived restore")
        H.eq(rev.bend[1].rate, "1/16", "rate keyframe preserved")
        H.eq(rev.bend[1].open, false, "open keyframe preserved")
    end },

    { "Synth:applyFilter multiplies sourceTone with track TONE and noteOn clears stale sourceTone", function()
        local M = H.loadMain()
        local S, L = M.Synth, M.Looper
        S.fxSupported = true
        local lastFilter
        local fakeSrc = { setFilter = function(_, f) lastFilter = f end }
        local track = L.tracks[3]
        track.fx.on.tone = true
        track.fx.tone = 0.5                        -- tone factor = 1 - 0.5*0.97 = 0.515
        S.sourceTone[fakeSrc] = 0.5
        S:applyFilter(fakeSrc, track)
        H.truthy(lastFilter and lastFilter.highgain < 0.3, "sourceTone multiplied with track TONE")

        local v1 = S:noteOn("bass_neuro", 0, 0.9, { track = track })
        H.truthy(v1 and v1.loopSrc, "got loopSrc")
        S.sourceTone[v1.loopSrc] = 0.2
        v1:kill()
        local v2 = S:noteOn("bass_neuro", 0, 0.9, { track = track })
        H.eq(S.sourceTone[v2.loopSrc], nil, "reused loopSrc cleared stale sourceTone")
    end },

    { "Synth:ensureDrum finishes a half-built lazy drum instead of dropping it", function()
        local M = H.fresh()
        local S = M.Synth
        S:init()
        S:startPregen()
        local target = S.lazyOrder[1]
        H.truthy(target, "has a lazy drum")
        -- step once with 0 budget so the coroutine starts building `target` and yields mid-buffer
        S:stepPregen(0)
        H.eq(S.drumBuilding, target, "drum is mid-build")
        local v = S:trigger(target, 0, 0.9, 1.0, nil, 1.0, M.Looper.tracks[1])
        H.truthy(v, "trigger finished the half-built drum instead of dropping it")
        S:stopPregen()
    end },

    { "Lane closes X wheel on track switch and ignores unowned X release", function()
        local M = H.loadMain()
        local L = M.Looper
        H.play(0.05)
        -- Go to Track C (5 = LANE)
        for _ = 1, 4 do H.tap("SELECT") end
        H.eq(L.activeTrack, L.LANE, "on Track C")
        H.hold("X"); H.play(0.4)                   -- open wheel
        H.hold("UP"); H.play(0.05)                 -- hover a progression
        local st = L.tracks[L.LANE].state
        H.truthy(st.wheelOpen and st.preview, "wheel open with preview")
        H.tap("SELECT")                            -- leave Track C while X still held
        H.falsy(st.wheelOpen, "wheel closed on track switch")
        H.eq(st.preview, nil, "preview cleared on track switch")
        H.release("UP", "X"); H.play(0.05)
        -- Return to Track C, open Transport page, press X there, release START then X: must not stamp
        for _ = 1, 4 do H.tap("SELECT") end
        local before = #L.tracks[L.LANE].events
        H.hold("START"); H.play(0.3)               -- enter TRANSPORT page
        H.hold("X"); H.play(0.05)                  -- press X while Transport blocks Track C
        H.release("START"); H.play(0.05)
        H.release("X"); H.play(0.05)
        H.eq(#L.tracks[L.LANE].events, before, "unowned X release did not stamp")
    end },

    { "holding L2+R2 combo while record is latched keeps recLatched on", function()
        local M = H.loadMain()
        H.play(0.05)
        H.tap("L2")
        H.truthy(M.Input.recLatched, "record latched")
        H.hold("L2", "R2"); H.play(0.4)
        H.release("R2", "L2"); H.play(0.05)
        H.truthy(M.Input.recLatched, "still latched after L2+R2 combo")
    end },

    { "1/4 grid early press in a 2-bar loop does not double-trigger", function()
        local M = H.fresh(); local L = M.Looper
        L.tracks[1].gridIndex = 1                  -- 1/4 (480 ticks)
        local loop = L:getLoopTicks()              -- 3840 (2 bars)
        startAt(L, (480 - 220) / loop)             -- 220 ticks before beat 2 (> 5% of 3840)
        local ev = L:recordEvent(1, { action = "B", vel = 0.8 })
        H.truthy(ev.skipOnce, "skipOnce set for 220-tick forward snap")
        local fired = H.run(L, 0.5)
        H.eq(#fired, 0, "no immediate double-trigger")
    end },

    { "Patterns.summary handles missing track slots without sparse holes", function()
        local M = H.loadMain()
        local Patterns = require("src.patterns")
        local snap = M.Session.snapshot()
        snap.tracks[2] = nil
        H.files["pattern_b.txt"] = "{seq=1,saved=1,session=" .. M.Save.encode(snap) .. "}"
        local sum = Patterns.summary("B")
        H.truthy(sum and not sum.empty, "summary built")
        local joined = table.concat(sum.instruments, " / ")
        H.truthy(#joined > 0, "dense table.concat succeeded")
    end },
}
