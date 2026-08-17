//! Compile-only gate. Not part of the shipped binary.
//!
//! Zig analyses declarations lazily: a function nothing references is parsed
//! but never type-checked. So `zig build` can succeed while whole functions
//! are broken, and the breakage surfaces only when someone finally calls one.
//! That is not hypothetical here — `channel.zig` shipped a `send`/`recv` pair
//! that had never compiled, and `main.zig` carried a dead `initWss` built
//! against an older reverb API.
//!
//! This file forces the compiler to analyse every module under `src/` and
//! every public declaration those modules expose. `build.zig` verifies that
//! every `.zig` file under `src/` appears below, so a new file cannot silently
//! opt out.
//!
//! Referenced only by the `check` build step, which `zig build` and
//! `zig build test` both depend on.

const std = @import("std");
const builtin = @import("builtin");

/// Every source file under `src/`, except `src/templates/` — those are
/// `@embedFile` payloads for scaffolded projects, not modules of this program.
/// They are written against vapor's API and cannot compile here.
const modules = .{
    @import("Time.zig"),
    @import("ansi-escape.zig"),
    @import("check.zig"),
    @import("file_contents.zig"),
    @import("fs_watcher.zig"),
    @import("main.zig"),
    @import("metal_config.zig"),
    @import("metal_ui.zig"),
    @import("posix.zig"),
    @import("proc_state.zig"),
    @import("spinner.zig"),
    @import("techy_spinner.zig"),
    @import("tests.zig"),
    @import("time/epoch.zig"),
    @import("watcher.zig"),
};

/// How far to descend into nested public types. Anything deeper is only
/// reached if a shallower declaration refers to it.
const max_depth = 4;

/// Takes a reference to every public declaration of `T` — which is what makes
/// the compiler analyse it — then recurses into public container types.
///
/// Generic functions are named but not addressed: they have no body until
/// instantiated with concrete arguments.
fn refAll(comptime T: type, comptime depth: usize) void {
    if (depth == 0) return;
    inline for (comptime std.meta.declarations(T)) |decl| {
        const Value = @TypeOf(@field(T, decl.name));

        if (Value == type) {
            const Decl = @field(T, decl.name);
            switch (@typeInfo(Decl)) {
                .@"struct", .@"enum", .@"union", .@"opaque" => {
                    if (comptime isOurs(Decl)) refAll(Decl, depth - 1);
                },
                else => {},
            }
            continue;
        }

        switch (@typeInfo(Value)) {
            // Naming a declaration analyses its type; taking its address is
            // what additionally pulls in a function's body.
            .@"fn" => |info| {
                if (info.is_generic or info.is_var_args) {
                    _ = @field(T, decl.name);
                } else {
                    _ = &@field(T, decl.name);
                }
            },
            else => _ = @field(T, decl.name),
        }
    }
}

/// Keeps the recursion inside this program. Without it `refAll` walks into
/// `std` and `reverb` through re-exported types, and the check takes minutes
/// instead of seconds — while reporting problems that are not ours.
fn isOurs(comptime T: type) bool {
    const name = @typeName(T);
    inline for (.{ "std.", "builtin.", "reverb.", "loom.", "pg.", "os." }) |foreign| {
        if (std.mem.startsWith(u8, name, foreign)) return false;
    }
    return true;
}

/// Exported so it is always analysed, and with it everything it reaches.
/// Never called.
export fn __metal_check() void {
    inline for (modules) |module| refAll(module, max_depth);
}
