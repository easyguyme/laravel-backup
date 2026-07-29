#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# commands/restore.sh - Restore a project from backup
# ─────────────────────────────────────────────────────────────
# Decrypts, extracts, restores database, uploads, and runs
# post-restore tasks (composer, artisan).
# ─────────────────────────────────────────────────────────────
set -Eeuo pipefail

LBACKUP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for _lib in colours logging env helpers validator config lock mysql postgres sqlite archive encrypt notifications; do
    [[ -f "${LBACKUP_ROOT}/lib/${_lib}.sh" ]] && source "${LBACKUP_ROOT}/lib/${_lib}.sh"
done
unset _lib

# ── Usage ───────────────────────────────────────────────────
usage() {
    printf '%b' "${BOLD}laravel-backup restore${NC} - Restore a project from backup

${BOLD}USAGE${NC}
    laravel-backup restore [options] [backup-file]

${BOLD}OPTIONS${NC}
    -h, --help          Show this help message
    --no-db             Skip database restore
    --no-uploads        Skip upload restore
    --no-composer       Skip composer install
    --no-artisan        Skip artisan commands
    --config <file>     Use specific config file

${BOLD}EXAMPLES${NC}
    laravel-backup restore ./backups/project_20260727_120000.tar.gz.enc
    laravel-backup restore --no-db

"
    exit 0
}

# ── Parse arguments ─────────────────────────────────────────
parse_args() {
    RESTORE_FILE=""
    NO_DB=false
    NO_UPLOADS=false
    NO_COMPOSER=false
    NO_ARTISAN=false
    CONFIG_FILE=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)          usage ;;
            --no-db)            NO_DB=true; shift ;;
            --no-uploads)       NO_UPLOADS=true; shift ;;
            --no-composer)      NO_COMPOSER=true; shift ;;
            --no-artisan)       NO_ARTISAN=true; shift ;;
            --config)           CONFIG_FILE="$2"; shift 2 ;;
            -*)                 log_error "Unknown option: $1"; usage ;;
            *)                  RESTORE_FILE="$1"; shift ;;
        esac
    done
}

