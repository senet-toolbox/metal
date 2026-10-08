// main.zig — improved DX version

const std = @import("std");
const Contents = @import("file_contents.zig").Contents;
const print = std.debug.print;
const Reverb = @import("reverb");
const watcher = @import("watcher.zig");
const MetalUI = @import("metal_ui.zig");
const SpinnerUI = @import("spinner.zig");
const TechyUI = @import("techy_spinner.zig");
const builtin = @import("builtin");
const MetalConfigMod = @import("metal_config.zig");
const proc_state = @import("proc_state.zig");
const Time = @import("Time.zig");

const Ansi = MetalUI.Ansi;

/// Disable colors when stdout isn't a TTY or NO_COLOR is set in the env.
fn applyColorPolicy() void {
    // var no_color = false;
    // if (std.process.hasEnvVarConstant("NO_COLOR")) {
    //     no_color = true;
    // }
    // stdout = fd 1; if it's not a tty, strip colors so logs/pipes stay clean.
    // if (!std.posix.isatty(1)) no_color = true;
    // if (no_color) {
    //     MetalUI.Ansi.disable();
    //     TechyUI.Ansi.disable();
    //     SpinnerUI.Color.disable();
    //     SpinnerUI.Cursor.disable();
    // }
}

const Command = enum {
    add,
    gen,
    help,
    create,
    unknown,
    run,
    version,
    build,
    release,
    doctor,
    clean,
    upgrade,
};

const GenOptions = struct {
    output_path: ?[]const u8 = null,
    quiet: bool = false,
    template: ?[]const u8 = null,
    name: ?[]const u8 = null,
    gen_type: []const u8 = "",
    dry_run: bool = false,
    force: bool = false,
};

/// Default output directory for a given gen type. The CLI is opinionated:
/// pages live under src/routes/, components under src/components/, backend
/// generators under src/handlers/. `--output` overrides this entirely.
fn defaultGenDir(gen_type: []const u8) []const u8 {
    if (std.mem.eql(u8, gen_type, "page")) return "src/routes";
    if (std.mem.eql(u8, gen_type, "component")) return "src/components";
    if (std.mem.eql(u8, gen_type, "card")) return "src/components";
    if (std.mem.eql(u8, gen_type, "button")) return "src/components";
    if (std.mem.eql(u8, gen_type, "fetch")) return "src/components";
    if (std.mem.eql(u8, gen_type, "crud")) return "src/handlers";
    if (std.mem.eql(u8, gen_type, "crudfull")) return "src/handlers";
    if (std.mem.eql(u8, gen_type, "database")) return "src";
    return "src";
}

pub const Config = struct {
    watch_paths: []const []const u8 = &.{"src"},
    build_command: []const []const u8 = &.{ "zig", "build" },
    make_command: []const []const u8 = &.{"make"},
    run_dev_command: []const []const u8 = &.{ "zig", "run", "src/main.zig" },
    run_command: []const []const u8 = &.{"zig-out/bin/app"},
    file_extensions: []const []const u8 = &.{ ".zig", ".html" },
    exclude_dirs: []const []const u8 = &.{ "zig-cache", "zig-out" },
    debounce_ms: u64 = 100,
};

fn parseFramework(cmd: []const u8) ?FrameworkType {
    if (std.mem.eql(u8, cmd, "vapor")) return .vapor;
    if (std.mem.eql(u8, cmd, "reverb")) return .reverb;
    if (std.mem.eql(u8, cmd, "canopy")) return .canopy;
    return null;
}

fn parseCommand(cmd: []const u8) Command {
    if (std.mem.eql(u8, cmd, "gen")) return .gen;
    if (std.mem.eql(u8, cmd, "create")) return .create;
    if (std.mem.eql(u8, cmd, "help")) return .help;
    if (std.mem.eql(u8, cmd, "run")) return .run;
    if (std.mem.eql(u8, cmd, "version")) return .version;
    if (std.mem.eql(u8, cmd, "build")) return .build;
    if (std.mem.eql(u8, cmd, "add")) return .add;
    if (std.mem.eql(u8, cmd, "release")) return .release;
    if (std.mem.eql(u8, cmd, "doctor")) return .doctor;
    if (std.mem.eql(u8, cmd, "clean")) return .clean;
    if (std.mem.eql(u8, cmd, "upgrade")) return .upgrade;
    return .unknown;
}

// ─── Doctor / Clean ─────────────────────────────────────────────────────────

/// Locate a binary on $PATH and capture its first stdout line as a version string.
/// Returns an owned slice the caller must free, or null if not found.
fn probeTool(name: []const u8, version_args: []const []const u8) !?[]u8 {
    var argv_buf: [8][]const u8 = undefined;
    argv_buf[0] = name;
    for (version_args, 0..) |a, i| argv_buf[i + 1] = a;
    const argv = argv_buf[0 .. 1 + version_args.len];

    var child = try std.process.spawn(main_init.io, .{
        .argv = argv,
        .stdin = .pipe,
        .stdout = .pipe,
        .stderr = .pipe,
    });

    var read_buf: [4096]u8 = undefined; // reader's internal buffer
    var stdout_buf: [65536]u8 = undefined; // where your data ends up

    var n: usize = 0; // number of bytes read
    if (child.stdout) |out| {
        var file_reader = out.reader(main_init.io, &read_buf);
        n = file_reader.interface.readSliceShort(&stdout_buf) catch 0;
    }

    var err_buf: [4096]u8 = undefined; // reader's internal buffer
    // Drain stderr so the child can exit cleanly.
    if (child.stderr) |errf| {
        var dump: [512]u8 = undefined;
        var file_reader = errf.reader(main_init.io, &err_buf);
        _ = file_reader.interface.readSliceShort(&dump) catch 0;
    }
    const result = child.wait(main_init.io) catch return null;
    switch (result) {
        .exited => |code| if (code != 0) return null,
        else => return null,
    }
    // Take the first line only.
    const slice = stdout_buf[0..n];
    const newline = std.mem.indexOfScalar(u8, slice, '\n') orelse slice.len;
    const trimmed = std.mem.trim(u8, slice[0..newline], " \t\r\n");
    return try allocator.dupe(u8, trimmed);
}

fn printDoctorEntry(name: []const u8, version: ?[]u8, required: bool) void {
    if (version) |v| {
        std.debug.print("  {s}✓{s} {s}{s:<12}{s} {s}{s}{s}\n", .{
            Ansi.bright_green,
            Ansi.reset,
            Ansi.bright_white,
            name,
            Ansi.reset,
            Ansi.dim,
            v,
            Ansi.reset,
        });
    } else {
        const marker = if (required) "✗" else "○";
        const color = if (required) Ansi.bright_red else Ansi.bright_yellow;
        const status = if (required) "missing (required)" else "missing (optional)";
        std.debug.print("  {s}{s}{s} {s}{s:<12}{s} {s}{s}{s}\n", .{
            color,
            marker,
            Ansi.reset,
            Ansi.bright_white,
            name,
            Ansi.reset,
            Ansi.dim,
            status,
            Ansi.reset,
        });
    }
}

fn runDoctorCommand() !u8 {
    std.debug.print("\n  {s}{s}metal doctor{s} {s}— environment check{s}\n\n", .{
        Ansi.bold,
        Ansi.bright_cyan,
        Ansi.reset,
        Ansi.dim,
        Ansi.reset,
    });

    const Probe = struct { name: []const u8, args: []const []const u8, required: bool };
    const probes = [_]Probe{
        .{ .name = "zig", .args = &.{"version"}, .required = true },
        .{ .name = "git", .args = &.{"--version"}, .required = false },
        .{ .name = "wasm-opt", .args = &.{"--version"}, .required = false },
        .{ .name = "brotli", .args = &.{"--version"}, .required = false },
        .{ .name = "tar", .args = &.{"--version"}, .required = false },
    };

    var any_missing_required = false;
    for (probes) |p| {
        const ver = try probeTool(p.name, p.args);
        defer if (ver) |v| allocator.free(v);
        if (ver == null and p.required) any_missing_required = true;
        printDoctorEntry(p.name, ver, p.required);
    }

    std.debug.print("\n", .{});
    if (any_missing_required) {
        MetalUI.printError("Required tooling missing", "install the items marked above");
        // `metal doctor` is meant to gate setup scripts, so a missing
        // requirement has to be visible to the shell, not only to the reader.
        return ExitCode.failure;
    }
    MetalUI.printSuccess("Doctor", "all required tools available");
    return ExitCode.ok;
}

fn rmTreeIfExists(path: []const u8) bool {
    const cwd = std.Io.Dir.cwd();
    cwd.deleteTree(main_init.io, path) catch |err| {
        // deleteTree returns success if the path doesn't exist on most platforms,
        // but log unexpected failures so the user isn't left guessing.
        if (err != error.FileNotFound) {
            MetalUI.printWarning("Could not remove", path);
        }
        return false;
    };
    return true;
}

