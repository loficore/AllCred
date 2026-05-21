const std = @import("std");

// Although this function looks imperative, it does not perform the build
// directly and instead it mutates the build graph (`b`) that will be then
// executed by an external runner. The functions in `std.Build` implement a DSL
// for defining build steps and express dependencies between them, allowing the
// build runner to parallelize the build automatically (and the cache system to
// know when a step doesn't need to be re-run).
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

    const main_test = b.addTest(.{
        .name = "main_test",
        .root_module = moudule,
    });

    main_test.root_module.addImport("AllCred", moudule);

    const run_main_tests = b.addRunArtifact(main_test);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_main_tests.step);
}
