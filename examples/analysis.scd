// TriadexMuse — Audio Analysis Pipeline
// Reverse-engineer slider configuration from a recording of the original hardware.
//
// Requires: FluCoMa (Fluid Corpus Manipulation) quark for pitch/onset analysis.
//   Quarks.install("FluCoMa");
//
// Workflow:
//   Stage 1 — Load audio, detect onsets, extract F0 per note
//   Stage 2 — Recover tempo from inter-onset intervals
//   Stage 3 — Cluster F0 values to find the scale tuning
//   Stage 4 — Map F0 sequence to scale degrees (pitch sequence)
//   Stage 5 — Infer slider positions from the pitch sequence
//   Stage 6 — Validate by running the emulator with inferred sliders
//
// Boot the server first: s.boot;
// Evaluate blocks one at a time (Cmd+Enter)
Server.killAll; // stop any existing synths before starting analysis

// =====================================================================
// Stage 1 — Load audio and extract note events
// =====================================================================
//
// Load a preprocessed recording into a buffer.
// Run preprocess.scd first to produce the mono, filtered file.
// The analysis assumes a monophonic signal with clear onsets.
// For two synced Muses, see Stage 6b at the bottom.
(
~audioPath = Platform.userHomeDir +/+ "Desktop/TriadexMuse/sounds/sequence_one_run.wav";
~buf = Buffer.read(s, ~audioPath, action: { |b| [b.numFrames, b.sampleRate].postln });
)

// --- Onset detection ---
// FluidBufOnsetSlice detects note boundaries.
// The Muse produces sharp-edged square waves, so onset detection is clean.
(
~onsetBuf = Buffer.new(s);
FluidBufOnsetSlice.processBlocking(s, ~buf,
	indices: ~onsetBuf,
	metric: 0,     // 0 = spectral energy (good for square waves)
	threshold: 0.5,
	action: {
		~onsetBuf.loadToFloatArray(action: { |arr|
			~onsets = arr.asInteger;
			("Detected " ++ ~onsets.size ++ " onsets").postln;
		});
	}
);
)

// --- F0 extraction per note segment ---
// For each onset-bounded segment, extract the median F0.
// FluidBufPitch returns [frequency, confidence] per frame.
(
var sr = ~buf.sampleRate;
var hopSize = 512;
~pitchBuf = Buffer.new(s);

FluidBufPitch.processBlocking(s, ~buf,
	features: ~pitchBuf,
	algorithm: 2,   // 2 = YIN (robust for square waves)
	minFreq: 60,
	maxFreq: 4000,
	action: {
		~pitchBuf.loadToFloatArray(action: { |arr|
			var numFrames = arr.size div: 2;
			var freqs = Array.new(numFrames);
			var confs = Array.new(numFrames);

			// FluidBufPitch interleaves [freq, confidence, freq, confidence, ...]
			numFrames.do({ |i|
				freqs = freqs.add(arr[i * 2]);
				confs = confs.add(arr[i * 2 + 1]);
			});

			// For each note segment, take median F0 of confident frames
			~noteFreqs = Array.new(~onsets.size);
			~onsets.do({ |onset, i|
				var startFrame = (onset / hopSize).floor.asInteger;
				var endFrame;
				var segFreqs, segConfs, goodFreqs, medianF0;

				endFrame = if(i < (~onsets.size - 1)) {
					(~onsets[i + 1] / hopSize).floor.asInteger;
				} {
					numFrames;
				};

				// Trim edges (avoid transient at onset)
				startFrame = startFrame + 1;
				if(startFrame >= endFrame) { startFrame = endFrame - 1 };

				segFreqs = freqs.copyRange(startFrame, endFrame - 1);
				segConfs = confs.copyRange(startFrame, endFrame - 1);

				// Keep only frames with confidence > 0.8
				goodFreqs = [];
				segFreqs.do({ |f, j|
					if(segConfs[j] > 0.8 and: { f > 20 }) {
						goodFreqs = goodFreqs.add(f);
					};
				});

				if(goodFreqs.size > 0) {
					medianF0 = goodFreqs.sort[goodFreqs.size div: 2];
				} {
					medianF0 = nil; // rest or too quiet
				};
				~noteFreqs = ~noteFreqs.add(medianF0);
			});

			// Report
			("Extracted " ++ ~noteFreqs.size ++ " note F0 values").postln;
			("  Non-nil: " ++ ~noteFreqs.reject(_.isNil).size).postln;
			("  Rests: " ++ ~noteFreqs.count(_.isNil)).postln;
		});
	}
);
)

