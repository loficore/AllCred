const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardOptimizeOption(.{});

    const moudule = b.addModule("AllCred", .{
        .root_source_file = .{ .src_path = .{ .owner = b, .sub_path = "src/root.zig" } },
        .target = target,
        .optimize = mode,
    });

    if (target.result.os.tag == .linux) {
        moudule.linkSystemLibrary("libsecret-1", .{});
        moudule.link_libc = true;
    } else if (target.result.os.tag == .windows) {
        moudule.linkSystemLibrary("advapi32", .{});
        moudule.link_libc = true;
    } else {
        std.debug.print("Unsupported OS: {}\n", .{target.result.os});
    }

    const linux_test_module = b.addModule("linux_test", .{
        .root_source_file = .{ .src_path = .{ .owner = b, .sub_path = "src/test/linux_test.zig" } },
        .target = target,
        .optimize = mode,
    });

    linux_test_module.addImport("AllCred", moudule);

    if (target.result.os.tag == .linux) {
        linux_test_module.linkSystemLibrary("libsecret-1", .{});
        linux_test_module.link_libc = true;
    }

    const windows_test_module = b.addModule("windows_test", .{
        .root_source_file = .{ .src_path = .{ .owner = b, .sub_path = "src/test/windows_test.zig" } },
        .target = target,
        .optimize = mode,
    });

    windows_test_module.addImport("AllCred", moudule);

    if (target.result.os.tag == .windows) {
        windows_test_module.linkSystemLibrary("advapi32", .{});
        windows_test_module.link_libc = true;
    }

    const linux_test = b.addTest(.{
        .name = "linux_test",
        .root_module = linux_test_module,
    });

    const windows_test = b.addTest(.{
        .name = "windows_test",
        .root_module = windows_test_module,
    });

    const test_step = b.step("test", "Run tests");

    if (target.result.os.tag == .linux) {
        const run_linux_tests = b.addRunArtifact(linux_test);
        test_step.dependOn(&run_linux_tests.step);
    } else if (target.result.os.tag == .windows) {
        const run_windows_tests = b.addRunArtifact(windows_test);
        test_step.dependOn(&run_windows_tests.step);
    }
}
