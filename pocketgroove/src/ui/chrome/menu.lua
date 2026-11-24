-- ============================================================================
-- src/ui/chrome/menu.lua — The menu (hold SELECT + START), drawn over the stage
-- (part of src/ui/chrome.lua: adds methods to the Chrome table)
--
-- While SELECT + START are held: a small card fills up until the menu opens.
-- Open: everything under the top bar is covered by the top list, or by the
-- slot list A–H when saving or loading a pattern.
-- ============================================================================

local Config   = require("src.config")
local Modes    = require("src.modes")
local Menu     = require("src.menu")
local Session  = require("src.session")
local Patterns = require("src.patterns")
local Fonts    = require("src.ui.fonts")

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

-- SELECT + START held: "MENU" and a bar that fills to the moment it opens
function Chrome:drawMenuHold()
    local p = Modes:menuHoldProgress()
    if p <= 0 then return end
    local C, col = Config.COLORS, accent()
    local w, h = 240, 64
    local x, y = 320 - w * 0.5, 160 - h * 0.5
    self:setColor(C.BG, 0.9)
    love.graphics.rectangle("fill", x, y, w, h, 8, 8)
    self:setColor(col)
    love.graphics.setLineWidth(1.6)
    love.graphics.rectangle("line", x, y, w, h, 8, 8)
    love.graphics.setLineWidth(1)
    local label = "KEEP HOLDING: MENU"
    self:menuText(label, 320 - self.fontSmall:getWidth(label) * 0.5, y + 22, self.fontSmall, C.TEXT)
    self:setColor(C.GRID)
    love.graphics.rectangle("fill", x + 20, y + 42, w - 40, 6, 3, 3)
    self:setColor(col)
    love.graphics.rectangle("fill", x + 20, y + 42, (w - 40) * p, 6, 3, 3)
end

local function frame(self, title, right)
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
    return Session.patternSlot and ("NOW: PATTERN " .. Session.patternSlot) or "NOW: NOT SAVED TO A SLOT"
end

function Chrome:drawMenuRoot()
    local C, col = Config.COLORS, accent()
    frame(self, "MENU", currentLabel())
    local rh, top = 62, Y + 58
    for i, item in ipairs(Menu.ITEMS) do
        local y = top + (i - 1) * (rh + 6)
        local cur = (i == Menu.row)
        local soon = (item.id == "SONG")
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
        self:menuText(item.label, X + 52, y + rh * 0.5 - 8, self.fontMed, textCol)
        self:menuText(item.hint, X + 52, y + rh * 0.5 + 12, self.fontTiny, soon and C.DIM or C.MUTED)

        local xr = X + W - 34
        if item.id == "FONTS" then
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
    footer(self, "UP / DOWN  MOVE     B  CHOOSE     A  BACK     START  CLOSE")
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

-- The little tape deck, the big one (tapedeck.lua) pared down: a faint
-- thread per track in its instrument's colour, a dot for each hit, a line
-- for each held note, and a faint line at each bar. A 2-bar loop fills the
-- same width as a 4-bar one; the bar lines tell them apart. Bright on the
-- row under the cursor, dim on the others; a muted track goes grey.
function Chrome:drawMiniDeck(x, y, w, h, sum, active)
    local C = Config.COLORS
    local lanes = sum.lanes or {}
    local pitch = h / 4
    local dim = active and 1.0 or 0.5

    -- bar lines only
    for b = 1, sum.bars - 1 do
        local bx = math_floor(x + w * b / sum.bars) + 0.5
        self:setColor(C.GRID, dim)
        love.graphics.line(bx, y, bx, y + h)
    end

    for i = 1, 4 do
        local lane = lanes[i] or { notes = {} }
        local cy = math_floor(y + (i - 0.5) * pitch) + 0.5
        local col = (lane.id and Config.INST_COLORS[lane.id]) or Config.TRACK_COLORS[i] or C.MUTED
        if lane.muted then col = C.DIM end

        self:setColor(col, 0.18 * dim)
        love.graphics.line(x, cy, x + w, cy)

        self:setColor(col, dim)
        for _, n in ipairs(lane.notes) do
            local nx = x + n[1] * w
            local nw = math.min((n[2] - n[1]) * w, x + w - nx)
            if nw >= 2 then
                love.graphics.rectangle("fill", nx, cy - 0.75, nw, 1.5, 0.75, 0.75)
            else
                love.graphics.circle("fill", nx, cy, 1.3)
            end
        end
    end
end

function Chrome:drawMenuSlots()
    local C, col = Config.COLORS, accent()
    local saving = (Menu.page == "SAVE")
    frame(self, saving and "SAVE PATTERN" or "LOAD PATTERN", currentLabel())
    local rh, gap, top = 36, 4, Y + 52
    for i, slot in ipairs(Patterns.SLOTS) do
        local y = top + (i - 1) * (rh + gap)
        local cur = (i == Menu.slotRow)
        local sum = Menu.slots[slot] or { empty = true }
        local isNow = (Session.patternSlot == slot)
        local confirming = (Menu.confirm == slot)
        local rowCol = confirming and C.AMBER or col

        if cur then
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
            self:drawMiniDeck(mapX, y + 5, mapW, rh - 10, sum, cur)
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
    footer(self, saving and "UP / DOWN  SLOT     B  SAVE HERE     A  BACK     START  CLOSE"
                         or "UP / DOWN  SLOT     B  LOAD     A  BACK     START  CLOSE")
end

function Chrome:drawMenu()
    if not Menu.open then
        self:drawMenuHold()
        return
    end
    if Menu.page == "ROOT" then
        self:drawMenuRoot()
    else
        self:drawMenuSlots()
    end
end

end