fn runCleanCommand() !u8 {
    std.debug.print("\n  {s}{s}metal clean{s}\n\n", .{
        Ansi.bold,
        Ansi.bright_cyan,
        Ansi.reset,
    });

    const targets = [_][]const u8{
        "zig-out",
        ".zig-cache",
        "zig-cache",
    };

    var removed: usize = 0;
    const cwd = std.Io.Dir.cwd();

    for (targets) |t| {
        // Probe existence so we can report what we actually touched.
        const exists = blk: {
            cwd.access(main_init.io, t, .{}) catch break :blk false;
            break :blk true;
        };
        if (!exists) {
            std.debug.print("  {s}─{s} {s}{s}{s} {s}(skipped, not present){s}\n", .{
                Ansi.dim,
                Ansi.reset,
                Ansi.bright_white,
                t,
                Ansi.reset,
                Ansi.dim,
                Ansi.reset,
            });
            continue;
        }
        if (rmTreeIfExists(t)) {
            removed += 1;
            std.debug.print("  {s}✓{s} {s}{s}{s} {s}removed{s}\n", .{
                Ansi.bright_green,
                Ansi.reset,
                Ansi.bright_white,
                t,
                Ansi.reset,
                Ansi.dim,
                Ansi.reset,
            });
        }
    }

    std.debug.print("\n", .{});
    if (removed == 0) {
        MetalUI.printSuccess("Clean", "nothing to remove");
    } else {
        MetalUI.printSuccess("Clean", "build artifacts removed");
    }
    return ExitCode.ok;
}

fn runUpgradeCommand() u8 {
    std.debug.print("\n  {s}{s}metal upgrade{s}\n\n", .{
        Ansi.bold,
        Ansi.bright_cyan,
        Ansi.reset,
    });

    MetalUI.printStep("Upgrade", "fetching latest version...");

    var child = std.process.spawn(main_init.io, .{
        .argv = &.{ "bash", "-c", "set -o pipefail; curl -fsSL https://raw.githubusercontent.com/senet-toolbox/metal/main/install.sh | sh" },
        .stdout = .inherit,
        .stderr = .inherit,
    }) catch {
        MetalUI.printError("Upgrade failed", "could not run install script");
        return ExitCode.failure;
    };

    const result = child.wait(main_init.io) catch {
        MetalUI.printError("Upgrade failed", "process error");
        return ExitCode.failure;
    };
    switch (result) {
        .exited => |code| {
            if (code == 0) {
                MetalUI.printSuccess("Upgrade", "metal has been updated to the latest version");
                return ExitCode.ok;
            }
            MetalUI.printError("Upgrade failed", "install script exited with an error");
            return ExitCode.failure;
        },
        else => {
            MetalUI.printError("Upgrade failed", "unexpected process termination");
            return ExitCode.failure;
        },
    }
}

fn callCommand(cmd: []const []const u8) !void {
    var child = try std.process.spawn(main_init.io, .{
        .argv = cmd,
    });

    // Wait for build to complete
    const result = try child.wait(main_init.io);

    // Check result and show appropriate message
    switch (result) {
        .exited => |code| {
            if (code != 0) {
                // On failure, we might want to show the error
                // Read stderr to get the actual error message
                // Optionally show error output
                if (child.stderr) |stderr| {
                    var err_buffer: [4096]u8 = undefined;
                    var file_reader = stderr.reader(main_init.io, err_buffer[0..]);
                    const err_output = file_reader.interface.allocRemaining(allocator, .limited(4096)) catch "";
                    if (err_output.len > 0) {
                        std.debug.print("\n{s}{s}Error Details:{s}\n", .{
                            Ansi.dim,
                            Ansi.bright_red,
                            Ansi.reset,
                        });
                        // Show first few lines of error
                        var lines = std.mem.splitScalar(u8, err_output, '\n');
                        var count: usize = 0;
                        while (lines.next()) |line| {
                            if (count >= 5) {
                                std.debug.print("{s}  ... (more errors){s}\n", .{ Ansi.dim, Ansi.reset });
                                break;
                            }
                            if (line.len > 0) {
                                std.debug.print("  {s}{s}{s}\n", .{ Ansi.dim, line, Ansi.reset });
                                count += 1;
                            }
                        }
                        std.debug.print("\n", .{});
                    }
                }
                return error.CommandFailed;
            }
        },
        else => {
            return;
        },
    }
}

fn runReleaseStage(
    step: usize,
    total_steps: usize,
    stage_label: []const u8,
    success_label: []const u8,
    cmd: []const []const u8,
) !void {
    var msg_buf: [192]u8 = undefined;
    const spinner_msg = try std.fmt.bufPrint(&msg_buf, "[{d}/{d}] {s}", .{
        step,
        total_steps,
        stage_label,
    });

    var stage_spinner = SpinnerUI.Spinner.init(.braille, spinner_msg);
    _ = stage_spinner.withColor(SpinnerUI.Color.bright_cyan);
    try stage_spinner.start();

    callCommand(cmd) catch |err| {
        stage_spinner.fail(stage_label);
        return err;
    };

    stage_spinner.success(success_label);
}

const TemplateFile = struct {
    path: []const u8,
    content: []const u8,
};

const templates = [_]TemplateFile{
    .{ .path = "build.zig", .content = @embedFile("templates/build.zig") },
    .{ .path = "build.zig.zon", .content = @embedFile("templates/build.zig.zon") },
    .{ .path = "src/main.zig", .content = @embedFile("templates/src/main.zig") },
    .{ .path = "src/Theme.zig", .content = @embedFile("templates/src/Theme.zig") },
    .{ .path = "assets/icon.svg", .content = @embedFile("templates/assets/icon.svg") },
    .{ .path = "src/config.zig", .content = @embedFile("templates/src/config.zig") },
    .{ .path = "template.html", .content = @embedFile("templates/template.html") },
    .{ .path = ".gitignore", .content = @embedFile("templates/gitignore") },
    .{ .path = "src/routes/Page.zig", .content = @embedFile("templates/src/routes/Page.zig") },
    .{ .path = "src/generator.zig", .content = @embedFile("templates/src/generator.zig") },
};

/// Lines in `templates/build.zig.zon` that `create` rewrites per project.
///
/// Zig treats `.fingerprint` as a globally unique package id and validates its
/// high 32 bits as CRC-32 of `.name`, so a template that shipped a fixed pair
/// would make every scaffolded app the same package.
const name_placeholder = ".name = .metal_project_name,";
const fingerprint_placeholder = ".fingerprint = 0x0000000000000000,";

/// Folds a directory name into a bare Zig identifier, which is the only form
/// Zig accepts for a package name — `my-app` and `2048` are both rejected.
fn packageNameFromDir(gpa: std.mem.Allocator, dir_name: []const u8) ![]const u8 {
    const base = std.fs.path.basename(dir_name);

    // A leading digit, an empty name and a keyword all fail Zig's bare
    // identifier check, and one prefix fixes every one of them.
    const prefix = "app_";
    const buf = try gpa.alloc(u8, prefix.len + base.len);
    errdefer gpa.free(buf);

    const folded = buf[prefix.len..];
    for (base, folded) |c, *out| {
        out.* = if (std.ascii.isAlphanumeric(c) or c == '_') c else '_';
    }

    if (std.zig.isValidId(folded)) {
        const name = try gpa.dupe(u8, folded);
        gpa.free(buf);
        return name;
    }

    @memcpy(buf[0..prefix.len], prefix);
    return buf;
}

/// The high half must be CRC-32 of the name — Zig checks it and refuses to
/// build otherwise. The low half is the id, which Zig rejects if it is 0 or
/// 0xffffffff.
fn generateFingerprint(package_name: []const u8) u64 {
    const checksum: u64 = std.hash.Crc32.hash(package_name);

    // std 0.16 exposes no portable CSPRNG, and the id only has to be unique
    // across projects rather than unguessable, so a nanosecond clock reading
    // run through the default PRNG covers it.
    const seed: u64 = @bitCast(@as(i64, @truncate(Time.nanoTimestamp())));
    var prng = std.Random.DefaultPrng.init(seed);
    const id = prng.random().intRangeAtMost(u32, 1, 0xffff_fffe);

    return (checksum << 32) | id;
}

/// Returns the project-specific rendering of a template, or null for the
/// templates that are copied out verbatim. Caller owns the returned memory.
fn renderTemplate(gpa: std.mem.Allocator, file: TemplateFile, package_name: []const u8) !?[]const u8 {
    if (!std.mem.eql(u8, file.path, "build.zig.zon")) return null;

    if (std.mem.indexOf(u8, file.content, name_placeholder) == null or
        std.mem.indexOf(u8, file.content, fingerprint_placeholder) == null)
    {
        // The template drifted away from the placeholders. Failing here beats
        // scaffolding a project that collides with every other one.
        return error.TemplatePlaceholderMissing;
    }

    const name_line = try std.fmt.allocPrint(gpa, ".name = .{s},", .{package_name});
    defer gpa.free(name_line);

    const fingerprint_line = try std.fmt.allocPrint(
        gpa,
        ".fingerprint = 0x{x:0>16},",
        .{generateFingerprint(package_name)},
    );
    defer gpa.free(fingerprint_line);

    const named = try std.mem.replaceOwned(u8, gpa, file.content, name_placeholder, name_line);
    defer gpa.free(named);

    return try std.mem.replaceOwned(u8, gpa, named, fingerprint_placeholder, fingerprint_line);
}

