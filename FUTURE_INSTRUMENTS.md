# PocketGroove — Future Instruments (the lab)

Companion to [SPEC.md](SPEC.md) and [ROADMAP.md](ROADMAP.md). The roadmap covers the instruments already decided (Drums, Chord Harp, Bass, Pad, Lead/Arp). This file is the **lab**: ideas for other ways of playing, written up far enough to prototype. Nothing here is scheduled. An idea moves to the roadmap only after it has been played and has earned a slot (§7).

Legend: 🧪 worth prototyping · 🧩 better as a setting or layer on an existing instrument · 💤 parked · ❓ needs a decision or a playtest

---

## 1. What makes an instrument different

SPEC §7 says each instrument must be *a different way of playing, not a different sound*. Today every instrument uses the same shape: **the left thumb chooses, the right thumb triggers**. The ideas below each change that shape. They start from what a controller can do that nothing uses yet:

| Controller ability | Used today | Idea that uses it |
| :-- | :-- | :-- |
| Press a button | every instrument | — |
| Hold a button (length) | Bass, Pad | — |
| Move the D-pad while holding | Bass bends | — |
| Two face buttons at once / rolling the thumb | no | **Dial** (§4.2) |
| Choose silently, trigger elsewhere | no | **Pick** (§4.1) |
| Both thumbs striking in turn | no | **Hand Drums** (§4.3) |
| D-pad as *speed* instead of *position* | no | **Slide** (§4.4) |
| D-pad as *movement on a map* (position is remembered) | no | **Map** (§4.5) |
| D-pad motions before a press | no | **Motions** (§4.6) |
| The release as its own event | no | **Push/Pull** (§5) |
| How long you held before releasing | no | **Charge** (§5) |
| Playing the other tracks instead of notes | `R2` punch-ins (not recorded) | **Tape** (§4.7) |

A second check for every idea: *what do my hands decide, and what does the machine decide?* Two instruments with the same answer are the same instrument.

---

## 2. What the hardware and the grammar allow

These limits shaped every design below.

**Buttons an instrument may use:** D-pad (8 directions + neutral), `B A Y X`, `L1`, `R1`. `L2`, `R2`, `SELECT` and `START` are global (SPEC §3.1) and stay that way.

**What one thumb can reach on the face diamond:**

- one button, or **two neighbouring buttons** (`B+A`, `A+X`, `X+Y`, `Y+B`) by laying the thumb across both;
- not opposite pairs (`B+X`, `A+Y`), and not three or four at once.

So the diamond has **8 reachable fingerings**, not the 15 that four buttons give on paper. (An earlier "Valves" idea assumed 15; §4.2 is the version that fits a thumb.)

**Timing:** input is read once per frame (about 16 ms). Two buttons meant to land together often arrive one frame apart, so anything that reads button combinations needs a short **settle window** (about 35 ms) before it commits.

**Grammar to keep where possible** (SPEC §3.1): right thumb triggers, left thumb is pitch or expression, `L1` = lower / sparser, `R1` = higher / denser. Each idea says where it breaks this and why.

**Existing rules that some ideas bump into:**

| Rule | Where | Affects |
| :-- | :-- | :-- |
| Erase is per face button: `L2 + R2 + B/A/Y/X` clears events with that `action` | `modes.lua` | Pick, Hand Drums (split), Dial |
| `L2 + R2 + LEFT` and `L2 + R2 + L1` are undo | `modes.lua` | any erase gesture for D-pad or shoulder actions |
| A held note ends when its `action` button goes up | `Instruments:update` | Dial (a note spans several buttons) |
| ≤ 6 rows on the Track page | SPEC §3.4 | Hand Drums (8 pads) |
| Sounds are generated at boot and replayed; there is no audio bus to record from | `synth/` | Tape (no true reverse or scratch) |

---

## 3. Summary

| Idea | You decide | Machine decides | Distinct feel | Size | Verdict |
| :-- | :-- | :-- | :-- | :-- | :-- |
| **Pick** | note with one hand, timing with the other | — | high | M | 🧪 first wave |
| **Dial** | scale steps by rolling the thumb | octave carry | high | M | 🧪 first wave, after a button test |
| **Hand Drums** | every hit, two-handed | — | medium–high | S | 🧪 first wave (cheapest) |
| **Slide** | direction and speed of pitch | landing on the scale | high | S–M | 🧪 first wave |
| **Map** | where to wander | voicing, voice leading | high | M–L | 🧪 second wave (after Phase D) |
| **Motions** | note + which ornament | the ornament's notes and timing | high | L | 🧩 layer on Bass/Lead first |
| **Tape** | which effect, when | what it does to each track | medium | L | 🧩 recordable punch-ins first |
| Push/Pull, Charge | — | — | — | S | 🧩 options on other instruments |
| Garden, Shadow, Stepper, Riff, Conductor, Vowel | see §5 | | | | 💤 / later |

