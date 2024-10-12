const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;

const native_endian = builtin.cpu.arch.endian();

const root = @import("root.zig");
const firmware = @import("firmware.zig");
const ioctl = @import("ioctl.zig");
const util = @import("util.zig");

const CpuId = ioctl.CpuId;

pub const protocol_version = 2;

fn TrailingData(comptime T: type, comptime max_struct_size: usize) type {
    var spec = @typeInfo(T);
    std.debug.assert(spec == .Struct);
    spec.Struct.fields = spec.Struct.fields ++ &[_]std.builtin.Type.StructField{
        .{
            .name = "data",
            .type = [max_struct_size - @sizeOf(T)]u8,
            .default_value = null,
            .is_comptime = false,
            .alignment = 0,
        },
    };
    const U = @Type(spec);
    std.debug.assert(@sizeOf(U) == max_struct_size);
    return U;
}

pub const FirmwareVersion = extern struct {
    major: u32,
    minor: u32,
    revision: packed struct(u32) {
        revision: u27,
        core: bool,
        _: u1,
        extended_context_switch_buffer: bool,
        dev: bool,
        second_stage: bool,
    },

    pub fn format(self: @This(), comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        try std.fmt.format(writer, "{d}.{d}.{d} (", .{ self.major, self.minor, self.revision.revision });

        if (self.revision.dev) {
            try writer.writeAll("develop");
        } else {
            try writer.writeAll("release");
        }

        try writer.writeAll(", ");

        if (self.revision.second_stage) {
            try writer.writeAll("invalid");
        } else if (self.revision.core) {
            try writer.writeAll("core");
        } else {
            try writer.writeAll("app");
        }

        if (self.revision.extended_context_switch_buffer) {
            try writer.writeAll(", extended context switch buffer");
        }

        try writer.writeByte(')');
    }

    pub fn toString(self: @This()) [128:0]u8 {
        var buf = std.mem.zeroes([128:0]u8);
        var stream = std.io.fixedBufferStream(&buf);
        self.format("", .{}, stream.writer()) catch unreachable;
        return buf;
    }

    pub fn jsonStringify(self: @This(), stream: anytype) !void {
        try stream.beginObject();
        try stream.objectField("version");
        try stream.write(root.Version{ .major = self.major, .minor = self.minor, .revision = self.revision.revision });
        try stream.objectField("mode");
        try stream.write(if (self.revision.dev) "develop" else "release");
        try stream.objectField("firmware_type");
        try stream.write(if (self.revision.second_stage) "invalid" else if (self.revision.core) "core" else "app");
        try stream.objectField("extended_context_switch_buffer");
        try stream.write(self.revision.extended_context_switch_buffer);
        try stream.endObject();
    }
};

