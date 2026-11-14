# Phase D · Chord Harp + Chord-Follow — Working Plan

Part of [ROADMAP.md](ROADMAP.md). Design: [SPEC.md](SPEC.md) §3.3, §5, §7.2.

**Status:** ✅ built (218 tests); ⬜ device check. Changed after planning: the harp keeps **one note per button** (no strums); strumming becomes its own future instrument, planned together with Lead/Arp (Phase G).

**Goal:** the harp becomes the song's chord track. You play chords, those chords are recorded, and the bass (later Pad and Lead too) follows them. A bass line played on the root moves to each new chord's root, and recording or changing chords later re-harmonises lines you already recorded. Without a chord track nothing changes: followers play in the key, as today.

**Rule for every step:** one step = one or a few commits, app playable, tests green. 📱 = check on the RG35XX.

---

## Decisions

| Topic | Decision | Why |
| :-- | :-- | :-- |
| Harp buttons | **Unchanged: each button plucks one string** of the chord (`B` root, `A` 2nd string, `Y` 3rd, `X` top) | Decided after planning: press a button, get a note. Strumming moves to a separate future instrument (with Lead/Arp, Phase G) |
| Chord map | Neutral = **I**; **`↑` = ♭VI** (A♭ in C major; its 7th colour is maj7); the rest unchanged: `↖` ii, `↗` iii, `←` IV, `→` V, `↓` vi, `↙` ♭VII, `↘` iv | `↑` duplicated I; ♭VI with ♭VII gives the ♭VI–♭VII–I lift. Same idea as the bass's low 5th |
| Chords on events | Every harp event stores its chord **relative to the key**: root offset and its 3rd, 5th, 7th intervals, plus name, numeral and colour | Changing key transposes recorded chords; followers can read the chord's real notes |
| Chord source | The **lowest-numbered harp track** with recorded chords | Predictable; a second harp can be a plain instrument |
| Current chord | The latest chord at or before a loop position (a chord up to a 1/16 late still counts on the beat), wrapping (before the first chord of the loop, the last chord carries over); **no recorded chords → the chord you last played live on the harp** (so jamming harp + bass works without recording); **no harp at all → I** (the tonic) | Recorded chords win, so playback is the same every pass |
| Bass `FOLLOW` row | `ON` (default) / `OFF` on the Bass Track page | `OFF` plays the recorded pitch exactly |
| Follow mapping | Chord roots more than a tritone above the key root are played below it (V = G below C), so a root line moves the shortest way. Degree **1 = chord root**, 3 = chord 3rd, 5 = chord 5th, 7 = chord 7th, 8 = octave, `L5` = 5th below. Diatonic chords: 2, 4, 6 walk the key's scale from the chord root (always in key). Borrowed chords (♭VI, ♭VII, iv): 2 = +2, 4 = +5, 6 = +8 (minor chord) or +9 (major) above the root | Root on neutral now means "the chord's root": the most-played bass note, with no thumb movement |
| When the chord is read | **At the note's start.** A held note keeps its pitch through a chord change; its bends use the same chord | Predictable; a bass player re-attacks on chord changes |
| What's stored | Bass events keep `degree`, `octave` *and* `semis` (as now); `FOLLOW ON` recomputes from the degree, `OFF` uses `semis` | Same files work both ways |

---

## Order

| Step | What | Size |
| :-- | :-- | :-- |
| D1 | Chord map (`↑` = ♭VI) and full chord data on harp events | S |
| ~~D2~~ | ~~Strums~~ dropped: the harp keeps its four strings | — |
| D3 | `harmony.lua`: the current chord at any tick (source track, live chord, tonic) | M |
| D4 | Bass `FOLLOW`: live and playback notes and bends follow the chord | M |
| D5 | Seeing it: chord in the top bar, chord names along the harp's tape lane, harp strum view, bass "following Am" 📱 | M |

---

## D1 · Chord map and chord data

- `Theory:getChordForDirection`: `UP` → ♭VI (root +8, major triad; 7th = +10, so ♭VI7 is a dominant-style chord like ♭VII7). Neutral stays I. The harp's D-pad labels follow.
- `chord` on every harp event: `{ name, roman, colour, root, third, fifth, seventh }`, with `root` in semitones above the key root and the others as intervals above the chord root.
- `Theory:chordFromEvent(chord)` turns that back into notes in the *current* key.

**Tests:** all 9 positions in major and minor (♭VI = A♭ in C major, F in A minor); chord data round-trips through events and saves; a key change transposes a recorded chord.

## D2 · Strums — dropped

The harp keeps one note per button. A strumming instrument is planned with Lead/Arp in Phase G.

