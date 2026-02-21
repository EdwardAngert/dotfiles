#!/usr/bin/env bash
# lib/network.sh - Network operations library for dotfiles installation
#
# This library provides network-related functions with retry logic,
# checksum validation, and GitHub API integration.
#
# Usage:
#   source "$DOTFILES_DIR/lib/utils.sh"   # Required dependency
#   source "$DOTFILES_DIR/lib/network.sh"

# Prevent multiple sourcing
[[ -n "${_NETWORK_SH_LOADED:-}" ]] && return 0
readonly _NETWORK_SH_LOADED=1

# Ensure utils.sh is loaded
if [[ -z "${_UTILS_SH_LOADED:-}" ]]; then
  echo "ERROR: lib/utils.sh must be sourced before lib/network.sh" >&2
  exit 1
fi

# ==============================================================================
# Configuration
# ==============================================================================

# Default retry settings
readonly NETWORK_MAX_RETRIES="${NETWORK_MAX_RETRIES:-3}"
readonly NETWORK_INITIAL_DELAY="${NETWORK_INITIAL_DELAY:-2}"  # seconds
readonly NETWORK_CONNECT_TIMEOUT="${NETWORK_CONNECT_TIMEOUT:-30}"  # seconds
readonly NETWORK_MAX_TIMEOUT="${NETWORK_MAX_TIMEOUT:-300}"  # 5 minutes

# ==============================================================================
# Download Functions
# ==============================================================================

# Download a file with retry logic and exponential backoff
# Usage: download_with_retry <url> <output_file> [description]
# Returns: 0 on success, 1 on failure
download_with_retry() {
  local url="$1"
  local output="$2"
  local description="${3:-file}"
  local attempt=1
  local delay="$NETWORK_INITIAL_DELAY"
  local success=false

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "download $description from: $url"
    return 0
  fi

  # Create output directory if needed
  safe_mkdir "$(dirname "$output")"

  while [[ $attempt -le $NETWORK_MAX_RETRIES ]]; do
    print_debug "Download attempt $attempt/$NETWORK_MAX_RETRIES: $description"

    # Try wget first (better progress display and resumption)
    if check_command wget; then
      if wget -q --show-progress \
          --connect-timeout="$NETWORK_CONNECT_TIMEOUT" \
          --timeout="$NETWORK_MAX_TIMEOUT" \
          -O "$output" \
          "$url" 2>/dev/null; then
        success=true
        break
      fi
    fi

    # Fall back to curl
    if [[ "$success" == "false" ]] && check_command curl; then
      if curl -fsSL \
          --connect-timeout "$NETWORK_CONNECT_TIMEOUT" \
          --max-time "$NETWORK_MAX_TIMEOUT" \
          -o "$output" \
          "$url" 2>/dev/null; then
        success=true
        break
      fi
    fi

    # Check if we have any download tool
    if ! check_command wget && ! check_command curl; then
      print_error "Neither wget nor curl is available. Cannot download files."
      return 1
    fi

    # Failed, prepare for retry
    if [[ $attempt -lt $NETWORK_MAX_RETRIES ]]; then
      print_warning "Download failed (attempt $attempt/$NETWORK_MAX_RETRIES). Retrying in ${delay}s..."
      sleep "$delay"
      delay=$((delay * 2))  # Exponential backoff
    fi

    ((attempt++))
  done

  if [[ "$success" == "true" ]]; then
    # Verify file was actually downloaded
    if [[ -s "$output" ]]; then
      print_debug "Successfully downloaded: $description"
      return 0
    else
      print_error "Downloaded file is empty: $output"
      rm -f "$output"
      return 1
    fi
  else
    print_error "Failed to download $description after $NETWORK_MAX_RETRIES attempts"
    rm -f "$output"
    return 1
  fi
}

