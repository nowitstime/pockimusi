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
| 5 | Harp stage still labels shoulders `7TH/9TH` and `SUS4/+8`; they already shift octave | `instruments/harp.lua` | Relabel `OCT −1` / `OCT +1`, both = `WIDE` |

**Done when:** each fix checked on desktop; the rebuilt `.love` runs on the device.

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

---

## A5 · Clock from absolute time + integer ticks 📱

**Ticks:** `PPQN = 96`, so `loopTicks = bars × 4 × 96` (768 or 1536).

| Grid | Step (ticks) |
| :-- | :-- |
| 1/4 | 96 |
| 1/8 | 48 |
| 1/16 | 24 |
| 1/12T | 32 |
| FREE | 1 |

**Clock:**

```lua
tick = anchorTick + (love.timer.getTime() - anchorTime) * (bpm / 60) * PPQN * rate
```

- `Looper:reanchor()` runs on BPM change, pause/resume, half-speed on/off, 2↔4 bars and playhead reset.
- **Stutter** (beat repeat) works in tick space: when the playhead reaches the end of the 1/16 window, re-anchor to the window start.
- **Gap guard:** if more than 0.25 s passed since the last update (suspend, hitch), re-anchor without firing the skipped events, so you never get a burst.
- `Looper.tick` is a float playhead. Events sit on integer ticks, and the crossing test stays `(prevTick, tick]` with wraparound.
- `Looper.phase = tick / loopTicks` is still updated every frame, so Chrome and the drum repeat keep working unchanged.

**Recording, swing, bars and click:**

- Recording snaps `tick` to the step: `round(tick / step) × step % loopTicks`.
- Swing becomes a tick offset: `round((swing − 0.5) × 2 × step)` on odd steps of 1/8 and 1/16 grids.
- 2↔4 bars multiplies or divides ticks exactly.
- The click fires on crossings of multiples of 96.
- The flam grace note stays a fixed 28 ms before the hit, converted to ticks at the current BPM.

**Tests:**

- Advance fake time in uneven frames, including one 0.3 s hitch: the tempo stays exact and no burst fires.
- The A2 characterisation tests still pass, after updating them to compare ticks.

**Done when:** the tests pass, and on the device the drums, repeats, swing and click feel the same, with no drift when frames drop.

---

## A6 · Event format v2 + note-on / note-off

**Event** as in SPEC §8.2: `tick`, `len`, `grid`, `action`, `vel`, `chance`, `takeId`, plus instrument fields.

- `trackSlot` and `instrumentId` move to the track; no saves exist yet, so there's nothing to migrate.

**Instrument API** (replaces `triggerEvent`):

| Function | Called when |
| :-- | :-- |
| `def:noteOn(ev, state, track, isPlayback)` | live press or playback start |
| `def:noteOff(ev, state, track, isPlayback)` | live release or playback `tick + len` (only when `len > 0`) |
| `def:grace(ev, state, track)` | drums flam grace (replaces `part == "grace"`) |

**Recording held notes:**

- `Instruments:pressNote(track, ev)` records the event with `len = 0` and returns a handle.
- `Instruments:releaseNote(track, handle)` sets `len = (tick − ev.tick) % loopTicks`, at least 1.
- Instruments whose notes are pure one-shots never call `releaseNote`.
- ❓ A note held across the loop seam: close it at the seam and start a new event, or let `len` wrap. Try wrapping first (simpler); split only if it sounds wrong.

**Porting each instrument at its *current* behaviour:**

| Instrument | v2 fields |
| :-- | :-- |
| Drums | `soundId`, `orn`, `ratchet`, `decay`; `len = 0` |
| Bass | `degree`, `octave`, `semis`; `len = 0` until A7 gives it sustain |
| Harp | `semis`, string index in `action`, `chord = { roman, colour }` |
| Grain | **one event per press** with `len`. Playback `noteOn` starts a grain spawner on that track's state and `noteOff` stops it. This is the model for every continuous instrument |

**Other changes:**

- `justRecorded` becomes `ev.skipOnce`, cleared the first time the playhead crosses the event.
- Dedup compares the same `action` on the same snapped `tick`.
- Chrome: the 3 places that read `ev.phase` switch to `Looper:evPhase(ev)`, which returns `ev.tick / loopTicks`.

**Tests:**

- A held Grain press records exactly one event with the right `len`.
- Playback calls `noteOn`/`noteOff` at the right ticks, including across the seam.
- Undo and erase work on v2 events.

**Done when:** every instrument records and replays as today, and a held Grain press is one event.

---

## A7 · Sustained voices 📱

**Patch layers** (`synths_bank.lua`):

- **Attack layer:** the existing one-shot buffer.
- **Loop layer:** a whole number of waveform periods.
  - The frequency is snapped to `44100 / periodSamples`, and `patch.tuneSemis` corrects the tiny detune in `setPitch`.
  - The loop plays with `setLooping(true)`, which is click-free.
- Patches to build: bass, harp, and the four grain textures (which become Pad patches in Phase F).

**Voice** (`src/synth/voice.lua`):

```lua
local v = Synth:noteOn(patchId, semis, vel, { track = track, attack = 0.005, release = 0.12, glide = nil })
v:setPitch(semis)   -- glide/bend target
v:noteOff()         -- start release; voice frees itself when silent
```

- Envelope states are `attack → sustain → release → free`, with the level set per frame in `Synth:update` through `setVolume`.
- The attack layer plays once, and the loop layer fades in underneath it (each patch sets the crossfade time).
- Both sources get the track's tone filter and EFX sends through `Synth:applyTrackFx`.
- Each patch has its own pool of loop sources; when one runs out, the oldest voice is stolen with a 10 ms fade.

**Hooks for Phase B:**

- Bass `noteOn` uses `Synth:noteOn` when the patch has a loop layer; otherwise it falls back to the one-shot.
- The Bass *feel* stays the same in A7. Real held notes and articulations are the Phase B work.

**Dev check:**

- A desktop-only key (`H`) holds a bass voice while pressed.
- Boot time is logged in `Synth:init` (`love.timer` before and after). If it goes over ~3 s on device, add a loading screen or build patches lazily.

**Done when:** `H` holds a bass note for 4 s without clicks and releases cleanly, with track effects on, on desktop and on the device. Boot time is noted in this file.

---

## Exit checklist for Phase A

- [ ] `python3 tests/run.py` green
- [ ] All SPEC §3.4–3.6 combos work (manual checklist)
- [ ] Drums feel identical on device: repeats, flam, ratchet, swing, choke, click
- [ ] No tempo drift with forced frame drops
- [ ] Harp `COLOUR` row works; instrument swap is undoable
- [ ] A held Grain press = one event; a held voice sustains and releases cleanly
- [ ] Boot time and EFX cost on the RG35XX recorded here

## Notes / measurements

| Date | Item | Result |
| :-- | :-- | :-- |
| | Boot time (before A7) | |
| | Boot time (after A7) | |
| | EFX on device (supported? sends?) | |
