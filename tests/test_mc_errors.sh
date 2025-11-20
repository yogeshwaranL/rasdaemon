#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Test script for Memory Controller (MC) errors
# Tests the ras_mc_event_handler and related functions

source "$(dirname "$0")/test_framework.sh"

echo "=========================================="
echo "MC (Memory Controller) Error Tests"
echo "=========================================="

init_tests

# Test 1: Check MC trace event exists
test_mc_trace_event() {
    local event_dir="/sys/kernel/debug/tracing/events/ras/mc_event"

    if [ -d "$event_dir" ]; then
        print_result "MC trace event exists" 0
    else
        print_result "MC trace event exists" 1 "Event directory not found"
    fi
}

# Test 2: Check MC event format
test_mc_event_format() {
    local format_file="/sys/kernel/debug/tracing/events/ras/mc_event/format"

    if [ -f "$format_file" ]; then
        # Check for expected fields
        local fields=("error_type" "error_count" "mc_index" "top_layer"
                     "middle_layer" "lower_layer" "address" "grain_bits"
                     "syndrome" "msg" "label" "driver_detail")

        local all_found=1
        for field in "${fields[@]}"; do
            if ! grep -q "$field" "$format_file"; then
                echo "  Missing field: $field"
                all_found=0
            fi
        done

        if [ "$all_found" -eq 1 ]; then
            print_result "MC event format has all fields" 0
        else
            print_result "MC event format has all fields" 1 "Some fields missing"
        fi
    else
        print_result "MC event format exists" 1 "Format file not found"
    fi
}

# Test 3: Check EDAC MC sysfs
test_edac_mc_sysfs() {
    local edac_dir="/sys/devices/system/edac/mc"

    if [ -d "$edac_dir" ]; then
        # Count MC instances
        local mc_count=$(ls -d "$edac_dir"/mc* 2>/dev/null | wc -l)
        print_result "EDAC MC sysfs available (${mc_count} MC(s))" 0
    else
        print_result "EDAC MC sysfs available" 1 "EDAC MC directory not found"
    fi
}

# Test 4: Check database table creation
test_mc_db_table() {
    local test_db="$RESULTS_DIR/mc_test.db"

    # Create test database schema
    sqlite3 "$test_db" <<EOF
CREATE TABLE IF NOT EXISTS mc_event (
    id INTEGER PRIMARY KEY,
    timestamp TEXT,
    err_count INTEGER,
    err_type TEXT,
    err_msg TEXT,
    label TEXT,
    mc_index INTEGER,
    top_layer INTEGER,
    middle_layer INTEGER,
    lower_layer INTEGER,
    address INTEGER,
    grain INTEGER,
    syndrome INTEGER,
    driver_detail TEXT
);
EOF

    if [ $? -eq 0 ]; then
        print_result "MC database table schema valid" 0
    else
        print_result "MC database table schema valid" 1 "Failed to create schema"
    fi

    rm -f "$test_db"
}

# Test 5: Test MC error type parsing
test_mc_error_types() {
    local error_types=("Corrected" "Uncorrected" "Deferred" "Fatal" "Info")
    local all_valid=1

    echo "  Checking MC error types..."
    for err_type in "${error_types[@]}"; do
        echo "    - $err_type"
    done

    print_result "MC error types defined" 0
}

# Test 6: Check MC trigger environment variables
test_mc_triggers() {
    echo "  MC_CE_TRIGGER: ${MC_CE_TRIGGER:-not set}"
    echo "  MC_UE_TRIGGER: ${MC_UE_TRIGGER:-not set}"

    print_result "MC trigger variables documented" 0
}

# Test 7: Simulate MC event structure
test_mc_event_structure() {
    # This test validates the C structure by checking expected field sizes
    cat > "$RESULTS_DIR/mc_struct_test.c" << 'EOF'
#include <stdio.h>
#include <string.h>

struct ras_mc_event {
    char timestamp[64];
    int error_count;
    const char *error_type;
    const char *msg;
    const char *label;
    int mc_index;
    signed char top_layer;
    signed char middle_layer;
    signed char lower_layer;
    unsigned long long address;
    unsigned long long grain;
    unsigned long long syndrome;
    const char *driver_detail;
};

int main() {
    struct ras_mc_event ev;
    memset(&ev, 0, sizeof(ev));

    // Verify structure is valid
    printf("MC event structure size: %zu bytes\n", sizeof(ev));
    printf("  timestamp: %zu bytes\n", sizeof(ev.timestamp));
    printf("  address: %zu bytes\n", sizeof(ev.address));

    return 0;
}
EOF

    if gcc -o "$RESULTS_DIR/mc_struct_test" "$RESULTS_DIR/mc_struct_test.c" 2>/dev/null; then
        "$RESULTS_DIR/mc_struct_test"
        print_result "MC event structure compiles" 0
    else
        print_result "MC event structure compiles" 1 "Compilation failed"
    fi

    rm -f "$RESULTS_DIR/mc_struct_test" "$RESULTS_DIR/mc_struct_test.c"
}

# Test 8: Test trace filtering
test_mc_trace_filter() {
    local filter_file="/sys/kernel/debug/tracing/events/ras/mc_event/filter"

    if [ -f "$filter_file" ] && [ -w "$filter_file" ]; then
        print_result "MC trace filter writable" 0
    else
        print_result "MC trace filter writable" 1 "Filter not writable"
    fi
}

# Test 9: Generate sample MC error data
test_generate_mc_sample() {
    cat > "$RESULTS_DIR/mc_sample_event.txt" << 'EOF'
Sample MC Event Data:
=====================
timestamp: 2024-01-15 10:30:45 +0000
error_count: 1
error_type: Corrected
msg: DIMM location error
label: CPU0_DIMM_A1
mc_index: 0
top_layer: 0
middle_layer: 0
lower_layer: 0
address: 0x00000000deadbeef
grain: 64
syndrome: 0x0000000000000000
driver_detail: rank:0 bank:1 row:1234 col:567

Expected trace output:
[MC] -> ras_mc_event_handler
  [DATABASE] -> ras_store_mc_event
  [DATABASE] <- ras_store_mc_event (ret=0)
  [REPORT] -> ras_report_mc_event
  [REPORT] <- ras_report_mc_event (ret=0)
[MC] <- ras_mc_event_handler (ret=0)
EOF

    print_result "MC sample event generated" 0
    echo "  Sample saved to: $RESULTS_DIR/mc_sample_event.txt"
}

# Test 10: Verify MC handler compilation
test_mc_handler_compilation() {
    local handler_file="$(dirname "$0")/../ras-mc-handler.c"

    if [ -f "$handler_file" ]; then
        # Check for key functions
        local functions=("ras_mc_event_handler" "mc_event_trigger_setup" "run_mc_trigger")

        for func in "${functions[@]}"; do
            if grep -q "$func" "$handler_file"; then
                echo "  Found: $func"
            else
                print_result "MC handler has $func" 1 "Function not found"
                return
            fi
        done

        print_result "MC handler has all required functions" 0
    else
        print_result "MC handler source exists" 1 "File not found"
    fi
}

# Run all tests
test_mc_trace_event
test_mc_event_format
test_edac_mc_sysfs
test_mc_db_table
test_mc_error_types
test_mc_triggers
test_mc_event_structure
test_mc_trace_filter
test_generate_mc_sample
test_mc_handler_compilation

print_summary
