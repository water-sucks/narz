const std = @import("std");
const io = std.io;
const mem = std.mem;
const Allocator = mem.Allocator;

const narz = @import("narz");
const CatFlags = @import("args.zig").CatFlags;
const log = @import("log.zig");

pub fn catMain(alloc: Allocator, args: CatFlags) !void {
    _ = alloc;

    log.info("cat :: {s} {s}", .{ args.positional.archive, args.positional.path });
}
