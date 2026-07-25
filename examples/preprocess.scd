// TriadexMuse — Audio Preprocessing
// Prepare recordings for the analysis pipeline.
//
// Amacher's recordings contain the Muse within a produced mix:
// room acoustics, layered sources, possible processing. The analysis
// pipeline expects a monophonic signal with clear onsets. This script
// isolates the Muse as far as possible before analysis.
//
// Boot the server first: s.boot;
// Place cursor inside a block and Cmd+Enter to evaluate.

(

	
)
// =====================================================================
// 1. Load source files
// =====================================================================
(
~soundsDir = if(thisProcess.nowExecutingPath.notNil,
	{ thisProcess.nowExecutingPath.dirname +/+ "../sounds" },
	{ Platform.userHomeDir +/+ "Desktop/TriadexMuse/sounds" }
);

~srcBuf = Buffer.read(s,
	~soundsDir +/+ "Triadex Excerpt_Maryanne Amacher - Synaptic Island.wav",
	action: { |b|
		("Loaded: " ++ b.numFrames ++ " frames, "
			++ b.numChannels ++ "ch, "
			++ (b.numFrames / b.sampleRate).round(0.01) ++ " sec").postln;
	}
);
)

// For Dense Boogie instead:
// (
// ~soundsDir = thisProcess.nowExecutingPath.dirname +/+ "../sounds";
// ~srcBuf = Buffer.read(s,
//     ~soundsDir +/+ "05 - Maryanne Amacher - Dense Boogie 1 - (1995).flac",
//     action: { |b| ("Loaded: " ++ (b.numFrames / b.sampleRate).round(0.01) ++ " sec").postln }
// );
// )

// Listen
~srcPlayer = { PlayBuf.ar(2, ~srcBuf, loop: 0, doneAction: 2) }.play;

~srcPlayer.free;


// =====================================================================
// 2. Convert stereo to mono
// =====================================================================
(
~monoBuf = Buffer.alloc(s, ~srcBuf.numFrames, 1);
{
	var sig = PlayBuf.ar(2, ~srcBuf, doneAction: 2);
	var mono = (sig[0] + sig[1]) * 0.5;
	RecordBuf.ar(mono, ~monoBuf, loop: 0, doneAction: 2);
	Silent.ar;
}.play;
)

// Listen to mono
~monoPlayer = { PlayBuf.ar(1, ~monoBuf, loop: 0, doneAction: 2) ! 2 }.play;

~monoPlayer.free;


// =====================================================================
// 3. Spectral inspection -- find the Muse
// =====================================================================
//
// The Muse produces a square wave: strong odd harmonics (1f, 3f, 5f...)
// with 1/n rolloff. Look for a harmonic comb in the spectrum.

~inspectSynth = { PlayBuf.ar(1, ~monoBuf, 1, loop: 1) ! 2 }.play;

FreqScope.new(800, 400, 0);

// Slow down
~inspectSynth.free;

~inspectSynth = { PlayBuf.ar(1, ~monoBuf, 0.5, loop: 1) ! 2 }.play;

~inspectSynth.free;

// Note the approximate range after listening:
// For Amacher Muse work, expect roughly 200-2000 Hz fundamentals.


// =====================================================================
// 4. Bandpass filter -- isolate the Muse register
// =====================================================================
//
// Adjust loFreq and hiFreq based on what you heard above.
(
var loFreq = 130;
var hiFreq = 2000;
~filtBuf = Buffer.alloc(s, ~monoBuf.numFrames, 1);
{
	var sig = PlayBuf.ar(1, ~monoBuf, doneAction: 2);
	4.do({
		sig = BPF.ar(sig, (loFreq * hiFreq).sqrt, hiFreq / loFreq);
	});
	sig = sig * 4;
	RecordBuf.ar(sig, ~filtBuf, loop: 0, doneAction: 2);
	Silent.ar;
}.play;
)

// Listen to filtered
~filtPlayer = { PlayBuf.ar(1, ~filtBuf, loop: 0, doneAction: 2) ! 2 }.play;

~filtPlayer.free;


// =====================================================================
// 5. Trim (optional -- skip if Muse is present throughout)
// =====================================================================
//
// For Dense Boogie, the Muse may only appear in certain passages.
// Set start and end times, or skip this block entirely.
(
var startTime = 10;
var endTime = 170;
var sr = s.sampleRate;
var startFrame = (startTime * sr).asInteger;
var endFrame = (endTime * sr).asInteger;
var numFrames = endFrame - startFrame;
~trimBuf = Buffer.alloc(s, numFrames, 1);
{
	var sig = PlayBuf.ar(1, ~filtBuf, startPos: startFrame, doneAction: 2);
	var env = EnvGen.kr(
		Env([0, 1, 1, 0], [0.01, (numFrames / sr) - 0.02, 0.01]),
		doneAction: 2
	);
	RecordBuf.ar(sig * env, ~trimBuf, loop: 0, doneAction: 2);
	Silent.ar;
}.play;
)

// If skipping trim, just alias filtBuf:
~trimBuf = ~filtBuf;

// Listen
~trimPlayer = { PlayBuf.ar(1, ~trimBuf, loop: 0, doneAction: 2) ! 2 }.play;

~trimPlayer.free;


// =====================================================================
// 6. Normalise
// =====================================================================
(
~trimBuf.loadToFloatArray(action: { |arr|
	var peak = arr.abs.maxItem;
	~normGain = if(peak > 0) { 0.95 / peak } { 1 };
	("Peak: " ++ peak.round(0.0001) ++ ", gain: " ++ ~normGain.round(0.01)).postln;
});
)

// Wait for the above to print, then:
(
~normBuf = Buffer.alloc(s, ~trimBuf.numFrames, 1);
{
	var sig = PlayBuf.ar(1, ~trimBuf, doneAction: 2) * ~normGain;
	RecordBuf.ar(sig, ~normBuf, loop: 0, doneAction: 2);
	Silent.ar;
}.play;
)


// =====================================================================
// 7. Export preprocessed file
// =====================================================================
(
~normBuf.write(
	~soundsDir +/+ "muse_preprocessed.wav",
	"wav", "int16",
	completionMessage: {
		("Exported: " ++ ~soundsDir +/+ "muse_preprocessed.wav").postln;
	}
);
)

// Done. Now open analysis.scd -- it reads sounds/muse_preprocessed.wav
