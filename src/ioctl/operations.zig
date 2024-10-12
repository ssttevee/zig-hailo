const std = @import("std");

const common = @import("common.zig");
const root = @import("../root.zig");

pub const max_memory_transfer_length = 4096;
pub const max_control_length = 1500;
pub const max_notification_length = 1500;
pub const max_fw_log_buffer_length = 512;
pub const max_vdma_engines = 3;
pub const max_vdma_channels_per_engine = 32;
pub const vdma_max_ongoing_transfers = 128;
pub const channel_irq_timestamps_size = vdma_max_ongoing_transfers * 2;
pub const max_buffers_per_single_transfer = 2;

/// HAILO_MEMORY_TRANSFER
pub const MemoryTransfer = struct {
    pub const read = true;
    pub const write = true;
    /// struct hailo_memory_transfer_params
    pub const Payload = extern struct {
        /// enum hailo_transfer_direction
        pub const TransferDirection = enum(u32) {
            read,
            write,
        };

        /// enum hailo_transfer_memory_type
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

/// HAILO_FW_CONTROL
pub const FirmwareControl = struct {
    pub const read = true;
    pub const write = true;
    /// struct hailo_fw_control
    pub const Payload = extern struct {
        expected_md5: [std.crypto.hash.Md5.digest_length]u8,
        buffer_len: u32,
        buffer: [max_control_length]u8,
        timeout_ms: u32,
        cpu_id: common.CpuId,
    };
};

/// HAILO_READ_NOTIFICATION
pub const ReadNotification = struct {
    pub const read = false;
    pub const write = true;
    /// struct hailo_d2h_notification
    pub const Payload = extern struct {
        buffer_len: usize,
        buffer: [max_notification_length]u8,
    };
};

/// HAILO_DISABLE_NOTIFICATION
pub const DisableNotification = struct {
    pub const read = false;
    pub const write = false;
    pub const Payload = void;
};

/// HAILO_QUERY_DEVICE_PROPERTIES
pub const QueryDeviceProperties = struct {
    pub const read = false;
    pub const write = true;
    /// struct hailo_device_properties
    pub const Payload = packed struct { // this must be 23 bytes long
        /// enum hailo_board_type
        pub const BoardType = enum(u32) {
            hailo8,
            hailo15,
            pluto,
            hailo10h,
            hailo10h_legacy,
        };

        /// enum hailo_allocation_mode
        pub const AllocationMode = enum(u32) {
            userspace,
            driver,
        };

        /// enum hailo_dma_type
        pub const DMAType = enum(u32) {
            pcie,
            dram,
            pcie_ep,
        };

        desc_max_page_size: u16,
        board_type: BoardType,
        allocation_mode: AllocationMode,
        dma_type: DMAType,
        dma_engines_count: usize,
        is_fw_loaded: u8,

        // #ifdef __QNX__
        // resource_manager_pid: pid_t,
        // #endif // __QNX__

        comptime {
            if (@bitSizeOf(@This()) / 8 != 23) {
                @compileError(std.fmt.comptimePrint("expected @bitSizeOf({s})/8 to be size 23, but it is actually {d}", .{ @typeName(@This()), @bitSizeOf(@This()) / 8 }));
            }
        }

        pub fn jsonStringify(self: @This(), stream: anytype) !void {
            try stream.beginObject();
            try stream.objectField("desc_max_page_size");
            try stream.write(self.desc_max_page_size);
            try stream.objectField("board_type");
            try stream.write(self.board_type);
            try stream.objectField("allocation_mode");
            try stream.write(self.allocation_mode);
            try stream.objectField("dma_type");
            try stream.write(self.dma_type);
            try stream.objectField("dma_engines_count");
            try stream.write(self.dma_engines_count);
            try stream.objectField("is_fw_loaded");
            try stream.write(self.is_fw_loaded != 0);
            try stream.endObject();
        }
    };
};

/// HAILO_QUERY_DRIVER_INFO
pub const QueryDriverInfo = struct {
    pub const read = false;
    pub const write = true;
    /// struct hailo_driver_info
    pub const Payload = root.Version;
};

/// HAILO_READ_LOG
pub const ReadLog = struct {
    pub const read = true;
    pub const write = true;
    /// struct hailo_read_log_params
    pub const Payload = extern struct {
        cpu_id: common.CpuId, // in
        buffer: [max_fw_log_buffer_length]u8, // out
        buffer_size: usize, // in
        read_bytes: usize, // out
    };
};

/// HAILO_RESET_NN_CORE
pub const ResetNNCore = struct {
    pub const read = false;
    pub const write = false;
    pub const Payload = void;
};

/// HAILO_VDMA_ENABLE_CHANNELS
pub const EnableVDMAInterruptChannels = struct {
    pub const read = true;
    pub const write = false;
    /// version < 4.18: struct hailo_vdma_interrupts_enable_params
    ///
    /// 4.18 <= version: struct hailo_vdma_enable_channels_params
    pub const Payload = extern struct {
        channels_bitmap_per_engine: [max_vdma_engines]u32, // in
        enable_timestamps_measure: bool, // in
    };
};

/// HAILO_VDMA_DISABLE_CHANNELS
pub const DisableVDMAInterruptChannels = struct {
    pub const read = true;
    pub const write = false;
    /// version < 4.18: struct hailo_vdma_interrupts_disable_params
    ///
    /// 4.18 <= version: struct hailo_vdma_disable_channels_params
    pub const Payload = extern struct {
        channels_bitmap_per_engine: [max_vdma_engines]u32,
    };
};

/// HAILO_VDMA_INTERRUPTS_WAIT
pub const WaitVDMAInterrupts417 = struct {
    pub const read = true;
    pub const write = true;
    /// struct hailo_vdma_interrupts_wait_params
    pub const Payload = extern struct {
        /// struct hailo_vdma_interrupts_channel_data
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

/// HAILO_VDMA_INTERRUPTS_WAIT
pub const WaitVDMAInterrupts = struct {
    pub const read = true;
    pub const write = true;
    /// struct hailo_vdma_interrupts_wait_params
    pub const Payload = extern struct {
        /// struct hailo_vdma_interrupts_channel_data
        pub const VDMAInterruptsChannelData = extern struct {
            engine_index: u8,
            channel_index: u8,
            /// If not activate, num_processed is ignored.
            is_active: bool,
            /// Number of transfers completed.
            transfers_completed: u8,
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

/// HAILO_VDMA_INTERRUPTS_READ_TIMESTAMPS
pub const ReadVDMAInterruptTimestamps = struct {
    pub const read = true;
    pub const write = true;
    /// struct hailo_vdma_interrupts_read_timestamp_params
    pub const Payload = extern struct {
        /// struct hailo_channel_interrupt_timestamp
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

/// HAILO_VDMA_BUFFER_MAP
pub const MapVDMABuffer417 = struct {
    pub const read = true;
    pub const write = true;
    /// struct hailo_vdma_buffer_map_params
    pub const Payload = extern struct {
        user_address: *anyopaque, // in
        size: usize, // in
        data_direction: common.DMADataDirection, // in
        allocated_buffer_handle: usize, // in
        mapped_handle: usize, // out
    };
};

/// HAILO_VDMA_BUFFER_MAP
pub const MapVDMABuffer = struct {
    pub const read = true;
    pub const write = true;
    /// struct hailo_vdma_buffer_map_params
    pub const Payload = extern struct {
        /// enum hailo_dma_buffer_type
        pub const DMABufferType = enum(c_int) {
            user_pointer,
            dma_buffer,
        };

        user_address: *anyopaque, // in
        size: usize, // in
        data_direction: common.DMADataDirection, // in
        buffer_type: DMABufferType, // in
        allocated_buffer_handle: usize, // in
        mapped_handle: usize, // out
    };
};

/// HAILO_VDMA_BUFFER_UNMAP
pub const UnmapVDMABuffer = struct {
    pub const read = true;
    pub const write = false;
    /// struct hailo_vdma_buffer_unmap_params
    pub const Payload = extern struct {
        mapped_handle: usize,
    };
};

/// HAILO_VDMA_BUFFER_SYNC
pub const SyncVDMABuffer = struct {
    pub const read = true;
    pub const write = false;
    /// struct hailo_vdma_buffer_sync_params
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

/// HAILO_DESC_LIST_CREATE
pub const CreateVDMADescriptionList = struct {
    pub const read = true;
    pub const write = true;
    /// struct hailo_desc_list_create_params
    pub const Payload = extern struct {
        desc_count: usize, // in
        desc_page_size: u16, // in
        is_circular: bool, // in
        desc_handle: usize, // out
        dma_address: u64, // out
    };
};

/// HAILO_DESC_LIST_RELEASE
pub const ReleaseVDMADescriptionList = struct {
    pub const read = true;
    pub const write = false;
    /// struct hailo_desc_list_release_params
    pub const Payload = extern struct {
        desc_handle: usize,
    };
};

/// HAILO_DESC_LIST_BIND_VDMA_BUFFER
pub const BindVDMADescriptionListBuffer = struct {
    pub const read = true;
    pub const write = false;
    /// version < 4.18: struct hailo_desc_list_bind_vdma_buffer_params
    pub const Payload = extern struct {
        buffer_handle: usize, // in
        buffer_size: usize, // in
        buffer_offset: usize, // in
        desc_handle: usize, // in
        channel_index: u8, // in
        starting_desc: u32, // in
    };
};

/// HAILO_DESC_LIST_PROGRAM
pub const ProgramVDMADescriptionList = struct {
    pub const read = true;
    pub const write = false;
    /// version >= 4.18: struct hailo_desc_list_program_params
    pub const Payload = extern struct {
        buffer_handle: usize, // in
        buffer_size: usize, // in
        buffer_offset: usize, // in
        desc_handle: usize, // in
        channel_index: u8, // in
        starting_desc: u32, // in
        should_bind: bool, // in
        last_interrupts_domain: common.VDMAInterruptsDomain, // in
        is_debug: bool, // in
    };
};

/// HAILO_VDMA_LOW_MEMORY_BUFFER_ALLOC in hailort/drivers/common/hailo_ioctl_h
pub const AllocateLowMemoryBuffer = struct {
    pub const read = true;
    pub const write = true;
    /// struct hailo_allocate_low_memory_buffer_params
    pub const Payload = extern struct {
        buffer_size: usize, // in
        buffer_handle: usize, // out
    };
};

/// HAILO_VDMA_LOW_MEMORY_BUFFER_FREE
pub const FreeLowMemoryBuffer = struct {
    pub const read = true;
    pub const write = false;
    /// struct hailo_free_low_memory_buffer_params
    pub const Payload = extern struct {
        buffer_handle: usize,
    };
};

/// HAILO_MARK_AS_IN_USE
pub const MarkAsInUse = struct {
    pub const read = false;
    pub const write = true;

    /// struct hailo_mark_as_in_use_params
    pub const Payload = extern struct {
        in_use: bool,
    };
};

/// HAILO_VDMA_CONTINUOUS_BUFFER_ALLOC
pub const AllocateContinuousBuffer = struct {
    pub const read = true;
    pub const write = true;
    /// struct hailo_allocate_continuous_buffer_params
    pub const Payload = extern struct {
        buffer_size: usize, // in
        buffer_handle: usize, // out
        dma_address: u64, // out
    };
};

/// HAILO_VDMA_CONTINUOUS_BUFFER_FREE
pub const FreeContinuousBuffer = struct {
    pub const read = true;
    pub const write = false;
    /// struct hailo_free_continuous_buffer_params
    pub const Payload = extern struct {
        buffer_handle: usize,
    };
};

/// HAILO_VDMA_LAUNCH_TRANSFER
pub const LaunchVDMATransfer = struct {
    pub const read = true;
    pub const write = true;
    /// struct hailo_vdma_launch_transfer_params
    pub const Payload = extern struct {
        /// struct hailo_vdma_transfer_buffer
        pub const VDMATransferBuffer = extern struct {
            mapped_buffer_handle: usize,
            offset: u32,
            size: u32,
        };

        engine_index: u8, // in
        channel_index: u8, // in

        desc_handle: usize, // in
        starting_desc: u32, // in

        /// if false, assumes buffer already bound
        should_bind: bool, // in
        buffers_count: u8, // in
        buffers: [max_buffers_per_single_transfer]VDMATransferBuffer, // in

        first_interrupts_domain: common.VDMAInterruptsDomain, // in
        last_interrupts_domain: common.VDMAInterruptsDomain, // in

        /// if set, program hw to send more info (e.g desc complete status)
        is_debug: bool, // in

        /// amount of descriptors programed
        descs_programed: u32, // out

        /// status of the launch transfer call. (only used in case of error)
        launch_transfer_status: i32, // out
    };
};

/// HAILO_NON_LINUX_DESC_LIST_MMAP
pub const MMapNonLinuxDescriptionList = struct {
    pub const read = true;
    pub const write = true;
    /// struct hailo_non_linux_desc_list_mmap_params
    pub const Payload = extern struct {
        desc_handle: usize, // in
        size: usize, // in
        user_address: *anyopaque, // out
    };
};

/// HAILO_SOC_CONNECT
pub const ConnectSOC = struct {
    pub const read = true;
    pub const write = true;
    /// struct hailo_soc_connect_params
    pub const Payload = extern struct {
        input_channel_index: u8, // out
        output_channel_index: u8, // out
        input_desc_handle: *anyopaque, // in
        output_desc_handle: *anyopaque, // in
    };
};

/// HAILO_SOC_CLOSE
pub const CloseSOC = struct {
    pub const read = true;
    pub const write = false;
    /// struct hailo_soc_close_params
    pub const Payload = extern struct {
        input_channel_index: u8, // in
        output_channel_index: u8, // in
    };
};

/// HAILO_PCI_EP_ACCEPT
pub const AcceptPCIEP = struct {
    pub const read = true;
    pub const write = true;
    pub const Payload = extern struct {
        input_channel_index: u8, // out
        output_channel_index: u8, // out
        input_desc_handle: *anyopaque, // in
        output_desc_handle: *anyopaque, // in
    };
};

/// HAILO_PCI_EP_CLOSE
pub const ClosePCIEP = struct {
    pub const read = true;
    pub const write = false;
    pub const Payload = extern struct {
        input_channel_index: u8, // in
        output_channel_index: u8, // in
    };
};
