# Architecture Overview

This document explains the architecture and design decisions behind laravel-backup.

## Project Structure

```
laravel-backup/
├── laravel-backup          # CLI router (main entry point)
├── commands/               # Subcommand implementations
│   ├── init.sh             # Initialize in a Laravel project
│   ├── backup.sh           # Create a backup
│   ├── restore.sh          # Restore from backup
│   ├── verify.sh           # Verify backup integrity
│   ├── cleanup.sh          # Remove old backups
│   ├── status.sh           # Show project status
│   ├── schedule.sh         # Set up automated backups
│   └── update.sh           # Self-update
├── lib/                    # Shared library modules
│   ├── colours.sh          # Terminal colour definitions
│   ├── logging.sh          # Centralized logging
│   ├── env.sh              # Environment detection
│   ├── helpers.sh          # General utilities
│   ├── validator.sh        # Input validation
│   ├── config.sh           # Configuration management
│   ├── lock.sh             # Concurrency prevention
│   ├── mysql.sh            # MySQL operations
│   ├── postgres.sh         # PostgreSQL operations
│   ├── sqlite.sh           # SQLite operations
│   ├── git.sh              # Git operations
│   ├── github.sh           # GitHub CLI integration
│   ├── archive.sh          # Archive creation/extraction
│   ├── encrypt.sh          # AES-256-CBC encryption
│   └── notifications.sh    # Multi-channel notifications
├── templates/              # Templates for init
│   ├── restore.sh          # Standalone restore script
│   ├── gitignore           # .gitignore entries
│   └── manifest.json       # Backup manifest schema
├── tests/                  # Test suite
│   └── run_tests.sh        # Custom test framework
├── docs/                   # Documentation
├── examples/               # Example configurations
├── install.sh              # System installer
├── uninstall.sh            # System uninstaller
├── backup.conf.example     # Example configuration
├── VERSION                 # Version number
├── CHANGELOG.md            # Changelog
└── LICENSE                 # MIT License
```

## Design Philosophy

### Bash-First Approach

laravel-backup is written entirely in Bash for several reasons:

1. **Zero dependencies** - No runtime required beyond Bash and standard Unix tools
2. **Universal availability** - Bash is installed on virtually all Unix-like systems
3. **Simplicity** - Shell scripts are easy to understand, modify, and debug
4. **Portability** - Works on macOS, Linux, and WSL without modification

### Modular Architecture

The codebase is organized into focused modules:

- **CLI Router** (`laravel-backup`) - Dispatches commands to `commands/` directory
- **Commands** (`commands/`) - Each command is a self-contained script
- **Libraries** (`lib/`) - Shared functionality loaded by commands

This separation provides:

- **Single responsibility** - Each module does one thing well
- **Testability** - Libraries can be tested independently
- **Maintainability** - Changes to one feature don't affect others
- **Reusability** - Libraries can be sourced by multiple commands

### Convention Over Configuration

laravel-backup uses sensible defaults:

- Auto-detects database from `.env`
- Auto-detects upload directories
- Auto-detects OS and adjusts commands
- Uses standard Laravel directory structure

Users only need to configure what differs from defaults.

## Backup Pipeline

The backup process follows a 14-step pipeline:

```
┌─────────────────────────────────────────────────────────────┐
│                    Backup Pipeline                          │
├─────────────────────────────────────────────────────────────┤
│  1. Lock acquisition     │  Prevents concurrent runs        │
│  2. Load .env            │  Read Laravel environment        │
│  3. Detect database      │  Identify MySQL/PostgreSQL/SQLite│
│  4. Dump database        │  Create compressed SQL dump      │
│  5. Encrypt database     │  AES-256-CBC encryption          │
│  6. Detect uploads       │  Find upload directories         │
│  7. Archive uploads      │  Create tar.gz archive           │
│  8. Encrypt uploads      │  AES-256-CBC encryption          │
│  9. Generate manifest    │  Create JSON metadata            │
│ 10. Finalize             │  Copy to backup directory        │
│ 11. Git commit           │  Stage and commit files          │
│ 12. Git tag              │  Create annotated tag            │
│ 13. Git push             │  Push to remote (if enabled)     │
│ 14. Notify               │  Send notifications              │
└─────────────────────────────────────────────────────────────┘
```

### Why a Pipeline?

The pipeline approach provides:

1. **Clear separation** - Each step has a single responsibility
2. **Error handling** - Failures at any step are caught and reported
3. **Dry run support** - Steps can be simulated without side effects
4. **Composability** - Steps can be skipped with flags
5. **Logging** - Each step provides progress feedback

### Error Handling

The pipeline uses `set -Eeuo pipefail` for strict error handling:

- **`-E`** - ERR trap is inherited by functions
- **`-e`** - Exit on error
- **`-u`** - Treat unset variables as errors
- **`-o pipefail`** - Return last non-zero exit code in pipelines

If any step fails:

1. The error is logged
2. Temp files are cleaned up
3. The lock is released
4. A failure notification is sent
5. The script exits with non-zero status

## Security Architecture

### Encryption

laravel-backup uses AES-256-CBC encryption via OpenSSL:

- **Algorithm**: AES-256-CBC (256-bit key)
- **Key derivation**: PBKDF2 with 100,000 iterations
- **Salt**: Random (generated per encryption)
- **IV**: Random (generated per encryption)

