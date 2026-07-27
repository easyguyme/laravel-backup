# laravel-backup

A production-ready command line backup utility for Laravel projects. Written entirely in Bash.

## Features

- **Database backups** — MySQL, MariaDB, PostgreSQL, SQLite
- **AES-256 encryption** — Encrypt backups with OpenSSL
- **Upload detection** — Automatically finds upload directories
- **Git integration** — Auto-commit, tag, and push backups
- **GitHub integration** — Create repos and releases via `gh` CLI
- **Notifications** — Telegram, Slack, Discord, Email, Webhooks
- **Scheduling** — Cron and systemd timer setup
- **Manifest** — Detailed metadata for every backup
- **Cross-platform** — Ubuntu, Debian, Rocky, Alma, CentOS Stream, macOS, WSL

## Quick Start

```bash
# Install
./install.sh

# Initialize in your Laravel project
cd /path/to/your/laravel/project
laravel-backup init

# Create your first backup
laravel-backup backup
```

## Commands

| Command | Description |
|---------|-------------|
| `init` | Initialize laravel-backup in a project |
| `backup` | Create a backup |
| `restore` | Restore from backup |
| `verify` | Verify backup integrity |
| `cleanup` | Remove old backups |
| `status` | Show project and backup status |
| `schedule` | Set up automated backups |
| `update` | Update laravel-backup |

## Installation

### From Source

```bash
git clone https://github.com/your-org/laravel-backup.git
cd laravel-backup
chmod +x install.sh
./install.sh
```

### Manual

```bash
chmod +x laravel-backup
sudo cp laravel-backup /usr/local/bin/
sudo cp -r lib /usr/local/lib/laravel-backup/
sudo cp -r commands /usr/local/lib/laravel-backup/
```

## Usage

### Initialize

```bash
laravel-backup init
```

This will:
- Detect your Laravel project
- Create `backup.conf` configuration
- Create `backups/` directory
- Generate `restore.sh`
- Update `.gitignore`

### Backup

```bash
laravel-backup backup
```

Options:
- `--dry-run` — Simulate without changes
- `--no-encrypt` — Skip encryption
- `--no-git` — Skip git operations
- `--no-db` — Skip database dump
- `--no-uploads` — Skip upload archiving
- `--config <file>` — Use specific config

### Restore

```bash
# Restore latest backup
laravel-backup restore

# Restore specific backup
laravel-backup restore ./backups/project_20260727_120000.tar.gz.enc
```

### Verify

```bash
laravel-backup verify
laravel-backup verify --all
```

### Cleanup

```bash
# Keep 5 most recent backups
laravel-backup cleanup --retain 5

# Remove backups older than 30 days
laravel-backup cleanup --older-than 30

# Preview what would be deleted
laravel-backup cleanup --dry-run
```

### Schedule

```bash
# Daily backups at random hour
laravel-backup schedule --frequency daily

# Weekly backups
laravel-backup schedule --frequency weekly

# Custom cron expression
laravel-backup schedule --cron "0 */6 * * *"

# Using systemd timer
laravel-backup schedule --systemd --frequency daily
```

### Status

```bash
laravel-backup status
```

Shows: project info, database type, git status, backup count, last backup time.

## Configuration

Edit `backup.conf` in your project root:

```bash
# Retention
RETENTION_COUNT=10
RETENTION_DAYS=30

# Encryption
ENCRYPTION_ENABLED=true
ENCRYPTION_PASSWORD_SOURCE=env  # env, file, or prompt

# Database (auto-detected from .env if empty)
DATABASE_TYPE=""
DATABASE_HOST=127.0.0.1
DATABASE_NAME=""

# Git
GIT_AUTO_COMMIT=true
GIT_AUTO_TAG=true
GIT_AUTO_PUSH=false

# Notifications
NOTIFICATIONS_ENABLED=false
SLACK_WEBHOOK_URL=""
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""
```

### Environment Variables

Set your backup password:

