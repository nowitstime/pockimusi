# Slide (`SLIDE`) — Working Plan

Part of [lab wave 1](README.md). Needs: [L0](L0_FOUNDATION.md). Independent of the other four instruments. Background: FUTURE_INSTRUMENTS §4.4.

**Feel:** like a trombone, a fretless or a theremin. Holding `↑` makes the pitch rise for as long as you hold it; letting go leaves it where it is. You steer the pitch instead of choosing it.

**Why it matters beyond itself:** this is the software test for a hardware slider. If continuous pitch is not fun here, a physical slider will not be either.

**Owns:** `pocketgroove/src/instruments/slide.lua`, `tests/test_slide.lua`, this file. Touches nothing else.

---

## Controls

| Control | Job |
| :-- | :-- |
| D-pad `↑ / ↓` | The pitch rises / falls smoothly while held, and stays where it is left |
| D-pad `← / →` | Step to the previous / next scale note |
| `B` | Note: sounds while held, at the current pitch |
| `A` | Note that settles on the nearest scale note when the D-pad is let go |
| `Y` | Dive: a note that falls away on release |
| `X` | Accent with vibrato |
| `L1 / R1` | Octave down / up; held while sliding = four times faster |
| `L1 + R1` | Back to the root |

## Decisions

| Topic | Decision | Why |
| :-- | :-- | :-- |
| Breaks the habit | The D-pad is speed, not position, and the pitch is remembered between notes | That is the instrument |
| The pitch | One number per track, in semitones with fractions, kept between notes and shown on the stage even when silent | You steer before you play as well as while |
| Speed | `SPEED` row: `SLOW` 4, `MEDIUM` 8, `FAST` 14 semitones per second; a shoulder held while sliding multiplies by 4 | |
| Range | Two octaves either side of the root; the pitch stops at the ends | A voice reaches ±3 octaves; the stage needs a scale |
| `SNAP` row | `OFF`: the pitch stays exactly where it is left. `SOFT`: on letting go of the D-pad it eases to the nearest scale note over about 0.25 s. `HARD`: it moves in scale steps only. Default `SOFT` | Out of tune should be a choice |
| `A` | Always settles as `SNAP = SOFT` does, whatever the row says | A "safe" note under the thumb even with `SNAP` off |
| `Y` dive | On release the pitch falls an octave over the patch's release; the track's pitch itself does not move | A gesture, not a change of place |
| Mono | One note at a time, as the Bass on a sustaining patch; a new press takes over | |
| Sound | `HOME_GROUP = "LEAD"`, opens on `SQUARE`, `REGISTER = 4`, `VOICES = 4`. `THROAT`, `SHEPARD` and `JUST` are worth trying here | |
| `FOLLOW` | Not in this plan | Decide after playing whether the home pitch should follow the chord root |
| Stage view | `viewKind = "bass"`: the pitch trace shows the slide. The degree readout shows the nearest scale note, with `+` or `−` when between notes | Free, and it is the right picture |

## Rows

`PATCH`, `SPEED`, `SNAP`.

## Event

A held note, as on Bass, with `action`, `semis` (fractional), `vel`, and `bend` keyframes `{ dt, semis }` with no degree.

- Keyframes are thinned: at most one per 30 ticks while sliding, plus one when the slide stops, so the end pitch is exact.
- The dive is not recorded as bends: `action = "Y"` replays it.

## How it is built

- Built on the Bass module (`__index = Bass`) for the voice, `bendTo`, the playback of bends and the trace. It replaces `updateInput`, the rows and the save / load.
- Each frame: move the track's pitch from the D-pad; if a note is held and the pitch moved, `h:bend({ semis = ... })` at the thinned rate and glide the live voice every frame.
- Glide rate fast enough that the voice follows the steering without lag.

## Order

