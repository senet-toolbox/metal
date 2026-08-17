// watcher.zig - Vapor Dev Server with Techy UI
const std = @import("std");
const fs = std.fs;
const process = std.process;
const time = std.time;
const heap = std.heap;
const Reverb = @import("reverb");
const ui = @import("techy_spinner.zig");
const builtin = @import("builtin");
const proc_state = @import("proc_state.zig");
const fs_watcher = @import("fs_watcher.zig");
const Time = @import("Time.zig");
const posix = @import("posix.zig");

pub const Config = struct {
    watch_paths: []const []const u8 = &.{"src"},
    build_command: []const []const u8 = &.{ "zig", "build" },
    make_command: []const []const u8 = &.{ "zig", "build" },
    run_dev_command: []const []const u8 = &.{ "zig", "run", "src/main.zig" },
    run_command: []const []const u8 = &.{"zig-out/bin/app"},
    file_extensions: []const []const u8 = &.{ ".zig", ".html", ".md" },
    exclude_dirs: []const []const u8 = &.{ "zig-cache", "zig-out" },
    debounce_ms: u64 = 100,
    project_name: []const u8 = "vapor-app",
    open_on_start: bool = false,
    app_host: []const u8 = "localhost",
    app_port: u16 = 5173,
    enable_keyboard_shortcuts: bool = true,
    process_environ: std.process.Environ = .empty,
    start_websocket_server: bool = true,
    notify_websocket: ?*const fn ([]const u8) void = null,
    /// When set, spawn this command after a successful build without waiting
    /// for it to exit.  The process is killed before the next rebuild.
    /// Useful for backend frameworks that are their own server.
    run_after_build: ?[]const []const u8 = null,
};

const InputState = struct {
    mutex: std.Io.Mutex = .{ .state = .{ .raw = .unlocked } },
    reload_requested: bool = false,
    open_requested: bool = false,
    quit_requested: bool = false,
    clear_requested: bool = false,
    help_requested: bool = false,
};

const RequestedInput = struct {
    reload: bool,
    open: bool,
    quit: bool,
    clear: bool,
    help: bool,
};

