-- ============================================================================
-- tests/helpers.lua — tiny test framework, a fake LÖVE, and fresh module loads
-- ============================================================================

local H = {}

-- ---------------------------------------------------------------------------
-- Assertions
-- ---------------------------------------------------------------------------
local function fmt(v)
    if type(v) == "number" then return string.format("%.6g", v) end
    return tostring(v)
end

function H.eq(actual, expected, msg)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", msg or "eq", fmt(expected), fmt(actual)), 2)
    end
end

function H.near(actual, expected, msg, eps)
    eps = eps or 1e-9
    if type(actual) ~= "number" or math.abs(actual - expected) > eps then
        error(string.format("%s: expected ~%s, got %s", msg or "near", fmt(expected), fmt(actual)), 2)
    end
end

function H.truthy(v, msg)
    if not v then error((msg or "truthy") .. ": got " .. fmt(v), 2) end
end

function H.falsy(v, msg)
    if v then error((msg or "falsy") .. ": got " .. fmt(v), 2) end
end

-- ---------------------------------------------------------------------------
-- Fake LÖVE: just enough for the engine, input and drawing code to run
-- ---------------------------------------------------------------------------
local noop = function() end

local function fakeSource(soundData)
    local s = { playing = false, volume = 1.0, pitch = 1.0, looping = false, soundData = soundData }
    function s:play() self.playing = true end
    function s:stop() self.playing = false end
    function s:isPlaying() return self.playing end
    function s:setVolume(v) self.volume = v end
    function s:setPitch(p) self.pitch = p end
    function s:setLooping(l) self.looping = l end
    s.setFilter, s.setEffect = noop, noop
    return s
end

-- SoundData that keeps its samples only when H.captureSamples is set
local function fakeSoundData(n)
    local d = { n = n }
    if H.captureSamples then
        d.samples = {}
        function d:setSample(i, v) self.samples[i] = v end
    else
        d.setSample = noop
    end
    function d:getSampleCount() return self.n end
    return d
end

local function fakeFont(size)
    return {
        size = size,
        getWidth = function(_, text) return #tostring(text) * math.floor(size * 0.6) end,
        getHeight = function() return size end,
    }
end

-- Every love.graphics call is a no-op except the few that must return values
local graphics = setmetatable({
    newFont = function(size) return fakeFont(size or 12) end,
    getDimensions = function() return 640, 480 end,
}, { __index = function() return noop end })

