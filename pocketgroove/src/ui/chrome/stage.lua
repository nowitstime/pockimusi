-- ============================================================================
-- src/ui/chrome/stage.lua — Region 2: the centre stage frame, shoulders, titles, control labels
-- (part of src/ui/chrome.lua: adds methods to the Chrome table)
-- ============================================================================

local Config      = require("src.config")
local Theory      = require("src.theory")
local Input       = require("src.input")
local Synth       = require("src.synth")
local Looper      = require("src.looper")
local Instruments = require("src.instruments")
local Modes       = require("src.modes")
local Harmony     = require("src.harmony")
local Display     = require("src.ui.display")
local Song        = require("src.song")

local clamp      = Config.clamp
local math_floor = math.floor
local math_min   = math.min
local math_max   = math.max
local math_sin   = math.sin
local math_cos   = math.cos
local math_abs   = math.abs
local math_pi    = math.pi

return function(Chrome)

-- ============================================================================
-- REGION 2: CENTER STAGE (y: 50..356)
-- ============================================================================
function Chrome:drawCenterStage()
    local C = Config.COLORS
    local sl = Looper.activeTrack
    local track = Looper.tracks[sl]
    local def, state = Instruments:getTrackInstrument(sl)
    local instCol = self:trackColor(sl)
    local mode = Modes.current or "NORMAL"
    local playMode = self:isPlayMode(mode)
    -- The S page (song mode): this stage, with the song's labels and view
    local songPage = Song.page and playMode
    local songRows = Song.page and mode == "TRACK"
    if songPage then instCol = Config.COLORS.SONG end
    if self.MOCK and mode == "TRACK" and not songRows and not track.isLane then
        return self:drawMockTrackStage(def, state, track, instCol, love.timer.getTime())
    end
    local accent = self:getAccent(mode, instCol)
    local t = love.timer.getTime()
    local kind = self:viewKind(def)
    local view = def.VIEW or {}

    -- Frame: the instrument's dark stage, sky and halo while playing; a
    -- solid mode-coloured border on a settings page or while recording
    local mockD = (self.MOCK == "D") and self.MOCK_PAGES[mode] and not songPage
    local borderCol = (mode == "NORMAL") and Config.shade(instCol, 0.45) or (Config.MODE_COLORS[mode] or C.GRID)
    if Song.recording and playMode then borderCol = C.RED end
    if mockD then
        self:mockModeBackdrop(def, instCol)
    else
    self:drawFrame(8, 50, 624, 306, borderCol, 1)
    self.haloDrawn = false
    if playMode and not songPage then
        self.haloDrawn = self:drawStageMood(def, instCol, 102, 188, 538, 188)
    end
    if mode == "ERASE" or mode == "NEW" then
        self:setColor(C.RED, 0.07)
        love.graphics.rectangle("fill", 9, 51, 622, 304, 6, 6)
    end
    self:setColor(borderCol)
    love.graphics.setLineWidth((mode == "NORMAL" and not Song.recording) and 1 or 2)
    love.graphics.rectangle("line", 8, 50, 624, 306, 6, 6)
    love.graphics.setLineWidth(1)

    if not self.haloDrawn then
        -- Vertical hairline dividers separating Left Zone | Center | Right Zone
        self:setColor(C.GRID, 0.55)
        love.graphics.line(198, 62, 198, 312)
        love.graphics.line(442, 62, 442, 312)

        -- Zone motifs: a view's own plain motif, or the astrolabe ring on settings pages
        if playMode then
            self:drawZoneMotifs(kind, instCol, t)
        else
            self:drawZoneMotifs("drums", accent, t)
        end
    end
    end -- mockD

    -- Shoulder capsules
    local lOn, rOn = Input.down.L1, Input.down.R1
    local l1Label, r1Label = "L1: -", "R1: +"
    if songPage and Song:writing() then
        l1Label, r1Label = "L1: < STEP", "R1: STEP >"
    elseif songRows then
        l1Label, r1Label = "L1: < STEP", "R1: STEP >"
    elseif songPage then
        l1Label, r1Label = "L1: FADE OUT", "R1: FADE IN"
    elseif mode == "TRACK" and track.isLane then
        l1Label, r1Label = "L1: -", "R1: -"
    elseif mode == "TRACK" then
        l1Label, r1Label = "L1: < INSTRUMENT", "R1: INSTRUMENT >"
    elseif mode == "TRANSPORT" then
        l1Label, r1Label = "L1: BPM -", "R1: BPM +"
    elseif mode == "MIX" then
        l1Label, r1Label = "L1: MST -", "R1: MST +"
    elseif mode == "ERASE" then
        l1Label, r1Label = "L1: UNDO", "R1: -"
    elseif mode == "NEW" then
        l1Label, r1Label = "L1: -", "R1: -"
    else
        -- playing: the view's own labels, then the instrument's VIEW over them
        if kind == "drums" then
            l1Label, r1Label = "L1: 1/4", "R1: 1/8"
        elseif kind == "harp" then
            l1Label, r1Label = "L1: OCT -", "R1: OCT +"
        elseif kind == "lead" and lOn and rOn then
            l1Label, r1Label = "L1+R1: RATE x2", "L1+R1: RATE x2"
        elseif kind == "lab" then
            l1Label, r1Label = "L1: -", "R1: -"
        else
            l1Label, r1Label = "L1: OCT -1", "R1: OCT +1"
        end
        if view.l1 then l1Label = "L1: " .. view.l1 end
        if view.r1 then r1Label = "R1: " .. view.r1 end
        if view.both and lOn and rOn then
            l1Label, r1Label = "L1+R1: " .. view.both, "L1+R1: " .. view.both
        end
    end
    -- Shoulder tabs: the button as a keycap, then what it does; a held
    -- shoulder fills solid and its word goes bold
    local function shoulder(x, label, on, right)
        local key, text = label:match("^(%S+):%s*(.*)$")
        if not key then key, text = "", label end
        local w, h, y = 112, 22, 58
        if on then
            self:setColor(accent)
            love.graphics.rectangle("fill", x, y, w, h, 11, 11)
        else
            self:setColor(playMode and C.BG or Config.shade(accent, 0.12))
            love.graphics.rectangle("fill", x, y, w, h, 11, 11)
            self:setColor(playMode and Config.shade(accent, 0.45) or accent)
            love.graphics.rectangle("line", x, y, w, h, 11, 11)
        end
        local ft = self.fontTiny
        local kw = math_max(22, ft:getWidth(key) + 10)
        local kx = right and (x + w - kw - 4) or (x + 4)
        self:setColor(on and C.BG or Config.shade(accent, 0.3))
        love.graphics.rectangle("fill", kx, y + 4, kw, 14, 7, 7)
        love.graphics.setFont(ft)
        self:setColor(accent)
        love.graphics.print(key, math_floor(kx + (kw - ft:getWidth(key)) * 0.5), math_floor(y + 11 - self:lineHeight(ft) * 0.5))
        local room = w - kw - 16
        local f = (self.fontSmall:getWidth(text) <= room) and self.fontSmall or ft
        love.graphics.setFont(f)
        local tw = f:getWidth(text)
        local tx = right and (kx - 6 - tw) or (kx + kw + 6)
        local ty = math_floor(y + 11 - self:lineHeight(f) * 0.5)
        self:setColor(on and C.BG or C.TEXT)
        if on then self:printBold(text, math_floor(tx), ty) else love.graphics.print(text, math_floor(tx), ty) end
    end
    if not (mode == "TRACK" and not songRows) then
        shoulder(18, l1Label, lOn)
        shoulder(510, r1Label, rOn, true)
    end

    local titleStr = songPage and "SONG" or def.name
    if mode == "TRACK" then titleStr = "TRACK " .. Looper:slotLabel(sl)
    elseif mode == "MIX" then titleStr = "MIX"
    elseif mode == "TRANSPORT" then titleStr = "CLOCK"
    elseif mode == "ERASE" then titleStr = "ERASE"
    elseif mode == "NEW" then titleStr = "FRESH"
    elseif mode == "FX" then titleStr = "LIVE FX"
    end

    if songRows then
        self:setColor(accent)
        love.graphics.setFont(self.fontMed)
        local tw = self.fontMed:getWidth("TRACK S - SONG")
        love.graphics.print("TRACK S - SONG", math_floor(320 - tw * 0.5), 62)
    elseif mode == "TRACK" then
        -- Style 2 compact group + instrument pill header (with L1 / R1 caps)
        self:drawInstrumentTabs(track, accent)
    else
        self:setColor(playMode and C.TEXT or accent)
        love.graphics.setFont(self.fontMed)
        local tw = self.fontMed:getWidth(titleStr)
        love.graphics.print(titleStr, math_floor(320 - tw * 0.5), 62)
    end

    if not (mode == "TRACK" and not songRows) then
        self:setColor(playMode and C.GRID or accent, playMode and 0.6 or 0.35)
        love.graphics.line(212, 82, 428, 82)
    end

    -- Left: Star D-Pad & Right: Circle Face Buttons (drawn in the page accent)
    local dpadLabels, faceLabels, flashMap, activeMap = self:getControlLabels(def, state, mode)
    local activeDir = Input:get8WayDirection()
    local guideDir = playMode and def.getGuideDir and def:getGuideDir(state) or nil
    if songPage then
        dpadLabels, faceLabels, activeMap, guideDir = self:songLabels()
        flashMap = {}
        if Song:writing() and Song.pointing then
            faceLabels = { B = "WRITE", A = "", Y = "COPY", X = "CLEAR" }
        end
    elseif songRows then
        faceLabels = { B = "", A = "", Y = "", X = "" }
        activeMap = {}
    elseif mode == "TRACK" then
        dpadLabels = {}       -- clean unlabelled compass on Track page
    elseif Song.page and mode == "ERASE" then
        dpadLabels = { LEFT = "UNDO SONG" }
        faceLabels = { B = "UNQUEUE", A = "", Y = "", X = "EMPTY Q" }
        activeMap = {}
    end
    if mockD then
        self:mockDial(102, 188, { 0.86, 0.92, 1.0, 1.0 }, instCol, C.TEXT, false, dpadLabels)
    else
    self:drawStarDpad(102, 188, dpadLabels, accent, activeDir, guideDir)
    end
    self:drawCircleFaceButtons(538, 188, faceLabels, accent, flashMap, activeMap)

    -- Option 3 Astrolabe Engraving subtitles (omitted on Track page)
    if mode ~= "TRACK" then
        local dpadMode = {
            MIX = "TRACK & LEVEL", TRANSPORT = "KEY & SCALE",
            ERASE = "UNDO", FX = "PUNCH-IN FX",
        }
        local faceMode = {
            MIX = "MUTES", TRANSPORT = "TIMING",
            ERASE = "CLEAR", FX = "MUTES",
        }
        local instDpad = {
            drums = "EXPRESSION", hands = "ARTICULATION", breaks = "SLICE JUMP",
            bass = "SCALE DEGREE", roller = "PITCH", wobble = "WOBBLE RATE",
            harp = "CHORD", strum = "CHORD", pad = "TONE & MOVE",
            lead = "SCALE DEGREE", dial = "DIAL NOTE", slide = "PITCH SLIDE",
            valves = "REGISTER", lane = "CHORD", fingers = "TEST",
        }
        local instFace = {
            drums = "PADS", hands = "STRIKES", breaks = "MOVES",
            bass = "ARTICULATION", roller = "ROLL RATE", wobble = "CHORD NOTES",
            harp = "STRINGS", strum = "STRINGS", pad = "VOICINGS",
            lead = "NOTE & ARP", dial = "STRIKE", slide = "HOLD & DIVE",
            valves = "VALVES", lane = "ACTIONS", fingers = "CHORD",
        }
        local dpadSub = dpadMode[mode] or (def.getDpadSubtitle and def:getDpadSubtitle(state))
            or instDpad[def.id] or instDpad[kind]
        local faceSub = faceMode[mode] or instFace[def.id] or instFace[kind]
        if songPage then
            dpadSub = "PATTERNS"
            faceSub = Song.pointing and ("ACT ON " .. Song.pointing) or "TRACKS"
        end
        local function drawEngraved(cx, txt)
            if not txt or txt == "" then return end
            love.graphics.setFont(self.fontTiny)
            local tw = self.fontTiny:getWidth(txt)
            local y = 297
            self:setColor(accent, 0.28)
            love.graphics.line(cx - tw * 0.5 - 16, y + 5, cx - tw * 0.5 - 6, y + 5)
            love.graphics.line(cx + tw * 0.5 + 6, y + 5, cx + tw * 0.5 + 16, y + 5)
            self:drawDiamond(cx - tw * 0.5 - 18, y + 5, 1.8, Config.shade(accent, 0.55))
            self:drawDiamond(cx + tw * 0.5 + 18, y + 5, 1.8, Config.shade(accent, 0.55))
            self:setColor(Config.shade(accent, 0.72))
            love.graphics.print(txt, math_floor(cx - tw * 0.5), y)
        end
        if mockD then
            self:mockSpacedTitle(102, 297, dpadSub or "", accent, 0.75)
            self:mockSpacedTitle(538, 297, faceSub or "", accent, 0.75)
        else
        drawEngraved(102, dpadSub)
        drawEngraved(538, faceSub)
        end
    end

    -- Center Column Visualizer (x: 204..436, y: 90..314)
    if mode == "MIX" then
        self:drawMixerView(t)
    elseif songRows then
        self:drawSongRows(accent)
    elseif mode == "TRACK" then
        self:drawTrackPageView(def, state, track, accent)
    elseif mode == "TRANSPORT" then
        self:drawTransportView(track, instCol, accent)
    elseif mode == "ERASE" then
        self:drawEraseView(track, def)
    elseif mode == "NEW" then
        self:drawFreshSessionView()
    elseif songPage and Song:writing() and not Song.pointing then
        self:drawSongGrid(accent)
    elseif songPage then
        self:drawSongView(accent)
    else
        self:drawInstrumentVisualizer(def, state, track, instCol, t)
    end

    -- Bottom Integrated Footer Strip (y: 322..355)
    self:drawFooterStrip(def, mode)
