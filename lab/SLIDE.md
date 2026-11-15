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

Not started.

## Open (settle by playing)

1. Default `SNAP`.
2. Should `FOLLOW` exist (the home pitch follows the chord root)?
3. With an analog stick present (FUTURE_PLANS §7), should stick deflection set the speed?
