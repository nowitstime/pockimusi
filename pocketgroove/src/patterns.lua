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
--   { bpm, key, notes, instruments = { "DRUMS", ... }, saved, bars,
--     lanes = { { id, muted, notes = { { from, to }, ... } } x4 } }
-- lanes: where each track's notes sit, as fractions of the loop (0..1), for
-- the little tape deck in the slot list
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
        bars = (s.bars == 4) and 4 or 2,
        lanes = {},
    }
    local loop = Looper.PPQN * 4 * out.bars
    for i = 1, 4 do
        local t = type(s.tracks) == "table" and s.tracks[i]
        local lane = { notes = {} }
        out.lanes[i] = lane
        if type(t) == "table" then
            local def = type(t.instrumentId) == "string" and Instruments.byId[t.instrumentId]
            out.instruments[i] = def and def.name or "?"
            lane.id, lane.muted = def and def.id or nil, (t.muted == true)
            if type(t.events) == "table" then
                out.notes = out.notes + #t.events
                for _, ev in ipairs(t.events) do
                    local tick, len = tonumber(type(ev) == "table" and ev.tick), tonumber(type(ev) == "table" and ev.len) or 0
                    if tick and tick >= 0 and tick < loop then
                        lane.notes[#lane.notes + 1] = { tick / loop, math.min(1, (tick + math.max(0, len)) / loop) }
                    end
                end
            end
        end
    end
    if type(s.lane) == "table" and type(s.lane.events) == "table" then
        out.chords = #s.lane.events
    end
    return out
end

-- Write already-encoded session text into `slot`'s file. Returns true, or
-- false + message.
function Patterns.writeText(slot, text)
    if not Patterns.isSlot(slot) then return false, "no slot " .. tostring(slot) end
    local saved = (os and os.time) and os.time() or 0
    local fileText = string.format('{slot="%s",saved=%d,session=%s}', slot, saved, text)
    local name = Patterns.fileName(slot)
    local written, err = love.filesystem.write(name, fileText)
    if not written then
        log("couldn't write " .. name .. ": " .. tostring(err))
        return false, "SAVE FAILED - SEE LOG"
    end
    return true, #fileText
end

-- The loop on screen as session text, as if it lived in `slot`
local function encodeAs(slot)
    local prev = Session.patternSlot
    Session.patternSlot = slot
    local ok, text = pcall(Save.encode, Session.snapshot())
    Session.patternSlot = prev
    if not ok then log("pattern encode failed: " .. tostring(text)) end
    return ok and text or nil
end

-- Save the loop on screen into `slot` and make it the current pattern.
-- Returns true, or false + message.
function Patterns.save(slot)
    if not Patterns.isSlot(slot) then return false, "no slot " .. tostring(slot) end
    local text = encodeAs(slot)
    if not text then return false, "SAVE FAILED - SEE LOG" end
    local ok, err = Patterns.writeText(slot, text)
    if not ok then return false, err end
    Session.patternSlot = slot
    log(string.format("saved %s (%.1f KB)", Patterns.fileName(slot), err / 1024))
    return true
end

-- Copy the loop on screen into another slot; the current pattern stays
function Patterns.copyTo(slot)
    if not Patterns.isSlot(slot) then return false, "no slot " .. tostring(slot) end
    local text = encodeAs(slot)
    if not text then return false, "COPY FAILED - SEE LOG" end
    local ok, err = Patterns.writeText(slot, text)
    if not ok then return false, err end
    return true
end

-- Empty a slot (not the one on screen: it would be written straight back)
function Patterns.clear(slot)
    if not Patterns.isSlot(slot) then return false, "no slot " .. tostring(slot) end
    if slot == Session.patternSlot then return false, "THAT'S THE PATTERN ON SCREEN" end
    local fs = love.filesystem
    if fs.getInfo and fs.getInfo(Patterns.fileName(slot)) then fs.remove(Patterns.fileName(slot)) end
    return true
end

-- Write the loop on screen into its own slot now (before leaving it)
function Patterns.flush()
    local slot = Session.patternSlot
    if not slot then return true end
    local text = encodeAs(slot)
    if not text then return false end
    return (Patterns.writeText(slot, text))
end

-- The first slot with no file, or nil
function Patterns.firstEmpty()
    local fs = love.filesystem
    for _, s in ipairs(Patterns.SLOTS) do
        if not (fs.getInfo and fs.getInfo(Patterns.fileName(s))) then return s end
    end
    return nil
end

-- Living slots: the loop on screen always belongs to a slot. A session from
-- before (no slot) takes the first empty one; with every slot full it stays
-- without one until you go to a slot.
function Patterns.ensureSlot()
    if Session.patternSlot then return Session.patternSlot end
    local s = Patterns.firstEmpty()
    if s then Session.patternSlot = s end      -- its file comes with the next save
    return s
end

-- Go to another slot: the loop on screen is written into its own slot
-- first, so nothing is lost. An empty slot starts a fresh pattern with the
-- same instruments, sounds, tempo and key, and no notes.
function Patterns.goTo(slot)
    if not Patterns.isSlot(slot) then return false, "no slot " .. tostring(slot) end
    if slot == Session.patternSlot then return true end
    local fs = love.filesystem
    local exists = fs.getInfo and fs.getInfo(Patterns.fileName(slot))
    if exists then
        local data, reason = Patterns.read(slot)
        if not data then return false, "PATTERN " .. slot .. " COULDN'T BE READ" end
    end
    Patterns.flush()
    if exists then
        local ok, err = Patterns.load(slot)
        if not ok then return false, err end
        Looper:showToast("PATTERN " .. slot)
        return true
    end
    -- empty: same setup, no notes, no chords
    Looper:silenceAll()
    for i = 1, #Looper.tracks do
        local t = Looper.tracks[i]
        t.events = {}
        t.muted = false
        Looper:touch(t)
    end
    Looper.undoStack = {}
    Session.patternSlot = slot
    Patterns.flush()
    Looper:showToast("NEW PATTERN " .. slot)
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
