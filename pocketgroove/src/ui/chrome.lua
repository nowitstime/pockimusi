-- ============================================================================
-- src/ui/chrome.lua — Unified 640x480 Celestial Anime UI Chrome
-- (Crown Top Bar, 3-Zone Celestial Stage, Thematic Constellation Tape Deck)
-- ============================================================================

local Config      = require("src.config")
local Theory      = require("src.theory")
local Input       = require("src.input")
local Synth       = require("src.synth")
local Looper      = require("src.looper")
local Instruments = require("src.instruments")
local Modes       = require("src.modes")

local clamp      = Config.clamp
local math_floor = math.floor
local math_min   = math.min
local math_max   = math.max
local math_sin   = math.sin
local math_cos   = math.cos
local math_abs   = math.abs
local math_pi    = math.pi

local Chrome = {
    fontTiny  = nil,
    fontSmall = nil,
    fontMed   = nil,
    fontLarge = nil,
    fontHuge  = nil,
}

function Chrome:init()
    self.fontTiny  = love.graphics.newFont(9)
    self.fontSmall = love.graphics.newFont(11)
    self.fontMed   = love.graphics.newFont(13)
    self.fontLarge = love.graphics.newFont(16)
    self.fontHuge  = love.graphics.newFont(28)
    love.graphics.setLineStyle("smooth")
end

function Chrome:setColor(c, alphaOverride)
    if alphaOverride then
        love.graphics.setColor(c[1], c[2], c[3], alphaOverride)
    else
        love.graphics.setColor(c[1], c[2], c[3], c[4] or 1.0)
    end
end

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

function Chrome:isPlayMode(mode)
    return mode == "NORMAL" or mode == "REC_LATCH" or mode == "REC_HOLD"
end

-- The page's colour: instrument colour while playing, mode colour on a settings page
function Chrome:getAccent(mode, instCol)
    if self:isPlayMode(mode) then return instCol end
    return Config.MODE_COLORS[mode] or instCol
end

-- ============================================================================
-- ZONE 1: 8-POINT WIREFRAME STAR D-PAD (cx=102, cy=188)
-- ============================================================================
function Chrome:drawStarDpad(cx, cy, labels, col, activeDirKey)
    local C = Config.COLORS
    local cardR = 55
    local diagR = 39
    local innerR = 17

    -- Outer astrolabe ring with 4 intercardinal diamond ticks
    self:setColor(C.GRID, 0.7)
    love.graphics.circle("line", cx, cy, 68)
    for i = 0, 3 do
        local a = (math_pi * 0.25) + i * (math_pi * 0.5)
        self:drawDiamond(cx + math_cos(a) * 68, cy + math_sin(a) * 68, 2, C.DIM)
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
    self:setColor(C.PANEL_HI, 0.38)
    local nVerts = #ringVerts
    for i = 1, nVerts do
        local v1 = ringVerts[i]
        local v2 = ringVerts[(i % nVerts) + 1]
        love.graphics.polygon("fill", cx, cy, v1.x, v1.y, v2.x, v2.y)
    end

    -- Clean single wireframe outline
    self:setColor(C.GRID)
    love.graphics.polygon("line", starPts)

    -- Internal axis lines
    self:setColor(C.GRID, 0.45)
    for _, d in ipairs(dirDefs) do
        local coord = tipCoords[d.k]
        love.graphics.line(cx, cy, coord.tx, coord.ty)
    end

    -- Center core sparkle
    local anyActive = (activeDirKey and activeDirKey ~= "NEUTRAL")
    self:drawStarGlint(cx, cy, anyActive and 10 or 7, anyActive and col or C.MUTED, anyActive and 0.9 or 0.45)

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

            -- Soft subtle point fill glow
            self:setColor(col, 0.22)
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
            local th = self.fontSmall:getHeight()
            self:setColor(isActive and C.TEXT or C.MUTED)
            love.graphics.print(text, math_floor(lx - tw * 0.5), math_floor(ly - th * 0.5))
        end
    end
end

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
function Chrome:drawZoneMotifs(instId, col, t)
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
    elseif instId == "bass" then
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
    elseif instId == "grain" then
        self:setColor(col, 0.2)
        love.graphics.circle("line", lx, ly, 76)
        self:drawDashedCircle(rx, ry, 82, 4, 8)
        self:drawDashedCircle(rx, ry, 90, 2, 6)
        for i = 0, 3 do
            local a = t * 0.2 + i * (math_pi * 0.5)
            self:drawStarGlint(rx + math_cos(a) * 82, ry + math_sin(a) * 82, 4.5, col, 0.45)
        end
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

