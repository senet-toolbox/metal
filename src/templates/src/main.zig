const std = @import("std");
const Vapor = @import("vapor");

/// Called by the JS runtime once vapor.wasm has loaded, and by the static
/// generator (src/generator.zig).
pub export fn init() void {
    Vapor.init(.{});

    // Register every page here.
    @import("routes/Page.zig").init();
}

pub const std_options = std.Options{
    .log_level = .debug,
    .logFn = Vapor.lib.log,
};
