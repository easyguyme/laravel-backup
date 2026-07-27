#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# encrypt.sh - Encryption and decryption
# ─────────────────────────────────────────────────────────────
# Provides AES-256-CBC encryption/decryption via OpenSSL.
# Supports password from environment, file, or interactive
# prompt.
# ─────────────────────────────────────────────────────────────

# ── Get encryption password from configured source ──────────
encrypt_get_password() {
    local source="${ENCRYPTION_PASSWORD_SOURCE:-env}"

    case "$source" in
        env)
            if [[ -n "${BACKUP_PASSWORD:-}" ]]; then
                echo "$BACKUP_PASSWORD"
                return 0
            fi
            log_error "BACKUP_PASSWORD environment variable not set"
            return 1
            ;;
        file)
            local passfile="${ENCRYPTION_PASSWORD_FILE:-}"
            if [[ -z "$passfile" ]]; then
                log_error "ENCRYPTION_PASSWORD_FILE not configured"
                return 1
            fi
            if [[ ! -r "$passfile" ]]; then
                log_error "Password file not readable: ${passfile}"
                return 1
            fi
            cat "$passfile" 2>/dev/null | tr -d '\n'
            return 0
            ;;
        prompt)
            prompt_password "Enter encryption password"
            return 0
            ;;
        *)
            log_error "Unknown password source: ${source}"
            return 1
            ;;
    esac
}

# ── Encrypt a file ──────────────────────────────────────────
# Usage: encrypt_file <input_file> <output_file>
# Output file should have .enc extension
encrypt_file() {
    local input_file="$1"
    local output_file="$2"

    if [[ ! -f "$input_file" ]]; then
        log_error "Input file not found: ${input_file}"
        return 1
    fi

    local password
    password=$(encrypt_get_password) || return 1

    if [[ -z "$password" ]]; then
        log_error "Encryption password is empty"
        return 1
    fi

    log_info "Encrypting: $(basename "$input_file")"

    if ! openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000 \
        -in "$input_file" \
        -out "$output_file" \
        -pass "pass:${password}" 2>/dev/null; then
        log_error "Encryption failed"
        rm -f "$output_file" 2>/dev/null || true
        return 1
    fi

    # Verify encrypted file was created
    if [[ ! -s "$output_file" ]]; then
        log_error "Encrypted file is empty"
        return 1
    fi

    # Remove original unencrypted file
    rm -f "$input_file" 2>/dev/null || true

    local enc_size
    enc_size=$(stat -f%z "$output_file" 2>/dev/null || stat -c%s "$output_file" 2>/dev/null || echo 0)
    log_success "Encrypted: $(basename "$output_file") ($(human_size "$enc_size"))"
    return 0
}

# ── Decrypt a file ──────────────────────────────────────────
# Usage: decrypt_file <input_file> <output_file>
decrypt_file() {
    local input_file="$1"
    local output_file="$2"

    if [[ ! -f "$input_file" ]]; then
        log_error "Encrypted file not found: ${input_file}"
        return 1
    fi

    local password
    password=$(encrypt_get_password) || return 1

    if [[ -z "$password" ]]; then
        log_error "Decryption password is empty"
        return 1
    fi

    log_info "Decrypting: $(basename "$input_file")"

    if ! openssl enc -aes-256-cbc -d -salt -pbkdf2 -iter 100000 \
        -in "$input_file" \
        -out "$output_file" \
        -pass "pass:${password}" 2>/dev/null; then
        log_error "Decryption failed (wrong password?)"
        rm -f "$output_file" 2>/dev/null || true
        return 1
    fi

    if [[ ! -s "$output_file" ]]; then
        log_error "Decrypted file is empty"
        return 1
    fi

    log_success "Decrypted: $(basename "$output_file")"
    return 0
}

# ── Verify an encrypted file can be decrypted ───────────────
# Usage: encrypt_verify <encrypted_file>
encrypt_verify() {
    local encrypted_file="$1"
    local tmp_output
    tmp_output=$(mktemp)

    local password
    password=$(encrypt_get_password) || return 1

    if openssl enc -aes-256-cbc -d -salt -pbkdf2 -iter 100000 \
        -in "$encrypted_file" \
        -out "$tmp_output" \
        -pass "pass:${password}" 2>/dev/null; then
        local size
        size=$(stat -f%z "$tmp_output" 2>/dev/null || stat -c%s "$tmp_output" 2>/dev/null || echo 0)
        rm -f "$tmp_output" 2>/dev/null || true
        [[ "$size" -gt 0 ]]
        return $?
    fi

    rm -f "$tmp_output" 2>/dev/null || true
    return 1
}

# ── Check if encryption is enabled ──────────────────────────
encryption_enabled() {
    [[ "${ENCRYPTION_ENABLED:-true}" == "true" ]]
}
