# TriadexMuse — Audio Analysis Log

## Objective

Reverse-engineer Triadex Muse slider positions from Maryanne Amacher recordings.
Recordings analysed: Synaptic Island excerpt, Chorale 1, Head Rhythm 1.

---

## Infrastructure Built

### SuperCollider (`examples/analysis.scd`, `analyse_sequence.scd`)
- FluCoMa-based onset detection + pitch extraction
- Grid-based and onset-based note segmentation
- Preset comparison (all 20 factory presets)
- Brute-force slider inference (40^4 theme search)
- **Problem**: SC blocks with `if(cond) { } { }` syntax fail in scvsc; must use `if(cond, { }, { })` comma syntax throughout. `Document` class unavailable in headless sclang. `thisProcess.nowExecutingPath` returns nil in scvsc.

### Python (`examples/analyse_full.py`, `examples/infer_sliders.py`)
- librosa-based onset detection, pYIN F0 tracking
- torchcrepe (CREPE neural pitch tracker) installed
- Gap-based pitch clustering
- Brute-force slider inference: ~55,000-70,000 configs/sec
- Monte Carlo + hill climbing contour matching
- **Verified correct**: recovers "Scale" preset perfectly from synthesized audio

### Audition tool (`examples/audition_candidates.scd`)
- Opens TriadexMuseGUI, loads reference recording
- Sets candidate slider configs with GUI matrix update
- A/B comparison with reference audio

---

## Recordings Analysed

### `sequence_one_run.wav` (1.51s, 48kHz, mono)
- User-trimmed single sequence cycle from Synaptic Island
- **F0 results (pYIN)**: all detected F0s in 2200-3000 Hz range
- **F0 results (CREPE)**: max confidence 0.06 — signal not periodic
- **Spectral analysis**: strongest peak at 2227 Hz, no harmonic series (ratios 0.75, 1.11 — non-integer). Spectral centroid 2512 Hz.
- **Conclusion**: NOT a raw square wave. Heavily processed (ring modulation, room acoustics). The 2200-3000 Hz readings are the actual spectral content, not harmonics of a lower fundamental.

### `06 - Maryanne Amacher - Chorale 1.flac` (354s, 44.1kHz, stereo)
- Full album track from Head Rhythm 1 / Head Rhythm 2 (1995)
- **Two Muses confirmed** by F0 distribution:
  - Low voice: ~90-112 Hz (MIDI 42-45), 2-3 pitches
  - High voice: ~525-1303 Hz (MIDI 72-88), 6 pitches
  - Clear gap between voices (~112-525 Hz)
- High voice clusters: 717, 923, 1091, 1369, 1777, 1905 Hz
- Clock period: ~80-100ms (10-12 notes/sec)
- Grid-based extraction: 745 steps, only 76 pitched (10%) at conf>0.3
- Lowering confidence helped but onsets still unreliable

### `01 - Maryanne Amacher - Head Rhythm 1 and Plaything 2 (1992).flac` (614s)
- Full album track
- CREPE max confidence: 0.19 — too low for any tracking
- The Muse is buried in a dense mix; pitch trackers cannot isolate it

### `Triadex Excerpt_Maryanne Amacher - Synaptic Island.wav` (145s, 44.1kHz, stereo)
- LOW band (80-600 Hz) analysis found 8 clusters at 206-590 Hz
- HIGH band (500-3000 Hz) found 75% voiced at 1275-2764 Hz
- 12 clusters in 60s version (full range)
- Dedup sequence: 452 steps with values 0-11

---

## Methods Tried & Results

### 1. Absolute F0 + exact DCBA matching
- **Approach**: Extract F0 per note, cluster into pitch classes, map cluster index to DCBA value, brute-force search all 40^4 theme configs
- **Result**: Zero solutions on every recording, every offset (0-31), every clustering threshold
- **Why it failed**: (a) F0 trackers detect harmonics or ring-mod sidebands, not the Muse fundamental; (b) even when F0 seemed correct, the onset-to-Muse-tick alignment was unknown; (c) ring modulation creates non-harmonic spectra that defeat all standard pitch trackers

### 2. Grid-based F0 sampling (fixed clock period)
- **Approach**: Detect clock from IOI mode, sample F0 at regular grid positions
- **Result**: Very low voiced detection rate (10-23%). Long runs of identical values suggesting clock misalignment.
- **Why it failed**: The detected clock period may not match the actual Muse tick rate; grid phase offset unknown

