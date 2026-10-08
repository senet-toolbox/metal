// src/generator.zig
const std = @import("std");
const App = @import("main.zig");

// Import your shared framework/component modules
const Vapor = @import("vapor");

pub fn main() !void {
    App.init();
    Vapor.lib.generate();
    std.debug.print("\nGenerated static pages in release/\n", .{});
}
