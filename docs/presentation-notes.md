# The Triadex Muse — Presentation Notes

30-minute talk with live SC demonstration.
Audience: experts, enthusiasts, academics.

---

## OPENING (3 min)

**Screen: hero image (SC interface)**

"I came to this instrument through Xenakis. Specifically through
sieve theory. Xenakis developed sieves as a way to generate pitch
structures from the intersection and union of periodic residue
classes — take every 3rd element from a chromatic set, combine it
with every 5th, intersect with every 7th. The result is a scale
that is neither random nor conventional: it is arithmetically
determined, yet perceptually unpredictable."

"The Triadex Muse does something strikingly analogous, but in the
time domain. It was designed by Edward Fredkin and Marvin Minsky
at MIT in 1969 — not as a music project, but as an experiment in
emergent complexity from minimal rules. Inside the instrument,
a binary counter produces periodic signals at powers-of-two rates:
mod 2, mod 4, mod 8, mod 16. A divide-by-3 counter introduces a
non-power-of-two periodicity. The interval sliders select which of
these periodic streams are combined — via bitwise OR across 4 bits —
to form a pitch index. The result is a sieve-like structure: a
subset of an integer lattice determined by the coincidence of
multiple periodic processes."

"But where Xenakis constructed sieves as static pitch sets to be
deployed within a composition, the Muse generates them dynamically,
tick by tick, because a 31-bit shift register introduces aperiodic
feedback into the source pool. The sieve evolves. The scale the
Muse plays through at step 100 is not the same sieve it plays
through at step 1000."

"About 280 units were ever built. No randomness anywhere in the
system. No stored sequences. Eight slider switches are the only
input. The output is a monophonic square wave. And it sounds
composed."

"I will walk through the architecture, show the SuperCollider
reimplementation, and demonstrate what happens when the instrument
is extended beyond its original constraints — including a Xenakis
Sieve scale preset that makes this connection audible."

---

## I. HISTORICAL CONTEXT (3 min)

implementation of "Rest" is clearly musical reference  

**Screen: patent drawings (US3610801-drawings-page-2.png)**

"Fredkin was a computer scientist, Minsky an AI researcher. The Muse
was not a music project. It was an experiment in emergent complexity
from minimal rules. The patent (US 3,610,801, filed 1969, granted 1971)
describes the instrument as an 'automatic music composer' — language
that reflects the AI framing. Triadex, the company, produced about 280
units before folding."

"The instrument has eight 40-position slider switches. Four control
the THEME (feedback into the shift register). Four control the
INTERVAL (pitch selection). The configuration space is 40^8 — roughly
6.55 trillion possible settings. Each produces a unique infinite
sequence."

"Our primary technical reference is J. Donald Tillman's JavaScript
emulation, which reverse-engineered the circuit from surviving
hardware. The patent documentation fills in the rest."

---

## II. ARCHITECTURE DIAGRAM (8 min)

**Screen: architecture diagram (Screenshot 2026-05-18 at 10.08.04.png)**

Walk through left to right, following the five stages.
Point at each block as you describe it.

### Stage 1: TIMING

**Point to: CLOCK**

"Everything begins with a single clock oscillator. This is the tempo
knob on the original hardware. It produces a regular pulse — nothing
more. Every tick of this clock advances the entire machine by one step.
The tempo is the only continuous parameter on the instrument; everything
else is discrete, binary."

"The clock feeds three subsystems simultaneously: the 4-bit counter,
the 31-bit shift register, and the divide-by-3 counter. All three
advance together, but at different rates."

### Stage 2: BINARY SOURCES

**Point to: 4-BIT COUNTER**

"The 4-bit counter is a simple binary counter. It counts 0 through 15,
then wraps. It produces five binary signals — C 1/2, C1, C2, C4, C8 —
each toggling at half the rate of the previous one. C 1/2 changes every
tick. C1 changes every 2 ticks. C2 every 4. C4 every 8. C8 every 16.
These are perfectly periodic, perfectly predictable. They give the Muse
its rhythmic skeleton."

**Point to: DIVIDE-BY-3 COUNTER**

