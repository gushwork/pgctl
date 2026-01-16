#!/bin/bash

# =============================================================================
# Schema Library for pgctl
# =============================================================================
# Functions for creating, deleting, and listing schemas with schema-specific users
# =============================================================================

# Prevent multiple sourcing
[[ -n "${PGCTL_SCHEMA_LOADED:-}" ]] && return
PGCTL_SCHEMA_LOADED=1

# Source dependencies
_SCHEMA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_SCHEMA_DIR}/common.sh"
source "${_SCHEMA_DIR}/permissions.sh"

# =============================================================================
# Schema Creation
# =============================================================================

# Create a schema with 5 schema-specific users
create_schema() {
    local dbname="${1:-}"
    local schemaname="${2:-}"
    
    log_header "Schema Creation Wizard"
    
    # Check connection
    if ! check_connection; then
        return 1
    fi
    
    # Get database name if not provided
    if [[ -z "$dbname" ]]; then
        local databases
        databases=$(list_databases_query)
        
        if [[ -z "$databases" ]]; then
            log_error "No databases found"
            return 1
        fi
        
        dbname=$(prompt_select "Select target database:" $databases)
        
        if [[ -z "$dbname" ]]; then
            log_error "No database selected"
            return 1
        fi
    fi
    
    # Verify database exists
    if ! database_exists "$dbname"; then
        log_error "Database '$dbname' does not exist"
        return 1
    fi
    
    # Get schema name if not provided
    if [[ -z "$schemaname" ]]; then
        schemaname=$(prompt_input "Schema name")
    fi
    
    # Validate schema name
    if ! validate_schema_name "$schemaname"; then
        return 1
    fi
    
    # Check if schema already exists
    if schema_exists "$dbname" "$schemaname"; then
        log_error "Schema '$schemaname' already exists in database '$dbname'"
        return 1
    fi
    
    # Define user prefix
    local prefix="${dbname}_${schemaname}"
    
    # Validate user name lengths
    if ! validate_user_names_length "$prefix"; then
        log_warning "Schema user names will exceed PostgreSQL limits."
        if ! prompt_confirm "Continue anyway?"; then
            return 1
        fi
    fi
    
    # Define user names
    local owner="${prefix}_owner"
    local migration="${prefix}_migration_user"
    local fullaccess="${prefix}_fullaccess_user"
    local app="${prefix}_app_user"
    local readonly="${prefix}_readonly_user"
    
    # Get passwords
    echo ""
    local owner_pass
    owner_pass=$(get_password "SCHEMA_OWNER_PASSWORD" "Schema owner password")
    
    local migration_pass
    migration_pass=$(get_password "SCHEMA_MIGRATION_PASSWORD" "Migration user password")
    
    local fullaccess_pass
    fullaccess_pass=$(get_password "SCHEMA_FULLACCESS_PASSWORD" "Full access user password")
    
    local app_pass
    app_pass=$(get_password "SCHEMA_APP_PASSWORD" "App user password")
    
    local readonly_pass
    readonly_pass=$(get_password "SCHEMA_READONLY_PASSWORD" "Read-only user password")
    
    echo ""
    
    # Create schema owner user
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum spin --spinner dot --title "Creating $owner..." -- \
            bash -c "PGPASSWORD='$PGPASSWORD' psql -h '$PGHOST' -p '$PGPORT' -U '$PGADMIN' -c \"CREATE ROLE $owner WITH LOGIN PASSWORD '$owner_pass';\" > /dev/null 2>&1"
    else
        echo -n "Creating $owner... "
        psql_admin_quiet "CREATE ROLE $owner WITH LOGIN PASSWORD '$owner_pass';"
    fi
    log_success "Schema owner created"
    
    # Create schema
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum spin --spinner dot --title "Creating schema $schemaname..." -- \
            bash -c "PGPASSWORD='$PGPASSWORD' psql -h '$PGHOST' -p '$PGPORT' -U '$PGADMIN' -d '$dbname' -c 'CREATE SCHEMA $schemaname AUTHORIZATION $owner;' > /dev/null 2>&1"
    else
        echo -n "Creating schema $schemaname... "
        psql_admin_quiet "CREATE SCHEMA $schemaname AUTHORIZATION $owner;" "$dbname"
    fi
    log_success "Schema created successfully"
    
    # Setting schema ownership is done via AUTHORIZATION above
    log_success "Ownership configured"
    
    # Create migration user
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum spin --spinner dot --title "Creating $migration..." -- \
            bash -c "PGPASSWORD='$PGPASSWORD' psql -h '$PGHOST' -p '$PGPORT' -U '$PGADMIN' -c \"CREATE ROLE $migration WITH LOGIN PASSWORD '$migration_pass';\" > /dev/null 2>&1"
    else
        echo -n "Creating $migration... "
        psql_admin_quiet "CREATE ROLE $migration WITH LOGIN PASSWORD '$migration_pass';"
    fi
    log_success "Schema migration user created"
    
    # Create fullaccess user
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum spin --spinner dot --title "Creating $fullaccess..." -- \
            bash -c "PGPASSWORD='$PGPASSWORD' psql -h '$PGHOST' -p '$PGPORT' -U '$PGADMIN' -c \"CREATE ROLE $fullaccess WITH LOGIN PASSWORD '$fullaccess_pass';\" > /dev/null 2>&1"
    else
        echo -n "Creating $fullaccess... "
        psql_admin_quiet "CREATE ROLE $fullaccess WITH LOGIN PASSWORD '$fullaccess_pass';"
    fi
    log_success "Schema fullaccess user created"
    
    # Create app user
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum spin --spinner dot --title "Creating $app..." -- \
            bash -c "PGPASSWORD='$PGPASSWORD' psql -h '$PGHOST' -p '$PGPORT' -U '$PGADMIN' -c \"CREATE ROLE $app WITH LOGIN PASSWORD '$app_pass';\" > /dev/null 2>&1"
    else
        echo -n "Creating $app... "
        psql_admin_quiet "CREATE ROLE $app WITH LOGIN PASSWORD '$app_pass';"
    fi
    log_success "Schema app user created"
    
    # Create readonly user
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum spin --spinner dot --title "Creating $readonly..." -- \
            bash -c "PGPASSWORD='$PGPASSWORD' psql -h '$PGHOST' -p '$PGPORT' -U '$PGADMIN' -c \"CREATE ROLE $readonly WITH LOGIN PASSWORD '$readonly_pass';\" > /dev/null 2>&1"
    else
        echo -n "Creating $readonly... "
        psql_admin_quiet "CREATE ROLE $readonly WITH LOGIN PASSWORD '$readonly_pass';"
    fi
    log_success "Schema readonly user created"
    
    # Configure schema permissions
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum spin --spinner dot --title "Configuring schema permissions..." -- \
            bash -c "source '${PGCTL_LIB_DIR}/permissions.sh'
                     grant_all_permissions '$dbname' '$owner' 'owner' '$schemaname'
                     grant_all_permissions '$dbname' '$migration' 'migration_user' '$schemaname'
                     grant_all_permissions '$dbname' '$fullaccess' 'fullaccess_user' '$schemaname'
                     grant_all_permissions '$dbname' '$app' 'app_user' '$schemaname'
                     grant_all_permissions '$dbname' '$readonly' 'readonly_user' '$schemaname'"
    else
        echo -n "Configuring schema permissions... "
        grant_all_permissions "$dbname" "$owner" "owner" "$schemaname"
        grant_all_permissions "$dbname" "$migration" "migration_user" "$schemaname"
        grant_all_permissions "$dbname" "$fullaccess" "fullaccess_user" "$schemaname"
        grant_all_permissions "$dbname" "$app" "app_user" "$schemaname"
        grant_all_permissions "$dbname" "$readonly" "readonly_user" "$schemaname"
    fi
    log_success "Schema permissions configured"
    
    # Revoke PUBLIC schema access (full isolation)
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum spin --spinner dot --title "Revoking PUBLIC schema access..." -- \
            bash -c "source '${PGCTL_LIB_DIR}/permissions.sh'
                     revoke_public_schema_access '$dbname' '$schemaname'
                     # Also revoke access to public schema for schema users
                     revoke_all_permissions '$dbname' '$owner' 'public'
                     revoke_all_permissions '$dbname' '$migration' 'public'
                     revoke_all_permissions '$dbname' '$fullaccess' 'public'
                     revoke_all_permissions '$dbname' '$app' 'public'
                     revoke_all_permissions '$dbname' '$readonly' 'public'"
    else
        echo -n "Revoking PUBLIC schema access... "
        revoke_public_schema_access "$dbname" "$schemaname"
        revoke_all_permissions "$dbname" "$owner" "public"
        revoke_all_permissions "$dbname" "$migration" "public"
        revoke_all_permissions "$dbname" "$fullaccess" "public"
        revoke_all_permissions "$dbname" "$app" "public"
        revoke_all_permissions "$dbname" "$readonly" "public"
    fi
    log_success "Full schema isolation enabled (no PUBLIC access)"
    
    # Configure default privileges for future objects
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum spin --spinner dot --title "Configuring default privileges..." -- \
            bash -c "source '${PGCTL_LIB_DIR}/permissions.sh'
                     set_default_privileges_for_all '$dbname' '$prefix' '$schemaname'"
    else
        echo -n "Configuring default privileges... "
        set_default_privileges_for_all "$dbname" "$prefix" "$schemaname"
    fi
    log_success "Default privileges configured for future objects"
    
    echo ""
    
    # Display summary
    local summary="✓ Schema Setup Complete

Database: $dbname
Schema: $schemaname
Owner: $owner
Schema users created: 5
Isolation: Full (no PUBLIC/cross-schema)
Default privileges: ✓ Enabled
Status: Ready"
    
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum style --border rounded --padding "1 2" --border-foreground 10 "$summary"
    else
        log_box "$summary"
    fi
}

