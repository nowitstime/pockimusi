-- ============================================================================
-- src/ui/chrome/face.lua — Zone 3: the face-button ring, and the motifs around both zones
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
-- ZONE 3: CELESTIAL ORBITAL CIRCULAR FACE BUTTONS (cx=538, cy=188)
-- ============================================================================
function Chrome:drawCircleFaceButtons(cx, cy, faceLabels, col, flashMap, activeMap)
    local C = Config.COLORS
    local R_ORB = 54
    local r = 24
    local pos = {
        X = { x = cx,         y = cy - R_ORB },
        Y = { x = cx - R_ORB, y = cy         },
        A = { x = cx + R_ORB, y = cy         },
        B = { x = cx,         y = cy + R_ORB },
    }

    -- Unifying orbital ring
    self:setColor(C.GRID, 0.85)
    love.graphics.circle("line", cx, cy, R_ORB)

    -- 4 Outer celestial compass arcs framing the circle
    for i = 0, 3 do
        local a1 = (i * math_pi * 0.5) + 0.36
        local a2 = ((i + 1) * math_pi * 0.5) - 0.36
        local rOut = 74
        self:setColor(col, 0.32)
        love.graphics.arc("line", "open", cx, cy, rOut, a1, a2)
    end

    -- 4 Intercardinal 4-point star glints along the orbital ring
    for i = 0, 3 do
        local ang = (math_pi * 0.25) + i * (math_pi * 0.5)
        self:drawStarGlint(cx + math_cos(ang) * R_ORB, cy + math_sin(ang) * R_ORB, 5.5, col, 0.65)
    end

    -- Center crosshairs and diamond
    self:setColor(C.GRID, 0.7)
    love.graphics.line(cx - 14, cy, cx + 14, cy)
    love.graphics.line(cx, cy - 14, cx, cy + 14)
    self:drawStarGlint(cx, cy, 8, col, 0.45)
    self:drawDiamond(cx, cy, 2.2, C.MUTED)

    local btnOrder = { "X", "Y", "A", "B" }
    for _, btn in ipairs(btnOrder) do
        local p = pos[btn]
        local fl = (flashMap and flashMap[btn]) or 0.0
        local isActive = (activeMap and activeMap[btn]) or (Input.down[btn] and not Input.down.R2)
        local btnCol = col
        if Modes.current == "MIX" and Looper.tracks[btn == "B" and 1 or (btn == "A" and 2 or (btn == "Y" and 3 or 4))].muted then
            btnCol = C.RED
        end

        -- Press burst & outer halo
        if fl > 0.05 then
            self:setColor(btnCol, fl * 0.75)
            love.graphics.circle("line", p.x, p.y, r + 6)
            self:drawStarGlint(p.x, p.y, r + 10, btnCol, fl * 0.75)
        end

        -- Subtle constant outer ring around each lens
        self:setColor(btnCol, 0.22 + fl * 0.5)
        love.graphics.circle("line", p.x, p.y, r + 3)

        -- Main circular lens fill
        self:setColor(C.PANEL)
        love.graphics.circle("fill", p.x, p.y, r)

        if fl > 0.02 or isActive then
            local fillA = math_max(isActive and 0.28 or 0.0, fl * 0.35)
            self:setColor(btnCol, fillA)
            love.graphics.circle("fill", p.x, p.y, r - 1)
        end

        -- Lens border
        self:setColor((fl > 0.05 or isActive) and btnCol or C.GRID)
        love.graphics.setLineWidth(fl > 0.05 and 2.0 or 1.4)
        love.graphics.circle("line", p.x, p.y, r)
        love.graphics.setLineWidth(1)

        -- Typography or Central Void Diamond Pip
        local label = faceLabels and faceLabels[btn]
        if not label or label == "" then
            -- Clean celestial void lens: elegant diamond pip in center (lights up on press)
            self:drawDiamond(p.x, p.y, (fl > 0.05 or isActive) and 3.5 or 2.2, (fl > 0.05 or isActive) and C.TEXT or C.DIM)
        elseif type(label) == "table" and label.l1 and label.l2 then
            self:setColor(btnCol)
            love.graphics.setFont(self.fontTiny)
            local w1 = self.fontTiny:getWidth(label.l1)
            love.graphics.print(label.l1, math_floor(p.x - w1 * 0.5), p.y - 7)

            self:setColor((fl > 0.05 or isActive) and btnCol or C.TEXT)
            love.graphics.setFont(self.fontSmall)
            local w2 = self.fontSmall:getWidth(label.l2)
            love.graphics.print(label.l2, math_floor(p.x - w2 * 0.5), p.y + 4)
        else
            local text = tostring(label or btn)
            local s1, s2 = text:match("^(%S+)%s+(%S+)$")
            if s1 and s2 then
                self:setColor(btnCol)
                love.graphics.setFont(self.fontTiny)
                local w1 = self.fontTiny:getWidth(s1)
                love.graphics.print(s1, math_floor(p.x - w1 * 0.5), p.y - 7)

                self:setColor((fl > 0.05 or isActive) and btnCol or C.TEXT)
                love.graphics.setFont(self.fontSmall)
                local w2 = self.fontSmall:getWidth(s2)
                love.graphics.print(s2, math_floor(p.x - w2 * 0.5), p.y + 4)
            else
                self:setColor((fl > 0.05 or isActive) and btnCol or C.TEXT)
                love.graphics.setFont(self.fontSmall)
                local tw = self.fontSmall:getWidth(text)
                local th = self.fontSmall:getHeight()
                love.graphics.print(text, math_floor(p.x - tw * 0.5), math_floor(p.y - th * 0.5))
            end
        end
    end
