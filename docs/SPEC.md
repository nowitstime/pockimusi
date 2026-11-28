# Pockimusi — Design & Technical Specification

**Name:** Pockimusi (*POCK-ee-MOO-see*: pocket + music). Written **Pockimusi** in prose, **POCKIMUSI** on screen, `pockimusi` for ids. The app was first called PocketGroove; the code, launcher (`PocketGroove.sh`), `.love` file, `pocketgroove/` folder and save folder still use that name for now.

**Target hardware:** Anbernic RG35XX Plus (Allwinner H700, ARM64 Linux, 1 GB RAM, 640×480 4:3 IPS, no touchscreen, **no analog sticks**)
**Engine:** LÖVE 11.5 via PortMaster (`gptokeyb` fallback), desktop PC for development
**Architecture:** headless domain engine (Input, Looper, Harmony, Synth, Instruments, Theory) + a 640×480 vector view (Chrome)

Companion: [ROADMAP.md](ROADMAP.md) says *in what order* this gets built.

> **Status legend:** ✅ implemented · 🔧 implemented but changing · 📐 designed, not built · ❓ open question

---

## 1. Design philosophy

1. **Playable without looking.** Every button has one clear job. Depth comes from *combining* simple controls, not from adding features to each control. The screen confirms what you did; it should not be required to do it.
2. **Same grammar on every track.** A button's *role* is the same on every instrument (§3). Learn it once.
3. **Zero-setup jamming.** The master loop is always rolling. Recording is a gesture, not a menu.
4. **Instrument ≠ sound.** An instrument is *how you play*. A sound is *what comes out*. They are chosen independently (§6).
5. **Four instrument tracks plus the song's chord lane, always visible.** The screen is sized for exactly four instrument tracks. Tracks are *slots*; the instrument in a slot can be swapped (§7). Four is a fixed design limit. Track C, the chord lane, sits outside the slots as a thin strip above them (§5.1). ✅
6. **Hard to play a wrong note.** Pitched instruments play scale degrees, and can follow track C's chords (§5).
7. **Look and feel together.** Each instrument pass includes its stage view in the shared visual template; the base look is set early and refined per instrument.
8. **Self-contained procedural audio.** All sounds are generated in RAM at boot. Optional `.wav` loading is a later milestone.

---

## 2. Hardware input abstraction ✅

All hardware maps to a virtual button table (`down`, `pressed`, `released`). Gamepad and keyboard are equivalent. On-device testing shows 8-way diagonals are reliable.

| Virtual | RG35XX Plus | SDL gamepad | Keyboard |
| :-- | :-- | :-- | :-- |
| `UP/DOWN/LEFT/RIGHT` | D-pad | `dp*` / left stick | `W S A D` |
| `B` (south) | bottom face | `a` | `J` / ↓ |
| `A` (east) | right face | `b` | `K` / → |
| `Y` (west) | left face | `x` | `U` / ← |
| `X` (north) | top face | `y` | `I` / ↑ |
| `L1` / `R1` | shoulders | `leftshoulder` / `rightshoulder` | `Q` / `E` |
| `L2` / `R2` | triggers | `triggerleft/right` axis, `leftstick/rightstick` | `Shift` / `Space` |
| `SELECT` | select | `back` | `Tab` |
| `START` | start | `start` | `Enter` |

---

## 3. Control grammar

### 3.1 Roles by physical zone ✅

| Zone | Role | Meaning |
| :-- | :-- | :-- |
| Right thumb `B A Y X` | **Trigger** | *What* plays and *when* |
| Left thumb D-pad | **Pitch / harmony / expression** | *Where* in pitch or harmony, or how hard the hit is |
| Shoulders `L1 R1` | **Register & density** | `L1` = lower / sparser, `R1` = higher / denser, both = a special "extra" |
| `L2` | **Record** | Latch or momentary (§4) |
| `R2` | **Performance** | Mutes and punch-in FX; with `L2` = erase |
| `SELECT` (hold) | **Track page = sound** | Sounds, settings, instrument and effects for the active track (§3.4) |
| `START` (hold) | **Transport = timing** | Tempo, key, scale, bars, and the active track's grid and swing (§3.5) |

**Rule:** a gesture may use at most two buttons plus the D-pad. No nested menus.

### 3.2 Instruments at a glance (target)

| Instrument | D-pad | `B A Y X` | `L1` | `R1` | `L1 + R1` |
| :-- | :-- | :-- | :-- | :-- | :-- |
| **Drums** ✅ | dynamics × articulation (§3.2a) | 4 pads | 1/4 repeat | 1/8 repeat | 1/16 repeat (1/12T on triplet grid) |
| **Chord Harp** ✅ | 9 chords (§3.3) | 4 strings of the chord | voicing −1 oct | voicing +1 oct | wide voicing |
| **Bass** ✅ | root on neutral + 8 directions (2–8, `↓` = 5th below) | articulations (§7.3) | oct −1 | oct +1 | — ❓ |
| **Pad** ✅ | brightness / movement | voicings + swell (§7.4) | oct −1 | oct +1 | — |
| **Lead / Arp** ✅ | as Bass; for arps, where the pattern starts | note + arp up / down / up-down (§7.5) | oct −1 | oct +1 | arp rate ×2 |

Grain is retired as an instrument; its textures are the **Pad's patches** (§7.4). ✅ Chord harp shoulders shift the voicing octave; chord colour is on the Track page (§3.3). ✅

### 3.2a Drums: the D-pad is two axes ✅

The D-pad modifies every hit while held. It is read as two independent axes so a slip into a diagonal still gives roughly what was meant; diagonals never have meanings of their own.

| Axis | ← / ↓ | → / ↑ |
| :-- | :-- | :-- |
| Vertical = **dynamics** | `DOWN` ghost (40 %, short) | `UP` accent (100 %, longer) |
| Horizontal = **articulation** | `LEFT` flam: grace note 28 ms before the hit | `RIGHT` ratchet: 3 hits inside one 1/16 (one triplet step on 1/12T) |

- Diagonals combine both axes (`UP+LEFT` = accented flam, `DOWN+RIGHT` = ghost ratchet).
- Flam and ratchet are stored on the event (`orn = "flam"`, `ratchet = 3`). On playback the flam's grace note fires just before the beat, so the main hit stays on the grid.
- Pad tuning moved off the D-pad (it was ±4 st) and will become a per-pad setting.
- **Note repeat (L1/R1)** is locked to the grid. A press within 45 ms of a tick plays at once and stands in for that tick, so it never doubles. A press further away waits for the next tick, and still plays there even if the pad is released first. Repeats follow the track's swing.
- **Choke:** closed hats cut a ringing open hat.
- **Display:** the face buttons stay unlabelled. The centre shows four lanes ordered like the button diamond (X, Y, A, B top to bottom), each with a mini diamond, the pad's sound and a step strip: bar height = dynamics, a tick before = flam, slivers = ratchet.

