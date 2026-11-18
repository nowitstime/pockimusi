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
-- Keys (desktop / laptop): F9 switches the look, F11 toggles fullscreen.
-- Both are remembered in display.txt next to the session saves.
-- ============================================================================

local Config = require("src.config")

local math_min, math_floor = math.min, math.floor

local Display = {
    FILE = "display.txt",
    STYLES = { "CRISP", "PIXEL" },

    style = "CRISP",
    fullscreen = false,

    scale = 1.0, offsetX = 0, offsetY = 0,  -- where the 640x480 picture lands
    fontScale = nil,                        -- the scale the fonts were last built for
    canvas = nil,                           -- PIXEL: the 640x480 drawing surface
    canvasFailed = false,                   -- PIXEL unavailable: stay CRISP
}

-- ---------------------------------------------------------------------------
-- Remembered settings: "style=PIXEL\nfullscreen=1\n"
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
end

function Display:save()
    local fs = love.filesystem
    if not (fs and fs.write) then return end
    pcall(fs.write, self.FILE, string.format("style=%s\nfullscreen=%d\n", self.style, self.fullscreen and 1 or 0))
end

-- Call once at boot, after Chrome:init()
function Display:init(chrome)
    self.chrome = chrome
    self:load()
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

function Display:getCanvas()
    if self.canvas or self.canvasFailed then return self.canvas end
    local W, H = Config.SCREEN_W, Config.SCREEN_H
    -- Smooth edges at 640x480 like the window's own MSAA; plain canvas if the
    -- GPU can't (some Android GLES 2 devices)
    local ok, c = pcall(love.graphics.newCanvas, W, H, { msaa = 2 })
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
        self:setFontScale(1)
        love.graphics.setCanvas(canvas)
        love.graphics.clear(bg[1], bg[2], bg[3], 1.0)
        drawFn()
        love.graphics.setCanvas()

        love.graphics.clear(0, 0, 0, 1)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(canvas, self.offsetX, self.offsetY, 0, self.scale, self.scale)
        return
    end

    self:setFontScale(self.scale)
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

return Display
