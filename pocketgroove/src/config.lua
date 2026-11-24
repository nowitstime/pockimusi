-- ============================================================================
-- src/config.lua — Hardware Constants, Color Palette & Math Utilities
-- ============================================================================

local math_pi = math.pi

local Config = {
    SCREEN_W = 640,
    SCREEN_H = 480,
    SAMPLE_RATE = 44100,
    DEFAULT_BPM = 115,
    MIN_BPM = 60,
    MAX_BPM = 240,
    TWO_PI = math_pi * 2.0,

    -- Test screens: with this off, every instrument marked `dev = true`
    -- (the FINGERS screen) leaves the catalogue
    DEV_TOOLS = true,

    COLORS = {
        BG         = { 0x08 / 255, 0x08 / 255, 0x0B / 255, 1.0 }, -- #08080B (near-black ground)
        PANEL      = { 0x11 / 255, 0x11 / 255, 0x16 / 255, 1.0 }, -- #111116 (panel)
        PANEL_HI   = { 0x1B / 255, 0x1B / 255, 0x22 / 255, 1.0 }, -- #1B1B22 (raised panel)
        GRID       = { 0x2A / 255, 0x2A / 255, 0x35 / 255, 1.0 }, -- #2A2A35 (hairlines)
        TEXT       = { 0xF2 / 255, 0xF5 / 255, 0xFC / 255, 1.0 }, -- #F2F5FC (Pure Starlight)
        MUTED      = { 0x9A / 255, 0x98 / 255, 0xAE / 255, 1.0 }, -- #9A98AE (muted text)
        DIM        = { 0x4A / 255, 0x48 / 255, 0x58 / 255, 1.0 }, -- #4A4858 (dim marks)
        ORANGE     = { 0xFF / 255, 0x6B / 255, 0x4A / 255, 1.0 }, -- #FF6B4A (Sunset Ember / Rec / Drums)
        CYAN       = { 0x38 / 255, 0xBD / 255, 0xF8 / 255, 1.0 }, -- #38BDF8 (Moonlight Azure / Chord Harp)
        VIOLET     = { 0xB8 / 255, 0x9B / 255, 0xFA / 255, 1.0 }, -- #B89BFA (Nebula Lavender / Bass)
        MINT       = { 0x4E / 255, 0xE1 / 255, 0xA0 / 255, 1.0 }, -- #4EE1A0 (Aurora Mint / Grain Pad)
        AMBER      = { 0xFC / 255, 0xD3 / 255, 0x4D / 255, 1.0 }, -- #FCD34D (Golden Star / Mix / Accent)
        RED        = { 0xFB / 255, 0x71 / 255, 0x85 / 255, 1.0 }, -- #FB7185 (Sakura Crimson / Rec / Erase / Mute)
        PINK       = { 0xF9 / 255, 0xA8 / 255, 0xD4 / 255, 1.0 }, -- #F9A8D4 (Sakura Blossom / Track Sound page)
        SILVER     = { 0xDC / 255, 0xE3 / 255, 0xF5 / 255, 1.0 }, -- #DCE3F5 (Moon Silver / Mix & Live FX)
    }
}

-- One colour per page. On a settings page the mode colour replaces the
-- instrument colour everywhere except a small track-identity capsule.
Config.MODE_COLORS = {
    REC_LATCH = Config.COLORS.RED,
    REC_HOLD  = Config.COLORS.RED,
    TRACK     = Config.COLORS.PINK,
    TRANSPORT = Config.COLORS.AMBER,  -- solar gold
    MIX       = Config.COLORS.SILVER,
    FX        = Config.COLORS.SILVER,
    ERASE     = Config.COLORS.RED,
    NEW       = Config.COLORS.RED,
}

-- Each instrument's own colour, grouped by family: rhythm warm, chords cool
-- and gold, bass violet, leads pink / lilac / periwinkle / champagne, texture mint.
-- The stage, top bar and tape deck take the colour of the instrument in the
-- slot (Chrome:trackColor); TRACK_COLORS is the fallback for an unknown one.
local function hex(h)
    return { tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255, 1.0 }
end
Config.INST_COLORS = {
    drums = hex("FF5D5D"), hands = hex("FF9548"), breaks = hex("FFB347"),
    harp = hex("4DB6FF"), lane = hex("FFD84D"), strum = hex("38D9C6"),
    bass = hex("A07CFF"), roller = hex("7C6CFF"), wobble = hex("C46CFF"),
    lead = hex("FF7AC6"), dial = hex("D59BFF"), slide = hex("7FA6FF"), valves = hex("FFE9C2"),
    pad = hex("5CE3A0"),
    fingers = hex("DCE3F5"),
}

-- A colour at strength k over black, for flat dark fills: 0.12 = the stage
-- behind an instrument, 0.5 = a quiet line, 1 = the colour itself
local shadeCache = setmetatable({}, { __mode = "k" })
function Config.shade(c, k)
    local row = shadeCache[c]
    if not row then
        row = {}
        shadeCache[c] = row
    end
    local key = math.floor(k * 100 + 0.5)
    local s = row[key]
    if not s then
        local b = Config.COLORS.BG
        k = key / 100
        s = { b[1] + (c[1] - b[1]) * k, b[2] + (c[2] - b[2]) * k, b[3] + (c[3] - b[3]) * k, 1.0 }
        row[key] = s
    end
    return s
end

Config.TRACK_COLORS = {
    Config.COLORS.ORANGE,
    Config.COLORS.CYAN,
    Config.COLORS.VIOLET,
    Config.COLORS.MINT,
}

function Config.clamp(x, lo, hi)
    if x < lo then return lo end
    if x > hi then return hi end
    return x
end

function Config.tanh_approx(x)
    if x > 3.0 then return 1.0 end
    if x < -3.0 then return -1.0 end
    local x2 = x * x
    return x * (27.0 + x2) / (27.0 + 9.0 * x2)
end

return Config
