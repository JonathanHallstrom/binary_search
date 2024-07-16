# binary_search

## summary
some benchmarks for a faster binarySearch

benchmarking and plotting heavily inspired by https://gist.github.com/Rexicon226/b533e0f1ec317b873cff691f54e63364

## requirements
zig 0.12+

### tldr
~2-4x speedup for `std.sort.binarySearch`, `std.sort.lowerBound`, `std.sort.upperBound`, `std.sort.equalRange`
