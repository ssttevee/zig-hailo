const std = @import("std");
const builtin = @import("builtin");

const hailo = @import("hailo");

const DefaultFormatter = struct {
    writer: std.io.AnyWriter,

    pub fn init(writer: std.io.AnyWriter) DefaultFormatter {
        return .{ .writer = writer };
    }

    fn format(
        self: DefaultFormatter,
        device_name: []const u8,
        valid_device_info: ?ValidHailoDeviceInfo,
    ) !void {
        if (valid_device_info) |device_info| {
            try std.fmt.format(self.writer, "Device: /dev/{s} ({any})\n", .{ device_name, device_info.device_bdf });

            if (device_info.ioctl_info) |ioctl_info| {
                try std.fmt.format(self.writer, "Driver Version: {}\n", .{ioctl_info.driver_version});

                try std.fmt.format(self.writer, "Max Page Size: {d}\n", .{ioctl_info.device_properties.desc_max_page_size});
                try std.fmt.format(self.writer, "Board Type: {s}\n", .{@tagName(ioctl_info.device_properties.board_type)});
                try std.fmt.format(self.writer, "Allocation Mode: {s}\n", .{@tagName(ioctl_info.device_properties.allocation_mode)});
                try std.fmt.format(self.writer, "DMA Type: {s}\n", .{@tagName(ioctl_info.device_properties.dma_type)});
                try std.fmt.format(self.writer, "DMA Engines Count: {d}\n", .{ioctl_info.device_properties.dma_engines_count});
                try std.fmt.format(self.writer, "Is Firmware Loaded: {}\n", .{ioctl_info.device_properties.is_fw_loaded != 1});

                try std.fmt.format(self.writer, "Control Protocol Version: {}\n", .{ioctl_info.device_identity.protocol_version});
                try std.fmt.format(self.writer, "Firmware Version: {}\n", .{ioctl_info.device_identity.fw_version});
                try std.fmt.format(self.writer, "Logger Version: {d}\n", .{ioctl_info.device_identity.logger_version});
                try std.fmt.format(self.writer, "Board Name: {s}\n", .{ioctl_info.device_identity.board_name});
                try std.fmt.format(self.writer, "Device Architecture: {}\n", .{ioctl_info.device_identity.device_architecture});
                try std.fmt.format(self.writer, "Serial Number: {s}\n", .{ioctl_info.device_identity.serial_number});
                try std.fmt.format(self.writer, "Part Number: {s}\n", .{ioctl_info.device_identity.part_number});
                try std.fmt.format(self.writer, "Product Name: {s}\n", .{ioctl_info.device_identity.product_name});

                try std.fmt.format(self.writer, "Core Clock Rate: {d}Hz\n", .{ioctl_info.device_information.neural_network_core_clock_rate});
                try std.fmt.format(self.writer, "Supported Features: ethernet           {}\n", .{ioctl_info.device_information.supported_features.ethernet});
                try std.fmt.format(self.writer, "                    mipi               {}\n", .{ioctl_info.device_information.supported_features.mipi});
                try std.fmt.format(self.writer, "                    pcie               {}\n", .{ioctl_info.device_information.supported_features.pcie});
                try std.fmt.format(self.writer, "                    current_monitoring {}\n", .{ioctl_info.device_information.supported_features.current_monitoring});
                try std.fmt.format(self.writer, "                    mdio               {}\n", .{ioctl_info.device_information.supported_features.mdio});
                try std.fmt.format(self.writer, "Boot Source: {s}\n", .{@tagName(ioctl_info.device_information.boot_source)});
                try std.fmt.format(self.writer, "LCS: {d}\n", .{ioctl_info.device_information.lcs});
                try std.fmt.format(self.writer, "SOC ID: {s}\n", .{std.fmt.bytesToHex(ioctl_info.device_information.soc_id, .upper)});
                try std.fmt.format(self.writer, "Ethernet MAC Address: {X:0>2}:{X:0>2}:{X:0>2}:{X:0>2}:{X:0>2}:{X:0>2}\n", .{ ioctl_info.device_information.eth_mac_address[0], ioctl_info.device_information.eth_mac_address[1], ioctl_info.device_information.eth_mac_address[2], ioctl_info.device_information.eth_mac_address[3], ioctl_info.device_information.eth_mac_address[4], ioctl_info.device_information.eth_mac_address[5] });
                try std.fmt.format(self.writer, "ULT ID: {s}\n", .{std.fmt.bytesToHex(std.mem.asBytes(&ioctl_info.device_information.fuse_info), .upper)});
                try std.fmt.format(self.writer, "PM Values: {s}\n", .{std.fmt.bytesToHex(&ioctl_info.device_information.pd_info, .upper)});
                try std.fmt.format(self.writer, "Partial Clusters Layout Bitmap: {any}\n", .{ioctl_info.device_information.partial_clusters_layout_bitmap});

                if (ioctl_info.power_measurements.len > 0) {
                    for (ioctl_info.power_measurements, 0..) |power, i| {
                        try std.fmt.format(self.writer, "{s} {s}: {d}{s}\n", .{ if (i == 0) "Measured Power:" else "               ", @tagName(power.dvm), power.value, power.type.unit() });
                    }
                } else {
                    try std.fmt.format(self.writer, "Measured Power: unavailable\n", .{});
                }

                try std.fmt.format(self.writer, "Temperature: S0  {d}C\n", .{ioctl_info.chip_temperature.info.ts0_temperature});
                try std.fmt.format(self.writer, "             S1  {d}C\n", .{ioctl_info.chip_temperature.info.ts1_temperature});
                try std.fmt.format(self.writer, "             Avg {d}C\n", .{(ioctl_info.chip_temperature.info.ts0_temperature + ioctl_info.chip_temperature.info.ts1_temperature) / 2});
            } else {
                try std.fmt.format(self.writer, "WARNING: could not query device info - potentially unsupported driver version ({s})\n", .{device_info.kernel_module_version orelse "unknown"});
            }
        } else {
            try std.fmt.format(self.writer, "Device: /dev/{s} (could not query device info)\n", .{device_name});
        }

        try self.writer.writeByte('\n');
    }
};

