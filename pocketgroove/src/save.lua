-- ============================================================================
-- src/save.lua — Save text: plain tables <-> text (SPEC §10)
--
-- Save.encode(value) writes numbers, strings, booleans and tables (string or
-- number keys) as a Lua-style table literal. Keys are sorted, so the same
-- data always gives the same text (autosave compares texts to see changes).
-- Anything else (functions, voices, NaN, cycles) is an error, so runtime
-- objects can't end up in a save.
--
-- Save.decode(text) reads that format back with its own small parser. It
-- never runs the text as code, so a damaged or tampered file can only fail
-- to load; it can't do anything or hang the game.
-- ============================================================================

local Save = {
    MAX_DEPTH = 32,
    MAX_BYTES = 8 * 1024 * 1024,
}

local string_format = string.format
local string_byte   = string.byte
local string_char   = string.char
local string_sub    = string.sub
local table_concat  = table.concat
local table_sort    = table.sort

-- ---------------------------------------------------------------------------
-- Encode
-- ---------------------------------------------------------------------------
local RESERVED = {}
for w in ("and break do else elseif end false for function goto if in local nil not or repeat return then true until while"):gmatch("%a+") do
    RESERVED[w] = true
end

local function encodeString(s)
    -- \\, \" and every control byte as \ddd: one simple rule the parser mirrors
    return '"' .. s:gsub('[%c"\\]', function(c)
        if c == '"' then return '\\"' end
        if c == "\\" then return "\\\\" end
        return string_format("\\%03d", string_byte(c))
    end) .. '"'
end

local function encodeNumber(n)
    if n ~= n or n == math.huge or n == -math.huge then
        error("save: can't store " .. tostring(n), 0)
    end
    if n == math.floor(n) and n >= -2^53 and n <= 2^53 then
        return string_format("%d", n)
    end
    return string_format("%.17g", n)
end

