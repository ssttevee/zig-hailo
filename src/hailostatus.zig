const std = @import("std");
const builtin = @import("builtin");

const hailo = @import("root.zig");

pub fn main() !void {
    var devices = try hailo.scan();
    defer devices.deinit();

    while (try devices.next()) |device_name| {
        const device_info = try hailo.queryDeviceInfo(device_name, .{});
        std.log.info("Device: /dev/{s} ({any})", .{ device_name, device_info });

        var device = try hailo.openDevice(device_name);
        defer device.close();

        const driver_version = try device.queryDriverInfo();
        std.log.info("Driver Version: {any}", .{driver_version});

        _ = try device.queryDeviceProperties();

        const identity = try device.control(.identify, .{}, .{});
        std.log.info("Control Protocol Version: {}", .{identity.protocol_version});
        std.log.info("Firmware Version: {firmware}", .{identity.fw_version});
        std.log.info("Logger Version: {}", .{identity.logger_version});
        std.log.info("Board Name: {s}", .{identity.board_name});
        std.log.info("Device Architecture: {}", .{identity.device_architecture});
        std.log.info("Serial Number: {s}", .{identity.serial_number});
        std.log.info("Part Number: {s}", .{identity.part_number});
        std.log.info("Product Name: {s}", .{identity.product_name});

        const device_information = try device.control(.get_device_information, .{}, .{});
        std.log.info("Core Clock Rate: {d}Hz", .{device_information.neural_network_core_clock_rate});
        std.log.info("Supported Features: ethernet           {}", .{device_information.supported_features.ethernet});
        std.log.info("                    mipi               {}", .{device_information.supported_features.mipi});
        std.log.info("                    pcie               {}", .{device_information.supported_features.pcie});
        std.log.info("                    current_monitoring {}", .{device_information.supported_features.current_monitoring});
        std.log.info("                    mdio               {}", .{device_information.supported_features.mdio});
        std.log.info("Boot Source: {s}", .{@tagName(device_information.boot_source)});
        std.log.info("LCS: {d}", .{device_information.lcs});
        std.log.info("SOC ID: {s}", .{std.fmt.bytesToHex(device_information.soc_id, .upper)});
        std.log.info("Ethernet MAC Address: {X:0>2}:{X:0>2}:{X:0>2}:{X:0>2}:{X:0>2}:{X:0>2}", .{ device_information.eth_mac_address[0], device_information.eth_mac_address[1], device_information.eth_mac_address[2], device_information.eth_mac_address[3], device_information.eth_mac_address[4], device_information.eth_mac_address[5] });
        std.log.info("ULT ID: {s}", .{std.fmt.bytesToHex(std.mem.asBytes(&device_information.fuse_info), .upper)});
        std.log.info("PM Values: {s}", .{std.fmt.bytesToHex(&device_information.pd_info, .upper)});
        std.log.info("Partial Clusters Layout Bitmap: {any}", .{device_information.partial_clusters_layout_bitmap});

        // try to read all power measurements
        const DVM = std.meta.FieldType(hailo.ControlOperationResponse(.power_measurement), .dvm);
        var i: usize = 0;
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
                std.log.info("{s} {s}: {d}{s}", .{ if (i == 0) "Measured Power:" else "               ", @tagName(power.dvm), power.value, power.type.unit() });
                i += 1;
            }
        }

        if (i == 0) {
            std.log.info("Measured Power: unavailable", .{});
        }

        const chip_temperature = try device.control(.get_chip_temperature, .{}, .{});
        std.log.info("Temperature: S0  {d}C", .{chip_temperature.info.ts0_temperature});
        std.log.info("             S1  {d}C", .{chip_temperature.info.ts1_temperature});
        std.log.info("             Avg {d}C", .{(chip_temperature.info.ts0_temperature + chip_temperature.info.ts1_temperature) / 2});

        std.debug.print("\n", .{});
    }
}
