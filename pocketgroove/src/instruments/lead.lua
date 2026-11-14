-- ============================================================================
-- src/instruments/lead.lua — Lead / Arp (SPEC §7.5, plan: PHASE_F.md)
--
-- Built on the Bass: the same D-pad degrees, event fields, follow rule,
-- voices and playback (everything not defined here comes from bass.lua).
--   B  a held note; D-pad and shoulders glide it while held (recorded bends)
--   A  arp up · Y arp down · X arp up-down, running while held
-- The arp walks a ladder of notes over the current chord (ARP PATTERN row),
-- starting from the D-pad's degree, one step per ARP RATE grid position with
-- the track's swing. L1 / R1 = octave; both = rate x2.
-- Every arp step is an ordinary recorded note, so playback, chord-follow,
-- erase and Bass <-> Lead swaps need nothing special.
-- ============================================================================

local Theory  = require("src.theory")
local Input   = require("src.input")
local Synth   = require("src.synth")
local Looper  = require("src.looper")
local Harmony = require("src.harmony")
local Bass    = require("src.instruments.bass")

local math_floor = math.floor
local math_max   = math.max

local Lead = setmetatable({
    id = "lead",
    name = "LEAD ARP",
    shortName = "LEAD",
    title = "COMET LEAD & ARP",
    defaultGridIndex = 3, -- 1/16
    eventClass = "mono",

    PATCHES = { "lead_square", "lead_saw", "lead_pluck" },

    -- Track page ARP RATE row: steps per bar
    RATES = { "1/8", "1/16", "1/8T" },
    RATE_STEPS = { ["1/8"] = 8, ["1/16"] = 16, ["1/8T"] = 12 },

    -- Track page ARP PATTERN row: the ladder's degrees and how many octaves
    -- of it one pass covers
    PATTERNS = { "CHORD", "CHORD 2 OCT", "7TH", "7TH 2 OCT", "SCALE" },
    PATTERN_DEFS = {
        ["CHORD"]       = { degrees = { 1, 3, 5 },             octaves = 1 },
        ["CHORD 2 OCT"] = { degrees = { 1, 3, 5 },             octaves = 2 },
        ["7TH"]         = { degrees = { 1, 3, 5, 7 },          octaves = 1 },
        ["7TH 2 OCT"]   = { degrees = { 1, 3, 5, 7 },          octaves = 2 },
        ["SCALE"]       = { degrees = { 1, 2, 3, 4, 5, 6, 7 }, octaves = 1 },
    },

    ARP_MODES = { A = "UP", Y = "DOWN", X = "UPDOWN" },
    ACTION_LABELS = { B = "NOTE", A = "ARP UP", Y = "ARP DOWN", X = "UP-DOWN" },

    GATE = 0.8,                -- an arp note lasts this much of its step
    SNAP_WINDOW = 0.045,       -- seconds: a press this close to a step is that step
    TOP_SEMIS = 29,            -- arp notes above this drop an octave (voices reach +36)
    -- Chord-follow lookahead in ticks (the bass uses a whole 1/16): under half
    -- of the fastest arp step, so the step before a chord change keeps the
    -- old chord, live and on playback
    CHORD_LOOKAHEAD = 59,
}, { __index = Bass })

function Lead:newState()
    local state = Bass.newState(self)
    state.patch = "lead_square"
    state.glide = "FAST"
    state.lastArticulation = "NOTE"
    state.rate = "1/16"            -- Track page ARP RATE row
    state.pattern = "CHORD"        -- Track page ARP PATTERN row
    -- Arp
    state.arpBtn = nil             -- the arp button in charge (newest held)
    state.arpStep = 0              -- steps played since it started
    state.arpSkip = nil            -- grid step already played by an early press
    state.arpTimer = 0.0           -- free-running timer (clock paused)
    state.arpDouble = false        -- rate x2 (both shoulders)
    state.arpPos = nil             -- position in the sequence of the last step (stage view)
    return state
end

-- ---------------------------------------------------------------------------
-- Track page rows: PATCH (sound), FOLLOW, ARP RATE, ARP PATTERN (settings)
-- ---------------------------------------------------------------------------
local function indexOf(list, value)
    for i, v in ipairs(list) do
        if v == value then return i end
    end
    return 1
end

