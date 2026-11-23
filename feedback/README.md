# Pockimusi — Feedback

The whole app is in testing. Every instrument gets a pass, and every screen has a file here with **questions to answer while playing** and a **clear place for what you noticed**.

The plans and [SPEC.md](../SPEC.md) say what was built. [MUSICAL_PARTS.md](../MUSICAL_PARTS.md) says what each kind of part needs. These files say how it actually plays, and what to change.

---

## How to use it

1. **Pick a screen** and open its file.
2. **Skim "How it plays"** so you know what to try.
3. **Play with the questions in mind.** There's no need to answer them all; answer the ones the session told you something about.
4. **Write what you noticed** under *Feedback*, as a new dated entry at the top: good, not yet, ideas. Your own words, short.
5. **When something is settled,** move it to *Decided* in that file. When it changes how the instrument is built, it goes into SPEC or the instrument's plan too.
6. **Add a line to the session log** below, so the order of sessions is easy to follow.

A question that's been answered can be ticked (`- [x]`) with the answer after it, or struck out if it stopped mattering.

---

## The files

| Screen | Part | Feel so far | Main thing to fix | Pass |
| :-- | :-- | :-- | :-- | :-- |
| [Drums](drums.md) | Rhythm | — | — | [ ] |
| [Hand Drums](hands.md) | Rhythm | Felt nice | Nothing specific yet | [ ] |
| [Breaks](breaks.md) | Rhythm | New (Phase L) | First pass; the transcriptions need checking by ear | [ ] |
| [Chord Harp](harp.md) | Chords | — | — | [ ] |
| [Track C: chord lane](lane.md) | Chords (the chord source) | New | First pass on the device | [ ] |
| [Chord Track](chords.md) | Chords | **Retired**: track C took its job | — | [x] |
| [Strum](strum.md) | Chords | Could be good | Could set the chords, as the Harp does | [ ] |
| [Bass](bass.md) | Bass | — | — | [ ] |
| [Roller](roller.md) | Bass | New (Phase L) | First pass on the device | [ ] |
| [Wobble](wobble.md) | Bass | New (Phase L) | First pass on the device | [ ] |
| [Pad](pad.md) | Texture | — | — | [ ] |
| [Lead / Arp](lead.md) | Lead | Fun; easiest to get going, most fully featured | Slower rate (`1/4`); loops get sloppy; everything sounds like boss music | [x] |
| [Dial](dial.md) | Lead | ★ Most fun | Moving round is too quiet: wants a re-strike, not only a glide | [ ] |
| [Slide](slide.md) | Lead | Could be good, unsure | Play more before deciding | [ ] |
| [Valves](valves.md) | Lead | Liked the idea | Needs brass sounds | [ ] |
| [Pages](pages.md) | Track page, Clock, Mix, stage | — | — | [ ] |

Keep this table in step with each file's latest feedback.

---

## What an instrument is for

Each instrument needs a **musical purpose** and should be **fun to play**, both at once.

- **Different ways of playing suit different styles.** Each one should pull you towards a way of playing you wouldn't have found on another. If an instrument inspires a style, that's a reason to keep it, even when another instrument could technically play the same notes.
- **Four leads is on purpose.** Dial, Slide, Valves and Lead/Arp are four feels for the lead part, not four rivals. Each still needs to be clearly different from the others, and clearly good at something.
- **Four tracks means choosing.** A loop usually has one or two leads, so rhythm and texture keep room to breathe. A lead doesn't have to fill a loop on its own; it has to make you want to pick it for this loop.

So every instrument file asks two kinds of question: *does it do its part* (from MUSICAL_PARTS) and *is it fun* (from playing).

### Questions for every instrument

Ask these on every screen, alongside the instrument's own:

- [ ] What did I want to play after the first minute?
- [ ] What style or feel did it pull me towards?
- [ ] Which gesture felt great? Which felt like a fight?
- [ ] Did I lose track of time, or keep checking the controls?
- [ ] Did it make me want to record a loop?
- [ ] Did I hear what I meant to play? (sound, level, timing)
- [ ] Which sounds suited it, and which sound did I wish for?
- [ ] Would I pick it up again a week from now?

---

## Across the app

### More sounds

The newer instruments need sounds made for how they play. Dial, Slide and Valves open on the `LEAD` group, Strum on `PLUCK`.

- Brass first (Valves; probably Dial and Slide too): a trumpet, a horn section, a muted horn.
- Then bowed strings for Strum's bow, a reed or woodwind, leads that keep their level through a slur.
- The full wish list by part: MUSICAL_PARTS §7.3.

### Where chords come from

Today the Chord Harp is the track the others follow. Two routes, maybe both:

1. **Strum as a chord source.** It follows chords today, so it would need to *choose* them: the Harp's chord map on the D-pad (MUSICAL_PARTS §3.4).
2. **A separate chord track.** The Harp on its `SILENT (CHORDS ONLY)` patch already is one, without sound. Now built as its own instrument, [Chord Track](chords.md): progressions, snap to the bar, stamp. Playing will decide whether it stays an instrument or becomes a hidden fifth track.

### Following the chords

Every instrument that plays pitches can follow the chords now, with a `FOLLOW` row on the Track page. Bass, Lead, Pad, Strum and Valves had it; **Dial**, **Slide** and the **Chord Harp** have it now (off by default, so they play as before):

- **Dial:** the eight positions are degrees over the current chord, the Bass's rule (1 root, 3 third, 5 fifth, 7 seventh, 8 octave; 2, 4, 6 walk the scale). Recorded notes re-fit when the chords change.
- **Slide:** steps and snapping land on the chord's notes instead of the scale's.
- **Chord Harp:** plays the chord source's chords instead of choosing them; it records strings, so it never becomes the chord source.

Not Drums or Hand Drums (no pitch), and not the Chord Track (it sets the chords).

### Decisions waiting (MUSICAL_PARTS §7.4)

- [ ] Chord source: Strum `CHORDS` mode, a chord track, or both
- [ ] Dial: slur vs re-strike as a row, a default per sound, a per-note gesture
- [ ] Pad latch
- [ ] First shared expression piece (articulation per note?)
- [ ] Default slots: is a lead more useful in the default four than the Pad?

---

## Session log

Newest first. One line each; the details go in the screens' files.

| # | Date | Focus | Screens | Headline |
| :-- | :-- | :-- | :-- | :-- |
| 3 | 2026-11-18 📱 | Chord Track | Chord Track | Likes stamp and names on the timeline; wants numerals in the middle, clearer buttons, a delete, single-chord colours (aug), random colours |
| 2 | 2026-11-16 📱 | Lead / Arp first pass | Lead / Arp | Fun and easy; `B` + arps mix well; ×2 on both shoulders is the move. Wants `1/4` rate, gate row, MiniFreak-style chaos + double, per-button pattern sets; no latch. Worries: loop slop, everything sounds like boss music |
| 1 | 2026-11-16 📱 | First look at the five new instruments | Hand Drums, Strum, Slide, Dial, Valves | Dial most fun; Hand Drums nice; Valves needs brass; Strum and Slide promising. All ten stay in as ordinary instruments |

---

## Template for a feedback entry

Copy to the top of a file's *Feedback* section:

```markdown
### Session N — YYYY-MM-DD 📱

- **Played:** how long, which sounds, what kind of loop
- **Good:**
- **Not yet:**
- **Ideas:**
- **Answered:** which questions above, and how
```
