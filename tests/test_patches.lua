-- The sound pool (SPEC §6): one catalogue for every pitched instrument, each
-- instrument's list and restrictions, and playing across groups.
local H = require("helpers")

local function boot()
    local M = H.loadMain()
    M.Patches = require("src.instruments.patches")
    H.play(0.1)
    return M, M.Looper, M.Synth
end

local function labels(M, id)
    local out = {}
    for i, pid in ipairs(M.Patches.list(M.Instruments:getDefinition(id))) do out[i] = M.Synth.patches[pid].label end
    return out
end

local function has(list, value)
    for _, v in ipairs(list) do if v == value then return true end end
    return false
end

-- Put `patch` on a track (as the Track page does)
local function use(M, L, slot, patch)
    local track = L.tracks[slot]
    track.state.patch = patch
    M.Synth:preparePatch(patch, M.Instruments:getDefinition(track.instrumentId).VOICES)
    return track
end

local function voicesOf(S, track)
    local out = {}
    for _, v in ipairs(S.sustainVoices) do
        if v.track == track then out[#out + 1] = v end
    end
    return out
end

return {
    { "each instrument lists the whole pool, its own group first", function()
        local M = boot()
        local bass, lead, pad, harp = labels(M, "bass"), labels(M, "lead"), labels(M, "pad"), labels(M, "harp")
        H.eq(bass[1] .. " " .. lead[1] .. " " .. pad[1] .. " " .. harp[1], "SAW SQUARE WARM HARP", "defaults first")
        H.eq(#bass, #lead, "bass and lead take the same sounds")
        H.truthy(has(bass, "SQUARE") and has(bass, "WARM") and has(bass, "KALIMBA") and has(bass, "GONG"), "bass: every group")
        H.truthy(has(lead, "808") and has(lead, "STRINGS") and has(lead, "NYLON"), "lead: every group")
        H.truthy(has(harp, "SQUARE") and has(harp, "CHOIR") and has(harp, "SWARM"), "harp: sustained sounds too")
        H.truthy(has(pad, "SAW") and has(pad, "RHODES") and has(pad, "SHEPARD"), "pad: anything with a loop")
    end },

    { "restrictions: the pad skips one-shot patches; only the harp gets SILENT", function()
        local M = boot()
        local pad = labels(M, "pad")
        for _, oneShot in ipairs({ "HARP", "NYLON", "KALIMBA", "GONG", "REVERSE" }) do
            H.falsy(has(pad, oneShot), "pad has no " .. oneShot)
        end
        H.truthy(has(labels(M, "harp"), "SILENT"), "harp: silent")
        for _, id in ipairs({ "bass", "lead", "pad" }) do
            H.falsy(has(labels(M, id), "SILENT"), id .. ": no silent")
        end
    end },

    { "the PATCH row's picker items carry their group and full name", function()
        local M, L = boot()
        local row = M.Instruments:getSoundRows(M.Instruments:getDefinition("pad"), L.tracks[4].state)[1]
        H.eq(row.value, "WARM", "value")
        H.eq(row.items[1].group, "PAD", "own group first")
        H.eq(row.items[1].full, "WARM PAD", "full name")
        local groups = {}
        for _, it in ipairs(row.items) do
            if groups[#groups] ~= it.group then groups[#groups + 1] = it.group end
        end
        H.eq(table.concat(groups, " "), "PAD BASS LEAD PLUCK ODD", "one run per group")
        L.tracks[4].state.patch = "odd_throat"
        row = M.Instruments:getSoundRows(M.Instruments:getDefinition("pad"), L.tracks[4].state)[1]
        H.eq(row.items[row.index].label, "THROAT", "index follows the patch")
    end },

    { "a bass plays a lead patch an octave down, a lead plays a bass patch an octave up", function()
        local M, L, S = boot()
        local track = use(M, L, 3, "lead_square")
        H.tap("SELECT"); H.tap("SELECT")                      -- track 3 = bass
        H.hold("B"); H.play(0.2)
        local v = voicesOf(S, track)[1]
        H.eq(v.patch.id, "lead_square", "the lead's patch")
        H.near(v.loopSrc.pitch, 0.5 * 2 ^ (v.patch.tune / 12), "in the bass's octave", 1e-6)
        H.eq(v.currentSemis, 0, "stage view still sees the root")
        H.release("B"); H.play(0.3)

        M.Instruments:swapTrackInstrument(3, "lead")
        track = use(M, L, 3, "bass_sub")
        H.hold("B"); H.play(0.2)
        v = voicesOf(S, track)[1]
        H.near(v.loopSrc.pitch, 2.0 * 2 ^ (v.patch.tune / 12), "in the lead's octave", 1e-6)
        H.release("B"); H.play(0.2)
    end },

    { "one-shot patches on the bass: notes ring over each other and bend", function()
        local M, L, S = boot()
        local track = use(M, L, 3, "pluck_kalimba")
        H.tap("SELECT"); H.tap("SELECT")
        H.tap("B"); H.tap("B")
        local vs = voicesOf(S, track)
        H.eq(#vs, 2, "two notes ringing (not mono)")
        H.eq(vs[1].loopSrc, nil, "one-shot voices")
        H.hold("B"); H.play(0.1); H.hold("UP"); H.play(0.2)
        vs = voicesOf(S, track)
        H.truthy(vs[#vs].attack.hasGlide and vs[#vs].attack.targetSemis ~= 0, "a held one-shot bends with the D-pad")
        H.release("B", "UP"); H.play(1.5)
        H.eq(#voicesOf(S, track), 0, "all rung out")
    end },

    { "the pad plays a lead patch as a chord; a one-shot patch from a save falls back", function()
        local M, L, S = boot()
        local track = use(M, L, 4, "lead_saw")
        H.tap("SELECT"); H.tap("SELECT"); H.tap("SELECT")     -- track 4 = pad
        H.hold("B"); H.play(0.5)
        local vs = voicesOf(S, track)
        H.eq(#vs, 4, "a four-note chord")
        H.eq(vs[1].patch.id, "lead_saw", "on the lead's saw")
        H.eq(vs[1].brightSrc, nil, "no bright layer: brightness does nothing")
        H.truthy(vs[1].loopSrc.volume > 0, "sounding")
        H.release("B"); H.play(0.2)

        local Pad = M.Instruments:getDefinition("pad")
        Pad:loadState(track.state, { patch = "pluck_kalimba" })
        H.eq(track.state.patch, "lead_saw", "a patch the pad can't play is not loaded")
        track.state.patch = "pluck_kalimba"                   -- (as if forced)
        H.eq(Pad:getPatch(track.state).id, "pad_warm", "and would play as the default")
    end },

    { "harp: ringing patches ring, sustained ones are gated, SILENT still drives the chords", function()
        local M, L, S = boot()
        local Harp = M.Instruments:getDefinition("harp")
        local track = L.tracks[2]
        H.tap("SELECT")                                       -- track 2 = harp

        H.tap("B")
        local v = voicesOf(S, track)[1]
        H.eq(v.patch.id, "harp", "its own pluck")
        H.eq(v.attack.soundName, "harp", "the same one-shot as before")
        H.play(1.5)

        use(M, L, 2, "lead_square")                           -- sustains: held for the gate
        H.tap("B")
        v = voicesOf(S, track)[1]
        H.truthy(v.loopSrc.playing and not v.releasedAt, "sounding")
        H.play(Harp.GATE)
        H.truthy(v.releasedAt, "released after the gate")
        H.play(0.3)
        H.eq(#voicesOf(S, track), 0, "and gone")

        use(M, L, 2, "pluck_rhodes")                          -- rings: left to ring
        H.tap("B")
        v = voicesOf(S, track)[1]
        H.play(Harp.GATE + 0.3)
        H.falsy(v.releasedAt, "still ringing after the gate")
        H.play(Harp.RING + 1.0)
        H.eq(#voicesOf(S, track), 0, "released later")

        use(M, L, 2, "silent")
        H.hold("LEFT"); H.play(0.05); H.tap("B"); H.release("LEFT"); H.play(0.05)
        H.eq(#voicesOf(S, track), 0, "no sound")
        H.eq(track.state.strings[1].energy > 0, true, "the string still moves")
        H.truthy(track.state.liveChord.roman ~= "I", "the chord is still set")
        H.truthy(require("src.harmony"):current().roman ~= "I", "followers get the silent harp's chord")
    end },

    { "the harp's patch is saved and loaded; unknown ids are ignored", function()
        local M, L = boot()
        local Harp = M.Instruments:getDefinition("harp")
        local st = L.tracks[2].state
        st.patch = "odd_gong"
        local saved = Harp:saveState(st)
        local fresh = Harp:newState()
        Harp:loadState(fresh, saved)
        H.eq(fresh.patch, "odd_gong", "restored")
        H.truthy(M.Synth.patches.odd_gong.built, "and generated, ready to play")
        Harp:loadState(fresh, { patch = "nope" })
        H.eq(fresh.patch, "odd_gong", "unknown id ignored")
        Harp:loadState(fresh, { colour = "7TH" })
        H.eq(fresh.patch, "odd_gong", "an old save without a patch keeps the current one")
    end },

    { "every instrument plays every patch in its list through full frames", function()
        local M, L, S = boot()
        for slot = 2, 4 do
            L.activeTrack = slot
            local track = L.tracks[slot]
            local def = M.Instruments:getDefinition(track.instrumentId)
            for _, id in ipairs(M.Patches.list(def)) do
                use(M, L, slot, id)
                H.play(0.1, { "B" }); H.play(0.1, { "A", "UP" }); H.play(0.1, { "X", "R1" }); H.play(0.1)
                if not S.patches[id].silent then H.truthy(S.patches[id].built, id .. " generated") end
            end
        end
        M.Instruments:swapTrackInstrument(3, "lead")
        L.activeTrack = 3
        for _, id in ipairs(M.Patches.list(M.Instruments:getDefinition("lead"))) do
            use(M, L, 3, id)
            H.play(0.15, { "B" }); H.play(0.3, { "A", "LEFT" }); H.play(0.1)
        end
        -- the Track page with a long, grouped list
        H.hold("SELECT"); H.play(0.3)
        for _ = 1, 30 do H.tap("RIGHT") end
        H.release("SELECT"); H.play(0.5)
        H.truthy(true, "no errors")
    end },
}
