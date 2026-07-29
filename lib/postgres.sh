#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# postgres.sh - PostgreSQL backup and restore
# ─────────────────────────────────────────────────────────────
# Provides database dump and restore for PostgreSQL databases.
# Supports pg_dump with compression.
# ─────────────────────────────────────────────────────────────

# ── Check PostgreSQL client is available ────────────────────
postgres_available() {
    command_exists pg_dump && command_exists psql
}

# ── Get PostgreSQL connection details from .env ─────────────
postgres_config() {
    local project_root="${1:-$(pwd)}"

    local host port user pass name
    host=$(env_read "${project_root}/.env" "DB_HOST" "${DATABASE_HOST:-127.0.0.1}")
    port=$(env_read "${project_root}/.env" "DB_PORT" "${DATABASE_PORT:-5432}")
    user=$(env_read "${project_root}/.env" "DB_USERNAME" "${DATABASE_USER:-postgres}")
    pass=$(env_read "${project_root}/.env" "DB_PASSWORD" "${DATABASE_PASSWORD:-}")
    name=$(env_read "${project_root}/.env" "DB_DATABASE" "${DATABASE_NAME:-}")

    echo "${host}|${port}|${user}|${pass}|${name}"
}

# ── Dump PostgreSQL database ────────────────────────────────
# Usage: postgres_dump <project_root> <output_file>
postgres_dump() {
    local project_root="$1"
    local output_file="$2"

    local config
    config=$(postgres_config "$project_root")

    IFS='|' read -r host port user pass name <<< "$config"

    if [[ -z "$name" ]]; then
        log_error "Database name not configured"
        return 1
    fi

    log_info "Dumping PostgreSQL database: ${name}"
    log_debug "  Host: ${host}:${port}"
    log_debug "  User: ${user}"
    log_debug "  Output: ${output_file}"

    # Set password for pg_dump
    if [[ -n "$pass" ]]; then
        export PGPASSWORD="$pass"
    fi

    # Build pg_dump command
    local -a dump_cmd=(
        pg_dump
        --host="$host"
        --port="$port"
        --username="$user"
        --no-owner
        --no-privileges
        --clean
        --if-exists
        --format=plain
        "$name"
    )

    # Execute dump with compression
    if [[ "$output_file" == *.gz ]]; then
        "${dump_cmd[@]}" 2>/dev/null | gzip > "$output_file"
    else
        "${dump_cmd[@]}" > "$output_file" 2>/dev/null
    fi

    local exit_code=$?
    unset PGPASSWORD

    if [[ $exit_code -ne 0 ]]; then
        log_error "PostgreSQL dump failed with exit code: ${exit_code}"
        rm -f "$output_file" 2>/dev/null || true
        return 1
    fi

    # Verify dump file
    if [[ ! -s "$output_file" ]]; then
        log_error "PostgreSQL dump is empty"
        rm -f "$output_file" 2>/dev/null || true
        return 1
    fi

    log_success "Database dumped: $(human_size "$(stat -f%z "$output_file" 2>/dev/null || stat -c%s "$output_file" 2>/dev/null || echo 0)")"
    return 0
}

# ── Restore PostgreSQL database ─────────────────────────────
# Usage: postgres_restore <project_root> <dump_file>
postgres_restore() {
    local project_root="$1"
    local dump_file="$2"

    local config
    config=$(postgres_config "$project_root")

    IFS='|' read -r host port user pass name <<< "$config"

    if [[ -z "$name" ]]; then
        log_error "Database name not configured"
        return 1
    fi

    log_info "Restoring PostgreSQL database: ${name}"

    # Set password
    if [[ -n "$pass" ]]; then
        export PGPASSWORD="$pass"
    fi

    # Build psql command
    local -a restore_cmd=(
        psql
        --host="$host"
        --port="$port"
        --username="$user"
        --no-psqlrc
        --quiet
        "$name"
    )

    # Execute restore with decompression if needed
    if [[ "$dump_file" == *.gz ]]; then
        gunzip -c "$dump_file" | "${restore_cmd[@]}" 2>/dev/null
    else
        "${restore_cmd[@]}" < "$dump_file" 2>/dev/null
    fi

    local exit_code=$?
    unset PGPASSWORD

    if [[ $exit_code -ne 0 ]]; then
        log_error "PostgreSQL restore failed with exit code: ${exit_code}"
        return 1
    fi

    log_success "Database restored successfully"
    return 0
}

# ── Get PostgreSQL database size ────────────────────────────
# Usage: postgres_size <project_root>
postgres_size() {
    local project_root="$1"

    local config
    config=$(postgres_config "$project_root")

    IFS='|' read -r host port user pass name <<< "$config"

    if [[ -n "$pass" ]]; then
        export PGPASSWORD="$pass"
    fi

    local size_query="SELECT pg_size_pretty(pg_database_size('${name}'));"

    local -a size_cmd=(
        psql
        --host="$host"
        --port="$port"
        --username="$user"
        --no-psqlrc
        --tuples-only
        --quiet
        -c "$size_query"
        "$name"
    )

    local size
    size=$("${size_cmd[@]}" 2>/dev/null | tr -d ' ' || echo "unknown")
    unset PGPASSWORD

    echo "${size:-unknown}"
}

# ── Test PostgreSQL connection ──────────────────────────────
postgres_test_connection() {
    local project_root="$1"

    local config
    config=$(postgres_config "$project_root")

    IFS='|' read -r host port user pass name <<< "$config"

    if [[ -n "$pass" ]]; then
        export PGPASSWORD="$pass"
    fi

    local -a test_cmd=(
        psql
        --host="$host"
        --port="$port"
        --username="$user"
        --no-psqlrc
        --quiet
        --tuples-only
        -c "SELECT 1"
        "$name"
    )

    "${test_cmd[@]}" &>/dev/null
    local result=$?
    unset PGPASSWORD

    return $result
}
