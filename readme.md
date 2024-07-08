# zig-hailo

A reimplementation of [hailort](https://github.com/hailo-ai/hailort) in Zig. The goal was to learn about the low level interface of the hailo devices and not feature parity with the official library, so reimplemented surface area may be small.

Only PCIE devices on linux are currently supported.

## hailostatus

This is a simple program that prints the status of your installed hailo devices. It is driver version independent unlike the official hailortcli tool.

### Usage

You can run the program with the zig build system:

```sh
zig build run-status
```

Or, you can build the program and run it:

```sh
zig build -Doptimize=ReleaseSafe
./zig-out/bin/hailostatus
```

The output looks like this:

```
Device: /dev/hailo0 (0000:59:00.00)
Driver Version: 4.17.1
Max Page Size: 4096
Board Type: hailo8
Allocation Mode: userspace
DMA Type: pcie
DMA Engines Count: 1
Is Firmware Loaded: false
Control Protocol Version: 2
Firmware Version: 4.17.1 (release, app, extended context switch buffer)
Logger Version: 0
Board Name: Hailo-8
Device Architecture: HAILO8
Serial Number: 0000000000000000
Part Number: 000000000000
Product Name: HAILO-8 AI ACC M.2 B+M KEY MODULE EXT TEMP
Core Clock Rate: 400000000Hz
Supported Features: ethernet           false
                    mipi               false
                    pcie               true
                    current_monitoring true
                    mdio               false
Boot Source: pcie
LCS: 3
SOC ID: 0000000000000000000000000000000000000000000000000000000000000000
Ethernet MAC Address: 00:00:00:00:00:00
ULT ID: 000000000000000000000000
PM Values: 000000000000000000000000000000000000000000000000
Partial Clusters Layout Bitmap: unknown
Measured Power: overcurrent_protection: 0.58912134W
Temperature: S0  41.05951C
             S1  41.110096C
             Avg 41.0848C
```

You can also get json output with the `-json` flag:

```sh
zig build run-status -- -json
# OR
./zig-out/bin/hailostatus -json
```

```json
[
  {
    "device": "/dev/hailo0",
    "bdf": "0000:59:00.00",
    "driver_version": "4.17.1",
    "device_properties": {
      "desc_max_page_size": 4096,
      "board_type": "hailo8",
      "allocation_mode": "userspace",
      "dma_type": "pcie",
      "dma_engines_count": 1,
      "is_fw_loaded": true
    },
    "device_identity": {
      "protocol_version": 2,
      "firmware_version": {
        "version": "4.17.1",
        "mode": "release",
        "firmware_type": "app",
        "extended_context_switch_buffer": true
      },
      "logger_version": 0,
      "board_name": "Hailo-8",
      "device_architecture": "HAILO8",
      "serial_number": "0000000000000000",
      "part_number": "000000000000",
      "product_name": "HAILO-8 AI ACC M.2 B+M KEY MODULE EXT TEMP"
    },
    "device_information": {
      "neural_network_core_clock_rate": 400000000,
      "supported_features": {
        "ethernet": false,
        "mipi": false,
        "pcie": true,
        "current_monitoring": true,
        "mdio": false
      },
      "boot_source": "pcie",
      "lcs": 3,
      "soc_id": "0000000000000000000000000000000000000000000000000000000000000000",
      "eth_mac_address": "00:00:00:00:00:00",
      "fuse_info": "000000000000000000000000",
      "pd_info": "000000000000000000000000000000000000000000000000",
      "partial_clusters_layout_bitmap": "unknown"
    },
    "power_measurements": [
      {
        "value": 0.5891213417053223,
        "dvm": "overcurrent_protection",
        "type": "power"
      }
    ],
    "chip_temperature": {
      "s0": 41.21126937866211,
      "s1": 41.26185607910156,
      "sample_count": 10459
    }
  }
]
```

## Importing into your own zig project

Run this command from your project folder

```sh
zig fetch --save https://github.com/ssttevee/zig-hailo/archive/refs/heads/trunk.tar.gz
```

Then add this snippet to your build.zig file

```zig
const adb = b.dependency("hailo", .{
    .optimize = optimize,
    .target = target,
});

exe.root_module.addImport("hailo", adb.module("hailo"));
```
