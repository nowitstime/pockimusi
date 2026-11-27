# Valves (`VALVE`) — Working Plan

Part of [lab wave 1](README.md). Needs: [L0](L0_FOUNDATION.md) (the fingering reader). Independent of the other four instruments. The lab doc had set this idea aside for needing 15 fingerings; this version needs seven, all easy ones.

**Feel:** a brass instrument. The left thumb picks the open note, as the lips do; the right thumb lowers it with valves; an index finger blows. Nothing sounds without breath. Changing a valve while blowing slurs.

**Owns:** `pocketgroove/src/instruments/valves.lua`, `tests/test_valves.lua`, this file. Touches nothing else.

---

## Controls

**Left thumb, D-pad: the open note** (a tone of the current chord)

| Direction | `↓` | neutral | `←` | `↑` | `→` | `↘` |
| :-- | :-- | :-- | :-- | :-- | :-- | :-- |
| Open note | fifth below | root | third | fifth | seventh | octave |

These are where the Bass compass has the same notes. The other three diagonals keep the last open note.

**Right thumb, face buttons: the valves** (each fingering lowers the open note)

| Fingering | none | `A` | `B` | `A + B` or `X` | `A + X` | `Y` | all four |
| :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- |
| Steps down | 0 | 1 | 2 | 3 | 4 | 5 | 6 |

**Index fingers: the breath**

| Control | Job |
| :-- | :-- |
| `R1` | Blow: the note sounds while it is held |
| `L1` | Tongue: a second, softer breath. Alternating `R1` and `L1` repeats a note fast |

## Decisions

| Topic | Decision | Why |
| :-- | :-- | :-- |
| Breaks the habit | The shoulders trigger; both thumbs choose | Three jobs on three fingers: no other instrument splits the hands this way |
| The chart | A real four-valve fingering chart: second valve (`A`) one step, first (`B`) two, third (`X`) three, the fourth (`Y`) standing in for first + third as on a euphonium; `A + X` is second + third; all four takes the place of the hardest real fingering | Authentic, and it needs only singles, two neighbouring pairs and all four. Learning it is part of the instrument |
| Fingerings not on the chart | `X + Y`, `Y + B`, three buttons and opposite pairs keep the last valve position | Passing through them must not glitch |
| What a step is | `VALVES` row: `SCALE` (one scale note; default) / `CHROMATIC` (one semitone, as on the real thing) | `SCALE` can't play a wrong note. `CHROMATIC` is the first instrument that can leave the key on purpose |
| Open notes | The current chord's tones, read at each breath; with `FOLLOW` off, the tonic chord's | The D-pad alone plays bugle calls that always fit the chord |
| Slurs | Changing valves or the D-pad while blowing moves the note without a new attack. A valve change glides fast (as `GLIDE FAST` on Bass), an open-note change a little slower | That is what makes it sound like brass and not like a keyboard |
| Settle window | A fingering change within 35 ms of the breath is a correction: the note is re-pitched and the recording fixed, no slur recorded | The thumb and the finger land a frame apart |
| Tonguing | A second shoulder pressed while the first is held takes the note over with a new attack; the first shoulder's release then does nothing | Double-tonguing must not leave gaps |
| `L1` level | 75 % of `R1` | The "ta-ka" of double-tonguing |
| Mono | One note | A brass instrument plays one |
| Sound | `HOME_GROUP = "LEAD"`, opens on `SAW` (the closest to brass in the pool), `VOICES = 4`. A ringing patch gives a plucked version: each breath is a hit | |
| Register | `REGISTER` row: `LOW` / `MID` / `HIGH` | The shoulders are the breath |
| Stage view | `viewKind = "bass"` for the pitch trace; `VIEW.face` shows each button's steps, so the chart is on the screen | |

## Rows

`PATCH`, `VALVES`, `REGISTER`, `FOLLOW`.

## Event

One per breath:

| Field | Meaning |
| :-- | :-- |
| `action` | `"R1"` or `"L1"` (held by that shoulder, so the length records by itself) |
| `tone` | Which open note: −1 fifth below, 0 root, 1 third, 2 fifth, 3 seventh, 4 octave |
| `steps` | Valve steps down, 0 to 6 |
| `chromatic` | `true` if the steps were semitones when it was played |
| `semis`, `octave`, `vel` | |
| `bend` | Slurs: `{ dt, tone, steps, semis }` |

