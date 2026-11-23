-- ============================================================================
-- src/instruments/drums.lua — 4-Pad Drum Kit
--   Face buttons  = pads (X top, Y left, A right, B bottom)
--   D-pad ↑ / ↓   = dynamics: ACCENT / GHOST
--   D-pad ← / →   = articulation: FLAM / RATCHET (diagonals combine both axes)
--   L1 / R1 / both = grid-locked note repeat at 1/4, 1/8, 1/16 (1/12T on triplet grid)
-- Track page rows: KIT, the four pad sounds, TUNE and LEVEL for the selected
-- pad, and VARIATION (playback-only randomness; plan: PHASE_H.md)
-- ============================================================================

local Config = require("src.config")
local Input  = require("src.input")
local Synth  = require("src.synth")
local Looper = require("src.looper")

local clamp      = Config.clamp
local math_floor = math.floor
local math_max   = math.max

local Drums = {
    id = "drums",
    group = "RHYTHM",
    name = "DRUMS",
    shortName = "DRUMS",
    defaultGridIndex = 3, -- 1/16
    eventClass = "drums",    -- instruments built on Drums keep each other's hits on a swap

    PADS = { "X", "Y", "A", "B" },   -- display order: matches the button diamond top -> bottom
    RATCHET_HITS = 3,
    REPEAT_SNAP_WINDOW = 0.045,      -- seconds: a press this close to a repeat tick counts as that tick

    -- Track page VARIATION row: applied on playback only, never recorded
    VARIATIONS = { "OFF", "LIGHT", "WILD" },
    VEL_JITTER = { LIGHT = 0.12, WILD = 0.22 },   -- level moves by up to this fraction
    LATE_CHANCE = 0.35,              -- WILD: share of off-beat hits that land late...
    LATE_MAX = 0.014,                -- ...by up to this many seconds
    FILL_CHANCE = 0.22,              -- WILD: per empty step in the last beat of a bar
    FILL_VEL = { 0.28, 0.45 },       -- a fill hit's level range
    GHOST_MAX_VEL = 0.5,             -- a hit this quiet is a ghost
    GHOST_CHANCE = 0.5,              -- a ghost recorded with variation on plays this often

    -- Track page TUNE and LEVEL rows (for the selected pad)
    TUNE_RANGE = 12,                 -- semitones either way
    LEVEL_MIN = 0.1, LEVEL_MAX = 1.2, LEVEL_STEP = 0.1,

    -- A kit is a preset of four one-shots, one per pad
    KITS = {
        { name = "808 CLASSIC", pads = { B = "kick_808",      Y = "snare_analog", A = "hat_closed",  X = "clap_studio"  } },
        { name = "909 HOUSE",   pads = { B = "kick_909",      Y = "snare_tight",  A = "hat_closed",  X = "hat_open"     } },
        { name = "LO-FI",       pads = { B = "kick_lofi",     Y = "snare_lofi",   A = "hat_tick",    X = "perc_snap"    } },
        { name = "ACOUSTIC",    pads = { B = "kick_acoustic", Y = "snare_brush",  A = "cym_ride",    X = "perc_wood"    } },
        { name = "LATIN",       pads = { B = "perc_conga",    Y = "perc_wood",    A = "perc_shaker", X = "perc_cowbell" } },
        { name = "INDUSTRIAL",  pads = { B = "kick_gabber",   Y = "snare_gated",  A = "hat_tick",    X = "fx_zap"       } },
    },
}

local function catalogIndexOf(soundId)
    for i, item in ipairs(Synth.drumCatalog) do
        if item.id == soundId then return i end
    end
    return 1
end

