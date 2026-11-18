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
    local accent = self:getAccent(mode, instCol)
    local t = love.timer.getTime()
    local kind = self:viewKind(def)
    local view = def.VIEW or {}

    -- Frame: grid line while jamming, mode colour (with a soft glow) otherwise
    local borderCol = (mode == "NORMAL") and C.GRID or (Config.MODE_COLORS[mode] or C.GRID)
    self:drawFrame(8, 50, 624, 306, borderCol, (mode == "NORMAL") and 1 or 1.6)
    if mode ~= "NORMAL" then
        for i, a in ipairs({ 0.16, 0.08, 0.04 }) do
            self:setColor(borderCol, a)
            love.graphics.setLineWidth(1.5)
            love.graphics.rectangle("line", 8 - i, 50 - i, 624 + i * 2, 306 + i * 2, 6 + i, 6 + i)
        end
        love.graphics.setLineWidth(1)
        if mode == "ERASE" or mode == "NEW" then
            self:setColor(C.RED, 0.07)
            love.graphics.rectangle("fill", 9, 51, 622, 304, 6, 6)
        end
    end

    -- Vertical hairline dividers separating Left Zone | Center | Right Zone
    self:setColor(C.GRID, 0.55)
    love.graphics.line(198, 62, 198, 312)
    love.graphics.line(442, 62, 442, 312)

    -- Zone motifs: the instrument's own while playing, a generic astrolabe ring on settings pages
    if playMode then
        self:drawZoneMotifs(kind, instCol, t)
    else
        self:drawZoneMotifs("drums", accent, t)
    end

    -- Shoulder capsules
    local lOn, rOn = Input.down.L1, Input.down.R1
    local l1Label, r1Label = "L1: -", "R1: +"
    if mode == "TRACK" then
        l1Label, r1Label = "L1: < INSTRUMENT", "R1: INSTRUMENT >"
    elseif mode == "TRANSPORT" then
        l1Label, r1Label = "L1: SCALE <", "R1: SCALE >"
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
    local function shoulder(x, label, on)
        if on then
            self:drawCapsule(x, 58, 112, 22, label, accent, accent, C.BG, self.fontTiny)
        elseif playMode then
            self:drawCapsule(x, 58, 112, 22, label, C.GRID, C.PANEL_HI, C.MUTED, self.fontTiny)
        else
            self:drawCapsule(x, 58, 112, 22, label, accent, accent, accent, self.fontTiny, 0.08)
        end
    end
    shoulder(18, l1Label, lOn)
    shoulder(510, r1Label, rOn)

    local titleStr = def.name
    if mode == "TRACK" then titleStr = string.format("TRACK %d - SOUND", sl)
    elseif mode == "MIX" then titleStr = "4-TRACK LEVEL & MUTE MIXER"
    elseif mode == "TRANSPORT" then titleStr = "MASTER CLOCK"
    elseif mode == "ERASE" then titleStr = "SELECTIVE ERASE & UNDO"
    elseif mode == "NEW" then titleStr = "FRESH SESSION"
    elseif mode == "FX" then titleStr = "LIVE PERFORMANCE FX"
    end

    if mode == "TRACK" then
        -- the instruments are tabs (L1 / R1), in place of a title
        self:drawInstrumentTabs(track, accent)
    else
        self:setColor(playMode and C.TEXT or accent)
        love.graphics.setFont(self.fontMed)
        local tw = self.fontMed:getWidth(titleStr)
        love.graphics.print(titleStr, math_floor(320 - tw * 0.5), 62)
    end

    self:setColor(playMode and C.GRID or accent, playMode and 0.6 or 0.35)
    love.graphics.line(212, 82, 428, 82)

    -- Left: Star D-Pad & Right: Circle Face Buttons (drawn in the page accent)
    local dpadLabels, faceLabels, flashMap, activeMap = self:getControlLabels(def, state, mode)
    local activeDir = Input:get8WayDirection()
    local guideDir = playMode and def.getGuideDir and def:getGuideDir(state) or nil
    self:drawStarDpad(102, 188, dpadLabels, accent, activeDir, guideDir)
    self:drawCircleFaceButtons(538, 188, faceLabels, accent, flashMap, activeMap)

    self:setColor(C.MUTED)
    love.graphics.setFont(self.fontTiny)
    local dpadSub = {
        TRACK = "D-PAD: ROW - VALUE", MIX = "D-PAD: LEVEL", TRANSPORT = "D-PAD: TEMPO - KEY",
        ERASE = "D-PAD: UNDO", FX = "D-PAD: PUNCH-IN FX",
    }
    local instSub = { drums = "D-PAD: EXPRESSION", harp = "D-PAD: HARMONY", bass = "D-PAD: SCALE DEGREE", pad = "D-PAD: TONE", lead = "D-PAD: SCALE DEGREE" }
    local faceSub = { TRACK = "FACE: EFFECTS ON / OFF", MIX = "FACE: MUTES", TRANSPORT = "FACE: TIMING", ERASE = "FACE: CLEAR", FX = "FACE: MUTES" }
    local dpadSubtitle = dpadSub[mode] or (def.getDpadSubtitle and def:getDpadSubtitle(state))
        or instSub[def.id] or instSub[kind] or "D-PAD"
    local faceSubtitle = faceSub[mode] or "FACE: TRIGGERS"
    local dsw = self.fontTiny:getWidth(dpadSubtitle)
    local fsw = self.fontTiny:getWidth(faceSubtitle)
    love.graphics.print(dpadSubtitle, math_floor(102 - dsw * 0.5), 296)
    love.graphics.print(faceSubtitle, math_floor(538 - fsw * 0.5), 296)

    -- Center Column Visualizer (x: 204..436, y: 90..314)
    if mode == "MIX" then
        self:drawMixerView(t)
    elseif mode == "TRACK" then
        self:drawTrackPageView(def, state, track, accent)
    elseif mode == "TRANSPORT" then
        self:drawTransportView(track, instCol, accent)
    elseif mode == "ERASE" then
        self:drawEraseView(track, def)
    elseif mode == "NEW" then
        self:drawFreshSessionView()
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

    if mode == "MIX" then
        dpadLabels = { UP = "LVL+", DOWN = "LVL-", LEFT = "TRK <", RIGHT = "TRK >" }
        faceLabels = {
            B = Looper.tracks[1].muted and "M1 [M]" or "M1",
            A = Looper.tracks[2].muted and "M2 [M]" or "M2",
            Y = Looper.tracks[3].muted and "M3 [M]" or "M3",
            X = Looper.tracks[4].muted and "M4 [M]" or "M4",
        }
    elseif mode == "TRACK" then
        local fx = Looper.tracks[Looper.activeTrack].fx
        dpadLabels = { UP = "ROW UP", DOWN = "ROW DOWN", LEFT = "VALUE <", RIGHT = "VALUE >" }
        faceLabels = { B = "SPACE", A = "ECHO", Y = "DRIVE", X = "TONE" }
        for btn, slot in pairs(Looper.FX_SLOTS) do
            activeMap[btn] = fx.on[slot]
        end
    elseif mode == "TRANSPORT" then
        local swingHeld = Input.down.Y
        dpadLabels = swingHeld and { UP = "SWING +", DOWN = "SWING -", LEFT = "KEY <", RIGHT = "KEY >" }
            or { UP = "BPM+", DOWN = "BPM-", LEFT = "KEY <", RIGHT = "KEY >" }
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
        faceLabels = { B = "", A = "", Y = "", X = "" }
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

    return dpadLabels, faceLabels, flashMap, activeMap
end

end
