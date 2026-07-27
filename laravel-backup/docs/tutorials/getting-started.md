# Getting Started Tutorial

This tutorial walks you through installing laravel-backup, initializing it in your Laravel project, and creating your first backup.

## Prerequisites

- Bash 4.0 or higher
- OpenSSL (for encryption)
- tar and gzip
- A Laravel project

### Optional Requirements

- `git` (for git integration)
- `gh` (for GitHub integration)
- `mysql`/`mysqldump` (for MySQL backups)
- `psql`/`pg_dump` (for PostgreSQL backups)
- `sqlite3` (for SQLite backups)
- `curl` (for notifications)

## Step 1: Install laravel-backup

Clone the repository and run the installer:

```bash
git clone https://github.com/your-org/laravel-backup.git
cd laravel-backup
chmod +x install.sh
./install.sh
```

The installer copies files to `/usr/local/bin` and `/usr/local/lib/laravel-backup/` by default. For a user-level install (no sudo needed):

```bash
./install.sh --user
```

This installs to `~/.local/bin` and `~/.local/lib/laravel-backup/`.

### Verify Installation

```bash
laravel-backup --version
# Output: laravel-backup v1.0.0
```

## Step 2: Navigate to Your Laravel Project

```bash
cd /path/to/your/laravel/project
```

Make sure you're in the project root (where `artisan` and `composer.json` are located).

## Step 3: Initialize laravel-backup

```bash
laravel-backup init
```

This command:

1. **Detects your Laravel project** - Verifies `artisan`, `composer.json`, and `app/` exist
2. **Detects Git** - Checks if you're in a git repository
3. **Creates `backup.conf`** - Copies the example configuration
4. **Creates `backups/` directory** - Where backups will be stored
5. **Generates `restore.sh`** - Standalone restore script
6. **Updates `.gitignore`** - Excludes backup files from version control
7. **Verifies permissions** - Checks write access

### What You'll See

```
laravel-backup Init
───────────────────

Checking Project
  ✓ Laravel project detected
    Project: my-laravel-app
    Laravel: 11.0

  ✓ Git repository detected
    Branch: main
    Remote: origin

Creating Configuration
  ✓ Created configuration file: backup.conf

  ✓ Created: backups/

Generating Restore Script
  ✓ Created restore.sh

Updating .gitignore
  ✓ Updated .gitignore

Verifying Permissions
  ✓ All permissions OK

Setup Complete
  Edit backup.conf to configure your backup settings
  Run 'laravel-backup backup' to create your first backup
```

## Step 4: Configure Your Backup

Edit `backup.conf` in your project root:

```bash
# Set encryption password via environment variable
export BACKUP_PASSWORD="your-secure-password-here"
```

Or configure the password file approach:

```bash
# Create a password file
echo "your-secure-password-here" > /path/to/backup-password
chmod 600 /path/to/backup-password

# Update backup.conf
ENCRYPTION_PASSWORD_SOURCE=file
ENCRYPTION_PASSWORD_FILE=/path/to/backup-password
```

### Key Configuration Options

```bash
# Retention: keep 10 most recent backups, delete after 30 days
RETENTION_COUNT=10
RETENTION_DAYS=30

# Encryption: enabled by default
ENCRYPTION_ENABLED=true
ENCRYPTION_PASSWORD_SOURCE=env

# Git: auto-commit backups
GIT_AUTO_COMMIT=true
GIT_AUTO_TAG=true
GIT_AUTO_PUSH=false
```

## Step 5: Create Your First Backup

```bash
laravel-backup backup
```

### What Happens

The backup command runs a 14-step pipeline:

1. **Acquires lock** - Prevents concurrent runs
2. **Loads .env** - Reads your Laravel environment
3. **Detects database** - Identifies MySQL/PostgreSQL/SQLite
4. **Dumps database** - Creates compressed SQL dump
5. **Encrypts dump** - AES-256-CBC encryption
6. **Detects uploads** - Finds upload directories
7. **Archives uploads** - Creates tar.gz of uploads
8. **Encrypts archive** - AES-256-CBC encryption
9. **Generates manifest** - Creates JSON metadata
10. **Finalizes** - Copies files to `backups/`
11. **Git commit** - Commits backup files
12. **Git tag** - Creates annotated tag
13. **Git push** - Pushes to remote (if enabled)
14. **Notifies** - Sends notifications (if configured)

