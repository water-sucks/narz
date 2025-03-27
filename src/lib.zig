const std = @import("std");
const testing = std.testing;

pub usingnamespace @import("nar.zig");

pub const Parser = @import("parse.zig");

test "all" {
    testing.refAllDeclsRecursive(@This());
}
