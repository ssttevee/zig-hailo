const std = @import("std");
const testing = std.testing;

const root = @import("root.zig");

pub const max_memory_transfer_length = 4096;
pub const max_control_length = 1500;
pub const max_notification_length = 1500;
pub const max_fw_log_buffer_length = 512;
pub const max_vdma_engines = 3;
pub const max_vdma_channels_per_engine = 32;
pub const vdma_max_ongoing_transfers = 128;
pub const channel_irq_timestamps_size = vdma_max_ongoing_transfers * 2;
pub const max_buffers_per_single_transfer = 2;

pub const CpuId = enum(u32) {
    app,
    core,
};

/// magic number https://github.com/hailo-ai/hailort/blob/e2190aeda847ab22057d162d08b516c39ac36ab8/hailort/drivers/common/hailo_ioctl_common.h#L117
const OperationType = enum(u8) {
    general = 'g',
    vdma = 'v',
    non_linux = 'w',
};

pub const operations = struct {
    pub const general = struct {
        pub const memory_transfer = struct {
            pub const read = true;
            pub const write = true;
            pub const Payload = extern struct {
                pub const TransferDirection = enum(u32) {
                    read,
                    write,
                };

                pub const TransferMemoryType = enum(u32) {
                    direct = 0,

                    vdma0 = 0x100,
                    vdma1 = 0x101,
                    vdma2 = 0x102,

                    pcie_bar0 = 0x200,
                    pcie_bar2 = 0x202,
                    pcie_bar4 = 0x204,

                    dma_engine0 = 0x300,
                    dma_engine1 = 0x301,
                    dma_engine2 = 0x303,
                };

                transfer_direction: TransferDirection, // in
                memory_type: TransferMemoryType, // in
                address: u64, // in
                count: usize, // in
                buffer: [max_memory_transfer_length]u8, // in/out
            };
        };

        pub const fw_control = struct {
            pub const read = true;
            pub const write = true;
            pub const Payload = extern struct {
                expected_md5: [16]u8,
                buffer_len: u32,
                buffer: [max_control_length]u8,
                timeout_ms: u32,
                cpu_id: CpuId,
            };
        };

        pub const read_notification = struct {
            pub const read = false;
            pub const write = true;
            pub const Payload = extern struct {
                buffer_len: usize,
                buffer: [max_notification_length]u8,
            };
        };

        pub const disable_notification = struct {
            pub const read = false;
            pub const write = false;
            pub const Payload = void;
        };

        pub const query_device_properties = struct {
            pub const read = false;
            pub const write = true;
            pub const Payload = packed struct { // this must be 23 bytes long
                pub const BoardType = enum(u32) {
                    hailo8,
                    hailo15,
                    pluto,
                };

                pub const AllocationMode = enum(u32) {
                    userspace,
                    driver,
                };

                pub const DMAType = enum(u32) {
                    pcie,
                    dram,
                };

                desc_max_page_size: u16,
                board_type: BoardType,
                allocation_mode: AllocationMode,
                dma_type: DMAType,
                dma_engines_count: u64,
                is_fw_loaded: u8,

                // #ifdef __QNX__
                // resource_manager_pid: pid_t,
                // #endif // __QNX__

                comptime {
                    if (@bitSizeOf(@This()) / 8 != 23) {
                        @compileError(std.fmt.comptimePrint("expected @bitSizeOf({s})/8 to be size 23, but it is actually {d}", .{ @typeName(@This()), @bitSizeOf(@This()) / 8 }));
                    }
                }
            };
        };

        pub const query_driver_info = struct {
            pub const read = false;
            pub const write = true;
            pub const Payload = root.Version;
        };

        pub const read_log = struct {
            pub const read = true;
            pub const write = true;
            pub const Payload = extern struct {
                cpu_id: CpuId, // in
                buffer: [max_fw_log_buffer_length]u8, // out
                buffer_size: usize, // in
                read_bytes: usize, // out
            };
        };

        pub const reset_nn_core = struct {
            pub const read = false;
            pub const write = false;
            pub const Payload = void;
        };
    };

    pub const vdma = struct {
        pub const interrupts_enable = struct {
            pub const read = true;
            pub const write = false;
            pub const Payload = extern struct {
                channels_bitmap_per_engine: [max_vdma_engines]u32, // in
                enable_timestamps_measure: bool, // in
            };
        };

        pub const interrupts_disable = struct {
            pub const read = true;
            pub const write = false;
            pub const Payload = extern struct {
                channels_bitmap_per_engine: [max_vdma_engines]u32,
            };
        };

        pub const interrupts_wait = struct {
            pub const read = true;
            pub const write = true;
            pub const Payload = extern struct {
                pub const VDMAInterruptsChannelData = extern struct {
                    engine_index: u8,
                    channel_index: u8,
                    /// If not activate, num_processed is ignored.
                    is_active: bool,
                    host_num_processed: u16,
                    /// Channel errors bits on source side
                    host_error: u8,
                    /// Channel errors bits on dest side
                    device_error: u8,
                    /// If the validation of the channel was successful
                    validation_success: bool,
                };

                channels_bitmap_per_engine: [max_vdma_engines]u32, // in
                channels_count: u8, // out
                irq_data: [max_vdma_channels_per_engine * max_vdma_engines]VDMAInterruptsChannelData, // out
            };
        };

        pub const interrupts_read_timestamps = struct {
            pub const read = true;
            pub const write = true;
            pub const Payload = extern struct {
                pub const ChannelInterruptTimestamp = extern struct {
                    timestamp_ns: u64,
                    desc_num_processed: u16,
                };

                engine_index: u8, // in
                channel_index: u8, // in
                timestamps_count: u32, // out
                timestamps: [channel_irq_timestamps_size]ChannelInterruptTimestamp, // out
            };
        };

        pub const buffer_map = struct {
            pub const read = true;
            pub const write = true;
            pub const Payload = extern struct {
                pub const DMADataDirection = enum(c_int) {
                    bidirectional,
                    to_device,
                    from_device,
                    none,
                };

                user_address: *anyopaque, // in
                size: usize, // in
                data_direction: DMADataDirection, // in
                allocated_buffer_handle: usize, // in
                mapped_handle: usize, // out
            };
        };

        pub const buffer_unmap = struct {
            pub const read = true;
            pub const write = false;
            pub const Payload = extern struct {
                mapped_handle: usize,
            };
        };

        pub const buffer_sync = struct {
            pub const read = true;
            pub const write = false;
            pub const Payload = extern struct {
                pub const VDMABufferSyncType = enum(c_int) {
                    for_cpu,
                    for_device,
                };

                handle: usize, // in
                sync_type: VDMABufferSyncType, // in
                offset: usize, // in
                count: usize, // in
            };
        };

        pub const desc_list_create = struct {
            pub const read = true;
            pub const write = true;
            pub const Payload = extern struct {
                desc_count: usize, // in
                desc_page_size: u16, // in
                is_circular: bool, // in
                desc_handle: usize, // out
                dma_address: u64, // out
            };
        };

        pub const desc_list_release = struct {
            pub const read = true;
            pub const write = false;
            pub const Payload = extern struct {
                desc_handle: usize,
            };
        };

        pub const desc_list_bind_vdma_buffer = struct {
            pub const read = true;
            pub const write = false;
            pub const Payload = extern struct {
                buffer_handle: usize, // in
                buffer_size: usize, // in
                buffer_offset: usize, // in
                desc_handle: usize, // in
                channel_index: u8, // in
                starting_desc: u32, // in
            };
        };

        pub const low_memory_buffer_alloc = struct {
            pub const read = true;
            pub const write = true;
            pub const Payload = extern struct {
                buffer_size: usize, // in
                buffer_handle: usize, // out
            };
        };

        pub const low_memory_buffer_free = struct {
            pub const read = true;
            pub const write = false;
            pub const Payload = extern struct {
                buffer_handle: usize,
            };
        };

        pub const mark_as_in_use = struct {
            pub const read = false;
            pub const write = true;
            pub const Payload = extern struct {
                in_use: bool,
            };
        };

        pub const continuous_buffer_alloc = struct {
            pub const read = true;
            pub const write = true;
            pub const Payload = extern struct {
                buffer_size: usize, // in
                buffer_handle: usize, // out
                dma_address: u64, // out
            };
        };

        pub const continuous_buffer_free = struct {
            pub const read = true;
            pub const write = false;
            pub const Payload = extern struct {
                buffer_handle: usize,
            };
        };

        pub const launch_transfer = struct {
            pub const read = true;
            pub const write = true;
            pub const Payload = extern struct {
                pub const VDMATransferBuffer = extern struct {
                    mapped_buffer_handle: usize,
                    offset: u32,
                    size: u32,
                };

                pub const VDMAInterruptsDomain = enum(c_int) {
                    none,
                    device = 1 << 0,
                    host = 1 << 1,
                };

                engine_index: u8, // in
                channel_index: u8, // in

                desc_handle: usize, // in
                starting_desc: u32, // in

                /// if false, assumes buffer already bound
                should_bind: bool, // in
                buffers_count: u8, // in
                buffers: [max_buffers_per_single_transfer]VDMATransferBuffer, // in

                first_interrupts_domain: VDMAInterruptsDomain, // in
                last_interrupts_domain: VDMAInterruptsDomain, // in

                /// if set, program hw to send more info (e.g desc complete status)
                is_debug: bool, // in

                /// amount of descriptors programed
                descs_programed: u32, // out
            };
        };
    };

    pub const non_linux = struct {
        pub const non_linux_desc_list_mmap = struct {
            pub const read = true;
            pub const write = true;
            pub const Payload = extern struct {
                desc_handle: usize, // in
                size: usize, // in
                user_address: *anyopaque, // out
            };
        };
    };
};