"The divide-by-3 counter is a modified Johnson counter. It advances
every second clock tick and produces two more binary signals: C3 and C6.
These cycle at rates that are incommensurate with the binary counter —
they don't align with powers of two. This is where rhythmic complexity
begins: C3 and C6 create a cross-rhythm against C1, C2, C4."

**Point to: 31-BIT LFSR (shift register)**

"The shift register is the heart of the instrument. 31 bits long — B1
through B31. On every second clock tick, the entire register shifts one
position to the left. A new bit enters at B1. That new bit comes from
the XNOR gate — which I will explain in a moment."

"The shift register provides 31 binary signals. Unlike the counters,
these are not periodic in any simple sense. They evolve according to
the feedback topology. The deeper positions — B20, B25, B31 — change
very slowly. They carry long-term memory of past states."


**additions

- logic modification in real time; 
- methodology for logic exposure; 
- increase gaps; 


**Pause. Gesture across all three blocks.**

"Together, these three subsystems produce 40 binary signals: 2 constants
(OFF = always 0, ON = always 1), 5 from the binary counter, 2 from the
divide-by-3 counter, and 31 from the shift register. These 40 signals
change at different rates — from every tick to once every billions of
ticks. This is the raw material of the Muse. Everything that follows
is selection and combination."

### Stage 3: PERMUTATION (Selector Matrix)

**Point to: SELECTOR MATRIX**

"This is the only part of the instrument the user controls. Eight
sliders, each with 40 positions. Each slider selects one of the 40
binary sources."

**Point to upper group: THEME sliders**

"The top four sliders — the THEME section — control the feedback.
They select four binary signals that feed into the XNOR gate. These
four signals determine what new bit enters the shift register at each
step. The theme sliders do not directly produce sound. They shape the
long-term evolution of the shift register — the 'character' or
'personality' of the melody."

"If all four theme sliders point to OFF, the XNOR gate always outputs 1.
The shift register fills with ones and the sequence becomes purely
counter-driven — perfectly periodic, completely predictable. Move even
one theme slider to a shift register position and you introduce
feedback. The sequence becomes aperiodic."

**Point to lower group: INTERVAL sliders**

"The bottom four sliders — the INTERVAL section — control pitch
directly. They select four binary signals that form a 4-bit number:
A is bit 0 (weight 1), B is bit 1 (weight 2), C is bit 2 (weight 4),
D is bit 3 (the octave bit). At each clock tick, these four bits are
read and combined into a value from 0 to 15."

**Point to annotation: 'each slider picks 1 of 40'**

"This is the key insight. Each of the eight sliders has access to the
same pool of 40 binary signals. A theme slider and an interval slider
can read from the same source. The slider position is the ONLY input.
Everything else — the counters, the shift register, the XNOR gate,
the scale — is fixed architecture."

### Stage 4: LOGIC

**Point to: XNOR GATE**

*Pronounced "ex-nor" — exclusive NOR, the inverse of XOR.*

"The XNOR gate asks a single question: do the four theme signals
agree? If yes, the output is 1. If any disagree, the output is 0.
This single bit feeds back into the shift register."

"This result feeds back to the shift register. The feedback arrow at
the top of the diagram — the dashed line running from the XNOR gate
back to the LFSR. This is what makes the Muse more than a counter.
The shift register's future depends on its own past, filtered through
whichever sources the theme sliders select."

**Point to: PITCH TABLE**

"The interval bits A, B, C form a 3-bit index (0-7) into an 8-note
scale. In the original hardware this was a resistor ladder producing
8 voltage levels — a fixed major scale. In our implementation it is
a programmable array. Any 8 values. Any tuning system."

**Point to: D -> OCTAVE x2**

"Bit D — the fourth interval slider — adds the interval of equivalence.
In 12-TET this is 12 semitones (one octave). In Bohlen-Pierce it is
19.02 semitones (one tritave). In Carlos Alpha it is 5.46 semitones.
The D bit doubles the frequency in standard tuning, but in our
implementation it adds whatever scale[7] contains."

### Stage 5: OUTPUT

