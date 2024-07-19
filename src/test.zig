const std = @import("std");

// tests from standard library
const testing = std.testing;
const math = std.math;

const lib = @import("lib.zig");
const ascending = lib.ascending;
const oldBinarySearch = lib.oldBinarySearch;
const brancyBinarySearch = lib.branchyBinarySearch;
const branchlessBinarySearch = lib.branchlessBinarySearch;
const prefetchBranchlessBinarySearch = lib.prefetchBranchlessBinarySearch;
const carefulPrefetchBranchlessBinarySearch = lib.carefulPrefetchBranchlessBinarySearch;
const inlineAsmBranchlessBinarySearch = lib.inlineAsmBranchlessBinarySearch;
const improvedLowerBound = lib.improvedLowerBound;
const improvedUpperBound = lib.improvedUpperBound;
const improvedEqualRange = lib.improvedEqualRange;
const alexandrescuLowerBound = lib.alexandrescuLowerBound;
const alexandrescuUpperBound = lib.alexandrescuUpperBound;
test oldBinarySearch {
    try testImplementation(oldBinarySearch);
}

test branchlessBinarySearch {
    try testImplementation(branchlessBinarySearch);
}

test prefetchBranchlessBinarySearch {
    try testImplementation(prefetchBranchlessBinarySearch);
}

test carefulPrefetchBranchlessBinarySearch {
    try testImplementation(carefulPrefetchBranchlessBinarySearch);
}

test inlineAsmBranchlessBinarySearch {
    try testImplementation(inlineAsmBranchlessBinarySearch);
}

fn testImplementation(binary_search_fn: anytype) !void {
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
        binary_search_fn(u32, @as(u32, 1), &[_]u32{}, {}, S.order_u32),
    );
    try testing.expectEqual(
        @as(?usize, 0),
        binary_search_fn(u32, @as(u32, 1), &[_]u32{1}, {}, S.order_u32),
    );
    try testing.expectEqual(
        @as(?usize, null),
        binary_search_fn(u32, @as(u32, 1), &[_]u32{0}, {}, S.order_u32),
    );
    try testing.expectEqual(
        @as(?usize, null),
        binary_search_fn(u32, @as(u32, 0), &[_]u32{1}, {}, S.order_u32),
    );
    try testing.expectEqual(
        @as(?usize, 4),
        binary_search_fn(u32, @as(u32, 5), &[_]u32{ 1, 2, 3, 4, 5 }, {}, S.order_u32),
    );
    try testing.expectEqual(
        @as(?usize, 0),
        binary_search_fn(u32, @as(u32, 2), &[_]u32{ 2, 4, 8, 16, 32, 64 }, {}, S.order_u32),
    );
    try testing.expectEqual(
        @as(?usize, 1),
        binary_search_fn(i32, @as(i32, -4), &[_]i32{ -7, -4, 0, 9, 10 }, {}, S.order_i32),
    );
    try testing.expectEqual(
        @as(?usize, 3),
        binary_search_fn(i32, @as(i32, 98), &[_]i32{ -100, -25, 2, 98, 99, 100 }, {}, S.order_i32),
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
        binary_search_fn(R, @as(i32, -45), &[_]R{ R.r(-100, -50), R.r(-40, -20), R.r(-10, 20), R.r(30, 40) }, {}, R.order),
    );
    try testing.expectEqual(
        @as(?usize, 2),
        binary_search_fn(R, @as(i32, 10), &[_]R{ R.r(-100, -50), R.r(-40, -20), R.r(-10, 20), R.r(30, 40) }, {}, R.order),
    );
    try testing.expectEqual(
        @as(?usize, 1),
        binary_search_fn(R, @as(i32, -20), &[_]R{ R.r(-100, -50), R.r(-40, -20), R.r(-10, 20), R.r(30, 40) }, {}, R.order),
    );
}

test improvedLowerBound {
    var a: [1024]i32 = undefined;
    var rng = std.Random.DefaultPrng.init(0);
    for (a[0..]) |*e| e.* = rng.random().int(i8);
    std.sort.pdq(i32, a[0..], void{}, std.sort.asc(i32));
    for (0..1024) |i| {
        const key: i32 = @as(i32, @intCast(i)) - 512;
        try std.testing.expectEqual(std.sort.lowerBound(i32, key, a[0..], void{}, std.sort.asc(i32)), improvedLowerBound(i32, key, a[0..], void{}, std.sort.asc(i32)));
    }
}

test improvedUpperBound {
    var a: [1024]i32 = undefined;
    var rng = std.Random.DefaultPrng.init(0);
    for (a[0..]) |*e| e.* = rng.random().int(i8);
    std.sort.pdq(i32, a[0..], void{}, std.sort.asc(i32));
    for (0..1024) |i| {
        const key: i32 = @as(i32, @intCast(i)) - 512;
        try std.testing.expectEqual(std.sort.upperBound(i32, key, a[0..], void{}, std.sort.asc(i32)), improvedUpperBound(i32, key, a[0..], void{}, std.sort.asc(i32)));
    }
}

test alexandrescuLowerBound {
    var a: [1024]i32 = undefined;
    var rng = std.Random.DefaultPrng.init(0);
    for (a[0..]) |*e| e.* = rng.random().int(i8);
    std.sort.pdq(i32, a[0..], void{}, std.sort.asc(i32));
    for (0..1024) |i| {
        const key: i32 = @as(i32, @intCast(i)) - 512;
        try std.testing.expectEqual(std.sort.lowerBound(i32, key, a[0..], void{}, std.sort.asc(i32)), improvedLowerBound(i32, key, a[0..], void{}, std.sort.asc(i32)));
    }
}

test alexandrescuUpperBound {
    var a: [1024]i32 = undefined;
    var rng = std.Random.DefaultPrng.init(0);
    for (a[0..]) |*e| e.* = rng.random().int(i8);
    std.sort.pdq(i32, a[0..], void{}, std.sort.asc(i32));
    for (0..1024) |i| {
        const key: i32 = @as(i32, @intCast(i)) - 512;
        try std.testing.expectEqual(std.sort.upperBound(i32, key, a[0..], void{}, std.sort.asc(i32)), improvedUpperBound(i32, key, a[0..], void{}, std.sort.asc(i32)));
    }
}

test improvedEqualRange {
    var a: [1024]i32 = undefined;
    var rng = std.Random.DefaultPrng.init(0);
    for (a[0..]) |*e| e.* = rng.random().int(i8);
    std.sort.pdq(i32, a[0..], void{}, std.sort.asc(i32));
    for (0..1024) |i| {
        const key: i32 = @as(i32, @intCast(i)) - 512;
        try std.testing.expectEqual(std.sort.equalRange(i32, key, a[0..], void{}, std.sort.asc(i32)), improvedEqualRange(i32, key, a[0..], void{}, std.sort.asc(i32)));
    }
}
