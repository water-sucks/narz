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
    };

    pub const switches = .{
        .long = 'l',
        .json = 'j',
        .recursive = 'r',
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
