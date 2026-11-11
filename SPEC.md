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
| `SELECT` (hold) | **Track page** | Per-track settings for the active track (§3.4) |
| `START` (hold) | **Transport** | Tempo, key, scale, loop length (§3.5) |

**Rule:** a gesture may use at most two buttons plus the D-pad. No nested menus. Settings live in one flat list per page.

### 3.2 Instruments at a glance (target)

| Instrument | D-pad | `B A Y X` | `L1` | `R1` | `L1 + R1` |
| :-- | :-- | :-- | :-- | :-- | :-- |
| **Drums** ✅ | expression: ↑ accent, ↓ ghost, ←/→ pitch | 4 pads | 1/4 repeat | 1/8 repeat | 1/16 repeat (1/12T on triplet grid) |
| **Chord Harp** 🔧 | 8 chords (§3.3) | strum / strings ❓ (§7.2) | voicing −1 oct | voicing +1 oct | wide voicing |
| **Bass** 🔧 | 8 degrees (1–8) | articulations (§7.3) | oct −1 | oct +1 | — ❓ |
| **Pad** 📐 | tone / movement | voicings + swell (§7.4) | oct −1 | oct +1 | — ❓ |
| **Lead / Arp** 📐 | 8 degrees | note + arp modes (§7.5) | oct −1 | oct +1 | arp rate ×2 |

Grain is retired as an instrument; its textures become **Pad sounds** (§6).

### 3.3 Chord map & colour

D-pad picks one of 8 chords from the current key: `↑`/neutral = I, `↖` ii, `↗` iii, `←` IV, `→` V, `↓` vi, `↙` ♭VII, `↘` iv (borrowed). ✅

- ❓ Neutral and `↑` both give I today. Option: neutral = *no chord change* (keep last chord), freeing nothing but making releases safe.
- **Chord colour** (triad, 7th, 9th, sus4, add9) is a **Track page setting** (§3.4), set once and left. 📐 Today `L1/R1` still add 7th/9th and sus4 — 🔧 these move to the Track page so shoulders follow the register rule.
- ❓ Momentary colour gesture for live variation. Decide after playtesting.

### 3.4 Track page (hold `SELECT`) 🔧

A **flat settings list** for the active track, drawn over the center stage while `SELECT` is held. This is where all per-track options live, so new options cost a row, not a button.

| Control | Action |
| :-- | :-- |
| `UP / DOWN` | Choose a row |
| `LEFT / RIGHT` | Change that row's value |
| `L1 / R1` | Quick previous / next **sound** (works on any row) |
| `B A Y X` | Drums: choose the pad that `Sound` edits. Other instruments: reserved |
| Release `SELECT` | Close; pending instrument change is applied (see below) |
| Tap `SELECT` (< 0.25 s, no combo) | Cycle active track 1→4 ✅ |

Rows (max ~6 so the list fits without scrolling):

| Row | Drums | Chord Harp | Bass | Pad | Lead / Arp |
| :-- | :-- | :-- | :-- | :-- | :-- |
| Instrument | ✓ | ✓ | ✓ | ✓ | ✓ |
| Sound | kit / pad sound | patch | patch | patch | patch |
| Grid | ✓ | ✓ | ✓ | ✓ | ✓ |
| Follow chords | — | — (it *is* the source) | ✓ | ✓ | ✓ |
| Instrument row 1 | Variation (§7.1) | Colour | Glide time | Attack | Arp rate |
| Instrument row 2 | Swing | Strum speed | Swing | Release | Arp pattern |

- **Instrument swap is safe:** `LEFT/RIGHT` on the Instrument row only *previews* the next instrument; it is applied when `SELECT` is released. Applying stashes the old instrument, state and events so **undo restores them**. 📐
- Same-class swaps (e.g. Bass ↔ Lead, both mono-melodic) keep events, because v2 events store degrees (§8). 📐

### 3.5 Transport (hold `START`) ✅

- `START` tap (on release, no combo): play/pause. Double-tap: reset playhead to 1.1.
- `START` + `UP/DOWN`: BPM ±5 (60–180).
- `START` + `RIGHT`: key. `START` + `LEFT`: scale.
- `START` + `B`: toggle 2 / 4 bars.
- 📐 `START` + `A`: metronome click on/off. `START` + `Y`: count-in on/off.