test packageNameFromDir {
    const gpa = std.testing.allocator;

    const cases = [_]struct { dir: []const u8, want: []const u8 }{
        .{ .dir = "fresh", .want = "fresh" },
        .{ .dir = "my-app", .want = "my_app" },
        .{ .dir = "my app.v2", .want = "my_app_v2" },
        .{ .dir = "/tmp/nested/site", .want = "site" },
        // Not bare identifiers on their own: leading digit, keyword, empty.
        .{ .dir = "2048", .want = "app_2048" },
        .{ .dir = "test", .want = "app_test" },
        .{ .dir = "", .want = "app_" },
    };

    for (cases) |case| {
        const got = try packageNameFromDir(gpa, case.dir);
        defer gpa.free(got);
        try std.testing.expectEqualStrings(case.want, got);
        try std.testing.expect(std.zig.isValidId(got));
    }
}

test generateFingerprint {
    for ([_][]const u8{ "fresh", "my_app", "app_2048" }) |name| {
        const fingerprint = generateFingerprint(name);
        try std.testing.expectEqual(std.hash.Crc32.hash(name), @as(u32, @truncate(fingerprint >> 32)));

        const id: u32 = @truncate(fingerprint);
        try std.testing.expect(id != 0 and id != 0xffff_ffff);
    }
}

test "renderTemplate gives each project its own package identity" {
    const gpa = std.testing.allocator;

    const zon: TemplateFile = for (templates) |file| {
        if (std.mem.eql(u8, file.path, "build.zig.zon")) break file;
    } else return error.TemplateMissing;

    const first = (try renderTemplate(gpa, zon, "alpha")).?;
    defer gpa.free(first);
    const second = (try renderTemplate(gpa, zon, "beta")).?;
    defer gpa.free(second);

    try std.testing.expect(std.mem.indexOf(u8, first, ".name = .alpha,") != null);
    try std.testing.expect(std.mem.indexOf(u8, second, ".name = .beta,") != null);

    // No placeholder may survive into a scaffolded project.
    for ([_][]const u8{ first, second }) |rendered| {
        try std.testing.expect(std.mem.indexOf(u8, rendered, name_placeholder) == null);
        try std.testing.expect(std.mem.indexOf(u8, rendered, fingerprint_placeholder) == null);
    }

    // Different names must not share a fingerprint — that collision is the
    // whole bug this rendering exists to prevent.
    try std.testing.expect(generateFingerprint("alpha") >> 32 != generateFingerprint("beta") >> 32);
}

test "renderTemplate copies every other template verbatim" {
    for (templates) |file| {
        if (std.mem.eql(u8, file.path, "build.zig.zon")) continue;
        try std.testing.expectEqual(
            @as(?[]const u8, null),
            try renderTemplate(std.testing.allocator, file, "alpha"),
        );
    }
}

fn runCreateCommand(dir_name: []const u8, vapor_path: ?[]const u8) !u8 {
    const cwd = std.Io.Dir.cwd();

    // Resolve --vapor-path before writing anything, so a typo leaves no
    // half-made project behind.
    const vapor_abs: ?[:0]u8 = if (vapor_path) |vp| blk: {
        const zon = try std.fs.path.join(allocator, &.{ vp, "build.zig.zon" });
        defer allocator.free(zon);
        cwd.access(main_init.io, zon, .{}) catch {
            MetalUI.printError("Not a vapor checkout (no build.zig.zon)", vp);
            return ExitCode.usage;
        };
        break :blk try cwd.realPathFileAlloc(main_init.io, vp, allocator);
    } else null;
    defer if (vapor_abs) |p| allocator.free(p);

    // Probe first. `createDirPath` is mkdir -p: it succeeds on a directory that
    // already exists, so catching PathAlreadyExists from it never fires and
    // `create` would overwrite an existing project's files one by one.
    if (cwd.access(main_init.io, dir_name, .{})) |_| {
        MetalUI.printError("Directory already exists", dir_name);
        return ExitCode.failure;
    } else |_| {}

    try cwd.createDirPath(main_init.io, dir_name);

    var project_dir = try cwd.openDir(main_init.io, dir_name, .{});
    defer project_dir.close(main_init.io);

    MetalUI.printCreateStart(dir_name);

    const package_name = try packageNameFromDir(allocator, dir_name);
    defer allocator.free(package_name);

    for (templates, 0..) |file, i| {
        var buffer: [4096]u8 = undefined;
        const message = try std.fmt.bufPrint(&buffer, "Creating {s}", .{file.path});
        MetalUI.printCreateStep(i + 1, templates.len, message, "📄");

        if (std.fs.path.dirname(file.path)) |dirname| {
            try project_dir.createDirPath(main_init.io, dirname);
        }

        const new_file = try project_dir.createFile(main_init.io, file.path, .{});
        defer new_file.close(main_init.io);
        var w_buffer: [4096]u8 = undefined;
        var file_writer = new_file.writer(main_init.io, &w_buffer);

        const rendered = try renderTemplate(allocator, file, package_name);
        defer if (rendered) |content| allocator.free(content);

        try file_writer.interface.writeAll(rendered orelse file.content);
        try file_writer.interface.flush();
    }

    if (vapor_abs) |abs| {
        MetalUI.printStep("Linking", abs);
        linkLocalVapor(project_dir, dir_name, abs) catch |err| {
            MetalUI.printError("Could not add the local vapor dependency", @errorName(err));
            return ExitCode.failure;
        };
        MetalUI.printCreateSuccess(dir_name);
        return ExitCode.ok;
    }

    // Pull in the vapor release this template is written against.
    MetalUI.printStep("Fetching", "vapor " ++ vapor_ref);
    zigFetchSave("vapor", packageUrl(.vapor), .{ .path = dir_name }) catch {
        MetalUI.printError("Could not fetch vapor into", dir_name);
        print("\n  {s}The files are on disk, but the project will not build until you{s}\n", .{ Ansi.dim, Ansi.reset });
        print("  {s}run `metal add vapor` inside it.{s}\n\n", .{ Ansi.dim, Ansi.reset });
        // Files were written, so this is not a clean failure — but the scaffold
        // cannot build yet, and a script that chains `create && build` needs to
        // stop here rather than fail confusingly one step later.
        return ExitCode.failure;
    };

    MetalUI.printCreateSuccess(dir_name);
    return ExitCode.ok;
}

/// Points the new project's build.zig.zon at a local vapor checkout, for
/// developing vapor and an app side by side. Zig requires `.path` to be
/// relative to the build root.
fn linkLocalVapor(project_dir: std.Io.Dir, dir_name: []const u8, vapor_abs: []const u8) !void {
    const io = main_init.io;
    const project_abs = try std.Io.Dir.cwd().realPathFileAlloc(io, dir_name, allocator);
    defer allocator.free(project_abs);
    const rel = try std.fs.path.relative(allocator, project_abs, null, project_abs, vapor_abs);
    defer allocator.free(rel);

    const zon = try project_dir.readFileAlloc(io, "build.zig.zon", allocator, .limited(64 * 1024));
    defer allocator.free(zon);

    const empty_deps = ".dependencies = .{},";
    const at = std.mem.indexOf(u8, zon, empty_deps) orelse return error.TemplateMissing;
    const updated = try std.fmt.allocPrint(allocator, "{s}.dependencies = .{{\n        .vapor = .{{ .path = \"{s}\" }},\n    }},{s}", .{
        zon[0..at], rel, zon[at + empty_deps.len ..],
    });
    defer allocator.free(updated);

    try project_dir.writeFile(io, .{ .sub_path = "build.zig.zon", .data = updated });
}

/// The vapor version new projects are pinned to. The scaffold templates are
/// written against this version's API, so it moves together with them, not on
/// its own: bump it when metal is released against a new vapor tag.
///
/// "main" is the development placeholder; tag a vapor release and set it here
/// before releasing metal.
pub const vapor_ref = "main";

const Packages = enum {
    auth,
    vaporize,
    vapor,
};

fn fetchPackage(package: []const u8) !void {
    const package_tag = std.meta.stringToEnum(Packages, package) orelse {
        MetalUI.printError("Unknown package", package);
        print("\n  {s}Available packages:{s} auth, vaporize, vapor\n\n", .{ Ansi.dim, Ansi.reset });
        return error.PackageNotFound;
    };

    const url = packageUrl(package_tag);

    MetalUI.printStep("Fetching", package);

    zigFetchSave(package, url, .inherit) catch {
        MetalUI.printError("Failed to fetch package", package);
        return error.ZigFetchFailed;
    };

    MetalUI.printSuccess("Added", package);
}

fn packageUrl(package_tag: Packages) []const u8 {
    return switch (package_tag) {
        .auth => "git+https://github.com/tether-labs/auth",
        .vaporize => "git+https://github.com/tether-labs/vaporize",
        .vapor => "git+https://github.com/senet-toolbox/vapor#" ++ vapor_ref,
    };
}

