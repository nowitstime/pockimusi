-- ============================================================================
-- src/ui/chrome/prims.lua — Primitives: glint, diamond, tags, frames, capsules; view kind and page accent
-- (part of src/ui/chrome.lua: adds methods to the Chrome table)
-- ============================================================================

local Config      = require("src.config")
local Theory      = require("src.theory")
local Input       = require("src.input")
local Synth       = require("src.synth")
local Looper      = require("src.looper")
local Instruments = require("src.instruments")
local Modes       = require("src.modes")
local Harmony     = require("src.harmony")
local Display     = require("src.ui.display")

local clamp      = Config.clamp
local math_floor = math.floor
local math_min   = math.min
local math_max   = math.max
local math_sin   = math.sin
local math_cos   = math.cos
local math_abs   = math.abs
local math_pi    = math.pi

return function(Chrome)

-- ============================================================================
-- CELESTIAL VECTOR PRIMITIVES
-- ============================================================================

-- 4-point concave star glint sparkle (✦)
function Chrome:drawStarGlint(cx, cy, r, col, alpha)
    alpha = alpha or 1.0
    self:setColor(col, alpha)
    local inner = r * 0.22
    local pts = {
        cx, cy - r,
        cx + inner, cy - inner,
        cx + r, cy,
        cx + inner, cy + inner,
        cx, cy + r,
        cx - inner, cy + inner,
        cx - r, cy,
        cx - inner, cy - inner,
    }
    -- Fill as 8 convex triangles from center to avoid non-convex triangulation overlapping
    for i = 1, 8 do
        local p1x = pts[(i - 1) * 2 + 1]
        local p1y = pts[(i - 1) * 2 + 2]
        local nextIdx = (i % 8) + 1
        local p2x = pts[(nextIdx - 1) * 2 + 1]
        local p2y = pts[(nextIdx - 1) * 2 + 2]
        love.graphics.polygon("fill", cx, cy, p1x, p1y, p2x, p2y)
    end
end

-- Crisp 4-vertex diamond (◇ / ◆)
function Chrome:drawDiamond(cx, cy, r, fillCol, strokeCol)
    local pts = { cx, cy - r, cx + r, cy, cx, cy + r, cx - r, cy }
    if fillCol then
        self:setColor(fillCol)
        love.graphics.polygon("fill", pts)
    end
    if strokeCol then
        self:setColor(strokeCol)
        love.graphics.polygon("line", pts)
    end
end

-- Squarish-rounded tag (rx=4)
function Chrome:drawTag(x, y, w, h, text, strokeCol, fillCol, textCol, font, fillAlpha)
    fillCol = fillCol or Config.COLORS.PANEL_HI
    strokeCol = strokeCol or Config.COLORS.GRID
    textCol = textCol or Config.COLORS.TEXT
    font = font or self.fontSmall
    fillAlpha = fillAlpha or 1.0

    self:setColor(fillCol, fillAlpha)
    love.graphics.rectangle("fill", x, y, w, h, 4, 4)

    self:setColor(strokeCol)
    love.graphics.rectangle("line", x, y, w, h, 4, 4)

    self:setColor(textCol)
    love.graphics.setFont(font)
    local tw = font:getWidth(text)
    local th = font:getHeight()
    love.graphics.print(text, math_floor(x + (w - tw) * 0.5), math_floor(y + (h - th) * 0.5))
end

-- Architectural frame (rx=6)
function Chrome:drawFrame(x, y, w, h, strokeCol, lineWidth)
    local C = Config.COLORS
    self:setColor(C.PANEL)
    love.graphics.rectangle("fill", x, y, w, h, 6, 6)

    self:setColor(strokeCol or C.GRID)
    love.graphics.setLineWidth(lineWidth or 1)
    love.graphics.rectangle("line", x, y, w, h, 6, 6)
    love.graphics.setLineWidth(1)
end

-- Pill-shaped capsule tag
function Chrome:drawCapsule(x, y, w, h, text, strokeCol, fillCol, textCol, font, fillAlpha)
    local C = Config.COLORS
    font = font or self.fontTiny
    local r = h * 0.5
    if fillCol then
        self:setColor(fillCol, fillAlpha or 1.0)
        love.graphics.rectangle("fill", x, y, w, h, r, r)
    end
    if strokeCol then
        self:setColor(strokeCol)
        love.graphics.rectangle("line", x, y, w, h, r, r)
    end
    self:setColor(textCol or C.TEXT)
    love.graphics.setFont(font)
    local tw = font:getWidth(text)
    love.graphics.print(text, math_floor(x + (w - tw) * 0.5), math_floor(y + (h - font:getHeight()) * 0.5))
end

-- Lay out capsules centred on cx; items = { {text, stroke, fill, textCol, fillAlpha} }
function Chrome:drawCapsuleRow(cx, y, h, items, gap)
    gap = gap or 5
    local font = self.fontTiny
    local widths, total = {}, 0
    for i, it in ipairs(items) do
        widths[i] = font:getWidth(it[1]) + 18
        total = total + widths[i] + (i > 1 and gap or 0)
    end
    local x = cx - total * 0.5
    for i, it in ipairs(items) do
        self:drawCapsule(math_floor(x), y, widths[i], h, it[1], it[2], it[3], it[4], font, it[5])
        x = x + widths[i] + gap
    end
end

-- Which stage view draws an instrument: its `viewKind` ("drums", "bass",
-- "lab"), or the view that goes with its id. An instrument with neither gets
-- the plain lab view.
Chrome.VIEW_KINDS = { drums = true, harp = true, bass = true, lead = true, pad = true, chords = true, strum = true, lab = true }

function Chrome:viewKind(def)
    local kind = def.viewKind or def.id
    return self.VIEW_KINDS[kind] and kind or "lab"
end

-- The colour of the instrument in a track slot
function Chrome:trackColor(slot)
    local def = Instruments:getTrackInstrument(slot)
    return (def and Config.INST_COLORS[def.id]) or Config.TRACK_COLORS[slot]
end

function Chrome:isPlayMode(mode)
    return mode == "NORMAL" or mode == "REC_LATCH" or mode == "REC_HOLD"
end

-- The page's colour: instrument colour while playing, mode colour on a settings page
function Chrome:getAccent(mode, instCol)
    if self:isPlayMode(mode) then return instCol end
    return Config.MODE_COLORS[mode] or instCol
end

end
