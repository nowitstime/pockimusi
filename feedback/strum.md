# Strum — feedback

**Part:** Chords · **Feel:** choose the notes with the thumbs, strum with the shoulders; rhythm guitar · **Plan:** [lab/STRUM.md](../lab/STRUM.md) · **Spec:** SPEC §7.6 · **Index:** [feedback/](README.md)

---

## How it plays

| Control | Job |
| :-- | :-- |
| D-pad | Degree, as Bass (neutral = root). Silent |
| `B A Y X`, held | Add strings above the root, silently: `B` third, `A` fifth, `X` octave, `Y` seventh. None held = one note |
| `R1` | Downstroke: the root and every held string, low to high |
| `L1` | Upstroke: the same, high to low |
| `L1 + R1` together | Damp: everything ringing stops |
| On a sustaining sound | Bowed: the stroke lasts while the shoulder is held; the D-pad glides the strings |
| Rows | `PATCH` (plucked sounds first, opens on `NYLON`), `REGISTER`, `STRUM` (`TIGHT` / `LOOSE`), `FOLLOW` |

Easy shapes: `B + A` a triad, `A + X` root-fifth-octave, `Y + B` a seventh without its fifth, all four the full chord.

---

## Questions to answer

### Does it do its part? (chords, MUSICAL_PARTS §3)

- [ ] Steady alternate-picked 1/16 notes at 120 BPM for two bars? (the plan's slot test)
- [ ] Can I play a strumming *pattern* (down, down-up, up-down-up), not just strokes?
- [ ] Do stabs work: short chords on the off-beats (reggae, funk)?
- [ ] Does damping fire by accident? Does it work as a muted "chuck"?
- [ ] Does the bow (on a sustaining sound) earn its place?
- [ ] Do the changes sound smooth when the chord moves?
- [ ] Does it sit well with the Harp, or do the two fight over the same space?

### Should it set the chords?

- [ ] Do I want to *choose* chords on Strum (the Harp's chord map on the D-pad), or keep it following?
- [ ] If it chose chords, what should the face buttons become: voicings (open, close, high), or colour?
- [ ] Or is a separate chord track the better home for chord choice?

### Is it fun?

- [ ] Does strumming with the shoulders feel like rhythm guitar?
- [ ] What style did it pull me towards: folk, funk, reggae, indie?
- [ ] Is choosing strings silently with the thumbs natural, or a lot to think about?

### Open from the plan

- [ ] The string map (`B` third, `A` fifth, `X` octave, `Y` seventh).
- [ ] Should a downstroke on the beat and an upstroke off it differ in level, as a hand does?
- [ ] No D-pad direction: follow the chord root (today), or keep the last degree?
- [ ] Damp is not recorded and playback never damps. Should a damp become a recorded event?

---

## Feedback

### Session 1 — 2026-11-16 📱

- **Good:** seemed like it could be good.
- **Ideas:** it could be the source of chords for the other tracks to follow, as the Harp is; or a separate chord track instead.

---

## Ideas

- A `CHORDS` mode: the Harp's nine-chord map on the D-pad, voicings on the face buttons, strumming on the shoulders (MUSICAL_PARTS §3.4).
- Sounds: electric guitar (clean and muted), bowed strings for the bow, organ (MUSICAL_PARTS §7.3).

## Decided

- Stays in as an ordinary instrument (session 1).

## Next

- [ ] Decide the chord-source question (feedback/README "Decisions waiting").
