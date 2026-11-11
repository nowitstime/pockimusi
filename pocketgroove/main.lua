-- ============================================================================
-- PocketGroove — 4-Track Procedural Handheld Groovebox
-- Target Hardware: Anbernic RG35XX Plus (640x480 4:3 IPS) & Desktop PC
-- Engine: LÖVE (Love2D 11.x) — Modular Pluggable Track/Instrument Architecture
-- ============================================================================

local Input       = require("src.input")
local Synth       = require("src.synth")
local Looper      = require("src.looper")
local Instruments = require("src.instruments")
local Modes       = require("src.modes")
local Chrome      = require("src.ui.chrome")

local math_min = math.min

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
    local controlsBlocked = Modes:update()

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
