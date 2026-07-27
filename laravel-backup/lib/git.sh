#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# git.sh - Git operations for backup
# ─────────────────────────────────────────────────────────────
# Provides git commit, tag, and push operations for backup
# integration. Supports GitHub, GitLab, Bitbucket, and
# Azure DevOps remotes.
# ─────────────────────────────────────────────────────────────

# ── Check if git is available and we're in a repo ───────────
git_available() {
    local project_root="${1:-$(pwd)}"
    command_exists git && \
    git -C "$project_root" rev-parse --is-inside-work-tree &>/dev/null
}

# ── Get current branch name ─────────────────────────────────
git_current_branch() {
    local project_root="${1:-$(pwd)}"
    git -C "$project_root" branch --show-current 2>/dev/null || echo "unknown"
}

# ── Get short commit hash ───────────────────────────────────
git_short_hash() {
    local project_root="${1:-$(pwd)}"
    git -C "$project_root" rev-parse --short HEAD 2>/dev/null || echo "unknown"
}

# ── Check for uncommitted changes ───────────────────────────
git_has_changes() {
    local project_root="${1:-$(pwd)}"
    ! git -C "$project_root" diff --quiet HEAD 2>/dev/null || \
    ! git -C "$project_root" diff --quiet --cached 2>/dev/null
}

# ── Count uncommitted changes ───────────────────────────────
git_changes_count() {
    local project_root="${1:-$(pwd)}"
    git -C "$project_root" status --porcelain 2>/dev/null | wc -l | tr -d ' '
}

# ── Stage and commit backup files ───────────────────────────
# Usage: git_commit_backup <project_root> <message>
git_commit_backup() {
    local project_root="$1"
    local message="$2"
    local backup_dir="${BACKUP_DIR:-backups}"

    if ! git_available "$project_root"; then
        log_warn "Git not available, skipping commit"
        return 0
    fi

    log_info "Committing backup to git..."

    # Stage backup directory
    git -C "$project_root" add "${backup_dir}/" 2>/dev/null || true

    # Stage manifest if present
    git -C "$project_root" add "manifest.json" 2>/dev/null || true

    # Check if there are changes to commit
    if git -C "$project_root" diff --cached --quiet 2>/dev/null; then
        log_debug "No backup changes to commit"
        return 0
    fi

    # Create commit
    if ! git -C "$project_root" commit -m "$message" --quiet 2>/dev/null; then
        log_error "Git commit failed"
        return 1
    fi

    local commit_hash
    commit_hash=$(git_short_hash "$project_root")
    log_success "Committed backup: ${commit_hash} - ${message}"
    return 0
}

# ── Create a git tag ────────────────────────────────────────
# Usage: git_tag_backup <project_root> <tag_name>
git_tag_backup() {
    local project_root="$1"
    local tag_name="$2"

    if ! git_available "$project_root"; then
        return 0
    fi

    log_info "Creating git tag: ${tag_name}"

    if ! git -C "$project_root" tag -a "$tag_name" -m "Backup: ${tag_name}" 2>/dev/null; then
        log_error "Git tag creation failed"
        return 1
    fi

    log_success "Created tag: ${tag_name}"
    return 0
}

# ── Push to remote ──────────────────────────────────────────
# Usage: git_push_backup <project_root> [remote] [branch]
git_push_backup() {
    local project_root="$1"
    local remote="${2:-origin}"
    local branch="${3:-}"

    if ! git_available "$project_root"; then
        return 0
    fi

    if [[ -z "$branch" ]]; then
        branch=$(git_current_branch "$project_root")
    fi

    log_info "Pushing to ${remote}/${branch}..."

    if ! git -C "$project_root" push "$remote" "$branch" --quiet 2>/dev/null; then
        log_error "Git push failed"
        return 1
    fi

    log_success "Pushed to ${remote}/${branch}"
    return 0
}

# ── Push tags to remote ─────────────────────────────────────
git_push_tags() {
    local project_root="$1"
    local remote="${2:-origin}"

    if ! git_available "$project_root"; then
        return 0
    fi

    log_info "Pushing tags to ${remote}..."

    if ! git -C "$project_root" push "$remote" --tags --quiet 2>/dev/null; then
        log_error "Git push tags failed"
        return 1
    fi

    log_success "Pushed tags to ${remote}"
    return 0
}

# ── Detect remote provider ──────────────────────────────────
# Returns: github, gitlab, bitbucket, azure, unknown
git_remote_provider() {
    local project_root="${1:-$(pwd)}"
    local remote_url
    remote_url=$(git -C "$project_root" remote get-url origin 2>/dev/null || echo "")

    if [[ -z "$remote_url" ]]; then
        echo "unknown"
        return 0
    fi

    case "$remote_url" in
        *github.com*)         echo "github" ;;
        *gitlab.com*)         echo "gitlab" ;;
        *bitbucket.org*)      echo "bitbucket" ;;
        *dev.azure.com*)      echo "azure" ;;
        *visualstudio.com*)   echo "azure" ;;
        *)                    echo "unknown" ;;
    esac
}

# ── Get remote URL ──────────────────────────────────────────
git_remote_url() {
    local project_root="${1:-$(pwd)}"
    git -C "$project_root" remote get-url origin 2>/dev/null || echo ""
}

# ── Create a full backup commit with optional tag and push ──
# Usage: git_backup_full <project_root> <message> [tag_name]
git_backup_full() {
    local project_root="$1"
    local message="$2"
    local tag_name="${3:-}"
    local auto_commit="${GIT_AUTO_COMMIT:-true}"
    local auto_tag="${GIT_AUTO_TAG:-true}"
    local auto_push="${GIT_AUTO_PUSH:-false}"

    if [[ "$auto_commit" != "true" ]]; then
        log_debug "Git auto-commit disabled"
        return 0
    fi

    # Commit
    if ! git_commit_backup "$project_root" "$message"; then
        return 1
    fi

    # Tag
    if [[ "$auto_tag" == "true" ]] && [[ -n "$tag_name" ]]; then
        git_tag_backup "$project_root" "$tag_name"
    fi

    # Push
    if [[ "$auto_push" == "true" ]]; then
        git_push_backup "$project_root"
        if [[ "$auto_tag" == "true" ]] && [[ -n "$tag_name" ]]; then
            git_push_tags "$project_root"
        fi
    fi

    return 0
}
