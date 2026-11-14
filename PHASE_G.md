# Phase G · Mix & FX finish — Working Plan

Part of [ROADMAP.md](ROADMAP.md). Design: [SPEC.md](SPEC.md) §3.5, §3.6, §4, §9.3.

**Goal:** the tools for balancing and recording a jam are finished: the master filter punch-in really filters, the meters show what is sounding, recording can start on a bar line after a count, and undo takes back one pass at a time.

**Rule for every step:** one step = one or a few commits, app playable, tests green. 📱 = check on the RG35XX.

---

## Decisions

| Topic | Decision | Why |
| :-- | :-- | :-- |
| `R2 + ←` | A **real low-pass sweep** on everything: it closes in about 0.2 s while held and opens again on release, using the same filter as the Track page's `TONE` (the two multiply) | Roadmap; a filter drop is the classic punch-in |
| Without EFX | The old volume duck stays as the fallback | The filter needs OpenAL EFX, which is still unchecked on the device |
| Meters | Levels are **estimated from the voices that are sounding** (each voice's gain and envelope, summed per track as power), not from the recorded velocity of the last note | LÖVE can't read the output signal; this still follows live playing, held notes, volume and mutes |
| Where | Tape deck: the bar at the right of each lane. Mix page: a live bar beside each fader with a peak mark, and one for the master that turns red when the sum is likely to clip | Roadmap |
| Meter motion | Rises at once, falls at 2.5 per second; the peak mark holds 0.8 s | Readable at a glance |
| Count-in control | Transport `X` now cycles **click: off → on → count-in → on + count-in** | SPEC §3.5 asked "X hold, or a click mode": a mode costs no new button |
| What count-in does | A record **tap** (latch) arms recording instead of starting it: beats are clicked and counted down in the top bar, and recording starts at the **next bar line** (the one after, if that is under two beats away). Tap again to cancel | In a loop, starting on the bar matters more than a fixed four beats |
| Early notes | Recording opens a 1/16 before the bar line | A note played a touch early still lands on beat 1 |
| From stopped | With the clock paused, the count-in starts it one bar before the loop's start | A true "1-2-3-4" into bar 1 |
| Hold-to-record | Unchanged: holding `L2` punches in at once | It is the instant path |
| Takes per pass | While recording, a new take starts every time a full loop has gone by since recording began, so undo removes one pass | SPEC §4 |
| Replace vs overdub ❓ | **Not built.** Recording stays overdub | Replace erases material as the playhead passes, so it needs an obvious control, and the Transport page has no free button. Needs a decision |
| Auto-stop after one pass ❓ | Not built | Same: needs a control |

---

## Order

| Step | What | Size |
| :-- | :-- | :-- |
| G1 | Master low-pass on `R2 + ←` | S |
| G2 | Meters from sounding voices; tape deck and Mix page | M |
| G3 | Click modes and count-in | M |
| G4 | Takes split per loop pass | S |

## Tests

- G1: holding `R2 + ←` closes the filter on one-shots and sustained voices already sounding and on new ones; it multiplies with a track's tone; it opens on release; without EFX the volume ducks instead.
- G2: a hit raises its track's meter and the master's, then they fall; a held note keeps its meter up; track volume scales it; other tracks stay at zero; the peak mark holds.
- G3: `X` cycles the four modes and they save; a tap arms, counts, and latches at the bar line; notes before that aren't recorded; a second tap cancels; from paused it starts a bar early; click-only-while-counting; hold-to-record is immediate.
- G4: three passes of recording give three takes and undo removes them one at a time; a note held across the boundary stays whole.

## Exit checklist

- [ ] `python3 tests/run.py` green
- [ ] The filter sweep is audible and cheap on the device (EFX present?) 📱
- [ ] Meters look right against what is heard; the red master mark matches real distortion 📱
- [ ] Count-in feels natural at slow and fast tempos 📱

## Open

1. Replace vs overdub, and auto-stop after one pass: where would the control go?
2. Should the count-in be a fixed four beats instead of "to the next bar line"?
