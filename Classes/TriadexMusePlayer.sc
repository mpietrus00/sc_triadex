// TriadexMusePlayer — Audio engine and scheduler for the Triadex Muse
//
// Wraps a TriadexMuse engine with server-side synthesis and clock scheduling.
// Two modes: faithful (square wave matching the original hardware) and
// enhanced (selectable waveform, filter, envelope, effects).
//
// Design: the engine is decoupled from audio — TriadexMuse computes note
// sequences, TriadexMusePlayer handles sound and timing.

TriadexMusePlayer {

	// SynthDef names registered on the server
	classvar <synthDefNames;
	classvar <synthDefsAdded;
	classvar <synthTypeNames;

	// The algorithmic engine
	var <muse;

	// Playback state
	var <isPlaying;
	var <routine;
	var <clock;
	var <currentSynth;
	var <activeSynths;  // Array of running synths for overlap management

	// Node groups for correct signal flow ordering
	var <sourceGroup;
	var <effectsGroup;

	// Audio parameters
	var <>baseNote;     // MIDI note for the root (default: 60 = middle C)
	var <>amp;          // Output amplitude 0-1 (default: 0.2)
	var <>legato;       // Note duration as fraction of beat (default: 0.8)

	// Synthesis mode
	var <>waveform;     // \pulse, \saw, \tri, \sine (enhanced mode)
	var <>filterFreq;   // Filter cutoff in Hz (enhanced mode, nil = bypass)
	var <>filterRes;    // Filter resonance 0-1 (enhanced mode)
	var <>pan;          // Stereo pan position -1 to 1
	var <>alternatePan; // Boolean: alternate L/R on each note
	var <panState;      // Internal: current alternation state (0 or 1)

	// Effects (enhanced mode)
	var <effectsBus;
	var <effectsSynth;

	// Stored tempo (used to create/update TempoClock)
	var <tempo;

	// Sync: external clock for syncing multiple players
	var <>externalClock;
	var <>tempoLocked;  // Boolean: true = this player follows, does not set tempo
	var <>beatOffset;   // Beats to wait before starting (synced delay)

	// Mode and effects stored values
	var <mode;
	var <synthType;
	var <reverbMix;
	var <delayTime;
	var <delayDecay;

	*initClass {
		synthDefNames = IdentityDictionary[
			\faithful -> \triadexFaithful,
			\enhanced -> \triadexEnhanced,
			\effects  -> \triadexEffects,
			\sine     -> \triadexSine,
			\saw      -> \triadexSaw,
			\fm       -> \triadexFM,
			\pluck    -> \triadexPluck,
			\dpoae    -> \triadexDPOAE
		];
		synthTypeNames = #[\faithful, \sine, \saw, \fm, \pluck, \dpoae, \enhanced];
		synthDefsAdded = false;
	}

	*new { |muse, server|
		^super.new.init(muse, server);
	}

	init { |argMuse, argServer|
		muse = argMuse ?? { TriadexMuse.new };

		// Defaults
		baseNote = 60;
		tempo = 4;
		amp = 0.2;
		legato = 0.8;
		mode = \faithful;
		synthType = \faithful;
		waveform = \pulse;
		filterFreq = nil;
		filterRes = 0.3;
		reverbMix = 0;
		delayTime = 0;
		delayDecay = 1.0;
		pan = 0;
		alternatePan = false;
		panState = 0;
		externalClock = nil;
		tempoLocked = false;
		beatOffset = 0;

		isPlaying = false;
		routine = nil;
		clock = nil;
		currentSynth = nil;
		activeSynths = [];
		sourceGroup = nil;
		effectsGroup = nil;
		effectsBus = nil;
		effectsSynth = nil;

		// Auto-register for CmdPeriod cleanup
		CmdPeriod.add(this);

		this.addSynthDefs(argServer);
	}

	// --- SynthDef Registration ---

	addSynthDefs { |server|
		server = server ?? { Server.default };

		if(synthDefsAdded) { ^this };

		// Faithful mode: band-limited square wave matching Tillman's JS
		// The original Muse used a divide-down oscillator producing a square wave.
		SynthDef(synthDefNames[\faithful], { |out = 0, freq = 440, amp = 0.2,
			gate = 1, pan = 0|
			var sig, env;

			sig = Pulse.ar(freq: freq, width: 0.5, mul: amp);

			env = EnvGen.kr(
				Env.asr(attackTime: 0.005, sustainLevel: 1, releaseTime: 0.01),
				gate: gate,
				doneAction: Done.freeSelf
			);

			sig = sig * env;
			sig = Pan2.ar(sig, pan);
			Out.ar(out, sig);
		}).add;

		// Enhanced mode: selectable waveform with filter and envelope
		// Note: Select.ar evaluates all branches — four oscillators run
		// continuously but only one is output. Acceptable for monophonic use.
		SynthDef(synthDefNames[\enhanced], { |out = 0, freq = 440, amp = 0.2,
			gate = 1, pan = 0, waveform = 0, filterFreq = 20000, filterRes = 0.3,
			attackTime = 0.01, releaseTime = 0.05|
			var sig, env, osc;

			// Waveform selection: 0=pulse, 1=saw, 2=tri, 3=sine
			osc = Select.ar(waveform, [
				Pulse.ar(freq, 0.5),
				Saw.ar(freq),
				LFTri.ar(freq),
				SinOsc.ar(freq)
			]);

			// Resonant low-pass filter
			sig = RLPF.ar(osc, filterFreq.clip(20, 20000), filterRes.linlin(0, 1, 1, 0.01));

			// Amplitude envelope
			env = EnvGen.kr(
				Env.asr(attackTime: attackTime, sustainLevel: 1, releaseTime: releaseTime),
				gate: gate,
				doneAction: Done.freeSelf
			);

			sig = sig * env * amp;
			sig = Pan2.ar(sig, pan);
			Out.ar(out, sig);
		}).add;

		// Sine — pure tone, warm and clear
		SynthDef(synthDefNames[\sine], { |out = 0, freq = 440, amp = 0.2,
			gate = 1, pan = 0|
			var sig, env;
			sig = SinOsc.ar(freq);
			env = EnvGen.kr(
				Env.asr(attackTime: 0.005, sustainLevel: 1, releaseTime: 0.02),
				gate: gate, doneAction: Done.freeSelf
			);
			Out.ar(out, Pan2.ar(sig * env * amp, pan));
		}).add;

		// Saw — band-limited sawtooth, bright and buzzy
		SynthDef(synthDefNames[\saw], { |out = 0, freq = 440, amp = 0.2,
			gate = 1, pan = 0|
			var sig, env;
			sig = Saw.ar(freq);
			sig = LPF.ar(sig, (freq * 6).clip(20, 18000));
			env = EnvGen.kr(
				Env.asr(attackTime: 0.005, sustainLevel: 1, releaseTime: 0.015),
				gate: gate, doneAction: Done.freeSelf
			);
			Out.ar(out, Pan2.ar(sig * env * amp, pan));
		}).add;

		// FM — two-operator FM bell/metallic tone
		SynthDef(synthDefNames[\fm], { |out = 0, freq = 440, amp = 0.2,
			gate = 1, pan = 0|
			var mod, sig, env;
			mod = SinOsc.ar(freq * 3.51, mul: freq * 2.5);
			sig = SinOsc.ar(freq + mod);
			env = EnvGen.kr(
				Env.asr(attackTime: 0.001, sustainLevel: 1, releaseTime: 0.08),
				gate: gate, doneAction: Done.freeSelf
			);
			Out.ar(out, Pan2.ar(sig * env * amp, pan));
		}).add;

		// Pluck — Karplus-Strong plucked string
		SynthDef(synthDefNames[\pluck], { |out = 0, freq = 440, amp = 0.2,
			gate = 1, pan = 0|
			var sig, env, trig;
			trig = EnvGen.kr(Env.perc(0.001, 0.01));
			sig = Pluck.ar(
				in: WhiteNoise.ar(1.0) * trig,
				trig: trig,
				maxdelaytime: 1/20,
				delaytime: 1/freq,
				decaytime: 4.0,
				coef: 0.2
			);
			env = EnvGen.kr(
				Env.asr(attackTime: 0.001, sustainLevel: 1, releaseTime: 0.05),
				gate: gate, doneAction: Done.freeSelf
			);
			Out.ar(out, Pan2.ar(sig * env * amp * 3, pan));
		}).add;

		// DPOAE — Distortion Product Otoacoustic Emission stimulus
		// Two pure-tone primaries f1 and f2 at ratio ~1.22 (optimal for
		// evoking the cubic difference tone 2f1-f2 in the listener's ear).
		// The Muse note sets f2; f1 is derived from the ratio.
		// Primaries should sit in the 1-4 kHz range for strongest DPOAEs.
		// L1 is slightly louder than L2 (Kummer formula approximation).
		SynthDef(synthDefNames[\dpoae], { |out = 0, freq = 440, amp = 0.2,
			gate = 1, pan = 0, ratio = 1.22|
			var f2, f1, l1, l2, sig, env;

			f2 = freq;
			f1 = f2 / ratio;

			// Kummer-like level rule: L1 a few dB above L2
			l2 = amp;
			l1 = amp * 1.25;

			sig = SinOsc.ar(f1, 0, l1) + SinOsc.ar(f2, 0, l2);

			env = EnvGen.kr(
				Env.asr(attackTime: 0.005, sustainLevel: 1, releaseTime: 0.02),
				gate: gate, doneAction: Done.freeSelf
			);

			Out.ar(out, Pan2.ar(sig * env, pan));
		}).add;

		// Effects processor: reverb + delay on a bus
		// CombL runs continuously; when delayTime is near 0, output is negligible.
		// FreeVerb2 mix is set to 1.0 (fully wet); dry/wet blend handled by XFade2.
		SynthDef(synthDefNames[\effects], { |in = 0, out = 0,
			reverbMix = 0, delayTime = 0.001, delayDecay = 1.0|
			var sig, wet, delayed;

			sig = In.ar(in, 2);

			// Comb delay — always runs; inaudible when delayTime ~0
			delayed = CombL.ar(sig,
				maxdelaytime: 2.0,
				delaytime: delayTime.max(0.001),
				decaytime: delayDecay
			);

			// Scale delay by whether delayTime is meaningfully > 0
			// (smooth crossfade avoids clicks when toggling delay)
			delayed = delayed * delayTime.min(0.01).linlin(0, 0.01, 0, 1);

			// FreeVerb fully wet — XFade2 handles dry/wet blend
			wet = FreeVerb2.ar(
				sig[0] + delayed[0],
				sig[1] + delayed[1],
				mix: 1.0,
				room: 0.7,
				damp: 0.5
			);

			// Crossfade between dry and fully-processed
			sig = XFade2.ar(sig, wet, reverbMix.linlin(0, 1, -1, 1));

			ReplaceOut.ar(out, sig);
		}).add;

		synthDefsAdded = true;
	}

	// --- Playback Control ---

	play { |argTempo, argBaseNote, argAmp|
		if(argTempo.notNil) { tempo = argTempo };
		if(argBaseNote.notNil) { baseNote = argBaseNote };
		if(argAmp.notNil) { amp = argAmp };

		if(Server.default.serverRunning.not) {
			"TriadexMusePlayer: server not running — call s.boot first".warn;
			^this;
		};

		if(isPlaying) {
			"TriadexMusePlayer: already playing — use .stop first or .tempo_ to change speed".warn;
			^this;
		};

		this.prStartGroups;
		this.prStartEffects;
		this.prStartRoutine;
		isPlaying = true;
		"TriadexMusePlayer: playing".postln;
	}

	stop {
		this.prStopRoutine;
		this.prFreeCurrentSynth;
		this.prStopEffects;
		this.prStopGroups;
		isPlaying = false;
		"TriadexMusePlayer: stopped".postln;
	}

	// Reset the engine and restart playback
	restart {
		var wasPlaying = isPlaying;
		this.stop;
		muse.reset;
		if(wasPlaying) { this.play };
	}

	// Single step: advance one tick and play the note
	stepOnce {
		var pitch;
		if(Server.default.serverRunning.not) {
			"TriadexMusePlayer: server not running — call s.boot first".warn;
			^nil;
		};
		pitch = muse.step;
		this.prPlayNote(pitch);
		^pitch;
	}

	// --- Group Management ---
	// Explicit groups ensure correct signal flow: sources -> effects

	prStartGroups {
		var server = Server.default;
		sourceGroup = Group.new(server);
		effectsGroup = Group.after(sourceGroup);
	}

	prStopGroups {
		if(sourceGroup.notNil) {
			sourceGroup.free;
			sourceGroup = nil;
		};
		if(effectsGroup.notNil) {
			effectsGroup.free;
			effectsGroup = nil;
		};
	}

	// --- Internal Scheduling ---

	prStartRoutine {
		// Use external clock if provided (for syncing multiple players),
		// otherwise create a private TempoClock
		if(externalClock.notNil) {
			clock = externalClock;
		} {
			clock = TempoClock.new(tempo);
		};

		panState = 0; // reset alternation on play

		routine = Routine({
			// Beat offset: delay start for synced instances
			if(beatOffset > 0) { beatOffset.wait };
			inf.do({
				var pitch = muse.step;
				this.prPlayNote(pitch);
				1.wait;
			});
		});

		routine.play(clock);
	}

	prStopRoutine {
		if(routine.notNil) {
			routine.stop;
			routine = nil;
		};
		if(clock.notNil) {
			// Don't stop an external clock -- it belongs to the caller
			if(externalClock.isNil) { clock.stop };
			clock = nil;
		};
	}

	// Update tempo on a running clock
	// If using an external clock, updates the shared clock (affects all synced players)
	tempo_ { |newTempo|
		tempo = newTempo;
		if(clock.notNil) {
			clock.tempo = newTempo;
		};
	}

	// --- Effects Bus Management ---

	prStartEffects {
		var server = Server.default;

		if(mode == \enhanced) {
			// Always create effects bus in enhanced mode so effects
			// can be enabled live without restarting playback
			effectsBus = Bus.audio(server, 2);
			effectsSynth = Synth(synthDefNames[\effects], [
				\in, effectsBus,
				\out, 0,
				\reverbMix, reverbMix,
				\delayTime, delayTime.max(0.001),
				\delayDecay, delayDecay
			], target: effectsGroup);
		};
	}

	prStopEffects {
		if(effectsSynth.notNil) {
			effectsSynth.free;
			effectsSynth = nil;
		};
		if(effectsBus.notNil) {
			effectsBus.free;
			effectsBus = nil;
		};
	}

	// --- Note Playback ---

	prPlayNote { |pitch|
		var freq, outBus, synthName, args, thisSynth, notePan, maxVoices;

		// Cap overlapping voices: legato determines how many can coexist
		// legato <= 1: monophonic (cut previous), >1: up to ceil(legato)+1
		maxVoices = if(legato <= 1) { 1 } { legato.ceil.asInteger + 1 };

		// Free excess synths (oldest first)
		while { activeSynths.size >= maxVoices } {
			var oldest = activeSynths.removeAt(0);
			if(oldest.notNil) { oldest.set(\gate, 0) };
		};

		// Rest or not playing: no sound
		if(pitch.isNil) { ^nil };
		if(isPlaying.not) { ^nil };

		freq = (baseNote + pitch).midicps;
		outBus = if(effectsBus.notNil) { effectsBus } { 0 };

		// Compute pan: alternate L/R if enabled, otherwise use static pan
		if(alternatePan) {
			notePan = if(panState == 0) { -1 } { 1 };
			panState = 1 - panState;
		} {
			notePan = pan;
		};

		case
		{ synthType == \enhanced } {
			synthName = synthDefNames[\enhanced];
			args = [
				\out, outBus,
				\freq, freq,
				\amp, amp,
				\pan, notePan,
				\waveform, this.prWaveformIndex,
				\filterFreq, filterFreq ? 20000,
				\filterRes, filterRes
			];
		}
		{ synthDefNames[synthType].notNil } {
			synthName = synthDefNames[synthType];
			args = [
				\out, outBus,
				\freq, freq,
				\amp, amp,
				\pan, notePan
			];
		}
		{ true } {
			synthName = synthDefNames[\faithful];
			args = [
				\out, outBus,
				\freq, freq,
				\amp, amp,
				\pan, notePan
			];
		};

		// Create synth in source group if available, otherwise default
		thisSynth = if(sourceGroup.notNil) {
			Synth(synthName, args, target: sourceGroup);
		} {
			Synth(synthName, args);
		};

		currentSynth = thisSynth;
		activeSynths = activeSynths.add(thisSynth);

		// Schedule note-off
		if(clock.notNil) {
			clock.sched(legato, {
				thisSynth.set(\gate, 0);
				activeSynths.remove(thisSynth);
				if(currentSynth === thisSynth) { currentSynth = nil };
				nil;
			});
		} {
			SystemClock.sched(legato / tempo, {
				thisSynth.set(\gate, 0);
				activeSynths.remove(thisSynth);
				if(currentSynth === thisSynth) { currentSynth = nil };
				nil;
			});
		};
	}

	prFreeCurrentSynth {
		// Release all active synths
		activeSynths.do({ |syn| syn.set(\gate, 0) });
		activeSynths = [];
		currentSynth = nil;
	}

	prWaveformIndex {
		^switch(waveform,
			\pulse, 0,
			\saw, 1,
			\tri, 2,
			\sine, 3,
			0  // default to pulse
		);
	}

	// --- Mode / Synth Switching ---

	synthType_ { |newType|
		if(synthTypeNames.includes(newType).not) {
			"TriadexMusePlayer: unknown synthType '%' — available: %".format(
				newType, synthTypeNames).warn;
			^this;
		};
		synthType = newType;
		// Update mode to match (enhanced needs effects bus)
		if(newType == \enhanced) { mode = \enhanced } { mode = \faithful };
	}

	mode_ { |newMode|
		var wasPlaying = isPlaying;
		if(newMode == mode) { ^this };

		if(wasPlaying) { this.stop };
		mode = newMode;
		if(wasPlaying) { this.play };
	}

	// --- Convenience ---

	// Load a preset and optionally start playing
	preset_ { |name, autoPlay = false|
		var wasPlaying = isPlaying;
		if(wasPlaying) { this.stop };
		muse.preset_(name);
		if(wasPlaying or: autoPlay) { this.play };
	}

	// Quick-start: create a player, load a preset, and play
	*play { |presetName, tempo = 4, baseNote = 60, amp = 0.2, mode = \faithful|
		var player = this.new;
		player.tempo = tempo;
		player.baseNote = baseNote;
		player.amp = amp;
		player.mode = mode;
		if(presetName.notNil) {
			player.muse.preset_(presetName);
		};
		player.play;
		^player;
	}

	// Update effects parameters on a running effects synth
	reverbMix_ { |val|
		reverbMix = val;
		if(effectsSynth.notNil) {
			effectsSynth.set(\reverbMix, val);
		};
	}

	delayTime_ { |val|
		delayTime = val;
		if(effectsSynth.notNil) {
			effectsSynth.set(\delayTime, val.max(0.001));
		};
	}

	delayDecay_ { |val|
		delayDecay = val;
		if(effectsSynth.notNil) {
			effectsSynth.set(\delayDecay, val);
		};
	}

	// --- CmdPeriod Cleanup ---

	cmdPeriod {
		// Stop routine first to prevent it from spawning synths
		// into freed groups
		if(routine.notNil) { routine.stop; routine = nil };
		if(clock.notNil and: { externalClock.isNil }) { clock.stop };
		clock = nil;
		isPlaying = false;
		panState = 0;
		// Server-side nodes are already freed by CmdPeriod
		currentSynth = nil;
		activeSynths = [];
		effectsSynth = nil;
		sourceGroup = nil;
		effectsGroup = nil;
		if(effectsBus.notNil) {
			effectsBus.free;
			effectsBus = nil;
		};
	}

	// Release resources and unregister from CmdPeriod
	free {
		this.stop;
		CmdPeriod.remove(this);
	}

	printOn { |stream|
		stream << "TriadexMusePlayer("
		<< "mode: " << mode
		<< ", playing: " << isPlaying
		<< ", tempo: " << tempo
		<< ", base: " << baseNote
		<< ")";
	}
}
