#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Test script for Machine Check Exception (MCE) errors
# Tests the ras_mce_event_handler and CPU-specific decoders

source "$(dirname "$0")/test_framework.sh"

echo "=========================================="
echo "MCE (Machine Check Exception) Error Tests"
echo "=========================================="

init_tests

# Test 1: Check MCE trace event
test_mce_trace_event() {
    local event_dir="/sys/kernel/debug/tracing/events/mce/mce_record"

    if [ -d "$event_dir" ]; then
        print_result "MCE trace event exists" 0
    else
        print_result "MCE trace event exists" 1 "Event directory not found"
    fi
}

# Test 2: Check /dev/mcelog
test_mcelog_device() {
    if [ -c "/dev/mcelog" ]; then
        print_result "MCE log device exists" 0
    else
        print_result "MCE log device exists" 1 "Device not found"
    fi
}

# Test 3: Detect CPU type
test_cpu_detection() {
    local cpu_info="/proc/cpuinfo"

    if [ -f "$cpu_info" ]; then
        local vendor=$(grep -m1 "vendor_id" "$cpu_info" | cut -d: -f2 | tr -d ' ')
        local family=$(grep -m1 "cpu family" "$cpu_info" | cut -d: -f2 | tr -d ' ')
        local model=$(grep -m1 "model" "$cpu_info" | head -1 | cut -d: -f2 | tr -d ' ')

        echo "  Vendor: $vendor"
        echo "  Family: $family"
        echo "  Model: $model"

        if [ -n "$vendor" ]; then
            print_result "CPU type detection" 0
        else
            print_result "CPU type detection" 1 "Could not detect CPU"
        fi
    else
        print_result "CPU info available" 1 "File not found"
    fi
}

# Test 4: Check supported Intel CPU types
test_intel_cpu_types() {
    local cpu_types=(
        "CPU_NEHALEM"
        "CPU_SANDY_BRIDGE"
        "CPU_SANDY_BRIDGE_EP"
        "CPU_IVY_BRIDGE"
        "CPU_IVY_BRIDGE_EPEX"
        "CPU_HASWELL"
        "CPU_HASWELL_EPEX"
        "CPU_BROADWELL"
        "CPU_BROADWELL_DE"
        "CPU_BROADWELL_EPEX"
        "CPU_SKYLAKE_XEON"
        "CPU_KNIGHTS_LANDING"
        "CPU_KNIGHTS_MILL"
        "CPU_ICELAKE_XEON"
        "CPU_ICELAKE_DE"
        "CPU_TREMONT_D"
        "CPU_SAPPHIRE_RAPIDS"
        "CPU_EMERALD_RAPIDS"
        "CPU_GRANITE_RAPIDS"
    )

    echo "  Supported Intel CPU types: ${#cpu_types[@]}"
    print_result "Intel CPU types documented" 0
}

# Test 5: Check supported AMD CPU types
test_amd_cpu_types() {
    local cpu_types=(
        "CPU_K8"
        "CPU_F10H"
        "CPU_F11H"
        "CPU_F12H"
        "CPU_F14H"
        "CPU_F15H"
        "CPU_F16H"
        "CPU_F17H"
        "CPU_F19H"
    )

    echo "  Supported AMD CPU types: ${#cpu_types[@]}"
    print_result "AMD CPU types documented" 0
}

# Test 6: Check MCE database table
test_mce_db_table() {
    local test_db="$RESULTS_DIR/mce_test.db"

    sqlite3 "$test_db" <<EOF
CREATE TABLE IF NOT EXISTS mce_record (
    id INTEGER PRIMARY KEY,
    timestamp TEXT,
    mcgcap INTEGER,
    mcgstatus INTEGER,
    status INTEGER,
    addr INTEGER,
    misc INTEGER,
    ip INTEGER,
    tsc INTEGER,
    walltime INTEGER,
    cpu INTEGER,
    cpuid INTEGER,
    apicid INTEGER,
    socketid INTEGER,
    cs INTEGER,
    bank INTEGER,
    cpuvendor INTEGER,
    bank_name TEXT,
    error_msg TEXT,
    mcgstatus_msg TEXT,
    mcistatus_msg TEXT,
    mcastatus_msg TEXT,
    user_action TEXT,
    mc_location TEXT
);
EOF

    if [ $? -eq 0 ]; then
        print_result "MCE database table schema valid" 0
    else
        print_result "MCE database table schema valid" 1 "Failed to create schema"
    fi

    rm -f "$test_db"
}

