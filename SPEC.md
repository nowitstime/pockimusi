# PocketGroove (Working Title) — Technical & Design Specification
**Target Hardware:** Anbernic RG35XX Plus (Allwinner H700, ARM64 Linux, 1GB RAM, 640x480 4:3 IPS Display, No Touchscreen)  
**Target Engine:** LÖVE (Love2D 11.x) via PortMaster (`westonpack` / SDL2 Gamepad + `gptokeyb` fallback)  
**Architecture Style:** Modular Headless Domain Engine (Clock, Looper, Synth, Instrument Logic) + Passive 640x480 Vector View

---

## 1. Core Design Philosophy
1. **Ergonomic First:** Designed specifically around how two hands hold a vertical retro handheld. The left thumb (D-Pad) and index/middle fingers (`L1/L2`, `R1/R2`) shape harmony, modifiers, and recording states, while the right thumb (`B, A, Y, X`) articulates rhythms, strums, and triggers.
2. **Zero-Setup Jamming:** The master 2-bar loop clock is always rolling. Recording is an instant "clutch" action (`Hold L2`) rather than a stop-and-wait menu workflow.
3. **Self-Contained Procedural Audio (V1):** All synthesis and drum samples are generated mathematically in RAM at boot via `love.sound.newSoundData()`. Zero external `.wav` dependencies required to boot and play V1 (with `.wav` sample folder loading planned for V2).
4. **Hybrid Quantization:** Each track independently defines whether incoming recorded events snap to the 1/16th-note grid (e.g., Drums, Bass) or record in free-time floating-point phase (e.g., thumb-strummed Chord Harp, Granular movements).

---

## 2. Hardware Input Abstraction (`Input` Service)
To support seamless testing on a desktop PC (via USB controller or keyboard) and immediate deployment to the RG35XX Plus, all hardware inputs map to a unified virtual button state table.

### 2.1 Virtual Button Mapping Table
| Virtual Button | RG35XX Plus Physical | SDL2 Gamepad Button | Desktop Keyboard Fallback |
| :--- | :--- | :--- | :--- |
| `UP`, `DOWN`, `LEFT`, `RIGHT` | D-Pad | `dpup`, `dpdown`, `dpleft`, `dpright` (or Left Stick) | `W`, `S`, `A`, `D` |
| `B` (South) | Bottom Face Button | `a` (SDL South) | `J` or `Down Arrow` |
| `A` (East) | Right Face Button | `b` (SDL East) | `K` or `Right Arrow` |
| `Y` (West) | Left Face Button | `x` (SDL West) | `U` or `Left Arrow` |
| `X` (North) | Top Face Button | `y` (SDL North) | `I` or `Up Arrow` |
| `L1` | Top Left Shoulder | `leftshoulder` | `Q` |
| `R1` | Top Right Shoulder | `rightshoulder` | `E` |
| `L2` | Bottom Left Trigger | `triggerleft` (Axis > 0.5) / `leftstick` | `Left Shift` |
| `R2` | Bottom Right Trigger | `triggerright` (Axis > 0.5) / `rightstick` | `Spacebar` |
| `SELECT` | Select | `back` | `Tab` |
| `START` | Start | `start` | `Return / Enter` |

### 2.2 Global Transport & Modifier Combos
* **`SELECT` (Tap):** Cycle active instrument (`1: DRUMS` -> `2: CHORD HARP` -> `3: RIBBON BASS` -> `4: GRANULAR PAD`).
* **`SELECT` (Hold) + `UP / DOWN`:** Adjust Master BPM (`60` to `180` BPM, default `115`).
* **`SELECT` (Hold) + `LEFT / RIGHT`:** Transpose Global Root Key (`C` through `B`) and Scale (`Major`, `Minor`, `Dorian`, `Mixolydian`).
* **`START` (Tap):** Play / Pause Master Loop Clock (resets playhead to `0.0` on double-tap).
* **`L2` (Hold) — The Record Clutch:** While held, any note/drum played on the active instrument is overdubbed into that instrument's loop track.
* **`L2` (Hold) + `START` (Tap):** Clear all recorded events on the **currently selected track**.
* **`L2` (Hold) + `SELECT` (Tap):** Toggle Quantization (`ON/OFF`) for the **currently selected track**.
* **`R2` (Hold) + `B / A / Y / X` (Tap):** Toggle Track Mute for Tracks 1, 2, 3, and 4 respectively (`B` = Track 1, `A` = Track 2, `Y` = Track 3, `X` = Track 4).
* **`R2` (Hold) + `D-Pad`:** Master Live Performance Punch-In FX:
  * `R2 + UP`: 1/16th Beat Repeat / Stutter loop.
  * `R2 + DOWN`: Half-speed tape slowdown (pitch/clock drop).
  * `R2 + LEFT`: Low-pass / volume ducking swell.
  * `R2 + RIGHT`: Bitcrush / sample-rate decimation effect.

