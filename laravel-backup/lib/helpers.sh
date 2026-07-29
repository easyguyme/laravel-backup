#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# helpers.sh - General utility functions
# ─────────────────────────────────────────────────────────────
# Reusable helper functions used across the application.
# ─────────────────────────────────────────────────────────────

# ── Check if a command exists ───────────────────────────────
# Usage: command_exists docker
command_exists() {
    command -v "$1" &>/dev/null
}

# ── Confirm a prompt (yes/no) ──────────────────────────────
# Usage: confirm "Proceed?" && echo "yes"
confirm() {
    local prompt="${1:-Continue?}"
    local default="${2:-n}"

    if [[ "${BATCH_MODE:-false}" == "true" ]]; then
        [[ "$default" == "y" ]]
        return $?
    fi

    local yn
    if [[ "$default" == "y" ]]; then
        read -rp "${prompt} [Y/n]: " yn
        yn="${yn:-y}"
    else
        read -rp "${prompt} [y/N]: " yn
        yn="${yn:-n}"
    fi

    [[ "${yn,,}" == "y" ]]
}

# ── Prompt for input with default ───────────────────────────
# Usage: value=$(prompt_input "Enter name" "default")
prompt_input() {
    local prompt="$1"
    local default="${2:-}"
    local result

    if [[ -n "$default" ]]; then
        read -rp "${prompt} [${default}]: " result
        echo "${result:-$default}"
    else
        read -rp "${prompt}: " result
        echo "$result"
    fi
}

# ── Prompt for password (hidden input) ──────────────────────
prompt_password() {
    local prompt="${1:-Enter password}"
    local result

    read -rsp "${prompt}: " result
    echo "" >&2
    echo "$result"
}

# ── Get file size in human-readable format ──────────────────
human_size() {
    local bytes="$1"
    local units=("B" "KB" "MB" "GB" "TB")
    local unit_index=0

    if [[ "$bytes" -eq 0 ]]; then
        echo "0B"
        return 0
    fi

    while [[ "$bytes" -ge 1024 ]] && [[ $unit_index -lt $((${#units[@]} - 1)) ]]; do
        bytes=$((bytes / 1024))
        ((unit_index++)) || true
    done

    echo "${bytes}${units[$unit_index]}"
}

# ── Calculate SHA-256 checksum ──────────────────────────────
checksum_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        if command_exists sha256sum; then
            sha256sum "$file" | cut -d' ' -f1
        elif command_exists shasum; then
            shasum -a 256 "$file" | cut -d' ' -f1
        else
            openssl dgst -sha256 "$file" 2>/dev/null | awk '{print $NF}'
        fi
    else
        echo ""
        return 1
    fi
}

# ── Create a temporary directory ────────────────────────────
# Returns path; caller is responsible for cleanup
make_temp_dir() {
    local prefix="${1:-lbackup}"
    local tmp_dir

    tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/${prefix}.XXXXXX" 2>/dev/null) || {
        log_error "Failed to create temporary directory"
        return 1
    }

    echo "$tmp_dir"
}

# ── Cleanup function for temp directories ───────────────────
# Usage: trap 'cleanup_temp "$TMP_DIR"' EXIT
cleanup_temp() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        rm -rf "$dir" 2>/dev/null || true
    fi
}

# ── Retry a command with backoff ────────────────────────────
retry() {
    local max_attempts="${1:-3}"
    local delay="${2:-1}"
    shift 2

    local attempt=1
    while [[ $attempt -le $max_attempts ]]; do
        if "$@"; then
            return 0
        fi

        if [[ $attempt -lt $max_attempts ]]; then
            log_debug "Retry ${attempt}/${max_attempts} failed, waiting ${delay}s..."
            sleep "$delay"
            ((delay *= 2)) || true
        fi
        ((attempt++)) || true
    done

    return 1
}

# ── Validate a filename (no path traversal) ─────────────────
validate_filename() {
    local filename="$1"

    # Reject empty
    if [[ -z "$filename" ]]; then
        return 1
    fi

    # Reject path traversal
    if [[ "$filename" =~ \.\. ]] || [[ "$filename" =~ ^/ ]]; then
        return 1
    fi

    # Reject special characters
    if [[ "$filename" =~ [^a-zA-Z0-9._/-] ]]; then
        return 1
    fi

    return 0
}

# ── Get project name from directory ─────────────────────────
project_name() {
    local project_root="${1:-$(pwd)}"
    local name
    name=$(basename "$project_root")
    # basename "." returns ".", use directory name instead
    if [[ "$name" == "." ]] || [[ "$name" == "/" ]]; then
        name=$(basename "$(cd "$project_root" && pwd)")
    fi
    echo "$name"
}

# ── Check if running as root ────────────────────────────────
is_root() {
    [[ $EUID -eq 0 ]]
}

# ── Get available disk space in bytes ───────────────────────
disk_space() {
    local path="${1:-.}"
    df -B1 "$path" 2>/dev/null | awk 'NR==2 {print $4}' || echo "0"
}

# ── Check if enough disk space for backup ───────────────────
check_disk_space() {
    local path="${1:-.}"
    local required="${2:-104857600}"  # 100MB default

    local available
    available=$(disk_space "$path")

    if [[ "$available" -lt "$required" ]]; then
        log_warn "Low disk space: $(human_size "$available") available, $(human_size "$required") recommended"
        return 1
    fi
    return 0
}

# ── Escape string for use in sed ────────────────────────────
sed_escape() {
    printf '%s' "$1" | sed 's/[.[\/*^$]/\\&/g'
}

# ── Escape string for use in grep ───────────────────────────
grep_escape() {
    printf '%s' "$1" | sed 's/[.[\/*^$]/\\&/g'
}

# ── Get elapsed time between two timestamps ─────────────────
elapsed_time() {
    local start="$1"
    local end="$2"
    local diff=$((end - start))

    if [[ $diff -lt 60 ]]; then
        echo "${diff}s"
    elif [[ $diff -lt 3600 ]]; then
        printf '%dm %ds' $((diff / 60)) $((diff % 60))
    else
        printf '%dh %dm %ds' $((diff / 3600)) $((diff / 3600 / 60)) $((diff % 60))
    fi
}

# ── Check if Git LFS is available ───────────────────────────
git_lfs_available() {
    command_exists git && git lfs version &>/dev/null
}

# ── Initialize Git LFS and track backup file patterns ────────
# Usage: git_lfs_setup <project_root>
git_lfs_setup() {
    local project_root="${1:-$(pwd)}"

    if ! git_lfs_available; then
        log_warn "Git LFS not installed - large files may fail to push"
        log_info "Install: brew install git-lfs && git lfs install"
        return 1
    fi

    log_info "Configuring Git LFS for backup files..."

    git -C "$project_root" lfs install 2>/dev/null || true

    git -C "$project_root" lfs track "*.sql.gz" 2>/dev/null || true
    git -C "$project_root" lfs track "*.sql.gz.enc" 2>/dev/null || true
    git -C "$project_root" lfs track "*.uploads.tar.gz" 2>/dev/null || true
    git -C "$project_root" lfs track "*.uploads.tar.gz.enc" 2>/dev/null || true
    git -C "$project_root" lfs track "*.tar.gz" 2>/dev/null || true
    git -C "$project_root" lfs track "*.tar.gz.enc" 2>/dev/null || true
    git -C "$project_root" lfs track "*.zip" 2>/dev/null || true
    git -C "$project_root" lfs track "*.zip.enc" 2>/dev/null || true

    git -C "$project_root" add -f .gitattributes 2>/dev/null || true

    log_success "Git LFS configured"
    return 0
}
