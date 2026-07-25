// TriadexMuse — Analyse a sequence from recording
// Infer slider configuration from audio of the Muse.
//
// Requires: FluCoMa quark (Quarks.install("FluCoMa"))
// Boot server first: s.boot;
// Evaluate each ( ) block in order.


// =====================================================================
// 1. Load audio
// =====================================================================
(
~path = Platform.userHomeDir +/+ "Desktop/TriadexMuse/sounds/06 - Maryanne Amacher - Chorale 1.flac";
~srcBuf = Buffer.read(s, ~path, action: { |b|
	postf("Loaded: % frames, %ch, % Hz, % sec\n",
		b.numFrames, b.numChannels, b.sampleRate,
		(b.numFrames / b.sampleRate).round(0.01));
});
)

// Listen
~player = { PlayBuf.ar(2, ~srcBuf, loop: 0, doneAction: 2) }.play;
~player.free;


// =====================================================================
// 1b. Preprocess: stereo -> mono -> bandpass
// =====================================================================
// Adjust loFreq/hiFreq after listening to isolate the Muse.
(
var loFreq = 150, hiFreq = 3000;
var numFrames = ~srcBuf.numFrames;
~monoBuf = Buffer.alloc(s, numFrames, 1);
{
	var sig = PlayBuf.ar(2, ~srcBuf, doneAction: 2);
	var mono = (sig[0] + sig[1]) * 0.5;
	// 4th-order bandpass to isolate Muse register
	4.do({ mono = BPF.ar(mono, (loFreq * hiFreq).sqrt, hiFreq / loFreq) });
	mono = mono * 4; // compensate filter loss
	RecordBuf.ar(mono, ~monoBuf, loop: 0, doneAction: 2);
	Silent.ar;
}.play;
"Processing stereo->mono->BPF...".postln;
)

// Listen to filtered
~filtPlayer = { PlayBuf.ar(1, ~monoBuf, loop: 0, doneAction: 2) ! 2 }.play;
~filtPlayer.free;

// Trim to a section with clear Muse (adjust start/end in seconds)
(
var startTime = 0, endTime = 360;
var sr = ~monoBuf.sampleRate;
var startFrame = (startTime * sr).asInteger;
var numFrames = ((endTime - startTime) * sr).asInteger;
~buf = Buffer.alloc(s, numFrames, 1);
{
	var sig = PlayBuf.ar(1, ~monoBuf, startPos: startFrame, doneAction: 2);
	var env = EnvGen.kr(
		Env([0,1,1,0], [0.01, (numFrames/sr)-0.02, 0.01]), doneAction: 2);
	RecordBuf.ar(sig * env, ~buf, loop: 0, doneAction: 2);
	Silent.ar;
}.play;
postf("Trimmed: %-%s (% frames)\n", startTime, endTime, numFrames);
)

// Listen to trimmed
~trimPlayer = { PlayBuf.ar(1, ~buf, loop: 0, doneAction: 2) ! 2 }.play;
~trimPlayer.free;


// =====================================================================
// 2. Onset detection
// =====================================================================
(
~onsetBuf = Buffer.new(s);
FluidBufOnsetSlice.processBlocking(s, ~buf,
	indices: ~onsetBuf,
	metric: 0,
	threshold: 0.3,
	action: {
		~onsetBuf.loadToFloatArray(action: { |arr|
			~onsets = arr.asInteger;
			postf("Detected % onsets\n", ~onsets.size);
		});
	}
);
)


