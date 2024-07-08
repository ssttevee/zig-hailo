const std = @import("std");
const testing = std.testing;

const util = @import("util.zig");

pub const ioctl = @import("ioctl.zig");

pub const control = @import("control.zig").control;
pub const control_protocol_version = @import("control.zig").protocol_version;
pub const ControlOptions = @import("control.zig").Options;
pub const ControlOperation = @import("control.zig").Operation;
pub const ControlRequest = @import("control.zig").OperationRequest;
pub const ControlResponse = @import("control.zig").OperationResponse;

pub const device = @import("device.zig");

pub const queryDeviceInfo = device.queryInfo;
pub const openDevice = device.open;

pub const Version = extern struct {
    major: u32,
    minor: u32,
    revision: u32,

    pub fn format(self: Version, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        try std.fmt.format(writer, "{d}.{d}.{d}", .{ self.major, self.minor, self.revision });
    }

    pub fn toString(self: Version) [32:0]u8 {
        var buf = std.mem.zeroes([32:0]u8);
        var stream = std.io.fixedBufferStream(&buf);
        self.format("", .{}, stream.writer()) catch |err| {
            std.debug.panic("{any}", .{err});
        };
        return buf;
    }

    pub fn jsonStringify(self: Version, stream: anytype) !void {
        try stream.write(util.cstr(&self.toString()));
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