# =============================================================================
# Schema Deletion
# =============================================================================

# Delete a schema and its users
delete_schema() {
    local dbname="${1:-}"
    local schemaname="${2:-}"
    
    log_header "Delete Schema"
    
    # Check connection
    if ! check_connection; then
        return 1
    fi
    
    # Get database name if not provided
    if [[ -z "$dbname" ]]; then
        local databases
        databases=$(list_databases_query)
        
        if [[ -z "$databases" ]]; then
            log_error "No databases found"
            return 1
        fi
        
        dbname=$(prompt_select "Select database:" $databases)
        
        if [[ -z "$dbname" ]]; then
            log_error "No database selected"
            return 1
        fi
    fi
    
    # Get schema name if not provided
    if [[ -z "$schemaname" ]]; then
        local schemas
        schemas=$(list_schemas_query "$dbname")
        
        if [[ -z "$schemas" ]]; then
            log_error "No custom schemas found in database '$dbname'"
            return 1
        fi
        
        schemaname=$(prompt_select "Select schema to delete:" $schemas)
        
        if [[ -z "$schemaname" ]]; then
            log_error "No schema selected"
            return 1
        fi
    fi
    
    # Verify schema exists
    if ! schema_exists "$dbname" "$schemaname"; then
        log_error "Schema '$schemaname' does not exist in database '$dbname'"
        return 1
    fi
    
    # Define user prefix
    local prefix="${dbname}_${schemaname}"
    
    # List users that will be deleted
    local users=("${prefix}_owner" "${prefix}_migration_user" "${prefix}_fullaccess_user" "${prefix}_app_user" "${prefix}_readonly_user")
    
    log_warning "This will permanently delete:"
    echo "  Schema: $schemaname (with CASCADE)"
    echo "  Users:"
    for user in "${users[@]}"; do
        if user_exists "$user"; then
            echo "    - $user"
        fi
    done
    echo ""
    
    # Confirm deletion
    if ! prompt_confirm "Are you sure you want to delete this schema?"; then
        log_info "Deletion cancelled"
        return 0
    fi
    
    # Delete schema with CASCADE
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum spin --spinner dot --title "Deleting schema $schemaname..." -- \
            bash -c "PGPASSWORD='$PGPASSWORD' psql -h '$PGHOST' -p '$PGPORT' -U '$PGADMIN' -d '$dbname' -c 'DROP SCHEMA IF EXISTS $schemaname CASCADE;' > /dev/null 2>&1"
    else
        echo -n "Deleting schema $schemaname... "
        psql_admin_quiet "DROP SCHEMA IF EXISTS $schemaname CASCADE;" "$dbname"
    fi
    log_success "Schema deleted"
    
    # Delete users
    for user in "${users[@]}"; do
        if user_exists "$user"; then
            if [[ "$GUM_AVAILABLE" == "true" ]]; then
                gum spin --spinner dot --title "Deleting user $user..." -- \
                    bash -c "PGPASSWORD='$PGPASSWORD' psql -h '$PGHOST' -p '$PGPORT' -U '$PGADMIN' -c 'DROP ROLE IF EXISTS $user;' > /dev/null 2>&1"
            else
                echo -n "Deleting user $user... "
                psql_admin_quiet "DROP ROLE IF EXISTS $user;"
            fi
            log_success "Deleted $user"
        fi
    done
    
    echo ""
    log_success "Schema and all associated users deleted successfully"
}

