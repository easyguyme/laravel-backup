#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# github.sh - GitHub CLI integration
# ─────────────────────────────────────────────────────────────
# Provides GitHub operations using the `gh` CLI when available.
# Supports repository creation, remote management, and
# release creation.
# ─────────────────────────────────────────────────────────────

# ── Check if gh CLI is available and authenticated ──────────
github_available() {
    if ! command_exists gh; then
        return 1
    fi

    if ! gh auth status &>/dev/null; then
        return 1
    fi

    return 0
}

# ── Create a GitHub repository ──────────────────────────────
# Usage: github_create_repo <name> [private|public]
github_create_repo() {
    local name="$1"
    local visibility="${2:-private}"

    if ! github_available; then
        log_warn "GitHub CLI not available or not authenticated"
        return 1
    fi

    log_info "Creating GitHub repository: ${name}"

    local -a create_args=(
        repo create "$name"
        --"$visibility"
        --clone=false
    )

    local repo_url
    repo_url=$(gh "${create_args[@]}" 2>/dev/null) || {
        log_error "Failed to create GitHub repository"
        return 1
    }

    log_success "Created repository: ${repo_url}"
    echo "$repo_url"
    return 0
}

# ── Add remote origin ───────────────────────────────────────
# Usage: github_add_remote <project_root> <repo_url>
github_add_remote() {
    local project_root="$1"
    local repo_url="$2"

    if ! git_available "$project_root"; then
        log_error "Not a git repository"
        return 1
    fi

    # Check if remote already exists
    local existing
    existing=$(git -C "$project_root" remote get-url origin 2>/dev/null || echo "")

    if [[ -n "$existing" ]]; then
        log_debug "Remote origin already exists: ${existing}"
        return 0
    fi

    log_info "Adding remote: ${repo_url}"
    git -C "$project_root" remote add origin "$repo_url" 2>/dev/null || {
        log_error "Failed to add remote"
        return 1
    }

    log_success "Added remote origin"
    return 0
}

# ── Create a GitHub release ─────────────────────────────────
# Usage: github_create_release <tag> <title> <body> [files...]
github_create_release() {
    local tag="$1"
    local title="$2"
    local body="$3"
    shift 3
    local files=("$@")

    if ! github_available; then
        log_warn "GitHub CLI not available"
        return 1
    fi

    log_info "Creating GitHub release: ${tag}"

    local -a release_args=(
        release create "$tag"
        --title "$title"
        --notes "$body"
    )

    # Add attachment files
    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            release_args+=("$file")
        fi
    done

    if ! gh "${release_args[@]}" 2>/dev/null; then
        log_error "Failed to create GitHub release"
        return 1
    fi

    log_success "Created release: ${tag}"
    return 0
}

# ── Upload release assets ───────────────────────────────────
# Usage: github_upload_release <tag> <files...>
github_upload_release() {
    local tag="$1"
    shift
    local files=("$@")

    if ! github_available; then
        return 1
    fi

    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            log_info "Uploading: $(basename "$file")"
            gh release upload "$tag" "$file" --clobber 2>/dev/null || {
                log_warn "Failed to upload: $(basename "$file")"
            }
        fi
    done

    return 0
}

# ── Get latest release tag ──────────────────────────────────
github_latest_release() {
    if ! github_available; then
        echo ""
        return 1
    fi

    gh release list --limit 1 --json tagName --jq '.[0].tagName' 2>/dev/null || echo ""
}

# ── Check if a tag exists as a release ──────────────────────
github_release_exists() {
    local tag="$1"

    if ! github_available; then
        return 1
    fi

    gh release view "$tag" &>/dev/null
}
