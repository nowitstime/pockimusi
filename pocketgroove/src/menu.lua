-- ============================================================================
-- src/menu.lua — The menu: hold SELECT + START for about a second
--
-- The music keeps playing underneath; the instrument is blocked while the
-- menu is up.
--
--   UP / DOWN     move
--   B             choose (on a full slot: press again to confirm)
--   LEFT / RIGHT  change a value (fonts)
--   A             back (closes from the top list)
--   START         close
--
-- Items:
--   GO TO PATTERN switch to slot A–H; the loop on screen is kept in its own
--                 slot first (living slots, src/patterns.lua). An empty slot
--                 starts a new pattern with the same setup
--   COPY PATTERN  the loop on screen into another slot (asks if it's full)
--   CLEAR PATTERN empty a slot (asks first; not the one on screen)
--   SONG MODE     on / off (PHASE_M)
--   FONTS         the font set (src/ui/fonts.lua), changed live
--
-- Opening waits until every button is let go, so the hold that opened it
-- does nothing inside; closing waits too, so the button that closed it does
-- nothing outside (a START release is not a play / pause tap).
-- ============================================================================

local Input    = require("src.input")
local Looper   = require("src.looper")
local Session  = require("src.session")
local Patterns = require("src.patterns")
local Song     = require("src.song")

local Menu = {
    HOLD = 0.3,              -- seconds SELECT + START are held to open (just past a tap)
    MESSAGE_TIME = 2.4,

    ITEMS = {
        { id = "GOTO",  label = "GO TO PATTERN", hint = "SWITCH - NOTHING IS LOST" },
        { id = "COPY",  label = "COPY PATTERN",  hint = "THIS LOOP INTO ANOTHER SLOT" },
        { id = "CLEAR", label = "CLEAR PATTERN", hint = "EMPTY A SLOT" },
        { id = "SONG",  label = "SONG MODE",     hint = "THE S PAGE: PERFORM A SONG FROM YOUR PATTERNS" },
        { id = "FONTS", label = "FONTS",        hint = "LEFT / RIGHT TO CHANGE" },
    },

    open = false,
    closing = false,         -- closed; waiting for every button to be let go
    waitRelease = false,     -- just opened; waiting for every button to be let go
    page = "ROOT",           -- ROOT, GOTO, COPY, CLEAR
    row = 1,                 -- cursor on the top list
    slotRow = 1,             -- cursor on the slot list
    confirm = nil,           -- the slot waiting for a second B
    slots = {},              -- slot -> Patterns.summary, read when a slot list opens
    message = nil,           -- a line under the list, and how long it stays
    messageTimer = 0.0,
}

local function anyDown()
    for _, btn in ipairs(Input.BUTTON_LIST) do
        if Input.down[btn] then return true end
    end
    return false
end

local function wrap(i, n)
    return ((i - 1) % n) + 1
end

function Menu:isActive()
    return self.open or self.closing
end

function Menu:say(text)
    self.message, self.messageTimer = text, self.MESSAGE_TIME
end

function Menu:openMenu()
    self.open, self.closing, self.waitRelease = true, false, true
    self.page, self.row, self.confirm = "ROOT", 1, nil
    self.message, self.messageTimer = nil, 0.0
end

-- Close; `toast` shows in the footer once the menu is gone
function Menu:close(toast)
    self.open, self.closing, self.confirm = false, true, nil
    if toast then Looper:showToast(toast) end
end

function Menu:refreshSlots()
    self.slots = {}
    for _, s in ipairs(Patterns.SLOTS) do
        self.slots[s] = Patterns.summary(s)
    end
end

-- The slot the cursor starts on: going to, the current pattern; copying,
-- the first empty slot; clearing, the first full one that isn't on screen
local function startRow(menu, page)
    if page == "GOTO" then
        for i, s in ipairs(Patterns.SLOTS) do
            if s == Session.patternSlot then return i end
        end
    end
    for i, s in ipairs(Patterns.SLOTS) do
        local sum = menu.slots[s]
        if sum and s ~= Session.patternSlot and (sum.empty == true) == (page == "COPY") then return i end
    end
    return 1
end

function Menu:openSlots(page)
    Patterns.flush()             -- so the list shows the pattern on screen as it is
    self:refreshSlots()
    self.page, self.confirm = page, nil
    self.slotRow = startRow(self, page)
end

function Menu:changeFonts(dir)
    local label = require("src.ui.chrome"):cycleFonts(dir)
    self:say(label)
end

-- ---------------------------------------------------------------------------
-- Pages
-- ---------------------------------------------------------------------------
local function updateRoot(menu)
    local n = #menu.ITEMS
    if Input.repeated.UP then menu.row = wrap(menu.row - 1, n) end
    if Input.repeated.DOWN then menu.row = wrap(menu.row + 1, n) end
    local item = menu.ITEMS[menu.row]

    if item.id == "FONTS" and (Input.pressed.LEFT or Input.pressed.RIGHT) then
        menu:changeFonts(Input.pressed.LEFT and -1 or 1)
    end
    if item.id == "SONG" and (Input.pressed.LEFT or Input.pressed.RIGHT) then
        Song:setOn(not Song:isOn())
        menu:say(Song:isOn() and "SONG MODE ON - SELECT TAPS REACH S" or "SONG MODE OFF")
    end

    if Input.pressed.A then return menu:close() end
    if not Input.pressed.B then return end
    if item.id == "GOTO" or item.id == "COPY" or item.id == "CLEAR" then
        menu:openSlots(item.id)
    elseif item.id == "FONTS" then
        menu:changeFonts(1)
    elseif item.id == "SONG" then
        Song:setOn(not Song:isOn())
        if Song:isOn() then
            Song:goToPage()
            return menu:close("SONG MODE ON - THIS IS S")
        end
        return menu:close("SONG MODE OFF")
    end
end

local function updateSlots(menu)
    local n = #Patterns.SLOTS
    if Input.repeated.UP or Input.repeated.DOWN then
        menu.slotRow = wrap(menu.slotRow + (Input.repeated.UP and -1 or 1), n)
        menu.confirm = nil
    end
    if Input.pressed.A then
        menu.page, menu.confirm = "ROOT", nil
        return
    end
    if not Input.pressed.B then return end

    local slot = Patterns.SLOTS[menu.slotRow]
    local sum = menu.slots[slot] or {}
    local isNow = (slot == Session.patternSlot)
    if menu.page == "GOTO" then
        if isNow then return menu:close("ALREADY ON PATTERN " .. slot) end
        if sum.broken then return menu:say("PATTERN " .. slot .. " COULDN'T BE READ") end
        -- song mode stays as it is (the slot's file carries its own flag)
        local wasSong = Session.songMode
        if Song.playing or Song.recording or Song.armed then Song:stop() end
        local ok, err = Patterns.goTo(slot)
        Session.songMode = wasSong
        if ok then return menu:close(sum.empty and ("NEW PATTERN " .. slot) or ("PATTERN " .. slot)) end
        menu:say(err)
    elseif menu.page == "COPY" then
        if isNow then return menu:say("THAT'S THE PATTERN ON SCREEN") end
        if not sum.empty and menu.confirm ~= slot then
            menu.confirm = slot
            return menu:say("B AGAIN TO COPY OVER PATTERN " .. slot)
        end
        local ok, err = Patterns.copyTo(slot)
        if ok then
            return menu:close("COPIED " .. (Session.patternSlot or "LOOP") .. " TO " .. slot)
        end
        menu.confirm = nil
        menu:say(err)
    else
        if isNow then return menu:say("CAN'T CLEAR THE PATTERN ON SCREEN") end
        if sum.empty then return menu:say("PATTERN " .. slot .. " IS ALREADY EMPTY") end
        if menu.confirm ~= slot then
            menu.confirm = slot
            return menu:say("B AGAIN TO CLEAR PATTERN " .. slot)
        end
        if Patterns.clear(slot) then Song:slotCleared(slot) end
        menu.confirm = nil
        menu:refreshSlots()
        menu:say("CLEARED PATTERN " .. slot)
    end
end

-- Every frame while the menu is active (Modes owns the frame)
function Menu:update(dt)
    if self.messageTimer > 0 then
        self.messageTimer = self.messageTimer - (dt or 0)
        if self.messageTimer <= 0 then self.message = nil end
    end
    if self.closing then
        if not anyDown() then self.closing = false end
        return
    end
    if self.waitRelease then
        if not anyDown() then self.waitRelease = false end
        return
    end
    if Input.pressed.START then return self:close() end
    if self.page == "ROOT" then
        updateRoot(self)
    else
        updateSlots(self)
    end
end

return Menu
