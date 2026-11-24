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

local Chrome = {
    fontTiny  = nil,
    fontSmall = nil,
    fontMed   = nil,
    fontLarge = nil,
    fontHuge  = nil,
}

local Fonts = require("src.ui.fonts")

Chrome.sizeOf = setmetatable({}, { __mode = "k" })   -- font -> its role's size

function Chrome:init()
    self:installTextWrapper()
    self:makeFonts(1)
    love.graphics.setLineStyle("smooth")
end

-- (Re)build the fonts with `dpiScale` screen pixels per layout pixel
-- (src/ui/display.lua), in the current font set (src/ui/fonts.lua). Widths
-- and heights still come back in layout pixels.
function Chrome:makeFonts(dpiScale)
    self.fontDpi = dpiScale or 1
    for role, r in pairs(Fonts.ROLES) do
        local f = Fonts:make(role, self.fontDpi)
        self[role] = f
        self.sizeOf[f] = r.size
    end
end

-- F8: the next font set; returns a label for a toast
function Chrome:cycleFonts()
    Fonts:cycle()
    self:makeFonts(self.fontDpi or 1)
    Display:save()
    return "FONTS: " .. Fonts.set
end

-- The line height the layout was drawn for (the built-in font's), so text
-- centred in a box sits the same in every font set
function Chrome:lineHeight(font)
    local size = self.sizeOf[font]
    if size then return Fonts:refHeight(size) end
    return font:getHeight()
end

-- Every print goes through here: the face's nudge so its capitals start
-- where the built-in font's did, then (CRISP, scaled) onto whole screen
-- pixels so the glyphs aren't smeared across two.
function Chrome:installTextWrapper()
    local g = love.graphics
    if rawget(g, "__pgTextWrapped") then return end
    local rawPrint, rawPrintf, getFont = g.print, g.printf, g.getFont
    g.print = function(text, x, y, ...)
        x, y = x or 0, (y or 0) + Fonts:offsetOf(getFont and getFont())
        if Display.snap then x, y = Display:snapPoint(x, y) end
        return rawPrint(text, x, y, ...)
    end
    g.printf = function(text, x, y, ...)
        x, y = x or 0, (y or 0) + Fonts:offsetOf(getFont and getFont())
        if Display.snap then x, y = Display:snapPoint(x, y) end
        return rawPrintf(text, x, y, ...)
    end
    rawset(g, "__pgTextWrapped", true)
end

function Chrome:setColor(c, alphaOverride)
    if alphaOverride then
        love.graphics.setColor(c[1], c[2], c[3], alphaOverride)
    else
        love.graphics.setColor(c[1], c[2], c[3], c[4] or 1.0)
    end
end

-- The parts, each adding its methods to Chrome (src/ui/chrome/*.lua)
for _, part in ipairs({
    "prims",
    "halos",
    "dpad",
    "face",
    "topbar",
    "stage",
    "views",
    "mixer",
    "drums",
    "trackpage",
    "picker",
    "transport",
    "footer",
    "tapedeck",
    "bass",
    "panels",
    "strum",
    "lead",
    "lane",
    "pad",
    "electronic",
}) do
    require("src.ui.chrome." .. part)(Chrome)
end

function Chrome:drawScreen()
    self:drawTopBar()
    self:drawCenterStage()
    self:drawTapeDeck()
    self:drawPickerShelf()
end

-- Fitted to the window, black bars around it (src/ui/display.lua)
function Chrome:draw()
    if not self.drawScreenFn then
        self.drawScreenFn = function() self:drawScreen() end
    end
    Display:draw(self.drawScreenFn)
end

return Chrome
