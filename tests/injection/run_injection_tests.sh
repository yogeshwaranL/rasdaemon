#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
#
# RAS Daemon Error Injection Test Runner
# Runs all error injection tests

SCRIPT_DIR="$(dirname "$0")"
RESULTS_DIR="${RESULTS_DIR:-/tmp/rasdaemon_injection_tests}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${RED}========================================${NC}"
echo -e "${RED}RAS DAEMON ERROR INJECTION TEST SUITE${NC}"
echo -e "${RED}========================================${NC}"
echo ""
echo -e "${YELLOW}WARNING: These tests inject REAL hardware errors!${NC}"
echo ""
echo "Options:"
echo "  FORCE_INJECT=1  - Skip confirmation prompts"
echo "  TEST_UCE=1      - Include uncorrectable error tests"
echo ""

# Check root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}ERROR: Must be run as root${NC}"
    exit 1
fi

mkdir -p "$RESULTS_DIR"

# Timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="$RESULTS_DIR/injection_report_$TIMESTAMP.txt"

# Header for report
cat > "$REPORT_FILE" << EOF
RAS Daemon Error Injection Test Report
Generated: $(date)
System: $(uname -a)
==========================================

EOF

# Total counters
TOTAL_PASSED=0
TOTAL_FAILED=0
TOTAL_SKIPPED=0

# Run a test suite
run_injection_suite() {
    local name="$1"
    local script="$2"

    if [ ! -f "$script" ]; then
        echo -e "${RED}Script not found: $script${NC}"
        return
    fi

    echo ""
    echo -e "${BLUE}Running: $name${NC}"
    echo ""

    # Run test and capture output
    local output
    output=$(bash "$script" 2>&1)
    local exit_code=$?

    echo "$output"

    # Extract counts
    local passed=$(echo "$output" | grep -c "\[PASS\]" || echo "0")
    local failed=$(echo "$output" | grep -c "\[FAIL\]" || echo "0")
    local skipped=$(echo "$output" | grep -c "\[SKIP\]" || echo "0")

    TOTAL_PASSED=$((TOTAL_PASSED + passed))
    TOTAL_FAILED=$((TOTAL_FAILED + failed))
    TOTAL_SKIPPED=$((TOTAL_SKIPPED + skipped))

    # Add to report
    echo "" >> "$REPORT_FILE"
    echo "=== $name ===" >> "$REPORT_FILE"
    echo "$output" >> "$REPORT_FILE"
}

# Run all injection test suites
run_injection_suite "Memory Error Injection" "$SCRIPT_DIR/inject_memory_errors.sh"
run_injection_suite "MCE Injection" "$SCRIPT_DIR/inject_mce_errors.sh"
run_injection_suite "PCIe AER Injection" "$SCRIPT_DIR/inject_pcie_errors.sh"

# Print overall summary
echo ""
echo "=========================================="
echo "Overall Injection Test Summary"
echo "=========================================="
echo "Total passed:  $TOTAL_PASSED"
echo -e "Total failed:  ${RED}$TOTAL_FAILED${NC}"
echo -e "Total skipped: ${YELLOW}$TOTAL_SKIPPED${NC}"
echo ""
echo "Report: $REPORT_FILE"
echo "Traces: $RESULTS_DIR/*_trace.txt"

# Add summary to report
cat >> "$REPORT_FILE" << EOF

==========================================
OVERALL SUMMARY
==========================================
Total passed:  $TOTAL_PASSED
Total failed:  $TOTAL_FAILED
Total skipped: $TOTAL_SKIPPED
EOF

if [ "$TOTAL_FAILED" -eq 0 ]; then
    echo ""
    echo -e "${GREEN}All injection tests completed!${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}Some injection tests failed!${NC}"
    exit 1
fi
