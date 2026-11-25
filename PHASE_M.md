# Phase M · Song mode — Working Plan

Part of [ROADMAP.md](ROADMAP.md). Takes the "patterns / song" half of Phase J. Background: the song-mode brainstorm and eight rounds of mockups (November 2026), which replace the proposal in [FUTURE_PLANS.md](FUTURE_PLANS.md) §8. Builds on the pattern slots (SPEC §10.1) and track C (SPEC §5.1).

**Goal:** make a whole song out of the patterns you jam, by **performing** it: switch patterns, bring tracks in and out, ride the effects, fade, and play solos over the top. The song is a recording of those moves, not audio, so a pattern can still change afterwards.

**North star:** the instrument pages don't change. Song mode adds one page (**S**), one strip, and one red badge. Everything else is buttons you already know.

**Rule for every step:** one step = one or a few commits, app playable, tests green. 📱 = check on the RG35XX.

**Status:** M0–M6 built, tests green (554). Every 📱 check is still to do. Where the build differs from the plan below, see *What changed from the plan* at the end.

---

## Decisions

| Topic | Decision | Why |
| :-- | :-- | :-- |
| What a pattern is | The whole session, as today: four tracks (instruments, sounds, effects, notes, mutes), track C's chords, **tempo, key and scale**, loop length | Already what a slot holds. Each section of a song can have its own tempo and key |
| Slots | **Living slots.** What's on screen is always a slot ("pattern B") and autosaves into it. The menu's LOAD becomes **GO TO**, SAVE becomes **COPY TO**, plus **CLEAR**. No revert | One model in and out of song mode. Copy first if you want to keep a version |
| Turning it on | Menu → `SONG MODE: ON / OFF` | Off, the app is exactly as today |
| S page | A page like every other: compass on the left, face diamond on the right, display in the middle, hint strip, tape deck. Aurora is its colour, as red is the drums' | Visual consistency; the special look lives in the strip and the badge |
| Reaching S | `SELECT` taps cycle 1 → 2 → 3 → 4 → C → **S** → 1. From anywhere, a quick **`SELECT + START` tap** goes to S (holding still opens the menu) | S is reached like track C; the tap is the fast way home while performing |
| Face buttons on S | **Alone:** go to track 1–4 (B A Y X). **D-pad held + face:** act on the pattern pointed at: `B` queue (loop end), `A` cut (now), `Y` copy the playing pattern here, `X` held clear | The control grammar: the D-pad says where, the face buttons do it |
| Queue | **Several patterns can be queued**: each D-pad + `B` adds one to the end of the queue; `B` on one already queued takes it out | Line up C → D → B ahead, as Elektron and Pocket Operators allow |
| Mutes | `R2` + face, as on every page. In song mode a mute lands **on the next bar** | Build-ups without new controls |
| FX | `R2` + D-pad, as on every page | Same buttons, now recordable |
| Fades | `L1 / R1` on S; **`R2 + L1 / R1`** on any page | Fade while playing an instrument |
| Tape deck | **Unchanged on every page, S included.** Muted tracks go grey (notes still visible) | You play over notes, not over a song overview |
| Song strip | In song mode the **chord strip becomes the song strip**: one row, pattern blocks with their chords, a fixed NOW line, the past darkened, the next pattern dashed, END at the right. **Focus zoom:** the pattern playing widens to one chord box per bar | Shows what's coming and when the chord changes, in the space the chords already use |
| Different instruments | Each pattern has its own four slots. When it switches, the names on the face buttons, the tape deck and the top bar change; **slot colours stay** | Any patterns in any order |
| Recording: tape not rolling | `L2` on a track page records into **the pattern playing**, as today (it loops, and every step using that pattern gets it). Moves are live only | Working on the parts |
| Recording: tape rolling | **`L2` on S starts song recording** (red badge on every page). Everything you do goes into the song: switches, mutes, FX, fades **and any notes you play, as a one-off take** at that spot. **`L2` anywhere stops it** | One state, always visible; no second record button |
| Overdub | Recording over an existing song: **what you don't touch stays.** Notes add on top; a switch, mute or FX move you make replaces that kind from that moment on. Undo takes back the whole pass | Touch-to-replace, as DAW automation does |
| Stopped S | With the clock stopped, S becomes the **writing grid** (steps × C + four tracks), with track C's writing grammar | Live while running, a chart while stopped, exactly like track C |
| Song rows | Hold `SELECT` on S: the Track page with a SONG tab: rows for the step under the cursor (pattern, loops, each track own / borrowed / out) and for the whole song (at the end, switch on, fade time) | Every setting is a row (SPEC §3.4) |