// Inspect the raw F0 sequence
~noteFreqs.do({ |f, i| ("  note %: % Hz".format(i, f ? "rest")).postln });


// =====================================================================
// Stage 2 — Tempo recovery
// =====================================================================
//
// The Muse clocks at a fixed rate. The inter-onset intervals should be
// nearly uniform. Outliers indicate rests (multiple clock ticks of silence)
// or detection artifacts.
(
var sr = ~buf.sampleRate;
var iois = Array.new(~onsets.size - 1);

(~onsets.size - 1).do({ |i|
	iois = iois.add((~onsets[i + 1] - ~onsets[i]) / sr);
});

// The minimum IOI is the clock period (rests produce multiples of it)
~iois = iois;
~clockPeriod = iois.sort[iois.size div: 4]; // 25th percentile (robust to rest gaps)
~tempo = 1 / ~clockPeriod;

("Inter-onset intervals:").postln;
("  min: " ++ iois.minItem.round(0.001) ++ " sec").postln;
("  median: " ++ iois.sort[iois.size div: 2].round(0.001) ++ " sec").postln;
("  max: " ++ iois.maxItem.round(0.001) ++ " sec").postln;
("Clock period: " ++ ~clockPeriod.round(0.0001) ++ " sec").postln;
("Tempo: " ++ ~tempo.round(0.01) ++ " notes/sec").postln;
)


// =====================================================================
// Stage 3 — Scale clustering
// =====================================================================
//
// Cluster the extracted F0 values to find the 8 (or fewer) pitch
// positions the resistor network produces. Working in MIDI (log-freq)
// space so that equal perceptual intervals have equal distance.
(
var validFreqs = ~noteFreqs.reject(_.isNil);
var midiVals = validFreqs.collect({ |f| f.cpsmidi });

// Simple histogram-based clustering:
// Round to nearest quarter-tone (0.5 semitones) and group
var rounded = midiVals.collect({ |m| (m * 2).round / 2 });
var bins = rounded.asSet.asArray.sort;

// Merge bins that are within 0.6 semitones of each other
var clusters = [];
var currentCluster = [bins[0]];
bins.do({ |b, i|
	if(i > 0) {
		if((b - currentCluster.last) < 0.6) {
			currentCluster = currentCluster.add(b);
		} {
			clusters = clusters.add(currentCluster);
			currentCluster = [b];
		};
	};
});
clusters = clusters.add(currentCluster);

// Cluster centres = mean MIDI value of each cluster
~clusterCentres = clusters.collect({ |c|
	var members = midiVals.select({ |m|
		c.any({ |bin| (m - bin).abs < 0.6 })
	});
	members.sum / members.size;
});

~clusterCentres = ~clusterCentres.sort;

("Found " ++ ~clusterCentres.size ++ " pitch clusters:").postln;
~clusterCentres.do({ |midi, i|
	var freq = midi.midicps;
	var cents = ((midi - ~clusterCentres[0]) * 100).round(0.1);
	("  cluster %: % Hz (MIDI %, +%c from root)".format(
		i, freq.round(0.1), midi.round(0.01), cents
	)).postln;
});

// Derive the scale as semitone offsets from the lowest cluster
~recoveredScale = ~clusterCentres.collect({ |m| m - ~clusterCentres[0] });
~baseNote = ~clusterCentres[0];

("Recovered scale (semitones from root): " ++ ~recoveredScale.collect(_.round(0.01))).postln;
("Base MIDI note: " ++ ~baseNote.round(0.01)).postln;
)


