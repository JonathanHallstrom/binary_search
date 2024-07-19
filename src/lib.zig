const std = @import("std");

pub fn ascending(T: type) fn (void, T, T) std.math.Order {
    return struct {
        fn impl(_: void, lhs: T, rhs: T) std.math.Order {
            return std.math.order(lhs, rhs);
        }
    }.impl;
}

const popt: std.builtin.PrefetchOptions = .{
    .locality = 1,
};

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
    // TODO: simplify this, kinda ugly

    // return @bitCast(@select(T, @as(@Vector(1, bool), @splat(predicate)), @as(@Vector(1, T), @splat(a)), @as(@Vector(1, T), @splat(b))));

    // var res: T = b;
    // if (predicate) res = a;
    // return res;

    // return if (predicate) a else b;
    return ([2]@TypeOf(a, b){ b, a })[@intFromBool(predicate)];
}

// if (predicate) a else 0
inline fn select2(predicate: bool, a: usize) usize {
    const mask = @as(usize, 0) -% @intFromBool(predicate);
    var res = a;
    if (@import("builtin").cpu.arch.isX86()) {
        // generates a branch if i dont do it myself :/
        asm volatile ("and %[mask], %[res]"
            : [res] "+r" (res),
            : [mask] "r" (mask),
        );
    } else {
        res &= mask;
    }
    return res;
}

pub fn branchyBinarySearch(
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
        it += if (compareFn(context, key, items[it + half - 1]) == .gt) half else 0;
    }
    return if (it < items.len and compareFn(context, key, items[it]) == .eq) it else null;
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
    return if (it < items.len and compareFn(context, key, items[it]) == .eq) it else null;
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
        @prefetch(items.ptr + it + len / 2 + 1, popt);
        @prefetch(items.ptr + it + half + len / 2 + 1, popt);
        it += select(compareFn(context, key, items[it + half - 1]) == .gt, half, 0);
    }
    return if (it < items.len and compareFn(context, key, items[it]) == .eq) it else null;
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
    if (len == 0) return null;
    const one_cache_line = 64;

    const prefetch_limit = one_cache_line / @sizeOf(T);
    if (prefetch_limit > 1) {
        while (len > prefetch_limit) {
            const half: usize = len / 2;
            len -= half;
            @prefetch(items.ptr + it + len / 2 + 1, popt);
            @prefetch(items.ptr + it + half + len / 2 + 1, popt);
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

pub fn inlineAsmBranchlessBinarySearch(
    comptime T: type,
    key: anytype,
    items: []const T,
    context: anytype,
    comptime compareFn: fn (context: @TypeOf(context), key: @TypeOf(key), mid_item: T) std.math.Order,
) ?usize {
    var it: usize = 0;
    var len: usize = items.len;
    if (len == 0) return null;
    const one_cache_line = 64;

    const prefetch_limit = one_cache_line / @sizeOf(T);
    if (prefetch_limit > 1) {
        while (len > prefetch_limit) {
            const half: usize = len / 2;
            len -= half;
            @prefetch(items.ptr + it + len / 2 + 1, popt);
            @prefetch(items.ptr + it + half + len / 2 + 1, popt);
            it += select2(compareFn(context, key, items[it + half - 1]) == .gt, half);
        }
    }
    while (len > 1) {
        const half: usize = len / 2;
        len -= half;
        it += select2(compareFn(context, key, items[it + half - 1]) == .gt, half);
    }
    return if (compareFn(context, key, items[it]) == .eq) it else null;
}

pub fn improvedLowerBound(
    comptime T: type,
    key: anytype,
    items: []const T,
    context: anytype,
    comptime lessThan: fn (context: @TypeOf(context), lhs: @TypeOf(key), rhs: T) bool,
) usize {
    var it: usize = 0;
    var len: usize = items.len;
    const one_cache_line = 64;

    const prefetch_limit = one_cache_line / @sizeOf(T);
    if (prefetch_limit > 1) {
        while (len > prefetch_limit) {
            const half: usize = len / 2;
            len -= half;
            @prefetch(items.ptr + it + len / 2 + 1, popt);
            @prefetch(items.ptr + it + half + len / 2 + 1, popt);
            it += select(lessThan(context, items[it + half - 1], key), half, 0);
        }
    }
    while (len > 1) {
        const half: usize = len / 2;
        len -= half;
        it += select(lessThan(context, items[it + half - 1], key), half, 0);
    }
    if (it < items.len and lessThan(context, items[it], key)) it += 1;
    return it;
}

pub fn improvedUpperBound(
    comptime T: type,
    key: anytype,
    items: []const T,
    context: anytype,
    comptime lessThan: fn (context: @TypeOf(context), lhs: @TypeOf(key), rhs: T) bool,
) usize {
    var it: usize = 0;
    var len: usize = items.len;
    const one_cache_line = 64;

    const prefetch_limit = one_cache_line / @sizeOf(T);
    if (prefetch_limit > 1) {
        while (len > prefetch_limit) {
            const half: usize = len / 2;
            len -= half;
            @prefetch(items.ptr + it + len / 2 + 1, popt);
            @prefetch(items.ptr + it + half + len / 2 + 1, popt);
            it += select(lessThan(context, key, items[it + half - 1]), 0, half);
        }
    }
    while (len > 1) {
        const half: usize = len / 2;
        len -= half;
        it += select(lessThan(context, key, items[it + half - 1]), 0, half);
    }
    if (it < items.len and !lessThan(context, key, items[it])) it += 1;
    return it;
}

pub fn alexandrescuLowerBound(
    comptime T: type,
    key: anytype,
    items: []const T,
    context: anytype,
    comptime lessThan: fn (context: @TypeOf(context), lhs: @TypeOf(key), rhs: T) bool,
) usize {
    var it: usize = 0;
    var len: usize = items.len;
    while (len > 0) {
        const cut = len / 2;
        if (lessThan(context, items[it + cut], key)) {
            it += cut + 1;
            len -= cut + 1;
        } else {
            len = cut;
        }
    }
    return it;
}

pub fn alexandrescuUpperBound(
    comptime T: type,
    key: anytype,
    items: []const T,
    context: anytype,
    comptime lessThan: fn (context: @TypeOf(context), lhs: @TypeOf(key), rhs: T) bool,
) usize {
    var it: usize = 0;
    var len: usize = items.len;
    while (len > 0) {
        const cut = len / 2;
        if (lessThan(context, key, items[it + cut])) {
            len = cut;
        } else {
            it += cut + 1;
            len -= cut + 1;
        }
    }
    return it;
}

pub fn improvedEqualRange(
    comptime T: type,
    key: anytype,
    items: []const T,
    context: anytype,
    comptime lessThan: fn (context: @TypeOf(context), lhs: @TypeOf(key), rhs: T) bool,
) struct { usize, usize } {
    const lower = improvedLowerBound(T, key, items, context, lessThan);
    // const upper = improvedUpperBound(T, key, items, context, lessThan);
    // return .{ lower, upper };
    var len = items.len - lower;
    var it = lower;
    while (len > 0) {
        const cut = len / 4;
        if (lessThan(context, key, items[it + cut])) {
            len = cut;
        } else {
            it += cut + 1;
            len -= cut + 1;
            break;
        }
    }
    while (len > 0) {
        const cut = len / 2;
        if (lessThan(context, key, items[it + cut])) {
            len = cut;
        } else {
            it += cut + 1;
            len -= cut + 1;
        }
    }

    return .{ lower, it };
}