-- ============================================================================
-- REGION 1: TOP STATUS BAR (CROWN) (y: 6..44)
-- ============================================================================
function Chrome:drawTopBar()
    local C = Config.COLORS
    local sl = Looper.activeTrack
    local track = Looper.tracks[sl]
    local instCol = Config.TRACK_COLORS[sl]
    local grid = Looper:getTrackGrid(sl)
    local mode = Modes.current or "NORMAL"

    -- Frame with corner accent diamonds
    self:drawFrame(8, 6, 624, 38, C.GRID, 1, instCol)

    -- Left Active Track Accent Block
    self:setColor(instCol, 0.16)
    love.graphics.rectangle("fill", 12, 10, 126, 30, 4, 4)
    self:setColor(instCol)
    love.graphics.rectangle("fill", 12, 10, 3.5, 30, 1.5, 1.5)

    self:setColor(C.TEXT)
    love.graphics.setFont(self.fontSmall)
    love.graphics.print(string.format("%d - %s", sl, track and track.name or "TRK"), 24, 17)

    -- Hairline dividers & Metadata
    self:setColor(C.GRID)
    love.graphics.line(146, 13, 146, 37)

    love.graphics.setFont(self.fontTiny)
    self:setColor(C.MUTED)
    love.graphics.print("GRID", 156, 11)
    love.graphics.setFont(self.fontSmall)
    self:setColor((grid.id ~= "FREE") and C.MINT or C.MUTED)
    love.graphics.print(grid.label, 156, 21)

    self:setColor(C.GRID)
    love.graphics.line(200, 13, 200, 37)

    love.graphics.setFont(self.fontTiny)
    self:setColor(C.MUTED)
    love.graphics.print("LOOP", 210, 11)
    love.graphics.setFont(self.fontSmall)
    self:setColor(C.TEXT)
    love.graphics.print(Looper.bars .. " BAR", 210, 21)

    self:setColor(C.GRID)
    love.graphics.line(256, 13, 256, 37)

    -- Center Tempo, Key & Diamond Metronome
    love.graphics.setFont(self.fontSmall)
    self:setColor(C.TEXT)
    love.graphics.print(string.format("%d BPM", Looper.bpm), 268, 12)
    self:setColor(C.CYAN)
    love.graphics.print(Theory:getKeyLabel(), 332, 12)

    local totalBeats = Looper:getTotalBeats()
    local sp = (totalBeats == 8) and 16 or 8.5
    for b = 1, totalBeats do
        local bx = 271 + (b - 1) * sp
        local by = 33
        local isBar = ((b - 1) % 4 == 0)
        local isCur = (Looper.playing and Looper.currentBeat == b)

        if isCur then
            local mc = (mode == "REC_LATCH" or mode == "REC_HOLD") and C.RED or C.TEXT
            self:drawStarGlint(bx, by, 6.5, mc, 1.0)
            self:drawDiamond(bx, by, 2.5, C.TEXT)
        else
            self:drawDiamond(bx, by, isBar and 2.5 or 1.6, isBar and C.MUTED or C.DIM)
        end
    end

    -- Right Mode Status Tag (rx=4) with vector icon + ASCII text
    local modeConfigs = {
        NORMAL    = { label = "JAM SAFE",   icon = "STAR",    stroke = C.GRID,   fill = C.PANEL_HI, txt = C.MUTED,  iconCol = C.GRID },
        REC_LATCH = { label = "REC LATCH",   icon = "DOT",     stroke = C.RED,    fill = C.RED,      txt = C.BG,     iconCol = C.BG },
        REC_HOLD  = { label = "REC HOLD",    icon = "DOT",     stroke = C.RED,    fill = C.RED,      txt = C.BG,     iconCol = C.BG },
        TRACK     = { label = "TRACK SOUND", icon = "GLINT",   stroke = C.PINK,   fill = C.PINK,     txt = C.BG,     iconCol = C.BG },
        MIX       = { label = "MIXER",       icon = "FADERS",  stroke = C.SILVER, fill = C.SILVER,   txt = C.BG,     iconCol = C.BG },
        TRANSPORT = { label = "TRANSPORT",   icon = "GLINT",   stroke = C.AMBER,  fill = C.AMBER,    txt = C.BG,     iconCol = C.BG },
        ERASE     = { label = "ERASE",       icon = "CROSS",   stroke = C.RED,    fill = C.RED,      txt = C.BG,     iconCol = C.BG },
        FX        = { label = "LIVE FX",     icon = "GLINT",   stroke = C.SILVER, fill = C.SILVER,   txt = C.BG,     iconCol = C.BG },
    }
    local mc = modeConfigs[mode] or modeConfigs.NORMAL
    local bx, by, bw, bh = 488, 11, 138, 28
    self:setColor(mc.fill, (mode == "NORMAL") and 1.0 or 0.92)
    love.graphics.rectangle("fill", bx, by, bw, bh, 4, 4)
    self:setColor(mc.stroke)
    love.graphics.rectangle("line", bx, by, bw, bh, 4, 4)

    -- Vector icon before label
    local icx, icy = bx + 18, by + 14
    if mc.icon == "STAR" then
        self:drawStarGlint(icx, icy, 4.2, mc.iconCol, 0.9)
    elseif mc.icon == "DOT" then
        self:setColor(mc.iconCol)
        love.graphics.circle("fill", icx, icy, 3.8)
    elseif mc.icon == "DIAMOND" then
        self:drawDiamond(icx, icy, 3.5, mc.iconCol)
    elseif mc.icon == "FADERS" then
        self:setColor(mc.iconCol)
        love.graphics.rectangle("fill", icx - 4, icy - 4.5, 2.5, 9, 1, 1)
        love.graphics.rectangle("fill", icx + 1, icy - 4.5, 2.5, 9, 1, 1)
    elseif mc.icon == "PLAY" then
        self:setColor(mc.iconCol)
        love.graphics.polygon("fill", icx - 3, icy - 4.5, icx + 4, icy, icx - 3, icy + 4.5)
    elseif mc.icon == "CROSS" then
        self:setColor(mc.iconCol)
        love.graphics.setLineWidth(1.8)
        love.graphics.line(icx - 3.5, icy - 3.5, icx + 3.5, icy + 3.5)
        love.graphics.line(icx - 3.5, icy + 3.5, icx + 3.5, icy - 3.5)
        love.graphics.setLineWidth(1)
    elseif mc.icon == "GLINT" then
        self:drawStarGlint(icx, icy, 5.0, mc.iconCol, 1.0)
    end

    love.graphics.setFont(self.fontSmall)
    self:setColor(mc.txt)
    love.graphics.print(mc.label, bx + 32, by + 6)
end

