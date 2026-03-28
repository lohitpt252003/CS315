# External Quicksort Assignment
**Course: CS315**

## Overview
This is my implementation for the external quicksort assignment. It sorts a really large list of numbers that dont fit into the main memory all at once. The code simulates how a real hard drive would work by keeping track of the disk blocks and counting every time we have to do a disk seek or transfer.

I wrote the code in C++ because its fast, and I used a custom `DiskSim` class instead of making a bunch of real files on the OS, which is way easier to test and count perfectly.

---

## How it works

### The Disk Simulator
The `DiskSim` class acts like the real disk. Instead of writing to actual files, it just uses a c++ `unordered_map` where the key is the block ID and the value is a vector of numbers. Every time the code calls `read()` or `write()`, it adds 1 to the `seeks` counter and 1 to the `transfers` counter. 
Since blocks can only hold a certain number of keys (`b/k`), my simulator packs them in chunks when writing and unpacks them when reading.

### Sorting Algorithm
1. **Load data:** First it reads all the numbers from the text file and writes them into "disk blocks".
2. **Base Case:** If the file we are currently looking at has fewer blocks than our memory limit `m`, we just load the whole thing into RAM, sort it with the standard `std::sort`, and write it back. This is the fastest way.
3. **External Partitioning:** If it is to big for RAM:
   - **Pivot Selection:** I use median-of-three. It reads the first block, the middle block, and the last block, takes the first number from each, and finds the median. This prevents worst-case runtime if the data is already sorted.
   - **Partitioning:** It goes through all the blocks one by one, and splits the numbers into three new files on the disk: one for numbers less than pivot, one for equal, and one for greater. 
   - **Recursion:** It recursively calls `run_sort` on the less-than part and the greater-than part.
   - **Merge:** Finally it takes all three parts, reads them from the old blocks, and writes them back into one continuous sorted sequence on the disk.

---

## Cost Analysis

- **Read 1 block:** 1 seek + 1 transfer
- **Write 1 block:** 1 seek + 1 transfer

During a partition pass on a file with $B$ blocks, it has to:
- Read 3 blocks to find the pivot
- Read all $B$ blocks to partition them
- Write all the numbers back out into the three new partitions (which is roughly $B$ blocks of writes)

So each pass takes about $2B + 3$ seeks and the same number of transfers. The total complexity depends on the pivot, but mainly it's expected to be $O(B \log_m B)$ operations.

---

## Test Run outputs

When I ran it on the example from the assignment:
```bash
make test
```
(10,000 keys, 4 byte size, 1024 byte blocks, 10 memory blocks)

- Total keys per block = 256
- Memory can hold 2560 keys at a time
- It took 4 partition passes
- Total disk seeks = 612
- Total disk transfers = 612
- And my verification check prints "OK" at the end indicating it is fully sorted.

You can run it yourself by using the makefile: `make` to compile then `./external_quicksort input.txt 10000 4 1024 10`.

---
## Files included
- `external_quicksort.cpp`: The main C++ code
- `Makefile`: to compile it easily
- `generate_input.py`: A python script I made to create random numbers for testing
- `writeup.md`: This file.
