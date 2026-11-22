# Phase K · Chord lane — Working Plan

Part of [ROADMAP.md](ROADMAP.md). Background: [feedback/chords.md](feedback/chords.md) (the Chord Track experiment), [FUTURE_PLANS.md](FUTURE_PLANS.md) §6.3 (a chord track that makes no sound). Design: SPEC §5 (Harmony), §11 (UI). Mockups: the "Chord Lane Mockups" canvas, sections D, E, "16 bars" and "Stamp".

**Goal:** the song's chords get their own built-in lane, **track C**, outside the four instrument slots. It is silent, can be longer than the loop (up to 16 bars), and can be written live with the clock running or written out with the clock stopped, using the same buttons both ways.

**North star:** controller first. **The playhead is the cursor; `B` writes where it is heading.** Running, the playhead moves by itself and a press lands on the next line. Stopped, it waits and each press moves it on.

**Rule for every step:** one step = one or a few commits, app playable, tests green. 📱 = check on the RG35XX.

---

## Decisions

### The lane

| Topic | Decision | Why |
| :-- | :-- | :-- |
| What it is | A built-in chord lane, **track C**, outside the four slots. Always silent: no `PATCH` row, no mute | The Chord Harp was mostly used on `SILENT` as a chord picker; that job shouldn't cost a slot |
| Reaching it | `SELECT` tap cycles **1 → 2 → 3 → 4 → C → 1**. The app starts on track 1 | No new combo; C is last so it doesn't confuse a first session |
| Chord source | The lane is the **only** recorded chord source. Empty lane: the chord being played live on a Harp, then the tonic | One source of truth; no "lowest-numbered harp" rule. Recorded Harp chords stop steering followers |
| Length | `BARS` row: **2 / 4 / 8 / 16**, independent of the loop. A lane shorter than the loop repeats; changing the loop 2 ↔ 4 leaves the lane alone | Lets a 2-bar groove play under a 16-bar progression without a song mode |
| Position | The looper counts loop passes so it knows where it is in the lane. `START` double tap resets to pass 1. Play starts from wherever the playhead is | |
| Fresh session | Clears the lane | It is content, not setup |
| Undo | Recording on C splits takes per **lane** pass. Writing with the clock stopped is one undo per press (a stamp is one press) | |
| Old saves | Whatever is simplest without breaking: a Chord Track in a slot loads as it is | Only one tester so far |
| Colour | The Chord Track's gold, for now | |

### Looks

| Topic | Decision |
| :-- | :-- |
| Strip | A thin strip (about 12 px) in its own frame **above** the tape deck, showing the **whole lane** at once with its own small playhead. The four lanes lose a few pixels each |
| This pass | When the lane is longer than the loop, a white frame on the strip marks the part under the current loop pass. No lens. Lane as long as the loop: no frame, lines up exactly |
| Highlight | Only the chord playing now is lit |
| Labels | Name and numeral up to 8 bars; **names only** at 16 bars |
| Passes | Pips in the strip header for up to 4 passes, else `3/8`; the top bar shows `BAR 5 OF 8` next to the chord |
| Stage on C | A **chord chart**: one box per bar, **one page** (4 × 4 at 16 bars, 2 × 4 at 8, names and numerals when they fit). The playhead's box is outlined; with the clock stopped the box ahead shows the D-pad's chord greyed out before you press |
| Empty | The strip reads "NO CHORDS YET · EVERYTHING PLAYS IN C MAJOR · SELECT TAP TO REACH TRACK C"; followers' `FOLLOW` chip reads `FOLLOW · NO CHORDS` |
| Tape deck v2 | Beads, ribbons and the legibility pass stay in Phase I |

### Controls on track C

| Control | Clock running (live) | Clock stopped (writing it out) |
| :-- | :-- | :-- |
| D-pad | Which chord | Which chord, shown greyed out in the box ahead |
| `B` | Change at the **next bar line** | Write this box, step on |
| `L1` / `R1` held + `B` | Sparser: lasts 2 bars · denser: next half bar | Write 2 bars / ½ bar and step that far |
| `L1 + R1` held + `B` | Change on the next beat | Write one beat |
| `L1` / `R1` tap | — | Step back / step on (the chord carries on, `%`) |
| `A` held + D-pad | Colour the chord playing | Colour the box behind the playhead |
| `Y` | Delete the chord playing (hold: keep deleting) | Take back the last thing written (a chord or a whole stamp) and step back |
| `X` held | The **progression wheel** (below) | The same |
| `X` tap | Stamp the picked progression from the next bar line | Stamp it at the playhead and step past it |
| `L1` / `R1` held + `X` tap | Stamp it sparser / denser (2 bars / ½ bar a chord) | The same |
| `L2` | Record: the changes get written. Not recording, `B` is a live change the followers play but nothing is written | Not needed: writing stopped is always kept |

- No press means "keep going": whatever is there stays.
- A press during a bar is queued for the next line; the next box shows it dashed with beat dots counting down.
- Switching tracks leaves the clock as it is.
- Grammar kept: right thumb = what and when, D-pad = harmony, shoulders = sparser / denser (and, stopped, back / on), `L2` = record. Two buttons + the D-pad at most.