/// Runs `zig fetch --save=<name> <url>`.
///
/// Zig resolves the URL to a concrete commit, computes the hash and writes the
/// `.url` / `.hash` pair into build.zig.zon itself. Letting it do that is what
/// keeps installs on the current release — a hand-written version pin here goes
/// stale the moment vapor is tagged again.
///
/// Note: `--save` overwrites an existing dependency of the same name *keeping
/// its field name*, so a pre-existing `.path` entry would be left as a `.path`
/// holding a URL. Templates must therefore not pre-declare these packages.
fn zigFetchSave(package: []const u8, url: []const u8, cwd: std.process.Child.Cwd) !void {
    const save_arg = try std.fmt.allocPrint(allocator, "--save={s}", .{package});
    defer allocator.free(save_arg);

    var child = try std.process.spawn(main_init.io, .{
        .argv = &.{ "zig", "fetch", save_arg, url },
        .stdout = .pipe,
        .stderr = .pipe,
        .cwd = cwd,
    });

    const stdout = child.stdout.?;
    var read_buf: [4096]u8 = undefined;
    var file_reader = stdout.reader(main_init.io, &read_buf);
    const output = try file_reader.interface.allocRemaining(allocator, .limited(1024 * 1024));
    allocator.free(output);

    const result = try child.wait(main_init.io);
    if (result.exited != 0) return error.ZigFetchFailed;
}

const RunOptions = struct {
    static: bool = false,
    generate: bool = false,
    release: bool = false,
    ssg: bool = false,
    open: bool = false,
    port: ?u16 = null,
    host: ?[]const u8 = null,
    port_explicit: bool = false,
};

fn parseRunOptions(args: []const [:0]const u8) RunOptions {
    var run_options = RunOptions{};
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.startsWith(u8, arg, "-")) {
            if (std.mem.eql(u8, arg, "-s") or std.mem.eql(u8, arg, "--static")) {
                run_options.static = true;
            } else if (std.mem.eql(u8, arg, "-g") or std.mem.eql(u8, arg, "--generate")) {
                run_options.generate = true;
            } else if (std.mem.eql(u8, arg, "-r") or std.mem.eql(u8, arg, "--release")) {
                run_options.release = true;
            } else if (std.mem.eql(u8, arg, "--ssg")) {
                run_options.ssg = true;
            } else if (std.mem.eql(u8, arg, "--open")) {
                run_options.open = true;
            } else if (std.mem.eql(u8, arg, "--port") or std.mem.eql(u8, arg, "-p")) {
                if (i + 1 < args.len) {
                    const parsed = std.fmt.parseInt(u16, args[i + 1], 10) catch {
                        MetalUI.printWarning("Invalid port", args[i + 1]);
                        i += 1;
                        continue;
                    };
                    run_options.port = parsed;
                    run_options.port_explicit = true;
                    i += 1;
                }
            } else if (std.mem.eql(u8, arg, "--host")) {
                if (i + 1 < args.len) {
                    run_options.host = args[i + 1];
                    i += 1;
                }
            } else {
                MetalUI.printWarning("Unknown flag", arg);
            }
        }
    }
    return run_options;
}

/// Best-effort check whether a TCP port is bindable on 127.0.0.1. We bind, then
/// immediately close — racy by definition, but enough for `is the dev server
/// already on this port?` UX.
const posix = @import("posix.zig");
fn isPortFree(port: u16) bool {
    const sock = posix.socket(
        std.posix.AF.INET,
        std.posix.SOCK.STREAM | std.posix.SOCK.CLOEXEC,
        0,
    ) catch return false;
    defer posix.close(sock);

    // SO_REUSEADDR so previous TIME_WAIT sockets don't make us think the port is taken.
    const one: c_int = 1;
    _ = std.posix.setsockopt(
        sock,
        std.posix.SOL.SOCKET,
        std.posix.SO.REUSEADDR,
        std.mem.asBytes(&one),
    ) catch {};

    const self_addr = std.Io.net.IpAddress.parse("127.0.0.1", port) catch return false;

    // Build a proper sockaddr_in from the parsed IpAddress
    var addr: std.posix.sockaddr.in = .{
        .family = std.posix.AF.INET,
        .port = std.mem.nativeToBig(u16, port),
        .addr = @bitCast(self_addr.ip4.bytes),
        .zero = .{0} ** 8,
    };

    const addr_len: std.posix.socklen_t = switch (self_addr) {
        .ip4 => @sizeOf(std.posix.sockaddr.in),
        .ip6 => @sizeOf(std.posix.sockaddr.in6),
    };

    posix.bind(sock, @ptrCast(&addr), addr_len) catch |err| {
        std.debug.print("Failed to bind socket: {any}\n", .{err});
        return false;
    };

    return true;
}

/// Returns the first free port in [start, start+span). Falls back to `start`
/// if nothing in the range is free so the caller still gets a deterministic value.
fn findFreePort(start: u16, span: u16) u16 {
    var p: u32 = start;
    while (p < @as(u32, start) + span and p < 65535) : (p += 1) {
        if (isPortFree(@intCast(p))) return @intCast(p);
    }
    return start;
}

fn findFreePortExcept(start: u16, span: u16, reserved_port: u16) u16 {
    var p: u32 = start;
    while (p < @as(u32, start) + span and p < 65535) : (p += 1) {
        const candidate: u16 = @intCast(p);
        if (candidate == reserved_port) continue;
        if (isPortFree(candidate)) return candidate;
    }

    if (start != reserved_port) return start;
    return start + 1;
}

/// Parses the tail of a `metal <fw> gen ...` invocation.
/// `gen_args` should already be sliced past the "gen" token, so the first
/// positional is the gen type and the second (optional) is the name.
fn parseGenOptions(gen_args: []const [:0]const u8) GenOptions {
    var options = GenOptions{};

    var positional_idx: usize = 0;
    var i: usize = 0;
    while (i < gen_args.len) : (i += 1) {
        const arg = gen_args[i];

        if (std.mem.startsWith(u8, arg, "-")) {
            if (std.mem.eql(u8, arg, "-o") or std.mem.eql(u8, arg, "--output")) {
                if (i + 1 < gen_args.len) {
                    options.output_path = gen_args[i + 1];
                    i += 1;
                }
            } else if (std.mem.eql(u8, arg, "-q") or std.mem.eql(u8, arg, "--quiet")) {
                options.quiet = true;
            } else if (std.mem.eql(u8, arg, "-t") or std.mem.eql(u8, arg, "--template")) {
                if (i + 1 < gen_args.len) {
                    options.template = gen_args[i + 1];
                    i += 1;
                }
            } else if (std.mem.eql(u8, arg, "--dry-run")) {
                options.dry_run = true;
            } else if (std.mem.eql(u8, arg, "-f") or std.mem.eql(u8, arg, "--force")) {
                options.force = true;
            } else {
                MetalUI.printWarning("Unknown flag", arg);
            }
        } else {
            switch (positional_idx) {
                0 => options.gen_type = arg,
                1 => options.name = arg,
                else => {},
            }
            positional_idx += 1;
        }
    }

    return options;
}

fn runGenCommand(contents: *const Contents, options: GenOptions) !void {
    // Validate the gen type before doing anything visible.
    const gen_type_enum = contents.getGenType(options.gen_type);
    if (gen_type_enum == .null) {
        MetalUI.printError("Unknown generation type", options.gen_type);
        print(
            "  {s}Available:{s} page, component, card, button, fetch (vapor); crud, crudfull, database (reverb)\n\n",
            .{ Ansi.dim, Ansi.reset },
        );
        return error.UnknownGenType;
    }

    if (!options.quiet) {
        MetalUI.printStep("Generating", options.gen_type);
    }

    try generateDefaultFile(contents, options, gen_type_enum);
}

fn generateDefaultFile(
    contents: *const Contents,
    options: GenOptions,
    gen_type_enum: @import("file_contents.zig").GenType,
) !void {
    const cwd = std.Io.Dir.cwd();
    const raw_name: []const u8 = options.name orelse "Basic";
    if (raw_name.len == 0) {
        MetalUI.printError("Missing name", "usage: metal <fw> gen <type> <Name>");
        return error.MissingName;
    }

    // Capitalized struct/file name (e.g. `home` → `Home`).
    const first_upper = std.ascii.toUpper(raw_name[0]);
    const rest = raw_name[1..];
    const struct_name = try std.fmt.allocPrint(allocator, "{c}{s}", .{ first_upper, rest });
    defer allocator.free(struct_name);

    // Resolve the final on-disk path.
    const output_path = if (options.output_path) |op|
        try allocator.dupe(u8, op)
    else
        try std.fmt.allocPrint(allocator, "{s}/{s}.zig", .{
            defaultGenDir(options.gen_type),
            struct_name,
        });
    defer allocator.free(output_path);

    // Refuse to overwrite without --force.
    if (!options.force) {
        if (cwd.statFile(main_init.io, output_path, .{})) |_| {
            MetalUI.printError("File already exists", output_path);
            print("  {s}Use {s}--force{s}{s} to overwrite\n\n", .{
                Ansi.dim,
                Ansi.bright_yellow,
                Ansi.reset,
                Ansi.dim,
            });
            return error.FileAlreadyExists;
        } else |_| {}
    }

    const content = try contents.getContent(.Gen, gen_type_enum, struct_name);

    if (options.dry_run) {
        MetalUI.printStep("Would create", output_path);
        print("  {s}── preview ──{s}\n", .{ Ansi.dim, Ansi.reset });
        // Print first ~20 lines so the user can sanity-check.
        const max_lines: usize = 20;
        var total_lines: usize = 0;
        var it1 = std.mem.splitScalar(u8, content, '\n');
        while (it1.next()) |_| total_lines += 1;

        var printed: usize = 0;
        var it2 = std.mem.splitScalar(u8, content, '\n');
        while (it2.next()) |line| {
            if (printed >= max_lines) break;
            print("  {s}{s}{s}\n", .{ Ansi.dim, line, Ansi.reset });
            printed += 1;
        }
        if (total_lines > printed) {
            print("  {s}… ({d} more lines){s}\n", .{ Ansi.dim, total_lines - printed, Ansi.reset });
        }
        print("\n", .{});
        return;
    }

    // Make parent dirs as needed.
    if (std.fs.path.dirname(output_path)) |parent| {
        try cwd.createDirPath(main_init.io, parent);
    }

    const file = cwd.createFile(main_init.io, output_path, .{ .truncate = true }) catch |err| {
        MetalUI.printError("Failed to create file", output_path);
        return err;
    };
    defer file.close(main_init.io);
    var w_buffer: [4096]u8 = undefined;
    var file_writer = file.writer(main_init.io, &w_buffer);
    try file_writer.interface.writeAll(content);
    // Without this the buffered bytes are dropped on close and the file is empty.
    try file_writer.interface.flush();

    if (!options.quiet) {
        MetalUI.printSuccess("Generated", output_path);
    }
}