### 3.3 Chord map & colour

D-pad picks one of 9 chords from the current key: neutral = **I**, `↑` = **♭VI** (was a second I), `↖` ii, `↗` iii, `←` IV, `→` V, `↓` vi, `↙` ♭VII, `↘` iv (borrowed). ✅ (plan: [PHASE_D.md](PHASE_D.md))

- **Chord colour** (triad, 7th, 9th, sus4, add9) is a **Track page setting row** (§3.4), set once and left. ✅ Strings per colour: triad root-3rd-5th-8ve · 7th root-3rd-5th-7th · 9th root-3rd-7th-9th · sus4 root-4th-5th-8ve · add9 root-3rd-5th-9th. The 7th comes from the scale, so V7 is dominant (G7) and vi7 is minor (Am7).
- ❓ Momentary colour gesture for live variation. Decide after playtesting.

### 3.4 Track page = sound (hold `SELECT`) ✅ / 📐

The same layout on every instrument:

| Control | Job |
| :-- | :-- |
| `UP / DOWN` | Move the row cursor |
| `LEFT / RIGHT` | Previous / next value for the selected row; holding repeats. A press previews a sound at once; held scrolling previews once it settles ✅ |
| `L1 / R1` | Preview the previous / next instrument for this slot (§7); applied on `SELECT` release. The instruments are a carousel across the top of the page: the selected one in the centre, the rest a ring that fades towards the edges. The catalogue runs group by group (RHYTHM, BASS, CHORDS, TEXTURE, LEAD); each tab has a bar in its group's colour and a hairline marks where a group ends; the swap card is tinted in the group's colour and names the group ✅ (Phase L) |
| Face tap | Effect on / off: `X` tone, `Y` drive, `A` echo, `B` space. The cursor jumps to that effect's row ✅ |
| `SELECT` tap (< 0.25 s, no combo) | Next track 1 → 2 → 3 → 4 → C (the chord lane, §5.1) → 1 ✅ |

**Rows** are the place every per-track option lives, so a new option costs a row, not a button. ✅ today: drums have `KIT, X, Y, A, B` (the kit row swaps all four sounds; a pad row swaps one); other instruments have a single `PATCH` row. The cursor opens on the **last pad you hit**, so "hit the snare, hold SELECT, press RIGHT" swaps the snare.

**Setting rows** ✅ are added below the sound rows and drawn as hollow rings (sounds are stars); `LEFT / RIGHT` change their value, with no sound preview. Built so far: Harp `COLOUR`. Planned:

| Instrument | Sound rows | Setting rows |
| :-- | :-- | :-- |
| Drums | `KIT, X, Y, A, B` | `TUNE`, `LEVEL` (for the selected pad), `VARIATION` (§7.1) |
| Chord Harp | `PATCH` | `COLOUR`, `STRUM` speed |
| Bass | `PATCH` | `FOLLOW`, `GLIDE` time |
| Pad | `PATCH` | `FOLLOW`, `ATTACK`, `RELEASE` |
| Lead / Arp | `PATCH` | `FOLLOW`, `ARP RATE`, `ARP PATTERN` |

**Effect rows** ✅ follow every instrument's rows: `TONE`, `DRIVE`, `ECHO`, `SPACE`. `LEFT / RIGHT` changes the amount in 10 % steps; changing it switches the effect on, and 0 switches it off. The list wraps, so the effects are also a few presses `UP` from the top row.

**Row types** ✅ decide how a row is shown and changed:

| Type | Row carries | Shown as |
| :-- | :-- | :-- |
| List (sounds, kits, patches, colour, follow, glide, ...) | `items` (label, optional `group` and `full` name) and `index` | The **picker**: a shelf over the tape deck while the row is being changed |
| Number (`TUNE`, `LEVEL`, the four effects) | `amount` 0..1 | A bar in the row; no picker |

The picker shows group tabs when the list has groups (the 39 drum sounds: kick, snare, hat, ...), the current group's items as chips (a list without groups shows up to five around the current item), and a bottom line with the full name, a map of the whole list and the position. It closes 1.2 s after the last change, or when the cursor moves.

The list shows six rows at a time and scrolls with the cursor (marks show when there is more above or below). ✅ Timing settings (grid, swing) stay on the Transport page.

✅ **Safe instrument swap:** `L1 / R1` only previews the next instrument; it is applied when `SELECT` is released. While a swap is previewed a card with the new instrument's name takes the place of the rows, and the rows and effects wait. Applying stashes the old instrument, state and events on the undo stack, so **undo restores them** (one stack for takes and swaps, `L2 + R2 + LEFT`). Stepping back to the current instrument cancels. 📐 Same-class swaps (Bass ↔ Lead, both mono-melodic) keep events, because v2 events store degrees (§8).

### 3.5 Clock = timing (hold `START`) ✅

| Control | Job |
| :-- | :-- |
| `L1 / R1` | BPM −5 / +5 (60–240); held, it keeps stepping, faster after 1.5 s ✅ |
| `LEFT / RIGHT` | Key (root) |
| `UP / DOWN` | Scale (next / previous) |
| `B` | Bars 2 / 4 |
| `A` | Grid for the active track (1/4 → 1/8 → 1/16 → 1/12T → FREE) |
| `Y` + `UP / DOWN` | Swing for the active track, 50–75 % in 2 % steps |
| `X` | Metronome click on / off |
| `START` tap | Play / pause; double tap = reset playhead to 1.1 and silence everything still ringing (stuck notes, echo and reverb tails) |

The D-pad holds the musical choices (key, scale), the shoulders the tempo. BPM, key, scale and bars are global. Grid and swing belong to the active track and are drawn in its colour. 

✅ **Click and count-in:** `X` cycles click **off → on → count-in → on + count-in**. With count-in, a record *tap* arms recording instead of starting it: the beats are clicked and counted down in the top bar, and recording latches at the next bar line (the one after, if that is under two beats away), opening a 1/16 early so a note played a touch ahead still lands on beat 1. Tap again, or pause, to cancel. From a paused clock the count starts the clock one bar before the loop's start. Holding `L2` still punches in at once.

### 3.6 Other global combos ✅

