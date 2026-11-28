-- The one-time copy of saves from the old PocketGroove save folder
local H = require("helpers")
local Migrate = require("src.migrate")

-- A fake love.filesystem with one save folder per identity, mounted over
-- the game's own files (which must never be copied)
local function fakeFs(folders)
    local fs = { identity = "pockimusi" }
    local source = { ["main.lua"] = true, ["conf.lua"] = true }
    local function dir() folders[fs.identity] = folders[fs.identity] or {} return folders[fs.identity] end
    function fs.setIdentity(name) fs.identity = name end
    function fs.getSaveDirectory() return "/save/" .. fs.identity end
    function fs.getDirectoryItems()
        local out = {}
        for name in pairs(source) do out[#out + 1] = name end
        for name in pairs(dir()) do out[#out + 1] = name end
        return out
    end
    function fs.getInfo(name)
        if dir()[name] or source[name] then return { type = "file" } end
    end
    function fs.getRealDirectory(name)
        if dir()[name] then return fs.getSaveDirectory() end
        if source[name] then return "/game" end
    end
    function fs.read(name) return dir()[name] end
    function fs.write(name, text) dir()[name] = text return true end
    return fs
end

return {
    { "old saves are copied to the new folder on the first boot", function()
        local folders = { pocketgroove = { ["session_a.txt"] = "A", ["pattern_b.txt"] = "PB", ["song.txt"] = "S" } }
        local fs = fakeFs(folders)
        H.eq(Migrate.run(fs), 3, "three files copied")
        H.eq(folders.pockimusi["session_a.txt"], "A", "session")
        H.eq(folders.pockimusi["pattern_b.txt"], "PB", "pattern")
        H.eq(folders.pockimusi["song.txt"], "S", "song")
        H.eq(folders.pockimusi["main.lua"], nil, "game files are not copied")
        H.eq(folders.pocketgroove["session_a.txt"], "A", "the old folder is left as it was")
        H.eq(fs.identity, "pockimusi", "ends on the new identity")
    end },

    { "nothing is copied once the new folder has saves", function()
        local folders = {
            pocketgroove = { ["session_a.txt"] = "OLD" },
            pockimusi = { ["session_a.txt"] = "NEW" },
        }
        local fs = fakeFs(folders)
        H.eq(Migrate.run(fs), 0, "no copy")
        H.eq(folders.pockimusi["session_a.txt"], "NEW", "new save kept")
    end },

    { "a fresh install with no old saves copies nothing", function()
        local fs = fakeFs({})
        H.eq(Migrate.run(fs), 0, "no copy")
        H.eq(fs.identity, "pockimusi", "ends on the new identity")
    end },

    { "a filesystem without setIdentity (tests, old runtimes) is left alone", function()
        H.eq(Migrate.run({ read = function() end }), 0, "no copy")
    end },
}
