# Pockimusi — Future Plans

Companion to [SPEC.md](SPEC.md), [ROADMAP.md](ROADMAP.md) and [FUTURE_INSTRUMENTS.md](FUTURE_INSTRUMENTS.md). The roadmap covers the phases already ordered. This file collects **feedback from playing and ideas for what comes after**: changes to the menus and the flow, song building, and the longer road to a new audio engine and hardware. Nothing here is scheduled. An idea moves to the roadmap once it is decided.

Legend: 👍 leaning yes · 🧪 try it first · ❓ undecided · 💤 later

---

## 1. Direction

1. **Workflow first.** Finish the concept in LÖVE until the workflow feels right. The workflow is cheap to change in Lua and expensive to change in a lower-level language or on a circuit board.
2. **Then the audio engine** (§9), once the workflow has settled.
3. **Then hardware** (§10), if a limit remains that software can't fix.

The LÖVE version stays as the edition anyone can download to a retro handheld. A dedicated device would be the full version of the same concept.

Two things keep the later remake cheap:

- Keep the engine headless: instruments, looper and harmony talk to audio only through the `Synth` calls.
- Don't polish sound inside the current engine beyond levels and patch choice; that work would be redone.

---

## 2. What playing has shown so far

| Finding | What it suggests |
| :-- | :-- |
| It has been played on the RG35XX throughout; the checks just weren't logged | Tick off or delete the "device check pending" lines in the roadmap |
| The most fun setup so far is a laptop with an Xbox controller | Bigger controls, a bigger screen and good speakers all add up (§7, §10) |
| That clashes with the first idea: something for on the go | Treat them as two settings for one instrument; don't choose yet (§10) |
| A built-in speaker matters; headphones sound better on the RG35XX but are less fun | A constraint for any future device: a good speaker needs physical volume |
| Other people play notes within a second, but had to ask how to record and do the rest | The gap is the step after the first note (§5) |
| The early, simpler version was easier to read: one bright colour, a couple of options | Features were added faster than focus; pages need stripping back (§4) |
| Track page navigation feels wrong; every instrument's page looks the same | Rework the Track page (§3) ✅ |
| "Every instrument works the same" doesn't always suit the instrument | Loosen the grammar on the play surface (§6) |
| The chord mechanic is a favourite, but the harp's sound isn't always wanted | A chord track that makes no sound (§6.3) |

---

## 3. Track page rework ✅

Built; the details are in SPEC §3.4.