-- ============================================================================
-- REGION 2: CENTER STAGE (y: 50..356)
-- ============================================================================
function Chrome:drawCenterStage()
    local C = Config.COLORS
    local sl = Looper.activeTrack
    local track = Looper.tracks[sl]
    local def, state = Instruments:getTrackInstrument(sl)
    local instCol = Config.TRACK_COLORS[sl]
    local mode = Modes.current or "NORMAL"
    local playMode = self:isPlayMode(mode)
    local accent = self:getAccent(mode, instCol)
    local t = love.timer.getTime()

    -- Frame: grid line while jamming, mode colour (with a soft glow) otherwise
    local borderCol = (mode == "NORMAL") and C.GRID or (Config.MODE_COLORS[mode] or C.GRID)
    self:drawFrame(8, 50, 624, 306, borderCol, (mode == "NORMAL") and 1 or 1.6)
    if mode ~= "NORMAL" then
        for i, a in ipairs({ 0.16, 0.08, 0.04 }) do
            self:setColor(borderCol, a)
            love.graphics.setLineWidth(1.5)
            love.graphics.rectangle("line", 8 - i, 50 - i, 624 + i * 2, 306 + i * 2, 6 + i, 6 + i)
        end
        love.graphics.setLineWidth(1)
        if mode == "ERASE" then
            self:setColor(C.RED, 0.07)
            love.graphics.rectangle("fill", 9, 51, 622, 304, 6, 6)
        end
    end

    -- Vertical hairline dividers separating Left Zone | Center | Right Zone
    self:setColor(C.GRID, 0.55)
    love.graphics.line(198, 62, 198, 312)
    love.graphics.line(442, 62, 442, 312)

    -- Zone motifs: the instrument's own while playing, a generic astrolabe ring on settings pages
    if playMode then
        self:drawZoneMotifs(def.id, instCol, t)
    else
        self:drawZoneMotifs("drums", accent, t)
    end

    -- Shoulder capsules
    local lOn, rOn = Input.down.L1, Input.down.R1
    local l1Label, r1Label = "L1: -", "R1: +"
    if mode == "TRACK" then
        l1Label, r1Label = "L1: CHANGE <", "R1: CHANGE >"
    elseif mode == "TRANSPORT" then
        l1Label, r1Label = "L1: SCALE <", "R1: SCALE >"
    elseif mode == "MIX" then
        l1Label, r1Label = "L1: MST -", "R1: MST +"
    elseif mode == "ERASE" then
        l1Label, r1Label = "L1: UNDO", "R1: -"
    elseif def.id == "drums" then
        l1Label, r1Label = "L1: 1/4", "R1: 1/8"
    elseif def.id == "harp" then
        l1Label, r1Label = "L1: OCT -", "R1: OCT +"
    else
        l1Label, r1Label = "L1: OCT -1", "R1: OCT +1"
    end
    local function shoulder(x, label, on)
        if on then
            self:drawCapsule(x, 58, 112, 22, label, accent, accent, C.BG, self.fontTiny)
        elseif playMode then
            self:drawCapsule(x, 58, 112, 22, label, C.GRID, C.PANEL_HI, C.MUTED, self.fontTiny)
        else
            self:drawCapsule(x, 58, 112, 22, label, accent, accent, accent, self.fontTiny, 0.08)
        end
    end
    shoulder(18, l1Label, lOn)
    shoulder(510, r1Label, rOn)

    local titleStr = def.name
    if mode == "TRACK" then titleStr = string.format("TRACK %d - SOUND", sl)
    elseif mode == "MIX" then titleStr = "4-TRACK LEVEL & MUTE MIXER"
    elseif mode == "TRANSPORT" then titleStr = "MASTER CLOCK"
    elseif mode == "ERASE" then titleStr = "SELECTIVE ERASE & UNDO"
    elseif mode == "FX" then titleStr = "LIVE PERFORMANCE FX"
    end

    self:setColor(playMode and C.TEXT or accent)
    love.graphics.setFont(self.fontMed)
    local tw = self.fontMed:getWidth(titleStr)
    love.graphics.print(titleStr, math_floor(320 - tw * 0.5), 62)

    self:setColor(playMode and C.GRID or accent, playMode and 0.6 or 0.35)
    love.graphics.line(212, 82, 428, 82)

    -- Left: Star D-Pad & Right: Circle Face Buttons (drawn in the page accent)
    local dpadLabels, faceLabels, flashMap, activeMap = self:getControlLabels(def, state, mode)
    local activeDir = Input:get8WayDirection()
    self:drawStarDpad(102, 188, dpadLabels, accent, activeDir)
    self:drawCircleFaceButtons(538, 188, faceLabels, accent, flashMap, activeMap)

    self:setColor(C.MUTED)
    love.graphics.setFont(self.fontTiny)
    local dpadSub = {
        TRACK = "D-PAD: ROW - INSTRUMENT", MIX = "D-PAD: LEVEL", TRANSPORT = "D-PAD: TEMPO - KEY",
        ERASE = "D-PAD: UNDO", FX = "D-PAD: PUNCH-IN FX",
    }
    local instSub = { drums = "D-PAD: EXPRESSION", harp = "D-PAD: HARMONY", bass = "D-PAD: SCALE DEGREE", grain = "D-PAD: TEXTURE" }
    local faceSub = { TRACK = "FACE: EFFECTS", MIX = "FACE: MUTES", TRANSPORT = "FACE: TIMING", ERASE = "FACE: CLEAR", FX = "FACE: MUTES" }
    local dpadSubtitle = dpadSub[mode] or instSub[def.id] or "D-PAD"
    local faceSubtitle = faceSub[mode] or "FACE: TRIGGERS"
    local dsw = self.fontTiny:getWidth(dpadSubtitle)
    local fsw = self.fontTiny:getWidth(faceSubtitle)
    love.graphics.print(dpadSubtitle, math_floor(102 - dsw * 0.5), 296)
    love.graphics.print(faceSubtitle, math_floor(538 - fsw * 0.5), 296)

    -- Center Column Visualizer (x: 204..436, y: 90..314)
    if mode == "MIX" then
        self:drawMixerView(t)
    elseif mode == "TRACK" then
        self:drawTrackPageView(def, state, track, accent)
    elseif mode == "TRANSPORT" then
        self:drawTransportView(track, instCol, accent)
    elseif mode == "ERASE" then
        self:drawEraseView(track)
    else
        self:drawInstrumentVisualizer(def, state, track, instCol, t)
    end

    -- Bottom Integrated Footer Strip (y: 322..355)
    self:drawFooterStrip(def, mode)
end

function Chrome:getControlLabels(def, state, mode)
    local C = Config.COLORS
    local dpadLabels = {}
    local faceLabels = { B = "B", A = "A", Y = "Y", X = "X" }
    local flashMap = {}
    local activeMap = {}

    if mode == "MIX" then
        dpadLabels = { UP = "LVL+", DOWN = "LVL-", LEFT = "TRK <", RIGHT = "TRK >" }
        faceLabels = {
            B = Looper.tracks[1].muted and "M1 [M]" or "M1",
            A = Looper.tracks[2].muted and "M2 [M]" or "M2",
            Y = Looper.tracks[3].muted and "M3 [M]" or "M3",
            X = Looper.tracks[4].muted and "M4 [M]" or "M4",
        }
    elseif mode == "TRACK" then
        local fx = Looper.tracks[Looper.activeTrack].fx
        local held = Modes.trackPage.fxHeld
        dpadLabels = held and { UP = "AMT +", DOWN = "AMT -", LEFT = "INST <", RIGHT = "INST >" }
            or { UP = "ROW UP", DOWN = "ROW DOWN", LEFT = "INST <", RIGHT = "INST >" }
        faceLabels = { B = "SPACE", A = "ECHO", Y = "DRIVE", X = "TONE" }
        for btn, slot in pairs(Looper.FX_SLOTS) do
            activeMap[btn] = fx.on[slot]
        end
    elseif mode == "TRANSPORT" then
        local swingHeld = Input.down.Y
        dpadLabels = swingHeld and { UP = "SWING +", DOWN = "SWING -", LEFT = "KEY <", RIGHT = "KEY >" }
            or { UP = "BPM+", DOWN = "BPM-", LEFT = "KEY <", RIGHT = "KEY >" }
        faceLabels = { B = Looper.bars .. " BAR", A = "GRID", Y = "SWING", X = "CLICK" }
        activeMap.X = Looper.clickOn
    elseif mode == "ERASE" then
        dpadLabels = { LEFT = "UNDO" }
        faceLabels = { B = "CLR B", A = "CLR A", Y = "CLR Y", X = "CLR X" }
    elseif def.id == "drums" then
        dpadLabels = { UP = "ACCENT", DOWN = "GHOST", LEFT = "FLAM", RIGHT = "RATCHET" }
        faceLabels = { B = "", A = "", Y = "", X = "" }
        flashMap = state.padFlash
    elseif def.id == "harp" then
        dpadLabels = { UP = "I", DOWN = "vi", LEFT = "IV", RIGHT = "V", UP_LEFT = "ii", UP_RIGHT = "iii", DOWN_LEFT = "bVII", DOWN_RIGHT = "IVm" }
        local chord = state.currentChord or Theory:getChordForDirection("NEUTRAL", false, false, state.colour)
        local n = chord.notes
        faceLabels = {
            B = Theory.NOTE_NAMES[(n[1] % 12) + 1],
            A = Theory.NOTE_NAMES[(n[2] % 12) + 1],
            Y = Theory.NOTE_NAMES[(n[3] % 12) + 1],
            X = Theory.NOTE_NAMES[(n[4] % 12) + 1],
        }
        for i = 1, 4 do
            local s = state.strings[i]
            flashMap[s.button] = s.energy
        end
    elseif def.id == "bass" then
        dpadLabels = { DOWN = "1", DOWN_LEFT = "2", LEFT = "3", UP_LEFT = "4", UP = "5", UP_RIGHT = "6", RIGHT = "7", DOWN_RIGHT = "8" }
        faceLabels = { B = "PLUCK", A = "GLIDE", Y = "+OCT", X = "+5TH" }
    elseif def.id == "grain" then
        dpadLabels = { UP = "DENSE", DOWN = "SPARSE", LEFT = "SCAN <", RIGHT = "SCAN >" }
        faceLabels = { B = "PAD", A = "BELL", Y = "CHOIR", X = "DRONE" }
    end

    return dpadLabels, faceLabels, flashMap, activeMap
