// =====================================================================
// TriadexMuse_StartUp.scd
// Complete reference and startup guide for the Triadex Muse in SC
// =====================================================================
//
// The Triadex Muse (Edward Fredkin & Marvin Minsky, 1969/1972)
// is a deterministic melodic automaton. It uses binary counters,
// a 31-bit shift register, and an XNOR gate to generate melodies.
//
// This SC implementation has three layers:
//   TriadexMuse           — the algorithmic engine (no audio)
//   TriadexMusePlayer     — audio playback + scheduling
//   TriadexMuseGUI        — visual interface (via TriadexMuseApplication)
//   TriadexMuseApplication — one-call launcher (singleton)
//
// Reference: J. Donald Tillman's JavaScript emulation
// https://till.com/articles/muse/
// =====================================================================


// =====================================================================
// 1. QUICK START — TriadexMuseApplication
// =====================================================================

// Boot server first (if not already running)
s.boot;

// Default launch: faithful square-wave mode
TriadexMuseApplication.run;

// Launch with a preset
TriadexMuseApplication.run(preset: "Polka");
TriadexMuseApplication.run(preset: "Birds 1");
TriadexMuseApplication.run(preset: "Meditation");

// Launch in enhanced mode (selectable waveform + filter + effects)
TriadexMuseApplication.run(\enhanced);
TriadexMuseApplication.run(\enhanced, "Michaels Tune");

// Launch with custom parameters
TriadexMuseApplication.run(
	mode: \faithful,
	preset: "Scale",
	baseNote: 48,    // C3 — lower root
	tempo: 6,        // 6 notes/sec
	amp: 0.15
);

// Access the running instance
TriadexMuseApplication.instance;
TriadexMuseApplication.instance.isRunning;

// Control the running instance
TriadexMuseApplication.instance.play;
TriadexMuseApplication.instance.stop;
TriadexMuseApplication.instance.restart;  // reset engine + restart playback

// Change preset while running
TriadexMuseApplication.instance.preset_("Christmas Bells");

// Change parameters while running
TriadexMuseApplication.instance.tempo_(8);
TriadexMuseApplication.instance.baseNote_(72);  // C5
TriadexMuseApplication.instance.amp_(0.1);

// Close the application
TriadexMuseApplication.instance.close;  // close window, stop playback
TriadexMuseApplication.instance.free;   // full cleanup


// =====================================================================
// 2. HEADLESS — TriadexMusePlayer (no GUI)
// =====================================================================

// Quick one-liner: create, load preset, play
~player = TriadexMusePlayer.play("Musers Waltz");
~player = TriadexMusePlayer.play("Birds 1", tempo: 8, baseNote: 72);
~player = TriadexMusePlayer.play("Polka", amp: 0.3);

// Or build step-by-step
(
~muse = TriadexMuse.new;
~player = TriadexMusePlayer.new(~muse, s);
~player.baseNote = 60;
~player.tempo = 4;
~player.amp = 0.2;
~player.legato = 0.8;   // note duration as fraction of beat
~player.pan = 0;         // stereo position: -1 (L) to 1 (R)
~muse.preset_("Mesopotamia");
~player.play;
)

// Stop / restart
~player.stop;
~player.restart;  // resets engine state + restarts

// Single step mode (advance one tick, play note, return pitch)
~player.stop;
~player.stepOnce;  // returns pitch or nil (rest)


// =====================================================================
// 3. SYNTHESIS TYPES
// =====================================================================

// Available synth types (switchable live while playing):
TriadexMusePlayer.synthTypeNames;
// -> [ faithful, sine, saw, fm, pluck, enhanced ]

// Change synth type on a running player
~player.synthType_(\faithful);  // original square wave (Pulse)
~player.synthType_(\sine);      // pure SinOsc — warm, clear
~player.synthType_(\saw);       // band-limited Saw + gentle LPF
~player.synthType_(\fm);        // 2-op FM — bell/metallic (ratio 3.51)
~player.synthType_(\pluck);     // Karplus-Strong via Pluck UGen
~player.synthType_(\enhanced);  // selectable waveform + filter + effects

// Enhanced mode waveform selection
~player.synthType_(\enhanced);
~player.waveform = \pulse;   // 0
~player.waveform = \saw;     // 1
~player.waveform = \tri;     // 2
~player.waveform = \sine;    // 3

// Enhanced mode filter
~player.filterFreq = 2000;  // Hz (nil = bypass)
~player.filterRes = 0.5;    // 0-1 (higher = more resonant)

// Enhanced mode effects (reverb + delay)
~player.reverbMix_(0.3);     // 0-1 dry/wet
~player.delayTime_(0.25);    // seconds
~player.delayDecay_(2.0);    // seconds


// =====================================================================
// 4. ENGINE ONLY — TriadexMuse (no audio)
// =====================================================================

// Create and inspect the engine directly
~muse = TriadexMuse.new;

// --- Setting sliders ---

