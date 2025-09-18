const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const Allocator = mem.Allocator;
const ArrayList = std.array_list.Managed;

pub fn normalizePath(alloc: Allocator, path: []const u8) ![]const u8 {
    var stack = ArrayList([]const u8).init(alloc);
    defer stack.deinit();

    var it = try fs.path.componentIterator(path);

    while (it.next()) |component| {
        const name = component.name;

        if (std.mem.eql(u8, name, ".") or name.len == 0) {
            continue;
        } else if (std.mem.eql(u8, name, "..")) {
            _ = stack.pop();
        } else {
            try stack.append(name);
        }
    }

    if (stack.items.len == 0) {
        return alloc.dupe(u8, "/");
    }

    return fs.path.join(alloc, stack.items);
}
