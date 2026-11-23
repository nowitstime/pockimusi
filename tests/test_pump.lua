-- Pump (PHASE_L L3): any KICK sound ducks the tracks whose PUMP row is on;
-- with no kick for a while (clock running) they pump on every beat.
local H = require("helpers")

local function boot()
    local M = H.loadMain()
    M.Synth = require("src.synth")
    H.play(0.1)
    return M, M.Looper, M.Synth
end

local function minMax(S, slot, seconds)
    local lo, hi = 1.0, 0.0
    for _ = 1, math.floor(seconds * 60 + 0.5) do
        H.play(1 / 60)
        lo = math.min(lo, S.pumpNow[slot])
        hi = math.max(hi, S.pumpNow[slot])
    end
    return lo, hi
end

return {
    { "every kick sound is known as a kick", function()
        local _, _, S = boot()
        local n = 0
        for _, item in ipairs(S.drumCatalog) do
            H.eq(S.KICK_SOUNDS[item.id] == true, item.cat == "KICK", item.id)
            if item.cat == "KICK" then n = n + 1 end
        end
        H.truthy(n >= 5, "the kicks: " .. n)
    end },

    { "a kick on the drums ducks a pumping track, which comes back up", function()
        local M, L, S = boot()
        L:setPlaying(false)
        L.tracks[3].pump = 3                       -- MEDIUM on the bass
        L.tracks[1].pump = 4                       -- the drums' own track: never pumps from its kick
        L.activeTrack = 1
        H.play(1 / 60, { "B" })                    -- B = the kit's kick
        H.truthy(S.pumpNow[3] < 0.55, "ducked right after the kick: " .. S.pumpNow[3])
        H.near(S.pumpNow[1], 1.0, "the kick's own track does not pump")
        H.near(S.pumpNow[2], 1.0, "a track with PUMP off does not pump")
        H.play(0.4)
        H.near(S.pumpNow[3], 1.0, "back up after the recovery")
    end },

    { "harder levels duck deeper", function()
        local M, L, S = boot()
        L:setPlaying(false)
        L.tracks[2].pump, L.tracks[3].pump, L.tracks[4].pump = 2, 3, 4
        L.activeTrack = 1
        H.play(1 / 60, { "B" })
        H.truthy(S.pumpNow[2] > S.pumpNow[3] and S.pumpNow[3] > S.pumpNow[4],
            string.format("LIGHT %.2f > MEDIUM %.2f > HARD %.2f", S.pumpNow[2], S.pumpNow[3], S.pumpNow[4]))
    end },

    { "a snare does not pump", function()
        local M, L, S = boot()
        L:setPlaying(false)
        L.tracks[3].pump = 4
        L.activeTrack = 1
        H.play(0.6)
        H.play(0.05, { "Y" })                      -- Y = the kit's snare
        H.near(S.pumpNow[3], 1.0, "no duck")
    end },

    { "no kick and the clock running: it pumps on the beat", function()
        local M, L, S = boot()
        L:setPlaying(true)
        L.tracks[4].pump = 3
        H.play(1.5)
        local lo, hi = minMax(S, 4, 60 / L.bpm * 2)
        H.truthy(lo < 0.6, "dips on the beat: " .. lo)
        H.truthy(hi > 0.95, "and recovers between beats: " .. hi)
        L:setPlaying(false)
        H.play(0.2)
        lo = minMax(S, 4, 1.0)
        H.near(lo, 1.0, "clock stopped and no kick: no pump")
    end },

    { "the PUMP row: on pitched tracks only, cycles, saved with the session", function()
        local M, L, S = boot()
        local I = M.Instruments
        local function pumpRow(slot)
            local t = L.tracks[slot]
            for i, row in ipairs(I:getSoundRows(I:getDefinition(t.instrumentId), t.state, t)) do
                if row.key == "PUMP" then return row, i end
            end
        end
        H.falsy(pumpRow(1), "drums: no PUMP row (they are what it listens to)")
        local row, idx = pumpRow(3)
        H.truthy(row, "bass has one")
        H.eq(row.value, "OFF", "off by default")
        local t3 = L.tracks[3]
        I:cycleRow(I:getDefinition(t3.instrumentId), t3.state, idx, 1, t3)
        H.eq(pumpRow(3).value, "LIGHT", "RIGHT steps it")
        I:cycleRow(I:getDefinition(t3.instrumentId), t3.state, idx, -2, t3)
        H.eq(pumpRow(3).value, "HARD", "LEFT wraps")
        local snap = M.Session.snapshot()
        t3.pump = 1
        H.truthy(M.Session.restore(snap), "restored")
        H.eq(L.tracks[3].pump, 4, "pump comes back")
        snap.tracks[3].pump = "loud"
        M.Session.restore(snap)
        H.eq(L.tracks[3].pump, 1, "a bad value is reset to off")
        snap.tracks[3].pump = 99
        M.Session.restore(snap)
        H.eq(L.tracks[3].pump, #S.PUMP_LEVELS, "too big: the hardest level")
    end },
}
