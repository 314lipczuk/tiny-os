const std = @import("std");
const Target = std.Target;
const Feature = std.Target.Cpu.Feature;
// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.

    const features = Target.riscv.Feature;
    var features_disabled = Feature.Set.empty;
    var features_enabled = Feature.Set.empty;

    features_disabled.addFeature(@intFromEnum(features.a));
    features_disabled.addFeature(@intFromEnum(features.c));
    features_disabled.addFeature(@intFromEnum(features.d));
    features_disabled.addFeature(@intFromEnum(features.e));
    features_disabled.addFeature(@intFromEnum(features.f));

    features_enabled.addFeature(@intFromEnum(features.m));
    features_enabled.removeFeatureSet(features_disabled);

    //Target.Cpu.Model.generic(Target.Cpu.Arch.riscv32);

    const target = Target{ .cpu = .{ .arch = Target.Cpu.Arch.riscv32, .model = Target.Cpu.Model.generic(Target.Cpu.Arch.riscv32), .features = features_enabled }, .os = .{ .tag = Target.Os.Tag.freestanding, .version_range = .{ .none = {} } }, .abi = Target.Abi.none, .ofmt = .raw };

    const target_1 = std.Target.Query{
        .cpu_arch = Target.Cpu.Arch.riscv32,
        .os_tag = Target.Os.Tag.freestanding,
        .abi = Target.Abi.none,
        .cpu_model = .{ .explicit = &Target.riscv.cpu.generic_rv32 },
        .cpu_features_sub = features_disabled,
        .cpu_features_add = features_enabled,
    };

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseSmall });
    const resolved_target = std.Build.ResolvedTarget{ .result = target, .query = target_1 };
    const exe = b.addExecutable(.{
        .name = "os-tiny",
        .root_source_file = b.path("src/main.zig"),
        //.target = .{ .query = target, .result =  },
        .target = resolved_target,
        .optimize = optimize,
        .strip = false,
        .code_model = .kernel,
    });
    exe.setLinkerScript(b.path("src/kernel.ld"));

    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.

    //const run_cmd = b.addRunArtifact(exe);
    const cmd = &[_][]const u8{ "qemu-system-riscv32", "-machine", "virt", "-bios", "default", "-nographic", "-serial", "mon:stdio", "--no-reboot", "--kernel", "zig-out/bin/os-tiny.bin" };
    const run_cmd = b.addSystemCommand(cmd);

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
    const run_step = b.step("run", "Run kernel with qemu");
    run_step.dependOn(&run_cmd.step);

    // const exe_unit_tests = b.addTest(.{
    //     .root_source_file = b.path("src/main.zig"),
    //     .target = resolved_target,
    //     .optimize = optimize,
    // });

    // const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // // Similar to creating the run step earlier, this exposes a `test` step to
    // // the `zig build --help` menu, providing a way for the user to request
    // // running the unit tests.
    // const test_step = b.step("test", "Run unit tests");
    // test_step.dependOn(&run_exe_unit_tests.step);
}