Size: S = an evening, M = a few sessions, L = a phase of its own.

---

## 4. Candidates in detail

### 4.1 Pick 🧪 — split hands, like fretting and picking

**Feel:** you set the note up silently with your thumbs, and nothing sounds until an index finger plucks it. Alternating the two shoulders gives fast tremolo picking and strums that one thumb cannot play.

| Control | Job |
| :-- | :-- |
| D-pad | Degree, same compass as Bass (neutral = root), **silent** |
| `B A Y X` (held) | Add strings above the root, **silent**: `B` third, `A` fifth, `X` octave, `Y` seventh ❓ |
| `R1` | Downstroke: plays the root and every held string, low to high |
| `L1` | Upstroke: the same, high to low |
| `L1 + R1` | Damp: stops everything ringing |

- No face button held = a single note, so it works as a melodic instrument. With strings held it strums.
- **The patch decides the behaviour**, as `PLUCK` does on Bass: plucked patches ring on; sustained patches sound only while the shoulder is held, which turns the same instrument into a **bow** (down-bow `R1`, up-bow `L1`, D-pad changes glide).
- **Rows:** `PATCH`, `REGISTER` (low / mid / high, since the shoulders no longer shift octave), `STRUM` (spread: tight / loose), `FOLLOW`.
- **Events:** one event per stroke: `action = "R1"` or `"L1"`, `degree`, `octave`, `semis`, plus `stack = {2, 4}` (scale steps above the root, so chord-follow can re-harmonise) and `strum` (spread in ticks, negative = upstroke).
- **Engine needs:** nothing new for held notes (a handle already follows any button in `Input.down`). Strum playback needs several voices from one event.
- **Breaks the grammar:** shoulders trigger instead of setting register. That is the whole point of the instrument.
- ❓ Erase: events have shoulder actions, and `L2 + R2 + L1` is undo. Proposal: `L2 + R2 + B` clears downstrokes, `+ A` clears upstrokes.
- ❓ Face-button string map, and whether the octave belongs on a row or on a face button.

**Playtest:** can you alternate-pick steady 1/16 notes at 120 BPM for two bars? Do fast lines come out cleaner than on Bass? Is the bow version worth keeping?

### 4.2 Dial 🧪 — the scale as a circle under the right thumb

**Feel:** the four face buttons and the four neighbouring pairs form eight positions around the diamond. Rolling the thumb clockwise walks up the scale; a fast roll is a run; rocking between a button and its pair is a trill. Keep rolling past the top and you climb into the next octave.

| Position (clockwise) | `B` | `B+A` | `A` | `A+X` | `X` | `X+Y` | `Y` | `Y+B` |
| :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- |
| Degree | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |

The single buttons are 1, 3, 5, 7: chord tones on the buttons, passing notes between them, close to the harp's strings.

| Control | Job |
| :-- | :-- |
| Face diamond | Note. Sounds while any face button is down |
| Roll to a neighbour | Slur: same note continues at the new pitch (legato, no new attack) |
| Lift and press elsewhere | New note in the current octave |
| D-pad `↑ / ↓` | Dynamics: accent with vibrato / soft (the same axis as on Drums) |
| D-pad `← / →` | Flat / sharp by a semitone: the only way to notes outside the scale |
| `L1 / R1` | Octave down / up |

- **Octave carry:** `Y+B` (8) and `B` (1 of the next octave) are the same pitch. Rolling clockwise across that seam keeps the pitch and moves the octave up one; anticlockwise moves it down. One step per lap makes no change in sound, then the roll continues in the new octave. `L1 + R1` returns to the home octave.
- **Settle window:** a change of fingering within about 35 ms of a fresh press is treated as a correction (the note is re-pitched and the recording is fixed), not as a slur. After that, changes are slurs.
- **Rows:** `PATCH`, `GLIDE` (slur speed; instant by default), `FOLLOW`.
- **Events:** one event per note with `degree`, `octave`, `semis`; slurs are `bend` keyframes, which already record and replay (Phase B).
- **Engine needs:** (1) held notes that are released by the instrument instead of by one button (`hold(ev, { manual = true })`); (2) a small helper in `input.lua` that reports the current face fingering with the settle window.
- ❓ Erase per face button does not fit (a note has no single button). Proposal: `L2 + R2 +` face clears the notes whose *starting* position was that button or its clockwise pair.
- **Biggest risk:** whether a thumb lands neighbouring pairs reliably on the RG35XX's small buttons. **Test this first** with a 20-line screen that just shows the fingering; if pairs are unreliable the idea is dead on this device.

