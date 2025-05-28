const std = @import("std");
const docker = @import("src/direct.zig");

test "list images" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    const response = try docker.@"/images/json".get(alloc, .{
        .all = true,
    });
    std.debug.print("{any}", .{response});

    for (response.@"200") |item| {
        std.debug.print("{s} {d}", .{ item.Id[0..20], item.Created });
    }
}

test "prune containers" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    const response = try docker.@"/containers/prune".post(alloc, .{ .filters = "until=1m" });

    std.log.info("{any}", .{response});
}
