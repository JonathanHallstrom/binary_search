const std = @import("std");

inline fn clflush(comptime T: type, slice: []const T) void {
    for (0..slice.len / @sizeOf(T)) |chunk| {
        const offset = slice.ptr + (chunk * @sizeOf(T));
        asm volatile ("clflush %[ptr]"
            :
            : [ptr] "m" (offset),
            : "memory"
        );
    }
}

fn ascending(T: type) fn (void, T, T) std.math.Order {
    return struct {
        fn impl(_: void, lhs: T, rhs: T) std.math.Order {
            return std.math.order(lhs, rhs);
        }
    }.impl;
}

pub fn old_binarySearch(
    comptime T: type,
    key: anytype,
    items: []const T,
    context: anytype,
    comptime compareFn: fn (context: @TypeOf(context), key: @TypeOf(key), mid_item: T) std.math.Order,
) ?usize {
    var left: usize = 0;
    var right: usize = items.len;

    while (left < right) {
        // Avoid overflowing in the midpoint calculation
        const mid = left + (right - left) / 2;
        // Compare the key with the midpoint element
        switch (compareFn(context, key, items[mid])) {
            .eq => return mid,
            .gt => left = mid + 1,
            .lt => right = mid,
        }
    }

    return null;
}

pub fn new_binarySearch(
    comptime T: type,
    key: anytype,
    items: []const T,
    context: anytype,
    comptime compareFn: fn (context: @TypeOf(context), key: @TypeOf(key), mid_item: T) std.math.Order,
) ?usize {
    var it: usize = 0;
    var len: usize = items.len;
    const four_cache_lines = 256;
    const prefetch_limit = four_cache_lines / @sizeOf(T);
    if (prefetch_limit > 1) {
        while (len > prefetch_limit) {
            const half: usize = len / 2;
            len -= half;
            @prefetch(items.ptr + it + len / 2 + 1, .{});
            @prefetch(items.ptr + it + half + len / 2 + 1, .{});
            it += ([_]usize{ 0, half })[@intFromBool(compareFn(context, key, items[it + half - 1]) == .gt)];
        }
    }
    while (len > 1) {
        const half: usize = len / 2;
        len -= half;
        it += ([_]usize{ 0, half })[@intFromBool(compareFn(context, key, items[it + half - 1]) == .gt)];
    }
    return if (compareFn(context, key, items[it]) == .eq) it else null;
}

pub fn main() !void {
    var size: usize = 1;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var alloc = gpa.allocator();
    var rng = std.Random.DefaultPrng.init(0);
    var rand = rng.random();
    const Tp = i32;

    // higher grows slower
    const incr = 100;
    while (size < 1 << 24) {
        const a = try alloc.alloc(Tp, size);
        defer alloc.free(a);
        for (a) |*e| e.* = rand.int(Tp);

        std.mem.sort(Tp, a, void{}, std.sort.asc(Tp));

        const iteration_count: u64 = 1024;

        const keys = try alloc.alloc(Tp, iteration_count);
        defer alloc.free(keys);
        for (keys) |*key| key.* = rand.int(Tp);

        const t1 = try std.time.Instant.now();
        clflush(Tp, a);
        for (keys) |key| {
            const found = new_binarySearch(Tp, key, a, void{}, ascending(Tp));
            std.mem.doNotOptimizeAway(found);
        }
        const t2 = try std.time.Instant.now();
        clflush(Tp, a);
        for (keys) |key| {
            const found = old_binarySearch(Tp, key, a, void{}, ascending(Tp));
            std.mem.doNotOptimizeAway(found);
        }
        const t3 = try std.time.Instant.now();

        // make sure it works
        for (keys) |key| {
            const old_res = old_binarySearch(Tp, key, a, void{}, ascending(Tp));
            const new_res = new_binarySearch(Tp, key, a, void{}, ascending(Tp));

            if ((old_res == null) != (new_res == null)) {
                @panic("bug");
            } else if (a[old_res orelse 0] != a[new_res orelse 0]) {
                @panic("bug");
            }
        }

        const first_time = (t2.since(t1) + iteration_count - 1) / iteration_count;
        const second_time = (t3.since(t2) + iteration_count - 1) / iteration_count;

        // std.debug.print("{d:.2} {d:.2}\n", .{ std.fmt.fmtDuration(first_time), std.fmt.fmtDuration(second_time) });
        try std.io.getStdOut().writer().print("{d},{d},{d}\n", .{ size * @sizeOf(Tp), first_time, second_time });
        size = (size * incr + incr - 2) / (incr - 1);
    }
}

// tests from standard library
const testing = std.testing;
const math = std.math;

test new_binarySearch {
    const S = struct {
        fn order_u32(context: void, lhs: u32, rhs: u32) math.Order {
            _ = context;
            return math.order(lhs, rhs);
        }
        fn order_i32(context: void, lhs: i32, rhs: i32) math.Order {
            _ = context;
            return math.order(lhs, rhs);
        }
    };
    try testing.expectEqual(
        @as(?usize, null),
        new_binarySearch(u32, @as(u32, 1), &[_]u32{}, {}, S.order_u32),
    );
    try testing.expectEqual(
        @as(?usize, 0),
        new_binarySearch(u32, @as(u32, 1), &[_]u32{1}, {}, S.order_u32),
    );
    try testing.expectEqual(
        @as(?usize, null),
        new_binarySearch(u32, @as(u32, 1), &[_]u32{0}, {}, S.order_u32),
    );
    try testing.expectEqual(
        @as(?usize, null),
        new_binarySearch(u32, @as(u32, 0), &[_]u32{1}, {}, S.order_u32),
    );
    try testing.expectEqual(
        @as(?usize, 4),
        new_binarySearch(u32, @as(u32, 5), &[_]u32{ 1, 2, 3, 4, 5 }, {}, S.order_u32),
    );
    try testing.expectEqual(
        @as(?usize, 0),
        new_binarySearch(u32, @as(u32, 2), &[_]u32{ 2, 4, 8, 16, 32, 64 }, {}, S.order_u32),
    );
    try testing.expectEqual(
        @as(?usize, 1),
        new_binarySearch(i32, @as(i32, -4), &[_]i32{ -7, -4, 0, 9, 10 }, {}, S.order_i32),
    );
    try testing.expectEqual(
        @as(?usize, 3),
        new_binarySearch(i32, @as(i32, 98), &[_]i32{ -100, -25, 2, 98, 99, 100 }, {}, S.order_i32),
    );
    const R = struct {
        b: i32,
        e: i32,

        fn r(b: i32, e: i32) @This() {
            return @This(){ .b = b, .e = e };
        }

        fn order(context: void, key: i32, mid_item: @This()) math.Order {
            _ = context;

            if (key < mid_item.b) {
                return .lt;
            }

            if (key > mid_item.e) {
                return .gt;
            }

            return .eq;
        }
    };
    try testing.expectEqual(
        @as(?usize, null),
        new_binarySearch(R, @as(i32, -45), &[_]R{ R.r(-100, -50), R.r(-40, -20), R.r(-10, 20), R.r(30, 40) }, {}, R.order),
    );
    try testing.expectEqual(
        @as(?usize, 2),
        new_binarySearch(R, @as(i32, 10), &[_]R{ R.r(-100, -50), R.r(-40, -20), R.r(-10, 20), R.r(30, 40) }, {}, R.order),
    );
    try testing.expectEqual(
        @as(?usize, 1),
        new_binarySearch(R, @as(i32, -20), &[_]R{ R.r(-100, -50), R.r(-40, -20), R.r(-10, 20), R.r(30, 40) }, {}, R.order),
    );
}