### 3.6 Other global combos ✅

| Combo | Action |
| :-- | :-- |
| `R2` + `B/A/Y/X` | Mute tracks 1/2/3/4 |
| `R2` + D-pad (hold) | Master punch-in FX: ↑ stutter, ↓ half-speed, ← duck (🔧 → low-pass), → bitcrush |
| `SELECT + R2` | Mix page: `LEFT/RIGHT` track/master, `UP/DOWN` level, `B/A/Y/X` mutes, `L1/R1` master trim |
| `L2 + R2` + `B/A/Y/X` | Erase that pad/action on the active track |
| `L2 + R2` + `LEFT` or `L1` | Undo last take |
| `L2 + R2` + `START` | Clear active track |

🔧 Mix page level changes once per press (plus key-repeat), not every frame.

---

## 4. Recording model ✅ / 📐

Hybrid **latch / momentary** on `L2` ✅:

- **Tap** `L2` (< 0.25 s, no other button used): toggle record on/off (latched).
- **Hold** `L2` (≥ 0.25 s): record only while held (momentary punch-in).
- Combos with `L2` never toggle the latch.
- The top bar always shows `REC (LATCHED)` / `REC (HOLD)` / `JAM SAFE`.

📐 Changes:

- **Takes split per loop pass** while latched, so undo removes one pass, not the whole session.
- **Held notes** record their length and bends (§8); a note still held at loop end wraps correctly.
- ❓ Replace vs overdub toggle. ❓ Auto-stop after one pass.

---

## 5. Harmony: the chord track & chord-follow 📐

There is always a **current chord** at every point in the loop. A small `Harmony` module resolves it:

1. If a track holds a **Chord Harp** with recorded chord events, the current chord is the most recent chord at that loop position (wrapping around the loop). If several tracks are chord harps, the lowest-numbered one is the **chord source**.
2. Otherwise the current chord is the **tonic** (I of the current key and scale).

So nothing depends on recording chords first: with no chord track, followers simply play in the key.

**Followers** (Bass, Pad, Lead/Arp) have a per-track **Follow chords** setting (Track page, default **on**):

- **On:** a note's stored *degree* is played relative to the current chord at playback time. Adding or changing chords later re-harmonises lines already recorded.
- **Off:** the note's stored *absolute pitch* is played, exactly as recorded.

Live playing uses the same rule, so what you hear while playing is what replays.

Mapping (follow on): D-pad degree 1 = chord root, 3 = chord third, 5 = chord fifth; other degrees walk the scale from the chord root. ❓ Tune after playtesting (e.g. snap off-scale borrowed chords).

Erasing or swapping away the chord source makes followers fall back to the tonic; nothing breaks.

---

## 6. Sounds: instruments vs sound pools 📐

| | **Instrument** (controller) | **Sound** (voice) |
| :-- | :-- | :-- |
| Defines | button/D-pad mapping, stage view, event format | the audio that plays |
| Chosen on | Track page *Instrument* row | Track page *Sound* row / `L1 R1` |

Two shared pools:

1. **One-shot pool** — drum hits, perc, FX. Any drum pad can hold any one-shot. ✅ (24-sound drum catalogue)
2. **Pitched patch pool** — each patch has a *one-shot* form and a *sustain* form (§9.2). Shared by Chord Harp, Bass, Pad and Lead/Arp. Initial patches: Rhodes-ish, pluck/harp, saw bass, sub, square lead, warm pad, glass bell, choir, drone (the last four from the old Grain textures).

**Kits:** a preset of four one-shots. Picking a kit is one `L1/R1` press. Per-pad overrides are saved with the track.

---

## 7. Instruments

Four slots, default **1 Drums · 2 Chord Harp · 3 Bass · 4 Pad**. The library: Drums, Chord Harp, Bass, Pad, Lead/Arp. Each must be a *different way of playing*, not a different sound.

### 7.1 Drums ✅ / 📐

