#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
#
# RAS Daemon - Main Test Runner
# Runs all unit tests and generates a comprehensive report

set -e

SCRIPT_DIR="$(dirname "$0")"
RESULTS_DIR="${RESULTS_DIR:-/tmp/rasdaemon_tests}"
REPORT_FILE="$RESULTS_DIR/test_report_$(date +%Y%m%d_%H%M%S).txt"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TOTAL_TESTS=0
TOTAL_PASSED=0
TOTAL_FAILED=0

mkdir -p "$RESULTS_DIR"

echo "=========================================="
echo "RAS Daemon Complete Test Suite"
echo "=========================================="
echo ""
echo "Results directory: $RESULTS_DIR"
echo "Report file: $REPORT_FILE"
echo ""

# Header for report
cat > "$REPORT_FILE" << EOF
RAS Daemon Test Report
Generated: $(date)
System: $(uname -a)
========================================

EOF

# Function to run a test suite
run_test_suite() {
    local test_name="$1"
    local test_script="$2"

    echo -e "${BLUE}Running: $test_name${NC}"
    echo ""

    # Run test and capture output
    local output
    local exit_code
    output=$(bash "$test_script" 2>&1) || exit_code=$?

    echo "$output"

    # Extract pass/fail counts from output
    local passed=$(echo "$output" | grep -c "\[PASS\]" || echo "0")
    local failed=$(echo "$output" | grep -c "\[FAIL\]" || echo "0")

    TOTAL_PASSED=$((TOTAL_PASSED + passed))
    TOTAL_FAILED=$((TOTAL_FAILED + failed))
    TOTAL_TESTS=$((TOTAL_TESTS + passed + failed))

    # Add to report
    echo "" >> "$REPORT_FILE"
    echo "=== $test_name ===" >> "$REPORT_FILE"
    echo "$output" >> "$REPORT_FILE"

    echo ""
}

# Run all test suites
run_test_suite "MC (Memory Controller) Errors" "$SCRIPT_DIR/test_mc_errors.sh"
run_test_suite "MCE (Machine Check Exception) Errors" "$SCRIPT_DIR/test_mce_errors.sh"
run_test_suite "AER (PCIe) Errors" "$SCRIPT_DIR/test_aer_errors.sh"
run_test_suite "CXL Errors" "$SCRIPT_DIR/test_cxl_errors.sh"
run_test_suite "Other Error Types" "$SCRIPT_DIR/test_other_errors.sh"

# Print overall summary
echo ""
echo "=========================================="
echo "Overall Test Summary"
echo "=========================================="
echo "Total tests run: $TOTAL_TESTS"
echo -e "Total passed:    ${GREEN}$TOTAL_PASSED${NC}"
echo -e "Total failed:    ${RED}$TOTAL_FAILED${NC}"

# Add summary to report
cat >> "$REPORT_FILE" << EOF

==========================================
OVERALL SUMMARY
==========================================
Total tests run: $TOTAL_TESTS
Total passed:    $TOTAL_PASSED
Total failed:    $TOTAL_FAILED
EOF

if [ "$TOTAL_FAILED" -eq 0 ]; then
    echo ""
    echo -e "${GREEN}All tests passed!${NC}"
    echo ""
    echo "ALL TESTS PASSED" >> "$REPORT_FILE"
    exit 0
else
    echo ""
    echo -e "${RED}Some tests failed. Review the report for details.${NC}"
    echo ""
    echo "SOME TESTS FAILED" >> "$REPORT_FILE"
    exit 1
fi
