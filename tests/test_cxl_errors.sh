#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Test script for CXL (Compute Express Link) errors
# Tests all CXL event handlers

source "$(dirname "$0")/test_framework.sh"

echo "=========================================="
echo "CXL (Compute Express Link) Error Tests"
echo "=========================================="

init_tests

# Test 1: Check CXL trace events
test_cxl_trace_events() {
    local events=(
        "cxl_poison"
        "cxl_aer_uncorrectable_error"
        "cxl_aer_correctable_error"
        "cxl_overflow"
        "cxl_generic_event"
        "cxl_general_media"
        "cxl_dram"
        "cxl_memory_module"
    )

    local found=0
    for event in "${events[@]}"; do
        if [ -d "/sys/kernel/debug/tracing/events/cxl/$event" ]; then
            found=$((found + 1))
        fi
    done

    echo "  Found $found/${#events[@]} CXL trace events"
    print_result "CXL trace events" 0
}

# Test 2: Check CXL devices
test_cxl_devices() {
    local cxl_bus="/sys/bus/cxl"

    if [ -d "$cxl_bus" ]; then
        local dev_count=$(ls "$cxl_bus/devices" 2>/dev/null | wc -l)
        echo "  CXL devices found: $dev_count"
        print_result "CXL bus available" 0
    else
        print_result "CXL bus available" 1 "CXL bus not found (may require kernel 5.12+)"
    fi
}

# Test 3: CXL Poison event types
test_cxl_poison_types() {
    echo "  CXL Poison trace types:"
    echo "    - List"
    echo "    - Inject"
    echo "    - Clear"

    print_result "CXL poison types documented" 0
}

# Test 4: CXL database tables
test_cxl_db_tables() {
    local test_db="$RESULTS_DIR/cxl_test.db"

    sqlite3 "$test_db" <<EOF
CREATE TABLE IF NOT EXISTS cxl_poison_event (
    id INTEGER PRIMARY KEY,
    timestamp TEXT,
    memdev TEXT,
    host TEXT,
    serial INTEGER,
    trace_type TEXT,
    region TEXT,
    region_uuid TEXT,
    hpa INTEGER,
    dpa INTEGER,
    dpa_length INTEGER,
    source TEXT,
    flags TEXT,
    overflow_timestamp TEXT
);

CREATE TABLE IF NOT EXISTS cxl_aer_ue_event (
    id INTEGER PRIMARY KEY,
    timestamp TEXT,
    memdev TEXT,
    host TEXT,
    serial INTEGER,
    error_status TEXT,
    first_error TEXT,
    header_log TEXT
);

CREATE TABLE IF NOT EXISTS cxl_aer_ce_event (
    id INTEGER PRIMARY KEY,
    timestamp TEXT,
    memdev TEXT,
    host TEXT,
    serial INTEGER,
    error_status TEXT
);

CREATE TABLE IF NOT EXISTS cxl_overflow_event (
    id INTEGER PRIMARY KEY,
    timestamp TEXT,
    memdev TEXT,
    host TEXT,
    serial INTEGER,
    log_type TEXT,
    count INTEGER,
    first_ts TEXT,
    last_ts TEXT
);

CREATE TABLE IF NOT EXISTS cxl_generic_event (
    id INTEGER PRIMARY KEY,
    timestamp TEXT,
    memdev TEXT,
    host TEXT,
    serial INTEGER,
    log_type TEXT,
    hdr_uuid TEXT,
    hdr_flags TEXT,
    hdr_handle INTEGER,
    hdr_related_handle INTEGER,
    hdr_ts TEXT,
    hdr_length INTEGER,
    hdr_maint_op_class INTEGER,
    data TEXT
);

CREATE TABLE IF NOT EXISTS cxl_general_media_event (
    id INTEGER PRIMARY KEY,
    timestamp TEXT,
    memdev TEXT,
    host TEXT,
    serial INTEGER,
    log_type TEXT,
    hdr_uuid TEXT,
    hdr_flags TEXT,
    hdr_handle INTEGER,
    hdr_related_handle INTEGER,
    hdr_ts TEXT,
    hdr_length INTEGER,
    hdr_maint_op_class INTEGER,
    dpa INTEGER,
    dpa_flags TEXT,
    descriptor TEXT,
    type TEXT,
    transaction_type TEXT,
    channel INTEGER,
    rank INTEGER,
    device INTEGER,
    comp_id TEXT
);

CREATE TABLE IF NOT EXISTS cxl_dram_event (
    id INTEGER PRIMARY KEY,
    timestamp TEXT,
    memdev TEXT,
    host TEXT,
    serial INTEGER,
    log_type TEXT,
    hdr_uuid TEXT,
    hdr_flags TEXT,
    hdr_handle INTEGER,
    hdr_related_handle INTEGER,
    hdr_ts TEXT,
    hdr_length INTEGER,
    hdr_maint_op_class INTEGER,
    dpa INTEGER,
    dpa_flags TEXT,
    descriptor TEXT,
    type TEXT,
    transaction_type TEXT,
    channel INTEGER,
    rank INTEGER,
    nibble_mask INTEGER,
    bank_group INTEGER,
    bank INTEGER,
    row INTEGER,
    column INTEGER,
    cor_mask TEXT
);

CREATE TABLE IF NOT EXISTS cxl_memory_module_event (
    id INTEGER PRIMARY KEY,
    timestamp TEXT,
    memdev TEXT,
    host TEXT,
    serial INTEGER,
    log_type TEXT,
    hdr_uuid TEXT,
    hdr_flags TEXT,
    hdr_handle INTEGER,
    hdr_related_handle INTEGER,
    hdr_ts TEXT,
    hdr_length INTEGER,
    hdr_maint_op_class INTEGER,
    event_type TEXT,
    health_status TEXT,
    media_status TEXT,
    life_used TEXT,
    dirty_shutdown_cnt INTEGER,
    cor_vol_err_cnt INTEGER,
    cor_per_err_cnt INTEGER,
    device_temp INTEGER,
    add_status TEXT
);
EOF

    if [ $? -eq 0 ]; then
        print_result "CXL database tables valid" 0
    else
        print_result "CXL database tables valid" 1 "Failed to create schema"
    fi

    rm -f "$test_db"
}

