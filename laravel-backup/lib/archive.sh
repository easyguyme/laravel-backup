#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# archive.sh - Archive creation and extraction
# ─────────────────────────────────────────────────────────────
# Creates compressed tar.gz archives and zip files for backup
# of project files and upload directories.
# ─────────────────────────────────────────────────────────────

# ── Detect upload directories automatically ─────────────────
# Usage: detect_upload_dirs <project_root>
# Returns one directory per line
detect_upload_dirs() {
    local project_root="$1"

    local candidates=(
        "storage/app"
        "storage/app/public"
        "public/storage"
        "public/uploads"
        "uploads"
        "images"
        "media"
        "assets/uploads"
    )

    for dir in "${candidates[@]}"; do
        if [[ -d "${project_root}/${dir}" ]]; then
            # Skip if empty
            if [[ -n "$(ls -A "${project_root}/${dir}" 2>/dev/null)" ]]; then
                echo "$dir"
            fi
        fi
    done
}

# ── Build exclusion list for tar ────────────────────────────
_build_tar_excludes() {
    local excludes="${EXCLUDE_DIRS:-}"

    local -a exclude_args=()

    for pattern in $excludes; do
        exclude_args+=("--exclude=${pattern}")
    done

    echo "${exclude_args[@]}"
}

# ── Create a tar.gz archive ────────────────────────────────
# Usage: create_tar <output_file> <project_root> <dirs...>
create_tar() {
    local output_file="$1"
    local project_root="$2"
    shift 2
    local dirs=("$@")

    if [[ ${#dirs[@]} -eq 0 ]]; then
        log_warn "No directories to archive"
        return 1
    fi

    log_info "Creating archive: $(basename "$output_file")"

    # Build exclude arguments
    local -a exclude_args
    read -ra exclude_args <<< "$(_build_tar_excludes)"

    # Create archive
    local tar_cmd=(tar -czf "$output_file" "${exclude_args[@]}")

    for dir in "${dirs[@]}"; do
        if [[ -d "${project_root}/${dir}" ]]; then
            tar_cmd+=("-C" "$project_root" "$dir")
        fi
    done

    if ! "${tar_cmd[@]}" 2>/dev/null; then
        log_error "Failed to create archive"
        rm -f "$output_file" 2>/dev/null || true
        return 1
    fi

    # Verify archive
    if [[ ! -s "$output_file" ]]; then
        log_error "Archive is empty"
        rm -f "$output_file" 2>/dev/null || true
        return 1
    fi

    local size
    size=$(stat -f%z "$output_file" 2>/dev/null || stat -c%s "$output_file" 2>/dev/null || echo 0)
    log_success "Archive created: $(human_size "$size")"
    return 0
}

# ── Create a zip archive ────────────────────────────────────
# Usage: create_zip <output_file> <project_root> <dirs...>
create_zip() {
    local output_file="$1"
    local project_root="$2"
    shift 2
    local dirs=("$@")

    if [[ ${#dirs[@]} -eq 0 ]]; then
        log_warn "No directories to archive"
        return 1
    fi

    if ! command_exists zip; then
        log_warn "zip not found, falling back to tar"
        create_tar "${output_file%.zip}.tar.gz" "$project_root" "${dirs[@]}"
        return $?
    fi

    log_info "Creating zip archive: $(basename "$output_file")"

    local -a zip_cmd=(zip -r -q "$output_file")

    # Add exclusions
    local excludes="${EXCLUDE_DIRS:-}"
    for pattern in $excludes; do
        zip_cmd+=("-x" "*/${pattern}/*" "*/${pattern}")
    done

    for dir in "${dirs[@]}"; do
        if [[ -d "${project_root}/${dir}" ]]; then
            zip_cmd+=("$dir")
        fi
    done

    # Execute from project root
    if ! (cd "$project_root" && "${zip_cmd[@]}") 2>/dev/null; then
        log_error "Failed to create zip archive"
        rm -f "$output_file" 2>/dev/null || true
        return 1
    fi

    log_success "Zip archive created: $(human_size "$(stat -f%z "$output_file" 2>/dev/null || stat -c%s "$output_file" 2>/dev/null || echo 0)")"
    return 0
}

# ── Extract a tar.gz archive ────────────────────────────────
# Usage: extract_tar <archive_file> <target_dir>
extract_tar() {
    local archive_file="$1"
    local target_dir="$2"

    if [[ ! -f "$archive_file" ]]; then
        log_error "Archive not found: ${archive_file}"
        return 1
    fi

    log_info "Extracting archive..."

    mkdir -p "$target_dir"

    if ! tar -xzf "$archive_file" -C "$target_dir" 2>/dev/null; then
        log_error "Failed to extract archive"
        return 1
    fi

    log_success "Archive extracted to: ${target_dir}"
    return 0
}

# ── List contents of a tar.gz archive ───────────────────────
# Usage: list_tar <archive_file>
list_tar() {
    local archive_file="$1"

    if [[ ! -f "$archive_file" ]]; then
        log_error "Archive not found: ${archive_file}"
        return 1
    fi

    tar -tzf "$archive_file" 2>/dev/null
}

# ── Get archive size ────────────────────────────────────────
archive_size() {
    local file="$1"

    if [[ -f "$file" ]]; then
        local size
        size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 0)
        human_size "$size"
    else
        echo "N/A"
    fi
}
