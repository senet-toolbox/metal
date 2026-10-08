const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const reverb = b.dependency("reverb", .{
        .target = target,
        .optimize = optimize,
    });

    const reverb_mod = reverb.module("reverb");

    // The version lives in build.zig.zon alone; metal_ui prints this copy.
    const options = b.addOptions();
    options.addOption([]const u8, "version", @import("build.zig.zon").version);
    const options_mod = options.createModule();

    // We will also create a module for our other entry point, 'main.zig'.
    const exe_mod = b.createModule(.{
        // `root_source_file` is the Zig "entry point" of the module. If a module
        // only contains e.g. external object files, you can make this `null`.
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "reverb", .module = reverb_mod },
            .{ .name = "build_options", .module = options_mod },
        },
        .link_libc = true,
    });

    // This creates another `std.Build.Step.Compile`, but this one builds an executable
    // rather than a static library.
    const exe = b.addExecutable(.{
        .name = "metal",
        .root_module = exe_mod,
    });

    // Native filesystem-event watcher needs CoreServices (FSEvents) on macOS.
    if (target.result.os.tag == .macos) {
        exe.root_module.linkFramework("CoreServices", .{});
        exe.root_module.linkFramework("CoreFoundation", .{});
        addMacSdkPaths(b, exe.root_module, target);
    }

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Tests live in modules that `main.zig` does not import, so the test root
    // is `src/tests.zig`, which imports every module that has test blocks.
    const test_mod = b.createModule(.{
        .root_source_file = b.path("src/tests.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "reverb", .module = reverb_mod },
            .{ .name = "build_options", .module = options_mod },
        },
        .link_libc = true,
    });

    const unit_tests = b.addTest(.{ .root_module = test_mod });

    if (target.result.os.tag == .macos) {
        test_mod.linkFramework("CoreServices", .{});
        test_mod.linkFramework("CoreFoundation", .{});
    }

    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    // Type-check everything, including code nothing calls. Wired into both the
    // default build and `test` so it cannot be forgotten.
    const check_step = addCheckStep(b, reverb_mod, options_mod, optimize);
    b.getInstallStep().dependOn(check_step);
    test_step.dependOn(check_step);
}

