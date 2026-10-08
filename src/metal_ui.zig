const std = @import("std");
const version = @import("build_options").version;
const vapor_ref = @import("main.zig").vapor_ref;

// REVERB
// const reverb_logo = [_][]const u8{
//     "╦═╗╔═╗╦  ╦╔═╗╦═╗╔╗ ",
//     "╠╦╝║╣ ╚╗╔╝║╣ ╠╦╝╠╩╗",
//     "╩╚═╚═╝ ╚╝ ╚═╝╩╚═╚═╝",
// };

const reverb_logo = [_][]const u8{ "╭─╮╭─╴╷ ╷╭─╴╭─╮╭╮ ", "├┬╯├╴ │╭╯├╴ ├┬╯├┴╮", "╵╰╴╰─╴╰╯ ╰─╴╵╰╴╰─╯" };

// SENET
// const senet_logo = [_][]const u8{
//     "╔═╗╔═╗╔╗╔╔═╗╔╦╗",
//     "╚═╗║╣ ║║║║╣  ║ ",
//     "╚═╝╚═╝╝╚╝╚═╝ ╩ ",
// };

const senet_logo = [_][]const u8{
    "╭─╮╭─╴╭╮╷╭─╴╶┬╴",
    "╰─╮├╴ │╰┤├╴  │ ",
    "╰─╯╰─╴╵ ╵╰─╴ ╵ ",
};

// CANOPY
const canopy_logo = [_][]const u8{
    "╔═╗╔═╗╔╗╔╔═╗╔═╗╦ ╦",
    "║  ╠═╣║║║║ ║╠═╝╚╦╝",
    "╚═╝╩ ╩╝╚╝╚═╝╩   ╩ ",
};

// METAL (for reference)
// const metal_logo = [_][]const u8{
//     "╔╦╗╔═╗╔╦╗╔═╗╦  ",
//     "║║║║╣  ║ ╠═╣║  ",
//     "╩ ╩╚═╝ ╩ ╩ ╩╩═╝",
// };

const metal_logo = [_][]const u8{ "╭┬╮╭─╴╶┬╴╭─╮╷  ", "│││├╴  │ ├─┤│  ", "╵ ╵╰─╴ ╵ ╵ ╵╰─╴" };

// VAPOR (original)
// const vapor_logo = [_][]const u8{
//     "╦  ╦╔═╗╔═╗╔═╗╦═╗",
//     "╚╗╔╝╠═╣╠═╝║ ║╠╦╝",
//     " ╚╝ ╩ ╩╩  ╚═╝╩╚═",
// };
// const vapor_logo = [_][]const u8{
//     "┓┏┏┓┏┓┏┓┳┓",
//     "┃┃┣┫┃┃┃┃┣┫",
//     "┗┛┛┗┣┛┗┛┛┗",
// };

// const vapor_logo = [_][]const u8{
// "██╗   ██╗ █████╗ ██████╗  ██████╗ ██████╗ ",
// "██║   ██║██╔══██╗██╔══██╗██╔═══██╗██╔══██╗",
// "██║   ██║███████║██████╔╝██║   ██║██████╔╝",
// "╚██╗ ██╔╝██╔══██║██╔═══╝ ██║   ██║██╔══██╗",
// " ╚████╔╝ ██║  ██║██║     ╚██████╔╝██║  ██║",
// "  ╚═══╝  ╚═╝  ╚═╝╚═╝      ╚═════╝ ╚═╝  ╚═╝"
// };

const vapor_logo = [_][]const u8{ "╷ ╷╭─╮╭─╮╭─╮╭─╮", "│╭╯├─┤├─╯│ │├┬╯", "╰╯ ╵ ╵╵  ╰─╯╵╰╴" };

// ═══════════════════════════════════════════════════════════════════════════════
//  ANSI Escape Codes
// ═══════════════════════════════════════════════════════════════════════════════