### Stamp

| Topic | Decision | Why |
| :-- | :-- | :-- |
| Picking | **Hold `X`**: the D-pad's chord labels become a wheel of 8 progressions. Pointing at one plays it on the other tracks. `L1` / `R1` flip to the second page. **Let go = picked, nothing written** | Choosing and placing were crammed into one hold; split like a weapon wheel and firing |
| Placing | **Tap `X`** writes the picked progression where the playhead is and steps past it, like a big `B`. Its ghost waits ahead of the playhead so you see where a tap lands | Same rule as `B`: no "where does this go?" |
| Running | Starts on the next bar line | Same as `B` |
| More | Tap again to repeat it (16 bars of POP = 4 taps) | Predictable; no "fill to the end" mode |
| Wheel page 1 | ↑ POP · ↗ 50S · → SAD POP · ↘ ROCK · ↓ JAZZ ii-V-I · ↙ ROYAL ROAD · ← MIXO · ↖ CANON | |
| Wheel page 2 | DESCEND · HEROIC · BITTERSWEET · BLUES 8 | |

### Track page on C and FOLLOW

| Topic | Decision |
| :-- | :-- |
| Rows on C | `BARS`, `PREVIEW` (`STRUM` default / `STAB` / `OFF`), `PREVIEW SOUND` (the sound pool, default `HARP`), `COLOUR` (for new chords), `SPICE` |
| Preview | With the clock stopped, each write plays the chord softly so you write by ear |
| Gone from the Chord Track | `PATCH`, `PROGRESSION` and `LENGTH` rows; snap shoulders; the `>` guide; NEXT / TOP |
| FOLLOW defaults | Bass, Pad, Lead **on**; Dial, Slide **off** (unchanged). With an empty lane the row reads `ON · NO CHORDS YET` |
| FOLLOW off over chords | A gentle toast when recording with `FOLLOW OFF` while the lane has chords: the same notes play over every chord |
| Harp | Unchanged for now; its job gets a pass of its own later |

---

## Order

| Step | What | Size |
| :-- | :-- | :-- |
| K1 | The lane in the looper: storage outside the tracks, `BARS`, loop-pass counter and lane position, save / load, fresh session; Harmony reads the lane first | M |
| K2 | Track C: the `SELECT` cycle, its play surface (built from `chords.lua`), its Track page rows | M |
| K3 | The strip above the tape deck, the squeezed lanes, `BAR x OF y` in the top bar | M |
| K4 | Running controls: queue to the next line, shoulder lengths, live vs recorded, undo per lane pass | M |
| K5 | Stopped controls: write and step, tap to step, `Y` take-back, the greyed-out chord ahead, `PREVIEW` rows | M |
| K6 | Stamp: the wheel on hold (two pages, preview on the other tracks), tap to place, repeat, sparser / denser | M |
| K7 | The chord chart stage view (2 × 4 / 4 × 4) | M |
| K8 | `FOLLOW` row text and the `FOLLOW OFF` toast; recorded Harp chords no longer steer | S |
| K9 | SPEC and feedback updates; decide whether the Chord Track stays as a slot instrument | S |

## Tests

- K1: chords at lane positions resolve across loop passes for 2/4/8/16-bar lanes over 2- and 4-bar loops; a lane shorter than the loop repeats; `START` double tap returns to pass 1; the lane survives save / load and is cleared by a fresh session; with an empty lane Harmony falls back to the live Harp chord, then the tonic; recorded Harp chords are ignored.
- K2: `SELECT` taps visit 1, 2, 3, 4, C and wrap; track C has no `PATCH` row and makes no sound.
- K4: a running `B` lands on the next bar line (half bar with `R1`, beat with both, 2-bar length with `L1`); not recording writes nothing but followers follow; recording writes; undo removes one lane pass.
- K5: a stopped `B` writes the box under the playhead and steps by the chord's length; `R1` tap steps and the chord carries on; `Y` removes the last write (a whole stamp in one press) and steps back.
- K6: holding `X` and letting go writes nothing; a tap writes the picked progression at the playhead and steps past it; repeat taps continue it; a running tap starts on the next bar line; shoulders change the chord length.

## Exit checklist

- [ ] `python3 tests/run.py` green
- [ ] Writing 16 bars with the clock stopped feels quick and obvious 📱
- [ ] Changing chords live on the bar line feels like playing, not editing 📱
- [ ] The wheel is easy to aim with the thumb; two pages are enough 📱
- [ ] The strip is readable at 16 bars; the pass frame makes sense without the lens 📱

## SPEC changes when built

- §1 principle 5: "four instrument tracks plus the song's chord lane".
- §3.6: `SELECT` tap reaches track C.
- §5: the lane is the chord source; drop the "lowest-numbered harp" rule.
- §7.2 / §7.6: the Chord Track becomes track C; the Harp's `SILENT` patch stays until the Harp pass.
- §11: the strip above the tape deck.

## Open (decide after playing)

- Grid or a "reel" (the bar ahead big in the middle) for the stopped clock.
- Does the Chord Track stay as a slot instrument once track C exists?
- The Harp's job once the lane sets the chords.