fn buildCommand(cmds: []const []const u8) !void {
    if (std.mem.eql(u8, "x86_64-linux", cmds[0])) {
        try callCommand(&.{ "zig", "build-exe", "src/main.zig", "-target", "x86_64-linux", "-O", "ReleaseFast" });
        return;
    }
    if (std.mem.eql(u8, "arm-macos", cmds[0])) {
        try callCommand(&.{ "zig", "build-exe", "server.zig", "-target", "aarch64-macos", "-O", "ReleaseFast" });
        return;
    }
}

/// Build the zig project with the appropriate flags.
fn runBuild(opts: RunOptions) !void {
    var cmd_buf: [8][]const u8 = undefined;
    var cmd_len: usize = 0;

    cmd_buf[cmd_len] = "zig";
    cmd_len += 1;
    cmd_buf[cmd_len] = "build";
    cmd_len += 1;

    if (opts.generate) {
        cmd_buf[cmd_len] = "-Dgenerate=true";
        cmd_len += 1;
    }
    if (opts.static) {
        cmd_buf[cmd_len] = "-Dstatic=true";
        cmd_len += 1;
    }
    if (opts.release) {
        cmd_buf[cmd_len] = "--release=small";
        cmd_len += 1;
    }

    if (!opts.release) {
        MetalUI.printStep("Building", "debug");
        callCommand(cmd_buf[0..cmd_len]) catch {
            MetalUI.printError("Build failed", "see errors above\n");
            return error.CommandFailed;
        };
    } else {
        const total_release_steps = 4;
        std.debug.print("\n", .{});
        MetalUI.printStep("Release pipeline", "starting");

        runReleaseStage(
            1,
            total_release_steps,
            "Building --release=small",
            "Release-small build complete",
            cmd_buf[0..cmd_len],
        ) catch {
            MetalUI.printError("Build failed", "release-small stage failed");
            return error.CommandFailed;
        };

        runReleaseStage(
            2,
            total_release_steps,
            "Preparing release output folder",
            "Release output folder ready",
            &.{ "mkdir", "-p", "zig-out/release" },
        ) catch {
            MetalUI.printError("Build failed", "could not prepare zig-out/release");
            return error.FailedToCreateReleaseFolder;
        };

        runReleaseStage(
            3,
            total_release_steps,
            "Optimizing wasm with wasm-opt -Oz",
            "Wasm optimization complete",
            &.{
                "wasm-opt",
                "zig-out/bin/vapor.wasm",
                "-Oz",
                "-o",
                "zig-out/release/vapor.wasm",
                "--enable-bulk-memory",
                "--strip-debug",
                "--enable-sign-ext",
                "--enable-nontrapping-float-to-int",
            },
        ) catch {
            MetalUI.printError("Build failed", "wasm-opt stage failed");
            return error.FailedToOptimizeWasm;
        };

        runReleaseStage(
            4,
            total_release_steps,
            "Compressing wasm with brotli -q 11",
            "Brotli compression complete",
            &.{ "brotli", "-f", "-q", "11", "zig-out/release/vapor.wasm" },
        ) catch {
            MetalUI.printError("Build failed", "brotli compression failed");
            return error.CommandFailed;
        };
    }

    MetalUI.printSuccess("Build", "complete");
}

const FrameworkType = enum {
    none,
    vapor,
    reverb,
    canopy,
};

var framework_type: FrameworkType = .none;

// ─── File serving ────────────────────────────────────────────────────────────

const mimeTypes = .{
    .{ ".html", "text/html; charset=utf8" },
    .{ ".js", "application/javascript" },
    .{ ".wasm", "application/wasm" },
    .{ ".css", "text/css" },
    .{ ".png", "image/png" },
    .{ ".jpg", "image/jpeg" },
    .{ ".webp", "image/webp" },
    .{ ".gif", "image/gif" },
    .{ ".svg", "image/svg+xml" },
    .{ ".txt", "text/plain; charset=utf8" },
    .{ ".woff", "font/woff" },
    .{ ".woff2", "font/woff2" },
    .{ ".md", "text/html; charset=utf8" },
    .{ ".zig", "text/html; charset=utf8" },
    .{ ".tsx", "text/html; charset=utf8" },
    .{ ".mp4", "video/mp4" },
    .{ ".ico", "image/x-icon" },
};

const staticExtensions = .{
    ".wasm", ".js",  ".css",  ".png",  ".jpg",   ".webp", ".gif",
    ".svg",  ".ico", ".txt",  ".woff", ".woff2", ".zig",  ".md",
    ".tsx",  ".mp4", ".html",
};

const compressibleExtensions = .{
    .{ ".wasm", "application/wasm" },
    // .{ ".js", "application/javascript" },
    // .{ ".css", "text/css" },
    // .{ ".html", "text/html; charset=utf8" },
};

pub fn mimeForPath(path: []const u8) []const u8 {
    const extension = std.fs.path.extension(path);
    inline for (mimeTypes) |kv| {
        if (std.mem.eql(u8, extension, kv[0])) return kv[1];
    }
    return "text/html; charset=utf8";
}

/// Strips the query string and fragment from a request target.
///
/// `handleRequest` matches on file extension, and `/static/app.js?v=3` has the
/// extension `.js?v=3` — so without this the cache-busting query strings every
/// browser sends would fall through to the SPA fallback.
pub fn requestPathOnly(target: []const u8) []const u8 {
    const end = std.mem.indexOfAny(u8, target, "?#") orelse target.len;
    return target[0..end];
}

/// Whether a request path is safe to resolve against the project directory.
///
/// The dev server opens `"." ++ path`, so a `..` segment escapes the project
/// and reads anything the developer can read. That matters more than it looks:
/// this server has no authentication, and `--host 0.0.0.0` puts it on the
/// local network.
///
/// The check is a whitelist on structure rather than a blacklist on strings:
/// the path must be absolute, and every segment must be an ordinary name.
/// Percent-encoded dots are rejected too — nothing in this path decodes them
/// today, but that is a property of the current server, not a guarantee.
pub fn isSafeRequestPath(path: []const u8) bool {
    if (path.len == 0 or path[0] != '/') return false;

    // A NUL truncates the name at the syscall boundary, so "/a.css\x00/../.."
    // would be checked as one thing and opened as another.
    if (std.mem.indexOfScalar(u8, path, 0) != null) return false;

    // Backslash is a separator on Windows and an ordinary character here;
    // rejecting it keeps one meaning of a path across platforms.
    if (std.mem.indexOfScalar(u8, path, '\\') != null) return false;

    if (std.ascii.indexOfIgnoreCase(path, "%2e") != null) return false;
    if (std.ascii.indexOfIgnoreCase(path, "%2f") != null) return false;
    if (std.ascii.indexOfIgnoreCase(path, "%5c") != null) return false;

    var segments = std.mem.splitScalar(u8, path[1..], '/');
    while (segments.next()) |segment| {
        if (std.mem.eql(u8, segment, "..")) return false;
    }

    return true;
}

test requestPathOnly {
    try std.testing.expectEqualStrings("/static/app.js", requestPathOnly("/static/app.js?v=3"));
    try std.testing.expectEqualStrings("/index.html", requestPathOnly("/index.html#top"));
    try std.testing.expectEqualStrings("/style.css", requestPathOnly("/style.css"));
    try std.testing.expectEqualStrings("/", requestPathOnly("/?a=b"));
    try std.testing.expectEqualStrings("", requestPathOnly("?a=b"));

    // The extension is what routing keys off, and a query string hides it.
    try std.testing.expectEqualStrings("text/css", mimeForPath(requestPathOnly("/a.css?v=1")));
}

test isSafeRequestPath {
    const safe = [_][]const u8{
        "/",
        "/index.html",
        "/static/style.css",
        "/deeply/nested/path/file.woff2",
        // A dot inside a segment is an ordinary character.
        "/a..b/c.js",
        "/...js",
        // A single dot segment cannot leave the directory.
        "/./a.css",
    };
    for (safe) |p| try std.testing.expect(isSafeRequestPath(p));

    const unsafe = [_][]const u8{
        // The extension check would let each of these through to openFile.
        "/../../../../etc/passwd.css",
        "/static/../../secrets.js",
        "/..",
        "/a/../../b.png",
        // Percent-encoded forms, in case anything upstream starts decoding.
        "/%2e%2e/%2e%2e/etc/passwd.css",
        "/%2E%2E/secrets.js",
        "/static%2f..%2fsecret.css",
        // Not absolute.
        "static/style.css",
        "",
        // Separator confusion and truncation.
        "/..\\..\\windows.css",
        "/a.css\x00/../../etc/passwd",
    };
    for (unsafe) |p| try std.testing.expect(!isSafeRequestPath(p));
}

