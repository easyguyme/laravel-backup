# How-To: Restore from Backup

This guide covers restoring your Laravel project from a backup created by laravel-backup.

## Prerequisites

- laravel-backup installed
- A backup file in `backups/` directory
- Database server running
- `BACKUP_PASSWORD` environment variable set (if encrypted)

## Restore Latest Backup

```bash
laravel-backup restore
```

This automatically finds and restores the most recent backup.

## Restore Specific Backup

```bash
laravel-backup restore ./backups/project_20260727_120000.tar.gz.enc
```

## List Available Backups

```bash
ls -la backups/*.tar.gz.enc backups/*.tar.gz
```

## What Gets Restored

### 1. Database

- MySQL/MariaDB: Uses `mysql` command
- PostgreSQL: Uses `psql` command
- SQLite: Replaces database file

### 2. Upload Directories

These directories are restored:

- `storage/app`
- `storage/app/public`
- `public/storage`
- `public/uploads`
- `uploads`
- `images`
- `media`

### 3. Post-Restore Tasks

By default, these commands run automatically:

```bash
# Install dependencies
composer install --no-dev --optimize-autoloader

# Create storage link
php artisan storage:link

# Clear cache
php artisan optimize:clear

# Run migrations
php artisan migrate --force
```

## Skip Specific Steps

### Skip Database Restore

```bash
laravel-backup restore --no-db
```

### Skip Upload Restore

```bash
laravel-backup restore --no-uploads
```

### Skip Composer Install

```bash
laravel-backup restore --no-composer
```

### Skip Artisan Commands

```bash
laravel-backup restore --no-artisan
```

### Skip All Post-Restore Tasks

```bash
laravel-backup restore --no-composer --no-artisan
```

## Restore Process

1. **Find backup file** - Uses latest if not specified
2. **Decrypt** - Decrypts if encrypted (requires `BACKUP_PASSWORD`)
3. **Extract** - Extracts tar.gz archive
4. **Restore database** - Imports SQL dump
5. **Restore uploads** - Copies upload directories
6. **Post-restore tasks** - Runs composer and artisan commands

## Troubleshooting

### "Decryption failed" Error

Ensure `BACKUP_PASSWORD` matches the password used during backup:

```bash
export BACKUP_PASSWORD="your-password"
```

### "No backup files found" Error

Check the backups directory:

```bash
ls -la backups/
```

Ensure backup files exist and have correct extensions (`.tar.gz.enc` or `.tar.gz`).

### Database Connection Error

Verify database credentials in `.env`:

```bash
cat .env | grep DB_
```

Test connection:

```bash
# MySQL
mysql -h 127.0.0.1 -u username -p database_name

# PostgreSQL
psql -h 127.0.0.1 -U username -d database_name
```

### Permission Denied

Check directory permissions:

```bash
chmod -R 755 storage/
chmod -R 755 bootstrap/cache/
```

### Composer Install Fails

Check PHP and composer:

```bash
php -v
composer --version
```

Run manually:

```bash
composer install --no-dev --optimize-autoloader
```

### Artisan Commands Fail

Check PHP:

```bash
php artisan --version
```

Run commands manually:

```bash
php artisan storage:link
php artisan optimize:clear
php artisan migrate --force
```

### Upload Directories Not Restored

Check if the backup contains upload files:

```bash
tar -tzf backups/backup-file.tar.gz
```

Verify the upload directories exist in the extracted contents.

## Standalone Restore Script

A standalone `restore.sh` script is generated during `init`. This can be used without laravel-backup installed:

```bash
./restore.sh ./backups/backup-file.tar.gz.enc
```

The standalone script requires:
- `openssl` (for decryption)
- `tar` (for extraction)
- `mysql`/`psql`/`sqlite3` (for database restore)