# =============================================================================
# Schema Listing
# =============================================================================

# List all schemas in a database
list_schemas() {
    local dbname="${1:-}"
    
    log_header "Schemas"
    
    # Check connection
    if ! check_connection; then
        return 1
    fi
    
    # Get database name if not provided
    if [[ -z "$dbname" ]]; then
        local databases
        databases=$(list_databases_query)
        
        if [[ -z "$databases" ]]; then
            log_error "No databases found"
            return 1
        fi
        
        dbname=$(prompt_select "Select database:" $databases)
        
        if [[ -z "$dbname" ]]; then
            log_error "No database selected"
            return 1
        fi
    fi
    
    log_info "Database: $dbname"
    echo ""
    
    local sql="SELECT n.nspname AS schema_name,
               pg_catalog.pg_get_userbyid(n.nspowner) AS owner,
               (SELECT COUNT(*) FROM information_schema.tables t WHERE t.table_schema = n.nspname) AS table_count
               FROM pg_catalog.pg_namespace n
               WHERE n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
               AND n.nspname NOT LIKE 'pg_%'
               ORDER BY n.nspname;"
    
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        local result
        result=$(psql_admin "$sql" "$dbname" 2>/dev/null)
        echo "$result" | gum table
    else
        psql_admin "$sql" "$dbname"
    fi
}

