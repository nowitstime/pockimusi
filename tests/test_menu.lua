-- The menu (hold SELECT + START) and pattern slots A–H
local H = require("helpers")

local function boot(keep)
    H.keepFiles = keep or false
    local M = H.loadMain()
    H.keepFiles = false
    M.Menu = require("src.menu")
    M.Patterns = require("src.patterns")
    M.Fonts = require("src.ui.fonts")
    H.play(0.1)
    return M
end

local function openMenu()
    H.hold("SELECT", "START"); H.play(1.1)
    H.release("SELECT", "START"); H.play(0.1)
end

local function recordHit(btn)
    H.tap("L2"); H.tap(btn or "B"); H.tap("L2")
end

local function noteCount(L)
    local n = 0
    for i = 1, 4 do n = n + #L.tracks[i].events end
    return n
end

-- Move the root cursor to an item by id
local function goTo(M, id)
    for _ = 1, #M.Menu.ITEMS do
        if M.Menu.ITEMS[M.Menu.row].id == id then return end
        H.tap("DOWN")
    end
    error("no menu item " .. id)
end

local function goToSlot(M, slot)
    for _ = 1, #M.Patterns.SLOTS do
        if M.Patterns.SLOTS[M.Menu.slotRow] == slot then return end
        H.tap("DOWN")
    end
    error("no slot " .. slot)
end

