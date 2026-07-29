# Library Modules Reference

The `lib/` directory contains shared libraries used by all commands. Each module is a bash script that provides related functions.

## colours.sh

Terminal colour definitions and helpers.

### Features

- Defines colour variables (`RED`, `GREEN`, `YELLOW`, `BLUE`, `BOLD`, `NC`)
- Auto-detects TTY support
- Strips colour codes when output is not a terminal

### Usage

```bash
source lib/colours.sh
echo -e "${GREEN}Success${NC}"
echo -e "${RED}Error${NC}"
```

---

## logging.sh

Centralized logging with levels, timestamps, and file output.

### Functions

| Function | Description |
|----------|-------------|
| `log_debug <msg>` | Debug level (only shown when `LOG_LEVEL=DEBUG`) |
| `log_info <msg>` | Informational messages |
| `log_success <msg>` | Success messages (green) |
| `log_warn <msg>` | Warning messages (yellow) |
| `log_error <msg>` | Error messages (red, to stderr) |
| `log_header <msg>` | Section header with bold formatting |
| `log_kv <key> <value>` | Key-value pair display |
| `set_log_level <level>` | Change log level at runtime |
| `set_log_file <path>` | Enable file logging |

### Log Levels

DEBUG < INFO < WARNING < ERROR < SUCCESS

### Examples

```bash
source lib/logging.sh
set_log_level "DEBUG"
set_log_file "backups/backup.log"

log_info "Starting backup..."
log_success "Backup complete"
log_error "Something went wrong"
log_kv "Project" "my-app"
```

---

## env.sh

Environment detection and `.env` file parsing.

### Functions

| Function | Description |
|----------|-------------|
| `detect_os` | Returns `os:distro` (e.g., `linux:ubuntu`, `macos:macos`) |
| `os_display_name` | Human-readable OS name |
| `detect_laravel <dir>` | Checks if directory is a Laravel project |
| `laravel_version <dir>` | Gets Laravel version from artisan or composer.json |
| `php_version` | Gets PHP version |
| `env_read <file> <key> [default]` | Safely reads a value from `.env` file |
| `env_load <file> [prefix]` | Loads all `.env` values into environment |
| `detect_database_type <dir>` | Detects database type from `.env` |
| `get_hostname` | Gets system hostname |

### Laravel Detection

A directory is considered a Laravel project if it contains:

- `artisan` file
- `composer.json` file
- `app/` directory

### Database Detection

Reads `DB_CONNECTION` from `.env` and maps:

| `.env` Value | Detected Type |
|--------------|---------------|
| `mysql`, `mariadb` | `mysql` |
| `pgsql`, `postgres`, `postgresql` | `pgsql` |
| `sqlite`, `sqlite3` | `sqlite` |

### Examples

```bash
source lib/env.sh

# Check OS
os=$(detect_os)
echo "Running on: $(os_display_name)"

# Check if Laravel project
if detect_laravel "."; then
    echo "Laravel version: $(laravel_version ".")"
fi

# Read .env value
db_name=$(env_read ".env" "DB_DATABASE" "laravel")
echo "Database: $db_name"
```

---

## helpers.sh

General utility functions.

### Functions

| Function | Description |
|----------|-------------|
| `command_exists <cmd>` | Checks if a command is available |
| `confirm <prompt>` | Y/N confirmation prompt |
| `prompt_input <prompt> <default>` | Input prompt with default |
| `prompt_password <prompt>` | Hidden password input |
| `human_size <bytes>` | Converts bytes to human-readable (e.g., `1.5M`) |
| `checksum_file <file>` | SHA-256 checksum of file |
| `temp_dir` | Creates and returns temp directory path |
| `retry <count> <delay> <cmd>` | Retry command with exponential backoff |
| `validate_filename <name>` | Validates filename (no path traversal) |
| `check_disk_space <dir> <bytes>` | Checks available disk space |
| `elapsed_time <start> <end>` | Formats elapsed time |

### Examples

```bash
source lib/helpers.sh

# Check if command exists
if command_exists docker; then
    echo "Docker is available"
fi

# Human-readable sizes
echo "$(human_size 1536)"  # Output: 1.5K
echo "$(human_size 1572864)"  # Output: 1.5M

# SHA-256 checksum
echo "$(checksum_file backup.tar.gz)"

# Retry with backoff
retry 3 2 curl -s https://example.com
```

---

## validator.sh

Input and state validation.

### Functions

| Function | Description |
|----------|-------------|
| `validate_laravel_project <dir>` | Validates directory is a Laravel project |
| `validate_backup_dir <dir>` | Validates backup directory exists and is writable |
| `validate_database_connection <type> <dir>` | Tests database connection |
| `validate_backup_file <file>` | Validates backup file exists and is readable |
| `validate_config` | Validates configuration values |
| `validate_disk_space <dir> <bytes>` | Checks sufficient disk space |
| `validate_encryption_password` | Checks encryption password is available |

