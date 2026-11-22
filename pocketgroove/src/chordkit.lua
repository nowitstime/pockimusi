-- ============================================================================
-- src/chordkit.lua — Chord helpers shared by track C (src/instruments/lane.lua)
--
-- The progressions, the colour wheel, spice, and chord data / numerals. Kept
-- from the Chord Track instrument when track C became the only chord source.
-- ============================================================================

local Theory = require("src.theory")

local math_floor = math.floor

-- D-pad directions by roman numeral (the Harp's chord map; Theory calls iv "IVm")
local DIR = {
    I = "NEUTRAL", ii = "UP_LEFT", iii = "UP_RIGHT", IV = "LEFT", V = "RIGHT",
    vi = "DOWN", bVI = "UP", bVII = "DOWN_LEFT", iv = "DOWN_RIGHT", IVm = "DOWN_RIGHT",
}

local function prog(name, romans, about)
    local dirs = {}
    for i, r in ipairs(romans) do dirs[i] = assert(DIR[r], r) end
    return { name = name, romans = romans, dirs = dirs, about = about }
end

local ChordKit = {
    DIR = DIR,

    -- Common progressions, built only from the nine D-pad chords, so every
    -- one can also be played by hand. Romans are in a major key; in a minor
    -- key the scale chords turn minor as the D-pad's do.
    PROGRESSIONS = {
        prog("POP",         { "I", "V", "vi", "IV" },   "the four-chord pop song"),
        prog("50S",         { "I", "vi", "IV", "V" },   "doo-wop, ballads"),
        prog("SAD POP",     { "vi", "IV", "I", "V" },   "the pop one, starting on the minor"),
        prog("ROCK",        { "I", "IV", "V", "IV" },   "three-chord rock"),
        prog("JAZZ ii-V-I", { "ii", "V", "I", "I" },    "the jazz turnaround"),
        prog("ROYAL ROAD",  { "IV", "V", "iii", "vi" }, "J-pop, anime themes"),
        prog("DESCEND",     { "vi", "V", "IV", "V" },   "minor, stepping down and back"),
        prog("MIXO",        { "I", "bVII", "IV", "I" }, "classic rock, borrowed bVII"),
        prog("HEROIC",      { "bVI", "bVII", "I", "I" }, "the big lift into I"),
        prog("BITTERSWEET", { "I", "IV", "iv", "I" },   "major to minor IV and home"),
        prog("CANON",       { "I", "V", "vi", "iii", "IV", "I", "IV", "V" }, "Pachelbel, eight chords"),
        prog("BLUES 8",     { "I", "V", "IV", "IV", "I", "V", "I", "V" },    "eight-bar blues"),
    },

    -- Hold A: the D-pad picks a colour. Up = richer, down = tense, sides = sus.
    COLOUR_WHEEL = {
        NEUTRAL = "TRIAD", UP = "7TH", UP_RIGHT = "9TH", RIGHT = "ADD9", UP_LEFT = "6TH",
        LEFT = "SUS4", DOWN_LEFT = "SUS2", DOWN = "DIM", DOWN_RIGHT = "AUG",
    },
    -- Short tags after a roman numeral ("V7", "IVsus4")
    COLOUR_TAG = { TRIAD = "", ["7TH"] = "7", ["9TH"] = "9", SUS4 = "sus4", ADD9 = "add9",
                   SUS2 = "sus2", ["6TH"] = "6", AUG = "+", DIM = "dim" },
    ROMAN_LABELS = { NEUTRAL = "I", UP = "bVI", DOWN = "vi", LEFT = "IV", RIGHT = "V",
                     UP_LEFT = "ii", UP_RIGHT = "iii", DOWN_LEFT = "bVII", DOWN_RIGHT = "iv" },

    -- SPICE row: on playback some plain chords get a colour, new each pass
    SPICES = { "OFF", "LIGHT", "WILD" },
    SPICE_CHANCE = { LIGHT = 0.3, WILD = 0.55 },
}

-- The chord data Harmony and followers read, plus the D-pad direction, so the
-- chord can be rebuilt in another colour
function ChordKit:chordData(chord)
    return { name = chord.name, roman = chord.roman, colour = chord.colour, suffix = chord.suffix,
             root = chord.root, third = chord.third, fifth = chord.fifth, seventh = chord.seventh,
             borrowed = chord.borrowed or nil, key = Theory:getRootSemis(), dirKey = chord.dirKey }
end

-- The same chord in another colour (nil if it can't be rebuilt)
function ChordKit:recolour(chord, colour)
    local dir = chord.dirKey or DIR[chord.roman]
    if not dir then return nil end
    local data = self:chordData(Theory:getChordForDirection(dir, false, false, colour))
    data.key = chord.key
    return data
end

-- "V7", "vi", "IV+": a chord as a numeral with its colour
function ChordKit:numeral(chord)
    local dir = chord.dirKey or DIR[chord.roman]
    local roman = (dir and self.ROMAN_LABELS[dir]) or chord.roman or "?"
    return roman .. (self.COLOUR_TAG[chord.colour or "TRIAD"] or "")
end

-- ---------------------------------------------------------------------------
-- Spice: some plain chords get a colour on playback, rolled again each pass.
-- Kept in state.spice ([event] = coloured chord), so followers play the
-- coloured chord too. Never recorded.
-- ---------------------------------------------------------------------------
function ChordKit.random()
    return love.math.random()
end

function ChordKit:spiceOptions(chord, level)
    local minor = (chord.third == 3)
    local opts
    if minor then
        opts = { "7TH", "ADD9" }
        if level == "WILD" then opts[#opts + 1] = "9TH" end
    else
        opts = { "7TH", "ADD9", "SUS4" }
        if level == "WILD" then
            opts[#opts + 1] = "9TH"
            opts[#opts + 1] = "6TH"
            opts[#opts + 1] = "SUS2"
            if chord.roman == "V" then opts[#opts + 1] = "AUG" end
        end
    end
    return opts
end

function ChordKit:rollSpice(state, track)
    state.spice = {}
    local chance = self.SPICE_CHANCE[state.spiceLevel]
    if not chance then return end
    for _, ev in ipairs(track.events) do
        local c = ev.chord
        if c and not ev.open and (c.colour or "TRIAD") == "TRIAD" and self.random() < chance then
            local opts = self:spiceOptions(c, state.spiceLevel)
            local pick = opts[math.min(#opts, math_floor(self.random() * #opts) + 1)]
            state.spice[ev] = self:recolour(c, pick)
        end
    end
end

return ChordKit
