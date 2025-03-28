const std = @import("std");
const io = std.io;
const mem = std.mem;
const Allocator = mem.Allocator;

const narz = @import("narz");
const PackFlags = @import("args.zig").PackFlags;
const log = @import("log.zig");

pub fn packMain(alloc: Allocator, args: PackFlags) !void {
    _ = alloc;

    log.info("pack :: {s}", .{args.positional.path});
}
