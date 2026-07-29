#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# commands/schedule.sh - Set up automated backup scheduling
# ─────────────────────────────────────────────────────────────
set -Eeuo pipefail

LBACKUP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for _lib in colours logging env helpers validator config; do
    [[ -f "${LBACKUP_ROOT}/lib/${_lib}.sh" ]] && source "${LBACKUP_ROOT}/lib/${_lib}.sh"
done
unset _lib

usage() {
    printf '%b' "${BOLD}laravel-backup schedule${NC} - Set up automated backups

${BOLD}USAGE${NC}
    laravel-backup schedule [options]

${BOLD}OPTIONS${NC}
    -h, --help              Show this help message
    -f, --frequency <freq>  Frequency: hourly, daily, weekly, monthly
    --cron <expression>     Custom cron expression
    --systemd               Use systemd timer instead of cron
    --remove                Remove existing schedule
    --show                  Show current schedule

${BOLD}EXAMPLES${NC}
    laravel-backup schedule --frequency daily
    laravel-backup schedule --frequency weekly
    laravel-backup schedule --cron "0 */6 * * *"
    laravel-backup schedule --systemd --frequency daily

"
    exit 0
}

parse_args() {
    FREQUENCY=""
    CUSTOM_CRON=""
    USE_SYSTEMD=false
    REMOVE=false
    SHOW=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)          usage ;;
            -f|--frequency)     FREQUENCY="$2"; shift 2 ;;
            --cron)             CUSTOM_CRON="$2"; shift 2 ;;
            --systemd)          USE_SYSTEMD=true; shift ;;
            --remove)           REMOVE=true; shift ;;
            --show)             SHOW=true; shift ;;
            *)                  log_error "Unknown option: $1"; usage ;;
        esac
    done
}

# ── Get cron expression for frequency ──────────────────────
frequency_to_cron() {
    local freq="$1"
    local hour
    hour=$(shuf -i 0-5 -n 1 2>/dev/null || echo "2")

    case "$freq" in
        hourly)     echo "0 * * * *" ;;
        daily)      echo "0 ${hour} * * *" ;;
        weekly)     echo "0 ${hour} * * 0" ;;
        monthly)    echo "0 ${hour} 1 * *" ;;
        *)
            log_error "Unknown frequency: ${freq}"
            log_info "Supported: hourly, daily, weekly, monthly"
            return 1
            ;;
    esac
}

# ── Install crontab entry ──────────────────────────────────
install_cron() {
    local cron_expr="$1"
    local script_path
    script_path=$(readlink -f "${LBACKUP_ROOT}/laravel-backup" 2>/dev/null || echo "${LBACKUP_ROOT}/laravel-backup")
    local project_dir
    project_dir=$(pwd)
    local log_file="${BACKUP_DIR:-backups}/backup.log"
    local marker="# laravel-backup auto"

    log_info "Installing cron job: ${cron_expr}"

    local cron_line="${cron_expr} cd ${project_dir} && ${script_path} backup >> ${log_file} 2>&1 ${marker}"

    # Remove existing entry
    local existing
    existing=$(crontab -l 2>/dev/null || echo "")
    local cleaned
    cleaned=$(echo "$existing" | grep -v "${marker}" 2>/dev/null || true)

    # Add new entry
    local new_crontab
    if [[ -n "$cleaned" ]]; then
        new_crontab=$(printf '%s\n%s' "$cleaned" "$cron_line")
    else
        new_crontab="$cron_line"
    fi

    echo "$new_crontab" | crontab -

    log_success "Cron job installed"
    log_info "Next run: $(date -d "tomorrow" '+%Y-%m-%d %H:%M' 2>/dev/null || date '+%Y-%m-%d %H:%M')"
}

