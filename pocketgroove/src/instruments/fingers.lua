-- ============================================================================
-- src/instruments/fingers.lua — FINGERS: a silent lab instrument that shows
-- what Input:getFingering() sees (lab/L0_FOUNDATION.md, step L0.6)
--
-- Press a fingering with the right thumb. The stage shows the one the game
-- sees and, for each of the nine fingerings, how many presses settled CLEAN
-- (straight from the fingering before) and how many came THROUGH another
-- fingering first (a pair that arrived as one button, then the other).
--   L1 + R1 together = reset the counts
-- It is the tool for tuning Input.FINGER_SETTLE, and goes when lab wave 1 ends.
-- ============================================================================

local Input = require("src.input")

local Fingers = {
    id = "fingers",
    name = "FINGERS",
    shortName = "FINGER",
    lab = true,
    viewKind = "lab",

    -- The nine fingerings to build on, in the order they are listed on screen
    ORDER = { "B", "A", "X", "Y", "BA", "AX", "XY", "YB", "ALL" },
    LABELS = { B = "B", A = "A", X = "X", Y = "Y", BA = "B+A", AX = "A+X", XY = "X+Y", YB = "Y+B",
               ALL = "ALL 4", NONE = "-", OTHER = "OTHER" },

    VIEW = {
        dpad = {},
        face = { B = "B", A = "A", Y = "Y", X = "X" },
        l1 = "RESET (+R1)", r1 = "RESET (+L1)", both = "RESET",
    },
}

function Fingers:newState()
    local state = { clean = {}, through = {}, other = 0 }
    self:reset(state)
    return state
end

function Fingers:reset(state)
    for _, id in ipairs(self.ORDER) do
        state.clean[id], state.through[id] = 0, 0
    end
    state.other = 0                -- settled on three buttons or an opposite pair
    state.steps = 0                -- fingering changes since the last settled one
    state.counted = true           -- the current fingering has been counted (or is NONE)
    state.shown = "NONE"           -- the fingering on screen
    state.last = nil               -- the last settled press: { id, clean }
end

-- Silent: nothing to play back
function Fingers:noteOn() end

function Fingers:updateInput(dt, state)
    if Input.down.L1 and Input.down.R1 and (Input.pressed.L1 or Input.pressed.R1) then
        self:reset(state)
    end

    local f = Input:getFingering()
    if f.changed then
        state.steps = state.steps + 1
        state.counted = false
    end
    state.shown = f.id
    if f.settled and not state.counted then
        state.counted = true
        local clean = (state.steps <= 1)
        state.steps = 0
        if f.id == "OTHER" then
            state.other = state.other + 1
        elseif f.id ~= "NONE" then
            local tally = clean and state.clean or state.through
            tally[f.id] = tally[f.id] + 1
            state.last = { id = f.id, clean = clean }
        end
    end
end

-- A page took the controls: start the next press from scratch
function Fingers:updateVisuals(dt, state, controlsBlocked)
    if controlsBlocked then
        state.steps, state.counted, state.shown = 0, true, "NONE"
    end
end

-- Large: the fingering the game sees. Small: how the last press settled.
-- Lines: clean / through counts for each of the nine.
function Fingers:getReadout(state)
    local f = Input:getFingering()
    local small
    if state.shown ~= "NONE" and not f.settled then
        small = "SETTLING..."
    elseif state.last then
        small = string.format("LAST: %s  %s", self.LABELS[state.last.id], state.last.clean and "CLEAN" or "THROUGH ANOTHER")
    else
        small = string.format("SETTLE %d MS  -  PRESS A FINGERING", math.floor(Input.FINGER_SETTLE * 1000 + 0.5))
    end

    local lines = { "CLEAN / THROUGH" }
    local function cell(id)
        return string.format("%s  %d / %d", self.LABELS[id], state.clean[id], state.through[id])
    end
    lines[#lines + 1] = cell("B") .. "     " .. cell("A")
    lines[#lines + 1] = cell("X") .. "     " .. cell("Y")
    lines[#lines + 1] = cell("BA") .. "     " .. cell("AX")
    lines[#lines + 1] = cell("XY") .. "     " .. cell("YB")
    lines[#lines + 1] = cell("ALL")
    lines[#lines + 1] = string.format("3 BUTTONS / OPPOSITE PAIR  %d", state.other)
    lines[#lines + 1] = string.format("SETTLE WINDOW %d MS", math.floor(Input.FINGER_SETTLE * 1000 + 0.5))
    return self.LABELS[state.shown] or state.shown, small, lines
end

return Fingers
