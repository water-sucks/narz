const std = @import("std");
const base64 = std.base64;
const io = std.io;
const mem = std.mem;
const fs = std.fs;
const json = std.json;
const meta = std.meta;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;

const narz = @import("narz");
const LsFlags = @import("args.zig").LsFlags;
const log = @import("log.zig");

const utils = @import("utils");

pub fn lsMain(alloc: Allocator, args: LsFlags) !void {
    const archiveFilename = args.positional.archive;

    const objectPath = utils.normalizePath(alloc, args.positional.path) catch |err| {
        log.err("failed to normalize path: {s}", .{@errorName(err)});
        return err;
    };
    defer alloc.free(objectPath);

    const archiveFile = fs.cwd().openFile(archiveFilename, .{ .mode = .read_only }) catch |err| {
        log.err("failed to open archive: {s}", .{@errorName(err)});
        return err;
    };
    defer archiveFile.close();

    const parsedArchive = narz.Parser.parseFromReader(alloc, archiveFile.reader()) catch |err| {
        log.err("failed to parse archive: {s}", .{@errorName(err)});
        return err;
    };
    defer parsedArchive.deinit();

    const archive = parsedArchive.value;

    const parentDirname = fs.path.dirname(objectPath) orelse "/";

    const parentDirObject = try archive.getObject(alloc, parentDirname) orelse {
        log.err("path '{s}' does not exist in the archive", .{parentDirname});
        return error.NotExists;
    };

    if (meta.activeTag(parentDirObject) != .directory) {
        log.err("path '{s}' is not a directory in the archive", .{parentDirname});
        log.info("the archive may be corrupted", .{});
        return error.NotADirectory;
    }

    var object: narz.NarObject = undefined;

    if (mem.eql(u8, parentDirname, "/")) {
        object = parentDirObject;
    } else {
        const objectBasename = fs.path.basename(objectPath);

        for (parentDirObject.directory.entries) |entry| {
            if (mem.eql(u8, entry.name, objectBasename)) {
                object = entry.object;
                break;
            }
        } else {
            log.err("path '{s}' does not exist in the directory '{s}'", .{ objectPath, objectBasename });
            log.info("the archive may be corrupted", .{});
            return error.NotExists;
        }
    }

    const stdout = io.getStdOut().writer();

    if (!args.json) {
        if (args.recursive) {
            try lstree(alloc, stdout, object, args.long);
        } else {
            try printObjLine(stdout, objectPath, object, args.long);
        }
    } else {
        var writer = json.writeStream(stdout, .{ .whitespace = .indent_2 });

        if (args.recursive) {
            try narObjectJsonRecursive(alloc, &writer, object, true);
        } else {
            try narObjectJson(&writer, object);
        }

        try stdout.writeAll("\n");
    }
}

fn lstree(alloc: Allocator, writer: anytype, root: narz.NarObject, long: bool) !void {
    const NodeType = struct { narz.NarObject, []const u8 };

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
                const nestedEntry = entries[i - 1];

                const new_path = try fs.path.join(alloc, &.{ path, nestedEntry.name });
                try stack.append(.{ nestedEntry.object, new_path });
            }
        }
    }
}

fn printObjLine(writer: anytype, name: []const u8, obj: narz.NarObject, long: bool) !void {
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

fn narObjectJsonRecursive(alloc: Allocator, writer: anytype, obj: narz.NarObject, wrap_object: bool) !void {
    if (wrap_object) {
        try writer.beginObject();
    }

    try writer.objectField("type");

    switch (obj) {
        .file => try writer.write("file"),
        .symlink => try writer.write("symlink"),
        .directory => try writer.write("directory"),
    }

    switch (obj) {
        .file => |f| {
            try writer.objectField("executable");
            try writer.write(f.executable);
        },

        .symlink => |s| {
            try writer.objectField("target");
            try writer.write(s.target);
        },

        .directory => |d| {
            try writer.objectField("entries");
            try writer.beginArray();

            for (d.entries) |entry| {
                try writer.beginObject();
                try writer.objectField("name");
                try writer.write(entry.name);

                try narObjectJsonRecursive(alloc, writer, entry.object, false);

                try writer.endObject();
            }

            try writer.endArray();
        },
    }

    if (wrap_object) {
        try writer.endObject();
    }
}

fn narObjectJson(writer: anytype, obj: narz.NarObject) !void {
    try writer.beginObject();

    try writer.objectField("type");

    switch (obj) {
        .file => try writer.write("file"),
        .symlink => try writer.write("symlink"),
        .directory => try writer.write("directory"),
    }

    switch (obj) {
        .file => |f| {
            try writer.objectField("executable");
            try writer.write(f.executable);
        },

        .symlink => |s| {
            try writer.objectField("target");
            try writer.write(s.target);
        },

        .directory => |d| {
            try writer.objectField("entries");
            try writer.beginArray();

            for (d.entries) |entry| {
                try writer.beginObject();
                try writer.objectField("name");
                try writer.write(entry.name);

                try writer.objectField("type");
                switch (obj) {
                    .file => try writer.write("file"),
                    .symlink => try writer.write("symlink"),
                    .directory => try writer.write("directory"),
                }

                try writer.endObject();
            }

            try writer.endArray();
        },
    }

    try writer.endObject();
}
