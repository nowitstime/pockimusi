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
local Menu        = require("src.menu")
local Song        = require("src.song")

local clamp = Config.clamp

local Modes = {
    -- NORMAL, REC_LATCH, REC_HOLD, NEW, ERASE, MIX, TRACK, TRANSPORT, FX,
    -- MENU_HOLD (SELECT + START held, counting up), MENU (src/menu.lua)
    current  = "NORMAL",
    previous = "NORMAL",

    -- Page state (read by Chrome)
    -- pending = instrument id previewed with L1/R1, applied on SELECT release
    -- picker  = { key, timer }: the list picker is open for the row `key`
    -- previewIn = seconds until the sound row `previewRow` is previewed
    trackPage = { row = 1, pending = nil, pendingSlot = nil, picker = nil, previewIn = nil, previewRow = nil },
    mixTrack  = 1,                       -- 1..4 = track, 5 = master

    -- Timings (seconds)
    TAP_MAX       = 0.25,                -- shorter than this = a tap
    TRACK_HOLD    = 0.18,                -- SELECT held this long opens the Track page
    TRANSPORT_HOLD = 0.22,               -- START held this long opens Transport
    DOUBLE_TAP    = 0.32,                -- two START taps within this = reset playhead
    NEW_HOLD      = 1.0,                 -- L2 + R2 + SELECT held this long = fresh session
    PICKER_HOLD   = 1.2,                 -- the list picker stays this long after the last change
    PREVIEW_SETTLE = 0.15,               -- held scrolling: preview the sound after this pause

    -- Count-in (SPEC §3.5): a record tap arms recording; it latches at `target`
    arm = nil,                           -- { target = tick, dist = ticks still to go }
    COUNT_MIN_BEATS = 2,                 -- a bar line nearer than this: use the one after
    COUNT_EARLY = 120,                   -- recording opens this many ticks before the bar line

    -- Recording passes: a new take every full loop, so undo removes one pass
    recPass = nil,                       -- { elapsed = ticks, lastTick }

    newHold = 0.0,                       -- seconds the fresh-session combo has been held
    newFired = false,                    -- fired during this hold (once per hold)
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

-- R2 + face: mute / unmute. In song mode it lands on the next bar.
local function face_mutes()
    for btn, slot in pairs(MUTE_BUTTON) do
        if Input.pressed[btn] then
            if Song:isOn() then Song:queueMute(slot) else Looper:toggleMute(slot) end
        end
    end
end

local function setMaster(v)
    Synth.masterVolume = clamp(v, 0.0, 1.0)
end

-- ---------------------------------------------------------------------------
-- Record: tap L2 = latch on/off, hold L2 = record while held (SPEC §4)
-- ---------------------------------------------------------------------------
local function cancelCountIn(toast)
    if not Modes.arm then return end
    Modes.arm = nil
    Looper.counting = false
    if toast then Looper:showToast(toast) end
end

-- Arm recording: it starts at the next bar line (the one after, if that is
-- very close). From a paused clock, start one bar before the loop's start.
local function startCountIn()
    local loop, bar = Looper:getLoopTicks(), Looper.PPQN * 4
    local target
    if not Looper.playing then
        Looper:seek((loop - bar) / loop)
        Looper:setPlaying(true)
        Synth:trigger("perc_wood", 5, 0.55, 0.8)        -- the first count
        target = 0
    else
        local nextBar = (math.floor(Looper.tick / bar) + 1) * bar
        if nextBar - Looper.tick < Modes.COUNT_MIN_BEATS * Looper.PPQN then nextBar = nextBar + bar end
        target = nextBar % loop
    end
    Modes.arm = { target = target, dist = (target - Looper.tick) % loop }
    Looper.counting = true
    Looper:showToast("COUNT-IN: RECORD STARTS ON THE BAR (TAP L2 TO CANCEL)")
end

-- Beats left in the count-in (for the top bar), or nil
function Modes:countInBeats()
    if not self.arm then return nil end
    return math.max(1, math.ceil(self.arm.dist / Looper.PPQN))
end

local function updateCountIn()
    local arm = Modes.arm
    if not arm then return end
    if not Looper.playing then return cancelCountIn("COUNT-IN CANCELLED") end
    local loop = Looper:getLoopTicks()
    local dist = (arm.target - Looper.tick) % loop
    -- nearly there, or already past it (the distance jumped back up)
    if dist <= Modes.COUNT_EARLY or dist > arm.dist + loop * 0.5 then
        cancelCountIn()
        Input.recLatched = true
        Looper:beginRecordingTake()
        Looper:showToast("[REC] RECORD LATCHED (TAP L2 TO STOP)")
    else
        arm.dist = dist
    end
end

-- While recording, every full loop since it began starts a new take
local function updateRecPass()
    if not Input:isRecording() then
        Modes.recPass = nil
        return
    end
    local pass = Modes.recPass
    if not pass then
        Modes.recPass = { elapsed = 0.0, lastTick = Looper.tick }
        return
    end
    local loop = Looper:getLoopTicks()
    local d = (Looper.tick - pass.lastTick) % loop
    if d < loop * 0.5 then pass.elapsed = pass.elapsed + d end     -- stutter jumps back don't count
    pass.lastTick = Looper.tick
    if pass.elapsed >= loop then
        pass.elapsed = pass.elapsed - loop
        Looper:beginRecordingTake()
    end
end

-- Recording on a track whose FOLLOW is off while chords are set: its notes
-- won't move with the chords. A warning, or nil.
function Modes:followWarning()
    local def, state, track = Instruments:getTrackInstrument(Looper.activeTrack)
    if not state or state.follow ~= false or not track or track.isLane then return nil end
    local hasRow = false
    for _, row in ipairs(Instruments:getSoundRows(def, state)) do
        if row.key == "FOLLOW" then hasRow = true end
    end
    if not hasRow or not require("src.harmony"):source() then return nil end
    return "FOLLOW OFF - THESE NOTES STAY PUT WHEN THE CHORDS CHANGE"
end

local function updateRecord()
    updateCountIn()
    updateRecPass()
    if Menu:isActive() then return end             -- L2 does nothing in the menu
    if Input.pressed.L2 then
        Looper:beginRecordingTake()
        Modes.warned = Modes:followWarning()
        if Modes.warned then Looper:showToast(Modes.warned) end
    end
    if not Input.released.L2 then return end

    local used = Input.comboUsed.L2
    -- Song mode: L2 on S rolls the song tape; L2 anywhere stops it
    if not used and Input.l2HoldTime < Modes.TAP_MAX and (Song.recording or Song.armed) then
        Song:stopRecording()
        return
    end
    if not used and Input.l2HoldTime < Modes.TAP_MAX and Song.page and Song:isOn() and not Input.recLatched then
        Song:startRecording()
        return
    end
    if not used and Input.l2HoldTime < Modes.TAP_MAX then
        if Modes.arm then
            cancelCountIn("COUNT-IN CANCELLED")
        elseif not Input.recLatched and Looper.countIn then
            startCountIn()
        else
            Input.recLatched = not Input.recLatched
            Looper:showToast(Input.recLatched and (Modes.warned or "[REC] RECORD LATCHED (TAP L2 TO STOP)") or "RECORD STOPPED")
        end
    elseif not used and Input.recLatched and Input.l2HoldTime >= Modes.TAP_MAX then
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
    if Menu:isActive() then return "MENU" end
    if d.L2 and d.R2 and d.SELECT then return "NEW" end
    if d.L2 and d.R2 then return "ERASE" end
    if d.SELECT and d.START then
        -- On the Clock page a quick SELECT tap still changes track; only a
        -- SELECT held past a tap counts towards the menu
        local st, sl = Input.startHoldTime, Input.selectHoldTime
        if st > sl and st >= self.TRANSPORT_HOLD and sl < self.TAP_MAX then return "TRANSPORT" end
        return "MENU_HOLD"
    end
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

-- What a face button clears on the Erase page: its own notes, or what the
-- instrument's ERASE map gives it ({ B = { actions = { "R1" }, label =
-- "DOWNSTROKES" } }; a button the map leaves out clears nothing).
-- Returns actions, label, or nil.
function Modes:eraseTarget(def, state, btn)
    if def.ERASE then
        local entry = def.ERASE[btn]
        if not entry then return nil end
        return entry.actions, entry.label
    end
    return btn, def.getActionLabel and def:getActionLabel(state, btn) or btn
