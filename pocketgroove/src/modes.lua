-- ============================================================================
-- src/modes.lua — Global modes and modifier combos (SPEC §3.4–3.6)
--
-- Each frame: record latch (L2) → resolve the mode → run that mode's handler
-- → taps (SELECT, START) and always-on combos. Returns whether the active
-- instrument should ignore the controls this frame.
-- ============================================================================

local Config      = require("src.config")
local Theory      = require("src.theory")
local Input       = require("src.input")
local Synth       = require("src.synth")
local Looper      = require("src.looper")
local Instruments = require("src.instruments")

local clamp = Config.clamp

local Modes = {
    -- NORMAL, REC_LATCH, REC_HOLD, ERASE, MIX, TRACK, TRANSPORT, FX
    current  = "NORMAL",
    previous = "NORMAL",

    -- Page state (read by Chrome)
    trackPage = { row = 1, fxHeld = nil, fxAdjusted = false },
    mixTrack  = 1,                       -- 1..4 = track, 5 = master

    -- Timings (seconds)
    TAP_MAX       = 0.25,                -- shorter than this = a tap
    TRACK_HOLD    = 0.18,                -- SELECT held this long opens the Track page
    TRANSPORT_HOLD = 0.22,               -- START held this long opens Transport
    DOUBLE_TAP    = 0.32,                -- two START taps within this = reset playhead
}

local FACE = { "B", "A", "Y", "X" }
local MUTE_BUTTON = { B = 1, A = 2, Y = 3, X = 4 }

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
local function setLiveFx(stutter, half, duck, crush)
    Synth.fxBeatRepeat = stutter
    Synth.fxHalfSpeed  = half
    Synth.fxLowPass    = duck
    Synth.fxBitcrush   = crush
end

local function face_mutes()
    for btn, slot in pairs(MUTE_BUTTON) do
        if Input.pressed[btn] then Looper:toggleMute(slot) end
    end
end

local function setMaster(v)
    Synth.masterVolume = clamp(v, 0.0, 1.0)
end

-- ---------------------------------------------------------------------------
-- Record: tap L2 = latch on/off, hold L2 = record while held (SPEC §4)
-- ---------------------------------------------------------------------------
local function updateRecord()
    if Input.pressed.L2 then
        Looper:beginRecordingTake()
    end
    if not Input.released.L2 then return end

    local used = Input.comboUsed.L2
    if not used and Input.l2HoldTime < Modes.TAP_MAX then
        Input.recLatched = not Input.recLatched
        Looper:showToast(Input.recLatched and "[REC] RECORD LATCHED (TAP L2 TO STOP)" or "RECORD STOPPED")
    elseif Input.recLatched and Input.l2HoldTime >= Modes.TAP_MAX then
        -- Releasing a held punch-in also clears the latch
        Input.recLatched = false
        Looper:showToast("PUNCH-IN COMPLETE")
    end
end

-- ---------------------------------------------------------------------------
-- Mode resolution (strict priority)
-- ---------------------------------------------------------------------------
function Modes:resolve()
    local d = Input.down
    if d.L2 and d.R2 then return "ERASE" end
    if d.SELECT and d.R2 then return "MIX" end
    if d.SELECT and Input.selectHoldTime >= self.TRACK_HOLD then return "TRACK" end
    if d.START and Input.startHoldTime >= self.TRANSPORT_HOLD then return "TRANSPORT" end
    if d.R2 then return "FX" end
    if d.L2 and not Input.comboUsed.L2 then return "REC_HOLD" end
    if Input.recLatched then return "REC_LATCH" end
    return "NORMAL"
end

-- ---------------------------------------------------------------------------
-- Mode handlers: each returns true when it owns the frame (no taps, no
-- always-on combos, instrument blocked).
-- ---------------------------------------------------------------------------
local handlers = {}