function Drums:newState()
    local state = {
        kitIndex = 1,
        kitEdited = false,
        padCatalogIndex = {},
        lastPad = "B",             -- the Track page cursor starts here
        expressionName = "NORMAL",
        velocity = 0.85,
        decayMod = 1.0,
        orn = nil,                 -- "flam" while LEFT is held
        ratchet = nil,             -- hit count while RIGHT is held
        repeatLabel = "OFF",
        padFlash = { B = 0, Y = 0, A = 0, X = 0 },
        padOrn = { B = nil, Y = nil, A = nil, X = nil },
        variation = "OFF",         -- Track page VARIATION row
        padTune = { B = 0, Y = 0, A = 0, X = 0 },          -- Track page TUNE row, per pad (semitones)
        padLevel = { B = 1.0, Y = 1.0, A = 1.0, X = 1.0 }, -- Track page LEVEL row, per pad
        rolled = {},               -- [ev] = plays this pass? (a flam's grace note and hit share one roll)
        fillStep = nil,            -- the last step considered for a fill
        skipTick = {},             -- per pad: repeat tick already played by an early press
        pendingTick = {},          -- per pad: repeat tick that should play even if the pad was released
    }
    self:applyKit(state, 1)
    return state
end

-- ---------------------------------------------------------------------------
-- Sounds & kits
-- ---------------------------------------------------------------------------
function Drums:applyKit(state, kitIdx)
    local kit = self.KITS[kitIdx]
    state.kitIndex = kitIdx
    state.kitEdited = false
    for pad, soundId in pairs(kit.pads) do
        state.padCatalogIndex[pad] = catalogIndexOf(soundId)
    end
end

function Drums:getPadSound(state, padBtn)
    local idx = state.padCatalogIndex[padBtn] or 1
    return Synth.drumCatalog[idx] or Synth.drumCatalog[1]
end

function Drums:getKitLabel(state)
    return self.KITS[state.kitIndex].name .. (state.kitEdited and "*" or "")
end

function Drums:getActionLabel(state, btn)
    return btn .. " (" .. self:getPadSound(state, btn).short .. ")"
end

-- Picker items for the pad rows: every drum sound, grouped by its category
function Drums:soundItems()
    if not self._soundItems or #self._soundItems ~= #Synth.drumCatalog then
        local items = {}
        for i, s in ipairs(Synth.drumCatalog) do
            items[i] = { label = s.short, group = s.cat, full = (s.full:gsub("^%d+%.%s*", "")) }
        end
        self._soundItems = items
    end
    return self._soundItems
end

function Drums:kitItems()
    if not self._kitItems then
        self._kitItems = {}
        for i, kit in ipairs(self.KITS) do self._kitItems[i] = { label = kit.name } end
    end
    return self._kitItems
end

-- Rows shown on the Track page (UP/DOWN moves the cursor, LEFT/RIGHT changes
-- the row). List rows carry `items` and `index` for the picker; number rows
-- carry `amount` (0..1) for a bar.
function Drums:getSoundRows(state)
    local rows = { { key = "KIT", label = "KIT", value = self:getKitLabel(state),
                     items = self:kitItems(), index = state.kitIndex } }
    for _, pad in ipairs(self.PADS) do
        table.insert(rows, { key = pad, label = pad, value = self:getPadSound(state, pad).short, isPad = true,
                             items = self:soundItems(), index = state.padCatalogIndex[pad] or 1 })
    end
    -- Tune and level of the selected pad: the last pad hit, or whose sound was changed
    local pad = state.lastPad
    local tune = state.padTune[pad] or 0
    local level = state.padLevel[pad] or 1.0
    table.insert(rows, { key = "TUNE", label = "TUNE " .. pad, kind = "setting", hint = "SEMIS",
                         value = (tune > 0 and "+" or "") .. tune,
                         amount = (tune + self.TUNE_RANGE) / (2 * self.TUNE_RANGE) })
    table.insert(rows, { key = "LEVEL", label = "LEVEL " .. pad, kind = "setting", hint = "PAD",
                         value = math_floor(level * 100 + 0.5) .. "%",
                         amount = (level - self.LEVEL_MIN) / (self.LEVEL_MAX - self.LEVEL_MIN) })
    local varItems = {}
    for i, v in ipairs(self.VARIATIONS) do varItems[i] = { label = v } end
    table.insert(rows, { key = "VARIATION", label = "VARIATION", kind = "setting", value = state.variation,
                         items = varItems, index = self:variationIndex(state) })
    return rows
end

function Drums:variationIndex(state)
    for i, v in ipairs(self.VARIATIONS) do
        if v == state.variation then return i end
    end
    return 1
end

function Drums:cycleSetting(state, key, delta)
    local pad = state.lastPad
    if key == "TUNE" then
        state.padTune[pad] = clamp((state.padTune[pad] or 0) + delta, -self.TUNE_RANGE, self.TUNE_RANGE)
        self:preview(state, pad)
        Looper:showToast(string.format("PAD %s TUNE: %+d", pad, state.padTune[pad]))
    elseif key == "LEVEL" then
        local steps = math_floor((state.padLevel[pad] or 1.0) / self.LEVEL_STEP + 0.5) + delta
        state.padLevel[pad] = clamp(steps * self.LEVEL_STEP, self.LEVEL_MIN, self.LEVEL_MAX)
        self:preview(state, pad)
        Looper:showToast(string.format("PAD %s LEVEL: %d%%", pad, math_floor(state.padLevel[pad] * 100 + 0.5)))
    elseif key == "VARIATION" then
        local n = #self.VARIATIONS
        state.variation = self.VARIATIONS[((self:variationIndex(state) - 1 + delta) % n) + 1]
        Looper:showToast("DRUM VARIATION: " .. state.variation)
    end
end

-- Play a pad as it will sound (its tune and level), on no track
function Drums:preview(state, pad)
    Synth:trigger(self:getPadSound(state, pad).id, state.padTune[pad] or 0,
        clamp(0.85 * (state.padLevel[pad] or 1.0), 0.0, 1.0), 1.0)
    state.padFlash[pad] = 1.0
end

function Drums:getDefaultSoundRow(state)
    for i, pad in ipairs(self.PADS) do
        if pad == state.lastPad then return i + 1 end
    end
    return 1
end

-- `quiet` skips the preview (held-direction scrolling previews once it settles)
function Drums:cycleRowSound(state, rowIdx, delta, quiet)
    if rowIdx <= 1 then
        local n = #self.KITS
        self:applyKit(state, ((state.kitIndex - 1 + delta) % n) + 1)
        Looper:showToast("KIT: " .. self.KITS[state.kitIndex].name)
    else
        local pad = self.PADS[rowIdx - 1]
        if not pad then return end
        local total = #Synth.drumCatalog
        local cur = state.padCatalogIndex[pad] or 1
        state.padCatalogIndex[pad] = ((cur - 1 + delta) % total) + 1
        state.kitEdited = true
        state.lastPad = pad
        Looper:showToast("PAD " .. pad .. ": " .. Synth.drumCatalog[state.padCatalogIndex[pad]].full)
    end
    if not quiet then self:previewRowSound(state, rowIdx) end
end

function Drums:previewRowSound(state, rowIdx)
    if rowIdx <= 1 then
        Synth:trigger(self:getPadSound(state, "B").id, 0, 0.9, 1.0)
        return
    end
    local pad = self.PADS[rowIdx - 1]
    if not pad then return end
    Synth:trigger(self:getPadSound(state, pad).id, 0, 0.9, 1.0)
    state.padFlash[pad] = 1.0
end

-- ---------------------------------------------------------------------------
-- Expression (D-pad): vertical = dynamics, horizontal = articulation
-- ---------------------------------------------------------------------------
function Drums:computeExpression(state)
    local u, d, l, r = Input.down.UP, Input.down.DOWN, Input.down.LEFT, Input.down.RIGHT
    local vel, decay, tags = 0.85, 1.0, {}

    if u then
        vel, decay = 1.0, 1.25
        table.insert(tags, "ACCENT")
    elseif d then
        vel, decay = 0.40, 0.65
        table.insert(tags, "GHOST")
    end

    state.orn, state.ratchet = nil, nil
    if l then
        state.orn = "flam"
        table.insert(tags, "FLAM")
    elseif r then
        state.ratchet = self.RATCHET_HITS
        table.insert(tags, "RATCHET")
    end

    state.velocity = vel
    state.decayMod = decay
    state.expressionName = (#tags > 0) and table.concat(tags, " + ") or "NORMAL"
end

function Drums:resetExpression(state)
    state.expressionName = "NORMAL"
    state.velocity = 0.85
    state.decayMod = 1.0
    state.orn, state.ratchet = nil, nil
end

function Drums:updateVisuals(dt, state, controlsBlocked)
    for k, v in pairs(state.padFlash) do
        state.padFlash[k] = math_max(0.0, v - dt * 5.5)
    end
    if controlsBlocked then
        self:resetExpression(state)
    end
end

-- ---------------------------------------------------------------------------
-- Note repeat (grid locked)
-- ---------------------------------------------------------------------------
-- Ticks sit at integer sub-steps; odd ticks are pushed late by `sw` (swing).
local function lastTickAt(u, sw)
    local base = math_floor(u)
    if base % 2 == 1 and (u - base) < sw then
        return base - 1
    end
    return base
end

local function tickTime(i, sw)
    return i + ((i % 2 == 1) and sw or 0.0)
end

function Drums:getRepeatRate(track)
    local l1, r1 = Input.down.L1, Input.down.R1
    if l1 and r1 then
        if Looper:getTrackGrid(track.slot).id == "1/12T" then
            return 12, "1/12T"
        end
        return 16, "1/16"
    elseif l1 then
        return 4, "1/4"
    elseif r1 then
        return 8, "1/8"
    end
    return nil, "OFF"
end

-- A drum hit (event format v2): one-shot, len = 0
function Drums:buildHit(state, track, btn, gridSteps)
    return {
        action = btn,
        soundId = self:getPadSound(state, btn).id,
        vel = state.velocity,
        decay = state.decayMod,
        orn = state.orn,
        ratchet = state.ratchet,
        overrideGridSteps = gridSteps,   -- note repeat snaps to its own rate
        -- a ghost played with variation on comes and goes on playback
        chance = (state.variation ~= "OFF" and state.velocity <= self.GHOST_MAX_VEL) and self.GHOST_CHANCE or nil,
    }
end

-- Was a pad hit this frame / is it held? The face button; an instrument
-- built on Drums may answer differently (other buttons playing the same pads).
function Drums:padPressed(btn)
    return Input.pressed[btn]
end

function Drums:padDown(btn)
    return Input.down[btn]
end

function Drums:updateInput(dt, state, track, emitEvent)
    self:computeExpression(state)

    local stepsPerBar, label = self:getRepeatRate(track)
    state.repeatLabel = label

    if not stepsPerBar or not Looper.playing then
        -- One-shot: every press plays immediately
        state.skipTick, state.pendingTick = {}, {}
        for _, btn in ipairs(self.PADS) do
            if self:padPressed(btn) then
                state.lastPad = btn
                emitEvent(self:buildHit(state, track, btn, stepsPerBar and stepsPerBar * Looper.bars or nil))
            end
        end
        return
    end

    local total = stepsPerBar * Looper.bars
    local sw = Looper:getLiveSwing(track.slot, stepsPerBar)
    local subDur = Looper:getLoopDuration() / total
    local u = Looper.phase * total
    local uPrev = Looper.prevPhase * total
    local tickNow = lastTickAt(u, sw)
    local tickPrev = lastTickAt(uPrev, sw)
    local crossed = (tickNow ~= tickPrev)
    local tickIdx = tickNow % total

    -- New presses: snap to the nearest tick or wait for the next one
    for _, btn in ipairs(self.PADS) do
        if self:padPressed(btn) then
            state.lastPad = btn
            local sinceTick = (u - tickTime(tickNow, sw)) * subDur
            local toNext = (tickTime(tickNow + 1, sw) - u) * subDur
            local nextIdx = (tickNow + 1) % total
            if crossed or sinceTick <= self.REPEAT_SNAP_WINDOW then
                -- Just after a tick: this press is that tick
                state.skipTick[btn] = nil
                emitEvent(self:buildHit(state, track, btn, total))
            elseif toNext <= self.REPEAT_SNAP_WINDOW then
                -- Just before a tick: play now and let the press stand in for it
                state.skipTick[btn] = nextIdx
                emitEvent(self:buildHit(state, track, btn, total))
            else
                -- Far from a tick: start on the next one, even if the pad is let go first
                state.pendingTick[btn] = nextIdx
            end
        end
    end

    if not crossed then return end

    for _, btn in ipairs(self.PADS) do
        local held = self:padDown(btn) and not self:padPressed(btn)
        local pending = (state.pendingTick[btn] == tickIdx)
        if state.skipTick[btn] == tickIdx then
            state.skipTick[btn] = nil
        elseif held or pending then
            emitEvent(self:buildHit(state, track, btn, total))
        end
        if pending then state.pendingTick[btn] = nil end
    end
end

-- ---------------------------------------------------------------------------
-- Sound output
-- ---------------------------------------------------------------------------
function Drums:getRatchetSpan(track)
    -- One 1/16 (or one triplet step on a 1/12T grid) holds the whole burst
    local perBeat = 4.0
    if track and Looper:getTrackGrid(track.slot).id == "1/12T" then perBeat = 3.0 end
    return (60.0 / Looper.bpm) / perBeat
end

-- Every random choice goes through here (tests replace it)
function Drums.random()
    return love.math.random()
end

-- How bright a hit of velocity `vel` is (1 = as generated): a softer stick
-- loses the crack, so quiet hits (ghosts) are darker as well as quieter
-- (PHASE_L L6). Applied as a low-pass on the voice where EFX exists.
function Drums.velTone(vel)
    return clamp(0.22 + 0.78 * (vel - 0.2) / 0.6, 0.22, 1.0)
end

-- One hit, with its pad's tune and level
function Drums:hit(ev, state, track, vel, decay)
    local pad = ev.action
    local tune = state.padTune[pad] or 0
    local level = state.padLevel[pad] or 1.0
    Synth:trigger(ev.soundId, (ev.semis or 0) + tune, clamp(vel * level, 0.0, 1.0), decay, nil, track.volume, track,
        Drums.velTone(vel))
end

-- Does a recorded hit play on this pass? Chance hits are rolled once per
-- pass (the flam's grace note asks first, the main hit reuses the answer).
function Drums:plays(ev, state, consume)
    if state.variation == "OFF" or not ev.chance then return true end
    local r = state.rolled[ev]
    if r == nil then
        r = self.random() <= ev.chance
        state.rolled[ev] = r
    end
    if consume then state.rolled[ev] = nil end
    return r
end

-- Flam grace note on playback (the looper sends it 28 ms before the hit)
function Drums:grace(ev, state, track)
    if not self:plays(ev, state, false) then return end
    self:hit(ev, state, track, (ev.vel or 0.85) * 0.45, (ev.decay or 1.0) * 0.6)
end

function Drums:noteOn(ev, state, track, isPlayback)
    local vel   = ev.vel or 0.85
    local decay = ev.decay or 1.0
    local act   = ev.action

    local mainDelay = 0.0
    if isPlayback then
        if not self:plays(ev, state, true) then return end
        -- Variation: the level moves a little; WILD also drags some off-beat hits
        local jitter = self.VEL_JITTER[state.variation]
        if jitter then
            vel = clamp(vel * (1.0 + (self.random() - 0.5) * 2.0 * jitter), 0.05, 1.0)
            if state.variation == "WILD" and (ev.tick or 0) % Looper.PPQN ~= 0 and self.random() < self.LATE_CHANCE then
                mainDelay = self.random() * self.LATE_MAX
            end
        end
    end

    if ev.orn == "flam" and not isPlayback then
        -- Live flam: grace note now, main hit a moment later
        self:hit(ev, state, track, vel * 0.45, decay * 0.6)
        mainDelay = Looper.FLAM_TIME
        Synth:schedule(mainDelay, function() self:hit(ev, state, track, vel, decay) end)
    elseif mainDelay > 0.0 then
        Synth:schedule(mainDelay, function() self:hit(ev, state, track, vel, decay) end)
    else
        self:hit(ev, state, track, vel, decay)
    end

    local n = ev.ratchet
    if n and n > 1 then
        local span = self:getRatchetSpan(track)
        for i = 1, n - 1 do
            local v = vel * (1.0 - 0.18 * i)
            Synth:schedule(mainDelay + span * i / n, function() self:hit(ev, state, track, v, decay * 0.7) end)
        end
    end

    state.padFlash[act] = clamp(vel, 0.35, 1.0)
    state.padOrn[act] = ev.orn or (n and "ratchet") or nil
end

-- WILD fills: in the last beat of each bar, an empty step may get a ghost
-- hit on one of the pads the pattern uses (not a kick). Played, never recorded.
function Drums:updateVoices(dt, state, track)
    if state.variation ~= "WILD" or not Looper.playing or track.muted or #track.events == 0 then
        state.fillStep = nil
        return
    end
    local grid = Looper:getTrackGrid(track.slot)
    local stepTicks = (grid.id == "1/12T") and 160 or 120
    local step = math_floor(Looper.tick / stepTicks)
    if step == state.fillStep then return end
    state.fillStep = step

    local perBar = (Looper.PPQN * 4) / stepTicks
    if step % perBar < perBar - perBar / 4 then return end          -- only the bar's last beat
    if self.random() >= self.FILL_CHANCE then return end

    local used, pads = {}, {}
    for _, ev in ipairs(track.events) do
        if math_floor(ev.tick / stepTicks + 0.5) == step then return end   -- the step isn't empty
        if not used[ev.action] and not self:getPadSound(state, ev.action).id:find("^kick") then
            used[ev.action] = true
            pads[#pads + 1] = ev.action
        end
    end
    if #pads == 0 then return end
    table.sort(pads)
    local pad = pads[math.min(#pads, math_floor(self.random() * #pads) + 1)]
    local vel = self.FILL_VEL[1] + self.random() * (self.FILL_VEL[2] - self.FILL_VEL[1])
    self:hit({ action = pad, soundId = self:getPadSound(state, pad).id }, state, track, vel, 0.65)
    state.padFlash[pad] = math_max(state.padFlash[pad] or 0, 0.5)
    state.lastFill = { pad = pad, step = step }
end

-- ---------------------------------------------------------------------------
-- Save / load (Phase C): pad sounds are saved by sound id, not catalogue
-- position, so adding sounds later doesn't reshuffle a saved kit
-- ---------------------------------------------------------------------------
function Drums:saveState(state)
    local pads = {}
    for _, pad in ipairs(self.PADS) do pads[pad] = self:getPadSound(state, pad).id end
    local tune, level = {}, {}
    for _, pad in ipairs(self.PADS) do
        tune[pad], level[pad] = state.padTune[pad], state.padLevel[pad]
    end
    return { kit = state.kitIndex, kitEdited = state.kitEdited, lastPad = state.lastPad, pads = pads,
             variation = state.variation, tune = tune, level = level }
end

function Drums:loadState(state, data)
    if type(data) ~= "table" then return end
    local kit = tonumber(data.kit)
    if kit and self.KITS[kit] then self:applyKit(state, kit) end
    if type(data.pads) == "table" then
        for _, pad in ipairs(self.PADS) do
            local id = data.pads[pad]
            for i, item in ipairs(Synth.drumCatalog) do
                if item.id == id then state.padCatalogIndex[pad] = i break end
            end
        end
    end
    state.kitEdited = (data.kitEdited == true)
    for _, pad in ipairs(self.PADS) do
        if data.lastPad == pad then state.lastPad = pad end
        local t = type(data.tune) == "table" and data.tune[pad]
        if type(t) == "number" and t == t then
            state.padTune[pad] = clamp(math_floor(t + 0.5), -self.TUNE_RANGE, self.TUNE_RANGE)
        end
        local l = type(data.level) == "table" and data.level[pad]
        if type(l) == "number" and l == l then
            state.padLevel[pad] = clamp(l, self.LEVEL_MIN, self.LEVEL_MAX)
        end
    end
    for _, v in ipairs(self.VARIATIONS) do
        if data.variation == v then state.variation = v end
    end
end

return Drums
