#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# commands/backup.sh - Create a complete project backup
# ─────────────────────────────────────────────────────────────
# Orchestrates: database dump → compression → encryption →
# archive uploads → git commit → tag → push
# ─────────────────────────────────────────────────────────────
set -Eeuo pipefail

LBACKUP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load all libraries
for _lib in colours logging env helpers validator config lock mysql postgres sqlite git github archive encrypt notifications; do
    [[ -f "${LBACKUP_ROOT}/lib/${_lib}.sh" ]] && source "${LBACKUP_ROOT}/lib/${_lib}.sh"
done
unset _lib

# ── Usage ───────────────────────────────────────────────────
usage() {
    printf '%b' "${BOLD}laravel-backup backup${NC} - Create a backup of the project

${BOLD}USAGE${NC}
    laravel-backup backup [options]

${BOLD}OPTIONS${NC}
    -h, --help          Show this help message
    -n, --dry-run       Simulate backup without making changes
    --no-encrypt        Skip encryption step
    --no-git            Skip git operations
    --no-db             Skip database dump
    --no-uploads        Skip upload folder archiving
    --verbose           Enable verbose output
    --config <file>     Use specific configuration file

${BOLD}EXAMPLES${NC}
    laravel-backup backup
    laravel-backup backup --dry-run
    laravel-backup backup --no-encrypt
    laravel-backup backup --no-git

"
    exit 0
}

# ── Parse arguments ─────────────────────────────────────────
parse_args() {
    DRY_RUN=false
    NO_ENCRYPT=false
    NO_GIT=false
    NO_DB=false
    NO_UPLOADS=false
    CONFIG_FILE=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)      usage ;;
            -n|--dry-run)   DRY_RUN=true; shift ;;
            --no-encrypt)   NO_ENCRYPT=true; shift ;;
            --no-git)       NO_GIT=true; shift ;;
            --no-db)        NO_DB=true; shift ;;
            --no-uploads)   NO_UPLOADS=true; shift ;;
            --verbose)      set_log_level "DEBUG"; shift ;;
            --config)       CONFIG_FILE="$2"; shift 2 ;;
            *)              log_error "Unknown option: $1"; usage ;;
        esac
    done
}

# ── Generate timestamp for filenames ────────────────────────
backup_timestamp() {
    date '+%Y%m%d_%H%M%S'
}

# ── Step 1: Read .env ──────────────────────────────────────
step_load_env() {
    log_header "Loading Environment"

    if [[ ! -f ".env" ]]; then
        log_error ".env file not found"
        return 1
    fi

    env_load ".env"
    log_success "Loaded .env"
}

# ── Step 2: Detect database ────────────────────────────────
step_detect_database() {
    log_header "Detecting Database"

    DB_TYPE=$(detect_database_type ".")
    if [[ -z "$DB_TYPE" ]]; then
        log_warn "No database connection configured in .env"
        DB_TYPE="none"
    else
        log_info "Database type: ${DB_TYPE}"
    fi

    case "$DB_TYPE" in
        mysql)  validate_database_connection "mysql" "." || true ;;
        pgsql)  validate_database_connection "pgsql" "." || true ;;
        sqlite) validate_database_connection "sqlite" "." || true ;;
    esac
}

# ── Step 3: Dump database ──────────────────────────────────
step_dump_database() {
    log_header "Dumping Database"

    if [[ "$NO_DB" == "true" ]]; then
        log_info "Database dump skipped (--no-db)"
        return 0
    fi

    if [[ "$DB_TYPE" == "none" ]]; then
        log_info "No database to dump"
        return 0
    fi

    local dump_file="${TEMP_DIR}/database.sql.gz"
    mkdir -p "$TEMP_DIR"

    # Trim whitespace and carriage returns
    DB_TYPE=$(echo "$DB_TYPE" | tr -d '\r' | xargs)
    log_debug "DB_TYPE='${DB_TYPE}' (length: ${#DB_TYPE})"
    
    case "$DB_TYPE" in
        mysql|mariadb)  mysql_dump "." "$dump_file" || return 1 ;;
        pgsql|postgres|postgresql)  postgres_dump "." "$dump_file" || return 1 ;;
        sqlite|sqlite3) sqlite_dump "." "$dump_file" || return 1 ;;
        *)
            log_error "Unsupported database type: '${DB_TYPE}'"
            return 1
            ;;
    esac

    DB_DUMP_FILE="$dump_file"
    DB_DUMP_SIZE=$(stat -f%z "$dump_file" 2>/dev/null || stat -c%s "$dump_file" 2>/dev/null || echo 0)
    DB_DUMP_CHECKSUM=$(checksum_file "$dump_file")

    log_success "Database dumped: $(human_size "$DB_DUMP_SIZE")"
}

