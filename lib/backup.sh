#!/usr/bin/env bash
# lib/backup.sh - Backup registry library for dotfiles installation
#
# This library provides backup functionality with a registry system
# that enables rollback of changes made during installation.
#
# Usage:
#   source "$DOTFILES_DIR/lib/utils.sh"   # Required dependency
#   source "$DOTFILES_DIR/lib/backup.sh"

# Prevent multiple sourcing
[[ -n "${_BACKUP_SH_LOADED:-}" ]] && return 0
readonly _BACKUP_SH_LOADED=1

# Ensure utils.sh is loaded
if [[ -z "${_UTILS_SH_LOADED:-}" ]]; then
  echo "ERROR: lib/utils.sh must be sourced before lib/backup.sh" >&2
  exit 1
fi

# ==============================================================================
# Configuration
# ==============================================================================

# Base directory for all backups
readonly BACKUP_BASE_DIR="${BACKUP_BASE_DIR:-$HOME/.dotfiles-backups}"

# Current session variables (set by init_backup_session)
BACKUP_SESSION_DIR=""
BACKUP_MANIFEST_FILE=""
BACKUP_SESSION_ID=""

# ==============================================================================
# Session Management
# ==============================================================================

# Initialize a new backup session
# Usage: init_backup_session [session_name]
# Sets: BACKUP_SESSION_DIR, BACKUP_MANIFEST_FILE, BACKUP_SESSION_ID
init_backup_session() {
  local session_name="${1:-install}"
  local timestamp

  timestamp=$(date +%Y%m%d_%H%M%S)
  BACKUP_SESSION_ID="${session_name}_${timestamp}"
  BACKUP_SESSION_DIR="${BACKUP_BASE_DIR}/${BACKUP_SESSION_ID}"
  BACKUP_MANIFEST_FILE="${BACKUP_SESSION_DIR}/manifest.json"

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "create backup session: $BACKUP_SESSION_ID"
    return 0
  fi

  # Create backup directory
  if ! mkdir -p "$BACKUP_SESSION_DIR"; then
    print_error "Failed to create backup directory: $BACKUP_SESSION_DIR"
    return 1
  fi

  # Initialize manifest file
  cat > "$BACKUP_MANIFEST_FILE" << EOF
{
  "session_id": "$BACKUP_SESSION_ID",
  "created_at": "$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)",
  "dotfiles_dir": "$(get_dotfiles_dir)",
  "os": "$OS",
  "arch": "$ARCH",
  "backups": []
}
EOF

  print_debug "Initialized backup session: $BACKUP_SESSION_ID"
  print_debug "Backup directory: $BACKUP_SESSION_DIR"

  export BACKUP_SESSION_DIR BACKUP_MANIFEST_FILE BACKUP_SESSION_ID
}

# Get the latest backup session (for rollback)
# Usage: get_latest_backup_session
# Outputs: session ID of the most recent backup
get_latest_backup_session() {
  local latest

  if [[ ! -d "$BACKUP_BASE_DIR" ]]; then
    print_error "No backup directory found: $BACKUP_BASE_DIR"
    return 1
  fi

  # Find the most recent session directory
  latest=$(find "$BACKUP_BASE_DIR" -mindepth 1 -maxdepth 1 -type d -name "*_*" | sort -r | head -1)

  if [[ -z "$latest" ]]; then
    print_error "No backup sessions found"
    return 1
  fi

  basename "$latest"
}

