-- Lead / Arp (Phase F): held notes like the bass, arps locked to the clock
-- that follow the chords, recorded as ordinary notes; Bass <-> Lead swaps.
local H = require("helpers")

-- Track 3 swapped to Lead and active
local function boot()
    local M = H.loadMain()
    M.Harmony = require("src.harmony")
    H.play(0.1)
    M.Instruments:swapTrackInstrument(3, "lead")
    M.Looper.undoStack = {}
    H.tap("SELECT"); H.tap("SELECT")
    return M, M.Looper, M.Looper.tracks[3].state
end

local function chordEv(M, dir, tick)
    local Harp = M.Instruments:getDefinition("harp")
    local c = M.Theory:getChordForDirection(dir, false, false)
    return { tick = tick, len = 0, action = "B", semis = c.notes[1], vel = 0.8, chord = Harp:chordData(c) }
end

local function chordLoop(M, L)
    L.tracks[2].events = {
        chordEv(M, "NEUTRAL", 0), chordEv(M, "DOWN", 960), chordEv(M, "LEFT", 1920), chordEv(M, "RIGHT", 2880),
    }
end

local function seekTick(L, tick)
    L:seek(tick / L:getLoopTicks()); L.lastClockTime = H.time
end

-- Collect every lead note started from now on: { semis, tick }
local function watch(M, L)
    local notes = {}
    local orig = M.Synth.noteOn
    M.Synth.noteOn = function(self, patch, semis, ...)
        if patch:find("^lead") then notes[#notes + 1] = { semis = semis, tick = L.tick } end
        return orig(self, patch, semis, ...)
    end
    return notes
end

local function semisOf(notes, n)
    local out = {}
    for i = 1, math.min(n or #notes, #notes) do out[i] = notes[i].semis end
    return table.concat(out, " ")
end

-- Hold an arp button from just after a grid step until `count` notes have played
local function arp(M, L, btn, count, dirs)
    seekTick(L, 2)
    local notes = watch(M, L)
    for _, d in ipairs(dirs or {}) do H.hold(d) end
    H.play(1 / 60)
    H.hold(btn)
    local guard = 0
    while #notes < count and guard < 3000 do H.play(1 / 60); guard = guard + 1 end
    H.release(btn); for _, d in ipairs(dirs or {}) do H.release(d) end
    H.play(0.05)
    return notes
end

return {
    -- ------------------------------------------------------------------
    -- The arp's notes
    -- ------------------------------------------------------------------
    { "arp up, down and up-down through the chord", function()
        local M, L, st = boot()
        H.eq(semisOf(arp(M, L, "A", 6)), "0 4 7 0 4 7", "up")
        H.eq(semisOf(arp(M, L, "Y", 6)), "7 4 0 7 4 0", "down")
        H.eq(semisOf(arp(M, L, "X", 9)), "0 4 7 4 0 4 7 4 0", "up-down, ends not repeated")
    end },

    { "ARP PATTERN: two octaves, sevenths, the scale", function()
        local M, L, st = boot()
        st.pattern = "CHORD 2 OCT"
        H.eq(semisOf(arp(M, L, "A", 7)), "0 4 7 12 16 19 0", "chord, 2 octaves")
        H.eq(semisOf(arp(M, L, "X", 11)), "0 4 7 12 16 19 16 12 7 4 0", "up-down, 2 octaves")
        st.pattern = "7TH"
        H.eq(semisOf(arp(M, L, "A", 5)), "0 4 7 11 0", "seventh")
        st.pattern = "SCALE"
        H.eq(semisOf(arp(M, L, "Y", 7)), "11 9 7 5 4 2 0", "scale, down")
    end },

    { "the D-pad degree is where the arp starts", function()
        local M, L, st = boot()
        H.eq(semisOf(arp(M, L, "A", 3, { "UP" })), "7 12 16", "from the 5th: an inversion")
        H.eq(semisOf(arp(M, L, "A", 3, { "DOWN" })), "-5 0 4", "from the 5th below")
        H.eq(semisOf(arp(M, L, "A", 3, { "LEFT" })), "4 7 12", "from the 3rd")
        H.eq(semisOf(arp(M, L, "A", 3, { "UP", "LEFT" })), "4 7 12", "4 isn't in the chord: from the 3rd under it")
        H.eq(semisOf(arp(M, L, "A", 3, { "R1" })), "12 16 19", "R1: an octave up")
    end },

    { "notes too high for the voices drop an octave", function()
        local M, L, st = boot()
        M.Theory.rootIndex = 12                              -- B
        st.pattern = "CHORD 2 OCT"
        local notes = arp(M, L, "A", 6, { "R1" })
        for _, n in ipairs(notes) do
            H.truthy(n.semis <= M.Instruments:getDefinition("lead").TOP_SEMIS, "in range: " .. n.semis)
        end
    end },

    -- ------------------------------------------------------------------
    -- Timing
    -- ------------------------------------------------------------------
    { "steps land on the grid at each rate, and at double rate with both shoulders", function()
        local M, L, st = boot()
        local function spacing(rate, dirs)
            st.rate = rate
            local notes = arp(M, L, "A", 5, dirs)
            for i = 2, 5 do
                local step = notes[i].tick - notes[i - 1].tick
                if i == 2 then step = notes[2].tick end      -- the first one came from the press at tick ~2
                H.truthy(i == 2 or math.abs(step - spacing_) < 20, rate .. " step " .. step)
            end
        end
        for rate, ticks in pairs({ ["1/8"] = 240, ["1/16"] = 120, ["1/8T"] = 160 }) do
            spacing_ = ticks; spacing(rate)
            spacing_ = ticks / 2; spacing(rate, { "L1", "R1" })
        end
        spacing_ = nil
    end },

    { "both shoulders double the rate without changing the octave", function()
        local M, L, st = boot()
        H.eq(semisOf(arp(M, L, "A", 3, { "L1", "R1" })), "0 4 7", "middle octave")
    end },

    { "the track's swing pushes the arp's off-steps late", function()
        local M, L, st = boot()
        L.tracks[3].swing = 0.66
        local notes = arp(M, L, "A", 4)
        local late = (0.66 - 0.5) * 2 * 120
        H.near(notes[2].tick, 120 + late, "step 1 late", 18)
        H.near(notes[3].tick, 240, "step 2 on the grid", 18)
        H.near(notes[4].tick, 360 + late, "step 3 late", 18)
    end },

    { "a press between steps starts on the next step; a press just before one sounds at once", function()
        local M, L, st = boot()
        local notes = watch(M, L)
        seekTick(L, 60)                                      -- 65 ms from either step
        H.hold("A"); H.play(1 / 60)
        H.eq(#notes, 0, "waits")
        H.play(0.1)
        H.eq(#notes, 1, "plays on the step")
        H.near(notes[1].tick, 120, "at the step", 18)
        H.release("A"); H.play(0.05)

        notes = watch(M, L)
        seekTick(L, 100)                                     -- 22 ms before step 1
        H.hold("A"); H.play(1 / 60)
        H.eq(#notes, 1, "sounds at once")
        H.play(0.06)
        H.eq(#notes, 1, "and stands in for that step (no double)")
        H.play(0.12)
        H.eq(#notes, 2, "then the next step")
        H.release("A"); H.play(0.05)
    end },

    { "releasing stops the arp; with two held, the newest is in charge", function()
        local M, L, st = boot()
        local notes = arp(M, L, "A", 3)
        local n = #notes
        H.play(0.5)
        H.eq(#notes, n, "no notes after the release")
        H.eq(st.arpBtn, nil, "idle")
        H.hold("A"); H.play(0.2); H.hold("Y"); H.play(0.05)
        H.eq(st.arpBtn, "Y", "newest")
        H.release("Y"); H.play(0.05)
        H.eq(st.arpBtn, "A", "back to the one still held")
        H.release("A"); H.play(0.05)
    end },

    { "the arp runs with the clock paused", function()
        local M, L, st = boot()
        L:setPlaying(false)
        local notes = watch(M, L)
        H.hold("A"); H.play(0.5); H.release("A"); H.play(0.05)
        H.truthy(#notes >= 4 and #notes <= 5, "about one per 1/16 (" .. #notes .. ")")
        H.eq(semisOf(notes, 3), "0 4 7", "in order")
    end },

    -- ------------------------------------------------------------------
    -- Recording and follow
    -- ------------------------------------------------------------------
    { "each arp step is recorded as one note on the arp's grid", function()
        local M, L, st = boot()
        H.tap("L2")
        arp(M, L, "A", 4)
        H.tap("L2")
        local evs = L.tracks[3].events
        H.eq(#evs, 4, "four notes")
        table.sort(evs, function(a, b) return a.tick < b.tick end)
        for i, ev in ipairs(evs) do
            H.eq(ev.tick, (i - 1) * 120, "on the 1/16 grid")
            H.eq(ev.len, 96, "80% of a step")
            H.eq(ev.grid, 120, "grid (for swing)")
            H.eq(ev.action, "A", "action")
            H.eq(ev.open, nil, "closed"); H.eq(ev.overrideGridSteps, nil, "no leftover field")
        end
        H.eq(evs[2].degree, 3, "degree stored"); H.eq(evs[2].semis, 4, "pitch stored")
        H.truthy(evs[1].vel > evs[2].vel, "first of the pass accented")
    end },

    { "a held arp follows the chords, live and on playback", function()
        local M, L, st = boot()
        chordLoop(M, L)
        local allowed = { [0] = { [0] = 1, [4] = 1, [7] = 1 }, { [-3] = 1, [0] = 1, [4] = 1 },
                          { [5] = 1, [9] = 1, [12] = 1 }, { [-5] = 1, [-1] = 1, [2] = 1 } }
        local function check(notes, what)
            H.truthy(#notes >= 28, what .. ": a full loop of notes (" .. #notes .. ")")
            for _, n in ipairs(notes) do
                local q = math.floor(((n.tick + 60) % 3840) / 960)
                H.truthy(allowed[q][n.semis], string.format("%s: %d at tick %d", what, n.semis, n.tick))
            end
        end
        H.tap("L2")
        seekTick(L, 2)
        local notes = watch(M, L)
        H.hold("A")
        while L.tick < 3800 do H.play(1 / 60) end
        H.release("A"); H.play(0.02)
        H.tap("L2")
        check(notes, "live")
        -- playback
        notes = watch(M, L)
        seekTick(L, 3830)
        H.play(L:getLoopDuration() * 0.98)
        check(notes, "playback")
        -- new chords: the recording re-harmonises
        L.tracks[2].events = { chordEv(M, "LEFT", 0) }
        L:silenceAll()
        notes = watch(M, L)
        seekTick(L, 3830)
        H.play(L:getLoopDuration() * 0.5)
        for _, n in ipairs(notes) do H.truthy(allowed[2][n.semis], "all F now: " .. n.semis) end
    end },

    -- ------------------------------------------------------------------
    -- B: held notes
    -- ------------------------------------------------------------------
    { "B holds a note an octave above the bass's patch, and D-pad moves glide and record", function()
        local M, L, st = boot()
        H.tap("L2")
        H.hold("B"); H.play(0.3)
        local h = st.handles[#st.handles]
        local v = st.voices[h.ev]
        H.eq(v.patch.label, "SQUARE", "lead patch")
        H.eq(v.targetSemis, 0, "the root")
        H.hold("UP"); H.play(0.3)
        H.eq(v.targetSemis, 7, "glides to the 5th")
        H.release("UP", "B"); H.play(0.05)
        H.tap("L2")
        local ev = L.tracks[3].events[1]
        H.truthy(ev.len > 0 and ev.bend and ev.bend[1].semis == 7, "one note with a bend")
    end },

    { "the arp ends a held B note (mono)", function()
        local M, L, st = boot()
        H.hold("B"); H.play(0.2)
        local v = st.voices[st.handles[#st.handles].ev]
        seekTick(L, 2)
        H.hold("A"); H.play(0.05)
        H.truthy(v.releasedAt ~= nil, "B note released")
        H.release("A", "B"); H.play(0.1)
    end },

    -- ------------------------------------------------------------------
    -- Rows, saves, swaps
    -- ------------------------------------------------------------------
    { "Track page rows: PATCH, FOLLOW, ARP RATE, ARP PATTERN; saved and loaded", function()
        local M, L, st = boot()
        H.hold("SELECT"); H.play(0.3)
        H.tap("R1");                H.eq(st.patch, "lead_saw", "patch")
        H.tap("DOWN"); H.tap("R1"); H.falsy(st.follow, "follow off")
        H.tap("DOWN"); H.tap("R1"); H.eq(st.rate, "1/8T", "rate")
        H.tap("DOWN"); H.tap("L1"); H.eq(st.pattern, "SCALE", "pattern wraps")
        H.release("SELECT"); H.play(0.1)
        local data = assert(M.Save.decode(M.Save.encode(M.Session.snapshot())))
        H.truthy(M.Session.restore(data), "restored")
        local st2 = L.tracks[3].state
        H.eq(L.tracks[3].instrumentId, "lead", "lead")
        H.eq(st2.patch .. " " .. st2.rate .. " " .. st2.pattern, "lead_saw 1/8T SCALE", "rows")
        H.falsy(st2.follow, "follow")
    end },

    { "Bass <-> Lead swaps keep the notes; undo restores; other swaps clear", function()
        local M, L = boot()
        local I = M.Instruments
        H.tap("L2"); arp(M, L, "A", 4); H.tap("L2")
        L.tracks[3].gridIndex = 2
        I:swapTrackInstrument(3, "bass")
        H.eq(L.tracks[3].instrumentId, "bass", "bass")
        H.eq(#L.tracks[3].events, 4, "notes kept")
        H.eq(L.tracks[3].gridIndex, 2, "grid kept")
        H.eq(L.tracks[3].state.patch, "bass_saw", "the bass's own sound")
        -- they play: the bass sounds them through its patch
        local started = 0
        local orig = M.Synth.noteOn
        M.Synth.noteOn = function(self, patch, ...)
            if patch:find("^bass") then started = started + 1 end
            return orig(self, patch, ...)
        end
        seekTick(L, 3830); H.play(1.0)
        M.Synth.noteOn = orig
        H.eq(started, 4, "played by the bass")
        -- the new track's notes are its own
        table.remove(L.tracks[3].events)
        L:undo()
        H.eq(L.tracks[3].instrumentId, "lead", "undo: lead back")
        H.eq(#L.tracks[3].events, 4, "with all its notes")
        I:swapTrackInstrument(3, "pad")
        H.eq(#L.tracks[3].events, 0, "a pad starts empty")
    end },
}
