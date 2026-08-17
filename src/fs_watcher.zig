//! Cross-platform "wait for filesystem activity" abstraction used by the dev
//! watcher to avoid burning CPU on a fixed polling timer.
//!
//! Backends:
//!   * macOS  — FSEvents (CoreServices) running on a dedicated CFRunLoop thread.
//!   * Linux  — inotify, with recursive directory subscription.
//!   * other  — degraded polling fallback (`wait` just sleeps the timeout).
//!
//! The watcher only signals "something changed somewhere under your roots".
//! The caller is still responsible for re-stat'ing files to confirm which
//! file(s) changed and whether they match the watched extensions. Treat
//! `wait()` as a hint, not a source of truth.

const std = @import("std");
const builtin = @import("builtin");
const posix = @import("posix.zig");
const Main = @import("main.zig");

pub const Watcher = struct {
    impl: *Impl,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, paths: []const []const u8) !Watcher {
        const impl = try Impl.create(allocator, paths);
        return .{ .impl = impl, .allocator = allocator };
    }

    pub fn deinit(self: *Watcher) void {
        self.impl.destroy(self.allocator);
    }

    /// Block up to `timeout_ms` for filesystem activity.
    /// Returns true if the underlying source signaled activity, false on timeout.
    /// On the polling fallback this always returns true after sleeping.
    pub fn wait(self: *Watcher, timeout_ms: u64) bool {
        return self.impl.wait(timeout_ms);
    }

    /// True when this watcher is backed by a real OS event source rather than
    /// the polling fallback. The caller can use this to choose a longer
    /// timeout (since rescans are no longer the only way to learn about
    /// changes).
    pub const is_native: bool = Impl.is_native;
};

const Impl = switch (builtin.os.tag) {
    .macos => MacImpl,
    .linux => LinuxImpl,
    else => PollImpl,
};

// ─── macOS: FSEvents ────────────────────────────────────────────────────────

/// Manual CoreServices/CoreFoundation bindings – replaces @cImport which
/// fails on Zig 0.16 due to sub-framework header resolution issues.
const c = if (builtin.os.tag == .macos) struct {
    // ── opaque handle types ────────────────────────────────────────────
    pub const CFRunLoopRef = ?*anyopaque;
    pub const CFArrayRef = ?*const anyopaque;
    pub const CFStringRef = ?*const anyopaque;
    pub const CFAllocatorRef = ?*anyopaque;
    const FSEventStreamRef = ?*anyopaque;
    pub const ConstFSEventStreamRef = ?*const anyopaque;
    pub const FSEventStreamEventFlags = u32;
    pub const FSEventStreamEventId = u64;

    // ── constants ──────────────────────────────────────────────────────
    pub const kFSEventStreamEventIdSinceNow: FSEventStreamEventId = 0xFFFFFFFFFFFFFFFF;
    pub const kFSEventStreamCreateFlagFileEvents: u32 = 0x00000010;
    pub const kFSEventStreamCreateFlagNoDefer: u32 = 0x00000002;
    pub const kCFStringEncodingUTF8: u32 = 0x08000100;
    pub extern const kCFRunLoopDefaultMode: CFStringRef;
    pub extern const kCFTypeArrayCallBacks: CFArrayCallBacks;

    // ── structs ────────────────────────────────────────────────────────
    pub const CFArrayCallBacks = extern struct {
        version: isize = 0,
        retain: ?*const anyopaque = null,
        release: ?*const anyopaque = null,
        copyDescription: ?*const anyopaque = null,
        equal: ?*const anyopaque = null,
    };

    pub const FSEventStreamContext = extern struct {
        version: isize = 0,
        info: ?*anyopaque = null,
        retain: ?*const anyopaque = null,
        release: ?*const anyopaque = null,
        copyDescription: ?*const anyopaque = null,
    };

    pub const FSEventStreamCallback = *const fn (
        ConstFSEventStreamRef,
        ?*anyopaque,
        usize,
        ?*anyopaque,
        [*c]const FSEventStreamEventFlags,
        [*c]const FSEventStreamEventId,
    ) callconv(.c) void;

    // ── CoreFoundation functions ────────────────────────────────────────
    pub extern fn CFRunLoopGetCurrent() CFRunLoopRef;
    pub extern fn CFRunLoopRun() void;
    pub extern fn CFRunLoopStop(rl: CFRunLoopRef) void;
    pub extern fn CFRelease(cf: ?*const anyopaque) void;
    pub extern fn CFStringCreateWithCString(
        alloc: CFAllocatorRef,
        cstr: [*:0]const u8,
        encoding: u32,
    ) CFStringRef;
    pub extern fn CFArrayCreate(
        alloc: CFAllocatorRef,
        values: ?*const ?*const anyopaque,
        count: isize,
        callbacks: *const CFArrayCallBacks,
    ) CFArrayRef;

    // ── FSEvents functions ─────────────────────────────────────────────
    pub extern fn FSEventStreamCreate(
        alloc: CFAllocatorRef,
        callback: FSEventStreamCallback,
        ctx: *FSEventStreamContext,
        paths: CFArrayRef,
        since: FSEventStreamEventId,
        latency: f64,
        flags: u32,
    ) FSEventStreamRef;
    pub extern fn FSEventStreamScheduleWithRunLoop(
        stream: FSEventStreamRef,
        rl: CFRunLoopRef,
        mode: CFStringRef,
    ) void;
    pub extern fn FSEventStreamStart(stream: FSEventStreamRef) bool;
    pub extern fn FSEventStreamStop(stream: FSEventStreamRef) void;
    pub extern fn FSEventStreamInvalidate(stream: FSEventStreamRef) void;
    pub extern fn FSEventStreamRelease(stream: FSEventStreamRef) void;
} else struct {};

