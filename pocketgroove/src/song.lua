-- ============================================================================
-- src/song.lua — Song mode (PHASE_M): switching patterns while playing
--
-- The patterns are the living slots A–H (src/patterns.lua). This module
-- switches between them without stopping the clock:
--
--   queue   one or more slots, played in order, each switching in at the end
--           of the loop. Any order, repeats too (A, A, B, B, A); on S,
--           L2 + R2 + B takes the last one back out, L2 + R2 + X empties it.
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
-- Recording the song (L2 on S; L2 anywhere stops it) works like a tape: while
-- it rolls, everything is written into the song as moves: pattern switches,
-- mutes, live FX, fades, and the notes played on any track as one-off takes.
-- START on S plays the song from the top. Rolling again over a song keeps
-- what you don't touch: a kind of move you touch is replaced from then on,
-- notes are added. The song lives in song.txt.
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

    -- The song: steps = { { slot, start (tick in its loop), len (ticks),
    -- mutes = { 4 booleans at the start }, moves = { { at, kind, ... } },
    -- takes = { [track] = { events with `at` } } } }; `at` = ticks into the step
    data = { steps = {} },
    playing = false,  -- the song drives the switches
    recording = false,-- the tape is rolling
    armed = false,    -- recording starts at the next loop start
    stepIdx = 0,
    stepPos = 0.0,    -- ticks into the current step
    lastTick = 0.0,
    touched = {},     -- kinds of move touched in this pass (replaced from then on)
    sounding = {},    -- take notes on: { ev, track, off = at }
    lastRecFx = nil,  -- the live FX as last written
    lastRecFade = nil,
    playFx = { s = false, h = false, d = false, c = false },   -- FX the song is playing
    undoData = nil,   -- the song before the last pass
    nextData = nil,   -- the next step's slot, read ahead
    FILE = "song.txt",
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

