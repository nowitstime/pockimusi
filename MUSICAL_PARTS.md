# PocketGroove — What Each Part Needs

A loop is built from a few **parts**, each with its own job. This file asks, for each part, what players actually do in it: the moves, the decorations, the timing. Then it asks what that means for our instruments. The aim is to judge an instrument by **the part it plays**, not by how clever its controls are.

Companion to [SPEC.md](SPEC.md) (what is built), [FEEDBACK.md](FEEDBACK.md) (how it feels) and [FUTURE_INSTRUMENTS.md](FUTURE_INSTRUMENTS.md) (ideas).

Legend in the coverage tables: ✅ easy, a natural move · ◐ possible but awkward or partial · — missing

---

## 1. The parts

| Part | Job | Moves how fast | Our instruments |
| :-- | :-- | :-- | :-- |
| **Rhythm** | Time, groove, energy | Every 1/8 or 1/16 | Drums, Hand Drums |
| **Bass** | Ties the rhythm to the harmony; says what the chord's root is | Every beat or two | Bass |
| **Chords** | Sets the harmony and its rhythm | Once or twice a bar, with a rhythm on top | Chord Harp, Strum |
| **Texture** | Fills the space, sets the mood, glues the rest | Over bars | Pad |
| **Lead** | The tune: what you sing back afterwards | Anything from long notes to fast runs | Lead / Arp, Dial, Slide, Valves |

Two observations straight away:

1. **Four instruments play lead.** That is fine for a lab, but only if each owns a *different slice* of what a lead does (§6.1). Otherwise they compete and the weakest go.
2. **Only one instrument sets chords.** The Chord Harp is the chord source. Strum *follows* chords; it doesn't set them (§3.4).

---

## 2. Lead

### 2.1 Moves on the scale

Most tunes, in most styles, are made from a short list of moves:

| Move | What it is | Example (C major) | Notes |
| :-- | :-- | :-- | :-- |
| **Step** | To the neighbouring scale note | C D E D C | The most common move by far. Melodies are mostly steps |
| **Repeated note** | The same note again, re-struck | E E E E | Riffs and hooks live on rhythm, not pitch |
| **Small leap** | A third: usually to another chord tone | C E G | Outlines the chord |
| **Big leap** | A fifth, sixth or octave | C → A, C → C' | For emphasis. Usually followed by a step back the other way ("leap, then fill") |
| **Run** | Several fast steps in one direction, aimed at a target note | C D E F **G** | Lands on a chord tone on a strong beat |
| **Neighbour** | Out and back by a step | C D C · C B C | Decoration around a held idea |
| **Enclosure** | Approach the target from above and below | D B **C** | Jazz and bebop staple; makes the target land hard |
| **Arpeggio** | The chord's notes one at a time | C E G C' G E | Lead/Arp's whole job |
| **Sequence** | The same shape, started on another degree | C D E · D E F · E F G | How tunes build without new ideas |
| **Pedal / pivot** | Alternate a moving line with one fixed note | G C G D G E | Common in riffs and guitar leads |
| **Blue note** | The ♭3 (or ♭5, ♭7) bent toward the natural note | E♭ ↗ E | The core of blues, rock and soul leads. Lives *between* scale notes |

**Where notes land:** chord tones (1, 3, 5, 7) on strong beats, passing notes between them on weak beats. A tune feels "right" when its strong-beat notes agree with the chord.

**Shape:** a phrase usually has one high point, often near its end. Range matters more than speed: a tune that sits on three notes for four bars and then leaps is more memorable than one that runs everywhere.

### 2.2 Decorations

