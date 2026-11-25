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

    { "song mode adds S to the SELECT cycle", function()
        local M = boot()
        local L = M.Looper
        L.activeTrack = 4
        H.tap("SELECT")
        H.truthy(L.tracks[L.activeTrack].isLane, "C")
        H.tap("SELECT")
        H.eq(L.activeTrack, 1, "without song mode, back to 1")
        M.Song:setOn(true)
        L.activeTrack = 4
        H.tap("SELECT"); H.tap("SELECT")
        H.truthy(M.Song.page, "S after C")
        H.tap("SELECT")
        H.falsy(M.Song.page, "S -> 1")
        H.eq(L.activeTrack, 1, "track 1")
    end },

    { "a quick SELECT + START tap goes to S (song mode only)", function()
        local M = boot()
        H.hold("SELECT", "START"); H.play(0.15); H.release("SELECT", "START"); H.play(0.1)
        H.falsy(M.Song.page, "off: nothing")
        M.Song:setOn(true)
        H.hold("SELECT", "START"); H.play(0.15); H.release("SELECT", "START"); H.play(0.1)
        H.truthy(M.Song.page, "on: S")
        H.falsy(require("src.menu"):isActive(), "no menu")
    end },

    { "on S a face button goes to its track and plays nothing", function()
        local M = boot()
        local L = M.Looper
        M.Song:setOn(true); M.Song:goToPage()
        H.tap("L2"); H.tap("Y"); H.tap("L2")
        H.falsy(M.Song.page, "left S")
        H.eq(L.activeTrack, 3, "Y = track 3")
        local n = 0
        for t = 1, 4 do n = n + #L.tracks[t].events end
        H.eq(n, 0, "no note recorded")
    end },

    { "on S, D-pad + B queues and unqueues, A cuts", function()
        local M = boot()
        twoPatterns(M, { bpmB = M.Looper.bpm })
        M.Song:setOn(true); M.Song:goToPage()
        H.hold("RIGHT"); H.play(0.05)
        H.eq(M.Song.pointing, "C", "RIGHT points at C")
        H.release("RIGHT")
        H.hold("UP", "RIGHT"); H.play(0.05)
        H.eq(M.Song.pointing, "B", "UP + RIGHT points at B")
        H.tap("B")
        H.truthy(M.Song:isQueued("B"), "queued")
        H.tap("B")
        H.falsy(M.Song:isQueued("B"), "taken out")
        H.tap("A")
        H.eq(M.Song.cutTo and M.Song.cutTo.slot, "B", "cut waiting")
        H.release("UP", "RIGHT")
        H.truthy(M.Song.page, "still on S")
    end },

    { "on S, D-pad + Y copies here (asking over a full slot), held X clears", function()
        local M = boot()
        M.Song:setOn(true); M.Song:goToPage()
        H.hold("DOWN"); H.play(0.05)
        H.tap("Y")
        H.truthy(H.files["pattern_e.txt"], "copied into empty E")
        local first = H.files["pattern_e.txt"]
        H.tap("L2"); H.release("DOWN"); H.play(0.05)
        H.hold("DOWN"); H.play(0.05)
        H.tap("Y")
        H.eq(M.Song.copyConfirm, "E", "asks over a full slot")
        H.play(1.0, { "X" })
        H.falsy(H.files["pattern_e.txt"], "held X cleared E")
        H.release("DOWN")
    end },

    { "in song mode a mute lands on the next bar", function()
        local M = boot()
        local L = M.Looper
        M.Song:setOn(true)
        L:resetPlayhead()
        H.play(0.3)
        H.hold("R2"); H.tap("B"); H.release("R2"); H.play(0.02)
        H.falsy(L.tracks[1].muted, "not yet")
        H.eq(M.Song.pendingMutes[1], true, "waiting")
        H.play(60 / L.bpm * 4)
        H.truthy(L.tracks[1].muted, "muted on the bar")
    end },

    { "fades: L1 / R1 on S, R2 + L1 / R1 anywhere", function()
        local M = boot()
        M.Song:setOn(true); M.Song:goToPage()
        H.play(1.0, { "L1" })
        local g = M.Synth.fadeGain
        H.truthy(g < 1.0, "fading out")
        H.play(1.0, { "R1" })
        H.truthy(M.Synth.fadeGain > g, "back in")
        M.Song:leavePage(1)
        H.hold("R2"); H.play(1.0, { "L1" }); H.release("R2")
        H.truthy(M.Synth.fadeGain < 1.0, "from a track page")
        M.Song:setOn(false)
        H.eq(M.Synth.fadeGain, 1.0, "song mode off: full volume")
    end },

    { "song mode is saved with the session", function()
        local M = boot()
        M.Song:setOn(true)
        local snap = M.Session.snapshot()
        H.eq(snap.songMode, true, "in the snapshot")
        M.Song:setOn(false)
        M.Session.restore(snap)
        H.truthy(M.Song:isOn(), "back on")
    end },

    { "the S page draws, also while pointing", function()
        local M = boot()
        local Chrome = require("src.ui.chrome")
        twoPatterns(M)
        M.Song:setOn(true); M.Song:goToPage()
        M.Song:toggleQueue("B")
        Chrome:draw()
        H.hold("UP", "RIGHT"); H.play(0.05); Chrome:draw()
        H.hold("RIGHT"); H.release("UP"); H.play(0.05); Chrome:draw()
        H.release("RIGHT")
    end },

    { "the song strip: the pattern playing is widened around a fixed NOW line", function()
        local M = boot()
        local L = M.Looper
        twoPatterns(M, { bpmB = L.bpm })
        M.Song:setOn(true)
        L:resetPlayhead()
        H.play(60 / L.bpm * 4)                       -- one bar in
        M.Song:toggleQueue("B")
        local lay = M.Song:stripLayout(148, 456)
        H.eq(lay.now, 148 + M.Song.STRIP_NOW, "NOW line")
        local now, nxt
        for _, b in ipairs(lay.blocks) do
            if b.kind == "now" then now = b elseif b.kind == "next" then nxt = b end
        end
        local zp = M.Song.STRIP_PPB * M.Song.STRIP_ZOOM
        H.eq(now.slot, "A", "A playing")
        H.near(now.w, L.bars * zp, "widened", 1e-6)
        H.near(lay.now - now.x, (L.tick / L.BAR_TICKS) * zp, "NOW line where the playhead is", 1e-6)
        H.eq(nxt.slot, "B", "B next")
        H.near(nxt.x, now.x + now.w, "right after", 1e-6)
    end },

    { "the song strip shows the playing pattern's chords bar by bar, the sounding one lit", function()
        local M = boot()
        local L = M.Looper
        M.Song:setOn(true)
        H.popChords(M)                               -- C G Am F, half a bar each
        L:resetPlayhead()
        H.play(60 / L.bpm * 5)                       -- into bar 2
        local lay = M.Song:stripLayout(148, 456)
        local now
        for _, b in ipairs(lay.blocks) do if b.kind == "now" then now = b end end
        H.eq(#now.chords, 2, "one box per bar (the chord on its downbeat)")
        H.eq(now.chords[1].name, "C", "bar 1 starts on C")
        H.eq(now.chords[2].name, "A" .. "m", "bar 2 starts on Am")
        H.truthy(now.chords[2].lit and not now.chords[1].lit, "bar 2 lit")
    end },

    { "after a switch the pattern left behind shows before the NOW line", function()
        local M = boot()
        local L = M.Looper
        twoPatterns(M, { bpmB = L.bpm })
        M.Song:setOn(true)
        L:resetPlayhead()
        M.Song:toggleQueue("B")
        H.play(L:getLoopDuration() + 0.1)
        local lay = M.Song:stripLayout(148, 456)
        H.eq(lay.blocks[1].kind, "past", "past first")
        H.eq(lay.blocks[1].slot, "A", "A before")
        H.eq(lay.blocks[2].slot, "B", "B playing")
    end },

    { "slot summaries carry the chord names", function()
        local M = boot()
        H.popChords(M)
        M.Patterns.copyTo("C")
        local sum = M.Patterns.summary("C")
        H.eq(table.concat(sum.chordNames, " "), "C G Am F", "names in order")
    end },

    { "the strip and a waiting mute draw on every page", function()
        local M = boot()
        local Chrome = require("src.ui.chrome")
        H.popChords(M)
        M.Song:setOn(true)
        M.Patterns.copyTo("B")
        M.Song:toggleQueue("B")
        H.hold("R2"); H.tap("A"); H.release("R2")
        Chrome:draw()
        M.Song:goToPage(); Chrome:draw()
    end },
}
