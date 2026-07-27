#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# commands/init.sh - Initialize laravel-backup in a project
# ─────────────────────────────────────────────────────────────
set -Eeuo pipefail

LBACKUP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for _lib in colours logging env helpers validator config git; do
    [[ -f "${LBACKUP_ROOT}/lib/${_lib}.sh" ]] && source "${LBACKUP_ROOT}/lib/${_lib}.sh"
done
unset _lib

usage() {
    printf '%b' "${BOLD}laravel-backup init${NC} - Initialize laravel-backup

${BOLD}USAGE${NC}
    laravel-backup init [options]

${BOLD}OPTIONS${NC}
    -h, --help          Show this help message
    --force             Overwrite existing configuration
    --github            Create GitHub repository
    --private           Make GitHub repo private (default)

${BOLD}WHAT IT DOES${NC}
    - Detects Laravel project
    - Detects Git repository
    - Creates backup.conf
    - Creates backups/ directory
    - Generates restore.sh
    - Updates .gitignore
    - Verifies permissions

"
    exit 0
}

parse_args() {
    FORCE=false
    CREATE_GITHUB=false
    GITHUB_PRIVATE=true

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)      usage ;;
            --force)        FORCE=true; shift ;;
            --github)       CREATE_GITHUB=true; shift ;;
            --private)      GITHUB_PRIVATE=true; shift ;;
            --public)       GITHUB_PRIVATE=false; shift ;;
            *)              log_error "Unknown option: $1"; usage ;;
        esac
    done
}

# ── Step 1: Detect Laravel ─────────────────────────────────
check_laravel() {
    log_header "Checking Project"

    if ! detect_laravel "."; then
        log_error "Not a Laravel project"
        log_info "Run this command from a Laravel project root"
        exit 1
    fi

    log_success "Laravel project detected"
    log_kv "Project" "$(project_name ".")"

    local ver
    ver=$(laravel_version ".")
    if [[ "$ver" != "unknown" ]]; then
        log_kv "Laravel" "$ver"
    fi
}

# ── Step 2: Detect Git ─────────────────────────────────────
check_git() {
    if git_available "."; then
        log_success "Git repository detected"
        log_kv "Branch" "$(git_branch ".")"
        log_kv "Remote" "$(git_remote_url "." || echo 'none')"
    else
        log_warn "No Git repository detected"
    fi
}

# ── Step 3: Detect OS ──────────────────────────────────────
check_os() {
    log_info "OS: $(os_display_name)"
}

# ── Step 4: Create configuration ───────────────────────────
create_config() {
    log_header "Creating Configuration"

    if [[ -f "backup.conf" ]] && [[ "$FORCE" != "true" ]]; then
        log_info "Configuration already exists (use --force to overwrite)"
        return 0
    fi

    config_create "backup.conf"
}

# ── Step 5: Create backup directory ────────────────────────
create_backup_dir() {
    local backup_dir="${BACKUP_DIR:-backups}"

    if [[ -d "$backup_dir" ]]; then
        log_info "Backup directory exists: ${backup_dir}"
    else
        mkdir -p "$backup_dir"
        log_info "Created: ${backup_dir}"
    fi

    # Create .gitkeep
    touch "${backup_dir}/.gitkeep" 2>/dev/null || true
}

# ── Step 6: Generate restore.sh ────────────────────────────
generate_restore() {
    log_header "Generating Restore Script"

    if [[ -f "restore.sh" ]] && [[ "$FORCE" != "true" ]]; then
        log_info "restore.sh already exists (use --force to overwrite)"
        return 0
    fi

    local template="${LBACKUP_ROOT}/templates/restore.sh"
    if [[ -f "$template" ]]; then
        cp "$template" "restore.sh"
        chmod +x "restore.sh"
        log_success "Created restore.sh"
    else
        log_warn "Restore template not found"
    fi
}

# ── Step 7: Update .gitignore ──────────────────────────────
update_gitignore() {
    log_header "Updating .gitignore"

    local gitignore_template="${LBACKUP_ROOT}/templates/gitignore"

    if [[ ! -f "$gitignore_template" ]]; then
        log_warn "Gitignore template not found"
        return 0
    fi

    if [[ -f ".gitignore" ]]; then
        # Check if already configured
        if grep -q "backups/" ".gitignore" 2>/dev/null; then
            log_info ".gitignore already configured"
            return 0
        fi

        # Append
        echo "" >> ".gitignore"
        echo "# laravel-backup" >> ".gitignore"
        while IFS= read -r line; do
            [[ -n "$line" ]] && echo "$line" >> ".gitignore"
        done < "$gitignore_template"
    else
        cp "$gitignore_template" ".gitignore"
    fi

    log_success "Updated .gitignore"
}

# ── Step 8: Verify permissions ─────────────────────────────
verify_permissions() {
    log_header "Verifying Permissions"

    local issues=0

    # Check write access
    if [[ ! -w "." ]]; then
        log_error "No write permission in project root"
        ((issues++)) || true
    fi

    local backup_dir="${BACKUP_DIR:-backups}"
    if [[ -d "$backup_dir" ]] && [[ ! -w "$backup_dir" ]]; then
        log_error "No write permission in backup directory"
        ((issues++)) || true
    fi

    if [[ $issues -eq 0 ]]; then
        log_success "All permissions OK"
    fi

    return $issues
}

# ── GitHub setup ────────────────────────────────────────────
setup_github() {
    if [[ "$CREATE_GITHUB" != "true" ]]; then
        return 0
    fi

    if ! github_available; then
        log_warn "GitHub CLI not available or not authenticated"
        return 0
    fi

    log_header "GitHub Setup"

    local name
    name=$(project_name ".")
    local visibility="private"
    if [[ "$GITHUB_PRIVATE" != "true" ]]; then
        visibility="public"
    fi

    local repo_url
    repo_url=$(github_create_repo "$name" "$visibility") || return 1

    if [[ -n "$repo_url" ]]; then
        github_add_remote "." "$repo_url" || true
    fi
}

# ── Main ────────────────────────────────────────────────────
main() {
    parse_args "$@"

    log_header "laravel-backup Init"

    check_laravel
    check_git
    check_os
    create_config
    create_backup_dir
    generate_restore
    update_gitignore
    verify_permissions || true
    setup_github

    log_header "Setup Complete"
    log_info "Edit backup.conf to configure your backup settings"
    log_info "Run 'laravel-backup backup' to create your first backup"
}

main "$@"