// By position index (0-39, maps to source table rows)
~muse.interval[0] = 3;   // A -> C1
~muse.interval[1] = 4;   // B -> C2
~muse.interval[2] = 5;   // C -> C4
~muse.interval[3] = 0;   // D -> OFF

~muse.theme[0] = 0;      // W -> OFF
~muse.theme[1] = 0;      // X -> OFF
~muse.theme[2] = 0;      // Y -> OFF
~muse.theme[3] = 0;      // Z -> OFF

// By individual setter
~muse.intervalA_(3);
~muse.intervalB_(4);
~muse.intervalC_(5);
~muse.intervalD_(0);
~muse.themeW_(0);
~muse.themeX_(0);
~muse.themeY_(0);
~muse.themeZ_(0);

// Set all 8 at once by position: [A, B, C, D, W, X, Y, Z]
~muse.sliders_([3, 4, 5, 0, 0, 0, 0, 0]);

// Set by source label name (most readable)
~muse.slidersNamed_("B7", "B8", "B5", "OFF", "OFF", "B4", "B23", "OFF");

// Rest switch: lowest note (pitch 0) becomes a rest
~muse.rest_(true);
~muse.rest_(false);

// --- Stepping ---

~muse.reset;              // reset all counters and shift register
~muse.step;               // advance one tick, returns pitch (Int or nil)
~muse.stepN(16);          // advance N steps, returns Array of pitches

// --- Scale ---

// Default: major scale
TriadexMuse.defaultScale;  // -> [0, 2, 4, 5, 7, 9, 11, 12]

// Custom scales (must be 8 values: semitone offsets from root)
~muse.scale_([0, 2, 4, 5, 7, 9, 11, 12]);   // major (default)
~muse.scale_([0, 2, 3, 5, 7, 8, 10, 12]);   // natural minor
~muse.scale_([0, 2, 3, 5, 7, 9, 11, 12]);   // dorian
~muse.scale_([0, 1, 3, 5, 7, 8, 10, 12]);   // phrygian
~muse.scale_([0, 2, 4, 6, 7, 9, 11, 12]);   // lydian
~muse.scale_([0, 2, 4, 5, 7, 9, 10, 12]);   // mixolydian
~muse.scale_([0, 2, 3, 5, 7, 8, 11, 12]);   // harmonic minor
~muse.scale_([0, 2, 4, 7, 9, 12, 14, 16]);  // pentatonic (wide)
~muse.scale_([0, 1, 4, 5, 7, 8, 11, 12]);   // Hungarian minor
~muse.scale_([0, 1, 5, 7, 10, 12, 13, 17]); // hirajoshi-ish
~muse.scale_([0, 3, 5, 6, 7, 10, 12, 15]);  // blues
~muse.scale_([0, 2, 4, 6, 8, 10, 12, 14]);  // whole tone

// --- State Inspection ---

~muse.postState;          // pretty-print full state to post window
~muse.currentPitch;       // current pitch without advancing
~muse.noteBits;           // raw 4-bit note value (0-15)
~muse.sourceStates;       // Array[40] of current binary source values (0/1)
~muse.shiftRegisterBits;  // Array[31] of shift register bits
~muse.counterState;       // Event with all counter values
~muse.stepCount;          // number of steps since last reset
~muse.history;            // Array of recent pitches

// --- Label Utilities ---

TriadexMuse.sourceLabels;           // all 40 source label strings
TriadexMuse.labelToIndex("B7");     // -> 15
TriadexMuse.indexToLabel(15);       // -> "B7"


// =====================================================================
// 5. PRESETS
// =====================================================================

// List all available presets
TriadexMuse.presetNames;

// Load a preset by name
~muse.preset_("Michaels Tune");

// All presets from Tillman's JS emulation:
//
//   "Als Surprise"      — B1, B5, B7, C 1/2 | C8, B1, B7, B11
//   "Birds 1"           — B1, B2, B3, C4 | B30, B31, B31, B31
//   "Birds 2"           — B28, B29, B30, B30 | B30, B31, B31, B31
//   "Christmas Bells"   — B31, B30, B29, B28 | B28, B29, B30, B31
//   "Dorian Muse"       — ON, B1, B3, C8 | B1, B16, OFF, OFF
//   "Eds Rhythm Piece"  — B6, B6, B6, C2 | OFF, OFF, B1, B31
//   "Federal Row"       — B14, B5, B12, B2 | B21, B24, C2, OFF
//   "Flat Baroque"      — C1, B15, B1, C 1/2 | B30, B29, B24, OFF  [REST]
//   "Marvins Yodel"     — B2, B17, B9, B25 | B16, OFF, B15, C1  [REST]
//   "Meditation"        — B1, B31, B14, OFF | OFF, OFF, B16, B31
//   "Mesopotamia"       — C2, B5, B9, OFF | C8, B9, B24, C4
//   "Michaels Tune"     — B7, B8, B5, OFF | OFF, B4, B23, OFF
//   "Musers Waltz"      — B10, B8, B7, OFF | ON, C4, B1, B2
//   "Polka"             — B1, B13, B11, C 1/2 | C8, B11, B7, B1  [REST]
//   "Rhyming Couplets"  — B1, B2, C4, C8 | OFF, OFF, B31, C4
//   "Rons Rhapsody"     — B6, B9, B6, C 1/2 | B31, C4, OFF, C8  [REST]
//   "Scale"             — C1, C2, C4, OFF | OFF, OFF, OFF, OFF
//   "Swiss Yodeler"     — B8, C1, B16, OFF | B22, B21, B16, OFF
//   "The Crazy Cuckoo"  — C1, B1, B31, C8 | OFF, OFF, B1, B31
//   "Yodle"             — C8, B2, B5, B6 | OFF, OFF, B1, B31


