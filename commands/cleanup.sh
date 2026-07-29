#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# commands/cleanup.sh - Remove old backups based on retention
# ─────────────────────────────────────────────────────────────
set -Eeuo pipefail

LBACKUP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for _lib in colours logging env helpers validator config; do
    [[ -f "${LBACKUP_ROOT}/lib/${_lib}.sh" ]] && source "${LBACKUP_ROOT}/lib/${_lib}.sh"
done
unset _lib

usage() {
    printf '%b' "${BOLD}laravel-backup cleanup${NC} - Remove old backups

${BOLD}USAGE${NC}
    laravel-backup cleanup [options]

${BOLD}OPTIONS${NC}
    -h, --help          Show this help message
    -n, --retain <N>    Number of backups to keep
    --older-than <D>    Remove backups older than D days
    --dry-run           Show what would be deleted
    --force             Skip confirmation

"
    exit 0
}

parse_args() {
    RETAIN_COUNT=""
    OLDER_THAN=""
    DRY_RUN=false
    FORCE=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)          usage ;;
            -n|--retain)        RETAIN_COUNT="$2"; shift 2 ;;
            --older-than)       OLDER_THAN="$2"; shift 2 ;;
            -n|--dry-run)       DRY_RUN=true; shift ;;
            --force)            FORCE=true; shift ;;
            *)                  log_error "Unknown option: $1"; usage ;;
        esac
    done
}

# ── Remove backups by count ────────────────────────────────
cleanup_by_count() {
    local count="$1"
    local backup_dir="${BACKUP_DIR:-backups}"

    if [[ ! -d "$backup_dir" ]]; then
        log_info "No backup directory found"
        return 0
    fi

    local files=()
    while IFS= read -r f; do
        [[ -n "$f" ]] && files+=("$f")
    done < <(ls -1t "${backup_dir}"/*.tar.gz.enc "${backup_dir}"/*.tar.gz "${backup_dir}"/*.manifest.json 2>/dev/null || true)

    local total=${#files[@]}
    if [[ $total -le $count ]]; then
        log_info "Only ${total} backup(s) found, keeping all"
        return 0
    fi

    local to_delete=$((total - count))
    log_info "Found ${total} backup(s), removing ${to_delete} oldest"

    local deleted=0
    for ((i = count; i < total; i++)); do
        local file="${files[$i]}"
        [[ -z "$file" ]] && continue

        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "Would delete: $(basename "$file")"
        else
            rm -f "$file" 2>/dev/null || true
            log_debug "Deleted: $(basename "$file")"
        fi
        ((deleted++)) || true
    done

    if [[ "$DRY_RUN" != "true" ]]; then
        log_success "Removed ${deleted} backup(s)"
    fi
}

# ── Remove backups by age ──────────────────────────────────
cleanup_by_age() {
    local days="$1"
    local backup_dir="${BACKUP_DIR:-backups}"

    if [[ ! -d "$backup_dir" ]]; then
        return 0
    fi

    log_info "Removing backups older than ${days} days"

    local count=0
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue

        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "Would delete: $(basename "$file")"
        else
            rm -f "$file" 2>/dev/null || true
            log_debug "Deleted: $(basename "$file")"
        fi
        ((count++)) || true
    done < <(find "$backup_dir" -maxdepth 1 \( -name "*.tar.gz" -o -name "*.tar.gz.enc" -o -name "*.manifest.json" \) -mtime "+${days}" 2>/dev/null)

    if [[ $count -gt 0 ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "Would delete ${count} file(s)"
        else
            log_success "Removed ${count} file(s)"
        fi
    else
        log_info "No files older than ${days} days"
    fi
}

main() {
    parse_args "$@"

    config_load "" "."

    log_header "Backup Cleanup"

    local retain="${RETAIN_COUNT:-${RETENTION_COUNT:-10}}"
    local days="${OLDER_THAN:-${RETENTION_DAYS:-0}}"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN MODE"
    fi

    # Count-based cleanup
    if [[ $retain -gt 0 ]]; then
        cleanup_by_count "$retain"
    fi

    # Age-based cleanup
    if [[ $days -gt 0 ]]; then
        cleanup_by_age "$days"
    fi

    log_success "Cleanup complete"
}

main "$@"