const MacImpl = struct {
    pub const is_native = true;

    pending: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    runloop: c.CFRunLoopRef = null,
    runloop_ready: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    thread: ?std.Thread = null,

    fn callback(
        _: c.ConstFSEventStreamRef,
        client_info: ?*anyopaque,
        _: usize,
        _: ?*anyopaque,
        _: [*c]const c.FSEventStreamEventFlags,
        _: [*c]const c.FSEventStreamEventId,
    ) callconv(.c) void {
        const self: *MacImpl = @ptrCast(@alignCast(client_info.?));
        self.pending.store(true, .release);
    }

    const ThreadArgs = struct {
        self: *MacImpl,
        paths_array: c.CFArrayRef,
    };

    fn threadMain(args: ThreadArgs) void {
        const self = args.self;
        const paths_array = args.paths_array;

        self.runloop = c.CFRunLoopGetCurrent();

        var ctx: c.FSEventStreamContext = .{
            .version = 0,
            .info = self,
            .retain = null,
            .release = null,
            .copyDescription = null,
        };

        const stream = c.FSEventStreamCreate(
            null,
            &callback,
            &ctx,
            paths_array,
            c.kFSEventStreamEventIdSinceNow,
            0.05, // latency seconds — coalesce bursty saves
            c.kFSEventStreamCreateFlagFileEvents | c.kFSEventStreamCreateFlagNoDefer,
        );
        c.CFRelease(paths_array);

        if (stream == null) {
            // Signal readiness even on failure so init() doesn't hang.
            self.runloop_ready.store(true, .release);
            return;
        }

        c.FSEventStreamScheduleWithRunLoop(stream, self.runloop, c.kCFRunLoopDefaultMode);
        _ = c.FSEventStreamStart(stream);
        self.runloop_ready.store(true, .release);

        c.CFRunLoopRun();

        c.FSEventStreamStop(stream);
        c.FSEventStreamInvalidate(stream);
        c.FSEventStreamRelease(stream);
    }

    pub fn create(allocator: std.mem.Allocator, paths: []const []const u8) !*MacImpl {
        const self = try allocator.create(MacImpl);
        errdefer allocator.destroy(self);
        self.* = .{};

        // Build a CFArray of CFString path entries. We resolve each path to
        // its absolute form so FSEvents can map deliveries back correctly even
        // if the working directory changes later.
        const cf_strings = try allocator.alloc(c.CFStringRef, paths.len);
        defer allocator.free(cf_strings);

        var resolved: usize = 0;
        errdefer {
            var i: usize = 0;
            while (i < resolved) : (i += 1) c.CFRelease(cf_strings[i]);
        }

        for (paths, 0..) |p, i| {
            const z = try allocator.dupeZ(u8, p);
            defer allocator.free(z);
            const cs = c.CFStringCreateWithCString(null, z.ptr, c.kCFStringEncodingUTF8);
            if (cs == null) return error.OutOfMemory;
            cf_strings[i] = cs;
            resolved = i + 1;
        }

        const paths_array = c.CFArrayCreate(
            null,
            @ptrCast(cf_strings.ptr),
            @intCast(paths.len),
            &c.kCFTypeArrayCallBacks,
        );
        if (paths_array == null) return error.OutOfMemory;

        // Ownership transfers to the thread (which calls CFRelease).
        resolved = 0;

        self.thread = try std.Thread.spawn(.{}, threadMain, .{ThreadArgs{
            .self = self,
            .paths_array = paths_array,
        }});

        // Wait for the run loop to be set up so destroy() can stop it cleanly.
        while (!self.runloop_ready.load(.acquire)) {
            _ = std.c.nanosleep(&std.c.timespec{ .sec = 0, .nsec = 1_000_000 }, null); // 1ms
        }
        return self;
    }

    pub fn destroy(self: *MacImpl, allocator: std.mem.Allocator) void {
        if (self.runloop != null) {
            c.CFRunLoopStop(self.runloop);
        }
        if (self.thread) |t| t.join();
        allocator.destroy(self);
    }

    pub fn wait(self: *MacImpl, timeout_ms: u64) bool {
        // Fast path: already signaled.
        if (self.pending.cmpxchgStrong(true, false, .acquire, .monotonic) == null)
            return true;

        const timeout_ns: u64 = timeout_ms * std.time.ns_per_ms;
        const poll_ns: u64 = 10 * std.time.ns_per_ms; // 10ms poll interval
        var elapsed: u64 = 0;
        while (elapsed < timeout_ns) {
            const sleep_ns: u64 = @min(poll_ns, timeout_ns - elapsed);
            _ = std.c.nanosleep(&std.c.timespec{ .sec = @intCast(sleep_ns / std.time.ns_per_s), .nsec = @intCast(sleep_ns % std.time.ns_per_s) }, null);
            elapsed += sleep_ns;
            if (self.pending.cmpxchgStrong(true, false, .acquire, .monotonic) == null)
                return true;
        }
        return false;
    }
};

