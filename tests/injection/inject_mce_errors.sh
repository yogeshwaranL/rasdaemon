#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
#
# MCE (Machine Check Exception) Injection Tests
# Uses mce-inject tool and EINJ to inject CPU errors

source "$(dirname "$0")/inject_framework.sh"

echo "=========================================="
echo "MCE Injection Tests"
echo "=========================================="

init_injection_tests

# EINJ error type codes for processor errors
EINJ_PROC_CE=0x1         # Processor Correctable
EINJ_PROC_UCE=0x2        # Processor Uncorrectable non-fatal
EINJ_PROC_UCE_FATAL=0x4  # Processor Uncorrectable fatal

# =========================================
# mce-inject Tests
# =========================================

test_mce_inject_correctable() {
    echo ""
    echo "Test: mce-inject Correctable Error"
    echo "-----------------------------------"

    if ! check_mce_inject; then
        inject_result "mce-inject CE" 2 "mce-inject not available"
        return
    fi

    # Create MCE injection file
    local mce_file="$RESULTS_DIR/test_ce.mce"

    cat > "$mce_file" << 'EOF'
# Correctable MCE - Memory Controller Error
CPU 0
BANK 7
STATUS 0x8c00004000010005
MISC 0x0000000000000000
ADDR 0x0000000012345678
EOF

    echo "Injecting MCE from: $mce_file"

    # Clear trace
    echo > "$TRACE_DIR/trace"

    # Inject
    if mce-inject "$mce_file" 2>/dev/null; then
        sleep 2

        # Check trace for mce_record
        if wait_for_trace "mce_record" 5; then
            inject_result "mce-inject CE - trace event" 0
        else
            inject_result "mce-inject CE - trace event" 1 "Event not found"
        fi

        # Check for handler
        if wait_for_trace "ras_mce_event_handler" 5; then
            inject_result "mce-inject CE - handler" 0
        else
            inject_result "mce-inject CE - handler" 1 "Handler not traced"
        fi

        # Check database
        if wait_for_db_event "mce_record" 5; then
            inject_result "mce-inject CE - database" 0
        else
            inject_result "mce-inject CE - database" 1 "Event not in database"
        fi

        save_trace "mce_inject_ce"
    else
        inject_result "mce-inject CE" 1 "Injection failed"
    fi
}

test_mce_inject_memory_error() {
    echo ""
    echo "Test: mce-inject Memory Controller Error"
    echo "----------------------------------------"

    if ! check_mce_inject; then
        inject_result "mce-inject Memory" 2 "mce-inject not available"
        return
    fi

    local mce_file="$RESULTS_DIR/test_mem.mce"

    cat > "$mce_file" << 'EOF'
# Memory Controller error
CPU 0
BANK 8
STATUS 0x9c00004000010080
MISC 0x0000000000000086
ADDR 0x00000000deadbeef
EOF

    echo "Injecting memory controller MCE..."

    # Clear trace
    echo > "$TRACE_DIR/trace"

    if mce-inject "$mce_file" 2>/dev/null; then
        sleep 2

        if wait_for_trace "mce_record" 5; then
            inject_result "mce-inject Memory" 0
        else
            inject_result "mce-inject Memory" 1 "Event not found"
        fi

        save_trace "mce_inject_mem"
    else
        inject_result "mce-inject Memory" 1 "Injection failed"
    fi
}

test_mce_inject_cache_error() {
    echo ""
    echo "Test: mce-inject Cache Error"
    echo "----------------------------"

    if ! check_mce_inject; then
        inject_result "mce-inject Cache" 2 "mce-inject not available"
        return
    fi

    local mce_file="$RESULTS_DIR/test_cache.mce"

    cat > "$mce_file" << 'EOF'
# L3 Cache error
CPU 0
BANK 3
STATUS 0x8c00004000010011
MISC 0x0000000000000000
ADDR 0x0000000000000000
EOF

    echo "Injecting cache MCE..."

    # Clear trace
    echo > "$TRACE_DIR/trace"

    if mce-inject "$mce_file" 2>/dev/null; then
        sleep 2

        if wait_for_trace "mce_record" 5; then
            inject_result "mce-inject Cache" 0
        else
            inject_result "mce-inject Cache" 1 "Event not found"
        fi

        save_trace "mce_inject_cache"
    else
        inject_result "mce-inject Cache" 1 "Injection failed"
    fi
}

