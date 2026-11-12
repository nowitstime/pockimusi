-- Bass (Phase B): patches and rows (B2); held notes, legato and bends follow.
local H = require("helpers")

local function boot()
    local M = H.loadMain()
    H.play(0.1)
    H.tap("SELECT"); H.tap("SELECT")              -- track 3 = bass
    return M, M.Looper, M.Looper.tracks[3]
end

-- Hold SELECT (Track page), run fn, let go
local function onTrackPage(fn)
    H.hold("SELECT"); H.play(0.3)
    fn()
    H.release("SELECT"); H.play(0.1)
end

local function triggersOf(Synth)
    local seen = {}
    local orig = Synth.trigger
    Synth.trigger = function(self, name, ...)
        table.insert(seen, name)
        return orig(self, name, ...)
    end
    return seen
end

return {
    -- ------------------------------------------------------------------
    -- B2: patches and rows
    -- ------------------------------------------------------------------
    { "three bass patches with attack pools and loops", function()
        local M = H.loadMain()
        local S = M.Synth
        local Bass = M.Instruments:getDefinition("bass")
        local labels = {}
        for _, id in ipairs(Bass.PATCHES) do
            local p = S.patches[id]
            H.truthy(p, id .. " defined")
            H.truthy(S.pools[p.attack], id .. " attack pool")
            H.truthy(S.loopPools[p.loop], id .. " loop pool")
            labels[#labels + 1] = p.label
        end
        H.eq(table.concat(labels, " "), "SAW SUB PLUCK", "labels in order")
        H.truthy(S.patches.bass_pluck.overlap, "PLUCK overlaps")
        H.falsy(S.patches.bass_saw.overlap or S.patches.bass_sub.overlap, "SAW and SUB are mono")
        H.truthy(S.patches.bass_pluck.release > S.patches.bass_saw.release, "PLUCK rings longer")
    end },

    { "Track page shows PATCH (sound) and GLIDE (setting) rows", function()
        local M, _, track = boot()
        local rows = M.Instruments:getSoundRows(M.Instruments:getDefinition("bass"), track.state)
        H.eq(#rows, 2, "two rows")
        H.eq(rows[1].label .. "=" .. rows[1].value, "PATCH=SAW", "patch row")
        H.eq(rows[1].kind, nil, "patch is a sound row")
        H.eq(rows[2].label .. "=" .. rows[2].value, "GLIDE=MEDIUM", "glide row")
        H.eq(rows[2].kind, "setting", "glide is a setting row")
    end },

    { "R1 on PATCH steps SAW -> SUB -> PLUCK -> SAW and previews each", function()
        local M, L, track = boot()
        local seen = triggersOf(M.Synth)
        local got = {}
        onTrackPage(function()
            for _ = 1, 3 do
                H.tap("R1")
                got[#got + 1] = track.state.patch
            end
        end)
        H.eq(table.concat(got, " "), "bass_sub bass_pluck bass_saw", "order")
        H.eq(table.concat(seen, " "), "bass_sub bass_pluck bass", "a preview of each attack")
        H.eq(L.toastText, "BASS PATCH: SAW", "toast")
    end },

    { "L1/R1 on GLIDE steps FAST / MEDIUM / SLOW without a preview", function()
        local M, _, track = boot()
        local Bass = M.Instruments:getDefinition("bass")
        local seen = triggersOf(M.Synth)
        onTrackPage(function()
            H.tap("DOWN")                              -- GLIDE row
            H.tap("R1")
        end)
        H.eq(track.state.glide, "SLOW", "MEDIUM -> SLOW")
        H.eq(#seen, 0, "no preview")
        H.truthy(Bass:getGlideRate(track.state) < Bass.GLIDE_RATES.MEDIUM, "slower rate")
        onTrackPage(function() H.tap("DOWN"); H.tap("L1"); H.tap("L1") end)
        H.eq(track.state.glide, "FAST", "SLOW -> MEDIUM -> FAST")
        H.truthy(Bass:getGlideRate(track.state) > Bass.GLIDE_RATES.MEDIUM, "faster rate")
    end },

    { "notes play with the chosen patch", function()
        local M, _, track = boot()
        onTrackPage(function() H.tap("R1") end)       -- SUB
        local seen = triggersOf(M.Synth)
        H.tap("B")
        H.eq(seen[1], "bass_sub", "SUB attack")
    end },

    { "each bass track keeps its own patch and glide", function()
        local M, L = boot()
        M.Instruments:swapTrackInstrument(4, "bass")
        onTrackPage(function() H.tap("R1"); H.tap("DOWN"); H.tap("R1") end)   -- track 3: SUB, SLOW
        H.eq(L.tracks[3].state.patch, "bass_sub", "track 3 patch")
        H.eq(L.tracks[3].state.glide, "SLOW", "track 3 glide")
        H.eq(L.tracks[4].state.patch, "bass_saw", "track 4 untouched")
        H.eq(L.tracks[4].state.glide, "MEDIUM", "track 4 untouched")
    end },

    { "patch and glide come back with undo after a swap", function()
        local M, L, track = boot()
        onTrackPage(function() H.tap("R1"); H.tap("DOWN"); H.tap("L1") end)   -- SUB, FAST
        M.Instruments:swapTrackInstrument(3, "harp")
        L:undo()
        H.eq(L.tracks[3].state.patch, "bass_sub", "patch")
        H.eq(L.tracks[3].state.glide, "FAST", "glide")
    end },

    -- ------------------------------------------------------------------
    -- B3: held notes, staccato, accent, mono / overlapping
    -- ------------------------------------------------------------------
    { "a held B note sustains while held and records its held length", function()
        local M, L, track = boot()
        local S = M.Synth
        H.tap("L2")
        H.hold("B"); H.play(1.0)
        H.eq(#S.sustainVoices, 1, "one voice sustaining")
        local v = S.sustainVoices[1]
        H.truthy(v.loopSrc.volume > 0 and not v.releasedAt, "holding at sustain")
        H.release("B"); H.play(0.3)
        H.tap("L2")
        H.eq(#S.sustainVoices, 0, "released and gone")
        H.eq(#track.events, 1, "one event")
        H.near(track.events[1].len / L:getTicksPerSecond(), 1.0, "len = time held", 0.04)
    end },

    { "a recorded held note sustains on playback for its length", function()
        local M, L, track = boot()
        local S = M.Synth
        H.tap("L2"); H.hold("B"); H.play(1.0); H.release("B"); H.play(0.05); H.tap("L2")
        H.play(0.5)
        local maxHeld, sounding = 0, 0
        for _ = 1, math.floor(L:getLoopDuration() * 60) do
            H.play(1 / 60)
            local held = 0
            for _, v in ipairs(S.sustainVoices) do if not v.releasedAt then held = held + 1 end end
            if held > 0 then sounding = sounding + 1 end
            maxHeld = math.max(maxHeld, held)
        end
        H.eq(maxHeld, 1, "one voice on playback")
        H.near(sounding / 60, 1.0, "held for about a second", 0.06)
    end },

    { "Y staccato lasts one grid step, however long it's held", function()
        local _, L, track = boot()
        H.tap("L2")
        H.hold("Y"); H.play(1.0); H.release("Y"); H.play(0.1)  -- held long
        H.play(0.3)
        H.hold("Y"); H.play(1 / 60); H.release("Y"); H.play(0.2) -- tapped very short
        H.tap("L2")
        H.eq(#track.events, 2, "two notes")
        for _, ev in ipairs(track.events) do H.eq(ev.len, 120, "one 1/16 (120 ticks)") end
        L:cycleGridMode(3); L:cycleGridMode(3); L:cycleGridMode(3); L:cycleGridMode(3)   -- 1/16 -> 1/8
        H.eq(L:getTrackGrid(3).id, "1/8", "grid 1/8")
        H.tap("L2"); H.play(0.5); H.hold("Y"); H.play(0.6); H.release("Y"); H.play(0.1); H.tap("L2")
        local last = track.events[#track.events]
        H.eq(last.len, 240, "follows the grid: one 1/8")
    end },

    { "X is an accent: full velocity, with vibrato", function()
        local M = boot()
        H.hold("X"); H.play(0.2)
        local v = M.Synth.sustainVoices[1]
        H.eq(v.vel, 1.0, "velocity")
        H.truthy(v.vibrato, "vibrato")
        H.release("X"); H.play(0.3)
    end },

    { "SAW is mono: a new press ends the held note right there", function()
        local M, L, track = boot()
        local S = M.Synth
        H.tap("L2")
        H.hold("B"); H.play(0.5)
        H.hold("X"); H.play(0.5)                       -- B still physically held
        local held = 0
        for _, v in ipairs(S.sustainVoices) do if not v.releasedAt then held = held + 1 end end
        H.eq(held, 1, "only the new note holds")
        H.release("B", "X"); H.play(0.3); H.tap("L2")
        local b, x
        for _, ev in ipairs(track.events) do if ev.action == "B" then b = ev else x = ev end end
        H.near(b.len / L:getTicksPerSecond(), 0.5, "B ends where X starts", 0.04)
        H.near(x.len / L:getTicksPerSecond(), 0.5, "X held 0.5 s", 0.04)
    end },

    { "PLUCK lets notes overlap", function()
        local M, L, track = boot()
        local S = M.Synth
        onTrackPage(function() H.tap("R1"); H.tap("R1") end)   -- PLUCK
        H.eq(track.state.patch, "bass_pluck", "pluck")
        H.tap("L2")
        H.hold("B"); H.play(0.5)
        H.hold("X"); H.play(0.5)
        local held = 0
        for _, v in ipairs(S.sustainVoices) do if not v.releasedAt then held = held + 1 end end
        H.eq(held, 2, "both notes hold")
        H.release("B", "X"); H.play(0.6); H.tap("L2")
        local b
        for _, ev in ipairs(track.events) do if ev.action == "B" then b = ev end end
        H.near(b.len / L:getTicksPerSecond(), 1.0, "B kept its full length", 0.04)
    end },

    { "muting stops a playing bass note", function()
        local M, L = boot()
        local S = M.Synth
        H.tap("L2"); H.hold("B"); H.play(2.0); H.release("B"); H.play(0.05); H.tap("L2")
        local t = 0
        while #S.sustainVoices == 0 and t < L:getLoopDuration() * 1.2 do H.play(1 / 60); t = t + 1 / 60 end
        H.eq(#S.sustainVoices, 1, "playing")
        H.hold("R2"); H.play(0.05); H.tap("Y"); H.release("R2")   -- R2 + Y mutes track 3
        H.play(0.3)
        H.truthy(L.tracks[3].muted, "muted")
        H.eq(#S.sustainVoices, 0, "stopped")
    end },

    -- ------------------------------------------------------------------
    -- B4: legato
    -- ------------------------------------------------------------------
    { "live legato takes over the held note's voice: no new attack, glides", function()
        local M = boot()
        local S = M.Synth
        H.hold("B"); H.play(0.3)
        local v = S.sustainVoices[1]
        local seen = triggersOf(S)
        H.hold("UP", "A"); H.play(0.02)                  -- degree 5 and legato in the same frame
        H.eq(#S.sustainVoices, 1, "still one voice")
        H.eq(S.sustainVoices[1], v, "the same voice")
        local attacks = 0
        for _, n in ipairs(seen) do if n == "bass" then attacks = attacks + 1 end end
        H.eq(attacks, 0, "no new attack")
        H.truthy(v.currentSemis < 7, "gliding, not jumping")
        H.play(0.6)
        H.near(v.currentSemis, 7, "arrives at G", 0.05)
        H.release("A", "B", "UP"); H.play(0.3)
    end },

    { "legato with nothing held glides up from the last note", function()
        local M = boot()
        local S = M.Synth
        H.hold("B"); H.play(0.2); H.release("B"); H.play(0.3)   -- last note: C
        H.hold("UP"); H.play(1 / 60)
        H.hold("A"); H.play(1 / 60)
        local v = S.sustainVoices[#S.sustainVoices]
        H.truthy(v.currentSemis < 3, "starts near C, not at G (" .. v.currentSemis .. ")")
        H.play(0.6)
        H.near(v.currentSemis, 7, "glides to G", 0.05)
        H.release("A", "UP"); H.play(0.3)
    end },

    { "recorded legato replays on one voice, without a new attack", function()
        local M, L = boot()
        local S = M.Synth
        H.tap("L2")
        H.hold("B"); H.play(0.5)
        H.hold("UP"); H.hold("A"); H.play(0.5)
        H.release("A", "B", "UP"); H.play(0.05)
        H.tap("L2")
        local attacks, maxVoices = 0, 0
        local seen = triggersOf(S)
        for _ = 1, math.floor(L:getLoopDuration() * 60) do
            H.play(1 / 60)
            maxVoices = math.max(maxVoices, #S.sustainVoices)
        end
        for _, n in ipairs(seen) do if n == "bass" then attacks = attacks + 1 end end
        H.eq(attacks, 1, "one attack for the B note only")
        H.eq(maxVoices, 1, "the A note reused B's voice")
    end },

    -- ------------------------------------------------------------------
    -- B5: bends (incl. the release tail)
    -- ------------------------------------------------------------------
    { "D-pad moves while holding glide and are recorded as bends", function()
        local M, L, track = boot()
        local S = M.Synth
        H.tap("L2")
        H.hold("B"); H.play(0.3)                          -- C
        H.hold("UP"); H.play(0.3)                         -- G (degree 5)
        local v = S.sustainVoices[1]
        H.near(v.currentSemis, 7, "glided to G", 0.1)
        H.release("UP"); H.hold("RIGHT"); H.play(0.3)     -- B (degree 7)
        H.release("RIGHT", "B"); H.play(0.05); H.tap("L2")
        local bend = track.events[1].bend
        H.truthy(bend and #bend >= 2, "keyframes recorded")
        H.eq(bend[1].degree, 5, "first: degree 5")
        H.eq(bend[1].semis, 7, "first: G")
        H.eq(bend[#bend].degree, 7, "last: degree 7")
        H.near(bend[1].dt / L:getTicksPerSecond(), 0.3, "first bend 0.3 s in", 0.04)
        H.truthy(bend[#bend].dt > bend[1].dt, "in order")
    end },

    { "octave changes while holding are bends too", function()
        local _, _, track = boot()
        H.tap("L2")
        H.hold("B"); H.play(0.2); H.hold("R1"); H.play(0.2); H.release("R1", "B"); H.play(0.05)
        H.tap("L2")
        local bend = track.events[1].bend
        H.eq(bend[1].octave, 1, "octave up")
        H.eq(bend[1].semis, 12, "C an octave up")
    end },

    { "after letting go, the fading note keeps following the D-pad, recorded after len", function()
        local M, L, track = boot()
        onTrackPage(function() H.tap("R1"); H.tap("R1") end)   -- PLUCK: long release
        H.tap("L2")
        H.hold("B"); H.play(0.4); H.release("B"); H.play(0.05)
        H.hold("UP"); H.play(0.15)                     -- still ringing
        local v = M.Synth.sustainVoices[1]
        H.truthy(v and v.releasedAt, "fading")
        H.truthy(v.targetSemis == 7, "tail follows the D-pad")
        H.release("UP"); H.play(0.6); H.tap("L2")
        local ev = track.events[1]
        H.truthy(ev.bend and #ev.bend >= 1, "tail bend recorded")
        H.truthy(ev.bend[1].dt > ev.len, "after len (" .. ev.bend[1].dt .. " > " .. ev.len .. ")")
    end },

    { "recorded bends replay at the same points, tail included", function()
        local M, L, track = boot()
        onTrackPage(function() H.tap("R1"); H.tap("R1") end)   -- PLUCK
        H.tap("L2")
        H.hold("B"); H.play(0.3); H.hold("UP"); H.play(0.3); H.release("UP")
        H.release("B"); H.play(0.05); H.hold("RIGHT"); H.play(0.1); H.release("RIGHT")
        H.play(0.6); H.tap("L2")
        local ev = track.events[1]
        local seenG, seenB = false, false
        for _ = 1, math.floor(L:getLoopDuration() * 60) do
            H.play(1 / 60)
            local p = track.state.playing[ev]
            if p then
                if p.semis == 7 then seenG = true end
                if p.semis == 11 then seenB = true end
            end
        end
        H.truthy(seenG, "held bend to G replayed")
        H.truthy(seenB, "tail bend to B replayed")
    end },

    { "letting go of the D-pad and button together doesn't drag the tail to the root", function()
        local M, _, track = boot()
        onTrackPage(function() H.tap("R1"); H.tap("R1") end)   -- PLUCK
        H.tap("L2")
        H.hold("B", "UP", "R1"); H.play(0.3)             -- G, an octave up
        H.release("B", "UP", "R1"); H.play(0.6)          -- all at once
        H.tap("L2")
        local ev = track.events[1]
        H.eq(ev.semis, 19, "the note is G an octave up")
        H.eq(ev.bend, nil, "no tail bend recorded")
    end },

    { "a mono note ends exactly where the next one starts", function()
        local _, L, track = boot()
        H.tap("L2")
        H.hold("B"); H.play(0.37); H.hold("X"); H.play(0.3); H.release("B", "X"); H.play(0.3)
        H.tap("L2")
        local b, x
        for _, ev in ipairs(track.events) do if ev.action == "B" then b = ev else x = ev end end
        H.eq((b.tick + b.len) % L:getLoopTicks(), x.tick, "no gap, no overlap")
    end },

    { "a normal press right after a note gets its own attack on playback", function()
        local M, L = boot()
        local S = M.Synth
        H.tap("L2")
        H.hold("B"); H.play(0.4); H.release("B")
        H.hold("UP", "A"); H.play(0.4); H.release("A", "UP"); H.play(0.05)   -- A without a held note
        H.tap("L2")
        local seen = triggersOf(S)
        for _ = 1, math.floor(L:getLoopDuration() * 60) do H.play(1 / 60) end
        local attacks = 0
        for _, n in ipairs(seen) do if n == "bass" then attacks = attacks + 1 end end
        H.eq(attacks, 2, "two attacks: it wasn't played legato")
    end },

    { "staccato notes bend too (newest note)", function()
        local _, _, track = boot()
        H.tap("L2")
        H.hold("Y"); H.play(1 / 60); H.hold("UP"); H.play(0.05); H.release("UP", "Y"); H.play(0.3)
        H.tap("L2")
        H.truthy(track.events[1].bend, "bend on the staccato note")
    end },

    -- ------------------------------------------------------------------
    -- B6: stage view data
    -- ------------------------------------------------------------------
    { "the view follows the live voice: trace samples its pitch, silence is empty", function()
        local M, _, track = boot()
        local Bass = M.Instruments:getDefinition("bass")
        local st = track.state
        H.eq(Bass:getDisplayVoice(st), nil, "idle: nothing sounding")
        H.hold("B"); H.play(0.3)
        local trace = Bass:getTrace(st)
        H.eq(#trace, Bass.TRACE_SAMPLES, "fixed length")
        H.near(trace[#trace].semis, 0, "newest sample at C", 0.01)
        H.truthy(trace[#trace].level > 0, "with a level")
        H.hold("UP"); H.play(0.5)
        trace = Bass:getTrace(st)
        H.near(trace[#trace].semis, 7, "followed the glide to G", 0.05)
        local mid = trace[#trace - 20].semis
        H.truthy(mid > 0, "earlier samples show the way up")
        H.release("B", "UP"); H.play(1.5)
        trace = Bass:getTrace(st)
        H.eq(trace[#trace], false, "silent again")
        H.eq(Bass:getDisplayVoice(st), nil, "nothing to show")
    end },

    { "the view follows playback when nothing is played live", function()
        local M, L, track = boot()
        local Bass = M.Instruments:getDefinition("bass")
        H.tap("L2"); H.hold("B"); H.play(1.0); H.release("B"); H.play(0.05); H.tap("L2")
        local seen = false
        for _ = 1, math.floor(L:getLoopDuration() * 60) do
            H.play(1 / 60)
            if Bass:getDisplayVoice(track.state) then seen = true end
        end
        H.truthy(seen, "playback voice shown")
    end },

    { "the oscilloscope follows the voice's real pitch and level", function()
        local M, _, track = boot()
        local st = track.state
        H.hold("B", "R1"); H.play(0.5)
        H.near(st.oscFreqRatio, 2.0, "an octave up = twice the speed", 0.01)
        H.truthy(st.oscAmp > 0.5, "loud while held")
        H.release("B", "R1"); H.play(1.0)
        H.truthy(st.oscAmp <= 0.1, "settles when silent")
    end },
}
