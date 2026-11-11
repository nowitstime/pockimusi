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
    Looper:setNoteHandler(function(kind, ev, track)
        Instruments:handleLooperNote(kind, ev, track)
    end)
    Chrome:init()
end

function love.update(dt)
    dt = math_min(dt, 0.05)

    Input:update(dt)
    local controlsBlocked = Modes:update()

    Looper:update(dt)

    Instruments:update(dt, controlsBlocked)
    Synth:update(dt)
end

function love.draw()
    Chrome:draw()
end

-- Desktop-only test keys for sustained voices: hold H (bass) or G (warm pad)
local testVoices = {}
local TEST_KEYS = { h = { patch = "bass", track = 3, semis = 0 }, g = { patch = "grain_pad", track = 4, semis = 0 } }

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
    local t = TEST_KEYS[key]
    if t and not testVoices[key] then
        testVoices[key] = Synth:noteOn(t.patch, t.semis, 0.9, { track = Looper.tracks[t.track] })
    end
end

function love.keyreleased(key)
    if testVoices[key] then
        testVoices[key]:noteOff()
        testVoices[key] = nil
    end
end
