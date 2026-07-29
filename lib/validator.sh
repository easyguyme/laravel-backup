#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# validator.sh - Input and state validation
# ─────────────────────────────────────────────────────────────
# Validates inputs, paths, configurations, and project state
# before operations execute.
# ─────────────────────────────────────────────────────────────

# ── Validate we're in a Laravel project ─────────────────────
validate_laravel_project() {
    local project_root="${1:-$(pwd)}"

    if ! detect_laravel "$project_root"; then
        log_error "Not a Laravel project (missing artisan or composer.json)"
        log_info "Run this command from a Laravel project root"
        return 1
    fi

    return 0
}

# ── Validate required commands exist ────────────────────────
validate_dependencies() {
    local deps=("$@")
    local missing=()

    for dep in "${deps[@]}"; do
        if ! command_exists "$dep"; then
            missing+=("$dep")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required dependencies:"
        for dep in "${missing[@]}"; do
            log_error "  - ${dep}"
        done
        return 1
    fi

    return 0
}

# ── Validate .env file exists and has DB config ─────────────
validate_env_file() {
    local project_root="${1:-$(pwd)}"

    if [[ ! -f "${project_root}/.env" ]]; then
        log_error ".env file not found"
        log_info "Create a .env file with database configuration"
        return 1
    fi

    return 0
}

# ── Validate database connection ────────────────────────────
validate_database_connection() {
    local db_type="$1"
    local project_root="${2:-$(pwd)}"

    case "$db_type" in
        mysql|pgsql)
            # Check if we can connect
            if [[ -f "${project_root}/.env" ]]; then
                # Read values without sourcing (avoid variable conflicts)
                local db_host db_user db_pass db_name
                db_host=$(env_read "${project_root}/.env" "DB_HOST" "127.0.0.1")
                db_user=$(env_read "${project_root}/.env" "DB_USERNAME" "root")
                db_pass=$(env_read "${project_root}/.env" "DB_PASSWORD" "")
                db_name=$(env_read "${project_root}/.env" "DB_DATABASE" "")
            fi

            case "$db_type" in
                mysql)
                    if command_exists mysql; then
                        mysql -h "${db_host:-127.0.0.1}" \
                              -u "${db_user:-root}" \
                              -p"${db_pass:-}" \
                              -e "SELECT 1" "${db_name:-}" &>/dev/null
                        return $?
                    fi
                    ;;
                pgsql)
                    if command_exists psql; then
                        PGPASSWORD="${db_pass:-}" \
                        psql -h "${db_host:-127.0.0.1}" \
                             -U "${db_user:-postgres}" \
                             -d "${db_name:-}" \
                             -c "SELECT 1" &>/dev/null
                        return $?
                    fi
                    ;;
            esac
            log_warn "Cannot verify database connection (client not available)"
            return 0
            ;;
        sqlite)
            local db_path
            db_path=$(env_read "${project_root}/.env" "DB_DATABASE" "database/database.sqlite")
            if [[ ! -f "$db_path" ]]; then
                log_warn "SQLite database not found: ${db_path}"
                return 1
            fi
            return 0
            ;;
        *)
            log_warn "Unknown database type: ${db_type}"
            return 0
            ;;
    esac

    return 0
}

# ── Validate backup file exists and is readable ─────────────
validate_backup_file() {
    local file="$1"

    if [[ -z "$file" ]]; then
        log_error "No backup file specified"
        return 1
    fi

    if [[ ! -f "$file" ]]; then
        log_error "Backup file not found: ${file}"
        return 1
    fi

    if [[ ! -r "$file" ]]; then
        log_error "Backup file not readable: ${file}"
        return 1
    fi

    return 0
}

# ── Validate configuration ──────────────────────────────────
validate_config() {
    local errors=0

    # Retention count
    if [[ -n "${RETENTION_COUNT:-}" ]]; then
        if ! [[ "$RETENTION_COUNT" =~ ^[0-9]+$ ]]; then
            log_error "RETENTION_COUNT must be a number"
            ((errors++)) || true
        fi
    fi

    # Compression level
    if [[ -n "${COMPRESSION_LEVEL:-}" ]]; then
        if ! [[ "$COMPRESSION_LEVEL" =~ ^[1-9]$ ]]; then
            log_error "COMPRESSION_LEVEL must be between 1 and 9"
            ((errors++)) || true
        fi
    fi

    # Password source
    if [[ -n "${ENCRYPTION_PASSWORD_SOURCE:-}" ]]; then
        case "${ENCRYPTION_PASSWORD_SOURCE}" in
            env|file|prompt)
                ;;
            *)
                log_error "ENCRYPTION_PASSWORD_SOURCE must be 'env', 'file', or 'prompt'"
                ((errors++)) || true
                ;;
        esac
    fi

    return $errors
}

# ── Validate the project has a backup directory ─────────────
validate_backup_dir() {
    local project_root="${1:-$(pwd)}"
    local backup_dir="${BACKUP_DIR:-backups}"

    if [[ ! -d "${project_root}/${backup_dir}" ]]; then
        log_warn "Backup directory does not exist: ${backup_dir}"
        mkdir -p "${project_root}/${backup_dir}" 2>/dev/null || {
            log_error "Cannot create backup directory: ${backup_dir}"
            return 1
        }
        log_info "Created backup directory: ${backup_dir}"
    fi

    if [[ ! -w "${project_root}/${backup_dir}" ]]; then
        log_error "Backup directory not writable: ${backup_dir}"
        return 1
    fi

    return 0
}

# ── Validate disk space ────────────────────────────────────
validate_disk_space() {
    local project_root="${1:-$(pwd)}"
    local min_space="${2:-104857600}"  # 100MB default

    local available
    available=$(disk_space "$project_root")

    if [[ "$available" -lt "$min_space" ]]; then
        log_error "Insufficient disk space"
        log_error "  Available: $(human_size "$available")"
        log_error "  Required: $(human_size "$min_space")"
        return 1
    fi

    return 0
}

# ── Validate encryption password is available ───────────────
validate_encryption_password() {
    local source="${ENCRYPTION_PASSWORD_SOURCE:-env}"

    case "$source" in
        env)
            if [[ -z "${BACKUP_PASSWORD:-}" ]]; then
                log_error "BACKUP_PASSWORD environment variable not set"
                log_info "Set it with: export BACKUP_PASSWORD='your-password'"
                return 1
            fi
            ;;
        file)
            local passfile="${ENCRYPTION_PASSWORD_FILE:-}"
            if [[ -z "$passfile" ]]; then
                log_error "ENCRYPTION_PASSWORD_FILE not configured"
                return 1
            fi
            if [[ ! -r "$passfile" ]]; then
                log_error "Password file not readable: ${passfile}"
                return 1
            fi
            ;;
        prompt)
            # Will prompt later, just validate config
            ;;
        *)
            log_error "Unknown password source: ${source}"
            return 1
            ;;
    esac

    return 0
}
