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

    { "song recording: armed on S, starts at the loop, catches switches, mutes and notes", function()
        local M = boot()
        local L = M.Looper
        local Song = M.Song
        twoPatterns(M, { bpmB = L.bpm })
        Song:setOn(true); Song:goToPage()
        L:resetPlayhead()
        H.play(0.3)
        H.tap("L2")
        H.truthy(Song.armed, "armed")
        H.falsy(Song.recording, "not yet")
        H.play(L:getLoopDuration())
        H.truthy(Song.recording, "rolling from the loop start")
        H.eq(#Song.data.steps, 1, "step 1")
        H.eq(Song.data.steps[1].slot, "A", "on A")
        Song:toggleQueue("B")
        H.play(L:getLoopDuration())
        H.eq(#Song.data.steps, 2, "the switch made step 2")
        H.eq(Song.data.steps[2].slot, "B", "B")
        H.truthy(Song.data.steps[1].len > L:getLoopTicks() * 0.9, "step 1 lasted about a loop")
        -- a mute, then a note on drums from track 1's page
        H.hold("R2"); H.tap("A"); H.release("R2")
        H.play(60 / L.bpm * 4)
        local moves = Song.data.steps[2].moves
        H.eq(moves[#moves].kind, "mute", "mute written")
        H.eq(moves[#moves].slot, 2, "track 2")
        local before = #L.tracks[1].events
        H.tap("B")                                   -- face alone: go to track 1
        H.eq(L.activeTrack, 1, "on drums")
        H.tap("B")                                   -- a kick, no L2
        H.eq(#L.tracks[1].events, before, "not into the pattern")
        local takes = Song.data.steps[2].takes[1]
        H.truthy(takes and #takes == 1, "a take note in the song")
        H.tap("L2")
        H.falsy(Song.recording, "L2 anywhere stops it")
        H.truthy(H.files["song.txt"], "saved")
    end },

    { "START on S plays the song back: switches, mutes and take notes", function()
        local M = boot()
        local L = M.Looper
        local Song = M.Song
        twoPatterns(M, { bpmB = L.bpm })
        Song:setOn(true); Song:goToPage()
        L:resetPlayhead()
        H.tap("L2")
        H.play(L:getLoopDuration())
        Song:toggleQueue("B")
        H.play(L:getLoopDuration() + 60 / L.bpm)
        H.hold("R2"); H.tap("A"); H.release("R2")
        H.play(60 / L.bpm * 4)
        H.tap("B"); H.tap("Y")                       -- track 1, a snare as a take
        M.Song:goToPage()
        H.play(0.3)
        H.tap("L2")
        H.falsy(Song.recording, "stopped")
        -- somewhere else entirely
        M.Patterns.goTo("A")
        L.tracks[2].muted = false
        local hits = spy(M)
        H.tap("START")
        H.truthy(Song.playing, "playing")
        H.eq(M.Session.patternSlot, "A", "from A")
        H.play(Song.data.steps[1].len / L:getTicksPerSecond() + 0.1)
        H.eq(M.Session.patternSlot, "B", "then B, on time")
        H.play(60 / L.bpm * 6)
        H.truthy(L.tracks[2].muted, "the mute came back")
        local sawSnare = false
        for _, h in ipairs(hits) do if h.action == "Y" and h.slot == "B" then sawSnare = true end end
        H.truthy(sawSnare, "the take note played")
    end },

    { "rolling again keeps what you don't touch; a switch rewrites the rest", function()
        local M = boot()
        local L = M.Looper
        local Song = M.Song
        twoPatterns(M, { bpmB = L.bpm })
        M.Patterns.copyTo("C")
        Song:setOn(true); Song:goToPage()
        L:resetPlayhead()
        H.tap("L2")
        H.play(L:getLoopDuration())
        Song:toggleQueue("B")
        H.play(L:getLoopDuration() * 2)
        H.tap("L2")
        H.eq(#Song.data.steps, 2, "A, B")
        -- overdub from the top with a mute only
        H.tap("L2")
        H.truthy(Song.recording and Song.playing, "rolling over the song")
        H.play(0.5)
        H.hold("R2"); H.tap("X"); H.release("R2")
        H.play(60 / L.bpm * 4)
        H.tap("L2")
        H.eq(#Song.data.steps, 2, "still two steps")
        H.eq(Song.data.steps[2].slot, "B", "B kept")
        H.eq(Song.data.steps[1].moves[1].kind, "mute", "the new mute")
        -- overdub with a switch: the rest is rewritten
        H.tap("L2")
        H.play(0.5)
        Song:toggleQueue("C")
        H.play(L:getLoopDuration())
        H.tap("L2")
        H.eq(Song.data.steps[2].slot, "C", "C in place of B")
        H.eq(#Song.data.steps, 2, "nothing after")
        -- and undo takes the pass back
        H.hold("L2", "R2"); H.tap("LEFT"); H.release("L2", "R2"); H.play(0.05)
        H.eq(Song.data.steps[2].slot, "B", "undo: B again")
    end },

    { "song.txt keeps steps, moves and takes", function()
        local M = boot()
        local Song = M.Song
        Song.data = { steps = {
            { slot = "A", start = 0, len = 3840, mutes = { false, true, false, false },
              moves = { { at = 960, kind = "mute", slot = 2, muted = false }, { at = 1200, kind = "fade", gain = 0.5 },
                        { at = 1500, kind = "fx", s = false, h = true, d = false, c = false } },
              takes = { [1] = { { at = 480, tick = 0, len = 0, action = "B", vel = 0.8, degree = 1, octave = 0 } } } },
            { slot = "C", start = 0, len = 1920, mutes = { false, false, false, false }, moves = {}, takes = {} },
        } }
        H.truthy(Song:save(), "saved")
        Song.data = { steps = {} }
        H.truthy(Song:load(), "loaded")
        local st = Song.data.steps
        H.eq(#st, 2, "two steps")
        H.eq(st[1].mutes[2], true, "start mutes")
        H.eq(#st[1].moves, 3, "moves")
        H.eq(st[1].moves[2].gain, 0.5, "fade gain")
        H.eq(st[1].moves[3].h, true, "fx")
        H.eq(st[1].takes[1][1].at, 480, "take position")
        H.eq(st[2].slot, "C", "slot")
        H.files["song.txt"] = "garbage("
        H.falsy(Song:load(), "a broken file is ignored")
        H.eq(#Song.data.steps, 0, "empty song")
    end },

    { "the song stops at its end", function()
        local M = boot()
        local L = M.Looper
        local Song = M.Song
        Song:setOn(true); Song:goToPage()
        Song.data = { steps = { { slot = "A", start = 0, len = L:getLoopTicks(), mutes = { false, false, false, false }, moves = {}, takes = {} } } }
        Song:playFromTop()
        H.play(L:getLoopDuration() + 0.2)
        H.falsy(Song.playing, "done")
        H.falsy(L.playing, "clock stopped")
    end },

    { "recording draws on S and on a track page", function()
        local M = boot()
        local Chrome = require("src.ui.chrome")
        M.Song:setOn(true); M.Song:goToPage()
        H.tap("L2"); Chrome:draw()
        H.play(M.Looper:getLoopDuration())
        Chrome:draw()
        M.Song:leavePage(1); Chrome:draw()
    end },

    { "writing with the clock stopped: D-pad + B writes steps, L1 / R1 move, R2 + face sets a track out", function()
        local M = boot()
        local L = M.Looper
        local Song = M.Song
        twoPatterns(M, { bpmB = L.bpm })
        Song:setOn(true); Song:goToPage()
        L:setPlaying(false)
        H.truthy(Song:writing(), "writing")
        H.hold("UP"); H.play(0.05); H.tap("B"); H.release("UP"); H.play(0.05)
        H.eq(#Song.data.steps, 1, "step 1")
        H.eq(Song.data.steps[1].slot, "A", "A")
        H.eq(Song.cursor, 2, "cursor on")
        H.eq(Song.data.steps[1].len, L:getLoopTicks(), "a loop long")
        H.hold("UP", "RIGHT"); H.play(0.05); H.tap("B"); H.release("UP", "RIGHT"); H.play(0.05)
        H.eq(Song.data.steps[2].slot, "B", "step 2 = B")
        H.tap("L1"); H.tap("L1")
        H.eq(Song.cursor, 1, "back to step 1")
        H.hold("RIGHT"); H.play(0.05); H.tap("B"); H.release("RIGHT"); H.play(0.05)
        H.eq(Song.data.steps[1].slot, "C", "step 1 rewritten")
        H.eq(#Song.data.steps, 2, "still two")
        H.tap("L1")
        H.hold("R2"); H.tap("Y"); H.release("R2")
        H.eq(Song.data.steps[1].mutes[3], true, "track 3 out on step 1")
        H.falsy(L.tracks[3].muted, "the loop on screen untouched")
    end },

    { "the song's rows: loops, in / out, at the end, delete, clear", function()
        local M = boot()
        local L = M.Looper
        local Song = M.Song
        local Modes = require("src.modes")
        Song:setOn(true); Song:goToPage()
        Song.data = { steps = {
            { slot = "A", start = 0, len = L:getLoopTicks(), mutes = { false, false, false, false }, moves = {}, takes = {} },
            { slot = "A", start = 0, len = L:getLoopTicks(), mutes = { false, false, false, false }, moves = {}, takes = {} } } }
        Song.cursor = 1
        local function row(key)
            for i, r in ipairs(Song:rows()) do if r.key == key then return i end end
        end
        H.hold("SELECT"); H.play(0.3)
        H.eq(H.mode(), "TRACK", "track page")
        local function goRow(key)
            for _ = 1, 20 do
                if Modes.trackPage.row == row(key) then return end
                H.tap("DOWN")
            end
            error("no row " .. key)
        end
        goRow("LOOPS"); H.tap("RIGHT")
        H.eq(Song.data.steps[1].len, 2 * L:getLoopTicks(), "x 2")
        goRow("IN2"); H.tap("RIGHT")
        H.eq(Song.data.steps[1].mutes[2], true, "track 2 out")
        goRow("END"); H.tap("RIGHT")
        H.eq(Song.data.atEnd, "LOOP", "loops")
        goRow("DELETE"); H.tap("RIGHT")
        H.eq(#Song.data.steps, 2, "asks first")
        H.tap("RIGHT")
        H.eq(#Song.data.steps, 1, "deleted")
        goRow("CLEAR"); H.tap("RIGHT"); H.tap("RIGHT")
        H.eq(#Song.data.steps, 0, "cleared")
        H.release("SELECT"); H.play(0.1)
        H.hold("L2", "R2"); H.tap("LEFT"); H.release("L2", "R2"); H.play(0.05)
        H.eq(#Song.data.steps, 1, "undo brings it back")
    end },

    { "at the end: LOOP plays the song again from step 1", function()
        local M = boot()
        local L = M.Looper
        local Song = M.Song
        Song:setOn(true)
        Song.data = { atEnd = "LOOP", steps = { { slot = "A", start = 0, len = L:getLoopTicks(), mutes = { false, false, false, false }, moves = {}, takes = {} } } }
        Song:playFromTop()
        H.play(L:getLoopDuration() + 0.2)
        H.truthy(Song.playing, "still playing")
        H.eq(Song.stepIdx, 1, "step 1 again")
        H.truthy(L.playing, "clock running")
    end },

    { "the writing grid and the song rows draw", function()
        local M = boot()
        local Chrome = require("src.ui.chrome")
        M.Song:setOn(true); M.Song:goToPage()
        M.Looper:setPlaying(false)
        Chrome:draw()
        H.hold("UP"); H.play(0.05); H.tap("B"); H.release("UP"); H.play(0.05)
        Chrome:draw()
        H.hold("SELECT"); H.play(0.3); Chrome:draw()
        H.release("SELECT"); H.play(0.1)
    end },
}
