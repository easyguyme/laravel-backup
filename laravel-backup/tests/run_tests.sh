#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# tests/run_tests.sh - Run all laravel-backup tests
# ─────────────────────────────────────────────────────────────
set -Eeuo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TEST_DIR")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

PASSED=0
FAILED=0
SKIPPED=0

# ── Test helpers ────────────────────────────────────────────
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"

    if [[ "$expected" == "$actual" ]]; then
        ((PASSED++)) || true
        printf '  %bPASS%b %s\n' "$GREEN" "$NC" "$message"
    else
        ((FAILED++)) || true
        printf '  %bFAIL%b %s (expected: %s, got: %s)\n' \
            "$RED" "$NC" "$message" "$expected" "$actual"
    fi
}

assert_true() {
    local condition="$1"
    local message="${2:-}"

    if eval "$condition"; then
        ((PASSED++)) || true
        printf '  %bPASS%b %s\n' "$GREEN" "$NC" "$message"
    else
        ((FAILED++)) || true
        printf '  %bFAIL%b %s\n' "$RED" "$NC" "$message"
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-File exists: $file}"

    if [[ -f "$file" ]]; then
        ((PASSED++)) || true
        printf '  %bPASS%b %s\n' "$GREEN" "$NC" "$message"
    else
        ((FAILED++)) || true
        printf '  %bFAIL%b %s\n' "$RED" "$NC" "$message"
    fi
}

skip_test() {
    local message="$1"
    local reason="${2:-}"
    ((SKIPPED++)) || true
    printf '  %bSKIP%b %s %s\n' "$YELLOW" "$NC" "$message" \
        "${reason:+($reason)}"
}

# ── Test: CLI Router ───────────────────────────────────────
test_cli_router() {
    printf '\n%bTest: CLI Router%b\n' "$BOLD" "$NC"

    # Test --help
    local output
    output=$("${PROJECT_DIR}/laravel-backup" --help 2>&1 || true)
    assert_true "[[ -n '$output' ]]" "Help output is not empty"
    assert_true "[[ '$output' == *'laravel-backup'* ]]" "Help contains tool name"

    # Test --version
    output=$("${PROJECT_DIR}/laravel-backup" --version 2>&1 || true)
    assert_true "[[ '$output' == *'v'* ]]" "Version output contains version"

    # Test no arguments
    output=$("${PROJECT_DIR}/laravel-backup" 2>&1 || true)
    assert_true "[[ -n '$output' ]]" "No args shows help"

    # Test invalid command
    local exit_code=0
    "${PROJECT_DIR}/laravel-backup" invalidcommand 2>&1 || exit_code=$?
    assert_equals "1" "$exit_code" "Invalid command returns exit 1"

    # Test path traversal prevention
    exit_code=0
    "${PROJECT_DIR}/laravel-backup" "../etc/passwd" 2>&1 || exit_code=$?
    assert_equals "1" "$exit_code" "Path traversal blocked"
}

