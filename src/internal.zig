const std = @import("std");
const builtin = @import("builtin");
const string = []const u8;
const zfetch = @import("zfetch");
const UrlValues = @import("UrlValues");
const extras = @import("extras");

const shared = @import("./shared.zig");

pub fn AllOf(comptime xs: []const type) type {
    var fields: []const std.builtin.Type.StructField = &.{};
    inline for (xs) |item| {
        fields = fields ++ std.meta.fields(item);
    }
    return Struct(fields);
}

fn Struct(comptime fields: []const std.builtin.Type.StructField) type {
    return @Type(.{ .@"struct" = .{ .layout = .@"auto", .fields = fields, .decls = &.{}, .is_tuple = false } });
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
            const url = try std.fmt.allocPrint(alloc, "http://localhost" ++ "/" ++ shared.version ++ endpoint_actual, if (P != void) argsP else .{});

            var paramsQ = try newUrlValues(alloc, Q, argsQ);
            defer paramsQ.inner.deinit();

            const full_url = try std.mem.concat(alloc, u8, &.{ url, "?", try paramsQ.encode() });
            std.log.debug("{s} {s}", .{ @tagName(fixMethod(method)), full_url });

            const conn = try zfetch.Connection.connect(alloc, .{ .protocol = .unix, .hostname = "/var/run/docker.sock" });
            var req = try zfetch.Request.fromConnection(alloc, conn, full_url);

            var paramsB = try newUrlValues(alloc, B, argsB);
            defer paramsB.inner.deinit();

            var headers = zfetch.Headers.init(alloc);
            try headers.appendValue("Content-Type", "application/x-www-form-urlencoded");

            try req.do(fixMethod(method), headers, if (paramsB.inner.count() == 0) null else try paramsB.encode());
            const r = req.reader();
            const body_content = try r.readAllAlloc(alloc, 1024 * 1024 * 5);
            const code = try std.fmt.allocPrint(alloc, "{d}", .{builtin.enumToInt(req.status)});
            std.log.debug("{d}", .{builtin.enumToInt(req.status)});
            std.log.debug("{s}", .{body_content});

            inline for (std.meta.fields(R)) |item| {
                if (std.mem.eql(u8, item.name, code)) {
                    var jstream = std.json.Scanner.initCompleteInput(alloc, body_content);
                    const res = try std.json.parseFromTokenSource(extras.FieldType(R, @field(std.meta.FieldEnum(R), item.name)), alloc, &jstream, .{
                        .ignore_unknown_fields = true,
                    });
                    return @unionInit(R, item.name, res);
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

        if (comptime std.meta.trait.isZigString(U)) {
            try params.add(key, value);
        } else if (U == bool) {
            try params.add(key, if (value) "true" else "false");
        } else if (U == i32) {
            try params.add(key, try std.fmt.allocPrint(alloc, "{d}", .{value}));
        } else {
            @compileError(@typeName(U));
        }
    }
    return params;
}

fn meta_fields(comptime T: type) []const std.builtin.Type.StructField {
    return switch (@typeInfo(T)) {
        .Struct => std.meta.fields(T),
        .Void => &.{},
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
