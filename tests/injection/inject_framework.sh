#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
#
# RAS Daemon Error Injection Test Framework
#
# WARNING: These tests inject real hardware errors and may:
# - Cause system instability
# - Trigger kernel panics (for fatal errors)
# - Require system reboot
# - Only work on specific hardware/platforms
#
# Use with caution in test environments only!

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Paths
EINJ_DIR="/sys/kernel/debug/apei/einj"
EDAC_DIR="/sys/devices/system/edac"
TRACE_DIR="/sys/kernel/debug/tracing"
RESULTS_DIR="${RESULTS_DIR:-/tmp/rasdaemon_injection_tests}"

# Test counters
INJECT_TESTS_RUN=0
INJECT_TESTS_PASSED=0
INJECT_TESTS_FAILED=0
INJECT_TESTS_SKIPPED=0

# Safety checks
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}ERROR: Error injection tests must be run as root${NC}"
        exit 1
    fi
}

check_dangerous() {
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}WARNING: ERROR INJECTION TESTS${NC}"
    echo -e "${RED}========================================${NC}"
    echo ""
    echo "These tests inject REAL hardware errors!"
    echo "This may cause:"
    echo "  - System instability"
    echo "  - Kernel panics"
    echo "  - Data corruption"
    echo "  - Need for system reboot"
    echo ""
    echo -e "${YELLOW}Only run in isolated test environments!${NC}"
    echo ""

    if [ "$FORCE_INJECT" != "1" ]; then
        read -p "Type 'INJECT' to continue: " confirm
        if [ "$confirm" != "INJECT" ]; then
            echo "Aborted."
            exit 1
        fi
    fi
}

# Initialize test environment
init_injection_tests() {
    check_root
    check_dangerous

    mkdir -p "$RESULTS_DIR"

    echo ""
    echo -e "${BLUE}Initializing error injection tests...${NC}"
    echo ""

    # Check for rasdaemon
    if ! pgrep -x rasdaemon > /dev/null; then
        echo -e "${YELLOW}Warning: rasdaemon is not running${NC}"
        echo "Start with: rasdaemon -f"
    fi

    # Enable tracing
    if [ -d "$TRACE_DIR" ]; then
        echo 1 > "$TRACE_DIR/tracing_on"
        echo > "$TRACE_DIR/trace"
        echo 1 > "$TRACE_DIR/events/ras/enable" 2>/dev/null || true
        echo 1 > "$TRACE_DIR/events/mce/enable" 2>/dev/null || true
    fi
}

# Check EINJ availability
check_einj() {
    if [ ! -d "$EINJ_DIR" ]; then
        echo -e "${YELLOW}EINJ not available. Try: modprobe einj${NC}"
        return 1
    fi

    if [ ! -f "$EINJ_DIR/available_error_type" ]; then
        echo -e "${YELLOW}EINJ available_error_type not found${NC}"
        return 1
    fi

    return 0
}

# Check EDAC availability
check_edac() {
    if [ ! -d "$EDAC_DIR/mc" ]; then
        echo -e "${YELLOW}EDAC MC not available${NC}"
        return 1
    fi
    return 0
}

# Check mce-inject tool
check_mce_inject() {
    if ! command -v mce-inject &> /dev/null; then
        echo -e "${YELLOW}mce-inject not found. Install mce-inject package.${NC}"
        return 1
    fi
    return 0
}

# Print test result
inject_result() {
    local name="$1"
    local result="$2"
    local message="$3"

    INJECT_TESTS_RUN=$((INJECT_TESTS_RUN + 1))

    case "$result" in
        0)
            echo -e "[${GREEN}PASS${NC}] $name"
            INJECT_TESTS_PASSED=$((INJECT_TESTS_PASSED + 1))
            ;;
        1)
            echo -e "[${RED}FAIL${NC}] $name: $message"
            INJECT_TESTS_FAILED=$((INJECT_TESTS_FAILED + 1))
            ;;
        2)
            echo -e "[${YELLOW}SKIP${NC}] $name: $message"
            INJECT_TESTS_SKIPPED=$((INJECT_TESTS_SKIPPED + 1))
            ;;
    esac
}

