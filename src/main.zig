const std = @import("std");
const narz = @import("narz");

pub fn main() !void {
    std.debug.print("Goodbye, cruel world!\n", .{});
    std.debug.print("1 + 2 = {d}", .{narz.add(1, 2)});
}
