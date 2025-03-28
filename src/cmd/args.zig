pub const Flags = struct {
    pub const description = "Create or inspect NAR archives";

    command: union(enum) {
        cat: CatFlags,
        ls: LsFlags,
        pack: PackFlags,
        unpack: UnpackFlags,

        pub const descriptions = .{
            .cat = "Print the contents of a NAR archive",
            .ls = "List the contents of a NAR archive",
            .pack = "Serialise a path in NAR format",
            .unpack = "Unpack a NAR archive to a path",
        };
    },
};

pub const CatFlags = struct {
    positional: struct {
        archive: []const u8,
        path: []const u8,

        pub const descriptions = .{
            .archive = "Path to NAR archive (required)",
            .path = "Path to file to print (required)",
        };
    },
};

pub const LsFlags = struct {
    long: bool,
    json: bool,
    recursive: bool,
    directory: bool,

    positional: struct {
        archive: []const u8,
        path: []const u8,

        pub const descriptions = .{
            .archive = "Path to NAR archive (required)",
            .path = "Path to object (required)",
        };
    },

    pub const descriptions = .{
        .long = "Show detailed file information",
        .json = "Produce JSON output",
        .recursive = "List subdirectories recursively",
        .directory = "Show directories rather than their contents",
    };

    pub const switches = .{
        .long = 'l',
        .json = 'j',
        .recursive = 'r',
        .directory = 'd',
    };
};

pub const PackFlags = struct {
    positional: struct {
        path: []const u8,

        pub const descriptions = .{
            .path = "Path to serialize as a NAR (required)",
        };
    },
};

pub const UnpackFlags = struct {
    positional: struct {
        archive: []const u8,
        path: []const u8,

        pub const descriptions = .{
            .archive = "Path to NAR archive (required)",
            .path = "Path to unpack to (required)",
        };
    },
};
