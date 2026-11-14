-- ============================================================================
-- src/theory.lua — Scales, Keys, and Diatonic / Borrowed Chord Voicings
-- ============================================================================

local math_floor = math.floor

local Theory = {
    NOTE_NAMES = { "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" },
    SCALES = {
        { name = "MAJ", fullName = "Major",      intervals = { 0, 2, 4, 5, 7, 9, 11, 12 } },
        { name = "MIN", fullName = "Minor",      intervals = { 0, 2, 3, 5, 7, 8, 10, 12 } },
        { name = "DOR", fullName = "Dorian",     intervals = { 0, 2, 3, 5, 7, 9, 10, 12 } },
        { name = "MIX", fullName = "Mixolydian", intervals = { 0, 2, 4, 5, 7, 9, 10, 12 } },
    },
    rootIndex = 1,  -- 1 = C
    scaleIndex = 1, -- 1 = MAJ
}

function Theory:getRootSemis()
    return self.rootIndex - 1
end

function Theory:getKeyLabel()
    local rootName = self.NOTE_NAMES[self.rootIndex]
    local scaleName = self.SCALES[self.scaleIndex].name
    return rootName .. " " .. scaleName
end

function Theory:cycleRoot(delta)
    self.rootIndex = ((self.rootIndex - 1 + delta) % #self.NOTE_NAMES) + 1
end

function Theory:cycleScale(delta)
    self.scaleIndex = ((self.scaleIndex - 1 + delta) % #self.SCALES) + 1
end

function Theory:getScaleDegreeSemis(degree)
    local intervals = self.SCALES[self.scaleIndex].intervals
    local len = 7
    local zeroIdx = degree - 1
    local octaves = math_floor(zeroIdx / len)
    local idx = (zeroIdx % len) + 1
    return self:getRootSemis() + intervals[idx] + (octaves * 12)
end

-- Chord colours (Track page COLOUR row). TRIAD is the default.
Theory.COLOURS = { "TRIAD", "7TH", "9TH", "SUS4", "ADD9" }

-- Name suffix for a chord with the given third, seventh and colour
local function colourSuffix(colour, third, seventh)
    local minor = (third == 3)
    if colour == "7TH" or colour == "9TH" then
        local n = (colour == "7TH") and "7" or "9"
        if minor then return (seventh == 11) and ("mMaj" .. n) or ("m" .. n) end
        return (seventh == 11) and ("maj" .. n) or n
    elseif colour == "SUS4" then
        return "sus4"
    elseif colour == "ADD9" then
        return minor and "m(add9)" or "add9"
    end
    return minor and "m" or ""
end

-- `colour` is one of Theory.COLOURS (nil = TRIAD). Strings 1-4 are, per colour:
--   TRIAD root 3rd 5th 8ve · 7TH root 3rd 5th 7th · 9TH root 3rd 7th 9th
--   SUS4  root 4th 5th 8ve · ADD9 root 3rd 5th 9th
function Theory:getChordForDirection(dirKey, l1, r1, colour)
    local scale = self.SCALES[self.scaleIndex].intervals
    local rootBase = self:getRootSemis()

    local roman = "I"
    local chordRootOffset = 0
    local thirdInterval = 4
    local fifthInterval = 7
    local seventhInterval = 11
    local ninthInterval = 14
    local quality = ""
    local borrowed = false       -- not built from the scale (followers use fixed intervals)

    local function buildFromScaleDegree(deg, romanStr)
        local r = scale[deg]
        local t = scale[((deg + 1) % 7) + 1] + (deg + 2 > 7 and 12 or 0)
        local f = scale[((deg + 3) % 7) + 1] + (deg + 4 > 7 and 12 or 0)
        local s = scale[((deg + 5) % 7) + 1] + (deg + 6 > 7 and 12 or 0)
        chordRootOffset = r
        thirdInterval = t - r
        fifthInterval = f - r
        seventhInterval = s - r
        ninthInterval = 14
        roman = romanStr
        quality = (thirdInterval == 3) and "m" or ""
    end

    if dirKey == "NEUTRAL" then
        buildFromScaleDegree(1, "I")
    elseif dirKey == "UP" then
        -- bVI (Ab in C major): with bVII gives the bVI - bVII - I lift
        chordRootOffset = 8
        thirdInterval = 4
        fifthInterval = 7
        seventhInterval = 11
        roman = "bVI"
        borrowed = true
    elseif dirKey == "LEFT" then
        buildFromScaleDegree(4, "IV")
    elseif dirKey == "RIGHT" then
        buildFromScaleDegree(5, "V")
    elseif dirKey == "DOWN" then
        buildFromScaleDegree(6, "vi")
    elseif dirKey == "UP_LEFT" then
        buildFromScaleDegree(2, "ii")
    elseif dirKey == "UP_RIGHT" then
        buildFromScaleDegree(3, "iii")
    elseif dirKey == "DOWN_LEFT" then
        chordRootOffset = 10
        thirdInterval = 4
        fifthInterval = 7
        seventhInterval = 10
        ninthInterval = 14
        roman = "bVII"
        quality = ""
        borrowed = true
    elseif dirKey == "DOWN_RIGHT" then
        chordRootOffset = 5
        thirdInterval = 3
        fifthInterval = 7
        seventhInterval = 10
        ninthInterval = 14
        roman = "IVm"
        quality = "m"
        borrowed = true
    end

    local absRoot = rootBase + chordRootOffset
    local noteName = self.NOTE_NAMES[(absRoot % 12) + 1]
    colour = colour or "TRIAD"
    local octShift = 0
    if l1 and not r1 then
        octShift = -12
    elseif r1 and not l1 then
        octShift = 12
    end

    -- Chord tones as intervals above the root, by colour
    local second = (colour == "SUS4") and 5 or thirdInterval     -- string 2
    local third  = (colour == "9TH") and seventhInterval or fifthInterval  -- string 3
    local top                                                     -- string 4
    if colour == "7TH" then top = seventhInterval
    elseif colour == "9TH" or colour == "ADD9" then top = ninthInterval
    else top = 12 end

    local voicings
    local isWide = (l1 and r1) and true or false
    if isWide then
        -- Spread voicing: bass an octave down, upper tones lifted
        local wideTop = (top == 12) and ninthInterval or top
        voicings = {
            absRoot - 12,
            absRoot + fifthInterval,
            absRoot + second + 12,
            absRoot + wideTop + 12,
        }
    else
        voicings = {
            absRoot + octShift,
            absRoot + second + octShift,
            absRoot + third + octShift,
            absRoot + top + octShift,
        }
    end

    local suffix = colourSuffix(colour, thirdInterval, seventhInterval)
    return {
        name = noteName .. suffix .. (isWide and " (WIDE)" or ""),
        roman = roman,
        dirKey = dirKey,
        colour = colour,
        suffix = suffix,
        -- The chord itself, relative to the key (for Harmony and followers):
        -- root = semitones above the key root; the rest above the chord root
        root = chordRootOffset,
        third = thirdInterval,
        fifth = fifthInterval,
        seventh = seventhInterval,
        borrowed = borrowed,
        notes = voicings,
        octShift = octShift,
        isWide = isWide,
    }
end

-- Semitones to add to something recorded in key `recordedRoot` (0-11) so it
-- sits in the current key: the nearest way round (-6 .. +5)
function Theory:keyShift(recordedRoot)
    if type(recordedRoot) ~= "number" then return 0 end
    return ((self:getRootSemis() - recordedRoot + 6) % 12) - 6
end

-- A chord's display name in the current key, from its key-relative data
function Theory:chordName(chord)
    local abs = (self:getRootSemis() + (chord.root or 0)) % 12
    return self.NOTE_NAMES[abs + 1] .. (chord.suffix or "")
end

-- Chord-follow (SPEC §5): the pitch of a D-pad degree played over `chord`
-- (key-relative data as above), in semitones like getScaleDegreeSemis.
--   1 = chord root, 3 = third, 5 = fifth, 7 = seventh, 8 = octave,
--   -2 = the fifth below. 2, 4, 6 walk the key's scale from the chord root
--   on chords built from the scale; on borrowed chords they are +2, +5 and
--   +8 (minor chord) / +9 (major).
-- Chord roots more than a tritone above the key root are played below it,
-- so a root-note bass line moves by the shortest way (V = G below C).
function Theory:getChordDegreeSemis(chord, degree)
    local rootOffset = chord.root or 0
    if rootOffset > 6 then rootOffset = rootOffset - 12 end
    local base = self:getRootSemis() + rootOffset
    local third, fifth, seventh = chord.third or 4, chord.fifth or 7, chord.seventh or 10

    if degree == 1 then return base end
    if degree == 3 then return base + third end
    if degree == 5 then return base + fifth end
    if degree == 7 then return base + seventh end
    if degree == 8 then return base + 12 end
    if degree == -2 then return base + fifth - 12 end

    -- 2, 4, 6 (and anything else): through the scale if the chord lives in it
    local scale = self.SCALES[self.scaleIndex].intervals
    local scaleDeg
    if not chord.borrowed then
        for i = 1, 7 do
            if scale[i] == (chord.root or 0) % 12 then scaleDeg = i break end
        end
    end
    if scaleDeg then
        local at = self:getScaleDegreeSemis(scaleDeg + degree - 1) - self:getScaleDegreeSemis(scaleDeg)
        return base + at
    end
    local fixed = { [2] = 2, [4] = 5, [6] = (third == 3) and 8 or 9 }
    return base + (fixed[degree] or 0)
end

return Theory
