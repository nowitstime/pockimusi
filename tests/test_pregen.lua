-- Sound generation speed-ups: samples written straight into memory, and the
-- patches not built at boot generated in the background, a little per frame.
local H = require("helpers")

-- A SoundData with a real block of memory behind getFFIPointer, like LÖVE 11.3+
local function ffiSoundData(n)
    local ffi = require("ffi")
    local buf = ffi.new("int16_t[?]", n)
    return { n = n, buf = buf, getFFIPointer = function() return buf end,
             getSampleCount = function() return n end }
end

-- Boot the whole app, keeping background generation, with a clock that moves
-- on every read (so the frame budget runs out as it would on the device)
local function bootWithClock(tick)
    H.keepPregen = true
    local M = H.loadMain()
    H.keepPregen = false
    love.timer.getTime = function() H.time = H.time + tick; return H.time end
    return M, M.Synth
end

local function lazyIds(S)
    local out = {}
    for _, id in ipairs(S.patchOrder) do
        local p = S.patches[id]
        if not p.core and not p.silent then out[#out + 1] = id end
    end
    return out
end

return {
    { "writing through the pointer gives the same samples as setSample", function()
        H.captureSamples = true
        local M = H.fresh({ realSynth = true })
        local S = M.Synth
        local wave = function(i) return math.sin(i * 0.05) * 1.3 - 0.1 end   -- clips both ways
        local slow = love.sound.newSoundData(3000)
        S:fillSamples(slow, 3000, wave)
        local fast = ffiSoundData(3000)
        S:fillSamples(fast, 3000, wave)
        H.captureSamples = false
        for i = 0, 2999 do
            local want = math.floor(math.abs(slow.samples[i]) * 32767) * (slow.samples[i] < 0 and -1 or 1)
            if fast.buf[i] ~= want then
                H.eq(fast.buf[i], want, "sample " .. i)
                return
            end
        end
        H.eq(fast.buf[0], -3276, "-0.1 truncated, as setSample does")
        H.eq(fast.buf[31], 32767, "clipped at the top")
    end },

    { "the patches left after boot are generated in the background, a bit per frame", function()
        local M, S = bootWithClock(0.0005)
        local lazy = lazyIds(S)
        H.truthy(#lazy >= 12, "some patches wait")
        H.truthy(S.pregen ~= nil, "a background job is waiting")
        H.falsy(S.patches[lazy[1]].built, "nothing built yet")
        local frames = 0
        while S.pregen and frames < 100000 do
            H.play(1 / 60)
            frames = frames + 1
        end
        H.falsy(S.pregen, "the job finishes")
        H.truthy(frames > #lazy, "spread over many frames: " .. frames)
        for _, id in ipairs(lazy) do
            local p = S.patches[id]
            H.truthy(p.built and not p.building, id .. " built")
            H.truthy((p.attack and S.pools[p.attack]) or (p.loop and S.loopPools[p.loop]), id .. " has sounds")
        end
    end },

    { "a patch picked while half built is finished at once, with its voices", function()
        local M, S = bootWithClock(0.0005)
        local first
        for _ = 1, 1000 do
            H.play(1 / 60)
            for _, id in ipairs(S.patchOrder) do
                if S.patches[id].building then first = id end
            end
            if first then break end
        end
        H.truthy(first, "caught a patch half built")
        S:preparePatch(first, 16)
        local p = S.patches[first]
        H.truthy(p.built and not p.building, "finished")
        H.falsy(S.pregen, "the rest of the job ran too")
        local n = p.loop and #S.loopPools[p.loop].sources or S.pools[p.attack].size
        H.truthy(n >= 16, "grown to the voices asked for: " .. n)
        H.truthy(p.loop == nil or S.loopPools[p.loop].data.n > 0, "loop filled")
    end },

    { "with no background job, picking a patch still builds it on the spot", function()
        local M = H.loadMain()
        local S = M.Synth
        H.falsy(S.pregen, "tests turn it off")
        local id = lazyIds(S)[1]
        H.falsy(S.patches[id].built, "not built")
        S:preparePatch(id)
        H.truthy(S.patches[id].built, "built when picked")
    end },
}
