-- ============================================================================
-- src/instruments/breaks.lua — Breaks: play a famous break and rearrange it
-- live (PHASE_L.md L8; the breaks are in src/breaks.lua)
--
-- The machine decides what is in each slice; you decide the order and the
-- edits. The break plays only while a face button is held:
--   B  play: from where the clock is (in time), or from the D-pad's slice
--   A  stutter: repeat a chunk of the track's grid from where it is
--   Y  reverse: the break runs backwards from where it is
--   X  choke: cut everything at once (held: silence, the break keeps time)
--   D-pad  a direction = jump to slice 1..8 (clockwise from UP) at the next
--          1/8 line; neutral = carry on
--   L1 / R1 held  half time / double time · both: a snare roll that speeds
--          up into the next bar line (the build)
--
-- Recording keeps your moves, not the drum hits: each stretch of playing is
-- a held note { action, at (0..1 into the break) or sync, slice, mode
-- (play / stutter / reverse / roll), speed, chunk }. Playback turns it into
-- hits from the break and kit chosen now, so BREAK and KIT can be changed
-- afterwards and the same performance plays on another break.
-- ============================================================================

local Config  = require("src.config")
local Input   = require("src.input")
local Synth   = require("src.synth")
local Looper  = require("src.looper")
local Library = require("src.breaks")
local Drums   = require("src.instruments.drums")

local clamp      = Config.clamp
local math_floor = math.floor
local math_max   = math.max
local math_min   = math.min

