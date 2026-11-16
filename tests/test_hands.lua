-- HAND DRUMS (lab/HANDS.md): the D-pad as four more pads, by position;
-- L1 ghost, R1 accent, both = note repeat. Built on Drums. This file runs
-- because "hands" is a reserved lab id (tests/run.lua).
local H = require("helpers")

local function boot()
    local M = H.loadMain()
    H.play(0.1)
    M.Instruments:swapTrackInstrument(1, "hands")
    M.Looper.activeTrack = 1
    M.Hands = M.Instruments.byId.hands
    M.Drums = M.Instruments:getDefinition("drums")
    return M, M.Looper, M.Looper.tracks[1].state
end

-- Every trigger from now on: { name, vol }
local function watch(M)
    local hits = {}
    local orig = M.Synth.trigger
    M.Synth.trigger = function(self, name, semis, vol, ...)
        hits[#hits + 1] = { name = name, vol = vol }
        return orig(self, name, semis, vol, ...)
    end
    return hits
end

local function count(events)
    local n = { B = 0, A = 0, Y = 0, X = 0 }
    for _, ev in ipairs(events) do n[ev.action] = (n[ev.action] or 0) + 1 end
    return n
end

return {
    { "HAND DRUMS is a lab instrument built on Drums, drawn by the drum lanes", function()
        local M = H.fresh()
        local def = M.Instruments.byId.hands
        H.truthy(def, "registered")
        H.truthy(def.lab, "marked lab")
        H.eq(def.shortName, "HANDS", "short name")
        H.eq(def.viewKind, "drums", "the four lanes")
        H.eq(def.eventClass, "drums", "the Drums' event class")
        H.eq(def.KITS, M.Instruments.byId.drums.KITS, "the Drums' kits")
        local Chrome = require("src.ui.chrome")
        local dpad = Chrome:getInstrumentLabels(def, def:newState())
        H.eq(dpad.UP, "X", "D-pad labels name the pads"); H.eq(dpad.RIGHT, "A", "D-pad labels name the pads")
        M.Config.LAB = false
        M.Instruments:buildCatalog()
        H.falsy(M.Instruments.byId.hands, "gone with the lab off")
    end },

    { "UP DOWN LEFT RIGHT play the sounds of X B Y A and record under those actions", function()
        local M, L, st = boot()
        local hits = watch(M)
        H.tap("L2")
        H.tap("UP"); H.play(0.1)
        H.tap("DOWN"); H.play(0.1)
        H.tap("LEFT"); H.play(0.1)
        H.tap("RIGHT"); H.play(0.1)
        H.tap("L2")
        local want = { "X", "B", "Y", "A" }
        H.eq(#hits, 4, "four hits")
        for i, pad in ipairs(want) do
            H.eq(hits[i].name, M.Hands:getPadSound(st, pad).id, "direction " .. i .. " plays pad " .. pad)
        end
        local n = count(L.tracks[1].events)
        for _, pad in ipairs(want) do H.eq(n[pad], 1, "recorded as " .. pad) end
        for _, ev in ipairs(L.tracks[1].events) do
            H.eq(ev.soundId, M.Hands:getPadSound(st, ev.action).id, "with its pad's sound")
        end
    end },

    { "a diagonal makes two hits; face and D-pad on one pad in one frame make one", function()
        local M, L = boot()
        H.tap("L2")
        H.tap("UP", "LEFT"); H.play(0.1)                        -- X and Y
        H.tap("DOWN", "RIGHT"); H.play(0.1)                     -- B and A
        H.tap("B", "DOWN"); H.play(0.1)                         -- one B
        H.tap("X", "UP"); H.play(0.1)                           -- one X
        H.tap("L2")
        local n = count(L.tracks[1].events)
        H.eq(n.X, 2, "X: diagonal + one double press")
        H.eq(n.Y, 1, "Y: diagonal")
        H.eq(n.A, 1, "A: diagonal")
        H.eq(n.B, 2, "B: diagonal + one double press")
        H.eq(#L.tracks[1].events, 6, "six hits in all")
        -- two thumbs alternating on one pad: every press sounds (a roll)
        local hits = watch(M)
        for _ = 1, 3 do H.tap("B"); H.tap("DOWN") end
        H.eq(#hits, 6, "a six-stroke roll on B")
    end },

    { "L1 is a ghost and R1 an accent, at the Drums' levels; never a flam or a ratchet", function()
        local M, L = boot()
        local hits = watch(M)
        H.tap("L2")
        H.hold("L1"); H.play(0.05); H.tap("B"); H.release("L1"); H.play(0.1)
        H.hold("R1"); H.play(0.05); H.tap("DOWN"); H.release("R1"); H.play(0.1)
        H.tap("Y"); H.play(0.1)
        H.tap("LEFT"); H.play(0.1)                              -- LEFT is a pad here, not a flam
        H.tap("RIGHT"); H.play(0.1)                             -- RIGHT is a pad here, not a ratchet
        H.tap("L2")
        H.eq(#hits, 5, "one sound per press (no grace notes, no ratchet bursts)")
        H.near(hits[1].vol, 0.40, "ghost level", 1e-9)
        H.near(hits[2].vol, 1.0, "accent level", 1e-9)
        H.near(hits[3].vol, 0.85, "normal level", 1e-9)
        local ev = L.tracks[1].events
        H.near(ev[1].vel, 0.40, "ghost recorded", 1e-9); H.near(ev[1].decay, 0.65, "ghost is short", 1e-9)
        H.near(ev[2].vel, 1.0, "accent recorded", 1e-9); H.near(ev[2].decay, 1.25, "accent is longer", 1e-9)
        for _, e in ipairs(ev) do
            H.eq(e.orn, nil, "no flam")
            H.eq(e.ratchet, nil, "no ratchet")
        end
    end },

    { "both shoulders with a pad or a direction held repeat at the grid; one shoulder doesn't", function()
        local M, L = boot()
        local loop = L:getLoopDuration()
        H.tap("L2")
        H.hold("B", "L1", "R1"); H.play(loop / 2); H.release("B", "L1", "R1"); H.play(0.05)
        H.tap("L2")
        local nB = count(L.tracks[1].events).B
        H.truthy(nB >= 14 and nB <= 17, "1/16 for one bar: " .. nB)
        for _, e in ipairs(L.tracks[1].events) do
            H.eq(e.tick % 120, 0, "on the 1/16 grid")
            H.near(e.vel, 0.85, "repeat at the normal level", 1e-9)
        end

        L:clearTrack(1)
        H.tap("L2")
        H.hold("UP", "L1", "R1"); H.play(loop / 2); H.release("UP", "L1", "R1"); H.play(0.05)
        H.tap("L2")
        local nX = count(L.tracks[1].events).X
        H.truthy(nX >= 14 and nX <= 17, "a held direction repeats too: " .. nX)

        L:clearTrack(1)
        H.tap("L2")
        H.hold("B", "R1"); H.play(loop / 2); H.release("B", "R1"); H.play(0.05)
        H.hold("A", "L1"); H.play(loop / 2); H.release("A", "L1"); H.play(0.05)
        H.tap("L2")
        local n = count(L.tracks[1].events)
        H.eq(n.B, 1, "R1 alone: one accent, no repeat")
        H.eq(n.A, 1, "L1 alone: one ghost, no repeat")
    end },

    { "a ghost recorded with VARIATION on gets its chance, as on Drums", function()
        local M, L, st = boot()
        st.variation = "LIGHT"
        H.tap("L2")
        H.hold("L1"); H.play(0.05); H.tap("DOWN"); H.release("L1"); H.play(0.3)
        H.tap("Y"); H.play(0.1)
        H.tap("L2")
        local by = {}
        for _, ev in ipairs(L.tracks[1].events) do by[ev.action] = ev end
        H.eq(by.B.chance, M.Drums.GHOST_CHANCE, "the ghost is a chance hit")
        H.eq(by.Y.chance, nil, "a normal hit isn't")
    end },

    { "Drums <-> Hand Drums keeps the notes both ways", function()
        local M = H.loadMain()
        H.play(0.1)
        local L = M.Looper
        H.record(L, 1, "B", 0.0); H.record(L, 1, "Y", 0.25); H.record(L, 1, "A", 0.5)
        M.Instruments:swapTrackInstrument(1, "hands")
        H.eq(L.tracks[1].instrumentId, "hands", "swapped")
        H.eq(#L.tracks[1].events, 3, "Drums -> Hand Drums keeps the hits")
        H.record(L, 1, "X", 0.75)
        M.Instruments:swapTrackInstrument(1, "drums")
        H.eq(#L.tracks[1].events, 4, "Hand Drums -> Drums keeps them, the new one too")
        M.Instruments:swapTrackInstrument(1, "bass")
        H.eq(#L.tracks[1].events, 0, "another class starts empty")
    end },

    { "a Hand Drums track saves and loads its kit, pad sounds, tune and level", function()
        local M, L, st = boot()
        M.Hands:applyKit(st, 5)                                 -- LATIN
        M.Hands:cycleRowSound(st, 2, 3, true)                   -- pad X: another sound
        st.padTune.Y, st.padLevel.A = 3, 0.6
        local xSound = M.Hands:getPadSound(st, "X").id
        H.tap("L2"); H.tap("UP"); H.tap("L2")
        local data = assert(M.Save.decode(M.Save.encode(M.Session.snapshot())))
        H.truthy(M.Session.restore(data), "restored")
        local t = L.tracks[1]
        H.eq(t.instrumentId, "hands", "still Hand Drums")
        H.eq(t.state.kitIndex, 5, "kit")
        H.truthy(t.state.kitEdited, "edited kit")
        H.eq(M.Hands:getPadSound(t.state, "X").id, xSound, "pad sound")
        H.eq(t.state.padTune.Y, 3, "tune"); H.near(t.state.padLevel.A, 0.6, "level", 1e-9)
        H.eq(#t.events, 1, "the hit")
        H.eq(t.events[1].action, "X", "under its face button")
    end },

    { "the erase page clears by face button, as on Drums", function()
        local M, L = boot()
        H.tap("L2")
        H.tap("UP"); H.play(0.1); H.tap("X"); H.play(0.1); H.tap("DOWN"); H.play(0.1)
        H.tap("L2")
        H.eq(L:countTrackAction(1, "X"), 2, "two X hits, one from the D-pad")
        H.hold("L2", "R2"); H.play(0.1)
        H.tap("X")
        H.release("L2", "R2"); H.play(0.1)
        H.eq(L:countTrackAction(1, "X"), 0, "X's hits cleared, the D-pad's too")
        H.eq(L:countTrackAction(1, "B"), 1, "B's kept")
    end },
}
