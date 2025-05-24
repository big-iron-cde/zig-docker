const std = @import("std");
const docker = @import("src/direct.zig");

test "list images" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    const list = try docker.@"/images/json".get(alloc, .{
        .all = true,
        .filters = "",
    });
        
    for (list.@"200") |item| {
        std.log.info("{s} {d}", .{ item.Id[0..20], item.Created });
    }
}
