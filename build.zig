const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule("docker", .{ .root_source_file = b.path("src/direct.zig"), .target = target, .optimize = optimize });

    const lib = b.addStaticLibrary(.{ .name = "docker", .root_source_file = b.path("src/direct.zig"), .target = target, .optimize = optimize });

    b.installArtifact(lib);

    const unit_tests = b.addTest(.{ .root_source_file = b.path("test.zig"), .target = target, .optimize = optimize });

    b.installArtifact(unit_tests);

    const unit_test = b.addRunArtifact(unit_tests);
    const unit_test_step = b.step("test", "Run unit tests.");
    unit_test_step.dependOn(&unit_test.step);
}
