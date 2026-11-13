-- ============================================================================
-- src/autosave.lua — Save the session while you play, restore it on boot
--
-- Two files, session_a.txt and session_b.txt, written alternately, each with
-- a rising sequence number. Boot restores the newest one that reads and
-- restores cleanly, so a power cut mid-write can only spoil the file being
-- written; the other still holds the previous save.
--
-- When: only after a button was pressed or released since the last save
-- (playback alone never changes the session), at least INTERVAL seconds
-- after the last save, at a moment with no buttons held; if buttons stay
-- busy, after MAX_WAIT seconds anyway. Also on quit and focus loss.
-- A file is written only when its text actually changed.
-- ============================================================================

local Input   = require("src.input")
local Looper  = require("src.looper")
local Save    = require("src.save")
local Session = require("src.session")

local Autosave = {
    SLOTS = { "session_a.txt", "session_b.txt" },
    INTERVAL = 10.0,       -- seconds between saves (at most this much is lost)
    MAX_WAIT = 30.0,       -- save even if buttons are busy after this long

    seq = 0,               -- sequence number of the newest file
    nextSlot = 1,          -- which file to write next
    lastText = nil,        -- the session text last written (or restored)
    touched = false,       -- a button changed since the last save
    sinceSave = 0.0,       -- seconds since the last save (or boot)
    failed = false,        -- a write failed (toast once)
}

local function log(msg)
    print("[PocketGroove] " .. msg)
end

local function anyButtonDown()
    for _, btn in ipairs(Input.BUTTON_LIST) do
        if Input.down[btn] then return true end
    end
    return false
end

local function anyButtonChanged()
    for _, btn in ipairs(Input.BUTTON_LIST) do
        if Input.pressed[btn] or Input.released[btn] then return true end
    end
    return false
end

-- Read one slot: returns { seq, session } or nil, reason
local function readSlot(name)
    if not (love.filesystem.getInfo and love.filesystem.getInfo(name)) then return nil, "missing" end
    local text = love.filesystem.read(name)
    if not text then return nil, "unreadable" end
    local data, err = Save.decode(text)
    if type(data) ~= "table" or type(data.seq) ~= "number" or type(data.session) ~= "table" then
        return nil, err or "not a save file"
    end
    return data
end

-- ---------------------------------------------------------------------------
-- Boot
-- ---------------------------------------------------------------------------
function Autosave:load()
    self.seq, self.nextSlot, self.lastText = 0, 1, nil
    self.touched, self.sinceSave, self.failed = false, 0.0, false
    if love.filesystem.getSaveDirectory then
        log("save folder: " .. tostring(love.filesystem.getSaveDirectory()))
    end

    local found, existed = {}, false
    for i, name in ipairs(self.SLOTS) do
        local data, reason = readSlot(name)
        if data then
            found[#found + 1] = { slot = i, data = data }
        elseif reason ~= "missing" then
            existed = true
            log(name .. ": " .. tostring(reason))
        end
    end
    table.sort(found, function(a, b) return a.data.seq > b.data.seq end)

    -- Newest first; fall back to the older one if it won't restore
    for _, f in ipairs(found) do
        local ok, err = Session.restore(f.data.session)
        if ok then
            self.seq = f.data.seq
            self.nextSlot = (f.slot % #self.SLOTS) + 1
            self.lastText = Save.encode(Session.snapshot())
            log(string.format("restored %s (seq %d)", self.SLOTS[f.slot], f.data.seq))
            return true
        end
        existed = true
        log(self.SLOTS[f.slot] .. ": " .. tostring(err))
        if f.data.seq > self.seq then self.seq = f.data.seq end
    end

    if existed then
        Looper:showToast("SAVE COULDN'T BE READ - FRESH SESSION")
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Saving
-- ---------------------------------------------------------------------------

-- Write the session now if it changed. Returns true if a file was written.
function Autosave:saveNow()
    self.touched = false
    self.sinceSave = 0.0
    local t0 = love.timer.getTime()
    local ok, text = pcall(Save.encode, Session.snapshot())
    if not ok then
        log("save failed: " .. tostring(text))
        return false
    end
    if text == self.lastText then return false end

    local seq = self.seq + 1
    local fileText = "{seq=" .. seq .. ",session=" .. text .. "}"   -- wraps the text: no second encode
    local name = self.SLOTS[self.nextSlot]
    local written, err = love.filesystem.write(name, fileText)
    if not written then
        log("couldn't write " .. name .. ": " .. tostring(err))
        if not self.failed then
            Looper:showToast("AUTOSAVE FAILED - SEE LOG")
            self.failed = true
        end
        return false
    end
    self.seq = seq
    self.lastText = text
    self.nextSlot = (self.nextSlot % #self.SLOTS) + 1
    self.failed = false
    log(string.format("saved %s (seq %d, %.1f KB, %.0f ms)", name, seq, #fileText / 1024,
        (love.timer.getTime() - t0) * 1000))
    return true
end

-- Every frame, after input and the looper
function Autosave:update(dt)
    self.sinceSave = self.sinceSave + dt
    if anyButtonChanged() then self.touched = true end
    if not self.touched or self.sinceSave < self.INTERVAL then return end
    if anyButtonDown() and self.sinceSave < self.MAX_WAIT then return end
    self:saveNow()
end

return Autosave
