# Lab wave 1 — Overview

Five new instruments to try, built so that they can be worked on **at the same time**. Background: [FUTURE_INSTRUMENTS.md](../FUTURE_INSTRUMENTS.md) (the lab), [SPEC.md](../SPEC.md) §3.4 (Track page) and §6 (sound pool).

**Goal:** five new ways of playing are in the app, rough but playable, so playing can decide which ones stay. The Track page's instrument tabs change first, because ten names no longer fit in a row.

**Lab rule:** no polish until an instrument has earned its slot (FUTURE_INSTRUMENTS §7).

---

## The plans

| Plan | What | Size | Needs |
| :-- | :-- | :-- | :-- |
| [L0_FOUNDATION.md](L0_FOUNDATION.md) | Everything shared: lab switch, carousel tabs, shared views, erase map, fingering reader, small engine hooks | M | — |
| [HANDS.md](HANDS.md) | **Hand Drums**: two thumbs, the D-pad as four more pads | S | L0 |
| [STRUM.md](STRUM.md) | **Strum**: choose the notes with the thumbs, pluck with the shoulders | M | L0 |
| [SLIDE.md](SLIDE.md) | **Slide**: steer the pitch instead of choosing it | S–M | L0 |
| [DIAL.md](DIAL.md) | **Dial**: roll the thumb round the scale | M | L0 |
| [VALVES.md](VALVES.md) | **Valves**: fingerings and breath, like a brass instrument | M | L0 |

```
L0 Foundation ──┬── Hand Drums
                ├── Strum
                ├── Slide
                ├── Dial
                └── Valves
```

L0 is one stream and goes first. After it, the five instruments are independent: any order, any number at once.

---

## How the streams stay apart

L0 exists so that an instrument never has to touch a shared file. It reserves a place for every instrument in advance:

| Shared thing | What L0 does | What an instrument does |
| :-- | :-- | :-- |
| Instrument list (`instruments/init.lua`) | Lists the five ids; a module that isn't there yet is skipped | Adds its own file, nothing else |
| Test list (`tests/run.lua`) | Runs `test_<id>.lua` for each id if the file exists | Adds its own test file |
| Stage view (`ui/chrome.lua`) | Draws any instrument from data the instrument provides (`VIEW`, `viewKind`, `getReadout`) | Fills in that data |
| Tape deck lanes | Takes a note's row from the instrument (`LANES`) | Names its rows |
| Erase page (`modes.lua`) | Reads the instrument's `ERASE` map | Provides the map |
| Input (`input.lua`) | The fingering reader | Calls it |
| Held notes (`instruments/init.lua`) | Notes the instrument releases itself (`manual`) | Uses them |
| Drums (`instruments/drums.lua`) | Hooks for "is this pad pressed" | Overrides the hooks |
| Build (`build.py`) | Already packs every `.lua` under `src/` | Nothing |

**Each instrument stream owns exactly three files:** `pocketgroove/src/instruments/<id>.lua`, `tests/test_<id>.lua`, and its plan in this folder (for the Status section).

**If a stream finds it needs a shared change:** make it as its own small commit, add a line to the "Added later" list in L0_FOUNDATION.md, and keep it additive (a new hook with the old behaviour as the default), so the other streams merge without conflicts.

**Branches:** each stream starts from the commit that finishes L0. Streams merge in any order. `pocketgroove/PocketGroove.love` is a built file: rebuild it (`python3 build.py`) once after merging, not in each stream.

---

## Decisions shared by all five

| Topic | Decision | Why |
| :-- | :-- | :-- |
| What a thumb can press | From playing: **one** button and **two neighbouring** buttons are easy; **all four** (the thumb laid flat) is a little harder but fine; **three** is hard to control; **opposite pairs** (`B + X`, `A + Y`) are a challenge. So there are **nine fingerings to build on**: four singles, four neighbouring pairs, all four. Nothing may need three buttons or an opposite pair | This replaces the lab doc's "not three or four at once" |
| `LAB` switch | `Config.LAB`, **on** for now. Lab instruments carry `lab = true`; with the switch off they leave the tabs | You are the only player while experimenting; the switch is there for a release |
| Sounds | Every pitched lab instrument takes the whole sound pool by declaring `HOME_GROUP`, `DEFAULT_PATCH`, `REGISTER`, `VOICES` (see `src/instruments/patches.lua`) | No sound work per instrument |
| Stage view | No new drawing code per instrument. Hand Drums uses the drum lanes; Slide, Dial and Valves use the Bass's pitch trace; Strum uses the plain lab view. All take their control labels from a `VIEW` table | Labels only, as the lab rules say; a real view comes with a slot |
| Settle window | 35 ms (`Input.FINGER_SETTLE`), in one place, for every instrument that reads two buttons meant to land together | Two buttons pressed together arrive a frame apart. One number to tune on the device |
| Global buttons | `L2`, `R2`, `SELECT`, `START` stay global. Each plan says where it breaks the play-surface habits and why | SPEC §3.1; FUTURE_PLANS §6.1 |
| Saves | A lab instrument's rows save and load like any other's. A save holding an instrument that no longer exists loads that track empty | A deleted experiment must not play its notes as drum hits |

---

## Order

1. **L0 Foundation.** Ends with the app playable, the tabs as a carousel, and a `FINGERS` test instrument on the device 📱.
2. **The five instruments**, at the same time or in any order. Suggested if done one by one: Hand Drums (smallest), Strum (most different), Slide, Dial, Valves.
3. **Merge, rebuild, play.** One session of real playing per instrument, then a verdict in its plan.

## What decides a slot

| Instrument | Question |
| :-- | :-- |
| Hand Drums | A clean 1/16 single-stroke roll at 120 BPM? Do you miss flam and ratchet? |
| Strum | Steady alternate-picked 1/16 notes at 120 BPM for two bars? Is the bow worth keeping? Does damping fire by accident? |
| Slide | Can you land on a note by ear with `SNAP` off? With `SNAP` soft, is it expressive or just out of tune? |
| Dial | A one-octave scale up and down by rolling, evenly, without looking? Does the seam feel natural? |
| Valves | Can you play a scale after two minutes with the chart? Do bugle calls on the D-pad alone feel good? Is `CHROMATIC` fun or just wrong notes? |

An instrument moves to the roadmap when it passes the five tests in FUTURE_INSTRUMENTS §7.5; the last one is "you want to pick it up again a week later".

## Exit checklist

- [x] `python3 tests/run.py` green with all five merged
- [ ] Ten tabs read clearly and the slide shows which way you stepped 📱
- [ ] Settle window tuned on the `FINGERS` screen 📱
- [ ] Each instrument has had a session of real playing and a verdict in its plan: slot, row on another instrument, or dropped 📱

## Open (across the wave)

1. With two or more winners, what leaves the library or becomes a row (FUTURE_INSTRUMENTS §8)?
2. Should the `LAB` switch be reachable on the device, or stay a line in `config.lua`?
