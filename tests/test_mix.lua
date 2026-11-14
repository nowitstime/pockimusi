-- Mix & FX finish (Phase G): master low-pass on R2 + LEFT, meters estimated
-- from the sounding voices, click modes and count-in, takes per loop pass.
local H = require("helpers")

-- Real synth with EFX "supported"; every source remembers its last filter
local function synth(efx)
    local M = H.fresh({ realSynth = true })
    local S = M.Synth
    S:init()
    S.fxSupported = (efx ~= false)
    local function spy(src) src.setFilter = function(self, f) self.filter = f or false end end
    for _, pool in pairs(S.pools) do for _, src in ipairs(pool.voices) do spy(src) end end
    for _, pool in pairs(S.loopPools) do for _, src in ipairs(pool.sources) do spy(src) end end
    return M, S, M.Looper.tracks
end

local function step(S, seconds)
    for _ = 1, math.floor(seconds * 60 + 0.5) do
        H.time = H.time + 1 / 60
        S:update(1 / 60)
    end
end

local function boot()
    local M = H.loadMain()
    M.Modes = require("src.modes")
    H.play(0.1)
    return M, M.Looper
end

local function seekTick(L, tick)
    L:seek(tick / L:getLoopTicks()); L.lastClockTime = H.time
end

local function playTo(L, tick)
    local guard = 0
    while L.tick < tick and guard < 3000 do H.play(1 / 60); guard = guard + 1 end
end

local function countClicks(M)
    local n = { value = 0 }
    local orig = M.Synth.trigger
    M.Synth.trigger = function(self, name, ...)
        if name == "perc_wood" then n.value = n.value + 1 end
        return orig(self, name, ...)
    end
    return n
end

