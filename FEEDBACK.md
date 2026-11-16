# PocketGroove — Playtest feedback

How the app feels on the device, and what to change. The whole app is in testing, so every instrument gets a pass and a section here, the library ones and the newer ones alike. The plans and SPEC say what was built; this file says how it played.

**How to use it:** after a session, copy the template at the bottom, fill in what you noticed, and put the newest session first. Keep the per-instrument sections up to date: they are the to-do list for each instrument's pass. When something settles into a decision, move it into SPEC or the instrument's plan.

To judge an instrument by the part it plays (lead, chords, texture, rhythm, bass), see [MUSICAL_PARTS.md](MUSICAL_PARTS.md) §8.

---

## Where things stand

| Instrument | Part | Feel so far | Main thing to fix | Pass |
| :-- | :-- | :-- | :-- | :-- |
| Drums | Rhythm | — | — | [ ] |
| Hand Drums | Rhythm | Felt nice | Nothing specific yet | [ ] |
| Chord Harp | Chords | — | — | [ ] |
| Strum | Chords | Could be good | Could set the chords, as the Harp does | [ ] |
| Bass | Bass | — | — | [ ] |
| Pad | Texture | — | — | [ ] |
| Lead / Arp | Lead | — | — | [ ] |
| Dial | Lead | ★ Most fun | Moving round sounds too quiet: wants a re-strike, not only a glide | [ ] |
| Slide | Lead | Could be good, unsure | Play more before deciding | [ ] |
| Valves | Lead | Liked the idea | Needs brass sounds | [ ] |

**Overall:** every instrument needs refinement, one at a time. All ten stay in: the carousel makes them easy to go through, and ten doesn't feel like too many.

---

## Across the app

### More sounds (patches)

The newer instruments need sounds made for how they play. Today Dial, Slide and Valves open on the `LEAD` group (`SQUARE`, `SAW`, `PLUCK`, `KEYS`) and Strum on `PLUCK`.

- **Brass:** for Valves first, probably Dial and Slide too. A trumpet, a horn section, a muted horn.
- **Others:** bowed strings for Strum's bow, a reed or woodwind, leads that keep their level through a slur.
- **Next:** a patch wave by part (list in MUSICAL_PARTS §7.3): add a `BRASS` group in `synth/synths_bank.lua` and point Valves' `HOME_GROUP` at it.

### Where chords come from

Today the Chord Harp is the track the others follow. Two ideas:

1. **Strum as a chord source**, as the Harp is. Strum follows chords today, so it would need to *choose* them: the Harp's chord map on the D-pad (MUSICAL_PARTS §3.4).
2. **A separate chord track** whose only job is the progression. Part of this exists: the Harp on its `SILENT (CHORDS ONLY)` patch is a chord track that isn't heard.

- **Next:** decide between the two, or both.

### What each part needs

Playing Dial and the other lead instruments raised the question: what does a lead part need (moves on the scale, bends, skips, timing), and the same for chords, texture and rhythm. That is written up in [MUSICAL_PARTS.md](MUSICAL_PARTS.md), with what each instrument covers today and the direction it suggests.

---

## By instrument

### Drums

- **Not played in a pass yet.**

### Hand Drums

- **Good:** felt nice.
- **Next:** play more; check the open points in [lab/HANDS.md](lab/HANDS.md) Status (a face button and a direction a frame apart give two hits; the D-pad label still says `EXPRESSION`).

### Chord Harp

- **Not played in a pass yet.**

### Strum

- **Good:** could be good.
- **Idea:** let it set the chords for the other tracks, as the Harp does (above).
- **Next:** decide the chord-source question; then the plan's open points (string map, louder downstrokes on the beat, neutral D-pad).

### Bass

- **Not played in a pass yet.**

### Pad

- **Not played in a pass yet.**

### Lead / Arp

- **Not played in a pass yet.**

### Dial ★

- **Good:** the most fun of the newer instruments.
- **Not yet:** with some sounds, moving round the dial is too quiet. Every move slurs the one held note to a new pitch (no new attack), so a sound that fades after its attack fades away while you roll.
- **Idea:** a choice of how a move sounds: `GLIDE` (today), `BEND` (instant slur) or `NEW NOTE` (each position strikes a fresh attack). Possibly a default per patch: plucky sounds strike, sustained ones slur. Better still, per note (MUSICAL_PARTS §2.2).
- **Next:** add the choice, try it with each patch, pick the defaults.

### Slide

- **Good:** could be good.
- **Not yet:** unsure about it.
- **Next:** a session on the plan's questions: can you land a note by ear with `SNAP` off; is `SOFT` expressive or just out of tune?

### Valves

- **Good:** liked the idea.
- **Not yet:** needs sounds that suit it. The saw lead doesn't sell it as brass.
- **Next:** brass patches, then play again: is the chart learnable; does the 35 ms slur wait feel late?

---

## Sessions

### Session 1 — first look at the five new instruments 📱 (2026-11-16)

- **Build:** `claude/vigilant-gates-h1z44f` at the five-instrument rebuild.
- **Ranking:** Dial > Hand Drums > Valves (idea) > Strum ≈ Slide.
- **Decided:** all of them stay in, as ordinary instruments; the whole app is in testing, and every instrument gets a pass.
- **Notes:** as above.

<!--
Template — copy above the newest session:

### Session N — <focus> 📱 (YYYY-MM-DD)

- **Build:** <branch / commit>
- **Played:** <which instruments, how long>
- **Good:**
- **Not yet:**
- **Ideas:**
- **Next:**
-->
