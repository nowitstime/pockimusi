-- ============================================================================
-- src/instruments/harp.lua — "Pocket Omnichord" Strum Harp Instrument Module
-- ============================================================================

local Config = require("src.config")
local Theory = require("src.theory")
local Input  = require("src.input")
local Synth  = require("src.synth")
local Looper = require("src.looper")

local math_sin   = math.sin
local math_cos   = math.cos
local math_floor = math.floor
local math_max   = math.max
local math_pi    = math.pi

local Harp = {
    id = "harp",
    name = "CHORD HARP",
    shortName = "HARP",
    title = "OMNICHORD HARP",
    patchName = "STARLIGHT PLUCK",
    defaultGridIndex = 5, -- FREE
    BUTTON_TO_INDEX = { B = 1, A = 2, Y = 3, X = 4 },
}

function Harp:newState()
    return {
        currentChord = nil,
        strings = {
            { button = "B", label = "STR 1 (ROOT)", energy = 0.0, phase = 0.0, lastSemis = 0 },
            { button = "A", label = "STR 2 (3RD)",  energy = 0.0, phase = 0.0, lastSemis = 4 },
            { button = "Y", label = "STR 3 (7TH)",  energy = 0.0, phase = 0.0, lastSemis = 7 },
            { button = "X", label = "STR 4 (9TH)",  energy = 0.0, phase = 0.0, lastSemis = 12 },
        },
    }
end

function Harp:updateVisuals(dt, state, controlsBlocked)
    for i = 1, 4 do
        local s = state.strings[i]
        if s.energy > 0 then
            s.energy = math_max(0.0, s.energy - dt * 1.65)
            s.phase = s.phase + dt * (42.0 + i * 9.0)
        end
    end

    local dirKey = controlsBlocked and "NEUTRAL" or Input:get8WayDirection()
    state.currentChord = Theory:getChordForDirection(dirKey, Input.down.L1, Input.down.R1)
end

function Harp:updateInput(dt, state, track, emitEvent)
    local chord = state.currentChord or Theory:getChordForDirection("NEUTRAL", false, false)
    local faceButtons = { "B", "A", "Y", "X" }

    for _, btn in ipairs(faceButtons) do
        local stringIdx = self.BUTTON_TO_INDEX[btn]
        if Input.pressed[btn] then
            local noteSemis = chord.notes[stringIdx] or 0
            emitEvent({
                trackSlot = track.slot,
                instrumentId = self.id,
                action = btn,
                pitchSemis = noteSemis,
                velocity = 0.82,
                chordName = chord.name,
                decayMod = 1.0,
            }, false)
        end
    end
end

function Harp:triggerEvent(ev, state)
    local act   = ev.action
    local semis = ev.pitchSemis or 0
    local decay = ev.decayMod or 1.0
    local vel   = ev.velocity or 0.85
    local track = Looper.tracks[ev.trackSlot or Looper.activeTrack]
    local trkVol = track and track.volume or 1.0

    Synth:trigger("harp", semis, vel, decay, nil, trkVol, track)
    local sIdx = self.BUTTON_TO_INDEX[act] or 1
    local str = state.strings[sIdx]
    if str then
        str.energy = 1.0
        str.lastSemis = semis
    end
end

