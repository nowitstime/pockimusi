# PocketGroove — Roadmap

Companion to [SPEC.md](SPEC.md). The spec says *what things should be*; this file says *in what order we build them* and what comes next.

Legend: `[x]` done · `[ ]` to do · ❓ needs a decision

---

## Where we are

Running on the RG35XX Plus and it feels fine. Built so far:

- [x] 4-track looper, quantize grids, 2/4 bars, undo last take, per-pad/track erase
- [x] Drums (expression, rolls, 24-sound catalogue), Chord Harp, Bass, Grain
- [x] Record latch/hold on `L2`, Transport on `START` hold, Track page on `SELECT` hold (basic), Mix page on `SELECT + R2`
- [x] Master punch-in FX, per-track + master volume
- [x] Base celestial visual language started (D-pad star, face buttons, drum stage)

## Decisions so far

| Topic | Decision |
| :-- | :-- |
| Tracks | **Four**, fixed. Instruments are swappable per slot |
| Instruments | Drums, Chord Harp, Bass, **Pad** (replaces Grain), **Lead/Arp** (new). Sample chop parked |
| Drums randomness | **Variation** setting + **chance** hits, applied at playback |
| Harmony | **Chord-follow**: chord harp track drives the current chord, tonic fallback, per-track *Follow* on/off |
| Settings space | Track page becomes a **flat settings list** (`UP/DOWN` row, `LEFT/RIGHT` value) — new options cost a row, not a button |
| Instrument swap | Preview on the Track page, apply on `SELECT` release, **undoable** |
| Notes | **Event format v2**: integer ticks, note length, degrees + absolute pitch, bends, chance |
| Audio | **Sustained voices** (attack + seamless loop layers) for all pitched patches |
| Workflow | **One instrument at a time**, each pass includes its stage visuals in the shared template |
| Look | Base look set early; refined per instrument, not finalised up front |
| Saving | Autosave right after the format settles; patterns/song later |

---

## Order of work

| # | Phase | Why here |
| :-- | :-- | :-- |
| **A** | **Foundation** — fixes, Track page list, clock, event v2, sustained voices | Everything after depends on the note format and sustain. Small fixes ride along |
| **B** | **Bass pass** | Hardest test of v2: held notes, glide/bend, degrees. Proves the engine |
| **C** | **Autosave** | Format is now stable; stop losing jams |
| **D** | **Chord Harp pass + Harmony (chord-follow)** | Bass already stores degrees, so follow just switches on |
| **E** | **Drums pass** — kits, Variation, chance, swing | Already plays well; port to v2 and add the randomness |
| **F** | **Pad** (replaces Grain) | Reuses sustained voices + Harmony; Grain textures become patches |
| **G** | **Lead / Arp** | Same class as Bass; arp needs clock-locked scheduling from A |
| **H** | **Mix & FX** — swing for all, tone, real low-pass, meters | Polish once all instruments exist |
| **I** | **Tape deck v2 & visual polish** | Ribbons/bends/chord lane need v2 data; final look across all stages |
| **J** | **Patterns / song, `.wav` export, sample loading** | Later, once the jam loop is great |

Device checks (frame rate, boot time, legibility) happen at the end of **every** phase, not as a separate one.

---

## Phase A · Foundation ← **next up** (detailed plan below)

- [ ] A1 Quick fixes
- [ ] A2 Track page as a settings list + safe instrument swap
- [ ] A3 Real tests that run the Lua
- [ ] A4 Clock from absolute time + integer ticks
- [ ] A5 Event format v2 + note-on/note-off playback
- [ ] A6 Sustained voice engine
- [ ] A7 Modes module (move combo handling out of `main.lua`)

## Phase B · Bass pass

- [ ] Bass plays sustained notes: sound while held, release on button-up
- [ ] Face buttons = articulations (`B` normal, `A` legato/glide, `Y` staccato, `X` accent + vibrato) ❓ confirm after playtest
- [ ] D-pad move while holding = glide to new degree, recorded as `bend`
- [ ] Records `degree`, `octave`, `semis`, `len`, `bend`
- [ ] Track page rows: Glide time, Swing (swing may land as a stub until H)
- [ ] 2–3 bass patches in the pitched pool (saw, sub, pluck)
- [ ] Stage view fitted to the template (keep the wave display character)
- [ ] Tape deck shows bass notes as ribbons (first use of held-note drawing)
- [ ] Device check

