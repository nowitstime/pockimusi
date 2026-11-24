-- ============================================================================
-- src/ui/chrome/dpad.lua — Zone 1: the 8-point star D-pad
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
-- ZONE 1: 8-POINT WIREFRAME STAR D-PAD (cx=102, cy=188)
-- ============================================================================
-- `guideDirKey` (optional): a direction to suggest (an instrument's
-- def:getGuideDir); its label is lit in the accent with a dot under it
function Chrome:drawStarDpad(cx, cy, labels, col, activeDirKey, guideDirKey)
    local C = Config.COLORS
    local cardR = 55
    local diagR = 39
    local innerR = 17

    local shade = Config.shade

    -- Outer astrolabe ring with 4 intercardinal diamond ticks
    self:setColor(shade(col, 0.45))
    love.graphics.circle("line", cx, cy, 68)
    for i = 0, 3 do
        local a = (math_pi * 0.25) + i * (math_pi * 0.5)
        self:drawDiamond(cx + math_cos(a) * 68, cy + math_sin(a) * 68, 2.4, shade(col, 0.7))
    end

    local dirDefs = {
        { k = "UP",         ang = -math_pi * 0.5,  r = cardR, lr = cardR + 15, short = "U"  },
        { k = "UP_RIGHT",   ang = -math_pi * 0.25, r = diagR, lr = diagR + 15, short = "UR" },
        { k = "RIGHT",      ang = 0,               r = cardR, lr = cardR + 16, short = "R"  },
        { k = "DOWN_RIGHT", ang = math_pi * 0.25,  r = diagR, lr = diagR + 15, short = "DR" },
        { k = "DOWN",       ang = math_pi * 0.5,   r = cardR, lr = cardR + 16, short = "D"  },
        { k = "DOWN_LEFT",  ang = math_pi * 0.75,  r = diagR, lr = diagR + 15, short = "DL" },
        { k = "LEFT",       ang = math_pi,         r = cardR, lr = cardR + 16, short = "L"  },
        { k = "UP_LEFT",    ang = -math_pi * 0.75, r = diagR, lr = diagR + 15, short = "UL" },
    }

    -- Build star polygon points and decompose fill into convex triangles
    local starPts = {}
    local tipCoords = {}
    local ringVerts = {}
    for i, d in ipairs(dirDefs) do
        local tx = cx + math_cos(d.ang) * d.r
        local ty = cy + math_sin(d.ang) * d.r
        local vAng = d.ang + (math_pi / 8.0)
        local vx = cx + math_cos(vAng) * innerR
        local vy = cy + math_sin(vAng) * innerR
        table.insert(starPts, tx)
        table.insert(starPts, ty)
        table.insert(starPts, vx)
        table.insert(starPts, vy)
        table.insert(ringVerts, { x = tx, y = ty })
        table.insert(ringVerts, { x = vx, y = vy })
        tipCoords[d.k] = { tx = tx, ty = ty, vx = vx, vy = vy, d = d }
    end

    -- Star fill rendered as 16 convex triangles from center to avoid triangulation overlap at vertex 1 (UP)
    self:setColor(shade(col, 0.16))
    local nVerts = #ringVerts
    for i = 1, nVerts do
        local v1 = ringVerts[i]
        local v2 = ringVerts[(i % nVerts) + 1]
        love.graphics.polygon("fill", cx, cy, v1.x, v1.y, v2.x, v2.y)
    end

    -- Clean single wireframe outline
    self:setColor(shade(col, 0.6))
    love.graphics.polygon("line", starPts)

    -- Internal axis lines
    self:setColor(shade(col, 0.35))
    for _, d in ipairs(dirDefs) do
        local coord = tipCoords[d.k]
        love.graphics.line(cx, cy, coord.tx, coord.ty)
    end

    -- Center core sparkle
    local anyActive = (activeDirKey and activeDirKey ~= "NEUTRAL")
    self:drawStarGlint(cx, cy, anyActive and 10 or 7, anyActive and C.TEXT or shade(col, 0.8), 1.0)

    -- Optional label for the resting D-pad (e.g. the bass root), lit while neutral
    if labels and labels.NEUTRAL then
        love.graphics.setFont(self.fontTiny)
        self:setColor(anyActive and C.MUTED or col, anyActive and 0.6 or 1.0)
        if guideDirKey == "NEUTRAL" and anyActive then self:setColor(col) end
        local t = labels.NEUTRAL
        love.graphics.print(t, math_floor(cx - self.fontTiny:getWidth(t) * 0.5), cy + 12)
        if guideDirKey == "NEUTRAL" then
            self:setColor(col)
            love.graphics.circle("fill", cx, cy + 12 + self:lineHeight(self.fontTiny) + 2, 1.8)
        end
    end

    -- Draw tips, labels, and active star point outlines
    love.graphics.setFont(self.fontSmall)
    for i, d in ipairs(dirDefs) do
        local coord = tipCoords[d.k]
        local has = labels and labels[d.k] and labels[d.k] ~= ""
        local isActive = (activeDirKey == d.k)

        if isActive then
            -- Light up the two edges of the star forming this directional point in instrument color
            local tipIdx = (i - 1) * 2 + 1
            local leftValleyIdx = ((tipIdx - 2 + nVerts) % nVerts) + 1
            local rightValleyIdx = (tipIdx % nVerts) + 1
            local vLeft = ringVerts[leftValleyIdx]
            local vTip = ringVerts[tipIdx]
            local vRight = ringVerts[rightValleyIdx]

            -- The held point fills solid
            self:setColor(col)
            love.graphics.polygon("fill", cx, cy, vLeft.x, vLeft.y, vTip.x, vTip.y, vRight.x, vRight.y)

            -- Glowing star outline in the direction pressed
            self:setColor(col)
            love.graphics.setLineWidth(2.2)
            love.graphics.line(vLeft.x, vLeft.y, vTip.x, vTip.y, vRight.x, vRight.y)
            love.graphics.setLineWidth(1)
        end

        -- Tip diamond vertex (lights up white when pressed, instrument color when idle)
        self:drawDiamond(coord.tx, coord.ty, isActive and 3.5 or (has and 2.5 or 1.5),
            isActive and C.TEXT or (has and col or C.DIM))

        -- Clean floating label (radial for Roman/numbers; tucked underneath for longer words like LOW/HIGH)
        if has then
            local text = labels[d.k]
            local isShortRadial = text:match("^[IVXLCDMivxlcdm]+$") or text:match("^%d+$")
            local lx, ly
            if isShortRadial then
                -- Roman numerals (IV, V) and numbers (1..8) sit directly outside points radially
                lx = cx + math_cos(d.ang) * d.lr
                ly = cy + math_sin(d.ang) * d.lr
            elseif d.k == "LEFT" then
                lx = coord.tx + 4
                ly = coord.ty + 14
            elseif d.k == "RIGHT" then
                lx = coord.tx - 4
                ly = coord.ty + 14
            elseif d.k == "UP" then
                lx = coord.tx
                ly = coord.ty - 13
            elseif d.k == "DOWN" then
                lx = coord.tx
                ly = coord.ty + 14
            else
                lx = cx + math_cos(d.ang) * d.lr
                ly = cy + math_sin(d.ang) * d.lr
            end

            local tw = self.fontSmall:getWidth(text)
            local th = self:lineHeight(self.fontSmall)
            local isGuide = (guideDirKey == d.k)
            if isActive then
                -- the held label sits in a solid chip
                self:setColor(col)
                love.graphics.rectangle("fill", math_floor(lx - tw * 0.5) - 5, math_floor(ly - th * 0.5) - 1, tw + 10, th + 2, 3, 3)
            end
            self:setColor(isActive and C.BG or (isGuide and col or C.TEXT))
            love.graphics.print(text, math_floor(lx - tw * 0.5), math_floor(ly - th * 0.5))
            if isGuide then
                self:setColor(col)
                love.graphics.circle("fill", lx, math_floor(ly + th * 0.5) + 3, 1.8)
            end
        end
    end
end

end
