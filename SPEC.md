# PocketGroove (Working Title) — Design & Technical Specification

**Target hardware:** Anbernic RG35XX Plus (Allwinner H700, ARM64 Linux, 1 GB RAM, 640×480 4:3 IPS, no touchscreen, **no analog sticks**)
**Engine:** LÖVE 11.5 via PortMaster (`gptokeyb` fallback), desktop PC for development
**Architecture:** headless domain engine (Input, Looper, Harmony, Synth, Instruments, Theory) + a 640×480 vector view (Chrome)

Companion: [ROADMAP.md](ROADMAP.md) says *in what order* this gets built.

> **Status legend:** ✅ implemented · 🔧 implemented but changing · 📐 designed, not built · ❓ open question

---

## 1. Design philosophy

1. **Playable without looking.** Every button has one clear job. Depth comes from *combining* simple controls, not from adding features to each control. The screen confirms what you did; it should not be required to do it.
2. **Same grammar on every track.** A button's *role* is the same on every instrument (§3). Learn it once.
3. **Zero-setup jamming.** The master loop is always rolling. Recording is a gesture, not a menu.
4. **Instrument ≠ sound.** An instrument is *how you play*. A sound is *what comes out*. They are chosen independently (§6).
5. **Four tracks, always visible.** The screen is sized for exactly four tracks. Tracks are *slots*; the instrument in a slot can be swapped (§7). Four is a fixed design limit.
6. **Hard to play a wrong note.** Pitched instruments play scale degrees, and can follow the chord track (§5).
7. **Look and feel together.** Each instrument pass includes its stage view in the shared visual template; the base look is set early and refined per instrument.
8. **Self-contained procedural audio.** All sounds are generated in RAM at boot. Optional `.wav` loading is a later milestone.

---

## 2. Hardware input abstraction ✅

All hardware maps to a virtual button table (`down`, `pressed`, `released`). Gamepad and keyboard are equivalent. On-device testing shows 8-way diagonals are reliable.

| Virtual | RG35XX Plus | SDL gamepad | Keyboard |
| :-- | :-- | :-- | :-- |
| `UP/DOWN/LEFT/RIGHT` | D-pad | `dp*` / left stick | `W S A D` |
| `B` (south) | bottom face | `a` | `J` / ↓ |
| `A` (east) | right face | `b` | `K` / → |
| `Y` (west) | left face | `x` | `U` / ← |
| `X` (north) | top face | `y` | `I` / ↑ |
| `L1` / `R1` | shoulders | `leftshoulder` / `rightshoulder` | `Q` / `E` |
| `L2` / `R2` | triggers | `triggerleft/right` axis, `leftstick/rightstick` | `Shift` / `Space` |
| `SELECT` | select | `back` | `Tab` |
| `START` | start | `start` | `Enter` |

---

## 3. Control grammar

### 3.1 Roles by physical zone ✅

| Zone | Role | Meaning |
| :-- | :-- | :-- |
| Right thumb `B A Y X` | **Trigger** | *What* plays and *when* |
| Left thumb D-pad | **Pitch / harmony / expression** | *Where* in pitch or harmony, or how hard the hit is |
| Shoulders `L1 R1` | **Register & density** | `L1` = lower / sparser, `R1` = higher / denser, both = a special "extra" |
| `L2` | **Record** | Latch or momentary (§4) |
| `R2` | **Performance** | Mutes and punch-in FX; with `L2` = erase |
| `SELECT` (hold) | **Track page = sound** | Sounds, settings, instrument and effects for the active track (§3.4) |
| `START` (hold) | **Transport = timing** | Tempo, key, scale, bars, and the active track's grid and swing (§3.5) |

**Rule:** a gesture may use at most two buttons plus the D-pad. No nested menus.

### 3.2 Instruments at a glance (target)

