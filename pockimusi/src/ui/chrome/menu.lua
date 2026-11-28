-- ============================================================================
-- src/ui/chrome/menu.lua — The menu (hold SELECT + START), drawn over the stage
-- (part of src/ui/chrome.lua: adds methods to the Chrome table)
--
-- Everything under the top bar is covered by the top list, or by the
-- slot list A–H when saving or loading a pattern.
-- ============================================================================

local Config   = require("src.config")
local Menu     = require("src.menu")
local Session  = require("src.session")
local Patterns = require("src.patterns")
local Fonts    = require("src.ui.fonts")
local Song     = require("src.song")

local clamp      = Config.clamp
local math_floor = math.floor

return function(Chrome)

local X, Y, W, H = 8, 52, 624, 422          -- the area under the top bar

local function accent()
    return Config.MODE_COLORS.MENU or Config.COLORS.CYAN
end

-- Text centred vertically on `cy`
function Chrome:menuText(text, x, cy, font, col, alpha)
    love.graphics.setFont(font)
    self:setColor(col, alpha)
    love.graphics.print(text, math_floor(x), math_floor(cy - self:lineHeight(font) * 0.5))
end

function Chrome:menuTextRight(text, xr, cy, font, col, alpha)
    self:menuText(text, xr - font:getWidth(text), cy, font, col, alpha)
end

local function plate(self)
    return self.MOCK == "D"
end

-- PLATE look: the current track's scenery dimmed behind a moonlit,
-- cut-corner panel, the title in spaced lettering
local function plateFrame(self, title, right)
    local C = Config.COLORS
    local Looper = require("src.looper")
    local Instruments = require("src.instruments")
    local def = Instruments:getTrackInstrument(Looper.activeTrack)
    local instCol = self:trackColor(Looper.activeTrack)
    self:setColor(C.BG)
    love.graphics.rectangle("fill", X - 2, Y - 2, W + 4, H + 8)
    self:drawStageMood(def, instCol, 102, 188, 538, 188)
    self:setColor(C.BG, 0.55)
    love.graphics.rectangle("fill", X, Y, W, H)
    local edge = self:mockEdge("MENU")
    local panel = self.mockChamfer(X + 6, Y + 50, W - 12, H - 56, 10)
    self:setColor(C.BG, 0.97)
    love.graphics.polygon("fill", panel)
    self:mockEmblem("MENU", "plate", edge)
    self:mockGlowPoly(panel, edge, 0.75)
    -- clear the cut corners, then the outer frame
    local CH = 12
    self:setColor(C.BG)
    love.graphics.polygon("fill", X - 1, Y - 1, X + CH, Y - 1, X - 1, Y + CH)
    love.graphics.polygon("fill", X + W + 1, Y - 1, X + W - CH, Y - 1, X + W + 1, Y + CH)
    love.graphics.polygon("fill", X - 1, Y + H + 1, X + CH, Y + H + 1, X - 1, Y + H - CH)
    love.graphics.polygon("fill", X + W + 1, Y + H + 1, X + W - CH, Y + H + 1, X + W + 1, Y + H - CH)
    self:mockGlowPoly(self.mockChamfer(X, Y, W, H, CH), edge, 0.8)
    -- title
    self:mockGlyph("MENU", X + 26, Y + 25, C.SILVER)
    local spaced = title:gsub(".", "%0 "):sub(1, -2)
    self:menuText(spaced, X + 42, Y + 25, self.fontLarge, C.TEXT)
    if right then self:menuTextRight(right, X + W - 20, Y + 25, self.fontSmall, C.MUTED) end
end

