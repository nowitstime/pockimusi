-- ============================================================================
-- src/patterns.lua — Pattern slots A–H: save the loop you have, try another
--
-- A pattern is the whole session as it is now (Session.snapshot): the four
-- tracks with their instruments, sounds, effects and notes, track C's chords,
-- tempo, key and scale. That is also what a scene in song mode will be
-- (FUTURE_PLANS §8.1), so these slots become the song's building blocks.
--
-- Each slot is its own file, pattern_a.txt .. pattern_h.txt, next to the
-- autosave files:  {slot="A",saved=<os.time>,session={...}}
-- Writing one slot can never spoil another. The autosave keeps working as
-- before: it is always the loop on screen, whichever slot it came from.
-- ============================================================================

local Save    = require("src.save")
local Session = require("src.session")
local Looper  = require("src.looper")

local Patterns = {
    SLOTS = { "A", "B", "C", "D", "E", "F", "G", "H" },
}

local function log(msg)
    print("[PocketGroove] " .. msg)
end

function Patterns.fileName(slot)
    return "pattern_" .. slot:lower() .. ".txt"
end

function Patterns.isSlot(slot)
    for _, s in ipairs(Patterns.SLOTS) do
        if s == slot then return true end
    end
    return false
end

-- Read a slot's file: the decoded { slot, saved, session } table, or nil
-- (nil, reason) when it is missing or unreadable
function Patterns.read(slot)
    local name = Patterns.fileName(slot)
    local fs = love.filesystem
    if not (fs.getInfo and fs.getInfo(name)) then return nil, "empty" end
    local text = fs.read(name)
    if not text then return nil, "unreadable" end
    local data, err = Save.decode(text)
    if type(data) ~= "table" or type(data.session) ~= "table" then
        return nil, err or "not a pattern file"
    end
    return data
end

-- What the slot list shows for one slot:
--   { empty = true }  or  { broken = true }  or
--   { bpm, key, notes, instruments = { "DRUMS", ... }, saved }
function Patterns.summary(slot)
    local data, reason = Patterns.read(slot)
    if not data then
        return (reason == "empty") and { empty = true } or { broken = true }
    end
    local s = data.session
    local Theory = require("src.theory")
    local Instruments = require("src.instruments")
    local root = Theory.NOTE_NAMES[tonumber(s.rootIndex) or 1] or "?"
    local scale = Theory.SCALES[tonumber(s.scaleIndex) or 1]
    local out = {
        bpm = tonumber(s.bpm) or 0,
        key = root .. " " .. (scale and scale.name or "?"),
        notes = 0,
        instruments = {},
        saved = tonumber(data.saved),
    }
    for i = 1, 4 do
        local t = type(s.tracks) == "table" and s.tracks[i]
        if type(t) == "table" then
            local def = type(t.instrumentId) == "string" and Instruments.byId[t.instrumentId]
            out.instruments[i] = def and def.name or "?"
            if type(t.events) == "table" then out.notes = out.notes + #t.events end
        end
    end
    if type(s.lane) == "table" and type(s.lane.events) == "table" then
        out.chords = #s.lane.events
    end
    return out
end

-- Save the loop on screen into `slot`. Returns true, or false + message.
function Patterns.save(slot)
    if not Patterns.isSlot(slot) then return false, "no slot " .. tostring(slot) end
    local prev = Session.patternSlot
    Session.patternSlot = slot
    local ok, text = pcall(Save.encode, Session.snapshot())
    if not ok then
        Session.patternSlot = prev
        log("pattern save failed: " .. tostring(text))
        return false, "SAVE FAILED - SEE LOG"
    end
    local saved = (os and os.time) and os.time() or 0
    local fileText = string.format('{slot="%s",saved=%d,session=%s}', slot, saved, text)
    local name = Patterns.fileName(slot)
    local written, err = love.filesystem.write(name, fileText)
    if not written then
        Session.patternSlot = prev
        log("couldn't write " .. name .. ": " .. tostring(err))
        return false, "SAVE FAILED - SEE LOG"
    end
    log(string.format("saved %s (%.1f KB)", name, #fileText / 1024))
    return true
end

-- Replace the loop on screen with `slot`. Returns true, or false + message.
-- If the file won't restore, the loop on screen is put back as it was.
function Patterns.load(slot)
    local data, reason = Patterns.read(slot)
    if not data then
        return false, (reason == "empty") and ("PATTERN " .. slot .. " IS EMPTY") or ("PATTERN " .. slot .. " COULDN'T BE READ")
    end
    local before = Session.snapshot()
    local called, ok, err = pcall(Session.restore, data.session)
    if not called then ok, err = false, ok end
    if not ok then
        log(Patterns.fileName(slot) .. ": " .. tostring(err))
        pcall(Session.restore, before)
        return false, "PATTERN " .. slot .. " COULDN'T BE LOADED"
    end
    Session.patternSlot = slot
    Looper:showToast("LOADED PATTERN " .. slot)
    return true
end

return Patterns
