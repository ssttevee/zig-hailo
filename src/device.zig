const std = @import("std");
const testing = std.testing;

const ioctl = @import("ioctl.zig");
const hailo = @import("root.zig");
const util = @import("util.zig");

file: std.fs.File,
control_sequence: u32 = 0,

const Device = @This();

pub const PCIEInfo = struct {
    domain: ?u16,
    bus: u8,
    device: u8,
    func: u4,

    pub fn format(self: PCIEInfo, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        if (self.domain) |domain| {
            try std.fmt.format(writer, "{x:0>4}:", .{domain});
        }

        try std.fmt.format(writer, "{x:0>2}:{x:0>2}.{x:0>2}", .{ self.bus, self.device, self.func });
    }

    pub fn toString(self: PCIEInfo) [13:0]u8 {
        var buf = std.mem.zeroes([13:0]u8);
        var stream = std.io.fixedBufferStream(&buf);
        self.format("", .{}, stream.writer()) catch unreachable;
        return buf;
    }

    pub fn jsonStringify(self: PCIEInfo, stream: anytype) !void {
        try stream.write(util.cstr(&self.toString()));
    }
};

const QueryInfoOptions = struct {
    log_on_error: bool = false,
};

pub fn queryInfo(device_name: []const u8, options: QueryInfoOptions) !PCIEInfo {
    var class_dir = try std.fs.openDirAbsolute("/sys/class/hailo_chardev", .{});
    defer class_dir.close();

    var device_class_dir = try class_dir.openDir(device_name, .{});
    defer device_class_dir.close();

    var device_id_file = try device_class_dir.openFile("board_location", .{});
    defer device_id_file.close();

    var device_id_buf: [16]u8 = undefined;
    const line = try device_id_file.reader().readUntilDelimiterOrEof(&device_id_buf, '\n') orelse return error.UnexpectedEOF;
    errdefer {
        if (options.log_on_error) {
            std.log.err("Invalid device info string (format is [<domain>:]<bus>:<device>.<func>) {s}", .{line});
        }
    }

    var info: PCIEInfo = undefined;

    const colons = std.mem.count(u8, line, ":");
    var parts_iter = std.mem.splitScalar(u8, line, ':');
    if (colons == 2) {
        info.domain = try std.fmt.parseInt(u16, parts_iter.next().?, 16);
    } else if (colons == 1) {
        info.domain = null;
    } else {
        return error.BadDevice;
    }

    info.bus = try std.fmt.parseInt(u8, parts_iter.next().?, 16);

    var dot_split_iter = std.mem.splitScalar(u8, parts_iter.next().?, '.');
    info.device = try std.fmt.parseInt(u8, dot_split_iter.next().?, 16);
    if (dot_split_iter.next()) |func_str| {
        info.func = try std.fmt.parseInt(u4, func_str, 10);
    } else {
        return error.BadDevice;
    }

    return info;
}

pub fn open(device_name: []const u8) !Device {
    var devdir = try std.fs.openDirAbsolute("/dev/", .{});
    defer devdir.close();

    return .{
        .file = try devdir.openFile(device_name, .{ .mode = .read_write }),
    };
}

pub fn close(self: *Device) void {
    self.file.close();
    self.* = undefined;
}

pub fn queryDriverInfo(self: Device, comptime protocol_version: ioctl.ProtocolVersion) !ioctl.ops.QueryDriverInfo.Payload {
    var info: ioctl.PayloadType(protocol_version, .query_driver_info) = undefined;
    try ioctl.run(protocol_version, self.file, .query_driver_info, &info);
    return info;
}

pub fn queryDeviceProperties(self: Device, comptime protocol_version: ioctl.ProtocolVersion) !ioctl.ops.QueryDeviceProperties.Payload {
    var props: ioctl.PayloadType(protocol_version, .query_device_properties) = undefined;
    try ioctl.run(protocol_version, self.file, .query_device_properties, &props);
    return props;
}

pub fn control(
    self: *Device,
    comptime protocol_version: ioctl.ProtocolVersion,
    comptime op: hailo.ControlOperation,
    request: hailo.ControlRequest(op),
    options: hailo.ControlOptions,
) !hailo.ControlResponse(op) {
    defer self.control_sequence += 1;

    return try hailo.control(protocol_version, self.file, op, request, self.control_sequence, options);
}