---

## 3. Instrument Specifications

### Instrument 1: "Euclidean / Ratchet" Drum Kit (Track 1)
* **Default Quantize:** `ON` (1/16th note grid = 32 steps per 2-bar loop).
* **Face Button Mapping:**
  * `B` (South): Kick Drum
  * `Y` (West): Snare Drum
  * `A` (East): Closed Hi-Hat
  * `X` (North): Clap / FM Wood Perc
* **Shoulder Modifiers (Live Roll / Ratchet Engine):**
  * **No Shoulder:** Single one-shot trigger on press.
  * **Hold `R1` + Hold Drum Button:** Auto-repeats the held drum at **1/16th note** intervals synchronized to the master clock.
  * **Hold `L1` + Hold Drum Button:** Auto-repeats at **1/12th (8th-note triplet)** intervals.
  * **Hold `L1 + R1` + Hold Drum Button:** Auto-repeats at **1/32nd note** glitch buzz intervals.
* **D-Pad Expression (While Playing/Rolling):**
  * `UP / DOWN`: Pitch offset of the triggered drum (`-6` to `+6` semitones—great for pitching hi-hat rolls or toms).
  * `LEFT / RIGHT`: Decay / tightness envelope modifier (short & clipped vs. long & booming).

---

### Instrument 2: "Pocket Omnichord" Strum Harp (Track 2)
* **Default Quantize:** `OFF` (Free-time phase recording to preserve natural thumb-strum speed across buttons).
* **Left Hand (D-Pad 8-Direction Chord Selector):**
  Selects diatonic chords relative to the global Root/Scale:
  * `Neutral (No D-Pad)`: **I** (Tonic triad/seventh)
  * `UP`: **I**
  * `LEFT`: **IV** (Subdominant)
  * `RIGHT`: **V** (Dominant)
  * `DOWN`: **vi** (Relative minor)
  * `UP-LEFT` (Diagonal): **ii**
  * `UP-RIGHT` (Diagonal): **iii**
  * `DOWN-LEFT` (Diagonal): **bVII** (Borrowed Mixolydian flat-seven)
  * `DOWN-RIGHT` (Diagonal): **IVm** (Borrowed minor fourth for indie-pop cadence)
* **Shoulder Modifiers (Voicing & Extensions):**
  * **Hold `L1`:** Adds lush **7th and 9th** extensions to the active chord.
  * **Hold `R1`:** Shifts chord voicing up **1st Inversion / +1 Octave** (or converts triad to **Sus4**).
  * **Hold `L1 + R1`:** Lush **Add9 + Upper Octave Spread** voicing.
* **Right Hand (`B, A, Y, X` = 4 Harp Strings):**
  * Each button plucks one note of the currently held 4-note chord voicing, ordered from lowest pitch to highest pitch in a circular thumb-slide arc:
    * `B` (Bottom) = Root / Bass Note (String 1)
    * `A` (Right) = 3rd / 5th (String 2)
    * `Y` (Left) = 7th / Octave (String 3)
    * `X` (Top) = 9th / High Extension (String 4)
  * Sliding the right thumb smoothly across `B -> A -> X -> Y` (or `B -> Y -> X -> A`) produces an organic harp strum.

---

### Instrument 3: "Compass" Ribbon Bass & Lead (Track 3)
* **Default Quantize:** `ON` (1/16th note grid).
* **Left Hand (8-Direction D-Pad Scale Compass):**
  Maps the 8 degrees of the active scale clockwise around the D-Pad so rolling your thumb plays smooth scalar runs:
  * `DOWN`: Scale Degree **1** (Root)
  * `DOWN-LEFT`: Scale Degree **2**
  * `LEFT`: Scale Degree **3**
  * `UP-LEFT`: Scale Degree **4**
  * `UP`: Scale Degree **5**
  * `UP-RIGHT`: Scale Degree **6**
  * `RIGHT`: Scale Degree **7**
  * `DOWN-RIGHT`: Scale Degree **8** (+1 Octave Root)
* **Shoulder Modifiers:**
  * `L1`: Octave Down (`-12` semitones — Deep Sub Bass range).
  * `R1`: Octave Up (`+12` semitones — Lead Synth range).
* **Right Hand (`B, A, Y, X` = Articulation Triggers):**
  * `B`: Punchy Staccato Bass Pluck.
  * `A`: Sustained Note with **Glide / Portamento** when rolling the D-Pad while held.
  * `Y`: Accented Octave Pop (plays current D-Pad note +12st with snappy envelope).
  * `X`: Fifth Interval Stab / Vibrato Lead.

---

