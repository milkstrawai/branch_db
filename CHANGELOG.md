## [Unreleased]

## [0.1.1] - 2026-01-18

### Fixed

- Fixed production/staging crash caused by undefined `BranchDb` constant when gem is only loaded in development/test groups
- Updated initializer template with `return unless defined?(BranchDb)` guard
- Updated documentation with `defined?(BranchDb)` guard in `database.yml` examples

## [0.1.0] - 2026-01-18

### Added

- Automatic per-branch PostgreSQL database management for Rails
- Seamless integration with Rails `db:prepare` task
- Automatic cloning from parent branch database (with main as fallback) when creating new branch databases
- Smart parent branch detection via git reflog analysis
- `BRANCH_DB_PARENT` environment variable to override parent branch detection
- Development-only cloning (test databases use standard Rails schema load)
- `BranchDb.database_name` helper for dynamic database naming in `database.yml`
- `rails db:branch:list` task to list all branch databases
- `rails db:branch:purge` task to remove all branch databases (keeps main and current)
- `rails db:branch:prune` task to remove databases for deleted git branches
- Support for Rails multiple database configurations
- Configurable main branch name (default: `main`)
- Configurable branch name length limit (default: 33 characters)
- Configurable database suffixes (`development_suffix`, `test_suffix`)
- Active connection detection to prevent dropping databases in use
- Rails generator for easy installation (`rails generate branch_db:install`)
