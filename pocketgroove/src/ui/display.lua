-- ============================================================================
-- src/ui/display.lua — Fit the 640x480 picture to any window or screen
--
-- The game is laid out at 640x480. Display scales it as large as fits,
-- keeps the shape (4:3), centres it and paints black bars around it.
--
-- Two looks:
--   CRISP  everything is drawn at the screen's full resolution. Shapes and
--          text stay sharp at any size (fonts are rebuilt at the new size).
--   PIXEL  the picture is drawn at 640x480 and then enlarged with
--          nearest-neighbour, like the handheld's own screen blown up.
--
-- High-DPI screens (a Mac's Retina, Windows display scaling): the window
-- asks for the screen's real pixels (conf.lua), and the fonts are
-- rasterised for scale x the screen's DPI scale, so nothing is drawn small
-- and then stretched by the system.
--
-- Keys (desktop / laptop): F9 switches the look, F11 toggles fullscreen,
-- F8 the font set (src/ui/fonts.lua). All are remembered in display.txt
-- next to the session saves.
-- ============================================================================

local Config = require("src.config")
local Fonts  = require("src.ui.fonts")

local math_min, math_floor = math.min, math.floor

local function dpiScale()
    local g = love.graphics
    local s = g and g.getDPIScale and g.getDPIScale()
    return (type(s) == "number" and s > 0) and s or 1
end

local Display = {
    FILE = "display.txt",
    STYLES = { "CRISP", "PIXEL" },

    style = "CRISP",
    fullscreen = false,

    scale = 1.0, offsetX = 0, offsetY = 0,  -- where the 640x480 picture lands
    fontScale = nil,                        -- the scale the fonts were last built for
    canvas = nil,                           -- PIXEL: the 640x480 drawing surface
    canvasFailed = false,                   -- PIXEL unavailable: stay CRISP
    snap = false,                           -- CRISP and scaled: text onto whole pixels
}

-- ---------------------------------------------------------------------------
-- Remembered settings: "style=PIXEL\nfullscreen=1\nfont=NEON\n"
-- ---------------------------------------------------------------------------
function Display:load()
    local fs = love.filesystem
    if not (fs and fs.getInfo and fs.getInfo(self.FILE)) then return end
    local ok, text = pcall(fs.read, self.FILE)
    if not ok or type(text) ~= "string" then return end
    local style = text:match("style=(%u+)")
    for _, s in ipairs(self.STYLES) do
        if s == style then self.style = s end
    end
    self.fullscreen = text:match("fullscreen=1") ~= nil
    local font = text:match("font=(%u+)")
    if font then Fonts:setByName(font) end
    self.look = text:match("look=([%u%- ]+)\n")
end

function Display:save()
    local fs = love.filesystem
    if not (fs and fs.write) then return end
    local look = self.chrome and self.chrome.look or self.look or "CLASSIC"
    pcall(fs.write, self.FILE, string.format("style=%s\nfullscreen=%d\nfont=%s\nlook=%s\n",
        self.style, self.fullscreen and 1 or 0, Fonts.set, look))
end

-- Call once at boot, after Chrome:init()
function Display:init(chrome)
    self.chrome = chrome
    self:load()
    if chrome and chrome.setLook and self.look then chrome:setLook(self.look) end
    if self.fullscreen then self:applyFullscreen() end
end

function Display:applyFullscreen()
    local w = love.window
    if w and w.setFullscreen then pcall(w.setFullscreen, self.fullscreen, "desktop") end
end

-- ---------------------------------------------------------------------------
-- Toggles (return a short label for a toast)
-- ---------------------------------------------------------------------------
function Display:cycleStyle()
    local idx = 1
    for i, s in ipairs(self.STYLES) do
        if s == self.style then idx = i end
    end
    self.style = self.STYLES[idx % #self.STYLES + 1]
    self:save()
    return "DISPLAY: " .. self.style
end

function Display:toggleFullscreen()
    self.fullscreen = not self.fullscreen
    self:applyFullscreen()
    self:save()
    return self.fullscreen and "FULLSCREEN" or "WINDOWED"
end

-- ---------------------------------------------------------------------------
-- Drawing
-- ---------------------------------------------------------------------------
function Display:layout()
    local winW, winH = love.graphics.getDimensions()
    local W, H = Config.SCREEN_W, Config.SCREEN_H
    self.scale = math_min(winW / W, winH / H)
    self.offsetX = math_floor((winW - W * self.scale) * 0.5)
    self.offsetY = math_floor((winH - H * self.scale) * 0.5)
end

-- The fonts are rasterised for `s` pixels per layout pixel. Their sizes as
-- the layout measures them don't change, so nothing moves.
function Display:setFontScale(s)
    s = math_floor(s * 100 + 0.5) / 100     -- don't rebuild for tiny wobbles
    if s < 1 then s = 1 end
    if self.fontScale == s then return end
    self.fontScale = s
    if self.chrome and self.chrome.makeFonts then self.chrome:makeFonts(s) end
end

-- A point of the 640x480 picture moved onto the nearest whole screen pixel
-- (in the coordinates of the current transform)
function Display:snapPoint(x, y)
    local g = love.graphics
    if not (g.transformPoint and g.inverseTransformPoint) then return x, y end
    local d = dpiScale()
    local sx, sy = g.transformPoint(x, y)
    if not sy then return x, y end
    sx = math_floor(sx * d + 0.5) / d
    sy = math_floor(sy * d + 0.5) / d
    local lx, ly = g.inverseTransformPoint(sx, sy)
    if not ly then return x, y end
    return lx, ly
end

function Display:getCanvas()
    if self.canvas or self.canvasFailed then return self.canvas end
    local W, H = Config.SCREEN_W, Config.SCREEN_H
    -- Smooth edges at 640x480 like the window's own MSAA; plain canvas if the
    -- GPU can't (some Android GLES 2 devices)
    -- (dpiscale 1: really 640x480 pixels, even on a high-DPI screen)
    local ok, c = pcall(love.graphics.newCanvas, W, H, { msaa = 2, dpiscale = 1 })
    if not ok or not c then ok, c = pcall(love.graphics.newCanvas, W, H, { dpiscale = 1 }) end
    if not ok or not c then ok, c = pcall(love.graphics.newCanvas, W, H) end
    if ok and c then
        c:setFilter("nearest", "nearest")
        self.canvas = c
    else
        self.canvasFailed = true
    end
    return self.canvas
end

-- Draw one frame: drawFn draws the 640x480 picture
function Display:draw(drawFn)
    local bg = Config.COLORS.BG
    local W, H = Config.SCREEN_W, Config.SCREEN_H
    self:layout()

    local canvas = self.style == "PIXEL" and self:getCanvas()
    if canvas then
        self.snap = false
        self:setFontScale(1)
        love.graphics.setCanvas(canvas)
        love.graphics.clear(bg[1], bg[2], bg[3], 1.0)
        self.onCanvas = true
        drawFn()
        self.onCanvas = false
        love.graphics.setCanvas()

        love.graphics.clear(0, 0, 0, 1)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(canvas, self.offsetX, self.offsetY, 0, self.scale, self.scale)
        return
    end

    local px = self.scale * dpiScale()       -- screen pixels per layout pixel
    self:setFontScale(px)
    -- At exactly 1:1 every layout position is already a whole pixel
    self.snap = math.abs(px - 1) > 0.001
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.push()
    love.graphics.translate(self.offsetX, self.offsetY)
    love.graphics.scale(self.scale, self.scale)
    love.graphics.setColor(bg[1], bg[2], bg[3], 1.0)
    love.graphics.rectangle("fill", 0, 0, W, H)
    -- Keep anything drawn past the edges out of the bars
    love.graphics.setScissor(self.offsetX, self.offsetY, math_floor(W * self.scale + 0.5), math_floor(H * self.scale + 0.5))
    drawFn()
    love.graphics.setScissor()
    love.graphics.pop()
end

-- Clip what is drawn next to a rectangle of the 640x480 picture (inside any
-- clip already set). Returns what to hand back to popClip.
function Display:pushClip(x, y, w, h)
    local px, py, pw, ph = love.graphics.getScissor()
    if self.onCanvas then
        love.graphics.intersectScissor(x, y, w, h)
    else
        local s = self.scale or 1
        love.graphics.intersectScissor((self.offsetX or 0) + x * s, (self.offsetY or 0) + y * s, w * s, h * s)
    end
    return { px, py, pw, ph }
end

function Display:popClip(prev)
    if prev and prev[1] then
        love.graphics.setScissor(prev[1], prev[2], prev[3], prev[4])
    else
        love.graphics.setScissor()
    end
end

return Display
