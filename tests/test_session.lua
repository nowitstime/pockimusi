-- Session snapshot and restore (C2)
local H = require("helpers")

local function boot()
    local M = H.loadMain()
    H.play(0.1)
    return M, M.Looper
end

-- A rich session built by actually playing, plus settings set directly
local function buildSession(M, L)
    local T = M.Theory
    -- Track 1 drums: hits with a flam, a different kit, one pad edited
    H.tap("L2"); H.tap("B"); H.play(0.2); H.hold("LEFT"); H.tap("Y"); H.release("LEFT"); H.tap("L2")
    local drums = M.Instruments:getDefinition("drums")
    drums:applyKit(L.tracks[1].state, 3)
    drums:cycleRowSound(L.tracks[1].state, 3, 2)          -- pad Y edited
    -- Track 2 harp: 7th chords
    H.tap("SELECT")
    L.tracks[2].state.colour = "7TH"
    H.tap("L2"); H.hold("RIGHT"); H.tap("A"); H.release("RIGHT"); H.tap("L2")
    -- Track 3 bass: SUB, slow glide, a held note with a bend
    H.tap("SELECT")
    L.tracks[3].state.patch = "bass_sub"
    L.tracks[3].state.glide = "SLOW"
    H.tap("L2"); H.hold("B"); H.play(0.3); H.hold("UP"); H.play(0.3); H.release("UP", "B"); H.play(0.05); H.tap("L2")
    -- Track 4 pad: tone and rows set, a held chord
    H.tap("SELECT")
    L.tracks[4].state.bright, L.tracks[4].state.move = 0.8, 0.3
    L.tracks[4].state.patch, L.tracks[4].state.attack, L.tracks[4].state.follow = "pad_choir", "SLOW", false
    H.tap("L2"); H.hold("A"); H.play(0.4); H.release("A"); H.play(0.05); H.tap("L2")
    -- Mix, effects, timing, key
    L.tracks[1].swing = 0.62
    L.tracks[2].volume = 0.55
    L.tracks[3].muted = true
    L.tracks[2].fx.on.echo, L.tracks[2].fx.echo = true, 0.7
    L.tracks[4].gridIndex = 2
    L.bpm = 132
    L:toggleBars()                                        -- 4 bars
    L.clickOn = true
    T.rootIndex, T.scaleIndex = 10, 2                     -- A minor
    M.Synth.masterVolume = 0.6
    L.activeTrack = 3
end

