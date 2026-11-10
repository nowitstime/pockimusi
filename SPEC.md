# PocketGroove (Working Title) — Design & Technical Specification

**Target hardware:** Anbernic RG35XX Plus (Allwinner H700, ARM64 Linux, 1 GB RAM, 640×480 4:3 IPS, no touchscreen, **no analog sticks**)
**Engine:** LÖVE 11.5 via PortMaster (`gptokeyb` fallback), desktop PC for development
**Architecture:** headless domain engine (Input, Looper, Synth, Instruments, Theory) + a passive 640×480 vector view (Chrome)

> **Status legend:** ✅ implemented · 🔧 implemented but changing · 📐 designed, not built · ❓ open question

---

## 1. Design philosophy

1. **Playable without looking.** Every button has one clear job. Depth comes from *combining* simple controls, not from adding features to each control. The screen confirms what you did; it should not be required to do it.
2. **Same grammar on every track.** A button's *role* is the same on every instrument (see §3). Learn it once.
3. **Zero-setup jamming.** The master loop is always rolling. Recording is a gesture, not a menu.
4. **Instrument ≠ sound.** An instrument is *how you play*. A sound is *what comes out*. They are chosen independently (§5).
5. **Four tracks, always visible.** The screen is sized for exactly four tracks. Tracks are *slots*; the instrument in a slot can be swapped (§6).
6. **Self-contained procedural audio.** All sounds are generated in RAM at boot. Optional `.wav` loading is a later milestone.

---

## 2. Hardware input abstraction ✅

All hardware maps to a virtual button table (`down`, `pressed`, `released`). Gamepad and keyboard are equivalent.

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

❓ Verify that L2/R2 → stick-click mapping is what the device actually needs; trigger axes are also handled.

---

## 3. Control grammar (the core of the base UI) 🔧

### 3.1 Roles by physical zone

| Zone | Role | Meaning |
| :-- | :-- | :-- |
| Right thumb `B A Y X` | **Trigger** | *What* plays and *when* |
| Left thumb D-pad | **Pitch / harmony / expression** | *Where* in pitch or harmony, or how hard the hit is |
| Shoulders `L1 R1` | **Register & density** | `L1` = lower / sparser, `R1` = higher / denser, both = a special "extra" |
| `L2` | **Record** | Latch or momentary (§4) |
| `R2` | **Performance** | Mutes and punch-in FX; with `L2` = erase |
| `SELECT` (hold) | **Track page** | Sound, instrument and per-track settings for the active track |
| `START` | **Transport / global** | Play/pause; with D-pad = tempo, key, scale |

**Rule:** a gesture may use at most two buttons plus the D-pad. No nested menus.

### 3.2 Shoulders per instrument (register & density)

| Instrument | `L1` | `R1` | `L1 + R1` |
| :-- | :-- | :-- | :-- |
| Drums | 1/4 repeat | 1/8 repeat | 1/16 repeat (1/12T on a triplet grid) |
| Chord | voicing down an octave | voicing up an octave | 📐 TBD "extra" |
| Bass / Lead | octave −1 | octave +1 | — |
| Grain | octave −1 | octave +1 | +7 semitones |

Today the chord harp still uses `L1`/`R1` for 7th/9th and sus4/add9 — 🔧 these move out (see §3.3).

### 3.3 Chord colour 📐

D-pad already picks the chord (8 directions), so extensions cannot also live on the D-pad. Proposal:

- **Chord colour** (triad, 7th, 9th, sus4, add9) is a **per-track setting** in the Track page (§3.4), set once and left.
- ❓ Optional **momentary colour** gesture for live variation (e.g. double-tap a direction). Decide after playtesting.

### 3.4 Track page (hold `SELECT`) 📐

Shows and edits the **active track** only:

- `L1 / R1` — previous / next **sound** (kit for drums, patch for pitched instruments).
- `LEFT / RIGHT` — previous / next **instrument** for this slot (§6).
- `UP / DOWN` — per-track setting (chord colour, swing, etc. ❓).
- `B A Y X` — drums: choose the pad to edit, then `L1/R1` changes that pad's sound. Other instruments: reserved for per-track FX slots (§7).
- Quick **tap** of `SELECT` (< 0.28 s, no combo used) still cycles the active track 1→4.

