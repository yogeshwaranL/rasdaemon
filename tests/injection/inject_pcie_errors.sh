#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
#
# PCIe AER Error Injection Tests
# Uses EINJ and aer-inject to inject PCIe errors

source "$(dirname "$0")/inject_framework.sh"

echo "=========================================="
echo "PCIe AER Error Injection Tests"
echo "=========================================="

init_injection_tests

# EINJ error type codes for PCIe
EINJ_PCIE_CE=0x40        # PCI Express Correctable
EINJ_PCIE_UCE=0x80       # PCI Express Uncorrectable non-fatal
EINJ_PCIE_UCE_FATAL=0x100 # PCI Express Uncorrectable fatal

# =========================================
# AER Injection Support Check
# =========================================

check_aer_inject() {
    if command -v aer-inject &> /dev/null; then
        return 0
    fi

    # Check for kernel module
    if [ -d "/sys/kernel/debug/aer_inject" ]; then
        return 0
    fi

    echo -e "${YELLOW}aer-inject not available${NC}"
    return 1
}

find_aer_device() {
    # Find a PCIe device with AER capability
    for dev in /sys/bus/pci/devices/*; do
        if [ -d "$dev" ]; then
            local dev_name=$(basename "$dev")

            # Check for AER capability
            if [ -d "$dev/aer_dev_correctable" ] || [ -f "$dev/aer_stats/dev_cor_errs" ]; then
                echo "$dev_name"
                return 0
            fi
        fi
    done

    return 1
}

# =========================================
# EINJ PCIe Error Tests
# =========================================

test_einj_pcie_correctable() {
    echo ""
    echo "Test: EINJ PCIe Correctable Error"
    echo "---------------------------------"

    if ! check_einj; then
        inject_result "EINJ PCIe CE" 2 "EINJ not available"
        return
    fi

    # Check if PCIe CE is supported
    local available=$(get_einj_types)
    if ! echo "$available" | grep -q "$EINJ_PCIE_CE"; then
        inject_result "EINJ PCIe CE" 2 "Not supported by platform"
        return
    fi

    # Clear trace
    echo > "$TRACE_DIR/trace"

    if inject_einj_error "$EINJ_PCIE_CE" "PCIe Correctable"; then
        sleep 2

        if wait_for_trace "aer_event" 5; then
            inject_result "EINJ PCIe CE - trace" 0
        else
            inject_result "EINJ PCIe CE - trace" 1 "Event not found"
        fi

        if wait_for_trace "ras_aer_event_handler" 5; then
            inject_result "EINJ PCIe CE - handler" 0
        else
            inject_result "EINJ PCIe CE - handler" 1 "Handler not traced"
        fi

        save_trace "einj_pcie_ce"
    fi
}

test_einj_pcie_uncorrectable() {
    echo ""
    echo "Test: EINJ PCIe Uncorrectable Error"
    echo "-----------------------------------"
    echo -e "${YELLOW}WARNING: May cause device errors${NC}"

    if ! check_einj; then
        inject_result "EINJ PCIe UCE" 2 "EINJ not available"
        return
    fi

    local available=$(get_einj_types)
    if ! echo "$available" | grep -q "$EINJ_PCIE_UCE"; then
        inject_result "EINJ PCIe UCE" 2 "Not supported by platform"
        return
    fi

    # Clear trace
    echo > "$TRACE_DIR/trace"

    if inject_einj_error "$EINJ_PCIE_UCE" "PCIe Uncorrectable"; then
        sleep 2

        if wait_for_trace "aer_event" 5; then
            inject_result "EINJ PCIe UCE - trace" 0
        else
            inject_result "EINJ PCIe UCE - trace" 1 "Event not found"
        fi

        save_trace "einj_pcie_uce"
    fi
}

# =========================================
# aer-inject Tests
# =========================================

test_aer_inject_correctable() {
    echo ""
    echo "Test: aer-inject Correctable Error"
    echo "----------------------------------"

    if ! check_aer_inject; then
        inject_result "aer-inject CE" 2 "aer-inject not available"
        return
    fi

    # Find AER-capable device
    local device=$(find_aer_device)
    if [ -z "$device" ]; then
        inject_result "aer-inject CE" 2 "No AER-capable device found"
        return
    fi

    echo "Target device: $device"

    local aer_file="$RESULTS_DIR/aer_ce.txt"

    # Create injection file (format depends on tool version)
    cat > "$aer_file" << EOF
AER
$device
COR_ERR
RCVR
EOF

    # Clear trace
    echo > "$TRACE_DIR/trace"

    # Try to inject
    if aer-inject "$aer_file" 2>/dev/null; then
        sleep 2

        if wait_for_trace "aer_event" 5; then
            inject_result "aer-inject CE - trace" 0
        else
            inject_result "aer-inject CE - trace" 1 "Event not found"
        fi

        if wait_for_trace "ras_aer_event_handler" 5; then
            inject_result "aer-inject CE - handler" 0
        else
            inject_result "aer-inject CE - handler" 1 "Handler not traced"
        fi

        save_trace "aer_inject_ce"
    else
        # Try alternative method via sysfs
        local inject_path="/sys/kernel/debug/aer_inject"
        if [ -d "$inject_path" ]; then
            echo "$device" > "$inject_path/dev"
            echo "cor" > "$inject_path/error_type"
            echo "receiver_error" > "$inject_path/error"
            echo 1 > "$inject_path/inject"

            sleep 2

            if wait_for_trace "aer_event" 5; then
                inject_result "aer-inject CE (sysfs)" 0
            else
                inject_result "aer-inject CE (sysfs)" 1 "Event not found"
            fi

            save_trace "aer_inject_ce_sysfs"
        else
            inject_result "aer-inject CE" 1 "Injection failed"
        fi
    fi
}

# =========================================
# AER Statistics Test
# =========================================

test_aer_stats() {
    echo ""
    echo "Test: AER Statistics Check"
    echo "--------------------------"

    local device=$(find_aer_device)
    if [ -z "$device" ]; then
        inject_result "AER Stats" 2 "No AER-capable device found"
        return
    fi

    local stats_dir="/sys/bus/pci/devices/$device/aer_stats"
    if [ -d "$stats_dir" ]; then
        echo "AER stats for $device:"
        for stat in "$stats_dir"/*; do
            if [ -f "$stat" ]; then
                echo "  $(basename "$stat"): $(cat "$stat")"
            fi
        done
        inject_result "AER Stats" 0
    else
        inject_result "AER Stats" 2 "No AER stats available"
    fi
}

# =========================================
# Run Tests
# =========================================

echo ""
echo "Running PCIe AER injection tests..."
echo ""

# List PCIe devices with AER
echo "PCIe devices with AER support:"
for dev in /sys/bus/pci/devices/*; do
    if [ -d "$dev/aer_dev_correctable" ]; then
        echo "  $(basename "$dev")"
    fi
done
echo ""

# Run tests
test_aer_stats
test_einj_pcie_correctable
test_aer_inject_correctable

# Optionally test UCE
if [ "$TEST_UCE" = "1" ]; then
    test_einj_pcie_uncorrectable
else
    echo ""
    echo -e "${YELLOW}Skipping UCE test (set TEST_UCE=1 to enable)${NC}"
fi

print_injection_summary
