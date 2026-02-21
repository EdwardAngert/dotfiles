#!/usr/bin/env bash
# tests/test_utils.sh - Unit tests for lib/utils.sh
#
# Run with: ./tests/test_utils.sh
# Or via test runner: ./tests/run_tests.sh

set -euo pipefail

# ==============================================================================
# Test Framework
# ==============================================================================

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Assert functions
assert_equals() {
  local expected="$1"
  local actual="$2"
  local message="${3:-}"

  if [[ "$expected" == "$actual" ]]; then
    return 0
  else
    echo "  Expected: '$expected'"
    echo "  Actual:   '$actual'"
    return 1
  fi
}

assert_true() {
  local condition="$1"
  local message="${2:-}"

  if eval "$condition"; then
    return 0
  else
    echo "  Condition failed: $condition"
    return 1
  fi
}

assert_false() {
  local condition="$1"
  local message="${2:-}"

  if ! eval "$condition"; then
    return 0
  else
    echo "  Condition should have been false: $condition"
    return 1
  fi
}

assert_file_exists() {
  local file="$1"

  if [[ -f "$file" ]]; then
    return 0
  else
    echo "  File does not exist: $file"
    return 1
  fi
}

assert_file_not_exists() {
  local file="$1"

  if [[ ! -f "$file" ]]; then
    return 0
  else
    echo "  File should not exist: $file"
    return 1
  fi
}

