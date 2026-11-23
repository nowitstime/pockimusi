-- Wobble (PHASE_L L9): face buttons hold chord notes, the D-pad sets how fast
-- the tone moves (the bright layer), locked to the beat; recorded and replayed.
local H = require("helpers")

local function boot()
    local M = H.loadMain()
    H.play(0.1)
    M.Instruments:swapTrackInstrument(3, "wobble")
    M.Looper.undoStack = {}
    H.tap("SELECT"); H.tap("SELECT")
    return M, M.Looper, M.Looper.tracks[3].state
end

local function seekTick(L, tick)
    L:seek(tick / L:getLoopTicks()); L.lastClockTime = H.time
end

-- Every voice the wobble starts from now on
local function watch(M)
    local voices = {}
    local orig = M.Synth.noteOn
    M.Synth.noteOn = function(self, patch, semis, ...)
        local v = orig(self, patch, semis, ...)
        voices[#voices + 1] = { v = v, semis = semis, patch = patch }
        return v
    end
    return voices
end

-- The voice's tone sampled every frame for `seconds`: min, max, samples
local function sampleTone(v, seconds)
    local lo, hi, s = 1, 0, {}
    for _ = 1, math.floor(seconds * 60 + 0.5) do
        H.play(1 / 60)
        lo, hi = math.min(lo, v.brightNow), math.max(hi, v.brightNow)
        s[#s + 1] = v.brightNow
    end
    return lo, hi, s
end

-- How many times the tone turns from rising to falling in the samples
local function peaks(s)
    local n = 0
    for i = 2, #s - 1 do
        if s[i] > s[i - 1] and s[i] >= s[i + 1] then n = n + 1 end
    end
    return n
end

return {
    { "Wobble is in the BASS group, offers only patches with a bright layer, opens on NEURO", function()
        local M, L, st = boot()
        local def = M.Instruments.byId.wobble
        H.eq(def.group, "BASS", "group")
        H.eq(st.patch, "bass_neuro", "NEURO")
        local ids = require("src.instruments.patches").list(def)
        H.truthy(#ids >= 3, "some patches: " .. #ids)
        for _, id in ipairs(ids) do
            H.truthy(M.Synth.patches[id].bright, id .. " has a bright layer")
        end
    end },

    { "B Y X A play the root, 3rd, 5th and octave of the chord", function()
        local M, L, st = boot()
        local voices = watch(M)
        for _, btn in ipairs({ "B", "Y", "X", "A" }) do
            H.hold(btn); H.play(0.05); H.release(btn); H.play(0.2)
        end
        local got = {}
        for i, e in ipairs(voices) do got[i] = e.semis end
        H.eq(table.concat(got, " "), "0 4 7 12", "C E G C")
    end },

    { "the tone moves at the D-pad's rate; neutral keeps it; DOWN closes it", function()
        local M, L, st = boot()
        local voices = watch(M)
        seekTick(L, 0)
        H.hold("RIGHT"); H.play(1 / 60)                  -- 1/16
        H.hold("B"); H.play(0.05)
        local v = voices[1].v
        H.eq(st.rate, "1/16", "rate from the D-pad")
        local lo, hi, s16 = sampleTone(v, 1.0)
        H.truthy(lo < 0.2 and hi > 0.8, string.format("opens and closes: %.2f..%.2f", lo, hi))
        H.release("RIGHT"); H.play(1 / 60)
        H.eq(st.rate, "1/16", "neutral keeps the rate")
        H.hold("UP"); H.play(1 / 60)                     -- 1/4
        local _, _, s4 = sampleTone(v, 1.0)
        H.truthy(peaks(s16) > peaks(s4) * 2, "1/16 wobbles faster than 1/4: " .. peaks(s16) .. " vs " .. peaks(s4))
        H.release("UP"); H.hold("DOWN"); H.play(1 / 60)
        lo, hi = sampleTone(v, 0.5)
        H.truthy(hi < 0.1, "DOWN: closed, no wobble (" .. hi .. ")")
        H.release("DOWN", "B"); H.play(0.1)
    end },

    { "both shoulders open the tone fully", function()
        local M, L, st = boot()
        local voices = watch(M)
        H.hold("DOWN"); H.play(1 / 60)
        H.hold("B"); H.play(0.1)
        H.hold("L1", "R1"); H.play(0.1)
        H.near(voices[1].v.brightNow, 1.0, "open")
        H.eq(voices[1].semis, 0, "and the octave doesn't move")
        H.release("L1", "R1", "DOWN", "B"); H.play(0.1)
    end },

    { "SQUARE flips between closed and open", function()
        local M, L, st = boot()
        st.shape = "SQUARE"
        local voices = watch(M)
        H.hold("UP"); H.play(1 / 60)
        H.hold("B"); H.play(0.05)
        local _, _, s = sampleTone(voices[1].v, 1.0)
        for _, b in ipairs(s) do
            H.truthy(b < 0.05 or b > 0.99, "only the two levels: " .. b)
        end
        H.release("UP", "B"); H.play(0.1)
    end },

    { "a new note while one is held glides on the same voice", function()
        local M, L, st = boot()
        local voices = watch(M)
        H.hold("B"); H.play(0.1)
        H.hold("X"); H.play(0.1)
        H.eq(#voices, 1, "no new attack")
        H.eq(voices[1].v.targetSemis, 7, "gliding to the 5th")
        H.release("X", "B"); H.play(0.1)
    end },

    { "rate changes while holding are recorded and replay", function()
        local M, L, st = boot()
        seekTick(L, 0)
        H.tap("L2")
        seekTick(L, 0)
        H.hold("DOWN"); H.play(1 / 60)
        H.hold("B"); H.play(0.2)
        H.release("DOWN"); H.hold("RIGHT"); H.play(0.4)
        H.release("RIGHT", "B"); H.play(0.05)
        H.tap("L2")
        local ev = L.tracks[3].events[1]
        H.truthy(ev, "a note")
        H.eq(ev.rate, "CLOSED", "it started closed")
        local found
        for _, kf in ipairs(ev.bend or {}) do if kf.rate == "1/16" then found = kf end end
        H.truthy(found, "the change to 1/16 is a keyframe")
        -- playback: closed first, wobbling after the keyframe
        local voices = watch(M)
        st.rate = "UP"                                    -- the live D-pad no longer matters
        seekTick(L, L:getLoopTicks() - 10)
        H.play(0.1)
        local v = voices[1] and voices[1].v
        H.truthy(v, "the note plays back")
        local lo, hi = sampleTone(v, 0.08)
        H.truthy(hi < 0.1, "closed at first: " .. hi)
        lo, hi = sampleTone(v, 0.4)
        H.truthy(hi > 0.5, "then wobbling: " .. hi)
    end },

    { "Track page rows; saved and loaded", function()
        local M, L, st = boot()
        local def = M.Instruments.byId.wobble
        local rows = M.Instruments:getSoundRows(def, st, L.tracks[3])
        local keys = {}
        for i = 1, 6 do keys[i] = rows[i].key end
        H.eq(table.concat(keys, " "), "PATCH SHAPE DEPTH GLIDE FOLLOW PUMP", "rows")
        def:cycleSetting(st, "SHAPE", 1); def:cycleSetting(st, "DEPTH", -1)
        H.eq(st.shape, "SAW", "shape steps"); H.eq(st.depth, "MEDIUM", "depth steps")
        st.patch = "bass_reese"
        local snap = M.Session.snapshot()
        H.truthy(M.Session.restore(snap), "restored")
        local s2 = L.tracks[3].state
        H.eq(s2.shape, "SAW", "shape"); H.eq(s2.depth, "MEDIUM", "depth"); H.eq(s2.patch, "bass_reese", "patch")
        snap.tracks[3].settings.patch = "bass_saw"        -- no bright layer
        M.Session.restore(snap)
        H.eq(L.tracks[3].state.patch, "bass_neuro", "a patch it can't play is not loaded")
    end },
}
