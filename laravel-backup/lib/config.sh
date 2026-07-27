#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# config.sh - Configuration management
# ─────────────────────────────────────────────────────────────
# Loads, validates, and provides access to backup.conf settings
# with sensible defaults.
# ─────────────────────────────────────────────────────────────

# ── Default configuration values ────────────────────────────
_LBACKUP_DEFAULTS=(
    "RETENTION_COUNT=10"
    "RETENTION_DAYS=30"
    "ENCRYPTION_ENABLED=false"
    "ENCRYPTION_PASSWORD_SOURCE=env"
    "ENCRYPTION_PASSWORD_FILE="
    "DATABASE_TYPE="
    "DATABASE_HOST=127.0.0.1"
    "DATABASE_PORT="
    "DATABASE_NAME="
    "DATABASE_USER="
    "DATABASE_PASSWORD="
    "SQLITE_DATABASE_PATH="
    "BACKUP_DIR=backups"
    "TEMP_DIR=/tmp/laravel-backup"
    "COMPRESSION_LEVEL=6"
    "EXTRA_UPLOAD_DIRS="
    "EXCLUDE_DIRS=.git node_modules vendor .env"
    "GIT_AUTO_COMMIT=true"
    "GIT_AUTO_TAG=true"
    "GIT_TAG_PREFIX=backup"
    "GIT_AUTO_PUSH=false"
    "GIT_BACKUP_BRANCH="
    "NOTIFICATIONS_ENABLED=false"
    "TELEGRAM_BOT_TOKEN="
    "TELEGRAM_CHAT_ID="
    "SLACK_WEBHOOK_URL="
    "DISCORD_WEBHOOK_URL="
    "EMAIL_TO="
    "EMAIL_FROM="
    "EMAIL_SUBJECT=[laravel-backup] Backup Report"
    "WEBHOOK_URL="
    "WEBHOOK_METHOD=POST"
    "LOG_LEVEL=INFO"
    "LOG_FILE=backups/backup.log"
    "VERBOSE=false"
    "DRY_RUN=false"
)

# ── Apply default values ────────────────────────────────────
_apply_defaults() {
    for default in "${_LBACKUP_DEFAULTS[@]}"; do
        local key="${default%%=*}"
        if [[ -z "${!key:-}" ]]; then
            export "$default"
        fi
    done
}

# ── Load configuration file ─────────────────────────────────
config_load() {
    local config_file="${1:-}"
    local project_root="${2:-$(pwd)}"

    # Apply defaults first
    _apply_defaults

    # Determine config file path
    if [[ -z "$config_file" ]]; then
        # Look for backup.conf in project root, then next to the script
        if [[ -f "${project_root}/backup.conf" ]]; then
            config_file="${project_root}/backup.conf"
        elif [[ -f "${LBACKUP_ROOT:-}/backup.conf" ]]; then
            config_file="${LBACKUP_ROOT}/backup.conf"
        fi
    fi

    if [[ -z "$config_file" ]] || [[ ! -f "$config_file" ]]; then
        log_debug "No configuration file found, using defaults"
        return 0
    fi

    log_debug "Loading config from: ${config_file}"

    # Source the config file
    # shellcheck source=/dev/null
    source "$config_file"

    # Re-apply defaults for any empty values
    _apply_defaults

    # Set up logging based on config
    set_log_level "${LOG_LEVEL:-INFO}"
    if [[ -n "${LOG_FILE:-}" ]]; then
        set_log_file "$LOG_FILE"
    fi

    return 0
}

# ── Get a configuration value ───────────────────────────────
config_get() {
    local key="$1"
    local default="${2:-}"

    local value="${!key:-}"
    if [[ -n "$value" ]]; then
        echo "$value"
    else
        echo "$default"
    fi
}

# ── Set a configuration value (runtime only) ────────────────
config_set() {
    local key="$1"
    local value="$2"
    export "${key}=${value}"
}

# ── Show current configuration ──────────────────────────────
config_show() {
    log_header "Configuration"

    local settings=(
        "RETENTION_COUNT"
        "RETENTION_DAYS"
        "ENCRYPTION_ENABLED"
        "ENCRYPTION_PASSWORD_SOURCE"
        "DATABASE_TYPE"
        "DATABASE_HOST"
        "DATABASE_PORT"
        "DATABASE_NAME"
        "BACKUP_DIR"
        "TEMP_DIR"
        "COMPRESSION_LEVEL"
        "GIT_AUTO_COMMIT"
        "GIT_AUTO_TAG"
        "GIT_AUTO_PUSH"
        "NOTIFICATIONS_ENABLED"
        "LOG_LEVEL"
        "LOG_FILE"
        "VERBOSE"
        "DRY_RUN"
    )

    for setting in "${settings[@]}"; do
        local value="${!setting:-}"
        # Mask sensitive values
        case "$setting" in
            *PASSWORD*|*TOKEN*|*SECRET*)
                if [[ -n "$value" ]]; then
                    value="********"
                fi
                ;;
        esac
        log_kv "$setting" "${value:-<not set>}"
    done
}

# ── Create default configuration file ───────────────────────
config_create() {
    local target="${1:-backup.conf}"

    if [[ -f "$target" ]]; then
        log_warn "Configuration file already exists: ${target}"
        if ! confirm "Overwrite?"; then
            return 0
        fi
    fi

    # Copy example config
    local example="${LBACKUP_ROOT:-$(dirname "$(dirname "${BASH_SOURCE[0]}")")}/backup.conf.example"
    if [[ -f "$example" ]]; then
        cp "$example" "$target"
        log_info "Created configuration file: ${target}"
    else
        # Generate minimal config
        cat > "$target" << 'CONFEOF'
# laravel-backup configuration
RETENTION_COUNT=10
RETENTION_DAYS=30
ENCRYPTION_ENABLED=false
ENCRYPTION_PASSWORD_SOURCE=env
BACKUP_DIR=backups
COMPRESSION_LEVEL=6
GIT_AUTO_COMMIT=true
GIT_AUTO_TAG=true
GIT_AUTO_PUSH=false
NOTIFICATIONS_ENABLED=false
LOG_LEVEL=INFO
LOG_FILE=backups/backup.log
CONFEOF
        log_info "Created configuration file: ${target}"
    fi

    return 0
}
