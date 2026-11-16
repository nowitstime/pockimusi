-- ============================================================================
-- src/instruments/hands.lua — HAND DRUMS: two thumbs, eight pads
-- (lab/HANDS.md, lab wave 1)
--   Face buttons  = pads, as on Drums (X top, Y left, A right, B bottom)
--   D-pad         = the same four pads again, by position (MIRROR_MAP):
--                   UP = X, DOWN = B, LEFT = Y, RIGHT = A; a diagonal hits both
--   L1            = GHOST (soft, short)    R1 = ACCENT (loud, longer)
--   L1 + R1       = grid-locked note repeat (1/16, 1/12T on a triplet grid);
--                   a held D-pad direction repeats too
-- Built on Drums: same state, kits, Track page rows, event format and saves.
-- A D-pad hit is recorded under its face button. No flam, no ratchet.
-- ============================================================================

local Input = require("src.input")
local Drums = require("src.instruments.drums")

local Hands = setmetatable({
    id = "hands",
    name = "HAND DRUMS",
    shortName = "HANDS",
    title = "HAND DRUMS",
    lab = true,
    viewKind = "drums",
    eventClass = "drums",            -- Drums <-> Hand Drums keep each other's hits

    -- Which D-pad direction plays which pad: by position on the diamond.
    -- The mirror-image variant to try is { UP = "X", DOWN = "B", LEFT = "A", RIGHT = "Y" }.
    MIRROR_MAP = { UP = "X", DOWN = "B", LEFT = "Y", RIGHT = "A" },

    -- Ghost and accent: the same levels and decay as Drums' DOWN and UP
    NORMAL_VEL = 0.85, NORMAL_DECAY = 1.0,
    GHOST_VEL = 0.40, GHOST_DECAY = 0.65,
    ACCENT_VEL = 1.0, ACCENT_DECAY = 1.25,

    VIEW = {
        dpad = { UP = "X", DOWN = "B", LEFT = "Y", RIGHT = "A" },
        l1 = "GHOST", r1 = "ACCENT", both = "REPEAT",
    },
}, { __index = Drums })

-- The direction that plays a pad (built from MIRROR_MAP, so one table decides)
function Hands:directionOf(btn)
    for dir, pad in pairs(self.MIRROR_MAP) do
        if pad == btn then return dir end
    end
    return nil
end

-- A pad is hit by its face button or its direction. Both in the same frame
-- are one hit (the caller asks once per pad).
function Hands:padPressed(btn)
    local dir = self:directionOf(btn)
    return Input.pressed[btn] or (dir ~= nil and Input.pressed[dir]) or false
end

function Hands:padDown(btn)
    local dir = self:directionOf(btn)
    return Input.down[btn] or (dir ~= nil and Input.down[dir]) or false
end

-- Shoulders: L1 ghost, R1 accent; both = repeat at the normal level.
-- Never a flam or a ratchet.
function Hands:computeExpression(state)
    local l1, r1 = Input.down.L1, Input.down.R1
    local vel, decay, name = self.NORMAL_VEL, self.NORMAL_DECAY, "NORMAL"
    if l1 and not r1 then
        vel, decay, name = self.GHOST_VEL, self.GHOST_DECAY, "GHOST"
    elseif r1 and not l1 then
        vel, decay, name = self.ACCENT_VEL, self.ACCENT_DECAY, "ACCENT"
    end
    state.velocity, state.decayMod, state.expressionName = vel, decay, name
    state.orn, state.ratchet = nil, nil
end

-- Repeat only with both shoulders (one shoulder is ghost or accent here)
function Hands:getRepeatRate(track)
    if Input.down.L1 and Input.down.R1 then
        return Drums.getRepeatRate(self, track)
    end
    return nil, "OFF"
end

return Hands
