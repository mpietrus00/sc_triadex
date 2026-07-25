// TriadexMuseProbe — Architecture Investigation
//
// Listen to each subsystem of the Muse independently or in combination.
// Each binary source (counter bits, SR bits, XNOR) becomes an audible voice.
//
// Evaluate blocks one at a time (Cmd+Enter).
// Cmd+. stops everything.


// =====================================================================
// 0. Boot server
// =====================================================================
s.boot;


// =====================================================================
// 1. Counter rhythms alone
// =====================================================================
// The 5-bit counter produces C 1/2, C1, C2, C4, C8.
// Each bit toggles at half the rate of the previous.
// The divide-by-3 counter produces C3, C6 — incommensurate with powers of 2.
// Listen: you hear binary counting as polyrhythm.
(
~probe = TriadexMuseProbe.new(tempo: 6, baseNote: 60);
~probe.addCounters(\click, 0.1);
~probe.play;
)

// Solo individual counter bits to hear each rate:
~probe.soloVoice(\Chalf);  // fastest — every tick
~probe.soloVoice(\C1);     // every 2 ticks
~probe.soloVoice(\C2);     // every 4 ticks
~probe.soloVoice(\C4);     // every 8 ticks
~probe.soloVoice(\C8);     // every 16 ticks
~probe.soloVoice(\C3);     // divide-by-3 — cross-rhythm
~probe.soloVoice(\C6);     // divide-by-6

// All counters together again:
~probe.unsoloAll;

~probe.stop;


// =====================================================================
// 2. Shift register bits as rhythmic voices
// =====================================================================
// B1 through B8: the shallowest SR positions.
// These evolve based on the XNOR feedback.
// With theme sliders at OFF, the SR fills with 1s — boring.
// With theme sliders on SR positions, the feedback creates rhythm.
(
~probe = TriadexMuseProbe.new(tempo: 6, baseNote: 60);
~probe.preset_('Birds 1');  // theme: B30, B31, B31, B31 — dense SR feedback
~probe.addShiftRegister((1..8), \rhythm, 0.08);
~probe.play;
)

// Solo B1 — the newest bit, changes most often:
~probe.soloVoice(\B1);

// Solo B8 — 8 shifts deep, changes less often:
~probe.soloVoice(\B8);

// All SR voices together — a rhythmic ensemble:
~probe.unsoloAll;

// Change preset — hear the rhythmic pattern shift:
~probe.preset_('Meditation');

// Back to Birds:
~probe.preset_('Birds 1');

~probe.stop;


// =====================================================================
// 3. The XNOR gate output
// =====================================================================
// The XNOR gate is the feedback signal.
// It determines what enters the shift register at B1.
// With theme sliders at OFF, XNOR always outputs 1 (no variation).
// With active theme sliders, the XNOR rhythm reveals the feedback topology.
(
~probe = TriadexMuseProbe.new(tempo: 6, baseNote: 60);
~probe.preset_('Musers Waltz');  // theme: ON, C4, B1, B2
~probe.addXnor(\xnor, \rhythm, 0.15, 0);
~probe.play;
)

// Compare: change to Scale preset (all theme OFF) — XNOR becomes constant:
~probe.preset_('Scale');

// Back to active feedback:
~probe.preset_('Musers Waltz');

~probe.stop;


// =====================================================================
// 4. Pitch output alone — the normal Muse melody
// =====================================================================
// This is what TriadexMusePlayer produces.
// Square wave, one note per step.
// Reference voice for A/B comparison.
(
~probe = TriadexMuseProbe.new(tempo: 4, baseNote: 60);
~probe.preset_('Scale');
~probe.addPitch(\pitch, 0.2, 0);
~probe.play;
)

// Switch presets — same voice, different sequences:
~probe.preset_('Musers Waltz');
~probe.preset_('Meditation');
~probe.preset_('Birds 1');
~probe.preset_('Scale');

~probe.stop;


// =====================================================================
// 5. Counters + pitch together
// =====================================================================
// Hear the rhythmic skeleton (counters) alongside the melody (pitch).
// The counter clicks reveal which bits are driving the pitch changes.
// When a counter bit toggles, the pitch may change — listen for the
// correlation between click patterns and melodic movement.
(
~probe = TriadexMuseProbe.new(tempo: 4, baseNote: 60);
~probe.preset_('Scale');  // interval reads C1, C2, C4 — direct counter-to-pitch
~probe.addCounters(\click, 0.06);
~probe.addPitch(\pitch, 0.2, 0);
~probe.play;
)

// Solo pitch, then add counters back:
~probe.soloVoice(\pitch);
~probe.unsoloAll;

// Solo just the interval-driving counters (C1, C2, C4):
~probe.muteVoice(\Chalf);
~probe.muteVoice(\C8);
~probe.muteVoice(\C3);
~probe.muteVoice(\C6);
// Now you hear only the bits that directly control pitch.

~probe.unsoloAll;

~probe.stop;


// =====================================================================
// 6. SR voices + pitch — hidden memory
// =====================================================================
// The shift register carries the Muse's long-term memory.
// When interval sliders read from SR positions, the melody
// depends on the feedback history. Listen to the SR bits
// alongside the pitch to hear the memory at work.
(
~probe = TriadexMuseProbe.new(tempo: 4, baseNote: 60);
~probe.preset_('Michaels Tune');  // interval: B7, B8, B5 — SR-driven pitch
~probe.addShiftRegister((1..12), \rhythm, 0.04);
~probe.addPitch(\pitch, 0.2, 0);
~probe.play;
)

