"""Generate random test input files for External Quicksort."""

import random
import sys

def generate_input(n, filename, lo=-100000, hi=100000):
    """Generate n random integer keys in [lo, hi] and write to filename."""
    with open(filename, 'w') as f:
        for _ in range(n):
            f.write(f"{random.randint(lo, hi)}\n")
    print(f"Generated {n} keys in '{filename}' (range [{lo}, {hi}])")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python generate_input.py <num_keys> <output_file>")
        sys.exit(1)
    n = int(sys.argv[1])
    fname = sys.argv[2]
    generate_input(n, fname)
