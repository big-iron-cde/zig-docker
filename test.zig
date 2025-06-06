const std = @import("std");
const docker = @import("src/direct.zig");

test "list images" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    _ = try docker.@"/images/json".get(alloc, .{
        .all = true,
        .filters = "",
    });
}

test "create container" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    _ = try docker.@"/containers/create".post(alloc, .{ .name = "hello-test" }, .{ .body = .{ .Image = "hello-world" } });
    //std.debug.print("{any}", .{response});
}

test "list containers" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    _ = try docker.@"/containers/json".get(alloc, .{ .limit = 10, .filters = "" });
    //std.debug.print("\n{any} {any}\n", .{ response.@"200".ContainersDeleted, response.@"200".SpaceReclaimed });
}

test "start container" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    const response = try docker.@"/containers/json".get(alloc, .{ .limit = 10, .filters = "" });
    std.debug.print("{any}", .{response});
    //_ = try docker.@"/containers/{id}/start".post(alloc, .{}, .{});
}

test "prune containers" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    _ = try docker.@"/containers/prune".post(alloc, .{ .filters = "" });
    //std.debug.print("\n{any} {any}\n", .{ response.@"200".ContainersDeleted, response.@"200".SpaceReclaimed });
}
