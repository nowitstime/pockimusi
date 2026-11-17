# Drums — feedback

**Part:** Rhythm · **Feel:** the kit: four pads, the D-pad as dynamics and articulation · **Plans:** [PHASE_H.md](../PHASE_H.md) (pass 2) · **Spec:** SPEC §3.2a, §7.1 · **Index:** [feedback/](README.md)

---

## How it plays

| Control | Job |
| :-- | :-- |
| `B A Y X` | Four pads |
| D-pad `↑ / ↓` | Accent / ghost |
| D-pad `← / →` | Flam / ratchet (three hits in one 1/16). Diagonals combine both |
| `L1` / `R1` / both | Note repeat at 1/4 / 1/8 / 1/16 (1/12T on a triplet grid), locked to the grid |
| Rows | Kit (six), pad sounds, `VARIATION` (`OFF` / `LIGHT` / `WILD`), `TUNE` and `LEVEL` for the selected pad |

Closed hats cut an open hat. Ghost hits recorded with `VARIATION` on sound about half the time.

---

## Questions to answer

### Does it do its part? (rhythm, MUSICAL_PARTS §5)

- [ ] Does a basic groove (kick, snare on 2 and 4, hats) come together in one pass?
- [ ] Does it groove at 1/16 with swing?
- [ ] Ghost notes and accents: easy enough to use all the time, not just as an effect?
- [ ] Fills at the end of a phrase: can I play one, and does `VARIATION` add good ones?
- [ ] Flam and ratchet: musical, or novelties?
- [ ] Note repeat: do 1/4, 1/8 and 1/16 all get used? Is a build (repeat speeding up) wanted?
- [ ] Do the kits cover the styles I play? Which sound is missing?
- [ ] Half-time / double-time feel: wanted as a move?

### Is it fun?

- [ ] Is finger drumming on the face buttons satisfying, or fiddly?
- [ ] What style does each kit pull me towards?
- [ ] Is it the instrument I start every loop with? Should it be?

### Open from the plans

- [ ] Fill rate, and the "last beat only" rule.
- [ ] Chance 0.5 for ghost hits: right? Should `LIGHT` and `WILD` differ?
- [ ] Should `TUNE` / `LEVEL` sit above the pad rows instead of below?

---

## Feedback

### Note — 2026-11-16 📱 (during the Lead / Arp session)

- **Not yet:** note repeat (`L1` / `R1` / both) doesn't repeat while the transport is stopped. Just playing with the music paused, holding a shoulder should still repeat (e.g. at the tempo, from the press). The Lead/Arp already does this: its arp keeps running while stopped on its own timer (`state.arpTimer` in `lead.lua`), so the drums can copy that (today `drums.lua` skips the repeat when `not Looper.playing`).

---

## Ideas

- Section moves (crash on the downbeat, drop-outs) with song building (FUTURE_PLANS §8).
- A build: repeat rate rising over a bar into the next loop.

## Decided

## Next

- [ ] First pass.
- [ ] Note repeat works while stopped.
