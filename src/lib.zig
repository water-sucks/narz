const std = @import("std");
const testing = std.testing;

pub const nar = @import("nar.zig");

pub const Archive = nar.NarArchive;
pub const Directory = nar.NarDirectory;
pub const DirectoryEntry = nar.NarDirectoryEntry;
pub const File = nar.NarFile;
pub const Object = nar.NarObject;
pub const Symlink = nar.NarSymlink;

pub const Parser = @import("parse.zig");

test "all" {
    testing.refAllDeclsRecursive(@This());
}