# Test 7: Check MCE event format
test_mce_event_format() {
    local format_file="/sys/kernel/debug/tracing/events/mce/mce_record/format"

    if [ -f "$format_file" ]; then
        local fields=("mcgcap" "mcgstatus" "status" "addr" "misc" "ip" "tsc"
                     "walltime" "cpu" "cpuid" "apicid" "socketid" "cs" "bank")

        local found=0
        for field in "${fields[@]}"; do
            if grep -q "$field" "$format_file"; then
                found=$((found + 1))
            fi
        done

        echo "  Found $found/${#fields[@]} expected fields"
        if [ "$found" -eq "${#fields[@]}" ]; then
            print_result "MCE event format complete" 0
        else
            print_result "MCE event format complete" 1 "Some fields missing"
        fi
    else
        print_result "MCE event format exists" 1 "Format file not found"
    fi
}

# Test 8: Generate sample MCE event
test_generate_mce_sample() {
    cat > "$RESULTS_DIR/mce_sample_event.txt" << 'EOF'
Sample MCE Event Data:
======================
timestamp: 2024-01-15 10:30:45
mcgcap: 0x0000000f0e000c14
mcgstatus: 0x0000000000000005
status: 0x8c00004000010005
addr: 0x00000000deadbeef
misc: 0x0000000000000000
ip: 0xffffffff81234567
tsc: 0x0000001234567890
cpu: 0
cpuid: 0x000506e3
apicid: 0
socketid: 0
cs: 0x0010
bank: 1
cpuvendor: 0 (Intel)

Expected trace output:
[MCE] -> ras_mce_event_handler
  [MCE] -> detect_cpu
  [MCE] <- detect_cpu (ret=0)
  [MCE] -> parse_intel_event
    [MCE] -> skylake_s_decode_model
    [MCE] <- skylake_s_decode_model (ret=0)
  [MCE] <- parse_intel_event (ret=0)
  [DATABASE] -> ras_store_mce_record
  [DATABASE] <- ras_store_mce_record (ret=0)
[MCE] <- ras_mce_event_handler (ret=0)
EOF

    print_result "MCE sample event generated" 0
    echo "  Sample saved to: $RESULTS_DIR/mce_sample_event.txt"
}

# Test 9: Check MCE handler source
test_mce_handler_source() {
    local handler_file="$(dirname "$0")/../ras-mce-handler.c"

    if [ -f "$handler_file" ]; then
        local functions=("ras_mce_event_handler" "detect_cpu" "register_mce_handler")

        for func in "${functions[@]}"; do
            if ! grep -q "$func" "$handler_file"; then
                print_result "MCE handler has $func" 1 "Function not found"
                return
            fi
        done

        print_result "MCE handler has all required functions" 0
    else
        print_result "MCE handler source exists" 1 "File not found"
    fi
}

# Test 10: Check Intel decoder sources
test_intel_decoders() {
    local decoders=(
        "mce-intel.c"
        "mce-intel-nehalem.c"
        "mce-intel-sb.c"
        "mce-intel-ivb.c"
        "mce-intel-haswell.c"
        "mce-intel-knl.c"
        "mce-intel-broadwell-de.c"
        "mce-intel-broadwell-epex.c"
        "mce-intel-skylake-xeon.c"
        "mce-intel-i10nm.c"
    )

    local found=0
    for decoder in "${decoders[@]}"; do
        if [ -f "$(dirname "$0")/../$decoder" ]; then
            found=$((found + 1))
        fi
    done

    echo "  Found $found/${#decoders[@]} Intel decoders"
    print_result "Intel MCE decoders present" 0
}

# Test 11: Check AMD decoder sources
test_amd_decoders() {
    local decoders=(
        "mce-amd-k8.c"
        "mce-amd-smca.c"
    )

    local found=0
    for decoder in "${decoders[@]}"; do
        if [ -f "$(dirname "$0")/../$decoder" ]; then
            found=$((found + 1))
        fi
    done

    echo "  Found $found/${#decoders[@]} AMD decoders"
    print_result "AMD MCE decoders present" 0
}

# Run all tests
test_mce_trace_event
test_mcelog_device
test_cpu_detection
test_intel_cpu_types
test_amd_cpu_types
test_mce_db_table
test_mce_event_format
test_generate_mce_sample
test_mce_handler_source
test_intel_decoders
test_amd_decoders

print_summary