pub const operations = struct {
    pub const identify = struct {
        pub const is_critical = true;
        pub const cpu_id = CpuId.app;

        pub const Request = struct {};
        pub const Response = struct {
            pub const Architecture = enum(u32) {
                hailo8_a0,
                hailo8,
                hailo8l,
                hailo15h,
                pluto,
                _,

                pub fn format(self: Architecture, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
                    _ = fmt;
                    _ = options;

                    var buf: [8]u8 = undefined;
                    try writer.writeAll(switch (self) {
                        .hailo8, .hailo8l, .hailo15h, .pluto => std.ascii.upperString(&buf, @tagName(self)),
                        else => "Unknown",
                    });
                }

                pub fn toString(self: Architecture) [8:0]u8 {
                    var buf = std.mem.zeroes([8:0]u8);
                    var stream = std.io.fixedBufferStream(&buf);
                    self.format("", .{}, stream.writer()) catch unreachable;
                    return buf;
                }

                pub fn jsonStringify(self: Architecture, stream: anytype) !void {
                    try stream.write(util.cstr(&self.toString()));
                }
            };

            protocol_version: u32,
            fw_version: FirmwareVersion,
            logger_version: u32,
            board_name: [32]u8,
            device_architecture: Architecture,
            serial_number: [16]u8,
            part_number: [16]u8,
            product_name: [42]u8,

            fn parse(bytes: []const u8) Response {
                var res = defaultParseResponse(Response, bytes);
                convertPtrEndian(.big, &res.protocol_version);
                convertPtrEndian(.little, &res.fw_version);
                convertPtrEndian(.big, &res.logger_version);
                convertPtrEndian(.big, &res.device_architecture);
                return res;
            }

            pub fn jsonStringify(self: @This(), stream: anytype) !void {
                try stream.beginObject();
                try stream.objectField("protocol_version");
                try stream.write(self.protocol_version);
                try stream.objectField("firmware_version");
                try stream.write(self.fw_version);
                try stream.objectField("logger_version");
                try stream.write(self.logger_version);
                try stream.objectField("board_name");
                try stream.write(util.cstr(&self.board_name));
                try stream.objectField("device_architecture");
                try stream.write(self.device_architecture);
                try stream.objectField("serial_number");
                try stream.write(util.cstr(&self.serial_number));
                try stream.objectField("part_number");
                try stream.write(util.cstr(&self.part_number));
                try stream.objectField("product_name");
                try stream.write(util.cstr(&self.product_name));
                try stream.endObject();
            }
        };
    };

    pub const write_memory = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.app;
    };

    pub const read_memory = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.app;
    };

    pub const config_stream = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.app;
    };

    pub const open_stream = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.app;
    };

    pub const close_stream = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.app;
    };

    pub const phy_operation = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.app;
    };

    pub const reset = struct {
        pub const is_critical = true;
        pub const cpu_id = CpuId.app;
    };

    pub const config_core_top = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.app;
    };

    pub const power_measurement = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.app;

        pub const DVM = enum(u32) {
            vdd_core,
            vdd_io,
            mipi_avdd,
            mipi_avdd_h,
            usb_avdd_io,
            vdd_top,
            usb_avdd_io_hv,
            avdd_h,
            sdio_vdd_io,
            overcurrent_protection,

            evb_total_power = std.math.maxInt(u31) - 1,
            auto = std.math.maxInt(u31),
        };

        pub const Type = enum(u32) {
            shunt_voltage,
            bus_voltage,
            power,
            current,

            auto = std.math.maxInt(u31),

            pub fn unit(self: @This()) []const u8 {
                return switch (self) {
                    .shunt_voltage, .bus_voltage => "mV",
                    .auto, .power => "W",
                    .current => "mW",
                };
            }
        };

        pub const Request = extern struct {
            dvm: DVM = .auto,
            type: Type = .auto,
        };

        pub const Response = extern struct {
            value: f32,
            dvm: DVM,
            type: Type,

            fn parse(bytes: []const u8) Response {
                var res = defaultParseResponse(Response, bytes);
                convertPtrEndian(.little, &res);
                return res;
            }
        };
    };

    pub const set_power_measurement = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.app;
    };

    pub const get_power_measurement = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.app;
    };

    pub const start_power_measurement = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.app;
    };

    pub const stop_power_measurement = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.app;
    };

    pub const start_firmware_update = struct {
        pub const is_critical = true;
        pub const cpu_id = CpuId.app;
    };

    pub const write_firmware_update = struct {
        pub const is_critical = true;
        pub const cpu_id = CpuId.app;
    };

    pub const validate_firmware_update = struct {
        pub const is_critical = true;
        pub const cpu_id = CpuId.app;
    };

    pub const finish_firmware_update = struct {
        pub const is_critical = true;
        pub const cpu_id = CpuId.app;
    };

    pub const examine_user_config = struct {
        pub const is_critical = true;
        pub const cpu_id = CpuId.app;
    };

    pub const read_user_config = struct {
        pub const is_critical = true;
        pub const cpu_id = CpuId.app;
    };

    pub const erase_user_config = struct {
        pub const is_critical = true;
        pub const cpu_id = CpuId.app;
    };

    pub const write_user_config = struct {
        pub const is_critical = true;
        pub const cpu_id = CpuId.app;
    };

    pub const i2c_write = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.app;
    };

    pub const i2c_read = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.app;
    };

    pub const nn_core_latency_measurement_config = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.app;
    };

    pub const nn_core_latency_measurement_read = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.app;
    };

    pub const sensor_store_config = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.app;
    };

    pub const sensor_get_config = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.app;
    };

    pub const sensor_set_generic_i2c_slave = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.app;
    };

    pub const sensor_load_and_start = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.app;
    };

    pub const sensor_reset = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.app;
    };

    pub const sensor_get_sections_info = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.app;
    };

    pub const context_switch_set_network_group_header = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.core;
    };

    pub const context_switch_set_context_info = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.core;
    };

    pub const idle_time_set_measurement = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.app;
    };

    pub const idle_time_get_measurement = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.app;
    };

    pub const download_context_action_list = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.core;
    };

    pub const change_context_switch_status = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.core;
    };

    pub const app_wd_enable = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.app;
    };

    pub const app_wd_config = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.app;
    };

    pub const app_previous_system_state = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.app;
    };

    pub const set_dataflow_interrupt = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.core;
    };

    pub const core_identify = struct {
        pub const is_critical = true;
        pub const cpu_id = CpuId.core;
        pub const Request = struct {};
        pub const Response = struct {
            fw_version: FirmwareVersion,
        };
    };

    pub const d2h_event_manager_set_host_info = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.app;
    };

    pub const d2h_event_manager_send_event_host_info = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.app;
    };

    /// obsolete
    pub const switch_application = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.core;
    };

    pub const get_chip_temperature = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.app;
        pub const Request = struct {};
        pub const Response = extern struct {
            const Temperature = extern struct {
                ts0_temperature: f32,
                ts1_temperature: f32,
                sample_count: u16,
            };

            info: Temperature,

            fn parse(bytes: []const u8) Response {
                std.debug.assert(bytes.len >= 14);

                var res = Response{
                    .info = .{
                        .ts0_temperature = @as(*align(1) const f32, @ptrCast(bytes.ptr + 4)).*,
                        .ts1_temperature = @as(*align(1) const f32, @ptrCast(bytes.ptr + 8)).*,
                        .sample_count = @as(*align(1) const u16, @ptrCast(bytes.ptr + 12)).*,
                    },
                };

                convertPtrEndian(.big, &res);

                return res;
            }

            pub fn jsonStringify(self: @This(), stream: anytype) !void {
                try stream.beginObject();
                try stream.objectField("s0");
                try stream.write(self.info.ts0_temperature);
                try stream.objectField("s1");
                try stream.write(self.info.ts1_temperature);
                try stream.objectField("sample_count");
                try stream.write(self.info.sample_count);
                try stream.endObject();
            }
        };
    };

    pub const read_board_config = struct {
        pub const is_critical = true;
        pub const cpu_id = CpuId.app;
    };

    pub const write_board_config = struct {
        pub const is_critical = true;
        pub const cpu_id = CpuId.app;
    };

    /// obsolete
    pub const get_soc_id = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.app;
    };

    pub const enable_debugging = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.app;
    };

    pub const get_device_information = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.app;
        pub const Request = struct {};
        pub const Response = struct {
            const SupportedFeatures = packed struct {
                _reserved0: u32,

                /// Is ethernet supported
                ethernet: bool,
                /// Is mipi supported
                mipi: bool,
                /// Is pcie supported
                pcie: bool,
                /// Is current monitoring supported
                current_monitoring: bool,
                /// Is current mdio supported
                mdio: bool,

                _reserved1: u27,

                pub fn jsonStringify(self: @This(), stream: anytype) !void {
                    try stream.beginObject();
                    try stream.objectField("ethernet");
                    try stream.write(self.ethernet);
                    try stream.objectField("mipi");
                    try stream.write(self.mipi);
                    try stream.objectField("pcie");
                    try stream.write(self.pcie);
                    try stream.objectField("current_monitoring");
                    try stream.write(self.current_monitoring);
                    try stream.objectField("mdio");
                    try stream.write(self.mdio);
                    try stream.endObject();
                }
            };

            comptime {
                std.debug.assert(@sizeOf(SupportedFeatures) == 8);
            }

            const BootSource = enum(u32) {
                invalid,
                pcie,
                flash,
            };

            const FuseInfo = extern struct {
                lot_id: [8]u8,
                die_wafer_info: u32,
            };

            const PartialClustersLayoutBitmap = enum(u32) {
                hailo15m_0 = 0b01110,
                hailo15m_1 = 0b01101,
                hailo15m_2 = 0b10011,
                default = 0b11111,

                ignore = std.math.maxInt(u32),
                _,

                pub fn format(self: @This(), comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
                    _ = fmt;
                    _ = options;

                    try writer.writeAll(switch (self) {
                        .hailo15m_0, .hailo15m_1, .hailo15m_2, .default, .ignore => @tagName(self),
                        else => "unknown",
                    });
                }

                pub fn toString(self: @This()) [10:0]u8 {
                    var buf = std.mem.zeroes([10:0]u8);
                    var stream = std.io.fixedBufferStream(&buf);
                    self.format("", .{}, stream.writer()) catch unreachable;
                    return buf;
                }

                pub fn jsonStringify(self: @This(), stream: anytype) !void {
                    try stream.write(util.cstr(&self.toString()));
                }
            };

            neural_network_core_clock_rate: u32,
            supported_features: SupportedFeatures,
            boot_source: BootSource,
            lcs: u8,
            soc_id: [32]u8,
            eth_mac_address: [6]u8,
            fuse_info: FuseInfo,
            pd_info: [24]u8,

            /// Seems like this is only for Hailo-15.
            ///
            /// There are some reference here:
            /// - https://github.com/hailo-ai/hailort/blob/e2190aeda847ab22057d162d08b516c39ac36ab8/hailort/libhailort/src/utils/soc_utils/partial_cluster_reader.hpp
            /// - https://github.com/hailo-ai/hailort/blob/e2190aeda847ab22057d162d08b516c39ac36ab8/hailort/libhailort/src/utils/soc_utils/partial_cluster_reader.cpp
            partial_clusters_layout_bitmap: PartialClustersLayoutBitmap,

            pub fn jsonStringify(self: @This(), stream: anytype) !void {
                var buf: [32]u8 = undefined;

                try stream.beginObject();
                try stream.objectField("neural_network_core_clock_rate");
                try stream.write(self.neural_network_core_clock_rate);
                try stream.objectField("supported_features");
                try stream.write(self.supported_features);
                try stream.objectField("boot_source");
                try stream.write(self.boot_source);
                try stream.objectField("lcs");
                try stream.write(self.lcs);
                try stream.objectField("soc_id");
                try stream.write(std.fmt.bytesToHex(&self.soc_id, .upper));
                try stream.objectField("eth_mac_address");
                try stream.write(std.fmt.bufPrint(&buf, "{X:0>2}:{X:0>2}:{X:0>2}:{X:0>2}:{X:0>2}:{X:0>2}", .{ self.eth_mac_address[0], self.eth_mac_address[1], self.eth_mac_address[2], self.eth_mac_address[3], self.eth_mac_address[4], self.eth_mac_address[5] }) catch unreachable);
                try stream.objectField("fuse_info");
                try stream.write(std.fmt.bytesToHex(std.mem.asBytes(&self.fuse_info), .upper));
                try stream.objectField("pd_info");
                try stream.write(std.fmt.bytesToHex(&self.pd_info, .upper));
                try stream.objectField("partial_clusters_layout_bitmap");
                try stream.write(self.partial_clusters_layout_bitmap);
                try stream.endObject();
            }
        };
    };

    pub const config_context_switch_breakpoint = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.core;
    };

    pub const get_context_switch_breakpoint_status = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.core;
    };

    pub const get_context_switch_main_header = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.core;
    };

    pub const set_fw_logger = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.app;
    };

    pub const write_second_stage_to_internal_memory = struct {
        pub const is_critical = true;
        pub const cpu_id = CpuId.app;
    };

    pub const copy_second_stage_to_flash = struct {
        pub const is_critical = true;
        pub const cpu_id = CpuId.app;
    };

    pub const set_pause_frames = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.app;
    };

    pub const config_context_switch_timestamp = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.core;
    };

    pub const run_bist_test = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.app;
    };

    pub const set_clock_freq = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.app;
    };

    pub const get_health_information = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.app;
    };

    pub const set_throttling_state = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.app;
    };

    pub const get_throttling_state = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.app;
    };

    pub const sensor_set_i2c_bus_index = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.app;
    };

    pub const set_overcurrent_state = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.app;
    };

    pub const get_overcurrent_state = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.app;
    };

    pub const core_previous_system_state = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.core;
    };

    pub const core_wd_enable = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.core;
    };

    pub const core_wd_config = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.core;
    };

    pub const context_switch_clear_configured_apps = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.core;
    };

    pub const get_hw_consts = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.core;
    };

    pub const set_sleep_state = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.app;
    };

    pub const change_hw_infer_status = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.core;
    };

    pub const signal_driver_down = struct {
        pub const is_critical = false;
        pub const cpu_id = CpuId.core;
    };
};

