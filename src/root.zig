const std = @import("std");
const testing = std.testing;

pub const ioctl = @import("ioctl.zig");

pub const control = @import("control.zig").control;
pub const control_protocol_version = @import("control.zig").protocol_version;
pub const ControlOptions = @import("control.zig").Options;
pub const ControlOperation = @import("control.zig").Operation;
pub const ControlOperationRequest = @import("control.zig").OperationRequest;
pub const ControlOperationResponse = @import("control.zig").OperationResponse;

pub const device = @import("device.zig");

pub const queryDeviceInfo = device.queryInfo;
pub const openDevice = device.open;

pub const Version = extern struct {
    major: u32,
    minor: u32,
    revision: packed struct(u32) {
        revision: u27,
        app_core: bool,
        _: u1,
        extended_context_switch_buffer: bool,
        dev: bool,
        second_stage: bool,
    },

    pub fn format(self: Version, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = options;

        try std.fmt.format(writer, "{d}.{d}.{d}", .{ self.major, self.minor, self.revision.revision });

        if (std.mem.eql(u8, fmt, "firmware")) {
            try writer.writeAll(" (");

            if (self.revision.dev) {
                try writer.writeAll("develop");
            } else {
                try writer.writeAll("release");
            }

            try writer.writeAll(", ");

            if (self.revision.second_stage) {
                try writer.writeAll("invalid");
            } else if (self.revision.app_core) {
                try writer.writeAll("core");
            } else {
                try writer.writeAll("app");
            }

            if (self.revision.extended_context_switch_buffer) {
                try writer.writeAll(", extended context switch buffer");
            }

            try writer.writeByte(')');
        }
    }
};

const device_name_prefix = "hailo";

pub const DeviceIterator = struct {
    iter: std.fs.Dir.Iterator,

    /// returns device name
    pub fn next(self: *DeviceIterator) !?[]const u8 {
        while (try self.iter.next()) |entry| {
            if (std.mem.startsWith(u8, entry.name, device_name_prefix)) {
                return entry.name;
            }
        }

        return null;
    }

    pub fn deinit(self: *DeviceIterator) void {
        self.iter.dir.close();
        self.* = undefined;
    }
};

pub fn scan() !DeviceIterator {
    var devdir = try std.fs.openDirAbsolute("/dev/", .{ .access_sub_paths = false, .iterate = true });

    return .{
        .iter = devdir.iterate(),
    };
}