// =====================================================================
// Stage 4 — Pitch sequence recovery
// =====================================================================
//
// Map each note's F0 to its nearest scale cluster, producing the
// sequence of 4-bit note values the Muse output at each step.
// Also reconstruct rest positions.
(
var stepTime = ~clockPeriod;
var sr = ~buf.sampleRate;
var totalSteps = (~buf.numFrames / sr / stepTime).floor.asInteger;

// Build the full step-by-step sequence, including rests
~pitchSequence = Array.fill(totalSteps, { |stepIdx|
	var stepSample = (stepIdx * stepTime * sr).round.asInteger;
	var matchedOnset, noteF0, bestCluster, bestDist, midi;

	// Find the onset closest to this step position
	matchedOnset = ~onsets.detectIndex({ |onset, i|
		var nextOnset = if(i < (~onsets.size - 1)) { ~onsets[i + 1] } { inf };
		(onset <= stepSample) and: { stepSample < nextOnset }
	});

	if(matchedOnset.notNil) {
		noteF0 = ~noteFreqs[matchedOnset];
	} { noteF0 = nil };

	if(noteF0.notNil) {
		// Find nearest cluster
		midi = noteF0.cpsmidi;
		bestDist = inf; bestCluster = 0;
		~clusterCentres.do({ |centre, j|
			var dist = (midi - centre).abs;
			if(dist < bestDist) {
				bestDist = dist;
				bestCluster = j;
			};
		});
		bestCluster;
	} {
		nil; // rest
	};
});

("Recovered " ++ totalSteps ++ " steps").postln;
("  Pitched: " ++ ~pitchSequence.reject(_.isNil).size).postln;
("  Rests: " ++ ~pitchSequence.count(_.isNil)).postln;
("First 32 steps: " ++ ~pitchSequence[0..31].collect({ |p| p ? "R" })).postln;
)

