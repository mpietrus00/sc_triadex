# TriadexMuse -- Project Notes

## On the scale system

The original hardware Muse outputs a 3-bit value (0-7) that addresses one of eight notes on a physical pitch wheel -- a resistor network tuned to a major scale. There is no "scale array" in the hardware; the tuning is a physical fact, subject to component tolerance, temperature drift, aging. Two Muses from the same production run would not produce identical pitches. The "scale" is whatever the resistors happen to produce.

Tillman's JavaScript emulation replaced that resistor network with an integer array of semitone offsets: [0, 2, 4, 5, 7, 9, 11, 12]. This is not a neutral translation. It removes the material contingency of the instrument and replaces it with an idealised 12-TET grid -- cleaner and more consistent than the original ever was, but also more constrained. Integer semitones cannot represent intervals that fall between semitones: just intonation thirds, 7-EDO steps, Bohlen-Pierce intervals, Carlos Alpha's 78-cent divisions. All of these collapse onto the same 12-TET lattice when rounded to integers.

The current implementation stores the scale array as floats (semitone values with sub-semitone precision). The 3-bit lookup is unchanged -- noteBits still indexes into an 8-element array. But the values at those positions can now sit anywhere in frequency space. A second change: the octave bit (D slider on the original) used to add a hardcoded 12 semitones. It now adds the last value in the scale array -- the interval of equivalence. For standard tunings this is 12.0 (no difference). For Bohlen-Pierce it is 19.02 (the tritave). For Carlos Alpha it is 5.46. The D slider transposes by whatever interval the scale actually repeats at, rather than forcing an octave onto non-octave-repeating systems. Scala .scl files are loaded at full cent precision.

So the trajectory is: physical (contingent) to integer (idealised, grid-locked) to float (idealised, grid-free). Each step gains and loses something. The engine logic -- counters, shift register, XNOR feedback, slider addressing -- is identical throughout. What changes is the pitch surface the 3-bit output is projected onto.

This raises questions that the implementation is now equipped to explore. The Muse's melodic logic was designed around major-scale intervals. Does it still produce musically coherent results when projected onto Bohlen-Pierce, where the intervals have no diatonic function? Or does the coherence break down, revealing that the "musicality" of the original was partly a property of the scale mapping, not of the shift register? The same slider configuration can now be heard through any tuning system -- the combinatorial structure stays fixed while the harmonic surface varies. This separates the two components of the instrument (sequence logic and pitch mapping) in a way the original hardware, with its soldered resistors, never could.

There is also a question the other way: what were the actual voltages on a production Muse? Were they reliably 12-TET, or would surviving units show measurable deviation? If the resistors drifted, was the "character" of a specific unit partly in its tuning imperfections? The integer version erased that possibility. The float version does not restore it (it has no component drift), but it reopens the space in which such variations could be deliberately introduced.


## On the Muse as a limit case

The Triadex Muse is interesting as a limit case: a fully deterministic composition machine with no stochastic element whatsoever. Everything follows from the initial state of the shift register and the slider positions. Yet the output, perceptually, is not experienced as deterministic. The listener hears pattern, surprise, repetition, variation -- all the hallmarks of composed music. This gap between mechanism and perception is the core research question.

Fredkin and Minsky built this at MIT in 1969, at the intersection of automata theory and artificial intelligence. The Muse is not a synthesizer and not a sequencer. It is a finite state machine that happens to produce pitch sequences. The musical surface is an epiphenomenon of binary logic. Compare this with Xenakis, who at the same moment was using stochastic processes to generate musical form -- the Muse takes the opposite path: no randomness at all, yet the perceptual result can be equally unpredictable.


## On synced instances

The original hardware had a sync jack on the back panel. Two Muses could be clocked from the same signal, producing interlocking melodic lines from independent slider configurations. This is structurally close to Koenig's Project 1 (1964): deterministic parallel processes generating polyphony from separate parameter streams. The difference is that Koenig's processes are computed offline, while the Muse runs in real time -- the performer hears the result as it unfolds.

Staggered beat offsets create canonic relationships without the Muse knowing anything about counterpoint. The shift registers evolve independently, but the shared clock ensures vertical alignment. Perceptually: are these heard as independent voices or as a single composite texture? This is a Bregman question -- auditory stream segregation by register, timbre, onset asynchrony.

With four voices across four registers and four presets, the complexity arises not from temporal independence but from the combinatorial divergence of four LFSR states. Each shift register follows its own trajectory; the vertical coincidences are emergent, never planned. At what point does the listener stop tracking individual voices and begin hearing the aggregate as a single harmonic field? This is the crossover from polyphony to texture that Truax describes in the context of granular synthesis. The Muse produces it from discrete pitched events rather than from grains.


## On synthesis types and timbral reframing

The original Muse produced only a square wave. Adding timbral variation raises a question about identity: at what point does the enhancement dissolve the character of the instrument? The Muse's identity is in its melodic logic, not its sound. The square wave is incidental -- a consequence of 1969 electronics, not an aesthetic decision. So extending the timbre is legitimate, as long as the sequence engine remains faithful.

Each synthesis type reframes the same pitch sequence through a different acoustic lens. The pluck mode is particularly revealing: Karplus-Strong introduces its own spectral evolution per note, so the timbre is pitch-dependent in a way the square wave is not. The FM mode adds inharmonicity that can mask or reinforce the intervallic relationships the Muse computes.

The DPOAE mode is a deliberate provocation: it connects the Muse's deterministic pitch logic to the nonlinear mechanics of the cochlea. DPOAEs (distortion product otoacoustic emissions) arise from the interaction of two tones at specific frequency ratios. The Muse's output becomes the stimulus for a psychoacoustic phenomenon.

Applying a filter sweep to the Muse imposes a continuous spectral trajectory onto a discrete pitch sequence. Two time scales operating simultaneously -- the stepwise melody and the smooth filter arc. This is structurally parallel to Roads' idea of the "sound object" having both micro and meso timescales.


## On sequence analysis

Listening to all twenty presets in sequence reveals the range of behaviour the Muse can produce from the same mechanism. Some presets (Scale, Eds Rhythm Piece) are clearly periodic. Others (Mesopotamia, Christmas Bells) produce sequences long enough to sound aperiodic within any reasonable listening window. The shift register has a maximum cycle length of 2^31 - 1 steps, but the effective period depends on which bits the sliders tap.

The shift register visualisation (available in the GUI) makes the internal state visible. Each step shifts one bit in, and the eight sliders sample from this evolving bit pattern. The connection to LFSR theory is direct: the theme sliders define the feedback polynomial, and the interval sliders define the output function.

A systematic study: for each preset, compute the actual cycle length. Which presets produce maximal-length sequences? Which produce short loops? What is the relationship between slider configuration and sequence periodicity? How does the autocorrelation function of the sequence compare to a random walk on the same pitch set?


## On spatialisation

Spatial movement driven by the step counter imposes a periodic spatial trajectory onto the aperiodic (or long-period) pitch sequence. The spatial and melodic cycles are incommensurate, producing a phasing relationship. Each synced instance could occupy a different spatial trajectory, creating an ensemble distributed in space. A direction for future work: route each synced Muse to a different DS100 object, with spatial position driven by the Muse's own internal state (shift register bits, counter values) rather than an external function.