### Instrument 4: "Granular Cloud" Texture Pad (Track 4)
* **Default Quantize:** `OFF` (Free-time phase recording).
* **Concept:** Triggers overlapping micro-grains from 4 procedural/sample buffers to create ambient pads and rhythmic textures.
* **Right Hand (`B, A, Y, X`):** Hold one or more buttons to emit continuous grain streams from 4 tonal/textural slots (`B`: Warm Pad, `A`: Glass Bell, `Y`: Breath/Choir, `X`: Sub Drone).
* **Left Hand (D-Pad):**
  * `LEFT / RIGHT`: Scrubs grain scan position / harmonic timbre.
  * `UP / DOWN`: Adjusts grain density and size (smooth cloud vs. rhythmic flutter).
* **Shoulder Modifiers (`L1 / R1`):**
  * `L1`: Pitch grains `-5` semitones (Fourth down).
  * `R1`: Pitch grains `+7` semitones (Fifth up).

---

## 4. Looper & Clock Engine Specification (`Looper` Module)

### 4.1 Timing Math
* **Loop Length:** 2 Bars in 4/4 time = `8` quarter-note beats = `32` sixteenth-note steps.
* **Loop Duration (Seconds):** `loopDuration = (60 / bpm) * 8`
* **Phase Advancement (`update(dt)`):**
  * `prevPhase = phase`
  * `phase = (phase + (dt / loopDuration)) % 1.0`
  * `currentBeat = math.floor(phase * 8) + 1` (1 to 8)
  * `currentStep = math.floor(phase * 32) + 1` (1 to 32)

### 4.2 Event Data Structure
Every track stores a flat array of event tables:
```lua
Event = {
  phase = 0.2500,        -- Float [0.0, 1.0)
  step  = 9,             -- Integer [1..32] (used for deduplication if quantized)
  instrument = 1,        -- Track ID (1..4)
  action = "B",          -- Button ID ("B", "A", "Y", "X")
  pitchSemis = 0,        -- Calculated semitone offset from base sample
  chordName = "Fmaj9",   -- Optional metadata for UI display
  decayMod = 1.0,        -- Envelope modifier
}
```

### 4.3 Recording & Playback Rules

1. **Quantized Recording (`track.quantize == true`):**
* When an event is recorded at `phase`, compute `step = (math.floor(phase * 32 + 0.5) % 32) + 1` and `snappedPhase = (step - 1) / 32`.
* **Deduplication:** If an event with the same `step` and `action` already exists in `track.events`, replace it rather than stacking duplicates.
* **Immediate Audition Prevention:** If snapping pushes `snappedPhase` slightly *ahead* of the current `phase` by a few milliseconds, tag the event with `justRecorded = true` so the playback head doesn't double-trigger it on the next frame.

2. **Unquantized Recording (`track.quantize == false`):**
* Record exact `phase` float as played. No step deduplication, allowing fast multi-string harp rolls (`B -> A -> Y -> X`) within a single 16th-note window.

3. **Playback Crossing Detection:**
* On each `update(dt)`, trigger any event where `event.phase > prevPhase and event.phase <= phase` (handling wrap-around when `phase < prevPhase` at the end of Bar 2).

---

## 5. Procedural Audio Engine (`Synth` Module)

At `love.load()`, generate `SoundData` buffers at `44100 Hz`, 16-bit mono, so the app is 100% playable as a single `.lua` file:

1. **Kick Buffer (`0.35s`):** Sine wave sweeping exponentially from `140 Hz` down to `42 Hz` over `0.08s`, with a `2ms` noise/click transient and `tanh` soft-clipping saturation.
2. **Snare Buffer (`0.25s`):** `180 Hz -> 110 Hz` triangle body mixed with band-shaped white noise (`exp(-t * 18)` amplitude decay).
3. **Hi-Hat Buffer (`0.12s`):** 6 detuned high-frequency square oscillators (`3100 Hz` to `7400 Hz`) ring-modulated with white noise and a fast exponential decay (`exp(-t * 45)`).
4. **Clap / Perc Buffer (`0.22s`):** Three `8ms` micro-bursts of filtered noise followed by a reverb-like noise tail (`exp(-t * 16)`).
5. **Harp / Plucked String Buffer (`1.2s`, Base Note `C4 = 261.63 Hz`):** Karplus-Strong physical string model or warm 2-operator FM electric piano (`Carrier: 1x`, `Modulator: 2x` with fast index decay so attack is glassy/plucky and tail is warm sine).
6. **Bass / Synth Buffer (`0.6s`, Base Note `C3 = 130.81 Hz`):** Filtered sawtooth + sub-octave square wave with resonant-style harmonic roll-off.

* **Voice Polyphony Pool:** Maintain a ring buffer of pre-allocated `love.audio.newSource()` clones per sound type (e.g., 12 harp string voices, 8 drum voices) to prevent garbage collection spikes during fast strumming.