const WatchContext = struct {
    allocator: std.mem.Allocator,
    config: Config,
    last_mod_times: std.StringHashMap(i128),
    child_process: ?std.process.Child = null,
    is_first_build: bool = true,
    input_state: *InputState,
    threaded: std.Io.Threaded = undefined,
    io: std.Io = undefined,

    pub fn init(allocator: std.mem.Allocator, config: Config, input_state: *InputState) !*WatchContext {
        const ctx = try allocator.create(WatchContext);
        ctx.* = .{
            .allocator = allocator,
            .config = config,
            .last_mod_times = std.StringHashMap(i128).init(allocator),
            .input_state = input_state,
            .threaded = std.Io.Threaded.init(allocator, .{
                .environ = config.process_environ,
            }),
        };
        ctx.io = ctx.threaded.io();
        return ctx;
    }

    pub fn deinit(self: *WatchContext) void {
        var it = self.last_mod_times.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.last_mod_times.deinit();
        self.allocator.destroy(self);
    }

    fn shouldWatch(self: *WatchContext, path: []const u8) bool {
        for (self.config.file_extensions) |ext| {
            if (std.mem.endsWith(u8, path, ext)) {
                for (self.config.exclude_dirs) |excluded| {
                    if (std.mem.indexOf(u8, path, excluded) != null) {
                        return false;
                    }
                }
                return true;
            }
        }
        return false;
    }

    fn killCurrentProcess(self: *WatchContext) !void {
        if (self.child_process) |*child| {
            child.kill(self.io);
            self.child_process = null;
            proc_state.child_pid.store(0, .release);
        }
    }

    fn sendWebSocketText(self: *WatchContext, message: []const u8) void {
        if (self.config.notify_websocket) |notify| {
            notify(message);
        } else {
            sendCurrentWsText(message);
        }
    }

    fn printBuildDiagnostics(_: *WatchContext, stdout: []const u8, stderr: []const u8) void {
        const trimmed_stderr = std.mem.trim(u8, stderr, "\r\n");
        const trimmed_stdout = std.mem.trim(u8, stdout, "\r\n");

        if (trimmed_stderr.len == 0 and trimmed_stdout.len == 0) return;

        std.debug.print("\n", .{});
        if (trimmed_stderr.len > 0) {
            std.debug.print("{s}stderr:{s}\n{s}\n", .{ ui.Ansi.dim, ui.Ansi.reset, trimmed_stderr });
        }
        if (trimmed_stdout.len > 0) {
            if (trimmed_stderr.len > 0) std.debug.print("\n", .{});
            std.debug.print("{s}stdout:{s}\n{s}\n", .{ ui.Ansi.dim, ui.Ansi.reset, trimmed_stdout });
        }
        std.debug.print("\n", .{});
    }

    fn buildAndRun(self: *WatchContext) !void {
        try self.killCurrentProcess();

        // Notify WebSocket clients that we're reloading
        // try reloading();
        self.sendWebSocketText("reloading");

        // Keep the primary CLI banner visible; don't redraw/clear on first watcher build.
        if (self.is_first_build) {
            self.is_first_build = false;
        }

        // Initialize build display
        var display = ui.BuildDisplay.init(self.allocator);
        try display.start();

        // Spawn the build process with HIDDEN output (no more LLVM spam!)
        // var child = std.process.Child.init(self.config.make_command, self.allocator);
        // child.stdout_behavior = .Pipe; // Hide stdout
        // child.stderr_behavior = .Pipe; // Hide stderr (this hides LLVM output)

        var child = try std.process.spawn(self.io, .{
            .argv = self.config.make_command,
        });

        // try child.spawn();
        proc_state.child_pid.store(child.id.?, .release);

        // Simulate build phases while waiting
        display.setPhase(.parsing);
        //Time.sleep(300 * std.time.ns_per_ms);

        display.setPhase(.analyzing);
        //Time.sleep(300 * std.time.ns_per_ms);

        display.setPhase(.codegen);

        // Wait for build to complete
        const result = child.wait(self.io) catch |err| {
            proc_state.child_pid.store(0, .release);
            return err;
        };
        proc_state.child_pid.store(0, .release);

        // Check result and show appropriate message
        switch (result) {
            .exited => |code| {
                if (code == 0) {
                    display.setPhase(.complete);
                    display.setProgress(1.0);
                    Time.sleep(100 * std.time.ns_per_ms);
                    display.success("Hot reload complete!");
                    self.sendWebSocketText("refresh");

                    // For backend frameworks: spawn the server process
                    // after a successful build (don't wait — it runs until
                    // killed on next rebuild).
                    if (self.config.run_after_build) |run_argv| {
                        const run_child = try std.process.spawn(self.io, .{
                            .argv = run_argv,
                        });
                        proc_state.child_pid.store(run_child.id.?, .release);
                        self.child_process = run_child;
                    }
                } else {
                    // On failure, we might want to show the error
                    // Read stderr to get the actual error message
                    display.fail("Build failed - check your code");

                    // Optionally show error output
                    if (child.stderr) |stderr| {
                        var err_buffer: [4096]u8 = undefined;
                        var file_reader = stderr.reader(self.io, err_buffer[0..]);
                        const err_output = file_reader.interface.allocRemaining(self.allocator, .limited(4096)) catch "";
                        if (err_output.len > 0) {
                            std.debug.print("\n{s}{s}Error Details:{s}\n", .{
                                ui.Ansi.dim,
                                ui.Ansi.bright_red,
                                ui.Ansi.reset,
                            });
                            // Show first few lines of error
                            var lines = std.mem.splitScalar(u8, err_output, '\n');
                            var count: usize = 0;
                            while (lines.next()) |line| {
                                if (count >= 5) {
                                    std.debug.print("{s}  ... (more errors){s}\n", .{ ui.Ansi.dim, ui.Ansi.reset });
                                    break;
                                }
                                if (line.len > 0) {
                                    std.debug.print("  {s}{s}{s}\n", .{ ui.Ansi.dim, line, ui.Ansi.reset });
                                    count += 1;
                                }
                            }
                            std.debug.print("\n", .{});
                        }
                    }
                }
            },
            else => {
                display.fail("Build interrupted");
            },
        }
    }

    fn scanForChanges(self: *WatchContext) !?[]const u8 {
        const cwd = std.Io.Dir.cwd();
        var first_changed_path: ?[]const u8 = null;

        for (self.config.watch_paths) |watch_path| {
            var dir = try cwd.openDir(self.io, watch_path, .{ .iterate = true });
            defer dir.close(self.io);

            var walker = try dir.walk(self.allocator);
            defer walker.deinit();

            while (try walker.next(self.io)) |entry| {
                const path = try std.fs.path.join(self.allocator, &.{ watch_path, entry.path });

                if (!self.shouldWatch(path)) {
                    self.allocator.free(path);
                    continue;
                }

                const stat = try cwd.statFile(self.io, path, .{});
                const mod_time = stat.mtime.nanoseconds;

                if (self.last_mod_times.getEntry(path)) |existing| {
                    if (existing.value_ptr.* != mod_time) {
                        existing.value_ptr.* = mod_time;
                        if (first_changed_path == null) first_changed_path = existing.key_ptr.*;
                    }
                    self.allocator.free(path);
                    continue;
                }

                self.last_mod_times.put(path, mod_time) catch |err| {
                    self.allocator.free(path);
                    return err;
                };
                if (first_changed_path == null) first_changed_path = path;
            }
        }

        return first_changed_path;
    }

    // fn buildAndRun(self: *WatchContext) !void {
    //     const output_limit = 1024 * 1024;
    //
    //     try self.killCurrentProcess();
    //
    //     // Notify WebSocket clients that we're reloading
    //     self.sendWebSocketText("reloading");
    //
    //     // Keep the primary CLI banner visible; don't redraw/clear on first watcher build.
    //     if (self.is_first_build) {
    //         self.is_first_build = false;
    //     }
    //
    //     // Initialize build display
    //     var display = ui.BuildDisplay.init(self.allocator);
    //     try display.start();
    //     errdefer display.stop();
    //
    //     var child = try std.process.spawn(self.io, .{
    //         .argv = self.config.make_command,
    //         .stdin = .ignore,
    //         .stdout = .pipe,
    //         .stderr = .pipe,
    //     });
    //
    //     proc_state.child_pid.store(child.id.?, .release);
    //     defer proc_state.child_pid.store(0, .release);
    //
    //     var multi_reader_buffer: std.Io.File.MultiReader.Buffer(2) = undefined;
    //     var multi_reader: std.Io.File.MultiReader = undefined;
    //     multi_reader.init(self.allocator, self.io, multi_reader_buffer.toStreams(), &.{ child.stdout.?, child.stderr.? });
    //     defer multi_reader.deinit();
    //
    //     const stdout_reader = multi_reader.reader(0);
    //     const stderr_reader = multi_reader.reader(1);
    //
    //     // Simulate build phases while waiting
    //     display.setPhase(.parsing);
    //     //Time.sleep(300 * std.time.ns_per_ms);
    //
    //     display.setPhase(.analyzing);
    //     //Time.sleep(300 * std.time.ns_per_ms);
    //
    //     display.setPhase(.codegen);
    //
    //     while (multi_reader.fill(4096, .none)) |_| {
    //         if (stdout_reader.buffered().len > output_limit or stderr_reader.buffered().len > output_limit) {
    //             child.kill(self.io);
    //             display.fail("Build output exceeded 1 MiB");
    //             return;
    //         }
    //     } else |err| switch (err) {
    //         error.EndOfStream => {},
    //         else => return err,
    //     }
    //
    //     try multi_reader.checkAnyError();
    //
    //     const result = try child.wait(self.io);
    //     const stdout_output = try multi_reader.toOwnedSlice(0);
    //     defer self.allocator.free(stdout_output);
    //     const stderr_output = try multi_reader.toOwnedSlice(1);
    //     defer self.allocator.free(stderr_output);
    //
    //     // Check result and show appropriate message
    //     switch (result) {
    //         .exited => |code| {
    //             if (code == 0) {
    //                 display.setPhase(.complete);
    //                 display.setProgress(1.0);
    //                 Time.sleep(100 * std.time.ns_per_ms);
    //                 display.success("Hot reload complete!");
    //                 self.sendWebSocketText("refresh");
    //             } else {
    //                 display.fail("Build failed");
    //                 self.printBuildDiagnostics(stdout_output, stderr_output);
    //             }
    //         },
    //         else => {
    //             display.fail("Build interrupted");
    //             self.printBuildDiagnostics(stdout_output, stderr_output);
    //         },
    //     }
    // }

    fn openAppUrl(self: *WatchContext) !void {
        const url = try std.fmt.allocPrint(self.allocator, "http://{s}:{d}", .{
            self.config.app_host,
            self.config.app_port,
        });
        defer self.allocator.free(url);

        var cmd: []const []const u8 = undefined;
        switch (builtin.os.tag) {
            .macos => cmd = &.{ "open", url },
            .linux => cmd = &.{ "xdg-open", url },
            .windows => cmd = &.{ "cmd", "/C", "start", "", url },
            else => {
                std.debug.print(
                    "{s}Auto-open not supported on this OS{s}\n",
                    .{ ui.Ansi.bright_yellow, ui.Ansi.reset },
                );
                return;
            },
        }

        var child = try std.process.spawn(self.io, .{
            .argv = cmd,
            .stderr = .ignore,
            .stdout = .ignore,
        });

        _ = try child.wait(self.io);

        std.debug.print(
            "{s}Opened {s}{s}\n",
            .{ ui.Ansi.dim, url, ui.Ansi.reset },
        );
    }
};