### Examples

```bash
source lib/validator.sh

# Validate before backup
validate_laravel_project "." || exit 1
validate_backup_dir "." || exit 1
validate_encryption_password || exit 1
```

---

## config.sh

Configuration management with defaults.

### Functions

| Function | Description |
|----------|-------------|
| `config_load [file] [dir]` | Load configuration file |
| `config_get <key> [default]` | Get configuration value |
| `config_set <key> <value>` | Set runtime configuration value |
| `config_show` | Display current configuration |
| `config_create [target]` | Create default configuration file |

### Default Values

The library defines 37 default configuration values. When loading a config file, defaults are applied first, then file values override them.

### Config Lookup Order

1. Path specified in first argument
2. `backup.conf` in project root
3. `backup.conf` next to laravel-backup script
4. Built-in defaults

### Examples

```bash
source lib/config.sh

# Load config
config_load "backup.conf" "."

# Get value with default
retain=$(config_get "RETENTION_COUNT" "10")

# Override at runtime
config_set "DRY_RUN" "true"

# Show all settings
config_show
```

---

## lock.sh

PID-based lock files for concurrent execution prevention.

### Functions

| Function | Description |
|----------|-------------|
| `lock_acquire <name>` | Acquire named lock (fails if already held) |
| `lock_release <name>` | Release named lock |
| `lock_check <name>` | Check if lock is held |
| `lock_force <name>` | Force-release stale lock |

### How It Works

- Creates a PID file in `/tmp/laravel-backup-<name>.lock`
- Checks if existing lock holder process is still running
- Automatically removes stale locks from dead processes

### Examples

```bash
source lib/lock.sh

# Acquire lock before backup
lock_acquire "backup" || exit 1

# ... perform backup ...

# Release lock (also done automatically on script exit)
lock_release "backup"
```

---

## mysql.sh

MySQL/MariaDB database operations.

### Functions

| Function | Description |
|----------|-------------|
| `mysql_dump <dir> <output>` | Dump MySQL database to compressed SQL file |
| `mysql_restore <dir> <dump_file>` | Restore MySQL database from SQL dump |
| `mysql_test_connection <dir>` | Test database connection |
| `mysql_database_size <dir>` | Get database size in bytes |

### Requirements

- `mysqldump` command
- `mysql` command
- Database credentials in `.env` or config

### Examples

```bash
source lib/mysql.sh

# Dump database
mysql_dump "." "/tmp/backup.sql.gz"

# Restore database
mysql_restore "." "/tmp/backup.sql.gz"
```

---

## postgres.sh

PostgreSQL database operations.

### Functions

| Function | Description |
|----------|-------------|
| `postgres_dump <dir> <output>` | Dump PostgreSQL database to compressed SQL file |
| `postgres_restore <dir> <dump_file>` | Restore PostgreSQL database from SQL dump |
| `postgres_test_connection <dir>` | Test database connection |
| `postgres_database_size <dir>` | Get database size in bytes |

### Requirements

- `pg_dump` command
- `psql` command
- Database credentials in `.env` or config

### Examples

```bash
source lib/postgres.sh

# Dump database
postgres_dump "." "/tmp/backup.sql.gz"

# Restore database
postgres_restore "." "/tmp/backup.sql.gz"
```

---

## sqlite.sh

SQLite database operations.

### Functions

| Function | Description |
|----------|-------------|
| `sqlite_dump <dir> <output>` | Dump SQLite database to compressed SQL file |
| `sqlite_restore <dir> <dump_file>` | Restore SQLite database from SQL dump |
| `sqlite_test_connection <dir>` | Test database file exists |
| `sqlite_database_size <dir>` | Get database file size in bytes |

### Requirements

- `sqlite3` command
- Database path in `.env` or config

### Examples

```bash
source lib/sqlite.sh

# Dump database
sqlite_dump "." "/tmp/backup.sql.gz"

# Restore database
sqlite_restore "." "/tmp/backup.sql.gz"
```

---

## git.sh

Git operations for backup management.

### Functions

| Function | Description |
|----------|-------------|
| `git_available <dir>` | Check if git is available and dir is a repo |
| `git_backup_full <dir> <message> <tag>` | Commit, tag, and optionally push backup files |
| `git_remote_url <dir>` | Get remote URL |
| `git_detect_remote_provider <dir>` | Detect GitHub/GitLab/Bitbucket from URL |
| `git_changes_count <dir>` | Count pending changes |

### Git Operations

