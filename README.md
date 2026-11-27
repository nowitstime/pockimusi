# Pockimusi (PocketGroove)

A gamepad-first 4-track groovebox, chord lane, and song arranger built in [LÖVE](https://love2d.org/) for retro handhelds (RG35XX Plus / PortMaster), Steam Deck, and laptops with a controller.

## Highlights
- **4 swappable instrument tracks + Track C chord lane** — 13 playable instruments across Rhythm (Drums, Hand Drums, Breaks), Bass (Bass, Roller, Wobble), Chords (Chord Harp, Strum), Texture (Pad), and Lead (Lead/Arp, Dial, Slide, Valves).
- **Chord-follow harmony** — record or stamp progressions on Track C and have Bass, Pad, Lead, and others follow automatically.
- **4 swappable per-track FX slots** — 10 OpenAL EFX effects (`TONE`, `HPF`, `RADIO`, `DRIVE`, `PUNCH`, `CHORUS`, `FLANGE`, `RING`, `ECHO`, `SPACE`) with moon-phase gauges.
- **Song Mode & Pattern Slots A–H** — queue, cut, record mutes/FX/fades/overdubs, and arrange full songs without stopping the clock.
- **Zero-sample procedural synth** — all drum kits and sustained pitched patches are synthesized on the fly in LuaJIT.

## Downloads & Try in Browser
- **Native Releases** (Windows `.exe`, Linux / Steam Deck `.AppImage`, macOS `.app`, PortMaster `.zip`, and universal `.love`): grab the latest build from [**GitHub Releases**](https://github.com/nowitstime/pockimusi/releases).
- **Try in Browser**: [**Play on GitHub Pages**](https://nowitstime.github.io/pockimusi/) *(plug in a gamepad or use keyboard controls)*.
  > **Note on Browser Audio:** The web build runs on WebAudio, which does not support OpenAL EFX — so per-track effects (`TONE`, `HPF`, `RADIO`, `CHORUS`, `FLANGE`, `RING`, `ECHO`, `SPACE`, `PUNCH`) are disabled in the browser (only the non-EFX `DRIVE` gain fallback applies). Download a native release for the full audio engine.

## Controls Quick Reference
| Button | Action |
| :-- | :-- |
| **D-Pad + `B A Y X` + `L1 / R1`** | Play the active instrument |
| **`L2`** (tap / hold) | Latch record / punch-in record |
| **`SELECT`** (tap / hold) | Switch track / Track page (sound, instrument swap, 4 FX slots) |
| **`START`** (tap / double-tap / hold) | Play-pause / panic & reset / Clock page (BPM, key, scale, grid, swing, bars) |
| **`R2`** (hold) | Live performance FX & quick mutes |
| **`SELECT + R2`** | Mix page (levels, meters, mutes) |
| **`L2 + R2`** | Erase / undo |
| **`SELECT + START`** (tap / hold) | Song page (`S`) / Pattern & settings menu |

## Development
```bash
# Run locally (requires LÖVE 11.x)
love pocketgroove

# Run the headless test suite (requires LuaJIT)
luajit tests/run.lua

# Package pocketgroove/PocketGroove.love
python3 build.py

# Render headless UI screenshots (requires lupa + Pillow)
python3 tools/screenshot.py
```

## Documentation
- [SPEC.md](docs/SPEC.md) — full design & behavior specification
- [ROADMAP.md](docs/ROADMAP.md) — build order and completed phases
- [FUTURE_PLANS.md](docs/FUTURE_PLANS.md) — playtest notes, ideas, and Audio Engine v2
- [docs/phases/](docs/phases/) — per-phase implementation notes
- [docs/feedback/](docs/feedback/) — per-instrument playtest logs

## License
Licensed under the [Apache License 2.0](LICENSE). Bundled fonts under `pocketgroove/assets/fonts/` are licensed under the SIL Open Font License (see `OFL-*.txt`).