fn consumeInput(state: *InputState) RequestedInput {
    std.Io.Threaded.mutexLock(&state.mutex);
    defer std.Io.Threaded.mutexUnlock(&state.mutex);

    const requested: RequestedInput = .{
        .reload = state.reload_requested,
        .open = state.open_requested,
        .quit = state.quit_requested,
        .clear = state.clear_requested,
        .help = state.help_requested,
    };
    state.reload_requested = false;
    state.open_requested = false;
    state.clear_requested = false;
    state.help_requested = false;
    // quit_requested is sticky — once set, the watcher should exit.
    return requested;
}

fn printShortcutsHelp() void {
    std.debug.print("\n  {s}Shortcuts:{s}\n", .{ ui.Ansi.bright_cyan, ui.Ansi.reset });
    std.debug.print("    {s}r{s}  rebuild now\n", .{ ui.Ansi.bright_yellow, ui.Ansi.reset });
    std.debug.print("    {s}o{s}  open app in browser\n", .{ ui.Ansi.bright_yellow, ui.Ansi.reset });
    std.debug.print("    {s}c{s}  clear screen\n", .{ ui.Ansi.bright_yellow, ui.Ansi.reset });
    std.debug.print("    {s}?{s}  this help\n", .{ ui.Ansi.bright_yellow, ui.Ansi.reset });
    std.debug.print("    {s}q{s}  quit\n\n", .{ ui.Ansi.bright_yellow, ui.Ansi.reset });
}