# ── Step 4: Compress dump ──────────────────────────────────
step_compress_dump() {
    log_info "Database dump already compressed (.gz)"
}

# ── Step 5: Encrypt database dump ──────────────────────────
step_encrypt_database() {
    if [[ "$NO_ENCRYPT" == "true" ]] || ! encryption_enabled; then
        log_info "Encryption skipped"
        DB_ENCRYPTED_FILE="${DB_DUMP_FILE:-}"
        return 0
    fi

    if [[ -z "${DB_DUMP_FILE:-}" ]]; then
        return 0
    fi

    log_header "Encrypting Database Dump"
    DB_ENCRYPTED_FILE="${DB_DUMP_FILE}.enc"
    encrypt_file "$DB_DUMP_FILE" "$DB_ENCRYPTED_FILE" || return 1
}

# ── Step 6: Detect upload folders ──────────────────────────
step_detect_uploads() {
    log_header "Detecting Upload Folders"

    UPLOAD_DIRS=()

    while IFS= read -r dir; do
        [[ -n "$dir" ]] && UPLOAD_DIRS+=("$dir")
    done < <(detect_upload_dirs ".")

    if [[ -n "${EXTRA_UPLOAD_DIRS:-}" ]]; then
        for dir in $EXTRA_UPLOAD_DIRS; do
            if [[ -d "$dir" ]]; then
                UPLOAD_DIRS+=("$dir")
            fi
        done
    fi

    if [[ ${#UPLOAD_DIRS[@]} -eq 0 ]]; then
        log_info "No upload directories found"
    else
        log_info "Upload directories:"
        for dir in "${UPLOAD_DIRS[@]}"; do
            log_info "  - ${dir}"
        done
    fi
}

# ── Step 7: Zip upload folders ─────────────────────────────
step_archive_uploads() {
    if [[ "$NO_UPLOADS" == "true" ]]; then
        log_info "Upload archiving skipped (--no-uploads)"
        return 0
    fi

    if [[ ${#UPLOAD_DIRS[@]} -eq 0 ]]; then
        log_info "Nothing to archive"
        UPLOAD_ARCHIVE=""
        return 0
    fi

    log_header "Archiving Upload Folders"

    UPLOAD_ARCHIVE="${TEMP_DIR}/uploads.tar.gz"
    create_tar "$UPLOAD_ARCHIVE" "." "${UPLOAD_DIRS[@]}" || return 1

    UPLOAD_ARCHIVE_SIZE=$(stat -f%z "$UPLOAD_ARCHIVE" 2>/dev/null || stat -c%s "$UPLOAD_ARCHIVE" 2>/dev/null || echo 0)
    UPLOAD_ARCHIVE_CHECKSUM=$(checksum_file "$UPLOAD_ARCHIVE")
}

# ── Step 8: Encrypt upload archive ─────────────────────────
step_encrypt_uploads() {
    if [[ "$NO_ENCRYPT" == "true" ]] || ! encryption_enabled; then
        return 0
    fi

    if [[ -z "${UPLOAD_ARCHIVE:-}" ]] || [[ ! -f "${UPLOAD_ARCHIVE:-}" ]]; then
        return 0
    fi

    log_header "Encrypting Upload Archive"
    UPLOAD_ENCRYPTED_FILE="${UPLOAD_ARCHIVE}.enc"
    encrypt_file "$UPLOAD_ARCHIVE" "$UPLOAD_ENCRYPTED_FILE" || return 1
}

# ── Step 9: Generate manifest ──────────────────────────────
step_generate_manifest() {
    log_header "Generating Manifest"

    local ts
    ts=$(backup_timestamp)
    local proj_name
    proj_name=$(project_name ".")
    local manifest_file="${TEMP_DIR}/manifest.json"

    local db_type="${DB_TYPE:-none}"
    local db_name="${DB_DATABASE:-}"
    local db_size="${DB_DUMP_SIZE:-0}"
    local db_checksum="${DB_DUMP_CHECKSUM:-}"
    local db_dump_file=""
    if [[ -n "${DB_DUMP_FILE:-}" ]]; then
        db_dump_file=$(basename "${DB_DUMP_FILE}")
    fi

    local upload_checksum="${UPLOAD_ARCHIVE_CHECKSUM:-}"
    local upload_size="${UPLOAD_ARCHIVE_SIZE:-0}"
    local upload_file=""
    if [[ -n "${UPLOAD_ARCHIVE:-}" ]]; then
        upload_file=$(basename "${UPLOAD_ARCHIVE}")
    fi

    local overall_checksum=""
    local files_to_check=()
    [[ -n "${DB_ENCRYPTED_FILE:-}" ]] && [[ -f "${DB_ENCRYPTED_FILE:-}" ]] && files_to_check+=("${DB_ENCRYPTED_FILE}")
    [[ -n "${DB_DUMP_FILE:-}" ]] && [[ -f "${DB_DUMP_FILE:-}" ]] && [[ "${NO_ENCRYPT:-false}" == "true" ]] && files_to_check+=("${DB_DUMP_FILE}")
    [[ -n "${UPLOAD_ENCRYPTED_FILE:-}" ]] && [[ -f "${UPLOAD_ENCRYPTED_FILE:-}" ]] && files_to_check+=("${UPLOAD_ENCRYPTED_FILE}")
    [[ -n "${UPLOAD_ARCHIVE:-}" ]] && [[ -f "${UPLOAD_ARCHIVE:-}" ]] && [[ "${NO_ENCRYPT:-false}" == "true" ]] && files_to_check+=("${UPLOAD_ARCHIVE}")

    if [[ ${#files_to_check[@]} -gt 0 ]]; then
        overall_checksum=$(cat "${files_to_check[@]}" | sha256sum 2>/dev/null | cut -d' ' -f1 || echo "")
    fi

    # Build archives JSON
    local archives_json="[]"
    if [[ ${#UPLOAD_DIRS[@]} -gt 0 ]]; then
        archives_json="["
        local first=true
        for dir in "${UPLOAD_DIRS[@]}"; do
            [[ "$first" == "true" ]] && first=false || archives_json+=","
            archives_json+="\"${dir}\""
        done
        archives_json+="]"
    fi

    cat > "$manifest_file" <<EOF
{
  "name": "${proj_name}",
  "date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "timestamp": "${ts}",
  "laravel_version": "$(laravel_version ".")",
  "php_version": "$(php_version)",
  "os": "$(os_display_name)",
  "hostname": "$(get_hostname)",
  "git_commit": "$(git_commit ".")",
  "git_branch": "$(git_branch ".")",
  "database": {
    "type": "${db_type}",
    "name": "${db_name}",
    "size": "${db_size}",
    "dump_file": "${db_dump_file}",
    "dump_checksum": "${db_checksum}"
  },
  "archives": [
    {
      "type": "uploads",
      "file": "${upload_file}",
      "size": "${upload_size}",
      "checksum": "${upload_checksum}",
      "directories": ${archives_json}
    }
  ],
  "checksum": "${overall_checksum}",
  "backup_version": "$(cat "${LBACKUP_ROOT}/VERSION" 2>/dev/null || echo "1.0.0")",
  "encryption": $(encryption_enabled && echo "true" || echo "false")
}
EOF

    MANIFEST_FILE="$manifest_file"
    log_success "Manifest generated"
}

# ── Step 10: Move files to backup directory ─────────────────
step_finalize() {
    log_header "Finalizing Backup"

    local ts
    ts=$(backup_timestamp)
    local proj_name
    proj_name=$(project_name ".")
    local backup_dir="${BACKUP_DIR:-backups}"

    mkdir -p "$backup_dir"

    BACKUP_NAME="${proj_name}_${ts}"

    # Move database files
    if [[ -n "${DB_DUMP_FILE:-}" ]] && [[ -f "${DB_DUMP_FILE:-}" ]]; then
        cp "${DB_DUMP_FILE}" "${backup_dir}/${BACKUP_NAME}.sql.gz"
        log_info "Copied database dump"
    fi

    if [[ -n "${DB_ENCRYPTED_FILE:-}" ]] && [[ -f "${DB_ENCRYPTED_FILE:-}" ]]; then
        cp "${DB_ENCRYPTED_FILE}" "${backup_dir}/${BACKUP_NAME}.sql.gz.enc"
        log_info "Copied encrypted database dump"
    fi

    # Move upload files
    if [[ -n "${UPLOAD_ARCHIVE:-}" ]] && [[ -f "${UPLOAD_ARCHIVE:-}" ]]; then
        cp "${UPLOAD_ARCHIVE}" "${backup_dir}/${BACKUP_NAME}.uploads.tar.gz"
        log_info "Copied upload archive"
    fi

    if [[ -n "${UPLOAD_ENCRYPTED_FILE:-}" ]] && [[ -f "${UPLOAD_ENCRYPTED_FILE:-}" ]]; then
        cp "${UPLOAD_ENCRYPTED_FILE}" "${backup_dir}/${BACKUP_NAME}.uploads.tar.gz.enc"
        log_info "Copied encrypted upload archive"
    fi

    # Copy manifest
    if [[ -n "${MANIFEST_FILE:-}" ]] && [[ -f "${MANIFEST_FILE:-}" ]]; then
        cp "${MANIFEST_FILE}" "${backup_dir}/${BACKUP_NAME}.manifest.json"
    fi

    # Clean up temp files
    rm -rf "${TEMP_DIR}" 2>/dev/null || true

    log_success "Backup files saved to: ${backup_dir}/"
}

# ── Step 11: Git commit ────────────────────────────────────
step_git_commit() {
    if [[ "$NO_GIT" == "true" ]]; then
        log_info "Git operations skipped (--no-git)"
        return 0
    fi

    if [[ "${GIT_AUTO_COMMIT:-true}" != "true" ]]; then
        return 0
    fi

    if ! command_exists git; then
        log_warn "Git not installed, skipping commit"
        return 0
    fi

    log_header "Git Operations"

    # Initialize repo (and private GitHub remote) if needed
    git_init_if_needed "." || true

    local proj_name
    proj_name=$(project_name ".")
    local commit_msg="backup: ${proj_name} $(date '+%Y-%m-%d %H:%M:%S')"

    git_backup_full "." "$commit_msg" "${GIT_TAG_PREFIX:-backup}-${BACKUP_NAME}" || true
}

# ── Step 12: Create tag ────────────────────────────────────
# (Handled by git_backup_full)

# ── Step 13: Push ──────────────────────────────────────────
# (Handled by git_backup_full)

# ── Step 14: Log success ───────────────────────────────────
step_notify() {
    log_header "Backup Complete"

    local duration=$((SECONDS))
    local elapsed
    elapsed=$(elapsed_time 0 "$duration")

    log_kv "Project" "$(project_name ".")"
    log_kv "Database" "${DB_TYPE:-none}"
    log_kv "Duration" "$elapsed"
    log_kv "Files" "${BACKUP_NAME:-unknown}"
    echo ""

    notify_success "Backup Complete" \
        "Project: $(project_name ".")\nDatabase: ${DB_TYPE:-none}\nDuration: ${elapsed}"
}

# ── Cleanup on error ────────────────────────────────────────
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "Backup failed with exit code: ${exit_code}"
        rm -rf "${TEMP_DIR}" 2>/dev/null || true
        notify_failure "Backup Failed" \
            "Project: $(project_name ".")\nError: Exit code ${exit_code}"
    fi
}

# ── Main ────────────────────────────────────────────────────
main() {
    parse_args "$@"
    SECONDS=0

    trap cleanup EXIT

    # Acquire lock
    lock_acquire "backup" || exit 1
    trap 'lock_release "backup"; cleanup' EXIT

    # Load configuration
    config_load "$CONFIG_FILE" "."

    if [[ "$DRY_RUN" == "true" ]]; then
        export DRY_RUN=true
        log_info "DRY RUN MODE - no changes will be made"
    fi

    log_header "Starting Backup"
    log_kv "Project" "$(project_name ".")"
    log_kv "Time" "$(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    # Validate
    validate_laravel_project "." || exit 1
    validate_backup_dir "." || exit 1

    # Set up temp directory
    TEMP_DIR="${TEMP_DIR:-/tmp/laravel-backup}"
    mkdir -p "$TEMP_DIR"

    # Run backup steps
    step_load_env
    step_detect_database
    step_dump_database
    step_encrypt_database
    step_detect_uploads
    step_archive_uploads
    step_encrypt_uploads
    step_generate_manifest
    step_finalize
    step_git_commit
    step_notify
}

main "$@"