**Point to: OUTPUT block (note + gate)**

"The output is two values: a pitch (from the interval sliders and
scale mapping) and a gate (from the XNOR logic — note on or off).
In the original hardware this drove a divide-down oscillator producing
a square wave. In our implementation it drives any of seven synthesis
types."

### Summary

**Gesture across the entire diagram.**

"No randomness. No stored sequences. All structure emerges from
deterministic binary logic. The 8 slider positions are the only input.
Everything else is fixed architecture. 40^8 = 6.55 trillion possible
configurations, each producing a unique infinite sequence. The question
the instrument poses is: where does the musicality come from? Not from
the scale — that can be changed. Not from the sliders — those are just
addresses. It comes from the interaction between periodic counter
sources and aperiodic shift register evolution. The meeting point of
predictability and feedback."

---

### DEMO 1: Scale preset (transition from architecture)

"Let me show you. The simplest case first — the 'Scale' preset.
All four theme sliders set to OFF. Interval sliders reading from
C1, C2, C4. Pure counter-driven sequence. You will hear the binary
counter literally counting in pitch."

    [Evaluate: TriadexMuseApplication.run; preset 'Scale']

"Now watch what happens when I move one theme slider to a shift
register position..."

    [Move theme slider in GUI, demonstrate character change]

---

## III. SC IMPLEMENTATION (3 min)

**Screen: SC interface + Tillman's JS side by side**

"Four layers, each independent. The engine is pure algorithm — no audio,
no GUI. It takes slider positions and returns a pitch as a float, or nil
for a rest. You can use it headless for batch analysis, pattern
integration, algorithmic composition."

"The player wraps the engine with SynthDefs, a TempoClock, and effects.
Seven synthesis types: faithful square wave matching the hardware; sine,
saw, FM, pluck for timbral variation; and DPOAE — a two-tone
psychoacoustic stimulus I will return to when we discuss Amacher."

"The GUI reproduces Tillman's JavaScript interface. Sliders on the left,
source matrix on the right. The matrix shows all 40 binary sources and
which ones each slider currently selects. Below, the shift register
state and melody history."

"The Application class handles lifecycle — server boot, SynthDef
registration, window management. One call to launch."

### DEMO 2: Preset comparison

"Two presets. First, 'Meditation' — theme sliders mostly OFF, interval
reading from deep shift register positions. Sparse, slow-changing."

    [Load Meditation preset]

"Now 'Birds 1' — theme sliders reading from B30, B31. Dense SR feedback.
Fast, unpredictable, chirping."

    [Load Birds 1 preset]

---

## IV. SYNTHESIS TYPES (3 min)

**Screen: GUI with Musers Waltz loaded**

"Same pitch sequence, seven different sonic identities. The engine
produces the same notes regardless of synthesis type. What changes is
the acoustic surface."

### DEMO 3: Cycle through synthesis types

    [Load Musers Waltz]
    [Cycle: faithful > sine > fm > pluck > dpoae]

"Notice: faithful gives you the raw square wave — the original sound.
Sine strips it to a single partial. FM adds inharmonicity — the melody
acquires a bell-like or metallic quality. Pluck gives pitch-dependent
decay — high notes ring shorter. And DPOAE — two tones per note at
ratio 1.22. This is the stimulus paradigm Amacher used. If the volume
is right and you are close to the speakers, you may hear tones that
are not in the speakers. Those are otoacoustic emissions — your
cochlea responding to the stimulus."

---

## V. SCALE SYSTEM (3 min)

**Screen: GUI, preparing to switch scales**

"The original hardware had a resistor ladder producing a fixed C major
scale. We replace that with a programmable 8-value float array. 37
presets are included."

"The same slider configuration — same counters, same shift register
evolution, same feedback — sounds fundamentally different in each scale.
This is the question: is the musicality in the logic or in the tuning?"

### DEMO 4: Scale switching

    [Same preset, switch: Major > Bohlen-Pierce > Carlos Alpha > Partch Diamond]

