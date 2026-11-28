-- ============================================================================
-- src/instruments/patches.lua — An instrument's view of the sound pool
--
-- Every pitched instrument picks from the same catalogue (SPEC §6,
-- src/synth/synths_bank.lua). An instrument says what it needs:
--   HOME_GROUP     the group listed first (its own sounds)
--   DEFAULT_PATCH  the patch a new track starts with
--   REGISTER       the octave of C its 0 semitones plays (Bass 3, others 4)
--   VOICES         how many voices it can sound at once
--   NEEDS_LOOP     true = only patches that sustain (the Pad)
--   NEEDS_BRIGHT   true = only patches with a bright layer (Wobble)
--   ALLOW_SILENT   true = the silent patch is offered (chord instruments)
-- and gets its list, the Track page PATCH row and the note calls from here.
-- ============================================================================

local Synth  = require("src.synth")
local Looper = require("src.looper")

local Patches = {}

function Patches.allowed(def, patch)
    if not patch or not patch.group then return false end
    if patch.silent then return def.ALLOW_SILENT == true end
    if def.NEEDS_LOOP and not patch.loop then return false end
    if def.NEEDS_BRIGHT and not patch.bright then return false end
    return true
end

-- The ids this instrument can play: its home group first, then the other
-- groups in catalogue order
function Patches.list(def)
    local order = Synth.patchOrder or {}
    local cache = rawget(def, "_patchList")
    if cache and cache.count == #order then return cache.ids end
    local ids = {}
    for pass = 1, 2 do
        for _, id in ipairs(order) do
            local p = Synth.patches[id]
            if Patches.allowed(def, p) and ((p.group == def.HOME_GROUP) == (pass == 1)) then
                ids[#ids + 1] = id
            end
        end
    end
    def._patchList = { count = #order, ids = ids }
    return ids
end

function Patches.indexOf(def, id)
    for i, v in ipairs(Patches.list(def)) do
        if v == id then return i end
    end
    return 1
end

-- The track's patch, or the instrument's default if it can't play that one
function Patches.get(def, state)
    local p = Synth.patches[state.patch]
    if Patches.allowed(def, p) then return p end
    return Synth.patches[def.DEFAULT_PATCH]
end

-- The Track page PATCH row: picker items grouped as the catalogue is
function Patches.row(def, state)
    local patch = Patches.get(def, state)
    local items = {}
    for i, id in ipairs(Patches.list(def)) do
        local p = Synth.patches[id]
        items[i] = { label = p.label, group = p.group, full = p.full }
    end
    if #items == 0 then items[1] = { label = state.patch } end
    return { key = "PATCH", label = "PATCH", value = patch and patch.label or state.patch,
             items = items, index = Patches.indexOf(def, state.patch) }
end

-- LEFT / RIGHT on the PATCH row
function Patches.step(def, state, delta)
    local ids = Patches.list(def)
    if #ids == 0 then return nil end
    state.patch = ids[((Patches.indexOf(def, state.patch) - 1 + delta) % #ids) + 1]
    local patch = Synth.patches[state.patch]
    Synth:preparePatch(state.patch, def.VOICES)       -- generated now, not on the first note
    Looper:showToast(def.shortName .. " PATCH: " .. (patch.full or patch.label))
    return patch
end

-- A saved patch id: kept only if this instrument can play it
function Patches.load(def, state, id)
    if type(id) == "string" and Patches.allowed(def, Synth.patches[id]) then
        state.patch = id
        Synth:preparePatch(id, def.VOICES)
    end
end

-- Start a note on the track's patch, in the instrument's register
function Patches.noteOn(def, state, semis, vel, opts)
    opts = opts or {}
    opts.register = opts.register or def.REGISTER
    opts.voices = opts.voices or def.VOICES
    local patch = Patches.get(def, state)
    return patch and Synth:noteOn(patch.id, semis, vel, opts) or nil
end

-- A short note to hear the patch (Track page)
function Patches.preview(def, state, semis, vel, opts, length)
    local v = Patches.noteOn(def, state, semis, vel or 0.8, opts)
    if v and v.loopSrc then Synth:schedule(length or 0.3, function() v:noteOff() end) end
    return v
end

return Patches
