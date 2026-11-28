# Pockimusi — Roadmap

Companion to [SPEC.md](SPEC.md). The spec says *what things should be*; this file says *in what order we build them* and what comes next. Playtest feedback and ideas that aren't scheduled yet (menu rework, song building, audio engine, hardware) are in [FUTURE_PLANS.md](FUTURE_PLANS.md).

Legend: `[x]` done · `[ ]` to do · ❓ needs a decision · 💤 parked

---

## Where we are

Played on the RG35XX Plus and a laptop with a controller throughout; every phase below has been played and listened to on the device (the checks just weren't logged one by one). Built so far:

- [x] 4-track looper, quantize grids, 2/4 bars, undo last take, per-pad/track erase
- [x] Record latch/hold on `L2`; Mix page on `SELECT + R2`; master punch-in FX; per-track + master volume
- [x] Drums pass 1: dynamics × articulation (flam, ratchet), grid-locked repeat, hat choke, six kits, four-lane view
- [x] Unified Track page = sound (rows, instrument, effects); four swappable per-track effect slots from ten OpenAL EFX effects
- [x] Transport = timing: tempo, key, scale, bars, per-track grid and swing, metronome click
- [x] Colour belongs to the instruments; settings pages set apart by the PLATE look (still being worked out); astrolabe and constellation designs
- [x] Thirteen instruments, track C (the chord lane) with chord-follow, pattern slots A–H and song mode (Phases A–M below)

## Decisions so far

| Topic | Decision |
| :-- | :-- |
| Tracks | **Four**, fixed. Instruments are swappable per slot |
| Instruments | Drums, Chord Harp, Bass, **Pad** (replaces Grain), **Lead/Arp**, from lab wave 1 **Hand Drums, Strum, Slide, Dial, Valves**, and from Phase L **Breaks, Roller, Wobble**: thirteen, one catalogue in group order (no lab split). Sample chop parked |
| Page roles | `SELECT` = sound (rows, instrument, effects); `START` = timing (tempo, key, scale, bars, grid, swing) |
| Settings space | New per-track options are **setting rows** on the Track page under the sound rows; `LEFT / RIGHT` change the value. A new option costs a row, not a button |
| Instrument swap | Preview with `LEFT/RIGHT`, apply on `SELECT` release, **undoable** |
| Harmony | **Chord-follow**: **track C** (the chord lane) is the only chord source, tonic fallback, per-track `FOLLOW` row. The Chord Track instrument is retired |
| Drums randomness | **Variation** row + **chance** hits, applied at playback |
| Notes | **Event format v2**: integer ticks, note length, degrees + absolute pitch, bends, chance |
| Audio | **Sustained voices** (attack + seamless loop layers) for all pitched patches |
| Workflow | **One instrument at a time**; each pass includes its stage visuals in the shared template |
| Look | Base look set early; refined per instrument, not finalised up front |
| Page colours | Colour belongs to the instruments; settings pages are set apart by a non-colour treatment (frame, material, glow), not page colours. The PLATE look is the default and still being worked out (SPEC §11) |
| Default slots | Today Drums · Chord Harp · Bass · Pad. Leaning: Drums · Bass · **Lead/Arp** · Pad (the Harp leaves the defaults until its revamp). Not changed in code yet |
| Saving | Autosave keeps the loop on screen; pattern slots A–H in the menu (`SELECT + START`); song mode (Phase M) |
| Latency | Fine on device. Revisit only if it gets worse |

---

## Order of work

| # | Phase | Why here |
| :-- | :-- | :-- |
| **A** | **Foundation** — fixes, setting rows + safe swap, tests, clock, event v2, sustained voices | Everything after depends on the note format and sustain. Small fixes ride along |
| **B** | **Bass pass** | Hardest test of v2: held notes, glide/bend, degrees. Proves the engine |
| **C** | **Autosave** | Format is now stable; stop losing jams |
| **D** | **Chord Harp pass + Harmony (chord-follow)** | Bass already stores degrees, so follow just switches on |
| **E** | **Pad** (replaces Grain) | Reuses sustained voices + Harmony; Grain textures become patches |
| **F** | **Lead / Arp** | Same class as Bass; arp needs the clock-locked scheduling from A |
| **G** | **Mix & FX finish** — master low-pass, meters, count-in, takes per pass | Most effects already exist |
| **H** | **Drums pass 2** — Variation, chance, per-pad tune/level | Pass 1 is done and plays fine; randomness and per-pad tune/level land once the mix tools (meters) exist |
| **K** | **Chord lane** — track C outside the four slots, longer than the loop, written live or with the clock stopped | The Chord Track showed the chord job doesn't need a slot; plan in [PHASE_K.md](phases/PHASE_K.md) |
| **I** | **Tape deck v2 & visual polish** | Ribbons/bends/chord lane need v2 data; final look across all stages |
| **L** | **Electronic** — no more lab split, grouped instrument picker, tempo to 240, Pump, electronic sounds and acoustic break kits, **Roller**, **Breaks**, **Wobble** | Jungle, drum and bass and EDM; plan in [PHASE_L.md](phases/PHASE_L.md) |
| **J** | **Patterns / song, `.wav` export, sample loading** | Later, once the jam loop is great |

Device play (feel, frame rate, boot time, EFX cost, legibility) happens throughout every phase; findings go straight into the working sessions and the [feedback/](feedback/README.md) files.

---

## Phase A · Foundation ✅ — details in [PHASE_A.md](phases/PHASE_A.md)

- [x] A1 Quick fixes + build script packs every file
- [x] A2 Real tests (characterise today's looper first) — `python3 tests/run.py`
- [x] A3 Modes module (move combo handling out of `main.lua`)
- [x] A4 Setting rows + safe instrument swap (first row: Harp `COLOUR`)
- [x] A5 Clock from real time + integer ticks (480 PPQN)
- [x] A6 Event format v2 + note-on/note-off playback (Grain = held notes)
- [x] A7 Sustained voice engine

## Phase B · Bass pass ✅ — details in [PHASE_B.md](phases/PHASE_B.md)

- [x] B1 Held-note handles: end early, record bends incl. the release tail (shared by Bass, Pad, Lead)
- [x] B2 Bass sounds: `SAW`, `SUB`, `PLUCK` patches + `PATCH` and `GLIDE` rows
- [x] B3 Held notes: `B` hold, `Y` staccato (one grid step), `X` accent + vibrato; mono (`PLUCK` overlaps)
- [x] B4 Legato `A`: glide without a new attack, live and on playback
- [x] B5 Bends: D-pad and shoulders while holding (and in the release tail) glide, record, replay
- [x] B6 Stage view (pitch trace, live scope, real face labels) + bend marks on the tape deck

## Phase C · Autosave ✅ — details in [PHASE_C.md](phases/PHASE_C.md)

- [x] C1 Save text: write a table, read it back with a parser that never runs code (`src/save.lua`)
- [x] C2 Session snapshot and restore (per-instrument settings, events, effects; every value checked)
- [x] C3 Autosave: two alternating slots, every 10 s if changed, on quit and focus loss; restore on boot
- [x] C4 Fresh session: hold `L2 + R2 + SELECT` (~1 s), clears notes only, undoable; saves in the port folder; log.txt fix

## Phase D · Chord Harp + chord-follow ✅ — details in [PHASE_D.md](phases/PHASE_D.md)

- [x] D1 Chord map (`↑` = ♭VI, neutral = I) and key-relative chord data on harp events
- [x] ~~D2 Strums~~ dropped: the harp keeps one note per button; strumming becomes its own instrument (see Phase F)
- [x] D3 `harmony.lua`: current chord at any tick (recorded chords, else live chord, else tonic)
- [x] D4 Bass `FOLLOW` (default on): live and playback notes and bends follow the chord
- [x] D5 Chord in the top bar and along the harp lane, bass follow capsule

## Phase E · Pad (replaces Grain) ✅ — details in [PHASE_E.md](phases/PHASE_E.md)

- [x] E1 Voice engine: bright layer, per-note attack and release, movement; patches `WARM`, `BELL`, `CHOIR`, `DRONE`
- [x] E2 Pad instrument: `B` full, `A` open, `Y` high, `X` swell; rows `PATCH`, `FOLLOW`, `ATTACK`, `RELEASE`; `grain.lua` removed, slot 4 = Pad, old Grain saves load as a Pad
- [x] E3 Follow: held and recorded chords move with the chord track; `FOLLOW OFF` keeps them as recorded
- [x] E4 D-pad ↑/↓ brightness, ←/→ movement, recorded as keyframes and replayed
- [x] E5 Stage view in the template

## Phase F · Lead / Arp ✅ — details in [PHASE_F.md](phases/PHASE_F.md)

- [x] F1 Lead on top of Bass: D-pad degree, `B` held note with glides; patches `SQUARE`, `SAW`, `PLUCK`; rows `PATCH`, `FOLLOW`, `ARP RATE`, `ARP PATTERN`
- [x] F2 Arp: `A` up, `Y` down, `X` up-down; locked to the clock and swing; rate 1/8, 1/16, 1/8T; `L1 + R1` = rate ×2; each step recorded as a note; follows the chords
- [x] F3 Bass ↔ Lead swaps keep events
- [x] F4 Stage view: arp ladder + pitch trace
- [x] Instrument colour: tracks are coloured by slot, nothing to add
- [ ] ❓ Arp latch (not built: hold only). Decide in the Lead/Arp pass
- [x] Strum: built as its own instrument in lab wave 1. The harp stays one note per button

## Phase G · Mix & FX finish ✅ — details in [PHASE_G.md](phases/PHASE_G.md)

- [x] G1 Real low-pass sweep for master `R2 + ←` (the tone filter; volume duck without EFX)
- [x] G2 Level meters from the sounding voices, in the Mix page (with peak marks and a red master) and the tape deck
- [x] G3 Count-in: Transport `X` cycles click off / on / count-in / both; a record tap counts in to the next bar line
- [x] G4 Record takes split per loop pass
- [ ] ❓ Replace vs overdub, auto-stop after one pass (not built: no free control). Still being considered

## Phase H · Drums pass 2 ✅ — details in [PHASE_H.md](phases/PHASE_H.md)

- [x] H1 Flam, ratchet and choke covered by tests (repeat already was)
- [x] H2 `VARIATION` row: `OFF` / `LIGHT` (level jitter) / `WILD` (more jitter, late off-beat hits, fills in each bar's last beat); playback only
- [x] H3 Chance hits: a ghost recorded with variation on plays on about half the passes; drawn hollow
- [x] H4 Per-pad `TUNE` and `LEVEL` rows for the last pad hit; the Track page list scrolls (5 rows shown)

## Sound pool ✅ — SPEC §6

- [x] One catalogue for all pitched instruments; each `PATCH` row lists it with the instrument's own group first, grouped in the picker
- [x] Restrictions by what a patch has (Pad: loop needed; `SILENT`: Chord Harp only); register and voice count come from the instrument
- [x] Chord Harp on the pool: `PATCH` row, saved with the session
- [x] Patches generated on first use (boot generates the original eleven)
- [x] New patches: `808`, `KEYS`, `STRINGS`, `NYLON`, `RHODES`, `KALIMBA`, `SILENT`
- [x] `ODD` group: `SHEPARD`, `JUST`, `THROAT`, `WAVE`, `GONG`, `REVERSE`, `TALK`, `SWARM`

## Phase K · Chord lane ✅ — details in [PHASE_K.md](phases/PHASE_K.md)

- [x] K1 The lane in the looper (bars, passes, save, Harmony reads it)
- [x] K2 Track C on the `SELECT` cycle, its play surface and rows
- [x] K3 The strip above the tape deck
- [x] K4 Running controls: next bar line, shoulder lengths, live vs recorded
- [x] K5 Stopped controls: write and step, take back, preview
- [x] K6 Stamp: hold `X` for the wheel, tap `X` to place
- [x] K7 Chord chart stage view
- [x] K8 `FOLLOW` text and warning (Harp chords still steer when track C is empty: see the Harp pass)
- [x] K9 SPEC and feedback updates

## Phase I · Tape deck v2 & visual polish

- [ ] Beads for hits, ribbons for held notes, bend lines, chord lane labels
- [ ] Readable at 4 bars (about 7 px per step)
- [ ] Hints only for the held modifier
- [ ] 💤 Learn-mode toggle: parked, no free button for it
- [ ] Shape cues besides colour; 12 px+ text (check the 9 px font on device); legibility pass
- [ ] Final pass on all five stage views

## Phase L · Electronic ✅ — details in [PHASE_L.md](phases/PHASE_L.md)

- [x] L0 The lab split goes: one catalogue ordered by group; `Config.LAB` → `Config.DEV_TOOLS` (test screens only)
- [x] L1 Groups (RHYTHM · BASS · CHORDS · TEXTURE · LEAD) with a name and colour on the swap card and tabs
- [x] L2 Tempo 60–240, hold to keep stepping
- [x] L3 `PUMP` row: any `KICK` sound ducks the other tracks; pumps on every beat with no kick
- [x] L4 Patches `REESE`, `DNB SUB`, `NEURO`, `HOOVER`, `STAB`, `SUPERSAW`, `ATMOS`, `VOX`; `tools/render.py` (the filter test was dropped: Wobble moves the bright layer)
- [x] L5 **Roller**: pitched note repeat
- [x] L6 Drums sound real: darker quiet hits, varied hits, wider hat choke
- [x] L7 Acoustic drums (12 sounds) and kits `FUNK BREAKS`, `JUNGLE`, `LATIN BREAKS`, `NEURO`, `LIQUID`
- [x] L8 **Breaks**: famous breaks rearranged live (Two Step, Amen, Think, Funky Drummer, Apache, Hot Pants, Cold Sweat)
- [x] L9 **Wobble**: face buttons hold chord notes, the D-pad sets the wobble rate

## Phase M · Song mode ✅ — details in [PHASE_M.md](phases/PHASE_M.md)

- [x] M0 Living slots: the loop on screen is always a slot and autosaves into it; menu GO TO / COPY TO / CLEAR
- [x] M1 Seamless switching: queue (several) or cut, tempo / key / bars per pattern, patches prepared up front
- [x] M2 Song mode + the S page: SELECT cycle and SELECT + START tap; face = go to track, D-pad + face = queue / cut / copy / clear; mutes on the bar; fades
- [x] M3 The song strip in place of the chord strip, with a focus zoom on the playing pattern
- [x] M4 Recording the song: L2 on S rolls the tape; switches, mutes, FX, fades and notes (as takes); overdub keeps what you don't touch
- [x] M5 Stopped S = writing grid; song rows on the Track page
- [x] M6 Docs, rebuilt `.love` (1-bar patterns and borrowed loops left for later)

## Phase J · Later

- [x] Menu on `SELECT + START` (hold 0.3 s): save / load pattern slots A–H, font set, song mode placeholder
- [x] Pattern slots A–H: each one a whole session (= a scene in FUTURE_PLANS §8.1), its own file
- [x] Song mode → built as Phase M (rough; the next song pass is the user's own)
- [ ] Export loop to `.wav`
- [ ] Optional `.wav` sample loading

---

## Lab wave 1 ✅ (built) — plans in [lab/](lab/README.md)

Five instruments built at the same time on a shared foundation. After the first playtest all five stay in as **ordinary instruments** (no `lab` flag; only the `FINGERS` test screen stays behind `Config.DEV_TOOLS`, which stays on for now).

- [x] L0 Foundation: lab switch, carousel tabs, views from data, erase map, held notes, fingering reader ([lab/L0_FOUNDATION.md](lab/L0_FOUNDATION.md))
- [x] Hand Drums · Strum · Slide · Dial · Valves built, tests green
- [x] First look on the device: Dial most fun, Hand Drums nice, Valves needs brass, Strum and Slide promising ([feedback/](feedback/README.md))

---

## Up next · Instrument passes

The whole app is in testing, so **every** instrument gets a pass, one at a time: play it, write the feedback in its file in [feedback/](feedback/README.md) (each file has the questions to answer for that instrument), refine it. Judge each by the part it plays: [MUSICAL_PARTS.md](MUSICAL_PARTS.md) lists what lead, chord, texture, rhythm and bass parts need and what each instrument covers today.

- [x] Chord source (MUSICAL_PARTS §7.4 #1): track C, the chord lane
- [ ] Remaining §7.4 questions, each decided in its instrument's pass: Dial slur vs re-strike, first shared expression piece
- [x] Pad latch: wanted, as part of the Pad revamp (the Pad needs the most work)
- [ ] Default slots: leaning Drums · Bass · Lead/Arp · Pad (see Decisions)
- [ ] Patch wave by part, brass first (MUSICAL_PARTS §7.3)
- [ ] A pass per instrument: Drums · Hand Drums · Breaks · Chord Harp (needs a full revamp) · Strum · Bass · Roller · Wobble · Pad (revamp) · Lead/Arp · Dial · Slide · Valves
- [x] Library size: thirteen is fine. Instruments may be upgraded or swapped out during the passes
- [ ] ❓ Group colours (PHASE_L): revisit after the visual work

---

## Immediate plan

1. **Cleanup** ✅: docs brought up to date with what is built and played; the rename to Pockimusi finished (window title, launcher, `.love`, folders, save folder with a one-time copy of old saves).
2. **Visual work** (the user's): settings-page styles (PLATE and its options), typography, ornament and animation. The test looks stay in the menu until then.
3. **Instrument passes**, one at a time (above), starting with the revamps: Pad, Chord Harp.
4. **Song mode pass** (the user's own): Phase M works but is rough.
5. Candidates after that: MIDI export (play on the device, finish the grid in a DAW), `.wav` export.
