#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# lock.sh - Concurrent execution prevention
# ─────────────────────────────────────────────────────────────
# Uses lock files to prevent multiple backup operations from
# running simultaneously. Supports PID-based locking with
# stale lock detection.
# ─────────────────────────────────────────────────────────────

# Default lock directory
LOCK_DIR="${LOCK_DIR:-/tmp}"

# ── Acquire a lock ──────────────────────────────────────────
# Usage: lock_acquire "backup" || exit 1
# Returns 0 on success, 1 if lock is held by another process
lock_acquire() {
    local name="$1"
    local lock_file="${LOCK_DIR}/lbackup.${name}.lock"

    # Check for existing lock
    if [[ -f "$lock_file" ]]; then
        local old_pid
        old_pid=$(cat "$lock_file" 2>/dev/null || echo "")

        if [[ -n "$old_pid" ]]; then
            # Check if the process is still running
            if kill -0 "$old_pid" 2>/dev/null; then
                log_error "Another ${name} operation is already running (PID: ${old_pid})"
                log_info "If this is an error, remove: ${lock_file}"
                return 1
            else
                # Stale lock, remove it
                log_warn "Removing stale lock file (PID ${old_pid} no longer running)"
                rm -f "$lock_file" 2>/dev/null || true
            fi
        else
            # Empty lock file, remove it
            rm -f "$lock_file" 2>/dev/null || true
        fi
    fi

    # Create lock file with PID
    echo $$ > "$lock_file"

    # Verify we got the lock
    local acquired_pid
    acquired_pid=$(cat "$lock_file" 2>/dev/null || echo "")

    if [[ "$acquired_pid" != "$$" ]]; then
        log_error "Failed to acquire lock"
        return 1
    fi

    log_debug "Lock acquired: ${name} (PID: $$)"
    return 0
}

# ── Release a lock ──────────────────────────────────────────
# Usage: lock_release "backup"
lock_release() {
    local name="$1"
    local lock_file="${LOCK_DIR}/lbackup.${name}.lock"

    if [[ -f "$lock_file" ]]; then
        local lock_pid
        lock_pid=$(cat "$lock_file" 2>/dev/null || echo "")

        # Only release if we own the lock
        if [[ "$lock_pid" == "$$" ]]; then
            rm -f "$lock_file" 2>/dev/null || true
            log_debug "Lock released: ${name}"
        else
            log_warn "Cannot release lock owned by PID ${lock_pid}"
        fi
    fi
}

# ── Check if a lock is held ─────────────────────────────────
# Usage: lock_check "backup" && echo "locked"
lock_check() {
    local name="$1"
    local lock_file="${LOCK_DIR}/lbackup.${name}.lock"

    if [[ ! -f "$lock_file" ]]; then
        return 1  # Not locked
    fi

    local pid
    pid=$(cat "$lock_file" 2>/dev/null || echo "")

    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        return 0  # Locked and active
    fi

    return 1  # Stale or empty lock
}

# ── Force-remove a lock ────────────────────────────────────
# Usage: lock_force_remove "backup"
lock_force_remove() {
    local name="$1"
    local lock_file="${LOCK_DIR}/lbackup.${name}.lock"

    if [[ -f "$lock_file" ]]; then
        rm -f "$lock_file" 2>/dev/null || true
        log_warn "Force-removed lock: ${name}"
    fi
}

# ── Cleanup handler for locks ───────────────────────────────
# Usage: trap 'lock_release "backup"' EXIT
lock_cleanup() {
    local name="$1"
    lock_release "$name"
}