| Instrument | D-pad | `B A Y X` | `L1` | `R1` | `L1 + R1` |
| :-- | :-- | :-- | :-- | :-- | :-- |
| **Drums** ✅ | dynamics × articulation (§3.2a) | 4 pads | 1/4 repeat | 1/8 repeat | 1/16 repeat (1/12T on triplet grid) |
| **Chord Harp** 🔧 | 8 chords (§3.3) | strum / strings ❓ (§7.2) | voicing −1 oct | voicing +1 oct | wide voicing |
| **Bass** 🔧 | 8 degrees (1–8) | articulations (§7.3) | oct −1 | oct +1 | — ❓ |
| **Pad** 📐 | tone / movement | voicings + swell (§7.4) | oct −1 | oct +1 | — ❓ |
| **Lead / Arp** 📐 | 8 degrees | note + arp modes (§7.5) | oct −1 | oct +1 | arp rate ×2 |

Grain is retired as an instrument; its textures become **Pad sounds** (§6). Today the chord harp still uses `L1`/`R1` for 7th/9th and sus4/add9 — 🔧 these move to the Track page (§3.3).

### 3.2a Drums: the D-pad is two axes ✅

The D-pad modifies every hit while held. It is read as two independent axes so a slip into a diagonal still gives roughly what was meant; diagonals never have meanings of their own.

| Axis | ← / ↓ | → / ↑ |
| :-- | :-- | :-- |
| Vertical = **dynamics** | `DOWN` ghost (40 %, short) | `UP` accent (100 %, longer) |
| Horizontal = **articulation** | `LEFT` flam: grace note 28 ms before the hit | `RIGHT` ratchet: 3 hits inside one 1/16 (one triplet step on 1/12T) |

- Diagonals combine both axes (`UP+LEFT` = accented flam, `DOWN+RIGHT` = ghost ratchet).
- Flam and ratchet are stored on the event (`orn = "flam"`, `ratchet = 3`). On playback the flam's grace note fires just before the beat, so the main hit stays on the grid.
- Pad tuning moved off the D-pad (it was ±4 st) and will become a per-pad setting.
- **Note repeat (L1/R1)** is locked to the grid. A press within 45 ms of a tick plays at once and stands in for that tick, so it never doubles. A press further away waits for the next tick, and still plays there even if the pad is released first. Repeats follow the track's swing.
- **Choke:** closed hats cut a ringing open hat.
- **Display:** the face buttons stay unlabelled. The centre shows four lanes ordered like the button diamond (X, Y, A, B top to bottom), each with a mini diamond, the pad's sound and a step strip: bar height = dynamics, a tick before = flam, slivers = ratchet.

### 3.3 Chord map & colour

D-pad picks one of 8 chords from the current key: `↑`/neutral = I, `↖` ii, `↗` iii, `←` IV, `→` V, `↓` vi, `↙` ♭VII, `↘` iv (borrowed). ✅

- ❓ Neutral and `↑` both give I today. Option: neutral = *keep the last chord*, which makes releasing the D-pad safe.
- **Chord colour** (triad, 7th, 9th, sus4, add9) is a **Track page setting row** (§3.4), set once and left. 📐
- ❓ Momentary colour gesture for live variation. Decide after playtesting.

### 3.4 Track page = sound (hold `SELECT`) ✅ / 📐

The same layout on every instrument:

| Control | Job |
| :-- | :-- |
| `UP / DOWN` | Move the row cursor |
| `L1 / R1` | Previous / next value for the selected row (sounds play a preview) |
| `LEFT / RIGHT` | Previous / next instrument for this slot (§7) — 📐 preview, applied on `SELECT` release |
| Face tap | Effect on / off: `X` tone, `Y` drive, `A` echo, `B` space |
| Face hold + `UP / DOWN` | Effect amount (10 % steps) |
| `SELECT` tap (< 0.25 s, no combo) | Next track 1→4 |

**Rows** are the place every per-track option lives, so a new option costs a row, not a button. ✅ today: drums have `KIT, X, Y, A, B` (the kit row swaps all four sounds; a pad row swaps one); other instruments have a single `PATCH` row. The cursor opens on the **last pad you hit**, so "hit the snare, hold SELECT, press R1" swaps the snare.