## D3 · Harmony

- `src/harmony.lua`: `Harmony:chordAt(tick)` → chord notes for that loop position; `Harmony:source()` → the chord-source track or nil; `Harmony:liveChord()`.
- Chord changes are cached per pass (rebuilt when the source track's events change) so looking up a chord is cheap every frame.
- Muting the chord source doesn't change harmony (you can mute the harp and keep the bass following); erasing its chords or swapping it away falls back as described.

**Tests:** no harp → I; recorded chords → the right chord at, between and before the first change (wrap); two harp tracks → the lower one; live chord used only when nothing is recorded; erase / swap / clear fall back; a key change moves everything.

## D4 · Bass follows

- `FOLLOW` row (setting, saved). With `ON`:
  - live: a press reads `Harmony:chordAt(Looper.tick)` and maps the D-pad degree through it; bends map their degrees through the same chord.
  - playback: `noteOn` maps `ev.degree` / `ev.octave` through the chord at the event's tick; bend keyframes likewise; legato `glideFrom` uses `glideFromDegree`.
- `OFF`: today's behaviour (`semis` as recorded).
- Recorded `semis` is still the absolute pitch at record time, so turning `FOLLOW` off later plays exactly what you heard.

**Tests:** with a C–Am–F–G harp loop, a bass note on neutral plays C, A, F, G at the four chords; degree 3 plays each chord's third; a borrowed chord (♭VII) gives its own root and third; a held note keeps its pitch through a chord change; recording chords *after* the bass re-harmonises it; `FOLLOW OFF` plays the recorded pitch; save/load keeps `FOLLOW`.

## D5 · Seeing it 📱

- Top bar: the current chord (e.g. `Am`) next to the key, lit when a chord source exists.
- Harp tape lane: chord names at each chord change (when there's room).
- Harp view in the template: big chord name and numeral, the four strings lighting in strum order, `STRUM` and colour capsules.
- Bass view: a `FOLLOW Am` capsule (or `FOLLOW OFF`).
- Device check: strum feel and speeds, following on real loops, readability of the chord labels.

## What was built

- **D1** `Theory:getChordForDirection`: `UP` = ♭VI; chords return `root`, `third`, `fifth`, `seventh`, `suffix`, `borrowed`. Harp events store that plus the key they were recorded in (`Harp:chordData`). `Theory:chordName`, `Theory:keyShift`; harp playback shifts recorded notes to the current key. The harp's own chord only follows the D-pad while its track is active.
- **D3** `src/harmony.lua`: `source()`, `liveChord()`, `chordAt(tick)` → chord + `"recorded"` / `"live"` / `"tonic"`, `current()`. Sorted chord changes cached until the source track's events change. `LOOKAHEAD = 120` ticks.
- **D4** `Theory:getChordDegreeSemis(chord, degree)`; Bass `FOLLOW` row (saved), `Bass:pitchFor`. Live notes read the chord at the press and keep it for their bends; playback reads the chord at the event's tick (also for `glideFrom` and bend keyframes). Events still store the pitch heard, for `FOLLOW OFF`.
- **D5** Top bar `CHORD` (lit when it comes from the harp, dim for the plain tonic); chord names along the chord-source lane; bass `FOLLOW Am` / `FOLLOW OFF` capsule; harp view shows the colour; harp D-pad labels `I` (centre) and `bVI`.

**Tests:** `tests/test_harmony.lua` (19) and 4 in `test_theory.lua`: chord map and data, follow degrees (tonic = plain scale degrees in every scale), source rules, late chords, wrap, live chord, fallbacks, key change, a root line following C–Am–F–G, thirds/fifths/low fifth, borrowed chords, re-harmonising after the fact, `FOLLOW OFF`, live following, bends over the note's chord, held notes keeping pitch, save/load. Disabling playback follow, live follow, lookahead, wrap or the key shift each fails tests.

## Exit checklist

- [x] `python3 tests/run.py` green (218)
- [ ] A recorded chord loop makes a root-note bass line follow it
- [ ] Recording chords after the bass re-harmonises it; `FOLLOW OFF` doesn't
- [ ] Chords visible in the top bar and on the harp lane

## Settled

1. Harp buttons: one string each, as before; strumming becomes a separate instrument later.
2. Neutral = I; `↑` = ♭VI.

## Open (settle by playing)

1. Do followers sound right on borrowed chords (♭VI, ♭VII, iv), or should 2/4/6 there snap to chord tones?
2. Should a held bass note re-pitch when the chord changes under it? (Planned: no.)
3. Should playing the harp live (while not recording) temporarily override recorded chords for the followers?
