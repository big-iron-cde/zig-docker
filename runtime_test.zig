const std = @import("std");
const uuid = @import("uuid");
const docker = @import("src/direct.zig");

test "create container" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    // create safe dummy folder path
    const home_dir = std.posix.getenv("HOME") orelse {
        std.log.warn("Could not get HOME environment variable", .{});
        return;
    };

    const dummy_folder_path = try std.fmt.allocPrint(alloc, "{s}/dummy-docker-volume", .{home_dir});
    defer alloc.free(dummy_folder_path);

    // create the dummy folder if it doesn't exist
    std.fs.makeDirAbsolute(dummy_folder_path) catch |err| switch (err) {
        error.PathAlreadyExists => {}, // Already exists, that's fine
        else => {
            std.log.warn("Failed to create dummy folder: {s}", .{dummy_folder_path});
            return err;
        },
    };

    // verify dummy folder exists and list its contents
    var dir = std.fs.openDirAbsolute(dummy_folder_path, .{}) catch |err| {
        std.log.warn("Could not open dummy folder: {any}", .{err});
        return;
    };
    defer dir.close();

    std.log.warn("Dummy folder exists: {s}", .{dummy_folder_path});

    var port_map = docker.PortMap.init(alloc);
    defer port_map.deinit();

    const path = try std.fmt.allocPrint(alloc, "{s}:/home/project", .{dummy_folder_path});

    try port_map.put("3000/tcp", &[_]docker.PortBinding{.{ .HostIp = "", .HostPort = "3000" }});

    const response = try docker.@"/containers/create".post(alloc, .{ .name = "theia-test" }, .{
        .body = .{
            .Image = "ghcr.io/eclipse-theia/theia-ide/theia-ide:1.61.0",
            .HostConfig = .{
                .Binds = &[1][]const u8{path},
                .PortBindings = port_map,
            },
            .NetworkingConfig = .{},
        },
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

test "start container" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    // start containers
    const list = try docker.@"/containers/json".get(alloc, .{ .limit = 1 });
    for (list.@"200") |container| {
        std.log.warn("Starting: {s}", .{container.Id});
        _ = try docker.@"/containers/{id}/start".post(alloc, .{ .id = container.Id }, .{});
        std.time.sleep(120 * (1000 * std.time.ns_per_ms));
    }
}

test "stop container" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    const list = try docker.@"/containers/json".get(alloc, .{ .limit = 1 });
    for (list.@"200") |container| {
        std.log.warn("Stopping: {s}", .{container.Id});
        _ = try docker.@"/containers/{id}/stop".post(alloc, .{ .id = container.Id }, .{});
    }
}

test "prune containers" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    const response = try docker.@"/containers/prune".post(alloc, .{ });
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