-- L2 + R2: erase a pad, undo a take, clear the track
function handlers.ERASE(ctx)
    Input.comboUsed.L2, Input.comboUsed.R2 = true, true
    local tIdx = Looper.activeTrack
    for _, btn in ipairs(FACE) do
        if Input.pressed[btn] then
            local label = ctx.def.getActionLabel and ctx.def:getActionLabel(ctx.state, btn) or btn
            Looper:clearTrackAction(tIdx, btn, label)
        end
    end
    if Input.pressed.LEFT or Input.pressed.L1 then
        Looper:undoLastTake()
    end
    if Input.pressed.START then
        Looper:clearTrack(tIdx)
        Input.comboUsed.START = true
    end
    return true
end

-- SELECT + R2: mix page
function handlers.MIX()
    Input.comboUsed.SELECT, Input.comboUsed.R2 = true, true

    if Input.pressed.LEFT then
        Modes.mixTrack = ((Modes.mixTrack - 2) % 5) + 1
    elseif Input.pressed.RIGHT then
        Modes.mixTrack = (Modes.mixTrack % 5) + 1
    end

    local step = (Input.repeated.UP and 0.08) or (Input.repeated.DOWN and -0.08) or 0
    if step ~= 0 then
        if Modes.mixTrack <= 4 then
            local trk = Looper.tracks[Modes.mixTrack]
            trk.volume = clamp(trk.volume + step, 0.0, 1.0)
        else
            setMaster(Synth.masterVolume + step)
        end
    end

    face_mutes()

    local trim = (Input.pressed.L1 and -0.1) or (Input.pressed.R1 and 0.1) or nil
    if trim then
        setMaster(Synth.masterVolume + trim)
        Looper:showToast(string.format("MASTER VOL: %d%%", math.floor(Synth.masterVolume * 100)))
    end
    return true
end

