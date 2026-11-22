# Chord Harp — feedback

**Part:** Chords (and the chord source for the other tracks) · **Feel:** an omnichord: chords on the D-pad, strings on the buttons · **Plan:** [PHASE_D.md](../PHASE_D.md) · **Spec:** SPEC §3.3, §5, §7.2 · **Index:** [feedback/](README.md)

---

## How it plays

| Control | Job |
| :-- | :-- |
| D-pad | One of nine chords: neutral I, `↑` ♭VI, `↖` ii, `↗` iii, `←` IV, `→` V, `↓` vi, `↙` ♭VII, `↘` iv |
| `B A Y X` | Pluck one string of the chord each: `B` root, `A`, `Y`, `X` top |
| `L1 / R1` | Voicing an octave down / up |
| `L1 + R1` | Wide voicing |
| Rows | `PATCH` (opens on `HARP`; `SILENT` = a chord track that isn't heard), `COLOUR` (triad, 7th, 9th, sus4, add9) |

The harp's chords are its own: track C sets the chord every follower plays over (it used to be the lowest-numbered harp with chords).

---

## Questions to answer

### Does it do its part? (chords, MUSICAL_PARTS §3)

- [ ] Can I change chord on time without thinking?
- [ ] Do the nine chords cover the progressions I want? Which one is never used, which one is missing?
- [ ] Does the harmonic rhythm work: one chord a bar, two a bar, a change pushed early?
- [ ] Broken chords: does plucking string by string sound like a part?
- [ ] Is playing a full chord at once (four buttons) ever needed? Would a strum gesture help?
- [ ] Do the changes sound smooth (voice leading), or jump about?
- [ ] Is `COLOUR` as a row right, or should it be a gesture while playing?

### As the chord source

- [ ] Do I record chords on the harp first, then build on it? Or does that order feel forced?
- [ ] Is the `SILENT` patch used? Does a chord track without sound make sense in practice?
- [ ] If Strum or a chord track could set chords too, what is the harp's own job?

### Is it fun?

- [ ] Still a favourite (FUTURE_PLANS §2 says the chord mechanic is)? What makes it so?
- [ ] Which sound do I keep it on?

### Open from the plans

- [ ] Do followers sound right on borrowed chords (♭VI, ♭VII, iv), or should 2/4/6 there snap to chord tones?
- [ ] Should a held bass note re-pitch when the chord changes under it? (Today: no.)
- [ ] Should playing the harp live (not recording) override recorded chords for the followers for a moment?
- [ ] A momentary colour gesture for live variation (SPEC §3.3)?

---

## Feedback

*No pass yet.*

---

## Ideas

- Voice leading: choose the inversion nearest the last chord (MUSICAL_PARTS §3.4).

## Decided

## Next
- [ ] Try the new `FOLLOW` row (off by default): the harp plays the chord source's chords (a Chord Track) instead of choosing; the D-pad has no job then. Is that the harp's job once the Chord Track exists?

- [ ] First pass.
