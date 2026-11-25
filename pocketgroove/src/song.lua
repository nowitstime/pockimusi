-- ============================================================================
-- src/song.lua — Song mode (PHASE_M): switching patterns while playing
--
-- The patterns are the living slots A–H (src/patterns.lua). This module
-- switches between them without stopping the clock:
--
--   queue   one or more slots, played in order, each switching in at the end
--           of the loop. Queueing a slot that is already queued takes it out.
--   cut     switch on the next beat, keeping the place in the bar where the
--           new loop allows.
--
-- A switch keeps the loop on screen in its own slot first (nothing is lost),
-- then restores the next pattern live (Session.restore with live = true):
-- its tracks, chords, tempo, key, scale and loop length. Track C starts from
-- its first bar. The data of a queued slot is read when it is queued, so the
-- switch itself only restores.
-- ============================================================================

local Looper   = require("src.looper")
local Session  = require("src.session")
local Patterns = require("src.patterns")

local Song = {
    queue = {},       -- { { slot, data } ... } in play order (data nil = an empty slot)
    cutTo = nil,      -- { slot, data } waiting for the next beat
    switches = 0,     -- how many switches have happened (tests, the strip)
}

local function log(msg)
    print("[PocketGroove] " .. msg)
end

-- Read a slot now, for a switch later. Returns data (nil for an empty slot)
-- or false, message for one that can't be read.
local function prepare(slot)
    if not Patterns.isSlot(slot) then return false, "NO SLOT " .. tostring(slot) end
    local fs = love.filesystem
    if not (fs.getInfo and fs.getInfo(Patterns.fileName(slot))) then return nil end
    local data = Patterns.read(slot)
    if not data then return false, "PATTERN " .. slot .. " COULDN'T BE READ" end
    -- make sure its sounds are built before the switch
    local Synth = require("src.synth")
    if type(data.session.tracks) == "table" then
        for _, t in pairs(data.session.tracks) do
            local set = type(t) == "table" and t.settings
            if type(set) == "table" and type(set.patch) == "string" and Synth.patches[set.patch] then
                Synth:preparePatch(set.patch)
            end
        end
    end
    return data
end

function Song:isQueued(slot)
    for i, q in ipairs(self.queue) do
        if q.slot == slot then return i end
    end
    return nil
end

function Song:clearQueue()
    self.queue, self.cutTo = {}, nil
    Looper.boundaryTick, Looper.boundaryHook = nil, nil
end

-- The slot that plays next (or nil)
function Song:nextSlot()
    if self.cutTo then return self.cutTo.slot end
    return self.queue[1] and self.queue[1].slot or nil
end

-- Add a slot to the end of the queue, or take it out if it is already there.
-- Returns true (queued), false (taken out) or nil, message.
function Song:toggleQueue(slot)
    local at = self:isQueued(slot)
    if at then
        table.remove(self.queue, at)
        return false
    end
    if slot == Session.patternSlot and #self.queue == 0 then
        return nil, "ALREADY PLAYING " .. slot
    end
    local data, err = prepare(slot)
    if data == false then return nil, err end
    self.queue[#self.queue + 1] = { slot = slot, data = data }
    return true
end

-- Switch on the next beat
function Song:cut(slot)
    if slot == Session.patternSlot then return nil, "ALREADY PLAYING " .. slot end
    local data, err = prepare(slot)
    if data == false then return nil, err end
    self.cutTo = { slot = slot, data = data }
    return true
end

-- The switch itself (also used directly, e.g. by the writing grid later)
function Song:switchTo(slot, data)
    Patterns.flush()
    if data then
        local called, ok, err = pcall(Session.restore, data.session, { live = true })
        if not called then ok, err = false, ok end
        if not ok then
            log("switch to " .. slot .. " failed: " .. tostring(err))
            Looper:showToast("PATTERN " .. slot .. " COULDN'T BE LOADED")
            return false
        end
    else
        Patterns.blank()
    end
    Session.patternSlot = slot
    self.switches = self.switches + 1
    Looper:showToast("PATTERN " .. slot)
    return true
end

-- Every frame: put the next switch point on the looper
function Song:update()
    if self.cutTo then
        local beat = Looper.PPQN
        local b = (math.floor(Looper.tick / beat) + 1) * beat
        local target = self.cutTo
        Looper.boundaryTick = b
        Looper.boundaryHook = function(at)
            self.cutTo = nil
            self:switchTo(target.slot, target.data)
            Looper.pass = 0
            return at % Looper:getLoopTicks()
        end
    elseif self.queue[1] then
        local target = self.queue[1]
        Looper.boundaryTick = Looper:getLoopTicks()
        Looper.boundaryHook = function()
            local at = self:isQueued(target.slot)
            if at then table.remove(self.queue, at) end
            self:switchTo(target.slot, target.data)
            Looper.pass = 0
            return 0
        end
    else
        Looper.boundaryTick, Looper.boundaryHook = nil, nil
    end
end

return Song
