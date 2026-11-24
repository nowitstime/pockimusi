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
--   SAVE PATTERN  the loop on screen into a slot A–H (src/patterns.lua)
--   LOAD PATTERN  a slot back onto the screen
--   SONG MODE     not built yet (FUTURE_PLANS §8); the slots will be its parts
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

local Menu = {
    HOLD = 1.0,              -- seconds SELECT + START are held to open
    MESSAGE_TIME = 2.4,

    ITEMS = {
        { id = "SAVE",  label = "SAVE PATTERN", hint = "KEEP THIS LOOP IN A SLOT" },
        { id = "LOAD",  label = "LOAD PATTERN", hint = "BRING A SLOT BACK" },
        { id = "SONG",  label = "SONG MODE",    hint = "COMING SOON" },
        { id = "FONTS", label = "FONTS",        hint = "LEFT / RIGHT TO CHANGE" },
    },

    open = false,
    closing = false,         -- closed; waiting for every button to be let go
    waitRelease = false,     -- just opened; waiting for every button to be let go
    page = "ROOT",           -- ROOT, SAVE, LOAD
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

-- The slot the cursor starts on: the current pattern's, else (saving) the
-- first empty one, (loading) the first full one
local function startRow(menu, wantEmpty)
    for i, s in ipairs(Patterns.SLOTS) do
        if s == Session.patternSlot then return i end
    end
    for i, s in ipairs(Patterns.SLOTS) do
        local sum = menu.slots[s]
        if sum and (sum.empty == true) == wantEmpty then return i end
    end
    return 1
end

function Menu:openSlots(page)
    self:refreshSlots()
    self.page, self.confirm = page, nil
    self.slotRow = startRow(self, page == "SAVE")
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

    if Input.pressed.A then return menu:close() end
    if not Input.pressed.B then return end
    if item.id == "SAVE" or item.id == "LOAD" then
        menu:openSlots(item.id)
    elseif item.id == "FONTS" then
        menu:changeFonts(1)
    elseif item.id == "SONG" then
        menu:say("SONG MODE IS COMING - SAVED PATTERNS WILL BE ITS PARTS")
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
    if menu.page == "SAVE" then
        if not sum.empty and menu.confirm ~= slot then
            menu.confirm = slot
            return menu:say("B AGAIN TO SAVE OVER PATTERN " .. slot)
        end
        local ok, err = Patterns.save(slot)
        if ok then return menu:close("SAVED PATTERN " .. slot) end
        menu.confirm = nil
        menu:say(err)
    else
        if sum.empty then
            menu.confirm = nil
            return menu:say("PATTERN " .. slot .. " IS EMPTY")
        end
        if menu.confirm ~= slot then
            menu.confirm = slot
            return menu:say("B AGAIN TO LOAD " .. slot .. " - THE LOOP ON SCREEN IS REPLACED")
        end
        local ok, err = Patterns.load(slot)
        if ok then return menu:close("LOADED PATTERN " .. slot) end
        menu.confirm = nil
        menu:say(err)
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
