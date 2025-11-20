# RAS Daemon Unit Tests

Unit tests that verify rasdaemon infrastructure exists and is correctly configured. These tests are **safe to run** anywhere - they do not inject actual errors.

## What These Tests Verify

- Kernel trace events exist (`/sys/kernel/debug/tracing/events/ras/`)
- Event formats have expected fields
- EDAC/sysfs interfaces present
- Database table schemas valid
- Handler source code complete

## Running Tests

```bash
# Run all unit tests
bash tests/run_all_tests.sh

# Run individual test suites
bash tests/test_mc_errors.sh      # Memory Controller
bash tests/test_mce_errors.sh     # Machine Check Exception
bash tests/test_aer_errors.sh     # PCIe AER
bash tests/test_cxl_errors.sh     # CXL errors
bash tests/test_other_errors.sh   # ARM, EXTLOG, devlink, etc.
```

## Test Output

```
==========================================
MC (Memory Controller) Error Tests
==========================================

[PASS] MC trace event exists
[PASS] MC event format has all fields
[PASS] MC database table schema valid
[SKIP] EDAC MC sysfs available: Not found

==========================================
Test Summary
==========================================
Tests run:    10
Tests passed: 8
Tests skipped: 2
```

## Results Location

Test results saved to: `/tmp/rasdaemon_tests/`

Report file: `/tmp/rasdaemon_tests/test_report_YYYYMMDD_HHMMSS.txt`

## Test Files

| File | Description |
|------|-------------|
| `test_framework.sh` | Common utilities and assertions |
| `test_mc_errors.sh` | Memory Controller tests |
| `test_mce_errors.sh` | Machine Check Exception tests |
| `test_aer_errors.sh` | PCIe AER tests |
| `test_cxl_errors.sh` | CXL error tests |
| `test_other_errors.sh` | ARM, EXTLOG, devlink, disk, memory failure, signal |
| `run_all_tests.sh` | Main test runner |

## Adding New Tests

```bash
#!/bin/bash
source "$(dirname "$0")/test_framework.sh"

echo "=========================================="
echo "My New Tests"
echo "=========================================="

init_tests

test_something() {
    if [ -d "/sys/some/path" ]; then
        print_result "Something exists" 0
    else
        print_result "Something exists" 1 "Not found"
    fi
}

test_something
print_summary
```

## Troubleshooting

### "Event not found"
- Kernel may not support that event type
- Check: `ls /sys/kernel/debug/tracing/events/ras/`

### "EDAC not available"
- No memory controller driver loaded
- Check: `ls /sys/devices/system/edac/`

### "debugfs not mounted"
```bash
mount -t debugfs none /sys/kernel/debug
```

## Note

These are **sanity checks only**. For actual error injection testing, see `tests/injection/README.md`.
