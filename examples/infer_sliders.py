"""
TriadexMuse slider inference from extracted pitch sequence.
Brute-force search over 40^4 theme configurations.

CRITICAL: The Muse reads pitch AFTER the counter advance (prClick),
so interval slider comparison must use post-click state.
"""

import time
import sys

# --- Pitch sequence from audio analysis ---
# Chorale 1 (23 steps, 4 clusters)
# PITCH_SEQUENCE = [2, 0, None, None, 3, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, None, 1, None, None, 2, 2]

# sequence_one run (19 steps, 10 clusters)
PITCH_SEQUENCE = [6, 2, 7, 1, 4, 0, 5, 5, 0, 3, 5, 6, 3, 4, 8, 7, 0, 9, 5]

SOURCE_LABELS = (
    ["OFF", "ON", "C 1/2", "C1", "C2", "C4", "C8", "C3", "C6"]
    + [f"B{i}" for i in range(1, 32)]
)


def source_at(position: int, c32: int, c6: int, sr: int) -> int:
    """Read binary value from source table."""
    if position == 0:
        return 0
    if position == 1:
        return 1
    if position < 7:
        return (c32 >> (position - 2)) & 1
    if position < 9:
        return (c6 >> (position - 5)) & 1
    if position < 40:
        return (sr >> (position - 9)) & 1
    return 0


def simulate_and_test(w, x, y, z, target_dcba, seq_len):
    """
    Simulate the Muse for a given theme config and test interval sliders.

    Key insight: prClick computes XNOR from pre-click state,
    then advances counters. currentPitch reads from post-click state.
    """
    sr = 0
    c32 = 1
    c6 = 0

    # Store post-click states (what currentPitch sees)
    post_states = []  # (c32_after, c6_after, sr_after) per step

    for step in range(seq_len):
        # 1. Compute XNOR from current (pre-click) state
        new_bit = 1
        new_bit ^= source_at(w, c32, c6, sr)
        new_bit ^= source_at(x, c32, c6, sr)
        new_bit ^= source_at(y, c32, c6, sr)
        new_bit ^= source_at(z, c32, c6, sr)

        # 2. Advance counters (the click)
        c32 = (c32 + 1) & 0x1F
        if (c32 & 1) == 0:
            c6 = c6 + 1
            if (c6 & 3) == 2:
                c6 = c6 + 1
            sr = ((sr << 1) | new_bit) & 0x7FFFFFFF

        # 3. Store POST-click state (this is what currentPitch reads)
        post_states.append((c32, c6, sr))

    # Test each interval bit against post-click states
    interval_sliders = [None] * 4
    for bit in range(4):
        candidates = []
        for pos in range(40):
            ok = True
            for step in range(seq_len):
                target = target_dcba[step]
                if target is not None:
                    expected = (target >> bit) & 1
                    pc32, pc6, psr = post_states[step]
                    actual = source_at(pos, pc32, pc6, psr)
                    if actual != expected:
                        ok = False
                        break
            if ok:
                candidates.append(pos)
        if not candidates:
            return None
        interval_sliders[bit] = candidates

    return interval_sliders


def main():
    seq = PITCH_SEQUENCE
    seq_len = len(seq)

    # Map cluster indices to 4-bit DCBA values
    target_dcba = [
        (ci & 15) if ci is not None else None for ci in seq
    ]

    print(f"Searching 40^4 = 2,560,000 theme configurations...")
    print(f"Using {seq_len} steps for inference.")
    print(f"Pitch sequence: {seq[:32]}{'...' if seq_len > 32 else ''}")
    print(f"Target DCBA: {target_dcba[:32]}")
    print()

    solutions = []
    start_time = time.time()
    tested = 0

    for w in range(40):
        for x in range(40):
            for y in range(40):
                for z in range(40):
                    tested += 1
                    result = simulate_and_test(w, x, y, z, target_dcba, seq_len)
                    if result is not None:
                        solutions.append({
                            "theme": [w, x, y, z],
                            "interval": result,
                        })
                        theme_labels = [SOURCE_LABELS[p] for p in [w, x, y, z]]
                        print(f"  FOUND: Theme {theme_labels}")
                        for b in range(4):
                            labels = [SOURCE_LABELS[p] for p in result[b]]
                            print(f"    Interval {'ABCD'[b]}: {labels}")
                        print()
                        sys.stdout.flush()

        elapsed = time.time() - start_time
        rate = tested / elapsed if elapsed > 0 else 0
        eta = (2560000 - tested) / rate if rate > 0 else 0
        print(
            f"  W={w:2d} | {tested/2560000*100:.1f}% | "
            f"{rate:.0f}/s | ETA {eta:.0f}s | "
            f"solutions: {len(solutions)}"
        )
        sys.stdout.flush()

    elapsed = time.time() - start_time
    print(f"\nSearch complete in {elapsed:.1f}s")
    print(f"Found {len(solutions)} solution(s).")

    if solutions:
        print("\n" + "=" * 60)
        for i, sol in enumerate(solutions[:20]):
            theme_labels = [SOURCE_LABELS[p] for p in sol["theme"]]
            print(f"\nSolution {i+1}:")
            print(f"  Theme [W X Y Z]: {theme_labels}")
            for bit in range(4):
                labels = [SOURCE_LABELS[p] for p in sol["interval"][bit]]
                print(f"  Interval {'ABCD'[bit]}: {labels}")
        if len(solutions) > 20:
            print(f"\n  ... and {len(solutions) - 20} more")
        print("\n" + "=" * 60)
        print("\nTo use in SuperCollider:")
        sol = solutions[0]
        sliders = [sol["interval"][b][0] for b in range(4)] + sol["theme"]
        print(f"  muse.sliders_({sliders});")


if __name__ == "__main__":
    main()