| Kind | Decoration | What it is |
| :-- | :-- | :-- |
| Pitch | **Bend into** | Start a step or half step low and rise into the note (guitar, voice, sax) |
| | **Bend and release** | Rise to a note and fall back without re-striking |
| | **Slide / glide** | Move continuously from one note to the next (portamento, synth leads, trombone, slide guitar) |
| | **Vibrato** | A wobble on long notes. Usually starts late in the note, not at the attack |
| | **Fall-off** | The pitch drops away at the end of a note (brass "fall", guitar "dive") |
| | **Scoop** | Short bend up into the note on its attack |
| | **Grace note** | A very short note just before the main one |
| | **Trill** | Fast alternation with the neighbour note |
| | **Turn / mordent** | Quick neighbour figure around the note (above, note, below, note) |
| Attack | **Slur (legato)** | The new note continues the old one: no new attack. Hammer-on, pull-off, brass slur |
| | **Tongued / re-struck** | Every note has its own attack. Picked guitar, tongued brass, synth retrigger |
| | **Staccato** | Short, separated notes |
| | **Accent / ghost** | One note louder; one barely there |
| Level | **Swell** | A long note that grows louder |
| | **Decay** | A long note that fades away (plucked sounds do this on their own) |

**Slur against re-strike is a per-note choice.** A real player decides it note by note: slur the run, tongue the repeated notes, accent the last one. An instrument that fixes it for the whole track (or the whole patch) loses most of the phrasing. This is the root of the Dial note in FEEDBACK.md: with a patch whose loudness fades after the attack, a roll of slurs fades away, because nothing is ever re-struck.

### 2.3 Timing

| Move | What it is | In a looper with a fixed tempo |
| :-- | :-- | :-- |
| **Rests** | Silence between phrases | Half of phrasing. A lead that never stops tires the ear |
| **Syncopation** | Notes on the off-beats, not the beats | Needs the grid to allow 1/8 and 1/16 off-beats (it does) |
| **Anticipation** | Land the next phrase's first note an 1/8 early | Very common in pop and funk |
| **Laid back / pushed** | Play slightly behind or ahead of the beat | A per-track offset or looser quantise. Not built |
| **Density change** | Switch between long notes and fast runs | This is what usually reads as "a tempo change" in a lead. Lead/Arp has ×2 on `L1 + R1`; the others rely on the player |
| **Triplets against straight** | Three notes where two are expected | Needs a triplet grid on the track (`1/8T`) |
| **Real tempo change** | Rubato, slowing at an ending | Transport-wide; not a lead's job in a groove. Not planned |

### 2.4 Phrasing

- **Phrases are two or four bars.** A loop of 2 or 4 bars holds one phrase or a call and its answer.
- **Question and answer:** the first phrase ends unresolved (on 2, 5 or 7); the second ends home (on 1 or 3).
- **Motif and variation:** repeat a short idea, change its ending. The looper already invites this: overdub a variation on the second pass.
- **Call and response** with another part: the lead answers the chords' rhythm, or a drum fill.

### 2.5 What a lead instrument needs

In order of how much it matters:

1. **Steps must be the cheapest move,** and both directions equally cheap.
2. **A choice, per note, between slur and re-strike.** Ideally one thumb chooses the note and the other decides the articulation, or it follows naturally from the gesture.
3. **Repeated notes** without moving to another note.
4. **Chord tones easy to find** for strong beats; leaps to them without a hunt.
5. **One expressive pitch move:** bend into, glide, or vibrato. Each instrument doesn't need all of them, but it needs at least one done well.
6. **Rests:** letting go must be instant and clean, and a sound that rings must be cut-able.
7. **Range:** at least an octave and a half without a shoulder.
8. **Notes outside the scale** for blue notes and chromatic passing, without breaking the in-scale default.

### 2.6 Coverage today

