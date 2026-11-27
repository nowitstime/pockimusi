# Hand Drums (`HANDS`) — Working Plan

Part of [lab wave 1](README.md). Needs: [L0](L0_FOUNDATION.md). Independent of the other four instruments.

**Feel:** the D-pad stops being a modifier and becomes four more pads. Left and right thumbs alternate, which gives rolls, paradiddles and conga patterns that one thumb cannot play.

**Owns:** `pocketgroove/src/instruments/hands.lua`, `tests/test_hands.lua`, this file. Touches nothing else.

---

## Controls

| Control | Job |
| :-- | :-- |
| `B A Y X` | Pads, as on Drums |
| D-pad `↑ ↓ ← →` | The same four pads again, by position: `↑` = `X`, `↓` = `B`, `←` = `Y`, `→` = `A` |
| D-pad diagonal | Both pads |
| `L1` | Ghost: soft, short |
| `R1` | Accent: loud, longer |
| `L1 + R1` | Note repeat at the track's grid, as on Drums; a held D-pad direction repeats too |

## Decisions

| Topic | Decision | Why |
| :-- | :-- | :-- |
| Built on | The Drums module (`setmetatable({...}, { __index = Drums })`), same state, kits, rows and event format | Lanes, erase, tape deck, variation and saves work unchanged |
| `MIRROR` only | The D-pad plays the same four sounds as the face buttons, and a D-pad hit is recorded under its face button | Rolls on one drum with two thumbs. `SPLIT` (eight sounds) waits: it needs more rows and an erase gesture |
| Which way | By position (each direction is the button in the same place on the diamond). `MIRROR_MAP` is one table, so the mirror-image variant is a one-line change to try | Nothing to learn |
| Both thumbs on one pad in the same frame | One hit | A flam by accident would be worse than a lost double |
| Shoulders | `L1` ghost, `R1` accent, both = repeat | The D-pad is busy; this is the `L1` = sparser, `R1` = denser habit |
| What it gives up | Flam and ratchet | They live on the D-pad on Drums |
| Swapping | `eventClass = "drums"`: Drums ↔ Hand Drums keeps the notes | Record on one, decorate on the other |
| Stage view | `viewKind = "drums"` with its own `VIEW` labels | The four lanes already show everything |

## How it is built

- `padPressed(btn)` / `padDown(btn)`: the face button **or** its mirrored direction.
- `computeExpression`: ghost and accent from the shoulders (same levels and decay as Drums' `↓` and `↑`); no flam, no ratchet.
- `getRepeatRate`: repeat only with both shoulders (Drums also repeats with one; here one shoulder is ghost or accent).
- `id = "hands"`, `shortName = "HANDS"`. Everything else is inherited. (It was `lab = true` until the five became ordinary instruments.)

## Order

| Step | What | Size |
| :-- | :-- | :-- |
| HD1 | Module, mirror map, shoulder expression, repeat | S |
| HD2 | Swap with Drums, saves, `VIEW` labels | S |

## Tests

- `↑ ↓ ← →` play the sounds of `X B Y A` and record under those actions; a diagonal makes two hits; face and D-pad on one pad in one frame make one.
- `L1` = ghost level, `R1` = accent level; neither sets `orn` or `ratchet`; both shoulders with a pad or a direction held repeat at the grid.
- A ghost recorded with `VARIATION` on gets its chance, as on Drums.
- Drums ↔ Hand Drums keeps the notes both ways; a Hand Drums track saves and loads its kit and pad sounds.
- The erase page clears by face button as on Drums.

## Playtest

- A clean 1/16 single-stroke roll at 120 BPM?
- By position, or mirror image?
- Do you miss flam and ratchet?

## Status

HD1 and HD2 are built and tested (`tests/test_hands.lua`, 9 tests). No shared file changed. `PocketGroove.love` is not rebuilt (done once after the wave merges). Left: the playtest above 📱.

- **Both shoulders = repeat at the normal level.** With `L1 + R1` held the hits are neither ghost nor accent: the two shoulders cancel, and the repeat plays at the plain level. Repeat is always 1/16 (1/12T on a triplet grid), as Drums' `L1 + R1`; there is no 1/4 or 1/8 repeat here.
- **One hit per pad per frame, not per stroke.** A face button and its direction landing in the same frame are one hit; a frame apart they are two (that is a roll, and it is what the instrument is for). Say if near-simultaneous doubles sound like accidental flams on the device.
- **Recorded rolls still quantize.** Two strokes on one pad that land on the same grid step while recording keep only one, as on Drums. Faster rolls need a finer track grid.
- **One label is the Drums'.** The subtitle under the D-pad still reads `D-PAD: EXPRESSION` (`ui/chrome.lua` picks it by view kind; the `VIEW` contract has no field for it). Left as is under the lab rule; a `VIEW.dpadTitle` hook would be a one-line additive change if it bothers.
- **Mirror variant:** change `MIRROR_MAP` in `hands.lua` to `{ UP = "X", DOWN = "B", LEFT = "A", RIGHT = "Y" }` (and the `VIEW.dpad` labels) to try it.

## Open (settle by playing)

1. Its own instrument, or a `HANDS` row on Drums (off / mirror)?
2. Is `SPLIT` worth its rows and erase gesture?
