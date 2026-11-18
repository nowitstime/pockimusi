# Dial — feedback

**Part:** Lead · **Feel:** roll the thumb round the scale; stepwise melody, runs, trills · **Plan:** [lab/DIAL.md](../lab/DIAL.md) · **Spec:** SPEC §7.6 · **Index:** [feedback/](README.md)

---

## How it plays

| Control | Job |
| :-- | :-- |
| Face diamond | Eight positions: `B` 1 · `B+A` 2 · `A` 3 · `A+X` 4 · `X` 5 · `X+Y` 6 · `Y` 7 · `Y+B` 8. A note sounds while any face button is down |
| Roll to the next position | Slur: the same note moves to the new pitch, no new attack |
| Lift and press | A new note |
| Roll past `Y+B` to `B` | Up an octave (and back down the other way) |
| All four | Home: octave 0, degree 1 |
| D-pad `↑ / ↓` | Accent with vibrato / soft (read at the note's start) |
| D-pad `← / →` | Flat / sharp by a semitone, while the note sounds |
| `L1 / R1` | Octave −1 / +1, stays until changed |
| Rows | `PATCH` (lead sounds first, opens on `SQUARE`), `GLIDE` (`INSTANT` / `FAST` / `SLOW`) |

---

## Questions to answer

### Does it do its part? (lead, MUSICAL_PARTS §2)

- [ ] Can I play a tune I can hum, without looking?
- [ ] A one-octave scale up and down by rolling, evenly? (the plan's slot test)
- [ ] Are runs aimed? Can I land the run's last note on a chord tone on the beat?
- [ ] Do trills (rocking between a button and its pair) sound musical, or like a glitch?
- [ ] Repeated notes: is lifting and re-pressing fast enough for a riff?
- [ ] Leaps: do jumps across the dial work, or do they smear because they slur?
- [ ] Do 1 3 5 7 on the single buttons help me land chord tones on strong beats?
- [ ] Rests: can I stop cleanly between phrases?
- [ ] Notes outside the scale (`← / →`): useful for blue notes, or never touched?
- [ ] Does it want vibrato on long notes without having to accent them?

### Is it fun?

- [ ] What made it the most fun of the five? (write it down, so refinement keeps it)
- [ ] What style did it pull me towards: folk melody, chiptune runs, synth lead, something else?
- [ ] Does rolling feel like playing an instrument, or like operating a control?
- [ ] Is it more fun fast (runs) or slow (melodies)?

### The quiet-roll problem

- [ ] With which sounds is moving round too quiet? (fading sounds: `PLUCK`, `KEYS`?)
- [ ] Which do I want: every move re-strikes, every move slurs, or choose per note?
- [ ] If per note: what gesture would choose it? (a D-pad direction, a shoulder, roll speed?)
- [ ] Should each sound have its own default (plucks re-strike, sustained sounds slur)?
- [ ] Is `GLIDE` still wanted once re-strike exists?

### Open from the plan

- [ ] Is the seam (the octave carry past `Y+B`) natural? If not: no carry, and the shoulders alone set the octave.
- [ ] Should the degrees follow the chord?
- [ ] A release note ("Push/Pull", FUTURE_INSTRUMENTS §5) as a row?
- [ ] Shoulders set the octave outright and it stays: right, or should they be momentary?

---

## Feedback

### Session 1 — 2026-11-16 📱

- **Good:** the most fun of the five new instruments.
- **Not yet:** with some sounds, moving round the dial is too quiet. Every move slurs the held note to a new pitch, so a sound that fades after its attack fades away while you roll.
- **Ideas:** a choice of how a move sounds: `GLIDE` (today), `BEND` (instant slur), `NEW NOTE` (a fresh attack per position); maybe a default per sound.

---

## Ideas

- Re-strike vs slur: as a row first, a default per sound, then a per-note gesture (MUSICAL_PARTS §2.2).
- Sustaining lead sounds that keep their level through a slur (MUSICAL_PARTS §7.3).

## Decided

- Stays in as an ordinary instrument (session 1).

## Next
- [ ] New screen panel: the dial (positions where the buttons are, a needle, the roll lit) and the 8 notes it walks. Does it help find your place?
- [ ] Try the new `FOLLOW` row (off by default): positions become degrees over the current chord, as on the Bass; flat / sharp still apply.

- [ ] Add the re-strike choice; try it with each sound; pick defaults.