# Download to a temporary file
# Usage: download_to_temp <url> [prefix]
# Outputs: path to temporary file
# Returns: 0 on success, 1 on failure
download_to_temp() {
  local url="$1"
  local prefix="${2:-download}"
  local temp_file

  temp_file=$(mktemp "/tmp/${prefix}.XXXXXX")

  if download_with_retry "$url" "$temp_file" "$prefix"; then
    echo "$temp_file"
    return 0
  else
    rm -f "$temp_file"
    return 1
  fi
}

# ==============================================================================
# Checksum Validation
# ==============================================================================

# Calculate SHA256 checksum of a file (cross-platform)
# Usage: calculate_sha256 <file>
# Outputs: checksum string
calculate_sha256() {
  local file="$1"

  if [[ ! -f "$file" ]]; then
    print_error "File not found for checksum: $file"
    return 1
  fi

  if check_command sha256sum; then
    sha256sum "$file" | cut -d' ' -f1
  elif check_command shasum; then
    shasum -a 256 "$file" | cut -d' ' -f1
  else
    print_error "No SHA256 tool available (need sha256sum or shasum)"
    return 1
  fi
}

# Validate a file's SHA256 checksum
# Usage: validate_checksum <file> <expected_checksum>
# Returns: 0 if valid, 1 if invalid
validate_checksum() {
  local file="$1"
  local expected="$2"
  local actual

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "validate checksum of: $file"
    return 0
  fi

  actual=$(calculate_sha256 "$file") || return 1

  # Normalize checksums to lowercase for comparison
  expected="${expected,,}"
  actual="${actual,,}"

  if [[ "$actual" == "$expected" ]]; then
    print_debug "Checksum valid for: $file"
    return 0
  else
    print_error "Checksum mismatch for: $file"
    print_error "  Expected: $expected"
    print_error "  Actual:   $actual"
    return 1
  fi
}

# Download and validate a file with checksum
# Usage: download_and_verify <url> <output> <checksum> [description]
# Returns: 0 on success, 1 on failure
download_and_verify() {
  local url="$1"
  local output="$2"
  local checksum="$3"
  local description="${4:-file}"

  if ! download_with_retry "$url" "$output" "$description"; then
    return 1
  fi

  if [[ "$DRY_RUN" != "true" ]]; then
    if ! validate_checksum "$output" "$checksum"; then
      print_error "Removing corrupted download: $output"
      rm -f "$output"
      return 1
    fi
  fi

  return 0
}

# ==============================================================================
# GitHub API Functions
# ==============================================================================

# Get the latest release version from a GitHub repository
# Usage: get_latest_github_release <owner/repo>
# Outputs: version tag (e.g., "v1.2.3" or "1.2.3")
get_latest_github_release() {
  local repo="$1"
  local api_url="https://api.github.com/repos/${repo}/releases/latest"
  local version

  print_debug "Fetching latest release for: $repo"

  if check_command curl; then
    version=$(curl -fsSL "$api_url" 2>/dev/null | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4)
  elif check_command wget; then
    version=$(wget -qO- "$api_url" 2>/dev/null | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4)
  else
    print_error "Neither curl nor wget available"
    return 1
  fi

  if [[ -z "$version" ]]; then
    print_error "Failed to fetch latest release for: $repo"
    return 1
  fi

  echo "$version"
}

