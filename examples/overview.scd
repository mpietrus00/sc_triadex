// TriadexMuse — Overview
// Boot the server first: s.boot;
// Evaluate blocks one at a time (Cmd+Enter on each parenthesized block)
// Stop playback: Cmd+Period
//
// The Triadex Muse is interesting as a limit case: a fully deterministic
// composition machine with no stochastic element whatsoever. Everything
// follows from the initial state of the shift register and the slider
// positions. Yet the output, perceptually, is not experienced as
// deterministic. The listener hears pattern, surprise, repetition,
// variation -- all the hallmarks of composed music. This gap between
// mechanism and perception is the core research question here.
//
// Fredkin and Minsky built this at MIT in 1969, at the intersection of
// automata theory and artificial intelligence. The Muse is not a
// synthesizer and not a sequencer. It is a finite state machine that
// happens to produce pitch sequences. The musical surface is an
// epiphenomenon of binary logic. Compare this with Xenakis, who at the
// same moment was using stochastic processes to generate musical form --
// the Muse takes the opposite path: no randomness at all, yet the
// perceptual result can be equally unpredictable.


// =====================================================================
// 1. Quick start -- one-line launch with GUI
// =====================================================================

TriadexMuseApplication.run;

// Or with a preset and mode:
TriadexMuseApplication.run(\faithful, "Musers Waltz");
TriadexMuseApplication.run(\enhanced, "Birds 1");


// =====================================================================
// 2. Two Muses synced
// =====================================================================
//
// The original hardware had a sync jack on the back panel. Two Muses
// could be clocked from the same signal, producing interlocking melodic
// lines from independent slider configurations. This is structurally
// close to Koenig's Project 1 (1964): deterministic parallel processes
// generating polyphony from separate parameter streams. The difference
// is that Koenig's processes are computed offline, while the Muse runs
// in real time -- the performer hears the result as it unfolds.
(
// Primary instance -- drives tempo for all
TriadexMuseApplication.run(\faithful, "Musers Waltz", tempo: 4);

// Second instance synced to the same clock
TriadexMuseApplication.runSynced(\faithful, "Birds 1",
	baseNote: 72, tempo: 4, beatOffset: 0);
)


// =====================================================================
// 3. Three Muses synced -- staggered entries
// =====================================================================
//
// Staggered beatOffset creates canonic relationships without the Muse
// knowing anything about counterpoint. The shift registers evolve
// independently, but the shared clock ensures vertical alignment.
// Perceptually: are these heard as independent voices or as a single
// composite texture? This is a Bregman question -- auditory stream
// segregation by register, timbre, onset asynchrony.
(
TriadexMuseApplication.run(\faithful, "Musers Waltz",
	baseNote: 60, tempo: 3, amp: 0.2);

TriadexMuseApplication.runSynced(\enhanced, "Polka",
	baseNote: 48, tempo: 3, amp: 0.15, beatOffset: 2);

TriadexMuseApplication.runSynced(\faithful, "Christmas Bells",
	baseNote: 72, tempo: 3, amp: 0.12, beatOffset: 4);
)


// =====================================================================
// 4. Four Muses synced -- ensemble
// =====================================================================
//
// Four registers, four presets, staggered entries. This begins to
// approach something like Nancarrow's tempo canons -- except here all
// voices share a single tempo. The complexity arises not from temporal
// independence but from the combinatorial divergence of four LFSR
// states. Each shift register follows its own trajectory; the vertical
// coincidences are emergent, never planned.
//
// Question: at what point does the listener stop tracking individual
// voices and begin hearing the aggregate as a single harmonic field?
// This is the crossover from polyphony to texture that Truax describes
// in the context of granular synthesis. The Muse produces it from
// discrete pitched events rather than from grains.
(
// Bass voice
TriadexMuseApplication.run(\enhanced, "Flat Baroque",
	baseNote: 36, tempo: 2, amp: 0.2);

// Tenor voice
TriadexMuseApplication.runSynced(\faithful, "Meditation",
	baseNote: 48, amp: 0.18, beatOffset: 0);

// Alto voice -- enters after 4 beats
TriadexMuseApplication.runSynced(\faithful, "Musers Waltz",
	baseNote: 60, amp: 0.15, beatOffset: 4);

// Soprano voice -- enters after 8 beats
TriadexMuseApplication.runSynced(\enhanced, "Swiss Yodeler",
	baseNote: 72, amp: 0.12, beatOffset: 8);
)

