-- Autosave (C3): when it writes, the two alternating files, restoring on
-- boot, and surviving damaged files and power cuts.
local H = require("helpers")

local A, B = "session_a.txt", "session_b.txt"

local function boot(keep)
    H.keepFiles = keep or false
    local M = H.loadMain()
    H.keepFiles = false
    M.Autosave = require("src.autosave")
    H.play(0.1)
    return M, M.Looper
end

local function recordHit(btn)
    H.tap("L2"); H.tap(btn or "B"); H.tap("L2")
end

local function seqOf(name)
    local data = require("src.save").decode(H.files[name] or "")
    return data and data.seq
end

local function fileCount()
    local n = 0
    for _ in pairs(H.files) do n = n + 1 end
    return n
end

return {
    -- ------------------------------------------------------------------
    -- When it writes
    -- ------------------------------------------------------------------
    { "an untouched session never writes", function()
        boot()
        H.play(35)
        H.eq(fileCount(), 0, "no files")
    end },

    { "a change is saved about 10 s later, at a quiet moment", function()
        boot()
        recordHit()
        H.play(8)
        H.eq(H.files[A], nil, "not yet")
        H.play(3)
        H.truthy(H.files[A], "saved to slot A")
        H.eq(seqOf(A), 1, "sequence 1")
    end },

    { "it waits while buttons are held, but not forever", function()
        local M = boot()
        recordHit()
        H.hold("R2"); H.play(15)
        H.eq(H.files[A], nil, "holding a button: wait")
        H.play(16)
        H.truthy(H.files[A], "saved after 30 s anyway")
        H.release("R2"); H.play(0.1)
    end },

    { "slots alternate and the sequence number rises", function()
        boot()
        recordHit("B"); H.play(11)
        recordHit("A"); H.play(11)
        recordHit("Y"); H.play(11)
        H.eq(seqOf(A), 3, "A has the newest (3)")
        H.eq(seqOf(B), 2, "B has the one before (2)")
    end },

    { "pressing buttons that change nothing doesn't rewrite the file", function()
        local M = boot()
        recordHit(); H.play(11)
        local before = H.files[A]
        H.tap("R2"); H.play(11)                         -- R2 alone: no lasting change
        H.eq(H.files[B], nil, "nothing new written")
        H.eq(H.files[A], before, "same file")
        H.eq(M.Autosave.seq, 1, "sequence unchanged")
    end },

    { "quitting and losing focus save at once", function()
        boot()
        recordHit()
        love.quit()
        H.truthy(H.files[A], "saved on quit")
        recordHit("Y")
        love.focus(false)
        H.truthy(H.files[B], "saved on focus loss")
        love.focus(true)
        H.eq(seqOf(B), 2, "no extra write on focus gain")
    end },

    -- ------------------------------------------------------------------
    -- Restoring on boot
    -- ------------------------------------------------------------------
    { "a reboot brings back the newest save", function()
        local M, L = boot()
        recordHit("B"); H.play(11)
        recordHit("Y"); L.bpm = 140; H.tap("SELECT"); H.play(11)   -- newest: 2 hits, 140 BPM, track 2
        local M2, L2 = boot(true)
        H.eq(#L2.tracks[1].events, 2, "both hits")
        H.eq(L2.bpm, 140, "tempo")
        H.eq(L2.activeTrack, 2, "active track")
        H.eq(L2.toastText, "SESSION RESTORED", "told you so")
        H.eq(M2.Autosave.seq, 2, "carries on the sequence")
        recordHit("A"); H.play(11)
        H.eq(seqOf(A), 3, "next save goes to the other slot")
    end },

    { "a restored session isn't written again until it changes", function()
        boot(); recordHit(); H.play(11)
        local before = H.files[A]
        local M2 = boot(true)
        H.tap("R2"); H.play(12)
        H.eq(H.files[A], before, "untouched")
        H.eq(H.files[B], nil, "no second file")
    end },

    { "a power cut mid-write: the half-written file is ignored, the previous save loads", function()
        local M, L = boot()
        recordHit("B"); H.play(11)                       -- A: 1 hit
        recordHit("Y"); H.play(11)                       -- B: 2 hits
        recordHit("X")
        local full = require("src.save").encode({ seq = 3, session = M.Session.snapshot() })
        H.files[A] = full:sub(1, math.floor(#full * 0.6)) -- cut off while writing A
        local _, L2 = boot(true)
        H.eq(#L2.tracks[1].events, 2, "the last complete save (B) came back")
    end },

    { "a damaged newest file falls back to the older one", function()
        boot()
        recordHit("B"); H.play(11)
        recordHit("Y"); H.play(11)
        H.files[B] = "{seq=2,session={format=1,tracks=" -- garbage in the newest
        local _, L2 = boot(true)
        H.eq(#L2.tracks[1].events, 1, "older save restored")
    end },

    { "a save from a newer version is skipped for the older good one", function()
        local M = boot()
        recordHit("B"); H.play(11)
        H.files[B] = '{seq=9,session={format=2,bpm=99}}'
        local _, L2 = boot(true)
        H.eq(#L2.tracks[1].events, 1, "older format-1 save used")
        H.truthy(L2.bpm ~= 99, "the newer file wasn't applied")
    end },

    { "if no save can be read: fresh session, a message, and the game runs", function()
        H.files = { [A] = "nonsense", [B] = "{seq=" }
        local _, L = boot(true)
        H.eq(#L.tracks[1].events, 0, "fresh")
        H.eq(L.toastText, "SAVE COULDN'T BE READ - FRESH SESSION", "message")
        recordHit(); H.play(11)
        H.truthy(seqOf(A) or seqOf(B), "saving works again")
    end },

    { "first boot with no files: fresh session, no message", function()
        local _, L = boot()
        H.truthy(L.toastText ~= "SAVE COULDN'T BE READ - FRESH SESSION", "no error message")
    end },

    { "a failed write says so once, and saving resumes when it can", function()
        local _, L = boot()
        local warnings = 0
        local show = L.showToast
        L.showToast = function(self, msg)
            if msg == "AUTOSAVE FAILED - SEE LOG" then warnings = warnings + 1 end
            return show(self, msg)
        end
        H.diskFull = true
        recordHit(); H.play(11)
        H.eq(warnings, 1, "warned")
        recordHit("Y"); H.play(11)
        H.eq(warnings, 1, "warned only once")
        H.diskFull = false
        recordHit("A"); H.play(11)
        H.truthy(H.files[A], "saved once there's room")
    end },
}
