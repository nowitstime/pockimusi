-- Notes (A6): event format v2, note-on / note-off playback, held notes that
-- record as one event with a length, and notes always being released.
local H = require("helpers")

local GRID = { S = 3, FREE = 5 }

local function setup()
    local M = H.fresh()
    M.Looper.tracks[1].gridIndex = GRID.S
    return M, M.Looper
end

local function startAt(L, phase)
    L:seek(phase)
    L.lastClockTime = H.time
end

local function kinds(fired)
    local t = {}
    for _, f in ipairs(fired) do t[#t + 1] = f.kind end
    return table.concat(t, " ")
end

-- A recorded note of `lenFrac` of the loop at `phase`
local function heldNote(L, phase, lenFrac)
    local ev = H.record(L, 1, "B", phase)
    ev.len = math.floor(lenFrac * L:getLoopTicks() + 0.5)
    return ev
end

local function count(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end

-- Track 4 (grain, a holding instrument), recording latched, playhead still
local function holdSetup()
    local M = H.fresh()
    M.Input.recLatched = true
    return M, M.Looper, M.Looper.tracks[4]
end

-- Game-loop helpers
local function boot()
    local M = H.loadMain()
    M.Theory = require("src.theory")
    H.play(0.1)
    return M, M.Looper
end

local function countGrains(Synth)
    local n = { value = 0 }
    local orig = Synth.trigger
    Synth.trigger = function(self, name, ...)
        if name:sub(1, 6) == "grain_" then n.value = n.value + 1 end
        return orig(self, name, ...)
    end
    return n
end

return {
    -- ------------------------------------------------------------------
    -- Looper: on / off
    -- ------------------------------------------------------------------
    { "a note with length sends on at its tick and off at tick + len", function()
        local _, L = setup()
        heldNote(L, 0.25 + 0.001, 0.25)              -- tick 960, a quarter loop long
        startAt(L, 0.1)
        local fired = H.run(L, H.loopSeconds(L), 1000)
        H.eq(kinds(fired), "on off", "order")
        H.near(fired[1].phase, 0.25, "on at 0.25", 0.002)
        H.near(fired[2].phase, 0.50, "off at 0.50", 0.002)
    end },

    { "a note crossing the loop seam turns off after the wrap", function()
        local _, L = setup()
        heldNote(L, 0.875 + 0.001, 0.25)              -- 0.875 .. 0.125
        startAt(L, 0.5)
        local fired = H.run(L, H.loopSeconds(L) * 0.75, 1000)
        H.eq(kinds(fired), "on off", "order")
        H.near(fired[2].phase, 0.125, "off after the wrap", 0.002)
    end },

    { "one-shots (len 0) never get a note-off", function()
        local _, L = setup()
        H.record(L, 1, "B", 0.26)
        startAt(L, 0.5)
        H.eq(kinds(H.run(L, H.loopSeconds(L) * 2)), "on on", "two passes, no offs")
    end },

    { "a note still being held while recording is not played back", function()
        local _, L = setup()
        local ev = heldNote(L, 0.26, 0.1)
        ev.open = true
        startAt(L, 0.5)
        H.eq(#H.run(L, H.loopSeconds(L)), 0, "nothing while open")
        ev.open = nil
        H.eq(kinds(H.run(L, H.loopSeconds(L))), "on off", "plays once closed")
    end },

    { "a note skipped once (already played live) gets no stray note-off", function()
        local _, L = setup()
        local ev = heldNote(L, 0.24, 0.1)             -- snapped forward: skipOnce
        H.truthy(ev.skipOnce, "skipOnce")
        local fired = H.run(L, H.loopSeconds(L), 1000)
        H.eq(kinds(fired), "", "first pass: no on, no off")
        H.eq(kinds(H.run(L, H.loopSeconds(L), 1000)), "on off", "second pass plays")
    end },

    { "a held note's already-played mark is used up while it is still held", function()
        local _, L = setup()
        local ev = heldNote(L, 0.24, 0.1)             -- snapped forward: skipOnce
        ev.open = true                                 -- still being held
        H.run(L, 0.2)                                  -- playhead passes it while held
        H.falsy(ev.skipOnce, "mark used up")
        ev.open = nil                                  -- released
        H.eq(kinds(H.run(L, H.loopSeconds(L) * 1.2, 1000)), "on off", "plays on the very next pass")
    end },

    -- ------------------------------------------------------------------
    -- Looper: sounding notes are always released
    -- ------------------------------------------------------------------
    { "sounding notes are released by mute, clear, erase, undo, bars, pause and swap", function()
        local cases = {
            mute  = function(M, L) L:toggleMute(1) end,
            clear = function(M, L) L:clearTrack(1) end,
            erase = function(M, L) L:clearTrackAction(1, "B") end,
            undo  = function(M, L) L:undo() end,
            bars  = function(M, L) L:toggleBars() end,
            pause = function(M, L) L:setPlaying(false) end,
            swap  = function(M, L) M.Instruments:swapTrackInstrument(1, "harp") end,
        }
        for name, act in pairs(cases) do
            local M, L = setup()
            local offs = 0
            L:setNoteHandler(function(kind) if kind == "off" then offs = offs + 1 end end)
            L:beginRecordingTake()
            heldNote(L, 0.25 + 0.001, 0.5)
            startAt(L, 0.2)
            H.run(L, H.loopSeconds(L) * 0.1)          -- note is now sounding
            H.eq(count(L.tracks[1].sounding), 1, name .. ": sounding")
            act(M, L)
            H.eq(count(L.tracks[1].sounding), 0, name .. ": released")
            H.eq(offs, 1, name .. ": one note-off sent")
        end
    end },

    { "re-recording over a sounding note releases it", function()
        local _, L = setup()
        local offs = 0
        L:setNoteHandler(function(kind) if kind == "off" then offs = offs + 1 end end)
        heldNote(L, 0.25 + 0.001, 0.5)
        startAt(L, 0.2)
        H.run(L, H.loopSeconds(L) * 0.1)
        H.record(L, 1, "B", 0.25 + 0.002)             -- same pad, same step
        H.eq(offs, 1, "old note released")
        H.eq(#L.tracks[1].events, 1, "replaced")
    end },

    { "4 -> 2 bars cuts a note that would run past the new loop end", function()
        local _, L = setup()
        L:toggleBars()                                 -- 4 bars, 7680 ticks
        local ev = H.record(L, 1, "B", 0.375 + 0.0001) -- tick 2880 (bar 2)
        ev.len = 2000
        L:toggleBars()
        H.eq(ev.len, 3840 - 2880, "len cut to the loop end")
    end },

    -- ------------------------------------------------------------------
    -- Held-note handles (B1): early release, bends, release-tail bends
    -- ------------------------------------------------------------------
    { "hold() returns a handle that can end the note early", function()
        local M, L, track = holdSetup()
        L:seek(0.1)
        local h = M.Instruments:holdNote(track, { action = "B", semis = 0 })
        H.truthy(h:isHeld(), "held")
        L:seek(0.35)
        h:release()
        H.falsy(h:isHeld(), "released")
        H.eq(h.rec.len, 960, "len = 0.25 of the loop")
        H.eq(#M.Instruments.held[4], 0, "no longer in the held list")
        H.eq(h.rec.open, nil, "closed")
    end },

    { "bends while held record keyframes with their time since the press", function()
        local M, L, track = holdSetup()
        L:seek(0.1)
        local h = M.Instruments:holdNote(track, { action = "B", semis = 0 })
        L:seek(0.2); h:bend({ degree = 3, octave = 0, semis = 4 })
        L:seek(0.3); h:bend({ degree = 5, octave = 0, semis = 7 })
        L:seek(0.4); h:release()
        local b = h.rec.bend
        H.eq(#b, 2, "two keyframes")
        H.eq(b[1].dt, 384, "first at 0.1 of the loop")
        H.eq(b[1].degree, 3, "first degree")
        H.eq(b[2].dt, 768, "second at 0.2")
        H.eq(b[2].semis, 7, "second pitch")
        H.eq(h.rec.len, 1152, "len")
    end },

    { "bends after letting go are recorded too, after len (release tail)", function()
        local M, L, track = holdSetup()
        L:seek(0.1)
        local h = M.Instruments:holdNote(track, { action = "B", semis = 0 })
        L:seek(0.3); h:release()
        L:seek(0.35); h:bend({ degree = 2, octave = 0, semis = 2 })
        H.eq(h.rec.len, 768, "len ends at the release")
        H.eq(h.rec.bend[1].dt, 960, "tail keyframe after len")
    end },

    { "time since the press keeps counting across the loop seam", function()
        local M, L, track = holdSetup()
        L:seek(0.9)
        local h = M.Instruments:holdNote(track, { action = "B", semis = 0 })
        L:seek(0.0); h:advance()
        L:seek(0.1); h:bend({ degree = 4, octave = 0, semis = 5 })
        L:seek(0.15); h:release()
        H.eq(h.rec.bend[1].dt, 768, "0.2 of the loop after the press")
        H.eq(h.rec.len, 960, "0.25 of the loop")
    end },

    { "a note held longer than a loop stops recording bends and caps its length", function()
        local M, L, track = holdSetup()
        L:seek(0.0)
        local h = M.Instruments:holdNote(track, { action = "B", semis = 0 })
        for k = 1, 12 do L:seek((k * 0.1) % 1.0); h:advance() end
        h:bend({ degree = 2, octave = 0, semis = 2 })
        h:release()
        H.eq(h.rec.bend, nil, "no keyframe past a loop")
        H.eq(h.rec.len, L:getLoopTicks() - 1, "len capped just under a loop")
    end },

    { "a stutter jump backwards doesn't count as time held", function()
        local M, L, track = holdSetup()
        L:seek(0.5)
        local h = M.Instruments:holdNote(track, { action = "B", semis = 0 })
        L:seek(0.49)
        H.eq(h:advance(), 0, "still 0")
    end },

    { "several bends in one tick keep only the latest", function()
        local M, L, track = holdSetup()
        L:seek(0.1)
        local h = M.Instruments:holdNote(track, { action = "B", semis = 0 })
        L:seek(0.2)
        h:bend({ degree = 2, octave = 0, semis = 2 })
        h:bend({ degree = 3, octave = 0, semis = 4 })
        H.eq(#h.rec.bend, 1, "one keyframe")
        H.eq(h.rec.bend[1].degree, 3, "the latest")
    end },

    { "bends reach the instrument's live voice even when not recording", function()
        local M, L, track = holdSetup()
        M.Input.recLatched = false
        local seen = {}
        local Grain = M.Instruments:getDefinition("grain")
        Grain.bendTo = function(_, ev, fields) table.insert(seen, fields.semis) end
        local h = M.Instruments:holdNote(track, { action = "B", semis = 0 })
        h:bend({ degree = 5, octave = 0, semis = 7 })
        Grain.bendTo = nil
        H.eq(h.rec, nil, "nothing recorded")
        H.eq(seen[1], 7, "bendTo got the new pitch")
    end },

    { "bendAt finds the keyframe in effect at a time", function()
        local M = H.fresh()
        local ev = { bend = { { dt = 100, semis = 2 }, { dt = 500, semis = 4 } } }
        H.eq(M.Instruments:bendAt(ev, 50), nil, "before the first bend")
        H.eq(M.Instruments:bendAt(ev, 100).semis, 2, "at the first")
        H.eq(M.Instruments:bendAt(ev, 499).semis, 2, "still the first")
        H.eq(M.Instruments:bendAt(ev, 900).semis, 4, "the second")
        H.eq(M.Instruments:bendAt({}, 900), nil, "no bends")
    end },

    { "one-shots carry no bend list", function()
        local M, L, track = holdSetup()
        M.Instruments:playNote(track, { action = "B", semis = 0 })
        H.eq(track.events[1].bend, nil, "no bend")
    end },

    { "2 -> 4 bars gives the copy its own keyframes; 4 -> 2 drops bends past the end", function()
        local M, L, track = holdSetup()
        L:seek(0.1)
        local h = M.Instruments:holdNote(track, { action = "B", semis = 0 })
        L:seek(0.2); h:bend({ degree = 3, octave = 0, semis = 4 })
        L:seek(0.3); h:release()
        L:toggleBars()
        local a, b = track.events[1], track.events[2]
        H.truthy(a.bend ~= b.bend, "separate tables")
        H.eq(b.bend[1].dt, a.bend[1].dt, "same timing")
        -- a note in bar 2 bending into bar 3, then back to 2 bars
        L:seek(0.45)
        local h2 = M.Instruments:holdNote(track, { action = "A", semis = 0 })
        L:seek(0.48); h2:bend({ degree = 2, octave = 0, semis = 2 })
        L:seek(0.55); h2:bend({ degree = 4, octave = 0, semis = 5 })
        L:seek(0.6); h2:release()
        L:toggleBars()
        local kept
        for _, ev in ipairs(track.events) do if ev.action == "A" then kept = ev end end
        H.eq(#kept.bend, 1, "the bend in bar 3 is dropped")
        H.eq(kept.bend[1].semis, 2, "the bend in bar 2 stays")
    end },

    -- ------------------------------------------------------------------
    -- Instruments: event fields per instrument
    -- ------------------------------------------------------------------
    { "drums, harp and bass record v2 fields only", function()
        local _, L = boot()
        H.tap("L2")
        H.tap("B")                                     -- drums
        H.tap("SELECT"); H.tap("A")                    -- harp
        H.tap("SELECT"); H.hold("UP"); H.play(0.05); H.tap("B"); H.release("UP")  -- bass, degree 5
        H.tap("L2")
        local d, h, b = L.tracks[1].events[1], L.tracks[2].events[1], L.tracks[3].events[1]
        H.eq(d.soundId, "kick_808", "drum sound")
        H.truthy(d.vel and d.decay, "drum vel/decay")
        H.eq(h.semis, 4, "harp string A = E")
        H.eq(h.chord.name, "C", "harp chord name")
        H.eq(h.chord.roman, "I", "harp chord roman")
        H.eq(h.chord.colour, "TRIAD", "harp chord colour")
        H.eq(b.degree, 5, "bass degree")
        H.eq(b.octave, 0, "bass octave")
        H.eq(b.semis, 7, "bass pitch (G)")
        H.truthy(b.len > 0, "bass notes are held notes (Phase B)")
        for _, ev in ipairs({ d, h, b }) do
            if ev ~= b then H.eq(ev.len, 0, "one-shot") end
            for _, old in ipairs({ "trackSlot", "instrumentId", "velocity", "pitchSemis", "decayMod", "phase" }) do
                H.eq(ev[old], nil, "no old field " .. old)
            end
        end
    end },

    -- ------------------------------------------------------------------
    -- Instruments: Grain as held notes
    -- ------------------------------------------------------------------
    { "a held Grain press records one event with the held length", function()
        local M, L = boot()
        for _ = 1, 3 do H.tap("SELECT") end            -- track 4 = grain
        local grains = countGrains(M.Synth)
        H.tap("L2")
        H.hold("B"); H.play(1.0)
        local st = L.tracks[4].state
        H.eq(count(st.spawners), 1, "one live spawner while held")
        H.release("B"); H.play(0.05)
        H.tap("L2")
        local ev = L.tracks[4].events
        H.eq(#ev, 1, "one event")
        local secs = ev[1].len / L:getTicksPerSecond()
        H.near(secs, 1.0, "len = time held", 0.04)
        H.eq(ev[1].action, "B", "action")
        H.truthy(ev[1].semis and ev[1].scanPos and ev[1].density, "grain settings stored")
        H.eq(ev[1].open, nil, "closed")
        H.truthy(grains.value >= 8, "grains spawned while held (" .. grains.value .. ")")
        H.eq(count(st.spawners), 0, "spawner gone after release")
    end },

    { "a recorded Grain note plays back as grains for its length, then stops", function()
        local M, L = boot()
        for _ = 1, 3 do H.tap("SELECT") end
        H.tap("L2"); H.hold("B"); H.play(0.6); H.release("B"); H.play(0.05); H.tap("L2")
        local st = L.tracks[4].state
        local grains = countGrains(M.Synth)
        local maxSpawners = 0
        for _ = 1, math.floor(L:getLoopDuration() * 60) do
            H.play(1 / 60)
            maxSpawners = math.max(maxSpawners, count(st.spawners))
        end
        H.eq(maxSpawners, 1, "one spawner during the note")
        H.truthy(grains.value >= 4, "grains on playback (" .. grains.value .. ")")
        H.eq(count(st.spawners), 0, "stopped after its length")
    end },

    { "opening a page while holding a Grain note releases it", function()
        local _, L = boot()
        for _ = 1, 3 do H.tap("SELECT") end
        H.tap("L2")
        H.hold("B"); H.play(0.4)
        H.hold("SELECT"); H.play(0.3)                  -- Track page takes the controls
        local st = L.tracks[4].state
        H.eq(count(st.spawners), 0, "released")
        H.truthy(L.tracks[4].events[1].len > 0, "recorded note closed with a length")
        H.release("SELECT", "B"); H.play(0.1)
    end },

    { "muting a track stops its playing Grain note", function()
        local _, L = boot()
        for _ = 1, 3 do H.tap("SELECT") end
        H.tap("L2"); H.hold("B"); H.play(1.5); H.release("B"); H.play(0.05); H.tap("L2")
        local st = L.tracks[4].state
        -- wait for playback to start the note
        local t = 0
        while count(st.spawners) == 0 and t < L:getLoopDuration() * 1.2 do H.play(1 / 60); t = t + 1 / 60 end
        H.eq(count(st.spawners), 1, "playing")
        H.hold("R2"); H.play(0.05); H.tap("X"); H.release("R2"); H.play(0.05)
        H.truthy(L.tracks[4].muted, "muted")
        H.eq(count(st.spawners), 0, "stopped")
    end },
}
