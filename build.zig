const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule("docker", .{ .root_source_file = b.path("src/direct.zig"), .target = target, .optimize = optimize });

    const lib = b.addStaticLibrary(.{ .name = "docker", .root_source_file = b.path("src/direct.zig"), .target = target, .optimize = optimize });

    b.installArtifact(lib);

    const lifecycle_tests = b.addTest(.{ .root_source_file = b.path("lifecycle_test.zig"), .target = target, .optimize = optimize });
    const runtime_tests = b.addTest(.{ .root_source_file = b.path("runtime_test.zig"), .target = target, .optimize = optimize });
    
    b.installArtifact(lifecycle_tests);
    b.installArtifact(runtime_tests);

    const lifecycle_test = b.addRunArtifact(lifecycle_tests);
    const lifecycle_test_step = b.step("lifecycle_test", "Run lifecycle tests.");
    lifecycle_test_step.dependOn(&lifecycle_test.step);

    const runtime_test = b.addRunArtifact(runtime_tests);
    const runtime_test_step = b.step("runtime_test", "Run runtime tests.");
    runtime_test_step.dependOn(&runtime_test.step);

}
