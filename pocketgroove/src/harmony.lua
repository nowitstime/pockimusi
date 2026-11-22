-- ============================================================================
-- src/harmony.lua — The current chord at any point in the loop (SPEC §5)
--
-- Track C (the chord lane, Looper.LANE) is the only chord source:
-- 1. A live change on track C played without recording (state.override), or
--    a progression being tried on its stamp wheel (state.preview). Both are
--    in song ticks.
-- 2. Track C's chords. They sit on the lane's own timeline (2..16 bars): a
--    loop position is turned into a lane position with the loop pass
--    (Looper:songTickAt). The current chord is the latest one at or before
--    the position, wrapping (before the first chord, the last carries over).
--    Track C's state may carry `spice` = { [event] = chord }: chords coloured
--    differently for this pass of the lane (its SPICE row).
-- 3. Nothing on track C: the tonic (I of the key and scale).
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
    cache = nil,     -- { track, events, rev, loop, list = { { tick, chord }, ... } }
}

local function anyChord(track)
    for _, ev in ipairs(track.events) do
        if ev.chord and ev.chord.root and not ev.open then return true end
    end
    return false
end

-- Track C, the chord lane
function Harmony:lane()
    return Looper.tracks[Looper.LANE]
end

-- Track C when it has chords, or nil
function Harmony:source()
    local lane = self:lane()
    if lane and anyChord(lane) then return lane end
    return nil
end

function Harmony:tonic()
    return Theory:getChordForDirection("NEUTRAL", false, false)
end

-- Chord changes of the source track, sorted by tick. Cached until its
-- events change: a new event list, or a change in place (track.rev, bumped
-- by Looper:touch).
function Harmony:changes(track)
    local events = track.events
    local c = self.cache
    local loop = Looper:getLaneTicks()
    if c and c.track == track and c.events == events and c.rev == track.rev and c.loop == loop then
        return c.list
    end
    local list = {}
    for _, ev in ipairs(events) do
        if ev.chord and ev.chord.root and not ev.open then
            list[#list + 1] = { tick = ev.tick, chord = ev.chord, ev = ev }
        end
    end
    table.sort(list, function(a, b) return a.tick < b.tick end)
    self.cache = { track = track, events = events, rev = track.rev, loop = loop, list = list }
    return list
end

-- A live change or wheel preview on track C covering song position `song`, or nil
function Harmony:overrideAt(song)
    local lane = self:lane()
    local st = lane and lane.state
    if not st or not Looper.playing then return nil end
    local pv = st.preview
    if pv and song >= pv.start and #pv.chords > 0 then
        local i = math.floor((song - pv.start) / pv.len) % #pv.chords + 1
        return pv.chords[i]
    end
    local o = st.override
    if o and song >= o.start and song < o.start + o.len then return o.chord end
    return nil
end

-- The chord at a loop position, and where it came from:
-- "recorded", "live" or "tonic". `lookahead` (ticks, default LOOKAHEAD):
-- pass 0 for the chord sounding exactly at `tick` (a held Pad changing chord).
function Harmony:chordAt(tick, lookahead)
    local la = lookahead or self.LOOKAHEAD
    local song = Looper:songTickAt(tick) + la
    local over = self:overrideAt(song)
    if over then return over, "live" end
    local track = self:source()
    if track then
        local list = self:changes(track)
        local pos = Looper:lanePos(song)
        local found = list[#list]                 -- wrap: the lane's last chord carries over
        for i = 1, #list do
            if list[i].tick <= pos then found = list[i] else break end
        end
        if found then
            -- coloured differently on this pass (track C's SPICE row)
            local spice = track.state.spice
            return (spice and spice[found.ev]) or found.chord, "recorded"
        end
    end
    return self:tonic(), "tonic"
end

-- Is track C setting chords (its chords, or a live change)?
-- With nothing, FOLLOW ON plays exactly as FOLLOW OFF: everything is in the key.
function Harmony:hasChords()
    if self:source() then return true end
    return self:overrideAt(Looper:songTick()) ~= nil
end

-- The FOLLOW chip on a follower's stage: what it follows
function Harmony:followChip(on)
    if not on then return "FOLLOW OFF" end
    if not self:hasChords() then return "FOLLOW - NO CHORDS" end
    return "FOLLOW " .. Theory:chordName((self:current()))
end

-- The chord at the playhead
function Harmony:current()
    return self:chordAt(Looper.tick)
end

return Harmony
