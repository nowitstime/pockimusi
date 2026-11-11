-- Input: press/release edges, key repeat, START combo flag
local H = require("helpers")

local function frames(Input, n)
    for _ = 1, n do
        H.time = H.time + 1 / 60
        Input:update(1 / 60)
    end
end

return {
    { "pressed and released fire for exactly one frame", function()
        local I = H.fresh().Input
        H.keys["j"] = true            -- B
        frames(I, 1)
        H.truthy(I.pressed.B, "pressed on first frame")
        frames(I, 1)
        H.falsy(I.pressed.B, "not pressed on second frame")
        H.truthy(I.down.B, "still down")
        H.keys["j"] = false
        frames(I, 1)
        H.truthy(I.released.B, "released")
        frames(I, 1)
        H.falsy(I.released.B, "released only once")
    end },

    { "key repeat: once on press, then every 0.08 s after 0.35 s", function()
        local I = H.fresh().Input
        H.keys["w"] = true
        local fires, firstRepeatAt = 0, nil
        for f = 1, 60 do
            frames(I, 1)
            if I.repeated.UP then
                fires = fires + 1
                if fires == 2 and not firstRepeatAt then firstRepeatAt = f end
            end
        end
        H.eq(fires, 9, "repeats in 1 s")
        H.truthy(firstRepeatAt >= 21 and firstRepeatAt <= 23, "first auto-repeat near 0.35 s (frame " .. firstRepeatAt .. ")")
        H.keys["w"] = false
        frames(I, 1)
        H.falsy(I.repeated.UP, "no repeat after release")
    end },

    { "combo flags clear when the modifier is pressed again", function()
        local I = H.fresh().Input
        for mod, key in pairs({ L2 = "lshift", R2 = "space", SELECT = "tab", START = "return" }) do
            I.comboUsed[mod] = true
            H.keys[key] = true
            frames(I, 1)
            H.falsy(I.comboUsed[mod], mod .. " cleared on press")
            H.keys[key] = false
            frames(I, 1)
        end
    end },

    { "combo flags survive the release frame until cleared", function()
        local I = H.fresh().Input
        H.keys["tab"] = true
        frames(I, 1)
        I.comboUsed.SELECT = true
        H.keys["tab"] = false
        frames(I, 1)
        H.truthy(I.released.SELECT, "release frame")
        H.truthy(I.comboUsed.SELECT, "still set so the tap check can see it")
        I:clearReleasedCombos()
        H.falsy(I.comboUsed.SELECT, "cleared after the frame")
    end },

    { "8-way direction from the D-pad", function()
        local I = H.fresh().Input
        H.keys["w"], H.keys["a"] = true, true
        frames(I, 1)
        H.eq(I:get8WayDirection(), "UP_LEFT", "up + left")
        H.keys["w"], H.keys["a"] = false, false
        frames(I, 1)
        H.eq(I:get8WayDirection(), "NEUTRAL", "nothing held")
    end },

    { "recording: latched, held, and blocked by R2", function()
        local I = H.fresh().Input
        H.falsy(I:isRecording(), "idle")
        I.recLatched = true
        H.truthy(I:isRecording(), "latched")
        I.recLatched = false
        H.keys["lshift"] = true       -- L2
        frames(I, 1)
        H.truthy(I:isRecording(), "L2 held")
        H.keys["space"] = true        -- R2
        frames(I, 1)
        H.falsy(I:isRecording(), "L2 + R2 = erase, not record")
    end },
}
