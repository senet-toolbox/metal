//! Test root.
//!
//! Zig only runs test blocks in files that are part of the compilation, so a
//! module nobody imports is silently untested. Everything with tests gets
//! imported here, and `zig build test` uses this file as its root.

test {
    _ = @import("main.zig");
    _ = @import("Time.zig");
    _ = @import("time/epoch.zig");
}
