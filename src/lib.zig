const std = @import("std");

pub fn ascending(T: type) fn (void, T, T) std.math.Order {
    return struct {
        fn impl(_: void, lhs: T, rhs: T) std.math.Order {
            return std.math.order(lhs, rhs);
        }
    }.impl;
}

pub fn oldBinarySearch(
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

inline fn select(predicate: bool, a: anytype, b: anytype) @TypeOf(a, b) {
    const T = @TypeOf(a, b);
    // TODO: simplify this, kinda ugly

    // return @bitCast(@select(T, @as(@Vector(1, bool), @splat(predicate)), @as(@Vector(1, T), @splat(a)), @as(@Vector(1, T), @splat(b))));

    // var res: T = b;
    // if (predicate) res = a;
    // return res;

    return ([2]T{ b, a })[@intFromBool(predicate)];
}

pub fn branchlessBinarySearch(
    comptime T: type,
    key: anytype,
    items: []const T,
    context: anytype,
    comptime compareFn: fn (context: @TypeOf(context), key: @TypeOf(key), mid_item: T) std.math.Order,
) ?usize {
    var it: usize = 0;
    var len: usize = items.len;
    while (len > 1) {
        const half: usize = len / 2;
        len -= half;
        it += select(compareFn(context, key, items[it + half - 1]) == .gt, half, 0);
    }
    return if (compareFn(context, key, items[it]) == .eq) it else null;
}

pub fn prefetchBranchlessBinarySearch(
    comptime T: type,
    key: anytype,
    items: []const T,
    context: anytype,
    comptime compareFn: fn (context: @TypeOf(context), key: @TypeOf(key), mid_item: T) std.math.Order,
) ?usize {
    var it: usize = 0;
    var len: usize = items.len;
    while (len > 1) {
        const half: usize = len / 2;
        len -= half;
        @prefetch(items.ptr + it + len / 2, .{});
        @prefetch(items.ptr + it + len, .{});
        it += select(compareFn(context, key, items[it + half - 1]) == .gt, half, 0);
    }
    return if (compareFn(context, key, items[it]) == .eq) it else null;
}

pub fn carefulPrefetchBranchlessBinarySearch(
    comptime T: type,
    key: anytype,
    items: []const T,
    context: anytype,
    comptime compareFn: fn (context: @TypeOf(context), key: @TypeOf(key), mid_item: T) std.math.Order,
) ?usize {
    var it: usize = 0;
    var len: usize = items.len;
    // when we prefetch ahead to reduce memory bottleneck we prefetch len / 2 and len ahead, so they'll overlap when len / 2 = the size of one cache line
    const four_cache_lines = 256;

    const prefetch_limit = four_cache_lines / @sizeOf(T);
    if (prefetch_limit > 1) {
        while (len > prefetch_limit) {
            const half: usize = len / 2;
            len -= half;
            @prefetch(items.ptr + it + len / 2, .{});
            @prefetch(items.ptr + it + len, .{});
            it += select(compareFn(context, key, items[it + half - 1]) == .gt, half, 0);
        }
    }
    while (len > 1) {
        const half: usize = len / 2;
        len -= half;
        it += select(compareFn(context, key, items[it + half - 1]) == .gt, half, 0);
    }
    return if (compareFn(context, key, items[it]) == .eq) it else null;
}
