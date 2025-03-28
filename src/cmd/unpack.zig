const std = @import("std");
const io = std.io;
const mem = std.mem;
const Allocator = mem.Allocator;

const narz = @import("narz");
const UnpackFlags = @import("args.zig").UnpackFlags;
const log = @import("log.zig");

pub fn unpackMain(alloc: Allocator, args: UnpackFlags) !void {
    _ = alloc;

    log.info("unpack :: {s} {s}", .{ args.positional.archive, args.positional.path });
}
