# Track C: the chord lane — feedback

**Part:** Chords (the song's chords, for every follower) · **Feel:** writing the changes like a chord chart, live or with the clock stopped · **Code:** `src/instruments/lane.lua`, `src/ui/chrome/lane.lua` · **Plan:** [PHASE_K.md](../PHASE_K.md) · **Spec:** SPEC §5.1 · **Index:** [feedback/](README.md)

---

## How it plays

Reach it with `SELECT` taps after track 4 (1 → 2 → 3 → 4 → C). It is silent. Its chords show as a thin strip above the tape deck on every screen.

**The playhead is the cursor; `B` writes where it is heading.**

| Control | Clock running | Clock stopped |
| :-- | :-- | :-- |
| D-pad + `B` | Change at the next bar line (live; written while recording) | Write this box, step on |
| `L1` / `R1` held + `B` | Lasts 2 bars / next half bar | Write 2 bars / 1/2 bar |
| `L1 + R1` + `B` | Next beat | Write a beat |
| `L1` / `R1` tap | — | Step back / on (the chord carries on) |
| `A` held + D-pad | Colour the chord playing | Colour the chord behind the playhead |
| `Y` | Clear the box playing (hold: keep clearing) | Clear the box under the playhead |
| `X` held | Progression wheel (`L1` / `R1`: page 2); let go = picked | The same |
| `X` tap | Stamp the picked progression from the box playing | Stamp it here, step past it |

**Rows:** `BARS` (2 / 4 / 8 / 16), `PREVIEW` (`STRUM` / `STAB` / `OFF`), `SOUND`, `COLOUR`, `SPICE`.

**Try:** stop the clock (`START`), go to track C, and write 16 bars: hold `X`, point at a progression, let go, tap `X` a few times, finish a bar or two with `B`. Then press play, go to the bass, and jam over it.

---

## Questions to answer

- [ ] Writing it out with the clock stopped: quick and obvious, or fiddly?
- [ ] Changing chords live on the bar line: does it feel like playing?
- [ ] The wheel: easy to aim with the thumb? Are two pages right? Which progressions are missing?
- [ ] Hold `X` to pick, tap `X` to place: does the split make sense, or do you want a tap to open the wheel?
- [ ] The strip: readable at 8 and 16 bars? Does the pass frame make sense without the lens?
- [ ] The chart on the stage: grid as it is, or the "reel" (the bar ahead big in the middle)?
- [ ] `PREVIEW`: is `STRUM` the right default? Is the sound right?
- [ ] Live change not recorded (dashed box): useful for jamming, or confusing?
- [ ] Does the Chord Track still need to be a slot instrument?
- [ ] What should the Harp do now that track C sets the chords?

---

## Feedback

### Session 1 — 2026-11-22 📱

- **Good:** the idea.
- **Not yet:** the buttons and stamping still a little unintuitive; BACK on `Y` was strange; a stamp starting from the next slot felt strange.
- **Changed:** `Y` is CLEAR, the box under the playhead, in both modes (the playhead doesn't move; undo stays on `L2 + R2 + LEFT`). A stamp starts in the box the playhead is on, running or stopped.

---

## Ideas

## Decided

- Built as planned in PHASE_K.md, with one change: recorded Harp chords still steer when track C is empty (until the Harp pass).

## Next

- [ ] First pass on the device.
