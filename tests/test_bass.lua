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
}