end

-- L2 + R2: erase a pad, undo a take, clear the track
function handlers.ERASE(ctx)
    Input.comboUsed.L2, Input.comboUsed.R2 = true, true
    local tIdx = Looper.activeTrack
    -- On S the Erase page works on the queue: B takes the last one out, X empties it
    if Song.page then
        if Input.pressed.B then
            local slot = Song:popQueue()
            Looper:showToast(slot and (slot .. " TAKEN OUT OF THE QUEUE") or "THE QUEUE IS EMPTY")
        elseif Input.pressed.X then
            Song:clearQueue()
            Looper:showToast("QUEUE EMPTIED")
        end
        if Input.pressed.LEFT or Input.pressed.L1 then Song:undo() end
        return true
    end
    for _, btn in ipairs(FACE) do
        if Input.pressed[btn] then
            local actions, label = Modes:eraseTarget(ctx.def, ctx.state, btn)
            if actions then Looper:clearTrackAction(tIdx, actions, label) end
        end
    end
    if Input.pressed.LEFT or Input.pressed.L1 then
        Instruments:releaseAll()      -- held notes end on the instrument that started them
        Looper:undo()
    end
    if Input.pressed.START then
        Looper:clearTrack(tIdx)
        Input.comboUsed.START = true
    end
    return true
