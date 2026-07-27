#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# install.sh - Install laravel-backup to system
# ─────────────────────────────────────────────────────────────
set -Eeuo pipefail

INSTALL_DIR="/usr/local/bin"
LIB_DIR="/usr/local/lib/laravel-backup"
VERSION="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cat VERSION 2>/dev/null || echo "1.0.0")"
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

log_info()  { printf '%b[INFO]%b  %s\n' "$GREEN" "$NC" "$*"; }
log_warn()  { printf '%b[WARN]%b  %s\n' "$YELLOW" "$NC" "$*"; }
log_error() { printf '%b[ERROR]%b %s\n' "$RED" "$NC" "$*"; }

# ── Check if running as root ────────────────────────────────
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_warn "Not running as root. Using sudo for system paths."
        return 1
    fi
    return 0
}

# ── Check dependencies ──────────────────────────────────────
check_dependencies() {
    local deps=(bash openssl)
    local optional=(git tar gzip curl jq)

    log_info "Checking dependencies..."

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            log_error "Required dependency not found: ${dep}"
            exit 1
        fi
    done

    for dep in "${optional[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            log_warn "Optional dependency not found: ${dep} (some features may be limited)"
        fi
    done

    log_info "Dependencies OK"
}

# ── Install files ───────────────────────────────────────────
install_files() {
    log_info "Installing laravel-backup v${VERSION}..."

    # Create directories
    if check_root; then
        mkdir -p "$LIB_DIR"
        mkdir -p "$INSTALL_DIR"
    else
        # User install
        INSTALL_DIR="${HOME}/.local/bin"
        LIB_DIR="${HOME}/.local/lib/laravel-backup"
        mkdir -p "$INSTALL_DIR"
        mkdir -p "$LIB_DIR"
    fi

    # Copy main executable
    cp "${SOURCE_DIR}/laravel-backup" "${INSTALL_DIR}/laravel-backup"
    chmod +x "${INSTALL_DIR}/laravel-backup"

    # Copy libraries
    cp -r "${SOURCE_DIR}/lib" "${LIB_DIR}/"

    # Copy commands
    cp -r "${SOURCE_DIR}/commands" "${LIB_DIR}/"

    # Copy templates
    cp -r "${SOURCE_DIR}/templates" "${LIB_DIR}/"

    # Copy version
    cp "${SOURCE_DIR}/VERSION" "${LIB_DIR}/"

    # Copy example config
    cp "${SOURCE_DIR}/backup.conf.example" "${LIB_DIR}/" 2>/dev/null || true

    # Update the executable to point to installed lib path
    sed -i.bak "s|LBACKUP_ROOT=.*|LBACKUP_ROOT=\"${LIB_DIR}\"|" \
        "${INSTALL_DIR}/laravel-backup" 2>/dev/null || true

    # macOS compatible sed
    if [[ "$(uname -s)" == "Darwin" ]]; then
        sed -i '' "s|LBACKUP_ROOT=.*|LBACKUP_ROOT=\"${LIB_DIR}\"|" \
            "${INSTALL_DIR}/laravel-backup" 2>/dev/null || true
        rm -f "${INSTALL_DIR}/laravel-backup.bak" 2>/dev/null || true
    fi

    log_success "Installed to ${INSTALL_DIR}/laravel-backup"
    log_success "Libraries at ${LIB_DIR}/"
}

# ── Verify PATH ─────────────────────────────────────────────
verify_path() {
    if [[ ":$PATH:" != *":${INSTALL_DIR}:"* ]]; then
        log_warn "${INSTALL_DIR} is not in your PATH"
        log_info "Add to your shell profile:"
        log_info "  export PATH=\"${INSTALL_DIR}:\$PATH\""

        if [[ -f "${HOME}/.bashrc" ]]; then
            log_info "Or run: echo 'export PATH=\"${INSTALL_DIR}:\$PATH\"' >> ~/.bashrc"
        fi
        if [[ -f "${HOME}/.zshrc" ]]; then
            log_info "Or run: echo 'export PATH=\"${INSTALL_DIR}:\$PATH\"' >> ~/.zshrc"
        fi
    else
        log_info "PATH verified"
    fi
}

# ── Post-install verification ──────────────────────────────
verify_install() {
    log_info "Verifying installation..."

    if [[ -x "${INSTALL_DIR}/laravel-backup" ]]; then
        local installed_version
        installed_version=$("${INSTALL_DIR}/laravel-backup" --version 2>/dev/null | grep -oP '[\d.]+' || echo "")
        if [[ -n "$installed_version" ]]; then
            log_success "Installation verified: v${installed_version}"
        else
            log_success "Installation complete"
        fi
    else
        log_error "Installation verification failed"
        exit 1
    fi
}

main() {
    printf '%b' "${BOLD}laravel-backup installer v${VERSION}${NC}\n\n"

    check_dependencies
    install_files
    verify_path
    verify_install

    echo ""
    log_success "Installation complete!"
    log_info "Get started:"
    log_info "  laravel-backup --help"
    log_info "  cd /path/to/your/laravel/project"
    log_info "  laravel-backup init"
}

main "$@"