end

function Chrome:getControlLabels(def, state, mode)
    local C = Config.COLORS
    local dpadLabels = {}
    local faceLabels = { B = "B", A = "A", Y = "Y", X = "X" }
    local flashMap = {}
    local activeMap = {}

    -- The face buttons mute tracks 1-4 (Mix page and live FX): a muted one is lit
    -- (song mode: a mute waiting for the next bar shows as it will be, with a ">")
    local function muteLabels()
        local labels = {}
        for btn, slot in pairs({ B = 1, A = 2, Y = 3, X = 4 }) do
            local muted = Looper.tracks[slot].muted
            local pending = Song.pendingMutes[slot]
            if pending ~= nil then
                labels[btn] = pending and ("M" .. slot .. " >M") or ("M" .. slot .. " >ON")
                activeMap[btn] = pending
            else
                labels[btn] = muted and ("M" .. slot .. " [M]") or ("M" .. slot)
                activeMap[btn] = muted
            end
        end
        return labels
    end

    if mode == "MIX" then
        dpadLabels = { UP = "LVL+", DOWN = "LVL-", LEFT = "TRK <", RIGHT = "TRK >" }
        faceLabels = muteLabels()
    elseif mode == "FX" then
        dpadLabels = { UP = "STUTTER", DOWN = "SLOW", LEFT = "FILTER", RIGHT = "CRUSH" }
        faceLabels = muteLabels()
    elseif mode == "TRACK" then
        local fx = Looper.tracks[Looper.activeTrack].fx
        dpadLabels = { UP = "ROW UP", DOWN = "ROW DOWN", LEFT = "VALUE <", RIGHT = "VALUE >" }
        faceLabels = { B = "SPACE", A = "ECHO", Y = "DRIVE", X = "TONE" }
        if def.NO_FX then faceLabels = { B = "", A = "", Y = "", X = "" } end
        for btn, slot in pairs(Looper.FX_SLOTS) do
            activeMap[btn] = fx.on[slot]
        end
    elseif mode == "TRANSPORT" then
        local swingHeld = Input.down.Y
        dpadLabels = swingHeld and { UP = "SWING +", DOWN = "SWING -", LEFT = "KEY <", RIGHT = "KEY >" }
            or { UP = "SCALE >", DOWN = "SCALE <", LEFT = "KEY <", RIGHT = "KEY >" }
        local clickLabels = { ["OFF"] = "CLICK", ["ON"] = "CLICK", ["COUNT-IN"] = "COUNT IN", ["ON + COUNT-IN"] = "CLICK +COUNT" }
        faceLabels = { B = Looper.bars .. " BAR", A = "GRID", Y = "SWING", X = clickLabels[Looper:getClickMode()] }
        activeMap.X = Looper.clickOn or Looper.countIn
    elseif mode == "ERASE" then
        dpadLabels = { LEFT = "UNDO" }
        faceLabels = { B = "CLR B", A = "CLR A", Y = "CLR Y", X = "CLR X" }
        if def.ERASE then
            -- only the buttons the instrument's erase map uses
            for btn in pairs(faceLabels) do
                if not def.ERASE[btn] then faceLabels[btn] = "" end
            end
        end
    elseif mode == "NEW" then
        dpadLabels = {}
        faceLabels = { B = "", A = "", Y = "", X = "" }
    else
        dpadLabels, faceLabels, flashMap, activeMap = self:getInstrumentLabels(def, state)
    end

    return dpadLabels, faceLabels, flashMap, activeMap