---

## 6. 640x480 UI Layout (`View` Module)

Target resolution is strictly **640x480** using crisp geometric vector primitives (`love.graphics.rectangle`, `circle`, `line`, `polygon`) with an OLED/dark-mode Teenage Engineering aesthetic (`#121316` background, `#F4F4F6` off-white text, `#FF5E36` punch orange for recording/drums, `#38BDF8` pastel cyan for chord harp, `#A78BFA` violet for bass, `#34D399` mint for granular).

### 6.1 Screen Regions

1. **Top Status Bar (`y: 0..48`):**
* **Left:** Active Instrument Badge (`[1: DRUMS]`) + Quantize indicator (`[Q: ON]`).
* **Center:** `BPM: 115` | `KEY: C MAJ` | **8-Beat Metronome Dots** (Beat 1 & 5 larger; active beat lights up bright).
* **Right:** Record Clutch Status (`[L2: OVERDUB]` glowing orange when `L2` is held, `[JAM SAFE]` when released).

2. **Center Stage Visualizer (`y: 56..360`):**
* Dynamically switches view based on active instrument:
* **Drums View:** 4 isometric/vector drum pads arranged in the physical diamond layout (`X` top, `Y` left, `A` right, `B` bottom) that flash and scale on hit, plus a live ratchet indicator (`1/16`, `1/12T`, `1/32`) and pitch slider bar on the left.
* **Chord Harp View:** Big bold chord name readout in the upper left (e.g., `Dm9`, `G7sus4`) with a D-Pad chord wheel radar; on the right, **4 vertical glowing harp strings (`B, A, Y, X`)** that physically bend and oscillate with sine-wave vibration physics when plucked!
* **Ribbon Bass View:** An 8-way circular compass rose showing the 8 scale notes around the D-pad, plus an oscilloscope waveform in the center.
* **Granular View:** Horizontal waveform cloud emitting floating particle circles whose size, speed, and height respond to D-pad scrubbing.

3. **Bottom 4-Track Tape Deck (`y: 368..480`):**
* 4 stacked horizontal tracks (`Track 1: DRUMS`, `Track 2: CHORD`, `Track 3: BASS`, `Track 4: GRAIN`).
* Each track displays:
* Track Name, `[Q]` quantize badge, and `[MUTE]` state (`R2 + B/A/Y/X`).
* 32 vertical grid tick marks (dimmed) with bright colored pill markers for every recorded event in that track.
* A sweeping vertical white **Playhead Line** moving from left (`0.0`) to right (`1.0`).

---

## 7. File & Directory Architecture

We will start with a single-file prototype (`main.lua` + `conf.lua`) so it's effortless to test, while keeping the internal tables cleanly separated so they can be split into `src/` modules whenever needed:

```text
pocketgroove/
 ├── SPEC.md                  # This specification document
 ├── PocketGroove.sh          # PortMaster launch script for RG35XX Plus (muOS / Knulli)
 └── pocketgroove/
      ├── conf.lua            # Sets 640x480 window, vsync, audio mix With system
      └── main.lua            # Cleanly separated into:
                              #   1. Config & Scales
                              #   2. Procedural Synth & Voice Pool
                              #   3. Input Abstraction (Gamepad + Keyboard)
                              #   4. Looper & Clock Engine
                              #   5. Instruments (Drums, Harp, Bass, Grain)
                              #   6. 640x480 Vector UI Renderer
```

---

## 8. Implementation Milestones

* **Milestone 1 (Core Playable Prototype):**
* `conf.lua` + `main.lua` with Input layer (USB Controller + Keyboard fallback).
* Procedural Synth Engine generating Kick, Snare, Hat, Clap, Karplus/FM Harp, and Bass at startup.
* Hybrid 4-Track Looper (`L2` Overdub, `L2+Start` Clear Track, `L2+Select` Toggle Quantize, `R2+Face` Track Mutes).
* Fully playable **Instrument 1 (Ratchet Drums)** and **Instrument 2 (Pocket Omnichord Strum Harp)** with vibrating string visuals.

* **Milestone 2 (Full Instrument Suite & Punch-In FX):**
* Add **Instrument 3 (Compass Bass)** and **Instrument 4 (Granular Cloud)**.
* Implement `R2 + D-Pad` Master Performance FX (Beat Repeat/Stutter, Half-Speed Tape Drop).

* **Milestone 3 (RG35XX Plus PortMaster Packaging & SD Sample Loading):**
* Add `.sh` launch script for PortMaster (`westonpack` / `love` binary binding).
* Add optional `/samples/` folder scanner so dropping custom `.wav` drum kits or vocal chops onto the SD card automatically populates extra banks.
