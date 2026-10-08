//! Process-wide shutdown plumbing.
//!
//! Stores the PID of the most recently spawned child (the user's app under
//! `metal run`) and installs a SIGINT/SIGTERM handler that:
//!   1. Forwards the signal to the child so it can exit cleanly,
//!   2. Restores the terminal (cursor on, attributes reset, raw mode off),
//!   3. Calls _exit(130) — the conventional exit code for SIGINT.
//!
//! Signal handlers can only call async-signal-safe APIs, which is why we use
//! `std.c.write` / `std.c.kill` / `std.c._exit` directly instead of the
//! higher-level Zig wrappers.

const std = @import("std");
const builtin = @import("builtin");

/// PID of the watcher's currently running child process. 0 means no child.
/// Updated atomically by the watcher when it spawns/reaps.
pub var child_pid: std.atomic.Value(i32) = std.atomic.Value(i32).init(0);

/// Saved termios so the signal handler can restore the terminal if the watcher
/// is in raw mode at the time of SIGINT. `raw_mode_fd == -1` means raw mode is
/// not active.
var saved_termios: ?std.posix.termios = null;
var raw_mode_fd: std.posix.fd_t = -1;

pub fn rememberRawMode(fd: std.posix.fd_t, original: std.posix.termios) void {
    raw_mode_fd = fd;
    saved_termios = original;
}

pub fn forgetRawMode() void {
    saved_termios = null;
    raw_mode_fd = -1;
}

/// Cleared by main's colour policy when output is not a terminal. Read from
/// the signal handler, which a plain bool load keeps async-signal-safe.
pub var emit_escapes: bool = true;

fn restoreTerminal() void {
    if (saved_termios) |t| {
        // tcsetattr is async-signal-safe on POSIX.
        std.posix.tcsetattr(raw_mode_fd, .NOW, t) catch {};
    }
    // Show cursor + reset SGR + newline so the next prompt isn't glued to output.
    const reset_seq: []const u8 = if (emit_escapes) "\x1b[?25h\x1b[0m\n" else "\n";
    _ = std.c.write(1, reset_seq.ptr, reset_seq.len);
}

fn handler(_: std.posix.SIG) callconv(.c) void {
    const pid = child_pid.load(.acquire);
    if (pid > 0) {
        // SIGTERM gives the child a chance to clean up. Ignore the return value.
        _ = std.c.kill(@intCast(pid), std.posix.system.SIG.TERM);
    }
    restoreTerminal();
    std.c._exit(130);
}

/// Install SIGINT and SIGTERM handlers. No-op on Windows.
pub fn install() void {
    if (builtin.os.tag == .windows) return;

    var act: std.posix.Sigaction = .{
        .handler = .{ .handler = handler },
        .mask = std.posix.sigemptyset(),
        .flags = 0,
    };
    std.posix.sigaction(std.posix.system.SIG.INT, &act, null);
    std.posix.sigaction(std.posix.system.SIG.TERM, &act, null);
}