// =====================================================================
// 6. ADVANCED USAGE — Callbacks and Data Collection
// =====================================================================

// --- onStep callback ---
// Called after every step with (muse, pitch)
(
~muse = TriadexMuse.new;
~muse.preset_("Michaels Tune");
~muse.onStep = { |muse, pitch|
	"Step %: pitch = %".format(muse.stepCount, pitch ? "rest").postln;
};
~muse.stepN(16);
~muse.onStep = nil;  // remove callback
)

// --- Collect a pitch sequence for analysis ---
(
~muse = TriadexMuse.new;
~muse.preset_("Polka");
~pitches = ~muse.stepN(256);
~pitches.postln;
// Histogram of pitch values
~pitches.reject(_.isNil).asBag.contents.keysValuesDo({ |pitch, count|
	"% -> % occurrences".format(pitch, count).postln;
});
)

// --- Compare presets ---
(
TriadexMuse.presetNames.do({ |name|
	var muse = TriadexMuse.new;
	var pitches, unique;
	muse.preset_(name);
	pitches = muse.stepN(128).reject(_.isNil);
	unique = pitches.asSet.size;
	"% — % unique pitches in 128 steps, range: %-%".format(
		name, unique, pitches.minItem, pitches.maxItem
	).postln;
});
)


// =====================================================================
// 7. COMPOSING WITH PATTERNS
// =====================================================================

// Use the Muse engine as a pitch source inside a Pbind
(
~muse = TriadexMuse.new;
~muse.preset_("Meditation");

Pbind(
	\instrument, \default,
	\midinote, Pfunc({ (~muse.step ? Rest()) + 60 }),
	\dur, 0.25,
	\amp, 0.1,
	\legato, 0.8
).play;
)

// Two Muses in parallel with different presets
(
~muse1 = TriadexMuse.new;
~muse1.preset_("Birds 1");
~muse2 = TriadexMuse.new;
~muse2.preset_("Meditation");

Ppar([
	Pbind(
		\instrument, \default,
		\midinote, Pfunc({ (~muse1.step ? Rest()) + 72 }),
		\dur, 0.125,
		\amp, 0.06,
		\pan, -0.5
	),
	Pbind(
		\instrument, \default,
		\midinote, Pfunc({ (~muse2.step ? Rest()) + 48 }),
		\dur, 0.5,
		\amp, 0.1,
		\pan, 0.5
	)
]).play;
)

// Muse controlling non-pitch parameters
(
~muse = TriadexMuse.new;
~muse.preset_("Rons Rhapsody");
~muse.scale_([0.01, 0.05, 0.1, 0.2, 0.4, 0.6, 0.8, 1.0]); // map to filter sweep

Pbind(
	\instrument, \default,
	\freq, 200,
	\amp, Pfunc({
		var val = ~muse.step;
		if(val.notNil) { val / 24 } { 0 };
	}),
	\dur, 0.125
).play;
)


// =====================================================================
// 8. SOURCE TABLE REFERENCE
// =====================================================================
//
// Position  Label    Source
// --------  -----    ------
//    0      OFF      Always 0
//    1      ON       Always 1
//    2      C 1/2    Counter bit 0 (clock / 2)
//    3      C1       Counter bit 1 (clock / 4)
//    4      C2       Counter bit 2 (clock / 8)
//    5      C4       Counter bit 3 (clock / 16)
//    6      C8       Counter bit 4 (clock / 32)
//    7      C3       Divide-by-6 counter bit 2 (clock / 6)
//    8      C6       Divide-by-6 counter bit 3 (clock / 12)
//   9-39    B1-B31   Shift register bits 1-31
//
// Interval sliders (A,B,C,D):
//   A = weight 1 (LSB), B = weight 2, C = weight 4
//   D = octave bit (adds 12 semitones)
//   3-bit value (ABC) indexes into 8-note scale
//
// Theme sliders (W,X,Y,Z):
//   All four source values are XNORed together
//   Result feeds into shift register at B1 on each clock tick
//
// The shift register advances on every other clock tick
// (on falling edge of C 1/2), creating sequences that repeat
// at periods determined by which bits feed back via the theme sliders.