pub const Operation = blk: {
    var spec = @typeInfo(std.meta.DeclEnum(operations));
    spec.Enum.tag_type = u32;
    spec.Enum.is_exhaustive = false;
    break :blk @Type(spec);
};

const CommonHeader = extern struct {
    const Flags = packed struct(u32) { ack: bool = false, _: u31 = 0 };

    version: u32 = protocol_version,
    flags: Flags = .{},
    sequence: u32,
    opcode: Operation,
};

comptime {
    std.debug.assert(@sizeOf(CommonHeader) == 16);
}

const RequestHeader = extern struct {
    common: CommonHeader,
    parameter_count: u32,
};

comptime {
    std.debug.assert(@sizeOf(RequestHeader) == 20);
}

const ResponseHeader = extern struct {
    const Status = extern struct {
        major: firmware.Status,
        minor: firmware.Status,
    };

    common: CommonHeader,
    status: Status,
    parameter_count: u32,
};

comptime {
    std.debug.assert(@sizeOf(ResponseHeader) == 28);
}

fn convertPtrEndian(comptime target: std.builtin.Endian, ptr: anytype) void {
    if (native_endian == target) {
        return;
    }

    const ptrinfo = @typeInfo(@TypeOf(ptr));
    std.debug.assert(ptrinfo == .Pointer);
    std.debug.assert(!ptrinfo.Pointer.is_const);
    std.debug.assert(ptrinfo.Pointer.size == .One);

    switch (@typeInfo(ptrinfo.Pointer.child)) {
        .Float => {},
        .Int => {
            ptr.* = @byteSwap(ptr.*);
        },
        .Enum => |enum_info| {
            comptime var ptrspec = ptrinfo;
            ptrspec.Pointer.child = enum_info.tag_type;
            convertPtrEndian(target, @as(@Type(ptrspec), @ptrCast(ptr)));
        },
        .Struct => |struct_info| {
            if (struct_info.layout == .@"packed") {
                comptime var ptrspec = ptrinfo;
                ptrspec.Pointer.child = struct_info.backing_integer.?;
                convertPtrEndian(target, @as(@Type(ptrspec), @ptrCast(ptr)));
                return;
            }

            inline for (struct_info.fields) |field| {
                if (@sizeOf(field.type) == 1) {
                    continue;
                }

                convertPtrEndian(target, &@field(ptr, field.name));
            }
        },
        .Array => |array_info| {
            if (@sizeOf(array_info.child) == 1) {
                return;
            }

            inline for (ptr.*) |*elem| {
                convertPtrEndian(target, elem);
            }
        },
        else => |info| std.debug.panic("endian conversion for {s} is not implemented", .{@tagName(info)}),
    }
}