| Move | Lead / Arp | Dial | Slide | Valves |
| :-- | :-- | :-- | :-- | :-- |
| Step | ◐ D-pad to a neighbouring direction | ✅ roll to the next position | ✅ `←/→` steps a scale note | ◐ change the valve fingering |
| Repeated note | ✅ re-press `B` | ✅ lift and press again | ✅ re-press | ✅ tongue with the other shoulder |
| Chord tone, strong beat | ✅ 1, 5, 8 on the D-pad | ✅ 1 3 5 7 on single buttons | ◐ by ear | ✅ open notes are chord tones |
| Big leap | ◐ D-pad across, or shoulder | ◐ a jump across the dial slurs | ◐ octave on a shoulder | ✅ open note on the D-pad |
| Run | ◐ arp `SCALE` pattern (not aimed) | ✅ fast roll | ◐ hold `↑/↓` (a glide, not notes) | ◐ |
| Trill | — | ✅ rock between a button and its pair | — | ◐ rock a valve |
| Slur vs re-strike, per note | ◐ held `B` glides; a new press strikes | — slurs only (the FEEDBACK note) | ◐ `B` holds and slides | ✅ shoulder strikes, valves slur |
| Bend into a note | — | — | ✅ press, then slide | — |
| Glide | ✅ hold and move | ◐ the `GLIDE` row, every move | ✅ its whole idea | ◐ slurs glide |
| Vibrato | — | ◐ with accent only | ◐ with `X` only | — |
| Fall-off | — | — | ✅ `Y` dive | — (a brass staple) |
| Staccato / length | — | — | — | ◐ short breath |
| Notes outside the scale | — | ✅ `←/→` flat / sharp | ✅ `SNAP` off | ✅ `CHROMATIC` |

---

## 3. Chords

### 3.1 What the part does

The chord part decides **which chord** and **when it changes** (the *harmonic rhythm*), then plays it **with a rhythm** of its own (the *comping*). The two are separate jobs, and good chord instruments keep them on separate hands.

### 3.2 Moves

