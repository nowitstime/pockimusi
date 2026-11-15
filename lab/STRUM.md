# Strum (`STRUM`) — Working Plan

Part of [lab wave 1](README.md). Needs: [L0](L0_FOUNDATION.md). Independent of the other four instruments. FUTURE_INSTRUMENTS §4.1 calls this idea "Pick".

**Feel:** you set the note up silently with your thumbs, and nothing sounds until an index finger plucks it. Alternating the two shoulders gives fast tremolo picking and strums that one thumb cannot play.

**Owns:** `pocketgroove/src/instruments/strum.lua`, `tests/test_strum.lua`, this file. Touches nothing else.

---

## Controls

| Control | Job |
| :-- | :-- |
| D-pad | Degree, the Bass compass (neutral = root). **Silent** |
| `B A Y X`, held | Add strings above the root. **Silent**: `B` third, `A` fifth, `X` octave, `Y` seventh |
| `R1` | Downstroke: the root and every held string, low to high |
| `L1` | Upstroke: the same, high to low |
| `L1` and `R1` together | Damp: everything ringing stops |

No face button held = a single note, so it is also a melody instrument.

The easy fingerings give useful shapes: `B + A` a triad, `A + X` root, fifth and octave, `Y + B` a seventh chord without its fifth, all four the full chord.

## Decisions

| Topic | Decision | Why |
| :-- | :-- | :-- |
| Breaks the habit | The shoulders trigger instead of setting the octave | That is the whole instrument |
| Strings | Scale steps above the D-pad's degree: third +2, fifth +4, seventh +6, octave +7. With `FOLLOW` on they are the current chord's own third, fifth and seventh | Stored as steps, so a recorded strum re-harmonises |
| Order in a stroke | By pitch: root, third, fifth, seventh, octave for a downstroke; reversed for an upstroke | A real strum crosses the strings in order |
| Spread | `STRUM` row: `TIGHT` (12 ms between strings) / `LOOSE` (30 ms). The first string sounds at once | The gap is what makes it a strum and not a chord. Timing is at frame resolution in this engine |
| Damp | The second shoulder landing within the settle window (35 ms) of the first: everything ringing stops, and the stroke that just started is cut and its recording removed | Both shoulders "together" arrive a frame apart. A wait before every stroke would make a rhythm instrument feel late, so the stroke plays at once and is withdrawn |
| Outside the window | The second shoulder is simply the next stroke | Alternate picking overlaps the shoulders all the time |
| A patch that **rings** | Plucked: a stroke is a hit (no length), notes ring over each other; a string plucked again restarts | The pool says which is which (`patch.rings`) |
| A patch that **sustains** | Bowed: the stroke sounds while its shoulder is held; moving the D-pad glides every string to the new degree; changing direction (the other shoulder) starts a new bow stroke | The same instrument becomes a bow |
| Level | A stroke's level is shared between its strings (as the Pad shares a chord's) | Five strings must not be five times as loud |
| Register | `REGISTER` row: `LOW` / `MID` / `HIGH` (an octave apart) | The shoulders are busy |
| Sound | `HOME_GROUP = "PLUCK"`, opens on `NYLON`, `VOICES = 10` | |
| Stage view | `viewKind = "lab"`: the readout names the degree and the strings held (`3  +  5TH  8VE`), and the last stroke's direction | |

## Rows

`PATCH`, `REGISTER`, `STRUM`, `FOLLOW`.

## Event

One per stroke:

| Field | Meaning |
| :-- | :-- |
| `action` | `"R1"` (down) or `"L1"` (up); a bowed stroke is held by that shoulder, so its length records by itself |
| `degree`, `octave`, `semis` | The root of the stroke, as on Bass |
| `stack` | The strings held, as scale steps above the root, e.g. `{ 2, 4 }` |
| `strum` | Seconds between strings; negative for an upstroke |
| `vel` | |
| `bend` | Bowed strokes only: the D-pad's moves, as on Bass |

`LANES = { R1 = 1, L1 = 2 }`. `ERASE`: `B` clears downstrokes, `A` clears upstrokes.

## How it is built

- Its own module; pitch helpers borrowed from Bass (`pitchFor`), sound through `Patches.noteOn`.
- A stroke = one event; `noteOn` works out the strings' pitches (from the chord at the note's start when following), plays the first and schedules the rest with `Synth:schedule`. Playback takes the same path.
- Damp: keep the last stroke's voices and its recorded event for the length of the settle window; if the other shoulder arrives inside it, stop all of this track's voices and remove that event.
- Bow: `hold(ev)` with the shoulder as the action; `bendTo` glides each string by the same interval.

## Order

| Step | What | Size |
| :-- | :-- | :-- |
| ST1 | Strokes: degree, strings, direction, spread, shared level; ringing patches | M |
| ST2 | Damp | S |
| ST3 | Rows, saves, erase map, lanes, lab view | S |
| ST4 | Playback with `FOLLOW`: recorded strums move with the chords | S |
| ST5 | Bow: sustaining patches, glides | S–M |

ST5 can be dropped without hurting the rest if the bow is not worth it.

## Tests

- No face button = one note at the D-pad's degree and octave; each button adds its step; all four add four.
- `R1` plays low to high and `L1` high to low, the row's spread apart, the first at once.
- A stroke's strings share one level.
- A second shoulder inside the window damps every voice on the track and removes the stroke's event; outside it, it is a new stroke and nothing is cut.
- A ringing patch records `len = 0`; a sustaining patch records the held length and ends on release.
- Bowed: a D-pad move glides every string and records one bend.
- Playback over a changed chord moves root and strings with `FOLLOW` on, and leaves them with it off.
- Rows save and load; erase clears by direction.

## Playtest

- Steady alternate-picked 1/16 notes at 120 BPM for two bars?
- Do fast lines come out cleaner than on Bass?
- Does damping fire by accident, or fail to fire when wanted?
- Is the bow worth keeping?

## Status

Not started.

## Open (settle by playing)

1. The string map (`B` third, `A` fifth, `X` octave, `Y` seventh).
2. Should a downstroke on the beat and an upstroke off it differ in level, as a hand does?
3. Should holding no D-pad direction follow the chord root (as now) or keep the last degree?
