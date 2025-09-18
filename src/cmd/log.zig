//! This module provides functions for logging output.
//! It is a stripped down version of `std.log`, and
//! does not filter output based on build type.

const std = @import("std");
const io = std.io;
const mem = std.mem;
const File = std.fs.File;

const ansi = @import("ansi.zig");
const ANSIFilter = ansi.ANSIFilter;

pub var use_color: bool = true;

/// Print to stderr. This makes sure that ANSI codes are handled
/// according to whether or not they are disabled.
pub fn print(comptime fmt: []const u8, args: anytype) void {
    const stderr = File.stdout().deprecatedWriter();
    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();

    var color_filter = ANSIFilter(@TypeOf(stderr)){
        .raw_writer = stderr,
        .use_color = use_color,
    };
    const writer = color_filter.writer();
    writer.print(fmt, args) catch return;
}

/// Base logging function with no level. Prints a newline automatically.
fn log(comptime prefix: []const u8, comptime fmt: []const u8, args: anytype) void {
    const real_prefix = prefix ++ (if (prefix.len != 0) ": " else "");

    print(real_prefix ++ fmt ++ "\n", args);
}

/// Print an error message, followed by a newline.
pub fn err(comptime fmt: []const u8, args: anytype) void {
    log(ansi.BOLD ++ ansi.RED ++ "error" ++ ansi.RESET, fmt, args);
}

/// Print a warning message, followed by a newline.
pub fn warn(comptime fmt: []const u8, args: anytype) void {
    log(ansi.BOLD ++ ansi.YELLOW ++ "warning" ++ ansi.RESET, fmt, args);
}

/// Print an info message, followed by a newline.
pub fn info(comptime fmt: []const u8, args: anytype) void {
    log(ansi.GREEN ++ "info" ++ ansi.RESET, fmt, args);
}
