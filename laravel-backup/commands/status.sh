#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# commands/status.sh - Show project and backup status
# ─────────────────────────────────────────────────────────────
set -Eeuo pipefail

LBACKUP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for _lib in colours logging env helpers validator config git env; do
    [[ -f "${LBACKUP_ROOT}/lib/${_lib}.sh" ]] && source "${LBACKUP_ROOT}/lib/${_lib}.sh"
done
unset _lib

usage() {
    printf '%b' "${BOLD}laravel-backup status${NC} - Show project status

${BOLD}USAGE${NC}
    laravel-backup status

${BOLD}OUTPUT${NC}
    Current project, database, last backup, repository,
    branch, pending changes, remote, backup count, latest tag

"
    exit 0
}

# ── Count backups ───────────────────────────────────────────
count_backups() {
    local backup_dir="${BACKUP_DIR:-backups}"
    if [[ -d "$backup_dir" ]]; then
        ls -1 "${backup_dir}"/*.tar.gz.enc "${backup_dir}"/*.tar.gz 2>/dev/null | wc -l | tr -d ' '
    else
        echo "0"
    fi
}

# ── Get latest backup date ─────────────────────────────────
latest_backup_date() {
    local backup_dir="${BACKUP_DIR:-backups}"
    if [[ -d "$backup_dir" ]]; then
        local latest
        latest=$(ls -1t "${backup_dir}"/*.tar.gz.enc "${backup_dir}"/*.tar.gz 2>/dev/null | head -1 || true)
        if [[ -n "$latest" ]]; then
            stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$latest" 2>/dev/null || \
            stat -c "%y" "$latest" 2>/dev/null | cut -d. -f1 || \
            echo "unknown"
        else
            echo "never"
        fi
    else
        echo "never"
    fi
}

# ── Get latest tag ─────────────────────────────────────────
latest_tag() {
    if git_available "."; then
        git -C "." describe --tags --abbrev=0 2>/dev/null || echo "none"
    else
        echo "N/A"
    fi
}

# ── Main ────────────────────────────────────────────────────
main() {
    [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage

    log_header "laravel-backup Status"

    # Project info
    log_kv "Project" "$(project_name ".")"
    log_kv "Path" "$(pwd)"

    # Laravel
    if detect_laravel "."; then
        local ver
        ver=$(laravel_version ".")
        log_kv "Laravel" "${ver}"
    else
        log_kv "Laravel" "Not a Laravel project"
    fi

    # PHP
    log_kv "PHP" "$(php_version)"

    # OS
    log_kv "OS" "$(os_display_name)"

    echo ""

    # Database
    local db_type
    db_type=$(detect_database_type ".")
    log_kv "Database" "${db_type:-not configured}"

    echo ""

    # Git
    if git_available "."; then
        log_kv "Repository" "Yes"
        log_kv "Branch" "$(git_branch ".")"
        log_kv "Commit" "$(git_commit ".")"
        log_kv "Remote" "$(git_remote_url "." || echo 'none')"
        log_kv "Pending" "$(git_changes_count ".") change(s)"
        log_kv "Latest Tag" "$(latest_tag)"
    else
        log_kv "Repository" "Not a git repository"
    fi

    echo ""

    # Backups
    log_kv "Backup Count" "$(count_backups)"
    log_kv "Last Backup" "$(latest_backup_date)"
    log_kv "Backup Dir" "${BACKUP_DIR:-backups}"

    # Config
    log_kv "Config" "$([ -f backup.conf ] && echo 'backup.conf' || echo 'using defaults')"
}

main "$@"