📐 **Setting rows** are added below the sound rows; `L1/R1` change their value the same way:

| Instrument | Sound rows | Setting rows |
| :-- | :-- | :-- |
| Drums | `KIT, X, Y, A, B` | `VARIATION` (§7.1); ❓ per-pad tune / level |
| Chord Harp | `PATCH` | `COLOUR`, `STRUM` speed |
| Bass | `PATCH` | `FOLLOW`, `GLIDE` time |
| Pad | `PATCH` | `FOLLOW`, `ATTACK`, `RELEASE` |
| Lead / Arp | `PATCH` | `FOLLOW`, `ARP RATE`, `ARP PATTERN` |

Keep each instrument at ≤ 6 rows so the constellation fits without scrolling. Timing settings (grid, swing) stay on the Transport page.

📐 **Safe instrument swap:** `LEFT/RIGHT` only previews the next instrument; it is applied when `SELECT` is released. Applying stashes the old instrument, state and events on the undo stack, so **undo restores them**. Same-class swaps (Bass ↔ Lead, both mono-melodic) keep events, because v2 events store degrees (§8).

### 3.5 Transport = timing (hold `START`) ✅

| Control | Job |
| :-- | :-- |
| `UP / DOWN` | BPM ±5 (60–180) |
| `LEFT / RIGHT` | Key (root) |
| `L1 / R1` | Scale |
| `B` | Bars 2 / 4 |
| `A` | Grid for the active track (1/4 → 1/8 → 1/16 → 1/12T → FREE) |
| `Y` + `UP / DOWN` | Swing for the active track, 50–75 % in 2 % steps |
| `X` | Metronome click on / off |
| `START` tap | Play / pause; double tap = reset playhead to 1.1 |

BPM, key, scale and bars are global. Grid and swing belong to the active track and are drawn in its colour. ❓ Count-in: `X` hold, or a click mode (off / on / count-in)?

### 3.6 Other global combos ✅

| Combo | Action |
| :-- | :-- |
| `R2` + `B/A/Y/X` | Mute tracks 1/2/3/4 |
| `R2` + D-pad (hold) | Master punch-in FX: ↑ stutter, ↓ half-speed, ← duck (❓ → low-pass), → bitcrush |
| `SELECT + R2` | Mix page: `LEFT/RIGHT` track/master, `UP/DOWN` level, `B/A/Y/X` mutes, `L1/R1` master trim |
| `L2 + R2` + `B/A/Y/X` | Erase that pad/action on the active track |
| `L2 + R2` + `LEFT` or `L1` | Undo last take |
| `L2 + R2` + `START` | Clear active track |

🔧 Mix page level should change once per press (plus key repeat), not every frame.

---

## 4. Recording model ✅ / 📐

Hybrid **latch / momentary** on `L2` ✅:

- **Tap** `L2` (< 0.25 s, no other button used): toggle record on/off (latched).
- **Hold** `L2` (≥ 0.25 s): record only while held (momentary punch-in).
- Combos with `L2` never toggle the latch.
- The top bar always shows `REC (LATCHED)` / `REC (HOLD)` / `JAM SAFE`.

📐 Changes:

- **Takes split per loop pass** while latched, so undo removes one pass, not the whole session.
- **Held notes** record their length and bends (§8); a note still held at the loop seam is handled cleanly.
- ❓ Replace vs overdub toggle. ❓ Auto-stop after one pass.

---

## 5. Harmony: the chord track & chord-follow 📐

There is always a **current chord** at every point in the loop. A small `Harmony` module resolves it:

1. If a track holds a **Chord Harp** with recorded chord events, the current chord is the most recent chord at that loop position (wrapping around the loop). If several tracks are chord harps, the lowest-numbered one is the **chord source**.
2. Otherwise the current chord is the **tonic** (I of the current key and scale).

So nothing depends on recording chords first: with no chord track, followers simply play in the key.

**Followers** (Bass, Pad, Lead/Arp) have a **FOLLOW** setting row (Track page, default **on**):

