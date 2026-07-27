# Commands Reference

## Global Options

| Option | Description |
|--------|-------------|
| `-h`, `--help` | Show help message |
| `-v`, `--version` | Show version |
| `--verbose` | Enable verbose output |

## init

Initialize laravel-backup in a Laravel project.

```bash
laravel-backup init [options]
```

### Options

| Option | Description |
|--------|-------------|
| `-h`, `--help` | Show help message |
| `--force` | Overwrite existing configuration |
| `--github` | Create GitHub repository |
| `--private` | Make GitHub repo private (default) |
| `--public` | Make GitHub repo public |

### What It Does

1. Detects Laravel project (checks for `artisan`, `composer.json`, `app/` directory)
2. Detects Git repository
3. Creates `backup.conf` from example template
4. Creates `backups/` directory
5. Generates `restore.sh` standalone script
6. Updates `.gitignore` with backup exclusions
7. Verifies write permissions
8. Optionally creates GitHub repository (with `--github`)

### Examples

```bash
# Basic initialization
laravel-backup init

# Force overwrite existing config
laravel-backup init --force

# Initialize and create GitHub repo
laravel-backup init --github --private
```

---

## backup

Create a backup of the project.

```bash
laravel-backup backup [options]
```

### Options

| Option | Description |
|--------|-------------|
| `-h`, `--help` | Show help message |
| `-n`, `--dry-run` | Simulate backup without making changes |
| `--no-encrypt` | Skip encryption step |
| `--no-git` | Skip git operations |
| `--no-db` | Skip database dump |
| `--no-uploads` | Skip upload folder archiving |
| `--verbose` | Enable verbose output |
| `--config <file>` | Use specific configuration file |

### Backup Pipeline

The backup command executes these steps in order:

1. **Lock acquisition** - Prevents concurrent backup runs
2. **Load .env** - Reads Laravel environment file
3. **Detect database** - Identifies MySQL/PostgreSQL/SQLite from `.env`
4. **Dump database** - Creates compressed SQL dump
5. **Encrypt database dump** - AES-256-CBC encryption (if enabled)
6. **Detect upload folders** - Scans for common upload directories
7. **Archive uploads** - Creates tar.gz of upload directories
8. **Encrypt upload archive** - AES-256-CBC encryption (if enabled)
9. **Generate manifest** - Creates JSON metadata file
10. **Finalize** - Copies files to backup directory
11. **Git commit** - Stages and commits backup files
12. **Git tag** - Creates annotated tag
13. **Git push** - Pushes to remote (if enabled)
14. **Notify** - Sends notifications via configured channels

### Output Files

Each backup creates up to 4 files:

```
backups/
├── project_YYYYMMDD_HHMMSS.sql.gz         # Database dump (unencrypted)
├── project_YYYYMMDD_HHMMSS.sql.gz.enc     # Database dump (encrypted)
├── project_YYYYMMDD_HHMMSS.uploads.tar.gz         # Uploads (unencrypted)
├── project_YYYYMMDD_HHMMSS.uploads.tar.gz.enc     # Uploads (encrypted)
└── project_YYYYMMDD_HHMMSS.manifest.json          # Metadata
```

### Examples

```bash
# Full backup
laravel-backup backup

# Dry run (simulate)
laravel-backup backup --dry-run

# Backup without encryption
laravel-backup backup --no-encrypt

# Backup database only (skip uploads)
laravel-backup backup --no-uploads

# Use custom config file
laravel-backup backup --config /path/to/backup.conf
```

---

## restore

Restore a project from backup.

```bash
laravel-backup restore [options] [backup-file]
```

### Options

| Option | Description |
|--------|-------------|
| `-h`, `--help` | Show help message |
| `--no-db` | Skip database restore |
| `--no-uploads` | Skip upload restore |
| `--no-composer` | Skip composer install |
| `--no-artisan` | Skip artisan commands |
| `--config <file>` | Use specific config file |

### Restore Pipeline

1. Find backup file (latest if not specified)
2. Decrypt backup (if encrypted)
3. Extract archive
4. Restore database (MySQL/PostgreSQL/SQLite)
5. Restore upload directories
6. Run `composer install --no-dev`
7. Run `php artisan storage:link`
8. Run `php artisan optimize:clear`
9. Run `php artisan migrate --force`

