"""
TriadexMuse — Full analysis pipeline (grid-based).

Instead of onset detection (unreliable for repeated notes),
detect the Muse's clock period and sample F0 at each grid position.

The Muse outputs at a FIXED clock rate — once we know the period,
we can read the pitch at every tick regardless of whether it changed.
"""

import numpy as np
import librosa
import soundfile as sf
from pathlib import Path
import time
import sys

# --- Configuration ---
SOUNDS_DIR = Path.home() / "Desktop/TriadexMuse/sounds"
AUDIO_FILE = SOUNDS_DIR / "06 - Maryanne Amacher - Chorale 1.flac"

# Analysis parameters
HOP_LENGTH = 256
F0_FMIN = 80       # Muse fundamental range (square wave)
F0_FMAX = 2000     # upper limit for fundamentals
TRIM_START = 0     # start time in seconds
TRIM_END = 60      # end time in seconds

SOURCE_LABELS = (
    ["OFF", "ON", "C 1/2", "C1", "C2", "C4", "C8", "C3", "C6"]
    + [f"B{i}" for i in range(1, 32)]
)


# =====================================================================
# Audio Analysis (grid-based)
# =====================================================================

def load_audio(path, start=0, end=None):
    """Load audio file, convert to mono, optional trim."""
    duration = (end - start) if end else None
    y, sr = librosa.load(str(path), sr=None, mono=True,
                         offset=start, duration=duration)
    print(f"Loaded: {path.name}")
    print(f"  {len(y)} samples, {sr} Hz, {len(y)/sr:.2f} sec")
    if start > 0 or end:
        print(f"  Trimmed: {start}-{end}s")
    return y, sr


