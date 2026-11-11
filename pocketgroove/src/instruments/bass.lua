-- ============================================================================
-- src/instruments/bass.lua — "Compass" Ribbon Bass & Lead Instrument Module
-- ============================================================================

local Config = require("src.config")
local Theory = require("src.theory")
local Input  = require("src.input")
local Synth  = require("src.synth")
local Looper = require("src.looper")

local TWO_PI     = Config.TWO_PI
local math_sin   = math.sin
local math_cos   = math.cos
local math_floor = math.floor
local math_max   = math.max
local math_pi    = math.pi

local Bass = {
    id = "bass",
    name = "RIBBON BASS",
    shortName = "BASS",
    title = "RIBBON BASS & LEAD",
    patchName = "SUB RIBBON",
    defaultGridIndex = 3, -- 1/16
    COMPASS_DEGREE_MAP = {
        DOWN       = 1,
        DOWN_LEFT  = 2,
        LEFT       = 3,
        UP_LEFT    = 4,
        UP         = 5,
        UP_RIGHT   = 6,
        RIGHT      = 7,
        DOWN_RIGHT = 8,
        NEUTRAL    = 1,
    },
}

function Bass:newState()
    return {
        activeDegree = 1,
        lastSemis = 0,
        sustainedVoice = nil,
        oscPhase = 0.0,
        oscAmp = 0.08,
        oscFreqRatio = 1.0,
        lastArticulation = "PLUCK",
    }
end

function Bass:updateVisuals(dt, state)
    state.oscAmp = math_max(0.08, state.oscAmp - dt * 2.2)
    state.oscPhase = state.oscPhase + dt * 18.0 * state.oscFreqRatio
end

function Bass:updateInput(dt, state, track, emitEvent)
    local dirKey = Input:get8WayDirection()
    local deg = self.COMPASS_DEGREE_MAP[dirKey] or 1
    state.activeDegree = deg

    local octShift = 0
    if Input.down.L1 then octShift = octShift - 12 end
    if Input.down.R1 then octShift = octShift + 12 end
    local baseSemis = Theory:getScaleDegreeSemis(deg) + octShift

    if state.sustainedVoice and (not state.sustainedVoice.source or not state.sustainedVoice.source:isPlaying()) then
        state.sustainedVoice = nil
    end

    if Input.down.A and state.sustainedVoice then
        state.sustainedVoice.hasGlide = true
        state.sustainedVoice.targetSemis = baseSemis
        state.oscFreqRatio = 2.0 ^ (baseSemis / 12.0)
    end

    if Input.pressed.B then
        state.lastArticulation = "PLUCK"
        emitEvent({
            trackSlot = track.slot,
            instrumentId = self.id,
            action = "B",
            pitchSemis = baseSemis,
            velocity = 0.88,
            decayMod = 0.48,
        }, false)
    end

    if Input.pressed.A then
        state.lastArticulation = "GLIDE"
        emitEvent({
            trackSlot = track.slot,
            instrumentId = self.id,
            action = "A",
            pitchSemis = baseSemis,
            velocity = 0.88,
            glideFromSemis = state.lastSemis,
            decayMod = 1.35,
        }, false)
    end

    if Input.pressed.Y then
        state.lastArticulation = "+OCT POP"
        emitEvent({
            trackSlot = track.slot,
            instrumentId = self.id,
            action = "Y",
            pitchSemis = baseSemis + 12,
            velocity = 0.90,
            decayMod = 0.42,
        }, false)
    end

    if Input.pressed.X then
        state.lastArticulation = "+5TH VIB"
        emitEvent({
            trackSlot = track.slot,
            instrumentId = self.id,
            action = "X",
            pitchSemis = baseSemis + 7,
            velocity = 0.85,
            decayMod = 0.95,
        }, false)
    end
end

function Bass:triggerEvent(ev, state, isPlayback)
    local act       = ev.action
    local semis     = ev.pitchSemis or 0
    local decay     = ev.decayMod or 1.0
    local vel       = ev.velocity or 0.85
    local glideFrom = ev.glideFromSemis
    local track = Looper.tracks[ev.trackSlot or Looper.activeTrack]
    local trkVol = track and track.volume or 1.0

    local voice = Synth:trigger("bass", semis, vel, decay, glideFrom, trkVol, track)
    if voice and act == "X" then
        voice.vibrato = true
    end
    if not isPlayback and act == "A" then
        state.sustainedVoice = voice
    end
    state.lastSemis = semis
    state.oscAmp = 1.0
    state.oscFreqRatio = 2.0 ^ (semis / 12.0)
end

