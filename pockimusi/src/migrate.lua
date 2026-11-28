-- src/migrate.lua — one-time copy of saves from the old name
--
-- The app used to be called PocketGroove, and LÖVE keeps each app's saves in
-- a folder named after its identity. The identity is now "pockimusi", so on
-- the first boot under the new name the old folder's files (sessions,
-- pattern slots, the song, display settings) are copied across. The old
-- folder is left as it was. Nothing is copied once the new folder has saves.

local Migrate = {
    OLD = "pocketgroove",
    NEW = "pockimusi",
}

local function log(msg)
    print("[Pockimusi] " .. msg)
end

-- Save files only: with the save folder mounted over the game's own files,
-- getDirectoryItems also lists the sources, so keep what lives in the save
-- folder itself
local function savedFiles(fs)
    local out, saveDir = {}, fs.getSaveDirectory()
    for _, name in ipairs(fs.getDirectoryItems("") or {}) do
        local info = fs.getInfo(name)
        if name:match("%.txt$") and info and info.type == "file"
            and fs.getRealDirectory(name) == saveDir then
            out[#out + 1] = name
        end
    end
    table.sort(out)
    return out
end

-- Returns how many files were copied (0 when there was nothing to do)
function Migrate.run(fs)
    fs = fs or (love and love.filesystem)
    if not (fs and fs.setIdentity and fs.getDirectoryItems and fs.getRealDirectory
            and fs.getSaveDirectory and fs.getInfo and fs.read and fs.write) then
        return 0
    end
    if #savedFiles(fs) > 0 then return 0 end     -- already has saves

    local copied = 0
    local ok, err = pcall(function()
        fs.setIdentity(Migrate.OLD, true)
        local files = {}
        for _, name in ipairs(savedFiles(fs)) do
            local text = fs.read(name)
            if text then files[#files + 1] = { name = name, text = text } end
        end
        fs.setIdentity(Migrate.NEW, true)
        for _, f in ipairs(files) do
            if fs.write(f.name, f.text) then copied = copied + 1 end
        end
    end)
    pcall(fs.setIdentity, Migrate.NEW, true)     -- always end on the new name
    if not ok then
        log("could not copy old PocketGroove saves: " .. tostring(err))
    elseif copied > 0 then
        log(("copied %d save file(s) from the old PocketGroove folder"):format(copied))
    end
    return copied
end

return Migrate
