# PocketGroove — Roadmap

Companion to [SPEC.md](SPEC.md). The spec says *what things should be*; this file says *in what order we build them* and what comes next.

Legend: `[x]` done · `[ ]` to do · ❓ needs a decision

---

## Where we are

Running on the RG35XX Plus and it feels fine. Built so far:

- [x] 4-track looper, quantize grids, 2/4 bars, undo last take, per-pad/track erase
- [x] Record latch/hold on `L2`; Mix page on `SELECT + R2`; master punch-in FX; per-track + master volume
- [x] Drums pass 1: dynamics × articulation (flam, ratchet), grid-locked repeat, hat choke, six kits, four-lane view
- [x] Unified Track page = sound (rows, instrument, effects) and per-track effects audio (tone, drive, echo, space)
- [x] Transport = timing: tempo, key, scale, bars, per-track grid and swing, metronome click
- [x] One colour per page; constellation Track page and astrolabe Transport designs
- [x] Chord Harp, Bass, Grain at their first versions

## Decisions so far

| Topic | Decision |
| :-- | :-- |
| Tracks | **Four**, fixed. Instruments are swappable per slot |
| Instruments | Drums, Chord Harp, Bass, **Pad** (replaces Grain), **Lead/Arp** (new). Sample chop parked |
| Page roles | `SELECT` = sound (rows, instrument, effects); `START` = timing (tempo, key, scale, bars, grid, swing) |
| Settings space | New per-track options are **setting rows** on the Track page under the sound rows; `L1/R1` change the value. A new option costs a row, not a button |
| Instrument swap | Preview with `LEFT/RIGHT`, apply on `SELECT` release, **undoable** |
| Harmony | **Chord-follow**: chord harp track drives the current chord, tonic fallback, per-track `FOLLOW` row |
| Drums randomness | **Variation** row + **chance** hits, applied at playback |
| Notes | **Event format v2**: integer ticks, note length, degrees + absolute pitch, bends, chance |
| Audio | **Sustained voices** (attack + seamless loop layers) for all pitched patches |
| Workflow | **One instrument at a time**; each pass includes its stage visuals in the shared template |
| Look | Base look set early; refined per instrument, not finalised up front |
| Page colours | One colour per page (SPEC §11) |
| Saving | Autosave right after the format settles; patterns/song later |
| Latency | Fine on device. Revisit only if it gets worse |

---

## Order of work

| # | Phase | Why here |
| :-- | :-- | :-- |
| **A** | **Foundation** — fixes, setting rows + safe swap, tests, clock, event v2, sustained voices | Everything after depends on the note format and sustain. Small fixes ride along |
| **B** | **Bass pass** | Hardest test of v2: held notes, glide/bend, degrees. Proves the engine |
| **C** | **Autosave** | Format is now stable; stop losing jams |
| **D** | **Chord Harp pass + Harmony (chord-follow)** | Bass already stores degrees, so follow just switches on |
| **E** | **Drums pass 2** — Variation, chance, per-pad tune/level | Pass 1 is done; add the randomness on v2 events |
| **F** | **Pad** (replaces Grain) | Reuses sustained voices + Harmony; Grain textures become patches |
| **G** | **Lead / Arp** | Same class as Bass; arp needs the clock-locked scheduling from A |
| **H** | **Mix & FX finish** — master low-pass, meters, count-in, takes per pass | Most effects already exist |
| **I** | **Tape deck v2 & visual polish** | Ribbons/bends/chord lane need v2 data; final look across all stages |
| **J** | **Patterns / song, `.wav` export, sample loading** | Later, once the jam loop is great |

Device checks (frame rate, boot time, EFX cost, legibility) happen at the end of **every** phase, not as a separate one.

---

## Phase A · Foundation ← **next up** — working plan in [PHASE_A.md](PHASE_A.md)

