-- ============================================================================
-- src/instruments/grain.lua — "Granular Cloud" Texture Pad Instrument Module
-- ============================================================================

local Config = require("src.config")
local Theory = require("src.theory")
local Input  = require("src.input")
local Synth  = require("src.synth")

local clamp      = Config.clamp
local math_floor = math.floor

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
        spawners = {},             -- one per sounding note: [ev] = { timer, live }
        live = { semis = 0, interval = 0.1, decay = 1.0 },  -- current D-pad/shoulder settings
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

function Grain:updateInput(dt, state, track, emitEvent, holdNote)
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

    -- Scan walks scale degrees 1, 2, 3, 5, 6, 8 (major pentatonic in a major key,
    -- and always inside the current scale)
    local scanDegrees = { 1, 2, 3, 5, 6, 8 }
    local scanIdx = clamp(math_floor(state.scanPos * (#scanDegrees - 1) + 1.5), 1, #scanDegrees)
    local scanSemis = Theory:getScaleDegreeSemis(scanDegrees[scanIdx]) + shoulderSemis

    -- Live settings: a held note follows the D-pad and shoulders while held
    state.live.semis = scanSemis
    state.live.interval = self:grainInterval(state.density)
    state.live.decay = self:grainDecay(state.density)

    -- Each press is one held note (one event with a length when recorded)
    for _, btn in ipairs({ "B", "A", "Y", "X" }) do
        if Input.pressed[btn] then
            holdNote({
                action = btn,
                semis = scanSemis,
                scanPos = state.scanPos,
                density = state.density,
                vel = 0.55,
            })
        end
    end
end

function Grain:grainInterval(density) return 0.045 + (1.0 - density) * 0.12 end
function Grain:grainDecay(density) return 0.45 + (1.0 - density) * 0.95 end

function Grain:spawnGrain(state, track, action, semis, decay, scanPos, vel)
    local slot = self.SLOT_MAP[action]
    if not slot then return end
    local jitter = (love.math.random() - 0.5) * 0.18
    Synth:trigger(slot.sound, semis + jitter, vel or 0.55, decay, nil, track.volume, track)
    self:spawnParticle(state, action, semis, scanPos)
end

function Grain:noteOn(ev, state, track, isPlayback)
    if (ev.len or 0) == 0 and isPlayback then
        -- A note without length (shouldn't happen): one grain
        self:spawnGrain(state, track, ev.action, ev.semis or 0, self:grainDecay(ev.density or 0.55), ev.scanPos, ev.vel)
        return
    end
    state.spawners[ev] = { timer = 0.0, live = not isPlayback }
end

function Grain:noteOff(ev, state)
    state.spawners[ev] = nil
end

-- Spawn grains for every sounding note (live: current settings; playback:
-- the settings stored on the event)
function Grain:updateVoices(dt, state, track)
    for ev, sp in pairs(state.spawners) do
        sp.timer = sp.timer - dt
        if sp.timer <= 0.0 then
            local semis, interval, decay, scan
            if sp.live then
                semis, interval, decay, scan = state.live.semis, state.live.interval, state.live.decay, state.scanPos
            else
                local d = ev.density or 0.55
                semis, interval, decay, scan = ev.semis or 0, self:grainInterval(d), self:grainDecay(d), ev.scanPos
            end
            self:spawnGrain(state, track, ev.action, semis, decay, scan, ev.vel)
            sp.timer = sp.timer + interval
            if sp.timer < 0 then sp.timer = interval end
        end
    end
end

-- Save / load (Phase C)
function Grain:saveState(state)
    return { scanPos = state.scanPos, density = state.density }
end

function Grain:loadState(state, data)
    if type(data) ~= "table" then return end
    if type(data.scanPos) == "number" then state.scanPos = clamp(data.scanPos, 0.0, 1.0) end
    if type(data.density) == "number" then state.density = clamp(data.density, 0.1, 1.0) end
end

return Grain
