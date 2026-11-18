-- Display (src/ui/display.lua): the 640x480 picture fitted to any window,
-- CRISP vs PIXEL looks, fullscreen, and remembering both across boots.
local H = require("helpers")

-- A love.graphics that records the calls Display makes, for a window w x h
local function recorder(w, h, opts)
    opts = opts or {}
    local log = { fonts = {}, canvases = 0 }
    local noop = function() end
    local g = setmetatable({
        getDimensions = function() return w, h end,
        newFont = function(size, _, dpi)
            log.fonts[#log.fonts + 1] = { size = size, dpi = dpi or 1 }
            size = size or 12
            return { getHeight = function() return size end,
                     getWidth = function(_, t) return #tostring(t) * math.floor(size * 0.6) end }
        end,
        newCanvas = function()
            if opts.noCanvas then error("canvases not supported") end
            log.canvases = log.canvases + 1
            return { setFilter = function(self, a, b) log.filter = a .. "/" .. b end }
        end,
        setCanvas = function(c) log.canvas = c end,
        setScissor = function(x, y, sw, sh) log.scissor = x and { x, y, sw, sh } or nil end,
        draw = function(obj, x, y, r, sx) if type(obj) == "table" and obj.setFilter then log.blit = { x, y, sx } end end,
    }, { __index = function() return noop end })
    return g, log
end

local function boot(w, h, opts)
    local g, log = recorder(w, h, opts)
    H.graphicsOverride = g
    local M = H.loadMain()
    H.graphicsOverride = nil
    M.Display = require("src.ui.display")
    return M, log
end

local function lastFontDpi(log) return log.fonts[#log.fonts].dpi end

return {
    { "fits 640x480 into a Steam Deck screen with bars left and right", function()
        local M, log = boot(1280, 800)
        H.play(1 / 30)
        local D = M.Display
        H.near(D.scale, 800 / 480, "scale by height")
        H.eq(D.offsetY, 0, "no bars top/bottom")
        H.eq(D.offsetX, math.floor((1280 - 640 * D.scale) * 0.5), "centred")
        H.truthy(log.scissor == nil, "scissor cleared after the frame")
    end },

    { "CRISP rebuilds the fonts for the screen's scale, once", function()
        local M, log = boot(1280, 800)
        H.play(1 / 30)
        H.eq(M.Display.style, "CRISP", "CRISP by default")
        H.near(lastFontDpi(log), 1.67, "fonts rasterised at the screen scale", 0.001)
        local n = #log.fonts
        H.play(0.5)
        H.eq(#log.fonts, n, "no rebuild while the window size holds")
        H.eq(log.canvases, 0, "no canvas in CRISP")
    end },

    { "at 640x480 the fonts stay as built", function()
        local M, log = boot(640, 480)
        H.play(1 / 30)
        H.near(M.Display.scale, 1.0, "1:1")
        H.eq(lastFontDpi(log), 1, "plain fonts")
    end },

    { "PIXEL draws at 640x480 and enlarges it nearest-neighbour", function()
        local M, log = boot(1280, 800)
        love.keypressed("f9")
        H.eq(M.Display.style, "PIXEL", "F9 switches the look")
        H.play(1 / 30)
        H.eq(log.canvases, 1, "one canvas")
        H.eq(log.filter, "nearest/nearest", "nearest-neighbour")
        H.eq(lastFontDpi(log), 1, "fonts at 640x480 size")
        H.truthy(log.canvas == nil, "drawing back on the screen after the frame")
        H.eq(log.blit[1], M.Display.offsetX, "blitted at the offset")
        H.near(log.blit[3], 800 / 480, "and scaled to fit")
        love.keypressed("f9")
        H.eq(M.Display.style, "CRISP", "and back")
    end },

    { "PIXEL without canvas support stays CRISP", function()
        local M, log = boot(1280, 800, { noCanvas = true })
        M.Display.style = "PIXEL"
        H.play(1 / 30)
        H.truthy(M.Display.canvasFailed, "noticed")
        H.near(lastFontDpi(log), 1.67, "drawn CRISP instead", 0.001)
    end },

    { "look and fullscreen are remembered across boots", function()
        boot(1280, 800)
        local calls = {}
        love.window.setFullscreen = function(on, kind) calls[#calls + 1] = { on, kind } end
        love.keypressed("f9")
        love.keypressed("f11")
        H.eq(#calls, 1, "F11 sets fullscreen")
        H.eq(calls[1][1], true, "on")
        H.eq(calls[1][2], "desktop", "at the desktop resolution")
        H.truthy(H.files["display.txt"], "settings written")

        H.keepFiles = true
        local M2 = boot(1280, 800)
        H.eq(M2.Display.style, "PIXEL", "look restored")
        H.eq(M2.Display.fullscreen, true, "fullscreen restored")
        H.keepFiles = false
    end },
}
