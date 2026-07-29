#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# uninstall.sh - Remove laravel-backup from system
# ─────────────────────────────────────────────────────────────
set -Eeuo pipefail

INSTALL_DIR="/usr/local/bin"
LIB_DIR="/usr/local/lib/laravel-backup"
USER_INSTALL_DIR="${HOME}/.local/bin"
USER_LIB_DIR="${HOME}/.local/lib/laravel-backup"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

log_info()    { printf '%b[INFO]%b    %s\n' "$GREEN" "$NC" "$*"; }
log_success() { printf '%b[SUCCESS]%b %s\n' "$GREEN" "$NC" "$*"; }
log_warn()    { printf '%b[WARN]%b    %s\n' "$YELLOW" "$NC" "$*"; }
log_error()   { printf '%b[ERROR]%b   %s\n' "$RED" "$NC" "$*"; }

usage() {
    printf '%b' "${BOLD}laravel-backup uninstaller${NC}

${BOLD}USAGE${NC}
    ./uninstall.sh [options]

${BOLD}OPTIONS${NC}
    -h, --help      Show this help message
    -y, --yes        Skip confirmation
    --system         Remove system-wide install (/usr/local)
    --user           Remove user install (~/.local)

"
    exit 0
}

parse_args() {
    AUTO_YES=false
    REMOVE_SYSTEM=false
    REMOVE_USER=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)  usage ;;
            -y|--yes)   AUTO_YES=true; shift ;;
            --system)   REMOVE_SYSTEM=true; shift ;;
            --user)     REMOVE_USER=true; shift ;;
            *)          log_error "Unknown option: $1"; usage ;;
        esac
    done

    # Default: remove both if not specified
    if [[ "$REMOVE_SYSTEM" == "false" ]] && [[ "$REMOVE_USER" == "false" ]]; then
        REMOVE_SYSTEM=true
        REMOVE_USER=true
    fi
}

# ── Remove files ────────────────────────────────────────────
remove_files() {
    local dir="$1"
    local label="$2"
    local removed=0

    if [[ -d "$dir" ]]; then
        log_info "Removing ${label}: ${dir}"
        rm -rf "$dir"
        ((removed++)) || true
    fi

    return $removed
}

# ── Remove executable ──────────────────────────────────────
remove_executable() {
    local dir="$1"
    local bin="${dir}/laravel-backup"

    if [[ -f "$bin" ]]; then
        log_info "Removing: ${bin}"
        rm -f "$bin"
        return 0
    fi
    return 1
}

main() {
    parse_args "$@"

    printf '%b' "${BOLD}laravel-backup uninstaller${NC}\n\n"

    # Show what will be removed
    log_info "Will remove:"

    [[ -d "$LIB_DIR" ]] && log_info "  System libs: ${LIB_DIR}"
    [[ -f "${INSTALL_DIR}/laravel-backup" ]] && log_info "  System bin: ${INSTALL_DIR}/laravel-backup"
    [[ -d "$USER_LIB_DIR" ]] && log_info "  User libs: ${USER_LIB_DIR}"
    [[ -f "${USER_INSTALL_DIR}/laravel-backup" ]] && log_info "  User bin: ${USER_INSTALL_DIR}/laravel-backup"

    echo ""

    # Confirm
    if [[ "$AUTO_YES" != "true" ]]; then
        read -rp "Proceed with uninstall? [y/N]: " confirm
        if [[ "${confirm,,}" != "y" ]]; then
            log_info "Uninstall cancelled"
            exit 0
        fi
    fi

    # Remove system files
    if [[ "$REMOVE_SYSTEM" == "true" ]]; then
        if [[ $EUID -eq 0 ]]; then
            remove_executable "$INSTALL_DIR" || true
            remove_files "$LIB_DIR" "system libs" || true
        else
            log_warn "Need root to remove system install. Trying sudo..."
            sudo rm -f "${INSTALL_DIR}/laravel-backup" 2>/dev/null || true
            sudo rm -rf "$LIB_DIR" 2>/dev/null || true
        fi
    fi

    # Remove user files
    if [[ "$REMOVE_USER" == "true" ]]; then
        remove_executable "$USER_INSTALL_DIR" || true
        remove_files "$USER_LIB_DIR" "user libs" || true
    fi

    # Remove cron jobs
    if crontab -l 2>/dev/null | grep -q "laravel-backup"; then
        log_info "Removing cron jobs..."
        crontab -l 2>/dev/null | grep -v "laravel-backup" | crontab - 2>/dev/null || true
        log_success "Cron jobs removed"
    fi

    # Remove systemd timers
    local service_name="laravel-backup"
    if systemctl --user is-enabled "${service_name}.timer" &>/dev/null 2>&1; then
        systemctl --user stop "${service_name}.timer" 2>/dev/null || true
        systemctl --user disable "${service_name}.timer" 2>/dev/null || true
        rm -f "${HOME}/.config/systemd/user/${service_name}.timer" 2>/dev/null || true
        rm -f "${HOME}/.config/systemd/user/${service_name}.service" 2>/dev/null || true
        systemctl --user daemon-reload 2>/dev/null || true
        log_success "Systemd timer removed"
    fi

    echo ""
    log_success "Uninstall complete!"
    log_info "Note: Project backup.conf and backups/ directories were NOT removed"
    log_info "Remove them manually if needed: rm -rf /path/to/project/backups /path/to/project/backup.conf"
}

main "$@"