- [ ] A1 Quick fixes + build script packs every file
- [ ] A2 Real tests (characterise today's looper first)
- [ ] A3 Modes module (move combo handling out of `main.lua`)
- [ ] A4 Setting rows + safe instrument swap (first row: Harp `COLOUR`)
- [ ] A5 Clock from absolute time + integer ticks
- [ ] A6 Event format v2 + note-on/note-off playback
- [ ] A7 Sustained voice engine

## Phase B · Bass pass

- [ ] Bass plays sustained notes: sound while held, release on button-up
- [ ] Face buttons = articulations (`B` normal, `A` legato/glide, `Y` staccato, `X` accent + vibrato) ❓ confirm after playtest
- [ ] D-pad move while holding = glide to the new degree, recorded as `bend`
- [ ] Records `degree`, `octave`, `semis`, `len`, `bend`
- [ ] Rows: `PATCH`, `FOLLOW` (inactive until D), `GLIDE`
- [ ] 2–3 bass patches in the pitched pool (saw, sub, pluck)
- [ ] Stage view fitted to the template (keep the wave display character)
- [ ] Tape deck shows bass notes as ribbons (first use of held-note drawing)
- [ ] Device check

## Phase C · Autosave

- [ ] Serialise session (globals + tracks + settings + FX + events) with `version = 2`
- [ ] Save on quit and every ~30 s; load on start; ignore or upgrade older versions
- [ ] Check the save directory on PortMaster / muOS

## Phase D · Chord Harp + Harmony

- [ ] `harmony.lua`: current chord at a tick (chord source track, tonic fallback)
- [ ] Harp records `chord` events; chord name in the top bar and along its tape lane
- [ ] Strum gesture ❓ (`B` down, `A` up, `Y` low, `X` high — playtest first)
- [ ] `COLOUR` and `STRUM` rows; shoulders become voicing octave / wide
- [ ] Bass `FOLLOW` switches on (default on)
- [ ] ❓ Neutral D-pad: tonic or keep last chord
- [ ] Stage view in template (keep the harp character)
- [ ] Device check

## Phase E · Drums pass 2

- [ ] Already on v2 from A5; check flam/ratchet/choke/repeat still behave
- [ ] `VARIATION` row: Off / Light / Wild (velocity jitter → timing nudge + fills)
- [ ] Chance hits ❓ gesture (proposal: ghost hit while Variation ≠ Off)
- [ ] Per-pad tune and level ❓ where
- [ ] Device check

## Phase F · Pad (replaces Grain)

- [ ] Grain textures → Pad patches (warm pad, glass bell, choir, drone)
- [ ] Holds the current chord; `B` full, `A` open, `Y` high, `X` swell
- [ ] D-pad ↑/↓ brightness (layer crossfade), ←/→ movement
- [ ] Rows: `PATCH`, `FOLLOW`, `ATTACK`, `RELEASE`
- [ ] Remove `grain.lua`; default slot 4 = Pad
- [ ] Stage view in template
- [ ] Device check

## Phase G · Lead / Arp

- [ ] D-pad degree; `B` note, `A` arp up, `Y` arp down, `X` up-down
- [ ] Arp locked to the clock and swing; rate 1/8, 1/16, 1/8T; `L1 + R1` = rate ×2
- [ ] Rows: `PATCH`, `FOLLOW`, `ARP RATE`, `ARP PATTERN`
- [ ] Bass ↔ Lead swaps keep events
- [ ] Instrument colour distinct from page colours
- [ ] ❓ Arp latch
- [ ] Device check

## Phase H · Mix & FX finish

- [ ] Real low-pass for master `R2 + ←` (reuse the tone filter)
- [ ] Level meters in the Mix page and tape deck
- [ ] Count-in ❓ control
- [ ] Record takes split per loop pass; ❓ replace vs overdub

## Phase I · Tape deck v2 & visual polish

- [ ] Beads for hits, ribbons for held notes, bend lines, chord lane labels
- [ ] Readable at 4 bars (about 7 px per step)
- [ ] Hints only for the held modifier; ❓ learn-mode toggle
- [ ] Shape cues besides colour; 12 px+ text (check the 9 px font on device); legibility pass
- [ ] Final pass on all five stage views

## Phase J · Later

- [ ] Pattern slots A–H and a simple chain ❓ what a "song" is
- [ ] Export loop to `.wav`
- [ ] Optional `.wav` sample loading

---

## Immediate plan

Phase A is next. The step-by-step plan, tests and exit checklist live in [PHASE_A.md](PHASE_A.md).
