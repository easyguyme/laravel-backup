#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# env.sh - Environment detection and .env parsing
# ─────────────────────────────────────────────────────────────
# Detects OS, Laravel project, PHP version, database type,
# and parses .env files safely.
# ─────────────────────────────────────────────────────────────

# ── Detect OS ───────────────────────────────────────────────
detect_os() {
    local os="unknown"
    local distro=""

    case "$(uname -s)" in
        Linux*)
            os="linux"
            if [[ -f /etc/os-release ]]; then
                # shellcheck source=/dev/null
                source /etc/os-release 2>/dev/null
                distro="${ID:-unknown}"
            elif [[ -f /etc/redhat-release ]]; then
                distro=$(sed 's/.*release \([0-9.]*\).*/\1/' /etc/redhat-release 2>/dev/null || echo "rhel")
            fi
            ;;
        Darwin*)
            os="macos"
            distro="macos"
            ;;
        CYGWIN*|MINGW*|MSYS*)
            os="windows"
            distro="wsl"
            ;;
        *)
            os="unknown"
            distro="unknown"
            ;;
    esac

    # Detect WSL specifically
    if [[ "$os" == "linux" ]] && grep -qi microsoft /proc/version 2>/dev/null; then
        distro="wsl"
    fi

    echo "${os}:${distro}"
}

# ── Get OS name for display ─────────────────────────────────
os_display_name() {
    local os_info
    os_info=$(detect_os)
    local os="${os_info%%:*}"
    local distro="${os_info##*:}"

    case "$os" in
        macos)
            local version
            version=$(sw_vers -productVersion 2>/dev/null || echo "unknown")
            echo "macOS ${version}"
            ;;
        linux)
            case "$distro" in
                ubuntu|debian|rocky|almalinux|centos)
                    echo "${distro^}"
                    ;;
                wsl)
                    echo "WSL"
                    ;;
                *)
                    echo "Linux"
                    ;;
            esac
            ;;
        *)
            echo "Unknown"
            ;;
    esac
}

# ── Detect if current directory is a Laravel project ────────
detect_laravel() {
    local project_root="${1:-$(pwd)}"

    if [[ -f "${project_root}/artisan" ]] && \
       [[ -f "${project_root}/composer.json" ]] && \
       [[ -d "${project_root}/app" ]]; then
        return 0
    fi
    return 1
}

# ── Get Laravel version ─────────────────────────────────────
laravel_version() {
    local project_root="${1:-$(pwd)}"

    if [[ -f "${project_root}/artisan" ]]; then
        local version
        version=$(php "${project_root}/artisan" --version 2>/dev/null | grep -oP '[\d]+\.[\d]+[\.\d]*' || true)
        if [[ -n "$version" ]]; then
            echo "$version"
            return 0
        fi
    fi

    # Fallback: check composer.json
    if [[ -f "${project_root}/composer.json" ]]; then
        if command -v jq &>/dev/null; then
            jq -r '.require["laravel/framework"] // "unknown"' "${project_root}/composer.json" 2>/dev/null || echo "unknown"
            return 0
        fi
        grep -oP '"laravel/framework":\s*"[^"]*"' "${project_root}/composer.json" 2>/dev/null | grep -oP '"[^"]*"$' | tr -d '"' || echo "unknown"
        return 0
    fi

    echo "unknown"
}

# ── Get PHP version ─────────────────────────────────────────
php_version() {
    if command -v php &>/dev/null; then
        php -r 'echo PHP_VERSION;' 2>/dev/null || echo "unknown"
    else
        echo "not installed"
    fi
}

# ── Safely read a value from .env file ──────────────────────
# Usage: env_read ".env" "DB_CONNECTION"
env_read() {
    local env_file="$1"
    local key="$2"
    local default="${3:-}"

    if [[ ! -f "$env_file" ]]; then
        echo "$default"
        return 1
    fi

    local value
    # Match KEY=value, KEY="value", KEY='value', #KEY=value (commented out)
    value=$(grep -E "^#?\s*${key}=" "$env_file" 2>/dev/null | tail -1 | cut -d'=' -f2-)

    # If the line was commented out, return default
    if grep -qE "^#\s*${key}=" "$env_file" 2>/dev/null; then
        echo "$default"
        return 0
    fi

    if [[ -z "$value" ]]; then
        echo "$default"
        return 1
    fi

    # Strip carriage return FIRST (before quote matching)
    value=$(echo "$value" | tr -d '\r')
    
    # Trim whitespace
    value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # Strip surrounding quotes (single or double) - only from start/end
    # Examples: "value" -> value, 'value' -> value, value" -> value
    if [[ "$value" =~ ^\"(.*)\"$ ]]; then
        value="${BASH_REMATCH[1]}"
    elif [[ "$value" =~ ^\'(.*)\'$ ]]; then
        value="${BASH_REMATCH[1]}"
    elif [[ "$value" == \"* ]]; then
        value="${value#\"}"
    elif [[ "$value" == *\" ]]; then
        value="${value%\"}"
    elif [[ "$value" == \'* ]]; then
        value="${value#\'}"
    elif [[ "$value" == *\' ]]; then
        value="${value%\'}"
    fi

    # Strip inline comments (space followed by #) - but not inside quotes
    value="${value%% #*}"

    echo "$value"
    return 0
}

# ── Read all .env values into an associative array ──────────
env_load() {
    local env_file="${1:-.env}"
    local prefix="${2:-}"

    if [[ ! -f "$env_file" ]]; then
        return 1
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comments
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue

        # Parse KEY=value
        if [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
            local key="${line%%=*}"
            local value="${line#*=}"

            # Skip if key starts with prefix (for namespacing)
            if [[ -n "$prefix" && ! "$key" =~ ^${prefix} ]]; then
                continue
            fi

            # Strip quotes
            value="${value#\"}"
            value="${value%\"}"
            value="${value#\'}"
            value="${value%\'}"

            # Strip inline comments
            value="${value%% #*}"

            export "${key}=${value}"
        fi
    done < "$env_file"
}

# ── Detect database type from .env ──────────────────────────
detect_database_type() {
    local project_root="${1:-$(pwd)}"

    # Check config override first
    if [[ -n "${DATABASE_TYPE:-}" ]]; then
        echo "${DATABASE_TYPE}"
        return 0
    fi

    if [[ -f "${project_root}/.env" ]]; then
        local db_connection
        db_connection=$(env_read "${project_root}/.env" "DB_CONNECTION" "")
        case "$db_connection" in
            mysql|mariadb)
                echo "mysql"
                ;;
            pgsql|postgres|postgresql)
                echo "pgsql"
                ;;
            sqlite|sqlite3)
                echo "sqlite"
                ;;
            *)
                echo "$db_connection"
                ;;
        esac
        return 0
    fi

    echo ""
    return 1
}

# ── Detect if git is installed and repo exists ──────────────
detect_git() {
    local project_root="${1:-$(pwd)}"

    if command -v git &>/dev/null; then
        if git -C "$project_root" rev-parse --is-inside-work-tree &>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# ── Get git commit hash ─────────────────────────────────────
git_commit() {
    local project_root="${1:-$(pwd)}"
    git -C "$project_root" rev-parse --short HEAD 2>/dev/null || echo "unknown"
}

# ── Get git branch ──────────────────────────────────────────
git_branch() {
    local project_root="${1:-$(pwd)}"
    git -C "$project_root" branch --show-current 2>/dev/null || echo "unknown"
}

# ── Get hostname ────────────────────────────────────────────
get_hostname() {
    hostname 2>/dev/null || echo "unknown"
}
