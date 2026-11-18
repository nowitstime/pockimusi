-- ============================================================================
-- src/ui/chrome/footer.lua — Footer strip under the stage: hints and toasts
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
-- FOOTER STRIP (y: 322..355): toasts and button hints
-- A toast (Looper:showToast) shows as a card: an icon, a bold title, the
-- detail, and a line that drains while it stays. Otherwise the strip shows the
-- page's buttons as keycaps; a key held right now lights up and its word goes
-- bold. On a page held open (Track, Mixer, Transport...) the hints stay put.
-- ============================================================================
local FOOT_Y, FOOT_H = 322, 33
local MID = FOOT_Y + 17          -- the strip's centre line
local TOAST_TIME = 2.4           -- Looper:showToast's duration

-- Hints per page: { kind, keys, word }. kind = "key" (keycaps), "dpad"
-- (arms: U D L R) or "face" (buttons: X Y A B)
Chrome.FOOTER_HINTS = {
    NORMAL    = { { "key", { "L2" }, "RECORD" }, { "key", { "SELECT" }, "TRACK" }, { "key", { "START" }, "CLOCK" },
                  { "key", { "SELECT", "R2" }, "MIX" }, { "key", { "L2", "R2" }, "ERASE" } },
    REC_LATCH = { { "key", { "L2" }, "TAP: STOP" }, { "key", { "L2" }, "HOLD: PUNCH-IN" }, { "key", { "L2", "R2" }, "ERASE" } },
    REC_HOLD  = { { "key", { "L2" }, "LET GO: STOP" }, { "key", { "L2" }, "QUICK TAP: LATCH" } },
    TRACK     = { { "dpad", "UD", "ROW" }, { "dpad", "LR", "CHANGE" }, { "key", { "L1", "R1" }, "INSTRUMENT" },
                  { "face", "XYAB", "FX ON/OFF" } },
    MIX       = { { "dpad", "LR", "TRACK" }, { "dpad", "UD", "LEVEL" }, { "face", "XYAB", "MUTE" }, { "key", { "L1", "R1" }, "MASTER" } },
    TRANSPORT = { { "dpad", "UD", "BPM" }, { "dpad", "LR", "KEY" }, { "key", { "L1", "R1" }, "SCALE" },
                  { "face", "A", "GRID" }, { "face", "Y", "+UP/DN SWING" }, { "face", "X", "CLICK" } },
    ERASE     = { { "face", "XYAB", "CLEAR PAD" }, { "dpad", "L", "UNDO" }, { "key", { "START" }, "CLEAR TRACK" },
                  { "key", { "SELECT" }, "FRESH" } },
    NEW       = { { "key", { "SELECT" }, "HOLD 1 S: CLEAR ALL NOTES" }, { "dpad", "L", "WITH L2+R2: UNDO" } },
    FX        = { { "dpad", "U", "STUTTER" }, { "dpad", "D", "SLOW" }, { "dpad", "L", "FILTER" }, { "dpad", "R", "CRUSH" },
                  { "face", "XYAB", "MUTE" } },
}
Chrome.FOOTER_TAGS = { REC_LATCH = "REC", REC_HOLD = "REC", TRACK = "TRACK", MIX = "MIX", TRANSPORT = "CLOCK",
                       ERASE = "ERASE", NEW = "FRESH", FX = "LIVE FX" }
-- Pages whose hints stay up even while a toast is showing
local HELD_PAGES = { TRACK = true, MIX = true, TRANSPORT = true, ERASE = true, NEW = true, FX = true }

-- Text drawn twice, a hair apart: a bold weight from the one font
function Chrome:printBold(text, x, y)
    love.graphics.print(text, x, y)
    love.graphics.print(text, x + 0.7, y)
end

local DIR_DOWN = { U = "UP", D = "DOWN", L = "LEFT", R = "RIGHT" }

-- One keycap; returns its width
function Chrome:drawKeycap(x, label, col, lit)
    local C = Config.COLORS
    local f = self.fontTiny
    local w = math_max(18, f:getWidth(label) + 10)
    self:setColor(lit and col or C.BG)
    love.graphics.rectangle("fill", x, MID - 8, w, 16, 8, 8)
    self:setColor(col)
    love.graphics.rectangle("line", x, MID - 8, w, 16, 8, 8)
    love.graphics.setFont(f)
    self:setColor(lit and C.BG or col)
    love.graphics.print(label, math_floor(x + (w - f:getWidth(label)) * 0.5), math_floor(MID - f:getHeight() * 0.5))
    return w
end

