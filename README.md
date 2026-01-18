# BranchDb

[![Gem Version](https://badge.fury.io/rb/branch_db.svg)](https://badge.fury.io/rb/branch_db)
[![Build Status](https://github.com/milkstrawai/branch_db/actions/workflows/main.yml/badge.svg)](https://github.com/milkstrawai/branch_db/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Automatic per-branch PostgreSQL databases for Rails development.**

BranchDb eliminates database migration conflicts by giving each git branch its own isolated database. Switch branches freely without worrying about schema mismatches or losing development data.

## Table of Contents

- [The Problem](#the-problem)
- [The Solution](#the-solution)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [How It Works](#how-it-works)
- [Requirements](#requirements)
- [Important Notes](#important-notes)
- [Troubleshooting](#troubleshooting)
- [Development](#development)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [License](#license)

## The Problem

Working on multiple feature branches with different migrations causes pain:

```
# On feature-a branch: Add a 'status' column
rails generate migration AddStatusToUsers status:string
rails db:migrate

# Switch to feature-b branch
git checkout feature-b
git status
# => modified: db/schema.rb   <- Contains 'status' column from feature-a!

# Now your schema.rb has changes that don't belong to this branch
# Accidentally commit it? You've just mixed schema changes across branches
# Run db:migrate? Schema.rb still shows the foreign column
```

## The Solution

BranchDb automatically manages separate databases for each branch:

```
main branch         → myapp_development_main
feature-auth        → myapp_development_feature_auth
feature-payments    → myapp_development_feature_payments
bugfix-login        → myapp_development_bugfix_login
```

Each branch has its own isolated database with its own schema and data. Switch branches, restart your server, and you're working with the right database automatically.

## Installation

Add BranchDb to your Gemfile:

```ruby
group :development, :test do
  gem 'branch_db'
end
```

Install and run the generator:

```bash
bundle install
rails generate branch_db:install
```

Update your `config/database.yml`:

```yaml
development:
  <<: *default
  database: <%= defined?(BranchDb) ? BranchDb.database_name('myapp_development') : 'myapp_development' %>

test:
  <<: *default
  database: <%= defined?(BranchDb) ? BranchDb.database_name('myapp_test') : 'myapp_test' %>
```

> **Note:** The `defined?(BranchDb)` guard ensures production/staging environments work correctly since the gem is only loaded in development/test. Replace `myapp` with your application name.

Initialize your first branch database:

```bash
rails db:prepare
```

## Configuration

The generator creates `config/initializers/branch_db.rb`:

```ruby
BranchDb.configure do |config|
  # The name of your main/stable branch (default: 'main')
  config.main_branch = 'main'

  # Maximum length for branch name suffix (default: 33)
  # PostgreSQL has a 63 character limit for database names
  # Formula: base_name_length + 1 (underscore) + max_branch_length <= 63
  config.max_branch_length = 33

  # Database name suffixes for cleanup feature (default: '_development', '_test')
  # Customize if your database names use different conventions
  # config.development_suffix = '_development'
  # config.test_suffix = '_test'
end
```

### Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `main_branch` | `'main'` | Your primary branch name (used as fallback clone source) |
| `max_branch_length` | `33` | Max characters for branch suffix (prevents exceeding PostgreSQL's 63-char limit) |
| `development_suffix` | `'_development'` | Suffix pattern for development databases |
| `test_suffix` | `'_test'` | Suffix pattern for test databases |

## Usage

### Daily Workflow

BranchDb enhances Rails' built-in `db:prepare` command:

```bash
# Just use Rails' standard command - now branch-aware!
rails db:prepare
```

**What happens (development only):**
1. Checks if your branch's database exists and has schema
2. If missing/empty and parent/main exists: **clones from parent branch** (or main as fallback)
3. If on main branch or no source exists: defers to standard Rails behavior
4. Rails then runs pending migrations and seeds as usual

**Test databases** use standard Rails behavior (schema load, no cloning):
```bash
RAILS_ENV=test rails db:prepare
```

> **Note:** Cloning only runs in development environment. All commands support Rails' multiple database feature.

### Available Commands

| Command | Description |
|---------|-------------|
| `rails db:prepare` | Rails' standard command, enhanced with cloning from parent/main |
| `rails db:branch:list` | List all branch databases |
| `rails db:branch:purge` | Remove all branch databases except current and main |
| `rails db:branch:prune` | Remove databases for branches that no longer exist in git |

### Examples

```bash
# Starting work on a new feature branch
git checkout -b feature-new-thing
rails db:prepare  # Clones from parent branch (or main as fallback)
rails server

# Switching to another branch
git checkout feature-other-thing
# Restart your Rails server to connect to the other database
rails server

# Purging all branch databases (keeps current and main only)
rails db:branch:purge
# => Found 5 database(s) to remove:
# =>   - myapp_development_feature_old
# =>   - myapp_test_feature_old
# =>   ...
# => Proceed with deletion? [y/N]

# Pruning databases for deleted git branches only
rails db:branch:prune
# => Found 2 database(s) to remove:
# =>   - myapp_development_merged_feature
# =>   - myapp_test_merged_feature
# => Proceed with deletion? [y/N]
```

## How It Works

### Rails Integration

BranchDb enhances Rails' `db:prepare` task by adding a prerequisite that clones from the parent branch when needed. This means:

- **Zero learning curve** - use `rails db:prepare` as usual
- **Automatic cloning** - new branch databases are cloned from their parent (or main as fallback)
- **Rails handles the rest** - migrations, seeds, and schema dumps work normally

### Database Naming

BranchDb generates database names by combining your base name with a sanitized branch name:

```
Base name:    myapp_development
Branch:       feature/user-auth
Sanitized:    feature_user_auth
Result:       myapp_development_feature_user_auth
```

Branch names are sanitized: non-alphanumeric characters become underscores, and names are truncated to `max_branch_length`.

### Cloning Process

When `db:prepare` detects a missing or empty database:

1. **Detects** the parent branch to clone from (see below)
2. **Checks** if the parent database exists; if not, falls back to main
3. **If source exists:** Creates the target database and uses `pg_dump | psql` for efficient cloning
4. **If no source:** Defers to Rails' standard `db:prepare` (loads schema, runs migrations, seeds)
5. **On main branch:** Defers to Rails' standard `db:prepare`

### Parent Branch Detection

BranchDb intelligently detects which branch you branched from and clones its database. This enables nested feature branch workflows:

```
main → feature-a → feature-a-child
```

When you create `feature-a-child` from `feature-a`, BranchDb will clone from `feature-a`'s database (if it exists), not main.

**Detection priority:**

1. `BRANCH_DB_PARENT` environment variable (explicit override)
2. Git reflog analysis (finds the last "checkout: moving from X to current-branch")
3. Configured `main_branch` (fallback)

**Fallback behavior:** If the detected parent's database doesn't exist, BranchDb automatically falls back to the main branch database.

**Override with environment variable:**

```bash
# Force cloning from main, even if on a nested feature branch
BRANCH_DB_PARENT=main rails db:prepare

# Clone from a specific branch
BRANCH_DB_PARENT=feature-other rails db:prepare
```

### Purge Safety

The purge command protects important databases:
- Current branch's development and test databases
- Main branch's development and test databases
- Databases with active connections (skipped with warning)

## Requirements

- **Ruby** >= 3.2
- **Rails** >= 7.0
- **PostgreSQL** (any supported version)
- **PostgreSQL client tools** in PATH:
  - `psql` - for database operations
  - `pg_dump` - for cloning databases
  - `dropdb` - for purge/prune operations

### Verifying PostgreSQL Tools

```bash
which psql pg_dump dropdb
# Should output paths for all three tools
```

If missing, install PostgreSQL client tools:

```bash
# macOS
brew install postgresql

# Ubuntu/Debian
sudo apt-get install postgresql-client

# Docker (add to your Dockerfile)
RUN apt-get update && apt-get install -y postgresql-client
```

## Important Notes

### Server Restart Required

Database selection happens at Rails boot time (ERB in `database.yml` is evaluated once). After switching branches, **restart your Rails server** to connect to the correct database.

```bash
git checkout other-branch
# Must restart Rails to use other-branch's database
rails server  # Now connected to myapp_development_other_branch
```

### Detached HEAD State

In detached HEAD state (e.g., `git checkout abc123`), BranchDb cannot determine a branch name. It falls back to using the base database name without a suffix. All detached HEAD checkouts share this database.

For CI environments, ensure you checkout an actual branch:

```bash
# CI script
git checkout $BRANCH_NAME  # Not just the commit SHA
rails db:prepare
```

### Database Name Length

PostgreSQL limits database names to 63 characters. With default settings:
- Base name: up to 29 characters
- Underscore: 1 character
- Branch suffix: up to 33 characters

If your base name is longer, reduce `max_branch_length` accordingly.

## Troubleshooting

### "PostgreSQL tool 'X' not found in PATH"

Install PostgreSQL client tools (see [Requirements](#requirements)).

### "Could not connect to Postgres on port X"

Ensure PostgreSQL is running and accessible:

```bash
# Check if PostgreSQL is running
pg_isready -h localhost -p 5432

# For Docker users
docker ps | grep postgres
```

### Database not switching when I change branches

Remember to restart your Rails server after switching branches. The database name is determined at boot time.

### Clone is slow for large databases

`pg_dump | psql` is already efficient, but for very large databases consider:
- Keeping your main branch database lean
- Using database-level compression
- Running cleanup regularly to remove old branch databases

### Branch name too long

Long branch names are automatically truncated to `max_branch_length` (default: 33). Two branches with the same prefix might collide:

```
feature/very-long-descriptive-name-for-auth    → _feature_very_long_descriptive_na
feature/very-long-descriptive-name-for-payments → _feature_very_long_descriptive_na  # Same!
```

Use shorter branch names or increase `max_branch_length` (if your base name is short enough).

## Development

### Setup

```bash
git clone https://github.com/milkstrawai/branch_db.git
cd branch_db
bin/setup
```

### Running Tests

```bash
# Run test suite
bundle exec rspec

# Run with coverage report
bundle exec rspec && open coverage/index.html

# Run linter
bundle exec rubocop

# Run both
bundle exec rake
```

### Test Coverage

The project maintains high test coverage standards:
- Line coverage: 100%
- Branch coverage: 90%

## Roadmap

Features we're considering for future releases:

- [ ] **SQLite and MySQL support** - Database adapter pattern for non-PostgreSQL databases
- [ ] **Standalone clone task** - `rails db:branch:clone FROM=branch-name` for manual cloning
- [ ] **Post-checkout git hook** - Auto-restart Rails server on branch switch (Doable?)
- [ ] **Database info task** - `rails db:branch:info` showing current branch, DB name, size, and parent
- [ ] **Clone progress indicator** - Visual feedback for large database clones
- [ ] **Disk usage report** - `rails db:branch:list --size` to show storage per branch

Have a feature request? [Open an issue](https://github.com/milkstrawai/branch_db/issues) to discuss it!

## Contributing

Contributions are welcome! Here's how you can help:

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

### Guidelines

- Write tests for new features
- Follow existing code style (RuboCop will help)
- Update documentation as needed
- Keep commits focused and atomic

### Reporting Issues

Found a bug? Please open an issue with:
- Ruby and Rails versions
- PostgreSQL version
- Steps to reproduce
- Expected vs actual behavior

## License

BranchDb is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Acknowledgments

Inspired by the pain of database migration conflicts and the joy of isolated development environments.
