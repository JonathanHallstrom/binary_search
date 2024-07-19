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
const alexandrescuLowerBound = lib.alexandrescuLowerBound;
const alexandrescuUpperBound = lib.alexandrescuUpperBound;

test {
    _ = @import("test.zig");
}

inline fn moveToCache(comptime T: type, slice: []const T) void {
    for (slice) |*e| @prefetch(e, .{});
}

// higher takes longer
const search_work_per_iteration = 1 << 16;

// higher grows slower
const growth_factor = 400;

fn nextSize(size: usize) usize {
    return (size * (growth_factor + 1) + growth_factor - 1) / growth_factor;
}

const num_functions = 14;

fn estimateWorkFromSize(size: usize) usize {
    return std.math.log10_int(size) * size + search_work_per_iteration * num_functions;
}

fn simpleDurationFmt(ns: usize) [14]u8 {
    var res: [14]u8 = undefined;
    const milliseconds = ns / std.time.ns_per_ms % 1000;
    const seconds = ns / std.time.ns_per_s % 60;
    const minutes = ns / std.time.ns_per_min % 60;
    const hours = ns / std.time.ns_per_hour % 100;

    _ = std.fmt.bufPrint(&res, "{d:0>2}h{d:0>2}m{d:0>2}s{d:0>3}ms", .{ hours, minutes, seconds, milliseconds }) catch undefined;
    return res;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = std.heap.raw_c_allocator;
    var rng = std.Random.Pcg.init(0);
    var rand = rng.random();
    const Tp = u64;

    var absolute_timings = try std.fs.cwd().createFile("absolute.csv", .{});
    defer absolute_timings.close();

    var relative_timings = try std.fs.cwd().createFile("relative.csv", .{});
    defer relative_timings.close();

    // labels
    try absolute_timings.writer().print("size,old,branchy,branchless,prefetch,careful,lowerBound,upperBound,equalRange,improvedLowerBound,improvedUpperBound,improvedEqualRange,alexandrescuLowerBound,alexandrescuUpperBound\n", .{});
    try relative_timings.writer().print("size,old,branchy,branchless,prefetch,careful,lowerBound,upperBound,equalRange,improvedLowerBound,improvedUpperBound,improvedEqualRange,alexandrescuLowerBound,alexandrescuUpperBound\n", .{});

    comptime var tmp_size = 1;
    comptime var num_lines = 0;
    comptime var total_work = 0;

    const start = try std.time.Instant.now();
    @setEvalBranchQuota(1 << 30);
    inline while (tmp_size < 1 << 24) {
        defer tmp_size = comptime nextSize(tmp_size);
        num_lines += 1;
        total_work += comptime estimateWorkFromSize(tmp_size);
    }
    var size: usize = 1;
    var lines_printed: usize = 0;
    var work_done: usize = 0;
    var array = std.ArrayList(Tp).init(alloc);
    var key_list = std.ArrayList(Tp).init(alloc);
    while (size < 1 << 24) {
        defer size = nextSize(size);
        while (array.items.len < size) {
            try array.append(rand.int(Tp));
        }
        const a = array.items;

        std.sort.pdq(Tp, a, void{}, std.sort.asc(Tp));

        const iteration_count: u32 = @as(u32, search_work_per_iteration) / std.math.log2_int_ceil(usize, size + 1);

        try key_list.resize(iteration_count);
        const keys = key_list.items;
        for (keys) |*key| key.* = rand.int(Tp);

        moveToCache(Tp, a);
        moveToCache(Tp, keys);
        const old_start = try std.time.Instant.now();
        for (keys) |key| {
            const found = oldBinarySearch(Tp, key, a, void{}, ascending(Tp));
            std.mem.doNotOptimizeAway(found);
        }
        const old_time = @as(f64, @floatFromInt((try std.time.Instant.now()).since(old_start) + iteration_count - 1)) / @as(f64, @floatFromInt(iteration_count));

        moveToCache(Tp, a);
        moveToCache(Tp, keys);
        const branchless_start = try std.time.Instant.now();
        for (keys) |key| {
            const found = branchlessBinarySearch(Tp, key, a, void{}, ascending(Tp));
            std.mem.doNotOptimizeAway(found);
        }
        const branchless_time = @as(f64, @floatFromInt((try std.time.Instant.now()).since(branchless_start) + iteration_count - 1)) / @as(f64, @floatFromInt(iteration_count));

        moveToCache(Tp, a);
        moveToCache(Tp, keys);
        const branchy_start = try std.time.Instant.now();
        for (keys) |key| {
            const found = brancyBinarySearch(Tp, key, a, void{}, ascending(Tp));
            std.mem.doNotOptimizeAway(found);
        }
        const branchy_time = @as(f64, @floatFromInt((try std.time.Instant.now()).since(branchy_start) + iteration_count - 1)) / @as(f64, @floatFromInt(iteration_count));

        moveToCache(Tp, a);
        moveToCache(Tp, keys);
        const prefetch_start = try std.time.Instant.now();
        for (keys) |key| {
            const found = prefetchBranchlessBinarySearch(Tp, key, a, void{}, ascending(Tp));
            std.mem.doNotOptimizeAway(found);
        }
        const prefetch_time = @as(f64, @floatFromInt((try std.time.Instant.now()).since(prefetch_start) + iteration_count - 1)) / @as(f64, @floatFromInt(iteration_count));

        moveToCache(Tp, a);
        moveToCache(Tp, keys);
        const careful_prefetch_start = try std.time.Instant.now();
        for (keys) |key| {
            const found = carefulPrefetchBranchlessBinarySearch(Tp, key, a, void{}, ascending(Tp));
            std.mem.doNotOptimizeAway(found);
        }
        const careful_prefetch_time = @as(f64, @floatFromInt((try std.time.Instant.now()).since(careful_prefetch_start) + iteration_count - 1)) / @as(f64, @floatFromInt(iteration_count));

        moveToCache(Tp, a);
        moveToCache(Tp, keys);
        const lower_bound_start = try std.time.Instant.now();
        for (keys) |key| {
            const found = std.sort.lowerBound(Tp, key, a, void{}, std.sort.asc(Tp));
            std.mem.doNotOptimizeAway(found);
        }
        const lower_bound_time = @as(f64, @floatFromInt((try std.time.Instant.now()).since(lower_bound_start) + iteration_count - 1)) / @as(f64, @floatFromInt(iteration_count));

        moveToCache(Tp, a);
        moveToCache(Tp, keys);
        const upper_bound_start = try std.time.Instant.now();
        for (keys) |key| {
            const found = std.sort.lowerBound(Tp, key, a, void{}, std.sort.asc(Tp));
            std.mem.doNotOptimizeAway(found);
        }
        const upper_bound_time = @as(f64, @floatFromInt((try std.time.Instant.now()).since(upper_bound_start) + iteration_count - 1)) / @as(f64, @floatFromInt(iteration_count));

        moveToCache(Tp, a);
        moveToCache(Tp, keys);
        const equal_range_start = try std.time.Instant.now();
        for (keys) |key| {
            const found = std.sort.equalRange(Tp, key, a, void{}, std.sort.asc(Tp));
            std.mem.doNotOptimizeAway(found);
        }
        const equal_range_time = @as(f64, @floatFromInt((try std.time.Instant.now()).since(equal_range_start) + iteration_count - 1)) / @as(f64, @floatFromInt(iteration_count));

        moveToCache(Tp, a);
        moveToCache(Tp, keys);
        const improved_lower_bound_start = try std.time.Instant.now();
        for (keys) |key| {
            const found = improvedLowerBound(Tp, key, a, void{}, std.sort.asc(Tp));
            std.mem.doNotOptimizeAway(found);
        }
        const improved_lower_bound_time = @as(f64, @floatFromInt((try std.time.Instant.now()).since(improved_lower_bound_start) + iteration_count - 1)) / @as(f64, @floatFromInt(iteration_count));

        moveToCache(Tp, a);
        moveToCache(Tp, keys);
        const improved_upper_bound_start = try std.time.Instant.now();
        for (keys) |key| {
            const found = improvedUpperBound(Tp, key, a, void{}, std.sort.asc(Tp));
            std.mem.doNotOptimizeAway(found);
        }
        const improved_upper_bound_time = @as(f64, @floatFromInt((try std.time.Instant.now()).since(improved_upper_bound_start) + iteration_count - 1)) / @as(f64, @floatFromInt(iteration_count));

        moveToCache(Tp, a);
        moveToCache(Tp, keys);
        const improved_equal_range_start = try std.time.Instant.now();
        for (keys) |key| {
            const found = improvedEqualRange(Tp, key, a, void{}, std.sort.asc(Tp));
            std.mem.doNotOptimizeAway(found);
        }
        const improved_equal_range_time = @as(f64, @floatFromInt((try std.time.Instant.now()).since(improved_equal_range_start) + iteration_count - 1)) / @as(f64, @floatFromInt(iteration_count));

        moveToCache(Tp, a);
        moveToCache(Tp, keys);

        const alexandrescu_lower_bound_start = try std.time.Instant.now();
        for (keys) |key| {
            const found = alexandrescuLowerBound(Tp, key, a, void{}, std.sort.asc(Tp));
            std.mem.doNotOptimizeAway(found);
        }
        const alexandrescu_lower_bound_time = @as(f64, @floatFromInt((try std.time.Instant.now()).since(alexandrescu_lower_bound_start) + iteration_count - 1)) / @as(f64, @floatFromInt(iteration_count));

        moveToCache(Tp, a);
        moveToCache(Tp, keys);
        const alexandrescu_upper_bound_start = try std.time.Instant.now();
        for (keys) |key| {
            const found = alexandrescuUpperBound(Tp, key, a, void{}, std.sort.asc(Tp));
            std.mem.doNotOptimizeAway(found);
        }
        const alexandrescu_upper_bound_time = @as(f64, @floatFromInt((try std.time.Instant.now()).since(alexandrescu_upper_bound_start) + iteration_count - 1)) / @as(f64, @floatFromInt(iteration_count));

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
            const alexandrescu_lower_bound = alexandrescuLowerBound(Tp, key, a, void{}, std.sort.asc(Tp));
            const alexandrescu_upper_bound = alexandrescuUpperBound(Tp, key, a, void{}, std.sort.asc(Tp));

            try std.testing.expectEqual(equal_range, improved_equal_range);
            try std.testing.expectEqual(lower_bound, improved_lower_bound);
            try std.testing.expectEqual(upper_bound, improved_upper_bound);
            try std.testing.expectEqual(lower_bound, alexandrescu_lower_bound);
            try std.testing.expectEqual(upper_bound, alexandrescu_upper_bound);
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
            const alexandrescu_lower_bound_val = if (alexandrescu_lower_bound < a.len and a[alexandrescu_lower_bound] == key) a[alexandrescu_lower_bound] else null;

            try std.testing.expectEqual(old_val, branchy_val);
            try std.testing.expectEqual(old_val, branchless_val);
            try std.testing.expectEqual(old_val, prefetch_val);
            try std.testing.expectEqual(old_val, careful_prefetch_val);
            try std.testing.expectEqual(old_val, lower_bound_val);
            try std.testing.expectEqual(old_val, equal_range_val);
            try std.testing.expectEqual(old_val, improved_lower_bound_val);
            try std.testing.expectEqual(old_val, improved_equal_range_val);
            try std.testing.expectEqual(old_val, alexandrescu_lower_bound_val);
        }

        try absolute_timings.writer().print("{d},{d:.4},{d:.4},{d:.4},{d:.4},{d:.4},{d:.4},{d:.4},{d:.4},{d:.4},{d:.4},{d:.4},{d:.4},{d:.4}\n", .{
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
            alexandrescu_lower_bound_time,
            alexandrescu_upper_bound_time,
        });

        try relative_timings.writer().print("{d},{d:.4},{d:.4},{d:.4},{d:.4},{d:.4},{d:.4},{d:.4},{d:.4},{d:.4},{d:.4},{d:.4},{d:.4},{d:.4}\n", .{
            size * @sizeOf(Tp),
            old_time / old_time,
            branchy_time / old_time,
            branchless_time / old_time,
            prefetch_time / old_time,
            careful_prefetch_time / old_time,
            lower_bound_time / old_time,
            upper_bound_time / old_time,
            equal_range_time / old_time,
            improved_lower_bound_time / old_time,
            improved_upper_bound_time / old_time,
            improved_equal_range_time / old_time,
            alexandrescu_lower_bound_time / old_time,
            alexandrescu_upper_bound_time / old_time,
        });
        lines_printed += 1;

        work_done += estimateWorkFromSize(size);
        const percent = (100 * work_done) / total_work;
        const percentf = (100.0 * @as(f64, @floatFromInt(work_done))) / total_work;
        const now = try std.time.Instant.now();
        const elapsed_ns = now.since(start);
        const estimated_total: u64 = @intFromFloat(@as(f64, @floatFromInt(elapsed_ns)) * 100 / @max(1, percentf));
        const estimated_remaining_ns: u64 = estimated_total - elapsed_ns;

        const step_digits = std.fmt.comptimePrint("{}", .{num_lines}).len;
        const step_digits_str = std.fmt.comptimePrint("{}", .{step_digits});
        if (percentf > 0.01) {
            var buf: [1024]u8 = undefined;

            // first print to local buffer so theres no flickering
            const to_print = try std.fmt.bufPrint(&buf, "\rProgress: {d:3}% ({d:" ++ step_digits_str ++ "}/{} steps) Elapsed: {s} Remaining: {s} Total: {s}", .{
                percent,
                lines_printed,
                num_lines,
                simpleDurationFmt(elapsed_ns),
                simpleDurationFmt(estimated_remaining_ns),
                simpleDurationFmt(estimated_total),
            });

            std.debug.print("{s}", .{to_print});
        }
    }
    std.debug.print("\n", .{});
}