# List all backup sessions
# Usage: list_backup_sessions
# Outputs: list of session IDs with dates
list_backup_sessions() {
  local session_dir
  local manifest
  local created_at

  if [[ ! -d "$BACKUP_BASE_DIR" ]]; then
    print_info "No backup directory found"
    return 0
  fi

  echo "Available backup sessions:"
  echo ""

  for session_dir in "$BACKUP_BASE_DIR"/*/; do
    [[ ! -d "$session_dir" ]] && continue

    manifest="${session_dir}manifest.json"
    if [[ -f "$manifest" ]]; then
      created_at=$(grep -o '"created_at": "[^"]*"' "$manifest" | cut -d'"' -f4)
      echo "  - $(basename "$session_dir") (created: $created_at)"
    else
      echo "  - $(basename "$session_dir") (no manifest)"
    fi
  done
}

# ==============================================================================
# Backup Operations
# ==============================================================================

# Register a backup in the manifest
# Usage: register_backup <original_path> <backup_path> [type]
# Types: file, directory, symlink
register_backup() {
  local original="$1"
  local backup="$2"
  local type="${3:-file}"
  local temp_file

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "register backup: $original -> $backup"
    return 0
  fi

  if [[ -z "$BACKUP_MANIFEST_FILE" ]] || [[ ! -f "$BACKUP_MANIFEST_FILE" ]]; then
    print_error "No backup session initialized. Call init_backup_session first."
    return 1
  fi

  # Create a temporary file for the updated manifest
  temp_file=$(mktemp)

  # Use awk to add the backup entry to the JSON array
  awk -v orig="$original" -v back="$backup" -v t="$type" '
    /"backups": \[/ {
      print
      getline
      if ($0 ~ /\]/) {
        # Empty array, add first entry
        printf "    {\"original\": \"%s\", \"backup\": \"%s\", \"type\": \"%s\"}\n", orig, back, t
      } else {
        # Non-empty array, add comma and entry
        print
        while (getline && $0 !~ /\]/) {
          print
        }
        printf ",\n    {\"original\": \"%s\", \"backup\": \"%s\", \"type\": \"%s\"}\n", orig, back, t
      }
      print "  ]"
      next
    }
    { print }
  ' "$BACKUP_MANIFEST_FILE" > "$temp_file"

  mv "$temp_file" "$BACKUP_MANIFEST_FILE"
  print_debug "Registered backup: $original -> $backup"
}

# Backup a file or directory with registry
# Usage: backup_with_registry <path>
# Returns: 0 on success, 1 if path doesn't exist, 2 on error
backup_with_registry() {
  local path="$1"
  local backup_name
  local backup_path
  local file_type

  # Check if path exists
  if [[ ! -e "$path" ]]; then
    print_debug "Nothing to backup (doesn't exist): $path"
    return 1
  fi

  # Ensure session is initialized
  if [[ -z "$BACKUP_SESSION_DIR" ]]; then
    print_warning "No backup session initialized, using simple backup"
    backup_if_exists "$path"
    return $?
  fi

  # Generate backup path
  # Convert absolute path to relative for storage
  backup_name="${path#$HOME/}"
  backup_name="${backup_name//\//__}"  # Replace / with __
  backup_path="${BACKUP_SESSION_DIR}/${backup_name}"

  # Determine type
  if [[ -L "$path" ]]; then
    file_type="symlink"
  elif [[ -d "$path" ]]; then
    file_type="directory"
  else
    file_type="file"
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "backup ($file_type): $path -> $backup_path"
    return 0
  fi

  print_info "Backing up: $path"

  # Perform backup
  if [[ -L "$path" ]]; then
    # For symlinks, store the target
    readlink "$path" > "$backup_path"
  elif [[ -d "$path" ]]; then
    # For directories, use cp -r
    if ! cp -r "$path" "$backup_path"; then
      print_error "Failed to backup directory: $path"
      return 2
    fi
  else
    # For files, use cp
    if ! cp "$path" "$backup_path"; then
      print_error "Failed to backup file: $path"
      return 2
    fi
  fi

  # Register in manifest
  register_backup "$path" "$backup_path" "$file_type"

  print_success "Backed up: $path"
  return 0
}

# ==============================================================================
# Rollback Operations
# ==============================================================================

# Rollback a specific backup session
# Usage: rollback_session [session_id]
# If no session_id provided, uses the latest session
rollback_session() {
  local session_id="${1:-}"
  local session_dir
  local manifest
  local backup_count

  # Get session ID if not provided
  if [[ -z "$session_id" ]]; then
    session_id=$(get_latest_backup_session) || return 1
  fi

  session_dir="${BACKUP_BASE_DIR}/${session_id}"
  manifest="${session_dir}/manifest.json"

  # Verify session exists
  if [[ ! -d "$session_dir" ]]; then
    print_error "Backup session not found: $session_id"
    return 1
  fi

  if [[ ! -f "$manifest" ]]; then
    print_error "Manifest not found for session: $session_id"
    return 1
  fi

  print_section "Rollback Session: $session_id"

  # Parse manifest and show what will be restored
  print_info "The following items will be restored:"
  echo ""

  # Extract backups from manifest using grep/sed (portable)
  backup_count=$(grep -c '"original":' "$manifest" 2>/dev/null || echo "0")

  if [[ "$backup_count" == "0" ]]; then
    print_info "No backups in this session"
    return 0
  fi

  # Show each backup
  grep '"original":' "$manifest" | while read -r line; do
    local original
    original=$(echo "$line" | sed 's/.*"original": "\([^"]*\)".*/\1/')
    echo "  - $original"
  done

  echo ""

  # Confirm rollback
  if [[ "$DRY_RUN" != "true" ]]; then
    if ! confirm "Proceed with rollback?"; then
      print_info "Rollback cancelled"
      return 0
    fi
  fi

  # Perform rollback
  _perform_rollback "$manifest"
}