```bash
# Option 1: Environment variable (recommended)
export BACKUP_PASSWORD="your-secure-password"

# Option 2: Password file
echo "your-secure-password" > /path/to/password-file
# Set ENCRYPTION_PASSWORD_SOURCE=file
# Set ENCRYPTION_PASSWORD_FILE=/path/to/password-file
```

## Backup Structure

Each backup creates:

```
backups/
├── project_20260727_120000.sql.gz.enc      # Database dump (encrypted)
├── project_20260727_120000.uploads.tar.gz.enc  # Uploads (encrypted)
└── project_20260727_120000.manifest.json   # Metadata
```

### Manifest

```json
{
  "name": "my-laravel-app",
  "date": "2026-07-27T12:00:00Z",
  "laravel_version": "11.0",
  "php_version": "8.3.0",
  "database": {
    "type": "mysql",
    "name": "my_database",
    "size": "24576"
  },
  "checksum": "abc123..."
}
```

## Security

- AES-256-CBC encryption via OpenSSL
- PBKDF2 key derivation (100,000 iterations)
- Passwords never stored in source code
- Shell input sanitized
- Path traversal prevention
- No `eval` usage
- All variables quoted

## Notifications

### Telegram

```bash
TELEGRAM_BOT_TOKEN="your-bot-token"
TELEGRAM_CHAT_ID="your-chat-id"
```

### Slack

```bash
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/..."
```

### Discord

```bash
DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/..."
```

### Email

```bash
EMAIL_TO="you@example.com"
EMAIL_FROM="backup@example.com"
```

### Webhook

```bash
WEBHOOK_URL="https://your-api.com/webhook"
WEBHOOK_METHOD="POST"
```

## Requirements

### Required

- Bash 4.0+
- OpenSSL
- tar
- gzip

### Optional

- git (for git integration)
- gh (for GitHub integration)
- jq (for JSON processing)
- mysql/mysqldump (for MySQL backups)
- psql/pg_dump (for PostgreSQL backups)
- sqlite3 (for SQLite backups)
- curl (for notifications)
- mail/sendmail (for email notifications)

## Platform Support

| Platform | Status |
|----------|--------|
| Ubuntu | Supported |
| Debian | Supported |
| Rocky Linux | Supported |
| AlmaLinux | Supported |
| CentOS Stream | Supported |
| macOS | Supported |
| WSL | Supported |

## Uninstall

```bash
./uninstall.sh
# or
./uninstall.sh --yes  # Skip confirmation
```

## Development

### Run Tests

```bash
chmod +x tests/run_tests.sh
./tests/run_tests.sh
```

### Project Structure

```
laravel-backup/
├── laravel-backup          # Main CLI router
├── commands/               # Subcommands
│   ├── backup.sh
│   ├── restore.sh
│   ├── init.sh
│   ├── verify.sh
│   ├── cleanup.sh
│   ├── status.sh
│   ├── schedule.sh
│   └── update.sh
├── lib/                    # Libraries
│   ├── colours.sh
│   ├── logging.sh
│   ├── env.sh
│   ├── helpers.sh
│   ├── validator.sh
│   ├── config.sh
│   ├── lock.sh
│   ├── mysql.sh
│   ├── postgres.sh
│   ├── sqlite.sh
│   ├── git.sh
│   ├── github.sh
│   ├── archive.sh
│   ├── encrypt.sh
│   └── notifications.sh
├── templates/              # Templates
│   ├── restore.sh
│   ├── gitignore
│   └── manifest.json
├── tests/                  # Tests
│   └── run_tests.sh
├── docs/                   # Documentation
├── examples/               # Example configurations
├── install.sh              # Installer
├── uninstall.sh            # Uninstaller
├── backup.conf.example     # Example config
├── VERSION                 # Version number
├── CHANGELOG.md            # Changelog
└── LICENSE                 # MIT License
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `./tests/run_tests.sh`
5. Submit a pull request

## License

MIT License. See [LICENSE](LICENSE) for details.