function H.installLove()
    if not H.keepFiles then H.files = {} end
    H.diskFull = false
    H.time = 0.0
    H.keys = {}          -- keyboard keys currently held, e.g. H.keys["w"] = true
    love = {
        timer = { getTime = function() return H.time end },
        keyboard = { isDown = function(k) return H.keys[k] == true end },
        joystick = { getJoysticks = function() return {} end },
        math = {
            newRandomGenerator = function()
                local seed = 1
                return { random = function() seed = (seed * 16807) % 2147483647; return seed / 2147483647 end }
            end,
            random = function() return 0.5 end,
        },
        sound = { newSoundData = function(n) return fakeSoundData(n) end },
        audio = {
            newSource = function(sd) return fakeSource(sd) end,
            isEffectsSupported = function() return false end,
            getMaxSourceEffects = function() return 0 end,
            setEffect = noop,
        },
        graphics = H.graphicsOverride or graphics,
        filesystem = {
            -- In-memory files. Each boot starts with an empty disk unless
            -- H.keepFiles is set (to test restoring after a "reboot").
            write = function(name, text)
                if H.diskFull then return false, "disk full" end
                H.files[name] = text
                return true
            end,
            read = function(name) return H.files[name] end,
            getInfo = function(name) return H.files[name] and { type = "file", size = #H.files[name] } or nil end,
            remove = function(name) H.files[name] = nil return true end,
            getSaveDirectory = function() return "/fake/save" end,
        },
        window = { setTitle = noop },
        event = { quit = noop },
    }
end

-- ---------------------------------------------------------------------------
-- Fresh modules: every test gets new Looper / Synth / Input / ... singletons
-- ---------------------------------------------------------------------------
function H.fresh(opts)
    opts = opts or {}
    for name in pairs(package.loaded) do
        if name:sub(1, 4) == "src." or name == "main" then
            package.loaded[name] = nil
        end
    end
    H.installLove()

    local M = {
        Config      = require("src.config"),
        Theory      = require("src.theory"),
        Input       = require("src.input"),
        Synth       = require("src.synth"),
        Looper      = require("src.looper"),
        Instruments = require("src.instruments"),
    }

    -- Record every sound trigger instead of playing it
    M.triggers = {}
    if not opts.realSynth then
        M.Synth.trigger = function(_, soundName, semis, vol)
            table.insert(M.triggers, { sound = soundName, semis = semis, vol = vol })
            return { source = fakeSource() }
        end
    end

    M.Looper:init(M.Instruments)
    return M
end

-- Seconds in one full loop at the Looper's current tempo and length
function H.loopSeconds(Looper)
    return Looper:getLoopDuration()
end

-- Run Looper:update in fixed frames for `seconds`, collecting playback notes.
-- Each entry: { kind = "on"|"off"|"grace", ev, track, phase, part }, where
-- part is nil for "on" and the kind otherwise (so `not f.part` = a note-on).
function H.run(Looper, seconds, fps)
    fps = fps or 60
    local dt = 1.0 / fps
    local fired = {}
    local n = math.floor(seconds * fps + 0.5)
    for _ = 1, n do
        H.time = H.time + dt
        Looper:update(dt, function(kind, ev, track)
            table.insert(fired, { kind = kind, ev = ev, track = track, playback = true,
                                  part = (kind ~= "on") and kind or nil, phase = Looper.phase })
        end)
    end
    return fired
end

-- Record an event on a track at a given playhead phase (as a live press would)
function H.record(Looper, slot, action, phase, extra)
    Looper:seek(phase)
    local ev = { action = action, vel = 0.85 }
    for k, v in pairs(extra or {}) do ev[k] = v end
    return Looper:recordEvent(slot, ev)
end

-- Load the real main.lua with real sound generation, as the game boots
function H.loadMain()
    for name in pairs(package.loaded) do
        if name:sub(1, 4) == "src." or name == "main" then
            package.loaded[name] = nil
        end
    end
    H.installLove()
    require("main")
    love.load()
    return {
        Looper      = require("src.looper"),
        Input       = require("src.input"),
        Synth       = require("src.synth"),
        Instruments = require("src.instruments"),
        Theory      = require("src.theory"),
        Session     = require("src.session"),
        Save        = require("src.save"),
    }
end

-- Keyboard keys for each virtual button (first key from Input.KEY_MAP)
H.KEY = {
    UP = "w", DOWN = "s", LEFT = "a", RIGHT = "d",
    B = "j", A = "k", Y = "u", X = "i",
    L1 = "q", R1 = "e", L2 = "lshift", R2 = "space",
    SELECT = "tab", START = "return",
}

-- Hold / release buttons across several H.play calls
function H.hold(...) for _, b in ipairs({ ... }) do H.keys[H.KEY[b]] = true end end
function H.release(...) for _, b in ipairs({ ... }) do H.keys[H.KEY[b]] = false end end

-- Press and release quickly (3 frames down, 3 frames up)
function H.tap(...)
    H.play(0.05, { ... })
    H.play(0.05)
end

-- The current UI mode
function H.mode()
    return package.loaded["src.modes"].current
end

-- Run full game frames (update + draw) for `seconds`, with `buttons` held
function H.play(seconds, buttons)
    for _, b in ipairs(buttons or {}) do H.keys[H.KEY[b]] = true end
    local n = math.max(1, math.floor(seconds * 60 + 0.5))
    for _ = 1, n do
        H.time = H.time + 1 / 60
        love.update(1 / 60)
        love.draw()
    end
    for _, b in ipairs(buttons or {}) do H.keys[H.KEY[b]] = false end
end

return H