### Defaults for the small open questions ❓

Each can change after playing it.

- **Tempo and key at a switch:** jump at the boundary, no ramp. The Clock page edits the playing pattern's tempo and key.
- **Cut:** switches on the next beat (not mid-beat), keeping the bar position where the new loop allows.
- **Song recording start:** on an empty song, recording starts at the next loop boundary and the playing pattern is step 1. On an existing song it starts where the song is (overdub).
- **`START` on S:** play the song from the top / stop. Elsewhere, unchanged.
- **At the end:** STOP (rows: STOP, LOOP, FADE OUT).
- **One song per session**, saved as `song.txt` beside the pattern files.
- **A song take after an instrument change:** it keeps the instrument it was played on.

---

## M0 · Living slots ✅

- [x] The loop on screen always belongs to a slot (`Session.patternSlot`); a session with none takes the first empty slot (A if all are full: ask)
- [x] Autosave also writes the current slot's file (same throttling as today)
- [x] Menu: `GO TO PATTERN` (no confirm: nothing is lost), `COPY TO PATTERN` (confirm when the target is full), `CLEAR PATTERN` (confirm)
- [x] Tests: switching slots keeps edits in both; copy; clear; an old save without `patternSlot`
- [ ] 📱 Write time of a pattern file during play (no hitch)

## M1 · Seamless switching ✅

- [x] `Patterns.switchTo(slot, when)`: replaces tracks, lane, tempo, key, scale and bars **without stopping the clock**; held notes released over their release, not cut
- [x] At the loop end (`queue`), or on the next beat (`cut`); a queue of several slots, played in order
- [x] A pattern with another loop length or tempo: the new loop starts on the boundary; track C starts from its first bar
- [x] Turning song mode on prepares every slot's patches up front (`Synth:preparePatch`), in the background with a progress note
- [x] Tests: queue order, boundary timing, tempo / bars change at the boundary, no double-fired events, held-note release
- [ ] 📱 Switch between patterns with different instruments: no stutter

## M2 · Song mode and the S page (live) ✅

