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
- [x] Chord Harp, Bass at their first versions; Grain (now replaced by the Pad)

## Decisions so far

| Topic | Decision |
| :-- | :-- |
| Tracks | **Four**, fixed. Instruments are swappable per slot |
| Instruments | Drums, Chord Harp, Bass, **Pad** (replaces Grain), **Lead/Arp** (swap it in on the Track page). Sample chop parked |
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
| **E** | **Pad** (replaces Grain) | Reuses sustained voices + Harmony; Grain textures become patches |
| **F** | **Lead / Arp** | Same class as Bass; arp needs the clock-locked scheduling from A |
| **G** | **Mix & FX finish** — master low-pass, meters, count-in, takes per pass | Most effects already exist |
| **H** | **Drums pass 2** — Variation, chance, per-pad tune/level | Pass 1 is done and plays fine; randomness and per-pad tune/level land once the mix tools (meters) exist |
| **I** | **Tape deck v2 & visual polish** | Ribbons/bends/chord lane need v2 data; final look across all stages |
| **J** | **Patterns / song, `.wav` export, sample loading** | Later, once the jam loop is great |

Device checks (frame rate, boot time, EFX cost, legibility) happen at the end of **every** phase, not as a separate one.

---

## Phase A · Foundation ✅ (device checks pending) — details in [PHASE_A.md](PHASE_A.md)

- [x] A1 Quick fixes + build script packs every file (device check pending)
- [x] A2 Real tests (characterise today's looper first) — `python3 tests/run.py`
- [x] A3 Modes module (move combo handling out of `main.lua`)
- [x] A4 Setting rows + safe instrument swap (first row: Harp `COLOUR`)
- [x] A5 Clock from real time + integer ticks (480 PPQN; device check pending)
- [x] A6 Event format v2 + note-on/note-off playback (Grain = held notes)
- [x] A7 Sustained voice engine (device listen pending)

## Phase B · Bass pass ✅ (device look of the new view pending) — details in [PHASE_B.md](PHASE_B.md)

- [x] B1 Held-note handles: end early, record bends incl. the release tail (shared by Bass, Pad, Lead)
- [x] B2 Bass sounds: `SAW`, `SUB`, `PLUCK` patches + `PATCH` and `GLIDE` rows
- [x] B3 Held notes: `B` hold, `Y` staccato (one grid step), `X` accent + vibrato; mono (`PLUCK` overlaps)
- [x] B4 Legato `A`: glide without a new attack, live and on playback
- [x] B5 Bends: D-pad and shoulders while holding (and in the release tail) glide, record, replay
- [x] B6 Stage view (pitch trace, live scope, real face labels) + bend marks on the tape deck (device look pending)

## Phase C · Autosave ✅ (device check pending) — details in [PHASE_C.md](PHASE_C.md)

- [x] C1 Save text: write a table, read it back with a parser that never runs code (`src/save.lua`)
- [x] C2 Session snapshot and restore (per-instrument settings, events, effects; every value checked)
- [x] C3 Autosave: two alternating slots, every 10 s if changed, on quit and focus loss; restore on boot (device check pending)
- [x] C4 Fresh session: hold `L2 + R2 + SELECT` (~1 s), clears notes only, undoable; saves in the port folder; log.txt fix (device check pending)

## Phase D · Chord Harp + chord-follow ✅ (device check pending) — details in [PHASE_D.md](PHASE_D.md)

- [x] D1 Chord map (`↑` = ♭VI, neutral = I) and key-relative chord data on harp events
- [x] ~~D2 Strums~~ dropped: the harp keeps one note per button; strumming becomes its own instrument (see Phase F)
- [x] D3 `harmony.lua`: current chord at any tick (recorded chords, else live chord, else tonic)
- [x] D4 Bass `FOLLOW` (default on): live and playback notes and bends follow the chord
- [x] D5 Chord in the top bar and along the harp lane, bass follow capsule

## Phase E · Pad (replaces Grain) ✅ (device listen pending) — details in [PHASE_E.md](PHASE_E.md)

- [x] E1 Voice engine: bright layer, per-note attack and release, movement; patches `WARM`, `BELL`, `CHOIR`, `DRONE`
- [x] E2 Pad instrument: `B` full, `A` open, `Y` high, `X` swell; rows `PATCH`, `FOLLOW`, `ATTACK`, `RELEASE`; `grain.lua` removed, slot 4 = Pad, old Grain saves load as a Pad
- [x] E3 Follow: held and recorded chords move with the chord track; `FOLLOW OFF` keeps them as recorded
- [x] E4 D-pad ↑/↓ brightness, ←/→ movement, recorded as keyframes and replayed
- [x] E5 Stage view in the template
- [ ] Device check: the four patches and their levels, sweep speed, chord changes while holding, frame rate

## Phase F · Lead / Arp ✅ (device listen pending) — details in [PHASE_F.md](PHASE_F.md)

- [x] F1 Lead on top of Bass: D-pad degree, `B` held note with glides; patches `SQUARE`, `SAW`, `PLUCK`; rows `PATCH`, `FOLLOW`, `ARP RATE`, `ARP PATTERN`
- [x] F2 Arp: `A` up, `Y` down, `X` up-down; locked to the clock and swing; rate 1/8, 1/16, 1/8T; `L1 + R1` = rate ×2; each step recorded as a note; follows the chords
- [x] F3 Bass ↔ Lead swaps keep events
- [x] F4 Stage view: arp ladder + pitch trace
- [x] Instrument colour: tracks are coloured by slot, nothing to add
- [ ] ❓ Arp latch (not built: hold only)
- [ ] ❓ Strum instrument: stays a lab idea ([FUTURE_INSTRUMENTS.md](FUTURE_INSTRUMENTS.md)). The harp stays one note per button
- [ ] Device check: arp feel against the drums at each rate, the three patches and their levels

## Phase G · Mix & FX finish

- [ ] Real low-pass for master `R2 + ←` (reuse the tone filter)
- [ ] Level meters in the Mix page and tape deck
- [ ] Count-in ❓ control
- [ ] Record takes split per loop pass; ❓ replace vs overdub

## Phase H · Drums pass 2

- [ ] Already on v2 from A5; check flam/ratchet/choke/repeat still behave
- [ ] `VARIATION` row: Off / Light / Wild (velocity jitter → timing nudge + fills)
- [ ] Chance hits ❓ gesture (proposal: ghost hit while Variation ≠ Off)
- [ ] Per-pad tune and level ❓ where
- [ ] Device check

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

Phase A is built (see [PHASE_A.md](PHASE_A.md); device checks still to do). Phase B (bass) is built ([PHASE_B.md](PHASE_B.md)). Phase C (autosave) is built ([PHASE_C.md](PHASE_C.md)); device checks pending. Phase D (chord-follow) is built ([PHASE_D.md](PHASE_D.md)). Phase E (Pad) is built ([PHASE_E.md](PHASE_E.md)); it has not been heard on the device yet. Phase F (Lead / Arp) is built ([PHASE_F.md](PHASE_F.md)), also unheard. Next: Phase G, Mix & FX finish.