# List schema-specific users
list_schema_users() {
    local dbname="${1:-}"
    local schemaname="${2:-}"
    
    log_header "Schema Users"
    
    # Check connection
    if ! check_connection; then
        return 1
    fi
    
    # Get database name if not provided
    if [[ -z "$dbname" ]]; then
        local databases
        databases=$(list_databases_query)
        
        if [[ -z "$databases" ]]; then
            log_error "No databases found"
            return 1
        fi
        
        dbname=$(prompt_select "Select database:" $databases)
        
        if [[ -z "$dbname" ]]; then
            log_error "No database selected"
            return 1
        fi
    fi
    
    # Get schema name if not provided
    if [[ -z "$schemaname" ]]; then
        local schemas
        schemas=$(list_schemas_query "$dbname")
        
        if [[ -z "$schemas" ]]; then
            log_error "No custom schemas found in database '$dbname'"
            return 1
        fi
        
        schemaname=$(prompt_select "Select schema:" $schemas)
        
        if [[ -z "$schemaname" ]]; then
            log_error "No schema selected"
            return 1
        fi
    fi
    
    log_info "Database: $dbname / Schema: $schemaname"
    echo ""
    
    local prefix="${dbname}_${schemaname}"
    
    local sql="SELECT rolname AS username,
               CASE 
                   WHEN rolname LIKE '%_owner' THEN 'owner'
                   WHEN rolname LIKE '%_migration_user' THEN 'migration'
                   WHEN rolname LIKE '%_fullaccess_user' THEN 'fullaccess'
                   WHEN rolname LIKE '%_app_user' THEN 'app'
                   WHEN rolname LIKE '%_readonly_user' THEN 'readonly'
                   ELSE 'unknown'
               END AS role_type,
               CASE WHEN rolcanlogin THEN 'Yes' ELSE 'No' END AS can_login
               FROM pg_roles
               WHERE rolname LIKE '${prefix}_%'
               ORDER BY rolname;"
    
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        local result
        result=$(psql_admin "$sql" 2>/dev/null)
        echo "$result" | gum table
    else
        psql_admin "$sql"
    fi
}

