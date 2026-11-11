-- Smoke: boot the real game (sound generation included) and drive every mode,
-- instrument and page through love.update + love.draw. Catches nil errors
-- anywhere on the update and draw paths.
local H = require("helpers")

local tap = function(btns) H.play(0.05, btns); H.play(0.05) end

return {
    { "boots, generates sounds and runs 2 s of frames", function()
        local M = H.loadMain()
        H.truthy(next(M.Synth.pools) ~= nil, "sound pools built")
        H.play(2.0)
        H.truthy(M.Looper.phase > 0, "playhead moved")
    end },

    { "every instrument on every track: play, record, pages, modes", function()
        local M = H.loadMain()
        local L, I = M.Looper, M.Instruments
        local dirs = { {}, { "UP" }, { "DOWN" }, { "LEFT" }, { "RIGHT" }, { "UP", "LEFT" }, { "DOWN", "RIGHT" } }

        for slot = 1, 4 do
            for _ = 1, #I.catalog do
                -- play every face button with every D-pad direction and shoulder, recording
                tap({ "L2" })                                   -- latch record on
                for _, d in ipairs(dirs) do
                    for _, face in ipairs({ "B", "A", "Y", "X" }) do
                        local held = { face }
                        for _, x in ipairs(d) do held[#held + 1] = x end
                        H.play(0.12, held)
                    end
                end
                H.play(0.3, { "B", "L1" }); H.play(0.3, { "A", "R1" }); H.play(0.3, { "Y", "L1", "R1" })
                tap({ "L2" })                                   -- latch record off
                H.play(0.5)                                     -- let it play back

                -- Track page: rows, sounds, effects (tap + hold-adjust)
                H.play(0.25, { "SELECT" })
                H.keys[H.KEY.SELECT] = true
                for _, b in ipairs({ "DOWN", "R1", "UP", "L1", "X", "Y", "A", "B" }) do tap({ b }) end
                H.play(0.2, { "X", "UP" })
                H.keys[H.KEY.SELECT] = false
                H.play(0.05)

                -- Transport, mix, live FX, erase/undo
                H.keys[H.KEY.START] = true
                H.play(0.3)
                for _, b in ipairs({ "UP", "DOWN", "LEFT", "RIGHT", "L1", "R1", "A", "X", "X" }) do tap({ b }) end
                H.play(0.2, { "Y", "UP" })
                H.keys[H.KEY.START] = false
                H.play(0.05)
                H.play(0.3, { "SELECT", "R2", "UP" })
                H.play(0.3, { "SELECT", "R2", "RIGHT" })
                for _, d in ipairs({ "UP", "DOWN", "LEFT", "RIGHT" }) do H.play(0.15, { "R2", d }) end
                H.play(0.1, { "L2", "R2", "B" })
                H.play(0.1, { "L2", "R2", "LEFT" })

                -- next instrument in this slot (Track page RIGHT)
                H.keys[H.KEY.SELECT] = true
                H.play(0.25)
                tap({ "RIGHT" })
                H.keys[H.KEY.SELECT] = false
                H.play(0.05)
            end
            tap({ "SELECT" })                                   -- next track
        end

        -- 4 bars and back, then clear
        H.keys[H.KEY.START] = true; H.play(0.3); tap({ "B" }); tap({ "B" }); H.keys[H.KEY.START] = false
        H.play(0.05)
        H.play(0.1, { "L2", "R2", "START" })
        H.play(0.5)
        H.truthy(L.activeTrack >= 1 and L.activeTrack <= 4, "active track valid")
    end },
}
