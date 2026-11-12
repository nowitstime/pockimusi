# Phase B · Bass Pass — Working Plan

Part of [ROADMAP.md](ROADMAP.md). Design: [SPEC.md](SPEC.md) §7.3. Builds on Phase A: v2 events with `len` (A6) and sustained voices (A7).

**Goal:** the bass becomes a real held-note instrument. Notes sound while you hold the button and stop when you let go; moving the D-pad while holding glides to the new degree, and that glide is recorded and replays; recorded notes show as ribbons with their bends. Plus a few bass sounds to choose from.

**Rule for every step:** one step = one or a few commits, each leaving the app playable, tests green. 📱 = check on the RG35XX at the end of the step.

---

## Decisions (change any of these before we start)

| Topic | Decision | Why |
| :-- | :-- | :-- |
| Voices | **Monophonic, last-note priority** on `SAW` and `SUB`; **`PLUCK` lets notes overlap** (each press its own voice; bends move the newest note) | A bass line is one note at a time; a pluck should ring on |
| `B` | **Hold** — normal note, sounds while held | The default way to play |
| `A` | **Legato** — glides from the note you're holding (or the last note) without a new attack | Slides and smooth lines |
| `Y` | **Staccato** — one grid step long (the track's grid; 1/16 on `FREE`), ignores how long you hold | Tight, plucky bass that locks to the groove |
| `X` | **Accent** — louder, held, with vibrato | Emphasis |
| Old `Y` / `X` (+octave pop, +fifth) | **Removed.** `R1` is the octave; the fifth is degree 5 on the D-pad | SPEC §7.3: face buttons say *how*, the D-pad says *which note* |
| D-pad while holding | **Glides gradually** to the new degree at the track's glide speed (never jumps), recorded as `bend` keyframes. The D-pad only ever chooses the note | The "ribbon" in Ribbon Bass |
| D-pad after letting go | **The release tail keeps following the D-pad** until it is silent or the next note starts; those moves are recorded (keyframes after `len`) and replay too | Glissando after release, as it works today |
| Shoulders while holding | Octave change glides too (same as a D-pad bend) | Same rule for every pitch change |
| Neutral D-pad | Degree 1 (root), as now | Releasing the D-pad lands on the root |
| Track page rows | `PATCH` (3 bass sounds) and `GLIDE` (fast / medium / slow) | `FOLLOW` waits for Phase D, where it does something |
| Swing | Stays on the Transport page (`START` + `Y`), not a bass row | Already built there for every track |

---

## Order

| Step | What | Size | Depends on |
| :-- | :-- | :-- | :-- |
| B1 | Held-note handles can end early and record bends (generic, for Bass/Pad/Lead) | M | — |
| B2 | Bass sounds: 3 patches + `PATCH` and `GLIDE` rows | M | — |
| B3 | Bass plays held notes: `B` hold, `Y` staccato, `X` accent; mono | M | B1, B2 |
| B4 | Legato `A`: glide without a new attack, live and on playback | M | B3 |
| B5 | Bends: D-pad and shoulders while holding glide, record, replay | M | B1, B3 |
| B6 | Bass stage view + bend marks on the tape deck 📱 | M | B3–B5 |

---

## B1 · Held-note handles: early release and bends

Today `hold(ev)` returns nothing and the note ends only when its button goes up. A mono bass needs to end the old note when a new one starts, and to record pitch changes while held.

- `hold(ev)` returns a **handle** `h`:
  - `h:release()` ends the note now (the auto-release on button-up stays).
  - `h:bend(fields)` records a pitch change while held: appends `{ dt = ticks since press, degree, octave, semis }` to the recording's `bend` list and calls the instrument's `def:bendTo(h.ev, fields, state, track)` so the live voice follows.
- Recorded events get `bend = { ... }` only when something was bent (one-shots stay small).
- **Playback:** the looper already knows which notes are sounding. A shared helper `Instruments:bendAt(ev, elapsedTicks)` returns the latest keyframe at that point, and `def:updateVoices` applies it to playback voices. Elapsed ticks are measured from the note's (swung) start, wrapping across the loop seam.
- **Release tail:** `h:bend` keeps working after the note is released, until the instrument stops bending it (its voice is silent, or a new note took over). Those keyframes land after `len` (`dt > len`) and playback applies them to the voice while it fades. Keyframes stop if a note is held longer than a whole loop (so `dt` never wraps).
- Re-recording, erase, undo, 2↔4 bars: `bend` is copied with the event; on 4→2 bars, keyframes past the cut length are dropped.

**Tests:** early release sets `len` correctly; bend keyframes have the right `dt` and order; bends after release are recorded with `dt > len`; `bendAt` returns the right keyframe across the seam; one-shots get no `bend`; 2→4 bars copies keyframes (not shared tables).

**Status:** ✅ done (125 tests). `hold(ev)` returns a handle with `release()`, `bend(fields)`, `isHeld()`; time since the press is counted frame by frame (`Handle:advance`), so `len` and bend `dt` are right across the loop seam, a stutter jump back doesn't count, and a note held over a loop caps `len` and stops recording bends. `Instruments:bendAt(ev, elapsed)` is the playback lookup. 2→4 bars gives copies their own keyframes; 4→2 drops keyframes past the new end. Live bends reach `def:bendTo` whether or not recording. Nothing uses bends yet: Bass does in B3–B5.

---

## B2 · Bass sounds and rows

- Three bass patches, each a one-shot attack plus a seamless loop (A7):

  | Patch | Character |
  | :-- | :-- |
  | `SAW` | today's sound: bright saw with a square sub |
  | `SUB` | round, nearly sine, deep |
  | `PLUCK` | sharp attack, quieter sustain, faster release (funky, close to today's one-shot feel) |

- **`PATCH` row** (sound row): `L1/R1` steps through them and plays a short preview note.
- **`GLIDE` row** (setting row): `FAST / MEDIUM / SLOW` → glide rates of roughly 40 / 18 / 8 per second; used by legato and bends.
- The patch is per track (`state.patch`), so two bass tracks can sound different.

**Tests:** rows list `PATCH` and `GLIDE`; cycling changes `state.patch` / `state.glide`; each patch loop is seamless and in tune (reuses the A7 seam check).

**Status:** ✅ done (132 tests, new `tests/test_bass.lua`). Patches `bass_saw` (today's sound; attack = the `bass` one-shot), `bass_sub` and `bass_pluck` (new attack buffers + loops; `PLUCK` has `overlap = true`, low sustain and a 0.45 s ring). `state.patch` / `state.glide` per track (kept through swap + undo). `PATCH` previews the attack on change; `GLIDE` is a setting row (FAST 40 / MEDIUM 18 / SLOW 8 per second, used from B4). Until B3, the bass's one-shot notes already play the chosen patch's attack, so the row is audible now.

---

## B3 · Held notes: hold, staccato, accent, mono

- `B` → `hold({ action = "B", degree, octave, semis, vel = 0.85 })`; `noteOn` starts `Synth:noteOn(patch, ...)`, `noteOff` releases it.
- `X` → same, `vel = 1.0`, vibrato on.
- `Y` → a held voice that releases itself after one grid step (the track's grid; 1/16 on `FREE`); recorded with that `len`, whatever the button does.
- **Mono** (`SAW`, `SUB`): pressing any face button first releases the bass's other held note (`h:release()`), so its recorded `len` ends exactly where the new note starts. **`PLUCK`** skips that: notes overlap and ring out.
- Playback voices are kept per event in the bass state, so `noteOff` (and every looper release: mute, clear, undo, swap…) stops the right one.

**Tests:** a held `B` records one event with the held length and sustains on playback for that length; `Y` records one grid step whatever the hold; `PLUCK` notes overlap; pressing `X` while holding `B` closes `B` at that tick; mute/clear during a playing note stops it; v2 fields (`degree`, `octave`, `semis`) are stored.

**Status:** ✅ done. Bass notes are held voices (`Synth:noteOn` with the track's patch); `Y` uses `hold(ev, { fixedLen = grid step })`, which the router releases by length instead of by button. Mono patches end the held note on a new press and set the old note's recorded `len` to end exactly at the new note's snapped start (no gap or overlap on playback). A note counts as held only while its button is down (the router releases it a moment later in the same frame), so letting go and pressing in one frame is not legato.

---

## B4 · Legato (`A`)

- **Live:** if a bass note is held, `A` takes over its voice: no new attack, the voice glides to the new pitch at the `GLIDE` speed. The old note's recording ends here; the `A` note starts here with `glideFrom` (previous semis, degree and octave).
- If nothing is held, `A` starts a new voice gliding up from the last note played.
- **Playback:** when an `A` note starts and the track's previous bass voice is still sounding or only just released (≤ 30 ms), it takes that voice over the same way; otherwise it starts a voice with `glideFrom`. This keeps recorded slides smooth even though the old note's note-off and the new note's note-on land on the same tick.

**Tests:** live legato reuses the voice (no attack trigger) and glides; playback legato reuses the previous voice; without a previous note it glides from `glideFrom`.

**Status:** ✅ done. Live legato marks the event `legato = true` (plus `glideFrom`, `glideFromDegree`, `glideFromOctave`); on playback only those notes take over the previous voice (sounding, or released ≤ 50 ms ago). A plain `A` with nothing held glides up from the last note with its own attack, live and on playback.

---

## B5 · Bends

- While a held note sounds, each frame the bass recomputes the target from the D-pad and shoulders. When it changes, `h:bend({ degree, octave, semis })`: the live voice glides there and the recording gets a keyframe.
- After letting go, the bends go to the fading note until it is silent or the next note starts (decision above).
- `Y` (staccato) and overlapping `PLUCK` notes: bends move the newest note.
- Playback: `updateVoices` applies `Instruments:bendAt` to each sounding playback note, so the line replays with the same moves at the same points.

**Tests:** a hold with two D-pad moves records two keyframes with increasing `dt` and the right degrees; playback reaches each bent pitch at the right time; octave changes are keyframes too.

**Status:** ✅ done. Pitch changes go to the newest held note, or the newest note's fading tail. In the tail only a D-pad direction moves the note: neutral, or letting go of a shoulder, keeps the pitch (otherwise releasing everything together swooped the tail down to the root). Playback applies keyframes through the release tail. Pulled forward from B6: glide marks on tape-deck ribbons (tick above = up, below = down).

**Tests for B3–B5:** 18 in `tests/test_bass.lua` (150 total). Removing the held-button check, the tail neutral rule, the end alignment, the legato flag or tail bends each fails its tests.

---

## B6 · Stage view and tape deck 📱

- **Centre view** (keeps the wave-display character):
  - big note name + degree / octave; the held articulation (`HOLD`, `LEGATO`, `STACCATO`, `ACCENT`)
  - oscilloscope driven by the live voice's real level and pitch
  - the bottom "ribbon" becomes a **pitch trace**: the last second or so of the voice's actual pitch, so glides and bends are visible as curves
- **Face labels:** `B HOLD`, `A LEGATO`, `Y STAC`, `X ACCENT` (D-pad keeps the degree labels).
- **Tape deck:** bass notes already draw as ribbons (Phase A). Add a small mark on the ribbon at each bend keyframe; full bend curves stay in Phase I.
- Screenshot scenes for each articulation and a recorded bent line.
- **Device check:** feel of hold/legato/staccato, glide speeds, the three patches, CPU/frame rate with several bass notes and track effects on, and the `log.txt` boot time.


**Status:** ✅ built (153 tests); ⬜ device look and feel.

- `Chrome:drawBassView`: the sounding note's name (mid-glide too; the D-pad's degree in the track colour when idle), `DEG · OCT · articulation` (or `READY`), patch and glide capsules, oscilloscope, pitch trace.
- `Bass:sampleTrace` (every frame, from `updateVoices`) records the display voice's pitch and level into a 72-sample ring (1.2 s); `Bass:getDisplayVoice` = newest live note while it sounds, else the newest playback note. The oscilloscope's speed and height come from the same voice.
- The trace scales to at least an octave around what was played; brighter = louder; a dot marks the newest sample; "PITCH TRACE" when empty.
- Face labels fixed: `HOLD`, `LEGATO`, `STAC`, `ACCENT` (they still showed the pre-B3 `PLUCK / GLIDE / +OCT / +5TH`).
- Glide marks on tape-deck ribbons were done in B5.
- Screenshot scenes: `bass-idle`, `bass-glide`, `bass-legato`, `bass-line`, `track-bass`.
---

## Exit checklist for Phase B

- [x] `python3 tests/run.py` green (153)
- [x] Held bass notes sustain exactly as long as held, live and on playback (tested on device)
- [x] Legato glides without a new attack, live and on playback (tested on device)
- [x] D-pad / shoulder bends glide live, record, and replay in time (tested on device)
- [x] Three patches and three glide speeds selectable on the Track page
- [x] Bass notes and bends visible on the tape deck
- [ ] Feels right on the RG35XX; frame rate and boot time noted

## Settled questions

1. Accent stays on `X`; the D-pad only chooses the note.
2. Slides glide gradually toward scale degrees at the glide speed.
3. Staccato follows the track's grid.
4. `PLUCK` allows overlapping notes.
5. The release tail keeps following the D-pad, recorded and replayed.
