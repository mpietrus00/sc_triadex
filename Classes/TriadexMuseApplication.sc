// TriadexMuseApplication — One-call launcher for the Triadex Muse
//
// Boots the server, registers SynthDefs, creates the engine and player,
// opens the GUI, and manages the full application lifecycle.
//
// Usage:
//   TriadexMuseApplication.run;                        // default: faithful mode
//   TriadexMuseApplication.run(\enhanced, "Birds 1");  // enhanced mode with preset
//   TriadexMuseApplication.run(preset: "Polka");       // faithful mode with preset
//
// The running instance is stored as a singleton accessible via:
//   TriadexMuseApplication.instance

TriadexMuseApplication {

	classvar <instance;
	classvar <instances;
	classvar <sharedClock;

	var <server;
	var <muse;
	var <player;
	var <gui;
	var <isRunning;
	var <serverQuitFunc;
	var <instanceId;

	*initClass {
		instances = [];
	}

	// --- Class-level launcher ---

	*run { |mode = \faithful, preset, baseNote = 60, tempo = 4, amp = 0.2|
		// Reuse existing instance if window is still open
		if(instance.notNil and: { instance.isRunning }) {
			"TriadexMuseApplication: already running — bringing window to front".postln;
			instance.gui.front;
			^instance;
		};
		instance = super.new.prInit(mode, preset, baseNote, tempo, amp);
		^instance;
	}

	// Launch an additional synced instance sharing a TempoClock
	*runSynced { |mode = \faithful, preset, baseNote = 60, tempo = 4, amp = 0.2,
		beatOffset = 0|
		var newInstance;
		// Create shared clock on first synced launch
		if(sharedClock.isNil) {
			sharedClock = TempoClock.new(tempo);
		};
		// Move the primary instance onto the shared clock (but keep it unlocked
		// so its tempo slider still controls tempo for everyone)
		if(instance.notNil and: { instance.isRunning }) {
			if(instance.player.externalClock.isNil) {
				instance.player.externalClock = sharedClock;
				// Primary is NOT locked -- it drives tempo
			};
		};
		newInstance = super.new.prInit(mode, preset, baseNote, tempo, amp, sharedClock);
		// Secondary instances are tempo-locked
		newInstance.player.tempoLocked = true;
		newInstance.player.beatOffset = beatOffset;
		instances = instances.add(newInstance);
		^newInstance;
	}

	// Set tempo on the shared clock (affects all synced instances)
	*sharedTempo_ { |bps|
		if(sharedClock.notNil) {
			sharedClock.tempo = bps;
		};
	}

	// --- Lifecycle ---

	prInit { |mode, preset, baseNote, tempo, amp, extClock|
		server = Server.default;
		isRunning = false;
		instanceId = instances.size;

		// Build the engine
		muse = TriadexMuse.new;

		// Build the player (registers SynthDefs if needed)
		player = TriadexMusePlayer.new(muse, server);
		player.baseNote = baseNote;
		player.tempo = tempo;
		player.amp = amp;
		player.mode = mode;
		if(extClock.notNil) { player.externalClock = extClock };

		// Load preset before GUI so sliders reflect it
		if(preset.notNil) {
			muse.preset_(preset);
		};

		// Boot server then open GUI
		if(server.serverRunning) {
			this.prLaunchGUI;
		} {
			"TriadexMuseApplication: booting server...".postln;
			server.waitForBoot({
				this.prLaunchGUI;
			}, onFailure: {
				"TriadexMuseApplication: server failed to boot".error;
			});
		};
	}

	prLaunchGUI {
		{
			// Ensure SynthDefs are registered on the now-running server
			player.addSynthDefs(server);

			// Small sync to let SynthDefs reach the server
			server.sync;

			// Create GUI (deferred to AppClock for thread safety)
			{
				gui = TriadexMuseGUI.new(player);
				isRunning = true;

				// Wrap the GUI's existing onClose with our cleanup
				gui.window.onClose = {
					player.stop;
					muse.onStep = nil;
					isRunning = false;
					this.prUnregisterServerQuit;
					"TriadexMuseApplication: closed".postln;
				};

				// Close GUI when server quits (e.g. reboot from VS Code)
				this.prRegisterServerQuit;

				"TriadexMuseApplication: ready".postln;
			}.defer;
		}.fork;
	}

	// --- Control Forwarding ---

	play { player.play }
	stop { player.stop }
	restart { player.restart }

	preset_ { |name|
		player.preset_(name);
	}

	mode_ { |newMode| player.mode_(newMode) }
	tempo_ { |bps| player.tempo_(bps) }
	baseNote_ { |note| player.baseNote = note }
	amp_ { |val| player.amp = val }

	// --- Server Quit Handling ---
	// Close the GUI when the server shuts down (e.g. reboot from VS Code)

	prRegisterServerQuit {
		serverQuitFunc = {
			{
				"TriadexMuseApplication: server quit — closing".postln;
				this.close;
			}.defer;
		};
		ServerQuit.add(serverQuitFunc);
	}

	prUnregisterServerQuit {
		if(serverQuitFunc.notNil) {
			ServerQuit.remove(serverQuitFunc);
			serverQuitFunc = nil;
		};
	}

	// --- Cleanup ---

	close {
		player.stop;
		muse.onStep = nil;
		this.prUnregisterServerQuit;
		if(gui.notNil) { { gui.close }.defer };
		isRunning = false;
	}

	free {
		this.close;
		player.free;
		if(instance === this) { instance = nil };
		instances.remove(this);
	}

	printOn { |stream|
		stream << "TriadexMuseApplication("
		<< "running: " << isRunning
		<< ", mode: " << player.mode
		<< ", preset step: " << muse.stepCount
		<< ")";
	}
}
