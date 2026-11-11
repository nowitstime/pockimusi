-- ============================================================================
-- src/instruments/drums.lua — 4-Pad Drum Kit
--   Face buttons  = pads (X top, Y left, A right, B bottom)
--   D-pad ↑ / ↓   = dynamics: ACCENT / GHOST
--   D-pad ← / →   = articulation: FLAM / RATCHET (diagonals combine both axes)
--   L1 / R1 / both = grid-locked note repeat at 1/4, 1/8, 1/16 (1/12T on triplet grid)
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
    name = "DRUMS",
    shortName = "DRUM",
    title = "DRUM MACHINE",
    defaultGridIndex = 3, -- 1/16

    PADS = { "X", "Y", "A", "B" },   -- display order: matches the button diamond top -> bottom
    RATCHET_HITS = 3,
    REPEAT_SNAP_WINDOW = 0.045,      -- seconds: a press this close to a repeat tick counts as that tick

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

-- Rows shown on the Track page (UP/DOWN moves the cursor, L1/R1 changes the row's sound)
function Drums:getSoundRows(state)
    local rows = { { key = "KIT", label = "KIT", value = self:getKitLabel(state),
                     hint = string.format("%d/%d", state.kitIndex, #self.KITS) } }
    for _, pad in ipairs(self.PADS) do
        table.insert(rows, { key = pad, label = pad, value = self:getPadSound(state, pad).short, isPad = true })
    end
    return rows
end

function Drums:getDefaultSoundRow(state)
    for i, pad in ipairs(self.PADS) do
        if pad == state.lastPad then return i + 1 end
    end
    return 1
end

function Drums:cycleRowSound(state, rowIdx, delta)
    if rowIdx <= 1 then
        local n = #self.KITS
        self:applyKit(state, ((state.kitIndex - 1 + delta) % n) + 1)
        Synth:trigger(self:getPadSound(state, "B").id, 0, 0.9, 1.0)
        Looper:showToast("KIT: " .. self.KITS[state.kitIndex].name)
        return
    end
    local pad = self.PADS[rowIdx - 1]
    if not pad then return end
    local total = #Synth.drumCatalog
    local cur = state.padCatalogIndex[pad] or 1
    state.padCatalogIndex[pad] = ((cur - 1 + delta) % total) + 1
    state.kitEdited = true
    state.lastPad = pad
    local item = Synth.drumCatalog[state.padCatalogIndex[pad]]
    Synth:trigger(item.id, 0, 0.9, 1.0)
    state.padFlash[pad] = 1.0
    Looper:showToast("PAD " .. pad .. ": " .. item.full)
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

function Drums:buildHit(state, track, btn, gridSteps)
    return {
        trackSlot = track.slot,
        instrumentId = self.id,
        action = btn,
        soundId = self:getPadSound(state, btn).id,
        pitchSemis = 0,
        velocity = state.velocity,
        decayMod = state.decayMod,
        orn = state.orn,
        ratchet = state.ratchet,
        overrideGridSteps = gridSteps,
    }
end

function Drums:updateInput(dt, state, track, emitEvent)
    self:computeExpression(state)

    local stepsPerBar, label = self:getRepeatRate(track)
    state.repeatLabel = label

    if not stepsPerBar or not Looper.playing then
        -- One-shot: every press plays immediately
        state.skipTick, state.pendingTick = {}, {}
        for _, btn in ipairs(self.PADS) do
            if Input.pressed[btn] then
                state.lastPad = btn
                emitEvent(self:buildHit(state, track, btn, stepsPerBar and stepsPerBar * Looper.bars or nil), false)
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
        if Input.pressed[btn] then
            state.lastPad = btn
            local sinceTick = (u - tickTime(tickNow, sw)) * subDur
            local toNext = (tickTime(tickNow + 1, sw) - u) * subDur
            local nextIdx = (tickNow + 1) % total
            if crossed or sinceTick <= self.REPEAT_SNAP_WINDOW then
                -- Just after a tick: this press is that tick
                state.skipTick[btn] = nil
                emitEvent(self:buildHit(state, track, btn, total), false)
            elseif toNext <= self.REPEAT_SNAP_WINDOW then
                -- Just before a tick: play now and let the press stand in for it
                state.skipTick[btn] = nextIdx
                emitEvent(self:buildHit(state, track, btn, total), false)
            else
                -- Far from a tick: start on the next one, even if the pad is let go first
                state.pendingTick[btn] = nextIdx
            end
        end
    end

    if not crossed then return end

    for _, btn in ipairs(self.PADS) do
        local held = Input.down[btn] and not Input.pressed[btn]
        local pending = (state.pendingTick[btn] == tickIdx)
        if state.skipTick[btn] == tickIdx then
            state.skipTick[btn] = nil
        elseif held or pending then
            emitEvent(self:buildHit(state, track, btn, total), false)
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

function Drums:triggerEvent(ev, state, isPlayback, part)
    local act     = ev.action
    local semis   = ev.pitchSemis or 0
    local decay   = ev.decayMod or 1.0
    local vel     = ev.velocity or 0.85
    local soundId = ev.soundId or self:getPadSound(state, act).id
    local track   = Looper.tracks[ev.trackSlot or Looper.activeTrack]
    local trkVol  = track and track.volume or 1.0

    local function hit(v, d)
        Synth:trigger(soundId, semis, v, d, nil, trkVol)
    end

    if part == "grace" then
        hit(vel * 0.45, decay * 0.6)
        return
    end

    local mainDelay = 0.0
    if ev.orn == "flam" and not isPlayback then
        -- Live flam: grace note now, main hit a moment later
        hit(vel * 0.45, decay * 0.6)
        mainDelay = Looper.FLAM_TIME
        Synth:schedule(mainDelay, function() hit(vel, decay) end)
    else
        hit(vel, decay)
    end

    local n = ev.ratchet
    if n and n > 1 then
        local span = self:getRatchetSpan(track)
        for i = 1, n - 1 do
            local v = vel * (1.0 - 0.18 * i)
            Synth:schedule(mainDelay + span * i / n, function() hit(v, decay * 0.7) end)
        end
    end

    state.padFlash[act] = clamp(vel, 0.35, 1.0)
    state.padOrn[act] = ev.orn or (n and "ratchet") or nil
end

return Drums