end

-- ============================================================================
-- CENTER VISUALIZERS (DRUMS, HARP, BASS, GRAIN)
-- ============================================================================
function Chrome:drawInstrumentVisualizer(def, state, track, col, t)
    local C = Config.COLORS
    if def.id == "drums" then
        self:drawDrumLanes(def, state, track, col)
    elseif def.id == "harp" then
        local chord = state.currentChord or Theory:getChordForDirection("NEUTRAL", false, false, state.colour)
        self:setColor(C.TEXT)
        love.graphics.setFont(self.fontHuge)
        local cw = self.fontHuge:getWidth(chord.name)
        love.graphics.print(chord.name, math_floor(320 - cw * 0.5), 122)

        love.graphics.setFont(self.fontSmall)
        self:setColor(col)
        local octStr = chord.isWide and "WIDE OPEN" or (chord.octShift < 0 and "OCT -1" or (chord.octShift > 0 and "OCT +1" or "OCT 0"))
        local sub = string.format("%s  -  %s", chord.roman, octStr)
        local sw = self.fontSmall:getWidth(sub)
        love.graphics.print(sub, math_floor(320 - sw * 0.5), 158)

        -- 4 Starlight vibrating strings
        local xs = { 248, 296, 344, 392 }
        self:setColor(C.GRID)
        love.graphics.line(232, 182, 408, 182)
        love.graphics.line(232, 276, 408, 276)

        for i = 1, 4 do
            local sx = xs[i]
            local str = state.strings[i]
            local amp = (str and str.energy or 0.0) * 9.0
            local ph = t * 40.0 + i * 2.0
            local pts = {}
            for seg = 0, 16 do
                local frac = seg / 16.0
                local py = 182 + frac * 94
                local wave = math_sin(math_pi * frac) * math_sin(ph + frac * 6.0) * amp
                table.insert(pts, sx + wave)
                table.insert(pts, py)
            end

            if str and str.energy > 0.05 then
                self:setColor(col, 0.25)
                love.graphics.setLineWidth(4)
                love.graphics.line(pts)
            end
            self:setColor((str and str.energy > 0.05) and col or C.MUTED)
            love.graphics.setLineWidth((str and str.energy > 0.05) and 2.0 or 1.2)
            love.graphics.line(pts)
            love.graphics.setLineWidth(1)

            self:drawStarGlint(sx, 182, (str and str.energy > 0.05) and 5 or 3, (str and str.energy > 0.05) and col or C.MUTED)
            self:drawStarGlint(sx, 276, (str and str.energy > 0.05) and 5 or 3, (str and str.energy > 0.05) and col or C.MUTED)
        end

    elseif def.id == "bass" then
        self:setColor(col)
        love.graphics.setFont(self.fontHuge)
        local deg = state.activeDegree or 1
        local s = Theory:getScaleDegreeSemis(deg)
        local noteName = Theory.NOTE_NAMES[(s % 12) + 1]
        local nw = self.fontHuge:getWidth(noteName)
        love.graphics.print(noteName, math_floor(320 - nw * 0.5), 116)

        love.graphics.setFont(self.fontSmall)
        self:setColor(C.MUTED)
        local oct = (Input.down.L1 and -1 or 0) + (Input.down.R1 and 1 or 0)
        local sub = string.format("DEGREE %d  -  OCT %s%d", deg, (oct > 0 and "+" or ""), oct)
        local sw = self.fontSmall:getWidth(sub)
        love.graphics.print(sub, math_floor(320 - sw * 0.5), 154)

        -- Oscilloscope waveform
        self:setColor(C.BG)
        love.graphics.rectangle("fill", 212, 174, 216, 64, 4, 4)
        self:setColor(C.GRID)
        love.graphics.rectangle("line", 212, 174, 216, 64, 4, 4)

        local pts = {}
        local midY = 174 + 32
        for x = 0, 208, 4 do
            local normX = x / 208
            local w = normX * math_pi * 2.0 * 2.5 * state.oscFreqRatio + state.oscPhase
            local saw = (math_sin(w) + 0.5 * math_sin(w * 2.0) + 0.25 * math_sin(w * 3.0)) * 0.6
            table.insert(pts, 216 + x)
            table.insert(pts, midY + saw * 22.0 * state.oscAmp)
        end
        self:setColor(col)
        love.graphics.setLineWidth(1.8)
        love.graphics.line(pts)
        love.graphics.setLineWidth(1)

        -- Pitch bend ribbon
        self:setColor(C.BG)
        love.graphics.rectangle("fill", 212, 246, 216, 30, 4, 4)
        self:setColor(C.GRID)
        love.graphics.rectangle("line", 212, 246, 216, 30, 4, 4)

        self:setColor(col)
        love.graphics.setLineWidth(2)
        local ribbonPts = {}
        for x = 0, 200, 5 do
            local frac = x / 200.0
            local bend = math_sin(frac * math_pi) * 8.0 * (Input.down.A and 1.5 or 0.6)
            table.insert(ribbonPts, 220 + x)
            table.insert(ribbonPts, 261 - bend)
        end
        love.graphics.line(ribbonPts)
        love.graphics.setLineWidth(1)

    elseif def.id == "grain" then
        self:setColor(C.BG)
        love.graphics.rectangle("fill", 212, 126, 216, 134, 4, 4)
        self:setColor(C.GRID)
        love.graphics.rectangle("line", 212, 126, 216, 134, 4, 4)

        self:setColor(C.DIM, 0.5)
        for i = 0, 35 do
            local frac = i / 35.0
            local x = 220 + frac * 200
            local bh = (math_sin(frac * 19.0) * 0.5 + math_cos(frac * 37.0) * 0.5) * 42.0
            love.graphics.line(x, 193 - math_abs(bh), x, 193 + math_abs(bh))
        end

        for _, p in ipairs(state.particles) do
            self:setColor(col, p.life * 0.8)
            love.graphics.circle("line", p.x, p.y, p.radius)
        end

        local scanX = 220 + state.scanPos * 200
        self:setColor(col)
        love.graphics.setLineWidth(1.5)
        love.graphics.line(scanX, 130, scanX, 256)
        love.graphics.setLineWidth(1)
        self:drawStarGlint(scanX, 130, 5, col)

        love.graphics.setFont(self.fontSmall)
        self:setColor(C.MUTED)
        local scanStr = string.format("SCAN %d%%  -  DENS %d%%", math_floor(state.scanPos * 100), math_floor(state.density * 100))
        local sw = self.fontSmall:getWidth(scanStr)
        love.graphics.print(scanStr, math_floor(320 - sw * 0.5), 276)
    end
