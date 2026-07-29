#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# notifications.sh - Backup notification system
# ─────────────────────────────────────────────────────────────
# Sends notifications about backup status via Telegram,
# Slack, Discord, Email, and custom Webhooks.
# ─────────────────────────────────────────────────────────────

# ── Send a notification ─────────────────────────────────────
# Usage: notify_send <title> <message> [success|failure]
notify_send() {
    local title="$1"
    local message="$2"
    local status="${3:-info}"

    if [[ "${NOTIFICATIONS_ENABLED:-false}" != "true" ]]; then
        return 0
    fi

    log_debug "Sending notifications..."

    # Run all notification methods in parallel
    {
        notify_telegram "$title" "$message" "$status" &
        notify_slack "$title" "$message" "$status" &
        notify_discord "$title" "$message" "$status" &
        notify_email "$title" "$message" "$status" &
        notify_webhook "$title" "$message" "$status" &
        wait
    } 2>/dev/null

    return 0
}

# ── Telegram notification ───────────────────────────────────
notify_telegram() {
    local title="$1"
    local message="$2"
    local status="$3"

    local token="${TELEGRAM_BOT_TOKEN:-}"
    local chat_id="${TELEGRAM_CHAT_ID:-}"

    if [[ -z "$token" ]] || [[ -z "$chat_id" ]]; then
        return 0
    fi

    if ! command_exists curl; then
        return 0
    fi

    local emoji
    case "$status" in
        success) emoji="✅" ;;
        failure) emoji="❌" ;;
        *)       emoji="ℹ️" ;;
    esac

    local text="${emoji} *${title}*\n${message}"

    curl -s -X POST "https://api.telegram.org/bot${token}/sendMessage" \
        -d "chat_id=${chat_id}" \
        -d "text=${text}" \
        -d "parse_mode=Markdown" \
        --max-time 10 \
        &>/dev/null || true
}

# ── Slack notification ──────────────────────────────────────
notify_slack() {
    local title="$1"
    local message="$2"
    local status="$3"

    local webhook="${SLACK_WEBHOOK_URL:-}"

    if [[ -z "$webhook" ]]; then
        return 0
    fi

    if ! command_exists curl; then
        return 0
    fi

    local color
    case "$status" in
        success) color="#36a64f" ;;
        failure) color="#cc0000" ;;
        *)       color="#439FE0" ;;
    esac

    local payload
    payload=$(cat <<EOF
{
    "attachments": [{
        "color": "${color}",
        "title": "${title}",
        "text": "${message}",
        "footer": "laravel-backup",
        "ts": $(date +%s)
    }]
}
EOF
)

    curl -s -X POST "$webhook" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        --max-time 10 \
        &>/dev/null || true
}

# ── Discord notification ────────────────────────────────────
notify_discord() {
    local title="$1"
    local message="$2"
    local status="$3"

    local webhook="${DISCORD_WEBHOOK_URL:-}"

    if [[ -z "$webhook" ]]; then
        return 0
    fi

    if ! command_exists curl; then
        return 0
    fi

    local color
    case "$status" in
        success) color=3066993 ;;
        failure) color=15158332 ;;
        *)       color=3447003 ;;
    esac

    local payload
    payload=$(cat <<EOF
{
    "embeds": [{
        "title": "${title}",
        "description": "${message}",
        "color": ${color},
        "footer": {
            "text": "laravel-backup"
        },
        "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    }]
}
EOF
)

    curl -s -X POST "$webhook" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        --max-time 10 \
        &>/dev/null || true
}

# ── Email notification ──────────────────────────────────────
notify_email() {
    local title="$1"
    local message="$2"
    local status="$3"

    local to="${EMAIL_TO:-}"
    local from="${EMAIL_FROM:-}"
    local subject="${EMAIL_SUBJECT:-[laravel-backup] Backup Report}"

    if [[ -z "$to" ]]; then
        return 0
    fi

    if ! command_exists mail && ! command_exists sendmail; then
        return 0
    fi

    local body
    body="Subject: ${subject} - ${title}\n\n${message}"

    if command_exists mail; then
        echo -e "$body" | mail -s "${subject} - ${title}" "$to" 2>/dev/null || true
    elif command_exists sendmail; then
        echo -e "$body" | sendmail "$to" 2>/dev/null || true
    fi
}

# ── Custom webhook notification ─────────────────────────────
notify_webhook() {
    local title="$1"
    local message="$2"
    local status="$3"

    local url="${WEBHOOK_URL:-}"
    local method="${WEBHOOK_METHOD:-POST}"

    if [[ -z "$url" ]]; then
        return 0
    fi

    if ! command_exists curl; then
        return 0
    fi

    local payload
    payload=$(cat <<EOF
{
    "title": "${title}",
    "message": "${message}",
    "status": "${status}",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "hostname": "$(get_hostname)"
}
EOF
)

    curl -s -X "$method" "$url" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        --max-time 10 \
        &>/dev/null || true
}

# ── Convenience: notify success ─────────────────────────────
notify_success() {
    local title="$1"
    local message="$2"
    notify_send "$title" "$message" "success"
}

# ── Convenience: notify failure ─────────────────────────────
notify_failure() {
    local title="$1"
    local message="$2"
    notify_send "$title" "$message" "failure"
}
