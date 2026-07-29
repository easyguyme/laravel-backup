# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-07-27

### Added

- Initial release
- `init` command for project initialization
- `backup` command with database dump, compression, and encryption
- `restore` command for full project restoration
- `verify` command for backup integrity checks
- `cleanup` command for retention management
- `status` command for project overview
- `schedule` command for cron and systemd timer setup
- `update` command for self-updating
- MySQL, MariaDB, PostgreSQL, and SQLite support
- AES-256-CBC encryption via OpenSSL
- Automatic upload folder detection
- Git integration with auto-commit, tag, and push
- GitHub integration via `gh` CLI
- Notification support (Telegram, Slack, Discord, Email, Webhook)
- Lock files for concurrent execution prevention
- Manifest generation with project metadata
- Cross-platform support (Ubuntu, Debian, Rocky, Alma, CentOS Stream, macOS, WSL)
- Comprehensive documentation
- Install and uninstall scripts
