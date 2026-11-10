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

function Theory:getChordForDirection(dirKey, l1, r1)
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
    local extLabel = ""
    local voicings

    if l1 and r1 then
        extLabel = quality .. "add9+"
        voicings = {
            absRoot,
            absRoot + fifthInterval,
            absRoot + ninthInterval,
            absRoot + thirdInterval + 12
        }
    elseif l1 then
        if quality == "m" then
            extLabel = "m9"
        elseif seventhInterval == 11 then
            extLabel = "maj9"
        else
            extLabel = "9"
        end
        voicings = {
            absRoot,
            absRoot + thirdInterval,
            absRoot + seventhInterval,
            absRoot + ninthInterval
        }
    elseif r1 then
        extLabel = "sus4"
        voicings = {
            absRoot + 5,
            absRoot + fifthInterval,
            absRoot + 12,
            absRoot + 12 + 5
        }
    else
        extLabel = quality
        voicings = {
            absRoot,
            absRoot + thirdInterval,
            absRoot + fifthInterval,
            absRoot + 12
        }
    end

    return {
        name = noteName .. extLabel,
        roman = roman,
        dirKey = dirKey,
        notes = voicings,
    }
end

return Theory
