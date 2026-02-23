#!/usr/bin/env bash
# tests/run_tests.sh - Test runner for dotfiles
#
# Runs all tests:
# 1. Shellcheck on all .sh files
# 2. Bash syntax validation
# 3. Unit tests
#
# Usage:
#   ./tests/run_tests.sh [--quick]
#
# Options:
#   --quick  Skip shellcheck (faster, for development)

set -euo pipefail

# ==============================================================================
# Configuration
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Options
QUICK_MODE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --quick) QUICK_MODE=true ;;
    --help)
      echo "Usage: $0 [--quick]"
      echo ""
      echo "Options:"
      echo "  --quick  Skip shellcheck (faster)"
      exit 0
      ;;
    *) ;;
  esac
  shift
done

# Track overall status
OVERALL_STATUS=0

# ==============================================================================
# Helper Functions
# ==============================================================================

print_header() {
  echo ""
  echo -e "${BOLD}${BLUE}=== $1 ===${NC}"
  echo ""
}

print_success() {
  echo -e "${GREEN}✓${NC} $1"
}

print_error() {
  echo -e "${RED}✗${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}!${NC} $1"
}

# ==============================================================================
# Shellcheck
# ==============================================================================

run_shellcheck() {
  print_header "Running Shellcheck"

  if ! command -v shellcheck &>/dev/null; then
    print_warning "shellcheck not installed, skipping"
    print_warning "Install with: brew install shellcheck (macOS) or apt install shellcheck (Linux)"
    return 0
  fi

  local files_checked=0
  local files_failed=0

  while IFS= read -r -d '' file; do
    files_checked=$((files_checked + 1))

    if shellcheck --severity=warning --shell=bash \
        -e SC1090 \
        -e SC1091 \
        -e SC2034 \
        "$file" 2>/dev/null; then
      print_success "$file"
    else
      print_error "$file"
      files_failed=$((files_failed + 1))
    fi
  done < <(find "$DOTFILES_DIR" -name "*.sh" -type f -not -path "*/\.*" -print0)

  echo ""
  echo "Checked $files_checked files, $files_failed failed"

  if [[ $files_failed -gt 0 ]]; then
    OVERALL_STATUS=1
    return 1
  fi

  return 0
}

# ==============================================================================
# Bash Syntax Validation
# ==============================================================================

run_syntax_check() {
  print_header "Checking Bash Syntax"

  local files_checked=0
  local files_failed=0

  while IFS= read -r -d '' file; do
    files_checked=$((files_checked + 1))

    if bash -n "$file" 2>/dev/null; then
      print_success "$file"
    else
      print_error "$file"
      bash -n "$file" 2>&1 | head -5
      files_failed=$((files_failed + 1))
    fi
  done < <(find "$DOTFILES_DIR" -name "*.sh" -type f -not -path "*/\.*" -print0)

  echo ""
  echo "Checked $files_checked files, $files_failed failed"

  if [[ $files_failed -gt 0 ]]; then
    OVERALL_STATUS=1
    return 1
  fi

  return 0
}

# ==============================================================================
# Unit Tests
# ==============================================================================

run_unit_tests() {
  print_header "Running Unit Tests"

  local tests_dir="$DOTFILES_DIR/tests"
  local tests_run=0
  local tests_failed=0

  for test_file in "$tests_dir"/test_*.sh; do
    [[ ! -f "$test_file" ]] && continue

    tests_run=$((tests_run + 1))
    local test_name
    test_name=$(basename "$test_file")

    echo "Running $test_name..."
    if bash "$test_file"; then
      print_success "$test_name"
    else
      print_error "$test_name"
      tests_failed=$((tests_failed + 1))
    fi
    echo ""
  done

  if [[ $tests_run -eq 0 ]]; then
    print_warning "No unit test files found"
    return 0
  fi

  echo "Ran $tests_run test files, $tests_failed failed"

  if [[ $tests_failed -gt 0 ]]; then
    OVERALL_STATUS=1
    return 1
  fi

  return 0
}

# ==============================================================================
# Library Sourcing Test
# ==============================================================================

run_source_test() {
  print_header "Testing Library Sourcing"

  # Test that all libraries can be sourced without errors
  local libs=(
    "lib/utils.sh"
    "lib/network.sh"
    "lib/backup.sh"
  )

  local modules=(
    "modules/package-managers.sh"
    "modules/dependencies.sh"
    "modules/nodejs.sh"
    "modules/neovim.sh"
    "modules/zsh.sh"
    "modules/link-configs.sh"
    "modules/vscode.sh"
    "modules/terminal.sh"
  )

  local failed=0

  # Test sourcing all libs
  for lib in "${libs[@]}"; do
    local lib_path="$DOTFILES_DIR/$lib"
    if [[ -f "$lib_path" ]]; then
      if bash -c "source '$lib_path'" 2>/dev/null; then
        print_success "$lib"
      else
        print_error "$lib"
        failed=$((failed + 1))
      fi
    else
      print_warning "$lib (not found)"
    fi
  done

  # Test sourcing all modules (requires libs first)
  for module in "${modules[@]}"; do
    local module_path="$DOTFILES_DIR/$module"
    if [[ -f "$module_path" ]]; then
      if bash -c "
        source '$DOTFILES_DIR/lib/utils.sh'
        source '$DOTFILES_DIR/lib/network.sh'
        source '$DOTFILES_DIR/lib/backup.sh'
        source '$DOTFILES_DIR/modules/package-managers.sh'
        source '$module_path'
      " 2>/dev/null; then
        print_success "$module"
      else
        print_error "$module"
        failed=$((failed + 1))
      fi
    else
      print_warning "$module (not found)"
    fi
  done

  if [[ $failed -gt 0 ]]; then
    OVERALL_STATUS=1
    return 1
  fi

  return 0
}

# ==============================================================================
# Main
# ==============================================================================

main() {
  echo -e "${BOLD}Dotfiles Test Suite${NC}"
  echo "===================="

  # Always run syntax check
  run_syntax_check || true

  # Run shellcheck unless in quick mode
  if [[ "$QUICK_MODE" != "true" ]]; then
    run_shellcheck || true
  else
    print_header "Skipping Shellcheck (quick mode)"
  fi

  # Test library sourcing
  run_source_test || true

  # Run unit tests
  run_unit_tests || true

  # Summary
  print_header "Summary"

  if [[ $OVERALL_STATUS -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}All tests passed!${NC}"
  else
    echo -e "${RED}${BOLD}Some tests failed!${NC}"
  fi

  exit $OVERALL_STATUS
}

main "$@"
