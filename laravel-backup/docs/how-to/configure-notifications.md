# How-To: Configure Notifications

This guide covers setting up notifications for backup events.

## Overview

laravel-backup supports multiple notification channels:

- **Telegram** - Bot API with Markdown formatting
- **Slack** - Incoming webhooks with attachment colors
- **Discord** - Webhooks with embed objects
- **Email** - Using `mail` or `sendmail` commands
- **Webhook** - Custom HTTP endpoint

All configured channels are notified in parallel for fast delivery.

## Enable Notifications

```bash
NOTIFICATIONS_ENABLED=true
```

## Telegram

### Create a Bot

1. Message [@BotFather](https://t.me/BotFather) on Telegram
2. Create a new bot with `/newbot`
3. Get the bot token
4. Get your chat ID (message the bot, then check `https://api.telegram.org/bot<TOKEN>/getUpdates`)

### Configure

```bash
NOTIFICATIONS_ENABLED=true
TELEGRAM_BOT_TOKEN="your-bot-token"
TELEGRAM_CHAT_ID="your-chat-id"
```

### Test

```bash
curl -X POST "https://api.telegram.org/bot<TOKEN>/sendMessage" \
  -d "chat_id=<CHAT_ID>&text=Test notification"
```

## Slack

### Create Webhook

1. Go to Slack API > Incoming Webhooks
2. Create a new webhook for your channel
3. Copy the webhook URL

### Configure

```bash
NOTIFICATIONS_ENABLED=true
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/..."
```

### Test

```bash
curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"Test notification"}' \
  https://hooks.slack.com/services/...
```

## Discord

### Create Webhook

1. Go to Server Settings > Integrations > Webhooks
2. Create a new webhook
3. Copy the webhook URL

### Configure

```bash
NOTIFICATIONS_ENABLED=true
DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/..."
```

### Test

```bash
curl -X POST -H 'Content-type: application/json' \
  --data '{"content":"Test notification"}' \
  https://discord.com/api/webhooks/...
```

## Email

### Requirements

- `mail` or `sendmail` command installed
- Properly configured MTA (Postfix, Sendmail, etc.)

### Configure

```bash
NOTIFICATIONS_ENABLED=true
EMAIL_TO="you@example.com"
EMAIL_FROM="backup@example.com"
EMAIL_SUBJECT="[laravel-backup] Backup Report"
```

### Test

```bash
echo "Test notification" | mail -s "Test" you@example.com
```

## Webhook

### Configure

```bash
NOTIFICATIONS_ENABLED=true
WEBHOOK_URL="https://your-api.com/webhook"
WEBHOOK_METHOD="POST"
```

### Payload Format

```json
{
  "title": "Backup Complete",
  "message": "Project: my-app\nDatabase: mysql\nDuration: 45s",
  "status": "success",
  "timestamp": "2026-07-27T12:00:00Z",
  "hostname": "server-01"
}
```

### Status Values

| Status | Description |
|--------|-------------|
| `success` | Backup completed successfully |
| `failure` | Backup failed |
| `info` | Informational message |

## Multiple Channels

Enable multiple channels simultaneously:

```bash
NOTIFICATIONS_ENABLED=true

# Telegram
TELEGRAM_BOT_TOKEN="..."
TELEGRAM_CHAT_ID="..."

# Slack
SLACK_WEBHOOK_URL="..."

# Email
EMAIL_TO="you@example.com"
EMAIL_FROM="backup@example.com"
```

## Notification Events

Notifications are sent for:

- **Backup complete** - Success notification with project name, database type, duration
- **Backup failed** - Failure notification with error details
- **Restore complete** - Success notification with duration

## Troubleshooting

### Notifications Not Sending

1. Check `NOTIFICATIONS_ENABLED=true`
2. Verify webhook URLs are correct
3. Check network connectivity
4. Look for errors in log file

### Telegram Issues

- Ensure bot is added to the chat
- Verify chat ID is correct
- Check bot token is valid

### Slack Issues

- Ensure webhook URL is valid
- Check channel permissions
- Verify webhook is active

### Discord Issues

- Ensure webhook URL is valid
- Check channel permissions
- Verify webhook is active

### Email Issues

- Check MTA is installed and configured
- Verify `mail` or `sendmail` is available
- Check email logs

### Webhook Issues

- Verify endpoint is accessible
- Check HTTP method matches configuration
- Ensure endpoint accepts JSON payload
