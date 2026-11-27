# Phase E · Pad (replaces Grain) — Working Plan

Part of [ROADMAP.md](ROADMAP.md). Design: [SPEC.md](SPEC.md) §3.2, §5, §7.4, §9.2.

**Goal:** track 4 becomes a chord pad. Hold one button and the current chord sustains under the jam; when the harp's chords change, the pad moves with them. The D-pad shapes the tone (brightness, movement) instead of choosing notes, so the pad is the easiest instrument to play. Grain goes; its four textures become the Pad's patches.

**Rule for every step:** one step = one or a few commits, app playable, tests green. 📱 = check on the RG35XX.

---

## Decisions

| Topic | Decision | Why |
| :-- | :-- | :-- |
| Buttons | **`B` full** chord (4 notes), **`A` open** (root, 5th, octave), **`Y` high** (5th, octave, 3rd above), **`X` swell** (the full chord with a slow attack). Hold = sustain | SPEC §7.4 |
| One press | One event with a length (`action`, `octave`, the notes it played, tone) | Same as every held note |
| Layering | Buttons overlap: `B` + `Y` held together sound together | Thicker pads with no extra controls |
| Shoulders | `L1` octave down, `R1` octave up, read at the press | SPEC §3.2 |
| Which chord | The **current chord** from Harmony at the press (recorded harp chords, else the chord last played live, else the tonic) | Works with no harp at all: it plays the key's I chord |
| Colour | The full chord uses the harp's colour for that chord: 7th, 9th, sus4, add9 | The pad matches what the harp played |
| **Held through a chord change** | With `FOLLOW ON` the pad **re-voices**: each note glides to the new chord (~150 ms). This differs from the bass, which keeps its pitch | Holding one button for the whole loop and hearing the changes is the point of a pad |
| `FOLLOW ON` (default) | Playback rebuilds the chord from Harmony, so recording or changing chords later re-harmonises pads already recorded | Same rule as the bass |
| `FOLLOW OFF` | Playing live still picks up the current chord at the press, but a held chord stays put, and playback uses the notes as recorded (moved with the key) | "Exactly as recorded" |
| D-pad | **`↑/↓` brightness, `←/→` movement.** Hold to sweep (about 1.5 s end to end); the value stays where you leave it | A filter-style sweep with the left thumb while the right holds the chord |
| Brightness | Each patch has a **dark** layer and a **bright** layer (upper harmonics); brightness is the bright layer's level | SPEC §9.2: crossfade, no filter needed |
| Movement | Slow pitch drift per note (up to ±9 cents, each note at its own speed), the bright layer detuned against the dark one, and a slow shimmer on the bright layer | Gives back the chorus the seamless loops can't contain |
| Recording the tone | Each event stores brightness and movement at the press; sweeps while holding are recorded as keyframes (like bass bends) and replayed | What you hear while playing is what replays |
| Rows | `PATCH` (`WARM`, `BELL`, `CHOIR`, `DRONE`), `FOLLOW` (on/off), `ATTACK` (fast 30 ms / medium 250 ms / slow 900 ms), `RELEASE` (short 0.25 s / medium 0.9 s / long 2.5 s) | SPEC §3.3 |
| Swell | Attack = 3× the `ATTACK` row, at least 1.2 s | Always clearly slower than the other buttons |
| Register | Chords sit around middle C; roots more than a tritone above the key root go below it (as for the bass). `BELL` sounds an octave higher, `DRONE` an octave lower | Smooth moves between chords; patches keep their character |
| Level | Each note's level is divided by √(number of notes) | A four-note chord isn't four times louder than the bass |
| Voices | 12 per patch (two layers each); the oldest is taken when they run out | Two overlapping four-note chords plus a tail |
| Grain | Removed: the instrument, its one-shot grain buffers and the `grain_*` patches. Default slot 4 = Pad | Roadmap |
| Old saves | A saved Grain track loads as a Pad with its notes kept (each old press becomes a held chord) | The autosave on the device has a Grain track |

---

## Order

| Step | What | Size |
| :-- | :-- | :-- |
| E1 | Voice engine: bright layer, per-note attack and release, movement; the four Pad patches | M |
| E2 | Pad instrument: voicings, held chords, rows, save; Grain removed; old saves load | M |
| E3 | Follow: held and recorded pads move with the chords; `FOLLOW OFF` | M |
| E4 | Tone on the D-pad: brightness and movement, recorded and replayed | S |
| E5 | Stage view in the template 📱 | M |

