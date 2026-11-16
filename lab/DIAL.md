# Dial (`DIAL`) — Working Plan

Part of [lab wave 1](README.md). Needs: [L0](L0_FOUNDATION.md) (the fingering reader and `manual` held notes). Independent of the other four instruments. Background: FUTURE_INSTRUMENTS §4.2.

**Feel:** the four face buttons and the four neighbouring pairs form eight positions around the diamond. Rolling the thumb clockwise walks up the scale; a fast roll is a run; rocking between a button and its pair is a trill. Keep rolling past the top and you climb into the next octave.

**Owns:** `pocketgroove/src/instruments/dial.lua`, `tests/test_dial.lua`, this file. Touches nothing else.

---

## Controls

| Position (clockwise) | `B` | `B+A` | `A` | `A+X` | `X` | `X+Y` | `Y` | `Y+B` |
| :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- |
| Degree | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |

The single buttons are 1, 3, 5, 7: chord tones on the buttons, passing notes between them.

| Control | Job |
| :-- | :-- |
| Face diamond | The note. It sounds while any face button is down |
| Roll to a neighbouring position | Slur: the same note continues at the new pitch, no new attack |
| Lift and press elsewhere | A new note in the current octave |
| All four | Back to the home octave (it plays degree 1 there) |
| D-pad `↑ / ↓` | Dynamics: accent with vibrato / soft |
| D-pad `← / →` | Flat / sharp by a semitone: the only way to notes outside the scale |
| `L1 / R1` | Octave down / up |

## Decisions

| Topic | Decision | Why |
| :-- | :-- | :-- |
| Breaks the habit | The right thumb chooses **and** triggers; the left thumb is only expression | One thumb plays whole melodies |
| Octave carry | `Y+B` (8) and `B` (1 of the next octave) are the same pitch. Rolling clockwise from `Y+B` to `B` keeps the pitch and moves the octave up one; anticlockwise from `B` to `Y+B` moves it down. The roll then continues in the new octave | A scale can run through more than one octave without the shoulders |
| Carried octave | Kept until all four are pressed, or a shoulder is tapped (a shoulder sets the octave outright) | You must always be able to get home |
| Settle window | A change of fingering within 35 ms of a fresh press is a **correction**: the note is re-pitched and the recording is fixed, no slur is recorded. After that, changes are slurs | Pairs arrive a frame apart |
| Jumps | A change to a position that is not a neighbour, without lifting, is a slur too (a wide one) | It happens while rolling fast; a new attack there would stutter |
| `OTHER` fingerings | Three buttons or an opposite pair change nothing: the note stays where it was | Passing through them must not glitch |
| Chord-follow | Not in this plan: degrees are scale degrees | Decide after playing; the buttons being 1, 3, 5, 7 already sits well over the tonic |
| Mono | One note | It is a one-thumb instrument |
| Sound | `HOME_GROUP = "LEAD"`, opens on `SQUARE`, `REGISTER = 4`, `VOICES = 4` | |
| Stage view | `viewKind = "bass"`: degree, octave and the pitch trace; `VIEW.face` names the four buttons 1, 3, 5, 7 | |

## Rows

`PATCH`, `GLIDE` (slur speed: `INSTANT` / `FAST` / `SLOW`; default `INSTANT`).

## Event

One per note, as on Bass: `action` (the button the note started on, or the clockwise-first button of a starting pair), `degree`, `octave`, `semis`, `vel`; slurs are `bend` keyframes `{ dt, degree, octave, semis }`.

`ERASE`: a face button clears the notes that started on it or on its clockwise pair (`B` clears those started on `B` and `B+A`).

## How it is built

- Built on the Bass module (`__index = Bass`) for the voice, bends and trace. It replaces `updateInput`, the rows and the save / load.
- Each frame, read `Input:getFingering()`:
  - `NONE` → release the note (`h:release()`).
  - a position, and no note → start one with `hold(ev, { manual = true })`.
  - a different position while a note sounds → inside the settle window, rewrite the note's pitch (live and recorded); after it, `h:bend(...)`, with the octave carry when the roll crosses the seam.
- The recorded event's fields are changed in place for a correction (`h.rec`).

## Order

| Step | What | Size |
| :-- | :-- | :-- |
| DL1 | Eight positions, notes on and off, corrections inside the settle window | M |
| DL2 | Slurs, the octave carry, all four = home | S–M |
| DL3 | D-pad dynamics and flat / sharp; shoulders; rows, saves, erase map, `VIEW` labels | S |

## Tests

- Each of the eight positions gives its degree; releasing everything ends the note with the right recorded length.
- A pair arriving one frame apart plays and records the pair's degree, with no bend.
- A roll after the window is one event with bends, on one voice (no new attack).
- Clockwise across the seam: same pitch, octave +1, and the next position is degree 2 of the higher octave; anticlockwise undoes it; several laps climb several octaves, up to the voice's range.
- All four returns to the home octave; a shoulder sets the octave outright.
- `OTHER` changes nothing.
- `← / →` shift by a semitone; `↑` accents with vibrato; `↓` is soft.
- A recorded roll replays the same pitches at the same times.
- Erase by face button clears the right notes; rows save and load.

## Playtest

- A one-octave scale up and down by rolling, evenly, without looking?
- Does the octave seam feel natural or like a bug?
- Do pairs land every time, or do passing notes drop out in fast runs?

## Status

DL1 to DL3 are built and tested (`pocketgroove/src/instruments/dial.lua`, `tests/test_dial.lua`, 12 tests). No shared file was touched. Left: the playtest above 📱.

Decisions made while building (say if any is wrong):

- **Shoulders set the octave outright, latched:** `L1` = octave -1, `R1` = octave +1, until all four, the other shoulder, or a roll across the seam changes it. While a note sounds, a shoulder slurs it to the new octave. (The Controls table says "octave down / up", the Decisions table "sets the octave outright"; this reads both as "go to -1 / +1".)
- **Range:** the octave runs from -2 to +2 (degree 8 at +2 is +36, the top of the voices). At the top the carry stops: rolling on past `Y+B` wraps to degree 1 of the top octave (an octave drop). Same at the bottom.
- **The seam by the shortest way round:** a roll carries whenever the shortest way between the two positions crosses the seam, not only `Y+B` ↔ `B`. So `Y` → `B` with the pair missed in a fast roll still climbs; an opposite jump (four steps) never carries.
- **All four** is home (octave 0, degree 1) and has no position: the roll that follows it never carries.
- **Corrections** inside the settle window (timed from the note's start) also move the note's `action` to the new position's button, so erase follows the corrected note; they never carry.
- **Dynamics** (`↑` accent + vibrato, `↓` soft) are read at a note's start; slurs keep them. Flat / sharp follow the D-pad while the note sounds (recorded as bends).
- **A page taking the controls** ends the note; it does not restart until the thumb lifts.
- **`eventClass = "dial"`:** Dial is built on Bass but does not share notes with Bass / Lead on a swap, since they would re-pitch its degrees over chords and lose the accidentals.
- **GLIDE** `INSTANT` is a very fast glide (rate 1000), not a jump in the voice code.

## Open (settle by playing)

1. Is the seam natural? If not: no carry, and the shoulders alone set the octave.
2. Should the degrees follow the chord?
3. A release note (FUTURE_INSTRUMENTS §5, "Push/Pull") as a row here?