end

-- ============================================================================
-- DELICATE ASTROLABE MOTIFS AROUND D-PAD AND FACE ZONES
-- ============================================================================
function Chrome:drawZoneMotifs(kind, col, t)
    local instId = kind
    local lx, ly, rx, ry = 102, 188, 538, 188

    if instId == "drums" then
        -- D-pad side: rhythmic astrolabe pulse ring
        self:setColor(col, 0.22)
        self:drawDashedCircle(lx, ly, 78, 2, 6)

        -- Face button side: 16-step chronometer graduation ring with 16th-note ticks
        self:setColor(col, 0.22)
        self:drawDashedCircle(rx, ry, 84, 2, 6)
        for i = 0, 15 do
            local ang = (i / 16.0) * 2.0 * math_pi
            local isQuarter = (i % 4 == 0)
            local r1, r2 = 82, isQuarter and 88 or 85
            local x1 = rx + math_cos(ang) * r1
            local y1 = ry + math_sin(ang) * r1
            local x2 = rx + math_cos(ang) * r2
            local y2 = ry + math_sin(ang) * r2
            self:setColor(col, isQuarter and 0.45 or 0.20)
            love.graphics.line(x1, y1, x2, y2)
        end
    elseif instId == "harp" then
        local rot = t * 0.35
        self:setColor(col, 0.28)
        love.graphics.arc("line", "open", lx, ly - 12, 80, math_pi * 1.1, math_pi * 1.9)
        love.graphics.arc("line", "open", rx, ry + 14, 84, math_pi * 0.1, math_pi * 0.9)
        self:drawStarGlint(lx + math_cos(rot) * 78, ly + math_sin(rot) * 78, 5.5, col, 0.55)
        self:drawStarGlint(rx + math_cos(-rot) * 84, ry + math_sin(-rot) * 84, 5.5, col, 0.55)

        -- Extra harmonic orbital halo
        self:setColor(col, 0.16)
        love.graphics.circle("line", rx, ry, 90)
    elseif instId == "bass" or instId == "lead" then
        local ptsL = { lx, ly - 82, lx + 82, ly, lx, ly + 82, lx - 82, ly }
        local ptsR = { rx, ry - 86, rx + 86, ry, rx, ry + 86, rx - 86, ry }
        self:setColor(col, 0.22)
        love.graphics.polygon("line", ptsL)
        love.graphics.polygon("line", ptsR)

        -- Cardinal diamond corner markers
        self:drawDiamond(rx, ry - 86, 2.8, col)
        self:drawDiamond(rx + 86, ry, 2.8, col)
        self:drawDiamond(rx, ry + 86, 2.8, col)
        self:drawDiamond(rx - 86, ry, 2.8, col)
    elseif instId == "pad" then
        self:setColor(col, 0.2)
        love.graphics.circle("line", lx, ly, 76)
        self:drawDashedCircle(rx, ry, 82, 4, 8)
        self:drawDashedCircle(rx, ry, 90, 2, 6)
        for i = 0, 3 do
            local a = t * 0.2 + i * (math_pi * 0.5)
            self:drawStarGlint(rx + math_cos(a) * 82, ry + math_sin(a) * 82, 4.5, col, 0.45)
        end
    else
        -- the plain lab view: two dashed rings, nothing more
        self:setColor(col, 0.2)
        self:drawDashedCircle(lx, ly, 78, 3, 7)
        self:drawDashedCircle(rx, ry, 84, 3, 7)
    end
end

function Chrome:drawDashedCircle(cx, cy, r, onDash, offDash)
    local perim = 2.0 * math_pi * r
    local totalDashes = math_floor(perim / (onDash + offDash))
    for i = 0, totalDashes - 1 do
        local a1 = (i / totalDashes) * 2.0 * math_pi
        local a2 = a1 + (onDash / perim) * 2.0 * math_pi
        love.graphics.arc("line", "open", cx, cy, r, a1, a2)
    end
end

end
