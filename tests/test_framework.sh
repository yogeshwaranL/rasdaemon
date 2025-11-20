#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
#
# RAS Daemon Unit Test Framework
# Common functions and utilities for testing rasdaemon error handlers

set -e

# Test configuration
RASDAEMON_BIN="${RASDAEMON_BIN:-../rasdaemon}"
TEST_DB="/tmp/test_ras.db"
TRACE_LOG="/tmp/test_trace.log"
RESULTS_DIR="/tmp/rasdaemon_tests"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Initialize test environment
init_tests() {
    echo "=========================================="
    echo "RAS Daemon Unit Test Framework"
    echo "=========================================="

    mkdir -p "$RESULTS_DIR"
    rm -f "$TEST_DB" "$TRACE_LOG"

    # Check if running as root (required for some tests)
    if [ "$EUID" -ne 0 ]; then
        echo -e "${YELLOW}Warning: Some tests may require root privileges${NC}"
    fi

    # Check if debugfs is mounted
    if ! mountpoint -q /sys/kernel/debug 2>/dev/null; then
        echo -e "${YELLOW}Warning: debugfs not mounted, some tests may fail${NC}"
    fi

    # Check for trace directories
    TRACE_DIR="/sys/kernel/debug/tracing"
    if [ ! -d "$TRACE_DIR" ]; then
        echo -e "${YELLOW}Warning: Trace directory not found at $TRACE_DIR${NC}"
    fi
}

# Print test result
print_result() {
    local name="$1"
    local result="$2"
    local message="$3"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [ "$result" -eq 0 ]; then
        echo -e "[${GREEN}PASS${NC}] $name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "[${RED}FAIL${NC}] $name: $message"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Assert functions
assert_file_exists() {
    local file="$1"
    local test_name="${2:-File exists: $file}"

    if [ -f "$file" ]; then
        print_result "$test_name" 0
        return 0
    else
        print_result "$test_name" 1 "File not found: $file"
        return 1
    fi
}

assert_file_contains() {
    local file="$1"
    local pattern="$2"
    local test_name="${3:-File contains pattern}"

    if grep -q "$pattern" "$file" 2>/dev/null; then
        print_result "$test_name" 0
        return 0
    else
        print_result "$test_name" 1 "Pattern not found: $pattern"
        return 1
    fi
}

assert_db_table_exists() {
    local db="$1"
    local table="$2"
    local test_name="${3:-Database table exists: $table}"

    if sqlite3 "$db" ".tables" 2>/dev/null | grep -q "$table"; then
        print_result "$test_name" 0
        return 0
    else
        print_result "$test_name" 1 "Table not found: $table"
        return 1
    fi
}

assert_db_has_records() {
    local db="$1"
    local table="$2"
    local test_name="${3:-Table has records: $table}"

    local count=$(sqlite3 "$db" "SELECT COUNT(*) FROM $table;" 2>/dev/null || echo "0")
    if [ "$count" -gt 0 ]; then
        print_result "$test_name" 0
        return 0
    else
        print_result "$test_name" 1 "No records in table"
        return 1
    fi
}

assert_command_succeeds() {
    local cmd="$1"
    local test_name="${2:-Command succeeds}"

    if eval "$cmd" > /dev/null 2>&1; then
        print_result "$test_name" 0
        return 0
    else
        print_result "$test_name" 1 "Command failed: $cmd"
        return 1
    fi
}

assert_trace_contains() {
    local pattern="$1"
    local test_name="${2:-Trace contains: $pattern}"

    if grep -q "$pattern" "$TRACE_LOG" 2>/dev/null; then
        print_result "$test_name" 0
        return 0
    else
        print_result "$test_name" 1 "Pattern not found in trace"
        return 1
    fi
}

# Check if error injection is supported
check_error_injection() {
    local dir="/sys/kernel/debug/apei/einj"

    if [ -d "$dir" ]; then
        return 0
    fi

    echo -e "${YELLOW}Note: APEI error injection not available${NC}"
    return 1
}

# Check if EDAC is available
check_edac() {
    local dir="/sys/devices/system/edac"

    if [ -d "$dir" ]; then
        return 0
    fi

    echo -e "${YELLOW}Note: EDAC not available${NC}"
    return 1
}

# Inject a fake MC event for testing
inject_mc_event() {
    local mc_index="${1:-0}"
    local error_type="${2:-0}" # 0=corrected

    # Check if fake_inject is available
    local inject_file="/sys/devices/system/edac/mc/mc${mc_index}/inject_addrmatch"

    if [ -f "$inject_file" ]; then
        echo 0 > "$inject_file"
        return 0
    fi

    return 1
}

# Print test summary
print_summary() {
    echo ""
    echo "=========================================="
    echo "Test Summary"
    echo "=========================================="
    echo "Tests run:    $TESTS_RUN"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
    echo ""

    if [ "$TESTS_FAILED" -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        return 1
    fi
}

# Run all tests in a directory
run_test_suite() {
    local test_dir="${1:-.}"

    for test_file in "$test_dir"/test_*.sh; do
        if [ -f "$test_file" ] && [ "$test_file" != "$0" ]; then
            echo ""
            echo "Running: $test_file"
            echo "------------------------------------------"
            bash "$test_file"
        fi
    done
}

# Export functions for use in test scripts
export -f init_tests
export -f print_result
export -f print_summary
export -f assert_file_exists
export -f assert_file_contains
export -f assert_db_table_exists
export -f assert_db_has_records
export -f assert_command_succeeds
export -f assert_trace_contains
export -f check_error_injection
export -f check_edac
export -f inject_mc_event

# Export variables
export RASDAEMON_BIN
export TEST_DB
export TRACE_LOG
export RESULTS_DIR
export TESTS_RUN
export TESTS_PASSED
export TESTS_FAILED
