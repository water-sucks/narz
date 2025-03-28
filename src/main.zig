const std = @import("std");
const heap = std.heap;
const process = std.process;
const posix = std.posix;

const flags = @import("flags");
const narz = @import("narz");

const log = @import("cmd/log.zig");
const Flags = @import("cmd/args.zig").Flags;

const catCmd = @import("cmd/cat.zig");
const lsCmd = @import("cmd/ls.zig");
const unpackCmd = @import("cmd/unpack.zig");
const packCmd = @import("cmd/pack.zig");

pub fn main() !u8 {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    defer {
        _ = gpa.deinit();
    }
    const alloc = gpa.allocator();

    if (posix.getenv("NO_COLOR") != null) {
        log.use_color = false;
    }

    const args = process.argsAlloc(alloc) catch |err| {
        log.err("failed to allocate arguments: {s}", .{@errorName(err)});
        return 1;
    };
    defer process.argsFree(alloc, args);

    var parseFlagOptions: flags.Options = .{};
    if (!log.use_color) {
        parseFlagOptions.colors = &.{};
    }

    const parsedFlags = flags.parseOrExit(args, "narz", Flags, parseFlagOptions);

    _ = switch (parsedFlags.command) {
        .cat => |catFlags| {
            log.info("cat {s} {s}", .{ catFlags.positional.archive, catFlags.positional.path });
        },
        .ls => |lsFlags| {
            log.info("ls {s}", .{lsFlags.positional.archive});
        },
        .pack => |packFlags| {
            log.info("pack {s}", .{packFlags.positional.path});
        },
        .unpack => |unpackFlags| unpackCmd.unpackMain(alloc, unpackFlags),
    } catch return 1;

    return 0;
}