test browsableHost {
    // A wildcard bind is not an address a browser can open.
    try std.testing.expectEqualStrings("localhost", browsableHost("0.0.0.0"));
    try std.testing.expectEqualStrings("localhost", browsableHost("::"));
    try std.testing.expectEqualStrings("127.0.0.1", browsableHost("127.0.0.1"));
    try std.testing.expectEqualStrings("192.168.1.10", browsableHost("192.168.1.10"));
}

test "dev server defaults to loopback" {
    // Loom's own default is 0.0.0.0. This server reads the project directory
    // with no authentication, so the default here has to override that.
    try std.testing.expectEqualStrings("127.0.0.1", default_host);
    try std.testing.expectEqualStrings("127.0.0.1", (ReverbConfig{}).host);
}

/// Whether a request is a page navigation. Browsers send `text/html` in Accept
/// when navigating; fetch() sends `*/*` unless told otherwise.
fn acceptsHtml(accept: []const u8) bool {
    return std.mem.indexOf(u8, accept, "text/html") != null;
}

test acceptsHtml {
    try std.testing.expect(acceptsHtml("text/html,application/xhtml+xml,*/*;q=0.8"));
    try std.testing.expect(!acceptsHtml("*/*"));
    try std.testing.expect(!acceptsHtml(""));
}

fn isStaticFile(path: []const u8) bool {
    const extension = std.fs.path.extension(path);
    inline for (staticExtensions) |ext| {
        if (std.mem.eql(u8, extension, ext)) return true;
    }
    return false;
}

var static_mode: bool = false;
var generate: bool = false;
var ssg: bool = false;
var release_mode: bool = false;
var allocator = std.heap.page_allocator;
var watcher_ws_port_global: u16 = 3003;

const reload_div =
    \\  <div id="reload-indicator" class="reload-indicator">
    \\    <div class="reload-spinner"></div>
    \\    <span>Reloading... <span id="reload-timer">0.0</span>s</span>
    \\  </div>
;

const dev_ws_script_template =
    \\<script>
    \\const socket = new WebSocket("ws://localhost:{d}");
    \\socket.onopen = function (event) {{}};
    \\let reloadStartTime = null;
    \\let reloadTimerInterval = null;
    \\function showReloading() {{
    \\  const reloadIndicator = document.getElementById("reload-indicator");
    \\  const reloadTimer = document.getElementById("reload-timer");
    \\  if (!reloadIndicator || !reloadTimer) return;
    \\  reloadStartTime = performance.now();
    \\  reloadIndicator.classList.add("visible");
    \\  reloadTimerInterval = setInterval(() => {{
    \\    const elapsed = (performance.now() - reloadStartTime) / 1000;
    \\    reloadTimer.textContent = elapsed.toFixed(1);
    \\  }}, 100);
    \\}}
    \\function hideReloading() {{
    \\  const reloadIndicator = document.getElementById("reload-indicator");
    \\  const reloadTimer = document.getElementById("reload-timer");
    \\  if (!reloadIndicator) return;
    \\  if (reloadStartTime && reloadTimer) {{
    \\    const elapsed = (performance.now() - reloadStartTime) / 1000;
    \\    reloadTimer.textContent = elapsed.toFixed(2);
    \\  }}
    \\  clearInterval(reloadTimerInterval);
    \\  reloadTimerInterval = null;
    \\  reloadStartTime = null;
    \\  setTimeout(() => {{
    \\    reloadIndicator.classList.remove("visible");
    \\  }}, 300);
    \\}}
    \\socket.onmessage = async function (event) {{
    \\  if (event.data === "reloading") {{ showReloading(); return; }}
    \\  if (event.data === "refresh") {{
    \\    const rootElement = document.getElementById("contents");
    \\    if (rootElement) rootElement.innerHTML = "";
    \\    window.location.reload();
    \\  }}
    \\  hideReloading();
    \\}};
    \\socket.onerror = function (error) {{ console.error("WebSocket error:", error); }};
    \\socket.onclose = function (event) {{ console.log("WebSocket connection closed:", event.code, event.reason); }};
    \\</script>
    \\  <div id="reload-indicator" class="reload-indicator">
    \\    <div class="reload-spinner"></div>
    \\    <span>Reloading... <span id="reload-timer">0.0</span>s</span>
    \\  </div>
;

const hardcoded_dev_ws_url = "ws://localhost:5173";

fn shouldPatchDevWebSocketScript(path: []const u8) bool {
    return !release_mode and
        (std.mem.endsWith(u8, path, "bundle.min.js") or
            std.mem.endsWith(u8, path, "wasi_obj.js") or
            std.mem.endsWith(u8, path, "wasi_obj_1.js"));
}

fn patchDevWebSocketPort(gpa: std.mem.Allocator, content: []const u8) !?[]u8 {
    if (std.mem.indexOf(u8, content, hardcoded_dev_ws_url) == null) return null;

    const dynamic_ws_url = try std.fmt.allocPrint(gpa, "ws://localhost:{d}", .{watcher_ws_port_global});

    const patched_len = std.mem.replacementSize(u8, content, hardcoded_dev_ws_url, dynamic_ws_url);
    const patched = try gpa.alloc(u8, patched_len);
    _ = std.mem.replace(u8, content, hardcoded_dev_ws_url, dynamic_ws_url, patched);
    return patched;
}

fn sendDevContent(gpa: std.mem.Allocator, ctx: *Reverb.Context, content_type: []const u8, payload: []const u8) !void {
    // Client.write can retain a pending slice after this handler returns, so
    // this must not be freed here. It belongs to the per-request arena, which
    // is reset only when this thread takes its next request.
    const response = try std.fmt.allocPrint(
        gpa,
        "HTTP/1.1 200 OK\r\n" ++
            "Vary: Origin\r\n" ++
            "Content-Type: {s}\r\n" ++
            "Content-Length: {d}\r\n\r\n" ++
            "{s}",
        .{ content_type, payload.len, payload },
    );
    try ctx.RAW(response);
}

/// Scratch memory for building one response.
///
/// Reverb can hold on to a response slice after `handleRequest` returns, which
/// is why the previous code leaked every allocation on purpose. Resetting at
/// the *start* of the next request on this thread keeps that property — the
/// last response stays valid until this thread is asked for another one —
/// while bounding total usage at (threads x largest response) instead of
/// growing without limit for as long as the dev server runs.
threadlocal var request_arena: std.heap.ArenaAllocator = undefined;
threadlocal var request_arena_initialized: bool = false;

/// Must be called exactly once per request, before any response allocation.
fn beginRequest() std.mem.Allocator {
    if (request_arena_initialized) {
        _ = request_arena.reset(.retain_capacity);
    } else {
        request_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        request_arena_initialized = true;
    }
    return request_arena.allocator();
}

