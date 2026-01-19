# Test Suite Documentation

## Overview

The `test.sh` script provides a fully automated, non-interactive test runner for the pgctl project. It runs all tests without prompts or manual intervention.

## Usage

### Basic Usage

```bash
./test.sh
```

This will:
- Use credentials from `config.env`
- Run all available tests
- Automatically clean up test data after completion

### Advanced Options

```bash
./test.sh [OPTIONS]

Options:
  --host, -h        PostgreSQL host (default: localhost)
  --port, -p        PostgreSQL port (default: 5432)
  --user, -u        Admin username (default: postgres)
  --password, -P    Admin password (default: from config.env)
  --database, -d    Test database name (default: pgctl_test)
  --no-cleanup      Skip cleanup after tests (retain test data for inspection)
  --verbose, -v     Show detailed output
  --help            Show help message
```

### Examples

```bash
# Run with default settings
./test.sh

# Run with custom credentials
./test.sh --host localhost --port 5432 --user postgres --password mypassword

# Run and keep test data for inspection
./test.sh --no-cleanup

# Run with verbose output
./test.sh --verbose
```

## Test Coverage

The test suite currently runs **88 tests** across the following areas:

### Database Tests (11 tests)
- Database creation with 5 standard users
- Duplicate database detection
- Database ownership verification
- User privilege validation
- Database listing

### User Tests (13 tests)
- User existence checks
- User listing functionality
- Custom user creation
- Password change operations
- User privilege flags (CREATEDB, CREATEROLE)

### Permission Tests (64 tests)
- Migration user DDL permissions (CREATE/DROP TABLE)
- Owner permissions
- Fullaccess user CRUD operations
- App user CRU operations (no DELETE)
- Readonly user SELECT-only access
- Sequence permissions
- Function execution permissions
- Default privileges on newly created tables
- Schema-specific permissions
- Permission revocation

## Configuration

### Environment Variables

The test script uses the following environment variables (automatically set from `config.env`):

```bash
PGHOST=localhost              # PostgreSQL host
PGPORT=5432                   # PostgreSQL port
PGADMIN=postgres              # Admin username
PGPASSWORD=password           # Admin password
PG_TEST_DATABASE=pgctl_test   # Test database name
```

### Test Passwords

The following test passwords are automatically set:

```bash
# Database-level users
DB_OWNER_PASSWORD="test_owner_pass"
DB_MIGRATION_PASSWORD="test_migration_pass"
DB_FULLACCESS_PASSWORD="test_fullaccess_pass"
DB_APP_PASSWORD="test_app_pass"
DB_READONLY_PASSWORD="test_readonly_pass"

# Schema-level users
SCHEMA_OWNER_PASSWORD="test_schema_owner_pass"
SCHEMA_MIGRATION_PASSWORD="test_schema_migration_pass"
SCHEMA_FULLACCESS_PASSWORD="test_schema_fullaccess_pass"
SCHEMA_APP_PASSWORD="test_schema_app_pass"
SCHEMA_READONLY_PASSWORD="test_schema_readonly_pass"
```

## Test Execution Flow

1. **Connection Test**: Verifies PostgreSQL connectivity
2. **Environment Setup**: Cleans up any existing test database and users
3. **Database Tests**: Tests database creation and management
4. **User Tests**: Tests user creation and management
5. **Schema Setup**: Creates a test schema for permission testing
6. **Permission Tests**: Comprehensive permission and privilege tests
7. **Cleanup**: Automatically removes all test data (unless `--no-cleanup` is specified)

## Non-Interactive Features

The test script includes several features to ensure non-interactive execution:

- **Auto-confirmation**: All prompts are automatically answered with "yes"
- **Pre-set passwords**: All required passwords are set via environment variables
- **Disabled gum**: Interactive TUI components are disabled
- **Output redirection**: Schema creation output is redirected to prevent hanging
- **Piped yes**: Ensures any unexpected prompts are automatically answered

## Exit Codes

- `0`: All tests passed
- `1`: One or more tests failed

## Test Results

The test suite provides a summary at completion:

```
═══════════════════════════════
TEST RESULTS

Total:  88
Passed: 88
Failed: 0
═══════════════════════════════
```

## Troubleshooting

### Connection Errors

If you see connection errors:
```bash
✗ Cannot connect to PostgreSQL
✗ Please check your credentials in config.env or use --password option
```

Solution: Verify your PostgreSQL credentials in `config.env` or pass them via command-line options.

### Test Failures

If tests fail, run with `--verbose` and `--no-cleanup` to inspect:
```bash
./test.sh --verbose --no-cleanup
```

Then you can manually inspect the test database:
```bash
psql -h localhost -p 5432 -U postgres -d pgctl_test
```

### Cleanup Test Data

If you need to manually clean up test data:
```bash
# Drop test database
psql -h localhost -p 5432 -U postgres -c "DROP DATABASE IF EXISTS pgctl_test;"

# Drop test users
psql -h localhost -p 5432 -U postgres -c "DROP ROLE IF EXISTS pgctl_test_owner;"
```

## Notes

- The test suite requires a running PostgreSQL instance
- Tests are run against a dedicated `pgctl_test` database
- All test data is isolated and cleaned up after completion
- Tests run in approximately 10-15 seconds on a local PostgreSQL instance

## Future Enhancements

The following test suites are planned for future implementation:

- **Schema Tests**: Comprehensive schema creation and management tests (currently integrated into permission tests)
- **Multiselect Tests**: Interactive component tests for multi-database operations
