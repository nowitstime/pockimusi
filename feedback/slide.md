# Slide — feedback

**Part:** Lead · **Feel:** steer one pitch instead of choosing notes; bends, glides, voice-like · **Plan:** [lab/SLIDE.md](../lab/SLIDE.md) · **Spec:** SPEC §7.6 · **Index:** [feedback/](README.md)

---

## How it plays

| Control | Job |
| :-- | :-- |
| D-pad `↑ / ↓` | The pitch rises / falls while held, and stays where it's left |
| D-pad `← / →` | Step to the previous / next scale note |
| `B` | A note at the current pitch, while held |
| `A` | A note that settles on the nearest scale note |
| `Y` | Dive: the note falls an octave as it fades |
| `X` | Accent with vibrato |
| `L1 / R1` | Octave down / up; held while sliding = four times faster |
| `L1 + R1` | Back to the root |
| Rows | `PATCH` (opens on `SQUARE`), `SPEED`, `SNAP` (`OFF` / `SOFT` / `HARD`) |

---

## Questions to answer

### Does it do its part? (lead, MUSICAL_PARTS §2)

- [ ] Can I land on a note by ear with `SNAP` off? (the plan's slot test)
- [ ] With `SNAP` soft: expressive, or just out of tune?
- [ ] Bending *into* a note: press low and slide up. Does it sound like a guitar or a voice?
- [ ] Can I play a simple tune at all, or is it only for long, expressive notes?
- [ ] Steps with `← / →`: quick enough for a melody line?
- [ ] Does the `Y` dive work as a fall-off at the end of a phrase?
- [ ] Is vibrato on `X` enough, or does it want vibrato on any long note?
- [ ] Blue notes: does sliding between scale notes give that bluesy in-between pitch?

### Is it fun?

- [ ] What does it make me play: slide guitar, theremin, singing synth, sirens?
- [ ] Does keeping the pitch between notes feel freeing, or confusing?
- [ ] Is it more fun over chords (with other tracks), or alone?
- [ ] What would make me sure about it? (it was "could be good, unsure")

### Open from the plan

- [ ] Default `SNAP`: `OFF`, `SOFT` or `HARD`?
- [ ] Should `FOLLOW` exist (the home pitch follows the chord root)?
- [ ] With an analog stick (FUTURE_PLANS §7), should deflection set the speed?
- [ ] Only held notes are steered; a released note's tail keeps its pitch. Right?
- [ ] Mono on every sound, ringing ones too. Right?
- [ ] Bass / Lead notes are cleared on a swap to Slide. Should they carry over?

---

## Feedback

### Session 1 — 2026-11-16 📱

- **Good:** seemed like it could be good.
- **Not yet:** unsure about it.

---

## Ideas

- Sounds that sing: a sine or triangle lead, a vocal "ooh", slide guitar (MUSICAL_PARTS §7.3).
- Delayed vibrato on long notes, from the shared expression toolkit (MUSICAL_PARTS §7.2).

## Decided

- Stays in as an ordinary instrument (session 1).

## Next
- [ ] Try the new `FOLLOW` row (off by default): steps and snapping land on the current chord's notes; the pitch stays free.

- [ ] A session focused on `SNAP` and bending into notes.