| Combo | Action |
| :-- | :-- |
| `R2` + `B/A/Y/X` | Mute tracks 1/2/3/4 |
| `R2` + D-pad (hold) | Master punch-in FX: ↑ stutter, ↓ half-speed, ← low-pass sweep (a volume duck without EFX), → bitcrush |
| `SELECT + R2` | Mix page: `LEFT/RIGHT` track/master, `UP/DOWN` level, `B/A/Y/X` mutes, `L1/R1` master trim |
| `L2 + R2` + `B/A/Y/X` | Erase that pad/action on the active track |
| `L2 + R2` + `LEFT` or `L1` | Undo last take |
| `L2 + R2` + `START` | Clear active track |
| `L2 + R2 + SELECT` (hold ~1 s) | ✅ Fresh session: clear every track's notes and mutes, keep the setup; undoable (§10) |
| `SELECT + START` (hold 0.3 s) | ✅ Menu (§10.1). On the Clock page a quick `SELECT` tap still changes track |
| `SELECT + START` (quick tap) | ✅ Song mode: go to S (§10.2) |
| `R2 + L1 / R1` | ✅ Song mode: fade out / in, from any page (§10.2) |

🔧 Mix page level should change once per press (plus key repeat), not every frame.

---

## 4. Recording model ✅ / 📐

Hybrid **latch / momentary** on `L2` ✅:

- **Tap** `L2` (< 0.25 s, no other button used): toggle record on/off (latched).
- **Hold** `L2` (≥ 0.25 s): record only while held (momentary punch-in).
- Combos with `L2` never toggle the latch.
- The top bar always shows `REC LATCH` / `REC HOLD` / `PLAY`.

Changes:

- ✅ **Takes split per loop pass**: while recording, a new take starts every time a full loop has gone by since recording began, so undo removes one pass, not the whole session. A note held across that boundary stays one note.
- ✅ **Count-in** (§3.5).
- **Held notes** record their length and bends (§8); a note still held at the loop seam is handled cleanly.
- ❓ Replace vs overdub toggle. ❓ Auto-stop after one pass. Not built: both need a control and the Transport page has no free button.

---

## 5. Harmony: track C & chord-follow ✅ (details: [PHASE_D.md](PHASE_D.md), [PHASE_K.md](PHASE_K.md))

There is always a **current chord** at every point in the loop. **Track C (§5.1) is the only chord source**; a small `Harmony` module resolves it:

1. ✅ A live change played on track C without recording, or a progression being tried on its stamp wheel, wins for as long as it lasts.
2. ✅ Track C's chords: the most recent chord at that point of the lane (wrapping: before the lane's first chord, the last one carries over; a chord up to a 1/16 late still counts on the beat).
3. ✅ Otherwise the **tonic** (I of the current key and scale).

A Chord Harp's chords (recorded or live) are its own and steer nothing. So nothing depends on writing chords first: with track C empty, followers simply play in the key.

### 5.1 Track C: the chord lane ✅ (details: [PHASE_K.md](PHASE_K.md), code `src/instruments/lane.lua`)

- **What:** a silent built-in track outside the four slots (`Looper.tracks[Looper.LANE]`), reached with `SELECT` taps after track 4. No `PATCH`, no mute, no effects; always the chords.
- **Length:** `BARS` row, 2 / 4 / 8 / 16, independent of the loop. The looper counts loop passes (`Looper.pass`), so a lane longer than the loop plays a different part on each pass; a shorter one repeats. A double `START` tap returns to pass 1. A longer `BARS` repeats what is there; a shorter one drops the end (undoable).
- **The playhead is the cursor; `B` writes where it is heading.**

