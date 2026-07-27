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

# ── Initialize git repo if not present ──────────────────────
# Creates repo, creates private GitHub repo (if gh available), adds remote
git_init_if_needed() {
    local project_root="${1:-$(pwd)}"

    # Resolve to absolute path
    project_root=$(cd "$project_root" 2>/dev/null && pwd) || project_root="$(pwd)"

    # Git must be installed
    if ! command_exists git; then
        log_error "Git is not installed"
        return 1
    fi

    # Already a git repo
    if git -C "$project_root" rev-parse --is-inside-work-tree &>/dev/null; then
        return 0
    fi

    log_info "Initializing git repository..."
    git -C "$project_root" init 2>/dev/null || {
        log_error "Failed to initialize git repository"
        return 1
    }
    log_success "Initialized git repository"

    # Ensure git user is configured
    if [[ -z "$(git -C "$project_root" config user.name 2>/dev/null)" ]]; then
        git -C "$project_root" config user.name "laravel-backup" 2>/dev/null || true
    fi
    if [[ -z "$(git -C "$project_root" config user.email 2>/dev/null)" ]]; then
        git -C "$project_root" config user.email "backup@laravel-backup" 2>/dev/null || true
    fi

    # Fix dubious ownership error
    git config --global --add safe.directory "$project_root" 2>/dev/null || true

    # Try to create a private GitHub repo and add remote
    if github_available; then
        local repo_name
        repo_name=$(basename "$project_root")

        log_info "Creating private GitHub repository: ${repo_name}"
        local repo_url
        repo_url=$(github_create_repo "$repo_name" "private") || true

        if [[ -n "$repo_url" ]]; then
            github_add_remote "$project_root" "$repo_url" || true
        fi
    else
        log_warn "GitHub CLI not available - skipping remote setup"
        log_info "Add a remote manually: git remote add origin <url>"
    fi

    return 0
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

    # Resolve to absolute path
    project_root=$(cd "$project_root" 2>/dev/null && pwd) || project_root="$(pwd)"

    # Initialize repo if needed
    if ! git_available "$project_root"; then
        git_init_if_needed "$project_root" || return 1
    fi

    # Ensure git user is configured
    if [[ -z "$(git -C "$project_root" config user.name 2>/dev/null)" ]]; then
        git -C "$project_root" config user.name "laravel-backup" 2>/dev/null || true
    fi
    if [[ -z "$(git -C "$project_root" config user.email 2>/dev/null)" ]]; then
        git -C "$project_root" config user.email "backup@laravel-backup" 2>/dev/null || true
    fi

    # Fix dubious ownership error
    git config --global --add safe.directory "$project_root" 2>/dev/null || true

    log_info "Committing backup to git..."

    # Check if this is a fresh repo (no commits yet) OR no remote (new GitHub repo)
    local is_fresh_repo=false
    if ! git -C "$project_root" rev-parse HEAD &>/dev/null; then
        is_fresh_repo=true
    fi
    
    # Also treat as fresh if no remote is configured (new GitHub repo)
    if [[ "$is_fresh_repo" == "false" ]]; then
        local remote_url
        remote_url=$(git -C "$project_root" remote get-url origin 2>/dev/null || echo "")
        if [[ -z "$remote_url" ]]; then
            is_fresh_repo=true
            log_info "No remote configured - treating as fresh repository"
        fi
    fi

    if [[ "$is_fresh_repo" == "true" ]]; then
        # Fresh repo - add everything (app + backups)
        log_info "Initial commit - adding entire project..."
        
        # Create .gitignore if it doesn't exist
        if [[ ! -f "${project_root}/.gitignore" ]]; then
            cat > "${project_root}/.gitignore" << 'GITIGNORE'
# Laravel
/vendor/
/node_modules/
/storage/logs/*.log
/storage/framework/cache/*
/storage/framework/sessions/*
/storage/framework/views/*
/bootstrap/cache/

# Environment
.env
.env.backup
.env.production

# IDE
.idea/
.vscode/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Backup temp files
/tmp/
*.tmp

# Large backup archives (store these offsite, not in git)
backups/*.sql.gz
backups/*.sql.gz.enc
backups/*.uploads.tar.gz
backups/*.uploads.tar.gz.enc
GITIGNORE
            log_info "Created .gitignore"
        fi
        
        # Stage everything (respects .gitignore)
        git -C "$project_root" add . 2>&1 || {
            log_warn "Failed to stage project files"
        }
        
        # Force-add only manifest and logs (not large archives)
        git -C "$project_root" add -f "${backup_dir}/*.manifest.json" 2>&1 || true
        git -C "$project_root" add -f "${backup_dir}/*.log" 2>&1 || true
    else
        # Existing repo - just add backup manifest and logs (not large archives)
        log_info "Adding backup files..."
        git -C "$project_root" add -f "${backup_dir}/*.manifest.json" 2>&1 || true
        git -C "$project_root" add -f "${backup_dir}/*.log" 2>&1 || true
    fi

    # Check if there are changes to commit
    if git -C "$project_root" diff --cached --quiet 2>/dev/null; then
        log_debug "No backup changes to commit"
        return 0
    fi

    # Create commit
    local commit_output
    commit_output=$(git -C "$project_root" commit -m "$message" 2>&1) || {
        log_error "Git commit failed: $commit_output"
        return 1
    }

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

    # Resolve to absolute path
    project_root=$(cd "$project_root" 2>/dev/null && pwd) || project_root="$(pwd)"

    if ! git_available "$project_root"; then
        git_init_if_needed "$project_root" || return 1
    fi

    # Fix dubious ownership error
    git config --global --add safe.directory "$project_root" 2>/dev/null || true

    # Check if there are any commits (tag requires at least one)
    if ! git -C "$project_root" rev-parse HEAD &>/dev/null; then
        log_warn "No commits yet, skipping tag creation"
        return 0
    fi

    log_info "Creating git tag: ${tag_name}"

    local tag_output
    tag_output=$(git -C "$project_root" tag -a "$tag_name" -m "Backup: ${tag_name}" 2>&1) || {
        log_error "Git tag creation failed: $tag_output"
        return 1
    }

    log_success "Created tag: ${tag_name}"
    return 0
}

# ── Ensure remote is configured and repo exists ─────────────
# Usage: git_ensure_remote <project_root> [remote]
git_ensure_remote() {
    local project_root="$1"
    local remote="${2:-origin}"
    local project_name
    project_name=$(basename "$project_root")

    # Check if remote exists
    local remote_url
    remote_url=$(git -C "$project_root" remote get-url "$remote" 2>/dev/null || echo "")

    # If remote exists, verify it works (repo exists on GitHub)
    if [[ -n "$remote_url" ]]; then
        # Fix URL - ensure it ends with .git
        if [[ "$remote_url" != *.git ]]; then
            remote_url="${remote_url}.git"
            git -C "$project_root" remote set-url "$remote" "$remote_url" 2>/dev/null || true
        fi
        
        # If GitHub is available, verify repo exists
        if github_available; then
            # Extract repo path from URL
            local repo_path
            repo_path=$(echo "$remote_url" | sed -E 's|https?://github.com/||; s|\.git$||; s|/$||')
            
            if [[ -n "$repo_path" ]]; then
                # Check if repo exists
                if ! gh repo view "$repo_path" &>/dev/null; then
                    log_warn "Repository not found on GitHub: ${repo_path}"
                    
                    # Extract just the repo name
                    local repo_name
                    repo_name=$(basename "$repo_path")
                    local owner
                    owner=$(dirname "$repo_path")
                    
                    if confirm "Create private GitHub repository '${repo_name}'?" "y"; then
                        local new_url
                        new_url=$(github_create_repo "$repo_name" "private") || true
                        
                        if [[ -n "$new_url" ]]; then
                            [[ "$new_url" != *.git ]] && new_url="${new_url}.git"
                            git -C "$project_root" remote set-url "$remote" "$new_url" 2>/dev/null || true
                            log_success "Created and configured remote: ${new_url}"
                            return 0
                        fi
                    else
                        log_warn "Skipping push - repository does not exist"
                        return 1
                    fi
                fi
            fi
        fi
        return 0
    fi

    # No remote configured - try to set up
    log_warn "Remote '${remote}' not configured"

    # Try GitHub first
    if github_available; then
        log_info "GitHub authenticated, checking for repository..."
        
        # Check if repo exists
        local existing_url
        existing_url=$(gh repo view "${project_name}" --json url --jq '.url' 2>/dev/null || echo "")
        
        if [[ -n "$existing_url" ]]; then
            log_info "Repository exists: ${existing_url}"
            git -C "$project_root" remote add "$remote" "${existing_url}.git" 2>/dev/null || true
        else
            # Ask to create repo
            if confirm "Create private GitHub repository '${project_name}'?" "y"; then
                local repo_url
                repo_url=$(github_create_repo "$project_name" "private") || true
                
                if [[ -n "$repo_url" ]]; then
                    # Ensure .git suffix
                    [[ "$repo_url" != *.git ]] && repo_url="${repo_url}.git"
                    git -C "$project_root" remote add "$remote" "$repo_url" 2>/dev/null || true
                fi
            fi
        fi
    fi

    # Still no remote - prompt user
    remote_url=$(git -C "$project_root" remote get-url "$remote" 2>/dev/null || echo "")
    if [[ -z "$remote_url" ]]; then
        echo ""
        echo "Enter your remote repository URL:"
        echo "  Examples:"
        echo "    https://github.com/username/repo.git"
        echo "    git@github.com:username/repo.git"
        echo ""
        read -rp "Remote URL: " remote_url
        
        if [[ -n "$remote_url" ]]; then
            [[ "$remote_url" != *.git ]] && remote_url="${remote_url}.git"
            git -C "$project_root" remote add "$remote" "$remote_url" 2>/dev/null || {
                log_error "Failed to add remote"
                return 1
            }
            log_success "Added remote: ${remote_url}"
        else
            log_warn "No URL provided"
            return 1
        fi
    fi

    return 0
}

# ── Push to remote ──────────────────────────────────────────
# Usage: git_push_backup <project_root> [remote] [branch]
git_push_backup() {
    local project_root="$1"
    local remote="${2:-origin}"
    local branch="${3:-}"

    # Resolve to absolute path
    project_root=$(cd "$project_root" 2>/dev/null && pwd) || project_root="$(pwd)"

    if ! git_available "$project_root"; then
        git_init_if_needed "$project_root" || return 1
    fi

    # Fix dubious ownership error
    git config --global --add safe.directory "$project_root" 2>/dev/null || true

    # Ensure remote is configured
    if ! git_ensure_remote "$project_root" "$remote"; then
        return 1
    fi

    if [[ -z "$branch" ]]; then
        branch=$(git_current_branch "$project_root")
    fi

    log_info "Pushing to ${remote}/${branch}..."

    local push_output
    push_output=$(git -C "$project_root" push -u "$remote" "$branch" 2>&1) || {
        log_error "Git push failed: $push_output"
        return 1
    }

    log_success "Pushed to ${remote}/${branch}"
    return 0
}

# ── Push tags to remote ─────────────────────────────────────
git_push_tags() {
    local project_root="$1"
    local remote="${2:-origin}"

    # Resolve to absolute path
    project_root=$(cd "$project_root" 2>/dev/null && pwd) || project_root="$(pwd)"

    if ! git_available "$project_root"; then
        git_init_if_needed "$project_root" || return 1
    fi

    # Fix dubious ownership error
    git config --global --add safe.directory "$project_root" 2>/dev/null || true

    # Check if remote exists
    if ! git -C "$project_root" remote get-url "$remote" &>/dev/null; then
        return 0
    fi

    log_info "Pushing tags to ${remote}..."

    local tags_output
    tags_output=$(git -C "$project_root" push "$remote" --tags 2>&1) || {
        log_error "Git push tags failed: $tags_output"
        return 1
    }

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
    local auto_push="${GIT_AUTO_PUSH:-true}"

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
    else
        # Ask if user wants to push
        if confirm "Push backup to remote repository?" "y"; then
            git_push_backup "$project_root"
            if [[ "$auto_tag" == "true" ]] && [[ -n "$tag_name" ]]; then
                git_push_tags "$project_root"
            fi
        fi
    fi

    return 0
}
