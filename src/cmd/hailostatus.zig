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
        device_bdf: hailo.device.PCIEInfo,
        driver_version: hailo.Version,
        device_properties: hailo.ioctl.PayloadType(.query_device_properties),
        device_identity: hailo.ControlResponse(.identify),
        device_information: hailo.ControlResponse(.get_device_information),
        power_measurements: []hailo.ControlResponse(.power_measurement),
        chip_temperature: hailo.ControlResponse(.get_chip_temperature),
    ) !void {
        try std.fmt.format(self.writer, "Device: /dev/{s} ({any})\n", .{ device_name, device_bdf });

        try std.fmt.format(self.writer, "Driver Version: {}\n", .{driver_version});

        try std.fmt.format(self.writer, "Max Page Size: {d}\n", .{device_properties.desc_max_page_size});
        try std.fmt.format(self.writer, "Board Type: {s}\n", .{@tagName(device_properties.board_type)});
        try std.fmt.format(self.writer, "Allocation Mode: {s}\n", .{@tagName(device_properties.allocation_mode)});
        try std.fmt.format(self.writer, "DMA Type: {s}\n", .{@tagName(device_properties.dma_type)});
        try std.fmt.format(self.writer, "DMA Engines Count: {d}\n", .{device_properties.dma_engines_count});
        try std.fmt.format(self.writer, "Is Firmware Loaded: {}\n", .{device_properties.is_fw_loaded != 1});

        try std.fmt.format(self.writer, "Control Protocol Version: {}\n", .{device_identity.protocol_version});
        try std.fmt.format(self.writer, "Firmware Version: {}\n", .{device_identity.fw_version});
        try std.fmt.format(self.writer, "Logger Version: {d}\n", .{device_identity.logger_version});
        try std.fmt.format(self.writer, "Board Name: {s}\n", .{device_identity.board_name});
        try std.fmt.format(self.writer, "Device Architecture: {}\n", .{device_identity.device_architecture});
        try std.fmt.format(self.writer, "Serial Number: {s}\n", .{device_identity.serial_number});
        try std.fmt.format(self.writer, "Part Number: {s}\n", .{device_identity.part_number});
        try std.fmt.format(self.writer, "Product Name: {s}\n", .{device_identity.product_name});

        try std.fmt.format(self.writer, "Core Clock Rate: {d}Hz\n", .{device_information.neural_network_core_clock_rate});
        try std.fmt.format(self.writer, "Supported Features: ethernet           {}\n", .{device_information.supported_features.ethernet});
        try std.fmt.format(self.writer, "                    mipi               {}\n", .{device_information.supported_features.mipi});
        try std.fmt.format(self.writer, "                    pcie               {}\n", .{device_information.supported_features.pcie});
        try std.fmt.format(self.writer, "                    current_monitoring {}\n", .{device_information.supported_features.current_monitoring});
        try std.fmt.format(self.writer, "                    mdio               {}\n", .{device_information.supported_features.mdio});
        try std.fmt.format(self.writer, "Boot Source: {s}\n", .{@tagName(device_information.boot_source)});
        try std.fmt.format(self.writer, "LCS: {d}\n", .{device_information.lcs});
        try std.fmt.format(self.writer, "SOC ID: {s}\n", .{std.fmt.bytesToHex(device_information.soc_id, .upper)});
        try std.fmt.format(self.writer, "Ethernet MAC Address: {X:0>2}:{X:0>2}:{X:0>2}:{X:0>2}:{X:0>2}:{X:0>2}\n", .{ device_information.eth_mac_address[0], device_information.eth_mac_address[1], device_information.eth_mac_address[2], device_information.eth_mac_address[3], device_information.eth_mac_address[4], device_information.eth_mac_address[5] });
        try std.fmt.format(self.writer, "ULT ID: {s}\n", .{std.fmt.bytesToHex(std.mem.asBytes(&device_information.fuse_info), .upper)});
        try std.fmt.format(self.writer, "PM Values: {s}\n", .{std.fmt.bytesToHex(&device_information.pd_info, .upper)});
        try std.fmt.format(self.writer, "Partial Clusters Layout Bitmap: {any}\n", .{device_information.partial_clusters_layout_bitmap});

        if (power_measurements.len > 0) {
            for (power_measurements, 0..) |power, i| {
                try std.fmt.format(self.writer, "{s} {s}: {d}{s}\n", .{ if (i == 0) "Measured Power:" else "               ", @tagName(power.dvm), power.value, power.type.unit() });
            }
        } else {
            try std.fmt.format(self.writer, "Measured Power: unavailable\n", .{});
        }

        try std.fmt.format(self.writer, "Temperature: S0  {d}C\n", .{chip_temperature.info.ts0_temperature});
        try std.fmt.format(self.writer, "             S1  {d}C\n", .{chip_temperature.info.ts1_temperature});
        try std.fmt.format(self.writer, "             Avg {d}C\n", .{(chip_temperature.info.ts0_temperature + chip_temperature.info.ts1_temperature) / 2});

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
        device_bdf: hailo.device.PCIEInfo,
        driver_version: hailo.Version,
        device_properties: hailo.ioctl.PayloadType(.query_device_properties),
        device_identity: hailo.ControlResponse(.identify),
        device_information: hailo.ControlResponse(.get_device_information),
        power_measurements: []hailo.ControlResponse(.power_measurement),
        chip_temperature: hailo.ControlResponse(.get_chip_temperature),
    ) !void {
        var buf: [16]u8 = undefined;

        try self.stream.beginObject();
        try self.stream.objectField("device");
        try self.stream.write(std.fmt.bufPrint(&buf, "/dev/{s}", .{device_name}) catch unreachable);
        try self.stream.objectField("bdf");
        try self.stream.write(device_bdf);
        try self.stream.objectField("driver_version");
        try self.stream.write(driver_version);
        try self.stream.objectField("device_properties");
        try self.stream.write(device_properties);
        try self.stream.objectField("device_identity");
        try self.stream.write(device_identity);
        try self.stream.objectField("device_information");
        try self.stream.write(device_information);
        try self.stream.objectField("power_measurements");
        try self.stream.write(power_measurements);
        try self.stream.objectField("chip_temperature");
        try self.stream.write(chip_temperature);
        try self.stream.endObject();
    }

    fn finalize(self: *JSONFormatter) !void {
        try self.stream.endArray();
        try self.stream.stream.writeByte('\n');
    }
};

