# L0 · Lab foundation — Working Plan

Part of [lab wave 1](README.md). This is the only plan that changes shared files. It goes first, as one stream; the five instrument plans start from its last commit.

**Goal:** everything the five instruments share is in place, so each of them is one new module and one new test file. The Track page shows the instruments as a centred carousel.

**Rule for every step:** one step = one or a few commits, app playable, tests green. 📱 = check on the RG35XX.

---

## Decisions

### Instrument tabs: a centred carousel

| Topic | Decision | Why |
| :-- | :-- | :-- |
| Layout | The selected instrument sits in the **centre** of the tab strip; the names slide under it when `L1 / R1` step | Works for any number of instruments |
| "Selected" | The previewed instrument while one is previewed, otherwise the track's own | The centre is always what `SELECT` release will give you |
| How many show | The centre and about two names each side (the strip is 216 px wide, between the `L1` and `R1` capsules); names fade out towards the edges | The fade says "there is more" without arrows |
| Ends | A **ring**: after the last instrument comes the first, on both sides | Stepping already wraps; the centre always has neighbours |
| The track's own instrument | Keeps its outline while another is previewed, if it is in view. The swap card still names it | You can see how far you have stepped |
| Lab instruments | A small dot over the name | Tell experiments from the library at a glance |
| Motion | The strip slides to its new place in about a tenth of a second, as the picker's highlight does | Shows the direction of the step |

### Lab plumbing

| Topic | Decision | Why |
| :-- | :-- | :-- |
| `Config.LAB` | `true` for now. With it off, instruments marked `lab = true` are left out of the catalogue | One line to hide every experiment |
| Reserved ids | `hands`, `strum`, `slide`, `dial`, `valves`, plus `fingers` (built here). The catalogue tries to load `src.instruments.<id>` for each; a module that does not exist is skipped, a module with an error still fails loudly | Streams never edit the list |
| Test files | `tests/run.lua` runs `test_<id>.lua` for each reserved id when the file exists | Streams never edit the list |
| Missing instrument in a save | The track loads empty on the slot's default instrument | Session load already picks the default; this step adds the test that the notes are dropped, and fixes it if they are not |

---

## What L0 provides (the contract)

Instrument plans rely on exactly these. Names are final once L0 is merged.

### On the instrument definition