end

-- The play surface's labels: those of the instrument's stage view, with the
-- instrument's own VIEW.dpad / VIEW.face in their place where it has them
function Chrome:getInstrumentLabels(def, state)
    local kind = self:viewKind(def)
    local dpadLabels = {}
    local faceLabels = { B = "B", A = "A", Y = "Y", X = "X" }
    local flashMap = {}
    local activeMap = {}

    if kind == "drums" then
        dpadLabels = { UP = "ACCENT", DOWN = "GHOST", LEFT = "FLAM", RIGHT = "RATCHET" }
        -- each pad shows the kind of sound on it (an icon for KICK, SNARE...)
        faceLabels = {}
        for _, btn in ipairs({ "B", "A", "Y", "X" }) do
            local snd = def.getPadSound and def:getPadSound(state, btn)
            faceLabels[btn] = snd and snd.cat or ""
        end
        flashMap = state.padFlash
    elseif kind == "harp" then
        dpadLabels = { NEUTRAL = "I", UP = "bVI", DOWN = "vi", LEFT = "IV", RIGHT = "V", UP_LEFT = "ii", UP_RIGHT = "iii", DOWN_LEFT = "bVII", DOWN_RIGHT = "IVm" }
        if state.follow then dpadLabels = { NEUTRAL = "FOLLOW" } end
        local chord = state.currentChord or Theory:getChordForDirection("NEUTRAL", false, false, state.colour)
        local n = chord.notes
        faceLabels = {
            B = Theory.NOTE_NAMES[(n[1] % 12) + 1],
            A = Theory.NOTE_NAMES[(n[2] % 12) + 1],
            Y = Theory.NOTE_NAMES[(n[3] % 12) + 1],
            X = Theory.NOTE_NAMES[(n[4] % 12) + 1],
        }
        for i = 1, 4 do
            local s = state.strings[i]
            flashMap[s.button] = s.energy
        end
    elseif kind == "bass" then
        dpadLabels = { NEUTRAL = "1", DOWN = "L5", DOWN_LEFT = "2", LEFT = "3", UP_LEFT = "4", UP = "5", UP_RIGHT = "6", RIGHT = "7", DOWN_RIGHT = "8" }
        faceLabels = { B = "HOLD", A = "LEGATO", Y = "STAC", X = "ACCENT" }
    elseif kind == "lead" then
        dpadLabels = { NEUTRAL = "1", DOWN = "L5", DOWN_LEFT = "2", LEFT = "3", UP_LEFT = "4", UP = "5", UP_RIGHT = "6", RIGHT = "7", DOWN_RIGHT = "8" }
        faceLabels = { B = "NOTE", A = "ARP UP", Y = "ARP DOWN", X = "UP DOWN" }
        if state.arpBtn then activeMap[state.arpBtn] = true end
    elseif kind == "pad" then
        dpadLabels = { UP = "BRIGHT +", DOWN = "BRIGHT -", LEFT = "MOVE -", RIGHT = "MOVE +" }
        faceLabels = { B = "FULL", A = "OPEN", Y = "HIGH", X = "SWELL" }
        for ev in pairs(state.live) do activeMap[ev.action] = true end
    end

    local view = def.VIEW
    if view then
        dpadLabels = view.dpad or dpadLabels
        faceLabels = view.face or faceLabels
    end
    if def.getActiveButtons then activeMap = def:getActiveButtons(state) end

    return dpadLabels, faceLabels, flashMap, activeMap
end

end
