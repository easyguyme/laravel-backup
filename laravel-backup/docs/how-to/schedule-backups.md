# How-To: Schedule Backups

This guide covers setting up automated backups with cron or systemd.

## Cron Scheduling

### Daily Backups

```bash
laravel-backup schedule --frequency daily
```

This installs a crontab entry that runs daily at a random hour (0-5).

### Weekly Backups

```bash
laravel-backup schedule --frequency weekly
```

### Monthly Backups

```bash
laravel-backup schedule --frequency monthly
```

### Hourly Backups

```bash
laravel-backup schedule --frequency hourly
```

### Custom Cron Expression

```bash
laravel-backup schedule --cron "0 */6 * * *"
```

This runs every 6 hours.

### View Current Schedule

```bash
laravel-backup schedule --show
```

### Remove Schedule

```bash
laravel-backup schedule --remove
```

## Systemd Timer Scheduling (Linux)

### Install Systemd Timer

```bash
laravel-backup schedule --systemd --frequency daily
```

This creates:

- `~/.config/systemd/user/laravel-backup.service`
- `~/.config/systemd/user/laravel-backup.timer`

### Check Timer Status

```bash
systemctl --user status laravel-backup.timer
```

### View Timer Schedule

```bash
systemctl --user list-timers laravel-backup.timer
```

### Stop Timer

```bash
systemctl --user stop laravel-backup.timer
```

### Start Timer

```bash
systemctl --user start laravel-backup.timer
```

### Remove Timer

```bash
laravel-backup schedule --remove
```

## Configuration

### Set Encryption Password

For automated backups, use a password file:

```bash
echo "your-secure-password" > /path/to/backup-password
chmod 600 /path/to/backup-password
```

Update `backup.conf`:

```bash
ENCRYPTION_PASSWORD_SOURCE=file
ENCRYPTION_PASSWORD_FILE=/path/to/backup-password
```

### Set Environment Variables

For cron jobs, ensure environment variables are available:

```bash
# Add to crontab
BACKUP_PASSWORD="your-password" 0 * * * * cd /path/to/project && laravel-backup backup
```

Or use a wrapper script:

```bash
#!/bin/bash
export BACKUP_PASSWORD="your-password"
cd /path/to/project
laravel-backup backup
```

### Configure Notifications

Get notified about scheduled backups:

```bash
NOTIFICATIONS_ENABLED=true
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/..."
```

## Best Practices

### Randomized Hour

The `--frequency` option randomizes the hour (0-5) to avoid thundering herd on shared infrastructure.

### Log Rotation

Backups log to `backups/backup.log`. Set up logrotate:

```bash
# /etc/logrotate.d/laravel-backup
/path/to/project/backups/backup.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
}
```

### Disk Space Monitoring

Monitor disk space to prevent backup failures:

```bash
# Check available space
df -h /path/to/project/backups/

# Clean old backups
laravel-backup cleanup --retain 5
```

### Verify Scheduled Backups

Periodically verify backups are working:

```bash
# Check latest backup
laravel-backup verify

# Check status
laravel-backup status
```

## Troubleshooting

### Cron Job Not Running

Check crontab:

```bash
crontab -l | grep laravel-backup
```

Check cron logs:

```bash
# Ubuntu/Debian
grep CRON /var/log/syslog

# CentOS/RHEL
grep CRON /var/log/cron
```

### Systemd Timer Not Running

Check timer status:

```bash
systemctl --user status laravel-backup.timer
systemctl --user list-timers
```

Check service logs:

```bash
journalctl --user -u laravel-backup
```

### Backup Fails Silently

Check log file:

```bash
tail -f backups/backup.log
```

Run manually to see errors:

```bash
laravel-backup backup --verbose
```

### Permission Denied

Ensure the cron user has access:

```bash
# Check cron user
whoami

# Check permissions
ls -la /path/to/project/backups/
```

### Environment Variables Not Available

Cron has a minimal environment. Use a wrapper script or set variables in crontab:

```bash
# In crontab
BACKUP_PASSWORD="your-password" PATH=/usr/local/bin:/usr/bin:/bin 0 * * * * cd /path/to/project && laravel-backup backup
```
