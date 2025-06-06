const std = @import("std");
const builtin = @import("builtin");
const string = []const u8;
const UrlValues = @import("zig-UrlValues/main.zig");
const shared = @import("./shared.zig");

pub fn AllOf(comptime xs: []const type) type {
    var fields: []const std.builtin.Type.StructField = &.{};
    inline for (xs) |item| {
        fields = fields ++ std.meta.fields(item);
    }
    return Struct(fields);
}

fn Struct(comptime fields: []const std.builtin.Type.StructField) type {
    return @Type(.{ .@"struct" = .{ .layout = .auto, .fields = fields, .decls = &.{}, .is_tuple = false } });
}

pub const Method = enum {
    get,
    head,
    post,
    put,
    patch,
    delete,
};

pub fn name(comptime Top: type, comptime This: type) string {
    inline for (std.meta.declarations(Top)) |item| {
        if (@field(Top, item.name) == This) {
            return item.name;
        }
    }
    @compileError("not found");
}

pub fn Fn(comptime method: Method, comptime endpoint: string, comptime P: type, comptime Q: type, comptime B: type, comptime R: type) type {
    return struct {
        pub usingnamespace switch (method) {
            .get => struct {
                pub const get = real;
            },
            .head => struct {
                pub const head = real;
            },
            .post => struct {
                pub const post = real;
            },
            .put => struct {
                pub const put = real;
            },
            .patch => struct {
                pub const patch = real;
            },
            .delete => struct {
                pub const delete = real;
            },
        };

        const real = switch (P) {
            void => switch (Q) {
                void => switch (B) {
                    void => unreachable,
                    else => inner1_B,
                },
                else => switch (B) {
                    void => inner1_Q,
                    else => inner2_QB,
                },
            },
            else => switch (Q) {
                void => switch (B) {
                    void => inner1_P,
                    else => inner2_PB,
                },
                else => switch (B) {
                    void => inner2_PQ,
                    else => inner,
                },
            },
        };

        fn inner1_P(alloc: std.mem.Allocator, args: P) !R {
            return inner(alloc, args, {}, {});
        }
        fn inner1_Q(alloc: std.mem.Allocator, args: Q) !R {
            return inner(alloc, {}, args, {});
        }
        fn inner1_B(alloc: std.mem.Allocator, args: B) !R {
            return inner(alloc, {}, {}, args);
        }

        fn inner2_PQ(alloc: std.mem.Allocator, args1: P, args2: Q) !R {
            return inner(alloc, args1, args2, {});
        }
        fn inner2_PB(alloc: std.mem.Allocator, args1: P, args2: B) !R {
            return inner(alloc, args1, {}, args2);
        }
        fn inner2_QB(alloc: std.mem.Allocator, args1: Q, args2: B) !R {
            return inner(alloc, {}, args1, args2);
        }

        fn inner(alloc: std.mem.Allocator, argsP: P, argsQ: Q, argsB: B) !R {
            @setEvalBranchQuota(1_000_000);

            const endpoint_actual = comptime replace(replace(endpoint, '{', "{["), '}', "]s}");
            const url = try std.fmt.allocPrint(alloc, "http://localhost:2375" ++ "/" ++ shared.version ++ endpoint_actual, if (P != void) argsP else .{});
            var paramsQ = try newUrlValues(alloc, Q, argsQ);
            defer paramsQ.inner.deinit(alloc);

            const full_url = try std.mem.concat(alloc, u8, &.{ url, "?", try paramsQ.encode() });

            var paramsB = try newUrlValues(alloc, B, argsB);
            defer paramsB.inner.deinit(alloc);

            var gpa = std.heap.GeneralPurposeAllocator(.{}){};
            var client = std.http.Client{ .allocator = gpa.allocator() };
            defer client.deinit();

            var headers: [4096]u8 = undefined;
            var body: [1024 * 1024 * 5]u8 = undefined;

            const uri = try std.Uri.parse(full_url);
            var req = try client.open(fixMethod(method), uri, .{ .server_header_buffer = &headers });
            defer req.deinit();

            if (fixMethod(method) != .GET) {
                if (B != void) {
                    // convert the struct to JSON
                    const json_body = try std.json.stringifyAlloc(alloc, argsB.body, .{});
                    defer alloc.free(json_body);
                    //std.debug.print("\nSending JSON body: {s}\n", .{json_body});

                    // IMPORTANT: Set transfer encoding before sending
                    req.transfer_encoding = .{ .content_length = json_body.len };

                    // Docker requires at least the MIME type sent as an additional header
                    req.headers.content_type = .{ .override = "application/json" };
                    req.headers.accept_encoding = .{ .override = "application/json" };

                    // Send the headers
                    try req.send();

                    //  write Content-Type header directly in the HTTP stream
                    // try req.writer().writeAll("Content-Type: application/json\r\n\r\n");

                    // now write the body
                    try req.writeAll(json_body);
                } else {
                    // with empty bodies (backward compatibility)
                    try req.send();
                    try req.writeAll(try paramsB.encode());
                }
            } else {
                // GET requests
                try req.send();
            }

            try req.finish();
            try req.wait();

            const read_result = try req.readAll(&body);
            const length = read_result;
            const code = translate_http_codes(req.response.status);

            inline for (std.meta.fields(R)) |item| {
                if (std.mem.eql(u8, item.name, code)) {
                    var stream = std.json.Scanner.initCompleteInput(alloc, body[0..length]);
                    const res = try std.json.parseFromTokenSource(std.meta.FieldType(R, @field(std.meta.FieldEnum(R), item.name)), alloc, &stream, .{
                        .ignore_unknown_fields = true,
                    });
                    return @unionInit(R, item.name, res.value);
                }
            }

            @panic(code);
        }
    };
}

