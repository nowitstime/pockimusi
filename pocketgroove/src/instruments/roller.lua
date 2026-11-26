-- ============================================================================
-- src/instruments/roller.lua — Roller: pitched note repeat (PHASE_L.md L5)
--
-- Hold a face button and the note fires again on every step of its rate;
-- move the D-pad (or a shoulder) while it rolls and the next repeat takes the
-- new note. The arp chooses notes for you; Roller leaves every note to your
-- hand and keeps only the rhythm. Rolling drum and bass basslines, EDM 1/16
-- plucks, a trance gate on one note.
--   B  roll in 1/16 · A in 1/8 · Y in 1/8 triplets
--   X  roll in 1/16 with the off-beats accented (the rolling feel)
--   D-pad  degree, the Bass's compass (neutral = root), read at each repeat
--   L1 / R1  octave down / up (read at each repeat) · both: rate x2
-- Built on Lead (its clock-locked step timing and mono note handling, which
-- come from the Bass). Every repeat is an ordinary recorded note on the
-- roll's own grid, so playback, chord-follow, erase, Pump and Bass <-> Lead
-- <-> Roller swaps need nothing special.
-- ============================================================================

local Theory  = require("src.theory")
local Input   = require("src.input")
local Looper  = require("src.looper")
local Harmony = require("src.harmony")
local Lead    = require("src.instruments.lead")
local Patches = require("src.instruments.patches")

local math_floor = math.floor
local math_max   = math.max

local Roller = setmetatable({
    id = "roller",
    group = "BASS",
    name = "ROLLER",
    shortName = "ROLL",
    viewKind = "bass",         -- the Bass view, with its own panel and badge
    PANEL = "roller",
    defaultGridIndex = 3, -- 1/16
    eventClass = "mono",

    HOME_GROUP = "BASS",
    DEFAULT_PATCH = "bass_reese",
    REGISTER = 3,              -- 0 semitones = C3, as the Bass
    VOICES = 8,

    -- Steps per bar for each roll button
    ROLL_STEPS = { B = 16, A = 8, Y = 12, X = 16 },
    ROLL_LABELS = { B = "1/16", A = "1/8", Y = "1/8T", X = "1/16 ACC" },
    ACTION_LABELS = { B = "ROLL 1/16", A = "ROLL 1/8", Y = "ROLL 1/8T", X = "ROLLING" },

    -- Track page LENGTH row: how much of a step each note lasts
    LENGTHS = { "SHORT", "HALF", "FULL" },
    LENGTH_GATES = { SHORT = 0.3, HALF = 0.5, FULL = 0.9 },

    -- Velocities: plain repeats, the first of a roll, X's accented off-beats
    VEL = 0.8, VEL_FIRST = 0.88, VEL_ON = 0.62, VEL_OFF = 0.95,

    VIEW = {
        face = { B = "1/16", A = "1/8", Y = "1/8T", X = "ROLL" },
        l1 = "OCT -1", r1 = "OCT +1", both = "RATE x2",
    },
}, { __index = Lead })

function Roller:newState()
    local state = Lead.newState(self)
    state.patch = self.DEFAULT_PATCH
    state.length = "HALF"          -- Track page LENGTH row
    state.lastArticulation = "READY"
    state.rollBtn = nil            -- the roll button in charge (newest held)
    state.rollCount = 0            -- repeats since the roll started
    state.rollSkip = nil           -- grid step already played by an early press
    state.rollTimer = 0.0          -- free-running timer (clock paused)
    state.rollDouble = false
    state.beads = {}               -- recent repeats for the stage view: { semis, vel, age }
    return state
end

function Roller:getMiddleBadge(state)
    if not state.rollBtn then return "LENGTH " .. state.length end
    return "ROLL " .. self.ROLL_LABELS[state.rollBtn] .. (state.rollDouble and " x2" or "")
end

function Roller:getActiveButtons(state)
    return state.rollBtn and { [state.rollBtn] = true } or {}
end

function Roller:getDpadSubtitle()
    return "D-PAD: NOTE OF THE NEXT REPEAT"