## Phase C · Autosave

- [ ] Serialise session (globals + tracks + events) with `version = 2`
- [ ] Save on quit and every ~30 s; load on start; ignore/upgrade older versions
- [ ] Check the save directory on PortMaster / muOS

## Phase D · Chord Harp + Harmony

- [ ] `harmony.lua`: current chord at a tick (chord source track, tonic fallback)
- [ ] Harp records `chord` events; chord name shown in the top bar and along its tape lane
- [ ] Strum gesture ❓ (`B` down, `A` up, `Y` low, `X` high — playtest first)
- [ ] Colour + Strum speed move to the Track page; shoulders become voicing octave / wide
- [ ] Bass *Follow chords* switches on (default on)
- [ ] ❓ Neutral D-pad: tonic or keep last chord
- [ ] Stage view in template (keep the harp character)
- [ ] Device check

## Phase E · Drums pass

- [ ] Port to v2 events (one-shots: `len = 0`)
- [ ] Kits (preset of 4) + per-pad override on the Track page
- [ ] Variation: Off / Light / Wild (velocity jitter → timing nudge + fills)
- [ ] Chance hits ❓ gesture (proposal: ghost hit while Variation ≠ Off)
- [ ] Swing row
- [ ] Device check

## Phase F · Pad (replaces Grain)

- [ ] Grain textures → Pad patches (warm pad, glass bell, choir, drone)
- [ ] Holds the current chord; `B` full, `A` open, `Y` high, `X` swell
- [ ] D-pad ↑/↓ brightness (layer crossfade), ←/→ movement
- [ ] Track page: Attack, Release, Follow
- [ ] Remove `grain.lua`; default slot 4 = Pad
- [ ] Stage view in template
- [ ] Device check

## Phase G · Lead / Arp

- [ ] D-pad degree; `B` note, `A` arp up, `Y` arp down, `X` up-down
- [ ] Arp locked to the clock; rate 1/8, 1/16, 1/8T; `L1 + R1` = rate ×2
- [ ] Track page: Arp rate, Arp pattern/range, Follow
- [ ] Bass ↔ Lead swaps keep events
- [ ] ❓ Arp latch
- [ ] Device check

## Phase H · Mix & FX

- [ ] Swing for every instrument
- [ ] Per-track Tone (layer crossfade)
- [ ] Real low-pass for master FX, or keep the duck ❓
- [ ] Level meters in the mix page and tape deck
- [ ] Metronome click and count-in (`START + A / Y`)
- [ ] Record takes split per loop pass; ❓ replace vs overdub

## Phase I · Tape deck v2 & visual polish

- [ ] Beads for hits, ribbons for held notes, bend lines, chord lane labels
- [ ] Readable at 4 bars (about 7 px per step)
- [ ] Hints only for the held modifier; ❓ learn-mode toggle
- [ ] Shape cues besides colour; 12 px+ text; legibility pass on the device
- [ ] Final pass on all five stage views

## Phase J · Later

- [ ] Pattern slots A–H and a simple chain ❓ what a "song" is
- [ ] Export loop to `.wav`
- [ ] Optional `.wav` sample loading

---

## Immediate plan: Phase A in detail

Goal: when Phase A is done, the app plays exactly as today, but the engine stores v2 events on integer ticks, can hold notes, and the Track page has room for every setting we planned. Do the steps in this order; each one leaves the app working.

### A1 · Quick fixes (small, do first)

