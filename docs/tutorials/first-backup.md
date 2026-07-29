# Creating Your First Backup

This tutorial walks you through creating your first backup with laravel-backup, from initialization to verification.

## Prerequisites

- laravel-backup installed
- A Laravel project with a database

## Step 1: Navigate to Your Laravel Project

```bash
cd /path/to/your/laravel/project
```

## Step 2: Initialize laravel-backup

```bash
laravel-backup init
```

This creates:
- `backup.conf` - Configuration file
- `backups/` - Backup directory
- `restore.sh` - Standalone restore script
- Updates `.gitignore`

## Step 3: Configure Encryption

Set your encryption password:

```bash
export BACKUP_PASSWORD="your-secure-password"
```

For production, use a password file:

```bash
echo "your-secure-password" > /path/to/backup-password
chmod 600 /path/to/backup-password
```

Then update `backup.conf`:

```bash
ENCRYPTION_PASSWORD_SOURCE=file
ENCRYPTION_PASSWORD_FILE=/path/to/backup-password
```

## Step 4: Run a Dry Run

Before creating a real backup, simulate it:

```bash
laravel-backup backup --dry-run
```

This shows what would happen without making any changes.

## Step 5: Create the Backup

```bash
laravel-backup backup
```

The backup pipeline:
1. Loads `.env` configuration
2. Detects database type (MySQL/PostgreSQL/SQLite)
3. Dumps database to compressed SQL file
4. Encrypts the database dump
5. Detects and archives upload directories
6. Encrypts the upload archive
7. Generates manifest with metadata
8. Copies files to `backups/` directory
9. Commits to git (if enabled)
10. Creates annotated tag
11. Sends notifications (if configured)

## Step 6: Verify the Backup

```bash
laravel-backup verify
```

This checks:
- File integrity
- Decryption works
- SHA-256 checksums
- Archive extraction
- Manifest validity
- Git integrity

## Step 7: Check Status

```bash
laravel-backup status
```

Shows project info, database type, git status, and backup count.

## Next Steps

- [Set up automated backups](../how-to/schedule-backups.md)
- [Configure notifications](../how-to/configure-notifications.md)
- [Restore from backup](../how-to/restore-backup.md)
