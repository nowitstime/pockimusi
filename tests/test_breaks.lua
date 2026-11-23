-- Breaks (PHASE_L L8): the break library, playing in time, jumps, stutter,
-- reverse, choke, half / double time, the snare roll, recording moves and
-- replaying them on another break or kit.
local H = require("helpers")

-- Track 1 swapped to Breaks and active; every sound triggered is logged
local function boot(breakId)
    local M = H.loadMain()
    H.play(0.1)
    M.Instruments:swapTrackInstrument(1, "breaks")
    M.Looper.undoStack = {}
    M.Looper.activeTrack = 1
    local st = M.Looper.tracks[1].state
    st.breakId = breakId or "two_step"
    local log = {}
    local orig = M.Synth.trigger
    M.Synth.trigger = function(self, sound, semis, vol, ...)
        log[#log + 1] = { sound = sound, tick = M.Looper.tick, vol = vol, semis = semis }
        return orig(self, sound, semis, vol, ...)
    end
    return M, M.Looper, st, log
end

local function seekTick(L, tick)
    L:seek(tick / L:getLoopTicks()); L.lastClockTime = H.time
end

local function sounds(log, from)
    local out = {}
    for i = from or 1, #log do out[#out + 1] = log[i].sound end
    return out
end

local function count(log, sound)
    local n = 0
    for _, e in ipairs(log) do if e.sound == sound then n = n + 1 end end
    return n
end

local function frames(seconds) H.play(seconds) end

return {
    -- ------------------------------------------------------------------
    -- The library
    -- ------------------------------------------------------------------
    { "every break is whole bars of 1/16 steps; every kit's sounds exist", function()
        local M = H.loadMain()
        local B = require("src.breaks")
        local f = assert(io.open("pocketgroove/src/breaks.lua", "r"))
        f:close()
        for _, brk in ipairs(B.LIST) do
            H.truthy(#brk.hits > 0, brk.id .. " has hits")
            for _, h in ipairs(brk.hits) do
                H.truthy(h.step >= 0 and h.step < brk.bars * 16, brk.id .. " step " .. h.step .. " inside")
                H.truthy(h.vel > 0 and h.vel <= 1, brk.id .. " velocity")
            end
            H.truthy(B.kitByName[brk.kit], brk.id .. "'s own kit exists")
        end
        local ids = {}
        for _, item in ipairs(M.Synth.drumCatalog) do ids[item.id] = true end
        for _, kit in ipairs(B.KITS) do
            for _, role in ipairs(B.ROLES) do
                local sound = B.roleSound(kit, role)
                H.truthy(ids[sound], kit.name .. " " .. role .. ": " .. tostring(sound))
            end
        end
        H.truthy(B.byId.amen and B.byId.think and B.byId.apache and B.byId.funky_drummer, "the famous ones")
    end },

    { "every line of a break has the same length (the source text)", function()
        local f = assert(io.open("pocketgroove/src/breaks.lua", "r"))
        local text = f:read("*a")
        f:close()
        for body in text:gmatch("hits = grid%((%b{})%)") do
            local len
            for line in body:gmatch('"([^"]+)"') do
                local n = 0
                for ch in line:gmatch("%S") do if ch ~= "|" then n = n + 1 end end
                if len then H.eq(n, len, "a line of the same break: " .. line) end
                len = len or n
                H.eq(n % 16, 0, "whole bars: " .. line)
            end
        end
    end },

    { "Breaks is in the RHYTHM group, with BREAK and KIT rows and no PUMP", function()
        local M, L, st = boot()
        local def = M.Instruments.byId.breaks
        H.eq(def.group, "RHYTHM", "group")
        local rows = M.Instruments:getSoundRows(def, st, L.tracks[1])
        H.eq(rows[1].key .. " " .. rows[2].key, "BREAK KIT", "rows")
        for _, r in ipairs(rows) do H.truthy(r.key ~= "PUMP", "no PUMP row") end
        H.eq(rows[2].value, "FUNK BREAKS", "the break's own kit")
        def:cycleSetting(st, "BREAK", 1)
        H.eq(st.breakId, "amen", "BREAK steps")
        def:cycleSetting(st, "KIT", 1)
        H.eq(def:kitName(st), "JUNGLE", "KIT steps")
    end },

    -- ------------------------------------------------------------------
    -- Playing
    -- ------------------------------------------------------------------
    { "holding B plays the break in time with the clock; letting go stops it", function()
        local M, L, st, log = boot("two_step")
        seekTick(L, 0)
        H.hold("B")
        frames(H.loopSeconds(L) * 0.5)                   -- one bar of a one-bar break
        H.release("B"); frames(0.05)
        local kicks, snares = {}, {}
        for _, e in ipairs(log) do
            if e.sound == "kick_funk" then kicks[#kicks + 1] = e.tick end
            if e.sound == "snare_funk" and e.vol > 0.7 then snares[#snares + 1] = e.tick end
        end
        H.truthy(#kicks >= 2, "kicks: " .. #kicks)
        H.truthy(kicks[1] < 30, "the first kick right at the press: " .. kicks[1])
        H.truthy(math.abs(kicks[2] - 1200) < 40, "the second on the and of 3: " .. tostring(kicks[2]))
        H.truthy(math.abs(snares[1] - 480) < 40, "snare on 2: " .. tostring(snares[1]))
        local n = #log
        frames(0.5)
        H.eq(#log, n, "silent once let go")
    end },

    { "a press mid-bar comes in in time, not from the start of the break", function()
        local M, L, st, log = boot("two_step")
        seekTick(L, 470)                                  -- just before beat 2
        H.hold("B"); frames(0.1); H.release("B"); frames(0.05)
        H.eq(count(log, "kick_funk"), 0, "no kick (beat 1 is past)")
        H.truthy(count(log, "snare_funk") >= 1, "the snare on 2")
    end },

    { "a D-pad direction picks the slice a press starts from", function()
        local M, L, st, log = boot("amen")
        seekTick(L, 100)
        H.hold("RIGHT"); frames(1 / 60)
        H.hold("B"); frames(1 / 60)
        H.release("B", "RIGHT"); frames(0.05)
        local first = log[1]
        -- slice 3 of 8 in a two-bar break is beat 3 of bar 1: ride and kick-less
        H.truthy(first, "something played")
        local brk = require("src.breaks").byId.amen
        H.eq(M.Instruments.byId.breaks:startPos(st, L.tracks[1], { slice = 3 }, 0), 2 * brk.ticks / 8, "slice 3 position")
    end },

    { "moving the D-pad while playing jumps at the next 1/8 line", function()
        local M, L, st, log = boot("amen")
        seekTick(L, 10)
        H.hold("B"); frames(0.05)
        seekTick(L, 130); frames(1 / 60)
        H.hold("DOWN"); frames(1 / 60)
        H.eq(st.pendingSlice, 5, "waiting for the line")
        while L.tick < 240 + 10 do frames(1 / 60) end
        H.eq(st.pendingSlice, nil, "jumped")
        local def = M.Instruments.byId.breaks
        local live = st.segs[st.seg.ev]
        H.eq(st.seg.ev.slice, 5, "from slice 5")
        H.truthy(live.pos >= 4 * 3840 / 8 and live.pos < 4 * 3840 / 8 + 120, "the break is at slice 5: " .. live.pos)
        H.release("B", "DOWN"); frames(0.05)
    end },

    { "A stutters: the same chunk again and again", function()
        local M, L, st, log = boot("two_step")
        seekTick(L, 0)
        H.hold("A"); frames(H.loopSeconds(L) * 0.25); H.release("A"); frames(0.05)
        -- a 1/16 chunk from the kick: only kicks, every 1/16
        H.truthy(count(log, "kick_funk") >= 6, "the kick repeats: " .. count(log, "kick_funk"))
        H.eq(count(log, "snare_funk"), 0, "never reaches the snare")
    end },

    { "Y plays backwards", function()
        local M, L, st, log = boot("two_step")
        seekTick(L, 490)                                   -- just after the snare on 2
        H.hold("Y"); frames(0.7); H.release("Y"); frames(0.05)
        local s = sounds(log)
        H.truthy(#s >= 2, "hits")
        -- from just past beat 2 backwards: the snare first, then the hats before it, then the kick
        H.eq(s[1], "snare_funk", "the snare first")
        local sawKick = false
        for _, x in ipairs(s) do if x == "kick_funk" then sawKick = true end end
        H.truthy(sawKick, "back to the kick on 1")
    end },

    { "X chokes: silence while held, the break keeps time", function()
        local M, L, st, log = boot("two_step")
        seekTick(L, 0)
        H.hold("B"); frames(0.05)
        H.hold("X"); frames(0.3)
        local n = #log
        frames(0.2)
        H.eq(#log, n, "silent while X is held")
        H.release("X"); frames(0.05)
        H.truthy(st.seg and st.seg.ev.sync, "back in time with the clock")
        H.release("B"); frames(0.05)
    end },

    { "R1 doubles and L1 halves the speed", function()
        local function hitsIn(btns)
            local M, L, st, log = boot("two_step")
            seekTick(L, 0)
            H.hold("B", unpack(btns)); frames(H.loopSeconds(L) * 0.25); H.release("B", unpack(btns))
            frames(0.05)
            return #log
        end
        local normal, double, half = hitsIn({}), hitsIn({ "R1" }), hitsIn({ "L1" })
        H.truthy(double > normal * 1.6, "double: " .. double .. " vs " .. normal)
        H.truthy(half < normal * 0.7, "half: " .. half .. " vs " .. normal)
    end },

    { "both shoulders: a snare roll that gets faster and louder into the bar line", function()
        local M, L, st, log = boot("two_step")
        seekTick(L, 0)
        H.hold("L1", "R1"); frames(1 / 60)
        H.hold("B")
        while L.tick < 1900 do frames(1 / 60) end
        H.release("B", "L1", "R1"); frames(0.05)
        local t = {}
        for _, e in ipairs(log) do
            H.eq(e.sound, "snare_funk", "only snares")
            t[#t + 1] = e
        end
        H.truthy(#t >= 12, "many hits: " .. #t)
        local early, late = t[3].tick - t[2].tick, t[#t].tick - t[#t - 1].tick
        H.truthy(late < early, "faster at the end: " .. early .. " then " .. late)
        H.truthy(t[#t].vol > t[2].vol, "louder at the end")
    end },

    -- ------------------------------------------------------------------
    -- Recording
    -- ------------------------------------------------------------------
    { "recording keeps the moves, which play back", function()
        local M, L, st, log = boot("two_step")
        H.tap("L2")
        seekTick(L, 0)
        H.hold("B"); frames(H.loopSeconds(L) * 0.5); H.release("B"); frames(0.05)
        H.tap("L2")
        local evs = L.tracks[1].events
        H.eq(#evs, 1, "one stretch")
        H.eq(evs[1].action, "B", "under B")
        H.truthy(evs[1].sync, "in time with the clock")
        H.truthy(evs[1].len > 1800, "about a bar long: " .. evs[1].len)
        for i = #log, 1, -1 do log[i] = nil end
        seekTick(L, L:getLoopTicks() - 30)
        frames(H.loopSeconds(L) * 0.5)
        H.truthy(count(log, "kick_funk") >= 2 and count(log, "snare_funk") >= 2, "plays back: " .. #log)
    end },

    { "a recorded performance replays on another break and kit", function()
        local M, L, st, log = boot("two_step")
        H.tap("L2")
        seekTick(L, 0)
        H.hold("B"); frames(H.loopSeconds(L) * 0.5); H.release("B"); frames(0.05)
        H.tap("L2")
        st.breakId = "apache"
        for i = #log, 1, -1 do log[i] = nil end
        seekTick(L, L:getLoopTicks() - 30)
        frames(H.loopSeconds(L) * 0.5)
        H.truthy(count(log, "bongo_high") + count(log, "bongo_low") > 0 or count(log, "perc_tamb") > 0,
            "Apache's bongos now")
    end },

    { "BREAK and KIT are saved and loaded", function()
        local M, L, st = boot("think")
        st.kit = "JUNGLE"
        local snap = M.Session.snapshot()
        st.breakId, st.kit = "amen", nil
        H.truthy(M.Session.restore(snap), "restored")
        local st2 = L.tracks[1].state
        H.eq(st2.breakId, "think", "break back")
        H.eq(st2.kit, "JUNGLE", "kit back")
        snap.tracks[1].settings = { breakId = "nope", kit = 7 }
        M.Session.restore(snap)
        H.eq(L.tracks[1].state.breakId, "two_step", "a bad break: the default")
    end },

    { "other tracks pump with the break's kicks", function()
        local M, L, st = boot("two_step")
        L.tracks[3].pump = 4
        seekTick(L, 0)
        H.hold("B"); H.play(1 / 60)
        H.truthy(M.Synth.pumpNow[3] < 0.5, "ducked by the break's kick: " .. M.Synth.pumpNow[3])
        H.release("B"); H.play(0.05)
    end },
}
