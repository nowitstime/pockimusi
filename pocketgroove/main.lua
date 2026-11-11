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
    Looper.prevUiMode = Looper.uiMode
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
            Input.startComboUsed = true
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
            if Input.repeated.UP then
                trk.volume = clamp(trk.volume + step, 0.0, 1.0)
            elseif Input.repeated.DOWN then
                trk.volume = clamp(trk.volume - step, 0.0, 1.0)
            end
        else
            if Input.repeated.UP then
                Synth.masterVolume = clamp(Synth.masterVolume + step, 0.0, 1.0)
            elseif Input.repeated.DOWN then
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
    -- 5. TRACK PAGE (SOUND): SELECT Held Alone (>= 0.18s)
    --    UP/DOWN row · L1/R1 row sound · LEFT/RIGHT instrument
    --    Face tap = effect on/off · hold face + UP/DOWN = effect amount
    -- ------------------------------------------------------------------------
    if mode == "TRACK" then
        controlsBlocked = true
        Input.selectComboUsed = true
        local page = Looper.trackPage
        local rows = Instruments:getSoundRows(activeDef, activeState)

        if Looper.prevUiMode ~= "TRACK" then
            page.row = (activeDef.getDefaultSoundRow and activeDef:getDefaultSoundRow(activeState)) or 1
            page.fxHeld, page.fxAdjusted = nil, false
        end
        page.row = clamp(page.row, 1, #rows)

        if Input.pressed.LEFT then
            Instruments:cycleTrackInstrument(Looper.activeTrack, -1)
            page.row = 1
        elseif Input.pressed.RIGHT then
            Instruments:cycleTrackInstrument(Looper.activeTrack, 1)
            page.row = 1
        end

        -- Effects on the face buttons
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
        else
            if Input.pressed.UP then
                page.row = ((page.row - 2) % #rows) + 1
            elseif Input.pressed.DOWN then
                page.row = (page.row % #rows) + 1
            end
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
            if activeDef.cycleRowSound then
                activeDef:cycleRowSound(activeState, page.row, delta)
            else
                Looper:showToast(activeDef.name .. ": ONE PATCH FOR NOW")
            end
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
    -- 6. TRANSPORT PAGE (TIMING): START Held Alone (>= 0.22s)
    --    UP/DOWN BPM · LEFT/RIGHT key · L1/R1 scale · B bars · A grid
    --    Y + UP/DOWN swing · X click
    -- ------------------------------------------------------------------------
    if mode == "TRANSPORT" then
        controlsBlocked = true
        Input.startComboUsed = true
        local tIdx = Looper.activeTrack

        if Input.down.Y then
            if Input.pressed.UP then
                Looper:adjustSwing(tIdx, 0.02)
            elseif Input.pressed.DOWN then
                Looper:adjustSwing(tIdx, -0.02)
            end
        elseif Input.pressed.UP then
            Looper.bpm = clamp(Looper.bpm + 5, Config.MIN_BPM, Config.MAX_BPM)
            Looper:showToast("TEMPO: " .. Looper.bpm .. " BPM")
        elseif Input.pressed.DOWN then
            Looper.bpm = clamp(Looper.bpm - 5, Config.MIN_BPM, Config.MAX_BPM)
            Looper:showToast("TEMPO: " .. Looper.bpm .. " BPM")
        end

        if Input.pressed.RIGHT then
            Theory:cycleRoot(1)
            Looper:showToast("KEY: " .. Theory:getKeyLabel())
        elseif Input.pressed.LEFT then
            Theory:cycleRoot(-1)
            Looper:showToast("KEY: " .. Theory:getKeyLabel())
        end

        if Input.pressed.R1 then
            Theory:cycleScale(1)
            Looper:showToast("SCALE: " .. Theory.SCALES[Theory.scaleIndex].fullName)
        elseif Input.pressed.L1 then
            Theory:cycleScale(-1)
            Looper:showToast("SCALE: " .. Theory.SCALES[Theory.scaleIndex].fullName)
        end

        if Input.pressed.B then Looper:toggleBars() end
        if Input.pressed.A then Looper:cycleGridMode(tIdx) end
        if Input.pressed.X then
            Looper.clickOn = not Looper.clickOn
            Looper:showToast(Looper.clickOn and "CLICK: ON" or "CLICK: OFF")
        end

        return controlsBlocked
    end

    -- Tap START (< 0.25s): Play / Pause, 2x tap = reset playhead
    if Input.released.START and not Input.startComboUsed and not Input.down.L2 and not Input.down.SELECT and Input.startHoldTime < 0.25 then
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
            Input.startComboUsed = true
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

    Looper:update(dt, function(ev, track, isPlayback, part)
        Instruments:triggerEvent(ev, track, isPlayback, part)
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