end

-- ============================================================================
-- MODE VIEWS: MIXER, TRACK PAGE, TRANSPORT, ERASE
-- ============================================================================
function Chrome:drawMixerView(t)
    local C = Config.COLORS
    for i = 1, 5 do
        local x = 212 + (i - 1) * 44
        local isMaster = (i == 5)
        local trk = not isMaster and Looper.tracks[i] or nil
        local lvl = isMaster and Synth.masterVolume or trk.volume
        local isSelected = (Modes.mixTrack == i)
        local isMuted = not isMaster and trk.muted or false
        local col = isMaster and C.TEXT or Config.TRACK_COLORS[i]

        if isSelected then
            self:setColor(col, 0.22)
            love.graphics.rectangle("fill", x - 2, 118, 40, 166, 4, 4)
            self:setColor(col)
            love.graphics.rectangle("line", x - 2, 118, 40, 166, 4, 4)
        end

        love.graphics.setFont(self.fontSmall)
        self:setColor(isMuted and C.DIM or col)
        local label = isMaster and "MST" or trk.shortName
        local lw = self.fontSmall:getWidth(label)
        love.graphics.print(label, math_floor(x + 18 - lw * 0.5), 126)

        -- Segmented LED bar (10 segments)
        local lit = math_floor(lvl * 10 + 0.5)
        for k = 1, 10 do
            local y = 252 - k * 11
            local on = (k <= lit)
            self:setColor(isMuted and C.GRID or (on and col or C.PANEL_HI))
            love.graphics.rectangle("fill", x + 4, y + 2, 28, 7, 2, 2)
        end

        self:drawTag(x + 2, 260, 32, 18, isMuted and "M" or "ON", isMuted and C.RED or C.GRID, isMuted and C.RED or C.PANEL_HI, isMuted and C.BG or C.MUTED, self.fontTiny)
    end
end

-- ============================================================================
-- DRUM LANES: one lane per pad, ordered like the button diamond (X, Y, A, B)
-- ============================================================================
function Chrome:drawMiniDiamond(x, y, pad, col)
    local C = Config.COLORS
    local pos = { X = { 0, -4 }, Y = { -4, 0 }, A = { 4, 0 }, B = { 0, 4 } }
    for k, o in pairs(pos) do
        self:setColor(k == pad and col or C.DIM)
        love.graphics.circle("fill", x + o[1], y + o[2], k == pad and 1.9 or 1.4)
    end
end

function Chrome:drawDrumLanes(def, state, track, col)
    local C = Config.COLORS
    local lx, lw = 205, 230
    local totalSteps = Looper:getTotalSixteenths()
    local isRec = Input:isRecording()

    for i, pad in ipairs(def.PADS) do
        local top = 88 + (i - 1) * 44
        local flash = state.padFlash[pad] or 0.0
        local lit = flash > 0.05 or (Input.down[pad] and Modes.current ~= "FX")

        if lit then
            self:setColor(col, 0.16 + flash * 0.12)
            love.graphics.rectangle("fill", 204, top, 232, 40, 4, 4)
            self:setColor(col)
            love.graphics.rectangle("line", 204, top, 232, 40, 4, 4)
        end

        -- Header: mini diamond, pad letter, sound name, info
        self:drawMiniDiamond(212, top + 8, pad, col)
        love.graphics.setFont(self.fontTiny)
        self:setColor(col)
        love.graphics.print(pad, 221, top + 2)
        love.graphics.setFont(self.fontSmall)
        self:setColor(C.TEXT)
        love.graphics.print(def:getPadSound(state, pad).short, 232, top)

        local count = Looper:countTrackAction(track.slot, pad)
        local info = count .. (count == 1 and " HIT" or " HITS")
        if lit and state.expressionName ~= "NORMAL" then info = state.expressionName end
        love.graphics.setFont(self.fontTiny)
        self:setColor(lit and col or C.MUTED)
        local iw = self.fontTiny:getWidth(info)
        love.graphics.print(info, math_floor(434 - iw), top + 2)

        -- Step strip
        local sy = top + 16
        self:setColor(C.PANEL_HI)
        love.graphics.rectangle("fill", 204, sy, 232, 22, 2, 2)
        self:setColor(C.GRID)
        love.graphics.rectangle("line", 204, sy, 232, 22, 2, 2)
        for st = 4, totalSteps - 1, 4 do
            local gx = math_floor(lx + (st / totalSteps) * lw) + 0.5
            self:setColor((st % 16 == 0) and C.DIM or C.GRID)
            love.graphics.line(gx, sy + 1, gx, sy + 21)
        end

        -- Hits: height = dynamics, tick before = flam, slivers = ratchet
        local base = sy + 20
        local bw = (totalSteps > 32) and 2.5 or 4
        for _, ev in ipairs(track.events) do
            if ev.action == pad then
                local x = lx + Looper:evPhase(ev) * lw + 0.5
                local vel = ev.vel or 0.85
                local h = (vel >= 0.95) and 17 or ((vel <= 0.5) and 6 or 11)
                local a = (vel <= 0.5) and 0.55 or 1.0
                local c = track.muted and C.DIM or col
                if ev.orn == "flam" then
                    self:setColor(c, 0.65)
                    love.graphics.rectangle("fill", x - 2.8, base - h * 0.5, 1.2, h * 0.5)
                end
                self:setColor(c, a)
                if ev.ratchet and ev.ratchet > 1 then
                    for k = 0, 2 do
                        local hh = h * (1.0 - k * 0.2)
                        love.graphics.rectangle("fill", x + k * (bw / 3 + 0.3), base - hh, 1.2, hh)
                    end
                else
                    love.graphics.rectangle("fill", x, base - h, bw, h)
                    if vel >= 0.95 then
                        self:setColor(C.TEXT, 0.8)
                        love.graphics.rectangle("fill", x, base - h, bw, 2)
                    end
                end
            end
        end
    end

    -- Shared playhead across the lanes
    local px = math_floor(lx + Looper.phase * lw) + 0.5
    local phCol = isRec and C.RED or C.TEXT
    self:setColor(phCol, 0.9)
    love.graphics.setLineWidth(1.5)
    love.graphics.line(px, 102, px, 266)
    love.graphics.setLineWidth(1)
    love.graphics.polygon("fill", px - 3.5, 97, px + 3.5, 97, px, 102)

    -- Status capsules
    local items = {}
    if state.expressionName ~= "NORMAL" then
        table.insert(items, { state.expressionName, col, col, C.BG })
    else
        table.insert(items, { "NORMAL", C.GRID, C.PANEL_HI, C.MUTED })
    end
    if state.repeatLabel ~= "OFF" then
        table.insert(items, { "REPEAT " .. state.repeatLabel, col, col, C.BG })
    else
        table.insert(items, { "REPEAT OFF", C.GRID, C.PANEL_HI, C.MUTED })
    end
    if (track.swing or 0.5) > 0.5 then
        table.insert(items, { string.format("SWING %d%%", math_floor(track.swing * 100 + 0.5)), C.GRID, C.PANEL_HI, C.TEXT })
    end
    self:drawCapsuleRow(320, 274, 18, items)