# ── Find latest backup if none specified ────────────────────
find_latest_backup() {
    local backup_dir="${BACKUP_DIR:-backups}"

    if [[ ! -d "$backup_dir" ]]; then
        log_error "Backup directory not found: ${backup_dir}"
        return 1
    fi

    local latest
    latest=$(ls -1t "${backup_dir}"/*.tar.gz.enc "${backup_dir}"/*.tar.gz 2>/dev/null | head -1 || true)

    if [[ -z "$latest" ]]; then
        log_error "No backup files found in ${backup_dir}"
        return 1
    fi

    echo "$latest"
}

# ── List available backups ──────────────────────────────────
list_backups() {
    local backup_dir="${BACKUP_DIR:-backups}"

    if [[ ! -d "$backup_dir" ]]; then
        echo "No backups found"
        return 0
    fi

    printf '%b\n' "${BOLD}Available backups:${NC}"
    local count=0
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        local size
        size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 0)
        local date
        date=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$file" 2>/dev/null || stat -c "%y" "$file" 2>/dev/null | cut -d. -f1 || echo "unknown")
        printf '  %s  %10s  %s\n' "$date" "$(human_size "$size")" "$(basename "$file")"
        ((count++)) || true
    done < <(ls -1t "${backup_dir}"/*.tar.gz.enc "${backup_dir}"/*.tar.gz 2>/dev/null || true)

    if [[ $count -eq 0 ]]; then
        echo "  No backups found"
    fi
}

# ── Decrypt backup if needed ────────────────────────────────
restore_decrypt() {
    local file="$1"
    local output_dir="$2"

    if [[ "$file" == *.enc ]]; then
        log_info "Decrypting backup..."
        local decrypted="${output_dir}/$(basename "${file%.enc}")"
        if ! encrypt_file_for_decrypt "$file" "$decrypted"; then
            log_error "Decryption failed"
            return 1
        fi
        echo "$decrypted"
    else
        echo "$file"
    fi
}

# Wrapper for decrypt (encrypt_file removes input, we need the opposite)
encrypt_file_for_decrypt() {
    local input="$1"
    local output="$2"

    local password
    password=$(encrypt_get_password) || return 1

    openssl enc -aes-256-cbc -d -salt -pbkdf2 -iter 100000 \
        -in "$input" \
        -out "$output" \
        -pass "pass:${password}" 2>/dev/null
}

# ── Extract backup ──────────────────────────────────────────
restore_extract() {
    local archive="$1"
    local output_dir="$2"

    log_info "Extracting backup..."
    mkdir -p "$output_dir"

    if ! tar -xzf "$archive" -C "$output_dir" 2>/dev/null; then
        log_error "Extraction failed"
        return 1
    fi

    # Handle nested directories
    local subdirs
    subdirs=$(find "$output_dir" -maxdepth 1 -type d -not -path "$output_dir" | wc -l)
    if [[ "$subdirs" -eq 1 ]]; then
        local inner
        inner=$(find "$output_dir" -maxdepth 1 -type d -not -path "$output_dir" | head -1)
        if [[ -n "$inner" ]]; then
            mv "${inner}"/* "${output_dir}/" 2>/dev/null || true
            rmdir "$inner" 2>/dev/null || true
        fi
    fi

    log_success "Extracted to: ${output_dir}"
}

# ── Restore database ────────────────────────────────────────
restore_database() {
    local backup_dir="$1"

    if [[ "$NO_DB" == "true" ]]; then
        log_info "Database restore skipped"
        return 0
    fi

    log_header "Restoring Database"

    local dump_file
    dump_file=$(find "$backup_dir" -name "*.sql.gz" -o -name "*.sql" | head -1 || true)

    if [[ -z "$dump_file" ]]; then
        log_warn "No database dump found in backup"
        return 0
    fi

    # Detect DB type from .env
    local db_type
    db_type=$(detect_database_type ".")

    case "$db_type" in
        mysql)
            mysql_restore "." "$dump_file" || return 1
            ;;
        pgsql)
            postgres_restore "." "$dump_file" || return 1
            ;;
        sqlite)
            sqlite_restore "." "$dump_file" || return 1
            ;;
        *)
            log_warn "Cannot restore database (type unknown)"
            return 0
            ;;
    esac
}

# ── Restore uploads ─────────────────────────────────────────
restore_uploads() {
    local backup_dir="$1"

    if [[ "$NO_UPLOADS" == "true" ]]; then
        log_info "Upload restore skipped"
        return 0
    fi

    log_header "Restoring Uploads"

    local uploads_archive
    uploads_archive=$(find "$backup_dir" -name "*.uploads.tar.gz" -o -name "*.uploads.tar.gz.enc" | head -1 || true)

    if [[ -z "$uploads_archive" ]]; then
        log_warn "No uploads archive found"
        return 0
    fi

    # Decrypt if needed
    local archive="$uploads_archive"
    if [[ "$uploads_archive" == *.enc ]]; then
        local decrypted="${TEMP_DIR}/uploads.tar.gz"
        mkdir -p "$TEMP_DIR"
        encrypt_file_for_decrypt "$uploads_archive" "$decrypted" || return 1
        archive="$decrypted"
    fi

    # Extract
    local extract_dir="${TEMP_DIR}/uploads_extract"
    mkdir -p "$extract_dir"
    tar -xzf "$archive" -C "$extract_dir" 2>/dev/null || {
        log_error "Failed to extract uploads"
        return 1
    }

    # Restore known directories
    local dirs_to_restore=(
        "storage/app"
        "storage/app/public"
        "public/storage"
        "public/uploads"
        "uploads"
        "images"
        "media"
    )

    for dir in "${dirs_to_restore[@]}"; do
        if [[ -d "${extract_dir}/${dir}" ]]; then
            mkdir -p "$dir"
            cp -a "${extract_dir}/./${dir}/." "$dir/" 2>/dev/null || true
            log_info "  Restored: ${dir}"
        fi
    done

    log_success "Uploads restored"
}

# ── Post-restore tasks ──────────────────────────────────────
post_restore() {
    log_header "Post-Restore Tasks"

    if [[ "$NO_COMPOSER" != "true" ]] && [[ -f "composer.json" ]]; then
        if command_exists composer; then
            log_info "Running composer install..."
            composer install --no-dev --optimize-autoloader 2>/dev/null || \
                log_warn "composer install failed (non-fatal)"
        fi
    fi

    if [[ "$NO_ARTISAN" != "true" ]] && [[ -f "artisan" ]]; then
        if command_exists php; then
            log_info "Creating storage link..."
            php artisan storage:link 2>/dev/null || true

            log_info "Clearing cache..."
            php artisan optimize:clear 2>/dev/null || true

            log_info "Running migrations..."
            php artisan migrate --force 2>/dev/null || true
        fi
    fi
}

# ── Cleanup ─────────────────────────────────────────────────
cleanup_restore() {
    rm -rf "${TEMP_DIR}" 2>/dev/null || true
}

# ── Main ────────────────────────────────────────────────────
main() {
    parse_args "$@"
    SECONDS=0

    trap cleanup_restore EXIT

    config_load "$CONFIG_FILE" "."

    # Load .env if it exists
    if [[ -f ".env" ]]; then
        env_load ".env"
    fi

    # Find backup file
    if [[ -z "$RESTORE_FILE" ]]; then
        list_backups
        echo ""
        RESTORE_FILE=$(find_latest_backup) || exit 1
        log_info "Using latest: $(basename "$RESTORE_FILE")"
    fi

    if ! validate_backup_file "$RESTORE_FILE"; then
        exit 1
    fi

    log_header "Starting Restore"
    log_kv "Backup" "$(basename "$RESTORE_FILE")"
    log_kv "Time" "$(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    # Set up temp directory
    TEMP_DIR="${TEMP_DIR:-/tmp/laravel-backup}"
    mkdir -p "$TEMP_DIR"

    # Decrypt if needed
    local working_file="$RESTORE_FILE"
    if [[ "$RESTORE_FILE" == *.enc ]]; then
        working_file=$(restore_decrypt "$RESTORE_FILE" "$TEMP_DIR") || exit 1
    fi

    # Extract
    local extract_dir="${TEMP_DIR}/extracted"
    restore_extract "$working_file" "$extract_dir" || exit 1

    # Find backup contents
    local backup_root="$extract_dir"
    if [[ $(find "$extract_dir" -maxdepth 1 -type d | wc -l) -eq 2 ]]; then
        backup_root=$(find "$extract_dir" -maxdepth 1 -type d -not -path "$extract_dir" | head -1)
    fi

    # Restore
    restore_database "$backup_root" || exit 1
    restore_uploads "$backup_root" || exit 1
    post_restore

    # Done
    local duration=$((SECONDS))
    log_header "Restore Complete"
    log_kv "Duration" "$(elapsed_time 0 "$duration")"
    notify_success "Restore Complete" "Project restored in $(elapsed_time 0 "$duration")"
}

main "$@"