- **Controls swapped:** `LEFT / RIGHT` change the selected row (holding repeats); `L1 / R1` step the instrument, shown as tabs across the top. The safe swap stays: preview, applied on `SELECT` release, undoable.
- **Effect amounts are rows:** `TONE`, `DRIVE`, `ECHO`, `SPACE` follow the instrument's rows. The face buttons keep the on / off toggle, and a tap moves the cursor to that effect's row.
- **Picker:** every list row opens a shelf over the tape deck (group tabs, the group's items, full name, a map of the list). It replaced the carousel idea after mockups: the tape deck is unused while the page is open, so the shelf costs nothing. Number rows show a bar instead.
- **Swap card:** a previewed instrument replaces the rows with a card naming it.

Still open:

- 🧪 Play a short phrase on instrument preview; show that instrument's stage view behind the card.
- 🧪 The same picker for key and scale on the Transport page.
- ~~Patch groups, once there are more patches.~~ ✅ Built with the sound pool (SPEC §6).

---

## 4. Clarity pass

The aim is the focus of the early version with today's features. This would reshape Phase I (visual polish) and is worth doing before more features land on the same pages.

- Show the row you are on in full; dim or shrink the others.
- One bright highlight per screen, on the next thing to press. Decoration stays quiet.
- The first screen of each page holds only the two or three things changed most; rarely changed settings move off it.
- Hints show what each button does on the current instrument, which matters more once instruments differ (§6).

---

## 5. Learning it without help

- **First-run prompts:** a fresh session shows "tap L2 to record" until the first take lands, then the next step, then nothing.
- **Learn mode** (already ❓ in Phase I): a held button overlays the whole control map.
- **Test unwatched:** hand it over with one sentence ("it's a looper, make a beat"), leave for five to ten minutes, then ask to be shown what was made. Note what was never found, not only what was asked.

The target is not "no learning": depth is fine (Ableton is loved and not obvious). The target is that the first minute works alone.

---

## 6. Control grammar

### 6.1 Two tiers 👍

| Tier | Buttons | Rule |
| :-- | :-- | :-- |
| Global | `L2` record, `R2` performance, `SELECT` sound, `START` timing | Fixed everywhere, never reused |
| Play surface | D-pad, `B A Y X`, `L1`, `R1` | Belongs to the instrument. "Right thumb triggers, left thumb picks" stays a habit, not a law |

Drums already use the shoulders for note repeat. Octave stays on the shoulders where it is natural (Bass, Lead) and can give way where something else is more expressive.

### 6.2 Chord Harp: colour back on the shoulders 👍

Colour changes chord by chord; octave is set once. This answers SPEC §3.3's open question about a momentary colour gesture.

| Held | Chord colour |
| :-- | :-- |
| nothing | the `COLOUR` row's value (the base colour) |
| `L1` | sus4 (sparser) |
| `R1` | 7th (denser) |
| `L1 + R1` | 9th or add9 ❓ |

- Voicing octave becomes a setting row.
- Harp events already store their colour, and the Pad's full voicing and the followers' 7th read it, so holding `R1` on a V chord would carry the Pad and Bass into V7.
- ❓ Which colours go on which shoulder; whether the wide voicing (`L1 + R1` today) is kept anywhere.

### 6.3 A chord track that makes no sound 🧪

- **Works today:** record chords on the harp and mute that track (`R2` + its face button). Muting the chord source doesn't change the harmony (SPEC §5), so the followers still follow. Play this way for a few sessions first.
- **Option A:** a silent patch for the harp. Cheap, but it uses one of the four tracks. ✅ Built: `SILENT` on the harp's `PATCH` row.
- **Option B:** a chord lane outside the four tracks. Frees a slot, but adds a concept and needs somewhere to be recorded from.
- **Also:** let the harp use the Pad and Lead patches, in case the problem is only the harp's sound. ✅ Built: the harp plays the whole sound pool (SPEC §6).

---

## 7. Controller experiments 🧪

- **Steam Deck:** LÖVE runs on it, so the current build should work as it is. Too big for the pocket version, but a stand-in for a larger device: full-size controls, a usable speaker, analog triggers, back buttons.
- **Analog controls on an Xbox-style pad:** today the left stick acts as a D-pad and the triggers are on / off. Try trigger pressure for drum velocity or Pad swell, and the right stick for bend or filter. Handhelds without them fall back to the digital controls.

---

## 8. Song building ❓

Still being thought through. The proposal below is a starting point, not a decision.

### 8.1 Scenes

- A scene is what a session is today: four tracks with their instruments, sounds, settings and notes. Eight slots, A–H. Tempo and key stay song-wide.
- Each scene has its own four slots, so a song can use more than four instruments while every phrase still shows four tracks.
- **Copy** is the main move: copy A into B, then change one thing. That is how variations are made.
- A switch is queued and lands at the end of the loop.
- The autosave snapshot (`src/session.lua`) is already close to a scene.

### 8.2 The song is a recording of switching

- Arm song record, then perform: switch scenes and mute or unmute tracks. The app stores steps: scene, muted tracks, number of loops.
- Mutes do much of the arranging: an intro is the verse scene with only drums and pad; a breakdown is the chorus without drums.
- A strip of blocks shows the song for repairs (change a step's length, delete a step). Editing is for fixing, not for building.
- Playing live over the song gives one more layer.

### 8.3 Controls

- Hold `SELECT + START` (free today; sound + timing = song) for the Song page.
- The eight scenes sit in a ring, one per D-pad direction: flick towards a scene to queue it.
- Face buttons on the page: copy to the pointed slot, clear a slot, arm song record, play / stop the song.

### 8.4 Alternative: a grid

Each track switches its own loop independently (Ableton's session view). More flexible; needs a grid cursor and more explaining. Considered, not ruled out.

### 8.5 Open

1. Whole scenes or per-track clips?
2. Bars per scene (a 2-bar fill scene next to 4-bar scenes)?
3. Switch only at the loop end, or also at once?
4. Is the song performed, edited, or both?
5. Where does `.wav` export fit? It depends on the new audio engine (§9).

---

## 9. Audio engine v2 💤

The current engine plays pre-rendered samples through LÖVE sources. Its limits:

- Notes start on a frame, so timing can be off by up to about 16 ms.
- Envelopes and glides move in 60 Hz steps.
- The only filter is the EFX low-pass, without resonance.
- There is no mix bus: no limiter, no true meters, no sidechain, no practical `.wav` export.

| Option | Gain | Cost |
| :-- | :-- | :-- |
| Own mixer in LuaJIT feeding a queueable source | Sample-accurate timing, real filters, a bus | Garbage-collection pauses become dropouts; CPU headroom on the H700 unknown |
| **Native DSP core (C, Rust or Zig) loaded from LÖVE via FFI** 👍 | The same with headroom, plus offline render for export | A cross-compiled library in the port; the looper sends timestamped events |
| Full rewrite on SDL2 | Faster boot, less memory | Loses the working Lua logic, UI and most tests |

Written as portable C (fixed blocks, no allocation), the native core could later run on a microcontroller (§10).

What it would allow: band-limited oscillators, a resonant filter with its own envelope, a master limiter, kick sidechain, tempo-synced delay, stereo and pan, `.wav` export.

---

## 10. Hardware 💤

Portability and comfort are two settings for the same instrument. A ladder, cheapest first:

1. **No new hardware:** handhelds with analog sticks; USB DAC and USB MIDI out or clock over OTG.
2. **Add-on:** a small RP2040 box with encoders or pads, as USB MIDI or HID.
3. **Linux board:** Pi Zero 2 or CM4 with an I2S DAC, running the same code.
4. **Microcontroller:** Daisy Seed or Teensy 4.1. The only step that needs the full low-level rewrite.

Form factor: something Steam Deck-shaped has full-size controls, a bigger screen and room for a real speaker, and still goes in a bag. Smaller cases rule out a good speaker.

---

## 11. Other candidates

- MIDI out and clock sync.
- Transport setting rows, which would give replace / overdub and auto-stop a home (both blocked today by "no free button", SPEC §4).
- Named session slots, before or alongside scenes.
- More devices: resolution scaling.
- Housekeeping: a README and licence, CI running `tests/run.py`, release builds (`PocketGroove.love` is a committed binary), finish the rename to Pockimusi (docs done; window title, launcher, `.love`, folder and save path still say PocketGroove, and moving the save folder needs a one-time copy of old saves), splitting `ui/chrome.lua`, phase docs in a `docs/` folder.

---

## 12. Suggested order

1. ~~Track page: control swap, effect rows, picker (§3)~~ ✅
2. Harp colour on the shoulders (§6.2)
3. Clarity pass and first-run prompts (§4, §5)
4. Song building, once designed (§8)
5. Audio engine v2, then hardware (§9, §10)