### Output

```
Starting Backup
───────────────
  Project: my-laravel-app
  Time: 2026-07-27 12:00:00

Loading Environment
  ✓ Loaded .env

Detecting Database
  Database type: mysql

Dumping Database
  ✓ Database dumped: 2.3M

Encrypting Database Dump
  ✓ Encrypted: database.sql.gz.enc (2.4M)

Detecting Upload Folders
  Upload directories:
    - storage/app
    - public/uploads

Archiving Upload Folders
  ✓ Archive created: uploads.tar.gz (15.2M)

Encrypting Upload Archive
  ✓ Encrypted: uploads.tar.gz.enc (15.3M)

Generating Manifest
  ✓ Manifest generated

Finalizing Backup
  ✓ Backup files saved to: backups/

Git Operations
  ✓ Committed: backup: my-laravel-app 2026-07-27 12:00:00
  ✓ Tagged: backup-my-laravel-app_20260727_120000

Backup Complete
───────────────
  Project: my-laravel-app
  Database: mysql
  Duration: 45s
  Files: my-laravel-app_20260727_120000
```

### Backup Files Created

```
backups/
├── my-laravel-app_20260727_120000.sql.gz.enc      # Encrypted database
├── my-laravel-app_20260727_120000.uploads.tar.gz.enc  # Encrypted uploads
└── my-laravel-app_20260727_120000.manifest.json   # Metadata
```

## Step 6: Verify Your Backup

```bash
laravel-backup verify
```

This checks:

- File exists and is readable
- File can be decrypted (correct password)
- SHA-256 checksum generation
- Archive can be extracted
- Manifest is valid
- Git repository integrity

### Output

```
Verifying: my-laravel-app_20260727_120000.tar.gz.enc
──────────────────────────────────────────────────────
  Size: 17.7M
  Type: Encrypted backup
  ✓ Encryption: File is decryptable
  SHA-256: abc123...
  ✓ Manifest: Found
  ✓ Database dump: Found
  ✓ Git integrity: OK

Verification passed
```

## Step 7: Set Up Automated Backups

Schedule daily backups with cron:

```bash
laravel-backup schedule --frequency daily
```

Or use systemd timers (Linux):

```bash
laravel-backup schedule --systemd --frequency daily
```

### View Schedule

```bash
laravel-backup schedule --show
```

### Remove Schedule

```bash
laravel-backup schedule --remove
```

## Step 8: Check Status

```bash
laravel-backup status
```

### Output

```
laravel-backup Status
─────────────────────
  Project: my-laravel-app
  Path: /path/to/your/laravel/project
  Laravel: 11.0
  PHP: 8.3.0
  OS: macOS 15.0

  Database: mysql

  Repository: Yes
  Branch: main
  Commit: abc1234
  Remote: origin
  Pending: 0 change(s)
  Latest Tag: backup-my-laravel-app_20260727_120000

  Backup Count: 1
  Last Backup: 2026-07-27 12:00
  Backup Dir: backups
  Config: backup.conf
```

## Next Steps

- [Configure notifications](../how-to/configure-notifications.md) to get alerts
- [Set up encryption](../how-to/manage-encryption.md) for secure backups
- [Restore from backup](../how-to/restore-backup.md) when needed
- [Clean up old backups](../how-to/cleanup-backups.md) to save space

## Troubleshooting

### "Not a Laravel project" Error

Make sure you're in the project root where `artisan` and `composer.json` exist.

### "BACKUP_PASSWORD not set" Error

Set the environment variable:

```bash
export BACKUP_PASSWORD="your-password"
```

Or configure `ENCRYPTION_PASSWORD_SOURCE=file` and set `ENCRYPTION_PASSWORD_FILE`.

### "Permission denied" Error

Check write permissions:

```bash
ls -la backup.conf backups/
chmod 644 backup.conf
chmod 755 backups/
```

### Backup Fails with Database Error

Test your database connection:

```bash
# MySQL
mysql -h 127.0.0.1 -u username -p database_name

# PostgreSQL
psql -h 127.0.0.1 -U username -d database_name

# SQLite
sqlite3 database/database.sqlite ".tables"
```
