-- Lab foundation (lab/L0_FOUNDATION.md): what the lab instruments share.
-- A lab instrument here is a stand-in module put in package.preload, so the
-- tests don't depend on which real lab instruments exist.
local H = require("helpers")

local LIBRARY = { "drums", "harp", "bass", "pad", "lead" }

-- Stand-in lab modules, removed again by cleanup()
local preloaded = {}
local function preload(id, loader)
    package.preload["src.instruments." .. id] = loader
    preloaded[#preloaded + 1] = id
end
local function cleanup()
    for _, id in ipairs(preloaded) do
        package.preload["src.instruments." .. id] = nil
        package.loaded["src.instruments." .. id] = nil
    end
    preloaded = {}
end

-- A silent lab instrument
local function labDef(id, extra)
    local def = {
        id = id, name = id:upper(), shortName = id:upper():sub(1, 4), title = id:upper(), lab = true,
        viewKind = "lab",
        newState = function() return {} end,
        noteOn = function() end,
    }
    for k, v in pairs(extra or {}) do def[k] = v end
    return def
end

-- Run `fn` with stand-in lab instruments in place; always clean up
local function withLab(defs, fn)
    return function()
        for id, extra in pairs(defs) do
            preload(id, function() return labDef(id, extra) end)
        end
        local ok, err = xpcall(fn, debug.traceback)
        cleanup()
        H.fresh()                    -- leave no stand-in in the loaded modules
        if not ok then error(err, 0) end
    end
end

local function ids(I)
    local out = {}
    for i, inst in ipairs(I.catalog) do out[i] = inst.id end
    return table.concat(out, " ")
end

-- The real game (sounds generated), as the session tests boot it
local function bootSession()
    local M = H.loadMain()
    M.Config = require("src.config")
    H.play(0.1)
    return M, M.Looper
end

return {
    -- ------------------------------------------------------------------
    -- L0.1: the lab switch, reserved ids, saves
    -- ------------------------------------------------------------------
    { "LAB off: the catalogue is the five library instruments", withLab({ strum = {} }, function()
        local M = H.fresh()
        M.Config.LAB = false
        M.Instruments:buildCatalog()
        H.eq(ids(M.Instruments), table.concat(LIBRARY, " "), "library only")
        H.falsy(M.Instruments.byId.strum, "lab instrument not registered")
        -- stepping goes round the five and never lands anywhere else
        local id = "drums"
        for i = 1, 5 do
            id = M.Instruments:stepInstrumentId(id, 1)
            H.eq(id, LIBRARY[(i % 5) + 1], "step " .. i)
        end
    end) },

    { "LAB on: lab instruments that exist follow the library, in reserved order", withLab({ valves = {}, strum = {} }, function()
        local M = H.fresh()
        H.truthy(M.Config.LAB, "the switch is on for now")
        local list = ids(M.Instruments)
        H.truthy(list:find("^drums harp bass pad lead "), "library first: " .. list)
        H.truthy(list:find(" strum .*valves"), "strum before valves: " .. list)
        H.truthy(M.Instruments.byId.strum.lab, "marked lab")
        for _, inst in ipairs(M.Instruments.catalog) do
            H.truthy(inst.id ~= "hands" or package.loaded["src.instruments.hands"], "no entry without a module")
        end
    end) },

    { "a reserved id without a module is skipped", function()
        local M = H.fresh()
        for _, id in ipairs(M.Instruments.LAB_IDS) do
            local f = io.open("pocketgroove/src/instruments/" .. id .. ".lua", "r")
            if f then f:close() end
            H.eq(M.Instruments.byId[id] ~= nil, f ~= nil, id .. " is in the catalogue only if its file exists")
        end
    end },

    { "a lab module with an error fails loudly", function()
        preload("slide", function() error("slide is broken") end)
        local ok, err = pcall(H.fresh)
        cleanup()
        H.fresh()
        H.falsy(ok, "loading did not carry on without it")
        H.truthy(tostring(err):find("slide is broken", 1, true), "the module's own error: " .. tostring(err))
    end },

    { "a lab module that needs a missing module fails loudly", function()
        preload("slide", function() return require("src.instruments.no_such_helper") end)
        local ok, err = pcall(H.fresh)
        cleanup()
        H.fresh()
        H.falsy(ok, "not mistaken for a missing instrument")
        H.truthy(tostring(err):find("no_such_helper", 1, true), "names what is missing")
    end },

    { "the test runner knows the same reserved ids", function()
        local M = H.fresh()
        local f = assert(io.open("tests/run.lua", "r"))
        local text = f:read("*a")
        f:close()
        local list = text:match("local LAB_IDS = (%b{})")
        H.truthy(list, "tests/run.lua has a LAB_IDS list")
        local found = {}
        for id in list:gmatch('"([%w_]+)"') do found[#found + 1] = id end
        H.eq(table.concat(found, " "), table.concat(M.Instruments.LAB_IDS, " "), "same ids, same order")
    end },

    { "a save holding an unknown instrument loads that track empty on the default", function()
        local M, L = bootSession()
        H.record(L, 1, "B", 0.0)
        H.record(L, 3, "A", 0.25, { len = 240, degree = 1, octave = 0, semis = 0 })
        local snap = M.Session.snapshot()
        snap.tracks[2].instrumentId = "theremin"
        snap.tracks[2].settings = { patch = "odd_gong" }
        snap.tracks[2].events = { { tick = 0, action = "B", vel = 0.8 }, { tick = 480, action = "X", vel = 0.8, len = 100 } }
        snap.tracks[2].volume = 0.3
        snap.tracks[2].muted = true

        H.truthy(M.Session.restore(snap), "restored")
        local t2 = L.tracks[2]
        H.eq(t2.instrumentId, "harp", "the slot's default instrument")
        H.eq(#t2.events, 0, "its notes are dropped")
        H.eq(t2.state.patch, M.Instruments.byId.harp:newState().patch, "its settings are not applied")
        H.near(t2.volume, 0.3, "the track's own values stay")
        H.truthy(t2.muted, "mute stays")
        H.eq(#L.tracks[1].events, 1, "track 1 intact")
        H.eq(#L.tracks[3].events, 1, "track 3 intact")
        H.eq(L.tracks[3].events[1].len, 240, "track 3's note intact")
    end },

    { "a lab instrument's notes save and load; with LAB off the track loads empty", withLab({ strum = { eventClass = "strum" } }, function()
        local M, L = bootSession()
        M.Instruments:swapTrackInstrument(2, "strum")
        H.record(L, 2, "R1", 0.0, { len = 200, semis = 4 })
        H.record(L, 2, "L1", 0.25)
        H.record(L, 1, "B", 0.5)
        local snap = M.Session.snapshot()

        H.truthy(M.Session.restore(snap), "restored")
        H.eq(L.tracks[2].instrumentId, "strum", "lab instrument back")
        H.eq(#L.tracks[2].events, 2, "shoulder notes kept")
        H.eq(L.tracks[2].events[1].action, "R1", "R1 note")
        H.eq(L.tracks[2].events[1].len, 200, "its length")
        H.eq(L.tracks[2].events[2].action, "L1", "L1 note")

        M.Config.LAB = false
        M.Instruments:buildCatalog()
        H.truthy(M.Session.restore(snap), "restored with the lab off")
        H.eq(L.tracks[2].instrumentId, "harp", "default instrument")
        H.eq(#L.tracks[2].events, 0, "no lab notes on the harp")
        H.eq(#L.tracks[1].events, 1, "the drum track is intact")
    end) },
}