local function frame(self, title, right)
    if plate(self) then return plateFrame(self, title, right) end
    local C, col = Config.COLORS, accent()
    self:setColor(C.BG, 0.94)
    love.graphics.rectangle("fill", X - 2, Y - 2, W + 4, H + 8)
    self:setColor(C.PANEL)
    love.graphics.rectangle("fill", X, Y, W, H, 6, 6)
    self:setColor(col)
    love.graphics.setLineWidth(1.6)
    love.graphics.rectangle("line", X, Y, W, H, 6, 6)
    love.graphics.setLineWidth(1)

    self:drawStarGlint(X + 22, Y + 22, 6, col, 1.0)
    self:menuText(title, X + 36, Y + 22, self.fontLarge, C.TEXT)
    if right then self:menuTextRight(right, X + W - 18, Y + 22, self.fontSmall, C.MUTED) end
    self:setColor(C.GRID)
    love.graphics.line(X + 12, Y + 42, X + W - 12, Y + 42)
end

-- The bottom line: the latest message, or what the buttons do
local function footer(self, hints)
    local C, col = Config.COLORS, accent()
    local cy = Y + H - 18
    if plate(self) then
        cy = Y + H - 20
        self:setColor(C.SILVER, 0.18)
        love.graphics.line(X + 20, cy - 13, X + W - 20, cy - 13)
        if Menu.message then
            local a = clamp(Menu.messageTimer / 0.3, 0.0, 1.0)
            self:menuText(Menu.message, X + 22, cy, self.fontSmall, C.TEXT, a)
        else
            self:menuText(hints, X + 22, cy, self.fontTiny, C.MUTED)
        end
        return
    end
    self:setColor(C.GRID)
    love.graphics.line(X + 12, cy - 16, X + W - 12, cy - 16)
    if Menu.message then
        local a = clamp(Menu.messageTimer / 0.3, 0.0, 1.0)
        self:menuText(Menu.message, X + 18, cy, self.fontSmall, col, a)
    else
        self:menuText(hints, X + 18, cy, self.fontTiny, C.MUTED)
    end
end

local function currentLabel()
    return Session.patternSlot and ("NOW: PATTERN " .. Session.patternSlot) or "NOW: NO SLOT - GO TO ONE"
end

-- Which heading each root row sits under on the PLATE look
local SECTIONS = { GOTO = "PATTERNS", COPY = "PATTERNS", CLEAR = "PATTERNS", SONG = "PERFORM",
                   FONTS = "DISPLAY", LOOK = "DISPLAY", OPT = "TEST: PLATE LOOK" }

local function rootValue(self, item)
    if item.id == "SONG" then return Song:isOn() and "ON" or "OFF", Song:isOn() end
    if item.id == "FONTS" then return Fonts.set end
    if item.id == "LOOK" then return self.look or "CLASSIC" end
    if item.id == "OPT" then return self.mockOpt[item.key] or "?" end
end

function Chrome:drawMenuRootPlate()
    local C = Config.COLORS
    local Looper = require("src.looper")
    local instCol = self:trackColor(Looper.activeTrack)
    local moon = self.MOCK_MOON
    frame(self, "MENU", currentLabel())
    local rh, gap, y = 25, 4, Y + 60
    local lastSec
    for i, item in ipairs(Menu.ITEMS) do
        local sec = SECTIONS[item.id] or ""
        if sec ~= lastSec then
            love.graphics.setFont(self.fontTiny)
            local sw = self.fontTiny:getWidth(sec)
            self:setColor(C.SILVER, 0.7)
            love.graphics.print(sec, X + 30, y)
            self:setColor(C.SILVER, 0.16)
            love.graphics.line(X + 36 + sw, y + 6, X + W - 30, y + 6)
            y = y + 15
            lastSec = sec
        end
        local cur = (i == Menu.row)
        local rx, rw = X + 22, W - 44
        local pts = self.mockChamfer(rx + 0.5, y + 0.5, rw, rh, 5)
        if cur then
            self:setColor(instCol, 0.16)
            love.graphics.polygon("fill", pts)
            self:mockGlowPoly(pts, moon, 0.9)
            self:setColor(instCol)
            love.graphics.rectangle("fill", rx + 6, y + 6, 3, rh - 12, 1, 1)
        else
            self:setColor(C.SILVER, 0.14)
            love.graphics.polygon("line", pts)
        end
        local cy = y + rh * 0.5
        local label = item.label:gsub("^PLATE: ", "")
        self:menuText(label, rx + 20, cy, self.fontMed, cur and C.TEXT or C.MUTED)
        local val, lit = rootValue(self, item)
        local xr = rx + rw - 14
        if val then
            local f = self.fontMed
            local vw = f:getWidth(val)
            local vcol = lit and C.SONG or (cur and C.TEXT or C.TEXT)
            self:menuTextRight(val, xr - 12, cy, f, vcol, cur and 1 or 0.85)
            -- chevrons either side of the value
            local cl, cr = xr - 12 - vw - 10, xr - 2
            self:mockChevron(cl, cy, "LEFT", 3.2, cur and instCol or C.SILVER, cur and 1 or 0.45)
            self:mockChevron(cr, cy, "RIGHT", 3.2, cur and instCol or C.SILVER, cur and 1 or 0.45)
        elseif cur then
            self:menuTextRight("B", xr - 12, cy, self.fontSmall, C.TEXT)
            self:mockChevron(xr - 2, cy, "RIGHT", 3.2, instCol, 1)
        end
        y = y + rh + gap
    end
    local item = Menu.ITEMS[Menu.row]
    footer(self, (item and item.hint or "") .. "     -     UP / DOWN  MOVE   B  CHOOSE   A  BACK")