# Wait for event to appear in trace
wait_for_trace() {
    local pattern="$1"
    local timeout="${2:-5}"
    local i

    for i in $(seq 1 $timeout); do
        if grep -q "$pattern" "$TRACE_DIR/trace" 2>/dev/null; then
            return 0
        fi
        sleep 1
    done

    return 1
}

# Wait for event in database
wait_for_db_event() {
    local table="$1"
    local timeout="${2:-5}"
    local db="/var/lib/rasdaemon/ras-mc_event.db"
    local i

    if [ ! -f "$db" ]; then
        db="/var/log/ras/ras.db"
    fi

    if [ ! -f "$db" ]; then
        return 1
    fi

    local initial_count=$(sqlite3 "$db" "SELECT COUNT(*) FROM $table;" 2>/dev/null || echo "0")

    for i in $(seq 1 $timeout); do
        local current_count=$(sqlite3 "$db" "SELECT COUNT(*) FROM $table;" 2>/dev/null || echo "0")
        if [ "$current_count" -gt "$initial_count" ]; then
            return 0
        fi
        sleep 1
    done

    return 1
}

# Get EINJ supported error types
get_einj_types() {
    if [ -f "$EINJ_DIR/available_error_type" ]; then
        cat "$EINJ_DIR/available_error_type"
    fi
}

# Inject error via EINJ
inject_einj_error() {
    local error_type="$1"
    local error_name="$2"

    if ! check_einj; then
        inject_result "EINJ $error_name" 2 "EINJ not available"
        return 1
    fi

    # Check if error type is supported
    local available=$(cat "$EINJ_DIR/available_error_type" 2>/dev/null)
    if ! echo "$available" | grep -q "$error_type"; then
        inject_result "EINJ $error_name" 2 "Error type $error_type not supported"
        return 1
    fi

    echo "Injecting $error_name (type $error_type)..."

    # Set error type
    echo "$error_type" > "$EINJ_DIR/error_type"

    # Trigger injection
    echo 1 > "$EINJ_DIR/error_inject"

    return 0
}

# Save trace output
save_trace() {
    local name="$1"
    local output_file="$RESULTS_DIR/${name}_trace.txt"

    if [ -f "$TRACE_DIR/trace" ]; then
        cp "$TRACE_DIR/trace" "$output_file"
        echo "Trace saved to: $output_file"
    fi
}

# Print injection test summary
print_injection_summary() {
    echo ""
    echo "=========================================="
    echo "Error Injection Test Summary"
    echo "=========================================="
    echo "Tests run:     $INJECT_TESTS_RUN"
    echo -e "Tests passed:  ${GREEN}$INJECT_TESTS_PASSED${NC}"
    echo -e "Tests failed:  ${RED}$INJECT_TESTS_FAILED${NC}"
    echo -e "Tests skipped: ${YELLOW}$INJECT_TESTS_SKIPPED${NC}"
    echo ""
    echo "Results saved to: $RESULTS_DIR"

    if [ "$INJECT_TESTS_FAILED" -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# Export functions
export -f check_root
export -f check_einj
export -f check_edac
export -f check_mce_inject
export -f inject_result
export -f wait_for_trace
export -f wait_for_db_event
export -f get_einj_types
export -f inject_einj_error
export -f save_trace
export -f init_injection_tests
export -f print_injection_summary

# Export variables
export EINJ_DIR
export EDAC_DIR
export TRACE_DIR
export RESULTS_DIR
export INJECT_TESTS_RUN
export INJECT_TESTS_PASSED
export INJECT_TESTS_FAILED
export INJECT_TESTS_SKIPPED
