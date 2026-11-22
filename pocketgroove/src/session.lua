-- ============================================================================
-- src/session.lua — The whole session as a plain table, and back (SPEC §10)
--
-- Session.snapshot() -> table that Save.encode can write: tempo, key, scale,
-- bars, click, master volume, active track; per track: instrument, its
-- settings (def:saveState), grid, swing, volume, mute, effects and events.
-- Not saved: undo history, record latch, playhead, voices, animations.
--
-- Session.restore(data) checks every value as it goes (a damaged or edited
-- file can't put the game in a bad state) and applies it. Returns true, or
-- false + message if the data isn't a session it understands.
-- ============================================================================

local Config      = require("src.config")
local Theory      = require("src.theory")
local Input       = require("src.input")
local Synth       = require("src.synth")
local Looper      = require("src.looper")
local Instruments = require("src.instruments")

local clamp = Config.clamp

local Session = {
    FORMAT = 1,
    DEFAULT_INSTRUMENTS = { "drums", "harp", "bass", "pad" },
    -- Instruments that no longer exist load as their replacement (notes kept)
    REPLACED = { grain = "pad" },
}

-- Event fields that only matter while the game runs
local RUNTIME_FIELDS = { open = true, skipOnce = true }
-- What can start a note: a face button, or a shoulder (lab instruments that
-- pluck or blow with L1 / R1)
local ACTIONS = { B = true, A = true, Y = true, X = true, L1 = true, R1 = true }

-- ---------------------------------------------------------------------------
-- Snapshot
-- ---------------------------------------------------------------------------
local function copyPlain(v, depth)
    if type(v) ~= "table" then
        local tv = type(v)
        if tv == "number" or tv == "string" or tv == "boolean" then return v end
        return nil                                -- functions, voices: never saved
    end
    if depth > 8 then return nil end
    local out = {}
    for k, x in pairs(v) do
        if type(k) == "string" or type(k) == "number" then
            out[k] = copyPlain(x, depth + 1)
        end
    end
    return out
end

local function snapshotEvent(ev, loop)
    local out = {}
    for k, v in pairs(ev) do
        if not RUNTIME_FIELDS[k] then out[k] = copyPlain(v, 0) end
    end
    if ev.open then
        -- still being held: save the length it has so far
        out.len = math.max(1, math.floor((Looper.tick - ev.tick) % loop + 0.5))
    end
    return out
end

function Session.snapshot()
    local loop = Looper:getLoopTicks()
    local tracks = {}
    for slot = 1, 4 do
        local track = Looper.tracks[slot]
        local def = Instruments:getDefinition(track.instrumentId)
        local events = {}
        for i, ev in ipairs(track.events) do events[i] = snapshotEvent(ev, loop) end
        tracks[slot] = {
            instrumentId = track.instrumentId,
            settings = def.saveState and copyPlain(def:saveState(track.state), 0) or nil,
            gridIndex = track.gridIndex,
            swing = track.swing,
            volume = track.volume,
            muted = track.muted,
            fx = copyPlain(track.fx, 0),
            events = events,
        }
    end
    -- Track C, the chord lane: its settings and chords (on the lane's own timeline)
    local lane = Looper:getLane()
    local laneOut
    if lane then
        local def = Instruments:getDefinition("lane")
        local events = {}
        for i, ev in ipairs(lane.events) do events[i] = snapshotEvent(ev, Looper:getLaneTicks()) end
        laneOut = { settings = copyPlain(def:saveState(lane.state), 0), events = events }
    end
    return {
        format = Session.FORMAT,
        lane = laneOut,
        bpm = Looper.bpm,
        bars = Looper.bars,
        clickOn = Looper.clickOn,
        countIn = Looper.countIn,
        activeTrack = Looper.activeTrack,
        rootIndex = Theory.rootIndex,
        scaleIndex = Theory.scaleIndex,
        masterVolume = Synth.masterVolume,
        tracks = tracks,
    }
end

-- ---------------------------------------------------------------------------
-- Restore (every value checked)
-- ---------------------------------------------------------------------------
local function num(v, lo, hi, default)
    if type(v) ~= "number" or v ~= v then return default end
    return clamp(v, lo, hi)
end

local function int(v, lo, hi, default)
    v = num(v, lo, hi, nil)
    if not v then return default end
    return math.floor(v + 0.5)
end

-- Fields instruments read as numbers, and the chord's numbers. A damaged
-- file with something else there loses the event (better than an error on
-- every pass of the loop).
local NUMBER_FIELDS = {
    degree = true, octave = true, acc = true, decay = true, ratchet = true, strum = true,
    string = true, octShift = true, key = true, tone = true, steps = true,
    glideFrom = true, glideFromDegree = true, glideFromOctave = true, bright = true, move = true,
}
local CHORD_NUMBERS = { root = true, third = true, fifth = true, seventh = true, key = true, octShift = true }

local function finite(v)
    return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

-- true if the instrument fields of `ev` are the types instruments expect
local function fieldsOk(ev)
    for k in pairs(NUMBER_FIELDS) do
        if ev[k] ~= nil and not finite(ev[k]) then return false end
    end
    if ev.soundId ~= nil and type(ev.soundId) ~= "string" then return false end
    if ev.orn ~= nil and type(ev.orn) ~= "string" then return false end
    if ev.chord ~= nil then
        if type(ev.chord) ~= "table" or not finite(ev.chord.root) then return false end
        for k in pairs(CHORD_NUMBERS) do
            if ev.chord[k] ~= nil and not finite(ev.chord[k]) then return false end
        end
        if ev.chord.notes ~= nil then
            if type(ev.chord.notes) ~= "table" then return false end
            for _, n in pairs(ev.chord.notes) do if not finite(n) then return false end end
        end
    end
    for _, list in ipairs({ "notes", "stack" }) do
        if ev[list] ~= nil and type(ev[list]) ~= "table" then return false end
    end
    if ev.slur ~= nil then
        if type(ev.slur) ~= "table" then return false end
        for _, kf in ipairs(ev.slur) do
            if type(kf) ~= "table" or not finite(kf.dt) then return false end
        end
    end
    return true
end

local function restoreEvent(raw, loop)
    if type(raw) ~= "table" or not ACTIONS[raw.action] then return nil end
    local tick = raw.tick
    if type(tick) ~= "number" or tick ~= tick or tick < 0 or tick >= loop then return nil end

    local ev = {}
    for k, v in pairs(raw) do
        if type(k) == "string" and not RUNTIME_FIELDS[k] then ev[k] = copyPlain(v, 0) end
    end
    ev.tick = math.floor(tick)
    ev.len = int(raw.len, 0, loop - 1, 0)
    ev.vel = num(raw.vel, 0.0, 1.0, 0.85)
    if raw.grid ~= nil then ev.grid = num(raw.grid, 1, loop, nil) end
    if raw.semis ~= nil then ev.semis = num(raw.semis, -48, 48, 0) end
    if raw.takeId ~= nil then ev.takeId = int(raw.takeId, 0, 1e9, 0) end
    if raw.chance ~= nil then ev.chance = num(raw.chance, 0.0, 1.0, nil) end

    -- keyframes (pitch bends, Pad tone sweeps): keep the valid ones, in time order
    if raw.bend ~= nil then
        local kfs = {}
        if type(raw.bend) == "table" then
            for _, kf in ipairs(raw.bend) do
                if type(kf) == "table" and type(kf.dt) == "number" and kf.dt >= 0 and kf.dt < loop
                   and (finite(kf.semis) or finite(kf.bright) or finite(kf.move)) then
                    kfs[#kfs + 1] = { dt = math.floor(kf.dt),
                                      semis = kf.semis ~= nil and num(kf.semis, -48, 48, 0) or nil,
                                      degree = finite(kf.degree) and kf.degree or nil,
                                      octave = finite(kf.octave) and kf.octave or nil,
                                      acc = finite(kf.acc) and kf.acc or nil,
                                      bright = kf.bright ~= nil and num(kf.bright, 0.0, 1.0, nil) or nil,
                                      move = kf.move ~= nil and num(kf.move, 0.0, 1.0, nil) or nil }
                end
            end
            table.sort(kfs, function(a, b) return a.dt < b.dt end)
        end
        ev.bend = (#kfs > 0) and kfs or nil
    end
    if not fieldsOk(ev) then return nil end
    return ev
end

function Session.restore(data)
    if type(data) ~= "table" then return false, "not a session" end
    if data.format ~= Session.FORMAT then
        return false, "session format " .. tostring(data.format) .. " (this version reads " .. Session.FORMAT .. ")"
    end

    -- Stop everything that is sounding or held first
    Instruments:releaseAll()
    Looper:silenceAll()
    Input.recLatched = false

    -- Globals
    Looper.bpm = int(data.bpm, Config.MIN_BPM, Config.MAX_BPM, Config.DEFAULT_BPM)
    Looper.bars = (data.bars == 4) and 4 or 2
    Looper.clickOn = (data.clickOn == true)
    Looper.countIn = (data.countIn == true)
    Theory.rootIndex = int(data.rootIndex, 1, #Theory.NOTE_NAMES, 1)
    Theory.scaleIndex = int(data.scaleIndex, 1, #Theory.SCALES, 1)
    Synth.masterVolume = num(data.masterVolume, 0.0, 1.0, Synth.masterVolume)

    local loop = Looper:getLoopTicks()
    local tracks = type(data.tracks) == "table" and data.tracks or {}
    local maxTake = 0

    for slot = 1, 4 do
        local raw = type(tracks[slot]) == "table" and tracks[slot] or {}
        local instId = raw.instrumentId
        instId = Session.REPLACED[instId] or instId
        -- An instrument that isn't there (a lab experiment since deleted, or
        -- the lab switched off): the slot's default, and none of its notes.
        -- They were played on another instrument and would mean nothing here.
        local missing = type(instId) == "string" and not Instruments.byId[instId]
        if type(instId) ~= "string" or missing then
            instId = Session.DEFAULT_INSTRUMENTS[slot]
        end
        Looper:setTrackInstrument(slot, instId, Instruments)   -- fresh state, no events
        local track = Looper.tracks[slot]
        local def = Instruments:getDefinition(instId)
        if def.loadState and not missing then def:loadState(track.state, raw.settings) end

        track.gridIndex = int(raw.gridIndex, 1, #Looper.GRID_MODES, track.gridIndex)
        track.swing = num(raw.swing, 0.50, 0.75, 0.50)
        track.volume = num(raw.volume, 0.0, 1.0, track.volume)
        track.muted = (raw.muted == true)

        local fx = type(raw.fx) == "table" and raw.fx or {}
        local on = type(fx.on) == "table" and fx.on or {}
        for _, slotName in ipairs(Looper.FX_ORDER) do
            track.fx[slotName] = num(fx[slotName], 0.0, 1.0, track.fx[slotName])
            track.fx.on[slotName] = (on[slotName] == true)
        end
        Synth:configureTrackFx(track)

        track.events = {}
        if type(raw.events) == "table" and not missing then
            for _, rawEv in ipairs(raw.events) do
                local ev = restoreEvent(rawEv, loop)
                if ev then
                    track.events[#track.events + 1] = ev
                    if ev.takeId and ev.takeId > maxTake then maxTake = ev.takeId end
                end
            end
        end
    end

    -- Track C (older saves have none: an empty 4-bar lane)
    local lane = Looper:getLane()
    if lane then
        local def = Instruments:getDefinition("lane")
        local rawLane = type(data.lane) == "table" and data.lane or {}
        lane.state = def:newState()
        def:loadState(lane.state, rawLane.settings)
        lane.events = {}
        local laneT = Looper:getLaneTicks()
        if type(rawLane.events) == "table" then
            for _, rawEv in ipairs(rawLane.events) do
                local ev = restoreEvent(rawEv, laneT)
                if ev and ev.chord then
                    lane.events[#lane.events + 1] = ev
                    if ev.takeId and ev.takeId > maxTake then maxTake = ev.takeId end
                end
            end
        end
        Looper:touch(lane)
    end

    Looper.activeTrack = int(data.activeTrack, 1, #Looper.tracks, 1)
    Looper.currentTakeId = maxTake
    Looper.undoStack = {}
    Looper:seek(0.0)
    Looper.pass = 0
    Looper:showToast("SESSION RESTORED")
    return true
end

return Session