# Test runner
run_test() {
  local test_name="$1"
  local test_func="$2"

  TESTS_RUN=$((TESTS_RUN + 1))
  echo -n "  $test_name... "

  if $test_func; then
    echo -e "${GREEN}PASS${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}FAIL${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# ==============================================================================
# Setup
# ==============================================================================

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"

# Create temp directory for tests
TEST_TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_TEMP_DIR"' EXIT

# Source the library being tested
source "$DOTFILES_DIR/lib/utils.sh"

# ==============================================================================
# Tests for check_command
# ==============================================================================

test_check_command_finds_existing() {
  check_command bash
}

test_check_command_returns_false_for_missing() {
  ! check_command nonexistent_command_12345
}

test_check_command_returns_error_for_empty() {
  local result
  result=$(check_command "" 2>&1) || true
  [[ "$result" == *"No command specified"* ]]
}

# ==============================================================================
# Tests for OS Detection
# ==============================================================================

test_os_is_detected() {
  [[ -n "$OS" ]]
}

test_arch_is_detected() {
  [[ -n "$ARCH" ]]
}

# ==============================================================================
# Tests for Version Comparison
# ==============================================================================

test_version_compare_equal() {
  version_compare "1.0.0" "1.0.0"
}

test_version_compare_greater() {
  version_compare "2.0.0" "1.0.0"
}

test_version_compare_less() {
  ! version_compare "1.0.0" "2.0.0"
}

test_version_compare_with_v_prefix() {
  version_compare "v1.5.0" "1.4.0"
}

# ==============================================================================
# Tests for Dry Run Mode
# ==============================================================================

test_dry_run_safe_mkdir_no_create() {
  DRY_RUN=true
  local test_dir="$TEST_TEMP_DIR/dry_run_test_dir"

  safe_mkdir "$test_dir"

  # Directory should NOT be created in dry run mode
  [[ ! -d "$test_dir" ]]
}

test_dry_run_safe_symlink_no_create() {
  DRY_RUN=true
  local source_file="$TEST_TEMP_DIR/source_file"
  local target_link="$TEST_TEMP_DIR/target_link"

  echo "test content" > "$source_file"
  safe_symlink "$source_file" "$target_link"

  # Symlink should NOT be created in dry run mode
  [[ ! -L "$target_link" ]]
}

test_dry_run_safe_copy_no_create() {
  DRY_RUN=true
  local source_file="$TEST_TEMP_DIR/copy_source"
  local target_file="$TEST_TEMP_DIR/copy_target"

  echo "test content" > "$source_file"
  safe_copy "$source_file" "$target_file"

  # File should NOT be copied in dry run mode
  [[ ! -f "$target_file" ]]
}

# ==============================================================================
# Tests for File Operations (non-dry-run)
# ==============================================================================

test_safe_mkdir_creates_directory() {
  DRY_RUN=false
  local test_dir="$TEST_TEMP_DIR/real_test_dir"

  safe_mkdir "$test_dir"

  [[ -d "$test_dir" ]]
}

test_safe_symlink_creates_link() {
  DRY_RUN=false
  local source_file="$TEST_TEMP_DIR/link_source"
  local target_link="$TEST_TEMP_DIR/link_target"

  echo "link content" > "$source_file"
  safe_symlink "$source_file" "$target_link"

  [[ -L "$target_link" ]] && [[ "$(readlink "$target_link")" == "$source_file" ]]
}

test_safe_copy_copies_file() {
  DRY_RUN=false
  local source_file="$TEST_TEMP_DIR/real_copy_source"
  local target_file="$TEST_TEMP_DIR/real_copy_target"

  echo "copy content" > "$source_file"
  safe_copy "$source_file" "$target_file"

  [[ -f "$target_file" ]] && [[ "$(cat "$target_file")" == "copy content" ]]
}

# ==============================================================================
# Tests for Backup
# ==============================================================================

test_backup_if_exists_creates_backup() {
  DRY_RUN=false
  local test_file="$TEST_TEMP_DIR/file_to_backup"

  echo "backup content" > "$test_file"
  backup_if_exists "$test_file"

  # Original should be gone, backup should exist
  [[ ! -f "$test_file" ]] && ls "$TEST_TEMP_DIR/file_to_backup.backup."* &>/dev/null
}

test_backup_if_exists_returns_1_for_missing() {
  DRY_RUN=false
  local missing_file="$TEST_TEMP_DIR/nonexistent_file"

  local result
  result=$(backup_if_exists "$missing_file" 2>&1; echo $?)
  [[ "${result: -1}" == "1" ]]
}

# ==============================================================================
# Run Tests
# ==============================================================================

echo ""
echo "Running utils.sh unit tests..."
echo "=============================="
echo ""

echo "check_command tests:"
run_test "finds existing commands" test_check_command_finds_existing
run_test "returns false for missing commands" test_check_command_returns_false_for_missing
run_test "returns error for empty argument" test_check_command_returns_error_for_empty

echo ""
echo "OS detection tests:"
run_test "OS is detected" test_os_is_detected
run_test "ARCH is detected" test_arch_is_detected

echo ""
echo "Version comparison tests:"
run_test "equal versions" test_version_compare_equal
run_test "greater version" test_version_compare_greater
run_test "lesser version" test_version_compare_less
run_test "handles v prefix" test_version_compare_with_v_prefix

echo ""
echo "Dry run mode tests:"
run_test "safe_mkdir doesn't create in dry run" test_dry_run_safe_mkdir_no_create
run_test "safe_symlink doesn't create in dry run" test_dry_run_safe_symlink_no_create
run_test "safe_copy doesn't copy in dry run" test_dry_run_safe_copy_no_create

echo ""
echo "File operations tests:"
run_test "safe_mkdir creates directory" test_safe_mkdir_creates_directory
run_test "safe_symlink creates link" test_safe_symlink_creates_link
run_test "safe_copy copies file" test_safe_copy_copies_file

echo ""
echo "Backup tests:"
run_test "backup_if_exists creates backup" test_backup_if_exists_creates_backup
run_test "backup_if_exists returns 1 for missing file" test_backup_if_exists_returns_1_for_missing

# ==============================================================================
# Summary
# ==============================================================================

echo ""
echo "=============================="
echo "Tests: $TESTS_RUN | Passed: $TESTS_PASSED | Failed: $TESTS_FAILED"

if [[ $TESTS_FAILED -gt 0 ]]; then
  echo -e "${RED}Some tests failed!${NC}"
  exit 1
else
  echo -e "${GREEN}All tests passed!${NC}"
  exit 0
fi