The high iteration count makes brute-force attacks computationally expensive.

### Password Management

Passwords are never stored in configuration files. Three sources are supported:

1. **Environment variable** (`BACKUP_PASSWORD`) - Recommended for automated backups
2. **Password file** - For systems where environment variables are impractical
3. **Interactive prompt** - For manual backups only (not suitable for cron)

### Input Sanitization

The codebase prevents:

- **Path traversal** - Command names and filenames are validated
- **Shell injection** - All variables are properly quoted
- **Eval usage** - No `eval` commands anywhere
- **Unquoted variables** - All shell variables are quoted

### Lock Files

The lock mechanism prevents concurrent backup runs:

- Uses PID files in `/tmp/laravel-backup-<name>.lock`
- Checks if existing lock holder is still running
- Automatically removes stale locks from dead processes

## Library Modules

### colours.sh

Provides terminal colour definitions with TTY detection. Colours are automatically stripped when output is not a terminal.

### logging.sh

Centralized logging with levels (DEBUG, INFO, WARNING, ERROR, SUCCESS). Supports:

- Console output with colours
- File logging with timestamps
- Key-value pair display
- Section headers

### env.sh

Environment detection and `.env` file parsing. Handles:

- OS detection (Linux, macOS, WSL)
- Laravel project detection
- Database type detection
- Safe `.env` parsing with quote stripping

### helpers.sh

General utilities including:

- Command existence checking
- User prompts (Y/N, input, password)
- Human-readable file sizes
- SHA-256 checksums
- Retry with exponential backoff
- Disk space checking

### validator.sh

Input and state validation:

- Laravel project validation
- Backup directory validation
- Database connection testing
- Backup file validation
- Configuration validation
- Encryption password validation

### config.sh

Configuration management with 37 default values. Loads configuration from:

1. Specified file path
2. `backup.conf` in project root
3. `backup.conf` next to script
4. Built-in defaults

### lock.sh

PID-based lock files for concurrency prevention. Features:

- Stale lock detection
- Automatic cleanup
- Named locks for different operations

### Database Modules (mysql.sh, postgres.sh, sqlite.sh)

Database-specific operations:

- **Dump**: Create compressed SQL dumps
- **Restore**: Import SQL dumps
- **Test**: Verify database connections
- **Size**: Get database sizes

Each module handles the specific CLI tools and connection parameters for its database type.

### git.sh

Git operations for backup management:

- Check git availability
- Stage and commit backup files
- Create annotated tags
- Push to remote
- Detect remote provider (GitHub/GitLab/Bitbucket)

### github.sh

GitHub CLI integration:

- Check `gh` CLI availability
- Create repositories
- Add remotes

### archive.sh

Archive creation and extraction:

- Create tar.gz archives
- Extract tar.gz archives
- Auto-detect upload directories

Upload directory detection scans for common Laravel directories:

- `storage/app`
- `storage/app/public`
- `public/storage`
- `public/uploads`
- `uploads`
- `images`
- `media`
- `assets`

### encrypt.sh

AES-256-CBC encryption/decryption:

- Encrypt files (removes original)
- Decrypt files
- Verify encrypted files
- Support multiple password sources

### notifications.sh

Multi-channel notification system:

- Telegram bot API
- Slack incoming webhooks
- Discord webhooks
- Email via mail/sendmail
- Custom webhooks

All channels run in parallel for fast delivery.

## Testing Strategy

The test suite (`tests/run_tests.sh`) uses a custom assertion-based framework:

- **CLI tests**: Router behavior, help output, version
- **Library tests**: All 15 libraries load without error
- **Function tests**: Key functions work correctly
- **Integration tests**: Encryption round-trip, file operations

Tests are designed to be:

- **Fast** - Run in seconds
- **Isolated** - No side effects
- **Portable** - Work on all supported platforms

## Platform Support

### Supported Platforms

- Ubuntu
- Debian
- Rocky Linux
- AlmaLinux
- CentOS Stream
- macOS
- WSL

### Platform-Specific Handling

The codebase handles platform differences:

- **`stat` flags**: macOS uses `-f%z`, Linux uses `-c%s`
- **`sed` in-place**: macOS requires `-i ''`, Linux uses `-i`
- **Path resolution**: Handles both GNU and BSD `readlink`
- **Database clients**: Detects available clients per platform

## Performance Considerations

### Compression

Database dumps are compressed with gzip (level 6 by default). This provides:

- Good compression ratio
- Fast compression speed
- Wide compatibility

### Encryption Overhead

AES-256-CBC with PBKDF2 (100k iterations) adds:

- ~1-2 seconds per file for key derivation
- Minimal overhead for actual encryption

### Parallel Notifications

All notification channels run in parallel, preventing slow channels from blocking others.

### Lock Contention

The lock mechanism uses PID files with stale detection, minimizing contention while preventing concurrent runs.

## Future Considerations

### Potential Enhancements

- **Incremental backups** - Only backup changed data
- **Remote storage** - S3, GCS, Azure Blob
- **Compression alternatives** - zstd, bzip2
- **Encryption alternatives** - GPG, age
- **Web UI** - Dashboard for managing backups
- **Metrics** - Prometheus/StatsD integration

### Backwards Compatibility

The project follows semantic versioning:

- **Major**: Breaking changes to config format or CLI
- **Minor**: New features with backwards compatibility
- **Patch**: Bug fixes and security updates