const JSONFormatter = struct {
    stream: std.json.WriteStream(std.io.AnyWriter, .{ .checked_to_fixed_depth = 256 }),

    pub fn init(writer: std.io.AnyWriter) !JSONFormatter {
        var stream = std.json.writeStream(writer, .{});
        try stream.beginArray();
        return .{ .stream = stream };
    }

    fn format(
        self: *JSONFormatter,
        device_name: []const u8,
        valid_device_info: ?ValidHailoDeviceInfo,
    ) !void {
        var buf: [16]u8 = undefined;

        try self.stream.beginObject();
        try self.stream.objectField("device");
        try self.stream.write(std.fmt.bufPrint(&buf, "/dev/{s}", .{device_name}) catch unreachable);
        if (valid_device_info) |device_info| {
            try self.stream.objectField("bdf");
            try self.stream.write(device_info.device_bdf);
            if (device_info.ioctl_info) |ioctl_info| {
                try self.stream.objectField("driver_version");
                try self.stream.write(ioctl_info.driver_version);
                try self.stream.objectField("device_properties");
                try self.stream.write(ioctl_info.device_properties);
                try self.stream.objectField("device_identity");
                try self.stream.write(ioctl_info.device_identity);
                try self.stream.objectField("device_information");
                try self.stream.write(ioctl_info.device_information);
                try self.stream.objectField("power_measurements");
                try self.stream.write(ioctl_info.power_measurements);
                try self.stream.objectField("chip_temperature");
                try self.stream.write(ioctl_info.chip_temperature);
            } else {
                try self.stream.objectField("error");
                try self.stream.print("\"could not query device info: potentially unsupported driver version ({s})\"", .{device_info.kernel_module_version orelse "unknown"});
            }
        } else {
            try self.stream.objectField("error");
            try self.stream.write("could not query device info");
        }
        try self.stream.endObject();
    }

    fn finalize(self: *JSONFormatter) !void {
        try self.stream.endArray();
        try self.stream.stream.writeByte('\n');
    }
};

const SupportedProtocolInfo = struct {
    driver_version: hailo.Version,
    device_properties: hailo.ioctl.PayloadType(.query_device_properties),
    device_identity: hailo.ControlResponse(.identify),
    device_information: hailo.ControlResponse(.get_device_information),
    power_measurements: []hailo.ControlResponse(.power_measurement),
    chip_temperature: hailo.ControlResponse(.get_chip_temperature),
};

const ValidHailoDeviceInfo = struct {
    device_bdf: hailo.device.PCIEInfo,
    ioctl_info: ?SupportedProtocolInfo,
    kernel_module_version: ?[]const u8,
};

const FormatterUnion = union(enum) {
    default: DefaultFormatter,
    json: JSONFormatter,

    inline fn format(
        self: *FormatterUnion,
        device_name: []const u8,
        device_info: ?ValidHailoDeviceInfo,
    ) !void {
        switch (self.*) {
            inline else => |*formatter| {
                try formatter.format(
                    device_name,
                    device_info,
                );
            },
        }
    }

    inline fn finalize(self: *FormatterUnion) !void {
        switch (self.*) {
            inline else => |*formatter| {
                if (@hasDecl(@TypeOf(formatter.*), "finalize")) {
                    try formatter.finalize();
                }
            },
        }
    }
};

