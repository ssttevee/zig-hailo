/// enum hailo_dma_data_direction
pub const DMADataDirection = enum(c_int) {
    bidirectional,
    to_device,
    from_device,
    none,
};

/// enum hailo_vdma_interrupts_domain
pub const VDMAInterruptsDomain = enum(c_int) {
    none,
    device = 1 << 0,
    host = 1 << 1,
};

/// enum hailo_cpu_id
pub const CpuId = enum(u32) {
    app,
    core,
};
