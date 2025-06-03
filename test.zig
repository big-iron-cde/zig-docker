const std = @import("std");
const docker = @import("src/direct.zig");

test "list images" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    const response = try docker.@"/images/json".get(alloc, .{
        .all = true,
    });

    for (response.@"200") |item| {
        std.debug.print("ID: {s} CREATED: {d}\n", .{ item.Id[0..20], item.Created });
    }
}

test "prune containers" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    const response = try docker.@"/containers/prune".post(alloc, .{ .filters = "" });
    std.debug.print("{any}", .{ response });
    //for (response.@"200") |item| {
    //    std.debug.print("RECLAIMED: {s}", .{ item.SpaceReclaimed });
    //}

}

test "create container" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    const response = try docker.@"/containers/create".post(alloc, .{
    },.{
        .body = .{ .Image = "hello-world", .HostConfig = .{}, .NetworkingConfig = .{} }
    });
    std.debug.print("{any}", .{ response });
}