fn printDeviceStatus(formatter: *FormatterUnion, kernel_module_version: ?[]const u8, device_name: []const u8) !void {
    try formatter.format(
        device_name,
        if (hailo.queryDeviceInfo(device_name, .{}) catch |err| blk: {
            if (err == error.FileNotFound) {
                break :blk null;
            }

            return err;
        }) |device_info| blk: {
            var device = try hailo.openDevice(device_name);
            defer device.close();

            const driver_version = device.queryDriverInfo() catch |err| {
                if (err == error.Unexpected) {
                    break :blk .{
                        .device_bdf = device_info,
                        .ioctl_info = null,
                        .kernel_module_version = kernel_module_version,
                    };
                }

                return err;
            };

            const device_properties = try device.queryDeviceProperties();

            const identity = try device.control(.identify, .{}, .{});

            const device_information = try device.control(.get_device_information, .{}, .{});

            // try to read all power measurements
            const DVM = std.meta.FieldType(hailo.ControlResponse(.power_measurement), .dvm);
            var power_len: usize = 0;
            var power_buf: [@typeInfo(DVM).Enum.fields.len]hailo.ControlResponse(.power_measurement) = undefined;
            inline for (@typeInfo(DVM).Enum.fields) |field| {
                if (@field(DVM, field.name) == .auto) {
                    continue;
                }

                if (device.control(.power_measurement, .{ .dvm = @field(DVM, field.name) }, .{ .log_response_error = false }) catch |err| blk2: {
                    if (err == error.FirmwareResponseError) {
                        break :blk2 null;
                    }

                    return err;
                }) |power| {
                    power_buf[power_len] = power;
                    power_len += 1;
                }
            }

            const chip_temperature = try device.control(.get_chip_temperature, .{}, .{});

            break :blk .{
                .device_bdf = device_info,
                .ioctl_info = .{
                    .driver_version = driver_version,
                    .device_properties = device_properties,
                    .device_identity = identity,
                    .device_information = device_information,
                    .power_measurements = power_buf[0..power_len],
                    .chip_temperature = chip_temperature,
                },
                .kernel_module_version = kernel_module_version,
            };
        } else null,
    );
}

fn readKernelModuleVersion(allocator: std.mem.Allocator) !?[]const u8 {
    var child = std.process.Child.init(&[_][]const u8{ "modinfo", "hailo_pci" }, allocator);
    child.stdout_behavior = .Pipe;
    try child.spawn();
    defer _ = child.kill() catch {};

    const stdout = child.stdout.?.reader();
    const version_key = "version:";
    while (true) {
        const line = try stdout.readUntilDelimiterOrEofAlloc(allocator, '\n', 4096) orelse return null;
        defer allocator.free(line);
        if (std.mem.startsWith(u8, line, version_key)) {
            const trimmed = std.mem.trim(u8, line[version_key.len..], " ");
            return try allocator.dupe(u8, trimmed);
        }
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var filename: ?[]u8 = null;
    defer if (filename) |s| allocator.free(s);

    var ft: std.meta.Tag(FormatterUnion) = .default;

    var requested_devices = std.ArrayList([]const u8).init(allocator);
    defer {
        for (requested_devices.items) |s| {
            allocator.free(s);
        }

        requested_devices.deinit();
    }

    {
        const args = try std.process.argsAlloc(allocator);
        defer std.process.argsFree(allocator, args);

        for (args[1..]) |arg| {
            if (std.mem.eql(u8, arg, "-json")) {
                ft = .json;
            }

            if (std.mem.startsWith(u8, arg, "-out=")) {
                if (filename) |s| {
                    allocator.free(s);
                }

                const path = arg[5..];
                if (path.len > 0) {
                    filename = try allocator.dupe(u8, path);
                }
            }

            if (arg.len > 0 and arg[0] != '-') {
                try requested_devices.append(try allocator.dupe(u8, arg));
            }
        }
    }

    var fileout = if (filename) |path| try std.fs.cwd().openFile(path, .{ .mode = .write_only }) else std.io.getStdOut();
    defer fileout.close();

    var formatter: FormatterUnion = switch (ft) {
        .default => .{ .default = DefaultFormatter.init(fileout.writer().any()) },
        .json => .{ .json = try JSONFormatter.init(fileout.writer().any()) },
    };

    const kernel_module_version = readKernelModuleVersion(allocator) catch |err| blk: {
        std.fmt.format(std.io.getStdErr().writer(), "WARNING: failed to read kernel module version\n", .{}) catch {};
        std.fmt.format(std.io.getStdErr().writer(), "{any}\n", .{err}) catch {};
        break :blk null;
    };

    defer if (kernel_module_version) |s| allocator.free(s);

    if (requested_devices.items.len == 0) {
        var devices = try hailo.scan();
        defer devices.deinit();

        var i: usize = 0;
        while (try devices.next()) |device_name| {
            try printDeviceStatus(&formatter, kernel_module_version, device_name);
            i += 1;
        }

        if (i == 0 and formatter == .default) {
            try fileout.writer().writeAll("Error: No hailo devices found\n");
        }
    } else {
        for (requested_devices.items) |device_name| {
            try printDeviceStatus(&formatter, kernel_module_version, device_name);
        }
    }

    try formatter.finalize();
}