()
// =====================================================================
// Stage 5 — Slider inference
// =====================================================================
//
// Given the recovered pitch sequence, find the 8 slider positions
// that reproduce it. The approach:
//
// 1. The counters (count32, count6) are deterministic from step 0.
// 2. For each candidate theme slider configuration (W, X, Y, Z):
//    - Simulate the shift register evolution
//    - All 40 sources are now known at every step
//    - Test each interval slider position against the observed output
// 3. Early termination: reject theme configs as soon as they fail.
//
// The search space: 40^4 theme configs = 2,560,000.
// With early termination most are rejected within a few steps.
(
var seqLen = ~pitchSequence.size.min(200);
var seq = ~pitchSequence[0..seqLen-1];
var numClusters = ~clusterCentres.size;
var intervalOfEquiv;
var clusterToDCBA, targetDCBA, counterStates, sourceAt;
var solutions = [];

// The 9th cluster is probably the octave of the 1st
intervalOfEquiv = if(numClusters > 8,
	{ ~clusterCentres[8] - ~clusterCentres[0] }, { nil });

// Convert cluster index to DCBA (4-bit note value)
clusterToDCBA = { |clusterIdx|
	var degree, octave;
	if(clusterIdx.isNil, { nil }, {
		if(numClusters <= 8, {
			clusterIdx bitAnd: 15;
		}, {
			degree = clusterIdx % 8;
			octave = clusterIdx div: 8;
			degree bitOr: (octave << 3);
		});
	});
};

targetDCBA = seq.collect({ |ci| clusterToDCBA.(ci) });

// Pre-compute counter states at each step
counterStates = Array.fill(seqLen, { |i|
	var c32 = 1, c6 = 0;
	i.do({
		c32 = (c32 + 1) bitAnd: 16r1F;
		if((c32 bitAnd: 1) == 0, {
			c6 = c6 + 1;
			if((c6 bitAnd: 3) == 2, { c6 = c6 + 1 });
		});
	});
	[c32, c6];
});

// Source value reader (given counter state and SR value)
sourceAt = { |position, c32, c6, sr|
	case
	{ position == 0 } { 0 }
	{ position == 1 } { 1 }
	{ position < 7 }  { (c32 >> (position - 2)) bitAnd: 1 }
	{ position < 9 }  { (c6 >> (position - 5)) bitAnd: 1 }
	{ position < 40 } { (sr >> (position - 9)) bitAnd: 1 }
	{ 0 };
};

("Searching " ++ (40 ** 4).asInteger ++ " theme configurations...").postln;
("Using first " ++ seqLen ++ " steps for inference.").postln;

// --- Search theme sliders ---
40.do({ |w|
	40.do({ |x|
		40.do({ |y|
			40.do({ |z|
				var sr = 0, c32 = 1, c6 = 0;
				var valid = true, intervalSliders;
				var srHistory = Array.new(seqLen);

				// Simulate SR evolution with this theme config
				seqLen.do({ |step|
					var newBit;
					srHistory = srHistory.add(sr);
					newBit = 1;
					newBit = newBit bitXor: sourceAt.(w, c32, c6, sr);
					newBit = newBit bitXor: sourceAt.(x, c32, c6, sr);
					newBit = newBit bitXor: sourceAt.(y, c32, c6, sr);
					newBit = newBit bitXor: sourceAt.(z, c32, c6, sr);
					c32 = (c32 + 1) bitAnd: 16r1F;
					if((c32 bitAnd: 1) == 0, {
						c6 = c6 + 1;
						if((c6 bitAnd: 3) == 2, { c6 = c6 + 1 });
						sr = ((sr << 1) bitOr: newBit) bitAnd: 16r7FFFFFFF;
					});
				});

				// Test interval sliders against observed output
				intervalSliders = Array.fill(4, { nil });
				4.do({ |bit|
					var candidates = (0..39).select({ |pos|
						var matches = true;
						seqLen.do({ |step|
							var target = targetDCBA[step];
							var expectedBit, c, actualBit;
							if(target.notNil, {
								expectedBit = (target >> bit) bitAnd: 1;
								c = counterStates[step];
								actualBit = sourceAt.(pos, c[0], c[1], srHistory[step]);
								if(actualBit != expectedBit, { matches = false });
							});
						});
						matches;
					});
					if(candidates.size == 0, { valid = false });
					if(candidates.size >= 1, {
						intervalSliders[bit] = candidates;
					});
				});

				if(valid, {
					solutions = solutions.add((
						theme: [w, x, y, z],
						interval: intervalSliders,
						themeLabels: [w, x, y, z].collect({ |p|
							TriadexMuse.sourceLabels[p]
						}),
						intervalLabels: intervalSliders.collect({ |cands|
							cands.collect({ |p| TriadexMuse.sourceLabels[p] })
						})
					));
				});
			});
		});
	});
	if((w % 10) == 9, {
		("  ... searched W=0..% (%%)".format(
			w, ((w + 1) / 40 * 100).round(1)
		)).postln;
	});
});

~solutions = solutions;
("Search complete. Found " ++ solutions.size ++ " solution(s).").postln;

if(solutions.size > 0, {
	solutions.do({ |sol, i|
		("").postln;
		("Solution %:".format(i + 1)).postln;
		("  Theme  [W X Y Z]: " ++ sol.themeLabels).postln;
		("  Interval A (bit 0): " ++ sol.intervalLabels[0]).postln;
		("  Interval B (bit 1): " ++ sol.intervalLabels[1]).postln;
		("  Interval C (bit 2): " ++ sol.intervalLabels[2]).postln;
		("  Interval D (bit 3): " ++ sol.intervalLabels[3]).postln;
	});
});
)


