# Phase L · Electronic — Working Plan

Part of [ROADMAP.md](ROADMAP.md). Background: the brainstorm on jungle, drum and bass and EDM (November 2026). Design: SPEC §6 (sounds), §7 (instruments), §9 (audio engine). Ideas not taken up here stay in [FUTURE_INSTRUMENTS.md](FUTURE_INSTRUMENTS.md) §5.

**Goal:** Pockimusi can make convincing jungle, drum and bass and EDM. That needs sidechain pump, tempos up to 240, the sounds those styles are built from (acoustic break kits, Reese and sub basses, stabs, atmospheres), and three new ways of playing: **Roller** (pitched note repeat), **Breaks** (rearranging a famous break while it plays) and **Wobble** (the D-pad sets how the tone moves in time).

**North star:** the cheap steps come first and improve the instruments that already exist. A new instrument comes only after the sounds it needs.

**Rule for every step:** one step = one or a few commits, app playable, tests green. 📱 = check on the RG35XX.

---

## Decisions

| Topic | Decision | Why |
| :-- | :-- | :-- |
| Lab | **The lab distinction goes.** The whole app is in testing, so every instrument is an ordinary instrument. Only test tools (FINGERS) stay behind a switch | One catalogue, nothing hidden |
| Library size | Grow it, and **group it**: each instrument belongs to a part, and the swap card and tabs show the part's name and colour | 13 instruments are fine to step through if you can see where you are |
| Groups | **RHYTHM** · **BASS** · **CHORDS** · **TEXTURE** · **LEAD**, the parts in [MUSICAL_PARTS.md](MUSICAL_PARTS.md) §1 | Groups by the job in the song, not by how it is played |
| New instruments | **Roller**, **Breaks**, **Wobble** (Wobble only if the filter test passes on the device) | They are the three ideas nothing else can play |
| Not instruments | Echo → a row on melodic instruments; Gate → a row on Pad; risers → recordable `R2` effects; Euclid, Cycle → [FUTURE_INSTRUMENTS.md](FUTURE_INSTRUMENTS.md) | They play like something that already exists |
| Tempo | **60–240 BPM** | Real double time (footwork, hardcore, jungle at 180+). Nothing in the code needs 180 |
| Pump | A **`PUMP` row** on every pitched track. **Any sound in the `KICK` category** on any track triggers it; with no kick it pumps on every beat | No set-up: it always just listens for the kick |
| Break names | **The real names** (AMEN, THINK, APACHE...) | We transcribe the rhythm and play it on our own synthesised sounds; no recording is used. Naming a pattern after the record it comes from is common practice. Fall back to style labels (JUNGLE 1, FUNK 2) if that ever changes, e.g. before selling the app |
| Breaks recording | Records **your moves** (which slice, when, how), not the drum hits | Changing `BREAK` or `KIT` afterwards re-plays the same performance on another break or kit |

### Groups and colours

