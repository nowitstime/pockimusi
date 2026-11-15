# Phase H · Drums pass 2 — Working Plan

Part of [ROADMAP.md](ROADMAP.md). Design: [SPEC.md](SPEC.md) §3.2a, §3.4, §7.1, §8.2.

**Goal:** a recorded drum loop stops sounding like a loop. A `VARIATION` setting makes each pass a little different without ever changing what was recorded, ghost notes can come and go, and each pad gets its own tuning and level so a kit can be balanced on the device.

**Rule for every step:** one step = one or a few commits, app playable, tests green. 📱 = check on the RG35XX.

---

## Decisions

| Topic | Decision | Why |
| :-- | :-- | :-- |
| Pass 1 | Flam, ratchet, choke and repeat get their own tests before anything changes | Roadmap: "check they still behave" |
| `VARIATION` row | `OFF` / `LIGHT` / `WILD`, default `OFF`, applied **on playback only** | The recorded pattern is never altered; `OFF` plays it exactly |
| `LIGHT` | Each hit's level moves by up to ±12 % | A drummer's hand |
| `WILD` | Level ±22 %; about a third of the hits that are not on a beat land up to 14 ms late; **fills** | Looser, with surprises |
| Fills | In the last beat of each bar, each empty 1/16 step has a 22 % chance of a ghost hit (28–45 % level) on one of the pads the pattern already uses. Never on a pad holding a kick; never on a step that already has a hit. On a 1/12T grid the steps are triplets | Fills sound like the kit that is playing, and the downbeat stays clear |
| Chance hits | A **ghost** hit (`↓`) recorded while `VARIATION` is not `OFF` is stored with `chance = 0.5`: on playback it sounds on about half the passes. With `VARIATION OFF` every hit always plays | The SPEC's proposal: no new gesture, and ghost notes are the ones that should come and go |
| Chance and flams | The grace note and the main hit share one roll | A flam never plays half of itself |
| Seeing chance | Chance hits are drawn hollow in the drum lanes | Tell at a glance which hits are "maybe" |
| Per-pad tune and level | Two setting rows, **`TUNE`** (−12 … +12 semitones) and **`LEVEL`** (10 … 120 %), that act on the **selected pad**: the last pad hit (the one the page opens on), or the last one whose sound was changed. Their labels name it (`TUNE B`) | Rows are where per-track options live; 8 more rows would not fit |
| When they apply | At the moment a hit sounds, live and on playback | Balance a loop that is already recorded |
| Track page list | The drums now have 8 rows (`KIT`, `X`, `Y`, `A`, `B`, `TUNE`, `LEVEL`, `VARIATION`). The list shows **5 at a time** and scrolls with the cursor, with marks when there is more above or below | This relaxes "≤ 6 rows, no scrolling" (SPEC §3.4) rather than adding a page |
| Randomness | One source, `Drums.random`, so tests can fix it | Variation must be testable |

---

## Order

| Step | What | Size |
| :-- | :-- | :-- |
| H1 | Tests for flam, ratchet, choke as they are today | S |
| H2 | `VARIATION` row: level jitter, late hits, fills | M |
| H3 | Chance on ghost hits; hollow marks in the lanes | S |
| H4 | `TUNE` and `LEVEL` for the selected pad; scrolling row list | M |

## Tests

- H1: a live flam plays a quiet grace note then the hit; a recorded one plays grace then hit on playback; a ratchet plays three hits inside one step; a closed hat cuts an open hat.
- H2: `OFF` plays every pass identically; `LIGHT` changes levels within ±12 % and never the timing or the events; `WILD` delays only off-beat hits and by at most 14 ms; fills land only on empty steps in the last beat, only on used non-kick pads, and are never recorded; a muted or empty track gets none.
- H3: a ghost recorded with variation on has `chance = 0.5`, other hits have none; it plays on roughly half the passes, always with `OFF`; a chance flam is all or nothing; `chance` survives save and load, clamped.
- H4: `TUNE` and `LEVEL` change the selected pad only, live and on playback, and clamp; hitting a pad or changing its sound selects it, moving the cursor over pad rows does not; rows save and load; the list scrolls and every row is reachable.

## Exit checklist

- [x] `python3 tests/run.py` green (292 tests; `tests/test_drums.lua` is new)
- [ ] `LIGHT` is felt, not heard as random; `WILD` fills are welcome, not annoying 📱
- [ ] Tuning and levelling a pad is quick enough to do mid-jam 📱

## Status

Built: H1 to H4. One change while building: the plan had the Track page cursor select the pad for `TUNE` / `LEVEL` as it moved over the pad rows, but walking down to `TUNE` passes pad B's row and always re-selected B. The selected pad is now the last one hit (or whose sound was changed), which is also the row the page opens on.

## Open (settle by playing)

1. Fill rate and the "last beat only" rule.
2. Is 0.5 the right chance, or should `LIGHT` and `WILD` differ?
3. Should `TUNE` / `LEVEL` sit above the pad rows instead of below?
