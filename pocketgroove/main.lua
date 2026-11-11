-- ============================================================================
-- PocketGroove — 4-Track Procedural Handheld Groovebox
-- Target Hardware: Anbernic RG35XX Plus (640x480 4:3 IPS) & Desktop PC
-- Engine: LÖVE (Love2D 11.x) — Modular Pluggable Track/Instrument Architecture
-- ============================================================================

local Config      = require("src.config")
local Theory      = require("src.theory")
local Input       = require("src.input")
local Synth       = require("src.synth")
local Looper      = require("src.looper")
local Instruments = require("src.instruments")
local Chrome      = require("src.ui.chrome")

local clamp    = Config.clamp
local math_min = math.min

-- ============================================================================
-- GLOBAL TRANSPORT & MODIFIER COMBO HANDLER
-- ============================================================================

local function handleGlobalCombos()
    local controlsBlocked = false
    local activeDef, activeState, activeTrack = Instruments:getTrackInstrument(Looper.activeTrack)

    -- ------------------------------------------------------------------------
    -- 1. Hybrid L2 Record (Tap to Latch, Hold for Momentary Punch-In)
    -- ------------------------------------------------------------------------
    if Input.pressed.L2 then
        Looper:beginRecordingTake()
    end

    if Input.released.L2 then
        if not Input.l2ComboUsed and Input.l2HoldTime < 0.25 then
            Input.recLatched = not Input.recLatched
            if Input.recLatched then
                Looper:showToast("[REC] RECORD LATCHED (TAP L2 TO STOP)")
            else
                Looper:showToast("RECORD STOPPED")
            end
        elseif Input.recLatched and Input.l2HoldTime >= 0.25 then
            -- Releasing a held punch-in also clears latch
            Input.recLatched = false
            Looper:showToast("PUNCH-IN COMPLETE")
        end
        Input.l2ComboUsed = false
    end

    -- ------------------------------------------------------------------------
    -- 2. Determine Explicit Global UI Mode (Strict Priority)
    -- ------------------------------------------------------------------------
    local mode = "NORMAL"
    if Input.down.L2 and Input.down.R2 then
        mode = "ERASE"
    elseif Input.down.SELECT and Input.down.R2 then
        mode = "MIX"
    elseif Input.down.SELECT and Input.selectHoldTime >= 0.18 then
        mode = "TRACK"
    elseif Input.down.START and Input.startHoldTime >= 0.22 then
        mode = "TRANSPORT"
    elseif Input.down.R2 then
        mode = "FX"
    elseif Input.down.L2 and not Input.down.R2 and not Input.l2ComboUsed then
        mode = "REC_HOLD"
    elseif Input.recLatched then
        mode = "REC_LATCH"
    end
    Looper.uiMode = mode

    -- ------------------------------------------------------------------------
    -- 3. ERASE MODE: L2 + R2 Held Together
    -- ------------------------------------------------------------------------
    if mode == "ERASE" then
        controlsBlocked = true
        Input.l2ComboUsed = true
        Input.r2ComboUsed = true

        local tIdx = Looper.activeTrack
        for _, btn in ipairs({ "B", "Y", "A", "X" }) do
            if Input.pressed[btn] then
                local label = (activeDef and activeDef.getActionLabel)
                    and activeDef:getActionLabel(activeState, btn)
                    or btn
                Looper:clearTrackAction(tIdx, btn, label)
            end
        end

        if Input.pressed.LEFT or Input.pressed.L1 then
            Looper:undoLastTake()
        end

        if Input.pressed.START then
            Looper:clearTrack(tIdx)
        end

        Synth.fxBeatRepeat = false
        Synth.fxHalfSpeed  = false
        Synth.fxLowPass    = false
        Synth.fxBitcrush   = false
        return controlsBlocked
    end

    -- ------------------------------------------------------------------------
    -- 4. MIX MODE: SELECT + R2 Held Together
    -- ------------------------------------------------------------------------
    if mode == "MIX" then
        controlsBlocked = true
        Input.selectComboUsed = true
        Input.r2ComboUsed = true

        if Input.pressed.LEFT then
            Looper.mixTrack = ((Looper.mixTrack - 2 + 5) % 5) + 1
        elseif Input.pressed.RIGHT then
            Looper.mixTrack = (Looper.mixTrack % 5) + 1
        end

        local step = 0.08
        if Looper.mixTrack <= 4 then
            local trk = Looper.tracks[Looper.mixTrack]
            if Input.pressed.UP or Input.down.UP then
                trk.volume = clamp(trk.volume + step, 0.0, 1.0)
            elseif Input.pressed.DOWN or Input.down.DOWN then
                trk.volume = clamp(trk.volume - step, 0.0, 1.0)
            end
        else
            if Input.pressed.UP or Input.down.UP then
                Synth.masterVolume = clamp(Synth.masterVolume + step, 0.0, 1.0)
            elseif Input.pressed.DOWN or Input.down.DOWN then
                Synth.masterVolume = clamp(Synth.masterVolume - step, 0.0, 1.0)
            end
        end

        -- Mute toggles in mixer
        if Input.pressed.B then Looper:toggleMute(1) end
        if Input.pressed.A then Looper:toggleMute(2) end
        if Input.pressed.Y then Looper:toggleMute(3) end
        if Input.pressed.X then Looper:toggleMute(4) end

        -- L1 / R1 master volume quick trim
        if Input.pressed.L1 then
            Synth.masterVolume = clamp(Synth.masterVolume - 0.1, 0.0, 1.0)
            Looper:showToast(string.format("MASTER VOL: %d%%", math.floor(Synth.masterVolume * 100)))
        elseif Input.pressed.R1 then
            Synth.masterVolume = clamp(Synth.masterVolume + 0.1, 0.0, 1.0)
            Looper:showToast(string.format("MASTER VOL: %d%%", math.floor(Synth.masterVolume * 100)))
        end

        return controlsBlocked
    end

    -- ------------------------------------------------------------------------
    -- 5. TRACK PAGE: SELECT Held Alone (>= 0.18s)
    -- ------------------------------------------------------------------------
    if mode == "TRACK" then
        controlsBlocked = true
        Input.selectComboUsed = true

        if Input.pressed.LEFT then
            Instruments:cycleTrackInstrument(Looper.activeTrack, -1)
        elseif Input.pressed.RIGHT then
            Instruments:cycleTrackInstrument(Looper.activeTrack, 1)
        end

        if Input.pressed.UP then
            Looper:cycleGridMode(Looper.activeTrack)
        elseif Input.pressed.DOWN then
            Looper:cycleGridMode(Looper.activeTrack)
        end

        -- Delegate instrument-specific sound selection (e.g. Drums / Bass / Grain)
        if activeDef and activeDef.handleSelectCombo then
            activeDef:handleSelectCombo(activeState, activeTrack)
        end

        return controlsBlocked
    end

    -- Quick tap of SELECT (< 0.25s) switches track slot 1->2->3->4
    if Input.released.SELECT then
        if not Input.selectComboUsed and not Input.l2ComboUsed and Input.selectHoldTime < 0.25 then
            Looper.activeTrack = (Looper.activeTrack % 4) + 1
            local nextTrack = Looper.tracks[Looper.activeTrack]
            Looper:showToast(string.format("TRACK %d: %s", Looper.activeTrack, nextTrack and nextTrack.name or ""))
        end
        Input.selectComboUsed = false
    end

    -- ------------------------------------------------------------------------
    -- 6. TRANSPORT PAGE: START Held Alone (>= 0.22s)
    -- ------------------------------------------------------------------------
    if mode == "TRANSPORT" then
        controlsBlocked = true

        if Input.pressed.UP then
            Looper.bpm = clamp(Looper.bpm + 5, Config.MIN_BPM, Config.MAX_BPM)
            Looper:showToast("TEMPO: " .. Looper.bpm .. " BPM")
        elseif Input.pressed.DOWN then
            Looper.bpm = clamp(Looper.bpm - 5, Config.MIN_BPM, Config.MAX_BPM)
            Looper:showToast("TEMPO: " .. Looper.bpm .. " BPM")
        elseif Input.pressed.RIGHT then
            Theory:cycleRoot(1)
            Looper:showToast("KEY: " .. Theory:getKeyLabel())
        elseif Input.pressed.LEFT then
            Theory:cycleScale(1)
            Looper:showToast("SCALE: " .. Theory.SCALES[Theory.scaleIndex].fullName)
        elseif Input.pressed.B then
            Looper:toggleBars()
        end

        return controlsBlocked
    end

    -- Tap START (< 0.25s): Play / Pause, 2x tap = reset playhead
    if Input.released.START and not Input.down.L2 and not Input.down.SELECT and Input.startHoldTime < 0.25 then
        local now = love.timer.getTime()
        if (now - Input.lastStartTapTime) < 0.32 then
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

    -- ------------------------------------------------------------------------
    -- 7. FX / MUTE MODE: R2 Held Alone
    -- ------------------------------------------------------------------------
    if mode == "FX" then
        controlsBlocked = true
        if Input.pressed.B then Looper:toggleMute(1) end
        if Input.pressed.A then Looper:toggleMute(2) end
        if Input.pressed.Y then Looper:toggleMute(3) end
        if Input.pressed.X then Looper:toggleMute(4) end

        Synth.fxBeatRepeat = Input.down.UP
        Synth.fxHalfSpeed  = Input.down.DOWN
        Synth.fxLowPass    = Input.down.LEFT
        Synth.fxBitcrush   = Input.down.RIGHT
    else
        Input.r2ComboUsed = false
        Synth.fxBeatRepeat = false
        Synth.fxHalfSpeed  = false
        Synth.fxLowPass    = false
        Synth.fxBitcrush   = false
    end

    -- ------------------------------------------------------------------------
    -- 8. L2 Record Combos while Recording: L2 + START (Clear Track)
    -- ------------------------------------------------------------------------
    if Input.down.L2 then
        if Input.pressed.START then
            Looper:clearTrack(Looper.activeTrack)
            Input.l2ComboUsed = true
            controlsBlocked = true
        end
    end

    return controlsBlocked
end

-- ============================================================================
-- LÖVE (LOVE2D) LIFECYCLE CALLBACKS
-- ============================================================================

function love.load()
    love.window.setTitle("PocketGroove - 4-Track Handheld Groovebox")
    Synth:init()
    Looper:init(Instruments)
    Chrome:init()
end

function love.update(dt)
    dt = math_min(dt, 0.05)

    Input:update(dt)
    local controlsBlocked = handleGlobalCombos()

    Looper:update(dt, function(ev, track, isPlayback)
        Instruments:triggerEvent(ev, track, isPlayback)
    end)

    Instruments:update(dt, controlsBlocked)
    Synth:update(dt)
end

function love.draw()
    Chrome:draw()
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
end
