const std = @import("std");
const testing = std.testing;

const root = @import("root.zig");
pub usingnamespace @import("ioctl/common.zig");
pub const ops = @import("ioctl/operations.zig");

const Request = std.os.linux.IOCTL.Request;

const protocols = struct {
    pub const @"4.17" = @import("ioctl/v4-17.zig");
    pub const @"4.18" = @import("ioctl/v4-18.zig");
};

pub const ProtocolVersion = std.meta.DeclEnum(protocols);

pub fn Protocol(comptime protocol_version: ProtocolVersion) type {
    const OuterCode = Code;
    const OuterPayloadType = PayloadType;

    return struct {
        const Self = @This();

        pub const operations = @field(protocols, @tagName(protocol_version));
        pub const version = protocol_version;

        pub const Code = OuterCode(protocol_version);
        pub fn PayloadType(comptime code: Self.Code) type {
            return OuterPayloadType(protocol_version, code);
        }

        pub fn runIoctl(
            device: std.fs.File,
            comptime code: Self.Code,
            data: *Self.PayloadType(code),
        ) !void {
            try run(device, protocol_version, code, data);
        }
    };
}

pub fn Code(comptime protocol_version: ProtocolVersion) type {
    const operations = Protocol(protocol_version).operations;

    var count: usize = 0;
    for (@typeInfo(operations).Struct.decls[1..]) |decl| {
        count += @typeInfo(@field(operations, decl.name)).Struct.decls.len - 1;
    }

    var enum_fields: [count]std.builtin.Type.EnumField = undefined;
    var current_field: usize = 0;
    for (@typeInfo(operations).Struct.decls[1..]) |group_decl| {
        const operation_group = @field(operations, group_decl.name);
        for (@typeInfo(operation_group).Struct.decls[1..], 0..) |op_decl, code| {
            const operation = @field(operation_group, op_decl.name);
            enum_fields[current_field] = .{
                .name = op_decl.name,

                .value = @as(u32, @bitCast(Request{
                    .nr = code,
                    .io_type = operation_group.magic,
                    .size = @bitSizeOf(operation.Payload) / 8,
                    .dir = (@intFromBool(operation.write)) | (@as(u2, @intFromBool(operation.read)) << 1),
                })),
            };

            current_field += 1;
        }
    }

    std.debug.assert(current_field == count);

    return @Type(.{
        .Enum = .{
            .tag_type = u32,
            .fields = &enum_fields,
            .decls = &.{},
            .is_exhaustive = true,
        },
    });
}

pub fn PayloadType(comptime protocol_version: ProtocolVersion, comptime code: Code(protocol_version)) type {
    const req = @as(Request, @bitCast(@as(u32, @intFromEnum(code))));

    const operations = Protocol(protocol_version).operations;

    inline for (@typeInfo(operations).Struct.decls[1..]) |group_decl| {
        // @compileLog(protocol_version, group_decl.name, req.nr);

        const operation_group = @field(operations, group_decl.name);
        if (operation_group.magic != req.io_type) {
            continue;
        }

        return @field(operation_group, @typeInfo(operation_group).Struct.decls[req.nr + 1].name).Payload;
    }

    std.debug.panic("invalid code");
}

pub fn run(
    comptime protocol_version: ProtocolVersion,
    device: std.fs.File,
    comptime code: Code(protocol_version),
    data: *PayloadType(protocol_version, code),
) !void {
    std.log.debug("running ioctl: {s} 0x{x} {any}", .{ @tagName(code), @intFromEnum(code), @as(Request, @bitCast(@intFromEnum(code))) });

    // std.os.windows.DeviceIoControl(device.handle);
    // const result = std.posix.errno(std.c.ioctl(device.handle, @bitCast(@intFromEnum(code)), @intFromPtr(data)));

    const result = std.posix.errno(std.posix.system.ioctl(device.handle, @bitCast(@intFromEnum(code)), @intFromPtr(data)));
    if (result != .SUCCESS) {
        std.debug.print("errno? {d} {s}\n", .{ @intFromEnum(result), @tagName(result) });
        return std.posix.unexpectedErrno(result);
    }
}