### 3. LOW band analysis (80-600 Hz fundamentals)
- **Approach**: Bandpass to isolate potential Muse fundamentals in the low register
- **Result**: Found 8 clusters at 206-590 Hz on Synaptic Island — the right number for a 3-bit Muse output. But inference still found zero solutions.
- **Why it failed**: The dedup step (collapsing identical consecutive notes) loses timing alignment with the Muse's internal counter state

### 4. Relative pitch contour matching
- **Approach**: Extract UP/DOWN/SAME direction of spectral centroid changes between consecutive onsets. Monte Carlo search (2-3M random configs) + hill climbing.
- **Result on sequence_one_run.wav**: 73.1% match (19/26 transitions correct), 53 candidate configs found
- **Result on Chorale**: 50.0% match (56/112 transitions) — barely above chance
- **Why limited**: Ring modulation and room acoustics distort the spectral centroid movement; many "SAME" transitions where the centroid barely changes

### 5. Neural pitch tracking (CREPE/torchcrepe)
- **Result**: Near-zero confidence on all recordings (max 0.06 on isolated file, 0.19 on full tracks)
- **Why it failed**: CREPE expects periodic signals; the processed Muse output lacks clear periodicity

### 6. Zero-crossing pitch detection
- **Result**: Implementation error (array shape mismatch), but unlikely to work on non-periodic signals
- **Why limited**: Only works on clean periodic waveforms; ring-mod output is not periodic

---

## Key Discovery: Amacher's Processing Chain

From "Additional Tones" workbook (Workbook IV, "Basic Experiments", pp. 153-167):

1. **Muse operating frequency**: ~3000 Hz for "standing wave phenomena" (p.165: "Standing wave phenomena w/ 3,000Hz Muse business")
2. **"Well Tuned Ear" range**: 800-6,000 Hz (p.165)
3. **Bode Ring Modulator**: Used to process Muse output (p.165: "Will want to repeat these experiments with Bode Ring Modulator and compare")
4. **Two Muses**: Producing tones in near-consonant ratios (octave, 5th, 4th) to generate:
   - Difference tones (1st order: F2-F1)
   - Combination tones (2nd order: beats of mistuned consonances)
   - Missing fundamental tracking
   - Otoacoustic emissions in the listener's ear
5. **Key frequencies**: 440 Hz reference, experiments from 90-1500 Hz, cutoff at 1500 Hz
6. **Psychoacoustic targets**: amplitude modulation near unison, roughness/beating at Δf=10-15 Hz, fusion at 3rd/4th/5th

This explains why pitch tracking fails: the Ring Modulator creates sum (F1+F2) and difference (F1-F2) frequencies from the Muse output and a carrier, producing non-harmonic spectra that no standard pitch tracker can handle.

---

## What Works / What to Use

- **TriadexMuse class**: Fully functional emulator with all 20 presets, custom scales (including microtonal, JI, Bohlen-Pierce), `.scl` file import
- **TriadexMusePlayer**: Audio engine with transport, tempo, waveform selection
- **TriadexMuseGUI**: Interactive GUI with slider matrix, source lamps, melody display
- **infer_sliders.py**: Fast brute-force inference (~55K configs/sec) — works perfectly when given a correct pitch sequence
- **Contour matching**: Best available approach for processed audio (73% on short excerpt)

## Requirements for Successful Inference

A direct line-out recording from Muse hardware (bypassing ring modulation, room acoustics, and mixing) would allow the inference pipeline to work. The pipeline needs:
- Clean monophonic square wave signal
- Known clock rate (or detectable from clear onsets)
- At least 20-30 steps of sequence data

---

## Files Created

| File | Purpose |
|------|---------|
| `examples/analysis.scd` | SC analysis pipeline (FluCoMa-based) |
| `examples/analyse_sequence.scd` | Simplified SC analysis for one sequence |
| `examples/analyse_full.py` | Python full analysis (librosa + inference) |
| `examples/infer_sliders.py` | Python brute-force slider inference |
| `examples/audition_candidates.scd` | SC audition tool with GUI |
| `examples/preprocess.scd` | SC audio preprocessing pipeline |
| `txt/IMG_8939-8950.HEIC` | Photos of Amacher's "Additional Tones" workbook |