fn handleRequest(ctx: *Reverb.Context) !void {
    const ra = beginRequest();

    const request_path = requestPathOnly(ctx.http_header.path);
    var path: []const u8 = request_path;
    const mime = mimeForPath(path);

    if (std.ascii.indexOfIgnoreCase(path, "com.chrome.devtools")) |_| {
        try ctx.STRING("Chrome Dev Tools Not found");
        return;
    }

    // Everything below resolves `path` against the project directory, so it has
    // to be known-good before the first join, not after.
    if (!isSafeRequestPath(path)) {
        try ctx.ERROR(400, "Bad request path");
        return;
    }

    if (generate or static_mode) {
        // Release/static mode: serve from release/ directory
        if (path.len <= 1) {
            // "/" -> serve the prerendered root index
            path = "/release/index.html";
        } else if (isStaticFile(path)) {
            // /static/style.css -> /release/static/style.css
            path = try std.fmt.allocPrint(ra, "/release{s}", .{path});
        } else {
            // /components -> /release/components/index.html
            path = try std.fmt.allocPrint(ra, "/release{s}/index.html", .{path});
        }
    } else {
        // Dev mode: SPA, everything goes to template.html except static files
        if (path.len <= 1) {
            path = "/template.html";
        } else if (isStaticFile(path)) {
            // serve as-is (e.g. /static/style.css from CWD)
        } else if (!acceptsHtml(ctx.http_header.accept)) {
            // A fetch() to a path the dev server does not have, e.g. an API
            // that is not running. Answering with the app shell would hand the
            // caller a 200 and a page of HTML instead of an error.
            try ctx.ERROR(404, "Not found");
            return;
        } else {
            path = "/template.html";
        }
    }

    if (std.ascii.indexOfIgnoreCase(path, "vapor.wasm")) |_| {
        path = "/zig-out/bin/vapor.wasm";
        if (release_mode) path = "/zig-out/release/vapor.wasm";
    }

    // The JS runtime ships with vapor; the app's build installs the copy that
    // matches the wasm next to it.
    if (std.mem.eql(u8, path, "/bundle.min.js")) {
        path = "/zig-out/bin/bundle.min.js";
    }

    // Remembered so the release-mode fallback below can retry without the
    // compression suffix, rather than the unrewritten request path.
    const uncompressed_path = path;

    if (release_mode) {
        const encoding = ctx.http_header.accept_encoding;
        if (encoding.len > 1) {
            inline for (compressibleExtensions) |entry| {
                if (std.mem.eql(u8, mime, entry[1])) {
                    if (std.mem.indexOf(u8, encoding, "br") != null) {
                        path = try std.fmt.allocPrint(ra, "{s}.br", .{path});
                        ctx.http_header.content_encoding = "br";
                    } else if (std.mem.indexOf(u8, encoding, "gzip") != null) {
                        path = try std.fmt.allocPrint(ra, "{s}.gzip", .{path});
                        ctx.http_header.content_encoding = "gzip";
                    }
                }
            }
        }
    }

    const file_cwd = try std.fmt.allocPrint(ra, ".{s}", .{path});
    const cwd = std.Io.Dir.cwd();
    const file = cwd.openFile(main_init.io, file_cwd, .{}) catch |err| blk: {
        std.debug.print("Opening file: {any} {s}\n", .{ err, file_cwd });
        if (release_mode and ctx.http_header.content_encoding.len > 0) {
            ctx.http_header.content_encoding = "";
            // Derived from `request_path`, not `ctx.http_header.path` — the raw
            // target still carries the query string, and only the stripped
            // form was checked by isSafeRequestPath.
            const original = try std.fmt.allocPrint(ra, ".{s}", .{uncompressed_path});
            break :blk cwd.openFile(main_init.io, original, .{}) catch {
                if (isStaticFile(request_path)) {
                    try ctx.ERROR(404, "Not found");
                    return;
                }
                // Fallback: in release mode serve the root index, in dev serve template
                const fallback = if (generate or static_mode) "./release/index.html" else "./template.html";
                break :blk cwd.openFile(main_init.io, fallback, .{}) catch |fallback_err| {
                    std.debug.print("Opening file: {any} {s}\n", .{ fallback_err, fallback });
                    try ctx.ERROR(404, "Not found");
                    return;
                };
            };
        }
        // A missing asset is a 404. Only routes fall back to the app shell,
        // where the client-side router takes over.
        if (isStaticFile(request_path)) {
            try ctx.ERROR(404, "Not found");
            return;
        }
        const fallback = if (generate or static_mode) "./release/index.html" else "./template.html";
        break :blk cwd.openFile(main_init.io, fallback, .{}) catch |fallback_err| {
            std.debug.print("Opening file: {any} {s}\n", .{ fallback_err, fallback });
            try ctx.ERROR(404, "Not found");
            return;
        };
    };

    if (shouldPatchDevWebSocketScript(path)) {
        defer file.close(main_init.io);
        var read_buf: [1024 * 1024]u8 = undefined;
        var file_reader = file.reader(main_init.io, &read_buf);
        const content = file_reader.interface.allocRemaining(ra, .limited(4 * 1024 * 1024)) catch {
            try ctx.ERROR(500, "Failed to read script");
            return;
        };

        const patched_content = try patchDevWebSocketPort(ra, content);
        const payload = patched_content orelse content;

        try sendDevContent(ra, ctx, "application/javascript", payload);
        return;
    }

    // Inject dev WebSocket script into template.html in non-release mode
    if (!release_mode and std.mem.endsWith(u8, path, "/template.html")) {
        defer file.close(main_init.io);
        var read_buf: [1024 * 1024]u8 = undefined;
        var file_reader = file.reader(main_init.io, &read_buf);
        const content = file_reader.interface.allocRemaining(ra, .limited(1024 * 1024)) catch {
            try ctx.ERROR(500, "Failed to read template");
            return;
        };

        const script = std.fmt.allocPrint(ra, dev_ws_script_template, .{watcher_ws_port_global}) catch {
            try ctx.ERROR(500, "Failed to format script");
            return;
        };

        // Not freed on the way out: the arena holds these until this thread
        // starts its next request, which is after reverb has written them.
        if (std.mem.indexOf(u8, content, "</body>")) |body_pos| {
            const injected = std.fmt.allocPrint(ra, "{s}{s}\n  {s}", .{
                content[0..body_pos],
                script,
                content[body_pos..],
            }) catch {
                try ctx.ERROR(500, "Failed to inject script");
                return;
            };
            try ctx.HTML(injected);
        } else {
            const injected = std.fmt.allocPrint(ra, "{s}{s}", .{ content, script }) catch {
                try ctx.ERROR(500, "Failed to inject script");
                return;
            };
            try ctx.HTML(injected);
        }
        return;
    }

    try ctx.FILE(file);
}
var dev_current_ws: ?*Reverb.WebSocket = null;

fn onConnection(ws: *Reverb.WebSocket, _: *Reverb.Context) !void {
    dev_current_ws = ws;
    try ws.sendText("connected");
}

fn onMessage(_: *Reverb.WebSocket, message: Reverb.WebSocket.Message, _: *Reverb.Context) !void {
    switch (message) {
        .Text => |text| std.debug.print("Text: {s}\n", .{text}),
        .Close => dev_current_ws = null,
        else => {},
    }
}

fn sendDevWsText(message: []const u8) void {
    if (dev_current_ws) |ws| {
        ws.sendText(message) catch {
            dev_current_ws = null;
        };
    }
}

/// Interface the dev server binds to unless `--host` or metal.zon says otherwise.
///
/// Loopback, not `0.0.0.0`: the dev server serves files out of the project
/// directory with no authentication, so the default must not be reachable from
/// the network.
pub const default_host = "127.0.0.1";

/// The address to put in a URL for the developer to click.
///
/// `0.0.0.0` is a valid thing to bind and a meaningless thing to browse to, so
/// the banner and `--open` get the loopback form instead.
pub fn browsableHost(bind_host: []const u8) []const u8 {
    if (std.mem.eql(u8, bind_host, "0.0.0.0")) return "localhost";
    if (std.mem.eql(u8, bind_host, "::")) return "localhost";
    return bind_host;
}

const ReverbConfig = struct {
    /// Read by reverb and handed to loom as `server_addr`. Loom's own default
    /// is `0.0.0.0`, which is why this is set explicitly on every path.
    host: []const u8 = default_host,
    port: u16 = 5173,
    max: usize = 1024,
    max_body_size: usize = 1024 * 1024 * 10,
};

pub fn initServer(host: []const u8, port: u16, local_allocator: std.mem.Allocator) !void {
    var server: Reverb.Server(ReverbConfig) = undefined;
    server.new(.{
        .host = host,
        .port = port,
        .max = 1024,
        .max_body_size = 1024 * 1024 * 10,
    }, local_allocator) catch |err| {
        std.debug.print("Server init failed: {s}\n", .{@errorName(err)});
        return err;
    };
    server.useCors(.{
        .cors_headers = .{
            .origin = .{ .override = "http://localhost:5173" },
            .headers = .{ .override = "Content-Type" },
            .credentials = .{ .override = "true" },
        },
    }) catch |err| {
        std.debug.print("Server CORS init failed: {s}\n", .{@errorName(err)});
        return err;
    };
    server.useWss(.{
        .onConnection = onConnection,
        .onMessage = onMessage,
        .max_body_size = 4 * 1024 * 1024,
    }) catch |err| {
        std.debug.print("Server WebSocket init failed: {s}\n", .{@errorName(err)});
        return err;
    };

    server.all(handleRequest, &.{}) catch |err| {
        std.debug.print("Server route init failed: {s}\n", .{@errorName(err)});
        return err;
    };
    server.listen() catch |err| {
        std.debug.print("Server listen failed: {s}\n", .{@errorName(err)});
        return err;
    };
    std.debug.print("Server listen returned unexpectedly\n", .{});
}

var local_allocator1 = std.heap.page_allocator;
var local_allocator2 = std.heap.page_allocator;

pub var main_init: std.process.Init = undefined;
/// Process exit codes.
///
/// A CLI that returns 0 after a failed build breaks every caller that composes
/// it — `metal vapor build && deploy`, `set -e` scripts, CI steps. Every path
/// out of `run` therefore carries an explicit code.
pub const ExitCode = struct {
    /// The command did what was asked.
    pub const ok: u8 = 0;
    /// The command ran and failed (build error, fetch error, watcher error).
    pub const failure: u8 = 1;
    /// The invocation itself was wrong (unknown command, missing argument).
    pub const usage: u8 = 2;
};

pub fn main(init: std.process.Init) !void {
    main_init = init;
    const code = run() catch |err| blk: {
        // `run` only propagates errors it has no better message for; anything
        // with a human explanation is reported at the call site and turned
        // into a code there.
        MetalUI.printError("metal failed", @errorName(err));
        break :blk ExitCode.failure;
    };
    if (code != ExitCode.ok) std.process.exit(code);
}

