-- ============================================================================
-- src/instruments/grain.lua — "Granular Cloud" Texture Pad Instrument Module
-- ============================================================================

local Config = require("src.config")
local Theory = require("src.theory")
local Input  = require("src.input")
local Synth  = require("src.synth")
local Looper = require("src.looper")

local clamp      = Config.clamp
local math_sin   = math.sin
local math_cos   = math.cos
local math_floor = math.floor
local math_abs   = math.abs

local Grain = {
    id = "grain",
    name = "GRANULAR PAD",
    shortName = "GRAN",
    title = "GRANULAR CLOUD PAD",
    patchName = "4 CLOUD TEXTURES",
    defaultGridIndex = 5, -- FREE
    SLOT_MAP = {
        B = { sound = "grain_pad",   name = "WARM PAD"   },
        A = { sound = "grain_bell",  name = "GLASS BELL" },
        Y = { sound = "grain_choir", name = "CHOIR"      },
        X = { sound = "grain_drone", name = "SUB DRONE"  },
    },
}

function Grain:newState()
    return {
        scanPos = 0.5,
        density = 0.55,
        spawnTimers = { B = 0.0, A = 0.0, Y = 0.0, X = 0.0 },
        particles = {},
    }
end

function Grain:spawnParticle(state, button, pitchSemis, scanPos)
    if #state.particles > 48 then
        table.remove(state.particles, 1)
    end
    local slotColors = {
        B = Config.COLORS.MINT,
        A = Config.COLORS.CYAN,
        Y = Config.COLORS.VIOLET,
        X = Config.COLORS.ORANGE,
    }
    local xBase = 90 + (scanPos or state.scanPos) * 460
    local yBase = 215 - (pitchSemis * 3.5) + (love.math.random() * 44 - 22)
    table.insert(state.particles, {
        x = xBase + (love.math.random() * 36 - 18),
        y = clamp(yBase, 84, 336),
        vx = (love.math.random() - 0.5) * 35,
        vy = -18 - love.math.random() * 28,
        radius = 5 + (1.0 - state.density) * 14,
        life = 1.0,
        color = slotColors[button] or Config.COLORS.MINT,
    })
end

function Grain:updateVisuals(dt, state)
    for i = #state.particles, 1, -1 do
        local p = state.particles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.life = p.life - dt * 1.4
        if p.life <= 0 then
            table.remove(state.particles, i)
        end
    end
end

