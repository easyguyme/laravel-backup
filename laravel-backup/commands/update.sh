#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# commands/update.sh - Update laravel-backup to latest version
# ─────────────────────────────────────────────────────────────
set -Eeuo pipefail

LBACKUP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for _lib in colours logging env helpers; do
    [[ -f "${LBACKUP_ROOT}/lib/${_lib}.sh" ]] && source "${LBACKUP_ROOT}/lib/${_lib}.sh"
done
unset _lib

CURRENT_VERSION="$(cat "${LBACKUP_ROOT}/VERSION" 2>/dev/null || echo "0.0.0")"
REPO="easyguyme/laravel-backup"

usage() {
    printf '%b' "${BOLD}laravel-backup update${NC} - Update to latest version

${BOLD}USAGE${NC}
    laravel-backup update [options]

${BOLD}OPTIONS${NC}
    -h, --help      Show this help message
    --check         Check for updates without installing
    --from-git      Update from Git repository

${BOLD}CURRENT VERSION${NC}
    v${CURRENT_VERSION}

"
    exit 0
}

parse_args() {
    CHECK_ONLY=false
    FROM_GIT=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)      usage ;;
            --check)        CHECK_ONLY=true; shift ;;
            --from-git)     FROM_GIT=true; shift ;;
            *)              log_error "Unknown option: $1"; usage ;;
        esac
    done
}

# ── Check for updates via GitHub releases ───────────────────
check_github_release() {
    if ! command_exists gh; then
        log_warn "GitHub CLI not available"
        return 1
    fi

    local latest
    latest=$(gh release list --repo "$REPO" --limit 1 --json tagName --jq '.[0].tagName' 2>/dev/null || echo "")

    if [[ -z "$latest" ]]; then
        log_warn "Could not check for updates"
        return 1
    fi

    echo "$latest"
}

# ── Compare versions ────────────────────────────────────────
version_gt() {
    local v1="$1"
    local v2="$2"

    # Simple version comparison
    if [[ "$v1" == "$v2" ]]; then
        return 1
    fi

    local IFS=.
    read -ra v1_parts <<< "$v1"
    read -ra v2_parts <<< "$v2"

    for ((i = 0; i < ${#v1_parts[@]}; i++)); do
        local p1="${v1_parts[$i]:-0}"
        local p2="${v2_parts[$i]:-0}"

        if [[ "$p1" -gt "$p2" ]]; then
            return 0
        elif [[ "$p1" -lt "$p2" ]]; then
            return 1
        fi
    done

    return 1
}

# ── Update from git ────────────────────────────────────────
update_from_git() {
    log_header "Updating from Git"

    local git_dir
    git_dir=$(git -C "$LBACKUP_ROOT" rev-parse --show-toplevel 2>/dev/null || echo "")

    if [[ -z "$git_dir" ]]; then
        log_error "Not a git repository"
        return 1
    fi

    log_info "Pulling latest changes..."
    if ! git -C "$LBACKUP_ROOT" pull --rebase 2>/dev/null; then
        log_error "Git pull failed"
        return 1
    fi

    log_success "Updated from git"
    log_info "New version: $(cat "${LBACKUP_ROOT}/VERSION" 2>/dev/null || echo "unknown")"
}

# ── Update from release archive ─────────────────────────────
update_from_release() {
    log_header "Updating from Release"

    if ! command_exists gh; then
        log_error "GitHub CLI required for this update method"
        log_info "Install: https://cli.github.com"
        return 1
    fi

    local latest
    latest=$(check_github_release) || return 1

    log_info "Latest version: ${latest}"
    log_info "Current version: v${CURRENT_VERSION}"

    if [[ "$latest" == "v${CURRENT_VERSION}" ]]; then
        log_success "Already up to date"
        return 0
    fi

    log_info "Downloading release..."
    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap 'rm -rf "$tmp_dir"' RETURN

    if ! gh release download "$latest" \
        --repo "$REPO" \
        --pattern "*.tar.gz" \
        --output "${tmp_dir}/release.tar.gz" 2>/dev/null; then
        log_error "Failed to download release"
        return 1
    fi

    log_info "Extracting..."
    tar -xzf "${tmp_dir}/release.tar.gz" -C "$tmp_dir" 2>/dev/null

    # Find the extracted directory
    local extracted
    extracted=$(find "$tmp_dir" -maxdepth 1 -type d -not -path "$tmp_dir" | head -1)

    if [[ -z "$extracted" ]]; then
        log_error "Failed to extract release"
        return 1
    fi

    # Backup current version
    local backup_dir="${tmp_dir}/old"
    mkdir -p "$backup_dir"
    cp -a "$LBACKUP_ROOT"/. "$backup_dir/" 2>/dev/null || true

    # Copy new files
    cp -a "${extracted}/." "$LBACKUP_ROOT/" 2>/dev/null || {
        log_error "Failed to copy update"
        # Restore from backup
        cp -a "${backup_dir}/." "$LBACKUP_ROOT/" 2>/dev/null || true
        return 1
    }

    chmod +x "${LBACKUP_ROOT}/laravel-backup" 2>/dev/null || true

    log_success "Updated to ${latest}"
}

main() {
    parse_args "$@"

    log_header "laravel-backup Update"
    log_kv "Current" "v${CURRENT_VERSION}"
    log_kv "Path" "$LBACKUP_ROOT"
    echo ""

    # Check for latest version
    local latest=""
    if command_exists gh && gh auth status &>/dev/null; then
        latest=$(check_github_release 2>/dev/null || echo "")
    fi

    if [[ -n "$latest" ]]; then
        log_kv "Latest" "$latest"

        if [[ "$latest" == "v${CURRENT_VERSION}" ]]; then
            log_success "Already up to date!"
            exit 0
        fi

        if [[ "$CHECK_ONLY" == "true" ]]; then
            log_info "Update available: ${latest}"
            log_info "Run 'laravel-backup update' to install"
            exit 0
        fi
    else
        if [[ "$CHECK_ONLY" == "true" ]]; then
            log_warn "Could not check for updates"
            exit 1
        fi
    fi

    # Perform update
    if [[ "$FROM_GIT" == "true" ]]; then
        update_from_git
    else
        update_from_release
    fi
}

main "$@"
