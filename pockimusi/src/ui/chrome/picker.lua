-- ============================================================================
-- src/ui/chrome/picker.lua — List picker shelf over the tape deck
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
local Song        = require("src.song")
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
-- LIST PICKER: a shelf over the tape deck while a list row is being changed.
-- Group tabs (when the list has groups), the current group's items as chips,
-- then the full name, a map of the whole list and the position.
-- ============================================================================
Chrome.SHELF_CHIPS = 5          -- chips shown for a list without groups

local function transportPickerRow(key)
    if key == "SCALE" then
        local root = Theory.rootIndex - 1
        local items = {}
        for i, sc in ipairs(Theory.SCALES) do
            local notes = {}
            for d = 1, 7 do
                notes[d] = Theory.NOTE_NAMES[((root + sc.intervals[d]) % 12) + 1]
            end
            items[i] = { label = sc.fullName:upper(), full = sc.fullName:upper() .. "  ·  " .. table.concat(notes, "  ") }
        end
        return { key = "TRANSPORT_SCALE", label = "SCALE", items = items, index = Theory.scaleIndex }
    elseif key == "KEY" then
        local scale = Theory.SCALES[Theory.scaleIndex]
        local items = {}
        for i, name in ipairs(Theory.NOTE_NAMES) do
            items[i] = { label = name, full = name .. " " .. scale.fullName:upper() }
        end
        return { key = "TRANSPORT_KEY", label = "KEY", items = items, index = Theory.rootIndex }
    end
end

