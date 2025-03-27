const std = @import("std");
const narz = @import("narz");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        _ = gpa.deinit();
    }
    const alloc = gpa.allocator();

    var args = try std.process.argsWithAllocator(alloc);
    defer args.deinit();

    _ = args.next();
    const archiveFilename = args.next() orelse {
        std.debug.print("error: missing archive path\n", .{});
        return;
    };

    const archiveFile = std.fs.cwd().openFile(archiveFilename, .{}) catch |err| {
        std.debug.print("error: failed to open archive: {s}\n", .{@errorName(err)});
        return;
    };
    defer archiveFile.close();

    var parsed = narz.Parser.parseFromReader(alloc, archiveFile.reader()) catch |err| {
        std.debug.print("error: failed to parse archive: {s}\n", .{@errorName(err)});
        return;
    };
    defer parsed.deinit();

    const archive = parsed.value;

    const repr = try archive.stringRepr(alloc);
    defer alloc.free(repr);

    std.debug.print("{s}", .{repr});
}
