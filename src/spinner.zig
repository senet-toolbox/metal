const std = @import("std");
const Main = @import("main.zig");
const Time = @import("Time.zig");

// ═══════════════════════════════════════════════════════════════════════════════
//  Terminal Spinner & Progress Bar
//  A collection of animated loading indicators for CLI applications
// ═══════════════════════════════════════════════════════════════════════════════

// ANSI Color Codes
pub const Color = struct {
    pub var reset: []const u8 = "\x1b[0m";
    pub var bold: []const u8 = "\x1b[1m";
    pub var dim: []const u8 = "\x1b[2m";

    // Standard colors
    pub var black: []const u8 = "\x1b[30m";
    pub var red: []const u8 = "\x1b[31m";
    pub var green: []const u8 = "\x1b[32m";
    pub var yellow: []const u8 = "\x1b[33m";
    pub var blue: []const u8 = "\x1b[34m";
    pub var magenta: []const u8 = "\x1b[35m";
    pub var cyan: []const u8 = "\x1b[36m";
    pub var white: []const u8 = "\x1b[37m";

    // Bright colors
    pub var bright_black: []const u8 = "\x1b[90m";
    pub var bright_red: []const u8 = "\x1b[91m";
    pub var bright_green: []const u8 = "\x1b[92m";
    pub var bright_yellow: []const u8 = "\x1b[93m";
    pub var bright_blue: []const u8 = "\x1b[94m";
    pub var bright_magenta: []const u8 = "\x1b[95m";
    pub var bright_cyan: []const u8 = "\x1b[96m";
    pub var bright_white: []const u8 = "\x1b[97m";

    // Background colors
    pub var bg_blue: []const u8 = "\x1b[44m";
    pub var bg_cyan: []const u8 = "\x1b[46m";
    pub var bg_magenta: []const u8 = "\x1b[45m";

    /// False once disable() runs; gates the hardcoded 256-colour gradient.
    pub var enabled: bool = true;

    pub fn disable() void {
        enabled = false;
        reset = "";
        bold = "";
        dim = "";
        black = "";
        red = "";
        green = "";
        yellow = "";
        blue = "";
        magenta = "";
        cyan = "";
        white = "";
        bright_black = "";
        bright_red = "";
        bright_green = "";
        bright_yellow = "";
        bright_blue = "";
        bright_magenta = "";
        bright_cyan = "";
        bright_white = "";
        bg_blue = "";
        bg_cyan = "";
        bg_magenta = "";
    }
};

