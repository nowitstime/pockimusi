-- ============================================================================
-- Pockimusi — 4-Track Procedural Handheld Groovebox
-- Target Hardware: Anbernic RG35XX Plus (640x480 4:3 IPS) & Desktop PC
-- Engine: LÖVE (Love2D 11.x) — Modular Pluggable Track/Instrument Architecture
-- ============================================================================

-- Send each log line to log.txt as it's printed (stdout is a pipe on the
-- device, and the runtime may not flush a buffer when it exits)
if io and io.stdout and io.stdout.setvbuf then io.stdout:setvbuf("line") end

local Input       = require("src.input")
local Synth       = require("src.synth")
local Looper      = require("src.looper")
local Instruments = require("src.instruments")
local Modes       = require("src.modes")
local Chrome      = require("src.ui.chrome")
local Display     = require("src.ui.display")
local Autosave    = require("src.autosave")
local Patterns    = require("src.patterns")
local Song        = require("src.song")
local Migrate     = require("src.migrate")

local math_min = math.min

-- ============================================================================
-- LÖVE (LOVE2D) LIFECYCLE CALLBACKS
-- ============================================================================

function love.load()
    love.window.setTitle("Pockimusi - 4-Track Handheld Groovebox")
    Migrate.run()              -- first boot under the new name: copy old PocketGroove saves
    Synth:init()
    Looper:init(Instruments)
    Looper:setNoteHandler(function(kind, ev, track)
        Instruments:handleLooperNote(kind, ev, track)
    end)
    Chrome:init()
    Display:init(Chrome)       -- remembered look (CRISP / PIXEL) and fullscreen
    Autosave:load()            -- the last session comes back
    Patterns.ensureSlot()      -- and always lives in a pattern slot
    Song:load()                -- the song (song mode)
    Synth:startPregen()        -- the other sounds, a little each frame
end

-- Save on the way out, and when the app goes to the background
function love.quit()
    Autosave:saveNow()
    if Song:hasSong() then Song:save() end
    return false
end

function love.focus(focused)
    if not focused then Autosave:saveNow() end
end

function love.update(dt)
    dt = math_min(dt, 0.05)

    Input:update(dt)
    local controlsBlocked = Modes:update(dt)

    Song:update(dt)            -- song mode: fades and the next switch point
    Looper:update(dt)
    Song:afterLooper()         -- the song position follows the playhead

    Instruments:update(dt, controlsBlocked)
    Synth:update(dt)
    Autosave:update(dt)
end

function love.draw()
    Chrome:draw()
end

-- Desktop-only test keys for sustained voices: hold H (bass) or G (warm pad, bright)
local testVoices = {}
local TEST_KEYS = { h = { patch = "bass_saw", track = 3, semis = 0 }, g = { patch = "pad_warm", track = 4, semis = 0, bright = 0.6, move = 0.5 } }

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "f9" then
        Looper:showToast(Display:cycleStyle())
    elseif key == "f8" then
        Looper:showToast(Chrome:cycleFonts())
    elseif key == "f11" then
        Looper:showToast(Display:toggleFullscreen())
    end
    local t = TEST_KEYS[key]
    if t and not testVoices[key] then
        testVoices[key] = Synth:noteOn(t.patch, t.semis, 0.9, { track = Looper.tracks[t.track], bright = t.bright, move = t.move })
    end
end

function love.keyreleased(key)
    if testVoices[key] then
        testVoices[key]:noteOff()
        testVoices[key] = nil
    end
end
