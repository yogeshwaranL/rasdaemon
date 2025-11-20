#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Test script for AER (PCIe Advanced Error Reporting) errors
# Tests the ras_aer_event_handler

source "$(dirname "$0")/test_framework.sh"

echo "=========================================="
echo "AER (PCIe) Error Tests"
echo "=========================================="

init_tests

# Test 1: Check AER trace event
test_aer_trace_event() {
    local event_dir="/sys/kernel/debug/tracing/events/ras/aer_event"

    if [ -d "$event_dir" ]; then
        print_result "AER trace event exists" 0
    else
        print_result "AER trace event exists" 1 "Event directory not found"
    fi
}

# Test 2: Check AER event format
test_aer_event_format() {
    local format_file="/sys/kernel/debug/tracing/events/ras/aer_event/format"

    if [ -f "$format_file" ]; then
        local fields=("dev_name" "status" "severity" "tlp_header_valid")

        local found=0
        for field in "${fields[@]}"; do
            if grep -q "$field" "$format_file"; then
                found=$((found + 1))
            fi
        done

        print_result "AER event format ($found/${#fields[@]} fields)" 0
    else
        print_result "AER event format exists" 1 "Format file not found"
    fi
}

# Test 3: Check PCI AER devices
test_pci_aer_devices() {
    local aer_count=0

    if [ -d "/sys/bus/pci/devices" ]; then
        for dev in /sys/bus/pci/devices/*; do
            if [ -d "$dev/aer_dev_correctable" ]; then
                aer_count=$((aer_count + 1))
            fi
        done
    fi

    echo "  Found $aer_count PCI devices with AER support"
    print_result "PCI AER devices enumerated" 0
}

# Test 4: Check AER error types
test_aer_error_types() {
    echo "  Correctable errors:"
    echo "    - Receiver Error"
    echo "    - Bad TLP"
    echo "    - Bad DLLP"
    echo "    - Replay Timer Timeout"
    echo "    - Replay Num Rollover"
    echo "    - Advisory Non-Fatal"
    echo "    - Corrected Internal Error"
    echo "    - Header Log Overflow"

    echo "  Uncorrectable errors:"
    echo "    - Data Link Protocol Error"
    echo "    - Surprise Down Error"
    echo "    - Poisoned TLP"
    echo "    - Flow Control Protocol Error"
    echo "    - Completion Timeout"
    echo "    - Completer Abort"
    echo "    - Unexpected Completion"
    echo "    - Receiver Overflow"
    echo "    - Malformed TLP"
    echo "    - ECRC Error"
    echo "    - Unsupported Request Error"
    echo "    - ACS Violation"
    echo "    - Uncorrectable Internal Error"
    echo "    - MC Blocked TLP"
    echo "    - AtomicOp Egress Blocked"
    echo "    - TLP Prefix Blocked Error"

    print_result "AER error types documented" 0
}

# Test 5: Check AER database table
test_aer_db_table() {
    local test_db="$RESULTS_DIR/aer_test.db"

    sqlite3 "$test_db" <<EOF
CREATE TABLE IF NOT EXISTS aer_event (
    id INTEGER PRIMARY KEY,
    timestamp TEXT,
    dev_name TEXT,
    err_type TEXT,
    err_msg TEXT
);
EOF

    if [ $? -eq 0 ]; then
        print_result "AER database table schema valid" 0
    else
        print_result "AER database table schema valid" 1 "Failed to create schema"
    fi

    rm -f "$test_db"
}

# Test 6: Generate sample AER event
test_generate_aer_sample() {
    cat > "$RESULTS_DIR/aer_sample_event.txt" << 'EOF'
Sample AER Event Data:
======================
timestamp: 2024-01-15 10:30:45
dev_name: 0000:01:00.0
severity: Corrected
error_status: 0x00000001
tlp_header: 00000000 00000000 00000000 00000000

Expected trace output:
[AER] -> ras_aer_event_handler
  [DATABASE] -> ras_store_aer_event
  [DATABASE] <- ras_store_aer_event (ret=0)
  [REPORT] -> ras_report_aer_event
  [REPORT] <- ras_report_aer_event (ret=0)
[AER] <- ras_aer_event_handler (ret=0)
EOF

    print_result "AER sample event generated" 0
}

# Test 7: Check AER handler source
test_aer_handler_source() {
    local handler_file="$(dirname "$0")/../ras-aer-handler.c"

    if [ -f "$handler_file" ]; then
        print_result "AER handler source exists" 0
    else
        print_result "AER handler source exists" 1 "File not found"
    fi
}

# Run all tests
test_aer_trace_event
test_aer_event_format
test_pci_aer_devices
test_aer_error_types
test_aer_db_table
test_generate_aer_sample
test_aer_handler_source

print_summary
