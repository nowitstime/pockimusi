# Phase F · Lead / Arp — Working Plan

Part of [ROADMAP.md](ROADMAP.md). Design: [SPEC.md](SPEC.md) §3.2, §5, §7.5.

**Goal:** a melody instrument for the top of the mix. One button plays held notes like the bass; the other three run an arpeggio through the current chord, locked to the clock, for as long as they are held. The D-pad chooses the degree, exactly as on the bass, so nothing new has to be learned.

**Rule for every step:** one step = one or a few commits, app playable, tests green. 📱 = check on the RG35XX.

---

## Decisions

| Topic | Decision | Why |
| :-- | :-- | :-- |
| Class | Lead is built on the Bass: same D-pad degrees (neutral = 1, `↓` = 5th below), same event fields, same follow rule | "Same class as Bass" (SPEC §7.5); the engine is already proven |
| Register | One octave above the bass (0 = middle C) | A bass line swapped to Lead becomes a melody |
| `B` | A held note. Moving the D-pad or shoulders while holding glides (fast), recorded as bends, as on the bass | The lead's plain voice |
| `A` / `Y` / `X` | Arp **up**, **down**, **up-down**, running while held. The newest held arp button wins | SPEC §7.5 |
| Arp notes | A ladder of notes over the current chord, set by the `ARP PATTERN` row: `CHORD` (1 3 5), `CHORD 2 OCT`, `7TH` (1 3 5 7), `7TH 2 OCT`, `SCALE` (1–7) | One row covers note set and range |
| D-pad while arping | The D-pad degree is where the pattern **starts** (the nearest ladder note at or below it). Neutral = from the root; `↑` = from the 5th (an inversion); it can move while the arp runs | The left thumb keeps its job: where in the harmony |
| Arp and chords | Every arp step reads the current chord, so a held arp follows the changes | Hold one button over the whole loop |
| Recording | **Each arp step is an ordinary note event** (degree, octave, pitch, a length of 80 % of the step), snapped to the arp's rate | Playback, follow, erase, undo, the tape deck and Bass ↔ Lead swaps all work with no new event type |
| Timing | Steps fall on the clock's grid at the `ARP RATE` (1/8, 1/16, 1/8T) with the track's swing. A press just before or after a step plays at once and counts as that step; a press between steps starts on the next one | The drum repeat's rule, which already feels right |
| `L1` / `R1` | Octave down / up. **Both = arp rate ×2** (octave stays in the middle) | SPEC §7.5 |
| Mono | A new note ends the one before (`PLUCK` notes overlap and ring) | As the bass |
| Paused clock | The arp runs on its own timer at the same rate | Still playable with the transport stopped |
| Rows | `PATCH` (`SQUARE`, `SAW`, `PLUCK`), `FOLLOW`, `ARP RATE`, `ARP PATTERN` | Roadmap |
| Swaps | Bass ↔ Lead keeps the track's notes and grid (still undoable) | Roadmap; they share one event format |
| Colour | Tracks are coloured by slot, so a Lead takes its slot's colour; nothing to add | — |
| Arp latch ❓ | Not built: hold only | Decide after playing it |
| Strum ❓ | Not in this phase: stays a lab idea ([FUTURE_INSTRUMENTS.md](FUTURE_INSTRUMENTS.md)) | It is a different way of playing, not an arp mode |

---

## Order

| Step | What | Size |
| :-- | :-- | :-- |
| F1 | Lead patches; `lead.lua` on top of Bass with `B` held notes; rows; save; in the catalogue | M |
| F2 | Arp: ladder, up / down / up-down, clock-locked steps with swing, rate ×2, recorded as notes | M |
| F3 | Bass ↔ Lead swaps keep notes | S |
| F4 | Stage view: arp ladder + pitch trace 📱 | M |

## Tests

- Patches: loops seamless and in tune.
- `B`: holds, bends glide and record, mono cut.
- Arp: the up, down and up-down orders for each pattern; the start note follows the D-pad; steps land on the grid at each rate, with swing, and at double rate with both shoulders; one event per step with the right length; a held arp follows a C–Am–F–G loop, live and on playback; releasing stops it; it runs with the clock paused.
- Swaps: Bass → Lead → Bass keeps notes; undo still restores; other swaps still clear.
- Save and load keeps the rows.

## Exit checklist

- [ ] `python3 tests/run.py` green
- [ ] Arps feel locked to the drums at every rate 📱
- [ ] The three patches sit above the pad and bass without being harsh 📱
- [ ] A recorded arp re-harmonises when the chords change

## Open (settle by playing)

1. Arp latch: tap to keep it running?
2. Should a press between steps sound at once instead of waiting for the next step?
3. Is 80 % the right note length, or should it be a row?
4. Does the lead want vibrato on long `B` notes?
