const std = @import("std");
const lib = @import("lib.zig");
const ascending = lib.ascending;
const oldBinarySearch = lib.oldBinarySearch;
const branchlessBinarySearch = lib.branchlessBinarySearch;
const prefetchBranchlessBinarySearch = lib.prefetchBranchlessBinarySearch;
const carefulPrefetchBranchlessBinarySearch = lib.carefulPrefetchBranchlessBinarySearch;

test {
    _ = @import("test.zig");
}

inline fn flushFromCache(comptime T: type, slice: []const T) void {
    for (0..slice.len / @sizeOf(T)) |chunk| {
        const offset = slice.ptr + (chunk * @sizeOf(T));
        asm volatile ("clflush %[ptr]"
            :
            : [ptr] "m" (offset),
            : "memory"
        );
    }
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
    const Tp = i32;

    var absolute_timings = try std.fs.cwd().createFile("absolute.csv", .{});
    defer absolute_timings.close();

    var relative_timings = try std.fs.cwd().createFile("relative.csv", .{});
    defer relative_timings.close();

    // higher grows slower
    const incr = 100;
    while (size < 1 << 24) {
        const a = try alloc.alloc(Tp, size);
        defer alloc.free(a);
        for (a) |*e| e.* = rand.int(Tp);

        std.sort.pdq(Tp, a, void{}, std.sort.asc(Tp));
        const iteration_count: u64 = 1 << 12;

        const keys = try alloc.alloc(Tp, iteration_count);
        defer alloc.free(keys);
        for (keys) |*key| key.* = rand.int(Tp);

        flushFromCache(Tp, a);
        moveToCache(Tp, keys);
        const old_start = try std.time.Instant.now();
        for (keys) |key| {
            const found = oldBinarySearch(Tp, key, a, void{}, ascending(Tp));
            std.mem.doNotOptimizeAway(found);
        }
        const old_time = ((try std.time.Instant.now()).since(old_start) + iteration_count - 1) / iteration_count;

        flushFromCache(Tp, a);
        moveToCache(Tp, keys);
        const branchless_start = try std.time.Instant.now();
        for (keys) |key| {
            const found = branchlessBinarySearch(Tp, key, a, void{}, ascending(Tp));
            std.mem.doNotOptimizeAway(found);
        }
        const branchless_time = ((try std.time.Instant.now()).since(branchless_start) + iteration_count - 1) / iteration_count;

        flushFromCache(Tp, a);
        moveToCache(Tp, keys);
        const prefetch_start = try std.time.Instant.now();
        for (keys) |key| {
            const found = prefetchBranchlessBinarySearch(Tp, key, a, void{}, ascending(Tp));
            std.mem.doNotOptimizeAway(found);
        }
        const prefetch_time = ((try std.time.Instant.now()).since(prefetch_start) + iteration_count - 1) / iteration_count;

        flushFromCache(Tp, a);
        moveToCache(Tp, keys);
        const careful_prefetch_start = try std.time.Instant.now();
        for (keys) |key| {
            const found = carefulPrefetchBranchlessBinarySearch(Tp, key, a, void{}, ascending(Tp));
            std.mem.doNotOptimizeAway(found);
        }
        const careful_prefetch_time = ((try std.time.Instant.now()).since(careful_prefetch_start) + iteration_count - 1) / iteration_count;

        // make sure it works
        for (keys) |key| {
            const old = oldBinarySearch(Tp, key, a, void{}, ascending(Tp));
            const branchless = branchlessBinarySearch(Tp, key, a, void{}, ascending(Tp));
            const prefetch = prefetchBranchlessBinarySearch(Tp, key, a, void{}, ascending(Tp));
            const carefulPrefetch = carefulPrefetchBranchlessBinarySearch(Tp, key, a, void{}, ascending(Tp));

            const old_val = if (old) |i| a[i] else null;
            const branchless_val = if (branchless) |i| a[i] else null;
            const prefetch_val = if (prefetch) |i| a[i] else null;
            const careful_prefetch_val = if (carefulPrefetch) |i| a[i] else null;

            try std.testing.expectEqual(old_val, branchless_val);
            try std.testing.expectEqual(old_val, prefetch_val);
            try std.testing.expectEqual(old_val, careful_prefetch_val);
        }

        // std.debug.print("{d:.2} {d:.2}\n", .{ std.fmt.fmtDuration(first_time), std.fmt.fmtDuration(second_time) });
        try absolute_timings.writer().print("{d},{d},{d},{d},{d}\n", .{
            size * @sizeOf(Tp),
            old_time,
            branchless_time,
            prefetch_time,
            careful_prefetch_time,
        });

        try relative_timings.writer().print("{d},{d:.4},{d:.4},{d:.4},{d:.4}\n", .{
            size * @sizeOf(Tp),
            @as(f64, @floatFromInt(old_time)) / @as(f64, @floatFromInt(old_time)),
            @as(f64, @floatFromInt(branchless_time)) / @as(f64, @floatFromInt(old_time)),
            @as(f64, @floatFromInt(prefetch_time)) / @as(f64, @floatFromInt(old_time)),
            @as(f64, @floatFromInt(careful_prefetch_time)) / @as(f64, @floatFromInt(old_time)),
        });
        size = (size * incr + incr - 2) / (incr - 1);
    }
}
