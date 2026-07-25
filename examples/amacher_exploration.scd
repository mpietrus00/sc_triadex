// TriadexMuse — Psychoacoustic Exploration (after Amacher)
//
// Informed by Amacher's "Additional Tones" workbook (Workbook IV):
//   - Muse operating at ~3000 Hz for standing wave phenomena
//   - Two synced Muses producing near-consonant intervals
//   - Target: difference tones, OAEs, beating at 10-15 Hz
//   - "Well Tuned Ear" range: 800-6,000 Hz
//   - Bode Ring Modulator processing
//
// This file sets up TWO synced Muses in Amacher's frequency range
// with scales and configs designed for psychoacoustic phenomena.
//
// Boot server first: s.boot;


// =====================================================================
// 1. Single Muse in DPOAE mode (~3000 Hz)
// =====================================================================
// The DPOAE synth generates two tones at ratio ~1.22 (f2/f1),
// optimised for evoking the cubic difference tone 2f1-f2 in the ear.
(
~app = TriadexMuseApplication.run(
	mode: \faithful,
	baseNote: 96,    // ~2093 Hz — Amacher's operating range
	tempo: 6,        // slow enough for psychoacoustic effects to register
	amp: 0.15
);
)

// Try the DPOAE synth type (two-tone stimulus per note)
~app.player.synthType_(\dpoae);

// Back to faithful (square wave)
~app.player.synthType_(\faithful);


// =====================================================================
// 2. Scales for psychoacoustic work
// =====================================================================
// Amacher's workbook references near-consonant intervals.
// These scales produce specific ratio relationships.

// JI Major — pure 3:2 fifths, 5:4 thirds
~app.muse.scalePreset_('JI Major');

// 7-limit JI — includes septimal intervals (7:4, 7:6)
~app.muse.scalePreset_('7-Limit JI');

// Partch Diamond — 11-limit, rich combination tones
~app.muse.scalePreset_('Partch Diamond');

// Young WTP — La Monte Young's tuning, maximises beating patterns
~app.muse.scalePreset_('Young WTP');

// Custom: near-unisons and near-fifths for beating
// Degrees 0-3 cluster near unison (Δf ~ 10-15 Hz at 3kHz)
// Degrees 4-7 cluster near the fifth (ratio ~1.5)
(
~app.muse.scale_([
	0,              // unison
	0.05,           // +5 cents — ~0.9 Hz beat at 3kHz
	0.10,           // +10 cents — ~1.7 Hz beat
	0.20,           // +20 cents — ~3.5 Hz beat
	7.0,            // perfect 5th
	7.05,           // 5th + 5 cents
	7.10,           // 5th + 10 cents
	12.0            // octave (interval of equivalence)
]);
"Scale: near-unison/near-fifth clusters for beating".postln;
)

// Custom: Amacher's 440-based experiments
// Workbook mentions 440 Hz and 293 Hz (near 3:2)
// At baseNote 96 (~2093 Hz), scale in semitones from root
(
~app.muse.scale_([
	0,              // root
	1.0,            // minor 2nd — roughness zone
	5.0,            // perfect 4th
	7.0,            // perfect 5th — strongest combination tones
	7.02,           // near-5th — slow beating (~0.35 Hz)
	12.0,           // octave
	12.02,          // near-octave — slow beating
	19.02           // octave + 5th (3:1 ratio)
]);
"Scale: Amacher workbook intervals (consonances + near-mistunings)".postln;
)

// Reset to default major
~app.muse.scalePreset_('Major');


// =====================================================================
// 3. Slider configs that produce musically dense patterns
// =====================================================================
// For psychoacoustic work, Amacher likely wanted:
//   - Frequent near-consonant intervals between consecutive notes
//   - Enough variety to prevent habituation
//   - Slow enough changes for the ear to "tune in"

// Config A: Counter-driven, produces rising/falling scales
// Interval reads from ascending counter bits — orderly melodic motion
(
~app.muse.sliders_([2, 3, 4, 0,   // A=C1/2, B=C1, C=C2, D=OFF
                     0, 0, 0, 0]); // theme all OFF (pure counter sequence)
~app.muse.reset;
"Config A: ascending counter scale (C1/2, C1, C2)".postln;
)

// Config B: SR-driven, chaotic melodic line
// Theme creates complex SR evolution, interval reads from SR
(
~app.muse.sliders_([9, 10, 11, 0,     // A=B1, B=B2, C=B3, D=OFF
                     1, 4, 9, 12]);    // W=ON, X=C2, Y=B1, Z=B4
~app.muse.reset;
"Config B: SR-driven chaotic (B1-B3 interval, mixed theme)".postln;
)

// Config C: Mixed counter+SR, moderate complexity
// Counter for low bits, SR for high bit — hybrid melodic movement
(
~app.muse.sliders_([2, 9, 4, 0,      // A=C1/2, B=B1, C=C2, D=OFF
                     0, 0, 9, 14]);   // W=OFF, X=OFF, Y=B1, Z=B6
~app.muse.reset;
"Config C: hybrid counter+SR (C1/2, B1, C2)".postln;
)

