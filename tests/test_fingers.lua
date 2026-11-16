-- FINGERS (lab/L0_FOUNDATION.md, L0.6): the silent lab instrument that shows
-- what the fingering reader sees. This file runs because "fingers" is a
-- reserved lab id (tests/run.lua).
local H = require("helpers")

local function boot()
    local M = H.loadMain()
    H.play(0.1)
    M.Instruments:swapTrackInstrument(2, "fingers")
    M.Looper.activeTrack = 2
    return M, M.Looper.tracks[2].state, M.Instruments.byId.fingers
end

return {
    { "FINGERS is in the catalogue as a lab instrument, after the library", function()
        local M = H.fresh()
        local def = M.Instruments.byId.fingers
        H.truthy(def, "registered")
        H.truthy(def.lab, "marked lab")
        H.eq(def.viewKind, "lab", "drawn by the plain view")
        H.eq(M.Instruments.catalog[#M.Instruments.catalog], def, "last tab")
        M.Config.LAB = false
        M.Instruments:buildCatalog()
        H.falsy(M.Instruments.byId.fingers, "gone with the lab off")
    end },

    { "a clean press of each of the nine is counted once", function()
        local M, state, def = boot()
        local nine = { B = { "B" }, A = { "A" }, X = { "X" }, Y = { "Y" },
                       BA = { "B", "A" }, AX = { "A", "X" }, XY = { "X", "Y" }, YB = { "Y", "B" },
                       ALL = { "B", "A", "X", "Y" } }
        for id, btns in pairs(nine) do
            H.play(0.2, btns); H.play(0.1)
            H.eq(state.clean[id], 1, id .. " counted clean")
            H.eq(state.through[id], 0, id .. " not through another")
        end
        local total = 0
        for _, id in ipairs(def.ORDER) do total = total + state.clean[id] + state.through[id] end
        H.eq(total, 9, "nothing else counted (releases are not presses)")
        H.eq(#M.Looper.tracks[2].events, 0, "silent: nothing recorded")
    end },

    { "a pair that arrives one button at a time is counted as through another", function()
        local _, state = boot()
        H.hold("B"); H.play(1 / 60)
        H.hold("A"); H.play(0.2)
        H.eq(state.through.BA, 1, "the pair, through B")
        H.eq(state.clean.B, 0, "B itself never settled")
        H.eq(state.clean.BA, 0, "not clean")
        H.eq(state.last.id, "BA", "the last press")
        H.falsy(state.last.clean, "marked as through another")
        H.release("B", "A"); H.play(0.1)

        -- a roll from a settled button to its pair is one clean step
        H.hold("A"); H.play(0.2)
        H.hold("X"); H.play(0.2)
        H.eq(state.clean.A, 1, "A settled"); H.eq(state.clean.AX, 1, "then A+X, cleanly")
        H.release("A", "X"); H.play(0.1)

        -- three buttons and opposite pairs have their own count
        H.play(0.2, { "B", "X" }); H.play(0.1)
        H.eq(state.other, 1, "an opposite pair")
    end },

    { "the stage shows the fingering and the counts; L1 + R1 resets", function()
        local _, state, def = boot()
        H.hold("X", "Y"); H.play(0.2)
        local big, small, lines = def:getReadout(state)
        H.eq(big, "X+Y", "the fingering, large")
        H.eq(small, "LAST: X+Y  CLEAN", "how it settled")
        H.truthy(#lines <= require("src.ui.chrome").LAB_LINES, "the lines fit the view")
        H.truthy(table.concat(lines, "|"):find("X+Y  1 / 0", 1, true), "its count is on screen")
        H.release("X", "Y"); H.play(0.1)
        H.eq((def:getReadout(state)), "-", "nothing down")

        H.play(0.1, { "L1", "R1" }); H.play(0.05)
        H.eq(state.clean.XY, 0, "counts reset")
        H.eq(state.last, nil, "last press forgotten")
    end },

    { "a page taking the controls doesn't leave a half-counted press", function()
        local _, state = boot()
        H.hold("SELECT"); H.play(0.3)                -- the Track page: B there is an effect switch
        H.hold("B"); H.play(0.2)
        H.release("SELECT"); H.play(0.2)             -- back on the stage with B still down
        H.eq(state.clean.B + state.through.B, 0, "a press made on the page is not counted")
        H.release("B"); H.play(0.1)
        H.play(0.2, { "A" }); H.play(0.1)
        H.eq(state.clean.A, 1, "the next press is clean")
    end },
}
