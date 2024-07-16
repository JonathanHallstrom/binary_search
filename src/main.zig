const std = @import("std");
const lib = @import("lib.zig");
const ascending = lib.ascending;
const oldBinarySearch = lib.oldBinarySearch;
const brancyBinarySearch = lib.branchyBinarySearch;
const branchlessBinarySearch = lib.branchlessBinarySearch;
const prefetchBranchlessBinarySearch = lib.prefetchBranchlessBinarySearch;
const carefulPrefetchBranchlessBinarySearch = lib.carefulPrefetchBranchlessBinarySearch;
const improvedLowerBound = lib.improvedLowerBound;
const improvedUpperBound = lib.improvedUpperBound;
const improvedEqualRange = lib.improvedEqualRange;

test {
    _ = @import("test.zig");
}

inline fn moveToCache(comptime T: type, slice: []const T) void {
    for (slice) |*e| @prefetch(e, .{});
}

pub fn main() !void {
    var size: usize = 1;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var alloc = gpa.allocator();
    var rng = std.Random.DefaultPrng.init(0);
    var rand = rng.random();
    const Tp = u64;

    var absolute_timings = try std.fs.cwd().createFile("absolute.csv", .{});
    defer absolute_timings.close();

    var relative_timings = try std.fs.cwd().createFile("relative.csv", .{});
    defer relative_timings.close();

    // higher grows slower
    const incr = 200;

    // labels
    try absolute_timings.writer().print("size,old,branchy,branchless,prefetch,careful,lowerBound,upperBound,equalRange,improvedLowerBound,improvedUpperBound,improvedEqualRange\n", .{});
    try relative_timings.writer().print("size,old,branchy,branchless,prefetch,careful,lowerBound,upperBound,equalRange,improvedLowerBound,improvedUpperBound,improvedEqualRange\n", .{});
    while (size < 1 << 24) {
        const a = try alloc.alloc(Tp, size);
        defer alloc.free(a);
        for (a) |*e| e.* = rand.int(Tp);

        std.sort.pdq(Tp, a, void{}, std.sort.asc(Tp));
        const iteration_count: u64 = 1 << 10;

        const keys = try alloc.alloc(Tp, iteration_count);
        defer alloc.free(keys);
        for (keys) |*key| key.* = rand.int(Tp);

        moveToCache(Tp, a);
        moveToCache(Tp, keys);
        const old_start = try std.time.Instant.now();
        for (keys) |key| {
            const found = oldBinarySearch(Tp, key, a, void{}, ascending(Tp));
            std.mem.doNotOptimizeAway(found);
        }
        const old_time = ((try std.time.Instant.now()).since(old_start) + iteration_count - 1) / iteration_count;

        moveToCache(Tp, a);
        moveToCache(Tp, keys);
        const branchless_start = try std.time.Instant.now();
        for (keys) |key| {
            const found = branchlessBinarySearch(Tp, key, a, void{}, ascending(Tp));
            std.mem.doNotOptimizeAway(found);
        }
        const branchless_time = ((try std.time.Instant.now()).since(branchless_start) + iteration_count - 1) / iteration_count;

        moveToCache(Tp, a);
        moveToCache(Tp, keys);
        const branchy_start = try std.time.Instant.now();
        for (keys) |key| {
            const found = brancyBinarySearch(Tp, key, a, void{}, ascending(Tp));
            std.mem.doNotOptimizeAway(found);
        }
        const branchy_time = ((try std.time.Instant.now()).since(branchy_start) + iteration_count - 1) / iteration_count;

        moveToCache(Tp, a);
        moveToCache(Tp, keys);
        const prefetch_start = try std.time.Instant.now();
        for (keys) |key| {
            const found = prefetchBranchlessBinarySearch(Tp, key, a, void{}, ascending(Tp));
            std.mem.doNotOptimizeAway(found);
        }
        const prefetch_time = ((try std.time.Instant.now()).since(prefetch_start) + iteration_count - 1) / iteration_count;

        moveToCache(Tp, a);
        moveToCache(Tp, keys);
        const careful_prefetch_start = try std.time.Instant.now();
        for (keys) |key| {
            const found = carefulPrefetchBranchlessBinarySearch(Tp, key, a, void{}, ascending(Tp));
            std.mem.doNotOptimizeAway(found);
        }
        const careful_prefetch_time = ((try std.time.Instant.now()).since(careful_prefetch_start) + iteration_count - 1) / iteration_count;

        moveToCache(Tp, a);
        moveToCache(Tp, keys);
        const lower_bound_start = try std.time.Instant.now();
        for (keys) |key| {
            const found = std.sort.lowerBound(Tp, key, a, void{}, std.sort.asc(Tp));
            std.mem.doNotOptimizeAway(found);
        }
        const lower_bound_time = ((try std.time.Instant.now()).since(lower_bound_start) + iteration_count - 1) / iteration_count;

        moveToCache(Tp, a);
        moveToCache(Tp, keys);
        const upper_bound_start = try std.time.Instant.now();
        for (keys) |key| {
            const found = std.sort.lowerBound(Tp, key, a, void{}, std.sort.asc(Tp));
            std.mem.doNotOptimizeAway(found);
        }
        const upper_bound_time = ((try std.time.Instant.now()).since(upper_bound_start) + iteration_count - 1) / iteration_count;

        moveToCache(Tp, a);
        moveToCache(Tp, keys);
        const equal_range_start = try std.time.Instant.now();
        for (keys) |key| {
            const found = std.sort.equalRange(Tp, key, a, void{}, std.sort.asc(Tp));
            std.mem.doNotOptimizeAway(found);
        }
        const equal_range_time = ((try std.time.Instant.now()).since(equal_range_start) + iteration_count - 1) / iteration_count;

        moveToCache(Tp, a);
        moveToCache(Tp, keys);
        const improved_lower_bound_start = try std.time.Instant.now();
        for (keys) |key| {
            const found = improvedLowerBound(Tp, key, a, void{}, std.sort.asc(Tp));
            std.mem.doNotOptimizeAway(found);
        }
        const improved_lower_bound_time = ((try std.time.Instant.now()).since(improved_lower_bound_start) + iteration_count - 1) / iteration_count;

        moveToCache(Tp, a);
        moveToCache(Tp, keys);
        const improved_upper_bound_start = try std.time.Instant.now();
        for (keys) |key| {
            const found = improvedUpperBound(Tp, key, a, void{}, std.sort.asc(Tp));
            std.mem.doNotOptimizeAway(found);
        }
        const improved_upper_bound_time = ((try std.time.Instant.now()).since(improved_upper_bound_start) + iteration_count - 1) / iteration_count;

        moveToCache(Tp, a);
        moveToCache(Tp, keys);
        const improved_equal_range_start = try std.time.Instant.now();
        for (keys) |key| {
            const found = improvedEqualRange(Tp, key, a, void{}, std.sort.asc(Tp));
            std.mem.doNotOptimizeAway(found);
        }
        const improved_equal_range_time = ((try std.time.Instant.now()).since(improved_equal_range_start) + iteration_count - 1) / iteration_count;

        // make sure it works
        for (keys) |key| {
            const old = oldBinarySearch(Tp, key, a, void{}, ascending(Tp));
            const branchy = brancyBinarySearch(Tp, key, a, void{}, ascending(Tp));
            const branchless = branchlessBinarySearch(Tp, key, a, void{}, ascending(Tp));
            const prefetch = prefetchBranchlessBinarySearch(Tp, key, a, void{}, ascending(Tp));
            const careful_prefetch = carefulPrefetchBranchlessBinarySearch(Tp, key, a, void{}, ascending(Tp));
            const lower_bound = std.sort.lowerBound(Tp, key, a, void{}, std.sort.asc(Tp));
            const upper_bound = std.sort.upperBound(Tp, key, a, void{}, std.sort.asc(Tp));
            const equal_range = std.sort.equalRange(Tp, key, a, void{}, std.sort.asc(Tp));
            const improved_lower_bound = improvedLowerBound(Tp, key, a, void{}, std.sort.asc(Tp));
            const improved_upper_bound = improvedUpperBound(Tp, key, a, void{}, std.sort.asc(Tp));
            const improved_equal_range = improvedEqualRange(Tp, key, a, void{}, std.sort.asc(Tp));

            try std.testing.expectEqual(equal_range, improved_equal_range);
            try std.testing.expectEqual(lower_bound, improved_lower_bound);
            try std.testing.expectEqual(upper_bound, improved_upper_bound);
            try std.testing.expectEqual(equal_range.@"0", improved_lower_bound);
            try std.testing.expectEqual(equal_range.@"1", improved_upper_bound);

            const old_val = if (old) |i| a[i] else null;
            const branchy_val = if (branchy) |i| a[i] else null;
            const branchless_val = if (branchless) |i| a[i] else null;
            const prefetch_val = if (prefetch) |i| a[i] else null;
            const careful_prefetch_val = if (careful_prefetch) |i| a[i] else null;
            const lower_bound_val = if (lower_bound < a.len and a[lower_bound] == key) a[lower_bound] else null;
            const equal_range_val = if (equal_range.@"0" < a.len and a[equal_range.@"0"] == key) a[equal_range.@"0"] else null;
            const improved_lower_bound_val = if (improved_lower_bound < a.len and a[improved_lower_bound] == key) a[improved_lower_bound] else null;
            const improved_equal_range_val = if (improved_equal_range.@"0" < a.len and a[improved_equal_range.@"0"] == key) a[improved_equal_range.@"0"] else null;

            try std.testing.expectEqual(old_val, branchy_val);
            try std.testing.expectEqual(old_val, branchless_val);
            try std.testing.expectEqual(old_val, prefetch_val);
            try std.testing.expectEqual(old_val, careful_prefetch_val);
            try std.testing.expectEqual(old_val, lower_bound_val);
            try std.testing.expectEqual(old_val, equal_range_val);
            try std.testing.expectEqual(old_val, improved_lower_bound_val);
            try std.testing.expectEqual(old_val, improved_equal_range_val);
        }

        // std.debug.print("{d:.2} {d:.2}\n", .{ std.fmt.fmtDuration(first_time), std.fmt.fmtDuration(second_time) });
        try absolute_timings.writer().print("{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d}\n", .{
            size * @sizeOf(Tp),
            old_time,
            branchy_time,
            branchless_time,
            prefetch_time,
            careful_prefetch_time,
            lower_bound_time,
            upper_bound_time,
            equal_range_time,
            improved_lower_bound_time,
            improved_upper_bound_time,
            improved_equal_range_time,
        });

        try relative_timings.writer().print("{d},{d:.4},{d:.4},{d:.4},{d:.4},{d:.4},{d:.4},{d:.4},{d:.4},{d:.4},{d:.4},{d:.4}\n", .{
            size * @sizeOf(Tp),
            @as(f64, @floatFromInt(old_time)) / @as(f64, @floatFromInt(old_time)),
            @as(f64, @floatFromInt(branchy_time)) / @as(f64, @floatFromInt(old_time)),
            @as(f64, @floatFromInt(branchless_time)) / @as(f64, @floatFromInt(old_time)),
            @as(f64, @floatFromInt(prefetch_time)) / @as(f64, @floatFromInt(old_time)),
            @as(f64, @floatFromInt(careful_prefetch_time)) / @as(f64, @floatFromInt(old_time)),
            @as(f64, @floatFromInt(lower_bound_time)) / @as(f64, @floatFromInt(old_time)),
            @as(f64, @floatFromInt(upper_bound_time)) / @as(f64, @floatFromInt(old_time)),
            @as(f64, @floatFromInt(equal_range_time)) / @as(f64, @floatFromInt(old_time)),
            @as(f64, @floatFromInt(improved_lower_bound_time)) / @as(f64, @floatFromInt(old_time)),
            @as(f64, @floatFromInt(improved_upper_bound_time)) / @as(f64, @floatFromInt(old_time)),
            @as(f64, @floatFromInt(improved_equal_range_time)) / @as(f64, @floatFromInt(old_time)),
        });
        size = (size * incr + incr - 2) / (incr - 1);
    }
}