// Config D: Slow-changing, meditative (like Amacher's Chorale)
// Higher counter bits change less frequently = longer held notes
(
~app.muse.sliders_([4, 5, 6, 0,      // A=C2, B=C4, C=C8, D=OFF
                     0, 0, 9, 10]);   // minimal SR activity
~app.muse.reset;
"Config D: slow counter (C2, C4, C8) — chorale-like".postln;
)

// Config E: Dense SR, all theme active — maximal melodic variation
(
~app.muse.sliders_([10, 11, 12, 9,    // A=B2, B=B3, C=B4, D=B1
                     9, 10, 11, 12]);  // W=B1, X=B2, Y=B3, Z=B4
~app.muse.reset;
"Config E: dense SR feedback (B1-B4 everywhere)".postln;
)

// Config F: Amacher-like — based on intervals near 5th and octave
// Using JI scale, slow tempo, notes near consonant relationships
(
~app.muse.scalePreset_('JI Major');
~app.player.baseNote_(84);  // ~523 Hz (C5) — lower end of "Well Tuned Ear"
~app.player.tempo_(3);      // slow for psychoacoustic perception
~app.muse.sliders_([3, 5, 4, 6,      // interval: C1, C4, C2, C8
                     1, 0, 9, 0]);    // theme: ON, OFF, B1, OFF
~app.muse.reset;
"Config F: JI scale, slow, consonant-focused".postln;
)


// =====================================================================
// 4. TWO SYNCED MUSES (Amacher's Chorale setup)
// =====================================================================
// This is the core of Amacher's approach:
// Two Muses sharing a clock, producing near-consonant intervals.
// Their combined output creates difference tones and OAEs.

// Close any existing windows first
// Cmd+.

// Launch primary Muse (controls tempo)
(
~muse1 = TriadexMuseApplication.run(
	mode: \faithful,
	baseNote: 84,    // C5 ~523 Hz
	tempo: 4,
	amp: 0.15
);
)

// Launch second Muse (synced, tempo-locked)
(
~muse2 = TriadexMuseApplication.runSynced(
	mode: \faithful,
	baseNote: 91,    // G5 ~784 Hz — a 5th above Muse 1
	tempo: 4,
	amp: 0.15,
	beatOffset: 0    // simultaneous (0) or staggered (0.5 = half-beat offset)
);
)

// Set different slider configs for each Muse
// Muse 1: orderly counter-based melody
(
~muse1.muse.sliders_([2, 3, 4, 0,   // C1/2, C1, C2, OFF
                       0, 0, 9, 0]); // OFF, OFF, B1, OFF
~muse1.muse.reset;
"Muse 1: counter melody".postln;
)

// Muse 2: SR-driven counterpoint
(
~muse2.muse.sliders_([9, 10, 3, 0,   // B1, B2, C1, OFF
                       1, 5, 11, 0]); // ON, C4, B3, OFF
~muse2.muse.reset;
"Muse 2: SR counterpoint".postln;
)


// =====================================================================
// 5. Preset-based dual Muse configurations
// =====================================================================
// Using known presets on two synced Muses at different base frequencies

// Chorale-like: slow, consonant
(
~muse1.muse.preset_('Meditation');
~muse1.player.baseNote_(84);
~muse1.player.tempo_(3);
~muse2.muse.preset_('Meditation');
~muse2.player.baseNote_(91); // 5th above
"Dual Meditation at 5th".postln;
)

// Dense: fast, complex beating
(
~muse1.muse.preset_('Birds 1');
~muse1.player.baseNote_(96);
~muse1.player.tempo_(8);
~muse2.muse.preset_('Birds 2');
~muse2.player.baseNote_(96); // unison — beating from different melodies
"Dual Birds at unison (beating from melodic difference)".postln;
)

// Amacher-style: near-mistuned consonance
(
~muse1.muse.preset_('Musers Waltz');
~muse1.player.baseNote_(84);
~muse1.player.tempo_(4);
~muse2.muse.preset_('Musers Waltz');
~muse2.player.baseNote_(84.15); // 15 cents sharp — slow beating
"Dual Musers Waltz detuned 15 cents (beating)".postln;
)


// =====================================================================
// 6. DPOAE dual stimulus
// =====================================================================
// Both Muses in DPOAE mode: each note generates a two-tone stimulus.
// Four simultaneous tones = rich combination tone field.
(
~muse1.player.synthType_(\dpoae);
~muse2.player.synthType_(\dpoae);
~muse1.player.baseNote_(84);
~muse2.player.baseNote_(91);
~muse1.player.tempo_(3);
"DPOAE dual Muse — four-tone psychoacoustic stimulus".postln;
)

// Back to square wave
(
~muse1.player.synthType_(\faithful);
~muse2.player.synthType_(\faithful);
)
