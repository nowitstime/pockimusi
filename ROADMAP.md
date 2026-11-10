# PocketGroove — UI & Interaction Roadmap

Companion to [SPEC.md](SPEC.md). The spec says *what the controls mean*; this file says *in what order we build and refine the UI* and what is still undecided.

Legend: `[x]` done · `[ ]` to do · ❓ needs a decision

---

## Decisions so far

| Topic | Decision |
| :-- | :-- |
| Layout | One **fixed stage template** for every instrument: shoulder badges on top, **faceted star-compass D-pad** left, **faceted diamond button pods** right, instrument signature display in the middle, hint strip at the bottom |
| Pizzazz & Motifs | **Per-instrument geometric visual halos/auras** behind the D-pad and face controls: rhythmic reticles for Drums, celestial orbit rings for Harp, cyber-grid brackets for Bass, and orbital dust rings for Grain |
| Labels | Widgets never move. Their **labels change** with the mode or held modifier |
| Mix | A **mix page** opened with a SELECT combination (proposed: `SELECT + R2`) |
| Hints | Show hints **for the modifier currently held**, not a permanent legend |
| Record | Hybrid **tap-to-latch / hold-for-momentary** on `L2` |
| Audio feedback | Try a short **audio tick** for mode changes and record on/off |
| Saving | **Autosave** first. A **song / pattern saving system** later |
| Latency | Not a concern right now. Revisit if it gets worse during testing |
| Instrument looks | Keep the character of the harp view and the bass wave display, but fit them into the template |

---

## UI-0 · Layout Template & Celestial Anime Visual Language

Goal: Every region of the 640×480 screen (Top Crown, Center Stage, and Bottom Starlight Tape Deck) shares the same elegant anime-celestial design language.

- [ ] Write a `stage` layout module with named zones (`topBar`, `stage`, `tapeDeck`).
- [ ] **Top Status Bar ("Crown")**:
  - Rounded crystal capsule badges with luminous border outlines and top glass highlights.
  - Starlight Metronome: 4-pointed sparkle stars that flare with a lens glow on downbeats.
  - Mode Talisman in the top right (Record, Jam Safe, Mix, Transport).
- [ ] **Center Stage Controls**:
  - **Wireframe Star Constellation D-Pad**: Slender 8-pointed star wireframe outline; glowing starlight beam ray shooting from center to selected star tip on press.
  - **Floating Clean Circle Lens Face Pods**: Crisp circular buttons floating on a celestial orbit ring with glass crescent gleam.
  - **Celestial Instrument Auras**:
    - Drums: Starlight pulse rings and constellation cross-stars.
    - Chord Harp: Moonlight crescent arc and harmonic orbital paths.
    - Bass: Flowing aurora ribbons and stellar degree guides.
    - Grain: Drifting stardust motes and luminous frequency filaments.
  - **Shoulder Wings**: Glowing crystal badges (`L1` / `R1`) at the top corners of the stage.
- [ ] **Bottom Tape Deck ("Starlight Timeline")**:
  - **Shooting Star Playhead**: Glowing dual-crystal starlight head with an astral beam sweeping across all 4 lanes.
  - **Constellation Note Beads**: Discrete hits rendered as glowing starlight pearls with outer halo rings.
  - **Aurora Energy Ribbons**: Sustained notes drawn as luminous rounded ribbons with starlight pitch-bend curves.
  - **Floating Track Runes**: Capsule badges displaying track number, instrument name, and active rune VU meters.
- [ ] Minimum text size (12px+) and high contrast pass throughout.

Mock-up: `ui_layout_mockup.html` (conversation artifact).

## UI-1 · Modes & feedback