// =====================================================================
// 3. F0 extraction per note
// =====================================================================
(
~pitchBuf = Buffer.new(s);
FluidBufPitch.processBlocking(s, ~buf,
	features: ~pitchBuf,
	algorithm: 2,
	minFreq: 60,
	maxFreq: 4000,
	action: {
		~pitchBuf.loadToFloatArray(action: { |arr|
			var hopSize = 512;
			var numFrames = arr.size div: 2;
			var freqs = Array.new(numFrames);
			var confs = Array.new(numFrames);

			numFrames.do({ |i|
				freqs = freqs.add(arr[i * 2]);
				confs = confs.add(arr[i * 2 + 1]);
			});

			~noteFreqs = Array.new(~onsets.size);
			~onsets.do({ |onset, i|
				var startFrame, endFrame, segFreqs, segConfs, goodFreqs, medianF0;
				startFrame = (onset / hopSize).floor.asInteger + 1;
				endFrame = if(i < (~onsets.size - 1),
					{ (~onsets[i + 1] / hopSize).floor.asInteger },
					{ numFrames }
				);
				if(startFrame >= endFrame, { startFrame = endFrame - 1 });
				segFreqs = freqs.copyRange(startFrame, endFrame - 1);
				segConfs = confs.copyRange(startFrame, endFrame - 1);
				goodFreqs = [];
				segFreqs.do({ |f, j|
					if((segConfs[j] > 0.8) and: { f > 20 }, {
						goodFreqs = goodFreqs.add(f);
					});
				});
				medianF0 = if(goodFreqs.size > 0,
					{ goodFreqs.sort[goodFreqs.size div: 2] },
					{ nil }
				);
				~noteFreqs = ~noteFreqs.add(medianF0);
			});

			postf("Extracted % note F0s (% pitched, % rests)\n",
				~noteFreqs.size,
				~noteFreqs.reject(_.isNil).size,
				~noteFreqs.count(_.isNil)
			);
		});
	}
);
)

// Inspect
(
~noteFreqs.do({ |f, i| postf("  note %: % Hz\n", i, f ? "rest") });
)


// =====================================================================
// 4. Cluster pitches to find the scale
// =====================================================================
(
var validFreqs, midiVals, rounded, bins;
var clusters, currentCluster;

validFreqs = ~noteFreqs.reject(_.isNil);
midiVals = validFreqs.collect({ |f| f.cpsmidi });
rounded = midiVals.collect({ |m| (m * 2).round / 2 });
bins = rounded.asSet.asArray.sort;

clusters = [];
currentCluster = [bins[0]];
bins.do({ |b, i|
	if(i > 0, {
		if((b - currentCluster.last) < 0.6, {
			currentCluster = currentCluster.add(b);
		}, {
			clusters = clusters.add(currentCluster);
			currentCluster = [b];
		});
	});
});
clusters = clusters.add(currentCluster);

~clusterCentres = clusters.collect({ |c|
	var members = midiVals.select({ |m|
		c.any({ |bin| (m - bin).abs < 0.6 })
	});
	members.sum / members.size;
}).sort;

~recoveredScale = ~clusterCentres.collect({ |m| m - ~clusterCentres[0] });
~baseNote = ~clusterCentres[0];

postf("Found % pitch clusters:\n", ~clusterCentres.size);
~clusterCentres.do({ |midi, i|
	postf("  cluster %: % Hz (MIDI %, +%c)\n",
		i, midi.midicps.round(0.1), midi.round(0.01),
		((midi - ~clusterCentres[0]) * 100).round(0.1));
});
postf("Recovered scale: %\n", ~recoveredScale.collect(_.round(0.01)));
postf("Base MIDI note: %\n", ~baseNote.round(0.01));
)


// =====================================================================
// 5. Map F0 to pitch sequence (cluster indices)
// =====================================================================
(
~pitchSequence = ~noteFreqs.collect({ |f|
	var midi, bestCluster, bestDist;
	if(f.isNil, { nil }, {
		midi = f.cpsmidi;
		bestDist = inf;
		bestCluster = 0;
		~clusterCentres.do({ |centre, j|
			var dist = (midi - centre).abs;
			if(dist < bestDist, {
				bestDist = dist;
				bestCluster = j;
			});
		});
		bestCluster;
	});
});

postf("Pitch sequence (% steps): %\n",
	~pitchSequence.size,
	~pitchSequence.collect({ |p| p ? "R" })
);
)


// =====================================================================
// 6. Test all presets first
// =====================================================================
(
var bestPreset, bestScore = 0;
var seqLen = ~pitchSequence.size;

postf("Testing % presets against % steps...\n",
	TriadexMuse.presetNames.size, seqLen);

TriadexMuse.presetNames.do({ |name|
	var muse = TriadexMuse.new;
	var score = 0;
	muse.preset_(name);

	seqLen.do({ |i|
		var pitch, emCluster, bestDist;
		pitch = muse.step;
		if(~pitchSequence[i].isNil and: { pitch.isNil }, {
			score = score + 1;
		}, {
			if(~pitchSequence[i].notNil and: { pitch.notNil }, {
				bestDist = inf;
				emCluster = 0;
				~recoveredScale.do({ |offset, j|
					var dist = (pitch - offset).abs;
					if(dist < bestDist, {
						bestDist = dist;
						emCluster = j;
					});
				});
				if(emCluster == ~pitchSequence[i], { score = score + 1 });
			});
		});
	});

	postf("  %: %/% (%)\n", name, score, seqLen,
		((score / seqLen * 100).round(0.1).asString ++ "%"));

	if(score > bestScore, {
		bestScore = score;
		bestPreset = name;
	});
});

postf("\nBest match: % (%)\n", bestPreset,
	((bestScore / seqLen * 100).round(0.1).asString ++ "%"));
)

