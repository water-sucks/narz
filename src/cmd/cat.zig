const std = @import("std");
const io = std.io;
const mem = std.mem;
const fs = std.fs;
const File = fs.File;
const Allocator = mem.Allocator;

const narz = @import("narz");
const CatFlags = @import("args.zig").CatFlags;
const log = @import("log.zig");

pub fn catMain(alloc: Allocator, args: CatFlags) !void {
    const archive_filename = args.positional.archive;
    const object_path = args.positional.path;

    var archive_file = std.fs.cwd().openFile(archive_filename, .{ .mode = .read_only }) catch |err| {
        log.err("failed to open archive: {s}", .{@errorName(err)});
        return err;
    };
    defer archive_file.close();

    var archive_file_reader = archive_file.reader(&.{});

    const parsed_archive = narz.Parser.parseFromReader(alloc, &archive_file_reader.interface) catch |err| {
        log.err("failed to parse archive: {s}", .{@errorName(err)});
        return err;
    };
    defer parsed_archive.deinit();

    const archive = parsed_archive.value;

    const object = (archive.getObject(alloc, object_path) catch |err| return err) orelse {
        log.err("path '{s}' does not exist in the archive", .{object_path});
        return error.NotExists;
    };

    switch (object) {
        .file => |file| {
            _ = try File.stdout().write(file.content);
        },

        .directory => {
            log.err("path '{s}' is a directory", .{object_path});
            return error.IsDirectory;
        },
        .symlink => {
            log.err("path '{s}' is a symlink", .{object_path});
            return error.IsSymlink;
        },
    }
}
