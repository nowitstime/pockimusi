-- Save text (C1): encode tables to text and decode them back, safely.
local H = require("helpers")

local function save() return H.fresh().Save or require("src.save") end

local function deepEqual(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not deepEqual(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

local function roundTrip(S, v)
    local text = S.encode(v)
    local back, err = S.decode(text)
    H.truthy(back ~= nil, "decoded: " .. tostring(err) .. "\n" .. text)
    return back, text
end

local SAMPLE = {
    format = 1,
    bpm = 115,
    swing = 0.56,
    name = 'quote " backslash \\ newline\nreturn\r tab\t nul\0 end',
    flags = { true, false },
    list = { 1, 2.5, -3, 1e-9, 123456789012 },
    holes = { [1] = "a", [3] = "c" },
    nested = { a = { b = { c = { d = "deep" } } } },
    events = {
        { tick = 960, len = 240, action = "B", vel = 0.85, bend = { { dt = 120, degree = 5, semis = 7 } } },
        { tick = 0, len = 0, action = "Y", chord = { name = "Cmaj7", roman = "I", colour = "7TH" } },
    },
    ["key with spaces"] = 1,
    ["end"] = "reserved word key",
    [2.5] = "fractional key",
    [-1] = "negative key",
}

return {
    { "round trip keeps every value exactly", function()
        local S = save()
        local back = roundTrip(S, SAMPLE)
        H.truthy(deepEqual(back, SAMPLE), "same data")
        H.eq(back.holes[2], nil, "holes stay holes")
        H.eq(back.holes[3], "c", "item after a hole keeps its key")
    end },

    { "a list that lost an item in the middle keeps every other item in place", function()
        local S = save()
        local t = { "a", "b", "c", "d", "e" }
        t[2] = nil                                     -- array storage with a gap: #t may still say 5
        local back = roundTrip(S, { t = t }).t
        H.eq(back[1], "a", "1")
        H.eq(back[2], nil, "the gap")
        H.eq(back[3], "c", "3 stays 3")
        H.eq(back[5], "e", "5 stays 5")
    end },

    { "numbers keep full precision", function()
        local S = save()
        for _, n in ipairs({ 0.1, 1 / 3, 2 ^ 52 + 1, -0.000123456789, 6.02214076e23, 960, -5 }) do
            local back = roundTrip(S, { n })
            H.eq(back[1], n, "number " .. tostring(n))
        end
    end },

    { "the same data always gives the same text", function()
        local S = save()
        local a = S.encode(SAMPLE)
        local copy = S.decode(a)
        H.eq(S.encode(copy), a, "stable")
        local t1, t2 = {}, {}
        for i = 1, 50 do t1["k" .. i] = i end
        for i = 50, 1, -1 do t2["k" .. i] = i end
        H.eq(S.encode(t1), S.encode(t2), "insertion order doesn't matter")
    end },

    { "the text is readable", function()
        local S = save()
        local text = S.encode({ bpm = 115, tracks = { { instrumentId = "bass", events = { { tick = 960, action = "B" } } } } })
        H.truthy(text:find("bpm=115", 1, true), "plain keys")
        H.truthy(text:find('instrumentId="bass"', 1, true), "strings")
        H.truthy(text:find('{action="B",tick=960}', 1, true), "an event on one line")
    end },

    { "runtime objects can't be saved", function()
        local S = save()
        for name, bad in pairs({
            ["function"] = { f = function() end },
            ["nan"] = { n = 0 / 0 },
            ["inf"] = { n = math.huge },
            ["table key"] = { [{}] = 1 },
            ["userdata-ish"] = { co = coroutine.create(function() end) },
        }) do
            local ok = pcall(S.encode, bad)
            H.falsy(ok, name .. " rejected")
        end
        local loop = {}
        loop.self = loop
        H.falsy(pcall(S.encode, loop), "a table containing itself")
    end },

    { "a file with code in it is never run", function()
        local S = save()
        _G.SAVE_PWNED = nil
        for _, text in ipairs({
            'SAVE_PWNED = true',
            '{ a = (function() SAVE_PWNED = true end)() }',
            '{ a = os.exit() }',
            '{ a = print("x") }',
            '{ a = 1 } SAVE_PWNED = true',
            'while true do end',
            '{ a = ("x"):rep(9) }',
            '{ [os.time()] = 1 }',
        }) do
            local v, err = S.decode(text)
            H.eq(v, nil, "refused: " .. text)
            H.truthy(type(err) == "string" and err:find("save:"), "with a message")
        end
        H.eq(_G.SAVE_PWNED, nil, "nothing ran")
    end },

    { "damaged text returns an error, never a crash", function()
        local S = save()
        local good = S.encode(SAMPLE)
        for cut = 1, #good - 1, 7 do
            local v = S.decode(good:sub(1, cut))       -- every truncation of a real save
            H.eq(v, nil, "truncated at " .. cut)
        end
        for _, text in ipairs({ "", "   ", "{", "}", "{,}", '{"unterminated}', "{a=}", "{1 2}", '"\\999"', "{-}", "nil", "{x=nil}" }) do
            local ok, v = pcall(S.decode, text)
            H.truthy(ok, "no crash on: " .. text)
            H.eq(v, nil, "nil for: " .. text)
        end
        H.eq(S.decode(nil), nil, "nil input")
    end },

    { "limits: depth and size", function()
        local S = save()
        local deep = {}
        local cur = deep
        for _ = 1, 40 do cur.x = {}; cur = cur.x end
        H.falsy(pcall(S.encode, deep), "too deep to save")
        H.eq(S.decode(string.rep("{", 40) .. string.rep("}", 40)), nil, "too deep to load")
        H.eq(S.decode("{" .. string.rep(" ", S.MAX_BYTES) .. "}"), nil, "too big to load")
    end },

    { "comments and spacing in a hand-edited file are fine", function()
        local S = save()
        local v = S.decode('-- my session\n{\n  bpm = 120 , -- tempo\n  list = { 1 ; 2 },\n}\n')
        H.eq(v.bpm, 120, "value")
        H.eq(v.list[2], 2, "semicolons too")
    end },
}