end

function Chrome:drawMenuRoot()
    if plate(self) then return self:drawMenuRootPlate() end
    local C, col = Config.COLORS, accent()
    frame(self, "MENU", currentLabel())
    local n = #Menu.ITEMS
    local compact = n > 6                    -- one line per row; the hint goes to the footer
    local gap = compact and 4 or 6
    local rh = compact and 32 or ((n > 5) and 50 or 62)
    local top = Y + 58
    for i, item in ipairs(Menu.ITEMS) do
        local y = top + (i - 1) * (rh + gap)
        local cur = (i == Menu.row)
        local soon = false
        if cur then
            self:setColor(col, 0.16)
            love.graphics.rectangle("fill", X + 16, y, W - 32, rh, 8, 8)
            self:setColor(col)
            love.graphics.rectangle("line", X + 16, y, W - 32, rh, 8, 8)
            self:drawDiamond(X + 34, y + rh * 0.5, 5, col)
        else
            self:setColor(C.GRID)
            love.graphics.rectangle("line", X + 16, y, W - 32, rh, 8, 8)
        end
        local textCol = soon and C.MUTED or (cur and C.TEXT or C.MUTED)
        if compact then
            self:menuText(item.label, X + 52, y + rh * 0.5, self.fontMed, textCol)
        else
            self:menuText(item.label, X + 52, y + rh * 0.5 - 8, self.fontMed, textCol)
            self:menuText(item.hint, X + 52, y + rh * 0.5 + 12, self.fontTiny, soon and C.DIM or C.MUTED)
        end

        local xr = X + W - 34
        if item.id == "SONG" then
            local on = Song:isOn()
            self:menuTextRight(on and "<  ON  >" or "<  OFF  >", xr, y + rh * 0.5, self.fontMed,
                on and Config.COLORS.SONG or (cur and col or C.TEXT))
        elseif item.id == "OPT" then
            self:menuTextRight("<  " .. (self.mockOpt[item.key] or "?") .. "  >", xr, y + rh * 0.5, self.fontMed, cur and col or C.TEXT)
        elseif item.id == "LOOK" then
            self:menuTextRight("<  " .. (self.look or "CLASSIC") .. "  >", xr, y + rh * 0.5, self.fontMed, cur and col or C.TEXT)
        elseif item.id == "FONTS" then
            local name = Fonts.set
            local f = self.fontMed
            self:menuTextRight("<  " .. name .. "  >", xr, y + rh * 0.5, f, cur and col or C.TEXT)
        elseif soon then
            local tag = "SOON"
            local tw = self.fontTiny:getWidth(tag) + 14
            self:setColor(C.DIM)
            love.graphics.rectangle("fill", xr - tw, y + rh * 0.5 - 8, tw, 16, 3, 3)
            self:menuText(tag, xr - tw + 7, y + rh * 0.5, self.fontTiny, C.TEXT)
        elseif cur then
            self:menuTextRight("B  >", xr, y + rh * 0.5, self.fontSmall, col)
        end
    end
    if compact then
        local item = Menu.ITEMS[Menu.row]
        footer(self, (item and item.hint or "") .. "     -     UP / DOWN  MOVE   B  CHOOSE   A  BACK")
    else
        footer(self, "UP / DOWN  MOVE     B  CHOOSE     A  BACK     START  CLOSE")
    end
