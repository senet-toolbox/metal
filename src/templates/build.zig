const std = @import("std");

fn generateHtml(b: *std.Build, static: bool, atomic: bool) *std.Build.Step {
    const target = b.graph.host;

    const optimize = std.builtin.OptimizeMode.Debug;

    // ---------------------
    //  Local modules
    // ---------------------
    const config_module = b.addModule("config", .{
        .root_source_file = b.path("src/config.zig"),
        .optimize = optimize,
    });

    // ---------------------
    //  Dependencies
    // ---------------------

    // Vapor — core framework
    const vapor_dep = b.dependency("vapor", .{
        .target = target,
        .optimize = optimize,
        .static = static,
        .atomic = atomic,
    });
    const vapor_module = vapor_dep.module("vapor");
    vapor_module.addImport("config", config_module);

    // Theme — styling layer (depends on vapor)
    const theme_module = b.addModule("theme", .{
        .root_source_file = b.path("src/Theme.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "vapor", .module = vapor_module },
        },
    });
    vapor_module.addImport("theme", theme_module);

    const generator_mod = b.createModule(.{
        .root_source_file = b.path("src/generator.zig"),
        .target = target,
        .optimize = .Debug,
        // The generator runs natively and vapor's SSR path uses the C
        // allocator. macOS links libc implicitly; Linux does not.
        .link_libc = true,
        .imports = &.{
            .{ .name = "vapor", .module = vapor_module },
            .{ .name = "theme", .module = theme_module }, // ADD THIS
            .{ .name = "config", .module = config_module },
        },
    });

    const generator_exe = b.addExecutable(.{
        .name = "generator",
        .root_module = generator_mod,
    });

    const run = b.addRunArtifact(generator_exe);
    return &run.step;
}

pub fn build(b: *std.Build) void {
    // ---------------------
    //  Build options
    // ---------------------
    const generate = b.option(bool, "generate", "Generate HTML") orelse false;
    const static = b.option(bool, "static", "Statically link the wasm module") orelse false;
    const atomic = b.option(bool, "atomic", "Atomically link the wasm module") orelse false;
    const optimize = b.standardOptimizeOption(.{});

    const wasm_target = b.standardTargetOptions(.{
        .default_target = .{ .cpu_arch = .wasm32, .os_tag = .wasi },
    });

    // ---------------------
    //  Local modules
    // ---------------------
    const config_module = b.addModule("config", .{
        .root_source_file = b.path("src/config.zig"),
        .target = wasm_target,
        .optimize = optimize,
    });

    // ---------------------
    //  Dependencies
    // ---------------------

    // Vapor — core framework
    const vapor_dep = b.dependency("vapor", .{
        .target = wasm_target,
        .optimize = optimize,
        .static = static,
        .atomic = atomic,
    });
    const vapor_module = vapor_dep.module("vapor");
    vapor_module.addImport("config", config_module);

    // Theme — styling layer (depends on vapor)
    const theme_module = b.addModule("theme", .{
        .root_source_file = b.path("src/Theme.zig"),
        .target = wasm_target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "vapor", .module = vapor_module },
        },
    });
    vapor_module.addImport("theme", theme_module);
    // ---------------------
    //  Executable
    // ---------------------
    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = wasm_target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "vapor", .module = vapor_module },
            .{ .name = "theme", .module = theme_module },
            .{ .name = "config", .module = config_module },
        },
    });

    const exe = b.addExecutable(.{
        .name = "vapor",
        .root_module = exe_mod,
    });

    // ---------------------
    //  Memory stack size
    // ---------------------
    exe.stack_size = 4 * 1024 * 1024;

    // ---------------------
    //  Disabling main entry point
    // ---------------------
    exe.entry = .disabled;

    // ---------------------
    //  Export all extern functions
    // ---------------------
    exe.rdynamic = true;

    b.installArtifact(exe);

    // ---------------------
    //  JS runtime
    // ---------------------
    // Ships with vapor, so it always matches the wasm built above. Installed
    // next to it as zig-out/bin/bundle.min.js.
    const install_runtime = b.addInstallBinFile(vapor_dep.namedLazyPath("runtime"), "bundle.min.js");
    b.getInstallStep().dependOn(&install_runtime.step);

    // Optional: wire up the HTML generator before compilation. It copies the
    // runtime into release/, so the runtime has to be installed first.
    if (generate) {
        const gen_step = generateHtml(b, static, atomic);
        gen_step.dependOn(&install_runtime.step);
        exe.step.dependOn(gen_step);
    }
}