**Playtest:** can you play a one-octave scale up and down by rolling, evenly, without looking? Does the octave seam feel natural or like a bug?

### 4.3 Hand Drums 🧪 — two thumbs, eight pads

**Feel:** the D-pad stops being a modifier and becomes four more pads. Left and right thumbs alternate, which gives rolls, paradiddles and conga patterns that one thumb cannot play.

| Control | Job |
| :-- | :-- |
| `B A Y X` | Pads, as on Drums |
| D-pad `↑ ↓ ← →` | Four more pads (a diagonal plays both) |
| `L1` | Ghost: soft, short |
| `R1` | Accent: loud, longer |
| `L1 + R1` | Note repeat at the track's grid, as on Drums |

- **`HANDS` row:** `MIRROR` = the D-pad plays the same four sounds as the face buttons (for rolls on one drum); `SPLIT` = eight different sounds.
- In `MIRROR`, a D-pad hit is recorded under its matching face `action`, so the event format, the four-lane view, erase and the tape deck all work unchanged. This makes MIRROR the cheapest experiment in this file.
- ❓ Which way to mirror: same direction (`←` = `Y`, `→` = `A`) or mirror image (`←` = `A`). Try both.
- **Rows:** `KIT`, `HANDS`, then the pad rows. `SPLIT` has 8 pads, which breaks the 6-row limit ❓ (show the kit, `HANDS` and only the last-hit pad's row).
- **Events:** same as Drums. `SPLIT` adds `action = "UP"` etc.; erase for those needs a gesture that avoids `L2 + R2 + LEFT` (undo) ❓.
- **What it gives up:** flam and ratchet on the D-pad (SPEC §3.2a). Swapping Drums ↔ Hand Drums keeps events, so a pattern can be recorded on one and decorated on the other.
- **Could simply be a `HANDS` row on Drums** (Off / Mirror / Split) instead of a separate instrument. Prototype it as a separate instrument, then decide.

**Playtest:** can you play a clean 1/16 single-stroke roll at 120 BPM in `MIRROR`? Do you miss flam and ratchet?

### 4.4 Slide 🧪 — the D-pad is speed, not position

**Feel:** like a trombone, a fretless or a theremin. Holding `↑` makes the pitch rise for as long as you hold it; letting go leaves it where it is. You steer the pitch instead of choosing it.

| Control | Job |
| :-- | :-- |
| `B` | Note: sounds while held, at the current pitch |
| `A` | Note that **snaps** to the nearest scale note when the D-pad is released |
| `Y` | Dive: note that falls away on release |
| `X` | Accent with vibrato |
| D-pad `↑ / ↓` | Pitch rises / falls smoothly while held |
| D-pad `← / →` | Jump to the previous / next scale note (a quick way back onto the grid of the scale) |
| `L1 / R1` | Octave; held while sliding = slide four times faster |
| `L1 + R1` | Back to the root |

- **Rows:** `PATCH`, `SPEED` (slow / medium / fast), `SNAP` (off / soft / hard: how strongly the pitch settles on scale notes), `FOLLOW` (the home pitch follows the chord root).
- **Events:** a held note plus `bend` keyframes with fractional `semis`. The format and the playback already exist; keyframes need thinning (for example one per 30 ticks) so a long slide does not store one per frame.
- **Engine needs:** bends that carry `semis` without a `degree`; check the Bass stage-view trace and the tape-deck bend marks cope with that.
- **Why it matters beyond itself:** this is the software test for the hardware slider idea. If continuous pitch is not fun here, a physical slider will not be either; if it is, the bend data already supports one.

**Playtest:** can you land on a target note by ear without `SNAP`? With `SNAP = soft`, does it sound expressive or just out of tune?

### 4.5 Map 🧪 (second wave) — wandering through harmony

**Feel:** the D-pad moves a cursor over a map of chords, and the position stays when you let go. Every step lands on a chord that shares notes with the last one, so wandering always sounds related. You explore rather than select.

| Control | Job |
| :-- | :-- |
| D-pad `← / →` | Step by a fifth (IV ← I → V): a strong change, one note shared |
| D-pad `↑ / ↓` | Step by a third (vi ↓ I ↑ iii): a soft change, two notes shared |
| Diagonals | Both steps at once |
| `B` | Play the chord where you stand (held) |
| `A` | Bass note only |
| `Y` | Roll the chord upward (arpeggio at the track's grid) |
| `X` | Top note only |
| `L1 / R1` | Voicing octave down / up |
| `L1 + R1` | Home: back to I |

- **The machine picks the voicing:** each new chord uses the inversion closest to the previous one, so the notes move as little as possible. That is where the smooth sound comes from.
- **Map:** in-key by default (seven chords, wrapping around, so no step is ever wrong). `ROAM` row: `KEY` (in-key) / `FREE` (true fifths and thirds, which can leave the key and come back).
- **Rows:** `PATCH`, `COLOUR` (shared with the harp), `ROAM`.
- **Events:** `chord` events as the harp will record in Phase D, so a Map track can be the **chord source** for chord-follow instead of a harp.
- **Stage view:** the map with a cursor and a fading trail of where you have been. It suits the constellation look.
- **Answers a harp open question:** SPEC §13.2 asks whether a neutral D-pad should keep the last chord. On Map it always does.
- **Engine needs:** `harmony.lua` (Phase D). Build after D.
- **Risk:** position is remembered, so you can get lost without the screen. The home gesture and the "no wrong step" rule are the mitigations.

**Playtest:** after two minutes, can you find I → vi → IV → V without looking? Does wandering produce progressions you would not have chosen on the harp?

### 4.6 Motions 🧩 — ornaments from D-pad gestures

**Feel:** fighting-game inputs. A plain press plays a note as on Bass. A D-pad motion just before the press adds an ornament that lands on that note.

| Motion (within about 200 ms before the press) | Ornament |
| :-- | :-- |
| none | plain note |
| quarter circle toward the note (e.g. `↓ ↘ →`) | run: three scale notes leading up to it |
| quarter circle the other way | run coming down to it |
| tap the direction twice | grace note from the step below |
| opposite direction, then the note | trill for as long as the button is held |
| half circle | arpeggio through the current chord |

- Motions happen **before** the press and Bass bends happen **while holding**, so the two do not collide. A motion must pass through the diagonal to count, which keeps ordinary fast playing from setting one off.
- Ornament notes are placed by the clock so the main note stays on the grid, the way a drum flam's grace note does today (SPEC §3.2a).
- **Events:** the main note plus `orn = "run_up"` etc., expanded at playback like flam and ratchet, so ornaments follow tempo, swing and chord changes.
- **Engine needs:** a short D-pad history in `input.lua`; clock-placed sub-notes for pitched voices (Lead/Arp needs the same scheduling in Phase F).
- **Verdict:** not a separate instrument. It is an `ORNAMENTS` row (off / on) on Bass and Lead. Highest risk here (hidden moves, false triggers), and possibly the most fun. Try after Phase F, when the scheduling exists.

### 4.7 Tape 🧩 — playing the loop itself

**Feel:** this track makes no notes. It performs on what the other tracks are playing: stutter, half-speed, drop-outs, and those moves are recorded and replay.

- **Limit:** there is no audio bus to capture, so effects work on *events and voices* (re-firing recent events, slowing the clock, muting, transposing). True reverse or scratching is not possible in this engine.
- The four `R2` punch-in effects already do most of this (`Synth.fxBeatRepeat`, `fxHalfSpeed`, duck, crush); they are just not recorded.
- **Cost:** a whole track slot out of four, for something `R2` gives for free today.
- **Verdict:** do not build it as an instrument. Instead consider making the `R2` punch-ins **recordable** into a small effects lane of their own (fits Phase G, Mix & FX). Revisit a full Tape instrument only if that lane proves too limiting.

---

## 5. Other ideas, shorter

| Idea | What it is | Verdict |
| :-- | :-- | :-- |
| **Push/Pull** | Each button plays one note on the press and a neighbour note on the release, like a concertina. Every tap is two notes; the hold length sets the rhythm between them | 🧩 a `RELEASE NOTE` row on Bass or Dial (off / step up / step down / chord tone). An evening to try |
| **Charge** | Holding a button builds up; the release fires. A longer hold gives a louder, brighter or longer swell | 🧩 natural for Pad's `X` swell (Phase E) and for risers. Not an instrument |
| **Garden** | Each face button plants a small self-playing pattern on the current chord; the D-pad sets density and register; you tend it rather than play it | 💤 distinct feel (the machine decides most), but overlaps Arp and Drums Variation. Revisit after F and H |
| **Shadow** | The instrument answers you: it replays your last phrase a moment later, transposed or upside down | 💤 wacky and cheap once notes are recorded; could be a row on any melodic instrument |
| **Stepper** | Buttons mean step up / step down / repeat / leap, relative to the last note | 💤 Dial's roll covers the same ground with a better feel |
| **Riff** | Record a short motif, then replay it from any degree | 💤 close to Arp; reconsider after Phase F |
| **Conductor drums** | Hold a pad to fill in a pattern; D-pad sets density and placement | 💤 fold into Drums `VARIATION` (Phase H) |
| **Vowel** | D-pad picks a vowel (ah, ee, oh…), buttons pick the chord tone: a choir that sings | 💤 really a patch family for Pad (brightness crossfade between vowel layers), not an instrument |
| **Slicer** | 4 pads × 8 directions = 32 slices of a sample | 💤 needs sample loading (Phase J) |

---

## 6. Shared engine work

Small pieces that several ideas need. None is required by the roadmap, so each is built with the first prototype that needs it.

| Piece | Needed by | Size |
| :-- | :-- | :-- |
| Held notes released by the instrument (`manual` handles) | Dial | S |
| Face fingering with a settle window (`input.lua`) | Dial, Hand Drums diagonals | S |
| D-pad history buffer (`input.lua`) | Motions | S |
| Several voices from one event (strum) | Pick; also the harp's strum (Phase D) | S–M |
| Bends without a degree, keyframe thinning | Slide | S |
| Erase for actions that are not face buttons | Pick, Hand Drums `SPLIT`, Dial | S, but needs a gesture ❓ |
| Clock-placed sub-notes for pitched voices | Motions; Lead/Arp (Phase F) | M |
| `harmony.lua` | Map, every `FOLLOW` row (Phase D) | roadmap |

---

## 7. How the lab works

1. **Prototype rough.** A lab instrument is one file in `src/instruments/` with `lab = true`, a plain stage view (labels only) and one patch. No polish until it has earned a slot.
2. **Hidden by default.** Lab instruments appear in the Track page swap list only when a `LAB` switch in `config.lua` is on, so the normal list stays short. With `LEFT/RIGHT` stepping through the catalog one at a time, the main library should stay at about six.
3. **Saves must survive a deleted experiment.** Today an unknown instrument id falls back to Drums (`Instruments:getDefinition`), which would play a deleted experiment's notes as drum hits. Phase C2 should load a track with an unknown instrument as an empty track of the default instrument instead.
4. **Tests as usual.** Each prototype gets a test file for its input → events mapping; the feel is judged on the device.
5. **Earning a slot.** An instrument moves to the roadmap when all of these hold:
   - it plays something the existing instruments cannot;
   - it is learnable in two minutes without reading the screen;
   - it still makes sense with any patch from the shared pool;
   - a recorded take replays as it was played;
   - you want to pick it up again a week later.

---

## 8. Recommended order

**First wave** (no dependency on later phases; can be tried between roadmap phases):

1. **Hand Drums, `MIRROR` only.** The cheapest test, with no format change.
2. **Dial button test**, then **Dial** if the pairs are reliable on the device.
3. **Pick.** The most different from everything built so far.
4. **Slide.** Cheap, and it answers the hardware slider question.

**Second wave:**

5. **Map**, after Phase D (needs Harmony).
6. **Motions** as an `ORNAMENTS` row, after Phase F (needs clock-placed notes).
7. **Recordable punch-ins** in Phase G, in place of Tape.

**Effect on the roadmap:** nothing changes yet. Two things to decide when the time comes:

- ❓ **Phase F:** Bass and Lead are the same way of playing (the spec calls them "same class"). Consider one mono instrument where bass and lead are a patch and a register, with **Arp** as the separate instrument. That frees a library place for a lab winner.
- ❓ **Library size:** with four slots, more than about six instruments mostly adds stepping. If two lab instruments win, something leaves or becomes a row on another instrument.

---

## 9. Open questions

1. Do neighbouring face-button pairs register reliably on the RG35XX? (Dial lives or dies on this.)
2. Pick: face-button string map; octave on a row or a button; the erase gesture.
3. Dial: is the octave seam natural? What should erase mean?
4. Hand Drums: mirror direction; its own instrument or a `HANDS` row on Drums; rows for 8 pads.
5. Slide: default `SNAP` strength; keyframe density.
6. Map: in-key only, or is `FREE` roaming worth its complexity?
7. Motions: which ornaments survive a playtest without false triggers?
8. Should the `R2` punch-ins become recordable (Phase G)?
9. Merge Bass and Lead into one mono instrument and make Arp its own (Phase F)?