-- A small D-pad, its named arms filled (held arms in the light colour)
function Chrome:drawDpadGlyph(cx, arms, col)
    local C = Config.COLORS
    local cy, s = MID, 7
    local a = s * 0.42
    self:setColor(C.BG)
    love.graphics.rectangle("fill", cx - a, cy - s, 2 * a, 2 * s)
    love.graphics.rectangle("fill", cx - s, cy - a, 2 * s, 2 * a)
    self:setColor(col)
    love.graphics.polygon("line", cx - a, cy - s, cx + a, cy - s, cx + a, cy - a, cx + s, cy - a, cx + s, cy + a,
        cx + a, cy + a, cx + a, cy + s, cx - a, cy + s, cx - a, cy + a, cx - s, cy + a, cx - s, cy - a, cx - a, cy - a)
    local box = { U = { cx - a, cy - s, 2 * a, s - a }, D = { cx - a, cy + a, 2 * a, s - a },
                  L = { cx - s, cy - a, s - a, 2 * a }, R = { cx + a, cy - a, s - a, 2 * a } }
    local any = false
    for arm in arms:gmatch(".") do
        local b = box[arm]
        local held = Input.down[DIR_DOWN[arm]]
        any = any or held
        self:setColor(held and C.TEXT or col)
        love.graphics.rectangle("fill", b[1] + 0.8, b[2] + 0.8, b[3] - 1.6, b[4] - 1.6)
    end
    return 2 * s, any
end

-- The four face buttons as dots, the named ones filled (held ones light)
function Chrome:drawFaceGlyph(cx, btns, col)
    local C = Config.COLORS
    local pos = { X = { 0, -1 }, Y = { -1, 0 }, A = { 1, 0 }, B = { 0, 1 } }
    local any = false
    for b, p in pairs(pos) do
        local x, y = cx + p[1] * 6.5, MID + p[2] * 6.5
        local named = btns:find(b, 1, true) ~= nil
        local held = named and Input.down[b]
        any = any or held
        self:setColor(held and C.TEXT or (named and col or C.BG))
        love.graphics.circle("fill", x, y, 2.9)
        self:setColor(col)
        love.graphics.circle("line", x, y, 2.9)
    end
    return 16, any
end

-- A row of hints from x; returns where it ended
function Chrome:drawHintRow(x, hints, col)
    local C = Config.COLORS
    for n, h in ipairs(hints) do
        if n > 1 then
            self:drawStarGlint(x - 8, MID, 3, Config.shade(col, 0.6), 1.0)
        end
        local kind, keys, word = h[1], h[2], h[3]
        local held = false
        if kind == "key" then
            local all = true
            for _, k in ipairs(keys) do
                local down = Input.down[k] and true or false
                all = all and down
                x = x + self:drawKeycap(x, k, col, down) + 3
            end
            held = all
        elseif kind == "dpad" then
            local w, any = self:drawDpadGlyph(x + 7, keys, col)
            held = any
            x = x + w + 3
        else
            local w, any = self:drawFaceGlyph(x + 8, keys, col)
            held = any
            x = x + w + 3
        end
        local f = self.fontSmall
        love.graphics.setFont(f)
        local ty = math_floor(MID - f:getHeight() * 0.5)
        if held then
            self:setColor(C.TEXT)
            self:printBold(word, x + 2, ty)
        else
            self:setColor(col == C.MUTED and C.TEXT or C.MUTED)
            love.graphics.print(word, x + 2, ty)
        end
        x = x + f:getWidth(word) + 20
    end
    return x
end

-- What a toast is: its icon, colour, title and detail, read from its text
function Chrome:readToast(text, instCol)
    local C = Config.COLORS
    local t = text:gsub("^%[REC%]%s*", "")
    local up = t:upper()
    local kind, col = "star", instCol
    local track = up:match("^TRACK (%d): ")
    if text:find("^%[REC%]") or up:find("RECORD") or up:find("PUNCH") or up:find("COUNT%-IN") then
        kind, col = "rec", C.RED
    elseif up:find("^UNDO") or up:find("NOTHING TO UNDO") then
        kind, col = "undo", C.SILVER
    elseif up:find("^ERASED") or up:find("^CLEARED") or up:find("^DELETED") or up:find("^FRESH") then
        kind, col = "cross", C.RED
    elseif up:find("^STAMPED") then
        kind = "stamp"
    elseif track then
        kind, col = "track", self:trackColor(tonumber(track))
    elseif up:find("^TEMPO") or up:find("^KEY") or up:find("^SCALE") or up:find("^CLOCK") or up:find("^CLICK")
        or up:find("^LOOP LENGTH") or up:find("^PLAYHEAD") or up:find("SWING") or up:find("QUANTIZE") then
        kind, col = "clock", C.AMBER
    elseif up:find("^MASTER") or up:find("MUTED") then
        kind, col = "mix", C.SILVER
    end
    local title, detail = t:match("^(.-):%s+(.*)$")
    if track then
        title, detail = t:match("^TRACK %d: (.*)$"), "TRACK " .. track
    elseif not title then
        title, detail = t:match("^(.-)%s+%-%s+(.*)$")
    end
    if not title then title, detail = t, "" end
    return kind, col, title, detail
