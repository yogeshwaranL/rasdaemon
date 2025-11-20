# RAS Daemon Tracing Guide

This document describes how to trace rasdaemon function calls using ftrace's trace_marker interface for unified kernel/userspace tracing.

## Overview

Rasdaemon uses ftrace's `trace_marker` to write userspace function entry/exit markers into the kernel's trace buffer. This provides:

- **Unified timeline** - kernel and userspace events in one trace
- **Hardware timestamps** - high-precision timing from kernel
- **Standard tools** - works with trace-cmd, perf, kernelshark
- **Zero overhead when disabled** - no trace output if debugfs not mounted

## Quick Start

### 1. Mount debugfs (if not mounted)

```bash
mount -t debugfs none /sys/kernel/debug
```

### 2. Enable tracing

```bash
# Clear trace buffer
echo > /sys/kernel/debug/tracing/trace

# Enable RAS kernel events
echo 1 > /sys/kernel/debug/tracing/events/ras/enable
echo 1 > /sys/kernel/debug/tracing/events/mce/enable

# Start rasdaemon
rasdaemon -f
```

### 3. View trace

```bash
cat /sys/kernel/debug/tracing/trace
```

## Using trace-cmd (Recommended)

trace-cmd is the easiest way to capture and analyze traces:

```bash
# Record all RAS events plus rasdaemon markers
trace-cmd record -e ras:* -e mce:* &

# Run rasdaemon
rasdaemon -f

# Stop recording (Ctrl+C on trace-cmd)
# View the trace
trace-cmd report

# Or save to file
trace-cmd report > trace_output.txt
```

### Filtering

```bash
# Only MC events
trace-cmd record -e ras:mc_event

# Only MCE events
trace-cmd record -e mce:mce_record

# Multiple event types
trace-cmd record -e ras:mc_event -e ras:aer_event -e mce:*
```

## Trace Output Format

The trace shows both kernel events and rasdaemon function markers:

```
# Kernel event
rasdaemon-1234 [001] 1234.567890: mc_event: 1 Corrected error: ...

# Rasdaemon function entry
rasdaemon-1234 [001] 1234.567891: tracing_mark_write: ras_mc_event_handler: entry

# Rasdaemon function exit
rasdaemon-1234 [001] 1234.567900: tracing_mark_write: ras_mc_event_handler: exit ret=0
```

## Available Trace Events

### Kernel RAS Events (ras:*)

- `mc_event` - Memory controller errors
- `aer_event` - PCIe AER errors
- `arm_event` - ARM processor errors
- `non_standard_event` - Vendor-specific errors
- `extlog_mem_event` - Extended machine check logging
- `memory_failure_event` - Memory page failures

### Kernel MCE Events (mce:*)

- `mce_record` - Machine check exceptions

### Kernel CXL Events (cxl:*)

- `cxl_poison` - CXL poison events
- `cxl_aer_uncorrectable_error` - CXL AER UE
- `cxl_aer_correctable_error` - CXL AER CE
- `cxl_overflow` - CXL log overflow
- `cxl_generic_event` - Generic CXL events
- `cxl_general_media` - General media errors
- `cxl_dram` - DRAM errors
- `cxl_memory_module` - Memory module events

### Rasdaemon Function Markers

All rasdaemon functions write entry/exit markers:

```
function_name: entry
function_name: exit ret=N
```

## Advanced Usage

### Function Graph Tracer

For call graph visualization:

```bash
echo function_graph > /sys/kernel/debug/tracing/current_tracer
echo 1 > /sys/kernel/debug/tracing/events/ras/enable
cat /sys/kernel/debug/tracing/trace
```

### Filtering by Function

```bash
# Only trace specific functions
echo 'ras_mc_event_handler' > /sys/kernel/debug/tracing/set_ftrace_filter
echo function > /sys/kernel/debug/tracing/current_tracer
```

### Measuring Latency

```bash
# Use function_graph with timing
echo function_graph > /sys/kernel/debug/tracing/current_tracer
echo funcgraph-duration > /sys/kernel/debug/tracing/trace_options
```

### Using KernelShark

For GUI visualization:

