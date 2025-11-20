#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Memory Error Injection Tests
# Uses APEI EINJ and EDAC fake_inject to inject memory errors

source "$(dirname "$0")/inject_framework.sh"

echo "=========================================="
echo "Memory Error Injection Tests"
echo "=========================================="

init_injection_tests

# EINJ error type codes
EINJ_MEM_CE=0x8          # Memory Correctable
EINJ_MEM_UCE_NONFATAL=0x10  # Memory Uncorrectable non-fatal
EINJ_MEM_UCE_FATAL=0x20     # Memory Uncorrectable fatal

# =========================================
# EINJ Memory Error Tests
# =========================================

test_einj_memory_correctable() {
    echo ""
    echo "Test: EINJ Memory Correctable Error"
    echo "-----------------------------------"

    if ! check_einj; then
        inject_result "EINJ Memory CE" 2 "EINJ not available"
        return
    fi

    # Clear trace
    echo > "$TRACE_DIR/trace"

    # Inject correctable memory error
    if inject_einj_error "$EINJ_MEM_CE" "Memory Correctable"; then
        # Wait for event
        sleep 2

        # Check trace for mc_event
        if wait_for_trace "mc_event" 5; then
            inject_result "EINJ Memory CE - trace event" 0
        else
            inject_result "EINJ Memory CE - trace event" 1 "Event not found in trace"
        fi

        # Check for rasdaemon handler
        if wait_for_trace "ras_mc_event_handler" 5; then
            inject_result "EINJ Memory CE - handler called" 0
        else
            inject_result "EINJ Memory CE - handler called" 1 "Handler not traced"
        fi

        # Check database
        if wait_for_db_event "mc_event" 5; then
            inject_result "EINJ Memory CE - database" 0
        else
            inject_result "EINJ Memory CE - database" 1 "Event not in database"
        fi

        save_trace "einj_mem_ce"
    fi
}

test_einj_memory_uncorrectable() {
    echo ""
    echo "Test: EINJ Memory Uncorrectable Error (Non-Fatal)"
    echo "-------------------------------------------------"
    echo -e "${YELLOW}WARNING: This may cause system instability${NC}"

    if ! check_einj; then
        inject_result "EINJ Memory UCE" 2 "EINJ not available"
        return
    fi

    # Check if UCE is supported
    local available=$(get_einj_types)
    if ! echo "$available" | grep -q "$EINJ_MEM_UCE_NONFATAL"; then
        inject_result "EINJ Memory UCE" 2 "UCE not supported by platform"
        return
    fi

    # Clear trace
    echo > "$TRACE_DIR/trace"

    # Inject uncorrectable memory error
    if inject_einj_error "$EINJ_MEM_UCE_NONFATAL" "Memory Uncorrectable"; then
        sleep 2

        # Check trace
        if wait_for_trace "mc_event\|mce_record" 5; then
            inject_result "EINJ Memory UCE - trace event" 0
        else
            inject_result "EINJ Memory UCE - trace event" 1 "Event not found"
        fi

        save_trace "einj_mem_uce"
    fi
}

# =========================================
# EDAC Fake Inject Tests
# =========================================

test_edac_fake_inject() {
    echo ""
    echo "Test: EDAC Fake Inject"
    echo "----------------------"

    if ! check_edac; then
        inject_result "EDAC Fake Inject" 2 "EDAC not available"
        return
    fi

    # Find MC with fake_inject support
    local mc_found=0
    for mc in "$EDAC_DIR"/mc/mc*; do
        if [ -d "$mc" ]; then
            local inject_file=""

            # Try different inject file names
            for name in fake_inject inject_addrmatch; do
                if [ -f "$mc/$name" ]; then
                    inject_file="$mc/$name"
                    break
                fi
            done

            if [ -n "$inject_file" ]; then
                mc_found=1
                echo "Using: $inject_file"

                # Clear trace
                echo > "$TRACE_DIR/trace"

                # Inject
                echo 0 > "$inject_file" 2>/dev/null || {
                    inject_result "EDAC Fake Inject" 1 "Write failed"
                    continue
                }

                sleep 2

                # Check trace
                if wait_for_trace "mc_event" 5; then
                    inject_result "EDAC Fake Inject - trace event" 0
                else
                    inject_result "EDAC Fake Inject - trace event" 1 "Event not found"
                fi

                # Check handler
                if wait_for_trace "ras_mc_event_handler" 5; then
                    inject_result "EDAC Fake Inject - handler" 0
                else
                    inject_result "EDAC Fake Inject - handler" 1 "Handler not traced"
                fi

                save_trace "edac_fake_inject"
                break
            fi
        fi
    done

    if [ "$mc_found" -eq 0 ]; then
        inject_result "EDAC Fake Inject" 2 "No MC with fake_inject support"
    fi
}

# =========================================
# Memory Address Injection Test
# =========================================

test_einj_specific_address() {
    echo ""
    echo "Test: EINJ Specific Address Injection"
    echo "-------------------------------------"

    if ! check_einj; then
        inject_result "EINJ Address Inject" 2 "EINJ not available"
        return
    fi

    # Check for address parameters
    if [ ! -f "$EINJ_DIR/param1" ]; then
        inject_result "EINJ Address Inject" 2 "Address parameters not supported"
        return
    fi

    # Get a valid physical address (first 1MB should be safe)
    local addr=0x100000

    echo "Injecting error at address: $addr"

    # Set parameters
    echo "$EINJ_MEM_CE" > "$EINJ_DIR/error_type"
    echo "$addr" > "$EINJ_DIR/param1"  # Physical address
    echo 0xfffffffffffff000 > "$EINJ_DIR/param2"  # Address mask

    # Clear trace
    echo > "$TRACE_DIR/trace"

    # Inject
    echo 1 > "$EINJ_DIR/error_inject"

    sleep 2

    if wait_for_trace "mc_event" 5; then
        # Check if address appears in trace
        if grep -q "address.*$addr\|$addr" "$TRACE_DIR/trace" 2>/dev/null; then
            inject_result "EINJ Address Inject" 0
        else
            inject_result "EINJ Address Inject - address" 1 "Address not in event"
        fi
    else
        inject_result "EINJ Address Inject" 1 "Event not found"
    fi

    save_trace "einj_address"
}

# =========================================
# Run Tests
# =========================================

echo ""
echo "Running memory error injection tests..."
echo ""

# List available EINJ error types
if check_einj; then
    echo "Available EINJ error types:"
    get_einj_types
    echo ""
fi

# Run tests
test_edac_fake_inject
test_einj_memory_correctable
test_einj_specific_address

# Optionally test UCE (dangerous)
if [ "$TEST_UCE" = "1" ]; then
    test_einj_memory_uncorrectable
else
    echo ""
    echo -e "${YELLOW}Skipping UCE test (set TEST_UCE=1 to enable)${NC}"
fi

print_injection_summary
