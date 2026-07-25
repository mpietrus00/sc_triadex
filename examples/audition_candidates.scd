// TriadexMuse — Audition candidate slider configurations WITH GUI
// Compare each with sequence_one_run.wav by ear.
//
// Boot server first: s.boot;

// =====================================================================
// 1. Open the Muse GUI
// =====================================================================
(
~player = TriadexMusePlayer.new;
~player.baseNote_(96);  // ~2200 Hz base — Amacher's operating range
~gui = TriadexMuseGUI(~player);
)

// =====================================================================
// 2. Load reference recording
// =====================================================================
(
~refPath = Platform.userHomeDir +/+ "Desktop/TriadexMuse/sounds/sequence_one_run.wav";
~refBuf = Buffer.read(s, ~refPath, action: { |b|
	postf("Reference loaded: % sec\n", (b.numFrames / b.sampleRate).round(0.01));
});
)

// Play reference
~refPlayer = { PlayBuf.ar(1, ~refBuf, loop: 0, doneAction: 2) ! 2 * 0.5 }.play;


// =====================================================================
// 3. Set candidate sliders — GUI updates automatically
// =====================================================================
// Evaluate ONE block at a time. The GUI matrix will show the slider
// positions. Then use the GUI transport (or ~player.play) to audition.

// --- Candidate 1: simple counter sources ---
(
~player.muse.sliders_([13, 3, 13, 10, 5, 0, 4, 13]);
~gui.matrixView.refresh;
"Candidate 1: interval=[B5,C1,B5,B2] theme=[C4,OFF,C2,B5]".postln;
)

// --- Candidate 2 ---
(
~player.muse.sliders_([9, 11, 16, 9, 15, 10, 3, 0]);
~gui.matrixView.refresh;
"Candidate 2: interval=[B1,B3,B8,B1] theme=[B7,B2,C1,OFF]".postln;
)

// --- Candidate 3 ---
(
~player.muse.sliders_([4, 15, 12, 19, 22, 32, 13, 27]);
~gui.matrixView.refresh;
"Candidate 3: interval=[C2,B7,B4,B11] theme=[B14,B24,B5,B19]".postln;
)

// --- Candidate 4 ---
(
~player.muse.sliders_([5, 12, 13, 18, 23, 19, 8, 3]);
~gui.matrixView.refresh;
"Candidate 4: interval=[C4,B4,B5,B10] theme=[B15,B11,C6,C1]".postln;
)

// --- Candidate 5 ---
(
~player.muse.sliders_([8, 4, 13, 14, 3, 14, 19, 15]);
~gui.matrixView.refresh;
"Candidate 5: interval=[C6,C2,B5,B6] theme=[C1,B6,B11,B7]".postln;
)

// --- Candidate 6 ---
(
~player.muse.sliders_([17, 12, 7, 10, 17, 3, 37, 9]);
~gui.matrixView.refresh;
"Candidate 6: interval=[B9,B4,C3,B2] theme=[B9,C1,B29,B1]".postln;
)

// --- Candidate 7 ---
(
~player.muse.sliders_([1, 9, 19, 14, 31, 29, 9, 11]);
~gui.matrixView.refresh;
"Candidate 7: interval=[ON,B1,B11,B6] theme=[B23,B21,B1,B3]".postln;
)


// =====================================================================
// Quick helper: set sliders and play
// =====================================================================
(
~tryConfig = { |sliders, label|
	~player.stop;
	~player.muse.sliders_(sliders);
	~player.muse.reset;
	~gui.matrixView.refresh;
	postf("--- % ---\n", label);
	postf("  interval: %\n", sliders[0..3].collect({ |p| TriadexMuse.sourceLabels[p] }));
	postf("  theme:    %\n", sliders[4..7].collect({ |p| TriadexMuse.sourceLabels[p] }));
	~player.play;
};
)

// Use like:
~tryConfig.([13, 3, 13, 10, 5, 0, 4, 13], "Candidate 1");

// Play reference for A/B comparison
~refPlayer = { PlayBuf.ar(1, ~refBuf, loop: 1, doneAction: 2) ! 2 * 0.5 }.play;

// Cmd+. to stop everything