### 3.5 Transport (hold `START`) 📐

Moves tempo/key/scale off `SELECT` so `SELECT` can be purely about the track.

- `START` tap (on release, if no combo used): play/pause. Double-tap: reset playhead to 1.1.
- `START` + `UP/DOWN`: BPM ±5 (60–180).
- `START` + `LEFT/RIGHT`: key / scale.
- `START` + a face button: toggle 2 / 4 bars. ❓ exact button.

❓ Moving tempo/key to `START` is a proposal; today they are on `SELECT`.

### 3.6 Other global combos ✅

| Combo | Action |
| :-- | :-- |
| `R2` + `B/A/Y/X` | Mute tracks 1/2/3/4 |
| `R2` + D-pad (hold) | Master punch-in FX: ↑ stutter, ↓ half-speed, ← duck, → bitcrush |
| `L2 + R2` + `B/A/Y/X` | Erase that pad/action on the active track |
| `L2 + R2` + `LEFT` or `L1` | Undo last take |
| `L2 + R2` + `START` | Clear active track |
| `L2` + `SELECT` | Cycle the active track's quantize grid |

---

## 4. Recording model 📐

Hybrid **latch / momentary** on `L2`:

- **Tap** `L2` (released in < 0.25 s with no other button used): toggle record **on/off** (latched).
- **Hold** `L2` (≥ 0.25 s): record **only while held** (momentary punch-in).
- Pressing any combo with `L2` (e.g. `L2 + R2`, `L2 + SELECT`) counts as "used" and never toggles the latch.
- A new **take** begins each time recording starts. Undo removes the last take.
- The top bar always shows the state: `● REC (LATCHED)` vs `● REC (HOLD)` vs `JAM SAFE`.

❓ Auto-stop after one pass? ❓ Count-in? ❓ Replace vs overdub toggle?

---

## 5. Sounds: instruments vs sound pools 📐

| | **Instrument** (controller) | **Sound** (voice) |
| :-- | :-- | :-- |
| Defines | button/D-pad mapping, UI, event format | the audio that plays |
| Swapped by | Track page `LEFT/RIGHT` | Track page `L1/R1` |

Two shared pools:

1. **One-shot pool** — drum hits, snaps, perc, FX, later chops. Any drum pad can hold any one-shot.
2. **Pitched patch pool** — Rhodes, saw, sub, pluck, pad, organ, etc. Shared by chord, bass, lead and (later) grain.

**Kits:** a kit is a preset of four one-shots (one per pad). Picking a kit is one `L1/R1` press. Per-pad overrides are allowed and saved with the track.

Goal: swapping the patch changes how the chord/bass sits with the drums **without changing how you play it**.

Current state: drums have a 24-sound catalogue ✅; harp and bass are hard-wired to one buffer each; grain has four fixed textures.

---

## 6. Tracks and instrument swapping 📐

- **Four slots**, always shown in the tape deck. A slot holds `{ instrumentId, sound, state, events, mute, grid, fx }`.
- The **instrument library** can grow past four; only four are active at once.
- Default slots: 1 Drums, 2 Chord, 3 Bass, 4 Grain.
- Swapping an instrument keeps the slot's mute/grid/FX but **clears its events**, because event formats differ. The previous track state is stashed so **undo can restore it** (❓ confirm).
- Instrument classes (for future compatibility): *percussive* (pads), *chord*, *mono-melodic* (bass/lead), *texture* (grain). Same-class swaps (e.g. two mono-melodic instruments) can keep events.

Planned instruments (❓ unprioritised): lead/arp, sample chop, second drum style.

---

## 7. Effects 📐

- **Master punch-in FX** (momentary, `R2` + D-pad) ✅ — note: the "low-pass" is currently a volume duck, not a filter.
- **Per-track FX** (set-and-forget, Track page): tone (low-pass), drive, echo, space. Needs real per-track DSP. 📐
- **Swing / humanize** per track. 📐 (high-value for groove)

---

## 8. Looper & clock ✅ / 📐

