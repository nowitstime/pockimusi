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

-- The real game (sounds generated), as the session tests boot it
local function bootSession()
    local M = H.loadMain()
    M.Config = require("src.config")
    H.play(0.1)
    return M, M.Looper
end

-- A catalogue of exactly n instruments: the library plus stand-ins
local function setCatalog(I, n)
    I.catalog, I.byId = {}, {}
    for _, inst in ipairs(I.LIBRARY) do I.catalog[#I.catalog + 1] = inst end
    for i = 6, n do I.catalog[i] = labDef("lab" .. i) end
    for _, inst in ipairs(I.catalog) do I.byId[inst.id] = inst end
end

-- The Track page's tabs as they stand now (after any slide has finished)
local function tabs(M)
    local Chrome = require("src.ui.chrome")
    local track = M.Looper.tracks[M.Looper.activeTrack]
    return Chrome:tabLayout(Chrome:tabPosition(track)), Chrome
end

local function centreTab(M)
    for _, tab in ipairs((tabs(M))) do
        if math.abs(tab.d) < 0.01 then return tab end
    end
end

-- Boot the real game with a love.graphics that keeps every printed text.
-- Returns M and seen(text): was exactly this text printed in the next frame?
local function bootCapturing()
    local texts = {}
    local noop = function() end
    H.graphicsOverride = setmetatable({
        newFont = function(size)
            size = size or 12
            return { size = size, getHeight = function() return size end,
                     getWidth = function(_, t) return #tostring(t) * math.floor(size * 0.6) end }
        end,
        getDimensions = function() return 640, 480 end,
        print = function(text) texts[#texts + 1] = tostring(text) end,
    }, { __index = function() return noop end })
    local M = bootSession()
    H.graphicsOverride = nil
    local function frame()
        for i = #texts, 1, -1 do texts[i] = nil end
        H.play(1 / 60)
        local set = {}
        for _, t in ipairs(texts) do set[t] = true end
        return set
    end
    return M, frame
end

-- Add stand-in instruments to the running catalogue
local function addInstrument(I, def)
    I.catalog[#I.catalog + 1] = def
    I.byId[def.id] = def
    return def
end

-- Make `id` the instrument of track `slot` and the active track
local function playOn(M, slot, id)
    M.Instruments:swapTrackInstrument(slot, id)
    M.Looper.activeTrack = slot
end

local function ids(I)
    local out = {}
    for i, inst in ipairs(I.catalog) do out[i] = inst.id end
    return table.concat(out, " ")
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

    -- ------------------------------------------------------------------
    -- L0.2: the instrument tabs as a centred carousel
    -- ------------------------------------------------------------------
    { "the centred tab is the track's own instrument, then the previewed one", function()
        local M = bootSession()
        local page = require("src.modes").trackPage
        H.hold("SELECT"); H.play(0.3)
        H.eq(centreTab(M).inst.id, "drums", "own instrument in the centre")
        H.eq(centreTab(M).x, 320, "the centre of the strip")
        H.near(centreTab(M).alpha, 1.0, "fully lit")

        H.tap("R1"); H.play(0.3)
        H.eq(page.pending, "harp", "previewing the harp")
        H.eq(centreTab(M).inst.id, "harp", "the preview takes the centre")
        local own
        for _, tab in ipairs((tabs(M))) do
            if tab.inst.id == "drums" then own = tab end
        end
        H.truthy(own and own.d == -1, "the track's own is still in view, one to the left")

        H.tap("L1"); H.play(0.3)
        H.eq(page.pending, nil, "back on the track's own: no preview")
        H.eq(centreTab(M).inst.id, "drums", "own instrument back in the centre")
        H.release("SELECT"); H.play(0.1)
    end },

    { "the tabs are a ring: stepping past either end wraps", function()
        local M = bootSession()
        local I = M.Instruments
        setCatalog(I, 7)
        local first, last = I.catalog[1].id, I.catalog[7].id
        H.eq(I:stepInstrumentId(last, 1), first, "past the last comes the first")
        H.eq(I:stepInstrumentId(first, -1), last, "before the first comes the last")

        -- on screen too: the first instrument has the last one on its left
        H.hold("SELECT"); H.play(0.3)
        local list = tabs(M)
        local seen = {}
        for _, tab in ipairs(list) do seen[tab.d] = tab.inst.id end
        H.eq(seen[0], first, "centre")
        H.eq(seen[-1], last, "the last instrument sits left of the first")
        H.eq(seen[-2], I.catalog[6].id, "and the one before it")
        H.eq(seen[1], I.catalog[2].id, "the second on the right")
        H.release("SELECT"); H.play(0.1)
    end },

    { "every instrument can be reached with L1 alone and with R1 alone", function()
        for _, btn in ipairs({ "L1", "R1" }) do
            local M = bootSession()
            local I = M.Instruments
            setCatalog(I, 10)
            local page = require("src.modes").trackPage
            H.hold("SELECT"); H.play(0.3)
            local reached = { drums = true }
            local count = 1
            for _ = 1, 9 do
                H.tap(btn)
                H.truthy(page.pending, btn .. " previews an instrument")
                H.falsy(reached[page.pending], btn .. " never repeats before the ring is done: " .. page.pending)
                reached[page.pending] = true
                count = count + 1
                H.play(0.2)
                H.eq(centreTab(M).inst.id, page.pending, "the centre follows")
            end
            H.eq(count, 10, "all ten with " .. btn)
            H.tap(btn)
            H.eq(page.pending, nil, "one more step is back home")
            H.release("SELECT"); H.play(0.1)
        end
    end },

    { "the strip slides the way of the step and settles", function()
        local M = bootSession()
        local Chrome = require("src.ui.chrome")
        local track = M.Looper.tracks[1]
        H.hold("SELECT"); H.play(0.3)
        H.eq(Chrome:tabPosition(track), 1, "at rest on the first tab")
        H.hold("R1"); H.play(1 / 60); H.release("R1")
        local pos = Chrome.tabAnim.pos
        H.truthy(pos > 1 and pos < 2, "part of the way to the second tab: " .. pos)
        H.play(0.2)
        H.eq(Chrome.tabAnim.pos, 2, "settled on it")

        -- from the first tab back to the last: the short way, leftwards
        H.tap("L1"); H.play(0.2)
        H.hold("L1"); H.play(1 / 60); H.release("L1")
        local n = #M.Instruments.catalog
        pos = Chrome.tabAnim.pos
        H.truthy(pos > n and pos < n + 1, "sliding left through the seam: " .. pos)
        H.play(0.2)
        H.eq(Chrome.tabAnim.pos, n, "settled on the last tab")
        H.release("SELECT"); H.play(0.1)
    end },

    { "the tabs draw with 5, 6 and 10 instruments, never showing one twice", function()
        for _, n in ipairs({ 5, 6, 10 }) do
            local M = bootSession()
            setCatalog(M.Instruments, n)
            H.hold("SELECT"); H.play(0.3)
            for _ = 1, n do
                H.hold("R1"); H.play(1 / 60); H.release("R1")
                for _ = 1, 8 do                          -- mid-slide frames too
                    H.play(1 / 60)
                    local list = tabs(M)
                    local seen = {}
                    H.truthy(#list >= 3 and #list <= 5, n .. " instruments: 3 to 5 tabs in view, got " .. #list)
                    for _, tab in ipairs(list) do
                        H.falsy(seen[tab.inst.id], tab.inst.id .. " drawn twice")
                        seen[tab.inst.id] = true
                        H.truthy(tab.x > 198 and tab.x < 442, "inside the centre column")
                    end
                end
            end
            H.release("SELECT"); H.play(0.1)
            H.eq(M.Looper.tracks[1].instrumentId, "drums", "a full circle changes nothing")
        end
    end },

    { "a lab instrument's tab is marked; the outer tabs fade", function()
        local M = bootSession()
        setCatalog(M.Instruments, 10)
        H.hold("SELECT"); H.play(0.3)
        local list = tabs(M)
        for _, tab in ipairs(list) do
            if math.abs(tab.d) == 2 then
                H.truthy(tab.alpha < 0.6 and tab.alpha > 0.2, "faded but readable: " .. tab.alpha)
            else
                H.near(tab.alpha, 1.0, "centre and neighbours fully lit")
            end
        end
        H.truthy(list[1].inst.lab and list[2].inst.lab, "left of DRUMS: the last two (lab) instruments")
        H.falsy(list[3].inst.lab, "the library is not marked")
        H.release("SELECT"); H.play(0.1)
    end },

    -- ------------------------------------------------------------------
    -- L0.3: stage views from data (viewKind, VIEW, getReadout, LANES)
    -- ------------------------------------------------------------------
    { "viewKind \"bass\" on a Bass-built instrument: the Bass view with its own labels", function()
        local M, frame = bootCapturing()
        local Bass = require("src.instruments.bass")
        addInstrument(M.Instruments, setmetatable({
            id = "slide", name = "SLIDE", shortName = "SLID", title = "SLIDE", lab = true, viewKind = "bass",
            VIEW = { dpad = { UP = "RISE", DOWN = "FALL" }, face = { B = "PLAY", A = "SNAP", Y = "DIVE", X = "LOUD" },
                     l1 = "LOW", r1 = "HIGH", both = "WIDE" },
        }, { __index = Bass }))
        playOn(M, 3, "slide")
        local seen = frame()
        H.truthy(seen["PITCH TRACE"], "the Bass's pitch trace")
        H.truthy(seen["GLIDE MEDIUM"], "the Bass's capsules")
        H.truthy(seen["RISE"] and seen["FALL"], "its own D-pad labels")
        H.truthy(seen["PLAY"] and seen["SNAP"] and seen["DIVE"] and seen["LOUD"], "its own face labels")
        H.falsy(seen["LEGATO"] or seen["L5"], "none of the Bass's labels")
        H.truthy(seen["L1: LOW"] and seen["R1: HIGH"], "its own shoulder labels")
        H.truthy(seen["SLIDE"], "its name as the title")
        H.hold("L1", "R1")
        seen = frame()
        H.truthy(seen["L1+R1: WIDE"], "the label for both shoulders")
        H.release("L1", "R1")
    end },

    { "VIEW parts may be left out: the view's own labels fill in", function()
        local M, frame = bootCapturing()
        local Bass = require("src.instruments.bass")
        addInstrument(M.Instruments, setmetatable({
            id = "dial", name = "DIAL", shortName = "DIAL", lab = true, viewKind = "bass",
            VIEW = { face = { B = "ONE", A = "THREE", Y = "SEVEN", X = "FIVE" } },
        }, { __index = Bass }))
        playOn(M, 3, "dial")
        local seen = frame()
        H.truthy(seen["ONE"] and seen["FIVE"], "its face labels")
        H.truthy(seen["L5"], "the Bass's D-pad labels")
        H.truthy(seen["L1: OCT -1"] and seen["R1: OCT +1"], "the Bass's shoulder labels")
        H.hold("L1", "R1")
        H.truthy(frame()["L1: OCT -1"], "no label for both: each shoulder keeps its own")
        H.release("L1", "R1")
    end },

    { "a Bass-view instrument may word the readout itself", function()
        local M, frame = bootCapturing()
        local Bass = require("src.instruments.bass")
        addInstrument(M.Instruments, setmetatable({
            id = "slide", name = "SLIDE", shortName = "SLID", lab = true, viewKind = "bass",
            getReadout = function() return "E +", "BETWEEN 3 AND 4" end,
        }, { __index = Bass }))
        playOn(M, 3, "slide")
        local seen = frame()
        H.truthy(seen["E +"] and seen["BETWEEN 3 AND 4"], "both lines from the instrument")
        H.truthy(seen["PITCH TRACE"], "still the Bass view")
    end },

    { "viewKind \"lab\": the plain view draws the readout", function()
        local M, frame = bootCapturing()
        addInstrument(M.Instruments, labDef("strum", {
            getReadout = function(_, state) return state.big, "DOWN STROKE", { "FIRST LINE", "SECOND LINE" } end,
            newState = function() return { big = "3  +  5TH" } end,
        }))
        playOn(M, 2, "strum")
        local seen = frame()
        H.truthy(seen["3  +  5TH"], "the large line, from the state")
        H.truthy(seen["DOWN STROKE"], "the small line")
        H.truthy(seen["FIRST LINE"] and seen["SECOND LINE"], "further lines")
        H.truthy(seen["LAB"], "marked as a lab view")
        H.truthy(seen["L1: -"] and seen["R1: -"], "no shoulder labels of its own")
        H.truthy(seen["B"] and seen["X"], "plain face labels")
    end },

    { "an instrument with no view of its own gets the plain view", function()
        local M, frame = bootCapturing()
        local def = labDef("valves")
        def.viewKind = nil
        addInstrument(M.Instruments, def)
        H.eq(require("src.ui.chrome"):viewKind(def), "lab", "falls back to the lab view")
        playOn(M, 4, "valves")
        local seen = frame()
        H.truthy(seen["VALVES"], "its name, large")
        H.truthy(seen["LAB"], "the plain view")
    end },

    { "viewKind \"drums\" on a Drums-built instrument: the four lanes with its own labels", function()
        local M, frame = bootCapturing()
        local Drums = require("src.instruments.drums")
        addInstrument(M.Instruments, setmetatable({
            id = "hands", name = "HAND DRUMS", shortName = "HAND", lab = true, viewKind = "drums", eventClass = "drums",
            VIEW = { dpad = { UP = "PAD X", DOWN = "PAD B", LEFT = "PAD Y", RIGHT = "PAD A" }, l1 = "SOFT", r1 = "LOUD" },
        }, { __index = Drums }))
        playOn(M, 1, "hands")
        H.tap("L2"); H.tap("B"); H.tap("L2")
        local seen = frame()
        H.truthy(seen["1 HIT"], "the lanes count the hit")
        H.truthy(seen["REPEAT OFF"], "the drum view's capsules")
        H.truthy(seen["PAD X"] and seen["PAD A"], "its own D-pad labels")
        H.falsy(seen["FLAM"], "not the Drums' labels")
        H.truthy(seen["L1: SOFT"] and seen["R1: LOUD"], "its own shoulder labels")
    end },

    { "the five library instruments keep their views and labels", function()
        local M, frame = bootCapturing()
        local expect = {
            drums = { "ACCENT", "RATCHET", "L1: 1/4", "R1: 1/8", "REPEAT OFF", "D-PAD: EXPRESSION" },
            harp  = { "bVI", "IVm", "L1: OCT -", "R1: OCT +", "D-PAD: HARMONY" },
            bass  = { "L5", "LEGATO", "STAC", "L1: OCT -1", "PITCH TRACE", "GLIDE MEDIUM", "D-PAD: SCALE DEGREE" },
            pad   = { "BRIGHT +", "SWELL", "L1: OCT -1", "MOVE", "D-PAD: TONE" },
            lead  = { "NOTE", "ARP", "L1: OCT -1", "PITCH TRACE", "D-PAD: SCALE DEGREE" },
        }
        for id, labels in pairs(expect) do
            playOn(M, 3, id)
            local seen = frame()
            for _, label in ipairs(labels) do
                H.truthy(seen[label], id .. " shows " .. label)
            end
            H.falsy(seen["LAB"], id .. " is not drawn as a lab view")
        end
        playOn(M, 3, "lead")
        H.hold("L1", "R1")
        H.truthy(frame()["L1+R1: RATE x2"], "the Lead's both-shoulders label")
        H.release("L1", "R1")
    end },

    { "LANES: a shoulder-started note lands on the tape deck row the instrument names", function()
        local M, frame = bootCapturing()
        local Chrome = require("src.ui.chrome")
        local strum = addInstrument(M.Instruments, labDef("strum", { LANES = { R1 = 1, L1 = 2 } }))
        local bass = M.Instruments.byId.bass
        H.eq(Chrome:eventRow(strum, { action = "R1", len = 0 }), Chrome.LANE_ROW[1], "R1 hit on row 1")
        H.eq(Chrome:eventRow(strum, { action = "R1", len = 200 }), Chrome.LANE_ROW[1], "R1 held note on row 1")
        H.eq(Chrome:eventRow(strum, { action = "L1", len = 0 }), Chrome.LANE_ROW[2], "L1 on row 2")
        H.truthy(Chrome.LANE_ROW[1] < Chrome.LANE_ROW[2], "row 1 is above row 2")
        H.eq(Chrome:eventRow(strum, { action = "B", len = 200 }), Chrome.RIBBON_ROW.B, "a face button keeps its own row")
        H.eq(Chrome:eventRow(strum, { action = "B", len = 0 }), 0, "a face-button hit stays on the centre line")
        -- instruments without LANES are as before
        H.eq(Chrome:eventRow(bass, { action = "A", len = 200 }), Chrome.RIBBON_ROW.A, "Bass held note")
        H.eq(Chrome:eventRow(bass, { action = "A", open = true }), Chrome.RIBBON_ROW.A, "Bass note still held")
        H.eq(Chrome:eventRow(bass, { action = "A", len = 0 }), 0, "hit")
        H.eq(Chrome:eventRow(bass, { action = "R1", len = 200 }), 0, "an action nobody names: the centre line")

        -- and the deck draws them
        playOn(M, 2, "strum")
        H.record(M.Looper, 2, "R1", 0.1, { len = 300 })
        H.record(M.Looper, 2, "L1", 0.3)
        H.record(M.Looper, 2, "R1", 0.6, { vel = 1.0 })
        frame()
    end },
}