"Major gives you familiar diatonic movement. Bohlen-Pierce — the tritave
replaces the octave. The D bit now adds 19.02 semitones instead of 12.
Carlos Alpha — non-repeating. No octave at all. Partch Diamond —
11-limit just intonation, maximally different intervals."

"The sequence is identical. The perception is not."

---

## VI. SYNCED INSTANCES (3 min)

**Screen: two GUI windows side by side**

"The original hardware had a sync jack. Two units sharing a clock.
The counters advance simultaneously; the shift registers evolve
independently because they have different theme sliders."

### DEMO 5: Two synced Muses

    [Launch primary: baseNote 84 (C5), tempo 4]
    [Launch synced: baseNote 91 (G5, a 5th above)]
    [Different presets on each]

"Two independent melodic lines locked to the same clock. They share
rhythmic structure but not pitch content. The intervals between the
two voices are emergent — not composed, not random. Determined by
the interaction of two shift registers."

"This is the core of Amacher's practice with the Muse."

---

## VII. AMACHER CONNECTION (5 min)

**Screen: presentation.html section VI (Amacher)**

"Maryanne Amacher used the Muse during her MIT fellowship at the
Center for Advanced Visual Studies, 1972 to 1976. She created 18
quarter-inch tapes between 1976 and 1978, labelled 'Tone and Interval
Studies,' some marked 'in collaboration with Minsky.' These are held
at the New York Public Library."

"Her 'Additional Tones' workbook — Workbook IV, 1976, revised 1987 —
documents systematic experiments with psychoacoustic phenomena.
Difference tones, beats of mistuned consonances, fundamental tracking.
She was not using the Muse to make melodies. She was using it to
generate stimulus tones that would produce otoacoustic emissions in
the listener's ear."

"A key detail from the workbook: she operated the Muse at approximately
3,000 Hz — far above what you would choose for a melody. And she
processed the output through a Bode Ring Modulator, which produces
sum and difference frequencies. The 'Well Tuned Ear' range she
identified is 800 to 6,000 Hz. This is the frequency band where
difference tones and otoacoustic emissions are most strongly perceived."

"The DPOAE synthesis type in our implementation connects directly to
this practice. Two pure tones per note at a ratio optimised for evoking
the cubic difference tone 2f1-f2 in the listener's cochlea."

### DEMO 6: DPOAE dual Muse

    [Both Muses in DPOAE mode, slow tempo, high register]

"Four simultaneous tones at each clock tick. If the volume is
sufficient and you are positioned between the speakers, you should
hear tones that are not physically present in the room. Those are
your ears responding."

"No technical analysis of the NYPL archive materials has been
published. The tapes and notebooks likely contain the slider
configurations Amacher used. This is an open research question."

---

## VII-b. REVERSE ENGINEERING ATTEMPT (3 min)

**Screen: presentation.html section VI-b**

"I tried to recover Amacher's slider configurations directly from
the album recordings. Head Rhythm 1, Chorale 1, Synaptic Island.
The approach: extract a pitch sequence from the audio, then search
all possible Muse configurations for one that produces the same
sequence."

"The search space is 40 to the power of 8 — 6.55 trillion possible
slider settings. I reduced this by separating the theme search
(2.56 million configurations) from the interval search, and by
testing all 32 possible starting offsets in the counter cycle."

"The inference engine works. I verified it: given a clean signal
from the emulator, it recovers the known preset. The Scale preset
goes in, the Scale configuration comes back out."

"On the Amacher recordings: zero solutions. Every method, every
recording, every offset. I tried pYIN, CREPE neural pitch tracking,
zero-crossing analysis. Onset-based segmentation, grid-based
segmentation. Absolute pitch matching, relative contour matching.
Monte Carlo search with hill climbing. Nothing."

"The failure is informative. The problem is not the search — it is
the audio. The recordings are the end of a long signal chain, and
each stage destroys information the inference needs:"

Music for Minsky was a "Problem Space"  

"6.55 trillion configurations. Times 32 starting offsets. Times an
unknown scale — she may not have used the default major. Times ring
modulation — the Bode Ring Mod creates sum and difference frequencies,
destroying the one-to-one relationship between Muse pitch and
recorded frequency. Times room acoustics — these are album tracks,
not line-out recordings. Times two voices — the Chorale pieces have
two synced Muses playing simultaneously."