- [x] Menu item `SONG MODE`; saved with the session
- [x] S in the `SELECT` cycle; `SELECT + START` tap → S (`Modes:resolve` tells a tap from the menu hold)
- [x] S page view: compass of patterns A–H (playing lit, queued dashed, empty dim), display (NOW → NEXT, "in N beats", then …, this pattern's chords and the next chord), face diamond of the four tracks (names and states), hint strip
- [x] Face alone → that track's page; D-pad held → the diamond relabels to QUEUE / CUT / COPY / CLEAR
- [x] Mutes on the next bar in song mode; a waiting mute shows dashed on the face button and the tape deck
- [x] Fades: `L1 / R1` on S, `R2 + L1 / R1` anywhere (master gain ramp; fade time from the song rows)
- [x] Top bar on every page: a small `SONG B` tag while song mode is on
- [x] Tests: cycle order, tap vs hold, face jump, queue / cut / copy / clear, quantised mutes, fades
- [ ] 📱 Legibility of the compass letters and the display at 640×480

## M3 · The song strip ✅

- [x] In song mode the chord strip draws the song: pattern blocks with chords, NOW line, past darkened, next dashed, END; focus zoom on the playing pattern
- [x] With no song recorded yet: the playing pattern and the queue
- [x] The tape deck: track names and slot colours follow the playing pattern; muted tracks grey with notes visible
- [x] Tests: strip layout maths (positions, zoom) on a few songs
- [ ] 📱 Strip readable at 14 px, chord boxes not too thin

## M4 · Recording the song ✅

- [x] Song data: `{ steps = { { slot, loops } ... }, moves = { { tick, kind, data } ... }, takes = { [track] = { events on the song timeline } } }` in `song.txt`, read with the same safe parser
- [x] `L2` on S starts the tape (count-in as today); the red badge on every page; `L2` anywhere stops it
- [x] Captured: switches (with loop counts), mutes, `R2` FX moves, fades, and notes played on any track (as takes; degrees, so they follow chords)
- [x] Playback: the song drives switches, mutes, FX and fades; takes play on top of the pattern's notes; a muted track silences its take
- [x] Overdub: touch-to-replace per kind; undo removes the whole pass
- [x] Takes on the tape deck: notes with a crimson outline
- [x] Tests: record → play back the same moves; overdub replaces only what was touched; undo; save → load
- [ ] 📱 A full song recorded and played back on the device

## M5 · Writing and fixing (stopped S, song rows) ✅

- [x] Clock stopped on S: the grid (steps × C + 1–4), cursor = the box under the playhead (dashed), with track C's grammar: D-pad picks the pattern, `B` writes it into the step and steps on, `L1 / R1` step back / on, `R2` + face track in / out on this step, `X` loops ×1 ×2 ×4, `Y` clear
- [x] Hold `SELECT` on S: SONG tab rows (step: pattern, loops, each track own / borrowed / out; song: at the end, switch on, fade time)
- [ ] Borrowed loops (later: see below): a step's track can play another pattern's loop for that slot
- [x] Tests: writing steps, borrowing, rows round-trip through save

## M6 · Finish ✅

- [ ] 1-bar patterns (later: see below)
- [x] First-run prompts: the toasts on turning song mode on, reaching S and pressing L2 there carry them
- [x] SPEC: new § for song mode; §10.1 slots → living slots; ROADMAP; FUTURE_PLANS §8 points here
- [x] Rebuild `PocketGroove.love`
- [ ] 📱 Every check above, plus frame rate with the strip and a full song

---

## Later (not in this phase)

- Export the song to `.wav` (needs audio engine v2, FUTURE_PLANS §9)
- Tempo ramps between patterns
- Several songs per session
- Redo only one kind of move (e.g. only the FX) without touching the rest

---

## What changed from the plan

- **Overdub "from that moment on"** means from the first touch until recording stops (DAW-style touch-and-latch): moves of a touched kind that the playhead reaches are dropped. Mutes count per track.
- **A switch you make during playback** (not recording) takes over: the song stops following and says so. While recording, it rewrites the rest of the song from there.
- **Song undo** is the song's own (one pass at a time, `L2 + R2 + LEFT` on S): a pattern switch clears the pattern undo stack, so the song keeps its own copy.
- **Live FX during playback:** the song's recorded FX play when `R2` isn't held; holding `R2` plays yours over them.
- **Fades** use `Synth.fadeGain`, on top of the master volume; turning song mode off resets it.
- **Notes into the song** reuse the instruments' recording path: `Input:isRecording()` is true while the tape rolls, and `Looper:recordEvent` hands the note to the song (`Looper.recordRedirect`).
- **The switch point** is one mechanism on the looper (`boundaryTick` / `boundaryHook`) that splits a frame exactly: queued and cut switches, mutes on the bar, the song's own steps and the armed recording start all use it.
- **Left for later:** borrowing another pattern's loop for one track (it would write borrowed notes into a living slot); 1-bar patterns (the Clock page's 2 ↔ 4 toggle, the save format and the top bar's beat marks all assume 2 or 4).
