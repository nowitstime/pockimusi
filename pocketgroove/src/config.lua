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
        BG         = { 0x12 / 255, 0x13 / 255, 0x16 / 255, 1.0 }, -- #121316
        PANEL      = { 0x1B / 255, 0x1D / 255, 0x22 / 255, 1.0 }, -- #1B1D22
        PANEL_HI   = { 0x25 / 255, 0x28 / 255, 0x30 / 255, 1.0 }, -- #252830
        GRID       = { 0x2E / 255, 0x32 / 255, 0x3C / 255, 1.0 }, -- #2E323C
        TEXT       = { 0xF4 / 255, 0xF4 / 255, 0xF6 / 255, 1.0 }, -- #F4F4F6
        MUTED      = { 0x8A / 255, 0x8F / 255, 0x9E / 255, 1.0 }, -- #8A8F9E
        DIM        = { 0x4B / 255, 0x50 / 255, 0x5E / 255, 1.0 }, -- #4B505E
        ORANGE     = { 0xFF / 255, 0x5E / 255, 0x36 / 255, 1.0 }, -- #FF5E36 (Drums / Rec)
        CYAN       = { 0x38 / 255, 0xBD / 255, 0xF8 / 255, 1.0 }, -- #38BDF8 (Chord Harp)
        VIOLET     = { 0xA7 / 255, 0x8B / 255, 0xFA / 255, 1.0 }, -- #A78BFA (Ribbon Bass)
        MINT       = { 0x34 / 255, 0xD3 / 255, 0x99 / 255, 1.0 }, -- #34D399 (Granular Pad)
        AMBER      = { 0xFB / 255, 0xBF / 255, 0x24 / 255, 1.0 }, -- #FBBF24 (FX / Accent)
        RED        = { 0xF8 / 255, 0x71 / 255, 0x71 / 255, 1.0 }, -- #F87171 (Erase / Mute)
    }
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