end

-- ============================================================================
-- TRACK SOUND PAGE: constellation of sound rows + moon-phase effect gauges
-- ============================================================================
function Chrome:drawMoonGauge(x, y, r, amount, on, col)
    local C = Config.COLORS
    if on and amount > 0 then
        self:setColor(col)
        love.graphics.circle("fill", x, y, r)
        -- Shadow disc slides off as the amount rises (new moon -> full moon)
        self:setColor(C.PANEL)
        love.graphics.circle("fill", x + amount * (2 * r + 2), y, r + 0.5)
    end
    self:setColor(on and col or C.DIM)
    love.graphics.setLineWidth(1.2)
    love.graphics.circle("line", x, y, r)
    love.graphics.setLineWidth(1)
end

function Chrome:drawTrackPageView(def, state, track, col)
    local C = Config.COLORS
    local rows = Instruments:getSoundRows(def, state)
    local sel = Modes.trackPage.row
    local n = #rows
    local y0 = (n == 1) and 134 or 108
    local nx = 226

    -- Value column starts after the widest label (KIT, X ... COLOUR)
    local labelW = 0
    for _, row in ipairs(rows) do
        labelW = math.max(labelW, self.fontTiny:getWidth(row.label))
    end
    local valueX = math.max(282, 250 + labelW + 10)

    if n > 1 then
        self:setColor(col, 0.3)
        for yy = y0, y0 + (n - 1) * 26, 4 do
            love.graphics.line(nx, yy, nx, yy + 1)
        end
    end

    for i, row in ipairs(rows) do
        local y = y0 + (i - 1) * 26
        local isSel = (i == sel)
        local isSetting = (row.kind == "setting")
        if isSel then
            self:setColor(col, 0.6)
            self:drawDashedCircle(nx, y, 11, 2, 3)
            if isSetting then
                self:setColor(col)
                love.graphics.setLineWidth(1.5)
                love.graphics.circle("line", nx, y, 5)
                love.graphics.setLineWidth(1)
            else
                self:drawStarGlint(nx, y, 7, col, 1.0)
            end
            self:drawCapsule(240, y - 10, 192, 20, "", col, col, col, self.fontSmall, 0.18)
        elseif isSetting then
            -- Settings are hollow rings; sounds are stars
            self:setColor(C.MUTED, 0.9)
            love.graphics.circle("line", nx, y, 3.5)
        else
            self:drawStarGlint(nx, y, (i == 1) and 4.5 or 3.2, C.MUTED, 0.9)
        end

        love.graphics.setFont(self.fontTiny)
        self:setColor(isSel and col or C.MUTED)
        love.graphics.print(row.label, 250, y - 6)

        local value = isSel and ("<  " .. row.value .. "  >") or row.value
        love.graphics.setFont(self.fontSmall)
        self:setColor(isSel and C.TEXT or C.MUTED)
        love.graphics.print(value, valueX, y - 7)

        if isSel then
            love.graphics.setFont(self.fontTiny)
            self:setColor(col)
            local hint = (isSetting and row.hint) or "L1/R1"
            love.graphics.print(hint, math_floor(424 - self.fontTiny:getWidth(hint)), y - 6)
        end
    end

    -- Instrument: a previewed swap is highlighted until SELECT is released
    love.graphics.setFont(self.fontTiny)
    self:setColor(C.MUTED)
    love.graphics.print("INSTRUMENT", 212, 232)
    local pending = Modes.trackPage.pending
    if pending then
        local pDef = Instruments:getDefinition(pending)
        self:drawCapsule(272, 228, 156, 18, "<  " .. (pDef.title or pDef.name) .. "  >", col, col, C.BG, self.fontTiny)
        self:setColor(col)
        local note = "RELEASE SELECT TO SWAP - UNDO: L2+R2+LEFT"
        love.graphics.print(note, math_floor(320 - self.fontTiny:getWidth(note) * 0.5), 249)
    else
        self:drawCapsule(272, 228, 156, 18, "<  " .. (def.title or def.name) .. "  >", C.DIM, nil, C.MUTED, self.fontTiny)
    end

    -- Effects as moon phases (X tone, Y drive, A echo, B space)
    local names = { tone = "TONE", drive = "DRIVE", echo = "ECHO", space = "SPACE" }
    for i, slot in ipairs(Looper.FX_ORDER) do
        local x = 236 + (i - 1) * 56
        local on = track.fx.on[slot]
        local amt = track.fx[slot]
        self:drawMoonGauge(x, 270, 10, amt, on, col)
        love.graphics.setFont(self.fontTiny)
        local name = names[slot]
        self:setColor(on and C.TEXT or C.MUTED)
        love.graphics.print(name, math_floor(x - self.fontTiny:getWidth(name) * 0.5), 283)
        local pct = on and (math_floor(amt * 100 + 0.5) .. "%") or "OFF"
        self:setColor(on and col or C.DIM)
        love.graphics.print(pct, math_floor(x - self.fontTiny:getWidth(pct) * 0.5), 294)
    end
end

