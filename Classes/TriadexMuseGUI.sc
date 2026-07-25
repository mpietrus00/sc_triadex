// TriadexMuseGUI — Visual interface for the Triadex Muse
//
// Colors and layout matched to Tillman's JavaScript emulation.
// Two-panel: left controls (track sliders) | right source matrix.

TriadexMuseGUI {

	// Colors from JS: this.color='#6666dd', this.altBackground='#cccccc'
	classvar <accent;       // #6666dd — labels, lines, brackets
	classvar <altBg;        // #cccccc — alternating row fill
	classvar <mainBg;       // near-white panel background
	classvar <paddleFill;   // #666666
	classvar <paddleStroke;  // #222222
	classvar <trackStroke;  // #444444
	classvar <lampBg;       // #555555
	classvar <lampCounter;  // #77bbff
	classvar <lampShiftReg; // #55ee55
	classvar <melodyColor;  // #aa3355
	classvar <sectionLines;

	var <player, <muse, <window;
	var <controlsView, <matrixView, <melodyView, <shiftRegView;
	var <stepLabel, <pitchLabel, <presetMenu, <synthMenu, <scaleMenu, <panToggle;
	var <overlapSlider, <overlapLabel, <offsetSlider, <offsetLabel;
	var <lightWindow, <lightView;
	var <controlValues, <controlDragging;
	var <labelWidth, <lampWidth;

	*initClass {
		accent       = Color(0.4, 0.4, 0.87);      // #6666dd
		altBg        = Color(0.8, 0.8, 0.8);        // #cccccc
		mainBg       = Color(0.92, 0.92, 0.92);     // light silver
		paddleFill   = Color(0.4, 0.4, 0.4);        // #666666
		paddleStroke = Color(0.13, 0.13, 0.13);      // #222222
		trackStroke  = Color(0.27, 0.27, 0.27);      // #444444
		lampBg       = Color(0.33, 0.33, 0.33);      // #555555
		lampCounter  = Color(0.47, 0.73, 1.0);       // #77bbff
		lampShiftReg = Color(0.33, 0.93, 0.33);      // #55ee55
		melodyColor  = Color(0.67, 0.2, 0.33);       // #aa3355
		sectionLines = #[2, 9];
	}

	*new { |player| ^super.new.init(player) }

	init { |argPlayer|
		player = argPlayer ?? { TriadexMusePlayer.new };
		muse = player.muse;
		labelWidth = 42; lampWidth = 12;
		controlValues = [2, 0, 1, 30, 25, 33];
		controlDragging = nil;
		this.prApplyControls;
		muse.onStep = { |m, pitch| this.prUpdateDisplay };
		CmdPeriod.doOnce({
			{
				controlValues[0] = 2;
				if(controlsView.notNil) { controlsView.refresh };
				this.prUpdateDisplay;
			}.defer;
		});
		this.prBuildWindow;
	}

	prBuildWindow {
		var mainRow, presetRow, srLabel, melLabel;

		window = Window(
			if(player.tempoLocked) { "THE MUSE — SYNCED" } { "THE MUSE" },
			Rect(if(player.tempoLocked) { 200 } { 100 }, 60, 940, 780)
		).background_(mainBg);

		stepLabel = StaticText().string_("Step: 0")
			.font_(Font("Menlo", 11)).stringColor_(accent).align_(\right);
		pitchLabel = StaticText().string_("Pitch: —")
			.font_(Font("Menlo", 11)).stringColor_(accent).align_(\right);

		// Left panel: custom-drawn control sliders on silver background
		controlsView = UserView().fixedWidth_(200)
			.background_(mainBg)
			.drawFunc_({ |view| this.prDrawControls(view) })
			.mouseDownAction_({ |view, x, y| this.prControlsClick(view, x, y) })
			.mouseMoveAction_({ |view, x, y| this.prControlsDrag(view, x, y) })
			.mouseUpAction_({ |view, x, y| this.prControlsRelease });

		// Right panel: source matrix on silver background
		matrixView = UserView().minHeight_(480)
			.background_(mainBg)
			.drawFunc_({ |view| this.prDrawMatrix(view) })
			.mouseDownAction_({ |view, x, y| this.prMatrixClick(view, x, y) })
			.mouseMoveAction_({ |view, x, y| this.prMatrixClick(view, x, y) });

		shiftRegView = UserView().fixedHeight_(20)
			.background_(lampBg)
			.drawFunc_({ |view| this.prDrawShiftReg(view) });

		melodyView = UserView().minHeight_(80)
			.background_(Color.white)
			.drawFunc_({ |view| this.prDrawMelody(view) });

		presetMenu = PopUpMenu()
			.items_(["— Presets —"] ++ TriadexMuse.presetNames)
			.value_(0).font_(Font("Menlo", 10))
			.background_(Color.grey(0.85)).stringColor_(accent)
			.action_({ |m|
				var name;
				if(m.value > 0) {
					name = TriadexMuse.presetNames[m.value - 1];
					player.preset_(name);
					{ matrixView.refresh }.defer;
				};
			});

		synthMenu = PopUpMenu()
			.items_(TriadexMusePlayer.synthTypeNames.collect({ |s|
				s.asString.toUpper
			}))
			.value_(0).font_(Font("Menlo", 10))
			.background_(Color.grey(0.85)).stringColor_(accent)
			.action_({ |m|
				var name = TriadexMusePlayer.synthTypeNames[m.value];
				player.synthType_(name);
			});

		scaleMenu = PopUpMenu()
			.items_(["— Scale —"] ++ TriadexMuse.scalePresetNames ++ ["Load .scl..."])
			.value_(0).font_(Font("Menlo", 10))
			.background_(Color.grey(0.85)).stringColor_(accent)
			.action_({ |m|
				var names = TriadexMuse.scalePresetNames;
				if(m.value == 0) { /* header, ignore */ } {
					if(m.value <= names.size) {
						muse.scalePreset_(names[m.value - 1]);
					} {
						// "Load .scl..." — positional args: okFunc, cancelFunc,
						// fileMode (1=existing), acceptMode (0=open), stripResult
						FileDialog({ |path|
							{
								if(path.isKindOf(Array)) { path = path[0] };
								muse.loadSCLFile(path);
								scaleMenu.items_(
									["— Scale —"] ++ names
									++ [PathName(path).fileNameWithoutExtension]
									++ ["Load .scl..."]
								);
								scaleMenu.value_(names.size + 1);
							}.defer;
						}, {
							// Cancel: reset to header
							{ scaleMenu.value_(0) }.defer;
						}, 1, 0, true);
					};
				};
			});

		panToggle = Button()
			.states_([
				["L/R", Color.grey(0.4), Color.grey(0.85)],
				["L/R", Color.white, accent]
			]).font_(Font("Menlo", 10, true))
			.fixedWidth_(40)
			.action_({ |btn|
				player.alternatePan = (btn.value == 1);
			});

		// Overlap (legato): NumberBox, range 0.1 to 8.0
		overlapLabel = StaticText().string_("OVERLAP")
			.font_(Font("Menlo", 8)).stringColor_(accent)
			.fixedWidth_(50).fixedHeight_(16).align_(\right);
		overlapSlider = NumberBox()
			.fixedWidth_(40).fixedHeight_(16)
			.font_(Font("Menlo", 9)).normalColor_(accent)
			.background_(Color.grey(0.85))
			.clipLo_(0.1).clipHi_(3.0).step_(0.1).scroll_step_(0.1)
			.value_(player.legato)
			.action_({ |nb|
				player.legato = nb.value;
			});

		// Offset (beat delay): NumberBox, only for synced instances
		if(player.tempoLocked) {
			offsetLabel = StaticText().string_("OFFSET")
				.font_(Font("Menlo", 8)).stringColor_(accent)
				.fixedWidth_(45).fixedHeight_(16).align_(\right);
			offsetSlider = NumberBox()
				.fixedWidth_(40).fixedHeight_(16)
				.font_(Font("Menlo", 9)).normalColor_(accent)
				.background_(Color.grey(0.85))
				.clipLo_(0.0).clipHi_(4.0).step_(0.05).scroll_step_(0.05)
				.value_(player.beatOffset)
				.action_({ |nb|
					player.beatOffset = nb.value;
				});
		};

		srLabel = StaticText().string_("SHIFT REGISTER")
			.font_(Font("Menlo", 8)).stringColor_(accent)
			.fixedHeight_(12).align_(\center);
		melLabel = StaticText().string_("MELODY")
			.font_(Font("Menlo", 8)).stringColor_(accent)
			.fixedHeight_(12).align_(\center);
		presetRow = HLayout(
			scaleMenu, synthMenu, panToggle,
			overlapLabel, overlapSlider,
			if(player.tempoLocked) { offsetLabel } { nil },
			if(player.tempoLocked) { offsetSlider } { nil },
			nil, presetMenu,
			Button()
				.states_([["LIGHT", Color.grey(0.4), Color.grey(0.85)]])
				.font_(Font("Menlo", 10, true))
				.fixedWidth_(50)
				.action_({ this.openLightShow })
		);
		presetRow.spacing_(6);

		mainRow = HLayout(controlsView, matrixView);
		mainRow.spacing_(2);

		window.layout = VLayout(
			HLayout(
				StaticText().string_("TRIADEX   THE MUSE")
					.font_(Font("Menlo", 14, true))
					.stringColor_(accent).align_(\left),
				if(player.tempoLocked) {
					StaticText().string_("SYNCED")
						.font_(Font("Menlo", 10, true))
						.stringColor_(lampShiftReg)
						.align_(\left);
				} { nil },
				nil, stepLabel, pitchLabel
			),
			mainRow,
			srLabel, shiftRegView,
			melLabel, melodyView,
			presetRow
		);
		window.layout.margins_(6);
		window.layout.spacing_(2);

		window.onClose = { player.stop; muse.onStep = nil };
		window.front;
		this.prUpdateDisplay;
	}

	// ============================================================
	// LEFT PANEL: Custom-drawn slider controls
	// ============================================================

	prDrawControls { |view|
		var bounds, col1, col2, col3, row1, row2;
		bounds = view.bounds;
		col1 = 35; col2 = 90; col3 = 145;
		row1 = 30; row2 = 130;

		this.prDrawSlider(col1, row1, 3, 20, controlValues[0], ["START", "RUN", "OFF"]);
		this.prDrawSlider(col2, row1, 3, 20, controlValues[1], ["AUTO", "HOLD", "STEP"]);
		this.prDrawSlider(col3, row1, 2, 20, controlValues[2], ["REST", "NORMAL"]);

		this.prDrawSlider(col1, row2, 50, 4, controlValues[3], ["VOLUME"]);
		if(player.tempoLocked.not) {
			this.prDrawSlider(col2, row2, 50, 4, controlValues[4], ["TEMPO"]);
		} {
			this.prDrawSlider(col2, row2, 50, 4, controlValues[4], ["SYNC"]);
			// Draw lock indicator over the tempo track
			Pen.fillColor = Color.grey(0.6, 0.5);
			Pen.fillRect(Rect(col2 - 10, row2, 20, 200));
		};
		this.prDrawSlider(col3, row2, 50, 4, controlValues[5], ["PITCH"]);

		// Number scale 0-8 alongside fine sliders
		Pen.font = Font("Menlo", 9); Pen.fillColor = accent;
		9.do({ |i|
			var y; y = row2 + ((8 - i) * (200.0 / 9)) + 8;
			Pen.stringAtPoint(i.asString, 8 @ y);
		});

		// Readouts below sliders
		this.prDrawVolumeLabel(col1, row2 + 210);
		if(player.tempoLocked.not) {
			this.prDrawBpmLabel(col2, row2 + 210);
		};
		this.prDrawPitchLabel(col3, row2 + 210);
	}

	prDrawSlider { |cx, top, n, dy, value, labels|
		var trackHeight, paddleH, paddleW, endSpace, yy;
		trackHeight = n * dy;
		paddleH = 8; paddleW = 20;
		endSpace = (0.5 * (paddleH - dy)).max(0);

		// Track — #444444
		Pen.strokeColor = trackStroke; Pen.width = 1;
		Pen.strokeRect(Rect(cx - 2, top, 4, trackHeight + (2 * endSpace)));

		// Paddle — fill #666666, stroke #222222
		yy = top + endSpace + ((value + 0.5) * dy);
		Pen.fillColor = paddleFill;
		Pen.fillRect(Rect(cx - (paddleW * 0.5), yy - (paddleH * 0.5), paddleW, paddleH));
		Pen.strokeColor = paddleStroke;
		Pen.strokeRect(Rect(cx - (paddleW * 0.5), yy - (paddleH * 0.5), paddleW, paddleH));

		// Labels — #6666dd
		Pen.font = Font("Menlo", 9); Pen.fillColor = accent;
		Pen.stringAtPoint(labels[0], (cx - (labels[0].size * 3)) @ (top - 14));
		if(labels.size == 2) {
			Pen.stringAtPoint(labels[1],
				(cx - (labels[1].size * 3)) @ (top + trackHeight + (2 * endSpace) + 4));
		};
		if(labels.size == 3) {
			Pen.stringAtPoint(labels[1],
				(cx - (labels[1].size * 6) - 14) @ (top + (trackHeight * 0.5) - 4));
			Pen.stringAtPoint(labels[2],
				(cx - (labels[2].size * 3)) @ (top + trackHeight + (2 * endSpace) + 4));
		};
	}

	prDrawBpmLabel { |cx, y|
		var bpm, label;
		bpm = (6000 * (30 / 6000).pow(controlValues[4] / 49)).round(1).asInteger;
		label = bpm.asString ++ " BPM";
		Pen.font = Font("Menlo", 8); Pen.fillColor = accent;
		Pen.stringAtPoint(label, (cx - (label.size * 2.5)) @ y);
	}

	prDrawVolumeLabel { |cx, y|
		var pct, label;
		pct = (((49 - controlValues[3]) / 49) * 100).round.asInteger;
		label = pct.asString ++ "%";
		Pen.font = Font("Menlo", 8); Pen.fillColor = accent;
		Pen.stringAtPoint(label, (cx - (label.size * 2.5)) @ y);
	}

	prDrawPitchLabel { |cx, y|
		var midi, noteName, octave, freq, label;
		var noteNames = #["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"];
		midi = ControlSpec(108, 24, \lin, 1).map(controlValues[5] / 49).asInteger;
		noteName = noteNames[midi % 12];
		octave = (midi / 12).floor.asInteger - 1;
		freq = midi.midicps.round(1).asInteger;
		label = noteName ++ octave ++ " [" ++ freq ++ "]";
		Pen.font = Font("Menlo", 8); Pen.fillColor = accent;
		Pen.stringAtPoint(label, (cx - (label.size * 2.5)) @ y);
	}

	// --- Controls interaction ---

	prControlsHitTest { |x, y|
		var specs;
		specs = [
			[35, 30, 3, 20], [90, 30, 3, 20], [145, 30, 2, 20],
			[35, 130, 50, 4], [90, 130, 50, 4], [145, 130, 50, 4]
		];
		specs.do({ |spec, i|
			var cx, top, n, dy, endSpace, val;
			cx = spec[0]; top = spec[1]; n = spec[2]; dy = spec[3];
			endSpace = (0.5 * (8 - dy)).max(0);
			if((x >= (cx - 15)) and: { x <= (cx + 15) }) {
				val = ((y - top - endSpace) / dy).floor.asInteger;
				if(val >= 0 and: { val < n }) { ^[i, val] };
			};
		});
		^nil;
	}

	prControlsClick { |view, x, y|
		var hit; hit = this.prControlsHitTest(x, y);
		if(hit.notNil) {
			// Block tempo slider (index 4) when synced to external clock
			if(hit[0] == 4 and: { player.tempoLocked }) { ^nil };
			controlDragging = hit[0];
			controlValues[hit[0]] = hit[1];
			this.prApplyControls; controlsView.refresh;
		};
	}

	prControlsDrag { |view, x, y|
		var hit;
		if(controlDragging.notNil) {
			hit = this.prControlsHitTest(x, y);
			if(hit.notNil and: { hit[0] == controlDragging }) {
				controlValues[hit[0]] = hit[1];
				this.prApplyControls; controlsView.refresh;
			};
		};
	}

	prControlsRelease {
		var idx; idx = controlDragging; controlDragging = nil;
		if(idx.isNil) { ^nil };
		if(idx == 0 and: { controlValues[0] == 0 }) {
			controlValues[0] = 1; this.prApplyControls;
			{ controlsView.refresh }.defer;
		};
		if(idx == 1 and: { controlValues[1] == 2 }) {
			controlValues[1] = 1;
			{ controlsView.refresh }.defer;
		};
	}

	prApplyControls {
		// Only apply transport switches when the dragged control IS a transport
		if(controlDragging.isNil or: { controlDragging == 0 }) {
			switch(controlValues[0],
				0, { muse.reset; player.play },
				1, { if(player.isPlaying.not) { player.play } },
				2, { player.stop }
			);
		};
		if(controlDragging.isNil or: { controlDragging == 1 }) {
			switch(controlValues[1],
				0, { if(player.isPlaying.not and: { controlValues[0] != 2 })
					{ player.play } },
				1, { player.stop },
				2, { player.stop; player.stepOnce;
					{ this.prUpdateDisplay }.defer }
			);
		};
		muse.rest_(controlValues[2] == 0);
		player.amp = (49 - controlValues[3]) * 0.01;
		// Don't change tempo from a synced instance -- only the primary controls tempo
		if(player.tempoLocked.not) {
			player.tempo_(ControlSpec(6000, 30, \exp).map(controlValues[4] / 49) / 60);
		};
		player.baseNote = ControlSpec(108, 24, \lin, 1).map(controlValues[5] / 49);
	}

	// ============================================================
	// RIGHT PANEL: Source Matrix
	// ============================================================

	prMatrixClick { |view, x, y|
		var bounds, col, row, ml, mw, cw, headerHeight, matrixHeight;
		headerHeight = 50;
		bounds = view.bounds;
		ml = labelWidth; mw = bounds.width - labelWidth - lampWidth - 8;
		cw = mw / 8;
		matrixHeight = bounds.height - headerHeight;
		col = ((x - ml) / cw).floor.asInteger;
		if(col < 0 or: { col > 7 }) { ^nil };
		row = ((y - headerHeight) / (matrixHeight / 40)).floor.asInteger;
		if(row < 0 or: { row > 39 }) { ^nil };
		if(col < 4) { muse.interval[col] = row } { muse.theme[col - 4] = row };
		matrixView.refresh;
	}

	prDrawMatrix { |view|
		var bounds, states, sourceLabels, rh, ml, mw, cw;
		var sliderLabels, lampColX, headerHeight, matrixTop;

		headerHeight = 50;
		bounds = view.bounds;
		matrixTop = headerHeight;
		rh = (bounds.height - headerHeight) / 40;
		ml = labelWidth; mw = bounds.width - labelWidth - lampWidth - 8;
		cw = mw / 8;
		sourceLabels = TriadexMuse.sourceLabels;
		states = muse.sourceStates;
		sliderLabels = ["A", "B", "C", "D", "W", "X", "Y", "Z"];
		lampColX = bounds.width - lampWidth - 2;

		if(states.isNil) { ^nil };

		// === HEADER: slider indicators, brackets, column labels ===
		// Layout (top to bottom):
		//   y=2..8    slider indicator bars
		//   y=12..22  brackets with INTERVAL / THEME labels
		//   y=28..40  column letters A B C D  W X Y Z
		//   y=50      separator line -> matrix starts

		// Slider position indicator bars
		8.do({ |col|
			var pos, barX, barW;
			pos = if(col < 4) { muse.interval[col] } { muse.theme[col - 4] };
			barX = ml + (col * cw) + 2;
			barW = cw - 4;
			Pen.fillColor = if(col < 4) { lampCounter } { lampShiftReg };
			Pen.fillRect(Rect(barX, 2, barW * ((pos + 1) / 40), 6));
			Pen.strokeColor = accent; Pen.width = 0.5;
			Pen.strokeRect(Rect(barX, 2, barW, 6));
		});

		// Section labels: INTERVAL and THEME
		// Each label centered in its own rect, no bracket lines to avoid overlap
		Pen.font = Font("Menlo", 9, true); Pen.fillColor = accent;
		Pen.stringCenteredIn("INTERVAL", Rect(ml, 10, 4 * cw, 14));
		Pen.stringCenteredIn("THEME", Rect(ml + (4 * cw), 10, 4 * cw, 14));

		// Column letters A B C D | W X Y Z
		Pen.font = Font("Menlo", 10); Pen.fillColor = accent;
		sliderLabels.do({ |label, i|
			var cx = ml + (i * cw) + (cw * 0.5) - 3;
			Pen.stringAtPoint(label, cx @ 30);
		});

		// Header/matrix separator line
		Pen.strokeColor = accent; Pen.width = 1;
		Pen.line(0 @ matrixTop, bounds.width @ matrixTop); Pen.stroke;

		// === MATRIX BODY ===

		// Matrix border — #6666dd
		Pen.strokeColor = accent; Pen.width = 1;
		Pen.strokeRect(Rect(0, matrixTop, bounds.width, bounds.height - matrixTop));

		// Lamp column background — #555555
		Pen.fillColor = lampBg;
		Pen.fillRect(Rect(lampColX - 2, matrixTop, lampWidth + 4, bounds.height - matrixTop));

		// Rows
		40.do({ |row|
			var y = matrixTop + (row * rh);

			// Alternating background: even=#cccccc, odd=white
			if(row.even) {
				Pen.fillColor = altBg;
				Pen.fillRect(Rect(0, y, lampColX - 2, rh));
			};

			// Section dividers
			if(sectionLines.includes(row)) {
				Pen.strokeColor = accent; Pen.width = 0.5;
				Pen.line(0 @ y, bounds.width @ y); Pen.stroke;
			};

			// Row label left — #6666dd
			Pen.fillColor = accent;
			Pen.font = Font("Menlo", (rh - 2).clip(7, 10));
			Pen.stringAtPoint(sourceLabels[row], 3 @ (y + 1));

			// Row label right
			Pen.stringAtPoint(sourceLabels[row],
				(lampColX - 6 - (sourceLabels[row].size * 6)) @ (y + 1));

			// Lamp — #77bbff (counters) or #55ee55 (SR)
			if(states[row] == 1) {
				Pen.fillColor = if(row < 9) { lampCounter } { lampShiftReg };
				Pen.fillRect(Rect(lampColX, y + 2, lampWidth, (rh - 4).max(2)));
			};

			// Slider paddles — fill #666666, stroke #222222
			8.do({ |col|
				var pos, px, pw, ph;
				pos = if(col < 4) { muse.interval[col] } { muse.theme[col - 4] };
				if(pos == row) {
					px = ml + (col * cw) + 2;
					pw = cw - 4; ph = (rh - 2).max(4);
					Pen.fillColor = paddleFill;
					Pen.fillRect(Rect(px, y + 1, pw, ph));
					Pen.strokeColor = paddleStroke;
					Pen.strokeRect(Rect(px, y + 1, pw, ph));
				};
			});
		});

		// Column grid — #6666dd
		Pen.strokeColor = accent; Pen.width = 0.5;
		9.do({ |i|
			var x = ml + (i * cw);
			Pen.line(x @ matrixTop, x @ bounds.height);
		});
		Pen.stroke;

		// INTERVAL/THEME divider — thicker
		Pen.strokeColor = accent; Pen.width = 1.5;
		Pen.line((ml + (4 * cw)) @ 0, (ml + (4 * cw)) @ bounds.height);
		Pen.stroke;
	}

	prDrawLabelBracket { |x1, x2, y, label, textWidth, color|
		// Draws:  ⌐———— LABEL ————¬
		// y = top of horizontal line, end caps go down 6px
		var cx, capH;
		capH = 6;
		cx = (x1 + x2) * 0.5;
		Pen.strokeColor = color; Pen.fillColor = color;
		Pen.width = 1.5; Pen.font = Font("Menlo", 9, true);
		// Left end cap (vertical) + horizontal line to label
		Pen.line(x1 @ (y + capH), x1 @ y);
		Pen.lineTo((cx - textWidth * 0.5 - 4) @ y);
		Pen.stroke;
		// Right end cap (vertical) + horizontal line to label
		Pen.line(x2 @ (y + capH), x2 @ y);
		Pen.lineTo((cx + textWidth * 0.5 + 4) @ y);
		Pen.stroke;
		// Label text centered in the gap
		Pen.stringAtPoint(label, (cx - textWidth * 0.5) @ (y - 5));
	}

	// --- Shift Register ---

	prDrawShiftReg { |view|
		var bounds, bits, cellWidth;
		bounds = view.bounds; bits = muse.shiftRegisterBits;
		cellWidth = bounds.width / 31;
		if(bits.isNil) { ^nil };
		31.do({ |i|
			var x; x = i * cellWidth;
			Pen.fillColor = if(bits[i] == 1) { lampShiftReg } { Color.grey(0.25) };
			Pen.fillRect(Rect(x + 1, 2, cellWidth - 2, bounds.height - 4));
		});
		Pen.fillColor = accent; Pen.font = Font("Menlo", 7);
		Pen.stringAtPoint("B1", 2 @ 4);
		Pen.stringAtPoint("B31", (bounds.width - 20) @ 4);
	}

	// --- Melody Plot — #aa3355 ---

	prDrawMelody { |view|
		var bounds, history, maxPitch, dotSize;
		var visibleCount, startIdx, prevPoint;
		bounds = view.bounds; history = muse.history;
		maxPitch = 24; dotSize = 3;
		if(history.isNil or: { history.size == 0 }) { ^nil };

		Pen.strokeColor = Color.grey(0.85); Pen.width = 0.5;
		(maxPitch + 1).do({ |p|
			var y; y = bounds.height - (p / maxPitch * bounds.height);
			Pen.line(0 @ y, bounds.width @ y);
		}); Pen.stroke;

		visibleCount = min(history.size, (bounds.width / (dotSize + 1)).asInteger);
		if(visibleCount <= 0) { ^nil };
		startIdx = max(0, history.size - visibleCount);
		prevPoint = nil;
		visibleCount.do({ |i|
			var idx, pitch, x, y, point;
			idx = startIdx + i; pitch = history[idx];
			if(pitch.notNil) {
				x = i / visibleCount * bounds.width;
				y = bounds.height - (pitch / maxPitch * bounds.height);
				point = x @ y;
				// #aa3355
				Pen.strokeColor = melodyColor; Pen.width = 2;
				Pen.line(x @ y, (x + (bounds.width / visibleCount)) @ y);
				Pen.stroke;
				if(prevPoint.notNil) {
					Pen.strokeColor = melodyColor; Pen.width = 1;
					Pen.line(prevPoint, point); Pen.stroke;
				};
				prevPoint = (x + (bounds.width / visibleCount)) @ y;
			} { prevPoint = nil };
		});
	}

	// --- Display Update ---

	prUpdateDisplay {
		{
			var pitch, bps;
			if(window.notNil and: { window.isClosed.not }) {
				pitch = muse.currentPitch;
				stepLabel.string = "Step: " ++ muse.stepCount;
				pitchLabel.string = "Pitch: " ++ if(pitch.notNil) {
					if(pitch.frac == 0) { pitch.asInteger } { pitch.round(0.01) }
				} { "rest" };
				matrixView.refresh; shiftRegView.refresh;
				melodyView.refresh; controlsView.refresh;
				this.prUpdateLightShow;
				// Sync START/RUN/OFF slider with transport state
				if(player.isPlaying and: { controlValues[0] == 2 }) {
					controlValues[0] = 1;
				};
				if(player.isPlaying.not and: { controlValues[0] == 1 }) {
					controlValues[0] = 2;
				};
				// Sync tempo slider from shared clock on locked instances
				if(player.tempoLocked and: { player.externalClock.notNil }) {
					bps = player.externalClock.tempo;
					controlValues[4] = (
						ControlSpec(6000, 30, \exp).unmap(bps * 60) * 49
					).round.asInteger.clip(0, 49);
				};
			};
		}.defer;
	}

	// ============================================================
	// LIGHT SHOW — separate window driven by the 4 interval bits
	// ============================================================
	// The original Triadex Muse Light Show was a flat panel accessory
	// with 4 coloured lamps (one per interval bit A/B/C/D) behind a
	// translucent diffuser. The additive colour mixing produced shifting
	// hues as the melody played. We simulate this with 4 colour channels:
	//   A (bit 0) = red, B (bit 1) = green, C (bit 2) = blue, D (bit 3) = warm white

	openLightShow {
		if(lightWindow.notNil and: { lightWindow.isClosed.not }) {
			lightWindow.front;
			^this;
		};

		lightWindow = Window("MUSE LIGHT SHOW", Rect(300, 100, 400, 400))
			.background_(mainBg);

		lightView = UserView(lightWindow, lightWindow.view.bounds)
			.resize_(5) // scale with window
			.drawFunc_({ |view|
				this.prDrawLightPanel(view);
			});

		lightWindow.front;
	}

	prDrawLightPanel { |view|
		var bounds, bits, r, g, b, w, color, steps, margin;
		var edgeColor, coreColor;
		bounds = view.bounds;
		bits = muse.noteBits;
		steps = 60; // high count for smooth wash
		margin = 4;

		// 4 lamps: A=red, B=green, C=blue, D=warm white
		r = (bits bitAnd: 1);
		g = (bits >> 1) bitAnd: 1;
		b = (bits >> 2) bitAnd: 1;
		w = (bits >> 3) bitAnd: 1;

		// Core colour from additive mixing
		color = Color(
			(r * 0.8 + (w * 0.35)).min(1.0),
			(g * 0.7 + (w * 0.3)).min(1.0),
			(b * 0.85 + (w * 0.2)).min(1.0)
		);

		// Edge tint
		edgeColor = Color(
			mainBg.red * 0.9 + (color.red * 0.1),
			mainBg.green * 0.9 + (color.green * 0.1),
			mainBg.blue * 0.9 + (color.blue * 0.1)
		);

		// When all bits off, dim warm grey
		if(bits == 0) {
			color = Color(mainBg.red * 0.85, mainBg.green * 0.83, mainBg.blue * 0.8);
			edgeColor = color;
		};

		// Concentric square gradient — many steps for smooth wash
		steps.do({ |i|
			var t, inset, col;
			t = i / steps;
			inset = margin + (t * (bounds.width.min(bounds.height) * 0.45));
			col = Color(
				edgeColor.red + (t * t * (color.red - edgeColor.red)),
				edgeColor.green + (t * t * (color.green - edgeColor.green)),
				edgeColor.blue + (t * t * (color.blue - edgeColor.blue))
			);
			Pen.fillColor = col;
			Pen.fillRect(Rect(
				inset, inset,
				bounds.width - (inset * 2),
				bounds.height - (inset * 2)
			));
		});

		// Thin border
		Pen.strokeColor = Color.grey(0.6);
		Pen.width = 1;
		Pen.strokeRect(Rect(margin, margin,
			bounds.width - (margin * 2),
			bounds.height - (margin * 2)
		));

		// Bit indicators along the bottom edge
		Pen.font = Font("Menlo", 9);
		["A", "B", "C", "D"].do({ |label, i|
			var x, bitOn;
			x = bounds.width * (i + 0.5) / 4;
			bitOn = (bits >> i) bitAnd: 1;
			Pen.fillColor = if(bitOn == 1) { Color.white(0.9) } { Color.grey(0.4) };
			Pen.fillRect(Rect(x - 4, bounds.height - 22, 8, 8));
			Pen.fillColor = Color.grey(0.5);
			Pen.stringAtPoint(label, (x - 3) @ (bounds.height - 13));
		});
	}

	prUpdateLightShow {
		if(lightWindow.notNil and: { lightWindow.isClosed.not }) {
			lightView.refresh;
		};
	}

	close {
		if(window.notNil and: { window.isClosed.not }) { window.close };
		if(lightWindow.notNil and: { lightWindow.isClosed.not }) { lightWindow.close };
	}
	front { if(window.notNil and: { window.isClosed.not }) { window.front } }
}