# Get SHA256 checksum from a GitHub release
# Usage: get_github_release_sha256 <owner/repo> <version> <asset_name> <checksum_file_pattern>
# Outputs: checksum string for the specified asset
# Example: get_github_release_sha256 "neovim/neovim" "stable" "nvim-linux64.tar.gz" "*.sha256sum"
get_github_release_sha256() {
  local repo="$1"
  local version="$2"
  local asset_name="$3"
  local checksum_pattern="${4:-SHA256SUMS}"
  local checksum_url
  local checksum_content
  local checksum

  # Build the checksum file URL
  # Common patterns: SHA256SUMS, *.sha256sum, *_checksums.txt
  case "$checksum_pattern" in
    *.sha256sum)
      checksum_url="https://github.com/${repo}/releases/download/${version}/${asset_name}.sha256sum"
      ;;
    *checksums*)
      # GitHub CLI style: gh_X.X.X_checksums.txt
      local version_clean="${version#v}"
      checksum_url="https://github.com/${repo}/releases/download/${version}/gh_${version_clean}_checksums.txt"
      ;;
    *)
      checksum_url="https://github.com/${repo}/releases/download/${version}/${checksum_pattern}"
      ;;
  esac

  print_debug "Fetching checksum from: $checksum_url"

  # Download checksum file
  if check_command curl; then
    checksum_content=$(curl -fsSL "$checksum_url" 2>/dev/null)
  elif check_command wget; then
    checksum_content=$(wget -qO- "$checksum_url" 2>/dev/null)
  else
    print_warning "Cannot fetch checksum: no download tool available"
    return 1
  fi

  if [[ -z "$checksum_content" ]]; then
    print_warning "Could not fetch checksum file for: $asset_name"
    return 1
  fi

  # Extract checksum for the specific asset
  # Checksums are usually in format: <checksum>  <filename> or <checksum> <filename>
  checksum=$(echo "$checksum_content" | grep -E "(^[a-f0-9]{64})\s+.*${asset_name}$" | head -1 | awk '{print $1}')

  if [[ -z "$checksum" ]]; then
    # Try alternate format where filename comes first
    checksum=$(echo "$checksum_content" | grep "${asset_name}" | head -1 | awk '{print $1}')
  fi

  if [[ -z "$checksum" ]] || [[ ${#checksum} -ne 64 ]]; then
    print_warning "Could not extract valid checksum for: $asset_name"
    return 1
  fi

  echo "$checksum"
}

# Download a GitHub release asset
# Usage: download_github_release <owner/repo> <version> <asset_name> <output_file> [verify_checksum]
# Returns: 0 on success, 1 on failure
download_github_release() {
  local repo="$1"
  local version="$2"
  local asset_name="$3"
  local output="$4"
  local verify="${5:-true}"
  local download_url
  local checksum

  download_url="https://github.com/${repo}/releases/download/${version}/${asset_name}"

  print_info "Downloading ${asset_name} from ${repo}..."

  # Try to get checksum if verification is enabled
  if [[ "$verify" == "true" ]]; then
    checksum=$(get_github_release_sha256 "$repo" "$version" "$asset_name" "*.sha256sum" 2>/dev/null) || true

    if [[ -n "$checksum" ]]; then
      print_debug "Found checksum for verification: ${checksum:0:16}..."
      if download_and_verify "$download_url" "$output" "$checksum" "$asset_name"; then
        return 0
      fi
    else
      print_debug "No checksum available, downloading without verification"
    fi
  fi

  # Download without verification (or if verification failed)
  download_with_retry "$download_url" "$output" "$asset_name"
}

# ==============================================================================
# Network Connectivity
# ==============================================================================

# Check if we have internet connectivity
# Usage: check_internet
# Returns: 0 if connected, 1 if not
check_internet() {
  local test_hosts=("github.com" "google.com" "1.1.1.1")

  for host in "${test_hosts[@]}"; do
    if check_command ping; then
      if ping -c 1 -W 2 "$host" &>/dev/null; then
        return 0
      fi
    elif check_command curl; then
      if curl -fsS --connect-timeout 2 "https://$host" &>/dev/null; then
        return 0
      fi
    fi
  done

  return 1
}

# Wait for internet connectivity
# Usage: wait_for_internet [timeout_seconds]
# Returns: 0 if connected within timeout, 1 if timeout
wait_for_internet() {
  local timeout="${1:-30}"
  local elapsed=0

  print_info "Waiting for internet connectivity..."

  while [[ $elapsed -lt $timeout ]]; do
    if check_internet; then
      print_success "Internet connection established"
      return 0
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done

  print_error "No internet connection after ${timeout}s"
  return 1
}
