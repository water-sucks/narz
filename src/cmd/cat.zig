const std = @import("std");
const io = std.io;
const mem = std.mem;
const Allocator = mem.Allocator;

const narz = @import("narz");
const CatFlags = @import("args.zig").CatFlags;
const log = @import("log.zig");

pub fn catMain(alloc: Allocator, args: CatFlags) !void {
    const archiveFilename = args.positional.archive;
    const objectPath = args.positional.path;

    const archiveFile = try std.fs.cwd().openFile(archiveFilename, .{ .mode = .read_only });
    defer archiveFile.close();

    const parsedArchive = narz.Parser.parseFromReader(alloc, archiveFile.reader()) catch |err| {
        log.err("failed to parse archive: {s}", .{@errorName(err)});
        return err;
    };
    defer parsedArchive.deinit();

    const archive = parsedArchive.value;

    const object = (archive.getObject(alloc, objectPath) catch |err| return err) orelse {
        log.err("path '{s}' does not exist in the archive", .{objectPath});
        return error.NotExists;
    };

    switch (object) {
        .file => |file| {
            try io.getStdOut().writer().writeAll(file.content);
        },

        .directory => {
            log.err("path '{s}' is a directory", .{objectPath});
            return error.IsDirectory;
        },
        .symlink => {
            log.err("path '{s}' is a symlink", .{objectPath});
            return error.IsSymlink;
        },
    }
}
