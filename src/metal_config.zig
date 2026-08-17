//! Project-local config loaded from `metal.zon` (or `.metal.zon`) at the
//! current working directory. Every field is optional in the on-disk schema;
//! values not specified fall back to compiled-in defaults.
//!
//! Example `metal.zon`:
//!
//!     .{
//!         .port = 5173,
//!         .host = "localhost",
//!         .open_on_start = false,
//!         .watch_paths = .{ "src", "assets" },
//!         .file_extensions = .{ ".zig", ".html", ".css" },
//!         .exclude_dirs = .{ "zig-cache", "zig-out", "node_modules" },
//!         .build_command = .{ "zig", "build" },
//!     }

const std = @import("std");
const Main = @import("main.zig");

pub const MetalConfig = struct {
    port: ?u16 = null,
    host: ?[]const u8 = null,
    open_on_start: ?bool = null,
    watch_paths: ?[]const []const u8 = null,
    file_extensions: ?[]const []const u8 = null,
    exclude_dirs: ?[]const []const u8 = null,
    build_command: ?[]const []const u8 = null,
};

pub const LoadResult = struct {
    config: MetalConfig,
    path: []const u8, // owned, free with the same allocator
    raw: [:0]const u8, // owned, free with the same allocator
};

/// Tries `metal.zon` then `.metal.zon` in the current directory.
/// Returns null if neither exists. On parse error, prints to stderr and returns null
/// so the CLI can fall back to defaults rather than refusing to start.
pub fn load(allocator: std.mem.Allocator) !?LoadResult {
    const cwd = std.Io.Dir.cwd();
    const candidates = [_][]const u8{ "metal.zon", ".metal.zon" };
    for (candidates) |name| {
        const source = cwd.readFileAllocOptions(
            Main.main_init.io,
            name,
            allocator,
            .unlimited,
            .of(u8),
            0,
        ) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => return err,
        };

        var diag: std.zon.parse.Diagnostics = .{};
        const cfg = std.zon.parse.fromSliceAlloc(
            MetalConfig,
            allocator,
            source,
            &diag,
            .{ .ignore_unknown_fields = true },
        ) catch |err| {
            std.debug.print(
                "metal: failed to parse {s}: {s}\n",
                .{ name, @errorName(err) },
            );
            allocator.free(source);
            return null;
        };

        const path_owned = try allocator.dupe(u8, name);
        return LoadResult{
            .config = cfg,
            .path = path_owned,
            .raw = source,
        };
    }
    return null;
}

pub fn freeLoaded(allocator: std.mem.Allocator, loaded: LoadResult) void {
    std.zon.parse.free(allocator, loaded.config);
    allocator.free(loaded.path);
    allocator.free(loaded.raw);
}
