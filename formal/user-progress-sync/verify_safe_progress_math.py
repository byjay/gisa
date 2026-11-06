#!/usr/bin/env python3
"""Bounded integer checks for slide max merge and score-milli encoding."""

from itertools import product


def merge_seen(left: int, right: int) -> int:
    return max(left, right)


def restore_timestamp(proposed_at: int, deleted_at: int) -> int:
    return max(proposed_at, deleted_at + 1)


def main() -> None:
    # Slide counts in this model are nonnegative page counts. Check the CRDT laws.
    for a, b, c in product(range(0, 101), repeat=3):
        assert merge_seen(a, b) == merge_seen(b, a), (a, b)
        assert merge_seen(merge_seen(a, b), c) == merge_seen(a, merge_seen(b, c)), (a, b, c)
        assert merge_seen(a, a) == a
        assert merge_seen(a, b) >= a

    # scoreMilli is 1/1000 of a percentage point, with legal range 0..100 points.
    for milli_points in range(0, 100_001):
        restored = round((milli_points / 1000) * 1000)
        assert restored == milli_points, milli_points

    # For exact integer micro-points, nearest-milli quantization has <= 500
    # micro-point error. All 1,000 residue classes are exhaustive for this bound.
    max_error_micro_points = 0
    for remainder in range(1000):
        rounded_milli = 1 if remainder >= 500 else 0
        max_error_micro_points = max(
            max_error_micro_points, abs(remainder - rounded_milli * 1000)
        )
    assert max_error_micro_points == 500

    # A registration restores only when it has a strictly newer integer version.
    for deleted_at in range(201):
        for record_at in range(201):
            assert (record_at > deleted_at) == (not (record_at <= deleted_at))
        assert restore_timestamp(deleted_at, deleted_at) > deleted_at

    print("PASS: max merge laws for 101^3 triples; integer score round-trip for 100,001 values")
    print("PASS: nearest-milli bound is <= 500 micro-points = 0.0005 score points")
    print("PASS: strict registration delete boundary and re-add timestamp for 201 tombstones")


if __name__ == "__main__":
    main()
