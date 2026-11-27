-- Drums (pass 1 behaviour, and Phase H): flam, ratchet, choke; VARIATION on
-- playback (level jitter, late hits, fills); chance on ghost hits; per-pad
-- tune and level.
local H = require("helpers")

local function boot()
    local M = H.loadMain()
    M.Drums = M.Instruments:getDefinition("drums")
    H.play(0.1)
    return M, M.Looper, M.Looper.tracks[1].state
end

local function seekTick(L, tick)
    L:seek(tick / L:getLoopTicks()); L.lastClockTime = H.time
end

-- Every drum trigger from now on: { name, semis, vol, time, tick }
local function watch(M, L)
    local hits = {}
    local orig = M.Synth.trigger
    M.Synth.trigger = function(self, name, semis, vol, ...)
        hits[#hits + 1] = { name = name, semis = semis, vol = vol, time = H.time, tick = L.tick }
        return orig(self, name, semis, vol, ...)
    end
    return hits
end

local function hit(tick, action, soundId, extra)
    local ev = { tick = tick, len = 0, action = action, soundId = soundId, vel = 0.85, decay = 1.0, grid = 120 }
    for k, v in pairs(extra or {}) do ev[k] = v end
    return ev
end

-- Play one pass of the loop (every step exactly once), from just after its start
local function onePass(L)
    seekTick(L, 3836)
    H.play(L:getLoopDuration() - 0.02)
end

-- Random values from a list, repeating
local function sequence(M, values)
    local i = 0
    M.Drums.random = function()
        i = i + 1
        return values[((i - 1) % #values) + 1]
    end
end

local function named(hits, name)
    local out = {}
    for _, h in ipairs(hits) do if h.name == name then out[#out + 1] = h end end
    return out
end

return {
    -- ------------------------------------------------------------------
    -- H1: pass 1 still behaves
    -- ------------------------------------------------------------------
    { "a live flam plays a quiet grace note, then the hit 28 ms later", function()
        local M, L = boot()
        local hits = watch(M, L)
        H.hold("LEFT"); H.play(0.05); H.tap("B"); H.release("LEFT"); H.play(0.1)
        local k = named(hits, "kick_808")
        H.eq(#k, 2, "grace + hit")
        H.near(k[1].vol, 0.85 * 0.45, "grace is quiet", 1e-9)
        H.near(k[2].vol, 0.85, "then the hit", 1e-9)
        H.near(k[2].time - k[1].time, 0.028, "28 ms apart (frame resolution)", 0.02)
    end },

    { "a recorded flam plays its grace note before the beat and the hit on it", function()
        local M, L = boot()
        L.tracks[1].events = { hit(960, "B", "kick_808", { orn = "flam" }) }
        local hits = watch(M, L)
        onePass(L)
        local k = named(hits, "kick_808")
        H.eq(#k, 2, "grace + hit")
        H.truthy(k[1].vol < k[2].vol, "grace first")
        H.truthy(k[1].tick < 960 and k[1].tick > 900, "grace just before the beat (" .. k[1].tick .. ")")
        H.near(k[2].tick, 960, "hit on the beat", 18)
    end },

    { "a ratchet plays three falling hits inside one 1/16", function()
        local M, L = boot()
        local hits = watch(M, L)
        H.hold("RIGHT"); H.play(0.05); H.tap("B"); H.release("RIGHT"); H.play(0.2)
        local k = named(hits, "kick_808")
        H.eq(#k, 3, "three hits")
        H.truthy(k[1].vol > k[2].vol and k[2].vol > k[3].vol, "falling")
        H.truthy(k[3].time - k[1].time < 60 / L.bpm / 4, "inside one 1/16")
    end },

    { "a closed hat cuts a ringing open hat", function()
        local M = H.fresh({ realSynth = true })
        local S = M.Synth
        S:init()
        local open = S:trigger("hat_open", 0, 0.8)
        local life = open.maxLife
        S:update(0.05)
        S:trigger("hat_closed", 0, 0.8)
        H.truthy(open.maxLife < life and open.maxLife <= open.elapsed + 0.03 + 1e-9, "choked")
        local kick = S:trigger("kick_808", 0, 0.8)
        S:trigger("hat_closed", 0, 0.8)
        H.near(kick.maxLife, S.pools.kick_808.baseDuration, "other sounds ring on", 1e-9)
    end },

    -- ------------------------------------------------------------------
    -- H2: variation
    -- ------------------------------------------------------------------
    { "VARIATION OFF plays every pass exactly as recorded", function()
        local M, L, st = boot()
        L.tracks[1].events = { hit(0, "B", "kick_808"), hit(600, "A", "hat_closed"), hit(960, "Y", "snare_analog", { chance = 0.5 }) }
        sequence(M, { 0.99 })
        local hits = watch(M, L)
        onePass(L); onePass(L)
        H.eq(#hits, 6, "three hits, twice (chance ignored)")
        for _, h in ipairs(hits) do H.near(h.vol, 0.85, "recorded level", 1e-9) end
    end },

    { "LIGHT moves each hit's level by up to 12 %, and nothing else", function()
        local M, L, st = boot()
        L.tracks[1].events = { hit(0, "B", "kick_808"), hit(600, "A", "hat_closed"), hit(960, "Y", "snare_analog") }
        st.variation = "LIGHT"
        sequence(M, { 0.0, 1.0, 0.5 })
        local hits = watch(M, L)
        local scheduled = 0
        local orig = M.Synth.schedule
        M.Synth.schedule = function(...) scheduled = scheduled + 1; return orig(...) end
        onePass(L)
        H.eq(#hits, 3, "the same three hits, no fills")
        H.near(hits[1].vol, 0.85 * 0.88, "down 12 %", 1e-9)
        H.near(hits[2].vol, 0.85 * 1.12, "up 12 %", 1e-9)
        H.near(hits[3].vol, 0.85, "unchanged", 1e-9)
        H.eq(scheduled, 0, "no hit is delayed")
        H.eq(L.tracks[1].events[1].vel, 0.85, "the recording isn't touched")
        H.eq(#L.tracks[1].events, 3, "no events added")
    end },

    { "WILD drags some off-beat hits late by at most 14 ms; hits on a beat stay", function()
        local M, L, st = boot()
        L.tracks[1].events = { hit(0, "B", "kick_808"), hit(240, "A", "hat_closed"), hit(600, "A", "hat_closed"),
                               hit(960, "Y", "snare_analog") }
        st.variation = "WILD"
        sequence(M, { 0.3 })                       -- under the late chance, over the fill chance
        local delays = {}
        local orig = M.Synth.schedule
        M.Synth.schedule = function(self, delay, fn) delays[#delays + 1] = delay; return orig(self, delay, fn) end
        local hits = watch(M, L)
        onePass(L)
        H.eq(#delays, 2, "the two off-beat hats")
        for _, d in ipairs(delays) do H.truthy(d > 0 and d <= M.Drums.LATE_MAX, "late by " .. d) end
        H.eq(#hits, 4, "all four still play")
        for _, h in ipairs(hits) do
            H.truthy(h.vol >= 0.85 * 0.78 - 1e-9 and h.vol <= 0.85 * 1.22 + 1e-9, "level within 22 %")
        end
    end },

    { "WILD fills: ghost hits on empty steps of each bar's last beat, on used pads but never a kick", function()
        local M, L, st = boot()
        L.tracks[1].events = { hit(0, "B", "kick_808"), hit(1680, "A", "hat_closed") }   -- step 14
        st.variation = "WILD"
        sequence(M, { 0.1 })                       -- under the fill chance
        local hits = watch(M, L)
        onePass(L)
        local fills = {}
        for _, h in ipairs(hits) do
            if math.abs(h.vol - (0.28 + 0.1 * 0.17)) < 1e-9 then fills[#fills + 1] = h end
        end
        H.eq(#fills, 7, "steps 12, 13, 15 and 28-31 (14 is taken)")
        for _, f in ipairs(fills) do
            H.eq(f.name, "hat_closed", "the hat, not the kick")
            local step = math.floor(f.tick / 120)
            H.truthy(step % 16 >= 12 and step ~= 14, "last beat, empty step: " .. step)
        end
        H.eq(#L.tracks[1].events, 2, "fills are never recorded")
    end },

    { "no fills on a muted or empty track, with only kicks, or unless WILD", function()
        local M, L, st = boot()
        sequence(M, { 0.1 })
        local hits = watch(M, L)
        st.variation = "WILD"
        onePass(L)
        H.eq(#hits, 0, "empty track")
        L.tracks[1].events = { hit(0, "B", "kick_808") }
        onePass(L)
        H.eq(#hits, 1, "only a kick in use: just the kick itself")
        L.tracks[1].events = { hit(600, "A", "hat_closed") }
        L.tracks[1].muted = true
        onePass(L)
        H.eq(#hits, 1, "muted")
        L.tracks[1].muted = false
        st.variation = "LIGHT"
        onePass(L)
        H.eq(#hits, 2, "LIGHT: the hat only")
    end },

    -- ------------------------------------------------------------------
    -- H3: chance
    -- ------------------------------------------------------------------
    { "a ghost recorded with variation on is a chance hit; other hits aren't", function()
        local M, L, st = boot()
        H.tap("L2")
        H.hold("DOWN"); H.play(0.05); H.tap("B"); H.release("DOWN"); H.play(0.3)   -- ghost, variation off
        st.variation = "LIGHT"
        H.tap("Y"); H.play(0.3)                                                    -- normal hit
        H.hold("DOWN"); H.play(0.05); H.tap("A"); H.release("DOWN"); H.play(0.1)   -- ghost
        H.tap("L2")
        local by = {}
        for _, ev in ipairs(L.tracks[1].events) do by[ev.action] = ev end
        H.eq(by.B.chance, nil, "variation off: a plain ghost")
        H.eq(by.Y.chance, nil, "a normal hit")
        H.eq(by.A.chance, 0.5, "ghost with variation on")
    end },

    { "a chance hit plays on some passes; with VARIATION OFF, on all", function()
        local M, L, st = boot()
        L.tracks[1].events = { hit(960, "Y", "snare_analog", { vel = 0.4, chance = 0.5 }) }
        st.variation = "LIGHT"
        sequence(M, { 0.3, 0.5, 0.9 })             -- pass 1: plays (roll, jitter); pass 2: skipped; ...
        local hits = watch(M, L)
        for _ = 1, 4 do onePass(L) end
        H.eq(#hits, 2, "two of four passes")
        st.variation = "OFF"
        for _ = 1, 4 do onePass(L) end
        H.eq(#hits, 6, "all four")
    end },

    { "a chance flam is all or nothing", function()
        local M, L, st = boot()
        L.tracks[1].events = { hit(960, "Y", "snare_analog", { vel = 0.4, chance = 0.5, orn = "flam" }) }
        st.variation = "LIGHT"
        sequence(M, { 0.9 })
        local hits = watch(M, L)
        onePass(L)
        H.eq(#hits, 0, "skipped: no grace note either")
        sequence(M, { 0.3 })
        onePass(L)
        H.eq(#hits, 2, "played: grace and hit")
    end },

    { "chance survives save and load, clamped", function()
        local M, L = boot()
        L.tracks[1].events = { hit(0, "B", "kick_808", { chance = 0.5 }), hit(120, "B", "kick_808", { chance = 7 }),
                               hit(240, "B", "kick_808", { chance = "x" }) }
        local data = assert(M.Save.decode(M.Save.encode(M.Session.snapshot())))
        H.truthy(M.Session.restore(data), "restored")
        local e = L.tracks[1].events
        H.eq(e[1].chance, 0.5, "kept"); H.eq(e[2].chance, 1.0, "clamped"); H.eq(e[3].chance, nil, "junk dropped")
    end },

    -- ------------------------------------------------------------------
    -- H4: per-pad tune and level
    -- ------------------------------------------------------------------
    { "TUNE and LEVEL rows change the selected pad, live and on playback", function()
        local M, L, st = boot()
        H.tap("L2"); H.tap("B"); H.tap("L2")                    -- a recorded kick
        H.hold("SELECT"); H.play(0.3)                           -- opens on pad B
        H.tap("DOWN"); H.tap("RIGHT"); H.tap("RIGHT")                 -- TUNE B +2
        H.tap("DOWN"); H.tap("LEFT"); H.tap("LEFT"); H.tap("LEFT")    -- LEVEL B 70 %
        H.release("SELECT"); H.play(0.1)
        H.eq(st.padTune.B, 2, "tune"); H.near(st.padLevel.B, 0.7, "level", 1e-9)
        H.eq(st.padTune.Y, 0, "other pads untouched"); H.eq(st.padLevel.Y, 1.0, "other pads untouched")
        local hits = watch(M, L)
        H.tap("B"); H.tap("Y")
        H.eq(hits[1].semis, 2, "live: tuned"); H.near(hits[1].vol, 0.85 * 0.7, "live: levelled", 1e-9)
        H.eq(hits[2].semis, 0, "pad Y as before"); H.near(hits[2].vol, 0.85, "pad Y as before", 1e-9)
        hits = watch(M, L)
        onePass(L)
        H.eq(hits[1].semis, 2, "the recorded kick plays tuned"); H.near(hits[1].vol, 0.85 * 0.7, "and levelled", 1e-9)
    end },

    { "the last pad hit is the selected one; values clamp; rows are named for the pad", function()
        local M, L, st = boot()
        H.tap("A")                                              -- hit pad A: selected
        H.hold("SELECT"); H.play(0.3)
        H.eq(package.loaded["src.modes"].trackPage.row, 4, "opens on pad A")
        H.tap("DOWN")                                           -- over pad B's row
        H.eq(st.lastPad, "A", "passing a pad row doesn't select it")
        H.tap("DOWN")                                           -- TUNE
        local rows = M.Drums:getSoundRows(st)
        H.eq(rows[6].label, "TUNE A", "row names the pad")
        for _ = 1, 20 do H.tap("LEFT") end
        H.eq(st.padTune.A, -12, "tune clamps")
        H.eq(M.Drums:getSoundRows(st)[6].value, "-12", "shown")
        H.tap("DOWN")
        for _ = 1, 5 do H.tap("RIGHT") end
        H.near(st.padLevel.A, 1.2, "level clamps at 120 %", 1e-9)
        for _ = 1, 20 do H.tap("LEFT") end
        H.near(st.padLevel.A, 0.1, "and at 10 %", 1e-9)
        H.tap("DOWN"); H.tap("RIGHT"); H.tap("RIGHT")
        H.eq(st.variation, "WILD", "VARIATION row")
        H.release("SELECT"); H.play(0.1)
    end },

    { "variation, tune and level are saved and loaded; bad values ignored", function()
        local M, L, st = boot()
        st.variation, st.padTune.X, st.padLevel.Y = "WILD", -5, 0.4
        local data = assert(M.Save.decode(M.Save.encode(M.Session.snapshot())))
        H.truthy(M.Session.restore(data), "restored")
        local s2 = L.tracks[1].state
        H.eq(s2.variation, "WILD", "variation"); H.eq(s2.padTune.X, -5, "tune"); H.near(s2.padLevel.Y, 0.4, "level", 1e-9)
        data.tracks[1].settings.variation = "CRAZY"
        data.tracks[1].settings.tune = { B = 99, Y = "x" }
        data.tracks[1].settings.level = { B = -3 }
        M.Session.restore(data)
        local s3 = L.tracks[1].state
        H.eq(s3.variation, "OFF", "unknown variation ignored")
        H.eq(s3.padTune.B, 12, "tune clamped"); H.eq(s3.padTune.Y, 0, "junk ignored")
        H.near(s3.padLevel.B, 0.1, "level clamped", 1e-9)
    end },

    { "the Track page list scrolls: all twelve drum rows (eight + four effects) can be reached and drawn", function()
        local M, L, st = boot()
        local page = function() return package.loaded["src.modes"].trackPage end
        H.hold("SELECT"); H.play(0.3)
        local seen = {}
        for _ = 1, 16 do
            H.tap("DOWN")
            seen[page().row] = true
        end
        for i = 1, 16 do H.truthy(seen[i], "row " .. i) end
        H.release("SELECT"); H.play(0.1)
    end },

    -- ------------------------------------------------------------------
    -- PHASE_L L6: quiet hits darker, variants, the hat choke group
    -- ------------------------------------------------------------------
    { "quiet hits are darker: velocity sets the hit's tone, with EFX a low-pass on the voice", function()
        local Drums = require("src.instruments.drums")
        H.near(Drums.velTone(0.85), 1.0, "a normal hit is as generated")
        H.truthy(Drums.velTone(0.4) < 0.55, "a ghost is darker")
        H.truthy(Drums.velTone(0.05) >= 0.2, "never fully muffled")
        local M = H.fresh({ realSynth = true })
        local S = M.Synth
        S:init()
        S.fxSupported = true
        local seen = {}
        for _, pool in pairs(S.pools) do
            for _, src in ipairs(pool.voices) do
                src.setFilter = function(self, f) seen[#seen + 1] = f or false end
            end
        end
        local track = M.Looper.tracks[1]
        S:trigger("snare_analog", 0, 0.4, 1.0, nil, 1.0, track, Drums.velTone(0.4))
        local f = seen[#seen]
        H.truthy(f and f.highgain and f.highgain < 0.6, "soft hit low-passed: " .. tostring(f and f.highgain))
        S:trigger("snare_analog", 0, 0.9, 1.0, nil, 1.0, track, Drums.velTone(0.9))
        H.eq(seen[#seen], false, "a full hit is not filtered")
    end },

    { "snares, hats and claps come in three versions, played in turn; kicks in one", function()
        local M = H.fresh({ realSynth = true })
        local S = M.Synth
        S:init()
        S:ensureAllDrums()
        for _, item in ipairs(S.drumCatalog) do
            local v = S.VARIANTS[item.id]
            if item.cat == "SNARE" or item.cat == "HAT" or item.cat == "CLAP" then
                H.eq(v and #v, 3, item.id .. " has three versions")
                for _, name in ipairs(v) do H.truthy(S.pools[name], name .. " pool") end
            elseif item.cat == "KICK" then
                H.falsy(v, item.id .. " has one")
            end
        end
        local used = {}
        local pools = S.VARIANTS.snare_tight
        for k = 1, 6 do
            local v = S:trigger("snare_tight", 0, 0.8, 1.0)
            for i, name in ipairs(pools) do
                for _, src in ipairs(S.pools[name].voices) do
                    if src == v.source then used[k] = i end
                end
            end
        end
        H.eq(table.concat(used, " "), "1 2 3 1 2 3", "in turn")
        H.eq(S.activeVoices[#S.activeVoices].soundName, "snare_tight", "the voice is still the snare (choke, meters)")
    end },

    { "a closed hat cuts an open hat whichever version is playing", function()
        local M = H.fresh({ realSynth = true })
        local S = M.Synth
        S:init()
        local open = S:trigger("hat_open", 0, 0.8, 1.0)
        S:update(0.05)
        S:trigger("hat_closed", 0, 0.8, 1.0)
        H.truthy(open.maxLife <= open.elapsed + 0.031, "the open hat is choked")
    end },

    { "the acoustic sounds are built after boot, at once when hit first, and in the background", function()
        local M = H.fresh({ realSynth = true })
        local S = M.Synth
        S:init()
        H.truthy(#S.lazyOrder >= 15, "the acoustic sounds wait: " .. #S.lazyOrder)
        H.falsy(S.pools.snare_funk, "not built at boot")
        local v = S:trigger("snare_funk", 0, 0.8, 1.0)
        H.truthy(v and S.pools.snare_funk, "a hit builds it at once and plays")
        H.truthy(S.pools["snare_funk#3"], "with its versions")
        S:startPregen()
        local guard = 0
        while S.pregen and guard < 100000 do S:stepPregen(0.001); guard = guard + 1 end
        for _, id in ipairs(S.lazyOrder) do H.truthy(S.pools[id], id .. " built in the background") end
    end },

    { "the catalogue runs category by category, numbered in order; every kit's sound exists", function()
        local M = H.fresh({ realSynth = true })
        local S = M.Synth
        S:init()
        local seen, last = {}, nil
        for i, item in ipairs(S.drumCatalog) do
            if item.cat ~= last then
                H.falsy(seen[item.cat], item.cat .. " in one piece")
                seen[item.cat], last = true, item.cat
            end
            H.eq(item.full:sub(1, 3), string.format("%02d.", i), item.id .. " numbered")
        end
        local ids = {}
        for _, item in ipairs(S.drumCatalog) do ids[item.id] = true end
        for _, kit in ipairs(require("src.instruments.drums").KITS) do
            for pad, id in pairs(kit.pads) do H.truthy(ids[id], kit.name .. " " .. pad .. ": " .. id) end
        end
    end },
}