fn keyboardInputLoop(ctx: *WatchContext) !void {
    if (!ctx.config.enable_keyboard_shortcuts) return;
    if (builtin.os.tag == .windows) return;

    const stdin_fd = std.posix.STDIN_FILENO;

    // Only enter raw mode if stdin is a tty — otherwise reads would burn CPU
    // and termios calls would fail.
    if (!posix.isatty(stdin_fd)) return;

    const original = posix.tcgetattr(stdin_fd) catch return;
    var raw = original;
    // Disable canonical line buffering and echo, but KEEP ISIG so Ctrl-C still
    // delivers SIGINT to our handler in proc_state.zig.
    raw.lflag.ECHO = false;
    raw.lflag.ICANON = false;

    posix.tcsetattr(stdin_fd, .NOW, raw) catch return;
    proc_state.rememberRawMode(stdin_fd, original);
    defer {
        posix.tcsetattr(stdin_fd, .NOW, original) catch {};
        proc_state.forgetRawMode();
    }

    var byte: [1]u8 = undefined;
    while (true) {
        const n = std.posix.read(stdin_fd, &byte) catch |err| switch (err) {
            error.WouldBlock => continue,
            else => return,
        };
        if (n == 0) return; // EOF
        const key = std.ascii.toLower(byte[0]);

        std.Io.Threaded.mutexLock(&ctx.input_state.mutex);
        switch (key) {
            'r' => ctx.input_state.reload_requested = true,
            'o' => ctx.input_state.open_requested = true,
            'c' => ctx.input_state.clear_requested = true,
            '?', 'h' => ctx.input_state.help_requested = true,
            'q' => {
                ctx.input_state.quit_requested = true;
                std.Io.Threaded.mutexUnlock(&ctx.input_state.mutex);
                return;
            },
            else => {},
        }
        std.Io.Threaded.mutexUnlock(&ctx.input_state.mutex);
    }
}