// =====================================================================
// Stage 6 — Validation
// =====================================================================
//
// Run the emulator with the inferred slider configuration and compare
// its output against the recovered pitch sequence.
(
if(~solutions.size > 0) {
	var sol = ~solutions[0];
	var muse = TriadexMuse.new;
	var seqLen = ~pitchSequence.size.min(200);
	var matches = 0, mismatches = 0, restMatches = 0;

	// Use first candidate for each interval slider
	muse.sliders_(
		sol.interval.collect(_.first) ++ sol.theme
	);

	// Restore the recovered scale
	if(~recoveredScale.size == 8) {
		muse.scale_(~recoveredScale);
	};

	seqLen.do({ |i|
		var emulatedPitch = muse.step;
		var targetCluster = ~pitchSequence[i];
		var emulatedCluster, bestDist;

		if(targetCluster.isNil and: { emulatedPitch.isNil }) {
			restMatches = restMatches + 1;
		} {
			if(targetCluster.notNil and: { emulatedPitch.notNil }) {
				// Compare: map emulated pitch to cluster index
				emulatedCluster = nil;
				bestDist = inf;
				~recoveredScale.do({ |offset, j|
					var dist = (emulatedPitch - offset).abs;
					if(dist < bestDist) {
						bestDist = dist;
						emulatedCluster = j;
					};
				});
				if(emulatedCluster == targetCluster) {
					matches = matches + 1;
				} {
					mismatches = mismatches + 1;
					if(mismatches <= 5) {
						("  Mismatch at step %: expected cluster %, got pitch % (cluster %)".format(
							i, targetCluster, emulatedPitch, emulatedCluster
						)).postln;
					};
				};
			} {
				mismatches = mismatches + 1;
			};
		};
	});

	("").postln;
	("Validation over " ++ seqLen ++ " steps:").postln;
	("  Pitch matches: " ++ matches).postln;
	("  Rest matches:  " ++ restMatches).postln;
	("  Mismatches:    " ++ mismatches).postln;
	("  Accuracy:      " ++ ((matches + restMatches) / seqLen * 100).round(0.1) ++ "%").postln;
} {
	"No solutions to validate.".postln;
};
)


// =====================================================================
// Stage 6b — Two synced Muses (source separation)
// =====================================================================
//
// If the recording contains two Muses playing simultaneously:
//
// Option A: If they are in different registers, bandpass filter first,
//   then run the pipeline above on each band separately.
//
// Option B: If the recording is stereo and the units were panned,
//   analyse left and right channels independently.
//
// Option C: Onset-aligned separation. If beatOffset is non-zero,
//   the onsets are staggered on the shared clock grid. Detect all
//   onsets, quantise to the clock grid, assign odd/even grid positions
//   to voice A and B.

// --- Option A: Register separation ---
(
// Assuming voice 1 is in the lower register, voice 2 in the upper.
// Adjust the crossover frequency based on the specific recording.
var crossover = 500; // Hz — adjust as needed

~loBuf = Buffer.new(s);
~hiBuf = Buffer.new(s);

// Low-pass for voice 1
SynthDef(\bpExtract, { |inBuf, outBuf, loFreq = 20, hiFreq = 500|
	var sig = PlayBuf.ar(1, inBuf, doneAction: 2);
	sig = BPF.ar(sig, (loFreq * hiFreq).sqrt, hiFreq / loFreq);
	RecordBuf.ar(sig, outBuf, loop: 0, doneAction: 2);
}).add;

// In practice, use FluidBufHPSS or NMF for cleaner separation:
//
// FluidBufHPSS.processBlocking(s, ~buf,
//     harmonic: ~harmonicBuf,
//     percussive: ~percBuf,
//     harmFilterSize: 31,
//     percFilterSize: 31
// );
//
// Or FluidBufNMF with 2 components, seeded with harmonic templates
// derived from the expected F0 ranges of each voice.

"See comments for separation approaches.".postln;
"After separation, run Stages 1-6 on each voice buffer independently.".postln;
)

// --- Option C: Onset-staggered separation ---
(
// If you know (or suspect) the two Muses share a clock with a
// half-beat offset, quantise all onsets to the grid and split.
var gridSize = ~clockPeriod / 2; // half-beat grid
var sr = ~buf.sampleRate;

var quantised = ~onsets.collect({ |onset|
	var timeSec = onset / sr;
	var gridPos = (timeSec / gridSize).round.asInteger;
	(onset: onset, gridPos: gridPos, time: timeSec)
});

var voiceA = quantised.select({ |ev| (ev.gridPos % 2) == 0 });
var voiceB = quantised.select({ |ev| (ev.gridPos % 2) == 1 });

("Grid quantisation (grid = " ++ (gridSize * 1000).round(0.1) ++ " ms):").postln;
("  Voice A: " ++ voiceA.size ++ " onsets (even grid positions)").postln;
("  Voice B: " ++ voiceB.size ++ " onsets (odd grid positions)").postln;
("Analyse each voice separately through Stages 1-6.").postln;
)


