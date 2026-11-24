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

Chrome.ROWS_SHOWN = 6

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
    local font = self.fontTiny
    if track.isLane then
        -- track C is always the chords: one title, no tabs
        love.graphics.setFont(self.fontMed)
        self:setColor(col)
        local t = "TRACK C - CHORDS"
        love.graphics.print(t, math_floor(320 - self.fontMed:getWidth(t) * 0.5), 62)
        return
    end
    local pending = Modes.trackPage.pending
    local selectedId = pending or track.instrumentId
    local y, h, pad = 60, 18, 7
    local groups = {}
    love.graphics.setFont(font)
    for _, tab in ipairs(self:tabLayout(self:tabPosition(track))) do
        local inst = tab.inst
        local label = inst.shortName or inst.name
        local w = font:getWidth(label) + pad * 2
        local x = math_floor(tab.x - w * 0.5)
        local a = tab.alpha
        local textCol = C.MUTED
        if inst.id == selectedId then
            -- the centre: filled while it is only a preview
            self:setColor(col, (pending and 1.0 or 0.12) * a)
            love.graphics.rectangle("fill", x, y, w, h, h * 0.5, h * 0.5)
            self:setColor(col, a)
            love.graphics.rectangle("line", x, y, w, h, h * 0.5, h * 0.5)
            textCol = pending and C.BG or C.TEXT
        elseif inst.id == track.instrumentId then
            -- the track's own keeps its outline while another is previewed
            self:setColor(col, 0.12 * a)
            love.graphics.rectangle("fill", x, y, w, h, h * 0.5, h * 0.5)
            self:setColor(col, a)
            love.graphics.rectangle("line", x, y, w, h, h * 0.5, h * 0.5)
        end
        self:setColor(textCol, a)
        love.graphics.print(label, x + pad, y + math_floor((h - font:getHeight()) * 0.5))
        -- the instrument's group: a short bar in the group's colour under the tab
        local group = Instruments:groupOf(inst)
        self:setColor(group.rgb, a)
        love.graphics.rectangle("fill", math_floor(tab.x - 6), y + h + 3, 12, 2)
        groups[#groups + 1] = { x = tab.x, w = w, group = group, a = a }
    end
    -- a hairline where one group ends and the next begins
    for i = 2, #groups do
        local l, r = groups[i - 1], groups[i]
        if l.group ~= r.group then
            local mx = math_floor((l.x + l.w * 0.5 + r.x - r.w * 0.5) * 0.5) + 0.5
            self:setColor(C.MUTED, math_min(l.a, r.a) * 0.7)
            love.graphics.line(mx, y + 2, mx, y + h - 2)
        end
    end
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
    local y0, step = 102, 25
    local nx = 226
    -- At most ROWS_SHOWN rows fit above the effect moons: a longer list
    -- scrolls with the cursor
    local shown = math_min(n, self.ROWS_SHOWN)
    local first = clamp(sel - 2, 1, n - shown + 1)
    local last = first + shown - 1

    -- Value column starts after the widest label (KIT, X ... COLOUR)
    local labelW = 0
    for _, row in ipairs(rows) do
        labelW = math.max(labelW, self.fontTiny:getWidth(row.label))
    end
    local valueX = math.max(282, 250 + labelW + 10)

    self:setColor(col, 0.3)
    for yy = y0, y0 + (shown - 1) * step, 4 do
        love.graphics.line(nx, yy, nx, yy + 1)
    end
    -- More rows above / below
    self:setColor(col, 0.9)
    if first > 1 then
        love.graphics.polygon("fill", nx - 4, y0 - 12, nx + 4, y0 - 12, nx, y0 - 17)
    end
    if last < n then
        local by = y0 + (shown - 1) * step + 12
        love.graphics.polygon("fill", nx - 4, by, nx + 4, by, nx, by + 5)
    end

    for i = first, last do
        local row = rows[i]
        local y = y0 + (i - first) * step
        local isSel = (i == sel)
        local isFx = (row.kind == "fx")
        local isSetting = (row.kind == "setting")
        local off = isFx and not row.on
        -- Marker: sounds are stars, settings hollow rings, effects small moons
        if isSel then
            self:setColor(col, 0.6)
            self:drawDashedCircle(nx, y, 11, 2, 3)
            self:drawCapsule(240, y - 10, 192, 20, "", col, col, col, self.fontSmall, 0.18)
        end
        local markCol = isSel and col or C.MUTED
        if isFx then
            self:setColor(markCol, 0.9)
            love.graphics.circle(row.on and "fill" or "line", nx, y, isSel and 4.5 or 3)
        elseif isSetting then
            self:setColor(markCol, 0.9)
            love.graphics.setLineWidth(isSel and 1.5 or 1)
            love.graphics.circle("line", nx, y, isSel and 5 or 3.5)
            love.graphics.setLineWidth(1)
        else
            self:drawStarGlint(nx, y, isSel and 7 or ((i == 1) and 4.5 or 3.2), markCol, isSel and 1.0 or 0.9)
        end

        love.graphics.setFont(self.fontTiny)
        self:setColor(isSel and col or C.MUTED)
        love.graphics.print(row.label, 250, y - 6)

        local shownValue = row.note and (row.value .. " - " .. row.note) or row.value
        local value = isSel and ("<  " .. shownValue .. "  >") or shownValue
        love.graphics.setFont(self.fontSmall)
        self:setColor((isSel and not off) and C.TEXT or C.MUTED)
        love.graphics.print(value, valueX, y - 7)

        if row.amount then
            -- Numbers get a bar: there is no list to pick from
            local bx, bw = 376, 46
            self:setColor(C.DIM)
            love.graphics.rectangle("fill", bx, y - 2, bw, 4, 2, 2)
            if not off then
                self:setColor(isSel and col or C.MUTED)
                love.graphics.rectangle("fill", bx, y - 2, math.max(2, bw * clamp(row.amount, 0, 1)), 4, 2, 2)
            end
        elseif isSel then
            love.graphics.setFont(self.fontTiny)
            self:setColor(col)
            local hint = row.items and (#row.items > 1) and string.format("%d/%d", row.index or 1, #row.items) or (row.hint or "")
            local hx = math_floor(424 - self.fontTiny:getWidth(hint))
            -- only where a long value leaves room
            if valueX + self.fontSmall:getWidth(value) + 6 <= hx then
                love.graphics.print(hint, hx, y - 6)
            end
        end
    end

    -- Effects as moon phases, with the face button that switches each one
    -- (track C is silent: no effects)
    for i, slot in ipairs(track.isLane and {} or Looper.FX_ORDER) do
        local x = 236 + (i - 1) * 56
        local on = track.fx.on[slot]
        local amt = track.fx[slot]
        self:drawMoonGauge(x, 276, 9, amt, on, col)
        if rows[sel] and rows[sel].slot == slot then
            self:setColor(col, 0.7)
            self:drawDashedCircle(x, 276, 13, 2, 3)
        end
        love.graphics.setFont(self.fontTiny)
        local name = Looper.FX_BUTTONS[slot] .. " " .. slot:upper()
        self:setColor(on and C.TEXT or C.MUTED)
        love.graphics.print(name, math_floor(x - self.fontTiny:getWidth(name) * 0.5), 291)
        local pct = on and (math_floor(amt * 100 + 0.5) .. "%") or "OFF"
        self:setColor(on and col or C.MUTED)
        love.graphics.print(pct, math_floor(x - self.fontTiny:getWidth(pct) * 0.5), 302)
    end
end

end
