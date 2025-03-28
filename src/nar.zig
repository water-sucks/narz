const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;

pub const NarArchive = struct {
    version: usize,
    object: NarObject,

    pub fn stringRepr(self: NarArchive, alloc: Allocator) ![]const u8 {
        var repr = ArrayList(u8).init(alloc);
        errdefer repr.deinit();

        const writer = repr.writer();

        try writer.print("nix-archive-{d} ", .{self.version});
        try printNar(repr.writer(), self.object, 0);

        return repr.toOwnedSlice();
    }

    pub fn getObject(self: NarArchive, alloc: Allocator, path: []const u8) !?NarObject {
        var it = fs.path.componentIterator(path) catch return null;

        var stack = ArrayList(NarObject).init(alloc);
        defer stack.deinit();

        try stack.append(self.object);

        componentTraversal: while (it.next()) |component| {
            const current = stack.items[stack.items.len - 1];

            if (mem.eql(u8, component.name, ".")) {
                continue;
            }

            if (mem.eql(u8, component.name, "..")) {
                if (stack.items.len > 1) {
                    _ = stack.pop();
                }
                continue;
            }

            if (std.meta.activeTag(current) != .directory) {
                // There are no more components to traverse past.
                return null;
            }

            for (current.directory.entries) |entry| {
                if (mem.eql(u8, entry.name, component.name)) {
                    try stack.append(entry.object);
                    continue :componentTraversal;
                }
            } else {
                // The entry with this name does not exist in the current directory.
                return null;
            }
        }

        return stack.pop();
    }

    fn printNar(writer: anytype, obj: NarObject, indent: usize) !void {
        const spaces = indent * 2; // Use 2 spaces per indent level

        try writer.writeAll("(\n");

        switch (obj) {
            .file => {
                try writer.writeByteNTimes(' ', spaces + 2);
                try writer.writeAll("type regular\n");

                try writer.writeByteNTimes(' ', spaces + 2);
                try writer.print("executable {}\n", .{obj.file.executable});

                try writer.writeByteNTimes(' ', spaces + 2);
                try writer.writeAll("contents <omitted>\n");
            },
            .symlink => {
                try writer.writeByteNTimes(' ', spaces + 2);
                try writer.writeAll("type symlink\n");

                try writer.writeByteNTimes(' ', spaces + 2);
                try writer.print("target {s}\n", .{obj.symlink.target});
            },
            .directory => {
                try writer.writeByteNTimes(' ', spaces + 2);
                try writer.writeAll("type directory\n");

                for (obj.directory.entries) |entry| {
                    try writer.writeByteNTimes(' ', spaces + 2);
                    try writer.writeAll("entry (\n");

                    try writer.writeByteNTimes(' ', spaces + 4);
                    try writer.print("name {s}\n", .{entry.name});

                    try writer.writeByteNTimes(' ', spaces + 4);
                    try writer.writeAll("node ");
                    try printNar(writer, entry.object, indent + 2);

                    try writer.writeByteNTimes(' ', spaces + 2);
                    try writer.writeAll(")\n");
                }
            },
        }

        try writer.writeByteNTimes(' ', spaces);
        try writer.writeAll(")\n");
    }
};

pub const NarObject = union(enum) {
    file: NarFile,
    directory: NarDirectory,
    symlink: NarSymlink,
};

pub const NarFile = struct {
    executable: bool,
    content: []const u8,
};

pub const NarSymlink = struct {
    target: []const u8,
};

pub const NarDirectory = struct {
    entries: []NarDirectoryEntry,
};

pub const NarDirectoryEntry = struct {
    name: []const u8,
    object: NarObject,
};