- [ ] Replace the hand-written combo handler in `main.lua` with an explicit **mode enum** (`NORMAL`, `REC_LATCH`, `REC_HOLD`, `ERASE`, `TRACK`, `MIX`, `TRANSPORT`, `FX`).
- [ ] **Record latch/hold** on `L2` (tap < 0.25 s toggles, longer is momentary; combos never toggle).
- [ ] **Mode badge** (top right) and stage border colour driven by the mode.
- [ ] **Hold-to-hint:** bottom strip shows hints for the held modifier only.
- [ ] **Audio tick** on mode change, record on/off and track switch (try it, keep it only if it helps).
- [ ] ❓ Should hints fade out for experienced users, or get a "learn mode" toggle?

## UI-2 · Track page & instrument swapping

- [ ] `SELECT` hold opens the track page: `L1/R1` sound, `LEFT/RIGHT` instrument, `UP/DOWN` setting, face buttons = track FX.
- [ ] Swapping an instrument clears the track's events but stashes them so **undo restores**.
- [ ] Sound pools: **one-shot pool** (drums, kits) and **pitched patch pool** (chord, bass, lead, grain).
- [ ] Drum **kits** (preset of four sounds) with per-pad override.
- [ ] Per-track setting per instrument (chord colour, swing, glide time, grain size).
- [ ] ❓ Which settings does each instrument expose on `UP/DOWN`?

## UI-3 · Mix page (`SELECT + R2`)

- [ ] Engine: **per-track volume** and **master volume** in `Synth` (trigger takes the track's level).
- [ ] Mix page layout: four channel strips + master, level segments, mute badges.
- [ ] Controls: `LEFT/RIGHT` choose track, `UP/DOWN` level, `B/A/Y/X` mute tracks 1–4, `L1/R1` master level.
- [ ] Live **level meters** (per track, also shown in the tape deck).
- [ ] ❓ Pan? Solo? Probably later; mono sources make pan awkward.
- [ ] ❓ Confirm `SELECT + R2` doesn't conflict with `R2` mute/FX use while `SELECT` is held.

## UI-4 · Tape deck v2

- [ ] Hits as **pills**, held notes as **bars**, bends as a **line over the bar** (needs Looper v2).
- [ ] Per-track **level meter** and a brief **activity flash** on hits.
- [ ] Clear selected-track and armed/recording indication.
- [ ] Readable at 4 bars (about 7 px per step).
- [ ] ❓ Do we ever want per-track loop length (polyrhythm)?

## UI-5 · Persistence

- [ ] **Autosave** the last session (BPM, key, scale, bars, and every track's instrument, sound, grid, mute, level, FX, events). Save on quit and every N seconds.
- [ ] Versioned save file via `love.filesystem` (check the save directory on PortMaster / muOS).
- [ ] Load the autosave on start.
- [ ] **Song / pattern system** (later): named pattern slots (A–H), maybe a simple chain. ❓ What exactly is a "song" here?
- [ ] ❓ Export a loop to `.wav`?

## UI-6 · Polish & device checks

- [ ] Test legibility on the real RG35XX Plus screen (font sizes, contrast, brightness).
- [ ] Measure frame rate with `msaa = 2` and smooth lines on the device.
- [ ] Shape or icon cues in addition to colour (orange / red / amber are easy to confuse).
- [ ] Measure boot-time sound generation on the device.
- [ ] Revisit audio latency only if it feels worse during testing.

---

## Suggested order

1. **UI-0** layout template, because everything else sits on it.
2. **UI-1** modes, record latch and hold-to-hint.
3. **UI-3** mix page (needs the per-track volume engine change; small).
4. **UI-2** track page and instrument swapping (depends on the sound pools).
5. **UI-4** tape deck v2 (waits for Looper v2: note length and bends).
6. **UI-5** autosave, then the song system.
7. **UI-6** device checks, in parallel throughout.

## Dependencies on engine work

| UI item | Needs |
| :-- | :-- |
| Mix page, meters | Per-track and master volume in `Synth` |
| Held notes and bends in the tape deck | Looper v2 (`dur`, `bend` in events) |
| Track page sounds | Sound pools and kits |
| Track FX slots | Per-track DSP |
| Autosave | Serialisable track and event state (already plain tables) |
