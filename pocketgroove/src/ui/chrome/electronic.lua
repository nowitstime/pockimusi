-- ============================================================================
-- src/ui/chrome/electronic.lua — Stage panels for Phase L's instruments:
-- Roller's bead strip, Breaks' slice ring, Wobble's rate panel
-- (part of src/ui/chrome.lua: adds methods to the Chrome table)
-- ============================================================================

local Config      = require("src.config")
local Theory      = require("src.theory")
local Looper      = require("src.looper")

local math_floor = math.floor
local math_min   = math.min
local math_max   = math.max
local math_sin   = math.sin
local math_cos   = math.cos
local math_pi    = math.pi

return function(Chrome)

-- ============================================================================
-- ROLLER (inside the Bass view): the last repeats as beads on a strip, newest
-- on the right, height = pitch, size = velocity (X's accents stand out); the
-- step grid of the roll's rate behind them
-- ============================================================================
function Chrome:drawPanel_roller(def, state, col, x, y, w, h)
    local C = Config.COLORS
    self:drawSunkenPanel(x, y, w, h)
    local beads = state.beads or {}
    -- the rate's grid: one tick per step over the strip's 1.6 s
    local steps = def:getRollSteps(state, state.rollBtn or "B")
    local stepSec = Looper:getLoopDuration() / (steps * Looper.bars)
    local n = math_min(64, math_floor(1.6 / math_max(stepSec, 0.01)))
    self:setColor(C.GRID, state.rollBtn and 0.9 or 0.4)
    for i = 0, n do
        local px = math_floor(x + w - 8 - i * (w - 16) / math_max(n, 1)) + 0.5
        love.graphics.line(px, y + h - 6, px, y + h - 3)
    end
    if #beads == 0 then
        love.graphics.setFont(self.fontTiny)
        self:setColor(C.DIM)
        local t = "HOLD A BUTTON TO ROLL"
        love.graphics.print(t, math_floor(x + (w - self.fontTiny:getWidth(t)) * 0.5), y + h * 0.5 - 5)
        return
    end
    local lo, hi = beads[1].semis, beads[1].semis
    for _, b in ipairs(beads) do lo, hi = math_min(lo, b.semis), math_max(hi, b.semis) end
    if hi - lo < 7 then
        local mid = (hi + lo) * 0.5
        lo, hi = mid - 3.5, mid + 3.5
    end
    local prevX, prevY
    for i, b in ipairs(beads) do
        local px = x + w - 8 - (b.age / 1.6) * (w - 16)
        local py = y + h - 10 - (b.semis - lo) / (hi - lo) * (h - 20)
        local a = math_max(0.0, 1.0 - b.age / 1.6)
        if prevX then
            self:setColor(col, 0.3 * a)
            love.graphics.line(prevX, prevY, px, py)
        end
        prevX, prevY = px, py
        local r = 1.6 + (b.vel - 0.55) * 7.0
        if i == #beads and b.age < 0.12 then
            self:drawStarGlint(px, py, r + 3.5, C.TEXT, 1.0)
        else
            self:setColor(col, a)
            love.graphics.circle("fill", px, py, r)
        end
    end
end

end
