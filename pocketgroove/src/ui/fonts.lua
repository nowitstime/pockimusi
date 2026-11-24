-- ============================================================================
-- src/ui/fonts.lua — The typefaces: font sets, sizes, and lining them up
--
-- Each set pairs two faces (all free, SIL Open Font License, in
-- assets/fonts/ with their licences):
--   text     the small labels everywhere (fontTiny, fontSmall)
--   display  titles and the big readouts: note and chord names, BPM
--            (fontMed, fontLarge, fontHuge)
-- CLASSIC is LÖVE's own built-in font, as the app looked before.
--
-- The layout was drawn for the built-in font. So nothing moves when the set
-- changes, each face is sized so its capitals are as tall as the built-in
-- font's at that size, and its text is nudged down or up so the capitals
-- start on the same row (Fonts:offsetOf, applied by the print wrapper
-- Chrome installs). Chrome:lineHeight gives the built-in font's line height,
-- for text centred in a box.
--
-- F8 (desktop) cycles the sets; the choice is kept in display.txt.
-- ============================================================================

local math_floor, math_max = math.floor, math.max

local Fonts = {
    DIR = "assets/fonts/",

    -- How big each role is (in the built-in font's sizes) and which face
    ROLES = {
        fontTiny  = { size = 9,  face = "text" },
        fontSmall = { size = 11, face = "text" },
        fontMed   = { size = 13, face = "display" },
        fontLarge = { size = 16, face = "display" },
        fontHuge  = { size = 28, face = "display" },
    },

    -- The built-in font's line heights at those sizes (Chrome:lineHeight)
    REF_HEIGHT = { [9] = 10, [11] = 13, [13] = 15, [16] = 19, [28] = 33 },

    -- scale: on top of matching the capitals, for faces that read big or wide
    FACES = {
        ["ChakraPetch-SemiBold"]          = { scale = 1.0 },
        ["Tomorrow-SemiBold"]             = { scale = 0.97 },
        ["AtkinsonHyperlegible-Bold"]     = { scale = 0.93 },
        ["Audiowide-Regular"]             = { scale = 0.94 },
        ["ZenDots-Regular"]               = { scale = 0.88 },
        ["Righteous-Regular"]             = { scale = 1.0 },
    },

    SETS = {
        { name = "NEON",      text = "ChakraPetch-SemiBold",      display = "Audiowide-Regular" },
        { name = "STARLIGHT", text = "Tomorrow-SemiBold",         display = "ZenDots-Regular" },
        { name = "SOFT",      text = "AtkinsonHyperlegible-Bold", display = "Righteous-Regular" },
        { name = "CLASSIC" },
    },

    set = "NEON",

    offsets = setmetatable({}, { __mode = "k" }),  -- font -> pixels to move its text down
    metrics = {},                                  -- face -> { capH, capTop } per point of size
}

function Fonts:getSet(name)
    for _, s in ipairs(self.SETS) do
        if s.name == (name or self.set) then return s end
    end
    return self.SETS[1]
end

function Fonts:setByName(name)
    for _, s in ipairs(self.SETS) do
        if s.name == name then self.set = name; return true end
    end
    return false
end

function Fonts:cycle()
    local idx = 1
    for i, s in ipairs(self.SETS) do
        if s.name == self.set then idx = i end
    end
    self.set = self.SETS[idx % #self.SETS + 1].name
    return self.set
end

-- Capital height and where the capitals start below the line's top, as a
-- fraction of the size (measured once per face; nil if the face won't load)
function Fonts:measure(face)
    local key = face or "(built-in)"
    if self.metrics[key] ~= nil then return self.metrics[key] or nil end
    local m = false
    local lf = love.font
    if lf and lf.newRasterizer then
        local S = 200
        local ok, r
        if face then
            ok, r = pcall(lf.newRasterizer, self.DIR .. face .. ".ttf", S)
        else
            ok, r = pcall(lf.newRasterizer, S)
        end
        if ok and r and r.getGlyphData then
            local g = r:getGlyphData("H")
            local _, by = g:getBearing()
            m = { capH = by / S, capTop = (r:getAscent() - by) / S }
        end
    end
    self.metrics[key] = m
    return m or nil
end

-- Where the built-in font's capitals start at `size` (hinted: measured at
-- the real size, so 1x text lines up to the pixel)
function Fonts:refCapTop(size)
    self.refTops = self.refTops or {}
    if self.refTops[size] ~= nil then return self.refTops[size] end
    local top = false
    local lf = love.font
    if lf and lf.newRasterizer then
        local ok, r = pcall(lf.newRasterizer, size)
        if ok and r and r.getGlyphData then
            local _, by = r:getGlyphData("H"):getBearing()
            top = r:getAscent() - by
        end
    end
    self.refTops[size] = top
    return top or nil
end

-- One role's font for the current set, rasterised at `dpi` screen pixels per
-- layout pixel. Falls back to the built-in font if a face won't load.
function Fonts:make(role, dpi)
    local r = self.ROLES[role]
    local set = self:getSet()
    local face = set[r.face]
    local g = love.graphics
    dpi = dpi or 1

    local function builtin()
        if dpi ~= 1 then return g.newFont(r.size, "normal", dpi) end
        return g.newFont(r.size)
    end

    if not face then return builtin() end

    local ref, m = self:measure(nil), self:measure(face)
    local spec = self.FACES[face] or {}
    local size = r.size
    if ref and m then size = r.size * ref.capH / m.capH end
    size = math_max(6, math_floor(size * (spec.scale or 1) + 0.5))

    local ok, font
    if dpi ~= 1 then
        ok, font = pcall(g.newFont, self.DIR .. face .. ".ttf", size, "normal", dpi)
    else
        ok, font = pcall(g.newFont, self.DIR .. face .. ".ttf", size)
    end
    if not ok or not font then return builtin() end

    local refTop = self:refCapTop(r.size)
    if refTop and m then
        self.offsets[font] = math_floor(refTop - m.capTop * size + 0.5)
    end
    return font
end

function Fonts:offsetOf(font)
    return font and self.offsets[font] or 0
end

function Fonts:refHeight(size)
    return self.REF_HEIGHT[size] or math_floor(size * 1.165 + 0.5)
end

return Fonts