fn run() !u8 {
    // const allocator = main_init.arena.allocator(); // or use init.gpa
    const args = try main_init.minimal.args.toSlice(allocator);

    if (main_init.environ_map.contains("NO_COLOR")) {
        // disable color
    }
    applyColorPolicy();

    // A bare `metal` is a request for help, not a mistake.
    if (args.len < 2) {
        MetalUI.printHelp();
        return ExitCode.ok;
    }

    const framework: []const u8 = args[1];

    // Allow bare `metal help` / `metal version` without a framework
    if (std.mem.eql(u8, framework, "help")) {
        MetalUI.printHelp();
        return ExitCode.ok;
    }
    if (std.mem.eql(u8, framework, "version")) {
        MetalUI.printVersion();
        return ExitCode.ok;
    }
    // Framework-agnostic utility commands
    if (std.mem.eql(u8, framework, "doctor")) {
        return runDoctorCommand();
    }
    if (std.mem.eql(u8, framework, "clean")) {
        return runCleanCommand();
    }
    if (std.mem.eql(u8, framework, "upgrade")) {
        return runUpgradeCommand();
    }

    framework_type = parseFramework(framework) orelse {
        MetalUI.printError("Unknown framework", framework);
        print("  {s}Available:{s} vapor, reverb, canopy\n\n", .{ Ansi.dim, Ansi.reset });
        return ExitCode.usage;
    };

    // Bare `metal <framework>` shows scoped help.
    if (args.len < 3) {
        MetalUI.printFrameworkHelp(framework);
        return ExitCode.ok;
    }

    const command = parseCommand(args[2]);

    switch (command) {
        .version => {
            MetalUI.printVersion();
            return ExitCode.ok;
        },

        .help => {
            MetalUI.printFrameworkHelp(framework);
            return ExitCode.ok;
        },

        .doctor => return runDoctorCommand(),

        .clean => return runCleanCommand(),

        .upgrade => return runUpgradeCommand(),

        .create => {
            if (args.len < 4) {
                MetalUI.printError("Missing project name", "usage: metal <framework> create <name>");
                return ExitCode.usage;
            }

            clearScreen();
            callCommand(&.{ "zig", "version" }) catch {
                MetalUI.printZigNotFound();
                return ExitCode.failure;
            };
            clearScreen();
            var vapor_path: ?[]const u8 = null;
            var i: usize = 4;
            while (i < args.len) : (i += 1) {
                if (std.mem.eql(u8, args[i], "--vapor-path")) {
                    i += 1;
                    if (i >= args.len) {
                        MetalUI.printError("Missing value", "usage: metal vapor create <name> --vapor-path <dir>");
                        return ExitCode.usage;
                    }
                    vapor_path = args[i];
                } else {
                    MetalUI.printError("Unknown option", args[i]);
                    return ExitCode.usage;
                }
            }
            return runCreateCommand(args[3], vapor_path);
        },

        .add => {
            if (args.len < 4) {
                MetalUI.printError("Missing package name", "usage: metal <framework> add <package>");
                print("  {s}Available:{s} auth, vaporize, vapor\n\n", .{ Ansi.dim, Ansi.reset });
                return ExitCode.usage;
            }
            // fetchPackage prints its own diagnosis for both failure modes.
            fetchPackage(args[3]) catch |err| return switch (err) {
                error.PackageNotFound => ExitCode.usage,
                else => ExitCode.failure,
            };
            return ExitCode.ok;
        },

        .gen => {
            if (args.len < 4) {
                MetalUI.printError("Missing generation type", "usage: metal <framework> gen <type> <Name> [--output path] [--force] [--dry-run]");
                return ExitCode.usage;
            }
            const gen_args = args[3..];
            const gen_options = parseGenOptions(gen_args);
            var local_alloc = allocator;
            const contents = Contents{ .allocator = &local_alloc };
            runGenCommand(&contents, gen_options) catch |err| return switch (err) {
                error.UnknownGenType => ExitCode.usage,
                else => blk: {
                    MetalUI.printError("Generation failed", @errorName(err));
                    break :blk ExitCode.failure;
                },
            };
            return ExitCode.ok;
        },

        .run => {
            const run_args = if (args.len > 3) args[3..] else args[0..0];
            const run_options = parseRunOptions(run_args);
            generate = run_options.generate;
            static_mode = run_options.static;
            release_mode = run_options.release;
            ssg = run_options.ssg;

            // Load project-local config (metal.zon). null = no config = defaults.
            const loaded_cfg = MetalConfigMod.load(allocator) catch |err| blk: {
                MetalUI.printWarning("Failed to load metal.zon", @errorName(err));
                break :blk null;
            };
            defer if (loaded_cfg) |lc| MetalConfigMod.freeLoaded(allocator, lc);

            // Resolve the bind address: --host > metal.zon > loopback.
            //
            // The default is deliberately 127.0.0.1. This server reads files
            // from the project directory and has no authentication, so binding
            // every interface would expose a developer's working tree to the
            // local network. `--host 0.0.0.0` is the opt-in.
            const host: []const u8 = blk: {
                if (run_options.host) |h| break :blk h;
                if (loaded_cfg) |lc| {
                    if (lc.config.host) |h| break :blk h;
                }
                break :blk default_host;
            };

            // Install signal handler before spawning anything so a Ctrl-C during
            // build doesn't leave a zombie child.
            proc_state.install();

            // Backend frameworks (reverb, canopy) are their own server —
            // metal only watches for file changes and rebuilds.  The user
            // starts/restarts their server themselves, so we skip port
            // probing, the dev HTTP server, and run_after_build entirely.
            if (framework_type == .reverb or framework_type == .canopy) {
                // Use the configured/default port for display only (no bind).
                const display_port: u16 = blk: {
                    if (run_options.port) |p| break :blk p;
                    if (loaded_cfg) |lc| {
                        if (lc.config.port) |p| break :blk p;
                    }
                    break :blk 8080;
                };
                MetalUI.printServerBanner(framework, display_port, run_options);

                watcher.runWithConfig(display_port, local_allocator2, .{
                    .open_on_start = run_options.open,
                    .app_port = display_port,
                    .app_host = host,
                    .enable_keyboard_shortcuts = true,
                    .process_environ = main_init.minimal.environ,
                    .start_websocket_server = false,
                    .notify_websocket = null,
                    .run_after_build = null,
                }) catch |err| {
                    MetalUI.printError("Watcher failed", @errorName(err));
                    return ExitCode.failure;
                };
                return ExitCode.ok;
            }

            // ── Vapor (frontend): metal spins up a dev server + watcher ──

            // Resolve effective port: --flag > metal.zon > default (5173)
            var requested_port: u16 = 5173;
            if (run_options.port) |p| {
                requested_port = p;
            } else if (loaded_cfg) |lc| {
                if (lc.config.port) |p| requested_port = p;
            }

            // Port resolution: if explicit and taken → bail; if implicit and
            // taken → fall back to the next free port in a small window.
            var effective_port: u16 = requested_port;
            if (!isPortFree(requested_port)) {
                if (run_options.port_explicit) {
                    var pbuf: [16]u8 = undefined;
                    const ps = std.fmt.bufPrint(&pbuf, "{d}", .{requested_port}) catch "?";
                    MetalUI.printError("Port already in use", ps);
                    return ExitCode.failure;
                }
                effective_port = findFreePort(requested_port + 1, 32);
                if (effective_port != requested_port) {
                    var pbuf: [64]u8 = undefined;
                    const msg = std.fmt.bufPrint(&pbuf, "{d} taken → using {d}", .{ requested_port, effective_port }) catch "auto-picked";
                    MetalUI.printWarning("Port", msg);
                }
            }

            MetalUI.printServerBanner(framework, effective_port, run_options);

            // The dev reload WebSocket rides on the same Reverb server as HTTP.
            watcher_ws_port_global = effective_port;

            // runBuild has already explained the failure.
            runBuild(run_options) catch return ExitCode.failure;

            // Start HTTP + WebSocket server in a background thread
            const server_thread = try std.Thread.spawn(.{}, initServer, .{ host, effective_port, local_allocator1 });
            server_thread.detach();

            MetalUI.printListening(effective_port);

            // Give the server a moment to bind
            Time.sleep(500 * std.time.ns_per_ms);

            // Start file watcher (blocks until quit) — recompiles on change
            // and sends WebSocket "refresh" to connected browsers
            watcher.runWithConfig(effective_port, local_allocator2, .{
                .open_on_start = run_options.open,
                .app_port = effective_port,
                .app_host = browsableHost(host),
                .enable_keyboard_shortcuts = true,
                .process_environ = main_init.minimal.environ,
                .start_websocket_server = false,
                .notify_websocket = sendDevWsText,
            }) catch |err| {
                MetalUI.printError("Watcher failed", @errorName(err));
                return ExitCode.failure;
            };
            return ExitCode.ok;
        },

        .release, .build => {
            const run_args = if (args.len > 3) args[3..] else args[0..0];
            var run_options = parseRunOptions(run_args);

            // `release` command implies release mode
            if (command == .release) run_options.release = true;

            generate = run_options.generate;
            static_mode = run_options.static;
            release_mode = run_options.release;

            // This is the one that matters most: `metal vapor build && deploy`
            // must not deploy a build that failed.
            runBuild(run_options) catch return ExitCode.failure;
            return ExitCode.ok;
        },

        .unknown => {
            MetalUI.printError("Unknown command", args[2]);
            print("  {s}Run {s}metal {s} help{s} for available commands\n\n", .{
                Ansi.dim,
                framework,
                Ansi.reset,
                Ansi.reset,
            });
            return ExitCode.usage;
        },
    }
}

pub fn clearScreen() void {
    print("\x1B[2J\x1B[H", .{});
}