- **On:** a note's stored *degree* is played relative to the current chord at playback time. Adding or changing chords later re-harmonises lines already recorded.
- **Off:** the note's stored *absolute pitch* is played, exactly as recorded.

Live playing uses the same rule, so what you hear while playing is what replays.

Mapping (follow on): degree 1 = chord root, 3 = chord third, 5 = chord fifth; other degrees walk the scale from the chord root. ❓ Tune after playtesting (e.g. borrowed chords).

Erasing or swapping away the chord source makes followers fall back to the tonic; nothing breaks.

---

## 6. Sounds: instruments vs sound pools

| | **Instrument** (controller) | **Sound** (voice) |
| :-- | :-- | :-- |
| Defines | button/D-pad mapping, stage view, event format | the audio that plays |
| Chosen on | Track page `LEFT/RIGHT` | Track page sound rows, `L1/R1` |

Two shared pools:

1. **One-shot pool** — drum hits, perc, FX. Any drum pad can hold any one-shot. ✅ 24-sound catalogue and six kits (808 Classic, 909 House, Lo-Fi, Acoustic, Latin, Industrial; a changed pad marks the kit with `*`).
2. **Pitched patch pool** 📐 — each patch has a *one-shot* form and a *sustain* form (§9.2). Shared by Chord Harp, Bass, Pad and Lead/Arp. Initial patches: Rhodes-ish, pluck/harp, saw bass, sub, square lead, warm pad, glass bell, choir, drone (the last four from the old Grain textures).

Goal: swapping the patch changes how the part sits with the drums **without changing how you play it**.

---

## 7. Instruments

Four slots, default **1 Drums · 2 Chord Harp · 3 Bass · 4 Pad**. The library: Drums, Chord Harp, Bass, Pad, Lead/Arp. Each must be a *different way of playing*, not a different sound.

### 7.1 Drums ✅ / 📐

- ✅ 4 pads; D-pad dynamics × articulation (§3.2a); grid-locked repeat; hat choke; kits; swing; four-lane view.
- 📐 **Variation** row (Off / Light / Wild): on playback, small velocity jitter; at Wild, occasional timing nudge and fill hits on empty steps. Applied at playback time, so the recorded pattern is never altered.
- 📐 **Chance hits:** events carry `chance` (0–1). ❓ Gesture — proposal: a *ghost* hit recorded while Variation ≠ Off gets `chance = 0.5`.
- 📐 Per-pad tune and level ❓ (rows, or a pad sub-row).

### 7.2 Chord Harp 🔧

- ✅ 8 chords on the D-pad; 4 face buttons pluck chord tones.
- 📐 **Strum** — the signature gesture. Proposal ❓: `B` strum down, `A` strum up (all chord tones, spread by the `STRUM` row), `Y` low string / root, `X` high string. Decide after playtesting.
- 📐 Shoulders = voicing octave; both = wide voicing (colour moves to the `COLOUR` row).
- 📐 Records `chord` events that drive Harmony (§5).

### 7.3 Bass 🔧 — *next instrument pass*

- ✅ D-pad = scale degrees 1–8; `L1/R1` = octave.
- 📐 **Sustained notes:** a note sounds while its button is held and releases on button-up (needs §9.2).
- 📐 Face buttons = articulations only: `B` normal (held), `A` glide/legato from previous note, `Y` short staccato, `X` accent with vibrato. ❓ (Today `Y`/`X` are +octave/+fifth, which mixes *which note* with *how*.)
- 📐 Moving the D-pad while holding a note **bends** to the new degree (glide); recorded as `bend` keyframes.
- 📐 Follows chords (§5). Rows: `PATCH`, `FOLLOW`, `GLIDE`.

### 7.4 Pad 📐 (replaces Grain)

- Holds the current chord as a sustained voicing.
- `B` full chord, `A` open (root + fifth), `Y` high voicing, `X` swell (slow attack). Notes sustain while held.
- D-pad: `↑/↓` brightness (crossfade between a dark and a bright layer of the patch), `←/→` movement (detune / shimmer depth).
- Rows: `PATCH`, `FOLLOW`, `ATTACK`, `RELEASE`.