// Change tempo for all synced instances at once
TriadexMuseApplication.sharedTempo_(4);
TriadexMuseApplication.sharedTempo_(1.5);


// =====================================================================
// 5. Player without GUI -- headless playback
// =====================================================================
//
// Headless mode is the path toward integration with larger compositional
// systems. The Muse becomes a pitch oracle that can be queried on
// demand -- feeding a Pbind, driving OSC messages, or generating
// material for offline analysis.
(
~player = TriadexMusePlayer.new;
~player.muse.preset_("Musers Waltz");
~player.baseNote = 60;
~player.tempo = 4;
~player.amp = 0.15;
~player.legato = 0.85;
~player.play;
)

// Control while playing
~player.tempo_(6);
~player.preset_("The Crazy Cuckoo");
~player.stop;


// =====================================================================
// 6. Enhanced mode -- waveform, filter, effects
// =====================================================================
//
// The original Muse produced only a square wave. Adding timbral
// variation raises a question about identity: at what point does the
// enhancement dissolve the character of the instrument? The Muse's
// identity is in its melodic logic, not its sound. The square wave is
// incidental -- a consequence of 1969 electronics, not an aesthetic
// decision. So extending the timbre is legitimate, as long as the
// sequence engine remains faithful.
//
// The filter sweep below is interesting: it imposes a continuous
// spectral trajectory onto a discrete pitch sequence. Two time scales
// operating simultaneously -- the stepwise melody and the smooth
// filter arc. This is structurally parallel to Roads' idea of the
// "sound object" having both micro and meso timescales.
(
~player = TriadexMusePlayer.new;
~player.mode = \enhanced;
~player.waveform = \saw;
~player.filterFreq = 2000;
~player.filterRes = 0.6;
~player.reverbMix = 0.4;
~player.delayTime = 0.375;
~player.delayDecay = 2.0;
~player.amp = 0.12;
~player.tempo = 5;
~player.baseNote = 48;
~player.muse.preset_("Meditation");
~player.play;
)

// Sweep the filter -- continuous spectral motion over discrete pitches
(
fork {
	100.do({ |i|
		~player.filterFreq = i.linexp(0, 99, 200, 8000);
		0.05.wait;
	});
};
)

// Adjust effects live
~player.reverbMix_(0.7);
~player.delayTime_(0.25);
~player.stop;


// =====================================================================
// 7. Synthesis types
// =====================================================================
//
// Each synthesis type reframes the same pitch sequence through a
// different acoustic lens. The pluck mode is particularly revealing:
// Karplus-Strong introduces its own spectral evolution per note, so
// the timbre is pitch-dependent in a way the square wave is not.
// The FM mode adds inharmonicity that can mask or reinforce the
// intervallic relationships the Muse computes.
//
// The DPOAE mode is a deliberate provocation: it connects the Muse's
// deterministic pitch logic to the nonlinear mechanics of the cochlea.
// DPOAEs (distortion product otoacoustic emissions) arise from the
// interaction of two tones at specific frequency ratios. Here the
// Muse's output becomes the stimulus for a psychoacoustic phenomenon.

// Faithful square wave (original hardware)
~player = TriadexMusePlayer.play("Scale");

// Sine -- clean, minimal
(
~player = TriadexMusePlayer.new;
~player.mode = \enhanced;
~player.waveform = \sine;
~player.amp = 0.25;
~player.tempo = 2;
~player.baseNote = 72;
~player.legato = 0.95;
~player.muse.preset_("Flat Baroque");
~player.play;
)