# =============================================================================
# Schema Access Management
# =============================================================================

# Grant existing user access to a schema
grant_schema_access() {
    log_header "Grant Schema Access"
    
    # Check connection
    if ! check_connection; then
        return 1
    fi
    
    # Get database
    local databases
    databases=$(list_databases_query)
    
    if [[ -z "$databases" ]]; then
        log_error "No databases found"
        return 1
    fi
    
    local dbname
    dbname=$(prompt_select "Select database:" $databases)
    
    if [[ -z "$dbname" ]]; then
        log_error "No database selected"
        return 1
    fi
    
    # Get schema
    local schemas
    schemas=$(list_schemas_query "$dbname")
    
    if [[ -z "$schemas" ]]; then
        log_error "No custom schemas found"
        return 1
    fi
    
    local schemaname
    schemaname=$(prompt_select "Select schema:" $schemas)
    
    if [[ -z "$schemaname" ]]; then
        log_error "No schema selected"
        return 1
    fi
    
    # Get user
    local users
    users=$(list_users_query)
    
    if [[ -z "$users" ]]; then
        log_error "No users found"
        return 1
    fi
    
    local username
    username=$(prompt_select "Select user:" $users)
    
    if [[ -z "$username" ]]; then
        log_error "No user selected"
        return 1
    fi
    
    # Select permission level
    local role_type
    role_type=$(prompt_select "Select permission level:" "readonly_user" "app_user" "fullaccess_user" "migration_user" "owner")
    
    if [[ -z "$role_type" ]]; then
        log_error "No permission level selected"
        return 1
    fi
    
    # Grant permissions
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum spin --spinner dot --title "Granting $role_type permissions to $username on $schemaname..." -- \
            bash -c "source '${PGCTL_LIB_DIR}/permissions.sh'; grant_all_permissions '$dbname' '$username' '$role_type' '$schemaname'"
    else
        echo -n "Granting permissions... "
        grant_all_permissions "$dbname" "$username" "$role_type" "$schemaname"
    fi
    
    log_success "Granted $role_type permissions to $username on schema $schemaname"
}

# =============================================================================
# Command Wrappers for CLI
# =============================================================================

cmd_create_schema() {
    create_schema "$@"
}

cmd_delete_schema() {
    delete_schema "$@"
}

cmd_list_schemas() {
    list_schemas "$@"
}

cmd_list_schema_users() {
    list_schema_users "$@"
}

cmd_grant_schema_access() {
    grant_schema_access "$@"
}

# =============================================================================
# Register Commands
# =============================================================================

register_command "Create Schema" "SCHEMA MANAGEMENT" "cmd_create_schema" \
    "Create a new schema with 5 standard users"

register_command "Delete Schema" "SCHEMA MANAGEMENT" "cmd_delete_schema" \
    "Delete a schema and all associated users"

register_command "List Schemas" "SCHEMA MANAGEMENT" "cmd_list_schemas" \
    "List all schemas in a database"

register_command "Grant Schema Access" "SCHEMA MANAGEMENT" "cmd_grant_schema_access" \
    "Grant existing user access to a schema"