// ─── Linux: inotify ─────────────────────────────────────────────────────────

const LinuxImpl = struct {
    pub const is_native = true;

    fd: std.posix.fd_t = -1,

    pub fn create(allocator: std.mem.Allocator, paths: []const []const u8) !*LinuxImpl {
        const self = try allocator.create(LinuxImpl);
        errdefer allocator.destroy(self);

        const fd = try posix.inotify_init1(std.os.linux.IN.NONBLOCK);
        errdefer posix.close(fd);
        self.* = .{ .fd = fd };

        const mask: u32 =
            std.os.linux.IN.MODIFY |
            std.os.linux.IN.CREATE |
            std.os.linux.IN.DELETE |
            std.os.linux.IN.MOVED_FROM |
            std.os.linux.IN.MOVED_TO |
            std.os.linux.IN.ATTRIB;

        for (paths) |p| {
            try addRecursive(allocator, fd, p, mask);
        }
        return self;
    }

    fn addRecursive(
        allocator: std.mem.Allocator,
        fd: std.posix.fd_t,
        root: []const u8,
        mask: u32,
    ) !void {
        // Add the root itself first.
        const root_z = try allocator.dupeZ(u8, root);
        defer allocator.free(root_z);
        _ = std.posix.inotify_add_watch(fd, root_z, mask) catch return;

        var dir = std.Io.Dir.cwd().openDir(Main.main_init.io, root, .{ .iterate = true }) catch return;
        defer dir.close(Main.main_init.io);

        var walker = try dir.walk(allocator);
        defer walker.deinit();

        while (try walker.next()) |entry| {
            if (entry.kind != .directory) continue;
            const sub = try std.fs.path.join(allocator, &.{ root, entry.path });
            defer allocator.free(sub);
            const sub_z = try allocator.dupeZ(u8, sub);
            defer allocator.free(sub_z);
            _ = std.posix.inotify_add_watch(fd, sub_z, mask) catch {};
        }
    }

    pub fn destroy(self: *LinuxImpl, allocator: std.mem.Allocator) void {
        if (self.fd >= 0) std.posix.close(self.fd);
        allocator.destroy(self);
    }

    pub fn wait(self: *LinuxImpl, timeout_ms: u64) bool {
        var pfd = [_]std.posix.pollfd{.{
            .fd = self.fd,
            .events = std.posix.POLL.IN,
            .revents = 0,
        }};
        const r = std.posix.poll(&pfd, @intCast(timeout_ms)) catch return false;
        if (r == 0) return false;

        // Drain whatever events are queued. We don't care which file changed —
        // the caller will rescan to figure that out.
        var buf: [4096]u8 align(@alignOf(std.os.linux.inotify_event)) = undefined;
        while (true) {
            const n = std.posix.read(self.fd, &buf) catch break;
            if (n == 0) break;
        }
        return true;
    }
};

// ─── Fallback: pure polling ─────────────────────────────────────────────────

const PollImpl = struct {
    pub const is_native = false;

    pub fn create(allocator: std.mem.Allocator, _: []const []const u8) !*PollImpl {
        const self = try allocator.create(PollImpl);
        self.* = .{};
        return self;
    }

    pub fn destroy(self: *PollImpl, allocator: std.mem.Allocator) void {
        allocator.destroy(self);
    }

    pub fn wait(_: *PollImpl, timeout_ms: u64) bool {
        const ns = timeout_ms * std.time.ns_per_ms;
        _ = std.c.nanosleep(&std.c.timespec{ .sec = @intCast(ns / std.time.ns_per_s), .nsec = @intCast(ns % std.time.ns_per_s) }, null);
        return true;
    }
};