- ✅ 4 pads; D-pad expression; shoulder repeats/rolls; per-pad sound.
- 📐 Kits (§6).
- 📐 **Variation** (Track page, Off / Light / Wild): on playback, small velocity jitter; at Wild, occasional timing nudge and fill hits on empty steps. Applied at playback time, so the recorded pattern is never altered.
- 📐 **Chance hits:** events carry `chance` (0–1). ❓ Gesture to record a chance hit — proposal: a *ghost* hit (D-pad ↓) recorded while Variation ≠ Off gets `chance = 0.5`.
- 📐 Swing (Track page).

### 7.2 Chord Harp 🔧

- ✅ 8 chords on the D-pad; 4 face buttons pluck chord tones.
- 📐 **Strum** — the signature gesture. Proposal ❓: `B` strum down, `A` strum up (all chord tones, spread by *Strum speed*), `Y` low string / root, `X` high string. Decide after playtesting.
- 📐 Shoulders = voicing octave; both = wide voicing (colour moves to the Track page).
- 📐 Records `chord` events that drive Harmony (§5).

### 7.3 Bass 🔧 — *next instrument pass*

- ✅ D-pad = scale degrees 1–8; `L1/R1` = octave.
- 📐 **Sustained notes:** a note sounds while its button is held and releases on button-up (needs §9.2).
- 📐 Face buttons = articulations only: `B` normal (held), `A` glide/legato from previous note, `Y` short staccato, `X` accent with vibrato. ❓ (Today `Y`/`X` are +octave/+fifth, which mixes *which note* with *how*.)
- 📐 Moving the D-pad while holding a note **bends** to the new degree (glide); recorded as `bend` keyframes.
- 📐 Follows chords (§5). Track page: Glide time, Swing.

### 7.4 Pad 📐 (replaces Grain)

- Holds the current chord as a sustained voicing.
- `B` full chord, `A` open (root + fifth), `Y` high voicing, `X` swell (slow attack). Notes sustain while held.
- D-pad: `↑/↓` brightness (crossfade between a dark and a bright layer of the patch), `←/→` movement (detune / shimmer depth).
- Track page: Attack, Release.

### 7.5 Lead / Arp 📐

- D-pad = degree (relative to the current chord when following).
- `B` single note (held). `A` arp up, `Y` arp down, `X` up-down (arp runs while held, at *Arp rate*, locked to the clock). ❓ arp latch.
- `L1/R1` octave; `L1 + R1` = arp rate ×2 while held.
- Track page: Arp rate (1/8, 1/16, 1/8T), Arp pattern / range.
- Same class as Bass (mono-melodic), so swaps between them keep events.

### 7.6 Parked ideas

- Sample chop instrument (needs `.wav` loading; not planned).
- Separate Perc/FX instrument — superseded by Drums Variation.

---

## 8. Looper & events

### 8.1 Timing ✅ / 🔧

- Loop is **2 or 4 bars** of 4/4. Per-track quantize grid: `1/4`, `1/8`, `1/16`, `1/12T`, `FREE`. ✅
- 🔧 **Clock from absolute time:** the playhead is derived from `love.timer.getTime()` since the last loop anchor, not accumulated clamped `dt`, so frame drops never slow the tempo.
- 🔧 **Integer ticks:** positions are stored as ticks at **96 PPQN** (one 2-bar loop = 768 ticks; 4 bars = 1536). Snapping, dedup, 2↔4 bar toggling and triplets become exact integer maths. `phase` remains a derived value for drawing.

### 8.2 Event format v2 📐

```lua
Event = {
  tick     = 192,          -- start position (96 PPQN)
  len      = 48,           -- held length in ticks (0 = one-shot hit)
  action   = "B",          -- which button
  vel      = 0.85,
  chance   = 1.0,          -- probability of playing (drums Variation)
  takeId   = 3,

  -- pitched instruments only
  degree   = 5,            -- D-pad degree (1..8)
  octave   = 0,            -- shoulder octave offset
  semis    = 7,            -- absolute pitch at record time (used when Follow = off)
  chordRef = "V",          -- chord that was current at record time (debug / display)
  bend     = { {dt = 12, degree = 6} },  -- keyframes while held (ticks after start)

  -- drums only
  soundId  = "kick_808",
  pitch    = 0, decay = 1.0,

  -- chord harp only
  chord    = { roman = "V", colour = "7" },
}
```