return {
    { "holding SELECT + START a moment opens the menu", function()
        local M = boot()
        H.hold("SELECT", "START"); H.play(0.15)
        H.eq(H.mode(), "MENU_HOLD", "counting up")
        H.falsy(M.Menu.open, "not yet")
        H.play(0.2)
        H.truthy(M.Menu.open, "open")
        H.release("SELECT", "START"); H.play(0.1)
        H.eq(H.mode(), "MENU", "menu mode")
    end },

    { "a short SELECT + START does nothing, and neither release is a tap", function()
        local M = boot()
        local playing, track = M.Looper.playing, M.Looper.activeTrack
        H.hold("SELECT", "START"); H.play(0.15)
        H.release("SELECT", "START"); H.play(0.1)
        H.falsy(M.Menu.open, "closed")
        H.eq(M.Looper.playing, playing, "clock unchanged")
        H.eq(M.Looper.activeTrack, track, "track unchanged")
    end },

    { "opening from the Track page or the Clock page works too", function()
        local M = boot()
        H.hold("SELECT"); H.play(0.3)
        H.eq(H.mode(), "TRACK", "track page")
        H.hold("START"); H.play(1.1)
        H.truthy(M.Menu.open, "open from TRACK")
        H.release("SELECT", "START"); H.play(0.1)
        H.tap("START"); H.play(0.1)
        H.falsy(M.Menu:isActive(), "closed")

        H.hold("START"); H.play(0.3)
        H.eq(H.mode(), "TRANSPORT", "clock page")
        H.tap("SELECT")
        H.falsy(M.Menu.open, "a SELECT tap on the clock page isn't the menu")
        H.hold("SELECT"); H.play(1.1)
        H.truthy(M.Menu.open, "open from TRANSPORT")
        H.release("SELECT", "START"); H.play(0.1)
    end },

    { "START closes it, and its release doesn't pause the clock", function()
        local M = boot()
        local playing = M.Looper.playing
        openMenu()
        H.tap("START"); H.play(0.1)
        H.falsy(M.Menu:isActive(), "closed")
        H.eq(M.Looper.playing, playing, "clock unchanged")
        H.eq(H.mode(), "NORMAL", "back to playing")
    end },

    { "after the menu, a SELECT tap still changes track (and L2 still records)", function()
        local M = boot()
        openMenu()
        H.tap("START"); H.play(0.1)
        local t = M.Looper.activeTrack
        H.tap("SELECT")
        H.eq(M.Looper.activeTrack, t % #M.Looper.tracks + 1, "next track")
        H.tap("L2")
        H.truthy(M.Input.recLatched, "record latches")
    end },

    { "the instrument and record are blocked while it's open", function()
        local M = boot()
        openMenu()
        H.tap("L2"); H.tap("X"); H.tap("Y")
        H.falsy(M.Input.recLatched, "L2 didn't latch record")
        H.eq(noteCount(M.Looper), 0, "no notes recorded")
    end },

    { "A backs out of the top list and closes", function()
        local M = boot()
        openMenu()
        goTo(M, "SAVE"); H.tap("B")
        H.eq(M.Menu.page, "SAVE", "slot list")
        H.tap("A")
        H.eq(M.Menu.page, "ROOT", "back")
        H.tap("A"); H.play(0.1)
        H.falsy(M.Menu:isActive(), "closed")
    end },

    { "save to a slot, change the loop, load it back", function()
        local M = boot()
        recordHit("B")
        local n = noteCount(M.Looper)
        H.truthy(n > 0, "a note recorded")
        M.Looper.bpm = 133

        openMenu()
        goTo(M, "SAVE"); H.tap("B")
        goToSlot(M, "B"); H.tap("B"); H.play(0.1)
        H.falsy(M.Menu:isActive(), "closes after saving")
        H.truthy(H.files["pattern_b.txt"], "file written")
        H.eq(M.Session.patternSlot, "B", "current pattern")

        -- something new
        M.Looper:clearTrack(M.Looper.activeTrack)
        for i = 1, 4 do M.Looper.tracks[i].events = {} end
        M.Looper.bpm = 90
        H.eq(noteCount(M.Looper), 0, "cleared")

        openMenu()
        goTo(M, "LOAD"); H.tap("B")
        H.eq(M.Patterns.SLOTS[M.Menu.slotRow], "B", "cursor starts on the current pattern")
        H.tap("B")
        H.truthy(M.Menu.open, "first B only asks")
        H.eq(M.Menu.confirm, "B", "waiting to confirm")
        H.tap("B"); H.play(0.1)
        H.falsy(M.Menu:isActive(), "closed after loading")
        H.eq(noteCount(M.Looper), n, "notes back")
        H.eq(M.Looper.bpm, 133, "tempo back")
    end },

    { "saving over a full slot asks first; moving cancels", function()
        local M = boot()
        recordHit("B")
        M.Patterns.save("A")
        local first = H.files["pattern_a.txt"]
        recordHit("A")
        openMenu()
        goTo(M, "SAVE"); H.tap("B")
        goToSlot(M, "A"); H.tap("B")
        H.eq(M.Menu.confirm, "A", "asks")
        H.eq(H.files["pattern_a.txt"], first, "not written yet")
        H.tap("DOWN"); H.tap("UP")
        H.eq(M.Menu.confirm, nil, "moving cancels")
        H.tap("B"); H.tap("B"); H.play(0.1)
        H.truthy(H.files["pattern_a.txt"] ~= first, "overwritten")
    end },

    { "an empty slot can't be loaded", function()
        local M = boot()
        recordHit("B")
        local n = noteCount(M.Looper)
        openMenu()
        goTo(M, "LOAD"); H.tap("B")
        goToSlot(M, "E"); H.tap("B"); H.tap("B")
        H.truthy(M.Menu.open, "still open")
        H.eq(noteCount(M.Looper), n, "loop untouched")
    end },

    { "a broken slot file leaves the loop on screen alone", function()
        local M = boot()
        recordHit("B")
        local n = noteCount(M.Looper)
        H.files["pattern_c.txt"] = "{slot=\"C\",session={format=99}}"
        local ok = M.Patterns.load("C")
        H.falsy(ok, "refused")
        H.eq(noteCount(M.Looper), n, "notes kept")
        H.eq(M.Patterns.summary("D").empty, true, "D empty")
        H.files["pattern_d.txt"] = "garbage("
        H.eq(M.Patterns.summary("D").broken, true, "D broken")
    end },

    { "the slot summary reads tempo, key, instruments and notes", function()
        local M = boot()
        recordHit("B")
        M.Looper.bpm = 101
        M.Patterns.save("H")
        local s = M.Patterns.summary("H")
        H.eq(s.bpm, 101, "bpm")
        H.eq(s.notes, noteCount(M.Looper), "notes")
        H.eq(#s.instruments, 4, "four instruments")
        H.truthy(type(s.key) == "string" and #s.key > 0, "key")
    end },

    { "the slot summary maps each track's notes onto the loop", function()
        local M = boot()
        local L = M.Looper
        local loop = L:getLoopTicks()
        L.tracks[3].events = { { tick = loop / 2, len = loop / 4, action = "B", vel = 0.8, degree = 1, octave = 0 } }
        L.tracks[2].muted = true
        M.Patterns.save("G")
        local s = M.Patterns.summary("G")
        H.eq(s.bars, L.bars, "bars")
        H.eq(#s.lanes, 4, "four lanes")
        H.eq(#s.lanes[3].notes, 1, "one note on track 3")
        H.near(s.lanes[3].notes[1][1], 0.5, "starts halfway")
        H.near(s.lanes[3].notes[1][2], 0.75, "lasts a quarter")
        H.truthy(s.lanes[2].muted, "mute shown")
        H.eq(s.lanes[1].id, L.tracks[1].instrumentId, "instrument id for the colour")
    end },

    { "the current pattern survives a reboot (autosave)", function()
        local M = boot()
        M.Patterns.save("F")
        M.Autosave = require("src.autosave")
        M.Autosave:saveNow()
        local M2 = boot(true)
        H.eq(M2.Session.patternSlot, "F", "still pattern F")
    end },

    { "fonts change from the menu, both ways, and are remembered", function()
        local M = boot()
        local start = M.Fonts.set
        openMenu()
        goTo(M, "FONTS")
        H.tap("RIGHT")
        local nextSet = M.Fonts.set
        H.truthy(nextSet ~= start, "changed")
        H.truthy(H.files["display.txt"]:find("font=" .. nextSet), "remembered")
        H.tap("LEFT")
        H.eq(M.Fonts.set, start, "back")
    end },

    { "song mode is listed but not built yet", function()
        local M = boot()
        openMenu()
        goTo(M, "SONG"); H.tap("B")
        H.truthy(M.Menu.open, "still open")
        H.truthy(M.Menu.message, "says it's coming")
    end },

    { "the menu draws in every page without errors", function()
        local M = boot()
        local Chrome = require("src.ui.chrome")
        H.hold("SELECT", "START"); H.play(0.15)
        Chrome:draw()
        H.play(0.3); H.release("SELECT", "START"); H.play(0.1)
        Chrome:draw()
        M.Patterns.save("A")
        goTo(M, "SAVE"); H.tap("B"); Chrome:draw()
        H.tap("A"); goTo(M, "LOAD"); H.tap("B"); Chrome:draw()
        H.tap("B"); Chrome:draw()
    end },
}