`tone` and `steps` are stored, not only the pitch, so a recorded line re-harmonises when the chords change. `LANES = { R1 = 1, L1 = 2 }`. `ERASE`: `B` clears `R1` breaths, `A` clears `L1` breaths.

## How it is built

- Built on the Bass module (`__index = Bass`) for the voice, bends, playback and trace. It replaces `updateInput`, `pitchFor` (tone + steps over a chord), the rows and the save / load.
- Each frame: the open note from the D-pad, the valve steps from `Input:getFingering()`; a shoulder press starts a note with `hold(ev)`; while it is held, a change of tone or steps is a correction inside the settle window, else `h:bend(...)`.
- Playback: the pitch is worked out again from `tone` and `steps` over the chord at the note's start when following, as the Bass does with degrees.

## Order

| Step | What | Size |
| :-- | :-- | :-- |
| VA1 | Open notes, the chart, breath on `R1`; `SCALE` and `CHROMATIC` | M |
| VA2 | Slurs and corrections; `L1` tonguing | S–M |
| VA3 | Rows, saves, erase map, lanes, `VIEW` labels | S |
| VA4 | Playback with `FOLLOW`: recorded lines move with the chords | S |

## Tests

- Nothing sounds without a shoulder, whatever the thumbs do.
- Each D-pad direction gives its chord tone over the current chord; the unused diagonals keep the last one; a chord change gives new open notes at the next breath.
- Each fingering on the chart lowers by its steps, in scale notes and in semitones; `X` equals `A + B`; fingerings off the chart change nothing.
- A valve or D-pad change while blowing is a bend on the same voice; inside the settle window it rewrites the note and records no bend.
- `L1` while `R1` is held re-attacks at 75 %; releasing `R1` afterwards does not stop the note; alternating gives one event per breath.
- A recorded line replays the same pitches; with `FOLLOW` on it moves with changed chords, with it off it does not.
- Rows save and load; erase clears by breath.

## Playtest

- Can you play a scale after two minutes with the chart on the screen?
- Do bugle calls on the D-pad alone feel good?
- Is `CHROMATIC` fun, or just wrong notes?
- Does double-tonguing keep time at 1/16 notes?

## Status

VA1 to VA4 are built and tested (`tests/test_valves.lua`, 14 tests). No shared file was touched. Left: the playtest above 📱.

- **Slur data sits beside the bend, not in it.** A recorded slur is an ordinary pitch keyframe in `bend` (`{ dt, semis, octave }`), plus `slur = { { dt, tone, steps }, ... }` on the event with the same `dt`s. Session load keeps only the known keyframe fields, so `tone` / `steps` inside a keyframe would be lost; an event field is saved as plain data. Playback re-harmonises from `slur` when following, and uses the bend's `semis` otherwise.
- **A slur waits for the thumbs to stand still.** After the settle window, a change of valves or open note is played (and recorded) once tone and steps have held for `Input.FINGER_SETTLE`, so a pair landing a frame apart, or a diagonal passing through a straight direction, slurs once to where it lands. Costs 35 ms on a slur; say if it feels late.
- **Glide rates:** a valve change 40 (the Bass's `FAST`), an open-note change 18 (`MEDIUM`), live and on playback (playback tells them apart by whether the tone changed). The Bass view's capsule reads `GLIDE FAST`.
- **`SCALE` steps from a note outside the key** (a borrowed chord's tone) land on the scale note below it first.
- **`REGISTER`** is stored in the event's `octave` (−1 / 0 / +1 over C4), so a recorded breath keeps the register it was played in.
- **Tonguing the other way round:** if the newer shoulder lets go while the older one is still down, the note stops (the older breath already ended). Only the newest breath ever sounds.
- **Both shoulders in one frame:** `R1` wins.
- **`eventClass = "valves"`**, so a swap with Bass or Lead does not carry notes across (the fields differ).
- **The chart on screen:** the face buttons show `-1 -2 -3 -5`; the line under the note shows the open note, the steps, the step kind and `A+X -4  ALL -6`.

## Open (settle by playing)

1. Is the chart learnable? The fallback is "one more button, one more step" for `SCALE`.
2. Should the open notes follow the chord (as planned) or be a true bugle series on the key's root?
3. A half-valve bend (a fingering held for a moment between two positions) as an effect?