### Examples

```bash
# Restore latest backup
laravel-backup restore

# Restore specific backup
laravel-backup restore ./backups/project_20260727_120000.tar.gz.enc

# Restore without database
laravel-backup restore --no-db

# Restore without running composer/artisan
laravel-backup restore --no-composer --no-artisan
```

---

## verify

Verify backup integrity.

```bash
laravel-backup verify [options] [backup-file]
```

### Options

| Option | Description |
|--------|-------------|
| `-h`, `--help` | Show help message |
| `--all` | Verify all backups |
| `--verbose` | Show detailed output |

### Verification Checks

- File exists and is readable
- File size check
- Encryption verification (can decrypt with current password)
- SHA-256 checksum generation
- Archive extraction test
- Manifest validation
- Git repository integrity (`git fsck`)

### Examples

```bash
# Verify latest backup
laravel-backup verify

# Verify specific backup
laravel-backup verify ./backups/project_20260727_120000.tar.gz.enc

# Verify all backups
laravel-backup verify --all

# Verbose output
laravel-backup verify --verbose
```

---

## cleanup

Remove old backups based on retention policy.

```bash
laravel-backup cleanup [options]
```

### Options

| Option | Description |
|--------|-------------|
| `-h`, `--help` | Show help message |
| `-n`, `--retain <N>` | Number of backups to keep |
| `--older-than <D>` | Remove backups older than D days |
| `--dry-run` | Show what would be deleted |
| `--force` | Skip confirmation |

### Cleanup Strategies

**Count-based:** Keep the N most recent backups, delete older ones.

**Age-based:** Delete backups older than D days.

Both strategies can be combined. When combined, count-based cleanup runs first, then age-based.

### Examples

```bash
# Keep 5 most recent backups
laravel-backup cleanup --retain 5

# Remove backups older than 30 days
laravel-backup cleanup --older-than 30

# Preview what would be deleted
laravel-backup cleanup --dry-run

# Combine strategies
laravel-backup cleanup --retain 5 --older-than 30
```

---

## status

Show project and backup status.

```bash
laravel-backup status
```

### Output

Displays:

- Project name and path
- Laravel version
- PHP version
- Operating system
- Database type
- Git repository status (branch, commit, remote, pending changes)
- Backup count
- Last backup date
- Backup directory
- Configuration file status

---

## schedule

Set up automated backup scheduling.

```bash
laravel-backup schedule [options]
```

### Options

| Option | Description |
|--------|-------------|
| `-h`, `--help` | Show help message |
| `-f`, `--frequency <freq>` | Frequency: `hourly`, `daily`, `weekly`, `monthly` |
| `--cron <expression>` | Custom cron expression |
| `--systemd` | Use systemd timer instead of cron |
| `--remove` | Remove existing schedule |
| `--show` | Show current schedule |

### Scheduling Methods

**Cron (default):** Installs a crontab entry with a `# laravel-backup auto` marker.

**Systemd timer:** Creates user-level systemd service and timer files in `~/.config/systemd/user/`.

### Frequency Presets

| Frequency | Cron Expression |
|-----------|-----------------|
| `hourly` | `0 * * * *` |
| `daily` | `0 <random-hour> * * *` |
| `weekly` | `0 <random-hour> * * 0` |
| `monthly` | `0 <random-hour> 1 * *` |

The hour is randomized (0-5) to avoid thundering herd on shared infrastructure.

### Examples

```bash
# Daily backups with random hour
laravel-backup schedule --frequency daily

# Weekly backups
laravel-backup schedule --frequency weekly

# Custom cron (every 6 hours)
laravel-backup schedule --cron "0 */6 * * *"

# Use systemd timer
laravel-backup schedule --systemd --frequency daily

# View current schedule
laravel-backup schedule --show

# Remove schedule
laravel-backup schedule --remove
```

---

## update

Update laravel-backup to the latest version.

```bash
laravel-backup update [options]
```

### Options

| Option | Description |
|--------|-------------|
| `-h`, `--help` | Show help message |
| `--check` | Check for updates without installing |
| `--from-git` | Update from git repository instead of releases |

### Examples

```bash
# Check for updates
laravel-backup update --check

# Update from GitHub releases
laravel-backup update

# Update from git
laravel-backup update --from-git
```