fn defaultParseResponse(comptime T: type, response_bytes: []const u8) T {
    var response: T = undefined;

    comptime var offset: usize = 0;
    inline for (@typeInfo(T).Struct.fields) |field| {
        const param_len = std.mem.bigToNative(u32, std.mem.bytesToValue(u32, response_bytes[offset .. offset + 4]));
        if (param_len != @sizeOf(field.type)) {
            std.debug.panic("parameter size is {d} but size of {s}.{s} ({}) is {d}\n", .{ param_len, @typeName(T), field.name, field.type, @sizeOf(field.type) });
        }

        offset += 4;

        @field(response, field.name) = std.mem.bytesToValue(field.type, response_bytes[offset .. offset + param_len]);

        offset += @sizeOf(field.type);
    }

    return response;
}

pub fn OperationRequest(comptime op: Operation) type {
    return @field(operations, @tagName(op)).Request;
}

pub fn OperationResponse(comptime op: Operation) type {
    return @field(operations, @tagName(op)).Response;
}

pub const Options = struct {
    log_response_error: bool = true,
};

pub fn control(
    comptime ioctl_protocol_version: ioctl.ProtocolVersion,
    device: std.fs.File,
    comptime op: Operation,
    request: OperationRequest(op),
    sequence: u32,
    options: Options,
) !OperationResponse(op) {
    const Request = OperationRequest(op);
    const Response = OperationResponse(op);

    var request_buf: [ioctl.ops.max_control_length]u8 = undefined;
    const request_header = std.mem.bytesAsValue(RequestHeader, request_buf[0..].ptr);
    request_header.* = .{
        .common = .{
            .version = 2,
            .sequence = sequence,
            .opcode = op,
        },
        .parameter_count = @typeInfo(Request).Struct.fields.len,
    };

    std.log.debug("control request header: {any}", .{request_header});

    convertPtrEndian(.big, request_header);

    comptime var request_offset = @sizeOf(RequestHeader);

    inline for (@typeInfo(Request).Struct.fields) |field| {
        std.mem.bytesAsValue(u32, request_buf[request_offset..]).* = std.mem.nativeToBig(u32, @sizeOf(field.type));
        request_offset += 4;

        const ptr = std.mem.bytesAsValue(field.type, request_buf[request_offset .. request_offset + @sizeOf(field.type)]);
        ptr.* = @field(request, field.name);
        convertPtrEndian(.big, ptr);
        // switch (@typeInfo(field.type)) {
        //     .Int => {
        //         ptr.* = std.mem.nativeToBig(field.type, @field(request, field.name));
        //     },
        //     .Enum => {
        //         @as(*@typeInfo(field.type).Enum.tag_type, @alignCast(@ptrCast(ptr))).* = std.mem.nativeToBig(
        //             @typeInfo(field.type).Enum.tag_type,
        //             @intFromEnum(@field(request, field.name)),
        //         );
        //     },
        //     .Struct, .Array => {
        //         ptr.* = @field(request, field.name);
        //         if (native_endian != .big) {
        //             std.mem.byteSwapAllFields(field.type, ptr);
        //         }
        //     },
        //     else => unreachable,
        // }

        request_offset += @sizeOf(field.type);
    }

    std.log.debug("sending control request bytes: {any}", .{request_buf[0..request_offset]});

    var response_buf: [ioctl.ops.max_control_length]u8 = undefined;
    const response_bytes = try send(ioctl_protocol_version, device, request_buf[0..request_offset], &response_buf, 50000, @field(operations, @tagName(op)).cpu_id);

    std.log.debug("received control response bytes: {any}", .{response_bytes});

    const response_header = std.mem.bytesAsValue(ResponseHeader, &response_buf);
    convertPtrEndian(.big, response_header);

    std.log.debug("control response header: {any}", .{response_header});

    std.debug.assert(response_header.common.version == protocol_version);
    std.debug.assert(response_header.common.flags.ack);
    std.debug.assert(response_header.common.opcode == op);

    if (response_header.status.major != .SUCCESS) {
        if (options.log_response_error) {
            std.log.err("Firmware control has failed. Major status: 0x{x} {s}, Minor status: 0x{x} {s}", .{ @intFromEnum(response_header.status.major), @tagName(response_header.status.major), @intFromEnum(response_header.status.minor), @tagName(response_header.status.minor) });
        }

        return error.FirmwareResponseError;
    }

    if (response_header.parameter_count != @typeInfo(Response).Struct.fields.len) {
        std.debug.panic("response parameter count is {d} but expected {d}\n", .{ response_header.parameter_count, @typeInfo(Response).Struct.fields.len });
    }

    if (@hasDecl(Response, "parse")) {
        return Response.parse(response_bytes[@sizeOf(ResponseHeader)..]);
    }

    var response = defaultParseResponse(Response, response_bytes[@sizeOf(ResponseHeader)..]);

    convertPtrEndian(.big, &response);

    return response;
}

