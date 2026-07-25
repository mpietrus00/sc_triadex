// TriadexMuse — SuperCollider implementation of the Triadex Muse (1969/1972)
//
// A deterministic algorithmic music composer designed by Edward Fredkin
// and Marvin Minsky at MIT. Generates melodies from binary counters,
// a 31-bit LFSR, and an XNOR gate.
//
// Reference: J. Donald Tillman's JavaScript emulation
// https://till.com/articles/muse/

TriadexMuse {

	// Source row labels (40 positions per slider)
	classvar <sourceLabels;

	// Default major scale mapping: 3-bit value (0-7) -> semitones from root
	// Values are floats to support microtonal intervals (e.g. 3.86 for JI major third)
	classvar <defaultScale;

	// 8 slider positions: interval [A, B, C, D] and theme [W, X, Y, Z]
	// Each value is 0-39, indexing into the binary source table
	var <interval;  // Array[4]: A=weight1, B=weight2, C=weight4, D=octave
	var <theme;     // Array[4]: W, X, Y, Z -> XNOR -> shift register input

	// Internal state
	var <count32;       // 5-bit binary counter (0-31), bit 0 = C 1/2
	var <count6;        // divide-by-3 counter (uses bits 2,3 for C3, C6)
	var <shiftRegister; // 31-bit shift register (B1-B31)

	// Configuration
	var <scale;         // Array[8]: semitone offsets (float) for the 8 note values
	var <rest;          // Boolean: true = substitute rest for lowest note
	var <stepCount;     // Number of steps taken since last reset

	// History
	var <history;       // Array of recent pitches (nil = rest)
	var <>historySize;  // Maximum history length

	// Callbacks
	var <>onStep;       // Function called after each step: { |muse, pitch| }

	*initClass {
		sourceLabels = [
			"OFF", "ON", "C 1/2",
			"C1", "C2", "C4", "C8",
			"C3", "C6"
		] ++ (1..31).collect({ |i| "B" ++ i });

		defaultScale = #[0, 2, 4, 5, 7, 9, 11, 12];
	}

	*new { |scale|
		^super.new.init(scale);
	}

	init { |argScale|
		interval = #[0, 0, 0, 0].copy;
		theme = #[0, 0, 0, 0].copy;
		scale = argScale ?? { defaultScale.copy };
		rest = false;
		historySize = 256;
		history = [];
		onStep = nil;
		this.reset;
	}

	// --- State Management ---

	reset {
		count32 = 1;
		count6 = 0;
		shiftRegister = 0;
		stepCount = 0;
		history = [];
	}

	// --- Slider Setters ---

	// Interval sliders (pitch selection)
	intervalA_ { |pos| interval[0] = pos.clip(0, 39) }
	intervalB_ { |pos| interval[1] = pos.clip(0, 39) }
	intervalC_ { |pos| interval[2] = pos.clip(0, 39) }
	intervalD_ { |pos| interval[3] = pos.clip(0, 39) }

	// Theme sliders (shift register input)
	themeW_ { |pos| theme[0] = pos.clip(0, 39) }
	themeX_ { |pos| theme[1] = pos.clip(0, 39) }
	themeY_ { |pos| theme[2] = pos.clip(0, 39) }
	themeZ_ { |pos| theme[3] = pos.clip(0, 39) }

	// Set all 8 sliders at once: [A, B, C, D, W, X, Y, Z]
	sliders_ { |positions|
		positions.do({ |pos, i|
			if(i < 4) {
				interval[i] = pos.clip(0, 39);
			} {
				theme[i - 4] = pos.clip(0, 39);
			};
		});
	}

	// Set sliders by source label names
	// e.g. muse.slidersNamed_("B7", "B8", "B5", "OFF", "OFF", "B4", "B23", "OFF")
	slidersNamed_ { |...names|
		var positions = names.collect({ |name|
			var idx = sourceLabels.detectIndex({ |label|
				label.toUpper == name.toUpper;
			});
			if(idx.isNil) {
				("TriadexMuse: unknown source label '" ++ name ++ "'").warn;
				0;
			} {
				idx;
			};
		});
		this.sliders_(positions);
	}

	rest_ { |bool| rest = bool }

	scale_ { |newScale|
		if(newScale.size != 8) {
			"TriadexMuse: scale must have exactly 8 values".error;
			^this;
		};
		scale = newScale.copy;
	}

	// --- Binary Source Table ---
	// Returns the current binary value (0 or 1) for a given source position (0-39)

	select { |position|
		case
		{ position == 0 } { ^0 }                                           // OFF
		{ position == 1 } { ^1 }                                           // ON
		{ position < 7 }  { ^(count32 >> (position - 2)) bitAnd: 1 }      // C 1/2, C1, C2, C4, C8
		{ position < 9 }  { ^(count6 >> (position - 5)) bitAnd: 1 }       // C3, C6
		{ position < 40 } { ^(shiftRegister >> (position - 9)) bitAnd: 1 } // B1-B31
		{ ^0 };
	}

	// --- Core Step Function ---
	// Advances the machine one clock tick. Returns the pitch (Integer or nil for rest).

	step {
		var pitch;

		// Advance internal state
		this.prClick;

		// Read pitch from current state
		pitch = this.currentPitch;

		// Record in history
		if(history.size >= historySize) {
			history.removeAt(0);
		};
		history = history.add(pitch);
		stepCount = stepCount + 1;

		// Callback
		onStep.value(this, pitch);

		^pitch;
	}

	// Advance N steps, return array of pitches
	stepN { |n|
		^n.collect({ this.step });
	}

	// --- Internal Clock Logic ---
	// Follows the barbican/multi JS version: compute XNOR before counter increment
	// (more hardware-accurate — XNOR gate reads state before clock edge)

	prClick {
		var newBit;

		// 1. Compute XNOR from current state (before any updates)
		//    XNOR of N inputs = XOR all inputs, then invert
		//    Start with 1, XOR each theme source value
		newBit = 1;
		4.do({ |i|
			newBit = newBit bitXor: this.select(theme[i]);
		});

		// 2. Increment 5-bit counter (0-31)
		//    Bit 0 is "C 1/2" — the clock signal itself
		count32 = (count32 + 1) bitAnd: 16r1F;

		// 3. On falling edge of C 1/2 (bit 0 goes to 0):
		//    advance divide-by-3 counter and shift register
		if((count32 bitAnd: 1) == 0) {

			// Divide-by-6 counter (produces divide-by-3 on bits 2,3)
			// Counts: 0, 1, 3, 4, 5, 7, 8, 9, 11, ...  (skips values where bits 0,1 == 2)
			count6 = count6 + 1;
			if((count6 bitAnd: 3) == 2) {
				count6 = count6 + 1;
			};

			// Shift register: shift left, insert new bit at position 0 (B1)
			// Mask to 31 bits to prevent unbounded integer growth
			shiftRegister = ((shiftRegister << 1) bitOr: newBit) bitAnd: 16r7FFFFFFF;
		};
	}

	// --- Pitch Computation ---

	// Returns the current 4-bit note value (0-15) from interval sliders
	noteBits {
		var dcba = 0;
		4.do({ |i|
			dcba = dcba bitOr: (this.select(interval[i]) << i);
		});
		^dcba;
	}

	// Returns the current pitch as semitones from root (Float), or nil for rest.
	// Supports microtonal scales: the octave bit (D) adds scale[7] -- the
	// interval of equivalence -- which is 12.0 for standard tunings but can
	// be any value (e.g. 18.98 for Bohlen-Pierce tritave).
	currentPitch {
		var dcba = this.noteBits;
		var pitch;

		// Lower 3 bits (A,B,C) index into scale, bit 3 (D) adds the
		// interval of equivalence (last scale value)
		pitch = scale[dcba bitAnd: 7] + (scale[7] * (dcba >> 3));

		// Rest switch: when enabled, lowest note (pitch == 0) becomes rest
		if(rest and: { pitch == 0 }) {
			^nil;
		};

		^pitch;
	}

	// --- State Inspection ---

	// Returns the full state of all 40 binary sources as an array of 0/1
	sourceStates {
		^40.collect({ |i| this.select(i) });
	}

	// Returns shift register contents as array of 31 bits (B1 at index 0)
	shiftRegisterBits {
		^31.collect({ |i| (shiftRegister >> i) bitAnd: 1 });
	}

	// Returns counter bits as an Event for inspection
	counterState {
		^(
			count32: count32,
			count6: count6,
			cHalf: (count32) bitAnd: 1,
			c1: (count32 >> 1) bitAnd: 1,
			c2: (count32 >> 2) bitAnd: 1,
			c4: (count32 >> 3) bitAnd: 1,
			c8: (count32 >> 4) bitAnd: 1,
			c3: (count6 >> 2) bitAnd: 1,
			c6: (count6 >> 3) bitAnd: 1
		);
	}

	// Pretty-print current state
	postState {
		var pitch = this.currentPitch;
		var bits = this.noteBits;
		"TriadexMuse state:".postln;
		("  step: " ++ stepCount).postln;
		("  count32: " ++ count32 ++ " (C1/2=" ++ ((count32) bitAnd: 1)
			++ " C1=" ++ ((count32 >> 1) bitAnd: 1)
			++ " C2=" ++ ((count32 >> 2) bitAnd: 1)
			++ " C4=" ++ ((count32 >> 3) bitAnd: 1)
			++ " C8=" ++ ((count32 >> 4) bitAnd: 1) ++ ")").postln;
		("  count6: " ++ count6 ++ " (C3=" ++ ((count6 >> 2) bitAnd: 1)
			++ " C6=" ++ ((count6 >> 3) bitAnd: 1) ++ ")").postln;
		("  shiftRegister: " ++ shiftRegister.asBinaryString(31)).postln;
		("  noteBits (DCBA): " ++ bits.asBinaryString(4)
			++ " -> pitch: " ++ (pitch ? "rest")).postln;
		("  interval: " ++ interval.collect({ |p| sourceLabels[p] })).postln;
		("  theme: " ++ theme.collect({ |p| sourceLabels[p] })).postln;
	}

	// --- Preset System ---

	// Load a preset by name lookup from the presets dictionary
	preset_ { |name|
		var presets = TriadexMuse.presets;
		var preset = presets[name.asSymbol];
		if(preset.isNil) {
			("TriadexMuse: unknown preset '" ++ name ++ "'").warn;
			("  Available: " ++ presets.keys.asArray.sort).postln;
			^this;
		};
		this.slidersNamed_(*preset[\interval] ++ preset[\theme]);
		this.rest_(preset[\rest] == "REST");
		this.reset;
	}

	// List available preset names
	*presetNames {
		^this.presets.keys.asArray.sort;
	}

	// Presets dictionary — transcribed from Tillman's JS implementation
	*presets {
		^(
			'Michaels Tune': (
				interval: ["B7", "B8", "B5", "OFF"],
				theme: ["OFF", "B4", "B23", "OFF"],
				rest: "NORM"
			),
			'Musers Waltz': (
				interval: ["B10", "B8", "B7", "OFF"],
				theme: ["ON", "C4", "B1", "B2"],
				rest: "NORM"
			),
			'Scale': (
				interval: ["C1", "C2", "C4", "OFF"],
				theme: ["OFF", "OFF", "OFF", "OFF"],
				rest: "NORM"
			),
			'Eds Rhythm Piece': (
				interval: ["B6", "B6", "B6", "C2"],
				theme: ["OFF", "OFF", "B1", "B31"],
				rest: "NORM"
			),
			'The Crazy Cuckoo': (
				interval: ["C1", "B1", "B31", "C8"],
				theme: ["OFF", "OFF", "B1", "B31"],
				rest: "NORM"
			),
			'Birds 1': (
				interval: ["B1", "B2", "B3", "C4"],
				theme: ["B30", "B31", "B31", "B31"],
				rest: "NORM"
			),
			'Birds 2': (
				interval: ["B28", "B29", "B30", "B30"],
				theme: ["B30", "B31", "B31", "B31"],
				rest: "NORM"
			),
			'Dorian Muse': (
				interval: ["ON", "B1", "B3", "C8"],
				theme: ["B1", "B16", "OFF", "OFF"],
				rest: "NORM"
			),
			'Mesopotamia': (
				interval: ["C2", "B5", "B9", "OFF"],
				theme: ["C8", "B9", "B24", "C4"],
				rest: "NORM"
			),
			'Swiss Yodeler': (
				interval: ["B8", "C1", "B16", "OFF"],
				theme: ["B22", "B21", "B16", "OFF"],
				rest: "NORM"
			),
			'Rons Rhapsody': (
				interval: ["B6", "B9", "B6", "C 1/2"],
				theme: ["B31", "C4", "OFF", "C8"],
				rest: "REST"
			),
			'Christmas Bells': (
				interval: ["B31", "B30", "B29", "B28"],
				theme: ["B28", "B29", "B30", "B31"],
				rest: "NORM"
			),
			'Marvins Yodel': (
				interval: ["B2", "B17", "B9", "B25"],
				theme: ["B16", "OFF", "B15", "C1"],
				rest: "REST"
			),
			'Federal Row': (
				interval: ["B14", "B5", "B12", "B2"],
				theme: ["B21", "B24", "C2", "OFF"],
				rest: "NORM"
			),
			'Als Surprise': (
				interval: ["B1", "B5", "B7", "C 1/2"],
				theme: ["C8", "B1", "B7", "B11"],
				rest: "NORM"
			),
			'Meditation': (
				interval: ["B1", "B31", "B14", "OFF"],
				theme: ["OFF", "OFF", "B16", "B31"],
				rest: "NORM"
			),
			'Flat Baroque': (
				interval: ["C1", "B15", "B1", "C 1/2"],
				theme: ["B30", "B29", "B24", "OFF"],
				rest: "REST"
			),
			'Polka': (
				interval: ["B1", "B13", "B11", "C 1/2"],
				theme: ["C8", "B11", "B7", "B1"],
				rest: "REST"
			),
			'Rhyming Couplets': (
				interval: ["B1", "B2", "C4", "C8"],
				theme: ["OFF", "OFF", "B31", "C4"],
				rest: "NORM"
			),
			'Yodle': (
				interval: ["C8", "B2", "B5", "B6"],
				theme: ["OFF", "OFF", "B1", "B31"],
				rest: "NORM"
			)
		);
	}

	// --- Scale Presets ---

	*scalePresets {
		^(
			// --- 12-TET diatonic ---
			'Major':           #[0, 2, 4, 5, 7, 9, 11, 12],
			'Natural Minor':   #[0, 2, 3, 5, 7, 8, 10, 12],
			'Dorian':          #[0, 2, 3, 5, 7, 9, 11, 12],
			'Phrygian':        #[0, 1, 3, 5, 7, 8, 10, 12],
			'Lydian':          #[0, 2, 4, 6, 7, 9, 11, 12],
			'Mixolydian':      #[0, 2, 4, 5, 7, 9, 10, 12],
			'Harmonic Minor':  #[0, 2, 3, 5, 7, 8, 11, 12],

			// --- 12-TET non-diatonic ---
			'Pentatonic':      #[0, 2, 4, 7, 9, 12, 14, 16],
			'Hungarian Minor': #[0, 1, 4, 5, 7, 8, 11, 12],
			'Blues':           #[0, 3, 5, 6, 7, 10, 12, 15],
			'Whole Tone':      #[0, 2, 4, 6, 8, 10, 12, 14],
			'Chromatic':       #[0, 1, 2, 3, 4, 5, 6, 7],
			'Hirajoshi':       #[0, 1, 5, 7, 10, 12, 13, 17],
			'Pelog':           #[0, 1, 3, 7, 8, 12, 13, 15],
			'Slendro':         #[0, 2, 5, 7, 10, 12, 14, 17],
			'Enigmatic':       #[0, 1, 4, 6, 8, 10, 11, 12],
			'Prometheus':      #[0, 2, 4, 6, 9, 10, 12, 14],
			'Augmented':       #[0, 3, 4, 7, 8, 11, 12, 15],
			'Tritone':         #[0, 1, 4, 6, 7, 10, 12, 13],
			'Double Harmonic': #[0, 1, 4, 5, 7, 8, 11, 12],
			'Locrian':         #[0, 1, 3, 5, 6, 8, 10, 12],

			// --- Microtonal: equal divisions ---
			// Values are in semitones (cents / 100). Float precision
			// preserves microtonal intervals that integer rounding collapses.

			// 7-EDO: 7 equal steps per octave (1200/7 = 171.43c each)
			'7-EDO':           [0, 1.7143, 3.4286, 5.1429, 6.8571, 8.5714, 10.2857, 12.0],
			// 5-EDO: 5 equal steps per octave (240c each)
			'5-EDO':           [0, 2.4, 4.8, 7.2, 9.6, 12.0, 14.4, 16.8],
			// 19-EDO subset: first 7 steps (1200/19 = 63.16c each) + octave
			'19-EDO Cluster':  [0, 0.6316, 1.2632, 1.8947, 2.5263, 3.1579, 3.7895, 12.0],
			// 31-EDO diatonic: Fokker's 31-tone equal (1200/31 = 38.71c/step)
			// Major scale: degrees 0,5,10,13,18,23,28,31
			'31-EDO Major':    [0, 1.9355, 3.871, 5.0323, 6.9677, 8.9032, 10.8387, 12.0],

			// --- Fokker periodicity blocks (31-tone lattice) ---
			// Fokker's 7-note periodicity block from the 5-limit lattice
			// Degrees 0,5,10,13,18,23,28 of 31-EDO
			'Fokker PB 7':     [0, 1.9355, 3.871, 5.0323, 6.9677, 8.9032, 10.8387, 12.0],
			// Fokker's "organ" selection: degrees 0,4,8,13,18,22,27,31
			'Fokker 31 Organ': [0, 1.5484, 3.0968, 5.0323, 6.9677, 8.5161, 10.4516, 12.0],

			// --- Just intonation ---
			// Ptolemy intense diatonic (5-limit JI major)
			// 1/1 9/8 5/4 4/3 3/2 5/3 15/8 2/1
			'JI Major':        [0, 2.0391, 3.8631, 4.9804, 7.0196, 8.8436, 10.8827, 12.0],
			// 7-limit JI: 1/1 8/7 7/6 4/3 3/2 12/7 7/4 2/1
			'7-Limit JI':      [0, 2.3104, 2.6691, 4.9804, 7.0196, 9.3309, 9.6896, 12.0],
			// Partch 11-limit diamond (8 from 43)
			// 1/1 12/11 7/6 4/3 3/2 11/7 11/6 2/1
			'Partch Diamond':  [0, 1.5064, 2.6691, 4.9804, 7.0196, 7.8240, 10.4941, 12.0],
			// La Monte Young "Well-Tuned Piano" subset (7-limit)
			// 1/1 567/512 9/8 147/128 21/16 3/2 49/32 7/4 2/1
			'Young WTP':       [0, 1.7715, 2.0391, 2.3869, 4.7104, 7.0196, 7.3791, 12.0],

			// --- Bohlen-Pierce (tritave = 3/1) ---
			// 13 equal divisions of 3:1 (1901.96/13 = 146.30c/step)
			// Lambda mode: steps 0,1,3,4,6,7,9,13
			// Interval of equivalence = tritave = 19.0196 semitones
			'BP Lambda':       [0, 1.463, 4.389, 5.852, 8.778, 10.241, 13.167, 19.0196],

			// --- Wendy Carlos ---
			// Alpha: 78c steps (~15.385 per octave), non-octave repeating
			'Carlos Alpha':    [0, 0.78, 1.56, 2.34, 3.12, 3.90, 4.68, 5.46],
			// Beta: 63.8c steps (~18.8 per octave), non-octave repeating
			'Carlos Beta':     [0, 0.638, 1.276, 1.914, 2.552, 3.190, 3.828, 4.466],
			// Gamma: 35.1c steps (~34.2 per octave), non-octave repeating
			'Carlos Gamma':    [0, 0.351, 0.702, 1.053, 1.404, 1.755, 2.106, 2.457],

			// --- Other ---
			// Xenakis sieve: irregular spacing from Jonchaies (approx)
			'Xenakis Sieve':   [0, 1, 4, 5, 8, 9, 11, 13],
			// Overtone series subset collapsed to one octave
			// Harmonics 1,3,5,7,9,11,13,2 (cents: 0,702,1586,1969,2400,2551,2841,1200
			// mod 1200: 0,702,386,769,0,151,441 -- reordered ascending + octave)
			'Overtone':        [0, 1.51, 3.86, 4.41, 7.02, 7.69, 10.49, 12.0],
			// Quartertone cluster: 50c steps
			'Quartertone':     [0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5],
			// Wilson hexany: 6 notes from 2x2x2 CPS {1,3,5,7}
			// 1/1 7/6 5/4 35/24 5/3 7/4 2/1 (+ 7/3 above)
			'Wilson Hexany':   [0, 2.6691, 3.8631, 6.5322, 8.8436, 9.6896, 12.0, 14.6691]
		);
	}

	*scalePresetNames {
		^this.scalePresets.keys.asArray.sort;
	}

	// Load a named scale preset
	scalePreset_ { |name|
		var presets = TriadexMuse.scalePresets;
		var s = presets[name.asSymbol];
		if(s.isNil) {
			("TriadexMuse: unknown scale preset '" ++ name ++ "'").warn;
			^this;
		};
		this.scale_(s.copy);
	}

	// Parse a Scala .scl file and return an 8-value Muse scale.
	// The Muse needs exactly 8 values (3-bit index 0-7).
	// Scala files list N pitches above an implicit 1/1 unison.
	// We take the first 6 intervals + the pseudo-octave (last pitch),
	// all converted to semitones as floats (preserving microtonal precision).
	// If the file has fewer than 7 pitches, remaining slots fill with
	// the last available value.
	*scaleFromSCLFile { |path|
		var lines, description, pitchCount, pitches, cents, result;

		if(File.exists(path).not) {
			("TriadexMuse: file not found -- " ++ path).error;
			^nil;
		};

		lines = File.use(path, "r", { |f| f.readAllString });
		// Strip \r for Windows line endings
		lines = lines.tr($\r, $ ).split($\n);

		// Strip comment lines (starting with !)
		lines = lines.reject({ |l|
			l.stripWhiteSpace.containsStringAt(0, "!")
		});

		if(lines.size < 2) {
			"TriadexMuse: invalid .scl file -- too few lines".error;
			^nil;
		};

		// First non-comment line = description (may be blank)
		description = lines[0].stripWhiteSpace;
		// Second non-comment line = pitch count
		pitchCount = lines[1].stripWhiteSpace.asInteger;

		if(pitchCount < 1) {
			"TriadexMuse: invalid .scl file -- pitch count < 1".error;
			^nil;
		};

		// Parse pitch lines: cents (has '.') or ratio (has '/')
		cents = Array.new(pitchCount);
		pitchCount.do({ |i|
			var line, val, parts;
			if((i + 2) < lines.size) {
				line = lines[i + 2].stripWhiteSpace;
				// Strip trailing comments
				line = line.split($ ).first;
				if(line.contains(".")) {
					// Cents value
					val = line.asFloat;
				} {
					if(line.contains("/")) {
						// Ratio: num/denom -> cents
						parts = line.split($/);
						val = (parts[0].asFloat / parts[1].asFloat).log2 * 1200;
					} {
						// Bare integer ratio (e.g. "2" means 2/1)
						val = line.asFloat.log2 * 1200;
					};
				};
				// Guard against invalid values from bad ratios
				if(val.isNaN or: { val == inf } or: { val == inf.neg }) {
					("TriadexMuse: invalid pitch on line " ++ (i + 3)).warn;
					val = 0;
				};
				cents = cents.add(val);
			};
		});

		if(cents.size == 0) {
			"TriadexMuse: .scl file has no valid pitches".error;
			^nil;
		};

		if(cents.size > 7) {
			("TriadexMuse: .scl has " ++ cents.size
				++ " pitches; using first 6 + octave for 8-slot mapping").postln;
		};

		// Build 8-value Muse scale (float semitones):
		// Slot 0 = 0 (unison, implicit in .scl)
		// Slots 1-6 = first 6 pitches from file (cents -> semitones)
		// Slot 7 = last pitch (interval of equivalence)
		result = Array.fill(8, { |i|
			if(i == 0) { 0.0 } {
				if(i < 7) {
					if((i - 1) < cents.size) {
						cents[i - 1] / 100;
					} {
						cents.last / 100;
					};
				} {
					cents.last / 100;
				};
			};
		});

		("TriadexMuse: loaded .scl '" ++ description ++ "' -> " ++ result).postln;
		^result;
	}

	// Load a .scl file and apply it as the current scale
	loadSCLFile { |path|
		var s = TriadexMuse.scaleFromSCLFile(path);
		if(s.notNil) { this.scale_(s) };
	}

	// --- Utility ---

	// Convert a source label string to its position index
	*labelToIndex { |label|
		var idx = sourceLabels.detectIndex({ |l|
			l.toUpper == label.toUpper;
		});
		if(idx.isNil) {
			("TriadexMuse: unknown label '" ++ label ++ "'").warn;
		};
		^idx;
	}

	// Convert a position index to its source label
	*indexToLabel { |index|
		if(index < 0 or: { index > 39 }) {
			("TriadexMuse: index " ++ index ++ " out of range 0-39").warn;
			^nil;
		};
		^sourceLabels[index];
	}

	printOn { |stream|
		stream << "TriadexMuse("
		<< "interval: " << interval.collect({ |p| sourceLabels[p] })
		<< ", theme: " << theme.collect({ |p| sourceLabels[p] })
		<< ", step: " << stepCount
		<< ")";
	}
}