local Breaks = {
    id = "breaks",
    group = "RHYTHM",
    name = "BREAKS",
    shortName = "BRKS",
    viewKind = "breaks",
    eventClass = "breaks",
    defaultGridIndex = 3, -- 1/16 (also the stutter's chunk)

    -- D-pad direction -> slice (clockwise from UP)
    SLICE_OF = { UP = 1, UP_RIGHT = 2, RIGHT = 3, DOWN_RIGHT = 4, DOWN = 5, DOWN_LEFT = 6, LEFT = 7, UP_LEFT = 8 },
    JUMP_TICKS = 240,          -- a jump waits for the next 1/8 line
    SNAP_WINDOW = 0.045,       -- seconds: a jump this close after a line goes at once
    ROLL_SOUND_ROLE = "snare",
    ACTION_LABELS = { B = "PLAY", A = "STUTTER", Y = "REVERSE", X = "CHOKE" },

    VIEW = {
        dpad = { NEUTRAL = "ON", UP = "1", UP_RIGHT = "2", RIGHT = "3", DOWN_RIGHT = "4",
                 DOWN = "5", DOWN_LEFT = "6", LEFT = "7", UP_LEFT = "8" },
        face = { B = "PLAY", A = "STUT", Y = "REV", X = "CHOKE" },
        l1 = "HALF", r1 = "DOUBLE", both = "ROLL",
    },
}

function Breaks:newState()
    return {
        breakId = Library.LIST[1].id,  -- Track page BREAK row
        kit = nil,                     -- Track page KIT row (nil = the break's own kit)
        segs = {},                     -- [ev] = a stretch of break playing (live or playback)
        seg = nil,                     -- the live stretch's handle
        order = {},                    -- face buttons held, oldest first
        lastDir = "NEUTRAL",
        pendingSlice = nil,            -- a jump waiting for the next 1/8 line
        flash = {},                    -- [role] = 0..1, for the stage view
        viewPos = nil,                 -- where in the break the live stretch is (0..1)
        viewMode = nil,
        hitsKey = nil, hits = nil,     -- the break's hits at the track's swing (cache)
    }
end

function Breaks:getDpadSubtitle()
    return "D-PAD: JUMP TO A SLICE"
end

-- ---------------------------------------------------------------------------
-- The break and kit
-- ---------------------------------------------------------------------------
function Breaks:getBreak(state)
    return Library.byId[state.breakId] or Library.LIST[1]
end

function Breaks:getKit(state)
    local brk = self:getBreak(state)
    return Library.kitByName[state.kit or brk.kit] or Library.KITS[1]
end

function Breaks:kitName(state)
    return self:getKit(state).name
end

-- The break's hits at the track's swing, and its length in ticks
function Breaks:hitList(state, track)
    local brk = self:getBreak(state)
    local sw = track and track.swing or 0.5
    local key = brk.id .. ":" .. sw
    if state.hitsKey ~= key then
        state.hits, state.hitsKey = Library.hitTicks(brk, sw), key
    end
    return state.hits, brk.ticks
end

-- ---------------------------------------------------------------------------
-- Track page rows: BREAK and KIT (settings)
-- ---------------------------------------------------------------------------
local function breakItems()
    local items = {}
    for i, b in ipairs(Library.LIST) do items[i] = { label = b.name } end
    return items
end

local function kitItems()
    local items = {}
    for i, k in ipairs(Library.KITS) do items[i] = { label = k.name } end
    return items
end

local function indexWhere(list, pred)
    for i, v in ipairs(list) do
        if pred(v) then return i end
    end
    return 1
end

function Breaks:getSoundRows(state)
    local bi = indexWhere(Library.LIST, function(b) return b.id == state.breakId end)
    local kitName = self:kitName(state)
    local ki = indexWhere(Library.KITS, function(k) return k.name == kitName end)
    return {
        { key = "BREAK", label = "BREAK", value = Library.LIST[bi].name, kind = "setting",
          items = breakItems(), index = bi },
        { key = "KIT", label = "KIT", value = kitName, kind = "setting", items = kitItems(), index = ki },
    }
end

function Breaks:cycleSetting(state, key, delta)
    if key == "BREAK" then
        local n = #Library.LIST
        local i = indexWhere(Library.LIST, function(b) return b.id == state.breakId end)
        local brk = Library.LIST[((i - 1 + delta) % n) + 1]
        state.breakId = brk.id
        Looper:showToast("BREAK: " .. brk.name)
    elseif key == "KIT" then
        local n = #Library.KITS
        local name = self:kitName(state)
        local i = indexWhere(Library.KITS, function(k) return k.name == name end)
        state.kit = Library.KITS[((i - 1 + delta) % n) + 1].name
        Looper:showToast("BREAK KIT: " .. state.kit)
    end
end

function Breaks:getActionLabel(state, btn)
    return self.ACTION_LABELS[btn] or btn
end

-- ---------------------------------------------------------------------------
-- Sound: a stretch of break playing (live or recorded) fires its hits as the
-- clock moves (updateVoices)
-- ---------------------------------------------------------------------------
function Breaks:fire(state, track, role, vel)
    local sound, tune, level = Library.roleSound(self:getKit(state), role)
    vel = clamp(vel * level, 0.0, 1.0)
    Synth:trigger(sound, tune, vel, 1.0, nil, track.volume, track, Drums.velTone(vel))
    state.flash[role] = 1.0
end

-- Hits at break positions [p, p + len), wrapping round the break
local function fireForward(self, state, track, hits, total, p, len)
    if len <= 0 then return end
    p = p % total
    local stop = p + len
    for i = 1, #hits do
        local t = hits[i].tick
        if (t >= p and t < stop) or (t + total >= p and t + total < stop) then
            self:fire(state, track, hits[i].role, hits[i].vel)
        end
    end
end

-- Hits at break positions (p - len, p], running backwards
local function fireBackward(self, state, track, hits, total, p, len)
    if len <= 0 then return end
    p = p % total
    local lo = p - len
    for i = #hits, 1, -1 do
        local t = hits[i].tick
        if (t > lo and t <= p) or (t - total > lo and t - total <= p) then
            self:fire(state, track, hits[i].role, hits[i].vel)
        end
    end
end

-- The snare roll: 1/8 more than half a bar before the bar line, then 1/16,
-- then 1/32 in the last quarter bar (and after it), getting louder
function Breaks:rollRate(ticksToBar)
    if ticksToBar > 960 then return 240 end
    if ticksToBar > 480 then return 120 end
    return 60
end

local function fireRoll(self, state, track, entry, s0, s1)
    local bar = Library.BAR_TICKS
    local barEnd = entry.barEnd
    local t = math.ceil(s0 / 60) * 60
    while t < s1 do
        local r = barEnd - t
        local rate = self:rollRate(r)
        if t % rate == 0 then
            self:fire(state, track, self.ROLL_SOUND_ROLE, 0.45 + 0.5 * clamp(1.0 - r / bar, 0.0, 1.0))
        end
        t = t + 60
    end
end

-- Move a stretch on by `d` clock ticks and fire what it passes
function Breaks:advance(entry, state, track, d)
    local hits, total = self:hitList(state, track)
    local ev = entry.ev
    local mode = ev.mode or "play"
    if mode == "roll" then
        local s0 = entry.song + entry.u
        entry.u = entry.u + d
        fireRoll(self, state, track, entry, s0, entry.song + entry.u)
        return
    end
    local du = d * (ev.speed or 1)
    local u0, u1 = entry.u, entry.u + du
    entry.u = u1
    if mode == "reverse" then
        fireBackward(self, state, track, hits, total, entry.start - u0, du)
        entry.pos = (entry.start - u1) % total
    elseif mode == "stutter" then
        local c = math_max(1, ev.chunk or 120)
        local x = u0
        while x < u1 do
            local k = math_floor(x / c)
            local segEnd = math_min(u1, (k + 1) * c)
            fireForward(self, state, track, hits, total, entry.start + (x - k * c), segEnd - x)
            x = segEnd
        end
        entry.pos = (entry.start + (u1 % c)) % total
    else
        fireForward(self, state, track, hits, total, entry.start + u0, du)
        entry.pos = (entry.start + u1) % total
    end
end

-- Where a stretch starts in the break (ticks): in time with the clock, at a
-- slice, or at a fraction of the way through
function Breaks:startPos(state, track, ev, songTick)
    local _, total = self:hitList(state, track)
    if ev.slice then return (ev.slice - 1) * total / Library.SLICES end
    if ev.sync or not ev.at then return songTick % total end
    return (ev.at * total) % total
end

function Breaks:noteOn(ev, state, track, isPlayback)
    -- How far behind the stretch already is: on playback, the frame since the
    -- event's tick; live, a press in time with the clock also plays the hits
    -- of the last SNAP_WINDOW (it was meant for the beat just gone)
    local lead = 0
    local forward = (ev.mode or "play") == "play" or ev.mode == "stutter"
    if isPlayback then
        local loop = Looper:getLoopTicks()
        lead = (Looper.tick - ev.tick) % loop
        if lead > loop * 0.5 then lead = 0 end
    elseif ev.sync and forward and Looper.playing then
        lead = self.SNAP_WINDOW * Looper:getTicksPerSecond()
    end
    local song = isPlayback and ev.tick or (Looper.tick - lead)
    local entry = {
        ev = ev, u = 0.0, lastTick = Looper.tick, playback = isPlayback,
        song = song, barEnd = (math_floor(song / Library.BAR_TICKS) + 1) * Library.BAR_TICKS,
    }
    entry.start = self:startPos(state, track, ev, song)
    entry.pos = entry.start
    state.segs[ev] = entry
    -- catch up now (and the hit right at the start sounds now, not a frame later)
    self:advance(entry, state, track, lead + 1)
end

function Breaks:noteOff(ev, state)
    state.segs[ev] = nil
end

function Breaks:updateVoices(dt, state, track)
    local loop = Looper:getLoopTicks()
    for _, entry in pairs(state.segs) do
        local d
        if Looper.playing then
            d = (Looper.tick - entry.lastTick) % loop
            if d > loop * 0.5 then d = 0 end         -- a backward jump (stutter FX): no hits
        else
            d = dt * Looper:getTicksPerSecond()      -- clock paused: the break keeps its own time
        end
        entry.lastTick = Looper.tick
        if d > 0 then self:advance(entry, state, track, d) end
    end
end

function Breaks:updateVisuals(dt, state)
    for role, v in pairs(state.flash) do
        state.flash[role] = math_max(0.0, v - dt * 5.0)
    end
    local live = state.seg and state.segs[state.seg.ev]
    if live then
        local _, total = self:hitList(state, nil)
        state.viewPos = (live.pos or 0) / total
        state.viewMode = live.ev.mode
    else
        state.viewPos, state.viewMode = nil, nil
    end
end

-- ---------------------------------------------------------------------------
-- Live input
-- ---------------------------------------------------------------------------
-- The face button in charge: the newest of B / A / Y still held
local function updateOrder(state)
    for _, btn in ipairs({ "B", "A", "Y" }) do
        if Input.pressed[btn] then
            for i = #state.order, 1, -1 do
                if state.order[i] == btn then table.remove(state.order, i) end
            end
            state.order[#state.order + 1] = btn
        end
    end
    for i = #state.order, 1, -1 do
        if not Input.down[state.order[i]] then table.remove(state.order, i) end
    end
    return state.order[#state.order]
end

-- Cut every sound this track is making
function Breaks:choke(track)
    for _, v in ipairs(Synth.activeVoices) do
        if v.track == track then v.maxLife = math_min(v.maxLife, v.elapsed + 0.02) end
    end
end

function Breaks:endStretch(state)
    if state.seg then
        state.seg:release()
        state.seg = nil
    end
end

-- Start a live stretch: what it is, and where it starts
function Breaks:startStretch(state, track, hold, want, where)
    self:endStretch(state)
    local ev = { action = want.btn, mode = want.mode, speed = want.speed, vel = 0.85 }
    if want.mode == "stutter" then
        local g = Looper:getTrackGrid(track.slot)
        ev.chunk = (g and g.stepTicks) or 240
    end
    if where.slice then
        ev.slice = where.slice
    elseif where.at then
        ev.at = where.at
    else
        ev.sync = true
    end
    state.seg = hold(ev, { manual = true })
    state.want = want
end

-- Did the clock cross a 1/8 line this frame? (clock paused: always)
function Breaks:crossedJumpLine()
    if not Looper.playing then return true end
    local step = self.JUMP_TICKS
    local cur, prev = Looper.tick, Looper.prevTick or Looper.tick
    return math_floor(cur / step) ~= math_floor(prev / step) or cur < prev
end

-- Is the clock just past a 1/8 line? (a jump pressed now goes at once)
function Breaks:justAfterJumpLine()
    if not Looper.playing then return true end
    return (Looper.tick % self.JUMP_TICKS) / Looper:getTicksPerSecond() <= self.SNAP_WINDOW
end

function Breaks:getActiveButtons(state)
    local on = {}
    if state.want and state.seg then on[state.want.btn] = true end
    if Input.down.X then on.X = true end
    return on
end

function Breaks:updateInput(dt, state, track, play, hold)
    local dir = Input:get8WayDirection()
    local slice = self.SLICE_OF[dir]
    local btn = updateOrder(state)
    local both = Input.down.L1 and Input.down.R1
    local speed = both and 1 or ((Input.down.L1 and 0.5) or (Input.down.R1 and 2) or 1)

    if Input.pressed.X then self:choke(track) end
    if Input.down.X then btn = nil end              -- held: silence, the break keeps time

    local want
    if btn then
        local mode = (both and "roll") or (btn == "A" and "stutter") or (btn == "Y" and "reverse") or "play"
        want = { btn = btn, mode = mode, speed = speed }
    end

    local cur = state.seg and state.segs[state.seg.ev]
    if not want then
        self:endStretch(state)
        state.pendingSlice = nil
    elseif not cur then
        -- a fresh press: from the D-pad's slice, or in time with the clock
        self:startStretch(state, track, hold, want, { slice = slice })
        state.pendingSlice = nil
    else
        local have = state.want
        local _, total = self:hitList(state, track)
        if have.btn ~= want.btn or have.mode ~= want.mode or have.speed ~= want.speed then
            -- a different move: carry on from where the break is
            self:startStretch(state, track, hold, want, { at = (cur.pos or 0) / total })
        end
        -- a new direction: jump to that slice at the next 1/8 line (at once
        -- if the line has only just gone by)
        if slice and dir ~= state.lastDir then
            state.pendingSlice = slice
            if self:justAfterJumpLine() then
                self:startStretch(state, track, hold, want, { slice = slice })
                state.pendingSlice = nil
            end
        end
        if state.pendingSlice and self:crossedJumpLine() then
            self:startStretch(state, track, hold, want, { slice = state.pendingSlice })
            state.pendingSlice = nil
        end
    end
    state.lastDir = dir
end

-- ---------------------------------------------------------------------------
-- Save / load (Phase C)
-- ---------------------------------------------------------------------------
function Breaks:saveState(state)
    return { breakId = state.breakId, kit = state.kit }
end

function Breaks:loadState(state, data)
    if type(data) ~= "table" then return end
    if type(data.breakId) == "string" and Library.byId[data.breakId] then state.breakId = data.breakId end
    if type(data.kit) == "string" and Library.kitByName[data.kit] then state.kit = data.kit end
end

return Breaks