end

-- L2 + R2 + SELECT held: a fresh session after NEW_HOLD seconds (once per
-- hold). Clears every track's notes and mutes, keeps the setup; undoable.
function handlers.NEW(ctx, dt)
    Input.comboUsed.L2, Input.comboUsed.R2, Input.comboUsed.SELECT = true, true, true
    if Modes.previous ~= "NEW" then
        Modes.newHold, Modes.newFired = 0.0, false
    end
    Modes.newHold = Modes.newHold + (dt or 0)
    if not Modes.newFired and Modes.newHold >= Modes.NEW_HOLD then
        Modes.newFired = true
        Instruments:releaseAll()
        Looper:freshSession()
    end
    return true
end

-- Seconds SELECT and START have both been held
local function menuHeld()
    return math.min(Input.selectHoldTime, Input.startHoldTime)
end

-- SELECT + START held: the menu opens once both have been down Menu.HOLD seconds
function handlers.MENU_HOLD()
    Input.comboUsed.SELECT, Input.comboUsed.START = true, true
    if menuHeld() >= Menu.HOLD then
        -- a swap previewed on the Track page is dropped, not applied
        Modes.trackPage.pending, Modes.trackPage.pendingSlot = nil, nil
        Modes.trackPage.picker, Modes.trackPage.previewIn = nil, nil
        Instruments:releaseAll()
        Menu:openMenu()
    end
    return true
end

-- The menu is up: it reads the buttons (src/menu.lua)
-- (L2 and R2 are not marked used: that mark only clears on their next
-- press, and a stale L2 mark would swallow every SELECT tap after the menu.
-- updateRecord skips L2 while the menu is active instead.)
function handlers.MENU(ctx, dt)
    Input.comboUsed.SELECT, Input.comboUsed.START = true, true
    Menu:update(dt)
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