# ── Install systemd timer ──────────────────────────────────
install_systemd() {
    local cron_expr="$1"
    local script_path
    script_path=$(readlink -f "${LBACKUP_ROOT}/laravel-backup" 2>/dev/null || echo "${LBACKUP_ROOT}/laravel-backup")
    local project_dir
    project_dir=$(pwd)
    local service_name="laravel-backup"

    log_info "Installing systemd timer"

    # Create service file
    local service_dir="${HOME}/.config/systemd/user"
    mkdir -p "$service_dir"

    cat > "${service_dir}/${service_name}.service" <<EOF
[Unit]
Description=laravel-backup
After=network.target

[Service]
Type=oneshot
WorkingDirectory=${project_dir}
ExecStart=${script_path} backup
StandardOutput=append:${project_dir}/${BACKUP_DIR:-backups}/backup.log
StandardError=append:${project_dir}/${BACKUP_DIR:-backups}/backup.log
EOF

    # Create timer file
    cat > "${service_dir}/${service_name}.timer" <<EOF
[Unit]
Description=laravel-backup timer

[Timer]
OnCalendar=${cron_expr}
Persistent=true

[Install]
WantedBy=timers.target
EOF

    # Enable timer
    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user enable "${service_name}.timer" 2>/dev/null || true
    systemctl --user start "${service_name}.timer" 2>/dev/null || true

    log_success "Systemd timer installed"
    log_info "Check status: systemctl --user status ${service_name}.timer"
}

# ── Remove schedule ─────────────────────────────────────────
remove_schedule() {
    log_info "Removing backup schedule..."

    # Remove cron entry
    local marker="# laravel-backup auto"
    local existing
    existing=$(crontab -l 2>/dev/null || echo "")
    local cleaned
    cleaned=$(echo "$existing" | grep -v "${marker}" 2>/dev/null || true)

    if [[ "$cleaned" != "$(crontab -l 2>/dev/null || echo "")" ]]; then
        echo "$cleaned" | crontab - 2>/dev/null || true
        log_success "Removed cron job"
    fi

    # Remove systemd timer
    local service_name="laravel-backup"
    local service_dir="${HOME}/.config/systemd/user"
    if [[ -f "${service_dir}/${service_name}.timer" ]]; then
        systemctl --user stop "${service_name}.timer" 2>/dev/null || true
        systemctl --user disable "${service_name}.timer" 2>/dev/null || true
        rm -f "${service_dir}/${service_name}.timer" "${service_dir}/${service_name}.service" 2>/dev/null || true
        systemctl --user daemon-reload 2>/dev/null || true
        log_success "Removed systemd timer"
    fi
}

# ── Show current schedule ──────────────────────────────────
show_schedule() {
    log_header "Current Schedule"

    # Cron
    local marker="# laravel-backup auto"
    local cron_entry
    cron_entry=$(crontab -l 2>/dev/null | grep "${marker}" || true)

    if [[ -n "$cron_entry" ]]; then
        log_info "Cron: ${cron_entry%%#*}"
    else
        log_info "Cron: not scheduled"
    fi

    # Systemd
    local service_name="laravel-backup"
    if systemctl --user is-enabled "${service_name}.timer" &>/dev/null; then
        local timer_info
        timer_info=$(systemctl --user list-timers "${service_name}.timer" --no-legend 2>/dev/null || echo "")
        log_info "Systemd: ${timer_info:-active}"
    else
        log_info "Systemd: not scheduled"
    fi
}

main() {
    parse_args "$@"

    config_load "" "."

    if [[ "$SHOW" == "true" ]]; then
        show_schedule
        exit 0
    fi

    if [[ "$REMOVE" == "true" ]]; then
        remove_schedule
        exit 0
    fi

    # Determine cron expression
    local cron_expr=""
    if [[ -n "$CUSTOM_CRON" ]]; then
        cron_expr="$CUSTOM_CRON"
    elif [[ -n "$FREQUENCY" ]]; then
        cron_expr=$(frequency_to_cron "$FREQUENCY") || exit 1
    else
        # Default to daily
        cron_expr=$(frequency_to_cron "daily")
    fi

    log_header "Scheduling Backup"
    log_kv "Expression" "$cron_expr"
    log_kv "Method" "$([ "$USE_SYSTEMD" == "true" ] && echo 'systemd timer' || echo 'cron')"
    echo ""

    if [[ "$USE_SYSTEMD" == "true" ]]; then
        install_systemd "$cron_expr"
    else
        install_cron "$cron_expr"
    fi
}

main "$@"
