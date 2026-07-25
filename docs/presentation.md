# The Triadex Muse: Deterministic Composition Machine
## A SuperCollider Implementation

### Presentation Notes (30 min: talk + demonstration)

---

## 1. Historical Context (5 min)

The Triadex Muse is a deterministic algorithmic composition device designed
by Edward Fredkin and Marvin Minsky at MIT in 1969, commercially released
by the Triadex company in 1972. It is one of the first algorithmic music
machines: a device that composes, not synthesises.

The Muse contains no randomness. Its entire output is determined by
eight slider positions and an initial state. Yet it produces melodies
that sound composed, surprising, and varied. This paradox sits at the
centre of the instrument's interest.

Maryanne Amacher used the Muse extensively during her MIT fellowship at
the Center for Advanced Visual Studies (1972-1976). She created her
unpublished *Tone and Interval Studies* (18 quarter-inch tapes, 1976-78)
using Minsky's Muse, some labelled "in collaboration with Minsky."
Amacher operated the Muse at approximately 3000 Hz to produce standing
wave phenomena and otoacoustic emissions in the listener's ear. Her
*Additional Tones* workbook (Workbook IV, 1976/rev. 1987) documents her
systematic experiments with difference tones, binaural beats, and
fundamental tracking using the Muse as stimulus generator.

The Amacher archive (approximately 200 boxes of notebooks, scores,
tapes, and recordings) is held at the New York Public Library for the
Performing Arts.


## 2. Instrument Logic (8 min)

### Architecture

The Muse is a clocked state machine. On each tick:
1. Read four theme slider sources, compute XNOR (feedback bit)
2. Advance binary counters
3. On every second tick: advance the shift register (insert feedback bit)
4. Read four interval slider sources to form a 4-bit note value
5. Map the note value through an 8-note scale


### Control Flow Diagram

```
                    CLOCK TICK
                        |
                        v
    +-------------------------------------------+
    |           THEME SLIDERS (W,X,Y,Z)         |
    |     each selects one of 40 sources         |
    +-------------------------------------------+
          |       |       |       |
          v       v       v       v
    +-------------------------------------------+
    |              XNOR GATE                     |
    |   new_bit = 1 XOR w XOR x XOR y XOR z     |
    +-------------------------------------------+
                        |
                        | new_bit
                        v
    +-------------------------------------------+
    |         5-BIT BINARY COUNTER               |
    |    count32: 0-31, increments every tick     |
    |    provides C 1/2, C1, C2, C4, C8          |
    +-------------------------------------------+
                        |
                   bit 0 falls?
                   (every 2nd tick)
                        |
               yes      |      no
                |               |
                v               |
    +------------------------+  |
    | DIVIDE-BY-3 COUNTER    |  |
    | count6: provides C3,C6 |  |
    +------------------------+  |
                |               |
                v               |
    +------------------------+  |
    | 31-BIT SHIFT REGISTER  |  |
    | B1...B31               |  |
    | shift left, insert     |  |
    | new_bit at B1          |  |
    +------------------------+  |
                |               |
                +-------+-------+
                        |
                        v
    +-------------------------------------------+
    |        40-POSITION SOURCE TABLE            |
    |                                            |
    |  pos 0:  OFF (always 0)                    |
    |  pos 1:  ON  (always 1)                    |
    |  pos 2:  C 1/2  (count32 bit 0)           |
    |  pos 3:  C1     (count32 bit 1)           |
    |  pos 4:  C2     (count32 bit 2)           |
    |  pos 5:  C4     (count32 bit 3)           |
    |  pos 6:  C8     (count32 bit 4)           |
    |  pos 7:  C3     (count6 bit 2)            |
    |  pos 8:  C6     (count6 bit 3)            |
    |  pos 9:  B1     (shift register bit 0)    |
    |  pos 10: B2     (shift register bit 1)    |
    |  ...                                       |
    |  pos 39: B31    (shift register bit 30)   |
    +-------------------------------------------+
          |       |       |       |
          v       v       v       v
    +-------------------------------------------+
    |       INTERVAL SLIDERS (A,B,C,D)           |
    |     each selects one of 40 sources         |
    |                                            |
    |     A = bit 0 (weight 1)                   |
    |     B = bit 1 (weight 2)                   |
    |     C = bit 2 (weight 4)                   |
    |     D = bit 3 (octave / 8)                 |
    +-------------------------------------------+
                        |
                   DCBA (4 bits)
                   0-15 note value
                        |
                        v
    +-------------------------------------------+
    |            SCALE MAPPING                   |
    |                                            |
    |  pitch = scale[DCBA & 7]                   |
    |        + scale[7] * (DCBA >> 3)            |
    |                                            |
    |  Lower 3 bits (ABC) index the 8-note      |
    |  scale. Bit D adds the interval of         |
    |  equivalence (octave, tritave, or any      |
    |  interval defined by scale[7]).            |
    +-------------------------------------------+
                        |
                        v
                   PITCH OUTPUT
              (semitones from root,
               float precision)
```


