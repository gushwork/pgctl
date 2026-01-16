#!/bin/bash

# =============================================================================
# Permission Tests for pgctl
# =============================================================================
# Tests for permission granting, revoking, and verification
# =============================================================================

# This file is sourced by test-runner.sh

# Source dependencies
source "${LIB_DIR}/permissions.sh"

# =============================================================================
# Setup Test Objects
# =============================================================================

setup_test_objects() {
    log_info "Creating test objects..."
    
    # Create test table
    psql_admin_quiet "CREATE TABLE IF NOT EXISTS test_table (id SERIAL PRIMARY KEY, name TEXT);" "$TEST_DATABASE"
    
    # Create test sequence
    psql_admin_quiet "CREATE SEQUENCE IF NOT EXISTS test_sequence;" "$TEST_DATABASE"
    
    # Create test function
    psql_admin_quiet "CREATE OR REPLACE FUNCTION test_function() RETURNS TEXT AS \$\$ SELECT 'test'; \$\$ LANGUAGE SQL;" "$TEST_DATABASE"
    
    # Grant ownership to database owner
    psql_admin_quiet "ALTER TABLE test_table OWNER TO ${TEST_DATABASE}_owner;" "$TEST_DATABASE"
    psql_admin_quiet "ALTER SEQUENCE test_sequence OWNER TO ${TEST_DATABASE}_owner;" "$TEST_DATABASE"
}

# =============================================================================
# Permission Tests
# =============================================================================