function Grain:updateInput(dt, state, track, emitEvent)
    if Input.down.LEFT then
        state.scanPos = clamp(state.scanPos - dt * 0.65, 0.0, 1.0)
    elseif Input.down.RIGHT then
        state.scanPos = clamp(state.scanPos + dt * 0.65, 0.0, 1.0)
    end

    if Input.down.UP then
        state.density = clamp(state.density + dt * 0.65, 0.1, 1.0)
    elseif Input.down.DOWN then
        state.density = clamp(state.density - dt * 0.65, 0.1, 1.0)
    end

    -- L1 = Octave Down (-12st), R1 = Octave Up (+12st), L1+R1 = +7st Fifth
    local shoulderSemis = 0
    if Input.down.L1 and Input.down.R1 then
        shoulderSemis = 7
    elseif Input.down.L1 then
        shoulderSemis = -12
    elseif Input.down.R1 then
        shoulderSemis = 12
    end

    local harmonicSteps = { 0, 2, 4, 7, 9, 12 }
    local scanIdx = clamp(math_floor(state.scanPos * (#harmonicSteps - 1) + 1.5), 1, #harmonicSteps)
    local scanSemis = Theory:getRootSemis() + harmonicSteps[scanIdx] + shoulderSemis

    local grainInterval = 0.045 + (1.0 - state.density) * 0.12
    local grainDecay = 0.45 + (1.0 - state.density) * 0.95
    local faceButtons = { "B", "A", "Y", "X" }

    for _, btn in ipairs(faceButtons) do
        if Input.down[btn] then
            state.spawnTimers[btn] = state.spawnTimers[btn] - dt
            if Input.pressed[btn] or state.spawnTimers[btn] <= 0.0 then
                state.spawnTimers[btn] = grainInterval
                local jitter = (love.math.random() - 0.5) * 0.18
                emitEvent({
                    trackSlot = track.slot,
                    instrumentId = self.id,
                    action = btn,
                    pitchSemis = scanSemis + jitter,
                    velocity = 0.60,
                    decayMod = grainDecay,
                    scanPos = state.scanPos,
                }, false)
            end
        else
            state.spawnTimers[btn] = 0.0
        end
    end
end

function Grain:triggerEvent(ev, state)
    local act   = ev.action
    local semis = ev.pitchSemis or 0
    local decay = ev.decayMod or 1.0
    local slot  = self.SLOT_MAP[act]
    if slot then
        local track = Looper.tracks[ev.trackSlot or Looper.activeTrack]
        local trkVol = track and track.volume or 1.0
        Synth:trigger(slot.sound, semis, 0.55, decay, nil, trkVol, track)
        self:spawnParticle(state, act, semis, ev.scanPos or state.scanPos)
    end
end

function Grain:drawStage(state, track, Chrome)
    local C = Config.COLORS
    local l1, r1 = Input.down.L1, Input.down.R1

    Chrome:setColor(C.TEXT)
    love.graphics.setFont(Chrome.fontLarge)
    love.graphics.print(self.title, 24, 62)

    -- Live L1 / R1 Octave Indicator Badges
    Chrome:drawBadge(234, 62, 86, 22, "L1: OCT -1", l1 and not r1 and C.MINT or C.PANEL_HI, l1 and not r1 and C.BG or C.MUTED, Chrome.fontSmall)
    Chrome:drawBadge(326, 62, 86, 22, "R1: OCT +1", r1 and not l1 and C.MINT or C.PANEL_HI, r1 and not l1 and C.BG or C.MUTED, Chrome.fontSmall)

    love.graphics.setFont(Chrome.fontSmall)
    Chrome:setColor(C.MINT)
    love.graphics.print(string.format("SCAN:%d%%  DENS:%d%%",
        math_floor(state.scanPos * 100), math_floor(state.density * 100)), 476, 67)

    local gx, gy, gw, gh = 24, 92, 592, 184
    Chrome:setColor(C.BG)
    love.graphics.rectangle("fill", gx, gy, gw, gh, 6, 6)
    Chrome:setColor(C.GRID)
    love.graphics.rectangle("line", gx, gy, gw, gh, 6, 6)

    Chrome:setColor(C.DIM, 0.45)
    local midY = gy + gh * 0.5
    for i = 0, 110 do
        local frac = i / 110
        local bx = gx + 12 + frac * (gw - 24)
        local bh = (math_sin(frac * 19.0) * 0.5 + math_cos(frac * 37.0) * 0.5) * (gh * 0.36)
        love.graphics.line(bx, midY - math_abs(bh), bx, midY + math_abs(bh))
    end

    local scanX = gx + 16 + state.scanPos * (gw - 32)
    Chrome:setColor(C.MINT, 0.7)
    love.graphics.setLineWidth(2)
    love.graphics.line(scanX, gy + 6, scanX, gy + gh - 6)
    love.graphics.setLineWidth(1)

    for i = 1, #state.particles do
        local p = state.particles[i]
        Chrome:setColor(p.color, p.life * 0.45)
        love.graphics.circle("fill", p.x, p.y, p.radius)
        Chrome:setColor(p.color, p.life * 0.95)
        love.graphics.circle("line", p.x, p.y, p.radius)
    end

    local slots = {
        { btn = "B", label = "B: WARM PAD",   x = 24  },
        { btn = "A", label = "A: GLASS BELL", x = 176 },
        { btn = "Y", label = "Y: CHOIR",      x = 328 },
        { btn = "X", label = "X: SUB DRONE",  x = 480 },
    }
    for _, s in ipairs(slots) do
        local active = Input.down[s.btn] and not Input.down.R2
        Chrome:drawBadge(s.x, 284, 136, 26, s.label,
            active and C.MINT or C.PANEL_HI,
            active and C.BG or C.TEXT,
            Chrome.fontSmall)
    end
end

return Grain