-- ============================================================================
-- TRANSPORT PAGE: astrolabe dial (key ring, grid + swing ticks, loop hand)
-- ============================================================================
function Chrome:drawTransportView(track, trackCol, col)
    local C = Config.COLORS
    local cx, cy = 320, 190
    local rad = math_pi / 180

    self:setColor(col, 0.3)
    self:drawDashedCircle(cx, cy, 100, 2, 5)
    self:setColor(col, 0.18)
    love.graphics.circle("line", cx, cy, 64)

    -- Key ring in circle-of-fifths order; the scale is a contiguous arc on it
    local root = Theory.rootIndex - 1
    local scale = Theory.SCALES[Theory.scaleIndex]
    local inScale = {}
    for k = 1, 7 do inScale[(root + scale.intervals[k]) % 12] = true end
    local fifthsPc = {}
    for i = 0, 11 do fifthsPc[i] = (i * 7) % 12 end

    local arcStart = nil
    for st = 0, 11 do
        local ok = true
        for k = 0, 6 do
            if not inScale[fifthsPc[(st + k) % 12]] then ok = false break end
        end
        if ok then arcStart = st break end
    end
    if arcStart then
        local a1 = (-90 + arcStart * 30 - 12) * rad
        local a2 = (-90 + (arcStart + 6) * 30 + 12) * rad
        self:setColor(col, 0.45)
        love.graphics.setLineWidth(2.5)
        love.graphics.arc("line", "open", cx, cy, 72, a1, a2)
        love.graphics.setLineWidth(1)
    end

    love.graphics.setFont(self.fontTiny)
    for i = 0, 11 do
        local pc = fifthsPc[i]
        local ang = (-90 + i * 30) * rad
        local x, y = cx + math_cos(ang) * 86, cy + math_sin(ang) * 86
        local name = Theory.NOTE_NAMES[pc + 1]
        if pc == root then
            self:drawCapsule(math_floor(x - 11), math_floor(y - 8), 22, 16, name, col, col, C.BG, self.fontTiny)
        else
            self:setColor(inScale[pc] and C.TEXT or C.DIM, inScale[pc] and 0.8 or 1.0)
            love.graphics.print(name, math_floor(x - self.fontTiny:getWidth(name) * 0.5), math_floor(y - 6))
        end
    end

    -- Grid ticks for one bar; swing pushes the offbeat ticks late
    local grid = Looper:getTrackGrid(track.slot)
    local perBar = grid.stepsPerBar or 16
    local sw = 0.0
    if perBar == 8 or perBar == 16 then sw = math_max(0.0, ((track.swing or 0.5) - 0.5) * 2.0) end
    local stepDeg = 360 / perBar
    for k = 0, perBar - 1 do
        local odd = (k % 2 == 1)
        local ang = (-90 + (k + (odd and sw or 0)) * stepDeg) * rad
        local onBeat = (k % (perBar / 4) == 0)
        local r1 = onBeat and 54 or 58
        self:setColor(col, grid.stepsPerBar and (odd and 0.5 or 0.8) or 0.25)
        love.graphics.setLineWidth(1.2)
        love.graphics.line(cx + math_cos(ang) * r1, cy + math_sin(ang) * r1, cx + math_cos(ang) * 64, cy + math_sin(ang) * 64)
    end
    love.graphics.setLineWidth(1)

    -- Loop hand: a star travelling the ring once per loop, leaving a trail
    local endA = (-90 + Looper.phase * 360) * rad
    if Looper.phase > 0.002 then
        self:setColor(col)
        love.graphics.setLineWidth(2)
        love.graphics.arc("line", "open", cx, cy, 64, -90 * rad, endA)
        love.graphics.setLineWidth(1)
    end
    self:drawStarGlint(cx + math_cos(endA) * 64, cy + math_sin(endA) * 64, 6, C.TEXT, 1.0)

    -- Centre: tempo, key, loop length as moons
    love.graphics.setFont(self.fontHuge)
    self:setColor(C.TEXT)
    local bpmStr = tostring(Looper.bpm)
    love.graphics.print(bpmStr, math_floor(cx - self.fontHuge:getWidth(bpmStr) * 0.5), 148)
    love.graphics.setFont(self.fontTiny)
    self:setColor(C.MUTED)
    love.graphics.print("BPM", math_floor(cx - self.fontTiny:getWidth("BPM") * 0.5), 182)
    local keyStr = Theory.NOTE_NAMES[root + 1] .. " " .. scale.fullName:upper()
    love.graphics.setFont(self.fontSmall)
    self:setColor(col)
    love.graphics.print(keyStr, math_floor(cx - self.fontSmall:getWidth(keyStr) * 0.5), 196)
    for k = 1, 4 do
        local mx = cx - 15 + (k - 1) * 10
        if k <= Looper.bars then
            self:setColor(col)
            love.graphics.circle("fill", mx, 222, 3)
        else
            self:setColor(col, 0.5)
            love.graphics.circle("line", mx, 222, 3)
        end
    end

    -- Track identity + the active track's timing settings
    self:drawCapsuleRow(cx, 296, 16, {
        { string.format("%d - %s", track.slot, track.name), trackCol, nil, trackCol },
        { "GRID " .. grid.label, col, col, col, 0.16 },
        { string.format("SWING %d%%", math_floor((track.swing or 0.5) * 100 + 0.5)), col, col, col, 0.16 },
    })
end