-- Hold SELECT: Track page = sound (rows, instrument, effects)
function handlers.TRACK(ctx)
    Input.comboUsed.SELECT = true
    local page = Modes.trackPage
    local def, state = ctx.def, ctx.state
    local rows = Instruments:getSoundRows(def, state)

    if Modes.previous ~= "TRACK" then
        page.row = (def.getDefaultSoundRow and def:getDefaultSoundRow(state)) or 1
        page.fxHeld, page.fxAdjusted = nil, false
    end
    page.row = clamp(page.row, 1, #rows)

    -- Instrument
    if Input.pressed.LEFT or Input.pressed.RIGHT then
        Instruments:cycleTrackInstrument(Looper.activeTrack, Input.pressed.LEFT and -1 or 1)
        page.row = 1
    end

    -- Effects on the face buttons: tap = on/off, hold + UP/DOWN = amount
    for _, btn in ipairs({ "X", "Y", "A", "B" }) do
        if Input.pressed[btn] then
            page.fxHeld, page.fxAdjusted = btn, false
        end
    end
    local heldSlot = page.fxHeld and Looper.FX_SLOTS[page.fxHeld]
    if heldSlot and Input.down[page.fxHeld] then
        if Input.pressed.UP or Input.pressed.DOWN then
            Looper:adjustTrackFx(Looper.activeTrack, heldSlot, Input.pressed.UP and 0.1 or -0.1)
            page.fxAdjusted = true
        end
    elseif Input.pressed.UP then
        page.row = ((page.row - 2) % #rows) + 1
    elseif Input.pressed.DOWN then
        page.row = (page.row % #rows) + 1
    end
    if page.fxHeld and Input.released[page.fxHeld] then
        if not page.fxAdjusted then
            Looper:toggleTrackFx(Looper.activeTrack, Looper.FX_SLOTS[page.fxHeld])
        end
        page.fxHeld = nil
    end

    -- L1 / R1: previous / next sound for the selected row
    local delta = (Input.pressed.L1 and -1) or (Input.pressed.R1 and 1) or nil
    if delta then
        if def.cycleRowSound then
            def:cycleRowSound(state, page.row, delta)
        else
            Looper:showToast(def.name .. ": ONE PATCH FOR NOW")
        end
    end
    return true
end

-- Hold START: Transport = timing. A SELECT tap still changes track here, so
-- grid and swing can be set for each track without leaving the page.
local updateSelectTap
function handlers.TRANSPORT()
    Input.comboUsed.START = true
    updateSelectTap()
    local tIdx = Looper.activeTrack

    if Input.down.Y then
        if Input.pressed.UP then
            Looper:adjustSwing(tIdx, 0.02)
        elseif Input.pressed.DOWN then
            Looper:adjustSwing(tIdx, -0.02)
        end
    elseif Input.pressed.UP or Input.pressed.DOWN then
        Looper.bpm = clamp(Looper.bpm + (Input.pressed.UP and 5 or -5), Config.MIN_BPM, Config.MAX_BPM)
        Looper:showToast("TEMPO: " .. Looper.bpm .. " BPM")
    end

    if Input.pressed.LEFT or Input.pressed.RIGHT then
        Theory:cycleRoot(Input.pressed.RIGHT and 1 or -1)
        Looper:showToast("KEY: " .. Theory:getKeyLabel())
    end

    if Input.pressed.L1 or Input.pressed.R1 then
        Theory:cycleScale(Input.pressed.R1 and 1 or -1)
        Looper:showToast("SCALE: " .. Theory.SCALES[Theory.scaleIndex].fullName)
    end

    if Input.pressed.B then Looper:toggleBars() end
    if Input.pressed.A then Looper:cycleGridMode(tIdx) end
    if Input.pressed.X then
        Looper.clickOn = not Looper.clickOn
        Looper:showToast(Looper.clickOn and "CLICK: ON" or "CLICK: OFF")
    end
    return true
end

-- Hold R2: face = mutes, D-pad = live FX. The instrument is blocked, but taps
-- and the L2 + START clear still apply.
function handlers.FX()
    face_mutes()
    setLiveFx(Input.down.UP, Input.down.DOWN, Input.down.LEFT, Input.down.RIGHT)
    return false
end

-- ---------------------------------------------------------------------------
-- Taps and always-on combos (only when no page owns the frame)
-- ---------------------------------------------------------------------------
function updateSelectTap()
    if not Input.released.SELECT then return end
    if not Input.comboUsed.SELECT and not Input.comboUsed.L2 and Input.selectHoldTime < Modes.TAP_MAX then
        Looper.activeTrack = (Looper.activeTrack % 4) + 1
        local nextTrack = Looper.tracks[Looper.activeTrack]
        Looper:showToast(string.format("TRACK %d: %s", Looper.activeTrack, nextTrack and nextTrack.name or ""))
    end
end

local function updateStartTap()
    if not (Input.released.START and not Input.comboUsed.START and not Input.down.L2
            and not Input.down.SELECT and Input.startHoldTime < Modes.TAP_MAX) then
        return
    end
    local now = love.timer.getTime()
    if (now - Input.lastStartTapTime) < Modes.DOUBLE_TAP then
        Looper.phase = 0.0
        Looper.prevPhase = 1.0 - 0.0001
        Looper.playing = true
        Looper:showToast("PLAYHEAD RESET TO BAR 1.1")
    else
        Looper.playing = not Looper.playing
        Looper:showToast(Looper.playing and "CLOCK: PLAYING" or "CLOCK: PAUSED (2x TAP = RESET)")
    end
    Input.lastStartTapTime = now
end

-- L2 + START: clear the active track
local function updateClearCombo()
    if Input.down.L2 and Input.pressed.START then
        Looper:clearTrack(Looper.activeTrack)
        Input.comboUsed.L2, Input.comboUsed.START = true, true
        return true
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Frame entry point
-- ---------------------------------------------------------------------------
function Modes:update()
    updateRecord()

    self.previous = self.current
    self.current = self:resolve()

    if self.current ~= "FX" then
        setLiveFx(false, false, false, false)
    end

    local def, state = Instruments:getTrackInstrument(Looper.activeTrack)
    local handler = handlers[self.current]
    local blocked = false
    if handler then
        blocked = true
        if handler({ def = def, state = state }) then
            Input:clearReleasedCombos()
            return true
        end
    end

    updateSelectTap()
    updateStartTap()
    if updateClearCombo() then blocked = true end

    Input:clearReleasedCombos()
    return blocked
end

return Modes
