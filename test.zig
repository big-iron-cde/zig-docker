const std = @import("std");
const uuid = @import("uuid");
const docker = @import("src/direct.zig");

test "list images" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    const response = try docker.@"/images/json".get(alloc, .{
        .all = true,
        .filters = "",
    });

    for (response.@"200") |image| {
        std.log.warn("ID: {s}, Created: {d}", .{ image.Id, image.Created });
    }
}

test "create container" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    const response = try docker.@"/containers/create".post(alloc, .{ .name = "theia-test" }, .{ 
        .body = .{ 
            .Image = "ghcr.io/eclipse-theia/theia-ide/theia-ide:1.61.0",
            .HostConfig = .{},
            .NetworkingConfig = .{} 
        } 
    });
    switch (response) {
        .@"201" => {
            std.log.warn("Created: {s}", .{response.@"201".Id});
        },
        .@"400", .@"404", .@"409", .@"500" => |*err| {
            std.log.warn("Error: {s}", .{err.*.message});
        },
    }
}

test "list containers" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    const list = try docker.@"/containers/json".get(alloc, .{ .limit = 10, .filters = "" });
    for (list.@"200") |container| {
        std.log.warn("Id: {s}", .{container.Id});
    }
}

test "start container" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    const list = try docker.@"/containers/json".get(alloc, .{ .limit = 1, .filters = "" });
    for (list.@"200") |container| {
        std.log.warn("Starting: {s}", .{container.Id});
        _ = try docker.@"/containers/{id}/start".post(alloc, .{ .id = container.Id }, .{ });
    }
}

test "stop container" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    const list = try docker.@"/containers/json".get(alloc, .{ .limit = 1, .filters = "" });
    for (list.@"200") |container| {
        std.log.warn("Stopping: {s}", .{container.Id});
        _ = try docker.@"/containers/{id}/stop".post(alloc, .{ .id = container.Id }, .{});
    }
}

test "prune containers" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    const response = try docker.@"/containers/prune".post(alloc, .{ .filters = "" });
    switch (response) {
        .@"200" => {
            for (response.@"200".ContainersDeleted) |container| {
                std.log.warn("Deleted: {s}", .{container});
            }
            std.log.warn("Reclaimed: {d}B", .{response.@"200".SpaceReclaimed});
        },
        else => {},
    }
}