fn replace(comptime haystack: string, comptime needle: u8, comptime replacement: string) string {
    comptime var res: string = &.{};
    inline for (haystack) |c| {
        if (c == needle) {
            res = res ++ replacement;
        } else {
            const temp: string = &.{c};
            res = res ++ temp;
        }
    }
    return res;
}

fn newUrlValues(alloc: std.mem.Allocator, comptime T: type, args: T) !*UrlValues {
    var params = try alloc.create(UrlValues);
    params.* = UrlValues.init(alloc);
    inline for (meta_fields(T)) |item| {
        const U = item.type;
        const key = item.name;
        const value = @field(args, item.name);

        if (comptime isZigString(U)) {
            try params.append(key, value);
        } else if (U == bool) {
            try params.append(key, if (value) "true" else "false");
        } else if (U == i32) {
            try params.append(key, try std.fmt.allocPrint(alloc, "{d}", .{value}));
        } else {
            //std.debug.print("{any}", .{U});
            //@compileError(@typeName(U));
        }
    }
    //std.debug.print("\nPARAMS: {any}\n", .{params});
    return params;
}

fn meta_fields(comptime T: type) []const std.builtin.Type.StructField {
    return switch (@typeInfo(T)) {
        .@"struct" => std.meta.fields(T),
        .void => &.{},
        else => |v| @compileError(@tagName(v)),
    };
}

fn fixMethod(m: Method) std.http.Method {
    return switch (m) {
        .get => .GET,
        .head => .HEAD,
        .post => .POST,
        .put => .PUT,
        .patch => .PATCH,
        .delete => .DELETE,
    };
}

pub fn isZigString(comptime T: type) bool {
    return comptime blk: {
        // Only pointer types can be strings, no optionals
        const info = @typeInfo(T);
        if (info != .pointer) break :blk false;

        const ptr = &info.pointer;
        // Check for CV qualifiers that would prevent coerction to []const u8
        if (ptr.is_volatile or ptr.is_allowzero) break :blk false;

        // If it's already a slice, simple check.
        if (ptr.size == .slice) {
            break :blk ptr.child == u8;
        }

        // Otherwise check if it's an array type that coerces to slice.
        if (ptr.size == .One) {
            const child = @typeInfo(ptr.child);
            if (child == .Array) {
                const arr = &child.Array;
                break :blk arr.child == u8;
            }
        }

        break :blk false;
    };
}

pub fn translate_http_codes(Status: anytype) string {
    const result = switch (Status) {
        std.http.Status.ok => "200",
        std.http.Status.created => "201",
        std.http.Status.no_content => "204",
        std.http.Status.not_modified => "304",
        std.http.Status.not_found => "404",
        else => "500",
    };
    return result;
}
