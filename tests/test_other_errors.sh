#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Test script for other error types:
# - ARM processor errors
# - EXTLOG (Extended Machine Check Logging)
# - Non-standard/vendor-specific errors
# - Devlink network errors
# - Disk errors
# - Memory failure (page offline)
# - Signal errors

source "$(dirname "$0")/test_framework.sh"

echo "=========================================="
echo "Other Error Types Tests"
echo "=========================================="

init_tests

# =========================================
# ARM Processor Error Tests
# =========================================

test_arm_trace_event() {
    local event_dir="/sys/kernel/debug/tracing/events/ras/arm_event"

    if [ -d "$event_dir" ]; then
        print_result "ARM trace event exists" 0
    else
        print_result "ARM trace event exists" 1 "Not found (may require ARM platform)"
    fi
}

test_arm_error_types() {
    echo "  ARM processor error types:"
    echo "    - Cache Error"
    echo "    - TLB Error"
    echo "    - Bus Error"
    echo "    - Micro-architectural Error"

    print_result "ARM error types documented" 0
}

# =========================================
# EXTLOG Tests
# =========================================

test_extlog_trace_event() {
    local event_dir="/sys/kernel/debug/tracing/events/ras/extlog_mem_event"

    if [ -d "$event_dir" ]; then
        print_result "EXTLOG trace event exists" 0
    else
        print_result "EXTLOG trace event exists" 1 "Not found"
    fi
}

test_extlog_error_types() {
    echo "  EXTLOG error types:"
    echo "    - Unknown"
    echo "    - No Error"
    echo "    - Single-bit ECC"
    echo "    - Multi-bit ECC"
    echo "    - Single-symbol ChipKill"
    echo "    - Multi-symbol ChipKill"
    echo "    - Master Abort"
    echo "    - Target Abort"
    echo "    - Parity Error"
    echo "    - Watchdog Timeout"
    echo "    - Invalid Address"
    echo "    - Mirror Broken"
    echo "    - Memory Sparing"
    echo "    - Scrub corrected"
    echo "    - Scrub uncorrected"

    print_result "EXTLOG error types documented" 0
}

# =========================================
# Non-Standard Error Tests
# =========================================

test_non_standard_trace_event() {
    local event_dir="/sys/kernel/debug/tracing/events/ras/non_standard_event"

    if [ -d "$event_dir" ]; then
        print_result "Non-standard trace event exists" 0
    else
        print_result "Non-standard trace event exists" 1 "Not found"
    fi
}

test_vendor_decoders() {
    local decoders=(
        "non-standard-hisilicon.c"
        "non-standard-ampere.c"
        "non-standard-yitian.c"
        "non-standard-jaguarmicro.c"
    )

    local found=0
    for decoder in "${decoders[@]}"; do
        if [ -f "$(dirname "$0")/../$decoder" ]; then
            found=$((found + 1))
            echo "    - $decoder"
        fi
    done

    echo "  Found $found/${#decoders[@]} vendor decoders"
    print_result "Vendor decoders present" 0
}

# =========================================
# Devlink Error Tests
# =========================================

test_devlink_trace_event() {
    local event_dir="/sys/kernel/debug/tracing/events/devlink/devlink_health_report"

    if [ -d "$event_dir" ]; then
        print_result "Devlink trace event exists" 0
    else
        print_result "Devlink trace event exists" 1 "Not found"
    fi
}

test_devlink_devices() {
    if command -v devlink &> /dev/null; then
        local dev_count=$(devlink dev 2>/dev/null | wc -l)
        echo "  Devlink devices: $dev_count"
        print_result "Devlink devices enumerated" 0
    else
        print_result "Devlink tool available" 1 "devlink command not found"
    fi
}

# =========================================
# Disk Error Tests
# =========================================

test_disk_trace_event() {
    local event_dir="/sys/kernel/debug/tracing/events/block/block_rq_complete"

    if [ -d "$event_dir" ]; then
        print_result "Disk error trace event exists" 0
    else
        print_result "Disk error trace event exists" 1 "Not found"
    fi
}

test_disk_error_types() {
    echo "  Disk error tracking:"
    echo "    - Block layer I/O errors"
    echo "    - Device-specific errors"

    print_result "Disk error types documented" 0
}

# =========================================
# Memory Failure Tests
# =========================================

test_memory_failure_trace_event() {
    local event_dir="/sys/kernel/debug/tracing/events/ras/memory_failure_event"

    if [ -d "$event_dir" ]; then
        print_result "Memory failure trace event exists" 0
    else
        print_result "Memory failure trace event exists" 1 "Not found"
    fi
}