| Control | Clock running (live) | Clock stopped (writing it out) |
| :-- | :-- | :-- |
| D-pad | Which chord | Which chord (the outlined box under the playhead is where it goes) |
| `B` | Change at the next box (up to a 1/16 late counts for the box just begun). Recording: written; not recording: the followers play it for one box, nothing written | Write this box, step on |
| `L1` / `R1` tap | — | Step back / on a box (the chord carries on) |
| `A` held + D-pad | Colour the chord playing | Colour the chord behind the playhead |
| `Y` | Clear the box playing (hold: keep clearing each box reached) | Clear the box under the playhead (it doesn't move) |
| `X` held | The progression wheel: point at one to hear it on the other tracks; `L1` / `R1` flip the page; let go = picked, nothing written | The same |
| `X` tap | Stamp the picked progression from the box the playhead is on, no waiting | Stamp it from the playhead's box, step past it |

- **One box = one `GRID` unit:** 1/2, 1 (default), 2, 3 or 4 bars. `B` writes one box, a stamp puts one chord in each box, `Y` clears one box. Changing `GRID` moves no chords; the chart just redraws its boxes (the last box stops at the lane's end).
- **The same chord twice in a row joins into one** on the timeline, so a long chord is the same chord again, or a box stepped over. Lengths mix freely: pick the finest grid you need.
- Writing a box leaves the rest of the lane as it was: a chord that was sounding at the end of the box comes back there if more chords follow.
- Undo: stopped writes, stamps, colours and clears are one undo per press; recording live is one undo per pass of the lane.
- **Rows:** `BARS`, `GRID`, `PREVIEW` (`STRUM` / `STAB` / `OFF`: the chord plays softly as you write with the clock stopped), `SOUND` (the preview sound, default `HARP`), `COLOUR` (for new chords), `SPICE`.
- **Wheel:** page 1 POP, 50S, SAD POP, ROCK, JAZZ ii-V-I, ROYAL ROAD, MIXO, CANON; page 2 DESCEND, HEROIC, BITTERSWEET, BLUES 8.
- **FOLLOW:** a follower's `FOLLOW ON` row reads `ON - NO CHORDS YET` while nothing sets chords (it then plays as `OFF`); starting to record with `FOLLOW OFF` while chords are set warns.
- Saved with the session (settings and chords); a fresh session clears it.

**Followers** (Bass, Pad and Lead/Arp) have a **FOLLOW** setting row (Track page, default **on**):

- **On:** a note's stored *degree* (for the Pad: its voicing shape) is played relative to the chord at the note's start. Recording or changing chords later re-harmonises lines already recorded. A held bass note keeps its pitch through a chord change; a held **Pad** chord moves to the new chord, on the chord's own tick (§7.4).
- **Off:** the note's stored *absolute pitch* is played, exactly as recorded.

Live playing uses the same rule, so what you hear while playing is what replays.

Mapping (follow on): chord roots more than a tritone above the key root are played below it (V = G below C). Degree 1 = chord root, 3 = chord third, 5 = chord fifth, 7 = chord seventh, 8 = octave, L5 = fifth below. On diatonic chords, 2, 4 and 6 walk the key's scale from the chord root; on borrowed chords (♭VI, ♭VII, iv) they are +2, +5 and +8/+9 above the root. ❓ Tune after playtesting.

Clearing track C makes followers fall back to the tonic; nothing breaks.

---

## 6. Sounds: instruments vs sound pools

| | **Instrument** (controller) | **Sound** (voice) |
| :-- | :-- | :-- |
| Defines | button/D-pad mapping, stage view, event format | the audio that plays |
| Chosen on | Track page `LEFT/RIGHT` | Track page sound rows, `L1/R1` |

Two shared pools:

1. **One-shot pool** — drum hits, perc, FX. Any drum pad can hold any one-shot. ✅ 39-sound catalogue, sorted by category, and eleven kits (808 Classic, 909 House, Lo-Fi, Acoustic, Latin, Industrial, Funk Breaks, Jungle, Latin Breaks, Neuro, Liquid; a changed pad marks the kit with `*`). The acoustic sounds (funk snare, stick / half-open / pedal hats, acoustic ride and bell, toms, bongos, tambourine, sidestick, acoustic crash, reverse snare and cymbal) are built in the background after boot. Snares, hats and claps are rendered three times and played in turn; a soft hit is low-passed as well as quieter (with EFX). ✅ (Phase L)
2. **Pitched patch pool** ✅ — one catalogue (`src/synth/synths_bank.lua`) shared by Chord Harp, Bass, Pad and Lead/Arp. A patch has an *attack one-shot*, a *seamless loop*, or both (§9.2), and each instrument's `PATCH` row lists the whole pool with its own group first.

   | Group | Patches |
   | :-- | :-- |
   | `BASS` | `SAW`, `SUB`, `PLUCK`, `808`, `REESE`, `DNB SUB`, `NEURO`, `HOOVER` |
   | `LEAD` | `SQUARE`, `SAW`, `PLUCK`, `KEYS`, `SUPERSAW` |
   | `PAD` | `WARM`, `BELL`, `CHOIR`, `DRONE`, `STRINGS`, `ATMOS`, `VOX` |
   | `PLUCK` | `HARP`, `NYLON`, `RHODES`, `KALIMBA`, `STAB`, `SILENT` |
   | `ODD` | `SHEPARD`, `JUST`, `THROAT`, `WAVE`, `GONG`, `REVERSE`, `TALK`, `SWARM` |

   - **Restrictions come from what a patch has, not from who owns it.** The Pad needs a loop, so it skips the one-shot patches (`HARP`, `NYLON`, `KALIMBA`, `GONG`, `REVERSE`). `SILENT` is offered only to chord instruments (the Chord Harp): the chords still drive the followers. A patch without a bright layer plays on the Pad with the brightness control doing nothing.
   - **A patch says how it behaves** and instruments read that: `rings` (notes ring out by themselves and overlap) or `sustains` (a note lasts as long as it is held). Bass and Lead are mono on a sustaining patch and overlap on a ringing one. The Chord Harp, whose presses have no length, lets a ringing patch ring and holds a sustaining one for 0.35 s.
   - **Register belongs to the instrument.** A patch stores the octave its 0 semitones plays; the instrument's register (Bass C3, the others C4) moves any patch into its own octave.
   - **Voice count belongs to the instrument** (Bass 6, Lead 8, Harp 8, Pad 12); a patch's pools grow to what is asked.
   - **Generated on first use.** Only the eleven original patches are generated at boot; the others when first selected or loaded, so the boot time doesn't grow with the catalogue.
   - Adding a patch = one entry in the catalogue; every instrument that can play it lists it.

Goal: swapping the patch changes how the part sits with the drums **without changing how you play it**.

---

## 7. Instruments

Four slots, default **1 Drums · 2 Chord Harp · 3 Bass · 4 Pad**. One catalogue, in group order (`Instruments.ORDER`): RHYTHM Drums, Hand Drums, Breaks · BASS Bass, Roller, Wobble · CHORDS Chord Harp, Strum · TEXTURE Pad · LEAD Lead/Arp, Dial, Slide, Valves (§7.6, §7.7). There is no lab split any more; only test screens (FINGERS) sit behind `Config.DEV_TOOLS`. Each must be a *different way of playing*, not a different sound.

### 7.1 Drums ✅ / 📐

- ✅ 4 pads; D-pad dynamics × articulation (§3.2a); grid-locked repeat; hat choke; kits; swing; four-lane view.
- ✅ **`VARIATION`** row (`OFF` / `LIGHT` / `WILD`, details: [PHASE_H.md](PHASE_H.md)), applied on playback only, so the recorded pattern is never altered and `OFF` plays it exactly. `LIGHT`: each hit's level moves by up to ±12 %. `WILD`: ±22 %, about a third of the hits that aren't on a beat land up to 14 ms late, and **fills**: in the last beat of each bar an empty step has a 22 % chance of a ghost hit on a pad the pattern already uses (never a kick).
- ✅ **Chance hits:** a *ghost* hit recorded while `VARIATION` is not `OFF` is stored with `chance = 0.5` and sounds on about half the passes (always, with `VARIATION OFF`). A flam's grace note and hit share one roll. Chance hits are drawn hollow in the lanes.
- ✅ **Per-pad tune and level:** `TUNE` (±12 semitones) and `LEVEL` (10–120 %) rows act on the selected pad, which is the last pad hit or the last one whose sound was changed; the row labels name it. They apply when a hit sounds, so they also change hits already recorded.
- ❓ After playing: fill rate; whether `LIGHT` and `WILD` want different chances.

### 7.2 Chord Harp ✅ (details: [PHASE_D.md](PHASE_D.md))

- ✅ Chords on the D-pad (§3.3); each face button plucks one string of the chord (`B` root, `A`, `Y`, `X` top). One press, one note.
- ✅ Shoulders = voicing octave; both = wide voicing. Colour on the `COLOUR` row.
- ✅ Rows: `PATCH` (the sound pool, §6, starting on `HARP`; `SILENT` too), `COLOUR`, `FOLLOW` (off by default; on, it plays track C's chord instead of choosing).
- ✅ Every harp event stores its chord relative to the key (root offset, 3rd, 5th, 7th, suffix, numeral, colour, recording key); a key change transposes recorded notes and chords. The harp's chords are its own: track C sets the song's chords (§5).
- 📐 Strumming is planned as a separate instrument, with Lead/Arp (§7.5).

### 7.3 Bass 🔧 — *next instrument pass* (plan: [PHASE_B.md](PHASE_B.md))

- ✅ D-pad = scale degrees: neutral = **1** (the root, the easiest note to land on, and the chord root once chord-follow arrives), `↙` 2, `←` 3, `↖` 4, `↑` 5, `↗` 6, `→` 7, `↘` 8, and `↓` = **L5**, the 5th below the root (stored as degree −2). Root, low fifth and octave are all one move away. `L1/R1` = octave.
- ✅ **Held notes:** a note sounds while its button is held and releases on button-up (§9.2). `SAW`/`SUB` are mono (a new press ends the previous note, exactly at the new note's start); `PLUCK` notes overlap.
- ✅ Face buttons = articulations only: `B` hold, `A` legato (glides from the held note without a new attack, or from the last note), `Y` staccato (one step of the track's grid), `X` accent with vibrato. The old `Y` +octave and `X` +fifth shortcuts go: `R1` is the octave and degree 5 is on the D-pad.
- ✅ Moving the D-pad or shoulders while holding a note **glides** to the new pitch at the track's glide speed; recorded as `bend` keyframes and replayed. After letting go, the fading tail keeps following D-pad directions (not neutral), also recorded. Glide points show as ticks on the tape-deck ribbon.
- ✅ Rows: `PATCH` (the sound pool, §6, starting on `SAW`; ringing patches such as `PLUCK` overlap), `GLIDE` (fast / medium / slow), `FOLLOW` (on / off: degrees are played over the current chord, §5).

### 7.4 Pad ✅ (replaces Grain; details: [PHASE_E.md](PHASE_E.md))

- ✅ Each face button holds the current chord as a sustained voicing: `B` full (four notes, taking the harp's colour: 7th, 9th, sus4, add9), `A` open (root, fifth, octave), `Y` high (fifth, octave, third above), `X` swell (the full chord, attack 3× the `ATTACK` row and at least 1.2 s). Buttons layer. One press = one event with a length.
- ✅ `L1/R1` = octave, read at the press. With no harp chords the pad plays the key's I chord.
- ✅ `FOLLOW ON`: a held or recorded chord glides to each new chord as it arrives. `FOLLOW OFF`: a held chord stays put and playback uses the notes as recorded (moved with the key).
- ✅ D-pad = tone, and the values stay where they are left: `↑/↓` brightness (the level of the patch's bright layer), `←/→` movement (slow per-note pitch drift, the bright layer detuned and shimmering). Sweeps while holding are recorded as keyframes on the event and replayed.
- ✅ Rows: `PATCH` (the sound pool, §6, starting on `WARM`; patches with a loop only), `FOLLOW`, `ATTACK` (fast / medium / slow), `RELEASE` (short / medium / long).
- ✅ Stage view: the chord, the shape and octave, one glowing line per sounding note, `BRIGHT` and `MOVE` bars.
- ❓ After playing on the device: glide or re-attack on chord changes; values that spring back; `X` as a charge.

### 7.5 Lead / Arp ✅ (details: [PHASE_F.md](PHASE_F.md))

- ✅ Built on the Bass: the same D-pad degrees, event fields and follow rule, one octave higher. Not in the default slots: swap it in on the Track page.
- ✅ `B` = a held note; moving the D-pad or shoulders while holding glides it (recorded bends).
- ✅ `A` arp up, `Y` arp down, `X` up-down, running while held (the newest held button wins). The arp walks a ladder of notes over the current chord, set by `ARP PATTERN`; the D-pad degree is where the pattern starts (neutral = the root, `↑` = from the 5th), and can move while it runs. Every step reads the current chord.
- ✅ Steps fall on the clock's grid at `ARP RATE` with the track's swing. A press within 45 ms of a step plays at once and counts as that step; a press between steps starts on the next one. With the clock paused the arp keeps its own time.
- ✅ Each arp step is recorded as an ordinary note (degree, octave, pitch, 80 % of the step long) on the arp's own grid.
- ✅ `L1/R1` octave; `L1 + R1` = arp rate ×2 while held. Notes too high for the voices drop an octave.
- ✅ Rows: `PATCH` (the sound pool, §6, starting on `SQUARE`), `FOLLOW`, `ARP RATE` (1/8, 1/16, 1/8T), `ARP PATTERN` (`CHORD`, `CHORD 2 OCT`, `7TH`, `7TH 2 OCT`, `SCALE`).
- ✅ Bass ↔ Lead swaps keep the track's notes and grid (undoable like any swap).
- ✅ Follow lookahead is under half a 1/32 for the Lead (a 1/16 for the Bass), so the arp step before a chord change keeps the old chord.
- ❓ Arp latch; note length as a row; vibrato on long notes (decide in the Lead/Arp pass). Strumming is its own instrument, Strum (built in lab wave 1).

### 7.6 From lab wave 1 ✅ (design notes in [lab/](lab/README.md))

Ordinary instruments while the app is in testing; each gets a pass ([feedback/](feedback/README.md)). The part each plays and what it still needs: [MUSICAL_PARTS.md](MUSICAL_PARTS.md).

| Instrument | Part | Way of playing | Plan |
| :-- | :-- | :-- | :-- |
| Hand Drums | Rhythm | Two thumbs: the D-pad is four more pads; shoulders ghost / accent | [lab/HANDS.md](lab/HANDS.md) |
| Strum | Chords | Thumbs choose the notes silently; `R1` / `L1` strum down / up; both damp | [lab/STRUM.md](lab/STRUM.md) |
| Slide | Lead | The D-pad steers one pitch that stays where it's left | [lab/SLIDE.md](lab/SLIDE.md) |
| Dial | Lead | Roll the right thumb round eight positions to walk the scale | [lab/DIAL.md](lab/DIAL.md) |
| Valves | Lead | D-pad open note, face buttons valves, shoulders breath | [lab/VALVES.md](lab/VALVES.md) |

### 7.7 Phase L: electronic ✅ (details: [PHASE_L.md](PHASE_L.md))

| Instrument | Part | Way of playing | Feedback |
| :-- | :-- | :-- | :-- |
| Breaks | Rhythm | A famous break plays while a face button is held (`B` play in time, `A` stutter, `Y` reverse, `X` choke); the D-pad jumps to one of 8 slices at the next 1/8 line; `L1` / `R1` half / double time, both a snare roll into the bar line. Records the moves, so a take replays on another break or kit. Rows `BREAK`, `KIT` | [feedback/breaks.md](feedback/breaks.md) |
| Roller | Bass | Pitched note repeat: hold `B` 1/16, `A` 1/8, `Y` 1/8T, `X` 1/16 with accented off-beats; the D-pad and shoulders set the next repeat's note; both shoulders double the rate. Rows `PATCH` (`REESE`), `FOLLOW`, `LENGTH` | [feedback/roller.md](feedback/roller.md) |
| Wobble | Bass | `B` root, `Y` 3rd, `X` 5th, `A` octave of the chord; the D-pad sets how fast the tone (the patch's bright layer) moves, locked to the beat (`↓` closed); both shoulders open it fully. Only patches with a bright layer. Rows `PATCH` (`NEURO`), `SHAPE`, `DEPTH`, `GLIDE`, `FOLLOW` | [feedback/wobble.md](feedback/wobble.md) |

- **Pump** ✅: a `PUMP` row (`OFF` / `LIGHT` / `MEDIUM` / `HARD`) on every track that isn't a rhythm instrument, saved with the track. Any sound in the `KICK` category on another track ducks it at once and it curves back up; with no kick for two beats (clock running) it pumps on every beat. §9.3.
- The `.wav` render tool (`tools/render.py`) writes patches, drum sounds and breaks to `renders/` to listen to without the device.

### 7.8 Parked ideas

- Sample chop instrument (needs `.wav` loading; not planned).
- Separate Perc/FX instrument — superseded by Drums Variation.

---

## 8. Looper & events

### 8.1 Timing ✅ / 🔧

- Loop is **2 or 4 bars** of 4/4. Per-track quantize grid: `1/4`, `1/8`, `1/16`, `1/12T`, `FREE`. ✅
- Per-track **swing** ✅ applied at playback to odd 8ths/16ths (by the event's grid), so it can change after recording; live repeats follow it.
- ✅ **Clock from real time:** the playhead advances by the real time between frames (`love.timer.getTime()`), not the clamped frame `dt`, so frame drops never slow the tempo. A frame longer than 0.25 s fires none of its skipped events.
- ✅ **Integer ticks:** positions are stored as ticks at **480 PPQN** (2 bars = 3840 ticks; 4 bars = 7680; 1 tick ≈ 1.1 ms at 115 BPM). Grid steps: 1/4 = 480, 1/8 = 240, 1/16 = 120, 1/12T = 160; FREE rounds to 1 tick. Snapping, dedup, 2↔4 bar toggling, triplets and swing offsets are exact. `phase` remains a derived value for drawing.

### 8.2 Event format v2 🔧 (core ✅; `chance`, `bend`, `chordRef` come with their phases)

```lua
Event = {
  tick     = 960,          -- start position (480 PPQN) ✅
  len      = 240,          -- held length in ticks (0 = one-shot hit)
  grid     = 120,          -- grid step it was snapped to (for swing), nil = FREE ✅
  action   = "B",          -- which button
  vel      = 0.85,
  chance   = 0.5,          -- drums: probability of playing when VARIATION is on (absent = always)
  takeId   = 3,

  -- pitched instruments only
  degree   = 5,            -- D-pad degree (1..8)
  octave   = 0,            -- shoulder octave offset
  semis    = 7,            -- absolute pitch at record time (used when FOLLOW = off)
  chordRef = "V",          -- chord that was current at record time (display)
  bend     = { {dt = 60, degree = 6, octave = 0, semis = 9} },  -- pitch changes, ticks after start; ✅ format
                                         -- (keyframes after len = bends in the release tail)

  -- drums only
  soundId  = "kick_808",
  orn      = "flam", ratchet = 3, decay = 1.0,

  -- chord harp only
  chord    = { roman = "V", colour = "7" },
}
```

- ✅ Track-level fields (`instrumentId`, `trackSlot`) live on the track, not on each event.
- ✅ Continuous textures record **notes with length**, never a stream of grains. One held pad chord = one event. A note still held while recording is marked `open` and not played back until released.
- ✅ Playback: note-on at `tick` (+ swing), note-off at `tick + len` (wrapping across the loop seam), bend keyframes (📐) applied in between. The looper keeps a set of sounding notes per track and always releases them on mute, clear, erase, undo, 2↔4 bars, pause, re-record and instrument swap.
- ✅ Instrument API: `noteOn(ev, state, track, isPlayback)`, `noteOff(...)`, `grace(...)` (drum flam), optional `updateVoices(dt, state, track)` every frame; live input uses `play(ev)` for one-shots and `hold(ev)` for held notes, which release themselves when the button goes up or a page takes the controls.
- Saved files store events as-is plus a `version` field (§10).

---

## 9. Audio engine

### 9.1 Current ✅

- 44.1 kHz, 16-bit mono `SoundData` generated at boot; pools of cloned `Source`s for polyphony; voice stealing.
- Live FX: beat repeat, half-speed, low-pass sweep (§9.3), bitcrush-style pitch quantize.

### 9.2 Sustained voices ✅ (engine; instruments start using it in Phase B)

- Each sustaining patch is generated as an **attack layer** (one-shot) plus a **seamless loop layer** (whole number of cycles, so `setLooping(true)` is click-free).
- A voice = attack (optional) + loop sources with an envelope (attack / release, per note if asked) driven in `Synth:update` via `setVolume`; pitch and glide via `setPitch`. Voices route through the track's effects like one-shots do.
- API: `Synth:noteOn(patch, semis, vel, opts) → voice`, `voice:setPitch(semis)`, `voice:noteOff()`. One-shots keep using `Synth:trigger`.
- Pad patches have a second **bright** loop layer (upper harmonics) paired with the main one: its level is the voice's brightness; the voice's movement drifts the pitch (±9 cents), detunes the bright layer (7 cents) and makes it shimmer.
- A patch with no loop layer is a **one-shot voice**: the same voice object, alive as long as its one-shot, so instruments handle both kinds the same way. `noteOff` cuts it over the patch's release.
- `opts.register` moves a patch to the instrument's octave; `opts.voices` grows its pools. `Synth:preparePatch(id, voices)` generates a patch ahead of its first note.
- The patches are listed in §6. Loops must repeat exactly: whole harmonics of the fundamental, or of the whole loop (`SWARM`: three saws on harmonics 191 to 193 of a 96-period loop, a few cents apart). Attack one-shots may hold anything (noise, inharmonic partials, pitch sweeps; `NYLON` is a Karplus-Strong string). A patch steals its oldest voice when full. `Synth.bootTimes` / `log.txt` report the boot's generation cost.

### 9.3 Effects & mix

- ✅ Per-track and master volume.
- ✅ **Per-track FX** (set-and-forget, Track page): tone = low-pass filter on each voice; drive (distortion), echo and space (reverb) = per-track OpenAL EFX sends. Without EFX, drive falls back to a gain push. ❓ Check EFX support and CPU cost on the RG35XX.
- ✅ Swing per track (§8.1). ✅ Humanize = Drums `VARIATION` (§7.1).
- ✅ **Pump** (sidechain): per-track gain envelope restarted by any `KICK` sound on another track, applied in the same per-frame volume pass as the duck, for one-shot and sustained voices (`Synth:pumpGain`). §7.7.
- ✅ **Master low-pass** on `R2 + ←`: closes in about 0.2 s while held and opens on release, applied to every sounding source with the same filter as tone (the two multiply). Without EFX it falls back to the old volume duck.
- ✅ **Meters** are estimated from the sounding voices (each voice's gain and envelope, added per track as power), since LÖVE can't read the output. They fall at 2.5 per second with a peak mark held 0.8 s. Shown at the right of each tape-deck lane and beside each Mix page fader; the master's turns red above 0.9, where the sum is likely to clip.

---

## 10. Persistence ✅ (details: [PHASE_C.md](PHASE_C.md))

- **Autosave** after you touched something (≥ 10 s apart, at a moment with no buttons held, or after 30 s regardless), and on quit / focus loss: tempo, key, scale, bars, click, master volume, active track, and each track's instrument, settings, grid, swing, volume, mute, effects and events. Not saved: undo history, record latch, playhead.
- Files live in the port folder (`conf/love/pocketgroove/`, via `XDG_DATA_HOME` in `PocketGroove.sh`).
- Two alternating save slots with sequence numbers, so a power cut mid-write never loses the previous save. Plain Lua-style table text (`format = 1`, events v2), read back by a parser that never runs it as code; unreadable or newer files are ignored and the game still boots.
- **Fresh session:** hold `L2 + R2 + SELECT` for about 1 s. Clears every track's notes and mutes; keeps tempo, key, scale, instruments, sounds and effects. Undoable with `L2 + R2 + LEFT`.
- The song (song mode, §10.2) is saved in `song.txt`.

### 10.1 Menu and living pattern slots ✅ (`src/menu.lua`, `src/patterns.lua`, `src/ui/chrome/menu.lua`)

- **Open:** hold `SELECT + START` for 0.3 s (just past a tap). The music keeps playing; the instrument and record are blocked. Opening and closing both wait until every button is let go, so nothing leaks in or out.
- **Buttons:** `UP / DOWN` move, `B` choose, `LEFT / RIGHT` change a value, `A` back (closes from the top list), `START` close.
- **Items:** `GO TO PATTERN`, `COPY PATTERN`, `CLEAR PATTERN`, `SONG MODE` (on / off, §10.2), `FONTS` (the font set, live; same as `F8`, kept in `display.txt`).
- **A pattern is the whole session** (`Session.snapshot`): four tracks with instruments, sounds, effects, notes and mutes, track C, tempo, key, scale, loop length.
- **Living slots (Phase M):** the loop on screen always belongs to a slot (`Session.patternSlot`; a session without one takes the first empty slot) and the autosave writes that slot's file along with the session. There is no separate save: what you hear is what's in the slot.
  - **Go to** another slot: the loop on screen is kept in its slot first, so nothing is lost; no confirm. An empty slot starts a new pattern with the same instruments, sounds, tempo and key, and no notes.
  - **Copy** the loop on screen into another slot (the current pattern stays); over a full slot `B` asks and a second `B` copies.
  - **Clear** a slot (asks first). The slot on screen can't be cleared.
- **Slots A–H**, one file each (`pattern_a.txt` … `pattern_h.txt`, next to the autosaves): `{slot="A",saved=<os.time>,session={...}}`. The list shows each slot's tempo, key, when it was saved, its instruments and a **little tape deck** in a small inset frame. `NOW` marks the slot on screen.
- Later ❓: names, export the loop to `.wav`.

### 10.2 Song mode ✅ (details: [PHASE_M.md](PHASE_M.md), code `src/song.lua`, `src/ui/chrome/song.lua`)

Turn it on in the menu (`SONG MODE`, saved with the session). The instrument pages don't change; song mode adds one page (**S**), one strip and one red badge.

- **Reaching S:** in song mode a `SELECT` tap on any track goes back to S, and on S it goes to track C (the one track the face buttons don't reach); a quick `SELECT + START` tap also goes to S. Song mode off, `SELECT` cycles 1 → 2 → 3 → 4 → C as before.
- **S** is a page like the others in the song's aurora colour (`Config.COLORS.SONG`): the compass shows patterns A–H (lower case = empty, a number = its place in the queue, the playing one marked), the face diamond the four tracks, the middle NOW → NEXT, "in N beats", the bar progress and this pattern's chords.

| On S | Clock running | Clock stopped (writing) |
| :-- | :-- | :-- |
| Face alone | Go to that track (B 1, A 2, Y 3, X 4) | The same |
| D-pad held + `B` | Add that pattern to the queue (any order, repeats too: A, A, B, B, A; the one playing again = one more loop of it) | Write it into the step under the cursor, step on |
| D-pad held + `A` | Cut to it on the next beat | — |
| D-pad held + `Y` | Copy the playing pattern into it (asks over a full slot) | The same |
| D-pad held + `X` (hold) | Clear that slot | The same |
| `L1 / R1` | Fade out / in | Step cursor back / on |
| `R2` + face | Mute / unmute, landing on the next bar | That track in / out on the step |
| `L2` | Record the song (below) | — |
| `L2 + R2` + `B` / `X` | Take the last queued pattern out / empty the queue | The same |
| `START` | Tap: pause / carry on. Double tap: play the song from the top (anywhere in song mode) | The same |
| hold `SELECT` | The song's rows | The same |

- **Switching** never stops the clock: a queued pattern switches in at the loop end (or the next bar: `SWITCH ON` row), a cut on the next beat. The pattern left behind is kept in its slot; the next one brings its own tempo, key, scale and loop length; track C starts from its first bar. Turning song mode on reads every slot and prepares its sounds.
- **The song strip** replaces the chord strip in song mode: the patterns played before (darkened), the one playing widened to one chord box per bar with the sounding chord lit, then the queue (the next one dashed), past a fixed NOW line. While the song plays it shows the song's own steps.
- **Recording the song** works like a tape. `L2` on S starts it (an empty song on the next loop; an existing one plays from the top and records over it); `L2` anywhere stops it. While it rolls (red `SONG REC` badge, frame and playheads on every page) everything goes into the song as moves: pattern switches, mutes, live FX (`R2` + D-pad), fades, and notes played on any track as one-off takes (no second `L2`). Without the tape rolling, `L2` on a track records into the pattern playing, as always.
- **Overdub:** rolling over a song keeps what you don't touch. A kind of move you touch (a track's mutes, the FX, the fade) is replaced from then until you stop; notes add; a switch you make rewrites the rest of the song. `L2 + R2 + LEFT` on S undoes the last pass.
- **Playback:** steps switch on time with their start mutes; moves and takes come back. A switch you make during playback takes over (the song stops following). At the end: `STOP` or `LOOP` (row).
- **Song rows** (hold `SELECT` on S, the Track page's look): `STEP`, `PATTERN`, `LOOPS`, `1–4` `IN / OUT`, `DELETE` (asks), `AT THE END`, `SWITCH ON`, `FADE TIME` (1–8 bars), `CLEAR SONG` (asks).
- **Saved** in `song.txt` (steps with slot, start, length, start mutes, moves, takes), read with the safe parser and checked.
- Later ❓: a step's track borrowing another pattern's loop; 1-bar patterns; tempo ramps; `.wav` export of the song.

## 11. UI layout (640×480) 🔧

1. **Top bar:** active track + instrument, grid, bars, BPM, key/scale, current chord (📐), beat stars, mode badge.
2. **Center stage:** one fixed template — shoulder badges top, D-pad left, face buttons right, instrument display middle, hint strip bottom. Track, Clock and Mix draw over the stage.
3. **Chord strip** ✅ (y 359–373): track C's whole lane at once with its own playhead; a frame marks the part under this loop pass when the lane is longer than the loop; only the chord playing is lit; a live change shows dashed. Names and numerals up to 8 bars, names only at 16. The top bar shows `LANE` length in place of the grid on track C, and the lane bar (`5/8`) by the chord.
4. **Tape deck:** four tracks with name, grid, mute, event markers and a shared playhead. 📐 Hits as beads, held notes as ribbons with bend lines, chord names along the chord-source lane.

Principles: show mode in the same place always; hints for the held modifier only; colour-code tracks consistently and add shape cues so colour is never the only signal.

**Colour belongs to the instruments** 🔧. Decided in the November screenshot review: colour is for instrument identity only. Settings pages (Track, Clock, Mix, Live FX, Menu) are grouped and set apart by a non-colour treatment (frame, material, glow, scenery), not by page colours. The **PLATE** look, the default, does this: its settings pages draw in moon silver over the instrument's dimmed scenery. The other looks in the menu's `LOOK` row are test looks while the style is being worked out.

The older rule, **one colour per page**, is what the `CLASSIC` look still draws: while playing, the instrument's colour owns the stage; on a settings page the mode colour replaces it on the frame (with a soft glow), badge, footer, D-pad, face rings, shoulders and selection; the only track colour left is a small identity capsule. Its mode colours avoid the track colours:

| Page | Colour | Motif |
| :-- | :-- | :-- |
| Play | instrument colour | the instrument's own decorations |
| Recording | crimson `#FB7185` (frame, badge, footer, playhead only) | — |
| Track page (sound) | sakura pink `#F9A8D4` | constellation of rows, moon-phase effect gauges |
| Clock (timing) | solar gold `#FCD34D` | astrolabe: circle-of-fifths key ring with scale arc, grid ticks that show swing, loop hand |
| Mix / Live FX | moon silver `#DCE3F5` | — |
| Erase | crimson with a tinted frame | — |

**Names** ✅. Every page and instrument has one plain name, used the same in the top bar, footer, heading, tabs, mixer and tape deck. Flavour lives in the halos and colours, not the words. Short names are whole words (no abbreviations) and at most about 5 capitals, so they fit the mixer column and the tape deck header.

| Page | Opened by | Name on screen |
| :-- | :-- | :-- |
| Play | — | `PLAY` |
| Track | hold `SELECT` | `TRACK` |
| Clock | hold `START` | `CLOCK` |
| Mix | `SELECT + R2` | `MIX` |
| Erase | `L2 + R2` | `ERASE` |
| Fresh | from Erase | `FRESH` |
| Live FX | `R2` | `LIVE FX` |

| Instrument | Name | Short name (tabs, mixer, tape deck) |
| :-- | :-- | :-- |
| drums | DRUMS | DRUMS |
| hands | HAND DRUMS | HANDS |
| harp | CHORD HARP | HARP |
| bass | BASS | BASS |
| pad | PAD | PAD |
| lead | LEAD & ARP | LEAD |
| strum | STRUM | STRUM |
| slide | SLIDE | SLIDE |
| dial | DIAL | DIAL |
| valves | VALVES | VALVES |
| breaks | BREAKS | BRKS |
| roller | ROLLER | ROLL |
| wobble | WOBBLE | WOB |
| fingers (test screen) | FINGERS | FINGER |

Internally the Clock page is still the `TRANSPORT` mode and the Fresh page is `NEW`.

The tape deck dims while a settings page is open. The Pad has Grain's mint. Tracks are coloured by slot, so a Lead takes the colour of the slot it is put in.

**Fonts** ✅ (`src/ui/fonts.lua`). Each font set pairs a *text* face for the small labels with a *display* face for titles and the big readouts (note and chord names, BPM). All are free (SIL Open Font License), in `pocketgroove/assets/fonts/` with their licences. Each face is sized so its capitals match the built-in font's and nudged so they start on the same row, so changing the set never moves the layout.

| Set | Text | Display |
| :-- | :-- | :-- |
| NEON (default) | Chakra Petch SemiBold | Audiowide |
| STARLIGHT | Tomorrow SemiBold | Zen Dots |
| SOFT | Atkinson Hyperlegible Bold | Righteous |
| CLASSIC | LÖVE's built-in font | — |

**Desktop display** ✅ (`src/ui/display.lua`). The picture scales to fit any window: CRISP draws at the screen's resolution (fonts rebuilt at that size, text snapped to whole pixels), PIXEL enlarges a 640×480 picture with nearest-neighbour. High-DPI screens draw at their real pixels (Retina via `highdpi`, Windows scaling via `SetProcessDPIAware`); 4× MSAA smooths shape edges. Keys: `F8` font set, `F9` CRISP / PIXEL, `F11` fullscreen, all remembered in `display.txt`.

---

## 12. Code layout

```text
pockimusi/
 ├── SPEC.md  ROADMAP.md
 ├── PocketGroove.sh            # PortMaster launcher
 ├── build.py                   # packs pocketgroove/PocketGroove.love
 ├── tests/                     # Lua tests: python3 tests/run.py (needs `pip install lupa`) or luajit tests/run.lua
 └── pocketgroove/
      ├── main.lua  conf.lua  controls.gptk
      ├── assets/fonts/          # the font sets' faces and their licences (OFL)
      └── src/
           config.lua  theory.lua  input.lua  looper.lua  harmony.lua  modes.lua
           session.lua  autosave.lua  save.lua  menu.lua  patterns.lua  song.lua (song mode)
           instruments/{init,drums,harp,bass,pad,lead}.lua
           synth/{init,voice (📐),drums_bank,synths_bank}.lua
           ui/chrome.lua  ui/display.lua  ui/fonts.lua  ui/chrome/*.lua
```

Global modes and combos live in `modes.lua` (`Modes.current` is read by the UI); `main.lua` only wires the LÖVE callbacks.

---

## 13. Open questions

1. Chord Harp face buttons: strum down/up + strings, or keep 4 strings? (§7.2)
2. Neutral D-pad on the harp: tonic, or keep last chord? (§3.3)
3. Bass face-button articulations — confirm after playtest. (§7.3)
4. Chord-follow degree mapping details, especially on borrowed chords. (§5)
5. Drum chance hits: ghost + variation is built; is that the right gesture? (§7.1)
6. Per-pad tune and level: rows for the last pad hit are built; good enough mid-jam? (§7.1)
7. Arp latch? (§7.5)
8. Count-in: to the next bar line (built) or a fixed four beats? (§3.5)
9. Replace vs overdub; auto-stop after one pass. (§4)
10. EFX support and CPU cost on the RG35XX. (§9.3)
11. What exactly is a "song"? (§10)
