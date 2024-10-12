const std = @import("std");
const root = @import("../root.zig");

const ops = @import("operations.zig");

pub const version = "4.18";

pub const general = struct {
    /// https://github.com/hailo-ai/hailort/blob/01e4c7f5a7463cc61ef1b2d22c31dd80a3a07d95/hailort/drivers/common/hailo_ioctl_common.h#L137
    pub const magic = 'g';

    pub const memory_transfer = ops.MemoryTransfer;

    pub const query_device_properties = ops.QueryDeviceProperties;

    pub const query_driver_info = ops.QueryDriverInfo;
};

pub const vdma = struct {
    /// https://github.com/hailo-ai/hailort/blob/01e4c7f5a7463cc61ef1b2d22c31dd80a3a07d95/hailort/drivers/common/hailo_ioctl_common.h#L138
    pub const magic = 'v';

    pub const enable_channels = ops.EnableVDMAInterruptChannels;

    pub const disable_channels = ops.DisableNotification;

    pub const interrupts_wait = ops.WaitVDMAInterrupts;

    pub const interrupts_read_timestamps = ops.ReadVDMAInterruptTimestamps;

    pub const buffer_map = ops.MapVDMABuffer;

    pub const buffer_unmap = ops.UnmapVDMABuffer;

    pub const buffer_sync = ops.SyncVDMABuffer;

    pub const desc_list_create = ops.CreateVDMADescriptionList;

    pub const desc_list_release = ops.ReleaseVDMADescriptionList;

    pub const desc_list_program_buffer = ops.ProgramVDMADescriptionList;

    pub const low_memory_buffer_alloc = ops.AllocateLowMemoryBuffer;

    pub const low_memory_buffer_free = ops.FreeLowMemoryBuffer;

    pub const mark_as_in_use = ops.MarkAsInUse;

    pub const continuous_buffer_alloc = ops.AllocateContinuousBuffer;

    pub const continuous_buffer_free = ops.FreeContinuousBuffer;

    pub const launch_transfer = ops.LaunchVDMATransfer;
};

pub const soc = struct {
    /// https://github.com/hailo-ai/hailort/blob/01e4c7f5a7463cc61ef1b2d22c31dd80a3a07d95/hailort/drivers/common/hailo_ioctl_common.h#L139
    pub const magic = 's';

    pub const soc_connect = struct {
        pub const read = true;
        pub const write = true;
        pub const Payload = ops.ConnectSOC;
    };

    pub const soc_close = struct {
        pub const read = true;
        pub const write = false;
        pub const Payload = ops.CloseSOC;
    };
};

pub const nnc = struct {
    /// https://github.com/hailo-ai/hailort/blob/01e4c7f5a7463cc61ef1b2d22c31dd80a3a07d95/hailort/drivers/common/hailo_ioctl_common.h#L140
    pub const magic = 'n';

    pub const fw_control = ops.FirmwareControl;

    pub const read_notification = ops.ReadNotification;

    pub const disable_notification = ops.DisableNotification;

    pub const read_log = ops.ReadLog;

    pub const reset_nn_core = ops.ResetNNCore;
};

pub const pci_ep = struct {
    /// https://github.com/hailo-ai/hailort/blob/01e4c7f5a7463cc61ef1b2d22c31dd80a3a07d95/hailort/drivers/common/hailo_ioctl_common.h#L141
    pub const magic = 'p';

    pub const pci_ep_accept = struct {
        pub const read = true;
        pub const write = true;
        pub const Payload = ops.AcceptPCIEP;
    };

    pub const pci_ep_close = struct {
        pub const read = true;
        pub const write = false;
        pub const Payload = ops.ClosePCIEP;
    };
};