"One finding confirmed the workbook: all detected frequencies in
the isolated excerpt were 2200 to 3000 Hz. I initially thought
these were harmonics of a lower fundamental. The workbook told us
otherwise — that IS the operating range. 'Standing wave phenomena
with 3,000 Hz Muse business.' The ring modulator then creates
non-harmonic sidebands, which is why no pitch tracker achieves
meaningful confidence."

"The NYPL archive is the realistic path. If Amacher's notebooks
contain the slider positions, the problem collapses from 6.55
trillion unknowns to a lookup. The inference pipeline is ready
for any clean, unprocessed Muse recording."

---

## CLOSING (2 min)

**Screen: architecture diagram again**

"The Triadex Muse is a limit case. Fully deterministic — no stochastic
process anywhere. Yet perceptually non-deterministic — listeners hear
composition, variation, development, surprise. The instrument does not
decide what to play. It computes what it must play, given 8 addresses
into a pool of 40 binary signals. The musicality is not in the machine.
It is in the interaction between the machine's periodicity and the
listener's pattern recognition."

"Three open questions I would like to leave you with:"

"First: where does the Muse's 'musicality' reside — in the shift
register logic, in the scale mapping, or in the listener?"

"Second: what happens to deterministic structure when the tuning system
is non-octave-repeating? The same binary sequence in Carlos Alpha
produces melodic patterns that have no tonal centre. Is it still music
in the same sense?"

"Third: Amacher's use of the Muse was not melodic but psychoacoustic.
The Muse was a stimulus generator. What does it mean to compose for
the listener's cochlea rather than for their cortex?"

    [Leave SC running for questions / hands-on exploration]

---

## TIMING SUMMARY

| Section              | Minutes | Cumulative |
|----------------------|---------|------------|
| Opening              | 2       | 2          |
| I. Historical context| 3       | 5          |
| II. Architecture     | 8       | 13         |
| Demo 1 (Scale)       | —       | (in II)    |
| III. SC implementation| 3      | 16         |
| Demo 2 (presets)     | —       | (in III)   |
| IV. Synthesis types  | 3       | 19         |
| Demo 3 (cycle synths)| —      | (in IV)    |
| V. Scales            | 3       | 22         |
| Demo 4 (scale switch)| —      | (in V)     |
| VI. Synced instances | 3       | 25         |
| Demo 5 (two Muses)   | —      | (in VI)    |
| VII. Amacher         | 5       | 30         |
| Demo 6 (DPOAE)      | —       | (in VII)   |
| Closing / questions  | 2       | 32         |

---

## SC BLOCKS TO PRE-EVALUATE

Before the talk, have these ready in the SC editor:

```
// Boot server
s.boot;

// Launch primary Muse
~m1 = TriadexMuseApplication.run(baseNote: 60, tempo: 4);

// Presets to load during talk
~m1.muse.preset_('Scale');
~m1.muse.preset_('Meditation');
~m1.muse.preset_('Birds 1');
~m1.muse.preset_('Musers Waltz');

// Synthesis type switching
~m1.player.synthType_(\faithful);
~m1.player.synthType_(\sine);
~m1.player.synthType_(\fm);
~m1.player.synthType_(\pluck);
~m1.player.synthType_(\dpoae);

// Scale switching
~m1.muse.scalePreset_('Major');
~m1.muse.scalePreset_('BP Lambda');
~m1.muse.scalePreset_('Carlos Alpha');
~m1.muse.scalePreset_('Partch Diamond');

// Second Muse (synced)
~m2 = TriadexMuseApplication.runSynced(
    baseNote: 72, tempo: 4, beatOffset: 0.5
);

// DPOAE mode for both
~m1.player.synthType_(\dpoae);
~m2.player.synthType_(\dpoae);

// High register for Amacher demo
~m1.player.baseNote_(84);
~m2.player.baseNote_(91);
~m1.player.tempo_(3);
```
