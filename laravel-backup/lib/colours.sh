#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# colours.sh - Terminal colour definitions and helpers
# ─────────────────────────────────────────────────────────────
# Provides standard colour variables and a function to strip
# colour codes from output for log files.
# ─────────────────────────────────────────────────────────────

# Detect colour support
if [[ -t 1 ]] && command -v tput &>/dev/null && [[ $(tput colors 2>/dev/null || echo 0) -ge 8 ]]; then
    BOLD=$'\033[1m'
    DIM=$'\033[2m'
    UNDERLINE=$'\033[4m'
    BLINK=$'\033[5m'
    REVERSE=$'\033[7m'

    RED=$'\033[0;31m'
    GREEN=$'\033[0;32m'
    YELLOW=$'\033[1;33m'
    BLUE=$'\033[0;34m'
    MAGENTA=$'\033[0;35m'
    CYAN=$'\033[0;36m'
    WHITE=$'\033[0;37m'

    BRIGHT_RED=$'\033[1;31m'
    BRIGHT_GREEN=$'\033[1;32m'
    BRIGHT_YELLOW=$'\033[1;33m'
    BRIGHT_BLUE=$'\033[1;34m'
    BRIGHT_MAGENTA=$'\033[1;35m'
    BRIGHT_CYAN=$'\033[1;36m'
else
    BOLD=''
    DIM=''
    UNDERLINE=''
    BLINK=''
    REVERSE=''

    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    MAGENTA=''
    CYAN=''
    WHITE=''

    BRIGHT_RED=''
    BRIGHT_GREEN=''
    BRIGHT_YELLOW=''
    BRIGHT_BLUE=''
    BRIGHT_MAGENTA=''
    BRIGHT_CYAN=''
fi

NC=$'\033[0m'

# ── Strip colour codes from a string ────────────────────────
# Usage: strip_colours "$string"
strip_colours() {
    printf '%s' "$1" | sed 's/\x1b\[[0-9;]*m//g'
}

# ── Print a coloured line ───────────────────────────────────
# Usage: colour_print "$RED" "error message"
colour_print() {
    local colour="$1"
    shift
    printf '%b%b%b' "$colour" "$*" "$NC"
}

# ── Print a coloured line with newline ──────────────────────
colour_println() {
    local colour="$1"
    shift
    printf '%b%b%b\n' "$colour" "$*" "$NC"
}