| Field | Meaning |
| :-- | :-- |
| `lab = true` | A lab instrument: dotted in the tabs, hidden when `Config.LAB` is off |
| `viewKind` | Which stage view draws it: `"drums"` (the four lanes), `"bass"` (pitch trace, degree, patch capsules) or `"lab"` (the plain view). Without it, the instrument's id decides, as today |
| `VIEW` | Control labels for the stage: `{ dpad = { UP = "...", ... , NEUTRAL = "..." }, face = { B = "...", A = "...", Y = "...", X = "..." }, l1 = "...", r1 = "...", both = "..." }`. Any part may be left out: the view's own labels show instead. `dpad` and `face` each replace the whole set; `l1` / `r1` are the text after `L1:` / `R1:`; `both` shows on both capsules while both shoulders are held |
| `getReadout(state)` | For the `"lab"` view: returns a large line and a small line (what is sounding now), and optionally a list of up to nine further lines. In the `"bass"` view the same call, if the instrument has it, words the note name and the line under it (either may be `nil` to keep the Bass's) |
| `LANES` | Tape deck row (1 to 4, top to bottom) for each event action that is not a face button, e.g. `{ R1 = 1, L1 = 2 }`. Hits and held notes of that action both sit on the row |
| `ERASE` | Erase page: what each face button clears, e.g. `{ B = { actions = { "R1" }, label = "DOWNSTROKES" } }`. A button the map leaves out clears nothing. Without a map, a face button clears events with that action, as today |
| `eventClass` | Unchanged: instruments with the same class keep each other's notes on a swap. L0 gives Drums `"drums"` |

### Calls

| Call | Meaning |
| :-- | :-- |
| `Input:getFingering()` | The right thumb's fingering: `id` = `"NONE"`, one of `"B" "A" "X" "Y"`, a neighbouring pair `"BA" "AX" "XY" "YB"`, `"ALL"`, or `"OTHER"` (three buttons, or an opposite pair); `settled` = it has been the same for `Input.FINGER_SETTLE` seconds; `changed` = it changed this frame; `prev` = the fingering before |
| `Input.FINGER_SETTLE` | 0.035 s. The one settle window |
| `hold(ev, { manual = true })` | A held note that ends only when the instrument calls `h:release()` (or a page takes the controls, or the track stops being active). Without `manual`, a note still ends when its `action` button goes up |
| `Drums:padPressed(btn)`, `Drums:padDown(btn)` | Whether a pad was hit this frame / is held. Default: the face button. Drums' own input code asks these instead of reading the buttons |
| `Looper:clearTrackAction(slot, actions, label)` | `actions` may be a list |

### Where things are

- The reserved ids: `Instruments.LAB_IDS` (`src/instruments/init.lua`), and the same list in `tests/run.lua`.
- An event's `action` may be a face button, `"L1"` or `"R1"`. Anything else is dropped when a save loads (`src/session.lua`).
- Stand-in instruments that use every part of this contract: `tests/test_lab.lua`.

### Already there (no L0 work), for reference

- A note whose `action` is `"R1"` or `"L1"` is held by that shoulder: the hold rule reads `Input.down[ev.action]`.
- `h:bend({ semis = ... })` records a pitch keyframe without a degree, and the Bass's playback replays it.
- `Patches.noteOn(def, state, semis, vel, opts)` plays the track's patch in the instrument's register; `patch.rings` / `patch.sustains` say how it behaves.
- `Synth:schedule(delay, fn)` runs something a little later (frame resolution).
- A module built on another with `setmetatable({...}, { __index = Bass })`, as Lead is.

---

## Order

| Step | What | Size |
| :-- | :-- | :-- |
| L0.1 | `Config.LAB`; reserved ids loaded if present; test files run if present; missing-instrument save test | S |
| L0.2 | Instrument tabs as a centred carousel 📱 | S |
| L0.3 | Stage views from data: `viewKind`, `VIEW`, `getReadout`, the plain lab view; tape deck rows from `LANES` | M |
| L0.4 | `ERASE` map on the Erase page | S |
| L0.5 | `manual` held notes; Drums pad hooks and `eventClass` | S |
| L0.6 | `Input:getFingering()` and the `FINGERS` test instrument 📱 | S |

`FINGERS` is a silent lab instrument: its lab view shows the fingering the app sees and counts, for each of the nine, how many presses settled cleanly and how many passed through another fingering first. It is the tool for tuning `FINGER_SETTLE` and is deleted when the wave ends.

## Tests

- L0.1: with `LAB` off the catalogue is the five library instruments and stepping skips the rest; with it on, `fingers` is there and the missing ids are not; a module that errors is not silently skipped; a save holding an unknown instrument loads that track empty on the default instrument, other tracks intact.
- L0.2: the centred tab is the previewed instrument, else the track's own; stepping past either end wraps; every instrument can be reached with `L1` alone and with `R1` alone; drawing works with 5, 6 and 10 instruments.
- L0.3: an instrument with `viewKind = "bass"` built on Bass draws the Bass view with its own `VIEW` labels; one with `"lab"` draws its readout; the five library instruments draw as before; an event with action `R1` lands on the row its `LANES` names.
- L0.4: an `ERASE` map clears the mapped actions and nothing else, with its label in the toast; an instrument without a map behaves as today; undo restores.
- L0.5: a `manual` note survives its button going up and ends on `h:release()`, on a page taking the controls and on a track change; its recorded length is right. Drums play and record exactly as before (the existing drum tests pass unchanged); Drums ↔ Drums-class swaps keep the notes.
- L0.6: the reader reports each of the nine fingerings; three buttons and opposite pairs give `"OTHER"`; a pair arriving one frame apart is `settled` as the pair, never as the single; four arriving over three frames settle as `"ALL"`; `changed` and `prev` are right across a roll.

## Exit checklist

- [x] `python3 tests/run.py` green; the existing tests pass without edits, except one line (see Status)
- [ ] Six tabs (five + `FINGERS`) slide and wrap; the dot reads at a glance 📱
- [ ] Pairs and all-four land on the `FINGERS` screen; `FINGER_SETTLE` set from what it shows 📱
- [x] The contract above matches the code, name for name

## Status

L0.1 to L0.6 are built and tested (`tests/test_lab.lua`, `tests/test_fingers.lua`); `PocketGroove.love` is rebuilt. Left: the two 📱 checks above.

- **One existing test changed.** `test_session` "bad values are fixed up" used an unknown instrument name and expected its notes to be kept. That is the opposite of the decision here, so that track now has no instrument name (still the slot's default, notes kept), and the unknown-name case is tested in `test_lab`.
- **Erase is not undoable, with or without a map.** The test line "undo restores" is read as "undo still works after an erase": it removes what is left of the take. Bringing erased notes back would be a new feature for every instrument; say if it is wanted.
- **A missing track name versus an unknown one.** Only a save that *names* an instrument that is not there loads the track empty. A track with no instrument name at all (a damaged file) keeps its notes on the slot's default, as before.
- **Previews:** `python3 tools/screenshot.py lab-fingers tabs-lab`.

## Added later

Shared changes made by an instrument stream after L0 (keep them additive):

- **The five are ordinary instruments** (after the first playtest): they dropped `lab = true`, and `buildCatalog` now loads every reserved id and leaves out only modules marked `lab` while `Config.LAB` is off. So `Config.LAB` hides just `FINGERS` now, and only `FINGERS` has the dot in the tabs. Test `test_lab` "LAB off" changed to match.

## Open (settle by playing)

1. Is 35 ms right, or do pairs need longer on the RG35XX's buttons?
2. Does the fade at the strip's edges read on the device's screen, or does it need arrows?
