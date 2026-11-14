-- ============================================================================
-- src/harmony.lua — The current chord at any point in the loop (SPEC §5)
--
-- 1. The chord source is the lowest-numbered Chord Harp track that has
--    recorded chords. The current chord is the latest one at or before the
--    position, wrapping (before the loop's first chord, the last carries over).
--    Muting that track doesn't change harmony.
-- 2. No recorded chords: the chord last played live on the lowest harp track.
-- 3. No harp, or nothing played yet: the tonic (I of the key and scale).
--
-- Chords are key-relative data ({ root, third, fifth, seventh, suffix,
-- roman, borrowed }), so they follow a key change. Followers turn a D-pad
-- degree into a pitch with Theory:getChordDegreeSemis(chord, degree).
-- ============================================================================

local Theory = require("src.theory")
local Looper = require("src.looper")

local Harmony = {
    -- A chord that starts up to this many ticks (one 1/16) after a position
    -- already counts there: chords are often played a touch late, and a bass
    -- note on the beat should still get the new chord.
    LOOKAHEAD = 120,
    cache = nil,     -- { events, count, last, loop, list = { { tick, chord }, ... } }
}

local function hasChords(track)
    if track.instrumentId ~= "harp" then return false end
    for _, ev in ipairs(track.events) do
        if ev.chord and ev.chord.root and not ev.open then return true end
    end
    return false
end

-- The chord-source track (recorded chords), or nil
function Harmony:source()
    for slot = 1, 4 do
        local track = Looper.tracks[slot]
        if track and hasChords(track) then return track end
    end
    return nil
end

-- The chord last played live on the lowest harp track, or nil
function Harmony:liveChord()
    for slot = 1, 4 do
        local track = Looper.tracks[slot]
        if track and track.instrumentId == "harp" then
            return track.state.liveChord
        end
    end
    return nil
end

function Harmony:tonic()
    return Theory:getChordForDirection("NEUTRAL", false, false)
end

-- Chord changes of the source track, sorted by tick (cached until its events change)
function Harmony:changes(track)
    local events = track.events
    local c = self.cache
    local loop = Looper:getLoopTicks()
    if c and c.events == events and c.count == #events and c.last == events[#events] and c.loop == loop then
        return c.list
    end
    local list = {}
    for _, ev in ipairs(events) do
        if ev.chord and ev.chord.root and not ev.open then
            list[#list + 1] = { tick = ev.tick, chord = ev.chord }
        end
    end
    table.sort(list, function(a, b) return a.tick < b.tick end)
    self.cache = { events = events, count = #events, last = events[#events], loop = loop, list = list }
    return list
end

-- The chord at a loop position, and where it came from:
-- "recorded", "live" or "tonic". `lookahead` (ticks, default LOOKAHEAD):
-- pass 0 for the chord sounding exactly at `tick` (a held Pad changing chord).
function Harmony:chordAt(tick, lookahead)
    local track = self:source()
    if track then
        local list = self:changes(track)
        local pos = (tick + (lookahead or self.LOOKAHEAD)) % Looper:getLoopTicks()
        local found = list[#list]                 -- wrap: the loop's last chord carries over
        for i = 1, #list do
            if list[i].tick <= pos then found = list[i] else break end
        end
        if found then return found.chord, "recorded" end
    end
    local live = self:liveChord()
    if live then return live, "live" end
    return self:tonic(), "tonic"
end

-- The chord at the playhead
function Harmony:current()
    return self:chordAt(Looper.tick)
end

return Harmony