- Track-level fields (`instrumentId`, `trackSlot`) live on the track, not on each event.
- Continuous textures record **notes with length**, never a stream of grains. One held pad chord = one event.
- Playback: a note-on at `tick`, a note-off at `tick + len` (wrapping), bend keyframes applied in between.
- Saved files store events as-is plus a `version` field (§10).

---

## 9. Audio engine

### 9.1 Current ✅

- 44.1 kHz, 16-bit mono `SoundData` generated at boot; pools of cloned `Source`s for polyphony; voice stealing.
- Live FX: beat repeat, half-speed, duck, bitcrush-style pitch quantize.

### 9.2 Sustained voices 📐

- Each pitched patch is generated as an **attack layer** (one-shot) plus a **seamless loop layer** (whole number of cycles, so `setLooping(true)` is click-free).
- A voice = attack + loop sources with an envelope (attack / release, and crossfade for Pad brightness) driven in `Synth:update` via `setVolume`; pitch and glide via `setPitch`.
- API: `Synth:noteOn(patch, semis, vel, opts) → voice`, `voice:setPitch(semis)`, `voice:noteOff()`. One-shots keep using `Synth:trigger`.
- ❓ Later: real-time synthesis with `QueueableSource` for per-track filters — only if per-track DSP proves necessary and the H700 has the headroom.

### 9.3 Mix & FX 📐

- ✅ Per-track and master volume.
- 📐 Swing per track (applied at playback by delaying off-beat ticks).
- 📐 Per-track **Tone** (dark ↔ bright) via the patch layer crossfade.
- 📐 Real low-pass for the master `R2 + ←` FX (needs DSP; until then it stays a duck).

---

## 10. Persistence 📐

- **Autosave** on quit and every ~30 s: BPM, key, scale, bars, and each track's instrument, sound, settings, mute, level and events. Versioned file via `love.filesystem`; loaded on start.
- Later: named **patterns** (A–H) and a simple chain = "song". ❓ Exact definition.
- Later ❓: export the loop to `.wav`.

---

## 11. UI layout (640×480) 🔧

1. **Top bar:** active track + instrument, grid, bars, BPM, key/scale, current chord, beat stars, mode badge.
2. **Center stage:** one fixed template — shoulder badges top, D-pad left, face buttons right, instrument display middle, hint strip bottom. Track page and Mix page draw over the stage.
3. **Tape deck:** four tracks with name, grid, mute, event markers and a shared playhead. 📐 Hits as beads, held notes as ribbons with bend lines, chord names along the chord-source lane.

Principles: show mode in the same place always; hints for the held modifier only; colour-code tracks consistently and add shape cues so colour is never the only signal.

---

## 12. Code layout

```text
pockimusi/
 ├── SPEC.md  ROADMAP.md
 ├── PocketGroove.sh            # PortMaster launcher
 ├── build.py                   # packs pocketgroove/PocketGroove.love
 ├── test_looper_logic.py       # to be replaced by tests that run the real Lua
 └── pocketgroove/
      ├── main.lua  conf.lua  controls.gptk
      └── src/
           config.lua  theory.lua  input.lua  looper.lua  harmony.lua (📐)  modes.lua (📐)
           instruments/{init,drums,harp,bass,pad,lead}.lua   (grain.lua retired)
           synth/{init,voice (📐),drums_bank,synths_bank}.lua
           ui/chrome.lua  ui/trackpage.lua (📐)
```

Structural debt: global combo handling in `main.lua` should move to `modes.lua` with an explicit mode enum shared by the UI.

---

## 13. Open questions

1. Chord Harp face buttons: strum down/up + strings, or keep 4 strings? (§7.2)
2. Neutral D-pad on the harp: tonic, or keep last chord? (§3.3)
3. Bass face-button articulations — confirm after playtest. (§7.3)
4. Chord-follow degree mapping details, especially on borrowed chords. (§5)
5. Gesture for recording drum chance hits. (§7.1)
6. Arp latch? (§7.5)
7. Replace vs overdub; auto-stop after one pass. (§4)
8. What exactly is a "song"? (§10)