~player.stop;


// =====================================================================
// 8. Single-step mode -- manual advance
// =====================================================================
//
// Stepping manually restores something the automatic playback conceals:
// the decision structure. Each step is a state transition, and the
// output pitch is fully determined by the current state. In automatic
// mode the tempo masks this -- you hear melody. In single-step mode
// you hear individual decisions. The difference is perceptual, not
// structural, but it changes how you listen.
(
~player = TriadexMusePlayer.new;
~player.mode = \faithful;
~player.amp = 0.2;
~player.baseNote = 60;
~player.muse.preset_("Scale");
)

// Evaluate repeatedly to step one note at a time:
~player.stepOnce;


// =====================================================================
// 9. Custom scale -- pentatonic
// =====================================================================
//
// The Muse's note output is a 3-bit value (0-7) passed through a
// scale mapping plus an octave bit. Changing the scale mapping
// transforms the intervallic content without touching the shift
// register logic. The same binary sequence, heard through pentatonic
// intervals, produces a qualitatively different musical result.
//
// This is where the scale presets become a research tool. The Muse
// was designed around a major scale. What happens when you feed its
// sequences through Slendro? Through Bohlen-Pierce? Through a
// Xenakis sieve? The combinatorial logic doesn't change, but the
// perceptual effect can be unrecognisable. The question is: how much
// of the Muse's "musicality" is in the sequence logic, and how much
// is in the scale mapping?
(
~player = TriadexMusePlayer.new;
~player.muse.scale_(#[0, 2, 4, 7, 9, 12, 14, 16]);
~player.mode = \enhanced;
~player.waveform = \tri;
~player.filterFreq = 4000;
~player.amp = 0.15;
~player.tempo = 6;
~player.baseNote = 60;
~player.muse.preset_("Birds 1");
~player.play;
)

~player.stop;


// =====================================================================
// 10. Pan modulation -- spatial movement
// =====================================================================
//
// Spatialisation driven by the step counter. The sinusoidal pan curve
// imposes a periodic spatial trajectory onto the aperiodic (or
// long-period) pitch sequence. The spatial and melodic cycles are
// incommensurate, producing a phasing relationship. This is a crude
// version of what ambisonics could do more richly -- each synced
// instance could occupy a different spatial trajectory, creating an
// ensemble distributed in space.
//
// For future work: route each synced Muse to a different DS100 object,
// with spatial position driven by the Muse's own internal state
// (shift register bits, counter values) rather than an external
// function.
(
~player = TriadexMusePlayer.new;
~player.mode = \faithful;
~player.tempo = 6;
~player.amp = 0.15;
~player.muse.preset_("Polka");

~player.muse.onStep = { |muse, pitch|
	~player.pan = sin(muse.stepCount * 0.1);
};

~player.play;
)

~player.stop;


// =====================================================================
// 11. Cycling through all presets
// =====================================================================
//
// Listening to all twenty presets in sequence reveals the range of
// behaviour the Muse can produce from the same mechanism. Some presets
// (Scale, Eds Rhythm Piece) are clearly periodic. Others (Mesopotamia,
// Christmas Bells) produce sequences long enough to sound aperiodic
// within any reasonable listening window. The shift register has a
// maximum cycle length of 2^31 - 1 steps, but the effective period
// depends on which bits the sliders tap.
//
// A systematic study: for each preset, compute the actual cycle length.
// Which presets produce maximal-length sequences? Which produce short
// loops? What is the relationship between slider configuration and
// sequence periodicity?
(
var presets = TriadexMuse.presetNames;
var index = 0;

~player = TriadexMusePlayer.new;
~player.tempo = 4;
~player.amp = 0.15;

~nextPreset = {
	var name = presets[index % presets.size];
	(">>> Now playing: " ++ name).postln;
	~player.preset_(name);
	if(~player.isPlaying.not) { ~player.play };
	index = index + 1;
};

~nextPreset.();
)

// Evaluate to advance:
~nextPreset.();
~player.stop;


// =====================================================================
// 12. Engine only -- no audio, inspect the algorithm
// =====================================================================
//
// The engine without audio is the analytical tool. Here the Muse is
// a number generator, and the questions become combinatorial.
// How many unique pitches does a preset visit? What is the pitch-class
// distribution? How does the autocorrelation function of the sequence
// compare to a random walk on the same pitch set?
//
// The shift register visualisation (available in the GUI) makes the
// internal state visible. Each step shifts one bit in, and the eight
// sliders sample from this evolving bit pattern. The connection to
// LFSR theory is direct: the theme sliders define the feedback
// polynomial, and the interval sliders define the output function.
(
var muse = TriadexMuse.new;

// Set sliders by name: interval [A, B, C, D], theme [W, X, Y, Z]
muse.slidersNamed_("C1", "C2", "C4", "OFF", "OFF", "OFF", "OFF", "OFF");

32.do({ |i|
	var pitch = muse.step;
	("step %: pitch = %  (DCBA = %)".format(
		i + 1,
		pitch ? "rest",
		muse.noteBits.asBinaryString(4)
	)).postln;
});
)

// Generate a sequence and collect as MIDI note numbers
(
var muse = TriadexMuse.new;
muse.preset_("Christmas Bells");
var notes = muse.stepN(128).collect({ |p|
	if(p.notNil) { 60 + p } { \rest }
});
notes.postln;
("Unique pitches: " ++ notes.reject({ |n| n == \rest }).asSet.size).postln;
("Rests: " ++ notes.count({ |n| n == \rest })).postln;
)

// onStep callback -- inspect notes as they are generated
(
var muse = TriadexMuse.new;
var noteNames = ["C", "D", "E", "F", "G", "A", "B", "C'"];

muse.preset_("Scale");
muse.onStep = { |m, pitch|
	if(pitch.notNil) {
		var name = noteNames[muse.noteBits bitAnd: 7];
		("  -> " ++ name ++ " (semitones: " ++ pitch ++ ")").postln;
	} {
		"  -> REST".postln;
	};
};
muse.stepN(16);
)


// =====================================================================
// 13. GUI -- standalone launch
// =====================================================================

~gui = TriadexMuseGUI.new;

// Or with a pre-configured player:
(
var player = TriadexMusePlayer.new;
player.mode = \enhanced;
player.waveform = \saw;
player.filterFreq = 3000;
player.reverbMix = 0.3;
player.muse.preset_("Christmas Bells");
~gui = TriadexMuseGUI(player);
)

// Control programmatically while GUI is open:
~gui.player.tempo_(8);
~gui.muse.scale_(#[0, 2, 3, 5, 7, 8, 10, 12]); // minor
~gui.close;

// Notes on scale presets and microtonal support:
//
// The scale array stores float semitone values (cents / 100), so
// microtonal intervals are preserved at full precision. For example,
// JI Major stores [0, 2.0391, 3.8631, 4.9804, 7.0196, 8.8436, 10.8827, 12.0]
// rather than the 12-TET approximation [0, 2, 4, 5, 7, 9, 11, 12].
//
// The last value in each scale array is the interval of equivalence --
// the interval added by the octave bit (D slider). For standard tunings
// this is 12.0 (the octave). For Bohlen-Pierce it is 19.0196 (the
// tritave). For Carlos Alpha/Beta/Gamma it is a non-octave interval
// (5.46, 4.466, 2.457 semitones respectively).
//
// Scala .scl files are loaded with full cent precision via:
//   muse.loadSCLFile("/path/to/tuning.scl");
//
// Custom scales can be set directly with float values:
//   muse.scale_([0, 1.7143, 3.4286, 5.1429, 6.8571, 8.5714, 10.2857, 12.0]);
//
// The pitch computation is: scale[noteBits & 7] + (scale[7] * octaveBit),
// and the Player converts to frequency via (baseNote + pitch).midicps,
// which handles fractional MIDI values.