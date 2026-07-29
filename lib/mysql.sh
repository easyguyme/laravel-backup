#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# mysql.sh - MySQL/MariaDB backup and restore
# ─────────────────────────────────────────────────────────────
# Provides database dump and restore for MySQL and MariaDB
# databases. Supports mysqldump with compression.
# ─────────────────────────────────────────────────────────────

# ── Check MySQL client is available ─────────────────────────
mysql_available() {
    command_exists mysqldump && command_exists mysql
}

# ── Get MySQL connection details from .env ──────────────────
mysql_config() {
    local project_root="${1:-$(pwd)}"

    local host port user pass name
    host=$(env_read "${project_root}/.env" "DB_HOST" "${DATABASE_HOST:-127.0.0.1}")
    port=$(env_read "${project_root}/.env" "DB_PORT" "${DATABASE_PORT:-3306}")
    user=$(env_read "${project_root}/.env" "DB_USERNAME" "${DATABASE_USER:-root}")
    pass=$(env_read "${project_root}/.env" "DB_PASSWORD" "${DATABASE_PASSWORD:-}")
    name=$(env_read "${project_root}/.env" "DB_DATABASE" "${DATABASE_NAME:-}")

    echo "${host}|${port}|${user}|${pass}|${name}"
}

# ── Dump MySQL database ─────────────────────────────────────
# Usage: mysql_dump <project_root> <output_file>
# Returns 0 on success, writes dump to output_file
mysql_dump() {
    local project_root="$1"
    local output_file="$2"

    local config
    config=$(mysql_config "$project_root")

    IFS='|' read -r host port user pass name <<< "$config"

    if [[ -z "$name" ]]; then
        log_error "Database name not configured"
        return 1
    fi

    log_info "Dumping MySQL/MariaDB database: ${name}"
    log_debug "  Host: ${host}:${port}"
    log_debug "  User: ${user}"
    log_debug "  Output: ${output_file}"

    # Build mysqldump command
    local -a dump_cmd=(
        mysqldump
        --host="$host"
        --port="$port"
        --user="$user"
        --single-transaction
        --routines
        --triggers
        --events
        --add-drop-table
        --create-options
        --disable-keys
        --extended-insert
        --quick
        --lock-tables=false
    )

    # Add password if set
    if [[ -n "$pass" ]]; then
        dump_cmd+=("--password=${pass}")
    fi

    dump_cmd+=("$name")

    # Execute dump with compression
    if [[ "$output_file" == *.gz ]]; then
        "${dump_cmd[@]}" 2>/dev/null | gzip > "$output_file"
    else
        "${dump_cmd[@]}" > "$output_file" 2>/dev/null
    fi

    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        log_error "MySQL dump failed with exit code: ${exit_code}"
        rm -f "$output_file" 2>/dev/null || true
        return 1
    fi

    # Verify dump file
    if [[ ! -s "$output_file" ]]; then
        log_error "MySQL dump is empty"
        rm -f "$output_file" 2>/dev/null || true
        return 1
    fi

    log_success "Database dumped: $(human_size "$(stat -f%z "$output_file" 2>/dev/null || stat -c%s "$output_file" 2>/dev/null || echo 0)")"
    return 0
}

# ── Restore MySQL database ──────────────────────────────────
# Usage: mysql_restore <project_root> <dump_file>
mysql_restore() {
    local project_root="$1"
    local dump_file="$2"

    local config
    config=$(mysql_config "$project_root")

    IFS='|' read -r host port user pass name <<< "$config"

    if [[ -z "$name" ]]; then
        log_error "Database name not configured"
        return 1
    fi

    log_info "Restoring MySQL/MariaDB database: ${name}"

    # Build mysql command
    local -a restore_cmd=(
        mysql
        --host="$host"
        --port="$port"
        --user="$user"
        "$name"
    )

    if [[ -n "$pass" ]]; then
        restore_cmd+=("--password=${pass}")
    fi

    # Execute restore with decompression if needed
    if [[ "$dump_file" == *.gz ]]; then
        gunzip -c "$dump_file" | "${restore_cmd[@]}" 2>/dev/null
    else
        "${restore_cmd[@]}" < "$dump_file" 2>/dev/null
    fi

    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        log_error "MySQL restore failed with exit code: ${exit_code}"
        return 1
    fi

    log_success "Database restored successfully"
    return 0
}

# ── Get MySQL database size ─────────────────────────────────
# Usage: mysql_size <project_root>
mysql_size() {
    local project_root="$1"

    local config
    config=$(mysql_config "$project_root")

    IFS='|' read -r host port user pass name <<< "$config"

    local size_query="SELECT table_schema AS 'Database', ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)' FROM information_schema.tables WHERE table_schema='${name}' GROUP BY table_schema;"

    local -a size_cmd=(
        mysql
        --host="$host"
        --port="$port"
        --user="$user"
        --skip-column-names
        --batch
    )

    if [[ -n "$pass" ]]; then
        size_cmd+=("--password=${pass}")
    fi

    size_cmd+=("-e" "$size_query")

    local size_mb
    size_mb=$("${size_cmd[@]}" 2>/dev/null | awk '{print $2}' || echo "0")

    if [[ -n "$size_mb" ]] && [[ "$size_mb" =~ ^[0-9.]+$ ]]; then
        echo "${size_mb} MB"
    else
        echo "unknown"
    fi
}

# ── Test MySQL connection ───────────────────────────────────
mysql_test_connection() {
    local project_root="$1"

    local config
    config=$(mysql_config "$project_root")

    IFS='|' read -r host port user pass name <<< "$config"

    local -a test_cmd=(
        mysql
        --host="$host"
        --port="$port"
        --user="$user"
        --connect-timeout=5
    )

    if [[ -n "$pass" ]]; then
        test_cmd+=("--password=${pass}")
    fi

    "${test_cmd[@]}" -e "SELECT 1" "$name" &>/dev/null
}