end

local function savedLabel(t)
    if not t or t <= 0 or not (os and os.date) then return "" end
    local ok, s = pcall(os.date, "%b %d  %H:%M", t)
    return ok and s and s:upper() or ""
end

-- `text` cut to fit `w` pixels in `font`, with ".." when it was cut
function Chrome:fitText(text, font, w)
    if font:getWidth(text) <= w then return text end
    while #text > 1 and font:getWidth(text .. "..") > w do text = text:sub(1, -2) end
    return text .. ".."
end

-- The little tape deck, the big one (tapedeck.lua) pared down, in a small
-- inset frame: a faint thread per track in its instrument's colour and a
-- rounded mark for every note. Hits and held notes are the same shape and
-- height (a hit is a held note of minimum length), so they read as one set.
-- A faint line at each bar; a 2-bar loop fills the same width as a 4-bar
-- one. Bright on the row under the cursor (its frame takes the row colour),
-- dim on the others; a muted track goes grey.
Chrome.MINI_NOTE_H = 3          -- note height (px)
Chrome.MINI_HIT_W  = 4          -- a hit's width (px)
Chrome.MINI_PAD    = { 7, 4 }   -- inside the frame: left/right, top/bottom

function Chrome:drawMiniDeck(x, y, w, h, sum, active, frameCol)
    local C = Config.COLORS
    local lanes = sum.lanes or {}
    local dim = active and 1.0 or 0.5
    local px, py = self.MINI_PAD[1], self.MINI_PAD[2]

    -- the frame: a darker inset with a hairline border
    self:setColor(C.BG, active and 0.75 or 0.45)
    love.graphics.rectangle("fill", x, y, w, h, 4, 4)
    self:setColor(active and Config.shade(frameCol or C.GRID, 0.55) or C.GRID)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, 4, 4)

    local ix, iw = x + px, w - px * 2
    local iy, ih = y + py, h - py * 2

    -- bar lines
    for b = 1, sum.bars - 1 do
        local bx = math_floor(ix + iw * b / sum.bars) + 0.5
        self:setColor(C.GRID, dim)
        love.graphics.line(bx, y + 2, bx, y + h - 2)
    end

    local nh, hw = self.MINI_NOTE_H, self.MINI_HIT_W
    local r = nh * 0.5
    local pitch = ih / 4
    for i = 1, 4 do
        local lane = lanes[i] or { notes = {} }
        local cy = math_floor(iy + (i - 0.5) * pitch + 0.5)
        local col = (lane.id and Config.INST_COLORS[lane.id]) or Config.TRACK_COLORS[i] or C.MUTED
        if lane.muted then col = C.DIM end

        self:setColor(col, 0.16 * dim)
        love.graphics.rectangle("fill", ix, cy - 0.5, iw, 1)

        self:setColor(col, dim)
        for _, n in ipairs(lane.notes) do
            local nx = ix + n[1] * iw
            local nw = math.max(hw, (n[2] - n[1]) * iw)
            nw = math.min(nw, ix + iw - nx)
            if nw > 0 then
                love.graphics.rectangle("fill", nx, cy - r, math.max(nw, nh), nh, r, r)
            end
        end
    end
end