function Harp:drawStage(state, track, Chrome)
    local C = Config.COLORS
    local chord = state.currentChord or Theory:getChordForDirection("NEUTRAL", false, false)

    Chrome:setColor(C.MUTED)
    love.graphics.setFont(Chrome.fontSmall)
    love.graphics.print(self.title, 24, 62)

    Chrome:setColor(C.CYAN)
    love.graphics.setFont(Chrome.fontHuge)
    love.graphics.print(chord.name, 24, 78)

    Chrome:drawBadge(156, 84, 54, 24, chord.roman, C.PANEL_HI, C.TEXT, Chrome.fontMed)

    -- Live L1 / R1 Voicing Indicator Badges
    local l1, r1 = Input.down.L1, Input.down.R1
    Chrome:drawBadge(24, 114, 90, 20, "L1: 7TH/9TH", l1 and C.CYAN or C.PANEL_HI, l1 and C.BG or C.MUTED, Chrome.fontSmall)
    Chrome:drawBadge(120, 114, 90, 20, "R1: SUS4/+8", r1 and C.CYAN or C.PANEL_HI, r1 and C.BG or C.MUTED, Chrome.fontSmall)

    local wx, wy, wr = 115, 220, 64
    Chrome:setColor(C.BG)
    love.graphics.circle("fill", wx, wy, wr)
    Chrome:setColor(C.GRID)
    love.graphics.circle("line", wx, wy, wr)

    local dirs = {
        { key = "UP",         roman = "I",    ang = -math_pi * 0.5  },
        { key = "UP_RIGHT",   roman = "iii",  ang = -math_pi * 0.25 },
        { key = "RIGHT",      roman = "V",    ang = 0               },
        { key = "DOWN_RIGHT", roman = "IVm",  ang = math_pi * 0.25  },
        { key = "DOWN",       roman = "vi",   ang = math_pi * 0.5   },
        { key = "DOWN_LEFT",  roman = "bVII", ang = math_pi * 0.75  },
        { key = "LEFT",       roman = "IV",   ang = math_pi         },
        { key = "UP_LEFT",    roman = "ii",   ang = -math_pi * 0.75 },
    }

    love.graphics.setFont(Chrome.fontSmall)
    for _, node in ipairs(dirs) do
        local nx = wx + math_cos(node.ang) * (wr - 20)
        local ny = wy + math_sin(node.ang) * (wr - 20)
        local isSel = (chord.dirKey == node.key) or (chord.dirKey == "NEUTRAL" and node.key == "UP")
        if isSel then
            Chrome:setColor(C.CYAN)
            love.graphics.circle("fill", nx, ny, 14)
            Chrome:setColor(C.BG)
        else
            Chrome:setColor(C.MUTED)
        end
        local tw = Chrome.fontSmall:getWidth(node.roman)
        love.graphics.print(node.roman, math_floor(nx - tw * 0.5), math_floor(ny - 6))
    end

    local harpLeft = 248
    local harpTop = 70
    local harpBottom = 304
    local stringSpacing = 96

    for i = 1, 4 do
        local str = state.strings[i]
        local sx = harpLeft + (i - 1) * stringSpacing
        local noteSemis = chord.notes[i] or 0
        local noteName = Theory.NOTE_NAMES[(noteSemis % 12) + 1] .. tostring(4 + math_floor(noteSemis / 12))

        Chrome:drawBadge(sx - 34, harpTop, 68, 22, str.button .. " : " .. noteName,
            str.energy > 0.1 and C.CYAN or C.PANEL_HI,
            str.energy > 0.1 and C.BG or C.TEXT,
            Chrome.fontSmall)

        local segments = 24
        local pts = {}
        local amp = str.energy * 16.0
        for seg = 0, segments do
            local frac = seg / segments
            local py = (harpTop + 28) + frac * (harpBottom - harpTop - 36)
            local standingWave = math_sin(frac * math_pi) * math_sin(str.phase + frac * 6.0)
            local px = sx + standingWave * amp
            table.insert(pts, px)
            table.insert(pts, py)
        end

        if str.energy > 0.02 then
            Chrome:setColor(C.CYAN, 0.35 * str.energy)
            love.graphics.setLineWidth(6)
            love.graphics.line(pts)
        end

        Chrome:setColor(str.energy > 0.05 and C.CYAN or C.MUTED)
        love.graphics.setLineWidth(2.2)
        love.graphics.line(pts)

        Chrome:setColor(C.GRID)
        love.graphics.circle("fill", sx, harpBottom - 6, 5)
    end
    love.graphics.setLineWidth(1)
end

return Harp
