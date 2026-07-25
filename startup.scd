// =====================================================================
// TriadexMuse — Startup
// =====================================================================
//
// The simplest way to use TriadexMuse: evaluate the two blocks below
// (place the cursor on a line and press Cmd/Ctrl + Return).
//
// This launches the graphical interface, which is the recommended entry
// point for most users. Scripting examples follow further down.
//
// Requirements:
//   - SuperCollider 3.12 or later
//   - The TriadexMuse Classes folder installed as a Quark or placed in
//     your SuperCollider Extensions directory. See README.md.
// =====================================================================


// ---------------------------------------------------------------------
// 1. Boot the audio server
// ---------------------------------------------------------------------

s.boot;


// ---------------------------------------------------------------------
// 2. Launch the graphical application
// ---------------------------------------------------------------------
// Opens the main window with sliders, transport, source-state display,
// and shift register visualisation. Click Play and experiment.

TriadexMuseApplication.run;


// =====================================================================
// Optional: launch variants
// =====================================================================
// If you want to start with a specific preset, mode, or tempo, evaluate
// one of the lines below *instead* of the plain `run` call above.

// TriadexMuseApplication.run(preset: "Polka");
// TriadexMuseApplication.run(preset: "Birds 1");
// TriadexMuseApplication.run(preset: "Meditation");

// Enhanced mode: selectable waveform, resonant filter, reverb, delay
// TriadexMuseApplication.run(\enhanced);
// TriadexMuseApplication.run(\enhanced, "Michaels Tune");

// Full parameter control
/*
TriadexMuseApplication.run(
    mode: \faithful,
    preset: "Scale",
    baseNote: 48,   // C3
    tempo: 6,       // notes per second
    amp: 0.15
);
*/


// =====================================================================
// Synced Muses — running multiple instances on a shared clock
// =====================================================================
//
// The original Triadex Muse had a sync output so two units could be
// clocked together, producing interlocking sequences from different
// slider configurations. We reproduce this with a shared TempoClock.
//
// HOW IT WORKS:
//
//   TriadexMuseApplication.run launches the primary instance with its
//   own private TempoClock.
//
//   TriadexMuseApplication.runSynced launches additional instances that
//   all share a single TempoClock. On the first runSynced call, a
//   shared clock is created. If the primary instance was already running,
//   it is also moved onto the shared clock.
//
//   Because every synced player steps its routine on the same clock,
//   they advance in lockstep: one note per beat, same beat grid. Each
//   instance has its own engine (counters, shift register, sliders),
//   so the note sequences differ, but the rhythmic alignment is exact
//   -- just like two hardware Muses driven from the same clock signal.
//
//   Changing tempo on any synced instance changes it for all of them
//   (they share the clock object). You can also set it globally:
//
//       TriadexMuseApplication.sharedTempo_(8);  // 8 notes/sec for all
//
//   Each instance gets its own GUI window, its own preset, its own
//   baseNote and synth type. Only the clock is shared.

// --- Example: two synced Muses ---

// Step 1: launch the primary instance
TriadexMuseApplication.run(preset: "Michaels Tune");

// Step 2: launch a second instance, synced to the first
// Different preset, higher octave, quieter, offset by half a beat
TriadexMuseApplication.runSynced(
    preset: "Birds 1",
    baseNote: 72,   // C5 -- one octave above the primary
    amp: 0.15,
    beatOffset: 0.5 // start half a beat after the primary
);

// Step 3 (optional): launch a third with different offset
// TriadexMuseApplication.runSynced(preset: "Meditation", baseNote: 48, beatOffset: 0.25);

// --- Note overlap (legato) ---
// By default, each note lasts 80% of the beat (legato: 0.8).
// Values > 1.0 make notes overlap — essentially a decay tail that
// bleeds into the next note. Try it with pluck or sine for pad-like textures.
//
// TriadexMuseApplication.instance.player.legato = 0.8;  // default: slight gap
// TriadexMuseApplication.instance.player.legato = 1.0;  // notes exactly touch
// TriadexMuseApplication.instance.player.legato = 2.0;  // notes ring for 2 beats
// TriadexMuseApplication.instance.player.legato = 4.0;  // long decay, dense overlap

// --- Control all synced instances at once ---
// TriadexMuseApplication.sharedTempo_(6);   // slow down
// TriadexMuseApplication.sharedTempo_(12);  // speed up

// --- Or control individual instances ---
// TriadexMuseApplication.instance;          // primary
// TriadexMuseApplication.instances;         // array of all synced
// TriadexMuseApplication.instances[0].player.synthType_(\dpoae);
// TriadexMuseApplication.instances[0].player.legato = 3.0;


// =====================================================================
// Optional: controlling the running instance from code
// =====================================================================
// Once the GUI is open, you can still drive it from the interpreter.

// TriadexMuseApplication.instance.play;
// TriadexMuseApplication.instance.stop;
// TriadexMuseApplication.instance.preset_("Christmas Bells");
// TriadexMuseApplication.instance.tempo_(8);
// TriadexMuseApplication.instance.baseNote_(72);  // C5
// TriadexMuseApplication.instance.amp_(0.1);
// TriadexMuseApplication.instance.close;


// =====================================================================
// For advanced use
// =====================================================================
// For headless use (no GUI), the engine-only API, custom scales,
// callbacks, pattern integration, and the full source table reference,
// see:
//
//     examples/overview.scd