| Fix | Where |
| :-- | :-- |
| Mix page level changes once per press (+ key repeat), not every frame | `main.lua` MIX block |
| Drums hint still says BPM/Key on SELECT | `instruments/drums.lua` `getSelectHint` |
| Track page `UP` and `DOWN` both step the grid forward (superseded by A2, fix anyway) | `main.lua` TRACK block |
| START tap toggles play after a 0.22–0.25 s hold that opened Transport | `main.lua` START tap check (use "combo used" flag) |
| Grain uses a fixed major pentatonic and ignores minor scales (stop-gap until it's replaced) | `instruments/grain.lua` |

Done when: each fix checked on desktop, then once on the device.

### A2 · Track page as a settings list + safe swap

1. New `src/ui/trackpage.lua`: draws the list over the stage; rows come from the instrument.
2. Instrument API: `def:getSettings(state, track)` returns rows `{ id, label, values, get, set }`. Common rows (Instrument, Sound, Grid) are added by the Track page itself; instrument rows are appended.
3. Controls: `UP/DOWN` row, `LEFT/RIGHT` value, `L1/R1` quick sound, `B/A/Y/X` drum pad select.
4. Instrument row previews only; apply on `SELECT` release.
5. Apply = push `{ slot, instrumentId, state, events, settings }` onto the undo stack, so `L2 + R2 + LEFT` restores it.
6. Move drum pad sound browsing and the grid choice into rows.

Done when: all current Track page functions still work through the list, a swap can be undone, and the list fits with 6 rows.

### A3 · Real tests

1. Make `looper.lua`, `theory.lua` and the new `harmony.lua` loadable without LÖVE (inject `love.timer` where needed).
2. Add `tests/` run with plain `luajit` (or `busted` if available): snapping, dedup across the loop seam, 2↔4 bars, take undo, chord building per scale.
3. Retire `test_looper_logic.py`.

Done when: `luajit tests/run.lua` passes and fails if looper maths are broken.

### A4 · Clock + ticks

1. `Looper` keeps `anchorTime` and `anchorTick`; current tick = `anchorTick + (now − anchorTime) × ticksPerSecond`, wrapped to loop length. Re-anchor on BPM change, pause/resume, half-speed and stutter.
2. Playback fires events whose tick lies in `(prevTick, tick]`, with wraparound — the same logic as today, on integers.
3. Grids become tick steps: 1/4 = 96, 1/8 = 48, 1/16 = 24, 1/12T = 32 (12 per bar), FREE = 1 tick.
4. 2↔4 bars: multiply/divide ticks exactly; no float drift.
5. `phase` = `tick / loopTicks` for drawing only.

Done when: tempo stays exact while frames drop (test by forcing a slow frame), and all existing gestures behave the same.

### A5 · Event format v2

1. Events as in SPEC §8.2. Track-level `instrumentId` moves to the track.
2. Recording: note-on creates the event with `len = 0`; note-off sets `len`. A note still held at the loop seam is closed at the seam and continues as a new event (❓ or wraps — decide in testing).
3. Playback calls `def:noteOn(ev)` at `tick` and `def:noteOff(ev)` at `tick + len`; one-shots (`len = 0`) only get `noteOn`.
4. Pitched instruments record `degree`, `octave` and `semis` (and `chordRef` = current chord name, tonic for now).
5. Port Drums, Harp, Bass and Grain to v2 at their *current* behaviour (no new features yet). Grain emits one event per press with `len`, not one per grain.
6. Undo, erase, dedup work on v2.

Done when: every instrument records and replays as today, and a held Grain/Bass press shows as one event.

### A6 · Sustained voices

1. `synths_bank.lua`: generate attack + seamless-loop layers for the harp, bass and pad patches.
2. `src/synth/voice.lua`: `Synth:noteOn(patch, semis, vel, opts)` → voice with `setPitch`, `noteOff` (release envelope), driven in `Synth:update`.
3. Voice stealing per patch pool, as today.
4. Measure boot time on the device before and after; if it grows past ~3 s, add a loading screen or generate lazily.

Done when: a test key holds a bass note for 4 s without clicks and releases cleanly, on desktop and on the device.

### A7 · Modes module

1. Move `handleGlobalCombos` into `src/modes.lua` with an explicit mode enum and one "combo used" flag per modifier.
2. Chrome reads `Modes.current` instead of re-deriving modes.

Done when: `main.lua` is just the LÖVE callbacks, and all combos in SPEC §3.6 still work.

**Then:** Phase B, the Bass pass, uses A5 + A6 directly.
