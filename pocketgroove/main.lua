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

    -- Begin a new Take ID whenever L2 is freshly pressed
    if Input.pressed.L2 then
        Looper:beginRecordingTake()
    end

    -- 1. L2 + R2 HELD TOGETHER = PER-PAD ERASE & UNDO MODE
    if Input.down.L2 and Input.down.R2 then
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

    -- 2. SELECT HELD = CONFIGURE, BPM, KEY/SCALE, 2/4 BARS, & INSTRUMENT SOUND PICKER
    if Input.down.SELECT then
        controlsBlocked = true
        if not Input.down.L2 then
            if Input.pressed.UP then
                Looper.bpm = clamp(Looper.bpm + 5, Config.MIN_BPM, Config.MAX_BPM)
                Looper:showToast("MASTER BPM: " .. Looper.bpm)
                Input.selectComboUsed = true
            elseif Input.pressed.DOWN then
                Looper.bpm = clamp(Looper.bpm - 5, Config.MIN_BPM, Config.MAX_BPM)
                Looper:showToast("MASTER BPM: " .. Looper.bpm)
                Input.selectComboUsed = true
            elseif Input.pressed.RIGHT then
                Theory:cycleRoot(1)
                Looper:showToast("KEY: " .. Theory:getKeyLabel())
                Input.selectComboUsed = true
            elseif Input.pressed.LEFT then
                Theory:cycleScale(1)
                Looper:showToast("SCALE: " .. Theory.SCALES[Theory.scaleIndex].fullName .. " (" .. Theory:getKeyLabel() .. ")")
                Input.selectComboUsed = true
            elseif Input.pressed.START then
                Looper:toggleBars()
                Input.selectComboUsed = true
            end

            -- Delegate instrument-specific SELECT combos (e.g. Drum Pad Sound Browser)
            if activeDef and activeDef.handleSelectCombo then
                if activeDef:handleSelectCombo(activeState, activeTrack) then
                    Input.selectComboUsed = true
                end
            end
        end
    end

    -- Only switch tracks on a QUICK TAP of SELECT (< 0.28s), not when held to read hints!
    if Input.released.SELECT then
        if not Input.selectComboUsed and not Input.l2ComboUsed and Input.selectHoldTime < 0.28 then
            Looper.activeTrack = (Looper.activeTrack % 4) + 1
            local nextTrack = Looper.tracks[Looper.activeTrack]
            Looper:showToast(string.format("TRACK %d: %s", Looper.activeTrack, nextTrack and nextTrack.name or ""))
        end
        Input.selectComboUsed = false
    end

    -- 3. L2 RECORD CLUTCH COMBOS: L2 + START (Clear Track), L2 + SELECT (Cycle Grid Mode)
    if Input.down.L2 then
        if Input.pressed.START then
            Looper:clearTrack(Looper.activeTrack)
            Input.l2ComboUsed = true
            controlsBlocked = true
        elseif Input.pressed.SELECT then
            Looper:cycleGridMode(Looper.activeTrack)
            Input.l2ComboUsed = true
            Input.selectComboUsed = true
            controlsBlocked = true
        end
    else
        Input.l2ComboUsed = false
    end

    -- 4. START (Tap / Double-Tap): Play / Pause Master Loop Clock
    if Input.pressed.START and not Input.down.L2 and not Input.down.SELECT then
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

    -- 5. R2 ALONE: Track Mutes (R2 + B/A/Y/X) & Live Performance FX (R2 + D-Pad)
    if Input.down.R2 then
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

    return controlsBlocked
end

-- ============================================================================
-- LÖVE (LOVE2D) LIFECYCLE CALLBACKS
-- ============================================================================

function love.load()
    love.window.setTitle("PocketGroove — 4-Track Handheld Groovebox")
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
