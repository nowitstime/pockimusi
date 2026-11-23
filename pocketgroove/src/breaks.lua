-- ============================================================================
-- src/breaks.lua — The break library (PHASE_L.md L8)
--
-- Famous drum breaks, transcribed by ear onto a 1/16 grid and played on our
-- own synthesised kits: no recording is used. Each break is one or two bars
-- of hits { step, role, vel }: step = 1/16 steps from the start (0..15 for
-- one bar, 0..31 for two), role = a part of the kit (below), vel = 0..1.
-- `late` (optional, ticks) nudges a hit behind the grid, the way a drummer
-- lays back.
--
-- Roles: kick, snare, ghost (a soft snare), hat, hat_open, pedal, ride,
-- crash, perc1, perc2. A kit says which sound plays each role, with an
-- optional tune and level, so a break isn't tied to four pads.
-- ============================================================================

local Breaks = {}

Breaks.ROLES = { "kick", "snare", "ghost", "hat", "hat_open", "pedal", "ride", "crash", "perc1", "perc2" }
Breaks.STEP_TICKS = 120          -- a 1/16 at 480 PPQN
Breaks.BAR_TICKS = 1920
Breaks.SLICES = 8                -- the D-pad's eight directions

-- Build a hit list from per-role strings, one character per 1/16:
--   X = loud (0.95), x = normal (0.8), o = soft (0.55), g = ghost (0.4), . = rest
local LEVELS = { X = 0.95, x = 0.8, o = 0.55, g = 0.4 }
local function grid(rows)
    local hits = {}
    for role, line in pairs(rows) do
        local step = 0
        for ch in line:gmatch("%S") do
            if ch ~= "|" then
                if LEVELS[ch] then hits[#hits + 1] = { step = step, role = role, vel = LEVELS[ch] } end
                step = step + 1
            end
        end
    end
    table.sort(hits, function(a, b)
        if a.step ~= b.step then return a.step < b.step end
        return a.role < b.role
    end)
    return hits
end

-- The breaks, in the order of the BREAK row. Bars are separated with | for
-- reading; every line of a break must have the same number of steps.
Breaks.LIST = {
    { id = "two_step", name = "TWO STEP", bars = 1, kit = "FUNK BREAKS",
      -- the plain drum and bass beat: kick on 1 and the "and" of 3, snare on 2 and 4
      hits = grid({
          kick  = "X . . . . . . . . . x . . . . .",
          snare = ". . . . X . . . . . . . X . . .",
          ghost = ". . . . . . . g . . . . . . . g",
          hat   = "x . o . x . o . x . o . x . o .",
      }) },
    { id = "amen", name = "AMEN", bars = 2, kit = "FUNK BREAKS",
      -- the jungle break: ride on the eighths, snares that skip around beat 3,
      -- a crash near the end of the second bar
      hits = grid({
          kick  = "X . x . . . . . . . x x . . . . | X . x . . . . . . . x . . . . .",
          snare = ". . . . X . . o . o . . X . . o | . . . . X . . o . o . . . . X .",
          ride  = "x . x . x . x . x . x . x . x . | x . x . x . x . x . x . x . x .",
          crash = ". . . . . . . . . . . . . . . . | . . . . . . . . . . X . . . . .",
      }) },
    { id = "think", name = "THINK", bars = 2, kit = "FUNK BREAKS",
      -- busy, shuffly sixteenth hats with an open hat before the backbeat
      hits = grid({
          kick     = "X . . x . . . . . . x . . . . . | X . . . . . . . . . x x . . . .",
          snare    = ". . . . X . g . . g . . X . . g | . . . . X . . g . . . . X g . .",
          hat      = "x o x o x o . o x o x o x o . o | x o x o x o x o x o x o x o . o",
          hat_open = ". . . . . . x . . . . . . . x . | . . . . . . . . . . . . . . x .",
      }) },
    { id = "funky_drummer", name = "FUNKY DRUMMER", bars = 1, kit = "FUNK BREAKS",
      -- ghost notes everywhere and an open hat flicked in
      hits = grid({
          kick     = "X . x . . . . . . . x . . x . .",
          snare    = ". . . . X . . . . . . . X . . .",
          ghost    = ". . . . . . . g . g . g . . . g",
          hat      = "x o x o x o . o x o x o x o . o",
          hat_open = ". . . . . . x . . . . . . . x .",
      }) },
    { id = "apache", name = "APACHE", bars = 2, kit = "LATIN BREAKS",
      -- bongos over a straight kick and snare, tambourine on the off-beats
      hits = grid({
          kick  = "X . . . . . . . X . x . . . . . | X . . . . . . . X . x . . . . .",
          snare = ". . . . X . . . . . . . X . . . | . . . . X . . . . . . . X . . .",
          hat   = ". . x . . . x . . . x . . . x . | . . x . . . x . . . x . . . x .",
          perc1 = ". . x x . . x . x . . x . . x . | . . x x . . x . x . . x . x x .",
          perc2 = "x . . . . . . x . . x . . x . . | x . . . . . . x . . x . . x . .",
      }) },
    { id = "hot_pants", name = "HOT PANTS", bars = 1, kit = "FUNK BREAKS",
      -- tight and funky, the foot on the hats keeping time
      hits = grid({
          kick  = "X . . x . . . . . . x . . . . .",
          snare = ". . . . X . g . . g . . X . g .",
          hat   = "x . x . x . x . x . x . x . x .",
          pedal = ". . o . . . o . . . o . . . o .",
      }) },
    { id = "cold_sweat", name = "COLD SWEAT", bars = 2, kit = "FUNK BREAKS",
      -- a laid-back backbeat with a ride and a pushed kick
      hits = grid({
          kick  = "X . . . . . . . x . x . . . . . | X . . . . . . . x . . x . . . .",
          snare = ". . . . X . . g . . . . X . . . | . . . . X . . g . . . . X . . g",
          ride  = "x . x . x . x . x . x . x . x . | x . x . x . x . x . x . x . x .",
          pedal = ". . . . x . . . . . . . x . . . | . . . . x . . . . . . . x . . .",
      }) },
}

Breaks.byId = {}
for _, b in ipairs(Breaks.LIST) do
    Breaks.byId[b.id] = b
    b.ticks = b.bars * Breaks.BAR_TICKS
end

-- Kits: which sound plays each role. { sound, tune (semitones), vel (level) }
Breaks.KITS = {
    { name = "FUNK BREAKS", roles = {
        kick = { "kick_acoustic" }, snare = { "snare_funk" }, ghost = { "snare_funk", 0, 0.9 },
        hat = { "hat_acoustic" }, hat_open = { "hat_half" }, pedal = { "hat_pedal" },
        ride = { "cym_ride_ac" }, crash = { "cym_crash_ac" }, perc1 = { "perc_tamb" }, perc2 = { "tom_low" } } },
    { name = "JUNGLE", roles = {
        -- sped-up chopped breaks: a tighter, higher snare and a booming kick
        kick = { "kick_808", 0, 0.9 }, snare = { "snare_funk", 3 }, ghost = { "snare_funk", 3, 0.9 },
        hat = { "hat_acoustic", 2 }, hat_open = { "hat_half", 2 }, pedal = { "hat_pedal" },
        ride = { "cym_ride_ac", 1 }, crash = { "cym_crash_ac" }, perc1 = { "fx_revsnare" }, perc2 = { "tom_high" } } },
    { name = "LATIN BREAKS", roles = {
        kick = { "kick_acoustic" }, snare = { "snare_funk" }, ghost = { "snare_funk", 0, 0.9 },
        hat = { "perc_tamb", 0, 0.8 }, hat_open = { "hat_half" }, pedal = { "hat_pedal" },
        ride = { "cym_ride_ac" }, crash = { "cym_crash_ac" }, perc1 = { "bongo_high" }, perc2 = { "bongo_low" } } },
    { name = "NEURO", roles = {
        kick = { "kick_909" }, snare = { "snare_gated" }, ghost = { "snare_tight", 0, 0.8 },
        hat = { "hat_tick" }, hat_open = { "hat_open" }, pedal = { "hat_tick", -2 },
        ride = { "cym_ride" }, crash = { "cym_crash" }, perc1 = { "fx_zap" }, perc2 = { "perc_tom" } } },
    { name = "808", roles = {
        kick = { "kick_808" }, snare = { "snare_analog" }, ghost = { "snare_analog", 0, 0.9 },
        hat = { "hat_closed" }, hat_open = { "hat_open" }, pedal = { "hat_tick" },
        ride = { "cym_ride" }, crash = { "cym_crash" }, perc1 = { "clap_studio" }, perc2 = { "perc_cowbell" } } },
    { name = "LO-FI", roles = {
        kick = { "kick_lofi" }, snare = { "snare_lofi" }, ghost = { "snare_lofi", 0, 0.9 },
        hat = { "hat_tick" }, hat_open = { "hat_half", -2 }, pedal = { "hat_pedal" },
        ride = { "cym_ride_ac", -2 }, crash = { "cym_crash_ac", -3 }, perc1 = { "perc_snap" }, perc2 = { "perc_wood" } } },
}

Breaks.kitByName = {}
for _, k in ipairs(Breaks.KITS) do Breaks.kitByName[k.name] = k end

-- The sound, tune and level for a role in a kit (a missing role plays as the snare)
function Breaks.roleSound(kit, role)
    local r = kit.roles[role] or kit.roles.snare
    return r[1], r[2] or 0, r[3] or 1.0
end

-- The hits of a break as { tick, role, vel }, sorted, with the swing pushing
-- odd 1/16 steps late (0.5 = straight .. 0.75 = heavy)
function Breaks.hitTicks(brk, swing)
    local out = {}
    local push = ((swing or 0.5) - 0.5) * 2.0 * Breaks.STEP_TICKS
    for i, h in ipairs(brk.hits) do
        local t = h.step * Breaks.STEP_TICKS + (h.late or 0)
        if h.step % 2 == 1 then t = t + push end
        out[i] = { tick = t, role = h.role, vel = h.vel }
    end
    table.sort(out, function(a, b) return a.tick < b.tick end)
    return out
end

-- For tools/render.py: the break played straight for `loops` passes at
-- `bpm` on a kit, as { time (s), sound, vol, semis } lists
function Breaks.renderHits(id, kitName, bpm, loops)
    local brk = Breaks.byId[id] or Breaks.LIST[1]
    local kit = Breaks.kitByName[kitName or brk.kit] or Breaks.KITS[1]
    local secPerTick = 60.0 / bpm / 480
    local out = {}
    for pass = 0, (loops or 2) - 1 do
        for _, h in ipairs(Breaks.hitTicks(brk, 0.5)) do
            local sound, tune, level = Breaks.roleSound(kit, h.role)
            out[#out + 1] = { (pass * brk.ticks + h.tick) * secPerTick, sound, h.vel * level, tune }
        end
    end
    return out
end

return Breaks
