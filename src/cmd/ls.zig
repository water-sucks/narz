const std = @import("std");
const base64 = std.base64;
const io = std.io;
const mem = std.mem;
const fs = std.fs;
const json = std.json;
const meta = std.meta;
const Allocator = mem.Allocator;
const ArrayList = std.array_list.Managed;
const File = fs.File;

const narz = @import("narz");
const LsFlags = @import("args.zig").LsFlags;
const log = @import("log.zig");

const utils = @import("utils");

pub fn lsMain(alloc: Allocator, args: LsFlags) !void {
    const archive_filename = args.positional.archive;

    const object_path = utils.normalizePath(alloc, args.positional.path) catch |err| {
        log.err("failed to normalize path: {s}", .{@errorName(err)});
        return err;
    };
    defer alloc.free(object_path);

    var archive_file = fs.cwd().openFile(archive_filename, .{ .mode = .read_only }) catch |err| {
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

    const parent_dirname = fs.path.dirname(object_path) orelse "/";

    const parent_dir_object = try archive.getObject(alloc, parent_dirname) orelse {
        log.err("path '{s}' does not exist in the archive", .{parent_dirname});
        return error.NotExists;
    };

    if (meta.activeTag(parent_dir_object) != .directory) {
        log.err("path '{s}' is not a directory in the archive", .{parent_dirname});
        log.info("the archive may be corrupted", .{});
        return error.NotADirectory;
    }

    var object: narz.Object = undefined;

    if (mem.eql(u8, parent_dirname, "/")) {
        object = parent_dir_object;
    } else {
        const object_basename = fs.path.basename(object_path);

        for (parent_dir_object.directory.entries) |entry| {
            if (mem.eql(u8, entry.name, object_basename)) {
                object = entry.object;
                break;
            }
        } else {
            log.err("path '{s}' does not exist in the directory '{s}'", .{ object_path, object_basename });
            log.info("the archive may be corrupted", .{});
            return error.NotExists;
        }
    }

    var stdout = File.stdout();
    var stdout_writer = stdout.writer(&.{}).interface;

    if (!args.json) {
        if (args.recursive) {
            try lsTree(alloc, &stdout_writer, object, args.long);
        } else {
            try printObjLine(&stdout_writer, object_path, object, args.long);
        }
    } else {
        var write_stream = json.Stringify{
            .options = .{ .whitespace = .indent_2 },
            .writer = &stdout_writer,
        };

        if (args.recursive) {
            try objectJsonRecursive(&write_stream, object, true);
        } else {
            try objectJson(&write_stream, object);
        }

        try stdout.writeAll("\n");
    }
}

fn lsTree(alloc: Allocator, writer: *io.Writer, root: narz.Object, long: bool) !void {
    const NodeType = struct { narz.Object, []const u8 };

    var stack = ArrayList(NodeType).init(alloc);
    defer stack.deinit();

    // If the root is a directory, don't print it. Just add its entries to the stack.
    if (meta.activeTag(root) == .directory) {
        const entries = root.directory.entries;

        // Since we need these in alphabetical order, add entries to the stack in reverse order
        // so that the top of the stack is the first alphabetical entry.
        var i: usize = entries.len;
        while (i > 0) : (i -= 1) {
            const nestedEntry = entries[i - 1];

            const new_path = try alloc.dupe(u8, nestedEntry.name);
            try stack.append(.{ nestedEntry.object, new_path });
        }
    }

    while (stack.pop()) |entry| {
        const obj = entry[0];
        const path = entry[1];

        defer alloc.free(path);

        try printObjLine(writer, path, obj, long);

        if (meta.activeTag(obj) == .directory) {
            const entries = obj.directory.entries;

            // Since we need these in alphabetical order, add entries to the stack in reverse order
            // so that the top of the stack is the first alphabetical entry.
            var i: usize = entries.len;
            while (i > 0) : (i -= 1) {
                const nested_entry = entries[i - 1];

                const new_path = try fs.path.join(alloc, &.{ path, nested_entry.name });
                try stack.append(.{ nested_entry.object, new_path });
            }
        }
    }
}

fn printObjLine(writer: *io.Writer, name: []const u8, obj: narz.Object, long: bool) !void {
    if (!long) {
        try writer.print("{s}\n", .{name});
        return;
    }

    const perms: []const u8 = switch (obj) {
        .file => |f| if (f.executable) "-r-xr-xr-x" else "-rw-r--r--",
        .directory => "dr-xr-xr-x",
        .symlink => "lrwxrwxrwx",
    };

    const size: usize = switch (obj) {
        .file => |f| f.content.len,
        else => 0,
    };

    try writer.print("{s} {d: >20} {s}", .{ perms, size, name });

    if (meta.activeTag(obj) == .symlink) {
        try writer.print(" -> {s}", .{obj.symlink.target});
    }

    try writer.writeAll("\n");
}

fn objectJsonRecursive(write_stream: *json.Stringify, obj: narz.Object, wrap_object: bool) !void {
    if (wrap_object) {
        try write_stream.beginObject();
    }

    try write_stream.objectField("type");

    switch (obj) {
        .file => try write_stream.write("file"),
        .symlink => try write_stream.write("symlink"),
        .directory => try write_stream.write("directory"),
    }

    switch (obj) {
        .file => |f| {
            try write_stream.objectField("executable");
            try write_stream.write(f.executable);
        },

        .symlink => |s| {
            try write_stream.objectField("target");
            try write_stream.write(s.target);
        },

        .directory => |d| {
            try write_stream.objectField("entries");
            try write_stream.beginArray();

            for (d.entries) |entry| {
                try write_stream.beginObject();
                try write_stream.objectField("name");
                try write_stream.write(entry.name);

                // TODO: replace with stack?
                try objectJsonRecursive(write_stream, entry.object, false);

                try write_stream.endObject();
            }

            try write_stream.endArray();
        },
    }

    if (wrap_object) {
        try write_stream.endObject();
    }
}

fn objectJson(write_stream: *json.Stringify, obj: narz.Object) !void {
    try write_stream.beginObject();

    try write_stream.objectField("type");

    switch (obj) {
        .file => try write_stream.write("file"),
        .symlink => try write_stream.write("symlink"),
        .directory => try write_stream.write("directory"),
    }

    switch (obj) {
        .file => |f| {
            try write_stream.objectField("executable");
            try write_stream.write(f.executable);
        },

        .symlink => |s| {
            try write_stream.objectField("target");
            try write_stream.write(s.target);
        },

        .directory => |d| {
            try write_stream.objectField("entries");
            try write_stream.beginArray();

            for (d.entries) |entry| {
                try write_stream.beginObject();
                try write_stream.objectField("name");
                try write_stream.write(entry.name);

                try write_stream.objectField("type");
                switch (obj) {
                    .file => try write_stream.write("file"),
                    .symlink => try write_stream.write("symlink"),
                    .directory => try write_stream.write("directory"),
                }

                try write_stream.endObject();
            }

            try write_stream.endArray();
        },
    }

    try write_stream.endObject();
}