end

-- ---------------------------------------------------------------------------
-- Track page rows: PATCH (sound), FOLLOW, LENGTH (settings)
-- ---------------------------------------------------------------------------
local function indexOf(list, value)
    for i, v in ipairs(list) do
        if v == value then return i end
    end
    return 1
end

local function itemsOf(list)
    local items = {}
    for i, v in ipairs(list) do items[i] = { label = v } end
    return items
end
local ON_OFF = { { label = "OFF" }, { label = "ON" } }

function Roller:getSoundRows(state)
    return {
        Patches.row(self, state),
        { key = "FOLLOW", label = "FOLLOW", value = state.follow and "ON" or "OFF", kind = "setting",
          items = ON_OFF, index = state.follow and 2 or 1 },
        { key = "LENGTH", label = "LENGTH", value = state.length, kind = "setting",
          items = itemsOf(self.LENGTHS), index = indexOf(self.LENGTHS, state.length) },
    }
end

function Roller:cycleSetting(state, key, delta)
    if key == "FOLLOW" then
        state.follow = not state.follow
        Looper:showToast("ROLLER FOLLOWS CHORDS: " .. (state.follow and "ON" or "OFF"))
    elseif key == "LENGTH" then
        local n = #self.LENGTHS
        state.length = self.LENGTHS[((indexOf(self.LENGTHS, state.length) - 1 + delta) % n) + 1]
        Looper:showToast("ROLLER LENGTH: " .. state.length)
    end
end

function Roller:previewRowSound(state, rowIdx)
    if rowIdx ~= 1 then return end
    Patches.preview(self, state, Theory:getRootSemis(), 0.85, nil, 0.2)
end

-- The roll's rate right now, in steps per bar
function Roller:getRollSteps(state, btn)
    return (self.ROLL_STEPS[btn or state.rollBtn] or 16) * (state.rollDouble and 2 or 1)
end

-- ---------------------------------------------------------------------------
-- Live input
-- ---------------------------------------------------------------------------
-- Grid steps sit at integers; odd steps are pushed late by `sw` (swing)
local function lastStepAt(u, sw)
    local base = math_floor(u)
    if base % 2 == 1 and (u - base) < sw then return base - 1 end
    return base
end

local function stepTime(i, sw)
    return i + ((i % 2 == 1) and sw or 0.0)
end

function Roller:updateVisuals(dt, state, controlsBlocked, isActive)
    Lead.updateVisuals(self, dt, state, controlsBlocked, isActive)
    if not isActive or controlsBlocked then
        state.rollBtn, state.rollSkip = nil, nil
    end
    for i = #state.beads, 1, -1 do
        local b = state.beads[i]
        b.age = b.age + dt
        if b.age > 1.6 then table.remove(state.beads, i) end
    end
end

function Roller:updateInput(dt, state, track, play, hold)
    local deg = self.COMPASS_DEGREE_MAP[Input:get8WayDirection()] or 1
    state.activeDegree = deg
    local both = Input.down.L1 and Input.down.R1
    local octave = both and 0 or ((Input.down.L1 and -1 or 0) + (Input.down.R1 and 1 or 0))
    state.rollDouble = both and true or false
    self:forgetFinished(state)
    self:updateRoll(dt, state, track, hold, deg, octave)
end

