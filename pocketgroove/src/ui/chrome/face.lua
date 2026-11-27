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
local Song        = require("src.song")
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
-- ZONE 3: THE FACE-BUTTON RING (cx=538, cy=188)
-- Four lenses on an orbit, glints between them. A held or lit button fills
-- solid in the page colour; a hit flashes it. A label with an icon (below)
-- draws the icon with a small word under it.
-- ============================================================================

-- Icons, by the label a button carries. Each draws at (x, y) in colour c.
local function lw(w) love.graphics.setLineWidth(w) end

local function moonIcon(f)
    return function(self, x, y)
        local r = 6.5
        lw(1.3)
        love.graphics.circle("line", x, y, r)
        lw(1)
        if f >= 0.98 then
            love.graphics.circle("fill", x, y, r)
        elseif f > 0.02 then
            -- lit part, waxing: the right half's rim to an inner edge whose
            -- width runs from the rim (thin crescent) through the middle
            -- (half) to past it (gibbous); drawn as thin strips
            local k = 1 - 2 * f
            local n = 10
            for i = 0, n - 1 do
                local a0 = -math_pi * 0.5 + math_pi * i / n
                local a1 = -math_pi * 0.5 + math_pi * (i + 1) / n
                local c0, s0, c1, s1 = math_cos(a0), math_sin(a0), math_cos(a1), math_sin(a1)
                love.graphics.polygon("fill",
                    x + c0 * r, y + s0 * r, x + c1 * r, y + s1 * r,
                    x + c1 * r * k, y + s1 * r, x + c0 * r * k, y + s0 * r)
            end
        end
    end
end