function Bass:drawStage(state, track, Chrome)
    local C = Config.COLORS
    local l1, r1 = Input.down.L1, Input.down.R1

    Chrome:setColor(C.TEXT)
    love.graphics.setFont(Chrome.fontLarge)
    love.graphics.print(self.title, 24, 62)

    -- Live Octave Up / Down Indicator Badges (L1 = -1 OCT, R1 = +1 OCT)
    Chrome:drawBadge(24, 86, 86, 20, "L1: OCT -1", l1 and C.VIOLET or C.PANEL_HI, l1 and C.BG or C.MUTED, Chrome.fontSmall)
    Chrome:drawBadge(116, 86, 86, 20, "R1: OCT +1", r1 and C.VIOLET or C.PANEL_HI, r1 and C.BG or C.MUTED, Chrome.fontSmall)

    local octText = "RANGE: BASE OCT"
    if l1 and not r1 then octText = "RANGE: SUB -1 OCT"
    elseif r1 and not l1 then octText = "RANGE: LEAD +1 OCT"
    end
    Chrome:drawBadge(256, 64, 170, 22, octText, (l1 or r1) and C.VIOLET or C.PANEL_HI, (l1 or r1) and C.BG or C.TEXT, Chrome.fontSmall)
    Chrome:drawBadge(434, 64, 178, 22, "LAST: " .. state.lastArticulation, C.PANEL_HI, C.VIOLET, Chrome.fontSmall)

    local cx, cy, cr = 115, 204, 72
    Chrome:setColor(C.BG)
    love.graphics.circle("fill", cx, cy, cr)
    Chrome:setColor(C.GRID)
    love.graphics.circle("line", cx, cy, cr)

    local compassNodes = {
        { deg = 1, ang = math_pi * 0.5   },
        { deg = 2, ang = math_pi * 0.75  },
        { deg = 3, ang = math_pi         },
        { deg = 4, ang = -math_pi * 0.75 },
        { deg = 5, ang = -math_pi * 0.5  },
        { deg = 6, ang = -math_pi * 0.25 },
        { deg = 7, ang = 0               },
        { deg = 8, ang = math_pi * 0.25  },
    }

    love.graphics.setFont(Chrome.fontSmall)
    for _, node in ipairs(compassNodes) do
        local nx = cx + math_cos(node.ang) * (cr - 21)
        local ny = cy + math_sin(node.ang) * (cr - 21)
        local semis = Theory:getScaleDegreeSemis(node.deg)
        local nName = Theory.NOTE_NAMES[(semis % 12) + 1]
        local isSel = (state.activeDegree == node.deg)

        if isSel then
            Chrome:setColor(C.VIOLET)
            love.graphics.line(cx, cy, nx, ny)
            love.graphics.circle("fill", nx, ny, 15)
            Chrome:setColor(C.BG)
        else
            Chrome:setColor(C.PANEL_HI)
            love.graphics.circle("fill", nx, ny, 12)
            Chrome:setColor(C.TEXT)
        end
        local label = tostring(node.deg) .. ":" .. nName
        local tw = Chrome.fontSmall:getWidth(label)
        love.graphics.print(label, math_floor(nx - tw * 0.5), math_floor(ny - 6))
    end

    local ox, oy, ow, oh = 256, 94, 356, 178
    Chrome:setColor(C.BG)
    love.graphics.rectangle("fill", ox, oy, ow, oh, 6, 6)
    Chrome:setColor(C.GRID)
    love.graphics.rectangle("line", ox, oy, ow, oh, 6, 6)

    local pts = {}
    local midY = oy + oh * 0.5
    for x = 0, ow - 4, 4 do
        local normX = x / ow
        local w = normX * TWO_PI * 3.0 * state.oscFreqRatio + state.oscPhase
        local saw = (math_sin(w) + 0.5 * math_sin(w * 2.0) + 0.25 * math_sin(w * 3.0)) * 0.6
        local py = midY + saw * (oh * 0.38) * state.oscAmp
        table.insert(pts, ox + 2 + x)
        table.insert(pts, py)
    end

    Chrome:setColor(C.VIOLET)
    love.graphics.setLineWidth(2.2)
    love.graphics.line(pts)
    love.graphics.setLineWidth(1)

    -- 4 Compact Face-Button Articulation Badges (fits cleanly inside 356px!)
    local acts = {
        { btn = "B", label = "B: PLUCK", x = 256 },
        { btn = "A", label = "A: GLIDE", x = 347 },
        { btn = "Y", label = "Y: +OCT",  x = 438 },
        { btn = "X", label = "X: +5TH",  x = 529 },
    }
    for _, a in ipairs(acts) do
        local active = Input.down[a.btn] and not Input.down.R2
        Chrome:drawBadge(a.x, 280, 83, 24, a.label,
            active and C.VIOLET or C.PANEL_HI,
            active and C.BG or C.TEXT,
            Chrome.fontSmall)
    end
end

return Bass
