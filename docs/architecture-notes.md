# Architecture Diagram — Talk Notes

Walk through the diagram left to right, following the five stages.
Point at each block as you describe it. The audience should understand
that the entire instrument is a pipeline from clock to pitch.

---

## Stage 1: TIMING

**Point to: CLOCK**

"Everything begins with a single clock oscillator. This is the tempo
knob on the original hardware. It produces a regular pulse — nothing
more. Every tick of this clock advances the entire machine by one step.
The tempo is the only continuous parameter on the instrument; everything
else is discrete, binary."

"The clock feeds three subsystems simultaneously: the 4-bit counter,
the 31-bit shift register, and the divide-by-3 counter. All three
advance together, but at different rates."

---

## Stage 2: BINARY SOURCES

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

**Pause. Gesture across all three blocks.**

"Together, these three subsystems produce 40 binary signals: 2 constants
(OFF = always 0, ON = always 1), 5 from the binary counter, 2 from the
divide-by-3 counter, and 31 from the shift register. These 40 signals
change at different rates — from every tick to once every billions of
ticks. This is the raw material of the Muse. Everything that follows
is selection and combination."

---

## Stage 3: PERMUTATION (Selector Matrix)

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

---

## Stage 4: LOGIC

**Point to: XNOR GATE**

"The XNOR gate receives the four theme signals — E, F, G, H. It
computes: start with 1, XOR each input. If all four agree (all 0 or
all 1), the result is 1. Otherwise 0."

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

---

## Stage 5: OUTPUT

**Point to: OUTPUT block (note + gate)**

"The output is two values: a pitch (from the interval sliders and
scale mapping) and a gate (from the XNOR logic — note on or off).
In the original hardware this drove a divide-down oscillator producing
a square wave. In our implementation it drives any of seven synthesis
types."

---

## Summary statement

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

## Transition to demo

"Let me show you. The simplest case first — the 'Scale' preset.
All four theme sliders set to OFF. Interval sliders reading from
C1, C2, C4. Pure counter-driven sequence. You will hear the binary
counter literally counting in pitch."

[Evaluate: Scale preset, faithful synthesis]

"Now watch what happens when I move one theme slider to a shift
register position..."

[Move theme slider, demonstrate character change]
