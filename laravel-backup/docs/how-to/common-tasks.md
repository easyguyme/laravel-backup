# How-To Guides

Common tasks and scenarios for using laravel-backup.

## Backup Operations

- [Create a Backup](#create-a-backup)
- [Restore from Backup](#restore-from-backup)
- [Verify Backup Integrity](#verify-backup-integrity)
- [Clean Up Old Backups](#clean-up-old-backups)
- [Schedule Automated Backups](#schedule-automated-backups)

## Configuration

- [Configure Encryption](#configure-encryption)
- [Configure Notifications](#configure-notifications)
- [Configure Git Integration](#configure-git-integration)
- [Configure Database Connections](#configure-database-connections)

## Advanced

- [Use Custom Config Files](#use-custom-config-files)
- [Run Backups Without Specific Steps](#run-backups-without-specific-steps)
- [Troubleshooting](#troubleshooting)

---

## Create a Backup

### Basic Backup

```bash
laravel-backup backup
```

### Dry Run (Simulate)

```bash
laravel-backup backup --dry-run
```

### Skip Encryption

```bash
laravel-backup backup --no-encrypt
```

### Skip Git Operations

```bash
laravel-backup backup --no-git
```

### Skip Database Dump

```bash
laravel-backup backup --no-db
```

### Skip Upload Archiving

```bash
laravel-backup backup --no-uploads
```

### Use Custom Config

```bash
laravel-backup backup --config /path/to/backup.conf
```

---

## Restore from Backup

### Restore Latest Backup

```bash
laravel-backup restore
```

### Restore Specific Backup

```bash
laravel-backup restore ./backups/project_20260727_120000.tar.gz.enc
```

### Skip Database Restore

```bash
laravel-backup restore --no-db
```

### Skip Upload Restore

```bash
laravel-backup restore --no-uploads
```

### Skip Post-Restore Tasks

```bash
laravel-backup restore --no-composer --no-artisan
```

### What Gets Restored

1. Database (MySQL/PostgreSQL/SQLite)
2. Upload directories (storage/app, public/uploads, etc.)
3. Composer dependencies (`composer install --no-dev`)
4. Laravel cache clearing (`php artisan optimize:clear`)
5. Storage link (`php artisan storage:link`)
6. Database migrations (`php artisan migrate --force`)

---

## Verify Backup Integrity

### Verify Latest Backup

```bash
laravel-backup verify
```

### Verify Specific Backup

```bash
laravel-backup verify ./backups/project_20260727_120000.tar.gz.enc
```

### Verify All Backups

```bash
laravel-backup verify --all
```

### Verbose Output

```bash
laravel-backup verify --verbose
```

### Verification Checks

- File exists and is readable
- File can be decrypted (correct password)
- SHA-256 checksum generation
- Archive can be extracted
- Manifest is valid
- Git repository integrity

---

## Clean Up Old Backups

### Keep N Most Recent

```bash
laravel-backup cleanup --retain 5
```

### Remove Old Backups by Age

```bash
laravel-backup cleanup --older-than 30
```

### Combine Strategies

```bash
laravel-backup cleanup --retain 5 --older-than 30
```

### Preview Deletions

```bash
laravel-backup cleanup --dry-run
```

### Skip Confirmation

```bash
laravel-backup cleanup --retain 5 --force
```

---

## Schedule Automated Backups

### Daily Backups (Cron)

```bash
laravel-backup schedule --frequency daily
```

### Weekly Backups (Cron)

```bash
laravel-backup schedule --frequency weekly
```

### Custom Cron Expression

```bash
laravel-backup schedule --cron "0 */6 * * *"
```

### Systemd Timer (Linux)

```bash
laravel-backup schedule --systemd --frequency daily
```

### View Current Schedule

```bash
laravel-backup schedule --show
```

### Remove Schedule

```bash
laravel-backup schedule --remove
```

---

## Configure Encryption

### Using Environment Variable

```bash
export BACKUP_PASSWORD="your-secure-password"
```

### Using Password File

```bash
# Create password file
echo "your-secure-password" > /path/to/backup-password
chmod 600 /path/to/backup-password

# Update backup.conf
ENCRYPTION_PASSWORD_SOURCE=file
ENCRYPTION_PASSWORD_FILE=/path/to/backup-password
```

### Disable Encryption

```bash
ENCRYPTION_ENABLED=false
```

### Encryption Details

- Algorithm: AES-256-CBC
- Key derivation: PBKDF2 with 100,000 iterations
- Salt: Random (generated per encryption)

---

## Configure Notifications

### Telegram

```bash
NOTIFICATIONS_ENABLED=true
TELEGRAM_BOT_TOKEN="your-bot-token"
TELEGRAM_CHAT_ID="your-chat-id"
```

### Slack

```bash
NOTIFICATIONS_ENABLED=true
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/..."
```

### Discord

```bash
NOTIFICATIONS_ENABLED=true
DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/..."
```

### Email

```bash
NOTIFICATIONS_ENABLED=true
EMAIL_TO="you@example.com"
EMAIL_FROM="backup@example.com"
```

### Custom Webhook

```bash
NOTIFICATIONS_ENABLED=true
WEBHOOK_URL="https://your-api.com/webhook"
WEBHOOK_METHOD="POST"
```

### Multiple Channels

All configured channels are notified in parallel. Enable multiple:

```bash
NOTIFICATIONS_ENABLED=true
TELEGRAM_BOT_TOKEN="..."
TELEGRAM_CHAT_ID="..."
SLACK_WEBHOOK_URL="..."
EMAIL_TO="you@example.com"
EMAIL_FROM="backup@example.com"
```

---

## Configure Git Integration

### Enable Auto-Commit

```bash
GIT_AUTO_COMMIT=true
```

### Enable Auto-Tag

```bash
GIT_AUTO_TAG=true
GIT_TAG_PREFIX="backup"
```

### Enable Auto-Push

```bash
GIT_AUTO_PUSH=true
```

### Custom Branch

```bash
GIT_BACKUP_BRANCH="backups"
```

### Disable Git Operations

```bash
GIT_AUTO_COMMIT=false
```

Or use the flag:

```bash
laravel-backup backup --no-git
```

---

## Configure Database Connections

### Auto-Detection

By default, laravel-backup reads your `.env` file and detects the database type:

| `DB_CONNECTION` | Detected Type |
|-----------------|---------------|
| `mysql`, `mariadb` | MySQL |
| `pgsql`, `postgres`, `postgresql` | PostgreSQL |
| `sqlite`, `sqlite3` | SQLite |

### Manual Override

```bash
DATABASE_TYPE=mysql
DATABASE_HOST=127.0.0.1
DATABASE_PORT=3306
DATABASE_NAME=my_database
DATABASE_USER=my_user
DATABASE_PASSWORD=my_password
```

### SQLite Path

```bash
DATABASE_TYPE=sqlite
SQLITE_DATABASE_PATH=database/database.sqlite
```

---

## Use Custom Config Files

### Via Command Flag

```bash
laravel-backup backup --config /path/to/production.conf
```

### Multiple Environments

Create environment-specific configs:

```bash
backup.development.conf
backup.staging.conf
backup.production.conf
```

Use them:

```bash
laravel-backup backup --config backup.production.conf
```

---

## Run Backups Without Specific Steps

### Database Only

```bash
laravel-backup backup --no-uploads
```

### Uploads Only

```bash
laravel-backup backup --no-db
```

### Without Encryption

```bash
laravel-backup backup --no-encrypt
```

### Without Git

```bash
laravel-backup backup --no-git
```

### Combine Flags

```bash
laravel-backup backup --no-db --no-uploads --no-git
```

---

## Troubleshooting

### "Not a Laravel project" Error

Ensure you're in the project root with `artisan` and `composer.json`:

```bash
ls artisan composer.json app/
```

### "BACKUP_PASSWORD not set" Error

Set the environment variable:

```bash
export BACKUP_PASSWORD="your-password"
```

Or configure file-based passwords in `backup.conf`.

### "Permission denied" Error

Check and fix permissions:

```bash
chmod 644 backup.conf
chmod 755 backups/
chmod +x restore.sh
```

### Database Connection Failed

Test your database connection:

```bash
# MySQL
mysql -h 127.0.0.1 -u username -p database_name

# PostgreSQL
psql -h 127.0.0.1 -U username -d database_name

# SQLite
sqlite3 database/database.sqlite ".tables"
```

### Backup Files Not Committed to Git

Check git status:

```bash
git status backups/
```

Ensure `GIT_AUTO_COMMIT=true` in `backup.conf` or run:

```bash
git add backups/
git commit -m "backup: manual commit"
```

### Restore Fails

Check if the backup file is valid:

```bash
laravel-backup verify ./backups/backup-file.tar.gz.enc
```

Ensure you have the correct `BACKUP_PASSWORD` set.

### Notifications Not Working

Test notification channels:

```bash
# Test Slack
curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"Test message"}' \
  https://hooks.slack.com/services/...

# Test Telegram
curl -X POST "https://api.telegram.org/bot<TOKEN>/sendMessage" \
  -d "chat_id=<CHAT_ID>&text=Test message"
```

### Disk Space Issues

Check available space:

```bash
df -h backups/
```

Clean up old backups:

```bash
laravel-backup cleanup --retain 5
```

### Log Files

Check logs for errors:

```bash
tail -f backups/backup.log
```

Set debug logging:

```bash
LOG_LEVEL=DEBUG
laravel-backup backup --verbose
```
