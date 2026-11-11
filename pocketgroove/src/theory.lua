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

    if dirKey == "NEUTRAL" or dirKey == "UP" then
        buildFromScaleDegree(1, "I")
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
    elseif dirKey == "DOWN_RIGHT" then
        chordRootOffset = 5
        thirdInterval = 3
        fifthInterval = 7
        seventhInterval = 10
        ninthInterval = 14
        roman = "IVm"
        quality = "m"
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
        notes = voicings,
        octShift = octShift,
        isWide = isWide,
    }
end

return Theory
