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

Chrome.FONT_SIZES = { fontTiny = 9, fontSmall = 11, fontMed = 13, fontLarge = 16, fontHuge = 28 }

function Chrome:init()
    self:makeFonts(1)
    love.graphics.setLineStyle("smooth")
end

-- (Re)build the fonts with `dpiScale` screen pixels per layout pixel
-- (src/ui/display.lua). Widths and heights still come back in layout pixels.
function Chrome:makeFonts(dpiScale)
    for name, size in pairs(self.FONT_SIZES) do
        if dpiScale and dpiScale ~= 1 then
            self[name] = love.graphics.newFont(size, "normal", dpiScale)
        else
            self[name] = love.graphics.newFont(size)
        end
    end
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
    "chords",
    "lane",
    "pad",
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
