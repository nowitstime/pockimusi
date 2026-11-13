# Phase C · Autosave — Working Plan

Part of [ROADMAP.md](ROADMAP.md). Design: [SPEC.md](SPEC.md) §10.

**Goal:** a jam survives turning the Anbernic off. The session saves itself while you play and on quit, and comes back exactly as you left it on the next boot. A deliberate hold combo starts a fresh session, and even that can be undone.

**Rule for every step:** one step = one or a few commits, each leaving the app playable, tests green. 📱 = check on the RG35XX.

---

## Decisions

| Topic | Decision | Why |
| :-- | :-- | :-- |
| What's saved | Tempo, key, scale, bars, click, master volume, active track; per track: instrument, its settings (kit and pad sounds, chord colour, bass patch and glide, grain scan and density), grid, swing, volume, mute, effects, and every event (bends and chords included) | Everything you set or played |
| Not saved | Undo history, record latch, playhead position, live voices and animations | You start jam-safe at bar 1; undo starts empty |
| When | **Every 10 s if anything changed**, and on quit / when the app loses focus | A hard power-off loses at most ~10 s; unchanged sessions write nothing |
| Change detection | Build the save text and compare it with the last one written | No need to flag "dirty" in dozens of places |
| Safe writes | **Two slots** (`session_a`, `session_b`), alternating, each with a sequence number; load the newest one that reads cleanly | A power cut mid-write can only spoil the slot being written; the other is the previous good save |
| Format | A plain Lua table written as text, read back in an empty sandbox (no code can run); `format = 1`, events in format v2 | Readable, no library; room for patterns later (`patterns = { A = ... }`) |
| Bad or newer files | Ignored with a toast; the other slot or a fresh session is used | Never crash on boot |
| Fresh session | **Hold `L2 + R2 + SELECT` for about 1 s**: clears every track's notes and mutes. **Keeps** tempo, key, scale, instruments, sounds and effects. The cleared session is kept, and undo (`L2 + R2 + LEFT`) brings it all back | A hold can't happen by accident; your setup stays ready to jam |
| Save location | LÖVE's save folder for identity `pocketgroove`; the path is printed to `log.txt`. Proposal: set `XDG_DATA_HOME="$GAMEDIR/conf"` in `PocketGroove.sh` so saves live in the port folder (easy to find, back up, and survive a PortMaster runtime update) ❓ confirm on device | Today the folder depends on how the PortMaster LÖVE runtime sets things up |

---

## Order

| Step | What | Size |
| :-- | :-- | :-- |
| C1 | Save text: write a table, read it back safely (`src/save.lua`) | S |
| C2 | Session snapshot and restore (per-instrument `saveState` / `loadState`) | M |
| C3 | Autosave: two slots, every 10 s if changed, on quit and focus loss; load on boot 📱 | M |
| C4 | Fresh session: `L2 + R2 + SELECT` hold, undoable; save folder check 📱 | S |

---

## C1 · Save text

- `Save.encode(value)` writes numbers, strings, booleans and tables (string or number keys, sorted so the text is stable for change detection). Anything else (functions, sources, voices) is an error, so runtime objects can't sneak into a save.
- `Save.decode(text)` loads the text as a chunk with an **empty environment** (`setfenv`) and a size limit; it must return a table. A file that tries to call anything fails to load instead of running.
- Numbers keep full precision (`%.17g`), so ticks and amounts come back exactly.

**Tests:** round trip of nested tables, strings with quotes and newlines, negative and fractional numbers; stable output for the same table; functions rejected; a file containing code (`os.exit()`, `print(...)`) doesn't run; garbage text returns an error, not a crash.

---

## C2 · Snapshot and restore

- `Session.snapshot()` builds the plain table: globals, and per track `{ instrumentId, settings = def:saveState(state), gridIndex, swing, volume, muted, fx, events }`.
- Each instrument gets `saveState(state)` → plain settings, and `loadState(state, data)` → applies them to a fresh `newState()`, ignoring unknown or invalid values:

  | Instrument | Saved settings |
  | :-- | :-- |
  | Drums | kit, each pad's sound (by sound id, not catalogue index, so adding sounds later doesn't shuffle them), edited flag, last pad |
  | Harp | chord colour |
  | Bass | patch, glide |
  | Grain | scan position, density |

- Events are copied without runtime flags (`open`, `skipOnce`); a note still being held at save time is saved with the length it has so far.
- `Session.restore(data)` checks everything as it goes (unknown instruments become the default, ticks outside the loop are dropped, numbers are clamped), applies it, reconfigures each track's effects, and silences anything playing first.

**Tests:** full round trip in the running game (record on all four tracks with bends, chord colours, kit edits, effects, swing, mutes; snapshot → encode → decode → restore into a fresh boot → identical); invalid values are fixed up, not trusted; runtime flags never saved; a held note mid-save comes back with a length.

---

## C3 · Autosave 📱

- `src/autosave.lua`: every 10 s, snapshot + encode; if the text differs from the last one written, write it to the other slot with the next sequence number.
- Also on `love.quit` and `love.focus(false)`.
- On boot (after sounds are built): read both slots, restore the newest that decodes and has `format == 1`; toast `SESSION RESTORED`. If neither works: fresh session (and a toast if a file existed but was unreadable).
- Print the save folder and each save's size and time to `log.txt`.
- Holding notes or recording doesn't delay saving; the snapshot handles open notes (C2).

**Tests:** fake in-memory `love.filesystem`; nothing written while unchanged; a change is written within 10 s; slots alternate and the sequence number rises; quit writes immediately; boot restores the newest slot; a corrupted newest slot falls back to the older one; a newer `format` is ignored; no files → fresh session.

**Device check:** where the files land, how long a save takes (should be a few ms), and that a session survives a normal quit *and* holding the power button.

---

## C4 · Fresh session 📱

- New mode `NEW` while `L2 + R2 + SELECT` are held; after 1 s it fires once, with the hold shown as a filling ring and a hint ("HOLD TO START A FRESH SESSION").
- Clears every track's events and mutes, silences everything, and pushes one undo entry holding the whole previous session's notes and mutes, so `L2 + R2 + LEFT` restores it.
- Tempo, key, scale, bars, instruments, sounds, settings and effects stay as they are.
- `L2 + R2` + face / `LEFT` / `START` keep working as today (erase, undo, clear track); the hold only starts when `SELECT` joins.
- Confirm the save folder on the device and, if agreed, move it into the port folder via `PocketGroove.sh`.

**Tests:** a short press does nothing; a 1 s hold clears all four tracks once (not repeatedly while still held); settings, instruments and tempo survive; undo brings back every note and mute; existing erase / undo / clear combos still work.

---

## Exit checklist for Phase C

- [ ] `python3 tests/run.py` green
- [ ] Quit and relaunch: the session is back exactly
- [ ] Power off mid-jam: at most ~10 s lost, and the game still boots
- [ ] A corrupted save never stops the game from booting
- [ ] Fresh-session hold works and is undoable
- [ ] Save folder known (and in the port folder, if agreed)

## Later (not Phase C)

- Named pattern slots A–H and a chain = "song" (Phase J); the save format leaves room for them.
- Export to `.wav` (Phase J).