const FormatterUnion = union(enum) {
    default: DefaultFormatter,
    json: JSONFormatter,

    inline fn format(
        self: *FormatterUnion,
        device_name: []const u8,
        device_bdf: hailo.device.PCIEInfo,
        driver_version: hailo.Version,
        device_properties: hailo.ioctl.PayloadType(.query_device_properties),
        device_identity: hailo.ControlResponse(.identify),
        device_information: hailo.ControlResponse(.get_device_information),
        power_measurements: []hailo.ControlResponse(.power_measurement),
        chip_temperature: hailo.ControlResponse(.get_chip_temperature),
    ) !void {
        switch (self.*) {
            inline else => |*formatter| {
                try formatter.format(
                    device_name,
                    device_bdf,
                    driver_version,
                    device_properties,
                    device_identity,
                    device_information,
                    power_measurements,
                    chip_temperature,
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

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var filename: ?[:0]u8 = null;
    defer if (filename) |s| allocator.free(s);

    var ft: std.meta.Tag(FormatterUnion) = .default;

    {
        const args = try std.process.argsAlloc(allocator);
        defer std.process.argsFree(allocator, args);

        for (args[1..]) |arg| {
            if (std.mem.eql(u8, arg, "-json")) {
                ft = .json;
            }

            if (arg.len > 0 and (arg[0] != '-' or arg.len == 1)) {
                filename = arg;
            }
        }

        if (filename) |s| {
            filename = try allocator.dupeZ(u8, s);
        }
    }

    var fileout = if (filename) |path| try std.fs.cwd().openFile(path, .{ .mode = .write_only }) else std.io.getStdOut();
    defer fileout.close();

    var formatter: FormatterUnion = switch (ft) {
        .default => .{ .default = DefaultFormatter.init(fileout.writer().any()) },
        .json => .{ .json = try JSONFormatter.init(fileout.writer().any()) },
    };

    var devices = try hailo.scan();
    defer devices.deinit();

    while (try devices.next()) |device_name| {
        const device_info = try hailo.queryDeviceInfo(device_name, .{});

        var device = try hailo.openDevice(device_name);
        defer device.close();

        const driver_version = try device.queryDriverInfo();

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

            if (device.control(.power_measurement, .{ .dvm = @field(DVM, field.name) }, .{ .log_response_error = false }) catch |err| blk: {
                if (err == error.FirmwareResponseError) {
                    break :blk null;
                }

                return err;
            }) |power| {
                power_buf[power_len] = power;
                power_len += 1;
            }
        }

        const chip_temperature = try device.control(.get_chip_temperature, .{}, .{});

        try formatter.format(
            device_name,
            device_info,
            driver_version,
            device_properties,
            identity,
            device_information,
            power_buf[0..power_len],
            chip_temperature,
        );
    }

    try formatter.finalize();
}