local function step(list, value, delta)
    return list[((indexOf(list, value) - 1 + delta) % #list) + 1]
end

function Lead:getSoundRows(state)
    local patch = self:getPatch(state)
    return {
        { key = "PATCH", label = "PATCH", value = patch and patch.label or state.patch,
          hint = string.format("%d/%d", indexOf(self.PATCHES, state.patch), #self.PATCHES) },
        { key = "FOLLOW", label = "FOLLOW", value = state.follow and "ON" or "OFF", kind = "setting",
          hint = "CHORDS" },
        { key = "RATE", label = "ARP RATE", value = state.rate, kind = "setting",
          hint = string.format("%d/%d", indexOf(self.RATES, state.rate), #self.RATES) },
        { key = "PATTERN", label = "ARP PATTERN", value = state.pattern, kind = "setting",
          hint = string.format("%d/%d", indexOf(self.PATTERNS, state.pattern), #self.PATTERNS) },
    }
end

function Lead:cycleRowSound(state, rowIdx, delta)
    if rowIdx ~= 1 then return end
    state.patch = step(self.PATCHES, state.patch, delta)
    local patch = self:getPatch(state)
    if patch then
        local v = Synth:noteOn(state.patch, Theory:getRootSemis(), 0.8, {})     -- preview
        if v then Synth:schedule(0.25, function() v:noteOff() end) end
        Looper:showToast("LEAD PATCH: " .. patch.label)
    end
end

function Lead:cycleSetting(state, key, delta)
    if key == "FOLLOW" then
        state.follow = not state.follow
        Looper:showToast("LEAD FOLLOWS CHORDS: " .. (state.follow and "ON" or "OFF"))
    elseif key == "RATE" then
        state.rate = step(self.RATES, state.rate, delta)
        Looper:showToast("ARP RATE: " .. state.rate)
    elseif key == "PATTERN" then
        state.pattern = step(self.PATTERNS, state.pattern, delta)
        Looper:showToast("ARP PATTERN: " .. state.pattern)
    end
end

-- Erase page: what the button plays instead of its letter
function Lead:getActionLabel(state, btn)
    return self.ACTION_LABELS[btn] or btn
end

-- ---------------------------------------------------------------------------
-- The arp's notes
-- ---------------------------------------------------------------------------
function Lead:getPattern(state)
    return self.PATTERN_DEFS[state.pattern] or self.PATTERN_DEFS.CHORD
end

-- Rung `r` of the ladder (0 = the pattern's first degree in the home octave;
-- negative rungs go below) -> degree, octave
local function rungNote(degrees, r)
    local n = #degrees
    return degrees[(r % n) + 1], math_floor(r / n)
end

-- The rung a D-pad degree starts from: the nearest ladder note at or below it
function Lead:startRung(state, dpadDegree)
    local degrees = self:getPattern(state).degrees
    local deg, oct = dpadDegree, 0
    if deg == -2 then deg, oct = 5, -1            -- the 5th below
    elseif deg >= 8 then deg, oct = deg - 7, 1 end -- the octave
    local idx = 1
    for i, d in ipairs(degrees) do
        if d <= deg then idx = i end
    end
    return (idx - 1) + oct * #degrees
end

-- One pass of the arp as a list of rungs, for a mode ("UP", "DOWN", "UPDOWN")
function Lead:arpSequence(state, mode, dpadDegree)
    local pat = self:getPattern(state)
    local start = self:startRung(state, dpadDegree)
    local n = #pat.degrees * pat.octaves
    local seq = {}
    if mode == "DOWN" then
        for i = n - 1, 0, -1 do seq[#seq + 1] = start + i end
    else
        for i = 0, n - 1 do seq[#seq + 1] = start + i end
        if mode == "UPDOWN" then
            for i = n - 2, 1, -1 do seq[#seq + 1] = start + i end   -- the ends aren't repeated
        end
    end
    return seq
end

-- The arp's rate right now, in steps per bar
function Lead:getArpSteps(state)
    return (self.RATE_STEPS[state.rate] or 16) * (state.arpDouble and 2 or 1)
end

-- ---------------------------------------------------------------------------
-- Sound: as the bass, without the accent vibrato
-- ---------------------------------------------------------------------------
function Lead:startVoice(ev, state, track, semis, glideFrom)
    local patch = self:getPatch(state)
    semis = semis or ev.semis or 0
    if glideFrom == nil then glideFrom = ev.glideFrom end
    return Synth:noteOn(state.patch, semis, ev.vel or 0.85, {
        track = track,
        glideFrom = glideFrom,
        glideRate = self:getGlideRate(state),
    }) or (patch and patch.attack and Synth:trigger(patch.attack, semis, ev.vel or 0.85, 1.0, nil, track.volume, track))
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

-- Held right now? (arp notes have a fixed length and don't depend on a button)
local function physicallyHeld(h)
    return h:isHeld() and (h.fixedLen ~= nil or Input.down[h.ev.action])
end

function Lead:forgetFinished(state)
    for i = #state.handles - 1, 1, -1 do
        local h = state.handles[i]
        local v = state.voices[h.ev]
        if not h:isHeld() and not (v and v:isSounding()) then
            state.voices[h.ev] = nil
            table.remove(state.handles, i)
        end
    end
end

-- Start a note; a mono patch ends the one before, exactly where this starts
function Lead:startHeld(state, track, hold, ev, opts, chord)
    local patch = self:getPatch(state)
    local mono = not (patch and patch.overlap)
    local prev = state.handles[#state.handles]
    local cut = mono and prev and physicallyHeld(prev)
    if cut then prev:release() end

    local h = hold(ev, opts)
    h.bentSemis, h.bentOctave = ev.semis, ev.octave
    h.chord = chord
    table.insert(state.handles, h)

    if cut and prev.rec and h.rec then
        local len = (h.rec.tick - prev.rec.tick) % Looper:getLoopTicks()
        if len > 0 then prev.rec.len = len end
    end
    return h
end

function Lead:updateInput(dt, state, track, play, hold)
    local deg = self.COMPASS_DEGREE_MAP[Input:get8WayDirection()] or 1
    state.activeDegree = deg
    local both = Input.down.L1 and Input.down.R1
    local octave = both and 0 or ((Input.down.L1 and -1 or 0) + (Input.down.R1 and 1 or 0))
    state.arpDouble = both and true or false
    local chordNow = state.follow and Harmony:chordAt(Looper.tick, self.CHORD_LOOKAHEAD) or nil

    self:forgetFinished(state)

    -- B: a held note
    if Input.pressed.B then
        local semis = self:pitchFor(state, deg, octave, chordNow)
        state.lastArticulation = "NOTE"
        self:startHeld(state, track, hold, { action = "B", degree = deg, octave = octave, semis = semis, vel = 0.85 },
            nil, chordNow)
    end

    -- ... which glides when the D-pad or shoulders move (and in its fading
    -- tail, when a direction is held), as on the bass
    local h = state.handles[#state.handles]
    if h and h.ev.action == "B" then
        local v = state.voices[h.ev]
        if h:isHeld() or (v and v:isSounding()) then
            local tDeg, tOct = deg, octave
            if not physicallyHeld(h) then
                if Input:get8WayDirection() == "NEUTRAL" then tDeg = nil end
                if not (Input.down.L1 or Input.down.R1) then tOct = h.bentOctave end
            end
            if tDeg then
                local tSemis = self:pitchFor(state, tDeg, tOct, h.chord)
                if tSemis ~= h.bentSemis then
                    h.bentSemis, h.bentOctave = tSemis, tOct
                    h:bend({ degree = tDeg, octave = tOct, semis = tSemis })
                    state.lastSemis, state.lastDegree, state.lastOctave = tSemis, tDeg, tOct
                end
            end
        end
    end

    self:updateArp(dt, state, track, hold, deg, octave)
end

-- Play the arp's next note. `offset` = ticks the playhead is past the grid
-- step this note stands for (negative: before it), so it still ends on time.
function Lead:arpFire(state, track, hold, deg, octave, stepsPerLoop, offset)
    local btn = state.arpBtn
    local seq = self:arpSequence(state, self.ARP_MODES[btn], deg)
    local pos = state.arpStep % #seq
    state.arpStep = state.arpStep + 1
    state.arpPos = pos

    local degrees = self:getPattern(state).degrees
    local noteDeg, noteOct = rungNote(degrees, seq[pos + 1])
    noteOct = noteOct + octave
    -- every step reads the chord, so a held arp follows the changes
    local chord = state.follow and Harmony:chordAt(Looper.tick, self.CHORD_LOOKAHEAD) or nil
    local semis = self:pitchFor(state, noteDeg, noteOct, chord)
    while semis > self.TOP_SEMIS do
        semis, noteOct = semis - 12, noteOct - 1
    end

    local gate = math_max(1, math_floor(Looper:getLoopTicks() / stepsPerLoop * self.GATE))
    state.lastArticulation = self.ACTION_LABELS[btn]
    self:startHeld(state, track, hold,
        { action = btn, degree = noteDeg, octave = noteOct, semis = semis,
          vel = (pos == 0) and 0.9 or 0.78,          -- a light accent on each pass
          overrideGridSteps = stepsPerLoop },        -- recorded on the arp's own grid
        { fixedLen = math_max(1, math_floor(gate - (offset or 0))), recLen = gate }, chord)
end

function Lead:updateArp(dt, state, track, hold, deg, octave)
    -- The newest held arp button is in charge
    local pressed
    for _, btn in ipairs({ "A", "Y", "X" }) do
        if Input.pressed[btn] then pressed = btn end
    end
    if pressed then
        state.arpBtn, state.arpStep, state.arpSkip, state.arpTimer = pressed, 0, nil, 0.0
    elseif state.arpBtn and not Input.down[state.arpBtn] then
        state.arpBtn = nil
        for _, btn in ipairs({ "A", "Y", "X" }) do
            if Input.down[btn] then state.arpBtn = btn end      -- another one is still held
        end
    end
    if not state.arpBtn then
        state.arpSkip, state.arpPos = nil, nil
        return
    end

    local stepsPerBar = self:getArpSteps(state)
    local total = stepsPerBar * Looper.bars

    if not Looper.playing then
        -- Clock paused: the arp keeps its own time
        local stepDur = Looper:getLoopDuration() / total
        if pressed then
            state.arpTimer = stepDur
            self:arpFire(state, track, hold, deg, octave, total)
        else
            state.arpTimer = state.arpTimer - dt
            if state.arpTimer <= 0.0 then
                state.arpTimer = state.arpTimer + stepDur
                self:arpFire(state, track, hold, deg, octave, total)
            end
        end
        return
    end

    -- Locked to the clock, with the track's swing (the drum repeat's rule)
    local sw = Looper:getLiveSwing(track.slot, stepsPerBar)
    local subDur = Looper:getLoopDuration() / total
    local u, uPrev = Looper.phase * total, Looper.prevPhase * total
    local stepNow = lastStepAt(u, sw)
    local crossed = (stepNow ~= lastStepAt(uPrev, sw))
    local stepIdx = stepNow % total

    if pressed then
        local sinceStep = (u - stepTime(stepNow, sw)) * subDur
        local toNext = (stepTime(stepNow + 1, sw) - u) * subDur
        local tps = Looper:getTicksPerSecond()
        if crossed or sinceStep <= self.SNAP_WINDOW then
            self:arpFire(state, track, hold, deg, octave, total, sinceStep * tps)   -- this press is that step
        elseif toNext <= self.SNAP_WINDOW then
            state.arpSkip = (stepNow + 1) % total                      -- ...or stands in for the next
            self:arpFire(state, track, hold, deg, octave, total, -toNext * tps)
        end                                                            -- else: starts on the next step
    elseif crossed then
        if state.arpSkip == stepIdx then
            state.arpSkip = nil
        else
            self:arpFire(state, track, hold, deg, octave, total, (u - stepTime(stepNow, sw)) * subDur * Looper:getTicksPerSecond())
        end
    end
end

-- ---------------------------------------------------------------------------
-- Save / load (Phase C)
-- ---------------------------------------------------------------------------
function Lead:saveState(state)
    return { patch = state.patch, follow = state.follow, rate = state.rate, pattern = state.pattern }
end

function Lead:loadState(state, data)
    if type(data) ~= "table" then return end
    for _, p in ipairs(self.PATCHES) do
        if data.patch == p then state.patch = p end
    end
    for _, r in ipairs(self.RATES) do
        if data.rate == r then state.rate = r end
    end
    for _, p in ipairs(self.PATTERNS) do
        if data.pattern == p then state.pattern = p end
    end
    if type(data.follow) == "boolean" then state.follow = data.follow end
end

return Lead
