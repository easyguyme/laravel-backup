# Design Decisions

This document explains the key design decisions behind laravel-backup and why they were made.

## Why Bash?

### Decision

Write the entire tool in Bash shell script.

### Alternatives Considered

1. **PHP** - Would require PHP installed, but Laravel projects already have PHP
2. **Python** - More features, but adds dependency
3. **Go/Rust** - Compiled binary, but harder to modify
4. **Node.js** - Requires Node.js installation

### Rationale

1. **Zero dependencies** - Only requires Bash and standard Unix tools
2. **Universal availability** - Bash is installed on virtually all systems
3. **Simplicity** - Easy to understand, modify, and debug
4. **Portability** - Works on macOS, Linux, WSL without modification
5. **Laravel ecosystem** - Developers are comfortable with command-line tools

### Trade-offs

**Pros:**
- No runtime dependencies
- Easy to install and uninstall
- Simple to debug and modify
- Fast startup time

**Cons:**
- Limited data structures
- No type safety
- String-heavy processing
- Harder to test formally

## Why Not Use Laravel's Built-in Backup?

### Decision

Create a standalone tool instead of a Laravel package.

### Rationale

1. **External operation** - Can backup without Laravel running
2. **No vendor dependency** - Doesn't add to composer.json
3. **Simpler deployment** - Just copy a directory
4. **Easier maintenance** - No package updates required
5. **Framework agnostic** - Could work with other PHP frameworks

### Trade-offs

**Pros:**
- No framework dependency
- Simpler installation
- Easier to customize
- Works outside Laravel context

**Cons:**
- Doesn't integrate with Laravel's service container
- Can't use Laravel's configuration system
- Separate maintenance burden

## Why AES-256-CBC?

### Decision

Use AES-256-CBC encryption via OpenSSL.

### Alternatives Considered

1. **AES-256-GCM** - Authenticated encryption, but less compatible
2. **ChaCha20-Poly1305** - Modern, but not in OpenSSL by default
3. **GPG** - More features, but heavier
4. **age** - Simpler, but newer and less widespread

### Rationale

1. **Widespread support** - OpenSSL is installed everywhere
2. **Battle-tested** - AES is industry standard
3. **Good performance** - Hardware acceleration on modern CPUs
4. **PBKDF2** - Strong key derivation with 100k iterations

### Trade-offs

**Pros:**
- Universal compatibility
- Well-understood security properties
- Hardware acceleration
- Good tooling support

**Cons:**
- Not authenticated (CBC mode)
- Requires proper IV handling
- More complex than some alternatives

## Why PBKDF2 with 100k Iterations?

### Decision

Use PBKDF2 with 100,000 iterations for key derivation.

### Alternatives Considered

1. **bcrypt** - Good, but designed for passwords
2. **scrypt** - Memory-hard, but less common
3. **Argon2** - Modern winner, but not in OpenSSL
4. **Fewer iterations** - Faster, but less secure

### Rationale

1. **OpenSSL support** - Built-in, no extra dependencies
2. **Standard** - Widely used and understood
3. **Adequate security** - 100k iterations makes brute-force expensive
4. **Reasonable performance** - ~1-2 seconds per key derivation

### Trade-offs

**Pros:**
- No extra dependencies
- Well-understood security
- Adequate for backup encryption
- Reasonable performance

**Cons:**
- Not memory-hard like Argon2
- Slower than simpler KDFs
- Fixed iteration count (not adaptive)

## Why PID-Based Lock Files?

### Decision

Use PID files in `/tmp` for concurrent execution prevention.

### Alternatives Considered

1. **File locks (flock)** - More robust, but less portable
2. **Database locks** - Requires database connection
3. **Redis/Memcached** - Requires external service
4. **No locking** - Simpler, but risks corruption

### Rationale

1. **Simplicity** - Easy to implement and understand
2. **No dependencies** - Uses only filesystem
3. **Stale detection** - Can detect dead processes
4. **Cross-platform** - Works everywhere

### Trade-offs

**Pros:**
- Simple implementation
- No external dependencies
- Easy to debug
- Works on all platforms

**Cons:**
- Race conditions possible
- Requires cleanup of stale locks
- Not distributed-safe
- Relies on `/tmp` availability

## Why Parallel Notifications?

### Decision

Run all notification channels in parallel.

### Alternatives Considered

1. **Sequential** - Simpler, but slower
2. **Parallel with timeout** - More complex, but bounded
3. **Queue-based** - More robust, but requires infrastructure
4. **Single channel** - Simpler, but less flexible

### Rationale

1. **Speed** - All channels notified quickly
2. **Independence** - Channels don't depend on each other
3. **Failure isolation** - One channel failing doesn't affect others
4. **Simplicity** - Easy to implement with bash job control

### Trade-offs