| Move | What it is |
| :-- | :-- |
| **Progression** | The loop of chords: I–V–vi–IV, vi–IV–I–V, ii–V–I, i–♭VI–♭VII, I–IV |
| **Harmonic rhythm** | One chord per bar, two per bar, or a change pushed an 1/8 early onto the "and" of 4 |
| **Voicing and inversion** | Which notes, in which order, how spread. The same chord sounds very different close or wide |
| **Voice leading** | Moving to the next chord by the nearest notes: common tones stay, the rest move by step. The single biggest thing that makes changes sound smooth |
| **Colour** | Seventh, ninth, sus4, add9 (the harp's `COLOUR` row) |
| **Suspension** | sus4 resolving to the third inside one chord: movement without a chord change |
| **Passing / approach chord** | A quick chord on the way to the next (V of V, a ♭VII before I) |
| **Pedal** | One bass note under changing chords |

### 3.3 Rhythm and decoration

| Pattern | What it is | Styles |
| :-- | :-- | :-- |
| **Sustained** | Whole notes, the chord held | Ballads; overlaps with texture |
| **Stabs** | Short chords on the off-beats | Reggae skank, house, funk horns |
| **Strummed pattern** | Down, down-up, up-down-up | Pop, folk, rock |
| **Broken / arpeggiated** | The chord's notes in turn | Ballads, harp, piano |
| **Muted strum / chuck** | A damped, percussive strum | Funk, reggae |
| **Push** | Change on the "and" of 4, held across the bar line | Pop, rock |
| **Roll** | The notes spread quickly from low to high | Harp, piano, guitar |

### 3.4 What this means for our instruments

- **Chord Harp:** chooses the chord well (D-pad, nine chords) and plays *broken* chords well (a string per button). It can't *strum* or *stab* easily: four presses are needed for a full chord.
- **Strum:** plays rhythm well (shoulders strum, both damp). But it *follows* chords: the thumbs pick a degree and the strings, and Harmony picks the chord. It can't be the chord source as it stands.
- **For Strum to be a chord source** it would have to *choose* chords, like the Harp: the D-pad as the Harp's nine-chord map, the face buttons as voicing (open, close, high, add a colour), the shoulders as the strum. That makes it "a strummed Chord Harp": a big but clear change.
- **A separate chord track** is the other route: chords chosen on a track that makes no sound, and every other instrument follows. The Harp's `SILENT` patch already does this. A dedicated chord instrument could make choosing chords easier (step through a progression, set the change timing), without having to play them in time.
- **Recommendation:** try Strum in a `CHORDS` mode first. It's the most musical answer (guitarists set the harmony by strumming it) and it reuses the Harp's chord map. Keep the `SILENT` harp as the "chord track" until a dedicated one is clearly needed.
- **Voice leading for everyone:** whichever instrument chooses chords, the followers (Pad, Strum, Harp voicings) should pick the inversion nearest the previous chord. Worth checking what Pad and Harp do today; it's probably the cheapest big improvement to how changes sound.

---

## 4. Texture

### 4.1 What the part does

Texture sits behind everything: it fills the frequency gap between bass and lead, sets the mood, and makes the loop feel like a place. It moves **slowly**, over bars, and is mostly about *how the sound changes* rather than which notes play.

### 4.2 Moves

| Move | What it is |
| :-- | :-- |
| **Sustained chord** | The current chord, held, following the changes |
| **Drone** | One note (or root and fifth) held under every chord |
| **Swell** | Fades in over a bar or two, landing on a downbeat |
| **Filter sweep** | Brightness opening or closing slowly over 4 to 8 bars |
| **Movement** | Shimmer, detune, slow wobble: the sound is never still |
| **Inner line** | One voice moves by step while the others hold |
| **Register choice** | High and airy, or low and warm, to leave room for lead and bass |
| **Density** | Two notes or six: thin for verses, thick for drops |
| **Rhythmic texture** | A pad that pulses in time: gated, or ducked by the kick ("pumping") |
| **Slow countermelody** | Long notes that move against the lead |

### 4.3 What this means for our instruments

- **The Pad covers most of this:** voicings, swell (`X`), brightness and movement recorded as sweeps, follow on/off.
- **A texture part shouldn't need a thumb held down for eight bars.** A **latch** (press once, it holds until pressed again) frees the hands, and lets you record the next track while the pad keeps going. Not built.
- **Drone:** close with `A` (open: root, fifth, octave) and `FOLLOW` off, but a true "hold this note through every chord" is missing.
- **Pumping / gating:** a rhythmic texture is a big modern move and the engine is close (the punch-in effects already change voices in time). A `PULSE` row on the Pad (off, 1/4, 1/8, kick-ducked) would cover it.
- **Long gestures are good:** a texture instrument should reward slow, small movements that are recorded, not fast playing.

---

## 5. Rhythm

### 5.1 Moves

| Move | What it is |
| :-- | :-- |
| **Backbone** | Kick and snare: backbeat on 2 and 4, four-on-the-floor, breakbeat |
| **Subdivision** | Hats in 1/8 or 1/16; open hat on the off-beat |
| **Syncopated kick** | Kicks on the off-beats against a steady snare |
| **Ghost notes** | Quiet snare notes between the main hits: the groove's glue |
| **Accent pattern** | Hats louder on the beat, softer between |
| **Fill** | A change at the end of a phrase (bar 4 or 8), leading into the next |
| **Roll / flam / ratchet** | Fast hits, doubled hits, triple hits |
| **Crash** | Marks the downbeat of a new section |
| **Interlocking percussion** | Shaker, conga, clap in patterns that fit between the kit's |
| **Drop / break** | The kick or everything drops out for a bar |
| **Build** | Rising density (a snare roll speeding up) into a drop |

### 5.2 Feel

- **Swing** (built), **humanising** (Drums `VARIATION`, built), **per-instrument push and pull** (the snare a touch late): not built.
- **Half-time and double-time:** the same tempo, the backbeat moved. This is what makes a groove feel faster or slower without changing tempo.
- **Variation over time:** the same groove with small changes every 2 or 4 bars. `VARIATION` and chance hits cover the small ones; sections are FUTURE_PLANS §8 (song building).

### 5.3 What this means for our instruments

- **Drums** covers the moves well: dynamics, flam, ratchet, grid-locked repeat, variation, chance hits, fills.
- **Hand Drums** covers what two hands add: alternating strokes for rolls, and two independent voices for interlocking patterns (a hand on the hats, a hand on the drums).
- **Missing:** a build (repeat rate rising over a bar), and section-level moves (crash on the first beat, drop-outs) that belong with song building.
- **Split the work:** Drums for the kit backbone, Hand Drums for percussion layered over it. That gives both a clear role.

---

## 6. Bass, briefly

Not part of the original question, but it bridges rhythm and chords, so the same lens applies: root on the downbeat, fifth and octave, **approach notes** (a step or half step into the next chord's root on beat 4), octave pops, notes locked to the kick, rests, slides into notes (808), dead notes. Bass already has root, low fifth and octave one move away, glide and staccato. **Approach notes** are the obvious missing move. They need to know the *next* chord, which Harmony can tell from the chord track.

---

## 7. How this shapes the direction

### 7.1 Give each lead instrument its slice

Four lead instruments only make sense if each is the best at something different:

| Instrument | Slice of lead playing | Sounds it wants | Its key feature to get right |
| :-- | :-- | :-- | :-- |
| **Dial** | Stepwise melody, runs, trills: scale fluency | Sustaining leads that keep their level; plucks that strike | Slur vs re-strike per note |
| **Valves** | Horn phrasing: tongued riffs, slurs, swells, falls | Brass: trumpet, horn section, muted horn | Fall-offs and swells; brass patches |
| **Slide** | Voice-like expression: bends, glides, vibrato, blue notes | Theremin, slide guitar, singing synth lead | Bending *into* notes; delayed vibrato |
| **Lead / Arp** | Machine patterns: arpeggios and sequences | Square, saw, plucks | Pattern variety; latch |

If two instruments end up doing the same slice, that's the moment to pick one.

### 7.2 A shared expression toolkit

Several decorations belong to every melodic instrument and should be built **once**, in shared code, then given to each instrument as a control that suits it:

| Shared piece | What it gives | Who wants it first |
| :-- | :-- | :-- |
| **Articulation per note** | Slur, re-strike, staccato as an event field | Dial (re-strike), Valves |
| **Delayed vibrato** | Vibrato that starts part-way into a long note | Slide, Valves, Lead |
| **Bend into** | Start low and rise into the note on its attack | Slide, Dial, Lead |
| **Fall-off** | The pitch drops at the note's end | Valves, Slide (it has `Y`) |
| **Swell** | Level rises through a held note | Valves, Pad |

This overlaps with *Motions* (FUTURE_INSTRUMENTS §4.6), which puts grace notes, runs and trills on D-pad gestures. The toolkit is the engine half; Motions is one way to trigger it.

### 7.3 Sounds follow parts

A patch wave by part, to fix the "needs patches" notes:

| Part | Wanted |
| :-- | :-- |
| Lead | Sustaining leads that keep their level through slurs; a singing sine/triangle lead; a vocal "ooh" |
| Brass | Trumpet, horn section, muted horn, brass stab |
| Chords | Bowed strings for Strum's bow; electric guitar (clean and muted); organ |
| Texture | Air / noise pad; a pulsing pad |
| Rhythm | More percussion one-shots for Hand Drums (shaker, conga, bongo, clap variants) |

Each patch could also carry a **default articulation** (plucky sounds re-strike on moves, sustained ones slur), which would fix most of the Dial note without any setting at all.

### 7.4 Decisions this raises

1. **Chord source:** Strum gets a `CHORDS` mode, or a dedicated chord track, or both (§3.4).
2. **Slur vs re-strike on Dial:** a row, a default per patch, a per-note gesture, or all three.
3. **Pad latch:** yes or no.
4. **Which shared expression piece first:** articulation per note looks like the one that unblocks the most.
5. **Roles in the default slots:** today 1 Drums · 2 Chord Harp · 3 Bass · 4 Pad (no lead). Is a lead in the default four more useful than the pad?

---

## 8. Questions to ask while playing

Use these during an instrument pass; write the answers in FEEDBACK.md.

- **Lead:** Can I play a phrase I can hum? Can I choose, note by note, whether it slurs or strikes? Can I leave a rest cleanly? Is there one expressive move that feels great?
- **Chords:** Can I change chord on time without thinking? Do the changes sound smooth? Can I play a rhythm, not just a chord?
- **Texture:** Can I set it going and leave it? Does it move on its own over the bars? Does it stay out of the way of bass and lead?
- **Rhythm:** Does it groove at 1/16 with swing? Can I make a fill at the end of a phrase? Do ghost notes and accents come easily?
- **Bass:** Does it lock with the kick? Can I walk into the next chord?
