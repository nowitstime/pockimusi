# Chord Track — feedback

**Part:** Chords (the chord source, nothing else) · **Feel:** writing the song's changes, not playing them · **Code:** `src/instruments/chords.lua` · **Index:** [feedback/](README.md)

Built after noticing the Chord Harp was mostly used on `SILENT` as a chord picker. This is that job as its own instrument, to find out whether it should stay an instrument or become a feature (a hidden fifth track).

---

## How it plays

| Control | Job |
| :-- | :-- |
| D-pad | The Harp's nine chords (same map). The progression's next chord is marked `>` |
| `B` PLACE | Write the D-pad's chord |
| `A` NEXT | Write the progression's next chord, no D-pad needed |
| `Y` TOP | Back to the progression's first chord, and write it |
| `X` STAMP | Fill the whole loop with the progression. Works without recording; undo brings the old chords back |
| `L1` / `R1` / both | Snap to the bar / half bar / beat. Hold `B` or `A` with a shoulder and it writes again on every line |
| Rows | `PATCH` (opens on `SILENT`), `COLOUR`, `PROGRESSION`, `LENGTH` (chord length for STAMP: `FIT`, 2 bars, 1 bar, 1/2 bar, 1 beat) |

Grid opens on `1/4`, so a plain press lands on a beat. Every chord is recorded on `B`, so a new one on a line replaces the old, and `CLR B` on the Erase page clears them.

**Ways to lay down chords:**

1. **Stamp:** pick a progression on the Track page, press `X`. Done.
2. **Step:** record, hold `L1`, tap `A` once a bar (anywhere in the first half of the bar lands on its start).
3. **Auto:** record, hold `A + L1`: one progression chord per bar, hands off.
4. **Steer:** record, hold `B + L1`, move the D-pad to the next chord before each bar line.

**Chord source:** the top-most chord track with recorded chords sets the chords (Chord Track or Chord Harp). The readout says whether this track is the one.

### Progressions

All built from the nine D-pad chords, so any of them can be played by hand too.

| Name | Chords | Known as |
| :-- | :-- | :-- |
| POP | I V vi IV | the four-chord pop song |
| 50S | I vi IV V | doo-wop, ballads |
| SAD POP | vi IV I V | pop, starting on the minor |
| ROCK | I IV V IV | three-chord rock |
| JAZZ ii-V-I | ii V I I | the jazz turnaround |
| ROYAL ROAD | IV V iii vi | J-pop |
| DESCEND | vi V IV V | minor, stepping down |
| MIXO | I ♭VII IV I | classic rock |
| HEROIC | ♭VI ♭VII I I | the big lift into I |
| BITTERSWEET | I IV iv I | major to minor IV |
| CANON | I V vi iii IV I IV V | Pachelbel |
| BLUES 8 | I V IV IV I V I V | eight-bar blues |

Not possible with the nine chords yet: anything with a major III or II (secondary dominants), 12-bar blues (loops are 2 or 4 bars), the true Andalusian cadence (needs a major V in a minor key).

---

## Questions to answer

- [ ] Which way of laying chords did I use: stamp, step, auto, steer?
- [ ] Is the bar / half bar / beat snap the right set? Is "nearest line" right, or should a press always wait for the next line?
- [ ] Which progressions got used? Which one was missing?
- [ ] Did I want to hear the chords (a patch), or is silent right?
- [ ] Should it be an instrument, or a hidden fifth track drawn over the tape deck?
- [ ] If it becomes a feature: where do the controls live? (A held button on any track? A Track page row?)
- [ ] Does the Harp still have a job once this exists? (Playing chords that are heard.)
- [ ] Stamp ignores record mode. Right, or confusing?

---

## Feedback

*No pass yet.*

---

## Ideas

- **Hidden fifth track:** chords drawn as a thin strip along the top of the tape deck, always there; any instrument could edit it from a held combo.
- **Progression → D-pad:** while a progression is picked, `A` NEXT could also show the next two chords, so you can learn the shape and then play it by hand.
- **More chords for progressions:** a progression could name chords outside the nine (III, II7), written only by STAMP / NEXT.
- **Section variations:** verse / chorus progressions per scene, once song building lands (FUTURE_PLANS §8).
- **Voice leading** for the strum when a patch is on.

## Decided

## Next

- [ ] First pass.
