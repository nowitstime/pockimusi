-- Roller (PHASE_L L5): pitched note repeat locked to the clock; the D-pad and
-- shoulders set the next repeat's note; every repeat recorded as a note.
local H = require("helpers")

-- Track 3 swapped to Roller and active
local function boot()
    local M = H.loadMain()
    H.play(0.1)
    M.Instruments:swapTrackInstrument(3, "roller")
    M.Looper.undoStack = {}
    H.tap("SELECT"); H.tap("SELECT")
    return M, M.Looper, M.Looper.tracks[3].state
end

local function seekTick(L, tick)
    L:seek(tick / L:getLoopTicks()); L.lastClockTime = H.time
end

-- Collect every note the roller starts from now on: { semis, tick, vel }
local function watch(M, L)
    local notes = {}
    local orig = M.Synth.noteOn
    M.Synth.noteOn = function(self, patch, semis, vel, ...)
        notes[#notes + 1] = { semis = semis, tick = L.tick, vel = vel }
        return orig(self, patch, semis, vel, ...)
    end
    return notes
end

-- Hold a roll button from just after a grid step until `count` notes played.
-- `during(i)` runs before each frame with the notes so far (to move the D-pad).
local function roll(M, L, btn, count, dirs, during)
    seekTick(L, 2)
    local notes = watch(M, L)
    for _, d in ipairs(dirs or {}) do H.hold(d) end
    H.play(1 / 60)
    H.hold(btn)
    local guard = 0
    while #notes < count and guard < 3000 do
        if during then during(#notes) end
        H.play(1 / 60); guard = guard + 1
    end
    H.release(btn); for _, d in ipairs(dirs or {}) do H.release(d) end
    H.play(0.05)
    return notes
end

local function spacingOk(notes, ticks, from)
    for i = (from or 3), #notes do
        local step = notes[i].tick - notes[i - 1].tick
        if math.abs(step - ticks) >= 20 then return false, step end
    end
    return true
end

return {
    { "Roller is in the catalogue, in the BASS group, on REESE", function()
        local M, L, st = boot()
        local def = M.Instruments.byId.roller
        H.truthy(def, "registered")
        H.eq(def.group, "BASS", "BASS group")
        H.eq(L.tracks[3].instrumentId, "roller", "on track 3")
        H.eq(st.patch, "bass_reese", "opens on REESE")
    end },

    { "each button rolls at its rate; both shoulders double it", function()
        local M, L, st = boot()
        for btn, ticks in pairs({ B = 120, A = 240, Y = 160, X = 120 }) do
            local notes = roll(M, L, btn, 5)
            local ok, bad = spacingOk(notes, ticks)
            H.truthy(ok, btn .. " every " .. ticks .. " ticks, got " .. tostring(bad))
            notes = roll(M, L, btn, 5, { "L1", "R1" })
            ok, bad = spacingOk(notes, ticks / 2)
            H.truthy(ok, btn .. " doubled: every " .. (ticks / 2) .. ", got " .. tostring(bad))
            H.eq(notes[3].semis, 0, btn .. " doubled stays in the home octave")
        end
    end },

    { "every repeat is the same note until the D-pad moves; then the next repeat takes it", function()
        local M, L, st = boot()
        local notes = roll(M, L, "B", 6, nil, function(n)
            if n == 3 then H.hold("UP") end            -- the 5th from the 4th repeat on
        end)
        H.release("UP")
        H.eq(notes[1].semis, 0, "root"); H.eq(notes[3].semis, 0, "still the root")
        H.eq(notes[4].semis, 7, "the next repeat takes the 5th")
        H.eq(notes[6].semis, 7, "and keeps it")
        notes = roll(M, L, "B", 4, nil, function(n) if n == 2 then H.hold("R1") end end)
        H.release("R1")
        H.eq(notes[2].semis, 0, "before R1"); H.eq(notes[3].semis, 12, "R1: next repeat an octave up")
    end },

    { "X accents the off-beats", function()
        local M, L, st = boot()
        local notes = roll(M, L, "X", 6)
        local def = M.Instruments.byId.roller
        for i = 2, 6 do
            local onBeat = (math.floor(notes[i].tick / 120 + 0.5) % 2 == 0)
            H.near(notes[i].vel, onBeat and def.VEL_ON or def.VEL_OFF, "repeat " .. i .. (onBeat and " on" or " off"))
        end
    end },

    { "releasing stops the roll; with two held, the newest is in charge", function()
        local M, L, st = boot()
        seekTick(L, 2)
        local notes = watch(M, L)
        H.hold("B"); H.play(0.2)
        H.hold("A"); H.play(0.05)
        H.eq(st.rollBtn, "A", "the newest held button")
        H.release("A"); H.play(0.05)
        H.eq(st.rollBtn, "B", "back to the one still held")
        H.release("B"); H.play(0.05)
        H.eq(st.rollBtn, nil, "stopped")
        local n = #notes
        H.play(0.5)
        H.eq(#notes, n, "nothing more")
    end },

    { "the roll runs with the clock paused", function()
        local M, L, st = boot()
        L:setPlaying(false)
        local notes = watch(M, L)
        H.hold("B"); H.play(0.5); H.release("B"); H.play(0.05)
        H.truthy(#notes >= 4 and #notes <= 5, "about one per 1/16 (" .. #notes .. ")")
    end },

    { "each repeat is recorded as one note on the roll's grid, LENGTH sets its length", function()
        local M, L, st = boot()
        H.tap("L2")
        roll(M, L, "A", 4)
        H.tap("L2")
        local evs = L.tracks[3].events
        H.eq(#evs, 4, "four notes")
        table.sort(evs, function(a, b) return a.tick < b.tick end)
        for i, ev in ipairs(evs) do
            H.eq(ev.tick, (i - 1) * 240, "on the 1/8 grid")
            H.eq(ev.len, 120, "HALF: half a step")
            H.eq(ev.grid, 240, "grid (for swing)")
            H.eq(ev.action, "A", "action")
            H.eq(ev.open, nil, "closed")
        end
        L.tracks[3].events = {}
        st.length = "SHORT"
        H.tap("L2"); roll(M, L, "B", 2); H.tap("L2")
        H.eq(L.tracks[3].events[1].len, 36, "SHORT: 30% of a 1/16")
    end },

    { "recorded repeats play back", function()
        local M, L, st = boot()
        H.tap("L2"); roll(M, L, "B", 4, { "LEFT" }); H.tap("L2")
        local notes = watch(M, L)
        H.play(H.loopSeconds(L) + 0.1)
        local thirds = 0
        for _, n in ipairs(notes) do if n.semis == 4 then thirds = thirds + 1 end end
        H.truthy(thirds >= 4, "the four 3rds come back on playback (" .. thirds .. ")")
    end },

    { "Track page rows: PATCH, FOLLOW, LENGTH, PUMP; saved and loaded", function()
        local M, L, st = boot()
        local def = M.Instruments.byId.roller
        local rows = M.Instruments:getSoundRows(def, st, L.tracks[3])
        local keys = {}
        for i = 1, 4 do keys[i] = rows[i].key end
        H.eq(table.concat(keys, " "), "PATCH FOLLOW LENGTH PUMP", "rows")
        def:cycleSetting(st, "LENGTH", 1)
        H.eq(st.length, "FULL", "LENGTH steps")
        st.patch = "bass_dnbsub"
        st.follow = false
        local snap = M.Session.snapshot()
        H.truthy(M.Session.restore(snap), "restored")
        local st2 = L.tracks[3].state
        H.eq(L.tracks[3].instrumentId, "roller", "still the roller")
        H.eq(st2.length, "FULL", "length kept")
        H.eq(st2.patch, "bass_dnbsub", "patch kept")
        H.eq(st2.follow, false, "follow kept")
    end },

    { "Bass <-> Roller swaps keep the notes", function()
        local M, L, st = boot()
        H.tap("L2"); roll(M, L, "B", 3); H.tap("L2")
        M.Instruments:swapTrackInstrument(3, "bass")
        H.eq(#L.tracks[3].events, 3, "the bass keeps the roll's notes")
        M.Instruments:swapTrackInstrument(3, "roller")
        H.eq(#L.tracks[3].events, 3, "and back")
    end },
}
