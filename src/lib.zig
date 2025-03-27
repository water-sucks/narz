const std = @import("std");
const testing = std.testing;

pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "simple test" {
    try testing.expectEqual(add(1, 2), 3);
}

test "all" {
    testing.refAllDeclsRecursive(@This());
}