### 8.1 Timing ✅
- Loop is **2 or 4 bars** of 4/4. `loopDuration = (60 / bpm) × bars × 4`.
- `phase ∈ [0,1)` advances `dt / loopDuration` per frame (× 0.5 with half-speed FX).
- Per-track **quantize grid**: `1/4`, `1/8`, `1/16`, `1/12T`, `FREE`.
- Playback fires events whose `phase` lies in `(prevPhase, phase]`, with wraparound handling.
- Recording is deduplicated per `(action, snapped phase)`, with circular distance across the loop boundary.

### 8.2 Event format
```lua
Event = {
  phase = 0.25, step = 9, gridSteps = 32,
  trackSlot = 1, instrumentId = "drums",
  action = "B", soundId = "kick_808",
  pitchSemis = 0, velocity = 0.85, decayMod = 1.0,
  glideFromSemis = nil, scanPos = nil, chordName = nil,
  takeId = 3, justRecorded = false,
}
```

### 8.3 Looper v2 📐 (needed for expressive bass/chords)
- `dur` — gate length: when the button was released, so sustained notes replay as sustained.
- `bend` — list of `{ dphase, semis }` keyframes captured while a note is held, so D-pad pitch bends replay.
- Tape deck draws held notes as bars (with a bend line) and short hits as pills.

---

## 9. Audio engine ✅

- 44.1 kHz, 16-bit mono `SoundData` generated at boot; pools of cloned `Source`s for polyphony.
- Voice stealing evicts the previous voice record for a reused source.
- Live FX: beat repeat, half-speed, duck, bitcrush-style pitch quantize.
- ❓ Boot-time generation cost on the RG35XX is unmeasured; may need a loading screen or caching.

---

## 10. UI layout (640×480) 🔧

1. **Top bar:** active track + instrument, quantize grid, bars, BPM, key/scale, beat dots, record/mode badge.
2. **Center stage:** the active instrument's own view + a context hint bar for held modifiers.
3. **Tape deck:** four tracks with name, grid, mute, event markers and a shared playhead.

Principles: show mode in the same place always; one hint line for the current held modifier; colour-code tracks consistently.

---

## 11. Code layout ✅

```text
pockimusi/
 ├── SPEC.md
 ├── PocketGroove.sh            # PortMaster launcher
 ├── build.py                   # packs pocketgroove/PocketGroove.love
 ├── test_looper_logic.py       # headless logic checks
 └── pocketgroove/
      ├── main.lua  conf.lua  controls.gptk
      └── src/
           config.lua  theory.lua  input.lua  looper.lua
           instruments/{init,drums,harp,bass,grain}.lua
           synth/{init,drums_bank,synths_bank}.lua
           ui/chrome.lua
```

Known structural debt: global combo handling in `main.lua` is a hand-written state machine and should become an explicit **mode enum** (`NORMAL`, `REC`, `ERASE`, `TRACK_PAGE`, `TRANSPORT`, `FX`); the UI re-derives the same modes.

---

## 12. Roadmap

| Phase | Goal | Contents |
| :-- | :-- | :-- |
| **0** | Agree the grammar | This document |
| **1** | Base UI & input | Mode state machine; record latch/hold; Track page; `START` transport; shoulders = register/density; hints/top bar per mode |
| **2** | Engine | Looper v2 (`dur`, `bend`); sound pools + kits; per-track FX; swing |
| **3** | Instrument passes | Bass → Chord → Drums → Track 4, each against the grammar |
| **4** | New instruments | Lead/arp, chops, etc., via instrument swapping |
| **5** | Packaging | `.wav` sample loading, PortMaster polish |

---

## 13. Open questions

1. Chord colour: per-track setting only, or also a momentary gesture? (§3.3)
2. Tempo/key on `START` instead of `SELECT`? (§3.5)
3. What does `L1 + R1` do on the chord instrument?
4. Should instrument swap be undoable and keep compatible events? (§6)
5. Per-track FX slot UI on `B/A/Y/X` in the Track page. (§3.4, §7)
6. Record extras: auto-stop, count-in, replace vs overdub. (§4)
7. Is direct track selection needed besides `SELECT` tap cycling?
8. Boot-time sound generation cost on device.