/// Builds `src/check.zig` as an object for each supported target.
///
/// Two targets, because they catch different things. The host target is what
/// developers run. x86_64-linux is checked explicitly because macOS links libc
/// implicitly and resolves some platform code differently, so a Linux-only
/// compile error is otherwise invisible until CI — and metal-cli has
/// hand-written syscall wrappers in `posix.zig` and an FSEvents watcher that
/// need a non-macOS path.
fn addCheckStep(
    b: *std.Build,
    reverb_mod: *std.Build.Module,
    options_mod: *std.Build.Module,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step {
    const check_step = b.step("check", "Type-check every source file, including unreferenced code");

    verifyCheckRootIsComplete(b, check_step);

    // Off by default: `loom`, reached through reverb, is kqueue-only and does
    // not build for Linux at all (its event engine and its coroutine assembly
    // are both macOS/BSD). Until that changes, a Linux check reports the
    // dependency's problems louder than ours. Our own Linux gaps are real
    // though — inotify code in fs_watcher.zig and clock_nanosleep in Time.zig
    // both use std APIs that 0.16 moved — so keep the target one flag away.
    const check_linux = b.option(
        bool,
        "check-linux",
        "Also type-check for x86_64-linux (currently blocked by the loom dependency)",
    ) orelse false;

    const CheckTarget = struct { name: []const u8, query: std.Target.Query };
    var target_buf: [2]CheckTarget = undefined;
    var target_count: usize = 1;
    target_buf[0] = .{ .name = "metal-check-host", .query = .{} };
    if (check_linux) {
        target_buf[1] = .{ .name = "metal-check-linux", .query = .{
            .cpu_arch = .x86_64,
            .os_tag = .linux,
            .abi = .gnu,
        } };
        target_count = 2;
    }

    for (target_buf[0..target_count]) |check_target| {
        const target = b.resolveTargetQuery(check_target.query);

        const check_module = b.createModule(.{
            .root_source_file = b.path("src/check.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "reverb", .module = reverb_mod },
                .{ .name = "build_options", .module = options_mod },
            },
            .link_libc = true,
        });

        if (target.result.os.tag == .macos) {
            check_module.linkFramework("CoreServices", .{});
            check_module.linkFramework("CoreFoundation", .{});
        }

        const check_obj = b.addObject(.{
            .name = check_target.name,
            .root_module = check_module,
        });

        check_step.dependOn(&check_obj.step);
    }

    return check_step;
}

/// Fails the check if a file under `src/` is missing from `src/check.zig`, so
/// a new module cannot silently opt out of type-checking.
///
/// `src/templates/` is excluded: those files are `@embedFile` payloads for
/// scaffolded projects, compiled by the generated project rather than by us.
fn verifyCheckRootIsComplete(b: *std.Build, check_step: *std.Build.Step) void {
    const io = b.graph.io;
    const root = b.build_root.handle;

    const contents = root.readFileAlloc(io, "src/check.zig", b.allocator, .limited(1 << 20)) catch |err| {
        std.debug.panic("check: cannot read src/check.zig: {t}", .{err});
    };

    var src_dir = root.openDir(io, "src", .{ .iterate = true }) catch |err| {
        std.debug.panic("check: cannot open src/: {t}", .{err});
    };
    defer src_dir.close(io);

    var walker = src_dir.walk(b.allocator) catch @panic("OOM");
    defer walker.deinit();

    var missing = std.array_list.Managed([]const u8).init(b.allocator);

    while (walker.next(io) catch @panic("walk failed")) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.path, ".zig")) continue;

        // Zig import paths use forward slashes regardless of host.
        const import_path = b.allocator.dupe(u8, entry.path) catch @panic("OOM");
        std.mem.replaceScalar(u8, import_path, std.fs.path.sep, '/');

        if (std.mem.startsWith(u8, import_path, "templates/")) continue;

        const needle = b.fmt("@import(\"{s}\")", .{import_path});
        if (std.mem.indexOf(u8, contents, needle) == null) {
            missing.append(import_path) catch @panic("OOM");
        }
    }

    if (missing.items.len == 0) return;

    var message = std.array_list.Managed(u8).init(b.allocator);
    message.appendSlice(b.fmt(
        "{d} source file(s) under src/ are not listed in src/check.zig, so nothing " ++
            "type-checks them. Add each to `modules`:\n",
        .{missing.items.len},
    )) catch @panic("OOM");
    for (missing.items) |path| {
        message.appendSlice(b.fmt("    @import(\"{s}\"),\n", .{path})) catch @panic("OOM");
    }

    const fail = b.addFail(message.items);
    check_step.dependOn(&fail.step);
}

/// Cross-compiling to macOS (e.g. x86_64 from an arm64 Mac, for a release)
/// does not search the SDK the way a native build does, so CoreServices and
/// CoreFoundation go missing at link time. Point the linker at the SDK that
/// `xcrun` reports. Native builds and non-Mac hosts are left alone.
fn addMacSdkPaths(b: *std.Build, module: *std.Build.Module, target: std.Build.ResolvedTarget) void {
    if (target.query.isNative()) return;
    if (b.graph.host.result.os.tag != .macos) return;

    var code: u8 = undefined;
    const out = b.runAllowFail(&.{ "xcrun", "--show-sdk-path" }, &code, .ignore) catch return;
    const sdk = std.mem.trim(u8, out, " \r\n\t");
    if (sdk.len == 0) return;

    module.addFrameworkPath(.{ .cwd_relative = b.pathJoin(&.{ sdk, "System/Library/Frameworks" }) });
    module.addSystemIncludePath(.{ .cwd_relative = b.pathJoin(&.{ sdk, "usr/include" }) });
    module.addLibraryPath(.{ .cwd_relative = b.pathJoin(&.{ sdk, "usr/lib" }) });
}
