# Lab wave 1 — Playtest feedback

What playing the lab instruments on the device showed. The plans say what was built; this file says how it felt and what to change. When an instrument's feedback settles into a decision, copy the verdict into its plan.

**How to add a session:** copy the template at the bottom, fill in what you noticed, and put the newest session first. Keep notes short and in your own words; the "Next" lines are the to-do list for refinement.

---

## Where things stand

| Instrument | Feel so far | Keep in the tabs? | Main thing to fix |
| :-- | :-- | :-- | :-- |
| [Dial](DIAL.md) | ★ Most fun | Yes | Moving round sounds too quiet: wants a new attack per note as an option, not only a glide |
| [Hand Drums](HANDS.md) | Felt nice | Yes | Refine (nothing specific yet) |
| [Valves](VALVES.md) | Liked the idea | Yes | Needs sounds made for it (brass) |
| [Strum](STRUM.md) | Could be good | Yes | Could be the chord source for the other tracks, as the Harp is |
| [Slide](SLIDE.md) | Could be good, unsure | Yes, for now | Play more before deciding |

**Overall:** all five need refinement, one at a time. Most stay in for now: the carousel makes them easy to go through, and ten doesn't feel like too many.

---

## Across all instruments

### More sounds (patches)

The lab instruments need sounds made for how they play. Today Dial, Slide and Valves open on the `LEAD` group (`SQUARE`, `SAW`, `PLUCK`, `KEYS`) and Strum on `PLUCK`.

- **Brass:** for Valves first, and probably Dial and Slide too. Something like a trumpet, a horn section, a muted horn.
- **Others to try:** bowed strings for Strum's bow, a reed or woodwind, a sound that keeps its loudness through a slur.
- **Next:** a patch wave: decide a list, add a `BRASS` group in `synth/synths_bank.lua`, point Valves' `HOME_GROUP` at it.

### Where chords come from

Today the Harp is the track that sets the chords others follow. Two ideas:

1. **Strum as a chord source**, as the Harp is. Strum already picks a chord shape, so it would mostly be a matter of publishing it.
2. **A separate chord track**: a track whose only job is the chord progression, so no instrument has to carry it. Part of this exists already: the Harp on its `SILENT (CHORDS ONLY)` patch is a chord track that isn't heard. A real chord track might start from there.

- **Next:** decide between the two (or both). A chord track is a bigger change and touches the shared harmony code.

---

## By instrument

### Dial ★

- **Good:** the most fun of the five.
- **Not yet:** with some sounds, moving round the dial is too quiet. Every move is a slur on the one held note (no new attack), so a sound that fades after its attack fades away while you roll.
- **Idea:** a setting for how a move sounds, per patch or as a row: `GLIDE` (today), `BEND` (instant slur) or `NEW NOTE` (each position strikes a fresh attack). Possibly a default per patch: plucky sounds strike, sustained sounds slur.
- **Next:** add the setting, try it with each patch, and pick a default per patch.

### Hand Drums

- **Good:** felt nice.
- **Not yet:** —
- **Next:** play more; check the open points in [HANDS.md](HANDS.md) Status (a face button and a direction a frame apart give two hits; the D-pad label still says `EXPRESSION`).

### Valves

- **Good:** liked the idea.
- **Not yet:** needs sounds that suit it. The saw lead doesn't sell it as a brass instrument.
- **Next:** brass patches (above), then play again: is the chart learnable, does the 35 ms slur wait feel late?

### Strum

- **Good:** could be good.
- **Idea:** let it be the chord source for the other tracks, as the Harp is (above).
- **Next:** decide the chord-source question; then the plan's open points (string map, louder downstrokes on the beat, neutral D-pad).

### Slide

- **Good:** could be good.
- **Not yet:** unsure about it.
- **Next:** another session focused on the plan's questions: can you land a note by ear with `SNAP` off, and is `SOFT` expressive or just out of tune?

---

## Sessions

### Session 1 — first look at all five 📱 (2026-11-16)

- **Build:** `claude/vigilant-gates-h1z44f` at the five-instrument rebuild.
- **Ranking:** Dial > Hand Drums > Valves (idea) > Strum ≈ Slide.
- **Notes:** as summarised above.

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