### Key Properties

**Determinism:** Given 8 slider positions and initial state (c32=1, c6=0,
sr=0), the output is fully determined for all time. No randomness anywhere
in the system.

**Temporal asymmetry:** Counter sources (C 1/2 through C8) produce
periodic patterns at powers-of-two rates. Shift register sources
(B1-B31) produce aperiodic-seeming patterns driven by the XNOR feedback.
The interplay between these two source types is where the Muse's
melodic complexity originates.

**Feedback topology:** The theme sliders select sources that feed back
into the shift register. If all theme sliders point to OFF, the SR fills
with 1s and the sequence becomes purely counter-driven. If theme sliders
read from SR positions, the feedback creates complex nonlinear dynamics.

**40 sources, 8 selectors:** Each of the 8 sliders chooses from the
same 40-position source table. The space of all configurations is
40^8 = 6.55 * 10^12. Each configuration produces a unique infinite
sequence.


## 3. SuperCollider Implementation (5 min)

### Architecture

```
+------------------+
| TriadexMuse      |  Pure algorithm. No audio, no GUI.
| (engine)         |  step() -> pitch (Float or nil)
+--------+---------+
         |
         v
+------------------+
| TriadexMusePlayer|  SynthDefs, TempoClock, effects.
| (audio)          |  7 synthesis types, sync, pan.
+--------+---------+
         |
         v
+------------------+
| TriadexMuseGUI   |  Two-panel: sliders + source matrix.
| (interface)      |  Shift register viz, melody history.
+--------+---------+
         |
         v
+------------------+
| TriadexMuse      |  One-call launcher. Server boot,
| Application      |  lifecycle. Sync for multiple instances.
+------------------+
```

Each layer is independent. The engine can be used headless for
algorithmic composition, pattern integration, or batch analysis
without any server or GUI.


### Synthesis Types

| Type     | Description                                          |
|----------|------------------------------------------------------|
| faithful | Band-limited square wave (Pulse), matching hardware  |
| sine     | Pure SinOsc                                          |
| saw      | Band-limited sawtooth with gentle LPF                |
| fm       | 2-operator FM (mod ratio 3.51)                       |
| pluck    | Karplus-Strong via Pluck UGen                        |
| dpoae    | Two-tone DPOAE stimulus (f1/f2 ratio ~1.22)         |
| enhanced | Selectable waveform + filter + reverb + delay        |


### Synced Instances

Multiple Muse instances share a single TempoClock. One instance drives
tempo; others are tempo-locked and can be offset by fractional beats.
Each instance has independent slider configuration, scale, synthesis
type, and base frequency. The shared clock ensures the internal
counters advance simultaneously (as with the original hardware's
sync jack).

```supercollider
// Primary Muse
~m1 = TriadexMuseApplication.run(baseNote: 60, tempo: 4);

// Second Muse, synced, starting half a beat later
~m2 = TriadexMuseApplication.runSynced(baseNote: 72, beatOffset: 0.5);
```


## 4. Scale System (2 min)

