#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# restore.sh - Template for auto-generated restore scripts
# This template is copied into the project during `init`
# ─────────────────────────────────────────────────────────────
set -Eeuo pipefail

# ── Configuration ───────────────────────────────────────────
RESTORE_FILE="${1:-}"
PROJECT_DIR="$(pwd)"
BACKUP_PASS="${BACKUP_PASSWORD:-}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# ── Usage ───────────────────────────────────────────────────
usage() {
    cat <<EOF
${BOLD}restore.sh${NC} - Restore a Laravel project from backup

${BOLD}USAGE${NC}
    ./restore.sh <backup-file>

${BOLD}ARGUMENTS${NC}
    backup-file     Path to the backup archive (.tar.gz.enc or .tar.gz)

${BOLD}ENVIRONMENT${NC}
    BACKUP_PASSWORD     Decryption password (if backup is encrypted)

${BOLD}EXAMPLES${NC}
    BACKUP_PASSWORD=mypassword ./restore.sh backups/project_20260727_120000.tar.gz.enc
    ./restore.sh backups/project_20260727_120000.tar.gz

EOF
    exit 0
}

# ── Dependency check ────────────────────────────────────────
check_dependencies() {
    local deps=(tar gzip)
    if [[ "$RESTORE_FILE" == *.enc ]]; then
        deps+=(openssl)
    fi

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            log_error "Required tool not found: ${dep}"
            exit 1
        fi
    done
}

# ── Prompt for password ────────────────────────────────────
get_password() {
    if [[ -z "$BACKUP_PASS" ]]; then
        if [[ "$RESTORE_FILE" == *.enc ]]; then
            read -rsp "Enter decryption password: " BACKUP_PASS
            echo ""
            if [[ -z "$BACKUP_PASS" ]]; then
                log_error "Password cannot be empty"
                exit 1
            fi
        fi
    fi
}

# ── Decrypt ─────────────────────────────────────────────────
decrypt_backup() {
    local encrypted="$1"
    local decrypted="${encrypted%.enc}"

    log_info "Decrypting backup..."
    if ! openssl enc -aes-256-cbc -d -salt -pbkdf2 \
        -in "$encrypted" \
        -out "$decrypted" \
        -pass "pass:${BACKUP_PASS}" 2>/dev/null; then
        log_error "Decryption failed. Wrong password?"
        exit 1
    fi
    echo "$decrypted"
}

# ── Extract ─────────────────────────────────────────────────
extract_backup() {
    local archive="$1"
    local tmp_dir
    tmp_dir=$(mktemp -d)

    log_info "Extracting backup..."
    if ! tar -xzf "$archive" -C "$tmp_dir"; then
        log_error "Extraction failed"
        rm -rf "$tmp_dir"
        exit 1
    fi

    echo "$tmp_dir"
}

# ── Restore database ────────────────────────────────────────
restore_database() {
    local backup_dir="$1"
    local dump_file

    dump_file=$(find "$backup_dir" -name "*.sql" -o -name "*.sql.gz" | head -1)
    if [[ -z "$dump_file" ]]; then
        log_warn "No database dump found, skipping database restore"
        return 0
    fi

    log_info "Restoring database from: $(basename "$dump_file")"

    # Detect database type from .env
    local db_type=""
    if [[ -f .env ]]; then
        db_type=$(grep -oP 'DB_CONNECTION=\K.*' .env 2>/dev/null || true)
    fi

    case "$db_type" in
        mysql|mariadb)
            if [[ "$dump_file" == *.gz ]]; then
                gunzip -c "$dump_file" | mysql -h "${DB_HOST:-127.0.0.1}" -u "${DB_USERNAME:-}" -p"${DB_PASSWORD:-}" "${DB_DATABASE:-}" 2>/dev/null
            else
                mysql -h "${DB_HOST:-127.0.0.1}" -u "${DB_USERNAME:-}" -p"${DB_PASSWORD:-}" "${DB_DATABASE:-}" < "$dump_file" 2>/dev/null
            fi
            ;;
        pgsql|postgres)
            if [[ "$dump_file" == *.gz ]]; then
                gunzip -c "$dump_file" | PGPASSWORD="${DB_PASSWORD:-}" pg -h "${DB_HOST:-127.0.0.1}" -U "${DB_USERNAME:-}" -d "${DB_DATABASE:-}" 2>/dev/null
            else
                PGPASSWORD="${DB_PASSWORD:-}" pg -h "${DB_HOST:-127.0.0.1}" -U "${DB_USERNAME:-}" -d "${DB_DATABASE:-}" < "$dump_file" 2>/dev/null
            fi
            ;;
        sqlite|sqlite3)
            local sqlite_path="${DB_DATABASE:-database/database.sqlite}"
            if [[ "$dump_file" == *.gz ]]; then
                gunzip -c "$dump_file" > "$sqlite_path"
            else
                cp "$dump_file" "$sqlite_path"
            fi
            ;;
        *)
            log_warn "Unknown database type '${db_type}', attempting generic restore"
            if [[ "$dump_file" == *.gz ]]; then
                gunzip -c "$dump_file" > /dev/null 2>&1 || true
            fi
            ;;
    esac

    log_info "Database restored"
}