function Chrome:drawPickerShelf()
    local picker, row, col
    if Modes.current == "TRANSPORT" and Modes.transportPicker then
        picker = Modes.transportPicker
        row = transportPickerRow(picker.key)
        col = Config.MODE_COLORS.TRANSPORT
    elseif Modes.current == "TRACK" and not Song.page and not Modes.trackPage.pending and Modes.trackPage.picker then
        picker = Modes.trackPage.picker
        local track = Looper.tracks[Looper.activeTrack]
        local def, state = Instruments:getTrackInstrument(Looper.activeTrack)
        for _, r in ipairs(Instruments:getSoundRows(def, state, track)) do
            if r.key == picker.key then row = r break end
        end
        col = Config.MODE_COLORS.TRACK
    else
        self.shelfAnim = nil
        return
    end
    if not row or not row.items then return end

    local C = Config.COLORS
    local items, idx = row.items, clamp(row.index or 1, 1, #row.items)
    local cur = items[idx]
    local a = clamp(picker.timer / 0.25, 0.0, 1.0)             -- fades out at the end
    local X, Y, W, H = 8, 362, 624, 112

    -- cover the deck, with the playhead's star that pokes out above it
    self:setColor(C.BG, a)
    love.graphics.rectangle("fill", X - 1, Y - 5, W + 2, H + 7)
    self:setColor(C.PANEL, a)
    love.graphics.rectangle("fill", X, Y, W, H, 6, 6)
    self:setColor(col, a)
    love.graphics.setLineWidth(1.6)
    love.graphics.rectangle("line", X, Y, W, H, 6, 6)
    love.graphics.setLineWidth(1)

    -- Groups, in list order
    local groups = {}
    if cur.group then
        for _, it in ipairs(items) do
            if it.group and groups[#groups] ~= it.group then groups[#groups + 1] = it.group end
        end
    end
    local cy = Y + 12
    if #groups > 0 then
        local gw = (W - 24) / #groups
        love.graphics.setFont(self.fontTiny)
        for g, name in ipairs(groups) do
            local gx = X + 12 + (g - 1) * gw
            local tw = self.fontTiny:getWidth(name)
            if name == cur.group then
                self:setColor(col, a)
                love.graphics.rectangle("fill", gx + 2, Y + 7, gw - 4, 15, 7, 7)
                self:setColor(C.BG, a)
            else
                self:setColor(C.MUTED, a)
            end
            love.graphics.print(name, math_floor(gx + (gw - tw) * 0.5), Y + 9)
        end
        cy = Y + 28
    end

    -- Chips: the current group, or a window of the list around the current item
    local from, to = 1, #items
    if cur.group then
        from, to = idx, idx
        while from > 1 and items[from - 1].group == cur.group do from = from - 1 end
        while to < #items and items[to + 1].group == cur.group do to = to + 1 end
    elseif #items > self.SHELF_CHIPS then
        from = clamp(idx - math_floor(self.SHELF_CHIPS / 2), 1, #items - self.SHELF_CHIPS + 1)
        to = from + self.SHELF_CHIPS - 1
    end
    local count = to - from + 1
    local gap, ch = 6, (#groups > 0) and 44 or 52
    local cw = math_min(150, (W - 24 - (count - 1) * gap) / count)
    local cx0 = X + (W - (count * cw + (count - 1) * gap)) * 0.5
    local targetX = cx0 + (idx - from) * (cw + gap)

    -- The highlight slides to the current chip (and jumps when the chips change)
    local animKey = row.key .. ":" .. from .. ":" .. count
    local anim = self.shelfAnim
    if not anim or anim.key ~= animKey then
        anim = { key = animKey, x = targetX }
        self.shelfAnim = anim
    end
    anim.x = anim.x + (targetX - anim.x) * 0.4
    if math.abs(targetX - anim.x) < 0.5 then anim.x = targetX end

    self:setColor(col, 0.18 * a)
    love.graphics.rectangle("fill", anim.x, cy, cw, ch, 8, 8)
    for i = from, to do
        local it = items[i]
        local x = cx0 + (i - from) * (cw + gap)
        local isCur = (i == idx)
        local dis = it.disabled and not isCur
        self:setColor(isCur and col or C.DIM, dis and (0.35 * a) or a)
        love.graphics.rectangle("line", x, cy, cw, ch, 8, 8)
        local font = isCur and self.fontMed or self.fontSmall
        love.graphics.setFont(font)
        self:setColor(isCur and C.TEXT or (dis and C.DIM or C.MUTED), dis and (0.45 * a) or a)
        love.graphics.print(it.label, math_floor(x + (cw - font:getWidth(it.label)) * 0.5), cy + ch * 0.5 - 13)
        local num = string.format("%02d", i)
        love.graphics.setFont(self.fontTiny)
        self:setColor(dis and C.DIM or C.MUTED, dis and (0.45 * a) or a)
        love.graphics.print(num, math_floor(x + (cw - self.fontTiny:getWidth(num)) * 0.5), cy + ch * 0.5 + 5)
    end

    -- Bottom line: which row, the full name, a map of the list, the position
    local by = Y + H - 17
    love.graphics.setFont(self.fontTiny)
    self:setColor(col, a)
    love.graphics.print(row.label .. "   " .. (cur.full or cur.label), X + 14, by)
    local pos = string.format("%d / %d", idx, #items)
    self:setColor(C.MUTED, a)
    love.graphics.print(pos, math_floor(X + W - 14 - self.fontTiny:getWidth(pos)), by)
    if #items > 1 and #items <= 40 then
        local tw, tg, gg = 5, 2, 6
        local total = #items * tw + (#items - 1) * tg
        for i = 2, #items do
            if items[i].group ~= items[i - 1].group then total = total + gg - tg end
        end
        local tx = math_floor(X + (W - total) * 0.5)
        for i, it in ipairs(items) do
            if i > 1 then tx = tx + ((it.group ~= items[i - 1].group) and gg or tg) end
            if i == idx then
                self:setColor(col, a)
                love.graphics.rectangle("fill", tx, by + 1, tw, 8, 1, 1)
            else
                self:setColor((cur.group and it.group == cur.group) and C.MUTED or C.DIM, a)
                love.graphics.rectangle("fill", tx, by + 6, tw, 3, 1, 1)
            end
            tx = tx + tw
        end
    end
end

end
