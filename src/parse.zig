const std = @import("std");
const heap = std.heap;
const mem = std.mem;
const io = std.io;
const fmt = std.fmt;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;

const narTypes = @import("nar.zig");
const NarArchive = narTypes.NarArchive;
const NarObject = narTypes.NarObject;
const NarFile = narTypes.NarFile;
const NarDirectory = narTypes.NarDirectory;
const NarDirectoryEntry = narTypes.NarDirectoryEntry;
const NarSymlink = narTypes.NarSymlink;

fn Parsed(comptime T: type) type {
    return struct {
        arena: std.heap.ArenaAllocator,
        value: T,

        pub fn deinit(self: @This()) void {
            self.arena.deinit();
        }
    };
}

pub const NarParseError = error{
    MalformedNarDirectory,
    MalformedNarFile,
    DirectoryEnded,
    UnknownObjectType,
    InvalidMagic,
    InvalidNarArchiveVersion,
    UnexpectedValue,
} || Allocator.Error || std.posix.ReadError || error{EndOfStream};

pub const ParsedNarArchive = Parsed(NarArchive);

pub fn parseFromSlice(allocator: Allocator, slice: []const u8) !ParsedNarArchive {
    var reader = io.fixedBufferStream(slice);

    return try parseFromReader(allocator, reader.reader());
}

pub fn parseFromReader(allocator: Allocator, reader: anytype) !ParsedNarArchive {
    var arena = heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const alloc = arena.allocator();

    var parsed: NarArchive = .{
        .object = undefined,
        .version = 0,
    };

    parsed.version = try expectHeaderAndArchiveVersion(alloc, reader);
    parsed.object = try expectObject(alloc, reader);

    return ParsedNarArchive{
        .arena = arena,
        .value = parsed,
    };
}

const NIX_ARCHIVE_PREFIX_MAGIC = "nix-archive-";

fn expectHeaderAndArchiveVersion(alloc: Allocator, reader: anytype) !usize {
    const magic = try readString(alloc, reader);

    if (!mem.startsWith(u8, magic, NIX_ARCHIVE_PREFIX_MAGIC)) {
        return error.InvalidMagic;
    }

    if (magic.len <= NIX_ARCHIVE_PREFIX_MAGIC.len) {
        return error.InvalidMagic;
    }

    const version = fmt.parseInt(usize, magic[NIX_ARCHIVE_PREFIX_MAGIC.len..], 10) catch {
        return error.InvalidNarArchiveVersion;
    };

    return version;
}

fn expectObject(alloc: Allocator, reader: anytype) NarParseError!NarObject {
    try expectStringValue(alloc, reader, "(");
    try expectStringValue(alloc, reader, "type");

    const valueType = try readString(alloc, reader);

    var parsed: NarObject = undefined;

    if (mem.eql(u8, valueType, "regular")) {
        parsed = .{ .file = try expectNarFile(alloc, reader) };
    } else if (mem.eql(u8, valueType, "directory")) {
        parsed = .{ .directory = try expectNarDirectory(alloc, reader) };
    } else if (mem.eql(u8, valueType, "symlink")) {
        parsed = .{ .symlink = try expectNarSymlink(alloc, reader) };
    } else {
        return error.UnknownObjectType;
    }

    // An extremely lazy way of getting around needing to backtrack.
    // Directories
    if (std.meta.activeTag(parsed) != .directory) {
        try expectStringValue(alloc, reader, ")");
    }

    return parsed;
}

fn expectNarFile(alloc: Allocator, reader: anytype) NarParseError!NarFile {
    var parsed: NarFile = undefined;

    var next = try readString(alloc, reader);

    if (mem.eql(u8, next, "executable")) {
        parsed.executable = true;
        _ = try readString(alloc, reader);
        next = try readString(alloc, reader);
    }

    if (!mem.eql(u8, next, "contents")) {
        return error.MalformedNarFile;
    }

    parsed.content = readString(alloc, reader) catch |err| {
        return err;
    };

    return parsed;
}

fn expectNarDirectory(alloc: Allocator, reader: anytype) !NarDirectory {
    var parsed: NarDirectory = undefined;

    var entries = ArrayList(NarDirectoryEntry).init(alloc);
    errdefer entries.deinit();

    while (true) {
        const entry = expectNarDirectoryEntry(alloc, reader) catch |err| switch (err) {
            error.DirectoryEnded => break,
            else => return err,
        };

        try entries.append(entry);
    }

    parsed.entries = try entries.toOwnedSlice();
    return parsed;
}

fn expectNarDirectoryEntry(alloc: Allocator, reader: anytype) NarParseError!NarDirectoryEntry {
    const entryDecl = try readString(alloc, reader);

    if (mem.eql(u8, entryDecl, ")")) {
        return error.DirectoryEnded;
    } else if (!mem.eql(u8, entryDecl, "entry")) {
        return error.MalformedNarDirectory;
    }

    var entry: NarDirectoryEntry = undefined;

    try expectStringValue(alloc, reader, "(");

    try expectStringValue(alloc, reader, "name");
    entry.name = try readString(alloc, reader);

    try expectStringValue(alloc, reader, "node");
    entry.object = try expectObject(alloc, reader);

    try expectStringValue(alloc, reader, ")");

    return entry;
}

fn expectNarSymlink(alloc: Allocator, reader: anytype) !NarSymlink {
    var parsed: NarSymlink = undefined;

    try expectStringValue(alloc, reader, "target");

    parsed.target = try readString(alloc, reader);

    return parsed;
}

fn expectStringValue(alloc: Allocator, reader: anytype, expected: []const u8) !void {
    const actual = try readString(alloc, reader);
    defer alloc.free(actual);

    if (!mem.eql(u8, expected, actual)) {
        return error.UnexpectedValue;
    }
}

fn readString(alloc: Allocator, reader: anytype) ![]const u8 {
    const len = try reader.readInt(u64, .little);

    if (len == 0) {
        return "";
    }

    const result = try alloc.alloc(u8, len);
    errdefer alloc.free(result);

    try reader.readNoEof(result);

    const remainder = len % 8;
    if (remainder > 0) {
        const bytesToSkip = 8 - remainder;
        try reader.skipBytes(bytesToSkip, .{});
    }

    return result;
}