// =====================================================================
// Utilities — compare against known presets
// =====================================================================
//
// If you suspect the recording uses a factory preset, you can test
// all 20 presets against the recovered sequence directly.
(
var seqLen = ~pitchSequence.size.min(200);
var targetSeq = ~pitchSequence[0..seqLen-1];
var bestPreset, bestScore = 0;

TriadexMuse.presetNames.do({ |name|
	var muse = TriadexMuse.new;
	var score = 0;
	muse.preset_(name);

	if(~recoveredScale.notNil and: { ~recoveredScale.size == 8 }) {
		muse.scale_(~recoveredScale);
	};

	seqLen.do({ |i|
		var pitch = muse.step;
		var target = targetSeq[i];
		var emCluster, bestDist;

		if(target.isNil and: { pitch.isNil }) {
			score = score + 1;
		} {
			if(target.notNil and: { pitch.notNil }) {
				// Compare via cluster index
				emCluster = nil;
				bestDist = inf;
				~recoveredScale.do({ |offset, j|
					var dist = (pitch - offset).abs;
					if(dist < bestDist) {
						bestDist = dist;
						emCluster = j;
					};
				});
				if(emCluster == target) { score = score + 1 };
			};
		};
	});

	("  " ++ name ++ ": " ++ score ++ "/" ++ seqLen
		++ " (" ++ (score / seqLen * 100).round(0.1) ++ "%)").postln;

	if(score > bestScore) {
		bestScore = score;
		bestPreset = name;
	};
});

("").postln;
("Best match: " ++ bestPreset ++ " (" ++ (bestScore / seqLen * 100).round(0.1) ++ "%)").postln;
)


// =====================================================================
// Utility — export analysis results
// =====================================================================
(
var path = "~/Desktop/muse_analysis.txt".standardizePath;
var file = File(path, "w");

file.write("TriadexMuse Audio Analysis Results\n");
file.write("==================================\n\n");
file.write("Source: " ++ ~audioPath ++ "\n\n");

file.write("Tempo: " ++ ~tempo.round(0.01) ++ " notes/sec\n");
file.write("Clock period: " ++ (~clockPeriod * 1000).round(0.1) ++ " ms\n");
file.write("Base note: MIDI " ++ ~baseNote.round(0.01)
	++ " (" ++ ~baseNote.round(0.01).midicps.round(0.1) ++ " Hz)\n\n");

file.write("Recovered scale (semitones from root):\n");
~recoveredScale.do({ |val, i|
	file.write("  degree " ++ i ++ ": " ++ val.round(0.01)
		++ " (" ++ (~clusterCentres[i].midicps.round(0.1)) ++ " Hz)\n");
});

file.write("\nDeviation from 12-TET major [0,2,4,5,7,9,11,12]:\n");
[0, 2, 4, 5, 7, 9, 11, 12].do({ |ideal, i|
	if(i < ~recoveredScale.size) {
		var deviation = (~recoveredScale[i] - ideal) * 100; // cents
		file.write("  degree " ++ i ++ ": " ++ deviation.round(0.1) ++ " cents\n");
	};
});

if(~solutions.notNil and: { ~solutions.size > 0 }) {
	var sol = ~solutions[0];
	file.write("\nInferred slider configuration:\n");
	file.write("  Theme  [W X Y Z]: " ++ sol.themeLabels ++ "\n");
	4.do({ |i|
		file.write("  Interval " ++ ["A", "B", "C", "D"][i]
			++ ": " ++ sol.intervalLabels[i] ++ "\n");
	});
};

file.write("\nPitch sequence (first 64 steps):\n");
~pitchSequence[0..63].do({ |p, i|
	file.write("  step " ++ (i+1) ++ ": " ++ (p ? "rest") ++ "\n");
});

file.close;
("Exported to: " ++ path).postln;
)