// Cursor control
pub const Cursor = struct {
    pub var hide: []const u8 = "\x1b[?25l";
    pub var show: []const u8 = "\x1b[?25h";
    pub var save: []const u8 = "\x1b[s";
    pub var restore: []const u8 = "\x1b[u";
    pub var clear_line: []const u8 = "\x1b[2K";
    pub var move_start: []const u8 = "\r";

    pub fn disable() void {
        hide = "";
        show = "";
        save = "";
        restore = "";
        clear_line = "";
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
//  Spinner Styles
// ═══════════════════════════════════════════════════════════════════════════════

pub const SpinnerStyle = enum {
    dots,
    dots_bounce,
    line,
    arc,
    circle,
    square,
    arrow,
    bounce,
    meteor,
    pulse,
    braille,
    clock,

    pub fn frames(self: SpinnerStyle) []const []const u8 {
        return switch (self) {
            .dots => &[_][]const u8{ "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
            .dots_bounce => &[_][]const u8{ "⠁", "⠂", "⠄", "⠂" },
            .line => &[_][]const u8{ "-", "\\", "|", "/" },
            .arc => &[_][]const u8{ "◜", "◠", "◝", "◞", "◡", "◟" },
            .circle => &[_][]const u8{ "◐", "◓", "◑", "◒" },
            .square => &[_][]const u8{ "◰", "◳", "◲", "◱" },
            .arrow => &[_][]const u8{ "←", "↖", "↑", "↗", "→", "↘", "↓", "↙" },
            .bounce => &[_][]const u8{ "⠁", "⠂", "⠄", "⡀", "⢀", "⠠", "⠐", "⠈" },
            .meteor => &[_][]const u8{ "☄", "💫", "✨", "⭐", "🌟", "💥" },
            .pulse => &[_][]const u8{ "█", "▓", "▒", "░", "▒", "▓" },
            .braille => &[_][]const u8{ "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" },
            .clock => &[_][]const u8{ "🕐", "🕑", "🕒", "🕓", "🕔", "🕕", "🕖", "🕗", "🕘", "🕙", "🕚", "🕛" },
        };
    }

    pub fn interval_ms(self: SpinnerStyle) u64 {
        return switch (self) {
            .dots, .dots_bounce, .braille => 80,
            .line, .arc, .circle, .square, .arrow, .bounce => 100,
            .meteor => 150,
            .pulse => 120,
            .clock => 100,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
//  Animated Spinner
// ═══════════════════════════════════════════════════════════════════════════════

pub const Spinner = struct {
    style: SpinnerStyle,
    message: []const u8,
    color: []const u8,
    frame_index: usize = 0,
    running: bool = false,
    thread: ?std.Thread = null,

    const Self = @This();

    pub fn init(style: SpinnerStyle, message: []const u8) Self {
        return .{
            .style = style,
            .message = message,
            .color = Color.bright_cyan,
        };
    }

    pub fn withColor(self: *Self, color: []const u8) *Self {
        self.color = color;
        return self;
    }

    pub fn start(self: *Self) !void {
        self.running = true;
        std.debug.print("{s}", .{Cursor.hide});
        self.thread = try std.Thread.spawn(.{}, spinLoop, .{self});
    }

    pub fn stop(self: *Self) void {
        self.running = false;
        if (self.thread) |t| {
            t.join();
        }
        std.debug.print("{s}{s}{s}", .{ Cursor.move_start, Cursor.clear_line, Cursor.show });
    }

    pub fn success(self: *Self, msg: []const u8) void {
        self.stop();
        std.debug.print("{s}{s}✓{s} {s}\n", .{ Color.bold, Color.bright_green, Color.reset, msg });
    }

    pub fn fail(self: *Self, msg: []const u8) void {
        self.stop();
        std.debug.print("{s}{s}✗{s} {s}\n", .{ Color.bold, Color.bright_red, Color.reset, msg });
    }

    fn spinLoop(self: *Self) void {
        const frames = self.style.frames();
        const interval_ns = self.style.interval_ms() * std.time.ns_per_ms;

        while (self.running) {
            const frame = frames[self.frame_index % frames.len];
            std.debug.print("{s}{s}{s}{s} {s}{s}", .{
                Cursor.move_start,
                self.color,
                Color.bold,
                frame,
                Color.reset,
                self.message,
            });
            self.frame_index +%= 1;
            Time.sleep(interval_ns);
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
//  Progress Bar
// ═══════════════════════════════════════════════════════════════════════════════

pub const ProgressBarStyle = enum {
    blocks,
    smooth,
    arrows,
    dots,
    gradient,
    pulse,
};

pub const ProgressBar = struct {
    width: usize,
    style: ProgressBarStyle,
    label: []const u8,
    show_percentage: bool,
    color: []const u8,

    const Self = @This();

    pub fn init(width: usize, label: []const u8) Self {
        return .{
            .width = width,
            .style = .smooth,
            .label = label,
            .show_percentage = true,
            .color = Color.bright_cyan,
        };
    }

    pub fn withStyle(self: *Self, style: ProgressBarStyle) *Self {
        self.style = style;
        return self;
    }

    pub fn withColor(self: *Self, color: []const u8) *Self {
        self.color = color;
        return self;
    }

    pub fn draw(self: *const Self, progress: f32) void {
        const clamped = @min(@max(progress, 0.0), 1.0);
        const filled_width: usize = @intFromFloat(clamped * @as(f32, @floatFromInt(self.width)));
        const empty_width = self.width - filled_width;

        const chars = self.getChars();

        std.debug.print("{s}{s}{s} {s}[{s}", .{
            Cursor.move_start,
            Cursor.clear_line,
            self.label,
            Color.dim,
            Color.reset,
        });

        // Draw filled portion
        std.debug.print("{s}{s}", .{ self.color, Color.bold });
        for (0..filled_width) |_| {
            std.debug.print("{s}", .{chars.filled});
        }

        // Draw empty portion
        std.debug.print("{s}", .{Color.dim});
        for (0..empty_width) |_| {
            std.debug.print("{s}", .{chars.empty});
        }

        std.debug.print("{s}{s}]{s}", .{ Color.reset, Color.dim, Color.reset });

        if (self.show_percentage) {
            const percent: u8 = @intFromFloat(clamped * 100);
            std.debug.print(" {s}{d:>3}%{s}", .{ Color.bright_white, percent, Color.reset });
        }
    }

    fn getChars(self: *const Self) struct { filled: []const u8, empty: []const u8 } {
        return switch (self.style) {
            .blocks => .{ .filled = "█", .empty = "░" },
            .smooth => .{ .filled = "━", .empty = "─" },
            .arrows => .{ .filled = "▶", .empty = "▷" },
            .dots => .{ .filled = "●", .empty = "○" },
            .gradient => .{ .filled = "▓", .empty = "░" },
            .pulse => .{ .filled = "◆", .empty = "◇" },
        };
    }

    pub fn complete(self: *const Self, msg: []const u8) void {
        _ = self;
        std.debug.print("{s}{s}{s}{s}✓{s} {s}\n", .{
            Cursor.move_start,
            Cursor.clear_line,
            Color.bold,
            Color.bright_green,
            Color.reset,
            msg,
        });
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
//  Fancy Reload Animation
// ═══════════════════════════════════════════════════════════════════════════════

pub const ReloadAnimation = struct {
    running: bool = false,
    thread: ?std.Thread = null,
    message: []const u8,

    const Self = @This();

    const reload_frames = [_][]const u8{
        "⟳  ",
        " ⟳ ",
        "  ⟳",
        " ⟳ ",
    };

    const wave_frames = [_][]const u8{
        "🌊     ",
        " 🌊    ",
        "  🌊   ",
        "   🌊  ",
        "    🌊 ",
        "     🌊",
        "    🌊 ",
        "   🌊  ",
        "  🌊   ",
        " 🌊    ",
    };

    const build_frames = [_][]const u8{
        "🔨      ",
        " 🔨     ",
        "  🔨    ",
        "   🔨   ",
        "    🔨  ",
        "     🔨 ",
        "      🔨",
    };

    pub fn init(message: []const u8) Self {
        return .{ .message = message };
    }

    pub fn start(self: *Self) !void {
        self.running = true;
        std.debug.print("{s}", .{Cursor.hide});
        self.thread = try std.Thread.spawn(.{}, animationLoop, .{self});
    }

    pub fn stop(self: *Self) void {
        self.running = false;
        if (self.thread) |t| {
            t.join();
        }
        std.debug.print("{s}{s}{s}", .{ Cursor.move_start, Cursor.clear_line, Cursor.show });
    }

    pub fn done(self: *Self, success_msg: []const u8) void {
        self.stop();
        std.debug.print("{s}{s}⚡{s} {s}\n", .{
            Color.bold,
            Color.bright_green,
            Color.reset,
            success_msg,
        });
    }

    fn animationLoop(self: *Self) void {
        var frame: usize = 0;
        const gradient = [_][]const u8{
            "\x1b[38;5;51m", // cyan
            "\x1b[38;5;45m",
            "\x1b[38;5;39m",
            "\x1b[38;5;33m", // blue
            "\x1b[38;5;39m",
            "\x1b[38;5;45m",
        };

        while (self.running) {
            const color = if (Color.enabled) gradient[frame % gradient.len] else "";
            const spinner = reload_frames[frame % reload_frames.len];

            std.debug.print("{s}{s}{s}{s}{s} {s}{s}", .{
                Cursor.move_start,
                Cursor.clear_line,
                Color.bold,
                color,
                spinner,
                Color.reset,
                self.message,
            });

            frame +%= 1;
            Time.sleep(100 * std.time.ns_per_ms);
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
//  Pulsing Dots Animation
// ═══════════════════════════════════════════════════════════════════════════════

pub const PulsingDots = struct {
    running: bool = false,
    thread: ?std.Thread = null,
    message: []const u8,

    const Self = @This();

    pub fn init(message: []const u8) Self {
        return .{ .message = message };
    }

    pub fn start(self: *Self) !void {
        self.running = true;
        std.debug.print("{s}", .{Cursor.hide});
        self.thread = try std.Thread.spawn(.{}, pulseLoop, .{self});
    }

    pub fn stop(self: *Self) void {
        self.running = false;
        if (self.thread) |t| {
            t.join();
        }
        std.debug.print("{s}{s}{s}", .{ Cursor.move_start, Cursor.clear_line, Cursor.show });
    }

    pub fn done(self: *Self, msg: []const u8) void {
        self.stop();
        std.debug.print("{s}{s}●{s} {s}\n", .{ Color.bold, Color.bright_green, Color.reset, msg });
    }

    fn pulseLoop(self: *Self) void {
        const dot_states = [_][]const u8{
            "●○○",
            "●●○",
            "●●●",
            "○●●",
            "○○●",
            "○○○",
        };

        var frame: usize = 0;
        while (self.running) {
            const dots = dot_states[frame % dot_states.len];
            std.debug.print("{s}{s}{s}{s}{s} {s}{s}", .{
                Cursor.move_start,
                Cursor.clear_line,
                Color.bold,
                Color.bright_magenta,
                dots,
                Color.reset,
                self.message,
            });
            frame +%= 1;
            Time.sleep(150 * std.time.ns_per_ms);
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
//  Simple Usage Functions (for quick integration)
// ═══════════════════════════════════════════════════════════════════════════════

/// Print a styled "reloading" message with animation
pub fn showReloading() !*ReloadAnimation {
    const anim = try std.heap.page_allocator.create(ReloadAnimation);
    anim.* = ReloadAnimation.init("Reloading...");
    try anim.start();
    return anim;
}

/// Print a styled "building" message with spinner
pub fn showBuilding() !*Spinner {
    const spinner = try std.heap.page_allocator.create(Spinner);
    spinner.* = Spinner.init(.braille, "Building...");
    _ = spinner.withColor(Color.bright_yellow);
    try spinner.start();
    return spinner;
}

/// Print a simple status message with icon.
///
/// `color` is a runtime parameter: `Color.disable()` rewrites the palette at
/// startup for `NO_COLOR`, so the constants are `var` and cannot be passed to
/// a comptime parameter.
pub fn status(icon: []const u8, color: []const u8, message: []const u8) void {
    std.debug.print("{s}{s}{s}{s} {s}\n", .{ Color.bold, color, icon, Color.reset, message });
}

pub fn statusInfo(message: []const u8) void {
    status("ℹ", Color.bright_blue, message);
}

pub fn statusSuccess(message: []const u8) void {
    status("✓", Color.bright_green, message);
}

pub fn statusWarning(message: []const u8) void {
    status("⚠", Color.bright_yellow, message);
}

pub fn statusError(message: []const u8) void {
    status("✗", Color.bright_red, message);
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Demo / Test
// ═══════════════════════════════════════════════════════════════════════════════

pub fn demo() !void {
    std.debug.print("\n{s}{s}═══ Spinner Styles ═══{s}\n\n", .{ Color.bold, Color.bright_cyan, Color.reset });

    // Demo different spinner styles
    const styles = [_]SpinnerStyle{ .dots, .braille, .arc, .circle, .line };
    for (styles) |style| {
        var spinner = Spinner.init(style, "Loading...");
        try spinner.start();
        Time.sleep(2 * std.time.ns_per_s);
        spinner.success("Done!");
    }

    std.debug.print("\n{s}{s}═══ Progress Bar Styles ═══{s}\n\n", .{ Color.bold, Color.bright_cyan, Color.reset });

    // Demo progress bar
    const bar_styles = [_]ProgressBarStyle{ .smooth, .blocks, .gradient };
    for (bar_styles) |style| {
        var bar = ProgressBar.init(30, "Progress");
        _ = bar.withStyle(style);

        var progress: f32 = 0.0;
        while (progress <= 1.0) {
            bar.draw(progress);
            progress += 0.05;
            Time.sleep(50 * std.time.ns_per_ms);
        }
        bar.complete("Complete!");
    }

    std.debug.print("\n{s}{s}═══ Reload Animation ═══{s}\n\n", .{ Color.bold, Color.bright_cyan, Color.reset });

    var reload = ReloadAnimation.init("Reloading application...");
    try reload.start();
    Time.sleep(3 * std.time.ns_per_s);
    reload.done("Reload complete!");

    std.debug.print("\n{s}{s}═══ Status Messages ═══{s}\n\n", .{ Color.bold, Color.bright_cyan, Color.reset });

    statusInfo("Information message");
    statusSuccess("Success message");
    statusWarning("Warning message");
    statusError("Error message");

    std.debug.print("\n", .{});
}
