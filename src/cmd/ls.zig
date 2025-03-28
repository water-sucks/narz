const std = @import("std");
const io = std.io;
const mem = std.mem;
const Allocator = mem.Allocator;

const narz = @import("narz");
const LsFlags = @import("args.zig").LsFlags;
const log = @import("log.zig");

pub fn lsMain(alloc: Allocator, args: LsFlags) !void {
    _ = alloc;

    log.info("ls        :: {s} {s}", .{ args.positional.archive, args.positional.path });
    log.info("recursive :: {}", .{args.recursive});
    log.info("json      :: {}", .{args.json});
    log.info("long      :: {}", .{args.long});
    log.info("directory :: {}", .{args.directory});
}