end

function Chrome:drawToastIcon(kind, x, y, c)
    self:setColor(c)
    if kind == "rec" then
        love.graphics.circle("fill", x, y, 4.5)
    elseif kind == "undo" then
        love.graphics.setLineWidth(2)
        love.graphics.arc("line", "open", x, y, 5, math_pi * 0.9, math_pi * 2.4)
        love.graphics.setLineWidth(1)
        love.graphics.polygon("fill", x - 8, y - 1, x - 5, y + 4, x - 2, y - 1)
    elseif kind == "cross" then
        love.graphics.setLineWidth(2.2)
        love.graphics.line(x - 4.5, y - 4.5, x + 4.5, y + 4.5)
        love.graphics.line(x + 4.5, y - 4.5, x - 4.5, y + 4.5)
        love.graphics.setLineWidth(1)
    elseif kind == "stamp" then
        love.graphics.rectangle("fill", x - 6, y + 1, 12, 4, 1, 1)
        love.graphics.rectangle("fill", x - 2, y - 6, 4, 7, 1, 1)
    elseif kind == "clock" then
        love.graphics.setLineWidth(1.6)
        love.graphics.circle("line", x, y, 5.5)
        love.graphics.line(x, y, x, y - 4)
        love.graphics.line(x, y, x + 3, y + 1)
        love.graphics.setLineWidth(1)
    elseif kind == "mix" then
        love.graphics.rectangle("fill", x - 5, y - 5, 2.5, 10)
        love.graphics.rectangle("fill", x - 1.2, y - 2, 2.5, 7)
        love.graphics.rectangle("fill", x + 2.5, y - 4, 2.5, 9)
    elseif kind == "track" then
        self:drawStarGlint(x, y, 7, c, 1.0)
    else
        self:fillStar(x, y, 6.5, 5, 0.45, -90, c)
    end
end

function Chrome:drawToast(text, timer, instCol)
    local C = Config.COLORS
    local kind, col, title, detail = self:readToast(text, instCol)
    self:setColor(col)
    love.graphics.circle("fill", 28, MID, 11)
    self:drawToastIcon(kind, 28, MID, C.BG)
    local f = self.fontSmall
    love.graphics.setFont(f)
    local ty = math_floor(MID - f:getHeight() * 0.5)
    self:setColor(C.TEXT)
    self:printBold(title, 46, ty)
    if detail ~= "" then
        self:setColor(C.MUTED)
        love.graphics.print(detail, 46 + f:getWidth(title) + 10, ty)
    end
    -- how long it stays
    self:setColor(C.GRID)
    love.graphics.rectangle("fill", 16, FOOT_Y + 29, 608, 2)
    self:setColor(col)
    love.graphics.rectangle("fill", 16, FOOT_Y + 29, 608 * clamp(timer / TOAST_TIME, 0, 1), 2)
end

function Chrome:drawFooterStrip(def)
    local C = Config.COLORS
    local mode = Modes.current or "NORMAL"
    local instCol = self:trackColor(Looper.activeTrack)

    self:setColor(C.BG)
    love.graphics.rectangle("fill", 9, FOOT_Y + 1, 622, FOOT_H - 1, 4, 4)
    self:setColor(C.GRID)
    love.graphics.line(9, FOOT_Y, 631, FOOT_Y)

    if Looper.toastTimer > 0 and not HELD_PAGES[mode] then
        self:drawToast(Looper.toastText, Looper.toastTimer, instCol)
        return
    end

    local hints = self.FOOTER_HINTS[mode] or self.FOOTER_HINTS.NORMAL
    local col = (mode == "NORMAL") and C.MUTED or (Config.MODE_COLORS[mode] or C.MUTED)
    local x = 18
    local tag = self.FOOTER_TAGS[mode]
    if tag then
        local f = self.fontTiny
        local w = f:getWidth(tag) + 14
        self:setColor(col)
        love.graphics.rectangle("fill", x, MID - 8, w, 16, 3, 3)
        love.graphics.setFont(f)
        self:setColor(C.BG)
        love.graphics.print(tag, math_floor(x + 7), math_floor(MID - f:getHeight() * 0.5))
        x = x + w + 12
    end
    self:drawHintRow(x, hints, col)
end

end