# Internal function to perform the actual rollback
_perform_rollback() {
  local manifest="$1"
  local original
  local backup
  local type
  local success=true

  # Process each backup entry
  # Using grep and process substitution for portability
  while IFS= read -r entry; do
    # Skip if empty
    [[ -z "$entry" ]] && continue

    # Extract fields (simple parsing)
    original=$(echo "$entry" | grep -o '"original": "[^"]*"' | cut -d'"' -f4)
    backup=$(echo "$entry" | grep -o '"backup": "[^"]*"' | cut -d'"' -f4)
    type=$(echo "$entry" | grep -o '"type": "[^"]*"' | cut -d'"' -f4)

    [[ -z "$original" ]] && continue

    print_info "Restoring: $original"

    if [[ "$DRY_RUN" == "true" ]]; then
      print_dry_run "restore $type: $backup -> $original"
      continue
    fi

    # Remove current version if it exists
    if [[ -e "$original" ]] || [[ -L "$original" ]]; then
      rm -rf "$original"
    fi

    # Restore based on type
    case "$type" in
      symlink)
        if [[ -f "$backup" ]]; then
          local target
          target=$(cat "$backup")
          if ln -s "$target" "$original"; then
            print_success "Restored symlink: $original -> $target"
          else
            print_error "Failed to restore symlink: $original"
            success=false
          fi
        fi
        ;;
      directory)
        if [[ -d "$backup" ]]; then
          if cp -r "$backup" "$original"; then
            print_success "Restored directory: $original"
          else
            print_error "Failed to restore directory: $original"
            success=false
          fi
        fi
        ;;
      file|*)
        if [[ -f "$backup" ]]; then
          # Ensure parent directory exists
          mkdir -p "$(dirname "$original")"
          if cp "$backup" "$original"; then
            print_success "Restored file: $original"
          else
            print_error "Failed to restore file: $original"
            success=false
          fi
        fi
        ;;
    esac
  done < <(grep -A3 '"original":' "$manifest" | paste - - - - | sed 's/--/\n/g')

  if [[ "$success" == "true" ]]; then
    print_success "Rollback completed successfully!"
    return 0
  else
    print_warning "Rollback completed with some errors"
    return 1
  fi
}

# ==============================================================================
# Cleanup Operations
# ==============================================================================

# Remove old backup sessions (keep last N)
# Usage: cleanup_old_backups [keep_count]
cleanup_old_backups() {
  local keep_count="${1:-5}"
  local sessions
  local count
  local to_remove

  if [[ ! -d "$BACKUP_BASE_DIR" ]]; then
    return 0
  fi

  # Get list of sessions sorted by date (newest first)
  mapfile -t sessions < <(find "$BACKUP_BASE_DIR" -mindepth 1 -maxdepth 1 -type d -name "*_*" | sort -r)
  count=${#sessions[@]}

  if [[ $count -le $keep_count ]]; then
    print_debug "No old backups to clean up ($count sessions, keeping $keep_count)"
    return 0
  fi

  to_remove=$((count - keep_count))
  print_info "Cleaning up $to_remove old backup session(s)..."

  for ((i = keep_count; i < count; i++)); do
    local session="${sessions[$i]}"

    if [[ "$DRY_RUN" == "true" ]]; then
      print_dry_run "remove old backup: $(basename "$session")"
    else
      rm -rf "$session"
      print_debug "Removed: $(basename "$session")"
    fi
  done

  print_success "Backup cleanup complete"
}

# Remove a specific backup session
# Usage: remove_backup_session <session_id>
remove_backup_session() {
  local session_id="$1"
  local session_dir="${BACKUP_BASE_DIR}/${session_id}"

  if [[ ! -d "$session_dir" ]]; then
    print_error "Session not found: $session_id"
    return 1
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "remove backup session: $session_id"
    return 0
  fi

  if rm -rf "$session_dir"; then
    print_success "Removed backup session: $session_id"
    return 0
  else
    print_error "Failed to remove backup session: $session_id"
    return 1
  fi
}

# ==============================================================================
# Information Functions
# ==============================================================================

# Get backup session info
# Usage: get_session_info [session_id]
get_session_info() {
  local session_id="${1:-}"
  local session_dir
  local manifest

  if [[ -z "$session_id" ]]; then
    session_id=$(get_latest_backup_session) || return 1
  fi

  session_dir="${BACKUP_BASE_DIR}/${session_id}"
  manifest="${session_dir}/manifest.json"

  if [[ ! -f "$manifest" ]]; then
    print_error "Manifest not found for session: $session_id"
    return 1
  fi

  echo "Session: $session_id"
  echo "Directory: $session_dir"
  echo ""

  # Show basic info from manifest
  grep -E '"(created_at|dotfiles_dir|os|arch)"' "$manifest" | \
    sed 's/[",]//g' | \
    sed 's/^[ ]*/  /'

  echo ""
  echo "Backups:"
  grep '"original":' "$manifest" | \
    sed 's/.*"original": "\([^"]*\)".*/  - \1/'
}
