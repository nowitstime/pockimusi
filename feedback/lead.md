# Lead / Arp — feedback

**Part:** Lead · **Feel:** machine patterns: held notes and arpeggios over the chord · **Plan:** [PHASE_F.md](../PHASE_F.md) · **Spec:** SPEC §7.5 · **Index:** [feedback/](README.md)

---

## How it plays

| Control | Job |
| :-- | :-- |
| D-pad | Scale degree, as Bass: neutral 1, `↙` 2, `←` 3, `↖` 4, `↑` 5, `↗` 6, `→` 7, `↘` 8, `↓` 5th below. For an arp, where the pattern starts |
| `B` | A held note; moving the D-pad or shoulders while holding glides it |
| `A` / `Y` / `X` | Arp up / down / up-down, while held |
| `L1 / R1` | Octave down / up |
| `L1 + R1` | Arp rate ×2 while held |
| Rows | `PATCH` (opens on `SQUARE`), `FOLLOW`, `ARP RATE` (1/8, 1/16, 1/8T), `ARP PATTERN` (`CHORD`, `CHORD 2 OCT`, `7TH`, `7TH 2 OCT`, `SCALE`) |

---

## Questions to answer

### Does it do its part? (lead, MUSICAL_PARTS §2)

- [x] Do the arps sound like a part, or like a demo? Which pattern gets used? — *A part: the patterns make sense, and it's the easiest of the instruments to get going (session 2).*
- [x] Can I play a held-note tune with `B` and the D-pad, or is that Dial's and Slide's job now? — *Yes, and mixing `B` notes (with their glide) in between the arps is what makes this the most fully featured instrument musically (session 2).*
- [x] Do arps follow the chords nicely across changes? — *`FOLLOW` on chord works well (session 2).*
- [x] Does ×2 on `L1 + R1` work as a "density change" (MUSICAL_PARTS §2.3)? — *Yes, the most-used shoulder move. 1× and 2× is the right amount; more speeds would be overkill (session 2).*
- [x] Is a sequence (the same shape from another degree) easy, by moving the D-pad while the arp runs? — *Moving between single note and the arps feels natural (session 2).*
- [ ] Does it want staccato, accents or vibrato?

### Is it fun?

- [x] What does it pull me towards: trance arps, chiptune, synth-pop? — *Video-game boss music (true of the whole device so far). Wanted: jungle, D&B, pop (session 2).*
- [ ] Is it fun to *play*, or mostly fun to *set going*?
- [ ] With Dial, Slide and Valves in, what is Lead/Arp's own feel? (MUSICAL_PARTS §7.1 suggests patterns)

### Open from the plan

- [x] ~~Arp latch: tap to keep it running?~~ — *Not needed (session 2).*
- [ ] A press between steps: sound at once, or wait for the next step (today)?
- [ ] Note length 80 % of a step: right, or a row?
- [ ] Vibrato on long `B` notes?

---

## Feedback

### Session 2 — 2026-11-16 📱

- **Played:** a loop of drums, Chord Harp chords and a simple bass line first, then the arp on top. Started on `SQUARE`, moved to `SAW`. Started at 1/16, switched to 1/8 and held `L1 + R1` for 1/16 when wanted.
- **Good:**
  - Fun; enjoying it straight away. The easiest instrument to get going.
  - Probably the most fully featured musically: `B` single notes (with glide) mix in between the arps.
  - `L1 + R1` for ×2 is great, and the main shoulder move. 1× and 2× is enough.
  - `FOLLOW` on chord works well. Patterns (`CHORD`, `SCALE`, …) make sense.
  - Works with most patches; only the pads don't really suit it, but keep them as options for being creative.
- **Not yet:**
  - Loop slop: play too much, overdub after overdub, and the loop goes crazy. A worry on every session so far.
  - Songs come out sounding similar (maybe a skill issue): not sure how to structure chords in a 2- or 3-bar loop.
  - Everything sounds like video-game boss music. What's missing for jungle, D&B, pop?
  - Octave `L1 / R1` only used a little.
- **Ideas:**
  - A `1/4` arp rate (maybe even `1/2`), since ×2 already covers the next one up. Same thought for the Drums.
  - Could the higher octave also speed the arp up? (`R1` = up an octave *and* ×2?)
  - Repeat / arp on other instruments, e.g. a note repeat on the Bass. Maybe a later phase.
  - A look at button combos and whether the rows cover everything.
- **Answered:** no latch needed; ×2 works as the density change; arps follow chords; `B` + arps mix well.
- **Later the same session (talking it over):**
  - Yes to the `GATE` row and `1/4` on `ARP RATE`.
  - From the MiniFreak's arp: a **chaos / randomness** setting that makes some of the notes random. Low amounts, with a few levels (e.g. `OFF` / `LOW` / `MED` / `HIGH`), not all-or-nothing.
  - Also from the MiniFreak: **double**: each arp note plays twice (a ratchet).
  - **What each button plays, chosen per button**, the way the Drums give each button its own job. `B` stays the single note. `A` / `Y` / `X` could each be e.g. up the chord, down the chord, down the scale. Mostly as **ready-made sets** to pick from, so you don't have to build every combination yourself.
  - Not building yet: this goes into the next build pass.

---

## Ideas

- More patterns (broken thirds, pedal patterns, random within the chord).
- `1/4` (and maybe `1/2`) on `ARP RATE` (session 2).
- A `GATE` / note length row: short and plucky vs legato (open question below "Note length 80 %").
- Note repeat or arp on Bass (session 2). The Drums already have a grid-locked repeat on the shoulders.
- Help with loop slop: see the brainstorm in session 2's notes.
- **Chaos row** (from the MiniFreak): `OFF` / `LOW` / `MED` / `HIGH` share of steps that pick a random chord or scale tone, or skip, or jump an octave. Low levels should still sound like the pattern (session 2).
- **Double / ratchet** (from the MiniFreak): each step plays twice, as a row or a toggle (session 2).
- **Button sets:** `A` / `Y` / `X` each play a pattern-and-direction, from a ready-made set chosen on one row. `B` stays the single note. Possible sets (session 2):
  - `CLASSIC` (today): up / down / up-down over `ARP PATTERN`
  - `CHORD + SCALE`: up the chord / down the chord / down the scale
  - `DANCE`: octave / pedal / up 2 octaves
  - `WILD`: random in chord / up-down / scale with chaos
  If button sets come in, `ARP PATTERN` may fold into them, or stay as the note pool the set plays from.

## Decided

- No arp latch (session 2).
- Two arp speeds (1× and ×2 on `L1 + R1`) is enough; no faster/slower steps (session 2).

## Next

- [x] First pass (session 2).
- [ ] Add `1/4` to `ARP RATE`.
- [ ] Add a `GATE` row (`SHORT` / `NORMAL` / `LEGATO`).
- [ ] Next build pass, to scope: `OCTAVE` and `PEDAL` patterns, chaos levels, double/ratchet, button sets.
- [ ] Later phase: note repeat on Bass.