-- Add a slot to the end of the queue (any slot, as often as you like: the
-- one playing again means one more loop of it). Returns true, or nil, message.
function Song:enqueue(slot)
    local data, err = prepare(slot)
    if data == false then return nil, err end
    self.queue[#self.queue + 1] = { slot = slot, data = data, writes = Patterns.writes[slot] or 0 }
    return true
end
Song.toggleQueue = Song.enqueue

-- Take the last queued pattern back out. Returns its slot, or nil.
function Song:popQueue()
    local q = table.remove(self.queue)
    return q and q.slot or nil
end

-- A slot was emptied: it leaves the queue and a waiting cut (its data was read earlier)
function Song:slotCleared(slot)
    for i = #self.queue, 1, -1 do
        if self.queue[i].slot == slot then table.remove(self.queue, i) end
    end
    if self.cutTo and self.cutTo.slot == slot then self.cutTo = nil end
    self.summaries[slot] = { empty = true }
end

-- Switch on the next beat
function Song:cut(slot)
    if slot == Session.patternSlot then return nil, "ALREADY PLAYING " .. slot end
    local data, err = prepare(slot)
    if data == false then return nil, err end
    self.cutTo = { slot = slot, data = data, writes = Patterns.writes[slot] or 0 }
    return true
end

-- The switch itself (also used directly, e.g. by the writing grid later)
function Song:switchTo(slot, data, writes)
    self:takesOff()
    Patterns.flush()
    -- the slot was written since it was read (it was on screen and changed): read it again
    if writes and (Patterns.writes[slot] or 0) ~= writes then
        data = Patterns.read(slot)
    end
    if Session.patternSlot then
        self.history[#self.history + 1] = { slot = Session.patternSlot, bars = Looper.bars }
        if #self.history > 4 then table.remove(self.history, 1) end
    end
    if slot == Session.patternSlot then
        -- the one playing again: it carries on as it is
        data = nil
    elseif data then
        local called, ok, err = pcall(Session.restore, data.session, { live = true })
        if not called then ok, err = false, ok end
        if not ok then
            log("switch to " .. slot .. " failed: " .. tostring(err))
            Looper:showToast("PATTERN " .. slot .. " COULDN'T BE LOADED")
            return false
        end
    elseif slot ~= Session.patternSlot then
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
        if self.playing or self.recording or self.armed then self:stop() end
        self.page, self.pointing = false, nil
        self:clearQueue()
        self.pendingMutes = {}
        self.playFx = { s = false, h = false, d = false, c = false }
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
        if t and t.isLane then
            Looper:showToast("TRACK C: CHORDS - SELECT GOES BACK TO S")
        else
            Looper:showToast(string.format("TRACK %d: %s", trackSlot, t and t.name or ""))
        end
    end
end

-- A mute pressed in song mode: lands on the next bar. Pressing it again
-- before then takes it back.
function Song:queueMute(slot)
    if self:writing() and self:hasSong() then return self:toggleStepMute(slot) end
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
        if self.recording then self:recordMove({ kind = "mute", slot = slot, muted = muted }) end
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
    local BAR = Looper.BAR_TICKS
    local bars = Looper.bars
    local posBars = Looper.tick / BAR
    local baseTick = function(b) return (Looper.pass * Looper:getLoopTicks()) + b * BAR end
    local songStep = self.playing and self.data.steps[self.stepIdx]
    if songStep then
        -- the song: the step playing, from where it began
        bars = math.max(1, math.ceil(math.max(songStep.len, self.stepPos + 1) / BAR))
        posBars = self.stepPos / BAR
        baseTick = function(b) return songStep.start + b * BAR end
    end
    local out = { now = nowX, blocks = {} }

    -- the pattern playing
    local x0 = nowX - posBars * zp
    local cur = { slot = Session.patternSlot or "-", x = x0, w = bars * zp, kind = "now", bars = bars, chords = {} }
    local lane = Looper:getLane()
    if lane then
        local def = require("src.instruments"):getDefinition("lane")
        local spans = def:spans(lane.state, lane)
        if #spans > 0 then
            local laneT = Looper:getLaneTicks()
            local litBar = math.floor(posBars)
            for b = 0, bars - 1 do
                local sp = laneChordAt(spans, (baseTick(b) % laneT) / laneT)
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
    local before = self.history
    if songStep then
        before = {}
        for i = 1, self.stepIdx - 1 do
            local st = self.data.steps[i]
            before[i] = { slot = st.slot, bars = math.max(1, st.len / BAR) }
        end
    end
    for i = #before, 1, -1 do
        local h = before[i]
        local w = (h.bars or 2) * ppb
        x = x - w
        if x + w < lx then break end
        table.insert(out.blocks, 1, { slot = h.slot, x = x, w = w, kind = "past", bars = h.bars, chords = {} })
    end

    -- after it: the cut or the queue
    x = x0 + bars * zp
    local upcoming, lens = {}, {}
    if self.cutTo then upcoming[1] = self.cutTo.slot end
    for _, q in ipairs(self.queue) do upcoming[#upcoming + 1] = q.slot end
    if songStep and #upcoming == 0 then
        for i = self.stepIdx + 1, #self.data.steps do
            local st = self.data.steps[i]
            upcoming[#upcoming + 1] = st.slot
            lens[#upcoming] = math.max(1, st.len / BAR)
        end
    end
    for i, slot in ipairs(upcoming) do
        local sum = self.summaries[slot] or {}
        local b = lens[i] or sum.bars or bars
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

    local writing = self:writing()
    if writing then
        if Input.pressed.L1 then self:moveCursor(-1) end
        if Input.pressed.R1 then self:moveCursor(1) end
    elseif Input.down.L1 and not Input.down.R1 then self.fadeDir = -1
    elseif Input.down.R1 and not Input.down.L1 then self.fadeDir = 1 end

    if not slot then
        for btn, t in pairs(FACE_TRACK) do
            if Input.pressed[btn] then return self:leavePage(t) end
        end
        return
    end

    if writing and Input.pressed.B then
        self:writeStep(slot)
    elseif writing and Input.pressed.A then
        Looper:showToast("THE CLOCK IS STOPPED - B WRITES " .. slot .. " INTO STEP " .. self.cursor)
    elseif Input.pressed.B then
        local queued, err = self:enqueue(slot)
        if queued then
            local order = {}
            for _, q in ipairs(self.queue) do order[#order + 1] = q.slot end
            Looper:showToast("QUEUED " .. slot .. " - NEXT: " .. table.concat(order, " "))
        else
            Looper:showToast(err)
        end
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
            if ok then self:slotCleared(slot) end
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
        local secs = self:setting("fadeBars", self.FADE_BARS) * 4 * 60 / Looper.bpm
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
            self:catchUp(at)
            self:switchTo(target.slot, target.data, target.writes)
            Looper.pass = 0
            local pos = at % Looper:getLoopTicks()
            self:userSwitched(target.slot, pos)
            return pos
        end
    elseif self.queue[1] then
        local target = self.queue[1]
        switchAt = loop
        if self:setting("switchOn", "LOOP END") == "NEXT BAR" then
            switchAt = math.min(loop, (math.floor(Looper.tick / bar) + 1) * bar)
        end
        switchFn = function(at0)
            for i, q in ipairs(self.queue) do
                if q == target then table.remove(self.queue, i) break end
            end
            self:catchUp(at0)
            self:switchTo(target.slot, target.data, target.writes)
            Looper.pass = 0
            self:userSwitched(target.slot, 0)
            return 0
        end
    end
    -- the song's own next step (playing back, and not writing a new one at its end)
    local step = self.playing and self.data.steps[self.stepIdx]
    if not switchAt and step and not (self.recording and self.stepIdx == #self.data.steps) then
        local left = step.len - self.stepPos
        -- past its end (a missed switch point: a hitch, stutter): on the next bar, not mid-bar
        local endAt = (left > 0) and (Looper.tick + left)
                      or math.min(loop, (math.floor(Looper.tick / bar) + 1) * bar)
        if endAt <= loop + 1e-4 then
            switchAt = math.min(endAt, loop)
            switchFn = function(at)
                self:catchUp(at)
                return self:nextStep(at)
            end
        end
    end
    -- recording armed: it starts at the loop start
    if not switchAt and self.armed then
        switchAt = loop
        switchFn = function(at)
            self:beginRecording()
            return at
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
        if switchAt and at >= switchAt then
            pos = switchFn(at)
        else
            self:catchUp(at)
        end
        if muteAt and at >= muteAt then self:applyMutes() end
        return pos
    end
end

-- ---------------------------------------------------------------------------
-- The song: recording and playing back
-- ---------------------------------------------------------------------------
local function copy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = copy(x) end
    return out
end

local function muteState()
    local m = {}
    for i = 1, 4 do m[i] = Looper.tracks[i].muted and true or false end
    return m
end

local function liveFx()
    return { s = Synth.fxBeatRepeat and true or false, h = Synth.fxHalfSpeed and true or false,
             d = Synth.fxLowPass and true or false, c = Synth.fxBitcrush and true or false }
end

local function sameFx(a, b)
    return a and b and a.s == b.s and a.h == b.h and a.d == b.d and a.c == b.c
end

local function moveKey(m)
    if m.kind == "mute" then return "mute" .. tostring(m.slot) end
    return m.kind
end

local function newStep(slot, start)
    return { slot = slot, start = start or 0, len = 0, mutes = muteState(), moves = {}, takes = {} }
end

function Song:hasSong()
    return #self.data.steps > 0
end

-- The FX the song plays back (Modes uses these when R2 isn't held)
function Song:playbackFx()
    local f = self.playFx
    return f.s, f.h, f.d, f.c
end

function Song:takesOff(trackIdx)
    local handler = Looper.noteHandler
    for i = #self.sounding, 1, -1 do
        local snd = self.sounding[i]
        if not trackIdx or (snd.track and snd.track.slot == trackIdx) then
            if handler then handler("off", snd.ev, snd.track) end
            table.remove(self.sounding, i)
        end
    end
end

-- Move the song position on by `d` ticks of the pattern playing, playing
-- (or, for kinds touched while recording, wiping) what lies in between
function Song:advance(d)
    local step = self.data.steps[self.stepIdx]
    if not (self.playing and step) or d <= 0 then return end
    local prev, cur = self.stepPos, self.stepPos + d
    if self.stepFresh then
        prev = -1e-6
        self.stepFresh = false
    end
    self.stepPos = cur
    if self.recording and self.stepIdx == #self.data.steps and cur > step.len then step.len = cur end

    -- moves
    local i = 1
    while i <= #step.moves do
        local m = step.moves[i]
        if m.at > prev and m.at <= cur and not m.fresh then
            if self.recording and self.touched[moveKey(m)] then
                table.remove(step.moves, i)
                i = i - 1
            elseif m.kind == "mute" then
                local t = Looper.tracks[m.slot]
                if t and t.muted ~= m.muted then Looper:toggleMute(m.slot) end
            elseif m.kind == "fx" then
                self.playFx = { s = m.s, h = m.h, d = m.d, c = m.c }
            elseif m.kind == "fade" then
                Synth.fadeGain = Config.clamp(m.gain or 1, 0, 1)
            end
        end
        i = i + 1
    end

    -- take notes
    local handler = Looper.noteHandler
    for j = #self.sounding, 1, -1 do
        local snd = self.sounding[j]
        if snd.off <= cur then
            if handler then handler("off", snd.ev, snd.track) end
            table.remove(self.sounding, j)
        end
    end
    for t, list in pairs(step.takes) do
        local track = Looper.tracks[t]
        if track and not track.muted then
            for _, ev in ipairs(list) do
                if ev.at > prev and ev.at <= cur and not ev.open then
                    if ev.skipOnce then
                        ev.skipOnce = nil
                    elseif handler then
                        handler("on", ev, track)
                        if (ev.len or 0) > 0 then
                            self.sounding[#self.sounding + 1] = { ev = ev, track = track, off = ev.at + ev.len }
                        else
                            handler("off", ev, track)
                        end
                    end
                end
            end
        end
    end
end

-- Inside a switch hook: count the ticks up to the switch point first
function Song:catchUp(at)
    if not self.playing then return end
    local loop = Looper:getLoopTicks()
    local d = (at - self.lastTick) % loop
    if d > loop * 0.5 then d = 0 end
    self:advance(d)
    self.lastTick = at % loop
end

-- Every frame, after the looper: the song position follows the playhead
function Song:afterLooper()
    if not self.playing then
        self.lastTick = Looper.tick
        return
    end
    local loop = Looper:getLoopTicks()
    local d = (Looper.tick - self.lastTick) % loop
    if d > loop * 0.5 then d = 0 end              -- a stutter jumping back
    self.lastTick = Looper.tick
    if Looper.playing then self:advance(d) end

    if self.recording then
        local step = self.data.steps[self.stepIdx]
        if not step then return end
        -- live FX: a change is a move (R2 + D-pad)
        local fx = liveFx()
        if not sameFx(fx, self.lastRecFx) then
            self:recordMove({ kind = "fx", s = fx.s, h = fx.h, d = fx.d, c = fx.c })
            self.lastRecFx = fx
        end
        -- fades
        local g = Synth.fadeGain or 1
        if not self.lastRecFade or math.abs(g - self.lastRecFade) > 0.01 or (g ~= self.lastRecFade and (g == 0 or g == 1)) then
            if self.lastRecFade then self:recordMove({ kind = "fade", gain = g }) end
            self.lastRecFade = g
        end
    end
end

-- Write a move at the song position (recording); its kind is touched from now
function Song:recordMove(m)
    local step = self.data.steps[self.stepIdx]
    if not (self.recording and step) then return end
    m.at = self.stepPos
    self.touched[moveKey(m)] = true
    -- the same kind already at this spot: replaced
    for i = #step.moves, 1, -1 do
        local o = step.moves[i]
        if moveKey(o) == moveKey(m) and math.abs(o.at - m.at) < 1 then table.remove(step.moves, i) end
    end
    local at = #step.moves + 1
    for i, o in ipairs(step.moves) do
        if o.at > m.at then at = i break end
    end
    table.insert(step.moves, at, m)
end

-- A note played while the tape rolls (Looper:recordEvent hands it here)
function Song:captureNote(trackIdx, ev)
    local step = self.data.steps[self.stepIdx]
    if not (self.recording and step) then return nil end
    local loop = Looper:getLoopTicks()
    local grid
    if ev.overrideGridSteps then
        grid = loop / ev.overrideGridSteps
    else
        grid = Looper:getTrackGrid(trackIdx).stepTicks
    end
    ev.overrideGridSteps = nil
    local now = Looper.tick
    local snapped = grid and (math.floor(now / grid + 0.5) * grid) or math.floor(now + 0.5)
    ev.at = math.max(0, self.stepPos + (snapped - now))
    ev.tick = 0
    ev.len = ev.len or 0
    ev.grid = grid
    ev.takeId = Looper.currentTakeId
    ev.skipOnce = (ev.at > self.stepPos) or nil   -- the live press played it (only one still ahead gets crossed)
    step.takes[trackIdx] = step.takes[trackIdx] or {}
    table.insert(step.takes[trackIdx], ev)
    return ev
end

-- The song's next step (or its end)
function Song:nextStep(at)
    local nextIdx = self.stepIdx + 1
    local step = self.data.steps[nextIdx]
    if not step and self:setting("atEnd", "STOP") == "LOOP" and #self.data.steps > 0 then
        nextIdx, step = 1, self.data.steps[1]
    end
    if not step then
        -- the end: stop
        self:takesOff()
        self.playing = false
        self.playFx = { s = false, h = false, d = false, c = false }
        Looper:setPlaying(false)
        Looper:showToast("SONG END - START ON S PLAYS IT AGAIN")
        return at
    end
    local data = self.nextData
    if not data or data.slot ~= step.slot then
        data = { data = (prepare(step.slot)) or nil, writes = Patterns.writes[step.slot] or 0 }
    end
    self:switchTo(step.slot, data.data or nil, data.writes)
    for i = 1, 4 do Looper.tracks[i].muted = step.mutes[i] and true or false end
    self.stepIdx, self.stepPos, self.stepFresh = nextIdx, 0, true
    self.cursor = nextIdx
    self.lastTick = step.start % Looper:getLoopTicks()
    Looper.pass = 0
    self:readAhead()
    return step.start
end

function Song:readAhead()
    local n = self.data.steps[self.stepIdx + 1]
    self.nextData = n and { slot = n.slot, data = (prepare(n.slot)) or nil, writes = Patterns.writes[n.slot] or 0 } or nil
end

-- A switch you made (queue or cut) while the song plays
function Song:userSwitched(slot, pos)
    if self.recording then
        local step = self.data.steps[self.stepIdx]
        if step then step.len = self.stepPos end
        for i = #self.data.steps, self.stepIdx + 1, -1 do table.remove(self.data.steps, i) end
        self.data.steps[#self.data.steps + 1] = newStep(slot, pos)
        self.stepIdx, self.stepPos, self.stepFresh = #self.data.steps, 0, true
        self.lastTick = pos
        self.nextData = nil
    elseif self.playing then
        self.playing = false
        self:takesOff()
        self.playFx = { s = false, h = false, d = false, c = false }
        Looper:showToast("SONG STOPPED - YOU TOOK OVER")
    end
end

-- START on S: play the song from the top
function Song:playFromTop()
    if not self:hasSong() then
        Looper:showToast("NO SONG YET - L2 ON S RECORDS ONE")
        return false
    end
    self:clearQueue()
    local step = self.data.steps[1]
    local data = prepare(step.slot)
    for _, st in ipairs(self.data.steps) do
        for _, list in pairs(st.takes) do
            for _, ev in ipairs(list) do ev.skipOnce = nil end
        end
    end
    self:switchTo(step.slot, data or nil)
    for i = 1, 4 do Looper.tracks[i].muted = step.mutes[i] and true or false end
    Synth.fadeGain = 1.0
    self.playFx = { s = false, h = false, d = false, c = false }
    Looper.tick = step.start % Looper:getLoopTicks()
    Looper.prevTick = Looper.tick - 1e-6
    Looper.resetPending = true
    Looper.pass = 0
    Looper.playing = true
    Looper:syncPhase()
    self.stepIdx, self.stepPos, self.stepFresh, self.lastTick = 1, 0, true, Looper.tick
    self.playing = true
    self:readAhead()
    Looper:showToast("PLAYING THE SONG")
    return true
end

function Song:stop()
    if self.recording or self.armed then self:stopRecording() end
    self.playing = false
    self:takesOff()
    self.playFx = { s = false, h = false, d = false, c = false }
    Looper:setPlaying(false)
    Looper:showToast("SONG STOPPED")
end

-- L2 on S
function Song:startRecording()
    if self.recording or self.armed then return end
    self.undoData = copy(self.data)
    self.touched = {}
    if self.playing then
        self.lastRecFx, self.lastRecFade = liveFx(), Synth.fadeGain or 1
        self:rolling(true)
        Looper:showToast("SONG REC - OVER THE SONG: WHAT YOU DON'T TOUCH STAYS")
    elseif self:hasSong() then
        self:playFromTop()
        self.lastRecFx, self.lastRecFade = liveFx(), Synth.fadeGain or 1
        self:rolling(true)
        Looper:showToast("SONG REC FROM THE TOP - WHAT YOU DON'T TOUCH STAYS")
    else
        self.lastRecFx, self.lastRecFade = liveFx(), Synth.fadeGain or 1
        self.armed = true
        Looper.playing = true
        Looper:showToast("SONG REC STARTS ON THE NEXT LOOP")
    end
end

function Song:rolling(on)
    self.recording = on
    Input.songRolling = on or nil
    Looper.recordRedirect = on and function(t, ev) return self:captureNote(t, ev) end or nil
    if on then Looper:beginRecordingTake() end
end

-- The armed recording begins (at a loop start)
function Song:beginRecording()
    self.armed = false
    self.data = { steps = { newStep(Session.patternSlot or "A", 0) } }
    self.stepIdx, self.stepPos, self.stepFresh, self.lastTick = 1, 0, true, 0
    self.playing = true
    self:rolling(true)
    Looper:showToast("SONG REC - EVERYTHING YOU DO GOES INTO THE SONG")
end

function Song:stopRecording()
    if self.armed then
        self.armed = false
        Looper:showToast("SONG REC CANCELLED")
        return
    end
    if not self.recording then return end
    -- stopped on the song's last step (the one being written): the song lets
    -- go and the loop carries on, instead of ending at once mid-bar
    if self.playing and self.stepIdx == #self.data.steps then
        self.playing = false
        self:takesOff()
        self.playFx = { s = false, h = false, d = false, c = false }
    end
    self:rolling(false)
    self.touched = {}
    for _, st in ipairs(self.data.steps) do
        for _, m in ipairs(st.moves) do m.fresh = nil end
    end
    self:save()
    Looper:showToast(string.format("SONG RECORDED - %d STEP%s", #self.data.steps, #self.data.steps == 1 and "" or "S"))
end

-- L2 + R2 + LEFT on S: the song before the last pass
function Song:undo()
    if not self.undoData then
        Looper:showToast("NOTHING TO UNDO IN THE SONG")
        return false
    end
    if self.recording then self:rolling(false) end
    self.data, self.undoData = self.undoData, nil
    self.playing = false
    self:takesOff()
    self.playFx = { s = false, h = false, d = false, c = false }
    self:save()
    Looper:showToast("UNDO: THE SONG BEFORE THAT PASS")
    return true
end

function Song:clearSong()
    if self.recording then self:rolling(false) end
    self.undoData = copy(self.data)
    self.data = { steps = {} }
    self.playing, self.armed = false, false
    self:takesOff()
    self.playFx = { s = false, h = false, d = false, c = false }
    self:save()
end

-- ---------------------------------------------------------------------------
-- Writing the song (the clock stopped on S) and the song's rows (hold SELECT
-- on S). `cursor` is the step being written: 1 .. #steps + 1 (a new one).
-- ---------------------------------------------------------------------------
Song.cursor = 1
Song.END_MODES = { "STOP", "LOOP" }
Song.SWITCH_MODES = { "LOOP END", "NEXT BAR" }
Song.FADE_CHOICES = { 1, 2, 4, 8 }

function Song:writing()
    return self.page and not Looper.playing
end

function Song:setting(key, default)
    local v = self.data[key]
    if v == nil then return default end
    return v
end

local function patternLoop(self, slot)
    local sum = self.summaries[slot] or Patterns.summary(slot)
    return (sum and sum.bars or Looper.bars) * 4 * Looper.PPQN
end

function Song:moveCursor(delta)
    self.cursor = Config.clamp(self.cursor + delta, 1, #self.data.steps + 1)
end

-- Write `slot` into the step under the cursor (a new one past the end), step on
function Song:writeStep(slot)
    self.undoData = copy(self.data)
    local steps = self.data.steps
    local st = steps[self.cursor]
    if st then
        st.slot = slot
    else
        local sum = self.summaries[slot] or Patterns.summary(slot)
        local mutes = {}
        for i = 1, 4 do mutes[i] = sum.lanes and sum.lanes[i] and sum.lanes[i].muted or false end
        st = { slot = slot, start = 0, len = patternLoop(self, slot), mutes = mutes, moves = {}, takes = {} }
        steps[#steps + 1] = st
    end
    Looper:showToast(string.format("STEP %d: %s", self.cursor, slot))
    self:moveCursor(1)
    self:save()
end

-- R2 + face while writing: that track in / out on the step under the cursor
function Song:toggleStepMute(slot)
    local st = self.data.steps[self.cursor]
    if not st then
        Looper:showToast("NO STEP HERE - D-PAD + B WRITES ONE")
        return
    end
    st.mutes[slot] = not st.mutes[slot]
    Looper:showToast(string.format("STEP %d: TRACK %d %s", self.cursor, slot, st.mutes[slot] and "OUT" or "IN"))
    self:save()
end

function Song:deleteStep()
    local st = self.data.steps[self.cursor]
    if not st then return false end
    self.undoData = copy(self.data)
    table.remove(self.data.steps, self.cursor)
    self:moveCursor(0)
    self:save()
    Looper:showToast("STEP DELETED - L2 + R2 + LEFT UNDOES")
    return true
end

-- The rows for the Track page on S: { key, label, value, kind, hint }
function Song:rows()
    local rows = {}
    local n = #self.data.steps
    local st = self.data.steps[self.cursor]
    rows[#rows + 1] = { key = "STEP", label = "STEP", value = st and string.format("%d / %d", self.cursor, n) or (n == 0 and "NO SONG YET" or "NEW (" .. (n + 1) .. ")") }
    if st then
        rows[#rows + 1] = { key = "PATTERN", label = "PATTERN", value = st.slot }
        local loopT = patternLoop(self, st.slot)
        local loops = st.len / loopT
        local shown = (math.abs(loops - math.floor(loops + 0.5)) < 0.01) and string.format("x %d", math.floor(loops + 0.5))
                      or string.format("x %.1f", loops)
        rows[#rows + 1] = { key = "LOOPS", label = "LOOPS", value = shown }
        for t = 1, 4 do
            local tr = Looper.tracks[t]
            rows[#rows + 1] = { key = "IN" .. t, label = t .. " " .. (tr and tr.shortName or ""), kind = "setting",
                                value = st.mutes[t] and "OUT" or "IN" }
        end
        rows[#rows + 1] = { key = "DELETE", label = "DELETE", kind = "setting",
                            value = self.confirmRow == "DELETE" and "RIGHT AGAIN" or "RIGHT: THIS STEP" }
    end
    rows[#rows + 1] = { key = "END", label = "AT THE END", kind = "setting", value = self:setting("atEnd", "STOP") }
    rows[#rows + 1] = { key = "SWITCH", label = "SWITCH ON", kind = "setting", value = self:setting("switchOn", "LOOP END") }
    rows[#rows + 1] = { key = "FADE", label = "FADE TIME", kind = "setting", value = self:setting("fadeBars", 2) .. " BAR" }
    rows[#rows + 1] = { key = "CLEAR", label = "CLEAR SONG", kind = "setting",
                        value = self.confirmRow == "CLEAR" and "RIGHT AGAIN" or "RIGHT: EVERY STEP" }
    return rows
end

local function cycle(list, cur, delta)
    local idx = 1
    for i, v in ipairs(list) do if v == cur then idx = i end end
    return list[((idx - 1 + delta) % #list) + 1]
end

function Song:cycleRow(key, delta)
    local st = self.data.steps[self.cursor]
    if key ~= self.confirmRow then self.confirmRow = nil end
    if key == "STEP" then
        self:moveCursor(delta)
        return
    elseif key == "PATTERN" and st then
        self.undoData = copy(self.data)
        local oldLoop = patternLoop(self, st.slot)
        st.slot = cycle(Patterns.SLOTS, st.slot, delta)
        local newLoop = patternLoop(self, st.slot)
        st.len = math.max(1, math.floor(st.len / oldLoop + 0.5)) * newLoop
        st.start = st.start % newLoop
    elseif key == "LOOPS" and st then
        self.undoData = copy(self.data)
        local loopT = patternLoop(self, st.slot)
        local loops = math.max(1, math.floor(st.len / loopT + 0.5) + delta)
        st.len = math.min(64, loops) * loopT
    elseif key and key:match("^IN%d$") and st then
        local t = tonumber(key:sub(3))
        st.mutes[t] = not st.mutes[t]
    elseif key == "DELETE" and st then
        if delta < 0 then return end
        if self.confirmRow ~= "DELETE" then self.confirmRow = "DELETE" return end
        self.confirmRow = nil
        self:deleteStep()
        return
    elseif key == "END" then
        self.data.atEnd = cycle(self.END_MODES, self:setting("atEnd", "STOP"), delta)
    elseif key == "SWITCH" then
        self.data.switchOn = cycle(self.SWITCH_MODES, self:setting("switchOn", "LOOP END"), delta)
    elseif key == "FADE" then
        self.data.fadeBars = cycle(self.FADE_CHOICES, self:setting("fadeBars", 2), delta)
    elseif key == "CLEAR" then
        if delta < 0 then return end
        if self.confirmRow ~= "CLEAR" then self.confirmRow = "CLEAR" return end
        self.confirmRow = nil
        self:clearSong()
        self.cursor = 1
        Looper:showToast("SONG CLEARED - L2 + R2 + LEFT UNDOES")
        return
    end
    self:save()
end

-- ---------------------------------------------------------------------------
-- song.txt
-- ---------------------------------------------------------------------------
function Song:save()
    local Save = require("src.save")
    local steps = {}
    for i, st in ipairs(self.data.steps) do
        local takes = {}
        for t, list in pairs(st.takes) do
            local out = {}
            for j, ev in ipairs(list) do
                local e = Session.plainEvent(ev)
                e.at = math.floor(ev.at + 0.5)
                out[j] = e
            end
            takes[t] = out
        end
        local moves = {}
        for j, m in ipairs(st.moves) do
            local c = copy(m)
            c.fresh = nil
            moves[j] = c
        end
        steps[i] = { slot = st.slot, start = math.floor(st.start + 0.5), len = math.floor(st.len + 0.5),
                     mutes = copy(st.mutes), moves = moves, takes = takes }
    end
    local ok, text = pcall(Save.encode, { format = 1, steps = steps, atEnd = self.data.atEnd,
                                          switchOn = self.data.switchOn, fadeBars = self.data.fadeBars })
    if not ok then
        log("song save failed: " .. tostring(text))
        return false
    end
    return love.filesystem.write(self.FILE, text) and true or false
end

local KINDS = { mute = true, fx = true, fade = true }

function Song:load()
    self.data = { steps = {} }
    local fs = love.filesystem
    if not (fs.getInfo and fs.getInfo(self.FILE)) then return false end
    local text = fs.read(self.FILE)
    local data = text and require("src.save").decode(text)
    if type(data) ~= "table" or data.format ~= 1 or type(data.steps) ~= "table" then
        log(self.FILE .. ": couldn't be read")
        return false
    end
    local num = function(v) return type(v) == "number" and v == v and v >= 0 and v < 1e9 end
    for _, raw in ipairs(data.steps) do
        if type(raw) == "table" and Patterns.isSlot(raw.slot) and num(raw.start) and num(raw.len) then
            local st = { slot = raw.slot, start = raw.start, len = raw.len, mutes = {}, moves = {}, takes = {} }
            for i = 1, 4 do st.mutes[i] = type(raw.mutes) == "table" and raw.mutes[i] == true end
            if type(raw.moves) == "table" then
                for _, m in ipairs(raw.moves) do
                    if type(m) == "table" and KINDS[m.kind] and num(m.at) then
                        local c = { at = m.at, kind = m.kind }
                        if m.kind == "mute" then
                            c.slot, c.muted = tonumber(m.slot), m.muted == true
                            if c.slot and c.slot >= 1 and c.slot <= 4 then st.moves[#st.moves + 1] = c end
                        elseif m.kind == "fx" then
                            c.s, c.h, c.d, c.c = m.s == true, m.h == true, m.d == true, m.c == true
                            st.moves[#st.moves + 1] = c
                        else
                            c.gain = Config.clamp(tonumber(m.gain) or 1, 0, 1)
                            st.moves[#st.moves + 1] = c
                        end
                    end
                end
            end
            if type(raw.takes) == "table" then
                for t = 1, 4 do
                    local list = raw.takes[t]
                    if type(list) == "table" then
                        local out = {}
                        for _, e in ipairs(list) do
                            local ev = type(e) == "table" and num(e.at) and Session.restoreEvent(e, 1e9)
                            if ev then ev.at = e.at out[#out + 1] = ev end
                        end
                        if #out > 0 then st.takes[t] = out end
                    end
                end
            end
            self.data.steps[#self.data.steps + 1] = st
        end
    end
    for _, v in ipairs(self.END_MODES) do if data.atEnd == v then self.data.atEnd = v end end
    for _, v in ipairs(self.SWITCH_MODES) do if data.switchOn == v then self.data.switchOn = v end end
    for _, v in ipairs(self.FADE_CHOICES) do if data.fadeBars == v then self.data.fadeBars = v end end
    return true
end

return Song