### 7.5 Lead / Arp 📐

- D-pad = degree (relative to the current chord when following).
- `B` single note (held). `A` arp up, `Y` arp down, `X` up-down (arp runs while held, at `ARP RATE`, locked to the clock and the track's swing). ❓ arp latch.
- `L1/R1` octave; `L1 + R1` = arp rate ×2 while held.
- Rows: `PATCH`, `FOLLOW`, `ARP RATE` (1/8, 1/16, 1/8T), `ARP PATTERN` / range.
- Same class as Bass (mono-melodic), so swaps between them keep events.

### 7.6 Parked ideas

- Sample chop instrument (needs `.wav` loading; not planned).
- Separate Perc/FX instrument — superseded by Drums Variation.

---

## 8. Looper & events

### 8.1 Timing ✅ / 🔧

- Loop is **2 or 4 bars** of 4/4. Per-track quantize grid: `1/4`, `1/8`, `1/16`, `1/12T`, `FREE`. ✅
- Per-track **swing** ✅ applied at playback to odd 8ths/16ths (by the event's grid), so it can change after recording; live repeats follow it.
- 🔧 **Clock from absolute time:** the playhead is derived from `love.timer.getTime()` since the last loop anchor, not accumulated clamped `dt`, so frame drops never slow the tempo.
- 🔧 **Integer ticks:** positions are stored as ticks at **96 PPQN** (2 bars = 768 ticks; 4 bars = 1536). Snapping, dedup, 2↔4 bar toggling, triplets and swing offsets become exact integer maths. `phase` remains a derived value for drawing.

### 8.2 Event format v2 📐

```lua
Event = {
  tick     = 192,          -- start position (96 PPQN)
  len      = 48,           -- held length in ticks (0 = one-shot hit)
  grid     = 24,           -- grid step it was snapped to (for swing), nil = FREE
  action   = "B",          -- which button
  vel      = 0.85,
  chance   = 1.0,          -- probability of playing (drums Variation)
  takeId   = 3,

  -- pitched instruments only
  degree   = 5,            -- D-pad degree (1..8)
  octave   = 0,            -- shoulder octave offset
  semis    = 7,            -- absolute pitch at record time (used when FOLLOW = off)
  chordRef = "V",          -- chord that was current at record time (display)
  bend     = { {dt = 12, degree = 6} },  -- keyframes while held (ticks after start)

  -- drums only
  soundId  = "kick_808",
  orn      = "flam", ratchet = 3, decay = 1.0,

  -- chord harp only
  chord    = { roman = "V", colour = "7" },
}
```

- Track-level fields (`instrumentId`, `trackSlot`) live on the track, not on each event.
- Continuous textures record **notes with length**, never a stream of grains. One held pad chord = one event.
- Playback: note-on at `tick` (+ swing), note-off at `tick + len` (wrapping), bend keyframes applied in between.
- Saved files store events as-is plus a `version` field (§10).

---

## 9. Audio engine

### 9.1 Current ✅

- 44.1 kHz, 16-bit mono `SoundData` generated at boot; pools of cloned `Source`s for polyphony; voice stealing.
- Live FX: beat repeat, half-speed, duck, bitcrush-style pitch quantize.

### 9.2 Sustained voices 📐

- Each pitched patch is generated as an **attack layer** (one-shot) plus a **seamless loop layer** (whole number of cycles, so `setLooping(true)` is click-free).
- A voice = attack + loop sources with an envelope (attack / release, and crossfade for Pad brightness) driven in `Synth:update` via `setVolume`; pitch and glide via `setPitch`. Voices route through the track's effects like one-shots do.
- API: `Synth:noteOn(patch, semis, vel, opts) → voice`, `voice:setPitch(semis)`, `voice:noteOff()`. One-shots keep using `Synth:trigger`.

### 9.3 Effects & mix

- ✅ Per-track and master volume.
- ✅ **Per-track FX** (set-and-forget, Track page): tone = low-pass filter on each voice; drive (distortion), echo and space (reverb) = per-track OpenAL EFX sends. Without EFX, drive falls back to a gain push. ❓ Check EFX support and CPU cost on the RG35XX.
- ✅ Swing per track (§8.1). 📐 Humanize = Drums Variation (§7.1).
- 📐 Real low-pass for the master `R2 + ←` FX, using the same filter as tone.

---

## 10. Persistence 📐

- **Autosave** on quit and every ~30 s: BPM, key, scale, bars, click, and each track's instrument, sounds, settings, FX, swing, grid, mute, level and events. Versioned file via `love.filesystem`; loaded on start.
- Later: named **patterns** (A–H) and a simple chain = "song". ❓ Exact definition.
- Later ❓: export the loop to `.wav`.

---

## 11. UI layout (640×480) 🔧

1. **Top bar:** active track + instrument, grid, bars, BPM, key/scale, current chord (📐), beat stars, mode badge.
2. **Center stage:** one fixed template — shoulder badges top, D-pad left, face buttons right, instrument display middle, hint strip bottom. Track page, Transport and Mix draw over the stage.
3. **Tape deck:** four tracks with name, grid, mute, event markers and a shared playhead. 📐 Hits as beads, held notes as ribbons with bend lines, chord names along the chord-source lane.

Principles: show mode in the same place always; hints for the held modifier only; colour-code tracks consistently and add shape cues so colour is never the only signal.

**One colour per page** ✅. While playing, the instrument's colour owns the stage. On a settings page the mode colour replaces it on the frame (with a soft glow), badge, footer, D-pad, face rings, shoulders and selection; the only track colour left is a small identity capsule. Mode colours avoid the track colours:

| Page | Colour | Motif |
| :-- | :-- | :-- |
| Play | instrument colour | the instrument's own decorations |
| Recording | crimson `#FB7185` (frame, badge, footer, playhead only) | — |
| Track page (sound) | sakura pink `#F9A8D4` | constellation of rows, moon-phase effect gauges |
| Transport (timing) | solar gold `#FCD34D` | astrolabe: circle-of-fifths key ring with scale arc, grid ticks that show swing, loop hand |
| Mix / Live FX | moon silver `#DCE3F5` | — |
| Erase | crimson with a tinted frame | — |

The tape deck dims while a settings page is open. 📐 Pad and Lead/Arp need instrument colours that stay distinct from the page colours (Pad can inherit Grain's mint).

---

## 12. Code layout

```text
pockimusi/
 ├── SPEC.md  ROADMAP.md
 ├── PocketGroove.sh            # PortMaster launcher
 ├── build.py                   # packs pocketgroove/PocketGroove.love
 ├── tests/                     # Lua tests: python3 tests/run.py (needs `pip install lupa`) or luajit tests/run.lua
 └── pocketgroove/
      ├── main.lua  conf.lua  controls.gptk
      └── src/
           config.lua  theory.lua  input.lua  looper.lua  harmony.lua (📐)  modes.lua
           instruments/{init,drums,harp,bass,pad,lead}.lua   (grain.lua retired)
           synth/{init,voice (📐),drums_bank,synths_bank}.lua
           ui/chrome.lua
```

Global modes and combos live in `modes.lua` (`Modes.current` is read by the UI); `main.lua` only wires the LÖVE callbacks.

---

## 13. Open questions

1. Chord Harp face buttons: strum down/up + strings, or keep 4 strings? (§7.2)
2. Neutral D-pad on the harp: tonic, or keep last chord? (§3.3)
3. Bass face-button articulations — confirm after playtest. (§7.3)
4. Chord-follow degree mapping details, especially on borrowed chords. (§5)
5. Gesture for recording drum chance hits. (§7.1)
6. Per-pad tune and level for drums: where on the Track page? (§7.1)
7. Arp latch? (§7.5)
8. Count-in control on the Transport page. (§3.5)
9. Replace vs overdub; auto-stop after one pass. (§4)
10. EFX support and CPU cost on the RG35XX. (§9.3)
11. What exactly is a "song"? (§10)
