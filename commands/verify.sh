#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# commands/verify.sh - Verify backup integrity
# ─────────────────────────────────────────────────────────────
set -Eeuo pipefail

LBACKUP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for _lib in colours logging env helpers validator config encrypt archive git; do
    [[ -f "${LBACKUP_ROOT}/lib/${_lib}.sh" ]] && source "${LBACKUP_ROOT}/lib/${_lib}.sh"
done
unset _lib

usage() {
    printf '%b' "${BOLD}laravel-backup verify${NC} - Verify backup integrity

${BOLD}USAGE${NC}
    laravel-backup verify [options] [backup-file]

${BOLD}OPTIONS${NC}
    -h, --help      Show this help message
    --all           Verify all backups
    --verbose       Show detailed output

"
    exit 0
}

parse_args() {
    VERIFY_FILE=""
    VERIFY_ALL=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)      usage ;;
            --all)          VERIFY_ALL=true; shift ;;
            --verbose)      set_log_level "DEBUG"; shift ;;
            -*)             log_error "Unknown option: $1"; usage ;;
            *)              VERIFY_FILE="$1"; shift ;;
        esac
    done
}

# ── Verify a single backup ─────────────────────────────────
verify_backup() {
    local file="$1"
    local errors=0
    local warnings=0

    log_header "Verifying: $(basename "$file")"

    # Check file exists and is readable
    if [[ ! -f "$file" ]]; then
        log_error "File not found: $file"
        return 1
    fi

    if [[ ! -r "$file" ]]; then
        log_error "File not readable: $file"
        return 1
    fi

    local size
    size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 0)
    log_kv "Size" "$(human_size "$size")"

    # Check if encrypted
    if [[ "$file" == *.enc ]]; then
        log_info "Type: Encrypted backup"
        if encryption_enabled; then
            if encrypt_verify "$file"; then
                log_success "Encryption: File is decryptable"
            else
                log_error "Encryption: Cannot decrypt file"
                ((errors++)) || true
            fi
        else
            log_warn "Encryption enabled but not configured"
            ((warnings++)) || true
        fi
    else
        log_info "Type: Unencrypted backup"
    fi

    # Verify checksum
    local checksum
    checksum=$(checksum_file "$file")
    log_kv "SHA-256" "$checksum"

    # Try to extract
    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap 'rm -rf "$tmp_dir"' RETURN

    if [[ "$file" == *.enc ]]; then
        log_debug "Skipping extraction of encrypted file"
    else
        log_info "Extracting..."
        if tar -xzf "$file" -C "$tmp_dir" 2>/dev/null; then
            log_success "Extraction: OK"

            # Check for manifest
            local manifest
            manifest=$(find "$tmp_dir" -name "*.manifest.json" | head -1 || true)
            if [[ -n "$manifest" ]]; then
                log_success "Manifest: Found"
                if command_exists jq; then
                    local manifest_errors
                    manifest_errors=$(jq -r 'select(.checksum == null or .checksum == "") | "missing checksum"' "$manifest" 2>/dev/null || true)
                    if [[ -n "$manifest_errors" ]]; then
                        log_warn "Manifest: ${manifest_errors}"
                        ((warnings++)) || true
                    fi
                fi
            else
                log_warn "Manifest: Not found"
                ((warnings++)) || true
            fi

            # Check for database dump
            local db_dump
            db_dump=$(find "$tmp_dir" -name "*.sql.gz" -o -name "*.sql" | head -1 || true)
            if [[ -n "$db_dump" ]]; then
                log_success "Database dump: Found"
            else
                log_info "Database dump: Not in this archive"
            fi
        else
            log_error "Extraction: Failed"
            ((errors++)) || true
        fi
    fi

    # Git integrity
    if git_available "."; then
        log_info "Checking git integrity..."
        if git fsck --no-dangling &>/dev/null; then
            log_success "Git integrity: OK"
        else
            log_warn "Git integrity: Issues detected"
            ((warnings++)) || true
        fi
    fi

    # Summary
    echo ""
    if [[ $errors -eq 0 ]]; then
        log_success "Verification passed"
    else
        log_error "Verification failed with ${errors} error(s) and ${warnings} warning(s)"
    fi

    return $errors
}

# ── Verify all backups ─────────────────────────────────────
verify_all() {
    local backup_dir="${BACKUP_DIR:-backups}"
    local total_errors=0

    if [[ ! -d "$backup_dir" ]]; then
        log_error "Backup directory not found: ${backup_dir}"
        return 1
    fi

    local count=0
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        ((count++)) || true
        verify_backup "$file" || ((total_errors++)) || true
        echo ""
    done < <(ls -1t "${backup_dir}"/*.tar.gz.enc "${backup_dir}"/*.tar.gz 2>/dev/null || true)

    if [[ $count -eq 0 ]]; then
        log_warn "No backups found to verify"
    fi

    return $total_errors
}

main() {
    parse_args "$@"

    config_load "" "."

    if [[ "$VERIFY_ALL" == "true" ]]; then
        verify_all
    elif [[ -n "$VERIFY_FILE" ]]; then
        verify_backup "$VERIFY_FILE"
    else
        # Find latest backup
        local backup_dir="${BACKUP_DIR:-backups}"
        local latest
        latest=$(ls -1t "${backup_dir}"/*.tar.gz.enc "${backup_dir}"/*.tar.gz 2>/dev/null | head -1 || true)
        if [[ -n "$latest" ]]; then
            verify_backup "$latest"
        else
            log_error "No backups found"
            exit 1
        fi
    fi
}

main "$@"
