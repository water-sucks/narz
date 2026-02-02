const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const Allocator = mem.Allocator;
const ArrayList = std.array_list.Managed;

pub fn normalizePath(alloc: Allocator, path: []const u8) ![]const u8 {
    return fs.path.resolve(alloc, &.{ "/", path });
}