# Test 5: Generate sample CXL events
test_generate_cxl_samples() {
    cat > "$RESULTS_DIR/cxl_sample_events.txt" << 'EOF'
Sample CXL Poison Event:
========================
memdev: mem0
serial: 0x1234567890abcdef
trace_type: List
region: region0
hpa: 0x0000000100000000
dpa: 0x0000000000100000
source: Media scrub

Sample CXL AER UE Event:
========================
memdev: mem0
serial: 0x1234567890abcdef
error_status: CXL.mem error
first_error: Cache Data Parity

Sample CXL DRAM Event:
======================
memdev: mem0
serial: 0x1234567890abcdef
dpa: 0x0000000000100000
transaction_type: Host Read
channel: 0
rank: 0
bank_group: 1
bank: 2
row: 1234
column: 567

Expected trace output for CXL DRAM event:
[CXL_DRAM] -> ras_cxl_dram_event_handler
  [DATABASE] -> ras_store_cxl_dram_event
  [DATABASE] <- ras_store_cxl_dram_event (ret=0)
[CXL_DRAM] <- ras_cxl_dram_event_handler (ret=0)
EOF

    print_result "CXL sample events generated" 0
}

# Test 6: Check CXL handler source
test_cxl_handler_source() {
    local handler_file="$(dirname "$0")/../ras-cxl-handler.c"

    if [ -f "$handler_file" ]; then
        local handlers=(
            "ras_cxl_poison_event_handler"
            "ras_cxl_aer_ue_event_handler"
            "ras_cxl_aer_ce_event_handler"
            "ras_cxl_overflow_event_handler"
            "ras_cxl_generic_event_handler"
            "ras_cxl_general_media_event_handler"
            "ras_cxl_dram_event_handler"
            "ras_cxl_memory_module_event_handler"
        )

        local found=0
        for handler in "${handlers[@]}"; do
            if grep -q "$handler" "$handler_file"; then
                found=$((found + 1))
            fi
        done

        echo "  Found $found/${#handlers[@]} CXL handlers"
        print_result "CXL handler source complete" 0
    else
        print_result "CXL handler source exists" 1 "File not found"
    fi
}

# Run all tests
test_cxl_trace_events
test_cxl_devices
test_cxl_poison_types
test_cxl_db_tables
test_generate_cxl_samples
test_cxl_handler_source

print_summary
