const std = @import("std");
const docker = @import("src/direct.zig");

test "list images" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    const response = try docker.@"/images/json".get(alloc, .{
        .all = true,
        .filters = "",
    });

    for (response.@"200") |item| {
        std.debug.print("\nID: {s} CREATED: {d}\n", .{ item.Id[0..20], item.Created });
    }
}

test "prune containers" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    const response = try docker.@"/containers/prune".post(alloc, .{ .filters = "" });

    std.debug.print("\n{any} {any}\n", .{ response.@"200".ContainersDeleted, response.@"200".SpaceReclaimed });
}

test "create container" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    const response = try docker.@"/containers/create".post(alloc, .{ .name = "hello-test" }, .{ .body = .{ .Image = "hello-world" } });
    std.debug.print("{any}", .{response});
}
