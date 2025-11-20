# RAS Daemon Error Injection Tests

**WARNING**: These tests inject REAL hardware errors. Only run in isolated test environments!

## What These Tests Do

- Inject actual errors via EINJ, mce-inject, aer-inject
- Verify rasdaemon handler invocation (via trace_marker)
- Check database event storage
- Test end-to-end error processing

## Requirements

- **Root privileges** (required)
- Kernel with APEI EINJ support
- rasdaemon running with tracing enabled
- Optional: `mce-inject` package
- Optional: `aer-inject` tool

### Check Requirements

```bash
# EINJ support
ls /sys/kernel/debug/apei/einj/
# If missing: modprobe einj

# mce-inject
which mce-inject
# If missing: apt install mce-inject

# aer-inject
ls /sys/kernel/debug/aer_inject/
```

## Running Tests

```bash
# Run all injection tests (will prompt for confirmation)
sudo bash tests/injection/run_injection_tests.sh

# Skip confirmation prompts
sudo FORCE_INJECT=1 bash tests/injection/run_injection_tests.sh

# Include uncorrectable error tests (DANGEROUS!)
sudo TEST_UCE=1 bash tests/injection/run_injection_tests.sh

# Run individual injection suites
sudo bash tests/injection/inject_memory_errors.sh
sudo bash tests/injection/inject_mce_errors.sh
sudo bash tests/injection/inject_pcie_errors.sh
```

## Injection Methods

| Error Type | Method | Requirements |
|------------|--------|--------------|
| Memory CE | APEI EINJ | `modprobe einj` |
| Memory CE | EDAC fake_inject | EDAC driver support |
| Memory UCE | APEI EINJ | Platform support |
| MCE | mce-inject | `mce-inject` package |
| PCIe AER CE | EINJ / aer-inject | PCIe device with AER |
| PCIe AER UCE | EINJ | Platform support |

## Test Output

```
==========================================
Memory Error Injection Tests
==========================================

Test: EINJ Memory Correctable Error
-----------------------------------
Injecting Memory Correctable (type 0x8)...
[PASS] EINJ Memory CE - trace event
[PASS] EINJ Memory CE - handler called
[PASS] EINJ Memory CE - database

==========================================
Error Injection Test Summary
==========================================
Tests run:     5
Tests passed:  4
Tests skipped: 1
```

## Results Location

- Test results: `/tmp/rasdaemon_injection_tests/`
- Trace files: `/tmp/rasdaemon_injection_tests/*_trace.txt`
- Report: `/tmp/rasdaemon_injection_tests/injection_report_YYYYMMDD_HHMMSS.txt`

## Test Files

| File | Description |
|------|-------------|
| `inject_framework.sh` | Common framework, safety checks |
| `inject_memory_errors.sh` | EINJ and EDAC memory errors |
| `inject_mce_errors.sh` | MCE via mce-inject tool |
| `inject_pcie_errors.sh` | PCIe AER error injection |
| `run_injection_tests.sh` | Main test runner |

## Recommended Workflow

### 1. Start Tracing

```bash
# Terminal 1
trace-cmd record -e ras:* -e mce:*
```

### 2. Start rasdaemon

```bash
# Terminal 2
sudo rasdaemon -f
```

### 3. Run Injection Tests

```bash
# Terminal 3
sudo FORCE_INJECT=1 bash tests/injection/run_injection_tests.sh
```

### 4. Analyze Results

```bash
# Stop trace-cmd (Ctrl+C in Terminal 1)
trace-cmd report

# View captured traces
cat /tmp/rasdaemon_injection_tests/einj_mem_ce_trace.txt
```

## Adding New Injection Tests

```bash
#!/bin/bash
source "$(dirname "$0")/inject_framework.sh"

init_injection_tests

test_inject_something() {
    echo ""
    echo "Test: My Injection Test"
    echo "-----------------------"

    # Clear trace
    echo > "$TRACE_DIR/trace"

    # Inject error
    echo 1 > /path/to/inject

    sleep 2

    # Verify trace event
    if wait_for_trace "expected_event" 5; then
        inject_result "My test - trace" 0
    else
        inject_result "My test - trace" 1 "Event not found"
    fi

    # Verify handler called
    if wait_for_trace "ras_handler_name" 5; then
        inject_result "My test - handler" 0
    else
        inject_result "My test - handler" 1 "Handler not traced"
    fi

    save_trace "my_test"
}

test_inject_something
print_injection_summary
```

## Troubleshooting

### "EINJ not available"

```bash
modprobe einj
```

If that fails, kernel needs `CONFIG_ACPI_APEI_EINJ=y`

### "mce-inject not found"

```bash
# Debian/Ubuntu
apt install mce-inject

# Fedora/RHEL
dnf install mce-inject
```

### "Permission denied"

Must run as root:
```bash
sudo bash tests/injection/inject_memory_errors.sh
```

### "Handler not traced"

1. Ensure rasdaemon is running:
   ```bash
   pgrep rasdaemon
   ```

2. Check debugfs is mounted:
   ```bash
   mount | grep debugfs
   ```

3. Verify trace_marker is writable:
   ```bash
   ls -l /sys/kernel/debug/tracing/trace_marker
   ```

### "Event not in database"

Check rasdaemon was built with SQLite support and database path:
```bash
ls /var/lib/rasdaemon/ras-mc_event.db
# or
ls /var/log/ras/ras.db
```

## Safety Notes

- **Always run in isolated test environments**
- UCE (uncorrectable) errors can crash the system
- Fatal errors will cause kernel panic
- Some errors may corrupt data
- Have console access for recovery

## See Also

- `docs/TRACING.md` - ftrace tracing guide
- `tests/README.md` - Unit tests (safe, no injection)
