# Chord Track — feedback

**Part:** Chords (the chord source, nothing else) · **Feel:** writing the song's changes, not playing them · **Code:** `src/instruments/chords.lua` · **Index:** [feedback/](README.md)

Built after noticing the Chord Harp was mostly used on `SILENT` as a chord picker. This is that job as its own instrument, to find out whether it should stay an instrument or become a feature (a hidden fifth track).

---

## How it plays

| Control | Job |
| :-- | :-- |
| D-pad | The Harp's nine chords (same map). The progression's chord for this point in the loop is marked `>`, so you enter a progression by following the numerals |
| `B` WRITE | Write the D-pad's chord (while recording; otherwise the others follow it live) |
| `A` COLOUR | Hold `A` and point the D-pad: the chord under the playhead takes that colour. ↑ 7 · ↗ 9 · → add9 · ↖ 6 · ← sus4 · ↙ sus2 · ↓ dim · ↘ aug · neutral = plain. No chord there: sets the colour new chords get |
| `Y` DELETE | Delete the chord under the playhead; keep holding to delete each chord the playhead reaches |
| `X` STAMP | Fill the whole loop with the progression |
| `L1` / `R1` / both | `B` snaps to the bar / half bar / beat. Hold `B` with a shoulder and it writes again on every line |
| Rows | `PATCH` (opens on `SILENT`), `COLOUR` (for new chords), `PROGRESSION`, `LENGTH` (chord length for STAMP and the `>` guide), `SPICE` |

COLOUR, DELETE and STAMP are edits: they work without recording, and each press is one undo. The middle of the screen shows numerals (the progression, and this track's loop as `I V7 | vi IV`); the tape deck shows chord names.

**SPICE** (`OFF` / `LIGHT` / `WILD`): on playback, some plain chords get a random colour, new each pass. Followers play the coloured chord too; the recording doesn't change. `LIGHT` picks from 7, add9, sus4 (minor: 7, add9); `WILD` adds 9, 6, sus2, and aug on V.

**Ways to lay down chords:**

1. **Stamp:** pick a progression on the Track page, press `X`, then colour or delete single chords.
2. **Follow the guide:** record, hold `L1`, and press `B` with the D-pad on the `>` numeral each bar.
3. **Steer:** record, hold `B + L1`, move the D-pad to the next chord before each bar line.

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

- [ ] Which way of laying chords did I use: stamp, follow the guide, steer?
- [ ] Is the colour wheel layout (up richer, down tense, sides sus) easy to remember?
- [ ] SPICE: musical, or just random? Should LIGHT and WILD pick differently?
- [ ] Is the bar / half bar / beat snap the right set? Is "nearest line" right, or should a press always wait for the next line?
- [ ] Which progressions got used? Which one was missing?
- [ ] Did I want to hear the chords (a patch), or is silent right?
- [ ] Should it be an instrument, or a hidden fifth track drawn over the tape deck?
- [ ] If it becomes a feature: where do the controls live? (A held button on any track? A Track page row?)
- [ ] Does the Harp still have a job once this exists? (Playing chords that are heard.)
- [ ] Stamp ignores record mode. Right, or confusing?

---

## Feedback

### Session 3 — 2026-11-18 📱

- **Good:** stamp makes it easy; chord names on the tape deck.
- **Not yet:** the progression showed chord names, but the D-pad is in numerals, so numerals are how you'd enter it. Wording and buttons confusing (NEXT / TOP). Wants a delete button.
- **Ideas:** a single augmented chord; random colours ("randomly augmented"). Leaning towards it staying a slot; maybe a track later.
- **Changed:** numerals in the readout and a `>` guide on the D-pad; buttons now WRITE / COLOUR / DELETE / STAMP (NEXT and TOP gone); hold `A` + D-pad colours one chord (aug, dim, sus2, 6 added to the colours); SPICE row for random colours.

---

## Ideas

- **Hidden fifth track:** chords drawn as a thin strip along the top of the tape deck, always there; any instrument could edit it from a held combo.
- **More chords for progressions:** a progression could name chords outside the nine (III, II7), written only by STAMP / NEXT.
- **Section variations:** verse / chorus progressions per scene, once song building lands (FUTURE_PLANS §8).
- **Voice leading** for the strum when a patch is on.

## Decided

## Next

- [ ] First pass.
