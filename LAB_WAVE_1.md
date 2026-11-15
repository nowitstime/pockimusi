# Lab wave 1 · Four instruments to try — Working Plan

Part of [FUTURE_INSTRUMENTS.md](FUTURE_INSTRUMENTS.md) (the lab). Design background: that file's §2, §4 and §6; [SPEC.md](SPEC.md) §3.4 (Track page), §6 (sound pool).

**Goal:** four new ways of playing are in the app, rough but playable, so playing can decide which ones stay: **Hand Drums** (two thumbs), **Strum** (set the notes with the thumbs, pluck with the shoulders), **Slide** (steer the pitch) and **Dial** (roll the thumb round the scale). The Track page's instrument tabs change first, because nine names no longer fit in a row.

**Rule for every step:** one step = one or a few commits, app playable, tests green. 📱 = check on the RG35XX. Lab rule: no polish until an instrument has earned its slot (FUTURE_INSTRUMENTS §7).

---

## Decisions

### The lab itself

| Topic | Decision | Why |
| :-- | :-- | :-- |
| Which four | Hand Drums, Strum (the doc's "Pick"), Slide, Dial | The doc's first wave: none depends on a later phase. Slide is cheap and answers the hardware-slider question. Dial is the most different, but only if the device's buttons allow it (see L4) |
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
| **Test first** | A lab screen that shows the fingering the app sees (one of eight: four buttons, four neighbouring pairs) and counts how often a pair lands cleanly. Dial is built only if pairs land reliably 📱 | The doc's biggest risk. On the RG35XX's small buttons this decides everything |
| If it passes | Degrees 1 to 8 clockwise from `B`; rolling to a neighbour slurs; rolling across the seam carries the octave; D-pad `↑ / ↓` dynamics, `← / →` flat / sharp; `L1 / R1` octave. As FUTURE_INSTRUMENTS §4.2 | |
| Settle window | A change of fingering within 35 ms of a fresh press corrects the note; after that it is a slur | Two buttons meant together arrive a frame apart |
| Engine pieces | Held notes the instrument releases itself; a fingering reader in `input.lua` | Both small, both listed in the doc's §6 |

---

## Order

| Step | What | Size |
| :-- | :-- | :-- |
| L0 | `LAB` switch, lab view, `ERASE` map, test for saves with a missing instrument | S |
| L1 | Instrument tabs as a centred carousel 📱 | S |
| L2 | Hand Drums (`MIRROR`) | S |
| L3 | Strum: strokes, strings, damp, pluck / bow by patch, strum playback | M |
| L4 | Dial button test 📱, then a go / no-go | S |
| L5 | Slide | S–M |
| L6 | Dial, if L4 passed | M |

L1 comes before any instrument, so each new one has a tab to appear in. The Dial test goes early because it needs the device and its answer is needed before L6.

## Tests

- L0: with `LAB` off the catalogue is the five library instruments and stepping skips the rest; a save holding a lab instrument loads as an empty track on the default instrument; an `ERASE` map clears the mapped actions and nothing else.
- L1: the centred tab is the previewed instrument, else the track's own; stepping past either end wraps; every instrument can be reached with `L1` alone and with `R1` alone; drawing works with 5 and with 9 instruments.
- L2: `↑ ↓ ← →` play and record under `X B Y A`; a diagonal makes two hits; `L1` = ghost level, `R1` = accent level, both = repeat; Drums ↔ Hand Drums keeps the notes; the erase and lane code see only face actions.
- L3: no face button = one note at the D-pad's degree; held buttons add their steps; `R1` orders low to high and `L1` high to low, the right spread apart; a second shoulder inside 35 ms damps and removes the stroke; a ringing patch records a hit, a sustaining patch records a length and glides; playback over a changed chord moves the whole stack; rows save and load.
- L4: the fingering reader reports the eight fingerings and nothing else; opposite pairs and three buttons give no fingering; a pair arriving one frame apart reads as the pair once settled.
- L5: holding `↑` raises the pitch at the row's speed and it stays on release; `← / →` land on scale notes; `A` settles on the nearest scale note; a slide records at most one keyframe per 30 ticks and replays the same curve; both shoulders return to the root.
- L6: the eight positions give degrees 1 to 8; a roll is a slur (one event, bends); the seam moves the octave by one per lap and keeps the pitch; a correction inside the settle window rewrites the note instead of slurring.

## Playtests (what decides a slot)

| Instrument | Question |
| :-- | :-- |
| Hand Drums | A clean 1/16 single-stroke roll at 120 BPM? Do you miss flam and ratchet? |
| Strum | Steady alternate-picked 1/16 notes at 120 BPM for two bars? Is the bow worth keeping? Does damping fire by accident? |
| Slide | Can you land on a note by ear with `SNAP` off? With `SNAP` soft, is it expressive or just out of tune? |
| Dial | A one-octave scale up and down by rolling, evenly, without looking? Does the seam feel natural? |

An instrument moves to the roadmap when it passes the five tests in FUTURE_INSTRUMENTS §7.5; the last one is "you want to pick it up again a week later".

## Exit checklist

- [ ] `python3 tests/run.py` green
- [ ] Nine tabs read clearly and the slide shows which way you stepped 📱
- [ ] Each instrument has had a session of real playing and a verdict: slot, row on another instrument, or dropped 📱
- [ ] Dial go / no-go recorded here 📱

## Open (settle by playing)

1. Hand Drums: its own instrument, or a `HANDS` row on Drums?
2. Strum: the string map (`B` third, `A` fifth, `X` octave, `Y` seventh), and whether 35 ms is the right damp window.
3. Slide: default `SNAP`; whether `FOLLOW` (the home pitch follows the chord root) is wanted.
4. With two or more winners, what leaves the library or becomes a row (FUTURE_INSTRUMENTS §8)?