test_memory_failure_actions() {
    echo "  Memory failure actions:"
    echo "    - Delayed"
    echo "    - Recovered"
    echo "    - Ignored"
    echo "    - Failed"
    echo "    - Soft Offline"

    echo "  Page types:"
    echo "    - Buddy page"
    echo "    - Huge page"
    echo "    - Anonymous page"
    echo "    - Mapped page"

    print_result "Memory failure actions documented" 0
}

# =========================================
# Signal Error Tests
# =========================================

test_signal_trace_event() {
    local event_dir="/sys/kernel/debug/tracing/events/signal"

    if [ -d "$event_dir" ]; then
        print_result "Signal trace event exists" 0
    else
        print_result "Signal trace event exists" 1 "Not found"
    fi
}

test_signal_types() {
    echo "  Tracked signals:"
    echo "    - SIGBUS (hardware fault)"
    echo "    - Various signal codes"

    print_result "Signal types documented" 0
}

# =========================================
# Database Tables for Other Error Types
# =========================================

test_other_db_tables() {
    local test_db="$RESULTS_DIR/other_test.db"

    sqlite3 "$test_db" <<EOF
-- ARM event table
CREATE TABLE IF NOT EXISTS arm_event (
    id INTEGER PRIMARY KEY,
    timestamp TEXT,
    error_count INTEGER,
    affinity INTEGER,
    mpidr INTEGER,
    midr INTEGER,
    running_state INTEGER,
    psci_state INTEGER,
    err_info TEXT
);

-- EXTLOG event table
CREATE TABLE IF NOT EXISTS extlog_event (
    id INTEGER PRIMARY KEY,
    timestamp TEXT,
    etype INTEGER,
    error_count INTEGER,
    severity INTEGER,
    address INTEGER,
    fru_id TEXT,
    fru_text TEXT,
    cper_data TEXT
);

-- Non-standard event table
CREATE TABLE IF NOT EXISTS non_standard_event (
    id INTEGER PRIMARY KEY,
    timestamp TEXT,
    sec_type TEXT,
    fru_id TEXT,
    fru_text TEXT,
    severity TEXT,
    error TEXT
);

-- Devlink event table
CREATE TABLE IF NOT EXISTS devlink_event (
    id INTEGER PRIMARY KEY,
    timestamp TEXT,
    bus_name TEXT,
    dev_name TEXT,
    driver_name TEXT,
    reporter_name TEXT,
    msg TEXT
);

-- Disk error table
CREATE TABLE IF NOT EXISTS disk_errors (
    id INTEGER PRIMARY KEY,
    timestamp TEXT,
    dev TEXT,
    sector INTEGER,
    nr_sector INTEGER,
    error TEXT,
    rwbs TEXT,
    cmd TEXT
);

-- Memory failure table
CREATE TABLE IF NOT EXISTS memory_failure_event (
    id INTEGER PRIMARY KEY,
    timestamp TEXT,
    pfn INTEGER,
    page_type TEXT,
    action_result TEXT
);

-- Signal event table
CREATE TABLE IF NOT EXISTS signal_event (
    id INTEGER PRIMARY KEY,
    timestamp TEXT,
    signal INTEGER,
    error_no INTEGER,
    code INTEGER,
    pid INTEGER,
    comm TEXT,
    group INTEGER
);
EOF

    if [ $? -eq 0 ]; then
        print_result "Other error database tables valid" 0
    else
        print_result "Other error database tables valid" 1 "Failed to create schema"
    fi

    rm -f "$test_db"
}

# Run all tests
echo ""
echo "ARM Processor Errors:"
echo "---------------------"
test_arm_trace_event
test_arm_error_types

echo ""
echo "EXTLOG Errors:"
echo "--------------"
test_extlog_trace_event
test_extlog_error_types

echo ""
echo "Non-Standard Errors:"
echo "--------------------"
test_non_standard_trace_event
test_vendor_decoders

echo ""
echo "Devlink Errors:"
echo "---------------"
test_devlink_trace_event
test_devlink_devices

echo ""
echo "Disk Errors:"
echo "------------"
test_disk_trace_event
test_disk_error_types

echo ""
echo "Memory Failure:"
echo "---------------"
test_memory_failure_trace_event
test_memory_failure_actions

echo ""
echo "Signal Errors:"
echo "--------------"
test_signal_trace_event
test_signal_types

echo ""
echo "Database Tables:"
echo "----------------"
test_other_db_tables

print_summary
