#!/bin/bash

# =============================================================================
# Schema Tests for pgctl
# =============================================================================
# Tests for schema creation, deletion, and schema-specific users
# =============================================================================

# This file is sourced by test-runner.sh

# Source dependencies
source "${LIB_DIR}/schema.sh"

# =============================================================================
# Schema Tests
# =============================================================================

test_create_schema() {
    log_info "Testing schema creation..."
    
    local test_schema="test_schema"
    
    # Set test passwords
    export SCHEMA_OWNER_PASSWORD="test_schema_owner_pass"
    export SCHEMA_MIGRATION_PASSWORD="test_schema_migration_pass"
    export SCHEMA_FULLACCESS_PASSWORD="test_schema_fullaccess_pass"
    export SCHEMA_APP_PASSWORD="test_schema_app_pass"
    export SCHEMA_READONLY_PASSWORD="test_schema_readonly_pass"
    
    # Create schema  
    # Note: Not redirecting output to avoid hanging issues with table formatters
    create_schema "$TEST_DATABASE" "$test_schema" &> /tmp/test_schema_output.txt
    local result=$?
    
    if [[ $result -eq 0 ]]; then
        test_pass "create_schema returns success"
    else
        test_fail "create_schema returns success" "Exit code: $result"
    fi
    
    # Verify schema exists
    if schema_exists "$TEST_DATABASE" "$test_schema"; then
        test_pass "Schema exists after creation"
    else
        test_fail "Schema exists after creation"
    fi
    
    # Verify schema-specific users exist
    local prefix="${TEST_DATABASE}_${test_schema}"
    
    if user_exists "${prefix}_owner"; then
        test_pass "Schema owner created"
    else
        test_fail "Schema owner created"
    fi
    
    if user_exists "${prefix}_migration_user"; then
        test_pass "Schema migration user created"
    else
        test_fail "Schema migration user created"
    fi
    
    if user_exists "${prefix}_fullaccess_user"; then
        test_pass "Schema fullaccess user created"
    else
        test_fail "Schema fullaccess user created"
    fi
    
    if user_exists "${prefix}_app_user"; then
        test_pass "Schema app user created"
    else
        test_fail "Schema app user created"
    fi
    
    if user_exists "${prefix}_readonly_user"; then
        test_pass "Schema readonly user created"
    else
        test_fail "Schema readonly user created"
    fi
}

test_schema_ownership() {
    log_info "Testing schema ownership..."
    
    local test_schema="test_schema"
    local prefix="${TEST_DATABASE}_${test_schema}"
    local expected_owner="${prefix}_owner"
    
    local owner
    owner=$(psql_admin "SELECT nspowner::regrole FROM pg_namespace WHERE nspname = '$test_schema';" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    if [[ "$owner" == "$expected_owner" ]]; then
        test_pass "Schema owned by ${expected_owner}"
    else
        test_fail "Schema owned by ${expected_owner}" "Actual owner: $owner"
    fi
}

test_schema_isolation() {
    log_info "Testing schema isolation..."
    
    local test_schema="test_schema"
    local prefix="${TEST_DATABASE}_${test_schema}"
    local schema_user="${prefix}_readonly_user"
    
    # Check that schema user has USAGE on their schema
    local has_usage
    has_usage=$(psql_admin "SELECT has_schema_privilege('$schema_user', '$test_schema', 'USAGE');" "$TEST_DATABASE" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    if [[ "$has_usage" == "t" ]]; then
        test_pass "Schema user has USAGE on their schema"
    else
        test_fail "Schema user has USAGE on their schema"
    fi
}

test_schema_naming_convention() {
    log_info "Testing schema naming convention..."
    
    local test_schema="test_schema"
    local prefix="${TEST_DATABASE}_${test_schema}"
    
    # Verify naming convention is correct
    local migration_user="${prefix}_migration_user"
    
    if user_exists "$migration_user"; then
        test_pass "Schema users follow naming convention {db}_{schema}_{role}"
    else
        test_fail "Schema users follow naming convention {db}_{schema}_{role}"
    fi
}

test_list_schemas() {
    log_info "Testing schema listing..."
    
    local result
    result=$(list_schemas "$TEST_DATABASE" 2>/dev/null)
    
    if [[ "$result" == *"test_schema"* ]]; then
        test_pass "Test schema appears in list"
    else
        test_fail "Test schema appears in list"
    fi
    
    if [[ "$result" == *"public"* ]]; then
        test_pass "Public schema appears in list"
    else
        test_fail "Public schema appears in list"
    fi
}

# =============================================================================
# Run Tests
# =============================================================================

test_create_schema
test_schema_ownership
test_schema_isolation
test_schema_naming_convention
test_list_schemas