return {
    -- ------------------------------------------------------------------
    -- G1: master low-pass
    -- ------------------------------------------------------------------
    { "R2 + LEFT closes a low-pass on everything sounding, and opens again", function()
        local M, S, tracks = synth()
        local hit = S:trigger("kick_808", 0, 0.8, 1.0, nil, 0.8, tracks[1])
        local held = S:noteOn("pad_warm", 0, 0.8, { track = tracks[4], bright = 0.5 })
        step(S, 0.05)
        H.falsy(hit.source.filter, "open: no filter")
        S.fxLowPass = true
        step(S, 0.05)
        local part = held.loopSrc.filter.highgain
        H.truthy(part < 1.0 and part > 0.5, "closing, not jumping (" .. part .. ")")
        step(S, 0.4)
        H.near(S.lpEnvelope, 1.0, "fully closed", 1e-9)
        H.near(held.loopSrc.filter.highgain, 1.0 - S.LP_DEPTH, "sustained voice filtered", 1e-6)
        H.near(held.brightSrc.filter.highgain, 1.0 - S.LP_DEPTH, "its bright layer too", 1e-6)
        H.eq(held.loopSrc.filter.type, "lowpass", "a low-pass")
        local late = S:trigger("perc_wood", 0, 0.8, 1.0, nil, 0.8, tracks[1])
        H.near(late.source.filter.highgain, 1.0 - S.LP_DEPTH, "a note started while closed is filtered", 1e-6)
        H.eq(S.duckEnvelope, 1.0, "no volume duck")
        S.fxLowPass = false
        step(S, 0.5)
        H.eq(S.lpEnvelope, 0.0, "open again")
        H.falsy(held.loopSrc.filter, "filter removed")
    end },

    { "the master sweep multiplies with a track's TONE, and leaves it when it opens", function()
        local M, S, tracks = synth()
        tracks[3].fx.on.tone, tracks[3].fx.tone = true, 0.5
        local v = S:noteOn("bass_saw", 0, 0.8, { track = tracks[3] })
        local tone = 1.0 - 0.5 * 0.97
        H.near(v.loopSrc.filter.highgain, tone, "tone alone", 1e-6)
        S.fxLowPass = true; step(S, 0.1)
        H.near(v.loopSrc.filter.highgain, tone * (1.0 - S.lpEnvelope * S.LP_DEPTH), "both", 1e-6)
        S.fxLowPass = false; step(S, 0.6)
        H.near(v.loopSrc.filter.highgain, tone, "tone stays", 1e-6)
    end },

    { "without EFX, R2 + LEFT ducks the volume instead", function()
        local M, S, tracks = synth(false)
        local v = S:noteOn("bass_saw", 0, 0.8, { track = tracks[3] })
        S.fxLowPass = true; step(S, 0.5)
        H.eq(S.lpEnvelope, 0.0, "no filter sweep")
        H.near(S.duckEnvelope, 0.22, "ducked", 1e-9)
        H.eq(v.loopSrc.filter, nil, "filter never touched")
        S.fxLowPass = false; step(S, 0.5)
        H.eq(S.duckEnvelope, 1.0, "back")
    end },

    -- ------------------------------------------------------------------
    -- G2: meters
    -- ------------------------------------------------------------------
    { "a hit raises its track's meter and the master's, then they fall", function()
        local M, S, tracks = synth()
        S:trigger("kick_808", 0, 0.85, 1.0, nil, 0.8, tracks[1])
        step(S, 1 / 60)
        local m = S.meters
        H.truthy(m[1].level > 0.4, "track 1 up (" .. m[1].level .. ")")
        H.near(m.master.level, m[1].level, "master the same", 1e-9)
        H.eq(m[2].level + m[3].level + m[4].level, 0, "other tracks at zero")
        local first = m[1].level
        step(S, 0.2)
        H.truthy(m[1].level < first, "falling")
        H.near(m[1].peak, first, "peak mark holds", 1e-9)
        step(S, 2.0)
        H.eq(m[1].level, 0.0, "silent")
        H.eq(m[1].peak, 0.0, "peak mark gone")
    end },

    { "a held note keeps its meter up; track volume scales it", function()
        local M, S, tracks = synth()
        local v = S:noteOn("bass_saw", 0, 0.85, { track = tracks[3] })
        step(S, 1.0)
        local level = S.meters[3].level
        H.truthy(level > 0.1, "up (" .. level .. ")")
        step(S, 2.0)
        H.near(S.meters[3].level, level, "steady while held", 1e-6)
        v:noteOff(); step(S, 1.0)
        H.eq(S.meters[3].level, 0.0, "falls after release")
        tracks[3].volume = tracks[3].volume * 0.5
        S:noteOn("bass_saw", 0, 0.85, { track = tracks[3] })
        step(S, 1.0)
        H.near(S.meters[3].level, level * 0.5, "half the volume, half the meter", 1e-6)
    end },

    { "tracks add up in the master (as power), and a click with no track counts there too", function()
        local M, S, tracks = synth()
        S:noteOn("bass_saw", 0, 0.85, { track = tracks[3] })
        S:noteOn("lead_square", 0, 0.85, { track = tracks[2] })
        step(S, 1.0)
        local a, b = S.meters[3].level, S.meters[2].level
        H.near(S.meters.master.level, math.sqrt(a * a + b * b), "power sum", 1e-6)
        local before = S.meters.master.level
        S:trigger("perc_wood", 0, 0.9, 0.8)
        step(S, 1 / 60)
        H.truthy(S.meters.master.level > before, "click shows on the master")
    end },

    { "the tape deck and Mix page draw the meters", function()
        local M, L = boot()
        H.tap("B")
        H.truthy(M.Synth.meters[1].level > 0, "drum hit on the meter")
        H.hold("SELECT", "R2"); H.play(0.2); H.release("SELECT", "R2"); H.play(0.1)
    end },

    -- ------------------------------------------------------------------
    -- G3: click modes and count-in
    -- ------------------------------------------------------------------
    { "Transport X cycles click off, on, count-in, on + count-in; saved", function()
        local M, L = boot()
        H.hold("START"); H.play(0.3)
        local seen = {}
        for i = 1, 4 do H.tap("X"); seen[i] = L:getClickMode() end
        H.eq(table.concat(seen, " | "), "ON | COUNT-IN | ON + COUNT-IN | OFF", "cycle")
        H.tap("X"); H.tap("X")
        H.release("START"); H.play(0.1)
        H.truthy(L.countIn and not L.clickOn, "count-in only")
        local data = assert(M.Save.decode(M.Save.encode(M.Session.snapshot())))
        L.countIn = false
        M.Session.restore(data)
        H.truthy(L.countIn, "count-in restored")
    end },

    { "with count-in, a record tap arms, counts and starts on the next bar line", function()
        local M, L = boot()
        L.countIn = true
        seekTick(L, 100)
        local clicks = countClicks(M)
        H.tap("L2")
        H.truthy(M.Modes.arm, "armed")
        H.eq(M.Modes.arm.target, 1920, "bar 2")
        H.falsy(M.Input.recLatched, "not recording yet")
        H.eq(M.Modes.current, "NORMAL", "still jam safe")
        H.tap("B")
        H.eq(#L.tracks[1].events, 0, "a hit during the count isn't recorded")
        playTo(L, 1000)
        H.eq(M.Modes:countInBeats(), 2, "two beats to go")
        playTo(L, 1750)
        H.truthy(M.Modes.arm, "still counting")
        H.eq(clicks.value, 3, "a click on each beat of the count")
        playTo(L, 1830)
        H.eq(M.Modes.arm, nil, "count over")
        H.truthy(M.Input.recLatched, "recording, a 1/16 before the bar line")
        playTo(L, 1880)
        H.hold("B"); H.play(0.03); H.release("B")            -- a touch early for beat 1
        H.eq(#L.tracks[1].events, 1, "recorded")
        H.eq(L.tracks[1].events[1].tick, 1920, "lands on the bar line")
        playTo(L, 2600)
        H.eq(clicks.value, 3, "no clicks after the count (click is off)")
        H.tap("L2")
        H.falsy(M.Input.recLatched, "tap stops as usual")
    end },

    { "a bar line under two beats away: the count goes to the one after", function()
        local M, L = boot()
        L.countIn = true
        seekTick(L, 1300)
        H.tap("L2")
        H.eq(M.Modes.arm.target, 0, "bar 1 of the next pass")
        playTo(L, 3700)
        H.truthy(M.Modes.arm, "counting through bar 2")
        while M.Modes.arm do H.play(1 / 60) end
        H.truthy(L.tick > 3700, "latched just before the loop's start")
        H.truthy(M.Input.recLatched, "recording")
    end },

    { "a second tap cancels the count-in; pausing does too", function()
        local M, L = boot()
        L.countIn = true
        seekTick(L, 100)
        H.tap("L2"); H.truthy(M.Modes.arm, "armed")
        H.tap("L2")
        H.eq(M.Modes.arm, nil, "cancelled")
        H.falsy(M.Input.recLatched, "not recording")
        H.falsy(L.counting, "clicks stop")
        H.tap("L2"); H.truthy(M.Modes.arm, "armed again")
        H.tap("START")
        H.eq(M.Modes.arm, nil, "pause cancels")
    end },

    { "from a paused clock the count-in starts one bar before the loop's start", function()
        local M, L = boot()
        L.countIn = true
        H.tap("START")
        H.falsy(L.playing, "paused")
        local clicks = countClicks(M)
        H.tap("L2")
        H.truthy(L.playing, "clock started")
        H.truthy(L.tick >= 1920 and L.tick < 2100, "in the last bar (" .. L.tick .. ")")
        H.eq(clicks.value, 1, "the first count sounds at once")
        while M.Modes.arm do H.play(1 / 60) end
        H.eq(clicks.value, 4, "four counts")
        H.truthy(M.Input.recLatched, "recording into bar 1")
    end },

    { "holding L2 still records at once, count-in or not", function()
        local M, L = boot()
        L.countIn = true
        H.hold("L2"); H.play(0.4)
        H.eq(M.Modes.current, "REC_HOLD", "punch-in")
        H.eq(M.Modes.arm, nil, "no count")
        H.tap("B")
        H.eq(#L.tracks[1].events, 1, "recorded")
        H.release("L2"); H.play(0.1)
        H.falsy(M.Input.recLatched, "and stops on release")
    end },

    -- ------------------------------------------------------------------
    -- G4: takes per loop pass
    -- ------------------------------------------------------------------
    { "each loop pass while recording is its own take; undo removes one pass", function()
        local M, L = boot()
        seekTick(L, 100)
        H.tap("L2")
        for _ = 1, 3 do
            H.tap("B")
            H.play(L:getLoopDuration() - 0.1 + 0.25)         -- a different spot each pass
        end
        H.tap("L2")
        local evs = L.tracks[1].events
        H.eq(#evs, 3, "three hits")
        H.truthy(evs[1].takeId ~= evs[2].takeId and evs[2].takeId ~= evs[3].takeId, "three takes")
        L:undo(); H.eq(#L.tracks[1].events, 2, "undo: the last pass only")
        L:undo(); H.eq(#L.tracks[1].events, 1, "then the one before")
        L:undo(); H.eq(#L.tracks[1].events, 0, "then the first")
    end },

    { "hits within one pass share a take; a note held across the boundary stays whole", function()
        local M, L = boot()
        seekTick(L, 100)
        H.tap("L2")
        H.tap("B"); H.play(0.5); H.tap("Y"); H.play(0.5); H.tap("A")
        local evs = L.tracks[1].events
        H.truthy(evs[1].takeId == evs[2].takeId and evs[2].takeId == evs[3].takeId, "one take")
        H.tap("L2")
        -- pad, held from before the pass boundary until after it
        for _ = 1, 3 do H.tap("SELECT") end
        seekTick(L, 100)
        H.tap("L2")
        H.play(L:getLoopDuration() - 0.6)
        H.hold("B"); H.play(0.9); H.release("B"); H.play(0.05)
        H.tap("L2")
        H.eq(#L.tracks[4].events, 1, "one note")
        H.near(L.tracks[4].events[1].len / L:getTicksPerSecond(), 0.9, "its whole length", 0.05)
    end },
}
