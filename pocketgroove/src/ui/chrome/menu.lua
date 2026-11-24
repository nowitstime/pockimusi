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
        if sum.empty then
            self:menuText(saving and "EMPTY" or "EMPTY", tx, cy, self.fontSmall, C.DIM)
        elseif sum.broken then
            self:menuText("COULDN'T BE READ", tx, cy, self.fontSmall, C.RED)
        else
            local head = string.format("%d BPM  %s", sum.bpm, sum.key)
            self:menuText(head, tx, cy - 7, self.fontSmall, cur and C.TEXT or C.MUTED)
            local notes = sum.notes .. (sum.notes == 1 and " NOTE" or " NOTES")
            if sum.chords and sum.chords > 0 then notes = notes .. "  " .. sum.chords .. " CHORDS" end
            local line = table.concat(sum.instruments, " / ") .. "    " .. notes
            self:menuText(line, tx, cy + 8, self.fontTiny, C.MUTED)
        end

        local xr = X + W - 28
        if isNow then
            local tag = "NOW"
            local tw = self.fontTiny:getWidth(tag) + 12
            self:setColor(col)
            love.graphics.rectangle("fill", xr - tw, cy - 8, tw, 16, 3, 3)
            self:menuText(tag, xr - tw + 6, cy, self.fontTiny, C.BG)
            xr = xr - tw - 10
        end
        if not sum.empty and not sum.broken then
            self:menuTextRight(savedLabel(sum.saved), xr, cy, self.fontTiny, C.MUTED)
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
