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

    { "C major chord map: neutral and all eight directions", function()
        local T = H.fresh().Theory
        local expect = {
            NEUTRAL    = { "C",  "0 4 7 12",    "I" },
            UP         = { "G#", "8 12 15 20",  "bVI" },
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
        local c = T:getChordForDirection("NEUTRAL", false, false)
        H.eq(c.name, "Cm", "name")
        H.eq(notes(c), "0 3 7 12", "notes")
    end },

    { "key change transposes chords", function()
        local T = H.fresh().Theory
        T.rootIndex = 3            -- D
        local c = T:getChordForDirection("NEUTRAL", false, false)
        H.eq(c.name, "D", "name")
        H.eq(notes(c), "2 6 9 14", "notes")
    end },

    { "shoulders: L1 octave down, R1 octave up, both = wide voicing", function()
        local T = H.fresh().Theory
        H.eq(notes(T:getChordForDirection("NEUTRAL", true, false)), "-12 -8 -5 0", "L1")
        H.eq(notes(T:getChordForDirection("NEUTRAL", false, true)), "12 16 19 24", "R1")
        local wide = T:getChordForDirection("NEUTRAL", true, true)
        H.eq(notes(wide), "-12 7 16 26", "wide notes")
        H.truthy(wide.isWide, "isWide")
    end },

    { "chord colours: notes and names", function()
        local T = H.fresh().Theory
        local function c(dir, colour) return T:getChordForDirection(dir, false, false, colour) end
        local expect = {
            { "NEUTRAL", "TRIAD", "C", "0 4 7 12" },
            { "NEUTRAL", "7TH", "Cmaj7", "0 4 7 11" },
            { "NEUTRAL", "9TH", "Cmaj9", "0 4 11 14" },
            { "NEUTRAL", "SUS4", "Csus4", "0 5 7 12" },
            { "NEUTRAL", "ADD9", "Cadd9", "0 4 7 14" },
            { "RIGHT", "7TH", "G7", "7 11 14 17" },
            { "DOWN", "7TH", "Am7", "9 12 16 19" },
            { "UP_LEFT", "9TH", "Dm9", "2 5 12 16" },
            { "DOWN", "ADD9", "Am(add9)", "9 12 16 23" },
            { "DOWN_LEFT", "7TH", "A#7", "10 14 17 20" },
            { "DOWN_RIGHT", "7TH", "Fm7", "5 8 12 15" },
        }
        for _, e in ipairs(expect) do
            local chord = c(e[1], e[2])
            H.eq(chord.name, e[3], e[1] .. " " .. e[2] .. " name")
            H.eq(notes(chord), e[4], e[1] .. " " .. e[2] .. " notes")
        end
    end },

    { "chord colour with shoulders: octave shift and wide voicing", function()
        local T = H.fresh().Theory
        H.eq(notes(T:getChordForDirection("NEUTRAL", true, false, "7TH")), "-12 -8 -5 -1", "L1 maj7")
        local wide = T:getChordForDirection("NEUTRAL", true, true, "7TH")
        H.eq(notes(wide), "-12 7 16 23", "wide maj7: top = 7th")
        H.eq(wide.name, "Cmaj7 (WIDE)", "wide name")
        H.eq(notes(T:getChordForDirection("NEUTRAL", true, true, "SUS4")), "-12 7 17 26", "wide sus4: 4th lifted")
    end },

    { "building a chord leaks no globals", function()
        local T = H.fresh().Theory
        T:getChordForDirection("NEUTRAL", false, false)
        T:getChordForDirection("NEUTRAL", true, true)
        H.eq(rawget(_G, "voicings"), nil, "global 'voicings'")
    end },

    -- ------------------------------------------------------------------
    -- Phase D: bVI, key-relative chord data, chord-follow degrees
    -- ------------------------------------------------------------------
    { "UP is bVI: Ab in C major, F in A minor; 7th colour gives maj7", function()
        local T = H.fresh().Theory
        local c = T:getChordForDirection("UP", false, false, "7TH")
        H.eq(c.name, "G#maj7", "name")
        H.eq(notes(c), "8 12 15 19", "notes")
        H.truthy(c.borrowed, "borrowed")
        T.rootIndex, T.scaleIndex = 10, 2
        H.eq(T:getChordForDirection("UP", false, false).name, "F", "A minor")
    end },

    { "chords carry key-relative data; names and shifts follow the key", function()
        local T = H.fresh().Theory
        local v = T:getChordForDirection("RIGHT", false, false, "7TH")
        H.eq(v.root, 7, "V root offset")
        H.eq(v.third .. " " .. v.fifth .. " " .. v.seventh, "4 7 10", "dominant intervals")
        H.falsy(v.borrowed, "diatonic")
        H.eq(T:chordName(v), "G7", "name in C")
        T.rootIndex = 3
        H.eq(T:chordName(v), "A7", "name in D")
        H.eq(T:keyShift(0), 2, "C -> D = +2")
        T.rootIndex = 12
        H.eq(T:keyShift(0), -1, "C -> B = -1 (nearest way)")
        H.eq(T:keyShift(nil), 0, "no recorded key")
    end },

    { "follow degrees over the tonic equal the plain scale degrees", function()
        local T = H.fresh().Theory
        for _, scale in ipairs({ 1, 2, 3, 4 }) do
            T.scaleIndex = scale
            local tonic = T:getChordForDirection("NEUTRAL", false, false)
            for _, d in ipairs({ -2, 1, 2, 3, 4, 5, 6, 7, 8 }) do
                H.eq(T:getChordDegreeSemis(tonic, d), T:getScaleDegreeSemis(d), "scale " .. scale .. " degree " .. d)
            end
        end
    end },

    { "follow degrees over other chords: root, third, fifth, in-key passing notes", function()
        local T = H.fresh().Theory
        local function deg(dir, d) return T:getChordDegreeSemis(T:getChordForDirection(dir, false, false), d) end
        H.eq(deg("DOWN", 1), -3, "vi: A below C")
        H.eq(deg("DOWN", 3), 0, "vi: third = C")
        H.eq(deg("DOWN", 5), 4, "vi: fifth = E")
        H.eq(deg("DOWN", 2), -1, "vi: 2 = B (in key)")
        H.eq(deg("LEFT", 1), 5, "IV: F above")
        H.eq(deg("LEFT", 4), 11, "IV: 4 = B (in key)")
        H.eq(deg("RIGHT", 1), -5, "V: G below")
        H.eq(deg("RIGHT", 7), 5, "V: seventh = F")
        H.eq(deg("RIGHT", -2), -10, "V: low fifth = D")
        H.eq(deg("RIGHT", 8), 7, "V: octave")
        H.eq(deg("DOWN_LEFT", 1), -2, "bVII: Bb below")
        H.eq(deg("DOWN_LEFT", 3), 2, "bVII: third = D")
        H.eq(deg("DOWN_LEFT", 6), 7, "bVII (major): 6 = +9")
        H.eq(deg("DOWN_RIGHT", 6), 13, "iv (minor): 6 = +8")
        H.eq(deg("UP", 1), -4, "bVI: Ab below")
    end },
}
