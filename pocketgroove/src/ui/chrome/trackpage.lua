-- ============================================================================
-- src/ui/chrome/trackpage.lua — Track page: instrument tabs, swap card, rows and effects
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
-- TRACK PAGE: constellation of sound rows + moon-phase effect gauges
-- ============================================================================
function Chrome:drawMoonGauge(x, y, r, amount, on, col)
    local C = Config.COLORS
    if on and amount > 0 then
        self:setColor(col)
        love.graphics.circle("fill", x, y, r)
        -- Shadow disc slides off as the amount rises (new moon -> full moon)
        self:setColor(C.PANEL)
        love.graphics.circle("fill", x + amount * (2 * r + 2), y, r + 0.5)
    end
    self:setColor(on and col or C.DIM)
    love.graphics.setLineWidth(1.2)
    love.graphics.circle("line", x, y, r)
    love.graphics.setLineWidth(1)
end

Chrome.ROWS_SHOWN = 9

-- The instruments as a carousel across the top of the Track page. The
-- selected one (the instrument previewed with L1 / R1, else the track's own)
-- sits in the centre; the others run out to both sides as a ring and fade
-- towards the edges. A step slides the strip under the centre.
Chrome.TAB_PITCH = 46          -- pixels from one tab's centre to the next
Chrome.TAB_REACH = 2.5         -- tabs further than this from the centre aren't drawn
Chrome.TAB_SLIDE = 0.1         -- seconds for the strip to reach its new place

-- Catalogue position of the tab that belongs in the centre
function Chrome:selectedTab(track)
    local id = Modes.trackPage.pending or track.instrumentId
    for i, inst in ipairs(Instruments.catalog) do
        if inst.id == id then return i end
    end
    return 1
end

-- The tabs in view when the strip stands at catalogue position `pos` (a
-- fraction while it slides), left to right: { inst, d, x, alpha } with d =
-- tabs from the centre. No instrument appears twice, however few there are.
function Chrome:tabLayout(pos)
    local catalog = Instruments.catalog
    local n = #catalog
    local reach = math_min(self.TAB_REACH, n * 0.5)
    local base = math_floor(pos + 0.5)
    local out = {}
    for k = -3, 3 do
        local d = (base + k) - pos
        if math_abs(d) < reach then
            out[#out + 1] = {
                inst = catalog[((base + k - 1) % n) + 1],
                d = d,
                x = 320 + d * self.TAB_PITCH,
                alpha = clamp((reach - math_abs(d)) / 1.2, 0.0, 1.0),
            }
        end
    end
    return out
end

-- Where the strip stands this frame: it slides the short way round the ring
-- to the selected tab, and starts in place when the page opens
function Chrome:tabPosition(track)
    local n = #Instruments.catalog
    local target = self:selectedTab(track)
    local now = love.timer.getTime()
    local anim = self.tabAnim
    if not anim or anim.slot ~= track.slot or anim.n ~= n or now - anim.time > 0.2 then
        anim = { pos = target, slot = track.slot, n = n }
        self.tabAnim = anim
    else
        local diff = ((target - anim.pos + n * 0.5) % n) - n * 0.5
        local dt = math_max(0.0, now - anim.time)
        -- most of the way in TAB_SLIDE seconds
        anim.pos = anim.pos + diff * (1.0 - math.exp(-dt * 3.0 / self.TAB_SLIDE))
        if math_abs(diff) < 0.02 then anim.pos = target end
        anim.pos = ((anim.pos - 1) % n) + 1
    end
    anim.time = now
    return anim.pos
end

function Chrome:drawInstrumentTabs(track, col)
    local C = Config.COLORS
    if track.isLane then
        love.graphics.setFont(self.fontMed)
        self:setColor(col)
        local t = "TRACK C - CHORDS"
        love.graphics.print(t, math_floor(320 - self.fontMed:getWidth(t) * 0.5), 60)
        return
    end
    local pending = Modes.trackPage.pending
    local selectedId = pending or track.instrumentId
    self:tabPosition(track)
    local inst = Instruments:getDefinition(selectedId)
    local group = Instruments:groupOf(inst)
    local idx = self:selectedTab(track)
    local n = #Instruments.catalog
    local gc = group.rgb

    -- Compact L1 / R1 caps flanking the group + instrument pill (Style 2)
    local lOn, rOn = Input.down.L1, Input.down.R1
    self:drawCapsule(194, 57, 28, 20, "L1", col, lOn and col or Config.shade(col, 0.14), lOn and C.BG or col, self.fontTiny)
    self:drawCapsule(418, 57, 28, 20, "R1", col, rOn and col or Config.shade(col, 0.14), rOn and C.BG or col, self.fontTiny)

    -- Center pill: GROUP · INSTRUMENT   idx/N
    local px, py, pw, ph = 228, 57, 184, 20
    self:setColor(gc, pending and 0.9 or 0.18)
    love.graphics.rectangle("fill", px, py, pw, ph, ph * 0.5, ph * 0.5)
    self:setColor(gc, 0.85)
    love.graphics.rectangle("line", px, py, pw, ph, ph * 0.5, ph * 0.5)

    local fhTiny = self:lineHeight(self.fontTiny)
    local fhSmall = self:lineHeight(self.fontSmall)
    local tyTiny = math_floor(py + (ph - fhTiny) * 0.5)
    local tySmall = math_floor(py + (ph - fhSmall) * 0.5)

    love.graphics.setFont(self.fontTiny)
    local gLabel = group.id
    self:setColor(pending and C.BG or gc)
    love.graphics.print(gLabel, px + 10, tyTiny)

    local gx = px + 10 + self.fontTiny:getWidth(gLabel) + 6
    self:setColor(pending and C.BG or C.DIM, 0.8)
    love.graphics.print("-", gx, tyTiny)

    love.graphics.setFont(self.fontSmall)
    self:setColor(pending and C.BG or C.TEXT)
    love.graphics.print(inst.name, gx + 10, tySmall)

    love.graphics.setFont(self.fontTiny)
    local countStr = string.format("%d/%d", idx, n)
    self:setColor(pending and C.BG or C.MUTED)
    love.graphics.print(countStr, math_floor(px + pw - 10 - self.fontTiny:getWidth(countStr)), tyTiny)
end

-- A previewed instrument swap takes the place of the rows
function Chrome:drawSwapCard(track, col)
    local C = Config.COLORS
    local pDef = Instruments:getDefinition(Modes.trackPage.pending)
    local group = Instruments:groupOf(pDef)
    local function centred(text, y, font, c, alpha)
        love.graphics.setFont(font)
        self:setColor(c, alpha)
        love.graphics.print(text, math_floor(320 - font:getWidth(text) * 0.5), y)
    end
    -- the card takes the colour of the instrument's group (RHYTHM, BASS ...)
    local gc = group.rgb
    self:setColor(gc, 0.16)
    love.graphics.rectangle("fill", 210, 94, 220, 214, 8, 8)
    self:setColor(gc)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", 210, 94, 220, 214, 8, 8)
    love.graphics.setLineWidth(1)
    self:drawStarGlint(320, 120, 12, gc, 1.0)
    centred(string.format("TRACK %d BECOMES", track.slot), 140, self.fontTiny, C.MUTED)
    centred(group.id, 154, self.fontSmall, gc)
    centred(pDef.name, 172, self.fontLarge, C.TEXT)
    self:drawCapsule(232, 206, 176, 20, "RELEASE SELECT TO SWAP", gc, gc, C.BG, self.fontTiny)
    centred("L1 / R1: ANOTHER INSTRUMENT", 244, self.fontTiny, gc)
    centred("BACK TO " .. (track.shortName or track.name) .. " CANCELS", 258, self.fontTiny, C.MUTED)
    centred("UNDO AFTERWARDS: L2 + R2 + LEFT", 284, self.fontTiny, C.MUTED)
end

function Chrome:drawTrackPageView(def, state, track, col)
    local C = Config.COLORS
    if Modes.trackPage.pending then
        return self:drawSwapCard(track, col)
    end
    local rows = Instruments:getSoundRows(def, state, track)
    local sel = Modes.trackPage.row
    local n = #rows
    local shown = math_min(n, self.ROWS_SHOWN)
    local first = clamp(sel - math_floor(shown * 0.5), 1, n - shown + 1)
    local last = first + shown - 1

    -- Value column starts after the widest label
    local labelW = 0
    for i = first, last do
        labelW = math.max(labelW, self.fontTiny:getWidth(rows[i].label))
    end
    local valueX = math.max(274, 204 + labelW + 10)

    -- Scroll arrows on the right edge when the list scrolls
    self:setColor(col, 0.85)
    if first > 1 then
        love.graphics.polygon("fill", 442, 88, 448, 88, 445, 83)
    end
    if last < n then
        love.graphics.polygon("fill", 442, 308, 448, 308, 445, 313)
    end

    -- Clean Style 1 hairline rows with SOUND / EFFECTS section subtitles
    local y = 94
    local lastSec = nil
    for i = first, last do
        local row = rows[i]
        local sec = row.section
        if sec and sec ~= lastSec then
            if lastSec ~= nil then y = y + 3 end
            love.graphics.setFont(self.fontTiny)
            self:setColor(col, 0.55)
            love.graphics.print(sec, 194, y - 5)
            self:setColor(col, 0.18)
            love.graphics.line(194 + self.fontTiny:getWidth(sec) + 6, y, 446, y)
            y = y + 14
            lastSec = sec
        end

        local isSel = (i == sel)
        local isFx = (row.kind == "fx")
        local off = isFx and not row.on

        if isSel then
            self:setColor(col, 0.18)
            love.graphics.rectangle("fill", 192, y - 9, 256, 19, 5, 5)
            self:setColor(col)
            love.graphics.rectangle("fill", 192, y - 6, 3, 13, 1, 1)
        end

        love.graphics.setFont(self.fontTiny)
        self:setColor(isSel and col or C.MUTED, isSel and 1.0 or (off and 0.42 or 0.58))
        love.graphics.print(row.label, 202, y - 5)

        local shownValue = row.note and (row.value .. " - " .. row.note) or row.value
        local value = isSel and ("< " .. shownValue .. " >") or shownValue
        love.graphics.setFont(self.fontSmall)
        self:setColor((isSel and not off) and C.TEXT or C.MUTED, isSel and 1.0 or (off and 0.42 or 0.68))
        love.graphics.print(value, valueX, y - 7)

        if row.amount then
            local bx, bw = 382, 60
            self:setColor(C.DIM, isSel and 0.8 or 0.45)
            love.graphics.rectangle("fill", bx, y - 2, bw, 4, 2, 2)
            if not off then
                self:setColor(col, isSel and 1.0 or 0.6)
                love.graphics.rectangle("fill", bx, y - 2, math.max(3, bw * clamp(row.amount, 0, 1)), 4, 2, 2)
            end
        elseif isSel then
            love.graphics.setFont(self.fontTiny)
            self:setColor(col)
            local hint = row.items and (#row.items > 1) and string.format("%d/%d", row.index or 1, #row.items) or (row.hint or "")
            local hx = math_floor(442 - self.fontTiny:getWidth(hint))
            if valueX + self.fontSmall:getWidth(value) + 6 <= hx then
                love.graphics.print(hint, hx, y - 5)
            end
        end
        y = y + 20
    end
end

end