Chrome.FACE_ICONS = {
    -- Bass: articulation marks
    ACCENT = function(self, x, y) lw(2.2); love.graphics.line(x - 8, y - 5, x + 8, y, x - 8, y + 5); lw(1) end,
    STAC   = function(self, x, y) love.graphics.circle("fill", x, y, 3.5) end,
    LEGATO = function(self, x, y)
        lw(2.2)
        local pts = {}
        for i = 0, 10 do
            local t = i / 10
            pts[#pts + 1] = x - 11 + 22 * t
            pts[#pts + 1] = y + 4 - 13 * t * (1 - t) * 4 * 0.5
        end
        love.graphics.line(pts)
        lw(1)
    end,
    HOLD   = function(self, x, y) love.graphics.rectangle("fill", x - 10, y - 1.5, 20, 3, 1, 1) end,
    -- Lead: arp directions
    ["ARP UP"]   = function(self, x, y) lw(2.2); love.graphics.line(x - 6, y + 3, x, y - 5, x + 6, y + 3); lw(1) end,
    ["ARP DOWN"] = function(self, x, y) lw(2.2); love.graphics.line(x - 6, y - 3, x, y + 5, x + 6, y - 3); lw(1) end,
    ["UP DOWN"]  = function(self, x, y)
        lw(2); love.graphics.line(x - 9, y + 1, x - 4, y - 5, x + 1, y + 1); love.graphics.line(x - 1, y - 1, x + 4, y + 5, x + 9, y - 1); lw(1)
    end,
    NOTE = function(self, x, y)
        love.graphics.circle("fill", x - 2, y + 3, 3.5)
        love.graphics.rectangle("fill", x + 0.5, y - 7, 2, 10)
        love.graphics.polygon("fill", x + 2.5, y - 7, x + 7, y - 4, x + 2.5, y - 3)
    end,
    -- Pad: layers as moon phases, swell to full
    SWELL = moonIcon(0.25), HIGH = moonIcon(0.5), OPEN = moonIcon(0.75), FULL = moonIcon(1.0),
    -- Track C: the edits as tools
    STAMP  = function(self, x, y) love.graphics.rectangle("fill", x - 8, y + 2, 16, 4, 1, 1); love.graphics.rectangle("fill", x - 3, y - 6, 6, 8, 1.5, 1.5) end,
    DELETE = function(self, x, y) lw(2.4); love.graphics.line(x - 6, y - 5, x + 6, y + 5); love.graphics.line(x + 6, y - 5, x - 6, y + 5); lw(1) end,
    COLOUR = function(self, x, y)
        love.graphics.circle("fill", x - 6, y + 2, 3); love.graphics.circle("fill", x, y - 5, 3); love.graphics.circle("fill", x + 6, y + 2, 3)
    end,
    WRITE  = function(self, x, y) love.graphics.polygon("fill", x - 8, y + 6, x - 6, y + 1, x + 4, y - 8, x + 8, y - 4, x - 2, y + 4) end,
    -- Drums: the kind of sound on the pad
    KICK  = function(self, x, y) lw(2); love.graphics.circle("line", x, y, 6); lw(1); love.graphics.circle("fill", x, y, 2) end,
    TOM   = function(self, x, y)
        local pts = {}
        for i = 0, 15 do
            local a = i * math_pi / 8
            pts[#pts + 1] = x + math_cos(a) * 7
            pts[#pts + 1] = y + math_sin(a) * 4.5
        end
        lw(2); love.graphics.polygon("line", pts); lw(1)
        love.graphics.circle("fill", x, y, 1.5)
    end,
    SNARE = function(self, x, y) lw(2); love.graphics.rectangle("line", x - 8, y - 4, 16, 8, 2, 2); lw(1); love.graphics.line(x - 8, y, x + 8, y) end,
    HAT   = function(self, x, y) love.graphics.polygon("fill", x - 9, y + 1, x, y - 3, x + 9, y + 1); lw(1.5); love.graphics.line(x, y - 3, x, y + 6); lw(1) end,
    CYM   = function(self, x, y) love.graphics.polygon("fill", x - 10, y + 2, x, y - 3, x + 10, y + 2); lw(1.5); love.graphics.line(x - 4, y + 6, x + 4, y + 6); lw(1) end,
    CLAP  = function(self, x, y, c) self:drawStarGlint(x, y, 7, c) end,
    PERC  = function(self, x, y, c) self:drawDiamond(x, y, 5, c) end,
    BELL  = function(self, x, y) love.graphics.arc("fill", x, y + 3, 7, math_pi, 2 * math_pi); love.graphics.circle("fill", x, y + 5, 2) end,
    FX    = function(self, x, y, c) self:drawStarGlint(x, y, 6, c); self:setColor(c); love.graphics.circle("fill", x + 6, y - 5, 1.5) end,
}
-- The word under an icon, where it differs from the label
Chrome.FACE_ICON_WORDS = { ["ARP UP"] = "UP", ["ARP DOWN"] = "DOWN", ["UP DOWN"] = "UP-DN" }

function Chrome:drawCircleFaceButtons(cx, cy, faceLabels, col, flashMap, activeMap)
    local C = Config.COLORS
    local shade = Config.shade
    local R_ORB = 54
    local r = 24
    local pos = {
        X = { x = cx,         y = cy - R_ORB },
        Y = { x = cx - R_ORB, y = cy         },
        A = { x = cx + R_ORB, y = cy         },
        B = { x = cx,         y = cy + R_ORB },
    }

    -- The orbit
    self:setColor(shade(col, 0.45))
    love.graphics.circle("line", cx, cy, R_ORB)

    -- 4 outer compass arcs, for a view with no halo of its own
    if not self.haloDrawn then
        for i = 0, 3 do
            local a1 = (i * math_pi * 0.5) + 0.36
            local a2 = ((i + 1) * math_pi * 0.5) - 0.36
            self:setColor(shade(col, 0.4))
            love.graphics.arc("line", "open", cx, cy, 74, a1, a2)
        end
    end

    -- 4 glints along the orbit, between the buttons
    for i = 0, 3 do
        local ang = (math_pi * 0.25) + i * (math_pi * 0.5)
        self:drawStarGlint(cx + math_cos(ang) * R_ORB, cy + math_sin(ang) * R_ORB, 5.5, col, 1.0)
    end

    -- Centre crosshair and glint
    self:setColor(shade(col, 0.4))
    love.graphics.line(cx - 12, cy, cx + 12, cy)
    love.graphics.line(cx, cy - 12, cx, cy + 12)
    self:drawStarGlint(cx, cy, 7, shade(col, 0.8), 1.0)

    local btnOrder = { "X", "Y", "A", "B" }
    local isTrackFx = (Modes.current == "TRACK" and not Song.page
                       and Looper.tracks[Looper.activeTrack] and not Looper.tracks[Looper.activeTrack].isLane)
    local selFxBtn
    if isTrackFx then
        local track = Looper.tracks[Looper.activeTrack]
        local def, state = Instruments:getTrackInstrument(Looper.activeTrack)
        local rows = Instruments:getSoundRows(def, state, track)
        local cur = rows[Modes.trackPage.row]
        if cur and (cur.kind == "fx" or cur.kind == "fx_type") then selFxBtn = cur.button end
    end

    for _, btn in ipairs(btnOrder) do
        local p = pos[btn]
        if isTrackFx then
            local track = Looper.tracks[Looper.activeTrack]
            local fxId = Looper:getTrackFxId(Looper.activeTrack, btn)
            local fxDef = Synth.FX_BY_ID[fxId]
            local on = track.fx.on[fxId] == true
            local amt = track.fx[fxId] or 0
            local isSel = (selFxBtn == btn)
            local name = fxDef and fxDef.label or fxId:upper()
            local pct = on and (math_floor(amt * 100 + 0.5) .. "%") or "OFF"

            if isSel then
                self:setColor(col, 0.9)
                self:drawDashedCircle(p.x, p.y, r + 5, 2, 3)
            else
                self:setColor(shade(col, on and 0.45 or 0.22))
                love.graphics.circle("line", p.x, p.y, r + 3)
            end
            self:setColor(shade(col, on and 0.14 or 0.06))
            love.graphics.circle("fill", p.x, p.y, r)

            -- Clipped moon-phase polygon inside the button lens
            if on and amt > 0.01 then
                local mr = r - 1.5
                local pts, steps = {}, 20
                for i = 0, steps do
                    local a = -math_pi * 0.5 - (i / steps) * math_pi
                    pts[#pts + 1] = p.x + math_cos(a) * mr
                    pts[#pts + 1] = p.y + math_sin(a) * mr
                end
                local rx = (amt * 2.0 - 1.0) * mr
                for i = 0, steps do
                    local a = math_pi * 0.5 - (i / steps) * math_pi
                    pts[#pts + 1] = p.x + math_cos(a) * rx
                    pts[#pts + 1] = p.y + math_sin(a) * mr
                end
                self:setColor(col, 0.34)
                love.graphics.polygon("fill", pts)
            end

            self:setColor(on and col or shade(col, 0.4))
            love.graphics.setLineWidth(isSel and 2.0 or (on and 1.6 or 1.1))
            love.graphics.circle("line", p.x, p.y, r)
            love.graphics.setLineWidth(1)

            love.graphics.setFont(self.fontTiny)
            self:setColor(on and C.TEXT or C.MUTED, on and 1.0 or 0.65)
            love.graphics.print(name, math_floor(p.x - self.fontTiny:getWidth(name) * 0.5), p.y - 10)
            self:setColor(on and col or C.DIM, on and 1.0 or 0.8)
            love.graphics.print(pct, math_floor(p.x - self.fontTiny:getWidth(pct) * 0.5), p.y + 2)
        else
        local fl = (flashMap and flashMap[btn]) or 0.0
        local isActive = (activeMap and activeMap[btn]) or (Input.down[btn] and not Input.down.R2)
        local btnCol = col
        if Modes.current == "MIX" then
            local slot = btn == "B" and 1 or (btn == "A" and 2 or (btn == "Y" and 3 or 4))
            local pending = Song.pendingMutes[slot]
            local muted = (pending ~= nil) and pending or Looper.tracks[slot].muted
            if muted then btnCol = C.RED end
        end
        local lit = isActive or fl > 0.5

        -- Press burst
        if fl > 0.05 then
            self:setColor(btnCol, fl * 0.75)
            love.graphics.circle("line", p.x, p.y, r + 7)
            self:drawStarGlint(p.x, p.y, r + 10, btnCol, fl * 0.6)
        end

        -- Outer ring, then the lens: a dark shade, or solid when lit
        self:setColor(shade(btnCol, 0.5))
        love.graphics.circle("line", p.x, p.y, r + 3)
        self:setColor(shade(btnCol, 0.14))
        love.graphics.circle("fill", p.x, p.y, r)
        if isActive then
            self:setColor(btnCol)
            love.graphics.circle("fill", p.x, p.y, r)
        elseif fl > 0.02 then
            self:setColor(btnCol, math_min(1, fl * 1.2))
            love.graphics.circle("fill", p.x, p.y, r)
        end
        self:setColor(btnCol)
        love.graphics.setLineWidth(1.6)
        love.graphics.circle("line", p.x, p.y, r)
        love.graphics.setLineWidth(1)

        local fg = lit and C.BG or C.TEXT
        local label = faceLabels and faceLabels[btn]
        local icon = type(label) == "string" and self.FACE_ICONS[label]
        if not label or label == "" then
            self:drawDiamond(p.x, p.y, lit and 3.5 or 2.2, lit and C.BG or shade(btnCol, 0.6))
        elseif icon then
            self:setColor(fg)
            icon(self, p.x, p.y - 5, fg)
            local word = self.FACE_ICON_WORDS[label] or label
            love.graphics.setFont(self.fontTiny)
            self:setColor(fg)
            love.graphics.print(word, math_floor(p.x - self.fontTiny:getWidth(word) * 0.5), p.y + 5)
        elseif type(label) == "table" and label.l1 and label.l2 then
            self:setColor(lit and C.BG or btnCol)
            love.graphics.setFont(self.fontTiny)
            local w1 = self.fontTiny:getWidth(label.l1)
            love.graphics.print(label.l1, math_floor(p.x - w1 * 0.5), p.y - 7)
            self:setColor(fg)
            love.graphics.setFont(self.fontSmall)
            local w2 = self.fontSmall:getWidth(label.l2)
            love.graphics.print(label.l2, math_floor(p.x - w2 * 0.5), p.y + 4)
        else
            local text = tostring(label or btn)
            local s1, s2 = text:match("^(%S+)%s+(%S+)$")
            if s1 and s2 then
                self:setColor(lit and C.BG or btnCol)
                love.graphics.setFont(self.fontTiny)
                local w1 = self.fontTiny:getWidth(s1)
                love.graphics.print(s1, math_floor(p.x - w1 * 0.5), p.y - 7)
                self:setColor(fg)
                love.graphics.setFont(self.fontSmall)
                local w2 = self.fontSmall:getWidth(s2)
                love.graphics.print(s2, math_floor(p.x - w2 * 0.5), p.y + 4)
            else
                self:setColor(fg)
                local font = (#text <= 3) and self.fontMed or self.fontSmall
                love.graphics.setFont(font)
                local tw = font:getWidth(text)
                local th = self:lineHeight(font)
                love.graphics.print(text, math_floor(p.x - tw * 0.5), math_floor(p.y - th * 0.5))
            end
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