# ── Test: Libraries load ───────────────────────────────────
test_libraries() {
    printf '\n%bTest: Library Loading%b\n' "$BOLD" "$NC"

    for lib in colours logging env helpers validator config lock mysql postgres sqlite git archive encrypt notifications; do
        assert_file_exists "${PROJECT_DIR}/lib/${lib}.sh" "Library exists: ${lib}.sh"
    done

    # Test loading all libs
    local exit_code=0
    for lib in "${PROJECT_DIR}"/lib/*.sh; do
        source "$lib" 2>/dev/null || exit_code=$?
    done
    assert_equals "0" "$exit_code" "All libraries load without error"
}

# ── Test: Colours ──────────────────────────────────────────
test_colours() {
    printf '\n%bTest: Colours%b\n' "$BOLD" "$NC"

    source "${PROJECT_DIR}/lib/colours.sh" 2>/dev/null || true

    assert_true "[[ -n '\$BOLD' ]]" "BOLD is defined"
    assert_true "[[ -n '\$RED' ]]" "RED is defined"
    assert_true "[[ -n '\$GREEN' ]]" "GREEN is defined"
    assert_true "[[ -n '\$NC' ]]" "NC is defined"

    # Test strip_colours
    local result
    result=$(strip_colours "${RED}test${NC}" 2>/dev/null || echo "")
    assert_equals "test" "$result" "strip_colours removes colour codes"
}

# ── Test: Logging ──────────────────────────────────────────
test_logging() {
    printf '\n%bTest: Logging%b\n' "$BOLD" "$NC"

    source "${PROJECT_DIR}/lib/colours.sh" 2>/dev/null || true
    source "${PROJECT_DIR}/lib/logging.sh" 2>/dev/null || true

    # Test level functions exist
    assert_true "declare -f log_info &>/dev/null" "log_info exists"
    assert_true "declare -f log_error &>/dev/null" "log_error exists"
    assert_true "declare -f log_warn &>/dev/null" "log_warn exists"
    assert_true "declare -f log_debug &>/dev/null" "log_debug exists"
    assert_true "declare -f log_success &>/dev/null" "log_success exists"

    # Test log file
    local tmp_log="/tmp/lbackup_test_$$.log"
    set_log_file "$tmp_log"
    log_info "test message" 2>/dev/null
    assert_file_exists "$tmp_log" "Log file created"
    assert_true "[[ -s '$tmp_log' ]]" "Log file has content"
    rm -f "$tmp_log"
}

# ── Test: Environment ──────────────────────────────────────
test_env() {
    printf '\n%bTest: Environment Detection%b\n' "$BOLD" "$NC"

    source "${PROJECT_DIR}/lib/env.sh" 2>/dev/null || true

    # Test OS detection
    local os
    os=$(detect_os 2>/dev/null || echo "")
    assert_true "[[ -n '$os' ]]" "detect_os returns result"

    # Test hostname
    local host
    host=$(get_hostname 2>/dev/null || echo "")
    assert_true "[[ -n '$host' ]]" "get_hostname returns result"

    # Test php_version
    local php_ver
    php_ver=$(php_version 2>/dev/null || echo "")
    assert_true "[[ -n '$php_ver' ]]" "php_version returns result"
}

# ── Test: Helpers ──────────────────────────────────────────
test_helpers() {
    printf '\n%bTest: Helpers%b\n' "$BOLD" "$NC"

    source "${PROJECT_DIR}/lib/helpers.sh" 2>/dev/null || true

    # Test command_exists
    assert_true "command_exists bash" "command_exists: bash"
    assert_true "! command_exists nonexistent_command_xyz" "command_exists: missing cmd"

    # Test human_size
    local size
    size=$(human_size 1024 2>/dev/null || echo "")
    assert_true "[[ '$size' == *'KB' ]]" "human_size: KB"

    size=$(human_size 1048576 2>/dev/null || echo "")
    assert_true "[[ '$size' == *'MB' ]]" "human_size: MB"

    # Test checksum_file
    local tmp_file="/tmp/lbackup_test_checksum_$$.txt"
    echo "test content" > "$tmp_file"
    local checksum
    checksum=$(checksum_file "$tmp_file" 2>/dev/null || echo "")
    assert_true "[[ -n '$checksum' ]]" "checksum_file returns result"
    rm -f "$tmp_file"
}

# ── Test: Commands exist ───────────────────────────────────
test_commands() {
    printf '\n%bTest: Command Files%b\n' "$BOLD" "$NC"

    for cmd in backup restore init verify cleanup status schedule update; do
        assert_file_exists "${PROJECT_DIR}/commands/${cmd}.sh" "Command: ${cmd}.sh"
        assert_true "[[ -x '${PROJECT_DIR}/commands/${cmd}.sh' ]]" "Command executable: ${cmd}.sh"
    done
}

# ── Test: Templates ────────────────────────────────────────
test_templates() {
    printf '\n%bTest: Templates%b\n' "$BOLD" "$NC"

    assert_file_exists "${PROJECT_DIR}/templates/restore.sh" "Restore template"
    assert_file_exists "${PROJECT_DIR}/templates/gitignore" "Gitignore template"
    assert_file_exists "${PROJECT_DIR}/templates/manifest.json" "Manifest template"
}

# ── Test: Config ───────────────────────────────────────────
test_config() {
    printf '\n%bTest: Configuration%b\n' "$BOLD" "$NC"

    source "${PROJECT_DIR}/lib/colours.sh" 2>/dev/null || true
    source "${PROJECT_DIR}/lib/logging.sh" 2>/dev/null || true
    source "${PROJECT_DIR}/lib/config.sh" 2>/dev/null || true

    # Test defaults
    config_load "" "/nonexistent" 2>/dev/null || true
    assert_equals "10" "${RETENTION_COUNT:-}" "Default RETENTION_COUNT"
    assert_equals "6" "${COMPRESSION_LEVEL:-}" "Default COMPRESSION_LEVEL"
    assert_equals "true" "${ENCRYPTION_ENABLED:-}" "Default ENCRYPTION_ENABLED"
}

# ── Test: Encryption ───────────────────────────────────────
test_encryption() {
    printf '\n%bTest: Encryption%b\n' "$BOLD" "$NC"

    if ! command -v openssl &>/dev/null; then
        skip_test "Encryption tests" "openssl not available"
        return 0
    fi

    source "${PROJECT_DIR}/lib/colours.sh" 2>/dev/null || true
    source "${PROJECT_DIR}/lib/logging.sh" 2>/dev/null || true
    source "${PROJECT_DIR}/lib/helpers.sh" 2>/dev/null || true
    source "${PROJECT_DIR}/lib/encrypt.sh" 2>/dev/null || true

    export ENCRYPTION_ENABLED=true
    export ENCRYPTION_PASSWORD_SOURCE=env
    export BACKUP_PASSWORD="test_password_$$"

    # Create test file
    local test_file="/tmp/lbackup_encrypt_test_$$.txt"
    local encrypted="${test_file}.enc"
    local decrypted="${test_file}.dec"

    echo "test content for encryption" > "$test_file"

    # Encrypt
    if encrypt_file "$test_file" "$encrypted" 2>/dev/null; then
        assert_file_exists "$encrypted" "Encrypted file created"
        assert_true "[[ ! -f '$test_file' ]]" "Original file removed"

        # Decrypt
        if decrypt_file "$encrypted" "$decrypted" 2>/dev/null; then
            assert_file_exists "$decrypted" "Decrypted file created"
            local original
            original=$(cat "$decrypted" 2>/dev/null || echo "")
            assert_equals "test content for encryption" "$original" "Decrypted content matches"
        else
            ((FAILED++)) || true
            printf '  %bFAIL%b Decryption failed\n' "$RED" "$NC"
        fi

        rm -f "$encrypted" "$decrypted"
    else
        ((FAILED++)) || true
        printf '  %bFAIL%b Encryption failed\n' "$RED" "$NC"
    fi

    rm -f "$test_file" "$encrypted" "$decrypted"
    unset BACKUP_PASSWORD
}

# ── Run all tests ──────────────────────────────────────────
main() {
    printf '%b%b laravel-backup Test Suite %b%b\n' "$BOLD" "$NC" "$BOLD" "$NC"
    printf '%s\n' "$(printf '─%.0s' $(seq 1 50))"

    test_libraries
    test_colours
    test_logging
    test_env
    test_helpers
    test_commands
    test_templates
    test_config
    test_encryption
    test_cli_router

    # Summary
    printf '\n%s\n' "$(printf '─%.0s' $(seq 1 50))"
    printf '%bResults:%b %b%d passed%b, %b%d failed%b, %b%d skipped%b\n' \
        "$BOLD" "$NC" \
        "$GREEN" "$PASSED" "$NC" \
        "$RED" "$FAILED" "$NC" \
        "$YELLOW" "$SKIPPED" "$NC"

    if [[ $FAILED -gt 0 ]]; then
        exit 1
    fi
    exit 0
}

main "$@"
