-- Theory: scale degrees and the chord harp's chord map (characterises today's behaviour)
local H = require("helpers")

local function notes(chord) return table.concat(chord.notes, " ") end

return {
    { "scale degrees in C major, including the octave above", function()
        local T = H.fresh().Theory
        H.eq(T:getScaleDegreeSemis(1), 0, "deg 1")
        H.eq(T:getScaleDegreeSemis(3), 4, "deg 3")
        H.eq(T:getScaleDegreeSemis(5), 7, "deg 5")
        H.eq(T:getScaleDegreeSemis(8), 12, "deg 8")
        H.eq(T:getScaleDegreeSemis(9), 14, "deg 9")
        H.eq(T:getScaleDegreeSemis(10), 16, "deg 10")
    end },

    { "scale degrees follow key and scale", function()
        local T = H.fresh().Theory
        T.rootIndex = 3            -- D
        T.scaleIndex = 2           -- minor
        H.eq(T:getScaleDegreeSemis(1), 2, "D minor deg 1")
        H.eq(T:getScaleDegreeSemis(3), 5, "D minor deg 3 (F)")
        H.eq(T:getScaleDegreeSemis(6), 10, "D minor deg 6 (Bb)")
    end },

    { "C major chord map: all eight directions", function()
        local T = H.fresh().Theory
        local expect = {
            NEUTRAL    = { "C",  "0 4 7 12",    "I" },
            UP         = { "C",  "0 4 7 12",    "I" },
            UP_LEFT    = { "Dm", "2 5 9 14",    "ii" },
            UP_RIGHT   = { "Em", "4 7 11 16",   "iii" },
            LEFT       = { "F",  "5 9 12 17",   "IV" },
            RIGHT      = { "G",  "7 11 14 19",  "V" },
            DOWN       = { "Am", "9 12 16 21",  "vi" },
            DOWN_LEFT  = { "A#", "10 14 17 22", "bVII" },
            DOWN_RIGHT = { "Fm", "5 8 12 17",   "IVm" },
        }
        for dir, e in pairs(expect) do
            local c = T:getChordForDirection(dir, false, false)
            H.eq(c.name, e[1], dir .. " name")
            H.eq(notes(c), e[2], dir .. " notes")
            H.eq(c.roman, e[3], dir .. " roman")
        end
    end },

    { "minor key makes the tonic minor", function()
        local T = H.fresh().Theory
        T.scaleIndex = 2
        local c = T:getChordForDirection("UP", false, false)
        H.eq(c.name, "Cm", "name")
        H.eq(notes(c), "0 3 7 12", "notes")
    end },

    { "key change transposes chords", function()
        local T = H.fresh().Theory
        T.rootIndex = 3            -- D
        local c = T:getChordForDirection("UP", false, false)
        H.eq(c.name, "D", "name")
        H.eq(notes(c), "2 6 9 14", "notes")
    end },

    { "shoulders: L1 octave down, R1 octave up, both = wide voicing", function()
        local T = H.fresh().Theory
        H.eq(notes(T:getChordForDirection("UP", true, false)), "-12 -8 -5 0", "L1")
        H.eq(notes(T:getChordForDirection("UP", false, true)), "12 16 19 24", "R1")
        local wide = T:getChordForDirection("UP", true, true)
        H.eq(notes(wide), "-12 7 16 26", "wide notes")
        H.truthy(wide.isWide, "isWide")
    end },

    { "building a chord leaks no globals", function()
        local T = H.fresh().Theory
        T:getChordForDirection("UP", false, false)
        T:getChordForDirection("UP", true, true)
        H.eq(rawget(_G, "voicings"), nil, "global 'voicings'")
    end },
}