test_migration_user_ddl() {
    log_info "Testing migration user DDL permissions..."
    
    local migration="${TEST_DATABASE}_migration_user"
    
    # Check CREATE privilege on schema
    local has_create
    has_create=$(psql_admin "SELECT has_schema_privilege('$migration', 'public', 'CREATE');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    if [[ "$has_create" == "t" ]]; then
        test_pass "Migration user has CREATE on schema"
    else
        test_fail "Migration user has CREATE on schema"
    fi
}

test_fullaccess_user_crud() {
    log_info "Testing fullaccess user CRUD permissions..."
    
    setup_test_objects
    
    local fullaccess="${TEST_DATABASE}_fullaccess_user"
    
    # Grant permissions
    grant_all_permissions "$TEST_DATABASE" "$fullaccess" "fullaccess_user" "public" > /dev/null 2>&1
    
    # Check SELECT
    local has_select
    has_select=$(psql_admin "SELECT has_table_privilege('$fullaccess', 'test_table', 'SELECT');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    if [[ "$has_select" == "t" ]]; then
        test_pass "Fullaccess user has SELECT"
    else
        test_fail "Fullaccess user has SELECT"
    fi
    
    # Check INSERT
    local has_insert
    has_insert=$(psql_admin "SELECT has_table_privilege('$fullaccess', 'test_table', 'INSERT');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    if [[ "$has_insert" == "t" ]]; then
        test_pass "Fullaccess user has INSERT"
    else
        test_fail "Fullaccess user has INSERT"
    fi
    
    # Check UPDATE
    local has_update
    has_update=$(psql_admin "SELECT has_table_privilege('$fullaccess', 'test_table', 'UPDATE');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    if [[ "$has_update" == "t" ]]; then
        test_pass "Fullaccess user has UPDATE"
    else
        test_fail "Fullaccess user has UPDATE"
    fi
    
    # Check DELETE
    local has_delete
    has_delete=$(psql_admin "SELECT has_table_privilege('$fullaccess', 'test_table', 'DELETE');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    if [[ "$has_delete" == "t" ]]; then
        test_pass "Fullaccess user has DELETE"
    else
        test_fail "Fullaccess user has DELETE"
    fi
}

test_app_user_cru_only() {
    log_info "Testing app user CRU (no DELETE) permissions..."
    
    local app="${TEST_DATABASE}_app_user"
    
    # Grant permissions
    grant_all_permissions "$TEST_DATABASE" "$app" "app_user" "public" > /dev/null 2>&1
    
    # Check SELECT
    local has_select
    has_select=$(psql_admin "SELECT has_table_privilege('$app', 'test_table', 'SELECT');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    if [[ "$has_select" == "t" ]]; then
        test_pass "App user has SELECT"
    else
        test_fail "App user has SELECT"
    fi
    
    # Check INSERT
    local has_insert
    has_insert=$(psql_admin "SELECT has_table_privilege('$app', 'test_table', 'INSERT');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    if [[ "$has_insert" == "t" ]]; then
        test_pass "App user has INSERT"
    else
        test_fail "App user has INSERT"
    fi
    
    # Check UPDATE
    local has_update
    has_update=$(psql_admin "SELECT has_table_privilege('$app', 'test_table', 'UPDATE');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    if [[ "$has_update" == "t" ]]; then
        test_pass "App user has UPDATE"
    else
        test_fail "App user has UPDATE"
    fi
    
    # Check DELETE (should NOT have)
    local has_delete
    has_delete=$(psql_admin "SELECT has_table_privilege('$app', 'test_table', 'DELETE');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    if [[ "$has_delete" == "f" ]]; then
        test_pass "App user does NOT have DELETE"
    else
        test_fail "App user does NOT have DELETE" "App user has DELETE which is not expected"
    fi
}

test_readonly_user_select_only() {
    log_info "Testing readonly user SELECT only permissions..."
    
    local readonly="${TEST_DATABASE}_readonly_user"
    
    # Grant permissions
    grant_all_permissions "$TEST_DATABASE" "$readonly" "readonly_user" "public" > /dev/null 2>&1
    
    # Check SELECT
    local has_select
    has_select=$(psql_admin "SELECT has_table_privilege('$readonly', 'test_table', 'SELECT');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    if [[ "$has_select" == "t" ]]; then
        test_pass "Readonly user has SELECT"
    else
        test_fail "Readonly user has SELECT"
    fi
    
    # Check INSERT (should NOT have)
    local has_insert
    has_insert=$(psql_admin "SELECT has_table_privilege('$readonly', 'test_table', 'INSERT');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    if [[ "$has_insert" == "f" ]]; then
        test_pass "Readonly user does NOT have INSERT"
    else
        test_fail "Readonly user does NOT have INSERT"
    fi
    
    # Check UPDATE (should NOT have)
    local has_update
    has_update=$(psql_admin "SELECT has_table_privilege('$readonly', 'test_table', 'UPDATE');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    if [[ "$has_update" == "f" ]]; then
        test_pass "Readonly user does NOT have UPDATE"
    else
        test_fail "Readonly user does NOT have UPDATE"
    fi
    
    # Check DELETE (should NOT have)
    local has_delete
    has_delete=$(psql_admin "SELECT has_table_privilege('$readonly', 'test_table', 'DELETE');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    if [[ "$has_delete" == "f" ]]; then
        test_pass "Readonly user does NOT have DELETE"
    else
        test_fail "Readonly user does NOT have DELETE"
    fi
}

test_sequence_permissions() {
    log_info "Testing sequence permissions..."
    
    local fullaccess="${TEST_DATABASE}_fullaccess_user"
    local readonly="${TEST_DATABASE}_readonly_user"
    
    # Fullaccess should have USAGE
    local has_usage
    has_usage=$(psql_admin "SELECT has_sequence_privilege('$fullaccess', 'test_sequence', 'USAGE');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    if [[ "$has_usage" == "t" ]]; then
        test_pass "Fullaccess user has USAGE on sequence"
    else
        test_fail "Fullaccess user has USAGE on sequence"
    fi
    
    # Readonly should have SELECT on sequence
    local has_select
    has_select=$(psql_admin "SELECT has_sequence_privilege('$readonly', 'test_sequence', 'SELECT');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    if [[ "$has_select" == "t" ]]; then
        test_pass "Readonly user has SELECT on sequence"
    else
        test_fail "Readonly user has SELECT on sequence"
    fi
}

test_function_permissions() {
    log_info "Testing function permissions..."
    
    local app="${TEST_DATABASE}_app_user"
    
    # App user should have EXECUTE
    local has_execute
    has_execute=$(psql_admin "SELECT has_function_privilege('$app', 'test_function()', 'EXECUTE');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    if [[ "$has_execute" == "t" ]]; then
        test_pass "App user has EXECUTE on function"
    else
        test_fail "App user has EXECUTE on function"
    fi
}

test_revoke_permissions() {
    log_info "Testing permission revocation..."
    
    local test_user="test_custom_user"
    
    # First grant SELECT
    psql_admin_quiet "GRANT SELECT ON test_table TO $test_user;" "$TEST_DATABASE"
    
    # Verify grant worked
    local has_select
    has_select=$(psql_admin "SELECT has_table_privilege('$test_user', 'test_table', 'SELECT');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    if [[ "$has_select" == "t" ]]; then
        test_pass "SELECT granted to custom user"
    else
        test_fail "SELECT granted to custom user"
    fi
    
    # Now revoke
    psql_admin_quiet "REVOKE SELECT ON test_table FROM $test_user;" "$TEST_DATABASE"
    
    # Verify revoke worked
    has_select=$(psql_admin "SELECT has_table_privilege('$test_user', 'test_table', 'SELECT');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    if [[ "$has_select" == "f" ]]; then
        test_pass "SELECT revoked from custom user"
    else
        test_fail "SELECT revoked from custom user"
    fi
}

# =============================================================================
# Run Tests
# =============================================================================

test_migration_user_ddl
test_fullaccess_user_crud
test_app_user_cru_only
test_readonly_user_select_only
test_sequence_permissions
test_function_permissions
test_revoke_permissions
