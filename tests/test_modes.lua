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

    { "Track page: opens on the last pad, rows move, L1/R1 change the sound", function()
        local _, L = boot()
        local st = L.tracks[1].state
        H.hold("SELECT"); H.play(0.3)
        H.eq(page().row, 5, "opens on pad B (row 5)")
        local before = st.padCatalogIndex.B
        H.tap("R1")
        H.truthy(st.padCatalogIndex.B ~= before, "R1 changed pad B's sound")
        H.tap("DOWN")
        H.eq(page().row, 1, "DOWN wraps to the KIT row")
        H.tap("UP")
        H.eq(page().row, 5, "UP wraps back")
        H.release("SELECT"); H.play(0.1)
        H.eq(L.activeTrack, 1, "closing the page does not change track")
    end },

    { "Track page: face tap toggles an effect; hold + UP/DOWN sets its amount", function()
        local _, L = boot()
        local fx = L.tracks[1].fx
        H.hold("SELECT"); H.play(0.3)
        H.tap("X")
        H.truthy(fx.on.tone, "X tap: tone on")
        H.tap("X")
        H.falsy(fx.on.tone, "X tap again: tone off")
        H.hold("X"); H.play(0.05)
        H.tap("UP")
        H.release("X"); H.play(0.05)
        H.near(fx.tone, 0.6, "tone amount +10 %", 1e-6)
        H.truthy(fx.on.tone, "adjusting switches it on, release does not toggle")
        H.release("SELECT"); H.play(0.1)
    end },

    { "Track page: LEFT/RIGHT preview an instrument; release SELECT applies it", function()
        local _, L = boot()
        H.tap("L2"); H.tap("B"); H.tap("L2")
        H.hold("SELECT"); H.play(0.3)
        H.tap("RIGHT")
        H.eq(page().pending, "harp", "harp previewed")
        H.eq(L.tracks[1].instrumentId, "drums", "not swapped yet")
        H.tap("RIGHT")
        H.eq(page().pending, "bass", "next preview")
        H.release("SELECT"); H.play(0.1)
        H.eq(L.tracks[1].instrumentId, "bass", "swapped on release")
        H.eq(#L.tracks[1].events, 0, "drum events stashed")
        H.eq(page().pending, nil, "preview cleared")
        H.eq(L.activeTrack, 1, "release did not change track")
    end },

    { "Track page: stepping back to the current instrument cancels the swap", function()
        local _, L = boot()
        H.hold("SELECT"); H.play(0.3)
        H.tap("RIGHT"); H.tap("LEFT")
        H.eq(page().pending, nil, "no preview")
        H.release("SELECT"); H.play(0.1)
        H.eq(L.tracks[1].instrumentId, "drums", "still drums")
        H.eq(#L.undoStack, 0, "nothing to undo")
    end },

    { "L2 + R2 + LEFT undoes an instrument swap", function()
        local _, L = boot()
        H.tap("L2"); H.tap("B"); H.tap("L2")
        local kit = L.tracks[1].state.kitIndex
        H.hold("SELECT"); H.play(0.3); H.tap("RIGHT"); H.release("SELECT"); H.play(0.1)
        H.eq(L.tracks[1].instrumentId, "harp", "swapped")
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
        H.tap("R1")
        H.eq(st.colour, "7TH", "R1 -> 7TH")
        H.release("SELECT"); H.play(0.1)
        H.eq(st.currentChord.name, "Cmaj7", "chord is maj7")
        H.eq(st.currentChord.notes[4], 11, "string 4 = major 7th")
        H.hold("SELECT"); H.play(0.3); H.tap("DOWN"); H.tap("L1"); H.tap("L1")
        H.eq(st.colour, "ADD9", "L1 twice wraps back to ADD9")
        H.release("SELECT"); H.play(0.1)
    end },

    { "Track page: L1/R1 on a PATCH-only row just shows a toast", function()
        local _, L = boot()
        H.tap("SELECT"); H.tap("SELECT")                  -- track 3 = bass
        H.hold("SELECT"); H.play(0.3); H.tap("R1"); H.release("SELECT"); H.play(0.1)
        H.eq(L.toastText, "RIBBON BASS: ONE PATCH FOR NOW", "toast")
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
        H.truthy(S.fxLowPass, "R2 + LEFT duck")
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
}