The `git_backup_full` function:

1. Stages backup files (`.enc`, `.json`, `.tar.gz`, `.sql.gz`)
2. Creates commit with message
3. Creates annotated tag
4. Pushes to remote (if `GIT_AUTO_PUSH=true`)

### Examples

```bash
source lib/git.sh

# Check git availability
git_available "." || echo "Not a git repo"

# Backup with git
git_backup_full "." "backup: my-app 2026-07-27" "backup-20260727"
```

---

## github.sh

GitHub CLI (`gh`) integration.

### Functions

| Function | Description |
|----------|-------------|
| `github_available` | Check if `gh` CLI is installed and authenticated |
| `github_create_repo <name> <visibility>` | Create a new GitHub repository |
| `github_add_remote <dir> <url>` | Add GitHub remote to repository |

### Examples

```bash
source lib/github.sh

# Create repository
if github_available; then
    repo_url=$(github_create_repo "my-backup" "private")
    github_add_remote "." "$repo_url"
fi
```

---

## archive.sh

Archive creation and extraction.

### Functions

| Function | Description |
|----------|-------------|
| `create_tar <output> <base_dir> <dirs...>` | Create tar.gz archive |
| `extract_tar <archive> <output_dir>` | Extract tar.gz archive |
| `detect_upload_dirs <dir>` | Detect common upload directories |

### Detected Upload Directories

The `detect_upload_dirs` function scans for:

- `storage/app`
- `storage/app/public`
- `public/storage`
- `public/uploads`
- `uploads`
- `images`
- `media`
- `assets`

### Examples

```bash
source lib/archive.sh

# Create archive
create_tar "/tmp/uploads.tar.gz" "." "storage/app" "public/uploads"

# Extract archive
extract_tar "/tmp/uploads.tar.gz" "/tmp/extracted"

# Detect uploads
detect_upload_dirs "." | while read dir; do
    echo "Found: $dir"
done
```

---

## encrypt.sh

AES-256-CBC encryption and decryption via OpenSSL.

### Functions

| Function | Description |
|----------|-------------|
| `encrypt_get_password` | Get password from configured source |
| `encrypt_file <input> <output>` | Encrypt file (removes original) |
| `decrypt_file <input> <output>` | Decrypt file |
| `encrypt_verify <file>` | Verify file can be decrypted |
| `encryption_enabled` | Check if encryption is enabled |

### Encryption Details

- Algorithm: AES-256-CBC
- Key derivation: PBKDF2 with 100,000 iterations
- Salt: Random (generated per encryption)

### Password Sources

| Source | Description |
|--------|-------------|
| `env` | Read from `BACKUP_PASSWORD` environment variable |
| `file` | Read from file specified by `ENCRYPTION_PASSWORD_FILE` |
| `prompt` | Interactive password prompt (not suitable for cron) |

### Examples

```bash
source lib/encrypt.sh

# Encrypt file
encrypt_file "backup.tar.gz" "backup.tar.gz.enc"

# Decrypt file
decrypt_file "backup.tar.gz.enc" "backup.tar.gz"

# Verify encryption
encrypt_verify "backup.tar.gz.enc" && echo "OK"
```

---

## notifications.sh

Multi-channel notification system.

### Functions

| Function | Description |
|----------|-------------|
| `notify_send <title> <message> [status]` | Send to all configured channels |
| `notify_success <title> <message>` | Send success notification |
| `notify_failure <title> <message>` | Send failure notification |
| `notify_telegram <title> <message> <status>` | Send to Telegram |
| `notify_slack <title> <message> <status>` | Send to Slack |
| `notify_discord <title> <message> <status>` | Send to Discord |
| `notify_email <title> <message> <status>` | Send via email |
| `notify_webhook <title> <message> <status>` | Send to custom webhook |

### Notification Channels

All channels run in parallel for fast delivery.

**Telegram:** Uses Bot API with Markdown formatting.

**Slack:** Uses incoming webhooks with attachment colors.

**Discord:** Uses webhooks with embed objects.

**Email:** Uses `mail` or `sendmail` commands.

**Webhook:** Custom HTTP endpoint with JSON payload.

### Status Values

| Value | Telegram | Slack | Discord |
|-------|----------|-------|---------|
| `success` | ✅ | Green (#36a64f) | Green (3066993) |
| `failure` | ❌ | Red (#cc0000) | Red (15158332) |
| `info` | ℹ️ | Blue (#439FE0) | Blue (3447003) |

### Examples

```bash
source lib/notifications.sh

# Send notification
NOTIFICATIONS_ENABLED=true
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/..."

notify_success "Backup Complete" "Database: mysql, Size: 15M"
notify_failure "Backup Failed" "Error: Connection refused"
```