-- Hold SELECT: Track page = sound.
--   UP / DOWN     row cursor (the instrument's rows, then the four effects)
--   LEFT / RIGHT  change the selected row; holding repeats
--   L1 / R1       preview another instrument; the swap happens on SELECT release
--   face tap      effect on / off, and the cursor jumps to that effect's row
function handlers.TRACK(ctx, dt)
    Input.comboUsed.SELECT = true
    local page = Modes.trackPage
    -- On S: the song's rows (src/song.lua)
    if Song.page then
        local rows = Song:rows()
        if Modes.previous ~= "TRACK" then page.row = 1 end
        page.row = clamp(page.row, 1, #rows)
        if Input.repeated.UP or Input.repeated.DOWN then
            page.row = Input.repeated.UP and ((page.row - 2) % #rows) + 1 or (page.row % #rows) + 1
            Song.confirmRow = nil
        end
        if Input.pressed.L1 then Song:moveCursor(-1) end
        if Input.pressed.R1 then Song:moveCursor(1) end
        local delta = (Input.repeated.LEFT and -1) or (Input.repeated.RIGHT and 1) or nil
        if delta then Song:cycleRow(rows[page.row].key, delta) end
        return true
    end
    local def, state = ctx.def, ctx.state
    local track = Looper.tracks[Looper.activeTrack]
    local rows = Instruments:getSoundRows(def, state, track)

    if Modes.previous ~= "TRACK" then
        page.row = (def.getDefaultSoundRow and def:getDefaultSoundRow(state)) or 1
        page.picker, page.previewIn = nil, nil
    end
    page.row = clamp(page.row, 1, #rows)

    -- Instrument: L1 / R1 only preview; the swap happens on SELECT release.
    -- Track C is always the chord lane.
    if track.isLane and (Input.pressed.L1 or Input.pressed.R1) then
        Looper:showToast("TRACK C IS ALWAYS THE CHORDS")
    elseif Input.pressed.L1 or Input.pressed.R1 then
        local from = page.pending or track.instrumentId
        local nextId = Instruments:stepInstrumentId(from, Input.pressed.L1 and -1 or 1)
        page.picker, page.previewIn = nil, nil
        if nextId == track.instrumentId then
            page.pending, page.pendingSlot = nil, nil
            Looper:showToast("INSTRUMENT: NO CHANGE")
        else
            page.pending, page.pendingSlot = nextId, track.slot
            local nextDef = Instruments:getDefinition(nextId)
            Looper:showToast("RELEASE SELECT TO SWAP TO " .. nextDef.name)
        end
    end
    -- A previewed swap shows its card in place of the rows, so they wait
    if page.pending then return true end

    -- Effects on the face buttons: on / off, and the cursor goes to its row
    for _, btn in ipairs({ "X", "Y", "A", "B" }) do
        if Input.pressed[btn] and not def.NO_FX then
            page.fxBtn = btn
            Looper:toggleTrackFx(Looper.activeTrack, btn)
            for i, row in ipairs(rows) do
                if row.kind == "fx" and row.button == btn then page.row = i end
            end
            page.picker, page.previewIn = nil, nil
        end
    end

    if Input.repeated.UP or Input.repeated.DOWN then
        page.row = Input.repeated.UP and ((page.row - 2) % #rows) + 1 or (page.row % #rows) + 1
        page.picker, page.previewIn = nil, nil
    end

    -- LEFT / RIGHT: change the selected row. A press previews a sound at once;
    -- held scrolling previews only once it settles.
    local delta = (Input.repeated.LEFT and -1) or (Input.repeated.RIGHT and 1) or nil
    if delta then
        local row = rows[page.row]
        local quiet = not (Input.pressed.LEFT or Input.pressed.RIGHT)
        Instruments:cycleRow(def, state, page.row, delta, track, quiet)
        if row.items then
            page.picker = { key = row.key, timer = Modes.PICKER_HOLD }
        end
        if quiet and not row.kind then
            page.previewIn, page.previewRow = Modes.PREVIEW_SETTLE, page.row
        else
            page.previewIn = nil
        end
    end

    if page.picker then
        page.picker.timer = page.picker.timer - (dt or 0)
        if page.picker.timer <= 0 then page.picker = nil end
    end
    if page.previewIn then
        page.previewIn = page.previewIn - (dt or 0)
        if page.previewIn <= 0 then
            page.previewIn = nil
            if def.previewRowSound then def:previewRowSound(state, page.previewRow) end
        end
    end
    return true
end

-- Hold START: Transport = timing. A SELECT tap still changes track here, so
-- grid and swing can be set for each track without leaving the page.
local updateSelectTap
-- Tempo (L1 / R1): a press steps 5 BPM; held, it keeps stepping after TEMPO_REPEAT[1]
-- seconds, every TEMPO_REPEAT[2] seconds, and twice as fast after
-- TEMPO_REPEAT[3] seconds, so 60 -> 240 is a short hold, not 36 presses
Modes.TEMPO_REPEAT = { 0.4, 0.12, 1.5 }
Modes.tempoHold = { dir = 0, held = 0.0, next = 0.0 }

local function stepTempo(dir)
    Looper.bpm = clamp(Looper.bpm + dir * 5, Config.MIN_BPM, Config.MAX_BPM)
    Looper:showToast("TEMPO: " .. Looper.bpm .. " BPM")
end

-- Tempo on the shoulders: R1 up, L1 down
local function updateTempo(dt)
    local th = Modes.tempoHold
    if Input.pressed.R1 or Input.pressed.L1 then
        th.dir = Input.pressed.R1 and 1 or -1
        th.held, th.next = 0.0, Modes.TEMPO_REPEAT[1]
        stepTempo(th.dir)
        return
    end
    if th.dir == 0 then return end
    if not Input.down[th.dir > 0 and "R1" or "L1"] then
        th.dir = 0
        return
    end
    th.held = th.held + (dt or 0)
    while th.held >= th.next do
        stepTempo(th.dir)
        local rate = Modes.TEMPO_REPEAT[2]
        if th.held >= Modes.TEMPO_REPEAT[3] then rate = rate * 0.5 end
        th.next = th.next + rate
    end
end

function handlers.TRANSPORT(ctx, dt)
    Input.comboUsed.START = true
    updateSelectTap()
    local tIdx = Looper.activeTrack
    local lane = Looper.tracks[tIdx] and Looper.tracks[tIdx].isLane

    updateTempo(dt)

    -- D-pad = the music: LEFT / RIGHT key, UP / DOWN scale (with Y: swing)
    if Input.down.Y and lane then
        if Input.pressed.UP or Input.pressed.DOWN then
            Looper:showToast("TRACK C HAS NO SWING")
        end
    elseif Input.down.Y then
        if Input.pressed.UP then
            Looper:adjustSwing(tIdx, 0.02)
        elseif Input.pressed.DOWN then
            Looper:adjustSwing(tIdx, -0.02)
        end
    elseif Input.pressed.UP or Input.pressed.DOWN then
        Theory:cycleScale(Input.pressed.UP and 1 or -1)
        Modes.transportPicker = { key = "SCALE", timer = Modes.PICKER_HOLD }
        Looper:showToast("SCALE: " .. Theory.SCALES[Theory.scaleIndex].fullName)
    end

    if Input.pressed.LEFT or Input.pressed.RIGHT then
        Theory:cycleRoot(Input.pressed.RIGHT and 1 or -1)
        Modes.transportPicker = { key = "KEY", timer = Modes.PICKER_HOLD }
        Looper:showToast("KEY: " .. Theory:getKeyLabel())
    end

    if Modes.transportPicker then
        Modes.transportPicker.timer = Modes.transportPicker.timer - (dt or 0)
        if Modes.transportPicker.timer <= 0 then Modes.transportPicker = nil end
    end

    if Input.pressed.B then Looper:toggleBars() end
    if Input.pressed.A then
        if lane then
            Looper:showToast("TRACK C: ITS GRID ROW IS ON THE TRACK PAGE (SELECT)")
        else
            Looper:cycleGridMode(tIdx)
        end
    end
    if Input.pressed.X then Looper:cycleClickMode() end
    return true
end

-- Hold R2: face = mutes, D-pad = live FX. The instrument is blocked, but taps
-- and the L2 + START clear still apply.
function handlers.FX()
    face_mutes()
    -- R2 + L1 / R1: song mode fades, from any page
    if Song:isOn() then
        if Input.down.L1 and not Input.down.R1 then Song.fadeDir = -1
        elseif Input.down.R1 and not Input.down.L1 then Song.fadeDir = 1 end
    end
    setLiveFx(Input.down.UP, Input.down.DOWN, Input.down.LEFT, Input.down.RIGHT)
    return false
end

-- ---------------------------------------------------------------------------
-- Taps and always-on combos (only when no page owns the frame)
-- ---------------------------------------------------------------------------
function updateSelectTap()
    if not Input.released.SELECT then return end
    if not Input.comboUsed.SELECT and not Input.comboUsed.L2 and Input.selectHoldTime < Modes.TAP_MAX then
        -- 1 -> 2 -> 3 -> 4 -> C (the chord lane) -> 1. In song mode the face
        -- buttons on S reach the tracks, so SELECT goes home to S, and from S
        -- to track C (the one track the face buttons don't reach).
        if Song:isOn() then
            if Song.page then
                Song:leavePage(Looper.LANE)
            else
                Song:goToPage()
            end
            return
        end
        Looper.activeTrack = (Looper.activeTrack % #Looper.tracks) + 1
        local nextTrack = Looper.tracks[Looper.activeTrack]
        if nextTrack and nextTrack.isLane then
            Looper:showToast("TRACK C: CHORDS - " .. (Looper.playing and "B CHANGES ON THE BAR LINE" or "B WRITES AND STEPS ON"))
        else
            Looper:showToast(string.format("TRACK %d: %s", Looper.activeTrack, nextTrack and nextTrack.name or ""))
        end
    end
end

local function updateStartTap()
    if not (Input.released.START and not Input.comboUsed.START and not Input.down.L2
            and not Input.down.SELECT and Input.startHoldTime < Modes.TAP_MAX) then
        return
    end
    local now = love.timer.getTime()
    -- Song mode with a song: a double tap plays it from the top (a single
    -- tap pauses and carries on, as always)
    if (now - Input.lastStartTapTime) < Modes.DOUBLE_TAP and Song:isOn() and Song:hasSong() then
        Song:playFromTop()
        Input.lastStartTapTime = now
        return
    end
    if (now - Input.lastStartTapTime) < Modes.DOUBLE_TAP then
        -- Back to bar 1.1 from silence: whatever is still ringing (a stuck
        -- note, echo and reverb tails) stops
        Instruments:releaseAll()
        Looper:silenceAll()
        Synth:panic()
        Looper:resetPlayhead()
        Looper.playing = true
        Looper:showToast("PLAYHEAD RESET TO BAR 1.1 - ALL SOUND CLEARED")
    else
        Looper:setPlaying(not Looper.playing)
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
-- Apply a previewed instrument swap once SELECT is let go
local function applyPendingSwap()
    local page = Modes.trackPage
    if page.pending and Input.released.SELECT then
        Instruments:swapTrackInstrument(page.pendingSlot, page.pending)
        page.pending, page.pendingSlot = nil, nil
        page.picker, page.previewIn = nil, nil
        page.row = 1
    end
end

function Modes:update(dt)
    updateRecord()
    applyPendingSwap()

    self.previous = self.current
    self.current = self:resolve()

    -- A quick SELECT + START tap (let go before the menu opens): to S
    if self.previous == "MENU_HOLD" and self.current ~= "MENU_HOLD" and not Menu:isActive() then
        Song:goToPage()
    end

    if self.current ~= "FX" then
        setLiveFx(Song:playbackFx())          -- the song's recorded FX, or none
    end
    if self.current ~= "TRANSPORT" then
        self.transportPicker = nil
    end

    local def, state = Instruments:getTrackInstrument(Looper.activeTrack)
    local handler = handlers[self.current]
    local blocked = false
    if handler then
        blocked = true
        if handler({ def = def, state = state }, dt) then
            Input:clearReleasedCombos()
            return true
        end
    end

    -- The S page owns the play controls (src/song.lua)
    if Song.page and not handler then
        Song:updatePage(dt)
        blocked = true
    end

    updateSelectTap()
    updateStartTap()
    if updateClearCombo() then blocked = true end

    Input:clearReleasedCombos()
    return blocked
end

return Modes