fn send(comptime ioctl_protocol_version: ioctl.ProtocolVersion, device: std.fs.File, request_bytes: []const u8, response_buf: []u8, timeout_ms: u32, cpu_id: CpuId) ![]const u8 {
    std.debug.assert(request_bytes.len <= ioctl.ops.max_control_length);

    // NOTE: libhailort has a check here to ensure that "critical" ops only work on the same major and minor version
    //       https://github.com/hailo-ai/hailort/blob/e2190aeda847ab22057d162d08b516c39ac36ab8/hailort/libhailort/src/device_common/device.cpp#L480

    var data: ioctl.ops.FirmwareControl.Payload = .{
        .expected_md5 = undefined,
        .buffer_len = @intCast(request_bytes.len),
        .buffer = undefined,
        .timeout_ms = timeout_ms,
        .cpu_id = cpu_id,
    };

    std.crypto.hash.Md5.hash(request_bytes, &data.expected_md5, .{});
    @memcpy(data.buffer[0..request_bytes.len], request_bytes);

    try ioctl.run(ioctl_protocol_version, device, .fw_control, &data);

    if (response_buf.len < data.buffer_len) {
        return error.NoMoreSpace;
    }

    const response_bytes = response_buf[0..data.buffer_len];
    @memcpy(response_bytes, data.buffer[0..data.buffer_len]);

    var response_md5: [16]u8 = undefined;
    std.crypto.hash.Md5.hash(response_bytes, &response_md5, .{});
    std.debug.assert(std.mem.eql(u8, &response_md5, &data.expected_md5));

    return response_buf[0..data.buffer_len];
}