local function count(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end

return {
    { "save -> fresh boot -> restore -> save gives exactly the same text", function()
        local M, L = boot()
        buildSession(M, L)
        local text1 = M.Save.encode(M.Session.snapshot())
        local data = assert(M.Save.decode(text1))

        local M2, L2 = boot()                              -- a fresh game
        H.truthy(M2.Session.restore(data), "restored")
        local text2 = M2.Save.encode(M2.Session.snapshot())
        H.eq(text2, text1, "identical session")
        -- spot checks
        H.eq(L2.bpm, 132, "tempo")
        H.eq(L2.bars, 4, "bars")
        H.eq(M2.Theory.rootIndex, 10, "key")
        H.eq(L2.tracks[3].state.patch, "bass_sub", "bass patch")
        H.eq(L2.tracks[2].state.colour, "7TH", "harp colour")
        H.eq(L2.tracks[1].state.kitIndex, 3, "kit")
        H.truthy(L2.tracks[1].state.kitEdited, "kit edited")
        H.truthy(L2.tracks[3].events[1].bend, "bass bend")
        H.truthy(L2.tracks[4].events[1].len > 0, "pad held chord")
        H.truthy(L2.tracks[2].fx.on.echo, "effect on")
        H.eq(L2.activeTrack, 3, "active track")
        -- every setting, checked against what was set (not through saveState)
        H.eq(L2.tracks[3].state.glide, "SLOW", "bass glide")
        H.near(L2.tracks[4].state.bright, 0.8, "pad brightness", 1e-9)
        H.near(L2.tracks[4].state.move, 0.3, "pad movement", 1e-9)
        H.eq(L2.tracks[4].state.patch, "pad_choir", "pad patch")
        H.eq(L2.tracks[4].state.attack, "SLOW", "pad attack")
        H.falsy(L2.tracks[4].state.follow, "pad follow")
        H.eq(#L2.tracks[4].events[1].notes, 3, "pad notes (open)")
        H.near(L2.tracks[1].swing, 0.62, "swing", 1e-9)
        H.near(L2.tracks[2].volume, 0.55, "volume", 1e-9)
        H.truthy(L2.tracks[3].muted, "mute")
        H.near(L2.tracks[2].fx.echo, 0.7, "echo amount", 1e-9)
        H.eq(L2.tracks[4].gridIndex, 2, "grid")
        H.truthy(L2.clickOn, "click")
        H.eq(M2.Theory.scaleIndex, 2, "scale")
        H.near(M2.Synth.masterVolume, 0.6, "master", 1e-9)
        local d1, d2 = M.Instruments:getDefinition("drums"), M2.Instruments:getDefinition("drums")
        for _, pad in ipairs({ "B", "A", "Y", "X" }) do
            H.eq(d2:getPadSound(L2.tracks[1].state, pad).id, d1:getPadSound(L.tracks[1].state, pad).id, "pad " .. pad)
        end
        local e1, e2 = L.tracks[3].events[1], L2.tracks[3].events[1]
        H.eq(e2.tick, e1.tick, "event tick")
        H.eq(e2.len, e1.len, "event len")
        H.eq(e2.bend[1].semis, e1.bend[1].semis, "bend pitch")
        H.eq(L2.tracks[2].events[1].chord.colour, "7TH", "chord saved with the note")
    end },

    { "a restored session plays: the drum hits fire", function()
        local M, L = boot()
        H.tap("L2"); H.tap("B"); H.play(0.5); H.tap("Y"); H.tap("L2")
        local data = M.Save.decode(M.Save.encode(M.Session.snapshot()))
        local M2, L2 = boot()
        M2.Session.restore(data)
        local hits = 0
        local orig = M2.Synth.trigger
        M2.Synth.trigger = function(self, name, ...)
            if name:find("^kick") or name:find("^snare") then hits = hits + 1 end
            return orig(self, name, ...)
        end
        H.play(L2:getLoopDuration() + 0.1)
        H.eq(hits, 2, "both hits played back")
    end },

    { "runtime flags are never saved; a note still held is saved with its length so far", function()
        local M, L = boot()
        for _ = 1, 3 do H.tap("SELECT") end                 -- pad
        H.tap("L2"); H.hold("B"); H.play(0.5)
        local snap = M.Session.snapshot()
        local ev = snap.tracks[4].events[1]
        H.eq(ev.open, nil, "no open flag")
        H.eq(ev.skipOnce, nil, "no skipOnce flag")
        H.near(ev.len / L:getTicksPerSecond(), 0.5, "length so far", 0.05)
        H.truthy(L.tracks[4].events[1].open, "the live event is still open")
        H.release("B"); H.play(0.05); H.tap("L2")
    end },

    { "drum pad sounds are saved by name, not position", function()
        local M, L = boot()
        local snap = M.Session.snapshot()
        H.eq(snap.tracks[1].settings.pads.B, "kick_808", "sound id")
        -- a catalogue with a new sound in front still finds the right one
        local M2, L2 = boot()
        table.insert(M2.Synth.drumCatalog, 1, { id = "new_sound", short = "NEW", full = "NEW" })
        snap.tracks[1].settings.pads.Y = "snare_brush"
        M2.Session.restore(snap)
        local drums = M2.Instruments:getDefinition("drums")
        H.eq(drums:getPadSound(L2.tracks[1].state, "B").id, "kick_808", "pad B")
        H.eq(drums:getPadSound(L2.tracks[1].state, "Y").id, "snare_brush", "pad Y")
    end },

    { "bad values are fixed up, not trusted", function()
        local M, L = boot()
        local ok = M.Session.restore({
            format = 1, bpm = 9999, bars = 3, clickOn = "yes", activeTrack = 7,
            rootIndex = -4, scaleIndex = 99, masterVolume = 5,
            tracks = {
                { instrumentId = "kazoo", swing = 2, volume = -1, gridIndex = 42,
                  fx = { tone = 9, on = { tone = "true" } },
                  events = { { tick = 960, action = "B", vel = 7 },          -- kept, vel clamped
                             { tick = 999999, action = "B" },                -- outside the loop
                             { tick = 100, action = "Z" },                   -- unknown button
                             { tick = -5, action = "A" },
                             "not a table",
                             { tick = 200, action = "Y", len = -9, bend = { { dt = 5, semis = 2 }, { dt = "x" } } } } },
                { instrumentId = "harp", settings = { colour = "PURPLE" } },
                { instrumentId = "bass", settings = { patch = "bass_kazoo", glide = 3 } },
                "garbage",
            },
        })
        H.truthy(ok, "restored anyway")
        H.eq(L.bpm, 180, "tempo clamped")
        H.eq(L.bars, 2, "bars default")
        H.falsy(L.clickOn, "click only if exactly true")
        H.eq(L.activeTrack, 4, "active track clamped")
        H.eq(M.Theory.rootIndex, 1, "key clamped")
        H.eq(M.Theory.scaleIndex, #M.Theory.SCALES, "scale clamped")
        H.eq(M.Synth.masterVolume, 1.0, "master clamped")
        local t1 = L.tracks[1]
        H.eq(t1.instrumentId, "drums", "unknown instrument -> slot default")
        H.eq(t1.swing, 0.75, "swing clamped")
        H.eq(t1.volume, 0.0, "volume clamped")
        H.eq(t1.gridIndex, #L.GRID_MODES, "grid clamped")
        H.eq(t1.fx.tone, 1.0, "fx clamped")
        H.falsy(t1.fx.on.tone, "fx on only if exactly true")
        H.eq(#t1.events, 2, "two valid events kept")
        H.eq(t1.events[1].vel, 1.0, "vel clamped")
        H.eq(t1.events[2].len, 0, "negative len -> 0")
        H.eq(#t1.events[2].bend, 1, "bad keyframe dropped")
        H.eq(L.tracks[2].state.colour, "TRIAD", "unknown colour ignored")
        H.eq(L.tracks[3].state.patch, "bass_saw", "unknown patch ignored")
        H.eq(L.tracks[4].instrumentId, "pad", "garbage track -> default")
    end },

    { "an unknown format is refused and the session is left alone", function()
        local M, L = boot()
        H.tap("L2"); H.tap("B"); H.tap("L2")
        local ok, msg = M.Session.restore({ format = 99, bpm = 60 })
        H.falsy(ok, "refused")
        H.truthy(msg:find("format"), "says why")
        H.eq(L.bpm, M.Session and require("src.config").DEFAULT_BPM, "tempo untouched")
        H.eq(#L.tracks[1].events, 1, "events untouched")
        H.falsy(M.Session.restore("nope"), "not a table")
    end },

    { "restoring stops what's playing, clears undo and the record latch", function()
        local M, L = boot()
        for _ = 1, 3 do H.tap("SELECT") end
        H.tap("L2"); H.hold("B"); H.play(0.3)                 -- pad held, recording
        local st = L.tracks[4].state
        H.eq(count(st.live), 1, "playing")
        local data = M.Session.snapshot()
        M.Session.restore(data)
        H.eq(count(L.tracks[4].state.live), 0, "silenced")
        H.eq(#L.undoStack, 0, "undo cleared")
        H.falsy(M.Input.recLatched, "jam safe")
        H.release("B"); H.play(0.1)
    end },

    { "new recordings after a restore continue the take numbers", function()
        local M, L = boot()
        H.tap("L2"); H.tap("B"); H.tap("L2"); H.tap("L2"); H.play(0.3); H.tap("A"); H.tap("L2")
        local last = L.currentTakeId
        local data = M.Save.decode(M.Save.encode(M.Session.snapshot()))
        local M2, L2 = boot()
        M2.Session.restore(data)
        H.tap("L2"); H.play(0.6); H.tap("Y"); H.tap("L2")
        local newest = L2.tracks[1].events[#L2.tracks[1].events]
        H.truthy(newest.takeId > last - 1, "take id moves on (" .. newest.takeId .. ")")
        H.hold("L2", "R2"); H.play(0.1); H.tap("LEFT"); H.release("L2", "R2"); H.play(0.1)
        H.eq(#L2.tracks[1].events, 2, "undo removes only the new take")
    end },

    { "swapped instruments come back in their slots", function()
        local M, L = boot()
        M.Instruments:swapTrackInstrument(1, "bass")
        M.Instruments:swapTrackInstrument(4, "harp")
        local data = M.Save.decode(M.Save.encode(M.Session.snapshot()))
        local M2, L2 = boot()
        M2.Session.restore(data)
        H.eq(L2.tracks[1].instrumentId, "bass", "slot 1")
        H.eq(L2.tracks[4].instrumentId, "harp", "slot 4")
        H.eq(L2.tracks[1].name, "RIBBON BASS", "name follows")
    end },
}