-- Play the roll's next note. `offset` = ticks the playhead is past the grid
-- step this note stands for (negative: before it), so it still ends on time.
-- `stepIdx` = the grid step (for X's off-beat accents).
function Roller:rollFire(state, track, hold, deg, octave, stepsPerLoop, offset, stepIdx)
    local btn = state.rollBtn
    local chord = state.follow and Harmony:chordAt(Looper.tick, self.CHORD_LOOKAHEAD) or nil
    local semis = self:pitchFor(state, deg, octave, chord)
    local vel = (state.rollCount == 0) and self.VEL_FIRST or self.VEL
    if btn == "X" then
        vel = ((stepIdx or state.rollCount) % 2 == 1) and self.VEL_OFF or self.VEL_ON
    end
    state.rollCount = state.rollCount + 1

    local gateFrac = self.LENGTH_GATES[state.length] or 0.5
    local gate = math_max(1, math_floor(Looper:getLoopTicks() / stepsPerLoop * gateFrac))
    state.lastArticulation = self.ACTION_LABELS[btn]
    state.lastSemis, state.lastDegree, state.lastOctave = semis, deg, octave
    table.insert(state.beads, { semis = semis, vel = vel, age = 0.0, deg = deg })
    if #state.beads > 24 then table.remove(state.beads, 1) end
    self:startHeld(state, track, hold,
        { action = btn, degree = deg, octave = octave, semis = semis, vel = vel,
          overrideGridSteps = stepsPerLoop },        -- recorded on the roll's own grid
        { fixedLen = math_max(1, math_floor(gate - (offset or 0))), recLen = gate }, chord)
end

function Roller:updateRoll(dt, state, track, hold, deg, octave)
    -- The newest held roll button is in charge
    local pressed
    for _, btn in ipairs({ "B", "A", "Y", "X" }) do
        if Input.pressed[btn] then pressed = btn end
    end
    if pressed then
        state.rollBtn, state.rollCount, state.rollSkip, state.rollTimer = pressed, 0, nil, 0.0
    elseif state.rollBtn and not Input.down[state.rollBtn] then
        state.rollBtn = nil
        for _, btn in ipairs({ "B", "A", "Y", "X" }) do
            if Input.down[btn] then state.rollBtn = btn end      -- another one is still held
        end
    end
    if not state.rollBtn then
        state.rollSkip = nil
        return
    end

    local stepsPerBar = self:getRollSteps(state)
    local total = stepsPerBar * Looper.bars

    if not Looper.playing then
        -- Clock paused: the roll keeps its own time
        local stepDur = Looper:getLoopDuration() / total
        if pressed then
            state.rollTimer = stepDur
            self:rollFire(state, track, hold, deg, octave, total)
        else
            state.rollTimer = state.rollTimer - dt
            if state.rollTimer <= 0.0 then
                state.rollTimer = state.rollTimer + stepDur
                self:rollFire(state, track, hold, deg, octave, total)
            end
        end
        return
    end

    -- Locked to the clock, with the track's swing (the arp's rule)
    local sw = Looper:getLiveSwing(track.slot, stepsPerBar)
    local subDur = Looper:getLoopDuration() / total
    local u, uPrev = Looper.phase * total, Looper.prevPhase * total
    local stepNow = lastStepAt(u, sw)
    local crossed = (stepNow ~= lastStepAt(uPrev, sw))
    local stepIdx = stepNow % total
    local tps = Looper:getTicksPerSecond()

    if pressed then
        local sinceStep = (u - stepTime(stepNow, sw)) * subDur
        local toNext = (stepTime(stepNow + 1, sw) - u) * subDur
        if crossed or sinceStep <= self.SNAP_WINDOW then
            self:rollFire(state, track, hold, deg, octave, total, sinceStep * tps, stepIdx)
        elseif toNext <= self.SNAP_WINDOW then
            state.rollSkip = (stepNow + 1) % total
            self:rollFire(state, track, hold, deg, octave, total, -toNext * tps, (stepNow + 1) % total)
        end
    elseif crossed then
        if state.rollSkip == stepIdx then
            state.rollSkip = nil
        else
            self:rollFire(state, track, hold, deg, octave, total, (u - stepTime(stepNow, sw)) * subDur * tps, stepIdx)
        end
    end
end

-- ---------------------------------------------------------------------------
-- Save / load (Phase C)
-- ---------------------------------------------------------------------------
function Roller:saveState(state)
    return { patch = state.patch, follow = state.follow, length = state.length }
end

function Roller:loadState(state, data)
    if type(data) ~= "table" then return end
    Patches.load(self, state, data.patch)
    for _, l in ipairs(self.LENGTHS) do
        if data.length == l then state.length = l end
    end
    if type(data.follow) == "boolean" then state.follow = data.follow end
end

return Roller
