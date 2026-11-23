-- Modes: every global combo in SPEC §3.4–3.6, driven through the real game loop.
-- Written against main.lua before the modes refactor (A3), then kept as the
-- spec for src/modes.lua.
local H = require("helpers")

local function page() return package.loaded["src.modes"].trackPage end
local function mixTrack() return package.loaded["src.modes"].mixTrack end

local function boot()
    local M = H.loadMain()
    M.Theory = require("src.theory")
    M.Config = require("src.config")
    H.play(0.1)
    return M, M.Looper, M.Input
end

return {
    -- ------------------------------------------------------------------
    -- Mode resolution
    -- ------------------------------------------------------------------
    { "mode names while holding each modifier", function()
        local _, _, I = boot()
        H.eq(H.mode(), "NORMAL", "idle")
        H.hold("L2");            H.play(0.3);  H.eq(H.mode(), "REC_HOLD", "L2 held");             H.release("L2")
        H.play(0.1)
        H.hold("L2", "R2");      H.play(0.1);  H.eq(H.mode(), "ERASE", "L2+R2");             H.release("L2", "R2")
        H.play(0.1)
        H.hold("SELECT");        H.play(0.3);  H.eq(H.mode(), "TRACK", "SELECT held");
        H.hold("R2");            H.play(0.1);  H.eq(H.mode(), "MIX", "SELECT+R2");           H.release("SELECT", "R2")
        H.play(0.1)
        H.hold("START");         H.play(0.3);  H.eq(H.mode(), "TRANSPORT", "START held");    H.release("START")
        H.play(0.1)
        H.hold("R2");            H.play(0.1);  H.eq(H.mode(), "FX", "R2");                   H.release("R2")
        H.play(0.1)
        H.tap("L2");             H.eq(H.mode(), "REC_LATCH", "latched")
        H.tap("L2");             H.eq(H.mode(), "NORMAL", "unlatched")
        H.falsy(I.recLatched, "latch off")
    end },

    { "SELECT and START need a short hold before their pages open", function()
        boot()
        H.hold("SELECT"); H.play(0.1); H.eq(H.mode(), "NORMAL", "SELECT 0.1 s"); H.release("SELECT")
        H.play(0.1)
        H.hold("START"); H.play(0.1); H.eq(H.mode(), "NORMAL", "START 0.1 s"); H.release("START")
    end },

    -- ------------------------------------------------------------------
    -- Recording (L2)
    -- ------------------------------------------------------------------
    { "L2 tap latches recording; tap again stops", function()
        local _, L, I = boot()
        H.tap("L2")
        H.truthy(I.recLatched, "latched")
        H.tap("B")
        H.eq(#L.tracks[1].events, 1, "hit recorded")
        H.tap("L2")
        H.falsy(I.recLatched, "stopped")
        H.tap("A")
        H.eq(#L.tracks[1].events, 1, "not recording after stop")
    end },

    { "L2 hold records only while held and does not latch", function()
        local _, L, I = boot()
        H.hold("L2"); H.play(0.3)
        H.tap("B")
        H.release("L2"); H.play(0.1)
        H.eq(#L.tracks[1].events, 1, "hit recorded during hold")
        H.falsy(I.recLatched, "not latched")
        H.tap("A")
        H.eq(#L.tracks[1].events, 1, "not recording after release")
    end },

    { "holding L2 while latched ends the latch on release", function()
        local _, _, I = boot()
        H.tap("L2")
        H.truthy(I.recLatched, "latched")
        H.hold("L2"); H.play(0.4); H.release("L2"); H.play(0.1)
        H.falsy(I.recLatched, "punch-in ended the latch")
    end },

    { "each record start begins a new take", function()
        local _, L = boot()
        local t0 = L.currentTakeId
        H.tap("L2"); H.tap("L2")
        H.eq(L.currentTakeId, t0 + 2, "two L2 presses = two takes")
    end },

    { "drum note repeat stays on the grid at 60 and 30 fps", function()
        for _, fps in ipairs({ 60, 30 }) do
            local _, L = boot()
            H.tap("L2")                                         -- latch record
            H.hold("B", "R1")                                   -- 1/8 repeat
            local frames = math.floor(L:getLoopDuration() * fps + 0.5)
            for _ = 1, frames do
                H.time = H.time + 1 / fps
                love.update(1 / fps)
            end
            H.release("B", "R1"); H.play(0.05)
            local ev = L.tracks[1].events
            local offGrid = 0
            for _, e in ipairs(ev) do if e.tick % 240 ~= 0 then offGrid = offGrid + 1 end end
            H.truthy(#ev >= 15 and #ev <= 16, fps .. " fps: " .. #ev .. " eighths in 2 bars")
            H.eq(offGrid, 0, fps .. " fps: all on 1/8 steps")
        end
    end },

    -- ------------------------------------------------------------------
    -- Track page (hold SELECT)
    -- ------------------------------------------------------------------
    { "SELECT tap cycles the active track; a hold does not", function()
        local _, L = boot()
        H.tap("SELECT")
        H.eq(L.activeTrack, 2, "tap -> track 2")
        H.hold("SELECT"); H.play(0.4); H.release("SELECT"); H.play(0.1)
        H.eq(L.activeTrack, 2, "hold keeps track 2")
    end },

    { "Track page: opens on the last pad, rows move, LEFT/RIGHT change the sound", function()
        local _, L = boot()
        local st = L.tracks[1].state
        H.hold("SELECT"); H.play(0.3)
        H.eq(page().row, 5, "opens on pad B (row 5)")
        local before = st.padCatalogIndex.B
        H.tap("RIGHT")
        H.eq(st.padCatalogIndex.B, before + 1, "RIGHT: pad B's next sound")
        H.tap("LEFT")
        H.eq(st.padCatalogIndex.B, before, "LEFT: back")
        H.tap("L1")
        H.eq(st.padCatalogIndex.B, before, "L1 does not change the row any more")
        H.tap("R1")                                       -- back to drums: no swap pending
        H.eq(page().pending, nil, "no swap left pending")
        H.tap("DOWN")
        H.eq(page().row, 6, "DOWN: the TUNE row")
        H.tap("UP"); H.tap("UP"); H.tap("UP"); H.tap("UP"); H.tap("UP")
        H.eq(page().row, 1, "UP to the KIT row")
        H.tap("UP")
        H.eq(page().row, 12, "UP past the first row wraps to the last effect row")
        H.tap("DOWN")
        H.eq(page().row, 1, "DOWN wraps back")
        H.release("SELECT"); H.play(0.1)
        H.eq(L.activeTrack, 1, "closing the page does not change track")
    end },

    { "Track page: holding LEFT/RIGHT repeats; the sound previews once it settles", function()
        local M, L = boot()
        local st = L.tracks[1].state
        local hits = {}
        local real = M.Synth.trigger
        M.Synth.trigger = function(self, name, ...) hits[#hits + 1] = name; return real(self, name, ...) end
        H.hold("SELECT"); H.play(0.3)
        local before = st.padCatalogIndex.B
        H.hold("RIGHT"); H.play(0.8); H.release("RIGHT")
        local moved = st.padCatalogIndex.B - before
        H.truthy(moved >= 4, "several steps while held")
        H.eq(#hits, 1, "only the first press previewed")
        H.play(0.3)
        H.eq(#hits, 2, "one more preview after it settles")
        H.eq(hits[2], M.Synth.drumCatalog[st.padCatalogIndex.B].id, "of the sound it landed on")
        H.release("SELECT"); H.play(0.1)
    end },

    { "Track page: the picker opens for a list row and closes by itself; numbers have none", function()
        local _, L = boot()
        H.hold("SELECT"); H.play(0.3)
        H.eq(page().picker, nil, "closed until something changes")
        H.tap("RIGHT")
        H.eq(page().picker.key, "B", "open for the pad B row")
        H.play(1.5)
        H.eq(page().picker, nil, "closes after a pause")
        H.tap("RIGHT")
        H.tap("DOWN")
        H.eq(page().picker, nil, "moving the cursor closes it")
        H.tap("RIGHT")                                    -- TUNE: a number
        H.eq(page().picker, nil, "no picker for a number row")
        H.release("SELECT"); H.play(0.1)
    end },

    { "Track page: face tap toggles an effect and jumps to its row; LEFT/RIGHT set the amount", function()
        local _, L = boot()
        local fx = L.tracks[1].fx
        H.hold("SELECT"); H.play(0.3)
        H.tap("X")
        H.truthy(fx.on.tone, "X tap: tone on")
        H.eq(page().row, 9, "cursor on the TONE row")
        H.tap("RIGHT")
        H.near(fx.tone, 0.6, "RIGHT: tone +10 %", 1e-9)
        H.tap("X")
        H.falsy(fx.on.tone, "X tap again: tone off")
        H.near(fx.tone, 0.6, "the amount is kept", 1e-9)
        H.tap("B")
        H.eq(page().row, 12, "B: the SPACE row")
        for _ = 1, 8 do H.tap("LEFT") end
        H.eq(fx.space, 0, "LEFT down to exactly 0")
        H.falsy(fx.on.space, "0 switches it off")
        H.tap("RIGHT")
        H.truthy(fx.on.space, "changing the amount switches it on")
        H.near(fx.space, 0.1, "10 %", 1e-9)
        H.release("SELECT"); H.play(0.1)
    end },

    { "Track page: L1/R1 preview an instrument; release SELECT applies it", function()
        local _, L = boot()
        H.tap("L2"); H.tap("B"); H.tap("L2")
        H.hold("SELECT"); H.play(0.3)
        local I = require("src.instruments")
        H.tap("R1")
        H.eq(page().pending, I.catalog[2].id, "next instrument previewed")
        H.eq(L.tracks[1].instrumentId, "drums", "not swapped yet")
        local kit = L.tracks[1].state.kitIndex
        H.tap("RIGHT"); H.tap("X")
        H.eq(L.tracks[1].state.kitIndex, kit, "rows wait while a swap is previewed")
        H.falsy(L.tracks[1].fx.on.tone, "so do the effects")
        H.tap("R1")
        H.eq(page().pending, I.catalog[3].id, "next preview")
        H.release("SELECT"); H.play(0.1)
        H.eq(L.tracks[1].instrumentId, I.catalog[3].id, "swapped on release")
        H.eq(#L.tracks[1].events, 0, "drum events stashed")
        H.eq(page().pending, nil, "preview cleared")
        H.eq(L.activeTrack, 1, "release did not change track")
    end },

    { "Track page: stepping back to the current instrument cancels the swap", function()
        local _, L = boot()
        H.hold("SELECT"); H.play(0.3)
        H.tap("R1"); H.tap("L1")
        H.eq(page().pending, nil, "no preview")
        H.release("SELECT"); H.play(0.1)
        H.eq(L.tracks[1].instrumentId, "drums", "still drums")
        H.eq(#L.undoStack, 0, "nothing to undo")
    end },

    { "L2 + R2 + LEFT undoes an instrument swap", function()
        local _, L = boot()
        H.tap("L2"); H.tap("B"); H.tap("L2")
        local kit = L.tracks[1].state.kitIndex
        H.hold("SELECT"); H.play(0.3); H.tap("R1"); H.release("SELECT"); H.play(0.1)
        H.eq(L.tracks[1].instrumentId, require("src.instruments").catalog[2].id, "swapped")
        H.hold("L2", "R2"); H.play(0.1); H.tap("LEFT"); H.release("L2", "R2"); H.play(0.1)
        H.eq(L.tracks[1].instrumentId, "drums", "drums back")
        H.eq(#L.tracks[1].events, 1, "hit back")
        H.eq(L.tracks[1].state.kitIndex, kit, "kit kept")
    end },

    { "Track page: harp COLOUR row changes the chord", function()
        local _, L = boot()
        H.tap("SELECT")                                   -- track 2 = harp
        local st = L.tracks[2].state
        H.eq(st.currentChord.name, "C", "triad")
        H.hold("SELECT"); H.play(0.3)
        H.eq(page().row, 1, "opens on PATCH")
        H.tap("DOWN")
        H.eq(page().row, 2, "COLOUR row")
        H.tap("RIGHT")
        H.eq(st.colour, "7TH", "RIGHT -> 7TH")
        H.release("SELECT"); H.play(0.1)
        H.eq(st.currentChord.name, "Cmaj7", "chord is maj7")
        H.eq(st.currentChord.notes[4], 11, "string 4 = major 7th")
        H.hold("SELECT"); H.play(0.3); H.tap("DOWN"); H.tap("LEFT"); H.tap("LEFT")
        H.eq(st.colour, "DIM", "LEFT twice wraps back to the last colour (DIM)")
        H.release("SELECT"); H.play(0.1)
    end },

    { "Track page: LEFT/RIGHT on the harp's PATCH row steps through the sound pool", function()
        local _, L = boot()
        H.tap("SELECT")                                  -- track 2 = harp
        H.eq(L.tracks[2].state.patch, "harp", "starts on its own sound")
        H.hold("SELECT"); H.play(0.3); H.tap("RIGHT"); H.release("SELECT"); H.play(0.1)
        H.eq(L.tracks[2].state.patch, "pluck_nylon", "the next sound in its group")
        H.eq(L.toastText, "HARP PATCH: NYLON STRING", "toast")
    end },

    { "every list row has items and an index inside them; number rows have an amount", function()
        local M, L = boot()
        for slot = 1, 4 do
            local def, state, track = M.Instruments:getTrackInstrument(slot)
            local rows = M.Instruments:getSoundRows(def, state, track)
            H.eq(rows[#rows].key, "FX_space", "the four effects come last")
            for _, row in ipairs(rows) do
                local what = def.id .. " " .. row.key
                if row.items then
                    H.truthy(row.index >= 1 and row.index <= #row.items, what .. ": index")
                    H.eq(row.amount, nil, what .. ": a list, not a number")
                else
                    H.truthy(row.amount >= 0 and row.amount <= 1, what .. ": amount")
                end
            end
        end
        local groups, seen = {}, {}
        for _, it in ipairs(M.Instruments:getDefinition("drums"):soundItems()) do
            if groups[#groups] ~= it.group then
                H.falsy(seen[it.group], "drum group " .. it.group .. " is in one piece")
                groups[#groups + 1], seen[it.group] = it.group, true
            end
        end
    end },

    { "Track page blocks playing: face buttons don't trigger the instrument", function()
        local _, L = boot()
        H.tap("L2")                                   -- latch record
        H.hold("SELECT"); H.play(0.3)
        H.tap("Y")
        H.release("SELECT"); H.play(0.1)
        H.eq(#L.tracks[1].events, 0, "nothing recorded")
    end },

    -- ------------------------------------------------------------------
    -- Mix page (SELECT + R2)
    -- ------------------------------------------------------------------
    { "Mix page: choose track, level, mutes, master trim", function()
        local M, L = boot()
        H.hold("SELECT", "R2"); H.play(0.1)
        H.tap("RIGHT")
        H.eq(mixTrack(), 2, "RIGHT -> track 2")
        local v = L.tracks[2].volume
        H.tap("UP")
        H.near(L.tracks[2].volume, v + 0.08, "UP raises track 2", 1e-6)
        H.tap("B")
        H.truthy(L.tracks[1].muted, "B mutes track 1")
        local mv = M.Synth.masterVolume
        H.tap("L1")
        H.near(M.Synth.masterVolume, mv - 0.1, "L1 master -10 %", 1e-6)
        for _ = 1, 4 do H.tap("RIGHT") end
        H.eq(mixTrack(), 1, "wraps through master (5) back to 1")
        H.release("SELECT", "R2"); H.play(0.1)
        H.eq(L.activeTrack, 1, "closing the mix page does not change track")
    end },

    -- ------------------------------------------------------------------
    -- Transport (hold START) and START tap
    -- ------------------------------------------------------------------
    { "Transport: tempo, key, scale, bars, grid, swing, click", function()
        local M, L = boot()
        local T, C = M.Theory, M.Config
        local playing = L.playing
        H.hold("START"); H.play(0.3)
        H.tap("UP");    H.eq(L.bpm, C.DEFAULT_BPM + 5, "UP tempo +5")
        H.tap("DOWN");  H.eq(L.bpm, C.DEFAULT_BPM, "DOWN tempo -5")
        H.tap("RIGHT"); H.eq(T.rootIndex, 2, "RIGHT key up")
        H.tap("LEFT");  H.eq(T.rootIndex, 1, "LEFT key down")
        H.tap("R1");    H.eq(T.scaleIndex, 2, "R1 next scale")
        H.tap("L1");    H.eq(T.scaleIndex, 1, "L1 previous scale")
        H.tap("B");     H.eq(L.bars, 4, "B -> 4 bars")
        H.tap("A");     H.eq(L.tracks[1].gridIndex, 4, "A -> next grid")
        H.hold("Y"); H.play(0.05); H.tap("UP"); H.release("Y"); H.play(0.05)
        H.near(L.tracks[1].swing, 0.52, "Y + UP swing +2 %", 1e-6)
        H.eq(L.bpm, C.DEFAULT_BPM, "Y + UP does not change tempo")
        H.tap("X");     H.truthy(L.clickOn, "X click on")
        H.release("START"); H.play(0.1)
        H.eq(L.playing, playing, "closing Transport does not toggle play")
    end },

    { "SELECT tap on the Transport page changes track (to set its grid/swing)", function()
        local _, L = boot()
        H.hold("START"); H.play(0.3)
        H.tap("SELECT")
        H.eq(L.activeTrack, 2, "track 2")
        H.tap("A")
        H.eq(L:getTrackGrid(2).id, "1/4", "A changed track 2's grid (harp FREE -> 1/4)")
        H.release("START"); H.play(0.1)
    end },

    { "START tap pauses and resumes; double tap resets to bar 1", function()
        local _, L = boot()
        H.tap("START")
        H.falsy(L.playing, "paused")
        H.play(0.5)
        H.tap("START")
        H.truthy(L.playing, "playing")
        H.play(1.0)
        H.truthy(L.phase > 0.1, "playhead moved")
        H.tap("START"); H.tap("START")
        H.truthy(L.playing, "double tap leaves it playing")
        H.truthy(L.phase < 0.05, "double tap reset the playhead")
    end },

    -- ------------------------------------------------------------------
    -- R2: mutes and live FX
    -- ------------------------------------------------------------------
    { "R2 + face mutes tracks; R2 + D-pad holds live FX", function()
        local M, L = boot()
        local S = M.Synth
        H.hold("R2"); H.play(0.05)
        H.tap("A")
        H.truthy(L.tracks[2].muted, "R2 + A mutes track 2")
        H.tap("A")
        H.falsy(L.tracks[2].muted, "again unmutes")
        H.hold("UP"); H.play(0.1)
        H.truthy(S.fxBeatRepeat, "R2 + UP stutter")
        H.release("UP"); H.hold("LEFT"); H.play(0.1)
        H.falsy(S.fxBeatRepeat, "stutter off when UP released")
        H.truthy(S.fxLowPass, "R2 + LEFT filter")
        H.release("LEFT", "R2"); H.play(0.1)
        H.falsy(S.fxLowPass, "FX off when R2 released")
        H.eq(#L.tracks[1].events, 0, "R2 + face never plays the pads")
    end },

    { "live FX switch off when another page takes over from R2", function()
        local M = boot()
        H.hold("R2", "UP"); H.play(0.1)
        H.truthy(M.Synth.fxBeatRepeat, "stutter on")
        H.hold("SELECT"); H.play(0.1)
        H.eq(H.mode(), "MIX", "SELECT + R2 = mix page")
        H.falsy(M.Synth.fxBeatRepeat, "stutter stopped in the mix page")
        H.release("R2", "UP", "SELECT"); H.play(0.1)
    end },

    -- ------------------------------------------------------------------
    -- Erase (L2 + R2) and clear
    -- ------------------------------------------------------------------
    { "L2 + R2 + face erases that pad; release does not toggle recording", function()
        local _, L, I = boot()
        H.tap("L2"); H.tap("B"); H.play(0.2); H.tap("A"); H.tap("L2")
        H.eq(#L.tracks[1].events, 2, "two hits recorded")
        H.hold("L2", "R2"); H.play(0.1)
        H.tap("B")
        H.release("L2", "R2"); H.play(0.1)
        H.eq(#L.tracks[1].events, 1, "B erased")
        H.eq(L.tracks[1].events[1].action, "A", "A kept")
        H.falsy(I.recLatched, "erase did not latch recording")
    end },

    { "L2 + R2 + LEFT undoes the last take", function()
        local _, L = boot()
        H.tap("L2"); H.tap("B"); H.tap("L2")
        H.tap("L2"); H.play(0.2); H.tap("A"); H.tap("L2")
        H.eq(#L.tracks[1].events, 2, "two takes")
        H.hold("L2", "R2"); H.play(0.1)
        H.tap("LEFT")
        H.release("L2", "R2"); H.play(0.1)
        H.eq(#L.tracks[1].events, 1, "last take undone")
        H.eq(L.tracks[1].events[1].action, "B", "first take kept")
    end },

    { "L2 + R2 + START clears the track without toggling play", function()
        local _, L = boot()
        H.tap("L2"); H.tap("B"); H.tap("L2")
        H.hold("L2", "R2"); H.play(0.1)
        H.tap("START")
        H.release("L2", "R2"); H.play(0.1)
        H.eq(#L.tracks[1].events, 0, "cleared")
        H.truthy(L.playing, "still playing")
    end },

    { "L2 + START clears the track; L2 release does not latch", function()
        local _, L, I = boot()
        H.tap("L2"); H.tap("B"); H.tap("L2")
        H.hold("L2"); H.play(0.05)
        H.tap("START")
        H.release("L2"); H.play(0.1)
        H.eq(#L.tracks[1].events, 0, "cleared")
        H.falsy(I.recLatched, "not latched")
        H.truthy(L.playing, "still playing")
    end },

    -- ------------------------------------------------------------------
    -- Fresh session: hold L2 + R2 + SELECT (C4)
    -- ------------------------------------------------------------------
    { "a short L2 + R2 + SELECT does nothing; a 1 s hold clears every track once", function()
        local M, L = boot()
        H.tap("L2"); H.tap("B"); H.tap("L2")                 -- drums
        H.tap("SELECT"); H.tap("L2"); H.tap("A"); H.tap("L2") -- harp
        L.tracks[2].muted = true
        H.hold("L2", "R2", "SELECT"); H.play(0.5)
        H.eq(H.mode(), "NEW", "fresh-session mode")
        H.eq(#L.tracks[1].events, 1, "not yet after 0.5 s")
        H.play(0.6)
        H.eq(#L.tracks[1].events, 0, "drums cleared")
        H.eq(#L.tracks[2].events, 0, "harp cleared")
        H.falsy(L.tracks[2].muted, "mutes cleared")
        L.tracks[1].events[1] = { tick = 0, len = 0, action = "B", vel = 0.8 }   -- something new
        H.play(1.5)
        H.eq(#L.tracks[1].events, 1, "fires once per hold, not again while held")
        H.release("L2", "R2", "SELECT"); H.play(0.1)
        H.falsy(M.Input.recLatched, "releasing doesn't latch recording")
        H.eq(L.activeTrack, 2, "releasing SELECT doesn't change track")
    end },

    { "a fresh session keeps tempo, key, instruments, sounds and effects", function()
        local M, L = boot()
        L.bpm = 140
        M.Theory.rootIndex = 5
        M.Instruments:swapTrackInstrument(4, "bass")
        L.tracks[4].state.patch = "bass_sub"
        L.tracks[1].fx.on.space = true
        L.tracks[1].swing = 0.6
        H.hold("L2", "R2", "SELECT"); H.play(1.2); H.release("L2", "R2", "SELECT"); H.play(0.1)
        H.eq(L.bpm, 140, "tempo")
        H.eq(M.Theory.rootIndex, 5, "key")
        H.eq(L.tracks[4].instrumentId, "bass", "instrument")
        H.eq(L.tracks[4].state.patch, "bass_sub", "sound")
        H.truthy(L.tracks[1].fx.on.space, "effect")
        H.eq(L.tracks[1].swing, 0.6, "swing")
    end },

    { "undo brings the whole session back", function()
        local M, L = boot()
        H.tap("L2"); H.tap("B"); H.play(0.3); H.tap("Y"); H.tap("L2")
        H.tap("SELECT"); H.tap("L2"); H.tap("A"); H.tap("L2")
        L.tracks[3].muted = true
        H.hold("L2", "R2", "SELECT"); H.play(1.2); H.release("SELECT"); H.play(0.1)
        H.tap("LEFT")                                          -- still holding L2 + R2: undo
        H.release("L2", "R2"); H.play(0.1)
        H.eq(#L.tracks[1].events, 2, "drum notes back")
        H.eq(#L.tracks[2].events, 1, "harp note back")
        H.truthy(L.tracks[3].muted, "mute back")
    end },

    { "a fresh session silences what's playing", function()
        local M, L = boot()
        for _ = 1, 3 do H.tap("SELECT") end
        H.tap("L2"); H.hold("B"); H.play(1.5); H.release("B"); H.play(0.05); H.tap("L2")
        local st = L.tracks[4].state
        local t = 0
        while next(st.playing) == nil and t < L:getLoopDuration() * 1.2 do H.play(1 / 60); t = t + 1 / 60 end
        H.truthy(next(st.playing) ~= nil, "pad playing")
        H.hold("L2", "R2", "SELECT"); H.play(1.2)
        H.eq(next(st.playing), nil, "silenced")
        H.release("L2", "R2", "SELECT"); H.play(0.1)
    end },

    { "erase, undo and clear-track still work with L2 + R2 alone", function()
        local _, L = boot()
        H.tap("L2"); H.tap("B"); H.play(0.3); H.tap("Y"); H.tap("L2")
        H.hold("L2", "R2"); H.play(0.1)
        H.eq(H.mode(), "ERASE", "erase mode without SELECT")
        H.tap("B")
        H.release("L2", "R2"); H.play(0.1)
        H.eq(#L.tracks[1].events, 1, "pad B erased only")
    end },
}
