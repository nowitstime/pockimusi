# Phase A · Foundation — Working Plan

Part of [ROADMAP.md](ROADMAP.md). Design references point to [SPEC.md](SPEC.md).

**Goal:** the app plays exactly as it does today, but:

- the clock can't drift,
- notes are stored as v2 events on integer ticks, with length,
- pitched sounds can be held,
- the Track page has room for setting rows, and instrument swaps can be undone,
- and real tests guard the looper maths.

**Rule for every step:** one step = one or a few commits, each leaving the app playable. Steps marked 📱 end with a check on the RG35XX.

---

## Order

| Step | What | Size | Depends on |
| :-- | :-- | :-- | :-- |
| A1 | Quick fixes + build script 📱 | S | — |
| A2 | Real tests (characterise today's looper) | M | A1 |
| A3 | Modes module (combo handling out of `main.lua`) | M | A2 |
| A4 | Setting rows + safe instrument swap | M | A3 |
| A5 | Clock from absolute time + integer ticks 📱 | M | A2 |
| A6 | Event format v2 + note-on / note-off | L | A5 |
| A7 | Sustained voices 📱 | L | A6 |

This differs from the ROADMAP's first draft on purpose:

- **Tests move to A2,** so the clock and event rewrites (A5, A6) are checked against how the looper behaves today.
- **Modes move to A3,** before the Track page work, so the new Track page logic lands in `modes.lua`, not in `main.lua`'s hand-written state machine.

---

## A1 · Quick fixes + build script 📱

| # | Fix | Where | How |
| :-- | :-- | :-- | :-- |
| 1 | `build.py` packs a hard-coded file list; new files would be missing from the `.love` and crash on device | `build.py` | Pack every `*.lua` under `pocketgroove/` plus `conf.lua` and `controls.gptk` |
| 2 | Mix page level jumps 0.08 **every frame** while held | `main.lua` MIX block | Add `Input:repeatPressed(btn)` (fires on press, then every 0.08 s after a 0.35 s delay) and use it for `UP/DOWN` |
| 3 | `START` tap toggles play after a 0.22–0.25 s hold that already opened Transport | `main.lua`, `input.lua` | Add `Input.startComboUsed`, set when Transport opens or any combo uses `START`; tap only when unused (same pattern as `SELECT`) |
| 4 | Grain ignores the scale (fixed major pentatonic) | `instruments/grain.lua` | Use scale degrees 1, 2, 3, 5, 6, 8 via `Theory:getScaleDegreeSemis` |
| ~~5~~ | ~~Harp shoulder labels~~ — not needed: Chrome already labels them `OCT −/+`. The stale text is in the instruments' `drawStage` functions, which nothing calls any more (see note) | — | — |

**Done when:** each fix checked on desktop; the rebuilt `.love` runs on the device.

**Status:** ✅ fixes 1–4 done and checked headless (LuaJIT via `lupa`, LÖVE stubbed): one mix step per tap then ~8/s auto-repeat; a 0.23 s `START` hold no longer toggles play (reproduced on the old code); Grain stays in scale in minor. ⬜ Device check.

**Note:** `Harp:drawStage`, `Bass:drawStage` and `Grain:drawStage` are dead code since Chrome took over the stage. Remove them during each instrument's pass (or in A3).

---

## A2 · Real tests

**Runner:** `tests/run.py` uses [`lupa`](https://pypi.org/project/lupa/) (LuaJIT inside Python, `pip install lupa`) to run `tests/*.lua`. The test files are plain Lua, so `luajit tests/run.lua` works too where LuaJIT is installed.

**Stubs:** `tests/stubs.lua` provides a fake `love` (`timer.getTime` under test control, `audio` and `sound` as no-ops) and a fake `Synth` that records triggers. `package.path` points at `pocketgroove/`.

**Characterisation tests**, written against *today's* behaviour before anything changes:

| Area | Cases |
| :-- | :-- |
| Recording | snap to each grid (1/4, 1/8, 1/16, 1/12T, FREE); `overrideGridSteps`; snap that rounds forward past the playhead is not double-played |
| Dedup | same action, same step replaces; across the loop seam; different actions coexist |
| Playback | events fire once per pass; seam wrap; muted tracks silent; flam grace fires before the main hit |
| Swing | odd 8ths/16ths pushed late; 1/4 and triplets unaffected |
| Loop length | 2→4 bars duplicates; 4→2 keeps bars 1–2; round trip restores |
| Undo / erase | undo removes the last take only; erase by pad; clear track |
| Theory | chord per direction in major and minor; scale degree semis |

Then delete `test_looper_logic.py`.

**Done when:** `python3 tests/run.py` passes, and breaking the snap or wrap maths makes it fail.

**Status:** ✅ done. 50 tests in under 1 s:

| File | Covers |
| :-- | :-- |
| `test_theory.lua` | scale degrees, all 8 chords, minor/key change, shoulder voicings |
| `test_input.lua` | press/release edges, key repeat, START flag, 8-way, record states |
| `test_looper.lua` | snapping per grid, dedup (incl. seam), playback per pass, already-played skip, mute, flam grace timing, swing, 2↔4 bars, undo/erase, grid cycle, instrument swap, click, half-speed, stutter |
| `test_smoke.lua` | boots the real `main.lua` with sound generation, then drives every instrument on every track through playing, recording, Track page, Transport, Mix, live FX and erase/undo with `love.update` + `love.draw` each frame |

- Mutation check: snap rounding, seam wrap, seam dedup, swing parity and 4→2 bar trimming each broken on purpose → each makes the suite fail.
- Found and fixed one bug: `Theory:getChordForDirection` wrote a global `voicings`.
- Add new test files to the `FILES` list in `tests/run.lua`.

---

## A3 · Modes module

- New `src/modes.lua`:
  - `Modes.current` holds one of `NORMAL`, `REC_LATCH`, `REC_HOLD`, `ERASE`, `MIX`, `TRACK`, `TRANSPORT`, `FX`.
  - `Modes:update()` resolves the mode with the same priority as today.
  - It then dispatches to one handler per mode: `Modes.handlers.MIX(...)` and so on.
- `Input.comboUsed = { L2, R2, SELECT, START }` replaces the four separate flags.
- Track page state (`row`, `fxHeld`, `pendingInstrument`) moves from `Looper.trackPage` to `Modes.trackPage`.
- `Looper.uiMode` becomes `Modes.current`; Chrome reads it from there.
- `main.lua` keeps only the LÖVE callbacks: `Input:update → Modes:update → Looper:update → Instruments:update → Synth:update`.

**Done when:** every combo in SPEC §3.4–3.6 behaves as before (manual checklist), and the tests still pass.

**Status:** ✅ done. `main.lua` is 49 lines of LÖVE callbacks; `src/modes.lua` holds one handler per mode.

- `tests/test_modes.lua` (21 tests) was written against the old `main.lua` first and committed as the baseline; the 19 original combo tests pass unchanged on `modes.lua`. These replace the manual checklist.
- `Input.comboUsed = { L2, R2, SELECT, START }` replaces the four flags; cleared on press and at the end of the release frame (`Input:clearReleasedCombos`).
- `Looper.uiMode`, `prevUiMode`, `trackPage`, `mixTrack` moved to `Modes.current`, `Modes.previous`, `Modes.trackPage`, `Modes.mixTrack`.
- Kept on purpose: a `SELECT` tap on the Transport page changes track, so grid and swing can be set per track without leaving it (now tested).
- One deliberate fix: live FX (`R2` + D-pad) used to stay stuck on when `SELECT` or `START` took over (e.g. stutter kept running in the Mix page). They now switch off whenever the mode isn't `FX`.

---

## A4 · Setting rows + safe instrument swap

**Row schema** (from `def:getSoundRows(state)`):

```lua
{ key = "COLOUR", label = "COLOUR", value = "7TH", kind = "setting" }  -- kind = "sound" is the default
```

- `L1/R1` on a row calls `Instruments:cycleRow(def, state, row, delta)`:
  - for a sound row → `def:cycleRowSound` (as today, plays a preview);
  - for a setting row → `def:cycleSetting(state, key, delta)`, which shows a toast and plays no preview.
- Chrome draws setting rows in a second style, e.g. hollow stars under the filled sound stars, so sounds and settings read differently.

**First real setting: Harp `COLOUR`** with the values `TRIAD`, `7TH`, `9TH`, `SUS4`, `ADD9`.

- `Theory:getChordForDirection(dir, l1, r1, colour)`: string 4 becomes the 7th or 9th; `SUS4` replaces the third with the fourth; `ADD9` puts the 9th on string 4.
- The chord name shows the colour (`Cmaj7`, `Gsus4`).

**Safe swap:**

- `LEFT/RIGHT` sets `Modes.trackPage.pendingInstrument`. The badge shows `→ BASS · release SELECT`, and pressing back to the current instrument cancels.
- When `SELECT` is released, the swap is applied.
- One undo stack: `Looper.undoStack` entries are either `{ kind = "take", takeId, slot }` or `{ kind = "swap", slot, instrumentId, state, events, gridIndex, swing, fx }`. `L2 + R2 + LEFT` pops either kind.

**Tests:** swap then undo restores the events and state; cycling `COLOUR` changes the chord notes.

**Done when:** Harp colour works from the Track page, a swap can be undone, and drum rows behave as today.

**Status:** ✅ done (81 tests).

- `Instruments:cycleRow` sends `L1/R1` to `def:cycleSetting` for `kind = "setting"` rows, otherwise to `def:cycleRowSound`.
- Harp rows: `PATCH` + `COLOUR` (`TRIAD → 7TH → 9TH → SUS4 → ADD9`). `Theory:getChordForDirection(dir, l1, r1, colour)` takes the 7th from the scale, so V7 = G7 and vi7 = Am7; wide voicings keep the colour.
- Setting rows draw as hollow rings with a `2/5` counter; the value column spaces itself from the widest label; shoulders read `CHANGE`.
- Swap preview: pink instrument capsule plus "RELEASE SELECT TO SWAP - UNDO: L2+R2+LEFT"; applied in `Modes` on `SELECT` release via `Instruments:swapTrackInstrument`.
- `Looper.undoStack` (takes and swaps) replaces `takeStack`; `Looper:undo()` replaces `undoLastTake()`. Take entries are now per take *and* track, so a latched take that spans a track change undoes one track at a time.
- New tool: `python3 tools/screenshot.py [scene]` renders screens to `screenshots/` (git-ignored) without LÖVE, by recording `love.draw()` and drawing it with Pillow. Close to, not identical with, the device.

---

## A5 · Clock from absolute time + integer ticks 📱

**Status:** ✅ done (88 tests). ⬜ Device check. What was built, where it differs from the first draft:

**Ticks:** `PPQN = 480` (the draft said 96). At 96 one tick is 5.4 ms at 115 BPM, so FREE recordings would be rounded to audible 5 ms steps; at 480 a tick is about 1.1 ms and every grid is still whole ticks. `loopTicks = bars × 4 × 480` (3840 or 7680).

| Grid | Step (ticks) |
| :-- | :-- |
| 1/4 | 480 |
| 1/8 | 240 |
| 1/16 | 120 |
| 1/12T | 160 |
| FREE | rounds to 1 |

**Clock:** each frame the playhead advances by the *real* time since the last frame (`love.timer.getTime()`), times `bpm / 60 × PPQN × rate`. The sum of real frame times is the absolute time, so this can't drift, and tempo, half-speed and pause changes apply from the next frame with no re-anchoring bookkeeping (the draft's anchor scheme). The clamped `dt` from `main.lua` is now only used for visuals.

- **Clock start:** the first update starts the clock (no time counted), so boot-time sound generation never counts as a hitch.
- **Gap guard:** a frame longer than 0.25 s keeps the playhead on real time but fires none of the skipped events.
- **Stutter:** one 1/16 window (120 ticks) in tick space, as before.
- `Looper.phase`, `prevPhase`, `currentBeat`, `currentStep` are derived each frame (`Looper:syncPhase`), so Chrome and the drum repeat didn't change. Chrome draws events with `Looper:evPhase(ev)`.
- `Looper:seek(phase)` moves the playhead silently; `Looper:resetPlayhead()` is the double-tap reset.

**Recording, swing, bars, click:**

- Events now store `tick` (integer) and `grid` (step in ticks, nil = FREE) instead of `phase`, `step` and `gridSteps`. Note repeat's `overrideGridSteps` becomes a step size in ticks.
- Swing offset in ticks: `(swing − 0.5) × 2 × grid` on odd 1/8 and 1/16 steps.
- 2→4 bars: events keep their ticks and are copied one loop later; 4→2 drops ticks past the new loop. Exact.
- Click: on each beat crossing; flam grace: 28 ms before the hit, converted to ticks at the current BPM.

**Fixed on the way:** the double-tap playhead reset skipped any hit on the downbeat (the old code set `prevPhase` just before `update` overwrote it). Now the downbeat plays.

**New tests:** uneven/slow frames over 4 loops land exactly back where they started with no lost hits (the old clamped-`dt` clock fails this); a half-loop freeze fires nothing and resumes normally; the clock runs from real time even with `dt = 0`; tempo change without a jump; downbeat after reset; whole-tick grids at 2 and 4 bars; drum 1/8 repeat lands on the grid at 60 and 30 fps. Each fix was removed in turn to check its test fails.

---

## A6 · Event format v2 + note-on / note-off

**Status:** ✅ done (102 tests). What was built:

**Events** (SPEC §8.2): `tick`, `len`, `grid`, `action`, `vel`, `takeId`, plus per instrument:

| Instrument | Fields | Kind |
| :-- | :-- | :-- |
| Drums | `soundId`, `decay`, `orn`, `ratchet` | one-shot (`len = 0`) |
| Bass | `degree`, `octave`, `semis`, `decay`, `glideFrom` | one-shot until A7 / Phase B |
| Harp | `semis`, `decay`, `chord = { name, roman, colour }` | one-shot |
| Grain | `semis`, `scanPos`, `density` | **held note** with `len` |

No `trackSlot`, `instrumentId`, `phase`, `velocity`, `pitchSemis` or `decayMod` on events any more. `justRecorded` is now `skipOnce`. `chance`, `bend` and `chordRef` arrive with Phases E, B and D.

**Instrument API** (replaces `triggerEvent`): `noteOn(ev, state, track, isPlayback)`, `noteOff(...)`, `grace(ev, state, track)` for drum flams, optional `updateVoices(dt, state, track)` run every frame on every track. `updateInput(dt, state, track, play, hold)`: `play(ev)` for one-shots, `hold(ev)` for held notes.

**Held notes** (`Instruments:holdNote`): sound at once; recorded with `open = true` (not played back yet); released automatically when the button goes up, when a page takes the controls, or when the track stops being active; on release the recording gets `len` = time held (at least 1 tick, at most one loop) and `open` is cleared.

**Playback** (`Looper:update` → `noteHandler(kind, ev, track)`, set once in `main.lua`): `"on"` at `tick` + swing, `"off"` at `tick + len` (wrapping), `"grace"` before flams. A per-track `sounding` set means a note-off is only sent for notes that were started, and every sounding note is released on mute, clear, erase, undo, 2↔4 bars (4→2 also cuts notes at the new loop end), pause, re-recording over it, and instrument swap.

**Loop seam:** a note held across the seam wraps (`len` runs past the end and the note-off lands after the wrap). Splitting wasn't needed.

**Grain:** one press = one held note. A per-note *spawner* makes the grains: live notes follow the D-pad and shoulders while held, recorded notes replay the settings stored at the press. A held press records one event (it used to record one per grain).

**Fixed on the way:** a held note snapped just ahead of the playhead kept its "already played live" mark until release, which silenced its next whole loop pass. The playhead now uses the mark up while the note is still held.

**Also:** the dead `drawStage` functions in Bass, Harp and Grain are deleted (Chrome draws every stage). `Looper:setPlaying(on)` replaces writing `Looper.playing` from Modes.

**New tests** (`tests/test_notes.lua`): on/off timing, seam wrap, no off for one-shots, open notes not played, no stray off after a skipped pass, the held-note mark fix, release on each of the 7 silencing actions, re-record releases, 4→2 bar cut, per-instrument v2 fields with no old fields, Grain held press = one event with the right length, Grain playback spawns and stops, page opening releases a held note, mute stops a playing note. Removing the auto-release or the mark fix fails the matching tests.

---

## A7 · Sustained voices 📱

**Status:** ✅ done (114 tests). ⬜ Device check.

**Loop layers** (`Synth:createLoop(freq, periods, wave)`): `wave(angle)` is a function of the fundamental's angle containing only whole harmonics; the buffer holds `periods` whole periods of `round(44100 / freq)` samples, so `setLooping(true)` repeats without a click. The loop's real frequency is `44100 / period`; the returned `tune` (a few thousandths of a semitone) corrects it in `setPitch`.

| Patch | Attack layer | Loop | Sustain / fade-in / release |
| :-- | :-- | :-- | :-- |
| `bass` | `bass` one-shot | saw (9 harmonics) + square sub, fundamental C2 | 0.55 / 0.18 s / 0.10 s |
| `grain_pad`, `grain_bell`, `grain_choir`, `grain_drone` | the Grain one-shots | harmonic re-voicings, fundamental C3 | 0.6 / 0.12 s / 0.35 s |

The loop versions leave out the one-shots' detune, noise and inharmonic FM, which can't loop seamlessly in a short buffer. Pad (Phase E) can add movement back (chorus between two loop sources, brightness crossfade). The harp stays a pluck (no loop).

**Voices** (`src/synth/voice.lua`, installed into `Synth`):

```lua
local v = Synth:noteOn("bass", semis, vel, { track = track, glideFrom = prev, vibrato = false })
v:setPitch(semis)   -- glide (loop and attack layers)
v:noteOff()         -- release; frees itself when silent
```

- The attack layer is the patch's one-shot via `Synth:trigger`, so it gets glide, track FX and the existing fade; the loop fades in under it over `xfade`, then holds at `sustain`.
- `noteOff` fades the loop over `release` and cuts the attack layer to the same time.
- Per frame (`Synth:update` → `updateVoices`): glide, vibrato, half-speed −7 st, and level = envelope × velocity × track volume × master × duck.
- Each patch has 6 loop sources; running out steals that patch's oldest voice.
- Not yet used by any instrument: Bass keeps its one-shot feel until Phase B, as planned.

**Test keys (desktop):** hold `H` for a bass voice (track 3's volume and FX), `G` for the warm pad (track 4).

**Boot time:** `Synth:init` prints `[PocketGroove] sound generation: ...` to the PortMaster `log.txt` and keeps `Synth.bootTimes`. Headless here the loops add about 10 % (4 ms of 45 ms); the device will be slower in absolute terms.

**New tests** (`tests/test_voices.lua`): a loop is whole periods, its seam is no rougher than any step inside it, and its tune correction is tiny; the seam check catches a non-harmonic wave; every real patch loop is seamless and in tune; noteOn plays the attack and fades the loop in; a voice sustains 4 s at a constant level; noteOff releases over the release time and frees the source; glide and `glideFrom`; half-speed; stealing; the H/G keys in the running game.

## Exit checklist for Phase A

- [x] `python3 tests/run.py` green (114)
- [x] All SPEC §3.4–3.6 combos work (`tests/test_modes.lua` replaces the manual checklist)
- [ ] Drums feel identical on device: repeats, flam, ratchet, swing, choke, click
- [x] No tempo drift with forced frame drops (tested headless; ⬜ feel it on device)
- [x] Harp `COLOUR` row works; instrument swap is undoable
- [x] A held Grain press = one event; a held voice sustains and releases cleanly (⬜ listen on device: `H` / `G` on a keyboard, or Phase B)
- [ ] Boot time and EFX cost on the RG35XX recorded here

## Notes / measurements

| Date | Item | Result |
| :-- | :-- | :-- |
| 2026-11-11 | Sound generation, headless LuaJIT (fake SoundData) | drums 0.020 s, synths 0.021 s, sustain loops 0.004 s, total 0.045 s |
| | Boot time on the RG35XX (from `log.txt`) | |
| | EFX on device (supported? sends?) | |