| Step | What | Size |
| :-- | :-- | :-- |
| SL1 | The pitch: steering, steps, shoulders, range; `B` notes; recording with thinned bends | S–M |
| SL2 | `SNAP` row and the `A` note | S |
| SL3 | `Y` dive, `X` accent; rows, saves, `VIEW` labels | S |

## Tests

- Holding `↑` for one second raises the pitch by the row's speed, and it stays on release; with a shoulder, four times as far; it stops at the range's ends.
- `← / →` land exactly on the neighbouring scale notes, from on a note and from between notes.
- Both shoulders return the pitch to the root.
- A slide while holding records at most one keyframe per 30 ticks and a last one at the stopping pitch; playback follows the same curve and ends on the same pitch.
- `SNAP = SOFT` ends on a scale note after the D-pad is released; `OFF` does not move; `HARD` never rests between notes; `A` settles with `SNAP` off.
- `Y` falls on release, live and on playback, and the next note starts from the pitch before the dive.
- Rows and the pitch save and load.

## Playtest

- Can you land on a target note by ear with `SNAP` off?
- With `SNAP = SOFT`, does it sound expressive or just out of tune?
- Is steering with a D-pad enough, or does it only make sense with an analog stick?

## Status

SL1 to SL3 are built and tested (`tests/test_slide.lua`, 10 tests). Left: the playtest. No shared file was touched.

Decisions made while building (say if any is wrong):

- **Shoulders: octave or speed.** A shoulder pressed while `↑ / ↓` is held only speeds the slide up; pressed otherwise it jumps an octave at once (no wait for the release). Holding a shoulder first and then sliding jumps the octave *and* slides four times faster. An octave that would leave the range does nothing (rather than stopping at the end, which would change the note).
- **The pitch is kept relative to the root,** so changing the key moves it with the key. Range ±24 from the root.
- **`A` pressed between notes** (with `SNAP` off, or after a step out of tune) eases onto the nearest scale note straight away, not only when the D-pad is let go. It is the "safe" note.
- **Settling moves the track's pitch,** for `SOFT` and for `A` alike (the pitch is one number). Any D-pad or shoulder move cancels a settle in progress.
- **`HARD`** steers a hidden position at the row's speed and sounds the nearest scale note, so a held `↑` walks up the scale at roughly the same speed. Switching the row to `HARD` snaps the pitch.
- **Dive length.** "Over the patch's release" is 90 ms on `SQUARE`, too short to hear, so a `Y` note's voice gets a release of at least 0.4 s (`DIVE_TIME`) and falls an octave over it.
- **Keyframes.** While sliding, one keyframe at most every 30 ticks, plus one when the pitch stops (steps and octave jumps are recorded on the next frame, when the pitch is still). Playback slides in a straight line between keyframes up to 90 ticks apart (`MAX_SEGMENT`) and steps to a keyframe after a longer still stretch, so a slide plays back within a fraction of a semitone of how it was played.
- **Only held notes are steered;** a released note's tail keeps its pitch (the Bass bends tails; here that would drag every note's fade along the next slide).
- **Mono on every patch,** ringing ones too: a new press releases the held note, and the old note's recorded length ends where the new one starts.
- **`eventClass = "slide"`** (its own): Bass / Lead notes are not kept on a swap to Slide or back. Slide notes would play on Bass, but Bass notes carry degrees Slide would ignore; decide after playing.
- **Stage.** The large note is the nearest scale note to the track's pitch (shown when silent too), with `+` / `-` between notes; the small line reads `DEG 2+  -  OCT 0  -  SNAP SOFT  -  NOTE`. The Bass view's capsules show `GLIDE FAST` and `FOLLOW OFF`, which are true but say nothing useful; left as is (labels only).
- **No preview scene:** `tools/screenshot.py` keeps its scenes in the shared file, so none was added.

## Open (settle by playing)

1. Default `SNAP`.
2. Should `FOLLOW` exist (the home pitch follows the chord root)?
3. With an analog stick present (FUTURE_PLANS §7), should stick deflection set the speed?
