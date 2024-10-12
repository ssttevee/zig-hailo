const std = @import("std");
const root = @import("../root.zig");

const ops = @import("operations.zig");

pub const version = "4.17";

pub const general = struct {
    /// https://github.com/hailo-ai/hailort/blob/e2190aeda847ab22057d162d08b516c39ac36ab8/hailort/drivers/common/hailo_ioctl_common.h#L117
    pub const magic = 'g';

    pub const memory_transfer = ops.MemoryTransfer;

    pub const fw_control = ops.FirmwareControl;

    pub const read_notification = ops.ReadNotification;

    pub const disable_notification = ops.DisableNotification;

    pub const query_device_properties = ops.QueryDeviceProperties;

    pub const query_driver_info = ops.QueryDriverInfo;

    pub const read_log = ops.ReadLog;

    pub const reset_nn_core = ops.ResetNNCore;
};

pub const vdma = struct {
    /// https://github.com/hailo-ai/hailort/blob/e2190aeda847ab22057d162d08b516c39ac36ab8/hailort/drivers/common/hailo_ioctl_common.h#L118
    pub const magic = 'v';

    pub const interrupts_enable = ops.EnableVDMAInterruptChannels;

    pub const interrupts_disable = ops.DisableVDMAInterruptChannels;

    pub const interrupts_wait = ops.WaitVDMAInterrupts417;

    pub const interrupts_read_timestamps = ops.ReadVDMAInterruptTimestamps;

    pub const buffer_map = ops.MapVDMABuffer417;

    pub const buffer_unmap = ops.UnmapVDMABuffer;

    pub const buffer_sync = ops.SyncVDMABuffer;

    pub const desc_list_create = ops.CreateVDMADescriptionList;

    pub const desc_list_release = ops.ReleaseVDMADescriptionList;

    pub const desc_list_bind_vdma_buffer = ops.BindVDMADescriptionListBuffer;

    pub const low_memory_buffer_alloc = ops.AllocateLowMemoryBuffer;

    pub const low_memory_buffer_free = ops.FreeLowMemoryBuffer;

    pub const mark_as_in_use = ops.MarkAsInUse;

    pub const continuous_buffer_alloc = ops.AllocateContinuousBuffer;

    pub const continuous_buffer_free = ops.FreeContinuousBuffer;

    pub const launch_transfer = ops.LaunchVDMATransfer;
};

pub const non_linux = struct {
    /// https://github.com/hailo-ai/hailort/blob/e2190aeda847ab22057d162d08b516c39ac36ab8/hailort/drivers/common/hailo_ioctl_common.h#L119
    pub const magic = 'w';

    pub const non_linux_desc_list_mmap = ops.MMapNonLinuxDescriptionList;
};
