#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# sqlite.sh - SQLite backup and restore
# ─────────────────────────────────────────────────────────────
# Provides database dump and restore for SQLite databases.
# Uses sqlite3 .dump command with compression.
# ─────────────────────────────────────────────────────────────

# ── Check SQLite client is available ────────────────────────
sqlite_available() {
    command_exists sqlite3
}

# ── Get SQLite database path from .env ──────────────────────
sqlite_config() {
    local project_root="${1:-$(pwd)}"

    # Check config override first
    local db_path="${SQLITE_DATABASE_PATH:-}"

    if [[ -z "$db_path" ]]; then
        # Read from .env
        db_path=$(env_read "${project_root}/.env" "DB_DATABASE" "")
    fi

    if [[ -z "$db_path" ]]; then
        # Default Laravel SQLite path
        db_path="database/database.sqlite"
    fi

    # Make relative path absolute
    if [[ "$db_path" != /* ]]; then
        db_path="${project_root}/${db_path}"
    fi

    echo "$db_path"
}

# ── Dump SQLite database ────────────────────────────────────
# Usage: sqlite_dump <project_root> <output_file>
sqlite_dump() {
    local project_root="$1"
    local output_file="$2"

    local db_path
    db_path=$(sqlite_config "$project_root")

    if [[ ! -f "$db_path" ]]; then
        log_error "SQLite database not found: ${db_path}"
        return 1
    fi

    log_info "Dumping SQLite database: ${db_path}"
    log_debug "  Output: ${output_file}"

    # Check if database is not empty
    local table_count
    table_count=$(sqlite3 "$db_path" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';" 2>/dev/null || echo "0")

    if [[ "$table_count" -eq 0 ]]; then
        log_warn "SQLite database is empty (no tables)"
    fi

    # Execute dump with compression
    if [[ "$output_file" == *.gz ]]; then
        sqlite3 "$db_path" ".dump" 2>/dev/null | gzip > "$output_file"
    else
        sqlite3 "$db_path" ".dump" > "$output_file" 2>/dev/null
    fi

    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        log_error "SQLite dump failed with exit code: ${exit_code}"
        rm -f "$output_file" 2>/dev/null || true
        return 1
    fi

    # Verify dump file
    if [[ ! -s "$output_file" ]]; then
        log_error "SQLite dump is empty"
        rm -f "$output_file" 2>/dev/null || true
        return 1
    fi

    log_success "Database dumped: $(human_size "$(stat -f%z "$output_file" 2>/dev/null || stat -c%s "$output_file" 2>/dev/null || echo 0)")"
    return 0
}

# ── Restore SQLite database ─────────────────────────────────
# Usage: sqlite_restore <project_root> <dump_file>
sqlite_restore() {
    local project_root="$1"
    local dump_file="$2"

    local db_path
    db_path=$(sqlite_config "$project_root")

    log_info "Restoring SQLite database: ${db_path}"

    # Create directory if needed
    local db_dir
    db_dir=$(dirname "$db_path")
    if [[ ! -d "$db_dir" ]]; then
        mkdir -p "$db_dir" 2>/dev/null || {
            log_error "Cannot create database directory: ${db_dir}"
            return 1
        }
    fi

    # Decompress if needed
    local sql_content
    if [[ "$dump_file" == *.gz ]]; then
        sql_content=$(gunzip -c "$dump_file" 2>/dev/null)
    else
        sql_content=$(cat "$dump_file" 2>/dev/null)
    fi

    if [[ -z "$sql_content" ]]; then
        log_error "Failed to read dump file"
        return 1
    fi

    # Remove existing database and recreate
    rm -f "$db_path" 2>/dev/null || true

    # Execute SQL to recreate database
    echo "$sql_content" | sqlite3 "$db_path" 2>/dev/null

    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        log_error "SQLite restore failed with exit code: ${exit_code}"
        return 1
    fi

    # Verify restored database
    local table_count
    table_count=$(sqlite3 "$db_path" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';" 2>/dev/null || echo "0")

    log_success "Database restored (${table_count} tables)"
    return 0
}

# ── Get SQLite database size ────────────────────────────────
# Usage: sqlite_size <project_root>
sqlite_size() {
    local project_root="$1"

    local db_path
    db_path=$(sqlite_config "$project_root")

    if [[ ! -f "$db_path" ]]; then
        echo "N/A"
        return 0
    fi

    local size
    size=$(stat -f%z "$db_path" 2>/dev/null || stat -c%s "$db_path" 2>/dev/null || echo "0")

    echo "$(human_size "$size")"
}

# ── Test SQLite connection ──────────────────────────────────
sqlite_test_connection() {
    local project_root="$1"

    local db_path
    db_path=$(sqlite_config "$project_root")

    if [[ ! -f "$db_path" ]]; then
        return 1
    fi

    # Simple query to test database integrity
    sqlite3 "$db_path" "PRAGMA integrity_check;" 2>/dev/null | grep -q "ok"
}

# ── Backup SQLite database file directly ────────────────────
# Usage: sqlite_file_backup <project_root> <output_file>
# This creates a raw copy instead of SQL dump
sqlite_file_backup() {
    local project_root="$1"
    local output_file="$2"

    local db_path
    db_path=$(sqlite_config "$project_root")

    if [[ ! -f "$db_path" ]]; then
        log_error "SQLite database not found: ${db_path}"
        return 1
    fi

    log_info "Creating SQLite file backup: ${db_path}"

    # Use sqlite3 .backup for a consistent copy
    sqlite3 "$db_path" ".backup '${output_file}'" 2>/dev/null

    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        # Fallback to simple copy
        cp "$db_path" "$output_file" 2>/dev/null
        exit_code=$?
    fi

    if [[ $exit_code -eq 0 ]]; then
        log_success "SQLite backup created: $(human_size "$(stat -f%z "$output_file" 2>/dev/null || stat -c%s "$output_file" 2>/dev/null || echo 0)")"
    fi

    return $exit_code
}