The original hardware used a resistor network divider producing
fixed intervals. This implementation replaces the network with a
configurable 8-value float array, enabling:

- **12-TET diatonic/chromatic** (Major, Dorian, Blues, Chromatic, etc.)
- **Microtonal equal divisions** (7-EDO, 5-EDO, 19-EDO, 31-EDO)
- **Just intonation** (JI Major, 7-Limit, Partch Diamond, Young WTP)
- **Non-octave systems** (Bohlen-Pierce Lambda, Carlos Alpha/Beta/Gamma)
- **Historical** (Fokker periodicity blocks, Wilson Hexany, Xenakis Sieve)
- **Scala .scl file import** (full cent precision)

The interval of equivalence (scale[7]) is not hardcoded to 12 semitones.
For Bohlen-Pierce it is 19.02 (the tritave); for Carlos Alpha it is
5.46 (non-repeating). The D bit (octave slider) adds this value,
whatever it is.

37 scale presets are included. The same slider configuration sounds
fundamentally different in each scale, raising the question: where
does the Muse's "musicality" reside? In the logic, or in the tuning?


## 5. Amacher Connection (5 min)

### Context

Amacher's *Additional Tones* workbook (Workbook IV, 1976/rev. 1987)
documents systematic experiments with psychoacoustic phenomena:

- Difference tone formulas: F_d = F_2 - F_1
- 2nd-order beats of mistuned consonances (near-octave, near-5th,
  near-4th)
- Fundamental tracking (the auditory system perceiving a missing
  fundamental from the repetition rate of combined stimuli)
- Binaural beats: perceived even below hearing threshold
  (Liebenhardt, Berlin)

Her notes reference specific frequencies (440 Hz, 293 Hz), the
"Well Tuned Ear" range (800-6,000 Hz), and explicitly mention
"standing wave phenomena w/ 3,000 Hz Muse business."

She also used a Bode Ring Modulator to process the Muse output,
producing sum and difference frequencies from two inputs.

### Implementation Connection

