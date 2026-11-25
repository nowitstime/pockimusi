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
-- The S page (reached with SELECT taps after track C, or a quick SELECT +
-- START tap from anywhere) is where you perform it:
--   D-pad held + B / A / Y / X   queue / cut / copy here / hold: clear
--   face alone                   go to that track (B 1, A 2, Y 3, X 4)
--   L1 / R1                      fade out / in (R2 + L1 / R1 on any page)
-- In song mode a mute (R2 + face) lands on the next bar.
--
-- A switch keeps the loop on screen in its own slot first (nothing is lost),
-- then restores the next pattern live (Session.restore with live = true):
-- its tracks, chords, tempo, key, scale and loop length. Track C starts from
-- its first bar. The data of a queued slot is read when it is queued, so the
-- switch itself only restores.
-- ============================================================================

local Config   = require("src.config")
local Input    = require("src.input")
local Synth    = require("src.synth")
local Looper   = require("src.looper")
local Session  = require("src.session")
local Patterns = require("src.patterns")

local Song = {
    queue = {},       -- { { slot, data } ... } in play order (data nil = an empty slot)
    cutTo = nil,      -- { slot, data } waiting for the next beat
    switches = 0,     -- how many switches have happened (tests, the strip)

    page = false,     -- the S page is showing
    pointing = nil,   -- the slot the held D-pad points at (S page)
    pendingMutes = {},-- track slot -> muted (true / false) at the next bar
    fadeDir = 0,      -- -1 fading out, +1 fading in (set each frame by Modes)
    FADE_BARS = 2,    -- a full fade takes this many bars
    copyConfirm = nil,-- a full slot waiting for a second Y
    clearHold = 0.0,  -- seconds X has been held (D-pad held: clear)
    CLEAR_HOLD = 0.8,
    summaries = {},   -- slot -> Patterns.summary (refreshed when slots change)
    history = {},     -- { { slot, bars } ... } the patterns played before this one (newest last)
}

-- The D-pad directions and the slots they point at
Song.DIR_SLOT = { UP = "A", UP_RIGHT = "B", RIGHT = "C", DOWN_RIGHT = "D",
                  DOWN = "E", DOWN_LEFT = "F", LEFT = "G", UP_LEFT = "H" }