function Chrome:drawMenuSlots()
    local C, col = Config.COLORS, accent()
    local TITLES = { GOTO = "GO TO PATTERN", COPY = "COPY PATTERN", CLEAR = "CLEAR PATTERN" }
    local HINTS = { GOTO = "B  GO THERE", COPY = "B  COPY HERE", CLEAR = "B  CLEAR" }
    frame(self, TITLES[Menu.page] or "PATTERNS", currentLabel())
    local rh, gap, top = 36, 4, Y + 52
    if plate(self) then rh, gap, top = 34, 4, Y + 58 end
    for i, slot in ipairs(Patterns.SLOTS) do
        local y = top + (i - 1) * (rh + gap)
        local cur = (i == Menu.slotRow)
        local sum = Menu.slots[slot] or { empty = true }
        local isNow = (Session.patternSlot == slot)
        local confirming = (Menu.confirm == slot)
        local rowCol = confirming and C.AMBER or col

        if plate(self) then
            local pts = self.mockChamfer(X + 22.5, y + 0.5, W - 44, rh, 5)
            if cur then
                local ic = confirming and C.AMBER or self:trackColor(require("src.looper").activeTrack)
                self:setColor(ic, 0.16)
                love.graphics.polygon("fill", pts)
                self:mockGlowPoly(pts, self.MOCK_MOON, 0.9)
            else
                self:setColor(C.SILVER, 0.12)
                love.graphics.polygon("line", pts)
            end
        elseif cur then
            self:setColor(rowCol, 0.16)
            love.graphics.rectangle("fill", X + 16, y, W - 32, rh, 6, 6)
            self:setColor(rowCol)
            love.graphics.rectangle("line", X + 16, y, W - 32, rh, 6, 6)
        end

        -- the slot's letter as a badge
        local bx, bw = X + 24, 26
        if sum.empty then
            self:setColor(C.DIM)
            love.graphics.rectangle("line", bx, y + 6, bw, rh - 12, 4, 4)
            self:menuText(slot, bx + (bw - self.fontMed:getWidth(slot)) * 0.5, y + rh * 0.5, self.fontMed, C.MUTED)
        else
            self:setColor(cur and rowCol or C.MUTED)
            love.graphics.rectangle("fill", bx, y + 6, bw, rh - 12, 4, 4)
            self:menuText(slot, bx + (bw - self.fontMed:getWidth(slot)) * 0.5, y + rh * 0.5, self.fontMed, C.BG)
        end

        local tx, cy = bx + bw + 14, y + rh * 0.5
        local mapX, mapW = X + 300, 236
        if sum.empty then
            self:menuText("EMPTY", tx, cy, self.fontSmall, C.DIM)
        elseif sum.broken then
            self:menuText("COULDN'T BE READ", tx, cy, self.fontSmall, C.RED)
        else
            local head = string.format("%d BPM  %s", sum.bpm, sum.key)
            self:menuText(head, tx, cy - 7, self.fontSmall, cur and C.TEXT or C.MUTED)
            self:menuText(savedLabel(sum.saved), tx + self.fontSmall:getWidth(head) + 14, cy - 7, self.fontTiny, C.DIM)
            -- the instruments, cut off before the little deck
            local names = self:fitText(table.concat(sum.instruments, " / "), self.fontTiny, mapX - 14 - tx)
            self:menuText(names, tx, cy + 8, self.fontTiny, C.MUTED)
            self:drawMiniDeck(mapX, y + 4, mapW, rh - 8, sum, cur, rowCol)
        end

        if isNow then
            local tag = "NOW"
            local xr = X + W - 28
            local tw = self.fontTiny:getWidth(tag) + 12
            self:setColor(col)
            love.graphics.rectangle("fill", xr - tw, cy - 8, tw, 16, 3, 3)
            self:menuText(tag, xr - tw + 6, cy, self.fontTiny, C.BG)
        end
    end
    footer(self, "UP / DOWN  SLOT     " .. (HINTS[Menu.page] or "B  CHOOSE") .. "     A  BACK     START  CLOSE")
end

function Chrome:drawMenu()
    if not Menu.open then return end
    if Menu.page == "ROOT" then
        self:drawMenuRoot()
    else
        self:drawMenuSlots()
    end
end

end