The DPOAE synthesis type in this implementation generates two-tone
stimuli at ratio ~1.22 (optimal for evoking the cubic difference
tone 2f1-f2 in the listener's cochlea). This directly implements
the stimulus paradigm Amacher explored. Combined with the synced
dual-Muse setup, the implementation can reproduce the four-tone
psychoacoustic stimulus field described in her workbook.

### Archive

The Maryanne Amacher papers at the NYPL contain 18 quarter-inch
tapes of *Tone and Interval Studies* made with the Muse. The
notebooks in the archive likely contain the slider configurations
she used. No technical analysis of these materials has been
published.


## 6. Presets (reference)

20 factory presets transcribed from J. Donald Tillman's JavaScript
emulation:

| Name              | Interval (A,B,C,D) | Theme (W,X,Y,Z)    |
|-------------------|---------------------|---------------------|
| Michaels Tune     | B7, B8, B5, OFF     | OFF, B4, B23, OFF   |
| Musers Waltz      | B10, B8, B7, OFF    | ON, C4, B1, B2      |
| Scale             | C1, C2, C4, OFF     | OFF, OFF, OFF, OFF  |
| Eds Rhythm Piece  | B6, B6, B6, C2      | OFF, OFF, B1, B31   |
| The Crazy Cuckoo  | C1, B1, B31, C8     | OFF, OFF, B1, B31   |
| Birds 1           | B1, B2, B3, C4      | B30, B31, B31, B31  |
| Birds 2           | B28, B29, B30, B30  | B30, B31, B31, B31  |
| Dorian Muse       | ON, B1, B3, C8      | B1, B16, OFF, OFF   |
| Mesopotamia       | C2, B5, B9, OFF     | C8, B9, B24, C4     |
| Swiss Yodeler     | B8, C1, B16, OFF    | B22, B21, B16, OFF  |
| Rons Rhapsody     | B6, B9, B6, C 1/2   | B31, C4, OFF, C8    |
| Christmas Bells   | B31, B30, B29, B28  | B28, B29, B30, B31  |
| Marvins Yodel     | B2, B17, B9, B25    | B16, OFF, B15, C1   |
| Federal Row       | B14, B5, B12, B2    | B21, B24, C2, OFF   |
| Als Surprise      | B1, B5, B7, C 1/2   | C8, B1, B7, B11     |
| Meditation        | B1, B31, B14, OFF   | OFF, OFF, B16, B31  |
| Flat Baroque      | C1, B15, B1, C 1/2  | B30, B29, B24, OFF  |
| Polka             | B1, B13, B11, C 1/2 | C8, B11, B7, B1     |
| Rhyming Couplets  | B1, B2, C4, C8      | OFF, OFF, B31, C4   |
| Yodle             | C8, B2, B5, B6      | OFF, OFF, B1, B31   |


## 7. Sources and References

### Primary Sources

- Fredkin, Edward and Minsky, Marvin. Triadex Muse (hardware), 1969/1972.
  MIT, Cambridge, MA.
- Tillman, J. Donald. "The Triadex Muse" (JavaScript emulation and
  technical documentation). https://till.com/articles/muse/
- Tillman, J. Donald. "The Triadex Muse, An Interactive Simulation"
  (multi-unit version). https://till.com/muse/barbican/
- Triadex Muse User Manual. Reproduced at:
  https://till.com/articles/muse/TriadexMuseUserManual.pdf

### Amacher

- Amacher, Maryanne. *Additional Tones* Workbook IV (1976/rev. 1987).
  Unpublished manuscript. Maryanne Amacher papers, NYPL.
- Amacher, Maryanne. *Tone and Interval Studies* (1976-1978). 18 tapes.
  Maryanne Amacher papers, NYPL.
- Amacher, Maryanne. *Head Rhythm 1 and Plaything 2* (1999). Tzadik.
- Cimini, Amy. *Wild Sound: Maryanne Amacher and the Tenses of Audible
  Life*. Oxford University Press, 2022.
- Schneider, Bret. "Groundwork for a Study of Maryanne Amacher."
  *Caesura*. https://caesuramag.org/posts/bret-schneider-groundwork-for-a-study-of-maryanne-amacher

### Psychoacoustics

- Roederer, Juan G. *Introduction to the Physics and Psychophysics of
  Music*. Springer, 1975. (Referenced in Amacher's workbook.)
- Oster, Gerald. "Auditory beats in the brain." *Scientific American*
  229.4 (1973): 94-102. (Referenced in Amacher's workbook.)
- Kemp, David T. "Stimulated acoustic emissions from within the human
  auditory system." *JASA* 64.5 (1978): 1386-1391.

### Technical

- Wikipedia: Triadex Muse. https://en.wikipedia.org/wiki/Triadex_Muse
- Computer History Museum: "Generative Music with the Muse."
  https://computerhistory.org/blog/generative-music-with-the-muse/
- Maryanne Amacher papers, NYPL finding aid:
  https://archives.nypl.org/mus/185461


## 8. Demonstration Plan (during the 30 min)

Suggested live demonstrations to interleave with the talk:

1. **Scale preset** (with talk section 2): run the "Scale" preset to
   show pure counter-driven ascending/descending. Audience sees the
   relationship between counter bits and note values directly.

2. **Preset comparison** (section 2/3): switch between "Meditation"
   (sparse, slow) and "Birds 1" (dense, fast SR feedback) to show
   how slider position dramatically changes character.

3. **Synthesis types** (section 3): same preset ("Musers Waltz"),
   cycle through faithful -> sine -> fm -> pluck -> dpoae. Same
   notes, completely different sonic identity.

4. **Scale switching** (section 4): same slider config, switch
   between Major -> Bohlen-Pierce -> Carlos Alpha -> Partch Diamond.
   The "same" melody becomes unrecognisable.

5. **Synced dual Muse** (section 5): two instances at a 5th apart,
   faithful synthesis, slow tempo. Point out emergent intervals
   and near-consonances.

6. **DPOAE mode** (section 5): switch both synced Muses to dpoae
   synthesis. Ask audience to listen for tones not present in the
   speakers (otoacoustic emissions).