| Group | Instruments | Colour ❓ |
| :-- | :-- | :-- |
| RHYTHM | Drums, Hand Drums, **Breaks** | warm orange |
| BASS | Bass, **Roller**, **Wobble** | deep violet |
| CHORDS | Chord Harp, Strum | gold (track C's colour) |
| TEXTURE | Pad | teal |
| LEAD | Lead / Arp, Dial, Slide, Valves | pink |

- Roller can play any register, but it opens on a bass patch, so it sits in BASS.
- ❓ Colours are picked on the device against the slot colours. The group colour appears only on the swap card and the tab carousel: the one-colour-per-page rule (SPEC §11) still holds on every other page.

---

## L0 · The lab goes

- [ ] One catalogue: `LIBRARY` and `LAB_IDS` become one list, **ordered by group** (above). The rule "an instrument is added by adding its file" stays
- [ ] `Config.LAB` → `Config.DEV_TOOLS` and covers only test screens (FINGERS)
- [ ] Docs: the ROADMAP's "Lab wave 1" becomes an ordinary section; `lab/` stays as each instrument's design notes (renamed in the docs as "design notes", not "the lab"); FUTURE_INSTRUMENTS stays the ideas file
- [ ] Tests: `test_lab.lua` checks the single catalogue and the order

## L1 · Groups on the swap card

- [ ] Each instrument declares `group = "RHYTHM"` etc.
- [ ] The swap card shows the group name above the instrument name (`RHYTHM · BREAKS`), and the card is tinted in the group's colour
- [ ] The tab carousel: a small group-colour mark under each tab, and a gap where one group ends and the next begins
- [ ] 📱 Colours against the four slot colours, legibility of the group name

## L2 · Tempo up to 240

- [ ] `MAX_BPM = 240`; saves load the new range
- [ ] Hold `UP / DOWN` on the Transport page to keep stepping, faster the longer it is held
- [ ] 📱 At 240: drum ratchets, note repeat at 1/16, Lead's arp at rate ×2 (1/32 notes at 31 ms, close to two frames). If they wobble, cap the fastest rates rather than the tempo

## L3 · Pump

- [ ] A kick fired on any track (live or playback; the sound's category is `KICK`) restarts a **per-track pump envelope**: a fast drop, then a curved recovery
- [ ] `PUMP` row on every pitched instrument: `OFF` / `LIGHT` / `MEDIUM` / `HARD` (depth and recovery time). Default `OFF`
- [ ] No kick in the loop: pump on every beat (the "fake sidechain"), so a breakdown still breathes
- [ ] The kick's own track never pumps; the duck from `R2 + ←` still works on top
- [ ] The envelope is applied in the same per-frame volume pass as `duckEnvelope` (`synth/init.lua`), for held and one-shot voices
- [ ] Tests: a kick event starts the envelope on the other tracks only; the fallback follows the beat
- [ ] 📱 Does `MEDIUM` sound like drum and bass, `HARD` like EDM? Clicks on fast recovery?

## L4 · Electronic patches + filter test

- [ ] **BASS:** `REESE` (detuned saws beating, looped the way `SWARM` is), `DNB SUB` (pure sine with a fast click, nothing soft at the start), `NEURO` (FM growl with a vowel-like bright layer), `HOOVER` (detuned pulse with a pitch dip on the attack)
- [ ] **LEAD / PLUCK:** `RAVE STAB` (organ / house piano, one-hit chords), `SUPERSAW` (a lead `SWARM`, brighter, less sub)
- [ ] **PAD:** `ATMOS` (airy, noise in the bright layer), `VOX` (short, breathy "ah / oh")
- [ ] Listen before the device: render each patch to a `.wav` with a small tool in `tools/`
- [ ] 📱 **Wobble filter test:** a test screen (`DEV_TOOLS`) that changes the low-pass filter of 4–6 held voices every frame. Measure the frame rate. This decides L9

## L5 · Roller

**Feel:** pitched note repeat. Hold a button and the note fires again on every step; move the D-pad while it rolls and the next repeat takes the new note. Rolling drum and bass basslines, EDM 1/16 plucks, trance gates on a single note. The arp chooses notes for you; Roller leaves every note to your hand and keeps only the rhythm.

| Control | Job |
| :-- | :-- |
| D-pad | Degree, the same compass as Bass (neutral = root). Read at each repeat |
| `B` (held) | Roll in 1/16 |
| `A` (held) | Roll in 1/8 |
| `Y` (held) | Roll in 1/8 triplets |
| `X` (held) | Roll in 1/16 with the off-beats accented (the "rolling" drum and bass feel) |
| `L1 / R1` | Octave down / up (read at each repeat, so tapping a shoulder mid-roll jumps the octave) |
| `L1 + R1` | Double the rate while held |

- **Timing:** the same as the arp: a press within 45 ms of a step plays at once and counts as that step; a press between steps starts on the next. Swing applies. With the clock paused, Roller keeps its own time.
- **Recording:** each repeat is an ordinary note (degree, octave, pitch, length) on the roll's grid, as arp steps are. So it follows chords, Pump and everything else, and Bass ↔ Lead ↔ Roller swaps keep the notes.
- **Rows:** `PATCH` (opens on `REESE`, or `SAW` until L4 lands), `FOLLOW`, `LENGTH` (`SHORT` 30 % / `HALF` 50 % / `FULL` 90 % of a step), `PUMP`.
- **Mono or overlapping** comes from the patch, as on Bass.
- **Stage view:** the roll as a strip of beads at its rate, the current degree lit, accents taller.
- **Tests:** press → repeats on the grid; D-pad and shoulder changes land on the next repeat; double rate; recorded notes replay as played.
- [ ] L5a Instrument, input → events, rows
- [ ] L5b Stage view
- [ ] L5c Tests, then a feedback file `feedback/roller.md` with questions for the pass
- [ ] 📱 Can you play a rolling drum and bass line at 174 that changes notes in time? Is `X`'s accent pattern the right one?

## L6 · Drums sound real

Engine work that helps every kit, and that the breaks need.

- [ ] **Quiet hits sound darker:** hits below full velocity get a low-pass filter (`setFilter`) as well as lower volume, so ghost notes lose the crack like real ones. No EFX: volume only, as today
- [ ] **Variation between hits:** 2–3 slightly different versions of each snare and hat are made at startup; hits alternate between them
- [ ] **Hat choke group:** the hat pedal and half-open hat also cut a ringing open hat
- [ ] 📱 Boot time with the extra versions; ghosts against accents

## L7 · Acoustic drums and new kits

- [ ] **Sounds (12):** funk snare (crack, ~200 Hz ring, wire rattle, ~0.3 s), acoustic closed hat, half-open hat, hat pedal, acoustic ride, ride bell, high and low acoustic tom, high and low bongo, tambourine, sidestick, acoustic crash, reverse snare, reverse cymbal
- [ ] **Kits:** `FUNK BREAKS`, `JUNGLE` (tighter, higher snare and the reverse hits), `LATIN BREAKS` (bongos, toms, conga, tambourine), `NEURO` (hard snare with a noise tail, punchy short kick, metallic hats), `LIQUID` (soft snare, shaker, tambourine)
- [ ] Render a test pattern per kit to a `.wav` before the device
- [ ] 📱 Levels against the old kits; does `FUNK BREAKS` sound like a drummer?

## L8 · Breaks

**Feel:** a famous break plays itself and you rearrange it live: jump to a slice, stutter it, reverse it, cut it, drop it to half time. The machine decides what is in each slice; you decide the order and the edits.

| Control | Job |
| :-- | :-- |
| `B` (held) | The break plays from where it is. Let go = silence |
| D-pad | Neutral = carry on in order. A direction = jump to slice 1–8 (clockwise from `↑`) at the next slice line |
| `A` (held) | Stutter: repeat the current slice at the track's grid |
| `Y` (held) | Play the current slice backwards (its hits in reverse order) |
| `X` | Choke: cut everything at once, so the bass shows through |
| `L1 / R1` (held) | Half time / double time |
| `L1 + R1` (held) | Snare roll that speeds up to the next bar line (1/8 → 1/16 → 1/32): the build |

- **Break library** (`src/breaks.lua`): each break is one or two bars of ordinary drum hits (sound role, tick, velocity), cut into **8 equal slices**. Roles (`kick`, `snare`, `ghost`, `hat`, `hat_open`, `pedal`, `ride`, `crash`, `perc1`, `perc2`) are filled from the kit, so a break is not tied to 4 pads.
- **First breaks:** `TWO STEP` (the plain drum and bass beat, default), `AMEN`, `THINK`, `FUNKY DRUMMER`, `APACHE`, `HOT PANTS`, `COLD SWEAT`.
- **Recording:** your moves, as events under the face button that made them: start tick, length, slice, and flags (stutter, reverse, half / double, roll). Playback turns them into drum hits from the current break and kit, so `BREAK` and `KIT` can be changed afterwards. Erase per face button works unchanged.
- **Rows:** `BREAK`, `KIT` (opens on `FUNK BREAKS`, or `ACOUSTIC` until L7 lands), `SWING`. No `PUMP` row: this track's kicks drive everyone else's.
- **Pump:** the break's kicks are `KICK` sounds, so other tracks pump with it automatically.
- **Stage view:** the break's 8 slices as a ring (matching the D-pad), the playing slice lit, its hits as beads; stutter, reverse and half / double shown on the ring.
- **Later ❓:** real audio slicing (render each break to one buffer at startup and play slices from an offset, pitched up like an old sampler). That also brings back the parked Slicer idea without loading samples.
- [ ] L8a Break library + transcriptions, checked by rendering each break to a `.wav`
- [ ] L8b Instrument: play, jump, stutter, reverse, choke
- [ ] L8c Half / double time and the snare roll
- [ ] L8d Recording moves and re-playing them on another break or kit
- [ ] L8e Stage view
- [ ] L8f Tests, `feedback/breaks.md`
- [ ] 📱 Does the Amen sound like the Amen? Can you play a recognisable jungle chop in two minutes?

## L9 · Wobble (only if the L4 filter test passes)

**Feel:** neuro, dubstep and EDM basses. The right thumb holds notes; the D-pad sets **how fast the tone moves, locked to the beat**. Rocking between directions while holding makes the bass talk.

| Control | Job |
| :-- | :-- |
| D-pad | Wobble rate: `↑` 1/4, `↗` 1/8, `→` 1/16, `↘` 1/8T, `↓` closed (no wobble), `↙` 1/2, `←` 1 bar, `↖` 1/16T. Neutral keeps the last rate |
| `B` | Held note |
| `A` | Legato: glide from the held note |
| `Y` | One wobble per note (the "yoi") |
| `X` | The filter opens on each note, then closes |
| `L1 / R1` | Octave |

- **Engine:** per-voice low-pass (and the bright-layer level) moved every frame, timed by the clock. Rate changes are recorded as keyframes, like bends.
- **Rows:** `PATCH` (opens on `NEURO`), `SHAPE` (sine / saw / square / stepped), `DEPTH`, `FOLLOW`, `PUMP`.
- [ ] L9a Engine: clock-timed filter movement and its keyframes
- [ ] L9b Instrument and rows
- [ ] L9c Stage view, tests, `feedback/wobble.md`
- [ ] 📱 Frame rate with four wobbling voices; does it talk?

---

## After Phase L

- `ECHO` row on Bass, Lead, Strum and Roller: each note repeats on the grid, fading, and the D-pad sets what each repeat does (stay, climb, fall, octave). Real notes, so they follow chords
- `GATE` row on Pad: 8 chopped rhythms for held chords (trance gate, house stab, garage skip)
- Risers and drops as recordable `R2` effects (with Phase G's recordable punch-ins)
- Drums `FEEL` row: half time without changing the tempo
- Step input with the clock stopped (acid basslines), the way track C is written

## Open questions

1. Group colours (picked on the device).
2. Roller's `X`: which accent pattern is "the" rolling feel?
3. Breaks: 8 slices for every break, or 16 for two-bar breaks?
4. Wobble's D-pad map: are 8 rates too many to remember?
