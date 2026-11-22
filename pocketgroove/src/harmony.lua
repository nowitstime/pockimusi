-- ============================================================================
-- src/harmony.lua — The current chord at any point in the loop (SPEC §5)
--
-- 0. Track C (the chord lane, Looper.LANE) can override for a while: a live
--    change played without recording (state.override) or a progression
--    being tried on the stamp wheel (state.preview). Both are in song ticks.
-- 1. The chord source is track C when it has chords. Its chords sit on the
--    lane's own timeline (2..16 bars): a loop position is turned into a lane
--    position with the loop pass (Looper:songTickAt). Otherwise, as before
--    the lane, the lowest-numbered chord track in a slot (Chord Harp or
--    Chord Track: SOURCES) with recorded chords; the Harp's role gets its
--    own pass later. The current chord is the latest one at or before the
--    position, wrapping (before the first chord, the last carries over).
-- 2. No recorded chords: the chord last played live on a Harp or Chord Track.
-- 3. Nothing played yet: the tonic (I of the key and scale).
--
-- A source track's state may carry `spice` = { [event] = chord }: chords
-- coloured differently for this pass of the loop (Chord Track SPICE row).
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
    -- Instruments that set the chords (they record `chord` data)
    SOURCES = { harp = true, chords = true },
    -- Instruments whose live chord counts when nothing is recorded
    LIVE = { harp = true, chords = true },
}

local function anyChord(track)
    for _, ev in ipairs(track.events) do
        if ev.chord and ev.chord.root and not ev.open then return true end
    end
    return false
end

local function hasChords(track)
    if not Harmony.SOURCES[track.instrumentId] then return false end
    for _, ev in ipairs(track.events) do
        if ev.chord and ev.chord.root and not ev.open then return true end
    end
    return false
end

-- Track C, the chord lane
function Harmony:lane()
    return Looper.tracks[Looper.LANE]
end

-- The chord-source track (recorded chords), or nil
function Harmony:source()
    local lane = self:lane()
    if lane and anyChord(lane) then return lane end
    for slot = 1, 4 do
        local track = Looper.tracks[slot]
        if track and hasChords(track) then return track end
    end
    return nil
end

-- The chord last played live on the lowest chord track that has played
-- one (a Harp that follows never chooses one), or nil
function Harmony:liveChord()
    for slot = 1, 4 do
        local track = Looper.tracks[slot]
        if track and self.LIVE[track.instrumentId] and track.state.liveChord then
            return track.state.liveChord
        end
    end
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
    local loop = track.isLane and Looper:getLaneTicks() or Looper:getLoopTicks()
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

-- The chord at a loop position, and where it came from:
-- "recorded", "live" or "tonic". `lookahead` (ticks, default LOOKAHEAD):
-- pass 0 for the chord sounding exactly at `tick` (a held Pad changing chord).
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

function Harmony:chordAt(tick, lookahead)
    local la = lookahead or self.LOOKAHEAD
    local song = Looper:songTickAt(tick) + la
    local over = self:overrideAt(song)
    if over then return over, "live" end
    local track = self:source()
    if track then
        local list = self:changes(track)
        local pos = track.isLane and Looper:lanePos(song) or ((tick + la) % Looper:getLoopTicks())
        local found = list[#list]                 -- wrap: the loop's last chord carries over
        for i = 1, #list do
            if list[i].tick <= pos then found = list[i] else break end
        end
        if found then
            -- a chord track may colour a chord differently on this pass (Chord Track SPICE)
            local spice = track.state and track.state.spice
            return (spice and spice[found.ev]) or found.chord, "recorded"
        end
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