// Solo pitch:
~probe.soloVoice(\pitch);

// Add SR back — hear the bits that drive the melody:
~probe.unsoloAll;

~probe.stop;


// =====================================================================
// 7. Full pipeline decomposed
// =====================================================================
// All counters + XNOR + pitch.
// The complete Muse output alongside its internal clock signals.
(
~probe = TriadexMuseProbe.new(tempo: 4, baseNote: 60);
~probe.preset_('Musers Waltz');
~probe.addAll(\click, 0.05);
~probe.play;
)

// Inspect what is running:
~probe.postVoices;

// Solo just the XNOR — the heartbeat of the feedback:
~probe.soloVoice(\xnor);

// Solo just the pitch — the melody as normally heard:
~probe.soloVoice(\pitch);

// Everything together:
~probe.unsoloAll;

~probe.stop;


// =====================================================================
// 8. Gate mode — sustained tones from binary sources
// =====================================================================
// Instead of clicks, hear sustained tones that follow the duty cycle.
// C4 is high for 8 ticks, low for 8 ticks — a slow drone toggle.
// B1 evolves with the feedback — an unpredictable gate pattern.
(
~probe = TriadexMuseProbe.new(tempo: 8, baseNote: 60);
~probe.preset_('Musers Waltz');
~probe.addVoice(\C4gate, 5, \gate, 0.1, -0.5, 200);
~probe.addVoice(\B1gate, 9, \gate, 0.1, 0.5, 300);
~probe.addPitch(\pitch, 0.15, 0);
~probe.play;
)

~probe.stop;


// =====================================================================
// 9. Deep SR bits — long-term memory
// =====================================================================
// B20 through B31 change very slowly.
// These carry the long-term state of the instrument.
// At tempo 8, it takes many steps before deep bits evolve.
// Listen for the rare transitions — each one marks a shift
// in the Muse's long-term memory.
(
~probe = TriadexMuseProbe.new(tempo: 8, baseNote: 60);
~probe.preset_('Christmas Bells');  // reads from B28-B31
~probe.addShiftRegister((20..31), \click, 0.12);
~probe.addPitch(\pitch, 0.15, 0);
~probe.play;
)

// At first: mostly silence from the deep bits.
// Wait... the clicks will come as the SR fills.

~probe.stop;


// =====================================================================
// 10. Live slider manipulation
// =====================================================================
// Start with Scale preset, listen to counters + pitch.
// Then change sliders and hear the structure shift in real time.
(
~probe = TriadexMuseProbe.new(tempo: 4, baseNote: 60);
~probe.preset_('Scale');
~probe.addCounters(\click, 0.06);
~probe.addShiftRegister((1..4), \rhythm, 0.04);
~probe.addXnor(\xnor, \rhythm, 0.08, 0);
~probe.addPitch(\pitch, 0.2, 0);
~probe.play;
)

// Scale: all theme OFF — SR voices are constant, XNOR always 1
// Now activate feedback — move one theme slider:
~probe.muse.themeW_(9);  // W = B1
// Listen: SR voices come alive, XNOR pattern changes, melody evolves.

// Add more feedback:
~probe.muse.themeX_(10); // X = B2
~probe.muse.themeY_(11); // Y = B3

// Change interval sources:
~probe.muse.intervalA_(9);  // A = B1 (was C1)
// The melody now depends on SR state instead of the counter.

// Reset to hear the difference:
~probe.preset_('Scale');

~probe.stop;


// =====================================================================
// 11. Microtonal probe — same logic, different tuning
// =====================================================================
// The pitch voice maps through the scale array.
// Change the scale; the counter/SR rhythm stays identical;
// only the pitch content shifts.
(
~probe = TriadexMuseProbe.new(tempo: 4, baseNote: 60);
~probe.preset_('Musers Waltz');
~probe.addCounters(\click, 0.04);
~probe.addPitch(\pitch, 0.2, 0);
~probe.play;
)

// Default major scale:
~probe.scalePreset_('Major');

// Bohlen-Pierce tritave:
~probe.scalePreset_('BP Lambda');

// Carlos Alpha — non-repeating:
~probe.scalePreset_('Carlos Alpha');

// Xenakis Sieve:
~probe.scalePreset_('Xenakis Sieve');

// Partch Diamond:
~probe.scalePreset_('Partch Diamond');

// Back to major:
~probe.scalePreset_('Major');

~probe.stop;


// =====================================================================
// 12. Comparison: isolated vs. full
// =====================================================================
// The pedagogical arc: what does the Muse sound like?
// Then: what is hidden inside that sound?
(
~probe = TriadexMuseProbe.new(tempo: 4, baseNote: 60);
~probe.preset_('Musers Waltz');

// Start with just the melody
~probe.addPitch(\pitch, 0.2, 0);
~probe.play;
)

// This is the Muse. A monophonic square wave melody.
// Now reveal the hidden structure:
(
~probe.addCounters(\click, 0.05);
// The rhythmic skeleton appears — binary counting underneath the melody.
)

(
~probe.addShiftRegister((1..8), \rhythm, 0.03);
// The memory layer — the SR bits that carry the feedback history.
)

(
~probe.addXnor(\xnor, \rhythm, 0.06, 0);
// The feedback signal itself — the heartbeat that drives the SR.
)

// Everything together:
~probe.unsoloAll;

// Back to just the melody:
~probe.soloVoice(\pitch);

// Done.
~probe.stop;
