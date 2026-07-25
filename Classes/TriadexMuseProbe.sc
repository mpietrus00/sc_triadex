// TriadexMuseProbe — Modular investigation tool for the Triadex Muse
//
// Decomposes the Muse architecture into independently listenable layers.
// Each binary source (counter bits, SR bits, XNOR output) can be sonified
// as clicks, rhythmic triggers, gates, or pitched tones. Multiple voices
// run simultaneously, revealing the hidden structure inside the instrument.
//
// Usage:
//   ~probe = TriadexMuseProbe.new(tempo: 4, baseNote: 60);
//   ~probe.addCounters;
//   ~probe.addPitch;
//   ~probe.play;

TriadexMuseProbe {

	classvar <synthDefsAdded;

	// Engine
	var <muse;
	var <clock;
	var <routine;
	var <isRunning;

	// Voice management
	// Each voice is an Event: (source, mode, amp, pan, freq, synth, prevState, mute)
	var <voices;
	var <voiceGroup;

	// Parameters
	var <>tempo;
	var <>baseNote;
	var <>masterAmp;

	// Passive mode: if true, does not call muse.step — reads state from external driver
	var <>passive;

	*new { |muse, tempo = 4, baseNote = 60, masterAmp = 0.5|
		^super.new.init(muse, tempo, baseNote, masterAmp);
	}

	init { |argMuse, argTempo, argBaseNote, argMasterAmp|
		muse = argMuse ?? { TriadexMuse.new };
		tempo = argTempo;
		baseNote = argBaseNote;
		masterAmp = argMasterAmp;
		passive = false;
		isRunning = false;
		voices = IdentityDictionary.new;

		this.addSynthDefs;
		CmdPeriod.add(this);
	}

	// --- SynthDef Registration ---

	addSynthDefs {
		if(synthDefsAdded == true) { ^this };

		// Click: short percussive hit on trigger. Sine-based for clarity.
		SynthDef(\probeClick, { |out = 0, freq = 2000, amp = 0.1, pan = 0|
			var sig = SinOsc.ar(freq);
			var env = EnvGen.kr(Env.perc(0.001, 0.04), doneAction: 2);
			Out.ar(out, Pan2.ar(sig * env * amp, pan));
		}).add;

		// Tone: pitched note per step, short sustain
		SynthDef(\probeTone, { |out = 0, freq = 440, amp = 0.15, pan = 0|
			var sig = Pulse.ar(freq, 0.5); // square wave — matching hardware
			var env = EnvGen.kr(Env.perc(0.003, 0.15, 1, -4), doneAction: 2);
			Out.ar(out, Pan2.ar(sig * env * amp, pan));
		}).add;

		// Gate: sustained tone, gated by external control
		SynthDef(\probeGate, { |out = 0, freq = 300, amp = 0.1, pan = 0, gate = 1|
			var sig = SinOsc.ar(freq);
			var env = EnvGen.kr(
				Env.asr(0.005, 1, 0.01),
				gate: gate, doneAction: 2
			);
			Out.ar(out, Pan2.ar(sig * env * amp, pan));
		}).add;

		// Drone: continuous tone, freq updated via .set
		SynthDef(\probeDrone, { |out = 0, freq = 440, amp = 0.1, pan = 0, gate = 1|
			var sig = SinOsc.ar(freq);
			var env = EnvGen.kr(Env.asr(0.01, 1, 0.05), gate: gate, doneAction: 2);
			Out.ar(out, Pan2.ar(sig * env * amp, pan));
		}).add;

		synthDefsAdded = true;
	}

	// --- Lifecycle ---

	play {
		if(isRunning) { ^this };
		fork {
			Server.default.bootSync;
			voiceGroup = Group.new(Server.default);
			Server.default.sync;
			isRunning = true;
			this.prStartRoutine;
			"TriadexMuseProbe: playing".postln;
		};
	}

	stop {
		this.prStopRoutine;
		voices.do({ |v|
			if(v[\synth].notNil) {
				v[\synth].set(\gate, 0);
				v[\synth] = nil;
			};
		});
		if(voiceGroup.notNil) { voiceGroup.free; voiceGroup = nil };
		isRunning = false;
		"TriadexMuseProbe: stopped".postln;
	}

	reset {
		this.stop;
		muse.reset;
		voices.do({ |v| v[\prevState] = 0 });
		"TriadexMuseProbe: reset".postln;
	}

	free {
		this.stop;
		CmdPeriod.remove(this);
		voices = IdentityDictionary.new;
	}

	cmdPeriod {
		routine = nil;
		clock = nil;
		voiceGroup = nil;
		isRunning = false;
		voices.do({ |v| v[\synth] = nil });
	}

	// --- Voice Management ---

	// Add a voice by source position (0-39)
	addVoice { |label, source, mode = \click, amp = 0.1, pan = 0, freq|
		var voice = (
			source: source,
			mode: mode,
			amp: amp,
			pan: pan,
			freq: freq ?? { this.prDefaultFreq(source, mode) },
			synth: nil,
			prevState: 0,
			mute: false
		);
		voices[label] = voice;
		postf("  + voice '%' : % (source %, mode %)\n",
			label, TriadexMuse.sourceLabels[source], source, mode);
	}

	// Add a voice by source label name (e.g. 'C1', 'B5')
	addSource { |sourceName, mode = \click, amp = 0.1, pan = 0|
		var idx = TriadexMuse.labelToIndex(sourceName.asString);
		if(idx.isNil) {
			("TriadexMuseProbe: unknown source '" ++ sourceName ++ "'").warn;
			^this;
		};
		this.addVoice(sourceName.asSymbol, idx, mode, amp, pan);
	}

	// Add the full pitch output voice
	addPitch { |label = \pitch, amp = 0.15, pan = 0|
		var voice = (
			source: \pitch,
			mode: \pitch,
			amp: amp,
			pan: pan,
			freq: nil,
			synth: nil,
			prevState: nil,
			mute: false
		);
		voices[label] = voice;
		"  + voice 'pitch' : full 4-bit melodic output".postln;
	}

	// Add the XNOR gate output
	addXnor { |label = \xnor, mode = \click, amp = 0.1, pan = 0, freq = 4000|
		var voice = (
			source: \xnor,
			mode: mode,
			amp: amp,
			pan: pan,
			freq: freq,
			synth: nil,
			prevState: 0,
			mute: false
		);
		voices[label] = voice;
		"  + voice 'xnor' : XNOR gate feedback output".postln;
	}

	removeVoice { |label|
		var v = voices[label];
		if(v.notNil) {
			if(v[\synth].notNil) { v[\synth].set(\gate, 0); v[\synth] = nil };
			voices.removeAt(label);
			postf("  - removed voice '%'\n", label);
		};
	}

	clearVoices {
		voices.keysValuesDo({ |label, v|
			if(v[\synth].notNil) { v[\synth].set(\gate, 0) };
		});
		voices = IdentityDictionary.new;
		"  cleared all voices".postln;
	}

	muteVoice { |label|
		var v = voices[label];
		if(v.notNil) {
			v[\mute] = true;
			if(v[\synth].notNil) { v[\synth].set(\gate, 0); v[\synth] = nil };
		};
	}

	unmuteVoice { |label| voices[label] !? { |v| v[\mute] = false } }

	soloVoice { |label|
		voices.keysValuesDo({ |k, v|
			if(k == label) { v[\mute] = false } { v[\mute] = true };
			if(v[\mute] and: { v[\synth].notNil }) {
				v[\synth].set(\gate, 0); v[\synth] = nil;
			};
		});
		postf("  solo: '%'\n", label);
	}

	unsoloAll { voices.do({ |v| v[\mute] = false }); "  unsolo all".postln }

	// --- Convenience: Add groups of voices ---

	// All 7 counter bits, panned L to R
	addCounters { |mode = \click, amp = 0.08|
		var sources = #[2, 3, 4, 5, 6, 7, 8]; // C½, C1, C2, C4, C8, C3, C6
		var labels = #[\Chalf, \C1, \C2, \C4, \C8, \C3, \C6];
		var freqs = #[8000, 4000, 2000, 1000, 500, 3000, 1500];
		"Adding counter voices:".postln;
		sources.do({ |src, i|
			var pan = i.linlin(0, sources.size - 1, -0.8, 0.8);
			this.addVoice(labels[i], src, mode, amp, pan, freqs[i]);
		});
	}

	// Shift register bits as voices
	// bits: array of bit numbers (1-31), e.g. (1..8) for B1-B8
	addShiftRegister { |bits, mode = \click, amp = 0.05|
		bits = bits ?? { (1..8) };
		postf("Adding SR voices B%..B%:\n", bits.first, bits.last);
		bits.do({ |b, i|
			var label = ("B" ++ b).asSymbol;
			var src = b + 8; // B1 = position 9, B2 = position 10, etc.
			var pan = i.linlin(0, bits.size - 1, -0.6, 0.6);
			var freq = b.linlin(1, 31, 6000, 200);
			this.addVoice(label, src, mode, amp, pan, freq);
		});
	}

	// Counter + XNOR + pitch — the full pipeline decomposed
	addAll { |mode = \click, amp = 0.06|
		this.addCounters(mode, amp);
		this.addXnor(\xnor, mode, amp * 1.5, 0);
		this.addPitch(\pitch, amp * 2.5, 0);
	}

	// --- Live Tweaking ---

	voiceAmp { |label, amp| voices[label] !? { |v| v[\amp] = amp } }
	voicePan { |label, pan| voices[label] !? { |v| v[\pan] = pan } }

	voiceMode { |label, newMode|
		var v = voices[label];
		if(v.notNil) {
			// Release any sustained synth
			if(v[\synth].notNil) { v[\synth].set(\gate, 0); v[\synth] = nil };
			v[\mode] = newMode;
			v[\freq] = this.prDefaultFreq(v[\source], newMode);
		};
	}

	// Change preset on the underlying Muse engine
	preset_ { |name|
		muse.preset_(name);
		postf("TriadexMuseProbe: preset '%'\n", name);
	}

	// Change scale on the underlying Muse engine
	scalePreset_ { |name|
		muse.scalePreset_(name);
		postf("TriadexMuseProbe: scale '%'\n", name);
	}

	// Direct slider access
	sliders_ { |positions|
		muse.sliders_(positions);
		muse.reset;
		"TriadexMuseProbe: sliders set, engine reset".postln;
	}

	// --- Internal: Stepping Routine ---

	prStartRoutine {
		clock = TempoClock.new(tempo);
		routine = Routine({
			inf.do({
				this.prStepAndDispatch;
				1.wait;
			});
		});
		routine.play(clock);
	}

	prStopRoutine {
		if(routine.notNil) { routine.stop; routine = nil };
		if(clock.notNil) { clock.stop; clock = nil };
	}

	prStepAndDispatch {
		var xnorBit;

		// Compute XNOR from pre-step state (same ordering as prClick)
		xnorBit = this.prComputeXnor;

		// Advance the engine (unless passive)
		if(passive.not) { muse.step };

		// Dispatch each voice
		voices.keysValuesDo({ |label, voice|
			if(voice[\mute].not) {
				this.prDispatchVoice(label, voice, xnorBit);
			};
		});
	}

	prComputeXnor {
		// Replicate the XNOR computation from TriadexMuse.prClick
		// Read theme sources from current (pre-step) state
		var bit = 1;
		4.do({ |i|
			bit = bit bitXor: muse.select(muse.theme[i]);
		});
		^bit;
	}

	prDispatchVoice { |label, voice, xnorBit|
		var src = voice[\source];
		var mode = voice[\mode];
		var currentState, prevState;

		// Determine current state based on source type
		case
		{ src == \pitch } {
			this.prDispatchPitch(voice);
			^this;
		}
		{ src == \xnor } {
			currentState = xnorBit;
		}
		{ src.isInteger } {
			currentState = muse.select(src);
		}
		{ ^this }; // unknown source

		prevState = voice[\prevState] ? 0;

		case
		{ mode == \click } {
			// Rising edge: 0 -> 1
			if(prevState == 0 and: { currentState == 1 }) {
				Synth(\probeClick, [
					\freq, voice[\freq],
					\amp, voice[\amp] * masterAmp,
					\pan, voice[\pan]
				], target: voiceGroup);
			};
		}
		{ mode == \rhythm } {
			// Trigger on every step where state == 1
			if(currentState == 1) {
				Synth(\probeClick, [
					\freq, voice[\freq],
					\amp, voice[\amp] * masterAmp,
					\pan, voice[\pan]
				], target: voiceGroup);
			};
		}
		{ mode == \gate } {
			// Sustained tone while state == 1
			if(prevState == 0 and: { currentState == 1 }) {
				voice[\synth] = Synth(\probeGate, [
					\freq, voice[\freq],
					\amp, voice[\amp] * masterAmp,
					\pan, voice[\pan]
				], target: voiceGroup);
			};
			if(prevState == 1 and: { currentState == 0 }) {
				if(voice[\synth].notNil) {
					voice[\synth].set(\gate, 0);
					voice[\synth] = nil;
				};
			};
		}
		{ mode == \drone } {
			// Continuous tone — start if not running, update freq
			if(voice[\synth].isNil) {
				voice[\synth] = Synth(\probeDrone, [
					\freq, voice[\freq],
					\amp, voice[\amp] * masterAmp,
					\pan, voice[\pan]
				], target: voiceGroup);
			};
			// Modulate freq based on state (higher when 1)
			voice[\synth].set(\freq,
				if(currentState == 1) { voice[\freq] } { voice[\freq] * 0.5 }
			);
		};

		voice[\prevState] = currentState;
	}

	prDispatchPitch { |voice|
		var pitch = muse.currentPitch;
		var freq;
		if(pitch.isNil) { ^this }; // rest
		freq = (baseNote + pitch).midicps;
		Synth(\probeTone, [
			\freq, freq,
			\amp, voice[\amp] * masterAmp,
			\pan, voice[\pan]
		], target: voiceGroup);
	}

	prDefaultFreq { |source, mode|
		if(mode == \pitch) { ^440 };
		if(source.isInteger.not) { ^4000 };
		// Counter sources: higher pitch for faster-changing bits
		if(source < 9) {
			^#[0, 0, 8000, 4000, 2000, 1000, 500, 3000, 1500][source];
		};
		// SR sources: descending pitch for deeper bits
		^(source - 8).linlin(1, 31, 6000, 200);
	}

	// --- State Inspection ---

	postVoices {
		"TriadexMuseProbe voices:".postln;
		voices.keysValuesDo({ |label, v|
			var srcName = case
			{ v[\source] == \pitch } { "pitch" }
			{ v[\source] == \xnor } { "xnor" }
			{ v[\source].isInteger } { TriadexMuse.sourceLabels[v[\source]] }
			{ "?" };
			postf("  % : % (mode: %, amp: %, pan: %, mute: %)\n",
				label, srcName, v[\mode], v[\amp].round(0.01),
				v[\pan].round(0.01), v[\mute]);
		});
	}

	printOn { |stream|
		stream << "TriadexMuseProbe("
		<< "voices: " << voices.size
		<< ", tempo: " << tempo
		<< ", " << if(isRunning) { "playing" } { "stopped" }
		<< ")";
	}
}
