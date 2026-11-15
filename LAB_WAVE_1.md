# Lab wave 1 · Five instruments to try — Working Plan

Part of [FUTURE_INSTRUMENTS.md](FUTURE_INSTRUMENTS.md) (the lab). Design background: that file's §2, §4 and §6; [SPEC.md](SPEC.md) §3.4 (Track page), §6 (sound pool).

**Goal:** five new ways of playing are in the app, rough but playable, so playing can decide which ones stay: **Hand Drums** (two thumbs), **Strum** (set the notes with the thumbs, pluck with the shoulders), **Slide** (steer the pitch), **Dial** (roll the thumb round the scale) and **Valves** (fingerings and breath, like a brass instrument). The Track page's instrument tabs change first, because nine names no longer fit in a row.

**Rule for every step:** one step = one or a few commits, app playable, tests green. 📱 = check on the RG35XX. Lab rule: no polish until an instrument has earned its slot (FUTURE_INSTRUMENTS §7).

---

## Decisions

### The lab itself

| Topic | Decision | Why |
| :-- | :-- | :-- |
| Which five | Hand Drums, Strum (the doc's "Pick"), Slide, Dial, Valves | The doc's first wave, none of which depends on a later phase, plus Valves, which the doc had set aside for needing 15 fingerings. This plan's version needs seven, all easy ones |
| What a thumb can press | From playing: **one** button and **two neighbouring** buttons are easy; **all four** (the thumb laid flat) is a little harder but fine; **three** is hard to control. So there are **nine fingerings to build on**: four singles, four neighbouring pairs, all four. Three-button fingerings are never required. Opposite pairs (`B + X`, `A + Y`) are not used until they have been tried | This replaces the doc's "not three or four at once" |
| Not in this wave | Map (bigger, and the Chord Harp already covers chords), Motions and Tape (the doc says: rows and layers, not instruments) | Keep the wave small enough to finish |
| `LAB` switch | `Config.LAB`, **on** for now. Lab instruments carry `lab = true`; with the switch off they leave the tabs | You are the only player while experimenting; the switch is there for a release |
| A save with a lab instrument, switch off | The track loads empty, on that slot's default instrument | Never play an experiment's notes as drum hits. Session load already falls back to the default instrument; L0 adds the test that the notes are dropped |
| Sounds | Each one takes the whole sound pool by declaring `HOME_GROUP`, `DEFAULT_PATCH`, `REGISTER`, `VOICES` | No sound work per instrument |
| Stage view | One shared **lab view**: the instrument's name, a large readout of what is sounding, and a legend of what each control does, from a table on the instrument | Labels only, as the lab rules say; a real view comes with a slot |
| Erase | An instrument may map each face button to the event actions it clears (`ERASE`), shown on the Erase page with its own labels | Strum's events belong to the shoulders, and `L2 + R2 + L1` is undo |

### Instrument tabs: a centred carousel

| Topic | Decision | Why |
| :-- | :-- | :-- |
| Layout | The selected instrument sits in the **centre** of the tab strip; the names slide under it when `L1 / R1` step | Your call. Works for any number of instruments |
| "Selected" | The previewed instrument while one is previewed, otherwise the track's own | The centre is always what `SELECT` release will give you |
| How many show | The centre and about two names each side (the strip is 216 px wide, between the `L1` and `R1` capsules); names fade out towards the edges | The fade says "there is more" without arrows |
| Ends | A **ring**: after the last instrument comes the first, on both sides | Stepping already wraps; the centre always has neighbours |
| The track's own instrument | Keeps its outline while another is previewed, if it is in view. The swap card still names it | You can see how far you have stepped from where you started |
| Lab instruments | A small dot over the name | Tell experiments from the library at a glance |
| Motion | The strip slides to its new place in about a tenth of a second, as the picker's highlight does | Shows the direction of the step |

### Hand Drums (`HANDS`) — two thumbs, eight contacts

| Topic | Decision | Why |
| :-- | :-- | :-- |
| What it is | Drums, with the D-pad as four more pads. Built on the Drums module, same kit rows, same event format | Cheapest experiment: lanes, erase, tape deck and saves work unchanged |
| `MIRROR` only | The D-pad plays the **same four sounds** as the face buttons; a D-pad hit is recorded under its face button | Rolls on one drum with two thumbs. `SPLIT` (eight sounds) waits: it needs more rows and an erase gesture |
| Which way | By position: `↑` = `X`, `↓` = `B`, `←` = `Y`, `→` = `A` (each direction is the button in the same place on the diamond) | Nothing to learn. The mirror-image variant is a one-line change to try |
| Diagonals | Play both pads | Two sounds with one thumb |
| Shoulders | `L1` ghost, `R1` accent, `L1 + R1` note repeat (as Drums) | The D-pad is busy; this is the `L1` = sparser, `R1` = denser habit |
| What it gives up | Flam and ratchet | They live on the D-pad on Drums |
| Swapping | Drums ↔ Hand Drums keeps the notes | Record on one, decorate on the other |

### Strum (`STRUM`) — fret with the thumbs, pluck with the fingers

| Topic | Decision | Why |
| :-- | :-- | :-- |
| D-pad | Degree, the Bass compass (neutral = root). **Silent** | Left thumb chooses |
| Face buttons, held | Add strings above the root, **silent**: `B` third, `A` fifth, `X` octave, `Y` seventh | Right thumb chooses the shape. None held = one note, so it is also a melody instrument |
| `R1` | Downstroke: the root and every held string, low to high | |
| `L1` | Upstroke: the same, high to low | Alternating the two gives tremolo and strumming one thumb can't play |
| Damp | The second shoulder landing within 35 ms of the first: everything ringing stops, and the stroke that just started is taken back | Both shoulders "together" arrive a frame apart. A wait before every stroke would make a rhythm instrument feel late, so the stroke plays at once and is withdrawn |
| The patch decides | A patch that **rings** is plucked: a stroke is a hit, notes ring over each other. A patch that **sustains** is bowed: it sounds while the shoulder is held and the D-pad glides it | The sound pool already says which is which (`rings` / `sustains`) |
| Spread | The strings of a stroke start one after another: `STRUM` row, `TIGHT` (12 ms apart) / `LOOSE` (30 ms) | That gap is what makes it a strum and not a chord |
| Event | One per stroke: `action` = `R1` / `L1`, `degree`, `octave`, `semis`, `stack` (scale steps above the root), `strum` (the spread, negative for an upstroke) | Stored as steps, so chord-follow can re-harmonise a recorded strum |
| Rows | `PATCH` (opens on `NYLON`), `REGISTER` (low / mid / high), `STRUM`, `FOLLOW` | The shoulders no longer shift the octave |
| Erase | `L2 + R2 + B` clears downstrokes, `+ A` clears upstrokes | |

### Slide (`SLIDE`) — the D-pad is speed, not position

| Topic | Decision | Why |
| :-- | :-- | :-- |
| D-pad `↑ / ↓` | The pitch rises / falls for as long as it is held, and stays where it is left | Steering, like a trombone or a fretless |
| D-pad `← / →` | Step to the previous / next scale note | A quick way back onto the scale |
| Face buttons | `B` note (sounds while held) · `A` note that settles on the nearest scale note when the D-pad is let go · `Y` dive (falls away on release) · `X` accent with vibrato | |
| Shoulders | `L1 / R1` octave; held while sliding = four times faster; both = back to the root | |
| Rows | `PATCH` (opens on `SQUARE`), `SPEED` (slow / medium / fast), `SNAP` (off / soft / hard) | `FOLLOW` waits until it has been played |
| Event | A held note plus bend keyframes with fractional pitch, one per 30 ticks at most | The Bass's bend recording already stores and replays this |
| Built on | The Bass module's voice, bend and trace code | Mono, glides, a pitch trace for the lab view: all there |

### Dial (`DIAL`) — the scale as a circle under the right thumb

| Topic | Decision | Why |
| :-- | :-- | :-- |
| Fingering screen | A lab screen that shows the fingering the app sees (one of nine) and counts how often each lands cleanly 📱 | Pairs are comfortable to press, so this is no longer a go / no-go. It is there to tune the settle window, for Dial and Valves both |
| Positions | Degrees 1 to 8 clockwise from `B`; rolling to a neighbour slurs; rolling across the seam carries the octave; D-pad `↑ / ↓` dynamics, `← / →` flat / sharp; `L1 / R1` octave. As FUTURE_INSTRUMENTS §4.2 | |
| Settle window | A change of fingering within 35 ms of a fresh press corrects the note; after that it is a slur | Two buttons meant together arrive a frame apart |
| All four | Free for now; a candidate for "back to the home octave" | Easy to press, and Dial has no use for it yet |
| Engine pieces | Held notes the instrument releases itself; a fingering reader in `input.lua` | Both small, both listed in the doc's §6 |

### Valves (`VALVE`) — fingerings and breath

| Topic | Decision | Why |
| :-- | :-- | :-- |
| The model | A brass instrument. The **left thumb** picks the open note (a bugle's notes), the **right thumb** lowers it with valves, an **index finger** blows. Nothing sounds without breath | Three jobs on three fingers: no other instrument splits the hands this way |
| D-pad: the open notes | The current chord's tones, absolute as on the Bass compass: neutral = root, `↓` fifth below, `←` third, `↑` fifth, `→` octave, diagonals the tones beyond. With the D-pad alone it plays bugle calls that always fit the chord | Brass open notes are a chord too. Chord-follow comes for free |
| Face buttons: the valves | Each fingering lowers the open note. The layout is a real four-valve fingering chart (the fourth valve stands in for first + third, as on a euphonium), and it happens to need only easy fingerings: |  |
| | none 0 · `A` −1 · `B` −2 · `A + B` −3 · `A + X` −4 · `Y` −5 · all four −6 | Six steps down fill the largest gap between open notes |
| What a step is | `VALVES` row: `SCALE` (a step = one scale note; default) / `CHROMATIC` (a step = one semitone, as on the real thing) | `SCALE` can't play a wrong note. `CHROMATIC` is the first instrument that can leave the key on purpose |
| `X` alone | −3, the same as `A + B` (a real alternate fingering) | Costs nothing and makes some runs easier |
| `R1` | Blow: the note sounds while it is held | |
| `L1` | Tongue: a second breath. Alternating `R1` and `L1` repeats a note fast (double-tonguing); `L1` is the softer of the two | The same alternating move as Strum |
| While blowing | Changing valves or the D-pad **slurs**: the note moves without a new attack. A valve change slurs quickly, an open-note change a little slower (a lip slur) | That is what makes it sound like brass and not like a keyboard |
| Settle window | As Dial: a fingering change within 35 ms of the breath corrects the note | |
| Patch | Any; opens on `SAW` (the closest to brass in the pool). A ringing patch gives a plucked version | |
| Rows | `PATCH`, `VALVES`, `REGISTER`, `FOLLOW` | The shoulders are the breath, so the octave is a row |
| Event | One per breath: `action` = `R1` / `L1`, the open note's chord tone, the valve steps, `semis`; slurs are bend keyframes that keep tone and steps, so a recorded line re-harmonises | |
| Erase | `L2 + R2 + B` clears `R1` breaths, `+ A` clears `L1` breaths (as Strum) | |
| Built on | The Bass module's voice, bend and trace code; Dial's fingering reader | |

---

## Order

| Step | What | Size |
| :-- | :-- | :-- |
| L0 | `LAB` switch, lab view, `ERASE` map, test for saves with a missing instrument | S |
| L1 | Instrument tabs as a centred carousel 📱 | S |
| L2 | Hand Drums (`MIRROR`) | S |
| L3 | Strum: strokes, strings, damp, pluck / bow by patch, strum playback | M |
| L4 | Fingering reader in `input.lua` and its lab screen 📱 | S |
| L5 | Slide | S–M |
| L6 | Dial | M |
| L7 | Valves | M |

L1 comes before any instrument, so each new one has a tab to appear in. The fingering reader goes before Dial and Valves, which both stand on it.

## Tests

- L0: with `LAB` off the catalogue is the five library instruments and stepping skips the rest; a save holding a lab instrument loads as an empty track on the default instrument; an `ERASE` map clears the mapped actions and nothing else.
- L1: the centred tab is the previewed instrument, else the track's own; stepping past either end wraps; every instrument can be reached with `L1` alone and with `R1` alone; drawing works with 5 and with 9 instruments.
- L2: `↑ ↓ ← →` play and record under `X B Y A`; a diagonal makes two hits; `L1` = ghost level, `R1` = accent level, both = repeat; Drums ↔ Hand Drums keeps the notes; the erase and lane code see only face actions.
- L3: no face button = one note at the D-pad's degree; held buttons add their steps; `R1` orders low to high and `L1` high to low, the right spread apart; a second shoulder inside 35 ms damps and removes the stroke; a ringing patch records a hit, a sustaining patch records a length and glides; playback over a changed chord moves the whole stack; rows save and load.
- L4: the fingering reader reports the nine fingerings; opposite pairs and three buttons are reported as such, so an instrument can ignore them; a pair arriving one frame apart reads as the pair once settled, and four arriving over three frames read as four.
- L5: holding `↑` raises the pitch at the row's speed and it stays on release; `← / →` land on scale notes; `A` settles on the nearest scale note; a slide records at most one keyframe per 30 ticks and replays the same curve; both shoulders return to the root.
- L6: the eight positions give degrees 1 to 8; a roll is a slur (one event, bends); the seam moves the octave by one per lap and keeps the pitch; a correction inside the settle window rewrites the note instead of slurring.
- L7: nothing sounds without a shoulder; each D-pad direction gives its chord tone and moves with the chord; each fingering lowers by its steps, in scale notes and in semitones; three-button and opposite fingerings change nothing; a valve or D-pad change while blowing is a slur on the same voice; `L1` after `R1` re-attacks the same pitch; a recorded line replays, and re-harmonises with `FOLLOW` on.

## Playtests (what decides a slot)

| Instrument | Question |
| :-- | :-- |
| Hand Drums | A clean 1/16 single-stroke roll at 120 BPM? Do you miss flam and ratchet? |
| Strum | Steady alternate-picked 1/16 notes at 120 BPM for two bars? Is the bow worth keeping? Does damping fire by accident? |
| Slide | Can you land on a note by ear with `SNAP` off? With `SNAP` soft, is it expressive or just out of tune? |
| Dial | A one-octave scale up and down by rolling, evenly, without looking? Does the seam feel natural? |
| Valves | Can you play a scale after two minutes with the chart? Do bugle calls on the D-pad alone feel good? Is `CHROMATIC` fun or just wrong notes? |

An instrument moves to the roadmap when it passes the five tests in FUTURE_INSTRUMENTS §7.5; the last one is "you want to pick it up again a week later".

## Exit checklist

- [ ] `python3 tests/run.py` green
- [ ] Nine tabs read clearly and the slide shows which way you stepped 📱
- [ ] Each instrument has had a session of real playing and a verdict: slot, row on another instrument, or dropped 📱
- [ ] Settle window tuned on the fingering screen 📱

## Open (settle by playing)

1. Hand Drums: its own instrument, or a `HANDS` row on Drums?
2. Strum: the string map (`B` third, `A` fifth, `X` octave, `Y` seventh), and whether 35 ms is the right damp window.
3. Slide: default `SNAP`; whether `FOLLOW` (the home pitch follows the chord root) is wanted.
4. Do opposite pairs (`B + X`, `A + Y`) press comfortably? If so, Valves can use the real first + third fingering and Dial gains two positions.
5. Valves: is the fingering chart learnable, or should `SCALE` use a simpler one (one more button = one more step)?
6. With two or more winners, what leaves the library or becomes a row (FUTURE_INSTRUMENTS §8)?