# =========================================
# EINJ Processor Error Tests
# =========================================

test_einj_processor_correctable() {
    echo ""
    echo "Test: EINJ Processor Correctable Error"
    echo "--------------------------------------"

    if ! check_einj; then
        inject_result "EINJ Processor CE" 2 "EINJ not available"
        return
    fi

    # Check if processor CE is supported
    local available=$(get_einj_types)
    if ! echo "$available" | grep -q "$EINJ_PROC_CE"; then
        inject_result "EINJ Processor CE" 2 "Not supported by platform"
        return
    fi

    # Clear trace
    echo > "$TRACE_DIR/trace"

    if inject_einj_error "$EINJ_PROC_CE" "Processor Correctable"; then
        sleep 2

        if wait_for_trace "mce_record" 5; then
            inject_result "EINJ Processor CE - trace" 0
        else
            inject_result "EINJ Processor CE - trace" 1 "Event not found"
        fi

        if wait_for_trace "ras_mce_event_handler" 5; then
            inject_result "EINJ Processor CE - handler" 0
        else
            inject_result "EINJ Processor CE - handler" 1 "Handler not traced"
        fi

        save_trace "einj_proc_ce"
    fi
}

# =========================================
# CPU-Specific Tests
# =========================================

test_mce_specific_cpu() {
    echo ""
    echo "Test: MCE on Specific CPU"
    echo "-------------------------"

    if ! check_mce_inject; then
        inject_result "MCE Specific CPU" 2 "mce-inject not available"
        return
    fi

    # Get number of CPUs
    local num_cpus=$(nproc)
    local target_cpu=$((num_cpus - 1))

    if [ "$target_cpu" -lt 0 ]; then
        target_cpu=0
    fi

    local mce_file="$RESULTS_DIR/test_cpu${target_cpu}.mce"

    cat > "$mce_file" << EOF
# MCE on CPU $target_cpu
CPU $target_cpu
BANK 0
STATUS 0x8c00004000010005
MISC 0x0000000000000000
ADDR 0x0000000000000000
EOF

    echo "Injecting MCE on CPU $target_cpu..."

    # Clear trace
    echo > "$TRACE_DIR/trace"

    if mce-inject "$mce_file" 2>/dev/null; then
        sleep 2

        # Check that the event mentions the correct CPU
        if grep -q "cpu.*$target_cpu\|CPU $target_cpu" "$TRACE_DIR/trace" 2>/dev/null; then
            inject_result "MCE Specific CPU" 0
        else
            if wait_for_trace "mce_record" 5; then
                inject_result "MCE Specific CPU - event" 0
            else
                inject_result "MCE Specific CPU" 1 "Event not found"
            fi
        fi

        save_trace "mce_cpu_$target_cpu"
    else
        inject_result "MCE Specific CPU" 1 "Injection failed"
    fi
}

# =========================================
# Run Tests
# =========================================

echo ""
echo "Running MCE injection tests..."
echo ""

# Detect CPU type
echo "CPU Information:"
grep -m1 "vendor_id" /proc/cpuinfo || echo "Unknown vendor"
grep -m1 "model name" /proc/cpuinfo || echo "Unknown model"
echo ""

# Run tests
test_mce_inject_correctable
test_mce_inject_memory_error
test_mce_inject_cache_error
test_mce_specific_cpu
test_einj_processor_correctable

print_injection_summary