fn watchFiles(self: *WatchContext) !void {
    // Initial file scan to populate mod times
    _ = try self.scanForChanges();

    // Initial build
    try self.buildAndRun();

    // Show server ready message
    ui.serverReady(self.config.app_port);
    std.debug.print(
        "{s}Shortcuts:{s} {s}r{s} reload  {s}o{s} open  {s}c{s} clear  {s}?{s} help  {s}q{s} quit\n",
        .{
            ui.Ansi.dim,         ui.Ansi.reset,
            ui.Ansi.bright_cyan, ui.Ansi.reset,
            ui.Ansi.bright_cyan, ui.Ansi.reset,
            ui.Ansi.bright_cyan, ui.Ansi.reset,
            ui.Ansi.bright_cyan, ui.Ansi.reset,
            ui.Ansi.bright_cyan, ui.Ansi.reset,
        },
    );

    if (self.config.open_on_start) {
        self.openAppUrl() catch |err| {
            std.debug.print("{s}Failed to open browser: {s}{s}\n", .{
                ui.Ansi.bright_yellow,
                @errorName(err),
                ui.Ansi.reset,
            });
        };
    }

    // Try to set up a native filesystem-event watcher. If it fails, fall back
    // to pure polling (the loop below already handles either case via the
    // is_native flag).
    var maybe_fs_watcher: ?fs_watcher.Watcher = fs_watcher.Watcher.init(
        self.allocator,
        self.config.watch_paths,
    ) catch |err| blk: {
        std.debug.print(
            "{s}fs_watcher init failed ({s}); using polling{s}\n",
            .{ ui.Ansi.dim, @errorName(err), ui.Ansi.reset },
        );
        break :blk null;
    };
    defer if (maybe_fs_watcher) |*w| w.deinit();

    const using_native = maybe_fs_watcher != null and fs_watcher.Watcher.is_native;

    if (try self.scanForChanges()) |changed_path| {
        ui.fileChanged(changed_path);
        try self.buildAndRun();
    }

    // Watch loop
    std.debug.print(
        "{s}Watching for changes... ({s}){s}\n",
        .{
            ui.Ansi.dim,
            if (using_native) "native fs events" else "polling",
            ui.Ansi.reset,
        },
    );

    while (true) {
        const requested = consumeInput(self.input_state);

        if (requested.reload) {
            std.debug.print(
                "{s}Manual reload requested{s}\n",
                .{ ui.Ansi.bright_cyan, ui.Ansi.reset },
            );
            try self.buildAndRun();
            std.debug.print("{s}Watching for changes...{s}\n", .{ ui.Ansi.dim, ui.Ansi.reset });
        }

        if (requested.open) {
            self.openAppUrl() catch |err| {
                std.debug.print("{s}Failed to open browser: {s}{s}\n", .{
                    ui.Ansi.bright_yellow,
                    @errorName(err),
                    ui.Ansi.reset,
                });
            };
        }

        if (requested.clear) {
            std.debug.print("{s}", .{ui.Ansi.clear_screen});
            ui.serverReady(self.config.app_port);
            std.debug.print("{s}Watching for changes...{s}\n", .{ ui.Ansi.dim, ui.Ansi.reset });
        }

        if (requested.help) {
            printShortcutsHelp();
        }

        if (requested.quit) {
            std.debug.print(
                "\n{s}Shutting down...{s}\n",
                .{ ui.Ansi.bright_cyan, ui.Ansi.reset },
            );
            self.killCurrentProcess() catch {};
            return;
        }

        // Wait for filesystem activity (or the input thread, indirectly via
        // its 150ms cap). Native backends return immediately on real changes
        // and otherwise sleep efficiently; the polling fallback just sleeps.
        const should_scan = if (maybe_fs_watcher) |*w|
            w.wait(150)
        else blk: {
            Time.sleep(150 * std.time.ns_per_ms);
            break :blk true;
        };

        if (should_scan) {
            if (try self.scanForChanges()) |changed_path| {
                ui.fileChanged(changed_path);
                try self.buildAndRun();
                std.debug.print("{s}Watching for changes...{s}\n", .{ ui.Ansi.dim, ui.Ansi.reset });
            }
        } else {
            continue;
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  WebSocket Handlers
// ═══════════════════════════════════════════════════════════════════════════════

var current_ws: ?*Reverb.WebSocket = null;
var ws_mutex: std.Io.Mutex = .{ .state = .{ .raw = .unlocked } };

// Simple ring buffer for cross-thread WS messages (watcher → sender thread).
const WS_QUEUE_SIZE = 8;
var ws_queue: [WS_QUEUE_SIZE][]const u8 = undefined;
var ws_queue_head: usize = 0; // next write slot
var ws_queue_tail: usize = 0; // next read slot
var ws_queue_ready: bool = false;

fn wsQueuePush(message: []const u8) void {
    std.Io.Threaded.mutexLock(&ws_mutex);
    defer std.Io.Threaded.mutexUnlock(&ws_mutex);
    const next_head = (ws_queue_head + 1) % WS_QUEUE_SIZE;
    if (next_head == ws_queue_tail) return; // full, drop message
    ws_queue[ws_queue_head] = message;
    ws_queue_head = next_head;
}

fn wsQueuePop() ?[]const u8 {
    std.Io.Threaded.mutexLock(&ws_mutex);
    defer std.Io.Threaded.mutexUnlock(&ws_mutex);
    if (ws_queue_tail == ws_queue_head) return null;
    const message = ws_queue[ws_queue_tail];
    ws_queue_tail = (ws_queue_tail + 1) % WS_QUEUE_SIZE;
    return message;
}

fn onConnection(ws: *Reverb.WebSocket, _: *Reverb.Context) !void {
    std.debug.print("Client connected\n", .{});
    std.Io.Threaded.mutexLock(&ws_mutex);
    current_ws = ws;
    std.Io.Threaded.mutexUnlock(&ws_mutex);
    try ws.sendText("connected");
}

fn onMessage(_: *Reverb.WebSocket, message: Reverb.WebSocket.Message, _: *Reverb.Context) !void {
    switch (message) {
        .Text => |text| {
            std.debug.print("{s}Message: {s}{s}\n", .{ ui.Ansi.dim, text, ui.Ansi.reset });
        },
        .Close => {
            std.Io.Threaded.mutexLock(&ws_mutex);
            current_ws = null;
            std.Io.Threaded.mutexUnlock(&ws_mutex);
        },
        else => {},
    }
}

/// Pushes a message onto the queue for the sender thread to deliver.
fn sendCurrentWsText(message: []const u8) void {
    if (ws_queue_ready) {
        wsQueuePush(message);
    }
}

/// Runs on its own thread. Polls the queue and sends each message
/// through the WebSocket connection.
fn wsSenderLoop() void {
    while (true) {
        if (wsQueuePop()) |message| {
            std.Io.Threaded.mutexLock(&ws_mutex);
            const ws = current_ws;
            std.Io.Threaded.mutexUnlock(&ws_mutex);
            if (ws) |w| {
                w.sendText(message) catch {
                    std.Io.Threaded.mutexLock(&ws_mutex);
                    current_ws = null;
                    std.Io.Threaded.mutexUnlock(&ws_mutex);
                };
            }
        } else {
            // No messages — sleep briefly to avoid busy-spinning.
            Time.sleep(10 * std.time.ns_per_ms);
        }
    }
}

fn refreshWss() !void {
    sendCurrentWsText("refresh");
}

fn reloading() !void {
    sendCurrentWsText("reloading");
}

fn handleRequest(_: *Reverb.Context) !void {}

const ReverbConfig = struct {
    /// Loopback, matching the dev HTTP server. Loom's own default is 0.0.0.0,
    /// and an unauthenticated reload socket has no business on the network.
    host: []const u8 = "127.0.0.1",
    port: u16 = 3003,
    max: usize = 1024,
    max_body_size: usize = 1024 * 1024 * 10,
};

fn createWSS(port: u16, allocator: std.mem.Allocator) !void {
    var server: Reverb.Server(ReverbConfig) = undefined;
    try server.new(.{
        .port = port,
        .max = 1024,
        .max_body_size = 1024 * 1024 * 10,
    }, allocator, null);
    try server.useWss(.{
        .onConnection = onConnection,
        .onMessage = onMessage,
        .max_body_size = 4 * 1024 * 1024,
    });
    std.debug.print("Listening on port {d}\n", .{port});
    try server.listen();
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Public API
// ═══════════════════════════════════════════════════════════════════════════════

pub fn run(port: u16, allocator: std.mem.Allocator) !void {
    runWithConfig(port, allocator, Config{}) catch {};
}

pub fn runWithConfig(port: u16, allocator: std.mem.Allocator, config: Config) !void {
    const input_state = try allocator.create(InputState);
    input_state.* = .{};
    defer allocator.destroy(input_state);

    const ctx = try WatchContext.init(allocator, config, input_state);
    defer ctx.deinit();

    if (config.start_websocket_server) {
        // Init the WS message queue + sender thread
        ws_queue_ready = true;
        var sender_thread = try std.Thread.spawn(.{}, wsSenderLoop, .{});
        sender_thread.detach();

        // Start WebSocket server in background
        var server_thread = try std.Thread.spawn(.{}, createWSS, .{ port, allocator });
        server_thread.detach();

        Time.sleep(500 * std.time.ns_per_ms);
    }

    if (config.enable_keyboard_shortcuts) {
        var input_thread = try std.Thread.spawn(.{}, keyboardInputLoop, .{ctx});
        input_thread.detach();
    }

    // Start file watcher (this blocks)
    var watcher_thread = try std.Thread.spawn(.{}, watchFiles, .{ctx});
    watcher_thread.join();
}