# ── Restore uploads ─────────────────────────────────────────
restore_uploads() {
    local backup_dir="$1"
    local uploads_dir="${backup_dir}/uploads"

    if [[ ! -d "$uploads_dir" ]]; then
        log_warn "No uploads directory found in backup"
        return 0
    fi

    log_info "Restoring upload files..."
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
        if [[ -d "${uploads_dir}/${dir}" ]]; then
            mkdir -p "$dir"
            cp -a "${uploads_dir}/./${dir}/." "$dir/" 2>/dev/null || true
            log_info "  Restored: ${dir}"
        fi
    done
}

# ── Post-restore tasks ──────────────────────────────────────
post_restore() {
    log_info "Running post-restore tasks..."

    if [[ -f "composer.json" ]]; then
        if command -v composer &>/dev/null; then
            log_info "  Running composer install..."
            composer install --no-dev --optimize-autoloader 2>/dev/null || \
                log_warn "  composer install failed (non-fatal)"
        fi
    fi

    if [[ -f "artisan" ]]; then
        if command -v php &>/dev/null; then
            log_info "  Creating storage link..."
            php artisan storage:link 2>/dev/null || true

            log_info "  Clearing cache..."
            php artisan optimize:clear 2>/dev/null || true

            log_info "  Running migrations..."
            php artisan migrate --force 2>/dev/null || true
        fi
    fi
}

# ── Main ────────────────────────────────────────────────────
main() {
    if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
        usage
    fi

    if [[ -z "${RESTORE_FILE:-}" ]]; then
        log_error "No backup file specified"
        echo "Usage: $0 <backup-file>"
        exit 1
    fi

    if [[ ! -f "$RESTORE_FILE" ]]; then
        log_error "Backup file not found: ${RESTORE_FILE}"
        exit 1
    fi

    check_dependencies
    get_password

    local working_file="$RESTORE_FILE"
    local tmp_dir=""

    # Decrypt if needed
    if [[ "$RESTORE_FILE" == *.enc ]]; then
        working_file=$(decrypt_backup "$RESTORE_FILE")
        trap 'rm -f "${working_file}" 2>/dev/null' EXIT
    fi

    # Extract
    tmp_dir=$(extract_backup "$working_file")
    trap 'rm -rf "${tmp_dir}" "${working_file}" 2>/dev/null' EXIT

    # Find backup contents
    local backup_root="${tmp_dir}"
    # Handle nested directories
    if [[ $(find "$tmp_dir" -maxdepth 1 -type d | wc -l) -eq 2 ]]; then
        backup_root=$(find "$tmp_dir" -maxdepth 1 -type d -not -path "$tmp_dir" | head -1)
    fi

    # Restore
    restore_database "$backup_root"
    restore_uploads "$backup_root"
    post_restore

    log_info "Restore complete!"
}

main "$@"
