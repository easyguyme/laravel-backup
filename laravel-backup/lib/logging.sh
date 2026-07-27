#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# logging.sh - Centralized logging with levels and file output
# ─────────────────────────────────────────────────────────────
# Provides log_info, log_warn, log_error, log_success, log_debug
# with timestamps, colour-coded console output, and file logging.
# ─────────────────────────────────────────────────────────────

# Log levels (numeric for comparison)
_LOG_LEVEL_DEBUG=0
_LOG_LEVEL_INFO=1
_LOG_LEVEL_SUCCESS=2
_LOG_LEVEL_WARNING=3
_LOG_LEVEL_ERROR=4

# Default log level
LOG_LEVEL="${LOG_LEVEL:-INFO}"

# Log file path
LOG_FILE="${LOG_FILE:-}"

# ── Get numeric level for a level name ──────────────────────
_log_level_num() {
    local level
    level=$(echo "$1" | tr '[:lower:]' '[:upper:]')
    case "$level" in
        DEBUG)   echo $_LOG_LEVEL_DEBUG ;;
        INFO)    echo $_LOG_LEVEL_INFO ;;
        SUCCESS) echo $_LOG_LEVEL_SUCCESS ;;
        WARNING) echo $_LOG_LEVEL_WARNING ;;
        ERROR)   echo $_LOG_LEVEL_ERROR ;;
        *)       echo $_LOG_LEVEL_INFO ;;
    esac
}

# ── Core log function ───────────────────────────────────────
_log() {
    local level="$1"
    local colour="$2"
    local icon="$3"
    shift 3

    local message="$*"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    # Check if we should output this level
    local current_level_num
    current_level_num=$(_log_level_num "$LOG_LEVEL")
    local message_level_num
    message_level_num=$(_log_level_num "$level")

    if [[ $message_level_num -ge $current_level_num ]]; then
        # Console output with colour
        if [[ -t 2 ]]; then
            printf '%b[%s] %-7s %b%b\n' \
                "$colour" "$timestamp" "[$level]" "$message" "$NC" >&2
        else
            # No colour for non-terminal
            printf '[%s] %-7s %s\n' \
                "$timestamp" "[$level]" "$message" >&2
        fi
    fi

    # File output (always, regardless of level check)
    if [[ -n "$LOG_FILE" ]]; then
        local log_dir
        log_dir="$(dirname "$LOG_FILE")"
        if [[ ! -d "$log_dir" ]]; then
            mkdir -p "$log_dir" 2>/dev/null || true
        fi
        printf '[%s] [%-7s] %s\n' \
            "$timestamp" "$level" "$(strip_colours "$message")" \
            >> "$LOG_FILE" 2>/dev/null || true
    fi
}

# ── Public logging functions ────────────────────────────────

log_debug() {
    _log "DEBUG" "$DIM" "  DEBUG" "$@"
}

log_info() {
    _log "INFO" "$BLUE" "   INFO" "$@"
}

log_success() {
    _log "SUCCESS" "$GREEN" " SUCCESS" "$@"
}

log_warn() {
    _log "WARNING" "$YELLOW" "WARNING" "$@"
}

log_error() {
    _log "ERROR" "$RED" "  ERROR" "$@"
}

# ── Log a section header ────────────────────────────────────
log_header() {
    local title="$1"
    local width=60
    local line

    line=$(printf '─%.0s' $(seq 1 "$width"))

    if [[ -t 2 ]]; then
        printf '\n%b══%s══%b\n' "$BOLD" "$line" "$NC" >&2
        printf '%b  %s%b\n' "$BOLD" "$title" "$NC" >&2
        printf '%b══%s══%b\n\n' "$BOLD" "$line" "$NC" >&2
    else
        printf '\n══%s══\n' "$line" >&2
        printf '  %s\n' "$title" >&2
        printf '══%s══\n\n' "$line" >&2
    fi

    # Log to file
    if [[ -n "$LOG_FILE" ]]; then
        printf '\n══%s══\n  %s\n══%s══\n\n' "$line" "$title" "$line" \
            >> "$LOG_FILE" 2>/dev/null || true
    fi
}

# ── Log a key-value pair ────────────────────────────────────
log_kv() {
    local key="$1"
    local value="$2"
    local indent="${3:-    }"

    if [[ -t 2 ]]; then
        printf '%b%b%-20s%b %s\n' "$indent" "$DIM" "$key:" "$NC" "$value" >&2
    else
        printf '%s%-20s %s\n' "$indent" "$key:" "$value" >&2
    fi
}

# ── Set log level ───────────────────────────────────────────
set_log_level() {
    LOG_LEVEL="${1:-INFO}"
}

# ── Set log file ────────────────────────────────────────────
set_log_file() {
    LOG_FILE="$1"
    local log_dir
    log_dir="$(dirname "$LOG_FILE")"
    if [[ ! -d "$log_dir" ]]; then
        mkdir -p "$log_dir" 2>/dev/null || true
    fi
}