pub const Ansi = struct {
    pub var reset: []const u8 = "\x1b[0m";
    pub var bold: []const u8 = "\x1b[1m";
    pub var dim: []const u8 = "\x1b[2m";
    pub var italic: []const u8 = "\x1b[3m";
    pub var underline: []const u8 = "\x1b[4m";

    pub var black: []const u8 = "\x1b[30m";
    pub var red: []const u8 = "\x1b[31m";
    pub var green: []const u8 = "\x1b[32m";
    pub var yellow: []const u8 = "\x1b[33m";
    pub var blue: []const u8 = "\x1b[34m";
    pub var magenta: []const u8 = "\x1b[35m";
    pub var cyan: []const u8 = "\x1b[36m";
    pub var white: []const u8 = "\x1b[37m";

    pub var bright_black: []const u8 = "\x1b[90m";
    pub var bright_red: []const u8 = "\x1b[91m";
    pub var bright_green: []const u8 = "\x1b[92m";
    pub var bright_yellow: []const u8 = "\x1b[93m";
    pub var bright_blue: []const u8 = "\x1b[94m";
    pub var bright_magenta: []const u8 = "\x1b[95m";
    pub var bright_cyan: []const u8 = "\x1b[96m";
    pub var bright_white: []const u8 = "\x1b[97m";

    // Custom gradient colors (256 color mode)
    pub var grad_1: []const u8 = "\x1b[38;5;51m"; // Bright cyan
    pub var grad_2: []const u8 = "\x1b[38;5;45m";
    pub var grad_3: []const u8 = "\x1b[38;5;39m"; // Blue
    pub var grad_4: []const u8 = "\x1b[38;5;33m";
    pub var grad_5: []const u8 = "\x1b[38;5;27m"; // Deeper blue
    pub var grad_6: []const u8 = "\x1b[38;5;99m"; // Purple
    pub var grad_7: []const u8 = "\x1b[38;5;135m"; // Magenta
    pub var grad_8: []const u8 = "\x1b[38;5;171m"; // Pink

    pub var clear_screen: []const u8 = "\x1b[2J\x1b[H";

    pub fn disable() void {
        reset = "";
        bold = "";
        dim = "";
        italic = "";
        underline = "";
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
        grad_1 = "";
        grad_2 = "";
        grad_3 = "";
        grad_4 = "";
        grad_5 = "";
        grad_6 = "";
        grad_7 = "";
        grad_8 = "";
        clear_screen = "";
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
//  Styled Help Menu
// ═══════════════════════════════════════════════════════════════════════════════

pub fn printHelp() void {
    // Header with ASCII art logo
    const logo = [_][]const u8{
        "███╗   ███╗███████╗████████╗ █████╗ ██╗     ",
        "████╗ ████║██╔════╝╚══██╔══╝██╔══██╗██║     ",
        "██╔████╔██║█████╗     ██║   ███████║██║     ",
        "██║╚██╔╝██║██╔══╝     ██║   ██╔══██║██║     ",
        "██║ ╚═╝ ██║███████╗   ██║   ██║  ██║███████╗",
        "╚═╝     ╚═╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝",
    };

    const gradient = [_][]const u8{
        Ansi.grad_1,
        Ansi.grad_2,
        Ansi.grad_3,
        Ansi.grad_4,
        Ansi.grad_5,
        Ansi.grad_6,
    };

    std.debug.print("\n", .{});

    // Print logo with gradient
    for (logo, 0..) |line, i| {
        std.debug.print("  {s}{s}{s}\n", .{ gradient[i], line, Ansi.reset });
    }

    // Version and tagline
    std.debug.print("\n  {s}{s}v{s}{s} {s}─{s} {s}The Zig Web Framework Toolbox{s}\n", .{
        Ansi.bold,
        Ansi.bright_cyan,
        version,
        Ansi.reset,
        Ansi.dim,
        Ansi.reset,
        Ansi.dim,
        Ansi.reset,
    });

    std.debug.print("  {s}Build fast, type-safe web applications with Zig{s}\n\n", .{
        Ansi.dim,
        Ansi.reset,
    });

    // Usage section
    printSectionHeader("USAGE");
    std.debug.print("  {s}metal{s} {s}<framework>{s} {s}<command>{s} {s}[options]{s} {s}[args]{s}\n\n", .{
        Ansi.bright_white,
        Ansi.reset,
        Ansi.bright_cyan,
        Ansi.reset,
        Ansi.bright_green,
        Ansi.reset,
        Ansi.bright_yellow,
        Ansi.reset,
        Ansi.dim,
        Ansi.reset,
    });

    // Frameworks section
    printSectionHeader("FRAMEWORKS");
    printFrameworkItem("vapor", "Frontend UI framework with reactive components", "💨");
    printFrameworkItem("reverb", "Backend HTTP server with WebSocket support", "🔊");
    // printFrameworkItem("canopy", "Full-stack framework combining both", "🌳");
    std.debug.print("\n", .{});

    // Commands section
    printSectionHeader("COMMANDS");
    printCommandItem("create <name>", "Create a new project", "📦");
    printCommandItem("run", "Start development server with hot reload", "▶️ ");
    // printCommandItem("build", "Build for production", "🔨");
    // printCommandItem("gen <type> [name]", "Generate components and files", "⚡");
    // printCommandItem("add <package>", "Add a dependency to your project", "➕");
    printCommandItem("upgrade", "Upgrade metal to the latest version", "⬆️ ");
    printCommandItem("help", "Show this help message", "❓");
    printCommandItem("version", "Show version information", "📋");
    std.debug.print("\n", .{});

    // Generation types
    printSectionHeader("GENERATION TYPES");

    std.debug.print("  {s}Frontend Components:{s}\n", .{ Ansi.bright_magenta, Ansi.reset });
    printGenItem("component", "Basic component with init/deinit/render");
    printGenItem("page", "Full page with routing setup");
    printGenItem("card", "Pre-styled card with title and body");
    printGenItem("button", "Interactive button with callback");
    printGenItem("template", "Base template with hooks and flexbox");
    printGenItem("form", "Form component with validation");

    std.debug.print("\n  {s}Backend Generators:{s}\n", .{ Ansi.bright_magenta, Ansi.reset });
    printGenItem("handler", "HTTP request handler");
    printGenItem("middleware", "Request middleware");
    printGenItem("model", "Database model");
    printGenItem("crud", "Full CRUD operations");
    printGenItem("websocket", "WebSocket handler");
    std.debug.print("\n", .{});

    // Options
    printSectionHeader("OPTIONS");
    // printOptionItem("-o, --output <path>", "Output file path");
    // printOptionItem("-q, --quiet", "Suppress output messages");
    // printOptionItem("-t, --template <name>", "Use specific template variant");
    printOptionItem("-r, --release", "Build in release mode");
    printOptionItem("-h, --help", "Show help message");
    printOptionItem("-v, --version", "Show version");
    std.debug.print("\n", .{});

    // Quick start box
    printSectionHeader("QUICK START");
    printCodeBlock(&[_][]const u8{
        "# Create a new Vapor app",
        "metal vapor create myapp",
        "",
        "# Navigate and run",
        "cd myapp",
        "metal vapor run",
    });

    // Examples
    printSectionHeader("EXAMPLES");
    printExample("metal vapor create myapp", "Create new Vapor project");
    // printExample("metal vapor gen component Button", "Generate a component");
    // printExample("metal reverb gen crud User", "Generate CRUD for User model");
    // printExample("metal vapor run --release", "Run in release mode");
    std.debug.print("\n", .{});

    // Footer with links
    printFooter();
}

/// Help scoped to a single framework. Lists only commands and gen types
/// that apply to that framework, plus framework-specific examples.
pub fn printFrameworkHelp(framework: []const u8) void {
    const is_vapor = std.mem.eql(u8, framework, "vapor");
    const is_reverb = std.mem.eql(u8, framework, "reverb");
    const is_canopy = std.mem.eql(u8, framework, "canopy");

    const logo = if (is_vapor)
        &vapor_logo
    else if (is_reverb)
        &reverb_logo
    else if (is_canopy)
        &canopy_logo
    else
        &metal_logo;

    const grad = if (is_vapor)
        cyanGradient()
    else if (is_reverb)
        purpleGradient()
    else if (is_canopy)
        greenGradient()
    else
        orangeGradient();

    printLogo(logo, &grad);

    std.debug.print("  {s}{s}metal {s}{s}{s} {s}— scoped help{s}\n\n", .{
        Ansi.bold,
        Ansi.bright_white,
        Ansi.bright_cyan,
        framework,
        Ansi.reset,
        Ansi.dim,
        Ansi.reset,
    });

    printSectionHeader("USAGE");
    std.debug.print("  {s}metal{s} {s}{s}{s} {s}<command>{s} {s}[options]{s}\n\n", .{
        Ansi.bright_white,
        Ansi.reset,
        Ansi.bright_cyan,
        framework,
        Ansi.reset,
        Ansi.bright_green,
        Ansi.reset,
        Ansi.dim,
        Ansi.reset,
    });

    printSectionHeader("COMMANDS");
    printCommandItem("create <name>", "Create a new project", "📦");
    printCommandItem("init", "Scaffold into the current directory", "📂");
    printCommandItem("run [opts]", "Start dev server with hot reload", "▶️ ");
    printCommandItem("build [opts]", "Build the project", "🔨");
    printCommandItem("release", "Run the full release pipeline", "🚀");
    printCommandItem("gen <type> <name>", "Generate a file from a template", "⚡");
    printCommandItem("add <package>", "Add a dependency", "➕");
    printCommandItem("doctor", "Check tooling (zig, wasm-opt, brotli...)", "🩺");
    printCommandItem("clean", "Remove zig-out and .zig-cache", "🧹");
    printCommandItem("help", "Show this help message", "❓");
    std.debug.print("\n", .{});

    printSectionHeader("GENERATION TYPES");
    if (is_vapor or is_canopy) {
        std.debug.print("  {s}Frontend:{s}\n", .{ Ansi.bright_magenta, Ansi.reset });
        printGenItem("component", "Basic component with init/deinit/render");
        printGenItem("page", "Full page with routing setup");
        printGenItem("card", "Pre-styled card");
        printGenItem("button", "Interactive button with callback");
        printGenItem("template", "Base template with hooks");
        printGenItem("fetch", "Component that fetches data");
    }
    if (is_reverb or is_canopy) {
        std.debug.print("\n  {s}Backend:{s}\n", .{ Ansi.bright_magenta, Ansi.reset });
        printGenItem("crud", "CRUD handler skeleton");
        printGenItem("crudfull", "Full CRUD with database calls");
        printGenItem("database", "Database client setup");
    }
    std.debug.print("\n", .{});

    printSectionHeader("RUN OPTIONS");
    printOptionItem("-r, --release", "Build in release mode");
    printOptionItem("-s, --static", "Serve from static/ tree");
    printOptionItem("-g, --generate", "Run -Dgenerate=true");
    printOptionItem("--ssg", "Static site generation mode");
    printOptionItem("--open", "Open the browser on start");
    printOptionItem("--port <n>", "Override the dev server port (default 5173)");
    printOptionItem("--host <addr>", "Override the dev server host");
    std.debug.print("\n", .{});

    printSectionHeader("EXAMPLES");
    var ex_buf: [128]u8 = undefined;
    const create_ex = std.fmt.bufPrint(&ex_buf, "metal {s} create myapp", .{framework}) catch "metal create myapp";
    printExample(create_ex, "Create a new project");
    var ex_buf2: [128]u8 = undefined;
    const run_ex = std.fmt.bufPrint(&ex_buf2, "metal {s} run --open", .{framework}) catch "metal run --open";
    printExample(run_ex, "Run the dev server and open the browser");
    if (is_vapor or is_canopy) {
        var ex_buf3: [128]u8 = undefined;
        const gen_ex = std.fmt.bufPrint(&ex_buf3, "metal {s} gen page Home", .{framework}) catch "metal gen page Home";
        printExample(gen_ex, "Generate a Page component");
    }
    if (is_reverb or is_canopy) {
        var ex_buf4: [128]u8 = undefined;
        const gen_ex = std.fmt.bufPrint(&ex_buf4, "metal {s} gen crud User", .{framework}) catch "metal gen crud User";
        printExample(gen_ex, "Generate a CRUD handler");
    }
    std.debug.print("\n", .{});
    printFooter();
}

fn printSectionHeader(title: []const u8) void {
    std.debug.print("  {s}{s}{s}\n", .{ Ansi.bright_cyan, title, Ansi.reset });
    std.debug.print("  {s}", .{Ansi.dim});
    for (0..title.len) |_| std.debug.print("─", .{});
    std.debug.print("{s}\n", .{Ansi.reset});
}

fn printFrameworkItem(name: []const u8, desc: []const u8, icon: []const u8) void {
    std.debug.print("  {s} {s}{s}{s:<10}{s} {s}{s}{s}\n", .{
        icon,
        Ansi.bold,
        Ansi.bright_green,
        name,
        Ansi.reset,
        Ansi.dim,
        desc,
        Ansi.reset,
    });
}

fn printCommandItem(cmd: []const u8, desc: []const u8, icon: []const u8) void {
    // Calculate padding for alignment
    const pad_width = 22;
    const cmd_len = cmd.len;
    const padding = if (pad_width > cmd_len) pad_width - cmd_len else 0;

    std.debug.print("  {s} {s}{s}{s}", .{ icon, Ansi.bright_yellow, cmd, Ansi.reset });
    for (0..padding) |_| std.debug.print(" ", .{});
    std.debug.print("{s}{s}{s}\n", .{ Ansi.dim, desc, Ansi.reset });
}

fn printGenItem(name: []const u8, desc: []const u8) void {
    const pad_width = 16;
    const name_len = name.len;
    const padding = if (pad_width > name_len) pad_width - name_len else 0;

    std.debug.print("    {s}•{s} {s}{s}{s}", .{
        Ansi.bright_cyan,
        Ansi.reset,
        Ansi.bright_white,
        name,
        Ansi.reset,
    });
    for (0..padding) |_| std.debug.print(" ", .{});
    std.debug.print("{s}{s}{s}\n", .{ Ansi.dim, desc, Ansi.reset });
}

fn printOptionItem(opt: []const u8, desc: []const u8) void {
    const pad_width = 24;
    const opt_len = opt.len;
    const padding = if (pad_width > opt_len) pad_width - opt_len else 0;

    std.debug.print("  {s}{s}{s}", .{ Ansi.bright_yellow, opt, Ansi.reset });
    for (0..padding) |_| std.debug.print(" ", .{});
    std.debug.print("{s}{s}{s}\n", .{ Ansi.dim, desc, Ansi.reset });
}

fn printCodeBlock(lines: []const []const u8) void {
    std.debug.print("  {s}┌─────────────────────────────────────────┐{s}\n", .{ Ansi.dim, Ansi.reset });
    for (lines) |line| {
        if (line.len == 0) {
            std.debug.print("  {s}│{s}                                         {s}│{s}\n", .{
                Ansi.dim,
                Ansi.reset,
                Ansi.dim,
                Ansi.reset,
            });
        } else if (line[0] == '#') {
            // Comment line
            const content_len = line.len;
            const padding = 41 - content_len;
            std.debug.print("  {s}│{s} {s}{s}{s}", .{
                Ansi.dim,
                Ansi.reset,
                Ansi.bright_black,
                line,
                Ansi.reset,
            });
            for (0..padding) |_| std.debug.print(" ", .{});
            std.debug.print("{s}│{s}\n", .{ Ansi.dim, Ansi.reset });
        } else {
            // Command line
            const content_len = line.len;
            const padding = 41 - content_len;
            std.debug.print("  {s}│{s} {s}{s}${s} {s}{s}{s}", .{
                Ansi.dim,
                Ansi.reset,
                Ansi.bright_green,
                Ansi.bold,
                Ansi.reset,
                Ansi.bright_white,
                line,
                Ansi.reset,
            });
            for (0..padding - 2) |_| std.debug.print(" ", .{});
            std.debug.print("{s}│{s}\n", .{ Ansi.dim, Ansi.reset });
        }
    }
    std.debug.print("  {s}└─────────────────────────────────────────┘{s}\n\n", .{ Ansi.dim, Ansi.reset });
}

fn printExample(cmd: []const u8, desc: []const u8) void {
    std.debug.print("  {s}${s} {s}{s}{s}\n", .{
        Ansi.bright_green,
        Ansi.reset,
        Ansi.bright_white,
        cmd,
        Ansi.reset,
    });
    std.debug.print("    {s}↳ {s}{s}\n\n", .{ Ansi.dim, desc, Ansi.reset });
}

fn printFooter() void {
    std.debug.print("  {s}─────────────────────────────────────────────{s}\n", .{ Ansi.dim, Ansi.reset });
    std.debug.print("  {s}📚 Docs:{s}    {s}https://senet.run/docs/vapor{s}\n", .{
        Ansi.dim,
        Ansi.reset,
        Ansi.bright_blue,
        Ansi.reset,
    });
    // std.debug.print("  {s}🐛 Issues:{s}  {s}https://github.com/tether-labs/metal/issues{s}\n", .{
    //     Ansi.dim,
    //     Ansi.reset,
    //     Ansi.bright_blue,
    //     Ansi.reset,
    // });
    // std.debug.print("  {s}💬 Discord:{s} {s}https://discord.gg/vapor-zig{s}\n\n", .{
    //     Ansi.dim,
    //     Ansi.reset,
    //     Ansi.bright_blue,
    //     Ansi.reset,
    // });
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Styled Create Command
// ═══════════════════════════════════════════════════════════════════════════════

pub fn printLogo(logo: []const []const u8, gradient: []const []const u8) void {
    std.debug.print("\n", .{});
    for (logo, 0..) |line, i| {
        const color = gradient[i % gradient.len];
        std.debug.print("    {s}{s}{s}{s}\n", .{ color, Ansi.bold, line, Ansi.reset });
    }
    std.debug.print("\n", .{});
}

// Gradients are computed at call time so NO_COLOR can blank them out at runtime.
fn noGradient() [3][]const u8 {
    return .{ "", "", "" };
}
fn cyanGradient() [3][]const u8 {
    return .{ Ansi.grad_1, Ansi.grad_2, Ansi.grad_3 };
}
fn purpleGradient() [3][]const u8 {
    if (Ansi.reset.len == 0) return .{ "", "", "" };
    return .{ "\x1b[38;5;135m", "\x1b[38;5;99m", "\x1b[38;5;63m" };
}
fn greenGradient() [3][]const u8 {
    if (Ansi.reset.len == 0) return .{ "", "", "" };
    return .{ "\x1b[38;5;48m", "\x1b[38;5;42m", "\x1b[38;5;36m" };
}
fn orangeGradient() [3][]const u8 {
    if (Ansi.reset.len == 0) return .{ "", "", "" };
    return .{ "\x1b[38;5;214m", "\x1b[38;5;208m", "\x1b[38;5;202m" };
}

pub fn printCreateStart(project_name: []const u8) void {
    std.debug.print("{s}", .{Ansi.clear_screen});

    // Vapor logo with gradient
    const grad = orangeGradient();
    printLogo(&senet_logo, &grad);

    // Creating message
    std.debug.print("    {s}Creating project:{s} {s}{s}{s}\n\n", .{
        Ansi.dim,
        Ansi.reset,
        Ansi.bold,
        project_name,
        Ansi.reset,
    });
}

pub fn printCreateStep(step: usize, total: usize, message: []const u8, icon: []const u8) void {
    std.debug.print("    {s}[{d}/{d}]{s} {s} {s}{s}{s}\n", .{
        Ansi.dim,
        step,
        total,
        Ansi.reset,
        icon,
        Ansi.bright_white,
        message,
        Ansi.reset,
    });
}

pub fn printCreateSuccess(project_name: []const u8) void {
    std.debug.print("\n", .{});

    // Top border
    std.debug.print("    {s}┌─────────────────────────────────────────────┐{s}\n", .{ Ansi.bright_green, Ansi.reset });

    // Success message
    std.debug.print("    {s}│{s}  {s}✨ Project created successfully!{s}           {s}│{s}\n", .{
        Ansi.bright_green,
        Ansi.reset,
        Ansi.bold,
        Ansi.reset,
        Ansi.bright_green,
        Ansi.reset,
    });

    // Divider
    std.debug.print("    {s}├─────────────────────────────────────────────┤{s}\n", .{ Ansi.bright_green, Ansi.reset });

    // Next steps header
    std.debug.print("    {s}│{s}  {s}Next steps:{s}                                {s}│{s}\n", .{
        Ansi.bright_green,
        Ansi.reset,
        Ansi.dim,
        Ansi.reset,
        Ansi.bright_green,
        Ansi.reset,
    });

    // Empty line
    std.debug.print("    {s}│{s}                                             {s}│{s}\n", .{
        Ansi.bright_green,
        Ansi.reset,
        Ansi.bright_green,
        Ansi.reset,
    });

    // cd command - build the line with proper padding
    var cd_buf: [64]u8 = undefined;
    const cd_cmd = std.fmt.bufPrint(&cd_buf, "cd {s}", .{project_name}) catch "cd <project>";

    std.debug.print("    {s}│{s}    {s}1.{s} {s}{s}{s}", .{
        Ansi.bright_green,
        Ansi.reset,
        Ansi.bright_cyan,
        Ansi.reset,
        Ansi.bright_yellow,
        cd_cmd,
        Ansi.reset,
    });
    // Pad to 45 chars: "    1. " = 7 chars, so need 45 - 7 - cd_cmd.len spaces
    const cd_padding = 45 - 7 - cd_cmd.len;
    for (0..cd_padding) |_| std.debug.print(" ", .{});
    std.debug.print("{s}│{s}\n", .{ Ansi.bright_green, Ansi.reset });

    // run command
    std.debug.print("    {s}│{s}    {s}2.{s} {s}metal vapor run{s}                       {s}│{s}\n", .{
        Ansi.bright_green,
        Ansi.reset,
        Ansi.bright_cyan,
        Ansi.reset,
        Ansi.bright_yellow,
        Ansi.reset,
        Ansi.bright_green,
        Ansi.reset,
    });

    // Empty line
    std.debug.print("    {s}│{s}                                             {s}│{s}\n", .{
        Ansi.bright_green,
        Ansi.reset,
        Ansi.bright_green,
        Ansi.reset,
    });

    // Bottom border
    std.debug.print("    {s}└─────────────────────────────────────────────┘{s}\n\n", .{ Ansi.bright_green, Ansi.reset });

    // Happy coding message
    std.debug.print("    {s}Happy coding! 🚀{s}\n\n", .{ Ansi.dim, Ansi.reset });
}
pub fn printZigNotFound() void {
    std.debug.print("{s}", .{Ansi.clear_screen});

    // Error box
    const box_width = 50;

    std.debug.print("\n", .{});

    // Top border
    std.debug.print("  {s}┌", .{Ansi.bright_red});
    for (0..box_width) |_| std.debug.print("─", .{});
    std.debug.print("┐{s}\n", .{Ansi.reset});

    // Error title
    std.debug.print("  {s}│{s}  {s}{s}✗ Error: Zig not found{s}                          {s}│{s}\n", .{
        Ansi.bright_red,
        Ansi.reset,
        Ansi.bold,
        Ansi.bright_red,
        Ansi.reset,
        Ansi.bright_red,
        Ansi.reset,
    });

    // Divider
    std.debug.print("  {s}├", .{Ansi.bright_red});
    for (0..box_width) |_| std.debug.print("─", .{});
    std.debug.print("┤{s}\n", .{Ansi.reset});

    // Message
    std.debug.print("  {s}│{s}  0.15.2 Zig compiler is required to use Metal.   {s}│{s}\n", .{
        Ansi.bright_red,
        Ansi.reset,
        Ansi.bright_red,
        Ansi.reset,
    });
    std.debug.print("  {s}│{s}                                                  {s}│{s}\n", .{
        Ansi.bright_red,
        Ansi.reset,
        Ansi.bright_red,
        Ansi.reset,
    });
    std.debug.print("  {s}│{s}  {s}Install options:{s}                                {s}│{s}\n", .{
        Ansi.bright_red,
        Ansi.reset,
        Ansi.bright_white,
        Ansi.reset,
        Ansi.bright_red,
        Ansi.reset,
    });
    std.debug.print("  {s}│{s}                                                  {s}│{s}\n", .{
        Ansi.bright_red,
        Ansi.reset,
        Ansi.bright_red,
        Ansi.reset,
    });

    // Option 1: zvm
    std.debug.print("  {s}│{s}  {s}1.{s} Using zvm (recommended):                     {s}│{s}\n", .{
        Ansi.bright_red,
        Ansi.reset,
        Ansi.bright_cyan,
        Ansi.reset,
        Ansi.bright_red,
        Ansi.reset,
    });
    std.debug.print("  {s}│{s}     {s}curl https://www.zvm.app/install.sh | bash{s}   {s}│{s}\n", .{
        Ansi.bright_red,
        Ansi.reset,
        Ansi.bright_yellow,
        Ansi.reset,
        Ansi.bright_red,
        Ansi.reset,
    });
    std.debug.print("  {s}│{s}                                                  {s}│{s}\n", .{
        Ansi.bright_red,
        Ansi.reset,
        Ansi.bright_red,
        Ansi.reset,
    });

    // Option 2: direct
    std.debug.print("  {s}│{s}  {s}2.{s} Direct download:                             {s}│{s}\n", .{
        Ansi.bright_red,
        Ansi.reset,
        Ansi.bright_cyan,
        Ansi.reset,
        Ansi.bright_red,
        Ansi.reset,
    });
    std.debug.print("  {s}│{s}     {s}https://ziglang.org/download{s}                 {s}│{s}\n", .{
        Ansi.bright_red,
        Ansi.reset,
        Ansi.bright_blue,
        Ansi.reset,
        Ansi.bright_red,
        Ansi.reset,
    });
    std.debug.print("  {s}│{s}                                                  {s}│{s}\n", .{
        Ansi.bright_red,
        Ansi.reset,
        Ansi.bright_red,
        Ansi.reset,
    });

    // Zig Install with ZVM
    std.debug.print("  {s}│{s}  {s}3.{s} Zig install with ZVM (recommended):          {s}│{s}\n", .{
        Ansi.bright_red,
        Ansi.reset,
        Ansi.bright_cyan,
        Ansi.reset,
        Ansi.bright_red,
        Ansi.reset,
    });
    std.debug.print("  {s}│{s}     {s}zvm install 0.15.2{s}                           {s}│{s}\n", .{
        Ansi.bright_red,
        Ansi.reset,
        Ansi.bright_yellow,
        Ansi.reset,
        Ansi.bright_red,
        Ansi.reset,
    });
    std.debug.print("  {s}│{s}                                                  {s}│{s}\n", .{
        Ansi.bright_red,
        Ansi.reset,
        Ansi.bright_red,
        Ansi.reset,
    });

    // Bottom border
    std.debug.print("  {s}└", .{Ansi.bright_red});
    for (0..box_width) |_| std.debug.print("─", .{});
    std.debug.print("┘{s}\n\n", .{Ansi.reset});
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Version Display
// ═══════════════════════════════════════════════════════════════════════════════

pub fn printVersion() void {
    const logo = [_][]const u8{
        "╦  ╦╔═╗╔═╗╔═╗╦═╗",
        "╚╗╔╝╠═╣╠═╝║ ║╠╦╝",
        " ╚╝ ╩ ╩╩  ╚═╝╩╚═",
    };

    const gradient = [_][]const u8{
        Ansi.grad_1,
        Ansi.grad_2,
        Ansi.grad_3,
    };

    std.debug.print("\n", .{});
    for (logo, 0..) |line, i| {
        std.debug.print("  {s}{s}{s}{s}\n", .{ gradient[i], Ansi.bold, line, Ansi.reset });
    }

    std.debug.print("\n  {s}metal{s} {s}v{s}{s}\n", .{
        Ansi.bright_white,
        Ansi.reset,
        Ansi.bright_cyan,
        version,
        Ansi.reset,
    });
    std.debug.print("  {s}The Zig Web Framework Toolbox{s}\n\n", .{
        Ansi.dim,
        Ansi.reset,
    });

    std.debug.print("  {s}Frameworks:{s}\n", .{ Ansi.bright_white, Ansi.reset });
    std.debug.print("    {s}•{s} Vapor   {s}{s}{s}  {s}Frontend UI (new apps pin this){s}\n", .{
        Ansi.bright_cyan,
        Ansi.reset,
        Ansi.bright_green,
        vapor_ref,
        Ansi.reset,
        Ansi.dim,
        Ansi.reset,
    });
    std.debug.print("    {s}•{s} Reverb  {s}Backend HTTP{s}\n", .{ Ansi.bright_cyan, Ansi.reset, Ansi.dim, Ansi.reset });
    std.debug.print("    {s}•{s} Canopy  {s}Full-stack{s}\n\n", .{ Ansi.bright_cyan, Ansi.reset, Ansi.dim, Ansi.reset });

    std.debug.print("  {s}Requirements:{s}\n", .{ Ansi.bright_white, Ansi.reset });
    std.debug.print("    {s}•{s} Zig {s}0.16.0{s}\n\n", .{
        Ansi.bright_cyan,
        Ansi.reset,
        Ansi.bright_green,
        Ansi.reset,
    });

    std.debug.print("  {s}License:{s} MIT\n", .{ Ansi.dim, Ansi.reset });
    std.debug.print("  {s}Website:{s} {s}https://vapor.zig.dev{s}\n\n", .{
        Ansi.dim,
        Ansi.reset,
        Ansi.bright_blue,
        Ansi.reset,
    });
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Minimal Feedback Helpers
// ═══════════════════════════════════════════════════════════════════════════════

pub fn printStep(verb: []const u8, subject: []const u8) void {
    std.debug.print("  {s}{s}{s:<12}{s} {s}{s}{s}\n", .{
        Ansi.bold,
        Ansi.bright_cyan,
        verb,
        Ansi.reset,
        Ansi.bright_white,
        subject,
        Ansi.reset,
    });
}

pub fn printSuccess(verb: []const u8, subject: []const u8) void {
    std.debug.print("  {s}{s}{s:<12}{s} {s}{s}{s}\n", .{
        Ansi.bold,
        Ansi.bright_green,
        verb,
        Ansi.reset,
        Ansi.bright_white,
        subject,
        Ansi.reset,
    });
}

pub fn printWarning(verb: []const u8, subject: []const u8) void {
    std.debug.print("  {s}{s}{s:<12}{s} {s}{s}{s}\n", .{
        Ansi.bold,
        Ansi.bright_yellow,
        verb,
        Ansi.reset,
        Ansi.bright_white,
        subject,
        Ansi.reset,
    });
}

pub fn printError(message: []const u8, detail: []const u8) void {
    std.debug.print("\n  {s}{s}error:{s} {s}{s}\n", .{
        Ansi.bold,
        Ansi.bright_red,
        Ansi.reset,
        message,
        Ansi.reset,
    });
    if (detail.len > 0) {
        std.debug.print("  {s}{s}{s}\n", .{ Ansi.dim, detail, Ansi.reset });
    }
    std.debug.print("\n", .{});
}

const RunOptions = @import("main.zig").RunOptions;

pub fn printServerBanner(framework: []const u8, port: u16, opts: anytype) void {
    std.debug.print("\n", .{});

    // Pick the right logo
    const logo = if (std.mem.eql(u8, framework, "vapor"))
        &vapor_logo
    else if (std.mem.eql(u8, framework, "reverb"))
        &reverb_logo
    else if (std.mem.eql(u8, framework, "canopy"))
        &canopy_logo
    else
        &metal_logo;

    const gradient = if (std.mem.eql(u8, framework, "vapor"))
        cyanGradient()
    else if (std.mem.eql(u8, framework, "reverb"))
        purpleGradient()
    else if (std.mem.eql(u8, framework, "canopy"))
        greenGradient()
    else
        orangeGradient();

    printLogo(logo, &gradient);

    // Mode line
    std.debug.print("  {s}mode{s}  ", .{ Ansi.dim, Ansi.reset });
    if (opts.release) {
        std.debug.print("{s}release{s}", .{ Ansi.bright_green, Ansi.reset });
    } else {
        std.debug.print("{s}development{s}", .{ Ansi.bright_yellow, Ansi.reset });
    }
    if (opts.generate) std.debug.print(" {s}+ generate{s}", .{ Ansi.dim, Ansi.reset });
    if (opts.static) std.debug.print(" {s}+ static{s}", .{ Ansi.dim, Ansi.reset });
    if (opts.ssg) std.debug.print(" {s}+ ssg{s}", .{ Ansi.dim, Ansi.reset });
    std.debug.print("\n", .{});

    _ = port;
}

pub fn printListening(port: u16) void {
    std.debug.print("  {s}ready{s} {s}http://localhost:{d}{s}\n\n", .{
        Ansi.dim,
        Ansi.reset,
        Ansi.bright_cyan,
        port,
        Ansi.reset,
    });
}