**Pros:**
- Fast notification delivery
- Failure isolation
- Simple implementation
- No infrastructure requirements

**Cons:**
- Harder to debug
- No guaranteed delivery order
- Potential resource contention
- Error handling complexity

## Why Auto-Detect Upload Directories?

### Decision

Automatically detect common upload directories.

### Alternatives Considered

1. **Require explicit configuration** - More control, but more work
2. **Fixed list** - Simpler, but less flexible
3. **Pattern matching** - More flexible, but complex
4. **No upload backup** - Simpler, but incomplete

### Rationale

1. **Convention over configuration** - Works out of the box
2. **Laravel conventions** - Follows standard directory structure
3. **Reduced configuration** - Most users don't need to change defaults
4. **Extensible** - Can add more directories via config

### Trade-offs

**Pros:**
- Works out of the box
- Follows Laravel conventions
- Reduces configuration burden
- Still configurable

**Cons:**
- May miss custom directories
- May include unnecessary directories
- Hardcoded list requires updates
- Not framework-agnostic

## Why Standalone Restore Script?

### Decision

Generate a standalone `restore.sh` during initialization.

### Alternatives Considered

1. **Use main CLI** - Simpler, but requires installation
2. **No restore script** - Simpler, but less convenient
3. **PHP restore script** - More features, but requires PHP
4. **Docker restore** - More isolated, but heavier

### Rationale

1. **Emergency recovery** - Can restore without laravel-backup installed
2. **Simplicity** - Single file, minimal dependencies
3. **Portability** - Can be copied and used anywhere
4. **Documentation** - Serves as example of restore process

### Trade-offs

**Pros:**
- Emergency recovery capability
- No installation required
- Simple to understand
- Portable

**Cons:**
- Code duplication
- May drift from main implementation
- Limited features
- Requires manual updates

## Why Custom Test Framework?

### Decision

Use a custom assertion-based test framework instead of an established framework.

### Alternatives Considered

1. **Bats (Bash Automated Testing System)** - More features, but dependency
2. **shunit2** - More complete, but heavier
3. **PHPUnit with shell_exec** - More familiar, but complex
4. **No tests** - Simpler, but risky

### Rationale

1. **Zero dependencies** - No extra tools required
2. **Simplicity** - Easy to understand and maintain
3. **Self-contained** - Single file, easy to run
4. **Adequate** - Covers needed test cases

### Trade-offs

**Pros:**
- No dependencies
- Simple to understand
- Easy to run
- Self-contained

**Cons:**
- Limited features
- No test isolation
- Manual assertions
- Harder to extend

## Why Not Use Laravel's .env Parser?

### Decision

Implement a custom `.env` parser instead of using Laravel's.

### Alternatives Considered

1. **Use `php artisan tinker`** - More accurate, but requires PHP
2. **Use `vlucas/phpdotenv`** - More features, but dependency
3. **Use `grep`/`sed`** - Simpler, but less robust
4. **Require explicit config** - More control, but more work

### Rationale

1. **No PHP dependency** - Can parse `.env` without PHP
2. **Simplicity** - Basic parsing is sufficient
3. **Portability** - Works anywhere with bash
4. **Performance** - Fast startup, no process creation

### Trade-offs

**Pros:**
- No PHP dependency
- Fast execution
- Simple implementation
- Portable

**Cons:**
- Less robust than PHP parser
- May not handle edge cases
- Code duplication
- Limited features

## Why Randomize Backup Hours?

### Decision

Randomize the hour for scheduled backups (0-5).

### Alternatives Considered

1. **Fixed hour** - Simpler, but predictable
2. **User-specified** - More control, but more configuration
3. **No randomization** - Simpler, but risks thundering herd
4. **Multiple times** - More backups, but more resources

### Rationale

1. **Thundering herd prevention** - Avoids all backups running at same time
2. **Shared infrastructure** - Important for shared hosting/CI
3. **Simplicity** - Automatic, no configuration needed
4. **Reasonable window** - 0-5 AM is low-traffic period

### Trade-offs

**Pros:**
- Prevents thundering herd
- Automatic, no configuration
- Reasonable time window
- Low-traffic period

**Cons:**
- Less predictable
- Harder to debug timing issues
- May not suit all timezones
- Fixed window may not be optimal

## Future Considerations

### Potential Changes

1. **Authenticated encryption** - Move from CBC to GCM
2. **Modern KDF** - Consider Argon2 when available in OpenSSL
3. **Incremental backups** - Only backup changed data
4. **Remote storage** - S3, GCS, Azure integration
5. **Web UI** - Dashboard for managing backups

### Backwards Compatibility

The project follows semantic versioning:

- **Major**: Breaking changes to config format or CLI
- **Minor**: New features with backwards compatibility
- **Patch**: Bug fixes and security updates

Configuration files and backup formats are maintained across minor versions.