local function sortedKeys(t)
    local nums, strs = {}, {}
    for k in pairs(t) do
        local kt = type(k)
        if kt == "number" then
            if k ~= k then error("save: NaN key", 0) end
            nums[#nums + 1] = k
        elseif kt == "string" then
            strs[#strs + 1] = k
        else
            error("save: can't use a " .. kt .. " as a key", 0)
        end
    end
    table_sort(nums)
    table_sort(strs)
    for i = 1, #strs do nums[#nums + 1] = strs[i] end
    return nums
end

local encodeValue

local function isFlat(t)
    for _, v in pairs(t) do
        if type(v) == "table" then return false end
    end
    return true
end

local function encodeTable(t, depth, seen, out)
    if seen[t] then error("save: a table contains itself", 0) end
    if depth > Save.MAX_DEPTH then error("save: tables nested too deep", 0) end
    seen[t] = true

    local keys = sortedKeys(t)
    -- List part (1, 2, 3 ... up to the first gap) is written without keys.
    -- Not #t: with holes, #t may point past a gap and shift later items.
    local n = 0
    while t[n + 1] ~= nil do n = n + 1 end
    local flat = isFlat(t)
    local indent = flat and "" or ("\n" .. string.rep(" ", depth + 1))
    out[#out + 1] = "{"
    local first = true
    for _, k in ipairs(keys) do
        local listItem = (type(k) == "number" and k >= 1 and k <= n and k == math.floor(k))
        out[#out + 1] = first and indent or ("," .. indent)
        first = false
        if not listItem then
            if type(k) == "string" and k:match("^[%a_][%w_]*$") and not RESERVED[k] then
                out[#out + 1] = k .. "="
            elseif type(k) == "string" then
                out[#out + 1] = "[" .. encodeString(k) .. "]="
            else
                out[#out + 1] = "[" .. encodeNumber(k) .. "]="
            end
        end
        encodeValue(t[k], depth + 1, seen, out)
    end
    if not flat and not first then out[#out + 1] = "\n" .. string.rep(" ", depth) end
    out[#out + 1] = "}"
    seen[t] = nil
end

function encodeValue(v, depth, seen, out)
    local tv = type(v)
    if tv == "table" then
        encodeTable(v, depth, seen, out)
    elseif tv == "string" then
        out[#out + 1] = encodeString(v)
    elseif tv == "number" then
        out[#out + 1] = encodeNumber(v)
    elseif tv == "boolean" then
        out[#out + 1] = v and "true" or "false"
    else
        error("save: can't store a " .. tv, 0)
    end
end

function Save.encode(value)
    local out = {}
    encodeValue(value, 0, {}, out)
    return table_concat(out)
end

-- ---------------------------------------------------------------------------
-- Decode (the format above, and nothing else)
-- ---------------------------------------------------------------------------
local Parser = {}
Parser.__index = Parser

function Parser:fail(msg)
    error({ saveError = string_format("save: %s at byte %d", msg, self.pos) }, 0)
end

function Parser:skip()
    local s, p = self.s, self.pos
    while true do
        local _, e = s:find("^[ \t\r\n]+", p)
        if e then p = e + 1 end
        if s:sub(p, p + 1) == "--" then                 -- line comment
            local nl = s:find("\n", p, true)
            p = nl and nl + 1 or #s + 1
        else
            break
        end
    end
    self.pos = p
end

function Parser:peek()
    self:skip()
    return string_sub(self.s, self.pos, self.pos)
end

function Parser:expect(c)
    if self:peek() ~= c then self:fail("expected '" .. c .. "'") end
    self.pos = self.pos + 1
end

function Parser:string()
    local s, p = self.s, self.pos + 1               -- after the opening quote
    local parts = {}
    while true do
        local c = string_sub(s, p, p)
        if c == "" then self:fail("unfinished string") end
        if c == '"' then break end
        if c == "\\" then
            local d = string_sub(s, p + 1, p + 1)
            if d == '"' or d == "\\" then
                parts[#parts + 1] = d
                p = p + 2
            elseif d:match("%d") then
                local digits = s:match("^%d%d?%d?", p + 1)
                local code = tonumber(digits)
                if code > 255 then self:fail("bad escape") end
                parts[#parts + 1] = string_char(code)
                p = p + 1 + #digits
            else
                self:fail("bad escape")
            end
        elseif c:match("%c") then
            self:fail("control character in string")
        else
            local e = s:find('[\\"%c]', p) or (#s + 1)
            parts[#parts + 1] = string_sub(s, p, e - 1)
            p = e
        end
    end
    self.pos = p + 1
    return table_concat(parts)
end

function Parser:number()
    local num = self.s:match("^-?%d+%.?%d*[eE][-+]?%d+", self.pos)
        or self.s:match("^-?%d+%.?%d*", self.pos)
        or self.s:match("^-?%.%d+[eE][-+]?%d+", self.pos)
        or self.s:match("^-?%.%d+", self.pos)
    if not num then self:fail("bad number") end
    self.pos = self.pos + #num
    local v = tonumber(num)
    if not v then self:fail("bad number") end
    return v
end

function Parser:value(depth)
    if depth > Save.MAX_DEPTH then self:fail("nested too deep") end
    local c = self:peek()
    if c == "{" then return self:table(depth + 1) end
    if c == '"' then return self:string() end
    if c == "-" or c == "." or c:match("%d") then return self:number() end
    local word = self.s:match("^%a+", self.pos)
    if word == "true" then self.pos = self.pos + 4 return true end
    if word == "false" then self.pos = self.pos + 5 return false end
    self:fail("unexpected '" .. (word or c) .. "'")
end

function Parser:table(depth)
    self:expect("{")
    local t, n = {}, 0
    while true do
        local c = self:peek()
        if c == "}" then self.pos = self.pos + 1 break end
        local key
        if c == "[" then
            self.pos = self.pos + 1
            local kc = self:peek()
            if kc == '"' then key = self:string() else key = self:number() end
            self:expect("]")
            self:expect("=")
        else
            local name = self.s:match("^[%a_][%w_]*", self.pos)
            if name and not RESERVED[name] then
                local after = self.s:match("^[ \t\r\n]*=", self.pos + #name)
                if after then
                    key = name
                    self.pos = self.pos + #name + #after
                end
            end
        end
        local v = self:value(depth)
        if key == nil then
            n = n + 1
            key = n
        end
        t[key] = v
        local sep = self:peek()
        if sep == "," or sep == ";" then
            self.pos = self.pos + 1
        elseif sep ~= "}" then
            self:fail("expected ',' or '}'")
        end
    end
    return t
end

-- Returns the value, or nil and an error message
function Save.decode(text)
    if type(text) ~= "string" then return nil, "save: no text" end
    if #text > Save.MAX_BYTES then return nil, "save: file too big" end
    local p = setmetatable({ s = text, pos = 1 }, Parser)
    local ok, result = pcall(function()
        local v = p:value(0)
        p:skip()
        if p.pos <= #text then p:fail("unexpected text after the end") end
        return v
    end)
    if ok then return result end
    if type(result) == "table" and result.saveError then return nil, result.saveError end
    return nil, "save: " .. tostring(result)
end

return Save