```bash
trace-cmd record -e ras:* -e mce:*
kernelshark trace.dat
```

## Rasdaemon Traced Functions

Every function in rasdaemon is instrumented. Key functions include:

### Event Handlers
- `ras_mc_event_handler` - Memory controller errors
- `ras_mce_event_handler` - Machine check exceptions
- `ras_aer_event_handler` - PCIe AER errors
- `ras_arm_event_handler` - ARM processor errors
- `ras_cxl_*_event_handler` - CXL errors (9 handlers)
- `ras_extlog_mem_event_handler` - Extended logging
- `ras_non_standard_event_handler` - Vendor errors
- `ras_devlink_event_handler` - Network device errors
- `ras_diskerror_event_handler` - Disk errors
- `ras_memory_failure_event_handler` - Memory failures
- `ras_signal_event_handler` - Signal errors

### Infrastructure
- `handle_ras_events` - Main event loop
- `add_event_handler` - Register handlers
- `read_ras_event_all_cpus` - Read trace events
- `parse_ras_data` - Parse trace data

### Database
- `ras_mc_event_opendb` - Open database
- `ras_store_*_event` - Store events (one per type)

### CPU Decoders
- `detect_cpu` - CPU detection
- `parse_intel_event` - Intel MCE decoding
- `parse_amd_k8_event` - AMD K8 decoding
- `parse_amd_smca_event` - AMD SMCA decoding

### Triggers
- `run_trigger` - Execute external triggers
- `mc_event_trigger_setup` - Setup MC triggers

## Example: Tracing a Memory Error

```bash
# Terminal 1: Start tracing
trace-cmd record -e ras:mc_event &

# Terminal 2: Start rasdaemon
rasdaemon -f

# Terminal 3: Inject test error (requires EDAC fake_inject)
echo 1 > /sys/devices/system/edac/mc/mc0/fake_inject

# Back to Terminal 1: Stop and view
# Press Ctrl+C
trace-cmd report
```

Expected output:
```
rasdaemon-1234 [001] 1234.567890: mc_event: 1 Corrected error...
rasdaemon-1234 [001] 1234.567891: tracing_mark_write: ras_mc_event_handler: entry
rasdaemon-1234 [001] 1234.567892: tracing_mark_write: ras_store_mc_event: entry
rasdaemon-1234 [001] 1234.567895: tracing_mark_write: ras_store_mc_event: exit ret=0
rasdaemon-1234 [001] 1234.567896: tracing_mark_write: ras_mc_event_stat: entry
rasdaemon-1234 [001] 1234.567897: tracing_mark_write: ras_mc_event_stat: exit ret=0
rasdaemon-1234 [001] 1234.567900: tracing_mark_write: ras_mc_event_handler: exit ret=0
```

## Troubleshooting

### No trace output

1. Verify debugfs is mounted:
   ```bash
   mount | grep debugfs
   ```

2. Check rasdaemon is running:
   ```bash
   ps aux | grep rasdaemon
   ```

3. Verify tracing is enabled:
   ```bash
   cat /sys/kernel/debug/tracing/tracing_on
   ```

### Permission denied

Tracing requires root privileges:
```bash
sudo rasdaemon -f
```

### Buffer overflow

Increase trace buffer size:
```bash
echo 8192 > /sys/kernel/debug/tracing/buffer_size_kb
```

### Missing kernel events

Enable the required events:
```bash
echo 1 > /sys/kernel/debug/tracing/events/ras/enable
```

Check if events exist:
```bash
ls /sys/kernel/debug/tracing/events/ras/
```

## Performance Considerations

- Tracing adds minimal overhead (~1μs per marker)
- Kernel events have essentially zero overhead when disabled
- Use filtering to reduce trace volume
- Increase buffer size for long traces

## Files

- `ras-daemon-trace.h` - Tracing macros
- `ras-daemon-trace.c` - trace_marker implementation
- `docs/TRACING.md` - This documentation

## See Also

- `trace-cmd(1)` - Trace command line tool
- `kernelshark(1)` - GUI trace viewer
- `/sys/kernel/debug/tracing/README` - Kernel tracing documentation
- `Documentation/trace/ftrace.txt` - Kernel ftrace documentation