Song.SLOT_DIR = {}
for d, s in pairs(Song.DIR_SLOT) do Song.SLOT_DIR[s] = d end
local FACE_TRACK = { B = 1, A = 2, Y = 3, X = 4 }

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
    if Session.patternSlot then
        self.history[#self.history + 1] = { slot = Session.patternSlot, bars = Looper.bars }
        if #self.history > 4 then table.remove(self.history, 1) end
    end
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
    self.summaries[slot] = Patterns.summary(slot)
    Looper:showToast("PATTERN " .. slot)
    return true
end

-- ---------------------------------------------------------------------------
-- Song mode on / off, and the S page
-- ---------------------------------------------------------------------------
function Song:isOn()
    return Session.songMode == true
end

function Song:refreshSummaries()
    self.summaries = {}
    for _, s in ipairs(Patterns.SLOTS) do self.summaries[s] = Patterns.summary(s) end
    if Session.patternSlot then
        Patterns.flush()
        self.summaries[Session.patternSlot] = Patterns.summary(Session.patternSlot)
    end
end

function Song:setOn(on)
    Session.songMode = on and true or false
    if on then
        -- every slot's sounds ready before the first switch
        for _, s in ipairs(Patterns.SLOTS) do prepare(s) end
        self:refreshSummaries()
        Looper:showToast("SONG MODE ON - SELECT TAPS REACH S")
    else
        self.page, self.pointing = false, nil
        self:clearQueue()
        self.pendingMutes = {}
        Synth.fadeGain = 1.0
        Looper:showToast("SONG MODE OFF")
    end
end

function Song:goToPage()
    if not self:isOn() then return false end
    if not self.page then
        require("src.instruments"):releaseAll()
        self:refreshSummaries()
    end
    self.page = true
    Looper:showToast("S: SONG - HOLD THE D-PAD FOR PATTERNS")
    return true
end

function Song:leavePage(trackSlot)
    self.page, self.pointing = false, nil
    if trackSlot then
        Looper.activeTrack = trackSlot
        local t = Looper.tracks[trackSlot]
        Looper:showToast(string.format("TRACK %d: %s", trackSlot, t and t.name or ""))
    end
end

-- A mute pressed in song mode: lands on the next bar. Pressing it again
-- before then takes it back.
function Song:queueMute(slot)
    if self.pendingMutes[slot] ~= nil then
        self.pendingMutes[slot] = nil
        return
    end
    local t = Looper.tracks[slot]
    if t then self.pendingMutes[slot] = not t.muted end
end

function Song:applyMutes()
    for slot, muted in pairs(self.pendingMutes) do
        local t = Looper.tracks[slot]
        if t and t.muted ~= muted then Looper:toggleMute(slot) end
    end
    self.pendingMutes = {}
end

-- ---------------------------------------------------------------------------
-- The song strip (drawn in place of the chord strip in song mode): the
-- patterns before, the one playing (widened: one chord box per bar) and the
-- ones queued, scrolling past a fixed NOW line. Pure layout, so it can be
-- tested; src/ui/chrome/song.lua draws it.
--   returns { now = x of the NOW line, blocks = { { slot, x, w, kind =
--   "past" | "now" | "next" | "later", bars, chords = { { name, x, w, lit } },
--   names } } }
-- ---------------------------------------------------------------------------
Song.STRIP_PPB = 14       -- pixels per bar for the patterns around
Song.STRIP_ZOOM = 3       -- the one playing is this much wider
Song.STRIP_NOW = 100      -- the NOW line, from the strip's left edge

local function laneChordAt(spans, pos)
    local hit = spans[#spans]                -- before the first chord, the last carries over
    for _, sp in ipairs(spans) do
        if pos >= sp.from - 1e-9 then hit = sp else break end
    end
    return hit
end

function Song:stripLayout(lx, lw)
    local Theory = require("src.theory")
    local ppb, zp = self.STRIP_PPB, self.STRIP_PPB * self.STRIP_ZOOM
    local nowX = lx + self.STRIP_NOW
    local bars = Looper.bars
    local posBars = Looper.tick / Looper.BAR_TICKS
    local out = { now = nowX, blocks = {} }

    -- the pattern playing
    local x0 = nowX - posBars * zp
    local cur = { slot = Session.patternSlot or "-", x = x0, w = bars * zp, kind = "now", bars = bars, chords = {} }
    local lane = Looper:getLane()
    if lane then
        local def = require("src.instruments"):getDefinition("lane")
        local spans = def:spans(lane.state, lane)
        if #spans > 0 then
            local laneT, loopT = Looper:getLaneTicks(), Looper:getLoopTicks()
            local passStart = (Looper.pass * loopT) % laneT
            local litBar = math.floor(posBars)
            for b = 0, bars - 1 do
                local sp = laneChordAt(spans, ((passStart + b * Looper.BAR_TICKS) % laneT) / laneT)
                local name = Theory:chordName(sp.chord)
                local last = cur.chords[#cur.chords]
                if last and last.name == name then
                    last.w = last.w + zp
                    last.lit = last.lit or (b == litBar)
                else
                    cur.chords[#cur.chords + 1] = { name = name, x = x0 + b * zp, w = zp, lit = (b == litBar) }
                end
            end
        end
    end
    out.blocks[#out.blocks + 1] = cur

    -- before it
    local x = x0
    for i = #self.history, 1, -1 do
        local h = self.history[i]
        local w = (h.bars or 2) * ppb
        x = x - w
        if x + w < lx then break end
        table.insert(out.blocks, 1, { slot = h.slot, x = x, w = w, kind = "past", bars = h.bars, chords = {} })
    end

    -- after it: the cut or the queue
    x = x0 + bars * zp
    local upcoming = {}
    if self.cutTo then upcoming[1] = self.cutTo.slot end
    for _, q in ipairs(self.queue) do upcoming[#upcoming + 1] = q.slot end
    for i, slot in ipairs(upcoming) do
        local sum = self.summaries[slot] or {}
        local b = sum.bars or bars
        local w = b * ppb
        out.blocks[#out.blocks + 1] = { slot = slot, x = x, w = w, kind = (i == 1) and "next" or "later", bars = b,
                                        chords = {}, names = sum.chordNames }
        x = x + w
        if x > lx + lw then break end
    end
    out.endX = x
    return out
end

-- Beats until the next switch (nil if none is waiting)
function Song:beatsToSwitch()
    local beat = Looper.PPQN
    if self.cutTo then return 1 end
    if self.queue[1] then
        return math.max(1, math.ceil((Looper:getLoopTicks() - Looper.tick) / beat))
    end
    return nil
end

-- The S page's buttons (called by Modes while the page owns the controls)
function Song:updatePage(dt)
    local slot = self.DIR_SLOT[Input:get8WayDirection()]
    if slot ~= self.pointing then self.copyConfirm, self.clearHold = nil, 0.0 end
    self.pointing = slot

    if Input.down.L1 and not Input.down.R1 then self.fadeDir = -1
    elseif Input.down.R1 and not Input.down.L1 then self.fadeDir = 1 end

    if not slot then
        for btn, t in pairs(FACE_TRACK) do
            if Input.pressed[btn] then return self:leavePage(t) end
        end
        return
    end

    if Input.pressed.B then
        local queued, err = self:toggleQueue(slot)
        if queued == nil then Looper:showToast(err)
        elseif queued then Looper:showToast("QUEUED " .. slot .. " (" .. #self.queue .. " WAITING)")
        else Looper:showToast(slot .. " TAKEN OUT OF THE QUEUE") end
    elseif Input.pressed.A then
        local ok, err = self:cut(slot)
        Looper:showToast(ok and ("CUT TO " .. slot .. " ON THE NEXT BEAT") or err)
    elseif Input.pressed.Y then
        local sum = self.summaries[slot] or Patterns.summary(slot)
        if slot == Session.patternSlot then
            Looper:showToast("THAT'S THE PATTERN PLAYING")
        elseif not sum.empty and self.copyConfirm ~= slot then
            self.copyConfirm = slot
            Looper:showToast("Y AGAIN TO COPY OVER " .. slot)
        else
            self.copyConfirm = nil
            local ok, err = Patterns.copyTo(slot)
            self.summaries[slot] = Patterns.summary(slot)
            Looper:showToast(ok and ("COPIED " .. tostring(Session.patternSlot) .. " TO " .. slot) or err)
        end
    end

    if Input.down.X then
        local before = self.clearHold
        self.clearHold = self.clearHold + (dt or 0)
        if before < self.CLEAR_HOLD and self.clearHold >= self.CLEAR_HOLD then
            local ok, err = Patterns.clear(slot)
            if ok then
                local at = self:isQueued(slot)
                if at then table.remove(self.queue, at) end
                self.summaries[slot] = { empty = true }
            end
            Looper:showToast(ok and ("CLEARED " .. slot) or err)
        end
    else
        self.clearHold = 0.0
    end
end

-- ---------------------------------------------------------------------------
-- Every frame: fades, and the next switch point on the looper
-- ---------------------------------------------------------------------------
function Song:update(dt)
    dt = dt or 0
    if self.fadeDir ~= 0 then
        local secs = self.FADE_BARS * 4 * 60 / Looper.bpm
        Synth.fadeGain = Config.clamp((Synth.fadeGain or 1.0) + self.fadeDir * dt / secs, 0.0, 1.0)
    end
    self.fadeDir = 0

    local beat, bar = Looper.PPQN, Looper.BAR_TICKS
    local loop = Looper:getLoopTicks()
    local switchAt, switchFn
    if self.cutTo then
        local target = self.cutTo
        switchAt = (math.floor(Looper.tick / beat) + 1) * beat
        switchFn = function(at)
            self.cutTo = nil
            self:switchTo(target.slot, target.data)
            Looper.pass = 0
            return at % Looper:getLoopTicks()
        end
    elseif self.queue[1] then
        local target = self.queue[1]
        switchAt = loop
        switchFn = function()
            local at = self:isQueued(target.slot)
            if at then table.remove(self.queue, at) end
            self:switchTo(target.slot, target.data)
            Looper.pass = 0
            return 0
        end
    end
    local muteAt = next(self.pendingMutes) and math.min(loop, (math.floor(Looper.tick / bar) + 1) * bar) or nil

    local b = switchAt
    if muteAt and (not b or muteAt < b) then b = muteAt end
    if not b then
        Looper.boundaryTick, Looper.boundaryHook = nil, nil
        return
    end
    Looper.boundaryTick = b
    Looper.boundaryHook = function(at)
        local pos = at
        if switchAt and at >= switchAt then pos = switchFn(at) end
        if muteAt and at >= muteAt then self:applyMutes() end
        return pos
    end
end

return Song
