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
    MAX_BPM = 180,
    TWO_PI = math_pi * 2.0,

    COLORS = {
        BG         = { 0x09 / 255, 0x0A / 255, 0x0F / 255, 1.0 }, -- #090A0F (Obsidian Space)
        PANEL      = { 0x0F / 255, 0x12 / 255, 0x1B / 255, 1.0 }, -- #0F121B (Deep Space Panel)
        PANEL_HI   = { 0x16 / 255, 0x1B / 255, 0x28 / 255, 1.0 }, -- #161B28 (Astral Highlight)
        GRID       = { 0x22 / 255, 0x29 / 255, 0x3C / 255, 1.0 }, -- #22293C (Starlight Wireframe Line)
        TEXT       = { 0xF2 / 255, 0xF5 / 255, 0xFC / 255, 1.0 }, -- #F2F5FC (Pure Starlight)
        MUTED      = { 0x7E / 255, 0x88 / 255, 0xA4 / 255, 1.0 }, -- #7E88A4 (Stardust Muted)
        DIM        = { 0x34 / 255, 0x3C / 255, 0x52 / 255, 1.0 }, -- #343C52 (Cosmic Dim)
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