def detect_clock_period(y, sr):
    """
    Detect the Muse's clock period using autocorrelation of spectral flux.
    The Muse clocks at a fixed rate, producing periodic spectral changes.
    """
    # Spectral flux (onset strength envelope)
    onset_env = librosa.onset.onset_strength(y=y, sr=sr, hop_length=HOP_LENGTH)

    # Autocorrelation to find periodicity
    autocorr = np.correlate(onset_env - onset_env.mean(),
                            onset_env - onset_env.mean(), mode='full')
    autocorr = autocorr[len(autocorr)//2:]  # positive lags only
    autocorr = autocorr / autocorr[0]  # normalize

    # Find first significant peak after lag 0
    # Expect Muse tempo between 1-30 notes/sec
    min_lag = int(1.0 / 30 * sr / HOP_LENGTH)  # 30 notes/sec
    max_lag = int(1.0 / 1.0 * sr / HOP_LENGTH)  # 1 note/sec

    search_region = autocorr[min_lag:max_lag]
    if len(search_region) == 0:
        print("  WARNING: could not detect clock period, using default")
        return 0.1  # default 100ms

    peak_idx = np.argmax(search_region) + min_lag
    period_sec = peak_idx * HOP_LENGTH / sr

    # Also try onset-based estimation
    onsets = librosa.onset.onset_detect(y=y, sr=sr, hop_length=HOP_LENGTH,
                                         units='samples')
    if len(onsets) > 2:
        iois = np.diff(onsets) / sr
        # Use mode (most common IOI) rather than median
        hist, bin_edges = np.histogram(iois, bins=50)
        mode_idx = np.argmax(hist)
        ioi_mode = (bin_edges[mode_idx] + bin_edges[mode_idx + 1]) / 2
        print(f"  Onset IOI mode: {ioi_mode*1000:.1f}ms ({1/ioi_mode:.1f} notes/sec)")
        print(f"  Autocorrelation period: {period_sec*1000:.1f}ms ({1/period_sec:.1f} notes/sec)")

        # Use the more plausible one
        if 0.03 < ioi_mode < 1.0:
            period_sec = ioi_mode
    else:
        print(f"  Autocorrelation period: {period_sec*1000:.1f}ms ({1/period_sec:.1f} notes/sec)")

    print(f"  Using clock period: {period_sec*1000:.1f}ms ({1/period_sec:.1f} notes/sec)")
    return period_sec


def extract_f0_grid(y, sr, clock_period):
    """
    Extract F0 at each clock grid position.
    Instead of onset detection, sample the pitch at regular intervals.
    """
    # Run pYIN on full signal
    f0, voiced_flag, voiced_prob = librosa.pyin(
        y, fmin=F0_FMIN, fmax=F0_FMAX,
        sr=sr, hop_length=HOP_LENGTH
    )

    # Grid positions (in frames)
    total_time = len(y) / sr
    num_steps = int(total_time / clock_period)
    grid_times = np.arange(num_steps) * clock_period

    # For each grid position, take median F0 in a window around it
    window = clock_period * 0.6  # use central 60% of each clock period
    note_freqs = []

    for t in grid_times:
        start_frame = int((t + clock_period * 0.2) * sr / HOP_LENGTH)
        end_frame = int((t + clock_period * 0.8) * sr / HOP_LENGTH)
        start_frame = max(0, start_frame)
        end_frame = min(len(f0), end_frame)

        if start_frame >= end_frame:
            note_freqs.append(None)
            continue

        seg_f0 = f0[start_frame:end_frame]
        seg_conf = voiced_prob[start_frame:end_frame]

        # Keep confident voiced frames
        mask = ~np.isnan(seg_f0) & (seg_conf > 0.3)
        good_f0 = seg_f0[mask]

        if len(good_f0) > 0:
            note_freqs.append(float(np.median(good_f0)))
        else:
            note_freqs.append(None)

    pitched = sum(1 for f in note_freqs if f is not None)
    print(f"  Grid: {num_steps} steps at {clock_period*1000:.1f}ms intervals")
    print(f"  Pitched: {pitched}, Rests: {num_steps - pitched}")
    return note_freqs, grid_times


def cluster_pitches(note_freqs):
    """Cluster F0 values using gap-based method in MIDI space."""
    valid_freqs = [f for f in note_freqs if f is not None]
    if not valid_freqs:
        return []

    midi_vals = librosa.hz_to_midi(np.array(valid_freqs))
    sorted_midi = np.sort(midi_vals)

    if len(sorted_midi) < 2:
        return [float(sorted_midi[0])]

    # Find gaps
    gaps = np.diff(sorted_midi)
    # Threshold: gaps larger than 2.5x median are cluster boundaries
    threshold = max(0.4, float(np.median(gaps) * 2.5))
    print(f"  Merge threshold: {threshold:.2f} semitones")

    split_indices = np.where(gaps > threshold)[0]
    cluster_groups = np.split(sorted_midi, split_indices + 1)

    centres = sorted([float(np.mean(g)) for g in cluster_groups if len(g) > 0])

    print(f"  Found {len(centres)} pitch clusters:")
    for i, midi in enumerate(centres):
        freq = librosa.midi_to_hz(midi)
        cents = (midi - centres[0]) * 100
        print(f"    cluster {i}: {freq:.1f} Hz (MIDI {midi:.2f}, +{cents:.0f}c)")

    return centres


def map_to_sequence(note_freqs, centres):
    """Map each note F0 to nearest cluster index."""
    midi_centres = np.array(centres)
    sequence = []
    for f in note_freqs:
        if f is None:
            sequence.append(None)
        else:
            midi = librosa.hz_to_midi(f)
            idx = int(np.argmin(np.abs(midi_centres - midi)))
            sequence.append(idx)
    return sequence


# =====================================================================
# Muse Model & Inference
# =====================================================================

def source_at(position, c32, c6, sr):
    if position == 0: return 0
    if position == 1: return 1
    if position < 7: return (c32 >> (position - 2)) & 1
    if position < 9: return (c6 >> (position - 5)) & 1
    if position < 40: return (sr >> (position - 9)) & 1
    return 0


def infer_sliders(target_dcba, seq_len, try_offsets=None):
    """Brute-force search with multiple starting offsets."""
    if try_offsets is None:
        try_offsets = list(range(32))  # try all 32 counter positions

    for offset in try_offsets:
        solutions = []
        tested = 0
        start_time = time.time()

        for w in range(40):
            for x in range(40):
                for y in range(40):
                    for z in range(40):
                        tested += 1
                        sr = 0; c32 = 1; c6 = 0
                        post_states = []

                        total_steps = offset + seq_len
                        for step in range(total_steps):
                            new_bit = 1
                            new_bit ^= source_at(w, c32, c6, sr)
                            new_bit ^= source_at(x, c32, c6, sr)
                            new_bit ^= source_at(y, c32, c6, sr)
                            new_bit ^= source_at(z, c32, c6, sr)
                            c32 = (c32 + 1) & 0x1F
                            if (c32 & 1) == 0:
                                c6 += 1
                                if (c6 & 3) == 2: c6 += 1
                                sr = ((sr << 1) | new_bit) & 0x7FFFFFFF
                            if step >= offset:
                                post_states.append((c32, c6, sr))

                        valid = True
                        interval_sliders = [None] * 4
                        for bit in range(4):
                            candidates = []
                            for pos in range(40):
                                ok = True
                                for step in range(seq_len):
                                    t = target_dcba[step]
                                    if t is not None:
                                        expected = (t >> bit) & 1
                                        pc32, pc6, psr = post_states[step]
                                        actual = source_at(pos, pc32, pc6, psr)
                                        if actual != expected:
                                            ok = False
                                            break
                                if ok:
                                    candidates.append(pos)
                            if not candidates:
                                valid = False
                                break
                            interval_sliders[bit] = candidates

                        if valid:
                            solutions.append({
                                "theme": [w, x, y, z],
                                "interval": interval_sliders,
                                "offset": offset,
                            })
                            theme_labels = [SOURCE_LABELS[p] for p in [w, x, y, z]]
                            print(f"    FOUND at offset {offset}: Theme {theme_labels}")
                            sys.stdout.flush()

            elapsed = time.time() - start_time
            rate = tested / elapsed if elapsed > 0 else 0
            eta = (2560000 - tested) / rate if rate > 0 else 0
            if w % 10 == 9:
                print(f"    offset={offset} W={w:2d} | {tested/2560000*100:.1f}% | "
                      f"{rate:.0f}/s | ETA {eta:.0f}s | sol: {len(solutions)}")
                sys.stdout.flush()

        if solutions:
            return solutions

        elapsed = time.time() - start_time
        print(f"  offset={offset}: 0 solutions ({elapsed:.0f}s)")
        sys.stdout.flush()

    return []


# =====================================================================
# Main
# =====================================================================

def main():
    print("=" * 60)
    print("TriadexMuse — Grid-Based Audio Analysis")
    print("=" * 60)

    # 1. Load
    print("\n--- Stage 1: Load Audio ---")
    y, sr = load_audio(AUDIO_FILE, start=TRIM_START, end=TRIM_END)

    # 2. Clock detection
    print("\n--- Stage 2: Clock Period Detection ---")
    clock_period = detect_clock_period(y, sr)

    # 3. F0 at grid positions
    print("\n--- Stage 3: F0 Extraction (grid-based) ---")
    note_freqs, grid_times = extract_f0_grid(y, sr, clock_period)

    # Show first 40 F0s
    print("  First 40 notes:")
    for i, f in enumerate(note_freqs[:40]):
        freq_str = f"{f:.1f} Hz" if f else "rest"
        print(f"    step {i}: {freq_str}")

    # 4. Clustering
    print("\n--- Stage 4: Pitch Clustering ---")
    centres = cluster_pitches(note_freqs)

    if not centres:
        print("  No valid pitches found. Check audio/parameters.")
        return

    # 5. Sequence
    print("\n--- Stage 5: Pitch Sequence ---")
    sequence = map_to_sequence(note_freqs, centres)
    print(f"  Sequence ({len(sequence)} steps):")
    print(f"    {sequence[:64]}")
    if len(sequence) > 64:
        print(f"    ... ({len(sequence) - 64} more)")

    # Target DCBA
    target_dcba = [(ci & 15) if ci is not None else None for ci in sequence]

    # Use first 64 steps for inference (enough constraints, reasonable speed)
    infer_len = min(64, len(sequence))
    target_subset = target_dcba[:infer_len]
    non_none = sum(1 for t in target_subset if t is not None)
    print(f"  Using first {infer_len} steps for inference ({non_none} non-rest)")

    # 6. Inference
    print("\n--- Stage 6: Slider Inference ---")
    print(f"  Searching all 40^4 theme configs at offsets 0-31...")

    solutions = infer_sliders(target_subset, infer_len, try_offsets=range(32))

    # Results
    print("\n" + "=" * 60)
    if solutions:
        print(f"Found {len(solutions)} solution(s):\n")
        for i, sol in enumerate(solutions[:10]):
            theme_labels = [SOURCE_LABELS[p] for p in sol["theme"]]
            print(f"Solution {i+1} (offset={sol['offset']}):")
            print(f"  Theme [W X Y Z]: {theme_labels}")
            for bit in range(4):
                labels = [SOURCE_LABELS[p] for p in sol["interval"][bit]]
                print(f"  Interval {'ABCD'[bit]}: {labels}")
            print()
        sol = solutions[0]
        sliders = [sol["interval"][b][0] for b in range(4)] + sol["theme"]
        print(f"SuperCollider: muse.sliders_({sliders});")
    else:
        print("No solutions found.")
        print("\nDiagnostics:")
        print(f"  Clusters: {len(centres)}")
        print(f"  Sequence length: {len(sequence)}")
        print(f"  Non-rest steps: {sum(1 for s in sequence if s is not None)}")
        print(f"  Unique values: {sorted(set(s for s in sequence if s is not None))}")
        print(f"  F0 range: {min(f for f in note_freqs if f):.0f} - {max(f for f in note_freqs if f):.0f} Hz")
        print("\nPossible issues:")
        print("  - F0 tracking harmonics (try lower fmax)")
        print("  - Clock period detection wrong")
        print("  - Non-standard Muse modification")
    print("=" * 60)


if __name__ == "__main__":
    main()
