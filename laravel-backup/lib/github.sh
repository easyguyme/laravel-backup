#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# github.sh - GitHub CLI integration
# ─────────────────────────────────────────────────────────────
# Provides GitHub operations using the `gh` CLI when available.
# Supports repository creation, remote management, and
# release creation.
# ─────────────────────────────────────────────────────────────

# ── Install GitHub CLI if not present ───────────────────────
github_install() {
    if command_exists gh; then
        return 0
    fi

    log_info "GitHub CLI (gh) not found, installing..."

    if is_root; then
        if command_exists apt-get; then
            curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
                | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
            chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
                | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
            apt-get update -qq && apt-get install -y -qq gh
        elif command_exists yum; then
            curl -fsSL https://cli.github.com/packages/rpm/gh-cli.repo \
                -o /etc/yum.repos.d/gh-cli.repo
            yum install -y gh
        elif command_exists dnf; then
            curl -fsSL https://cli.github.com/packages/rpm/gh-cli.repo \
                -o /etc/yum.repos.d/gh-cli.repo
            dnf install -y gh
        elif command_exists apk; then
            apk add --no-cache gh
        else
            log_error "Cannot install gh: unsupported package manager"
            log_info "Install manually: https://cli.github.com/"
            return 1
        fi
    else
        if command_exists brew; then
            brew install gh
        elif command_exists apt-get; then
            curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
                | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
            sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
                | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
            sudo apt-get update -qq && sudo apt-get install -y -qq gh
        elif command_exists yum; then
            curl -fsSL https://cli.github.com/packages/rpm/gh-cli.repo \
                | sudo tee /etc/yum.repos.d/gh-cli.repo > /dev/null
            sudo yum install -y gh
        elif command_exists dnf; then
            curl -fsSL https://cli.github.com/packages/rpm/gh-cli.repo \
                | sudo tee /etc/yum.repos.d/gh-cli.repo > /dev/null
            sudo dnf install -y gh
        elif command_exists apk; then
            sudo apk add --no-cache gh
        elif command_exists pacman; then
            sudo pacman -S --noconfirm github-cli
        elif command_exists zypper; then
            sudo zypper install -y gh
        else
            log_error "Cannot install gh: no supported package manager found"
            log_info "Install manually: https://cli.github.com/"
            return 1
        fi
    fi

    if ! command_exists gh; then
        log_error "GitHub CLI installation failed"
        return 1
    fi

    log_success "GitHub CLI installed: $(gh --version | head -1)"
    return 0
}

# ── Authenticate GitHub CLI with token ──────────────────────
github_authenticate() {
    # Already authenticated
    if gh auth status &>/dev/null 2>&1; then
        log_info "GitHub CLI already authenticated"
        return 0
    fi

    echo ""
    echo "GitHub CLI needs authentication to create repositories."
    echo ""
    echo "To create a personal access token:"
    echo "  1. Go to: https://github.com/settings/tokens"
    echo "  2. Click 'Generate new token (classic)'"
    echo "  3. Select scopes: repo, read:org"
    echo "  4. Copy the token"
    echo ""

    local token
    read -rsp "Paste your GitHub token: " token
    echo ""

    if [[ -z "$token" ]]; then
        log_warn "No token provided - skipping GitHub authentication"
        return 1
    fi

    # Authenticate with token
    echo "$token" | gh auth login --with-token 2>/dev/null || {
        log_error "GitHub authentication failed"
        return 1
    }

    log_success "GitHub CLI authenticated"
    return 0
}

# ── Ensure gh is installed and authenticated ─────────────────
github_setup() {
    github_install || return 1
    github_authenticate || return 1
    return 0
}

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
    repo_url=$(gh "${create_args[@]}" 2>&1) || {
        # Check if repo already exists
        if echo "$repo_url" | grep -qi "already exists"; then
            local username
            username=$(gh api user --jq '.login' 2>/dev/null || echo "")
            if [[ -n "$username" ]]; then
                repo_url="https://github.com/${username}/${name}"
                log_info "Repository already exists: ${repo_url}"
                echo "$repo_url"
                return 0
            fi
        fi
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

    # Resolve to absolute path
    project_root=$(cd "$project_root" 2>/dev/null && pwd) || project_root="$(pwd)"

    if ! git_available "$project_root"; then
        log_error "Not a git repository: $project_root"
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