---

## E1 · Voice engine and patches

- `voice.lua`: a patch may name a `bright` loop pool, paired source for source with its main pool. A voice takes `attack`, `release`, `bright`, `move` options; brightness changes are smoothed. The attack one-shot is optional (pads have none, except `BELL`'s strike on fast attacks).
- A release starts from the level the note had reached, so a short tap with a slow attack fades instead of swelling after you let go.
- `synths_bank.lua`: `pad_warm`, `pad_bell`, `pad_choir`, `pad_drone`, each a dark and a bright seamless loop. The Hann-windowed grain buffers and `grain_*` patches go.

**Tests:** all loops (both layers) seamless and in tune; the bright layer is silent at brightness 0 and follows the envelope; per-note attack and release times; a tap during a slow attack only fades; stealing frees both layers; movement stays within its cents.

## E2 · Pad instrument

- `Theory:getPadVoicing(chord, shape, octave)`: the notes of `FULL`, `OPEN`, `HIGH` for a chord, kept inside the playable range.
- `src/instruments/pad.lua`: `hold()` per press; one voice per note; rows; save and load.
- `grain.lua` deleted; catalogue, default slots, desktop test key and the tests that used Grain as "the holding instrument" move to Pad.
- `Session`: `grain` → `pad` when loading.

**Tests:** each button's notes in C major and on a minor chord; one event per press with the held length; buttons layer; opening a page, muting, a fresh session and restoring all silence it; rows cycle and save; an old Grain save loads as a Pad.

## E3 · Follow

- `Harmony:chordAt(tick, lookahead)`: the pad asks with the usual 1/16 lookahead at a note's start and with none while holding, so a held chord changes on the beat, not a 1/16 early.
- Live and playback notes re-voice when the chord at the playhead changes (`FOLLOW ON`).
- `FOLLOW OFF`: stored notes, shifted with the key.

**Tests:** with a C–Am–F–G harp loop, one pad held for the loop plays all four chords; recorded, it replays them; chords recorded after the pad re-harmonise it; `FOLLOW OFF` keeps the recorded notes; a pad pressed just before a late chord doesn't flip back and forth; a key change moves both.

## E4 · Tone

- `↑/↓` and `←/→` sweep `bright` and `move` (0–1); live notes follow at once.
- Sweeps while holding become keyframes `{ dt, bright, move }` in the event's `bend` list (at most one per 4 % of change); playback applies them.
- Saved with the session; 2↔4 bars copies and trims them like pitch bends.

**Tests:** sweeping changes the live voices; keyframes are recorded and replayed; save and load keeps them; the values clamp at both ends.

## E5 · Stage view 📱

- Middle column: the chord being held (or the current chord), the button's shape and octave, patch and follow capsules, a field with one glowing line per sounding note (height = pitch, strength = level, wobble = movement, glow = brightness; idle shows the full chord faintly), and `BRIGHT` / `MOVE` bars.
- D-pad labels `BRIGHT +/−`, `MOVE −/+`; face labels `FULL`, `OPEN`, `HIGH`, `SWELL`.
- Device check: levels against the bass and drums, the four patches, sweep speed, chord changes while holding, frame rate with 12+ voices.

## Exit checklist

- [x] `python3 tests/run.py` green (244 tests; `tests/test_pad.lua` is new)
- [x] A held pad follows a recorded harp loop, live and on playback (tests; 📱 by ear)
- [ ] The four patches sound right on the device, at sensible levels 📱
- [ ] Brightness and movement sweeps are audible, recorded and replayed 📱
- [ ] No frame drops with two chords and a tail sounding 📱

## Status

Built: E1 to E5. Nothing here has been listened to yet: the sound design (patch harmonics, levels, movement depth) was written without hearing it and needs the device.

## Open (settle by playing)

1. Should a held pad re-voice by gliding (planned) or re-attack on each chord change?
2. Should the D-pad values spring back when released instead of staying put?
3. Should pad notes snap their start to the grid by default (now `FREE`, like the harp)?
4. `X` swell could become a "charge" (hold longer = bigger swell), see [FUTURE_INSTRUMENTS.md](FUTURE_INSTRUMENTS.md).
