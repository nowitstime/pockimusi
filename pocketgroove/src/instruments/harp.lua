-- ============================================================================
-- src/instruments/harp.lua — "Pocket Omnichord" Strum Harp Instrument Module
-- ============================================================================

local Theory = require("src.theory")
local Input  = require("src.input")
local Synth  = require("src.synth")
local Looper = require("src.looper")

local math_max   = math.max

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
        colour = "TRIAD",          -- Track page COLOUR row (Theory.COLOURS)
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
    state.currentChord = Theory:getChordForDirection(dirKey, Input.down.L1, Input.down.R1, state.colour)
end

-- ---------------------------------------------------------------------------
-- Track page rows: one sound row (PATCH) and the COLOUR setting
-- ---------------------------------------------------------------------------
function Harp:getSoundRows(state)
    return {
        { key = "PATCH", label = "PATCH", value = self.title },
        { key = "COLOUR", label = "COLOUR", value = state.colour, kind = "setting",
          hint = string.format("%d/%d", self:colourIndex(state), #Theory.COLOURS) },
    }
end

function Harp:colourIndex(state)
    for i, c in ipairs(Theory.COLOURS) do
        if c == state.colour then return i end
    end
    return 1
end

function Harp:cycleSetting(state, key, delta)
    if key ~= "COLOUR" then return end
    local n = #Theory.COLOURS
    state.colour = Theory.COLOURS[((self:colourIndex(state) - 1 + delta) % n) + 1]
    Looper:showToast("CHORD COLOUR: " .. state.colour)
end

function Harp:updateInput(dt, state, track, emitEvent)
    local chord = state.currentChord or Theory:getChordForDirection("NEUTRAL", false, false, state.colour)

    for _, btn in ipairs({ "B", "A", "Y", "X" }) do
        if Input.pressed[btn] then
            -- One-shot; the chord it belongs to is stored for Harmony (Phase D)
            emitEvent({
                action = btn,
                semis = chord.notes[self.BUTTON_TO_INDEX[btn]] or 0,
                vel = 0.82,
                decay = 1.0,
                chord = { name = chord.name, roman = chord.roman, colour = chord.colour },
            })
        end
    end
end

function Harp:noteOn(ev, state, track)
    local semis = ev.semis or 0
    Synth:trigger("harp", semis, ev.vel or 0.85, ev.decay or 1.0, nil, track.volume, track)
    local str = state.strings[self.BUTTON_TO_INDEX[ev.action] or 1]
    if str then
        str.energy = 1.0
        str.lastSemis = semis
    end
end

-- Save / load (Phase C)
function Harp:saveState(state)
    return { colour = state.colour }
end

function Harp:loadState(state, data)
    if type(data) ~= "table" then return end
    for _, c in ipairs(Theory.COLOURS) do
        if data.colour == c then state.colour = c end
    end
end

return Harp