()

// =====================================================================
// 7. Brute-force slider inference (if no preset matches)
// =====================================================================
// This searches all 40^4 theme configs. It will be SLOW in sclang.
// Only run if Step 6 gives < 90% accuracy.
// For faster inference, use the TriadexMuse class method (compiled).
(
var seqLen, targetDCBA, counterStates, sourceAt;
var solutions = [];

seqLen = ~pitchSequence.size.min(64);
postf("Brute-force search using % steps...\n", seqLen);

// Map cluster indices to 4-bit values
targetDCBA = ~pitchSequence[0..seqLen-1].collect({ |ci|
	if(ci.isNil, { nil }, { ci bitAnd: 15 });
});

// Pre-compute counter states
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

// Source value reader
sourceAt = { |position, c32, c6, sr|
	case
	{ position == 0 } { 0 }
	{ position == 1 } { 1 }
	{ position < 7 }  { (c32 >> (position - 2)) bitAnd: 1 }
	{ position < 9 }  { (c6 >> (position - 5)) bitAnd: 1 }
	{ position < 40 } { (sr >> (position - 9)) bitAnd: 1 }
	{ 0 };
};

// Search all theme configs
40.do({ |w|
	40.do({ |x|
		40.do({ |y|
			40.do({ |z|
				var sr = 0, c32 = 1, c6 = 0;
				var valid = true, intervalSliders;
				var srHistory = Array.new(seqLen);
				var newBit;

				// Simulate SR evolution
				seqLen.do({ |step|
					srHistory = srHistory.add(sr);
					newBit = 1;
					newBit = newBit bitXor: sourceAt.value(w, c32, c6, sr);
					newBit = newBit bitXor: sourceAt.value(x, c32, c6, sr);
					newBit = newBit bitXor: sourceAt.value(y, c32, c6, sr);
					newBit = newBit bitXor: sourceAt.value(z, c32, c6, sr);
					c32 = (c32 + 1) bitAnd: 16r1F;
					if((c32 bitAnd: 1) == 0, {
						c6 = c6 + 1;
						if((c6 bitAnd: 3) == 2, { c6 = c6 + 1 });
						sr = ((sr << 1) bitOr: newBit) bitAnd: 16r7FFFFFFF;
					});
				});

				// Test each interval bit independently
				intervalSliders = Array.fill(4, { nil });
				4.do({ |bit|
					var candidates;
					candidates = (0..39).select({ |pos|
						var matches = true;
						seqLen.do({ |step|
							var target, expectedBit, c, actualBit;
							target = targetDCBA[step];
							if(target.notNil, {
								expectedBit = (target >> bit) bitAnd: 1;
								c = counterStates[step];
								actualBit = sourceAt.value(pos, c[0], c[1], srHistory[step]);
								if(actualBit != expectedBit, { matches = false });
							});
						});
						matches;
					});
					if(candidates.size == 0, { valid = false });
					intervalSliders[bit] = candidates;
				});

				if(valid, {
					solutions = solutions.add(
						IdentityDictionary[\theme -> [w,x,y,z],
							\interval -> intervalSliders]
					);
				});
			});
		});
	});
	if((w % 10) == 9, {
		postf("  ... W=0..% done\n", w);
	});
});

~solutions = solutions;
postf("Search complete. Found % solution(s).\n", solutions.size);

solutions.do({ |sol, i|
	postf("\nSolution %:\n", i + 1);
	postf("  Theme [W X Y Z]: %\n",
		sol[\theme].collect({ |p| TriadexMuse.sourceLabels[p] }));
	4.do({ |bit|
		postf("  Interval %: %\n", ["A","B","C","D"][bit],
			sol[\interval][bit].collect({ |p| TriadexMuse.sourceLabels[p] }));
	});
});
)

~pitchSequence.postln;