function Chrome:drawEraseView(track)
    local C = Config.COLORS
    self:setColor(C.RED)
    love.graphics.setFont(self.fontLarge)
    local ew = self.fontLarge:getWidth("ASTRAL ERASE")
    love.graphics.print("ASTRAL ERASE", math_floor(320 - ew * 0.5), 142)

    love.graphics.setFont(self.fontSmall)
    self:setColor(C.TEXT)
    love.graphics.print("B / A / Y / X - Clear pad lane", 232, 178)
    love.graphics.print("LEFT / L1 - Undo last overdub", 232, 202)
    love.graphics.print("START - Clear entire track", 232, 226)

    self:setColor(C.MUTED)
    love.graphics.print(string.format("%d EVENTS ON TRACK %d", #track.events, track.slot), 244, 260)
end

-- ============================================================================
-- BOTTOM FOOTER HINT STRIP (y: 322..355)
-- ============================================================================
function Chrome:drawFooterStrip(def)
    local C = Config.COLORS
    local mode = Modes.current or "NORMAL"
    local hintText = "[L2] Record   [SELECT] Track   [SELECT+R2] Mix   [START] Transport"
    local hintCol = C.MUTED

    if mode == "REC_LATCH" then
        hintText = "REC LATCHED | Tap L2 to stop | Hold L2 for momentary punch-in"
        hintCol = C.RED
    elseif mode == "REC_HOLD" then
        hintText = "REC (HOLD) | Release L2 to stop punch-in | Quick tap latches"
        hintCol = C.RED
    elseif mode == "TRACK" then
        hintText = "TRACK | UP/DN Row | L1/R1 Change | < > Instrument (on release) | Face FX, hold + UP/DN"
        hintCol = C.PINK
    elseif mode == "MIX" then
        hintText = "MIXER | < > Track | UP/DN Volume | B/A/Y/X Mute | L1/R1 Master"
        hintCol = C.SILVER
    elseif mode == "TRANSPORT" then
        hintText = "TRANSPORT | UP/DN BPM | < > Key | L1/R1 Scale | A Grid | Y+UP/DN Swing | X Click"
        hintCol = C.AMBER
    elseif mode == "ERASE" then
        hintText = "ERASE | B/A/Y/X Clear pad | LEFT or L1 Undo take | START Clear all"
        hintCol = C.RED
    elseif mode == "FX" then
        hintText = "LIVE FX | UP Stutter | DN Slow | LEFT Duck | RIGHT Bitcrush | B/A/Y/X Mute"
        hintCol = C.SILVER
    elseif Looper.toastTimer > 0 then
        hintText = "> " .. Looper.toastText
        hintCol = C.AMBER
    end

    self:setColor(C.GRID)
    love.graphics.line(9, 322, 631, 322)
    self:setColor(C.BG)
    love.graphics.rectangle("fill", 9, 323, 622, 32, 4, 4)

    self:setColor(hintCol)
    love.graphics.setFont(self.fontSmall)
    love.graphics.print(hintText, 24, 331)
end

-- ============================================================================
-- REGION 3: THEMATIC CONSTELLATION TAPE DECK (y: 362..474)
-- ============================================================================
function Chrome:drawTapeDeck()
    local C = Config.COLORS
    local activeCol = Config.TRACK_COLORS[Looper.activeTrack]
    local lx = 148
    local lw = 456
    local totalSixteenths = Looper:getTotalSixteenths()

    self:drawFrame(8, 362, 624, 112, C.GRID, 1, activeCol)

    -- Vertical divider between headers and lanes
    self:setColor(C.GRID)
    love.graphics.line(136, 368, 136, 468)

    -- Continuous bar & beat grid lines spanning the 4 threads
    for s = 0, totalSixteenths, 4 do
        local sx = lx + (s / totalSixteenths) * lw
        local isBar = (s % 16 == 0)
        self:setColor(isBar and C.GRID or C.PANEL_HI)
        love.graphics.line(sx, 370, sx, 466)
        if isBar then
            self:drawDiamond(sx, 368, 2.0, C.MUTED)
            self:drawDiamond(sx, 468, 2.0, C.MUTED)
        end
    end

    for tIdx = 1, 4 do
        local ry = 369 + (tIdx - 1) * 25
        local cy = ry + 11
        local isSel = (Looper.activeTrack == tIdx)
        local tColor = Config.TRACK_COLORS[tIdx]
        local track = Looper.tracks[tIdx]
        local grid = Looper:getTrackGrid(tIdx)

        -- Left Track Header
        if isSel then
            self:setColor(tColor, 0.14)
            love.graphics.rectangle("fill", 12, ry, 120, 22, 3, 3)
            self:drawStarGlint(19, cy, 4.5, tColor, 1.0)
        else
            self:drawDiamond(19, cy, 2.0, track.muted and C.DIM or tColor)
        end

        self:setColor(isSel and C.TEXT or C.MUTED)
        love.graphics.setFont(self.fontSmall)
        love.graphics.print(string.format("%d %s", tIdx, track.shortName or "TRK"), 28, ry + 3)

        self:setColor((grid.id ~= "FREE") and C.MINT or C.DIM)
        love.graphics.setFont(self.fontTiny)
        love.graphics.print(grid.label, 78, ry + 4)

        -- Mute Rune Tag (Diamond vs M)
        if track.muted then
            self:drawTag(112, ry + 2, 18, 18, "M", C.RED, C.RED, C.BG, self.fontTiny)
        else
            self:drawTag(112, ry + 2, 18, 18, "", C.GRID, C.PANEL_HI, tColor, self.fontTiny)
            self:drawDiamond(121, ry + 11, 2.6, tColor)
        end

        -- Constellation Thread Lane
        if isSel then
            self:setColor(tColor, 0.07)
            love.graphics.rectangle("fill", lx - 2, ry + 2, lw + 4, 18, 3, 3)
        end
        self:setColor(isSel and tColor or C.GRID, isSel and 0.55 or 0.8)
        love.graphics.line(lx, cy, lx + lw, cy)

        self:drawDiamond(lx, cy, isSel and 2.8 or 1.8, isSel and tColor or C.DIM)
        self:drawDiamond(lx + lw, cy, isSel and 2.8 or 1.8, isSel and tColor or C.DIM)

        -- Recorded Events: Starlight beads & aurora ribbons
        local col = track.muted and C.DIM or tColor
        for _, ev in ipairs(track.events) do
            local x = lx + Looper:evPhase(ev) * (lw - 4)
            if ev.duration or ev.dur then
                local w = math_max(6, (ev.duration or ev.dur) * lw)
                self:setColor(col, 0.28)
                love.graphics.rectangle("fill", x, cy - 4.5, w, 9, 3, 3)
                self:setColor(col, 0.9)
                love.graphics.rectangle("fill", x, cy - 2.5, w, 5, 2, 2)
                self:drawDiamond(x + 2, cy, 2.0, C.TEXT)
            else
                local vel = ev.vel or 0.85
                if vel >= 0.88 and not track.muted then
                    self:drawStarGlint(x, cy, 5.5, col, 0.95)
                    self:setColor(C.TEXT)
                    love.graphics.circle("fill", x, cy, 1.8)
                else
                    local radius = 2.0 + vel * 1.6
                    self:setColor(col, 0.22)
                    love.graphics.circle("fill", x, cy, radius + 1.5)
                    self:setColor(col)
                    love.graphics.circle("fill", x, cy, radius)
                end
            end
        end

        -- Level meter on far right
        local peak = track.muted and 0.0 or track.meterPeak
        self:setColor(C.GRID)
        love.graphics.setLineWidth(2)
        love.graphics.line(616, ry + 3, 616, ry + 19)
        local mh = math_floor(16 * peak)
        if mh > 0 then
            self:setColor(col)
            love.graphics.setLineWidth(2.5)
            love.graphics.line(616, ry + 19 - mh, 616, ry + 19)
            self:drawDiamond(616, ry + 19 - mh, 2.2, col)
        end
        love.graphics.setLineWidth(1)
    end

    -- Shooting Star Sweeping Playhead
    local px = lx + Looper.phase * lw
    local isRec = (Modes.current == "REC_LATCH" or Modes.current == "REC_HOLD")
    local playCol = isRec and C.RED or C.TEXT

    -- Comet wake trailing behind playhead
    local wakeW = math_min(14, px - lx)
    if wakeW > 1 then
        self:setColor(playCol, 0.08)
        love.graphics.rectangle("fill", px - wakeW, 368, wakeW, 98)
        self:setColor(playCol, 0.14)
        love.graphics.rectangle("fill", px - wakeW * 0.45, 368, wakeW * 0.45, 98)
    end

    self:setColor(playCol)
    love.graphics.setLineWidth(1.5)
    love.graphics.line(px, 366, px, 470)
    love.graphics.setLineWidth(1)
    self:drawStarGlint(px, 366, 7.0, playCol, 1.0)
    self:drawStarGlint(px, 470, 5.5, playCol, 0.9)
    self:drawDiamond(px, 366, 2.5, C.TEXT)

    -- Dim the deck while a settings page has focus
    local mode = Modes.current or "NORMAL"
    if mode == "TRACK" or mode == "TRANSPORT" or mode == "MIX" then
        self:setColor(C.BG, 0.55)
        love.graphics.rectangle("fill", 7, 361, 626, 114)
    end
end

function Chrome:draw()
    local C = Config.COLORS
    love.graphics.clear(C.BG[1], C.BG[2], C.BG[3], 1.0)

    local winW, winH = love.graphics.getDimensions()
    local scale = math_min(winW / Config.SCREEN_W, winH / Config.SCREEN_H)
    local offsetX = math_floor((winW - Config.SCREEN_W * scale) * 0.5)
    local offsetY = math_floor((winH - Config.SCREEN_H * scale) * 0.5)

    love.graphics.push()
    love.graphics.translate(offsetX, offsetY)
    love.graphics.scale(scale, scale)

    self:drawTopBar()
    self:drawCenterStage()
    self:drawTapeDeck()

    love.graphics.pop()
end

return Chrome