const Request = std.os.linux.IOCTL.Request;

// const OpCodeBits = packed struct(u32) {
//     size: u16,
//     code: u8,
//     type: OperationType,
//     read: bool,
//     write: bool,
// };

pub const Code = blk: {
    var count: usize = 0;
    for (@typeInfo(OperationType).Enum.fields) |field| {
        count += @typeInfo(@field(operations, field.name)).Struct.decls.len;
    }

    var enum_fields: [count]std.builtin.Type.EnumField = undefined;
    var current_field: usize = 0;
    for (@typeInfo(OperationType).Enum.fields) |operation_type| {
        const operation_group = @field(operations, operation_type.name);
        for (@typeInfo(operation_group).Struct.decls, 0..) |decl, code| {
            const operation = @field(operation_group, decl.name);
            enum_fields[current_field] = .{
                .name = decl.name,
                // .value = blk2: {
                //     if (operation.read and operation.write) {
                //         break :blk2 std.os.linux.IOCTL.IOWR(@intFromEnum(@field(OperationType, operation_type.name)), code, operation.Payload);
                //     }

                //     if (operation.read) {
                //         break :blk2 std.os.linux.IOCTL.IOR(@intFromEnum(@field(OperationType, operation_type.name)), code, operation.Payload);
                //     }

                //     if (operation.write) {
                //         break :blk2 std.os.linux.IOCTL.IOW(@intFromEnum(@field(OperationType, operation_type.name)), code, operation.Payload);
                //     }

                //     break :blk2 std.os.linux.IOCTL.IO(@intFromEnum(@field(OperationType, operation_type.name)), code);
                // },

                .value = @as(u32, @bitCast(std.os.linux.IOCTL.Request{
                    .nr = code,
                    .io_type = @intFromEnum(@field(OperationType, operation_type.name)),
                    .size = @bitSizeOf(operation.Payload) / 8,
                    .dir = (@intFromBool(operation.write)) | (@as(u2, @intFromBool(operation.read)) << 1),
                })),

                // .value = @as(u32, @bitCast(OpCodeBits{
                //     .size = @sizeOf(operation.Payload),
                //     .code = code,
                //     .type = @field(OperationType, operation_type.name),
                //     .read = operation.read,
                //     .write = operation.write,
                // })),
            };

            current_field += 1;
        }
    }

    std.debug.assert(current_field == count);

    break :blk @Type(.{
        .Enum = .{
            .tag_type = u32,
            .fields = &enum_fields,
            .decls = &.{},
            .is_exhaustive = true,
        },
    });
};

pub fn PayloadType(comptime code: Code) type {
    // @compileLog(code, @as(std.os.linux.IOCTL.Request, @bitCast(@intFromEnum(code))));
    return @field(@field(operations, @tagName(@as(OperationType, @enumFromInt(@as(std.os.linux.IOCTL.Request, @bitCast(@intFromEnum(code))).io_type)))), @tagName(code)).Payload;
}

pub fn run(device: std.fs.File, comptime code: Code, data: *PayloadType(code)) !void {
    // std.log.debug("running ioctl: {s} 0x{x} {any}", .{ @tagName(code), @intFromEnum(code), @as(std.os.linux.IOCTL.Request, @bitCast(@intFromEnum(code))) });

    // std.os.windows.DeviceIoControl(device.handle);
    // const result = std.posix.errno(std.c.ioctl(device.handle, @bitCast(@intFromEnum(code)), @intFromPtr(data)));

    const result = std.posix.errno(std.posix.system.ioctl(device.handle, @intFromEnum(code), @intFromPtr(data)));
    if (result != .SUCCESS) {
        std.debug.print("errno? {d} {s}\n", .{ @intFromEnum(result), @tagName(result) });
        return std.posix.unexpectedErrno(result);
    }
}
