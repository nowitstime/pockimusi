-- Song mode (PHASE_M): switching patterns while the clock runs
local H = require("helpers")

local function boot()
    local M = H.loadMain()
    M.Patterns = require("src.patterns")
    M.Song = require("src.song")
    H.play(0.05)
    return M
end

local function ev(tick, action)
    return { tick = tick, len = 0, action = action, vel = 0.8, degree = 1, octave = 0 }
end

local function clearAll(L)
    for i = 1, 4 do L.tracks[i].events = {} end
end

-- Pattern A: kicks (B) on tick 0 and late in the loop; pattern B: a clap (X)
-- on tick 0 at another tempo. Leaves A on screen.
local function twoPatterns(M, opts)
    opts = opts or {}
    local L = M.Looper
    local loop = L:getLoopTicks()
    clearAll(L)
    L.tracks[1].events = { ev(0, "B"), ev(loop - 120, "B") }
    M.Patterns.save("A")
    clearAll(L)
    L.bpm = opts.bpmB or 100
    if opts.barsB then L.bars = opts.barsB end
    L.tracks[1].events = { ev(0, "X") }
    M.Patterns.save("B")
    H.truthy(M.Patterns.goTo("A"), "back on A")
    return loop
end

-- Every note the looper plays on track 1: { action, slot, pass }
local function spy(M)
    local L = M.Looper
    local hits = {}
    local orig = L.noteHandler
    L:setNoteHandler(function(kind, e, track)
        if kind == "on" and track.slot == 1 then
            hits[#hits + 1] = { action = e.action, slot = M.Session.patternSlot, tick = e.tick }
        end
        orig(kind, e, track)
    end)
    return hits
end

local function actions(hits)
    local out = {}
    for i, h in ipairs(hits) do out[i] = h.action .. "@" .. h.slot end
    return table.concat(out, " ")
end

return {
    { "a queued pattern switches in exactly at the loop end", function()
        local M = boot()
        local L = M.Looper
        twoPatterns(M)
        local bpmA = L.bpm
        local hits = spy(M)
        L:resetPlayhead()
        H.truthy(M.Song:toggleQueue("B"), "queued")
        H.play(L:getLoopDuration() + 0.2)
        H.eq(actions(hits), "B@A B@A X@B", "the end of A, then B's first hit")
        H.eq(M.Session.patternSlot, "B", "on B")
        H.eq(L.bpm, 100, "B's tempo")
        H.truthy(bpmA ~= 100, "A had another tempo")
        H.eq(M.Song.switches, 1, "one switch")
        H.eq(#M.Song.queue, 0, "queue used up")
    end },

    { "several queued patterns play in order", function()
        local M = boot()
        local L = M.Looper
        twoPatterns(M, { bpmB = L.bpm })
        M.Patterns.copyTo("C")
        L:resetPlayhead()
        M.Song:toggleQueue("B")
        M.Song:toggleQueue("C")
        H.eq(M.Song:nextSlot(), "B", "B first")
        H.play(L:getLoopDuration() + 0.1)
        H.eq(M.Session.patternSlot, "B", "then B")
        H.play(L:getLoopDuration())
        H.eq(M.Session.patternSlot, "C", "then C")
    end },

    { "queueing a queued pattern takes it out", function()
        local M = boot()
        twoPatterns(M)
        H.truthy(M.Song:toggleQueue("B"), "in")
        H.eq(M.Song:toggleQueue("B"), false, "out")
        H.eq(#M.Song.queue, 0, "empty")
        H.play(M.Looper:getLoopDuration() + 0.2)
        H.eq(M.Session.patternSlot, "A", "still A")
    end },

    { "a cut switches on the next beat and keeps the place in the bar", function()
        local M = boot()
        local L = M.Looper
        twoPatterns(M, { bpmB = L.bpm })
        L:resetPlayhead()
        H.play(60 / L.bpm * 1.5)                    -- halfway through beat 2
        H.eq(M.Session.patternSlot, "A", "A so far")
        M.Song:cut("B")
        H.play(60 / L.bpm * 0.25)
        H.eq(M.Session.patternSlot, "A", "not before the beat")
        H.play(60 / L.bpm * 0.4)
        H.eq(M.Session.patternSlot, "B", "switched on the beat")
        H.truthy(L.tick >= L.PPQN * 2 and L.tick < L.PPQN * 2.5, "carries on from beat 3")
    end },

    { "a longer pattern brings its own loop length", function()
        local M = boot()
        local L = M.Looper
        H.eq(L.bars, 2, "A is 2 bars")
        twoPatterns(M, { barsB = 4 })
        L:resetPlayhead()
        M.Song:toggleQueue("B")
        H.play(L:getLoopDuration() + 0.1)
        H.eq(L.bars, 4, "B is 4 bars")
        H.eq(L.pass, 0, "B starts from its first pass")
    end },

    { "notes recorded before the switch stay in the pattern left behind", function()
        local M = boot()
        local L = M.Looper
        twoPatterns(M)
        L:resetPlayhead()
        M.Song:toggleQueue("B")
        H.tap("L2"); H.tap("Y"); H.tap("L2")
        local n = #L.tracks[1].events
        H.play(L:getLoopDuration() + 0.2)
        H.eq(M.Session.patternSlot, "B", "on B")
        M.Patterns.goTo("A")
        H.eq(#L.tracks[1].events, n, "A kept the new note")
    end },

    { "an empty slot in the queue becomes a new pattern with the same setup", function()
        local M = boot()
        local L = M.Looper
        twoPatterns(M)
        local inst = L.tracks[2].instrumentId
        L:resetPlayhead()
        M.Song:toggleQueue("E")
        H.play(L:getLoopDuration() + 0.2)
        H.eq(M.Session.patternSlot, "E", "on E")
        H.eq(#L.tracks[1].events, 0, "no notes")
        H.eq(L.tracks[2].instrumentId, inst, "same instruments")
    end },

    { "after a switch each note plays once per loop", function()
        local M = boot()
        local L = M.Looper
        twoPatterns(M)
        local hits = spy(M)
        L:resetPlayhead()
        M.Song:toggleQueue("B")
        H.play(L:getLoopDuration() + 0.1)
        local before = #hits
        H.play(L:getLoopDuration())
        H.eq(#hits - before, 1, "one clap in B's next loop")
    end },
}
