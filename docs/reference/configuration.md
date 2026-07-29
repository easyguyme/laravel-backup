# Configuration Reference

All configuration is managed through `backup.conf` in your project root. Copy `backup.conf.example` to get started.

## Configuration File Location

The configuration is loaded in this order (first found wins):

1. Path specified via `--config` flag
2. `backup.conf` in the current directory
3. `backup.conf` next to the laravel-backup script
4. Built-in defaults

## Configuration Options

### Retention

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `RETENTION_COUNT` | integer | `10` | Number of backups to keep (0 = keep all) |
| `RETENTION_DAYS` | integer | `30` | Days to keep backups (0 = no age-based cleanup) |

### Encryption

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `ENCRYPTION_ENABLED` | boolean | `true` | Enable AES-256-CBC encryption |
| `ENCRYPTION_PASSWORD_SOURCE` | string | `env` | Password source: `env`, `file`, or `prompt` |
| `ENCRYPTION_PASSWORD_FILE` | string | (empty) | Path to password file (when source is `file`) |

### Database

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `DATABASE_TYPE` | string | (auto) | Database type override (auto-detected from `.env` if empty) |
| `DATABASE_HOST` | string | `127.0.0.1` | Database host |
| `DATABASE_PORT` | string | (empty) | Database port (uses driver default if empty) |
| `DATABASE_NAME` | string | (empty) | Database name (auto-detected from `.env` if empty) |
| `DATABASE_USER` | string | (empty) | Database user (auto-detected from `.env` if empty) |
| `DATABASE_PASSWORD` | string | (empty) | Database password (auto-detected from `.env` if empty) |
| `SQLITE_DATABASE_PATH` | string | (empty) | SQLite database path (relative to project root) |

### Paths

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `BACKUP_DIR` | string | `backups` | Backup output directory (relative to project root) |
| `TEMP_DIR` | string | `/tmp/laravel-backup` | Temp directory for intermediate files |

### Compression

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `COMPRESSION_LEVEL` | integer | `6` | gzip compression level (1-9, where 9 is maximum) |

### Upload Folders

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `EXTRA_UPLOAD_DIRS` | string | (empty) | Additional upload directories to include (space-separated) |
| `EXCLUDE_DIRS` | string | `.git node_modules vendor .env` | Directories to exclude from archives (space-separated) |

### Git

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `GIT_AUTO_COMMIT` | boolean | `true` | Auto-commit backups to git |
| `GIT_AUTO_TAG` | boolean | `true` | Auto-create annotated tags for backups |
| `GIT_TAG_PREFIX` | string | `backup` | Tag name prefix |
| `GIT_AUTO_PUSH` | boolean | `false` | Auto-push to remote after commit |
| `GIT_BACKUP_BRANCH` | string | (empty) | Branch to commit backups to (empty = current branch) |

### Notifications

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `NOTIFICATIONS_ENABLED` | boolean | `false` | Enable notification channels |
| `TELEGRAM_BOT_TOKEN` | string | (empty) | Telegram bot API token |
| `TELEGRAM_CHAT_ID` | string | (empty) | Telegram chat ID |
| `SLACK_WEBHOOK_URL` | string | (empty) | Slack incoming webhook URL |
| `DISCORD_WEBHOOK_URL` | string | (empty) | Discord webhook URL |
| `EMAIL_TO` | string | (empty) | Recipient email address |
| `EMAIL_FROM` | string | (empty) | Sender email address |
| `EMAIL_SUBJECT` | string | `[laravel-backup] Backup Report` | Email subject prefix |
| `WEBHOOK_URL` | string | (empty) | Custom webhook URL |
| `WEBHOOK_METHOD` | string | `POST` | HTTP method for webhook |

### Logging

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `LOG_LEVEL` | string | `INFO` | Log level: `DEBUG`, `INFO`, `WARNING`, `ERROR`, `SUCCESS` |
| `LOG_FILE` | string | `backups/backup.log` | Log file path (relative to project root or absolute) |

### Misc

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `VERBOSE` | boolean | `false` | Enable verbose output |
| `DRY_RUN` | boolean | `false` | Dry run mode (simulate without changes) |

## Environment Variables

Some values can be set via environment variables instead of the config file:

| Variable | Description |
|----------|-------------|
| `BACKUP_PASSWORD` | Encryption password (when `ENCRYPTION_PASSWORD_SOURCE=env`) |

## Example Configuration

```bash
# laravel-backup configuration

# Retention
RETENTION_COUNT=10
RETENTION_DAYS=30

# Encryption
ENCRYPTION_ENABLED=true
ENCRYPTION_PASSWORD_SOURCE=env

# Database (auto-detected from .env if empty)
DATABASE_TYPE=""
DATABASE_HOST=127.0.0.1
DATABASE_NAME=""

# Paths
BACKUP_DIR=backups
TEMP_DIR=/tmp/laravel-backup

# Compression
COMPRESSION_LEVEL=6

# Git
GIT_AUTO_COMMIT=true
GIT_AUTO_TAG=true
GIT_AUTO_PUSH=false

# Notifications
NOTIFICATIONS_ENABLED=false
SLACK_WEBHOOK_URL=""

# Logging
LOG_LEVEL=INFO
LOG_FILE=backups/backup.log
```

## Config Commands

View current configuration:

```bash
laravel-backup status
```

The `status` command displays key configuration values and project information.
